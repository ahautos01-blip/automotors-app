-- APNs device registration and transactional delivery queue.
-- Apple credentials live only in Edge Function secrets, never in this file.
begin;
create table public.push_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  session_id uuid not null references auth.sessions(id) on delete cascade,
  token text not null check(token ~ '^[0-9a-f]+$' and length(token) between 64 and 512),
  environment text not null check(environment in ('sandbox','production')),
  active boolean not null default true,
  updated_at timestamptz not null default now(),
  unique(token,environment)
);
create index push_devices_user_idx on public.push_devices(user_id);
create index push_devices_session_idx on public.push_devices(session_id);
alter table public.push_devices enable row level security;
revoke all on public.push_devices from public,anon,authenticated;
grant select,delete on public.push_devices to authenticated;
grant all on public.push_devices to service_role;
create policy "users see own push devices" on public.push_devices for select to authenticated using(user_id=(select auth.uid()));
create policy "users remove own push devices" on public.push_devices for delete to authenticated using(user_id=(select auth.uid()));

create table private.push_worker_config (
  singleton boolean primary key default true check(singleton),
  worker_token text not null default encode(extensions.gen_random_bytes(32),'hex')
);
insert into private.push_worker_config(singleton) values(true);
create table private.push_deliveries (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references public.push_devices(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  event_key text not null,
  kind text not null check(kind in ('chat_message','review_requested')),
  listing_id uuid references public.vehicle_listings(id) on delete cascade,
  conversation_id bigint references public.chat_conversations(id) on delete cascade,
  message_id bigint references public.chat_messages(id) on delete cascade,
  status text not null default 'pending' check(status in ('pending','sent','discarded','failed')),
  attempts integer not null default 0,
  created_at timestamptz not null default now(),
  available_at timestamptz not null default now(),
  lease_until timestamptz,
  lease_token uuid,
  last_error text,
  unique(device_id,event_key)
);
create index push_deliveries_pending_idx on private.push_deliveries(available_at) where status='pending';
create index push_deliveries_user_idx on private.push_deliveries(user_id);
create index push_deliveries_listing_idx on private.push_deliveries(listing_id);
create index push_deliveries_conversation_idx on private.push_deliveries(conversation_id);
create index push_deliveries_message_idx on private.push_deliveries(message_id);
alter table private.push_worker_config enable row level security;
alter table private.push_deliveries enable row level security;
create policy "worker reads private config" on private.push_worker_config for select to service_role using(true);
create policy "worker manages deliveries" on private.push_deliveries for all to service_role using(true) with check(true);
revoke all on private.push_worker_config,private.push_deliveries from public,anon,authenticated;
grant usage on schema private to service_role;
grant select,update on private.push_worker_config,private.push_deliveries to service_role;

-- Rebind a device on account changes. A session revocation deletes its tokens.
create function private.register_push_device(p_token text,p_environment text) returns void
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_session uuid; v_device uuid;
begin
  v_session:=nullif(auth.jwt()->>'session_id','')::uuid;
  if v_user is null or not exists(select 1 from auth.sessions where id=v_session and user_id=v_user) then
    raise exception 'Inicia sesión para activar las notificaciones.' using errcode='42501';
  end if;
  if (p_token !~ '^[0-9a-f]+$' or length(p_token) not between 64 and 512) or p_token is null or p_environment not in ('sandbox','production') or p_environment is null then
    raise exception 'Dispositivo no válido.';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_token||p_environment,9));
  delete from private.push_deliveries q using public.push_devices d
    where q.device_id=d.id and d.token=p_token and d.environment=p_environment
      and (d.user_id<>v_user or d.session_id<>v_session);
  insert into public.push_devices(user_id,session_id,token,environment)
    values(v_user,v_session,p_token,p_environment)
  on conflict(token,environment) do update set user_id=excluded.user_id,session_id=excluded.session_id,active=true,updated_at=now()
  returning id into v_device;
  -- Recover unread purchase invitations on the first push-enabled installation.
  insert into private.push_deliveries(device_id,user_id,event_key,kind,listing_id)
    select v_device,v_user,'review:'||a.id,'review_requested',a.listing_id
    from public.vehicle_search_alerts a join public.vehicle_listings v on v.id=a.listing_id
    where a.user_id=v_user and a.alert_type='review_requested' and a.read_at is null
      and a.created_at>now()-interval '7 days' and v.status='sold' and not v.sold_externally
      and v.sold_to_buyer_id=v_user
      and not exists(select 1 from public.vehicle_reviews r where r.listing_id=v.id and r.buyer_id=v_user)
    on conflict(device_id,event_key) do nothing;
end; $$;
revoke all on function private.register_push_device(text,text) from public,anon;
grant usage on schema private to authenticated;
grant execute on function private.register_push_device(text,text) to authenticated;
create function public.register_push_device(p_token text,p_environment text) returns void
language sql security invoker set search_path='' as $$ select private.register_push_device(p_token,p_environment); $$;
revoke all on function public.register_push_device(text,text) from public,anon;
grant execute on function public.register_push_device(text,text) to authenticated;

