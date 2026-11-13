begin;
alter table public.push_devices add column buyer_alerts boolean not null default false;
create or replace function private.register_push_device(p_token text,p_environment text) returns void
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
  on conflict(token,environment) do update set user_id=excluded.user_id,session_id=excluded.session_id,active=true,buyer_alerts=false,updated_at=now()
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

create function private.register_buyer_push_device(p_token text,p_environment text,p_buyer_alerts boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform private.register_push_device(p_token,p_environment);
 update public.push_devices set buyer_alerts=coalesce(p_buyer_alerts,false)
 where token=p_token and environment=p_environment and user_id=auth.uid() and session_id=(auth.jwt()->>'session_id')::uuid;
end; $$;
revoke all on function private.register_buyer_push_device(text,text,boolean) from public,anon;
grant execute on function private.register_buyer_push_device(text,text,boolean) to authenticated;
create function public.register_push_device(p_token text,p_environment text,p_buyer_alerts boolean) returns void
language sql security invoker set search_path='' as $$ select private.register_buyer_push_device(p_token,p_environment,p_buyer_alerts); $$;
revoke all on function public.register_push_device(text,text,boolean) from public,anon;
grant execute on function public.register_push_device(text,text,boolean) to authenticated;
alter table private.push_deliveries drop constraint push_deliveries_kind_check;
alter table private.push_deliveries add constraint push_deliveries_kind_check check(kind in ('chat_message','review_requested','new_listing','price_drop'));

create index vehicle_alerts_unread_push_idx on public.vehicle_search_alerts(user_id,listing_id,alert_type,created_at) where read_at is null;

-- Private cross-account preference check. No public RPC or client queue writes.
create function private.buyer_push_allowed(p_user uuid,p_listing uuid,p_kind text) returns boolean
language sql stable security definer set search_path='' as $$
 select p_kind in ('new_listing','price_drop')
 and exists(select 1 from auth.users where id=p_user)
 and not exists(select 1 from private.account_deletions where user_id=p_user)
 and not exists(select 1 from private.account_suspensions where user_id=p_user)
 and exists(select 1 from public.vehicle_listings v where v.id=p_listing and v.status in ('published','reserved') and v.owner_id<>p_user
   and private.community_subject_active(v.owner_id) and private.listing_not_held(v.id)
   and (not private.content_moderation_enabled() or private.listing_content_approved(v.id))
   and not exists(select 1 from private.chat_user_blocks b where (b.blocker_id=p_user and b.blocked_id=v.owner_id) or (b.blocker_id=v.owner_id and b.blocked_id=p_user))
   and exists(select 1 from public.vehicle_search_alerts a where a.user_id=p_user and a.listing_id=v.id and a.alert_type=p_kind and a.read_at is null
     and a.created_at>now()-interval '1 day'
     and (p_kind<>'price_drop' or v.price<=a.current_price)
     and (exists(select 1 from public.saved_vehicle_searches s where s.id=a.search_id and s.user_id=p_user
        and case when p_kind='new_listing' then s.notify_new_listings else s.notify_price_drops end)
       or (p_kind='price_drop' and a.search_id is null and exists(select 1 from public.saved_vehicles f where f.user_id=p_user and f.listing_id=v.id and f.notify_price_drops)))));
$$;
revoke all on function private.buyer_push_allowed(uuid,uuid,text) from public,anon,authenticated;
grant execute on function private.buyer_push_allowed(uuid,uuid,text) to service_role;

create function private.queue_buyer_push() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.alert_type not in ('new_listing','price_drop') or new.read_at is not null then return new; end if;
 if not private.buyer_push_allowed(new.user_id,new.listing_id,new.alert_type) then return new; end if;
 insert into private.push_deliveries(device_id,user_id,event_key,kind,listing_id)
 select d.id,new.user_id,'watch:'||new.alert_type||':'||new.listing_id||':'||extract(epoch from transaction_timestamp())::text,new.alert_type,new.listing_id
 from public.push_devices d join auth.sessions s on s.id=d.session_id and s.user_id=d.user_id
 where d.user_id=new.user_id and d.active and d.buyer_alerts and d.updated_at>now()-interval '90 days'
 and (s.not_after is null or s.not_after>now())
 on conflict(device_id,event_key) do nothing;
 return new;
end; $$;
revoke all on function private.queue_buyer_push() from public,anon,authenticated;
create trigger queue_buyer_push after insert or update of created_at,current_price on public.vehicle_search_alerts
 for each row execute function private.queue_buyer_push();
create function private.push_session_active(p_device uuid,p_user uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.push_devices d join auth.sessions s on s.id=d.session_id and s.user_id=d.user_id
 where d.id=p_device and d.user_id=p_user and d.active and (s.not_after is null or s.not_after>now()));
$$;
revoke all on function private.push_session_active(uuid,uuid) from public,anon,authenticated;
grant execute on function private.push_session_active(uuid,uuid) to service_role;

create or replace function public.claim_push_deliveries(p_token text) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare result jsonb;
begin
  if not public.authorize_push_worker(p_token) then raise exception 'Unauthorized' using errcode='42501'; end if;
  update private.push_deliveries q set status='discarded',last_error='expired_or_no_longer_pending'
  where status='pending' and (
    q.created_at<now()-case when q.kind<>'review_requested' then interval '1 day' else interval '7 days' end
    or not exists(select 1 from public.push_devices d where d.id=q.device_id and d.user_id=q.user_id and d.active)
    or (q.kind in ('new_listing','price_drop') and (not private.buyer_push_allowed(q.user_id,q.listing_id,q.kind) or not exists(select 1 from public.push_devices where id=q.device_id and buyer_alerts)))
    or not private.push_session_active(q.device_id,q.user_id)
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
    'expiration',extract(epoch from q.created_at+case when q.kind<>'review_requested' then interval '1 day' else interval '7 days' end)::bigint
  )),'[]'::jsonb) into result from claimed q join public.push_devices d on d.id=q.device_id;
  return result;
end; $$;

commit;