create function private.queue_chat_push() returns trigger
language plpgsql security definer set search_path='' as $$
declare c public.chat_conversations; recipient uuid;
begin
  if auth.uid() is not null and auth.uid()<>new.sender_id then raise exception 'Remitente no válido.'; end if;
  select * into c from public.chat_conversations where id=new.conversation_id;
  if new.sender_id=c.buyer_id then recipient:=c.seller_id;
  elsif new.sender_id=c.seller_id then recipient:=c.buyer_id;
  else raise exception 'El remitente no pertenece a esta conversación.'; end if;
  insert into private.push_deliveries(device_id,user_id,event_key,kind,listing_id,conversation_id,message_id)
    select d.id,recipient,'message:'||new.id,'chat_message',c.listing_id,c.id,new.id
    from public.push_devices d where d.user_id=recipient and d.active
      and d.updated_at>now()-interval '90 days'
    on conflict(device_id,event_key) do nothing;
  return new;
end; $$;
revoke all on function private.queue_chat_push() from public,anon,authenticated;
create trigger queue_chat_push after insert on public.chat_messages for each row execute function private.queue_chat_push();

create function private.queue_review_push() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.alert_type<>'review_requested' then return new; end if;
  if auth.uid() is not null and not exists(select 1 from public.vehicle_listings v
      where v.id=new.listing_id and v.owner_id=auth.uid()) then
    raise exception 'Solo el vendedor puede confirmar esta compra.' using errcode='42501';
  end if;
  if not exists(select 1 from public.vehicle_listings v where v.id=new.listing_id and v.status='sold'
      and not v.sold_externally and v.sold_to_buyer_id=new.user_id) then return new; end if;
  insert into private.push_deliveries(device_id,user_id,event_key,kind,listing_id)
    select d.id,new.user_id,'review:'||new.id,'review_requested',new.listing_id
    from public.push_devices d where d.user_id=new.user_id and d.active
      and d.updated_at>now()-interval '90 days'
    on conflict(device_id,event_key) do nothing;
  return new;
end; $$;
revoke all on function private.queue_review_push() from public,anon,authenticated;
create trigger queue_review_push after insert on public.vehicle_search_alerts for each row execute function private.queue_review_push();

-- These worker RPCs are callable only with the server's service role.
create function public.authorize_push_worker(p_token text) returns boolean
language sql security invoker set search_path='' as $$
  select exists(select 1 from private.push_worker_config where worker_token=p_token);
$$;
create function public.claim_push_deliveries(p_token text) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare result jsonb;
begin
  if not public.authorize_push_worker(p_token) then raise exception 'Unauthorized' using errcode='42501'; end if;
  update private.push_deliveries q set status='discarded',last_error='expired_or_no_longer_pending'
  where status='pending' and (
    q.created_at<now()-case when q.kind='chat_message' then interval '1 day' else interval '7 days' end
    or not exists(select 1 from public.push_devices d where d.id=q.device_id and d.user_id=q.user_id and d.active)
    or (q.kind='chat_message' and exists(select 1 from public.chat_messages m where m.id=q.message_id and m.read_at is not null))
    or (q.kind='review_requested' and (
      exists(select 1 from public.vehicle_reviews r where r.listing_id=q.listing_id and r.buyer_id=q.user_id)
      or not exists(select 1 from public.vehicle_listings v where v.id=q.listing_id and v.status='sold' and not v.sold_externally and v.sold_to_buyer_id=q.user_id)))
  );
  update private.push_deliveries set status='failed',last_error='retry_limit'
    where status='pending' and attempts>=8 and (lease_until is null or lease_until<now());
  with candidates as (
    select id from private.push_deliveries where status='pending' and available_at<=now()
      and attempts<8 and (lease_until is null or lease_until<now())
      order by created_at for update skip locked limit 25
  ), claimed as (
    update private.push_deliveries q set attempts=attempts+1,lease_until=now()+interval '3 minutes',lease_token=gen_random_uuid()
      from candidates c where q.id=c.id returning q.*
  ) select coalesce(jsonb_agg(jsonb_build_object(
    'id',q.id,'lease_token',q.lease_token,'attempts',q.attempts,'kind',q.kind,
    'user_id',q.user_id,'listing_id',q.listing_id,'conversation_id',q.conversation_id::text,
    'token',d.token,'environment',d.environment,
    'expiration',extract(epoch from q.created_at+case when q.kind='chat_message' then interval '1 day' else interval '7 days' end)::bigint
  )),'[]'::jsonb) into result from claimed q join public.push_devices d on d.id=q.device_id;
  return result;
end; $$;
create function public.finish_push_delivery(p_id uuid,p_lease_token uuid,p_status text,p_error text default null,p_retry_seconds integer default 60,p_disable_device boolean default false) returns void
language plpgsql security invoker set search_path='' as $$
declare device uuid;
begin
  if p_status not in ('sent','pending','failed') then raise exception 'Invalid delivery status'; end if;
  update private.push_deliveries set status=p_status,last_error=left(p_error,120),lease_until=null,lease_token=null,
    available_at=now()+make_interval(secs=>greatest(30,least(p_retry_seconds,3600)))
    where id=p_id and status='pending' and lease_token=p_lease_token returning device_id into device;
  if p_disable_device and device is not null then update public.push_devices set active=false where id=device; end if;
end; $$;
revoke all on function public.authorize_push_worker(text),public.claim_push_deliveries(text),public.finish_push_delivery(uuid,uuid,text,text,integer,boolean) from public,anon,authenticated;
grant execute on function public.authorize_push_worker(text),public.claim_push_deliveries(text),public.finish_push_delivery(uuid,uuid,text,text,integer,boolean) to service_role;
notify pgrst,'reload schema';
commit;
