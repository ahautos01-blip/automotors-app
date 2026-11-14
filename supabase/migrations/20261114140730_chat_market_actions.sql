begin;
create table public.chat_market_activities(
 id uuid primary key default gen_random_uuid(),conversation_id bigint not null references public.chat_conversations(id) on delete cascade,
 creator_id uuid not null references auth.users(id) on delete cascade,kind text not null check(kind in ('offer','visit')),
 amount numeric(12,2),scheduled_at timestamptz,meeting_place text,
 status text not null default 'pending' check(status in ('pending','accepted','rejected','cancelled','expired')),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),expires_at timestamptz not null,
 check((kind='offer' and amount is not null and amount>0 and amount<=100000000 and scheduled_at is null and meeting_place is null)
 or(kind='visit' and amount is null and scheduled_at is not null and meeting_place is not null and length(meeting_place) between 3 and 120))
);
create index chat_market_activity_history on public.chat_market_activities(conversation_id,created_at desc);
create unique index chat_market_activity_pending on public.chat_market_activities(conversation_id,kind) where status='pending';
alter table public.chat_market_activities enable row level security;
revoke all on public.chat_market_activities from public,anon,authenticated;
grant select on public.chat_market_activities to authenticated,service_role;
create policy participants_read_market_activities on public.chat_market_activities for select to authenticated using(
 private.metrics_actor_active()
 and exists(select 1 from public.chat_conversations c where c.id=conversation_id and private.chat_pair_allowed(c.buyer_id,c.seller_id)));

create function private.chat_market_action(p_conversation bigint,p_action text,p_id uuid,p_kind text,p_amount numeric,p_scheduled timestamptz,p_place text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c public.chat_conversations; a public.chat_market_activities; v public.vehicle_listings; result jsonb;
begin
 select * into c from public.chat_conversations where id=p_conversation;
 if c.id is null or not private.chat_pair_allowed(c.buyer_id,c.seller_id)
 or not exists(select 1 from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id' and (not_after is null or not_after>now())) then raise exception 'Conversation unavailable' using errcode='42501';end if;
 if p_action='list' then
  select coalesce(jsonb_agg(to_jsonb(q)),'[]') into result from(
   select a.*,case when a.status='pending' and a.expires_at<now() then 'expired' else a.status end display_status
   from public.chat_market_activities a where conversation_id=c.id order by created_at desc,id desc limit 100)q;
  return result;
 end if;
 select * into v from public.vehicle_listings where id=c.listing_id;
 if p_action='create' then
  if v.status not in ('published','reserved') or not private.listing_not_held(v.id) then raise exception 'Listing unavailable';end if;
  if p_kind='offer' and (auth.uid()<>c.buyer_id or p_amount is null or p_amount<=0 or p_amount>100000000 or p_amount<>round(p_amount,2)) then raise exception 'Invalid offer';end if;
  if p_kind='visit' and (p_scheduled is null or p_scheduled<now()+interval '15 minutes' or p_scheduled>now()+interval '90 days' or length(trim(coalesce(p_place,''))) not between 3 and 120) then raise exception 'Invalid visit';end if;
  if p_kind not in ('offer','visit') or p_kind is null then raise exception 'Invalid activity';end if;
  perform pg_advisory_xact_lock(c.id);
  update public.chat_market_activities set status='expired',updated_at=now() where conversation_id=c.id and status='pending' and expires_at<now();
  if exists(select 1 from public.chat_market_activities where conversation_id=c.id and kind=p_kind and status='pending') then raise exception 'Respond to the pending proposal first';end if;
  if (select count(*) from public.chat_market_activities where creator_id=auth.uid() and created_at>now()-interval '1 day')>=20 then raise exception 'Daily proposal limit';end if;
  insert into public.chat_market_activities(conversation_id,creator_id,kind,amount,scheduled_at,meeting_place,expires_at)
  values(c.id,auth.uid(),p_kind,case when p_kind='offer' then p_amount end,case when p_kind='visit' then p_scheduled end,case when p_kind='visit' then trim(p_place) end,
   case when p_kind='visit' then p_scheduled else now()+interval '7 days' end) returning * into a;
 elsif p_action in ('accept','reject','cancel') then
  select * into a from public.chat_market_activities where id=p_id and conversation_id=c.id for update;
  if a.id is null then raise exception 'Proposal unavailable';end if;
  if p_action='cancel' then
   if a.status not in ('pending','accepted') or(a.kind='offer' and a.creator_id<>auth.uid()) then raise exception 'Cannot cancel';end if;
   update public.chat_market_activities set status='cancelled',updated_at=now() where id=a.id returning * into a;
  else
   if a.creator_id=auth.uid() or a.status<>'pending' or a.expires_at<=now() or v.status not in ('published','reserved') or not private.listing_not_held(v.id) then raise exception 'Cannot respond';end if;
   update public.chat_market_activities set status=case when p_action='accept' then 'accepted' else 'rejected' end,updated_at=now() where id=a.id returning * into a;
  end if;
 else raise exception 'Invalid action';end if;
 return to_jsonb(a);
end;$$;
revoke all on function private.chat_market_action(bigint,text,uuid,text,numeric,timestamptz,text) from public,anon;
grant execute on function private.chat_market_action(bigint,text,uuid,text,numeric,timestamptz,text) to authenticated;
create function public.chat_market_action(p_conversation bigint,p_action text,p_id uuid default null,p_kind text default null,p_amount numeric default null,p_scheduled timestamptz default null,p_place text default null) returns jsonb language sql security invoker set search_path='' as $$select private.chat_market_action(p_conversation,p_action,p_id,p_kind,p_amount,p_scheduled,p_place);$$;
revoke all on function public.chat_market_action(bigint,text,uuid,text,numeric,timestamptz,text) from public,anon;
grant execute on function public.chat_market_action(bigint,text,uuid,text,numeric,timestamptz,text) to authenticated;

-- Case-scoped moderation includes the new user-generated meeting text.
create function private.community_report_activities(p_report uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare conversation bigint;result jsonb;begin
 if not private.is_community_moderator()then raise exception 'Moderator required' using errcode='42501';end if;
 select conversation_id into conversation from private.chat_reports where id=p_report;if conversation is null then raise exception 'Report unavailable';end if;
 select coalesce(jsonb_agg(to_jsonb(q)),'[]')into result from(select kind,amount,scheduled_at,meeting_place,status,created_at from public.chat_market_activities where conversation_id=conversation order by created_at desc limit 100)q;return result;end;$$;
revoke all on function private.community_report_activities(uuid)from public,anon;grant execute on function private.community_report_activities(uuid)to authenticated;
create function public.community_report_activities(p_report uuid)returns jsonb language sql stable security invoker set search_path='' as $$select private.community_report_activities(p_report);$$;
revoke all on function public.community_report_activities(uuid)from public,anon;grant execute on function public.community_report_activities(uuid)to authenticated;

-- Aggregate diagnostic categories only: no user IDs, messages or exception text.
create table private.client_error_totals(day date not null,category text not null,code text not null,app_build integer not null,occurrences integer not null default 1,last_seen timestamptz not null default now(),primary key(day,category,code,app_build));
alter table private.client_error_totals enable row level security;revoke all on private.client_error_totals from public,anon,authenticated;
create function private.record_client_error(p_category text,p_code text,p_build integer) returns void language plpgsql security definer set search_path='' as $$
begin
 if not private.current_account_active() or not exists(select 1 from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id' and(not_after is null or not_after>now())) then raise exception 'Sign in required' using errcode='42501';end if;
 if p_category not in ('app','catalogue','publication','photo','chat','purchase') or p_code not in ('network','permission','unavailable','unknown') or p_build<>40 then raise exception 'Invalid diagnostic category';end if;
 insert into private.client_error_totals(day,category,code,app_build)values((now() at time zone 'UTC')::date,p_category,p_code,p_build)
 on conflict(day,category,code,app_build)do update set occurrences=private.client_error_totals.occurrences+1,last_seen=now() where private.client_error_totals.last_seen<now()-interval '15 seconds';
 delete from private.client_error_totals where day<current_date-30;
end;$$;
revoke all on function private.record_client_error(text,text,integer) from public,anon;grant execute on function private.record_client_error(text,text,integer) to authenticated;
create function public.record_client_error(p_category text,p_code text,p_build integer)returns void language sql security invoker set search_path='' as $$select private.record_client_error(p_category,p_code,p_build);$$;
revoke all on function public.record_client_error(text,text,integer) from public,anon;grant execute on function public.record_client_error(text,text,integer) to authenticated;
create function private.client_error_summary() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;begin
 if not private.is_community_moderator() then raise exception 'Moderator required' using errcode='42501';end if;
 select coalesce(jsonb_agg(to_jsonb(q)),'[]') into result from(select day,category,code,app_build,occurrences from private.client_error_totals where day>=current_date-7 order by day desc,occurrences desc limit 30)q;return result;end;$$;
revoke all on function private.client_error_summary()from public,anon;grant execute on function private.client_error_summary()to authenticated;
create function public.client_error_summary()returns jsonb language sql stable security invoker set search_path='' as $$select private.client_error_summary();$$;
revoke all on function public.client_error_summary()from public,anon;grant execute on function public.client_error_summary()to authenticated;

create function private.seller_trust_summary(p_seller uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if exists(select 1 from private.account_deletions where user_id=p_seller) or not private.community_subject_active(p_seller) or not private.community_seller_visible(p_seller) or not exists(select 1 from public.public_seller_profile_data where id=p_seller) then return null;end if;
 return jsonb_build_object('email_confirmed',exists(select 1 from auth.users where id=p_seller and email_confirmed_at is not null));
end;$$;
revoke all on function private.seller_trust_summary(uuid)from public;grant execute on function private.seller_trust_summary(uuid)to anon,authenticated;
create function public.seller_trust_summary(p_seller uuid)returns jsonb language sql stable security invoker set search_path='' as $$select private.seller_trust_summary(p_seller);$$;
revoke all on function public.seller_trust_summary(uuid)from public;grant execute on function public.seller_trust_summary(uuid)to anon,authenticated;

alter table public.push_devices add market_actions boolean not null default false;
alter table private.push_deliveries add activity_id uuid references public.chat_market_activities(id) on delete cascade;
create index push_activity_idx on private.push_deliveries(activity_id);
alter table private.push_deliveries drop constraint push_deliveries_kind_check;
alter table private.push_deliveries add constraint push_deliveries_kind_check check(kind in ('chat_message','review_requested','new_listing','price_drop','chat_activity','visit_reminder'));
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
  on conflict(token,environment) do update set user_id=excluded.user_id,session_id=excluded.session_id,active=true,buyer_alerts=false,market_actions=false,updated_at=now()
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


create function private.register_market_push_device(p_token text,p_environment text)returns void language plpgsql security definer set search_path='' as $$
begin perform private.register_buyer_push_device(p_token,p_environment,true);
 update public.push_devices set market_actions=true where token=p_token and environment=p_environment and user_id=auth.uid() and session_id::text=auth.jwt()->>'session_id';end;$$;
revoke all on function private.register_market_push_device(text,text)from public,anon;grant execute on function private.register_market_push_device(text,text)to authenticated;
create function public.register_market_push_device(p_token text,p_environment text)returns void language sql security invoker set search_path='' as $$select private.register_market_push_device(p_token,p_environment);$$;
revoke all on function public.register_market_push_device(text,text)from public,anon;grant execute on function public.register_market_push_device(text,text)to authenticated;

create function private.market_delivery_allowed(p_user uuid,p_activity uuid,p_reminder boolean)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.chat_market_activities a join public.chat_conversations c on c.id=a.conversation_id join public.vehicle_listings v on v.id=c.listing_id
 where a.id=p_activity and p_user in(c.buyer_id,c.seller_id) and v.status in ('published','reserved') and private.listing_not_held(v.id)
 and (not p_reminder or a.kind='visit' and a.status='accepted' and a.scheduled_at>now())
 and not exists(select 1 from private.account_suspensions where user_id in(c.buyer_id,c.seller_id))
 and not exists(select 1 from private.account_deletions where user_id in(c.buyer_id,c.seller_id))
 and not exists(select 1 from private.chat_restrictions where user_id in(c.buyer_id,c.seller_id))
 and not exists(select 1 from private.chat_user_blocks where(blocker_id=c.buyer_id and blocked_id=c.seller_id)or(blocker_id=c.seller_id and blocked_id=c.buyer_id)));
$$;
revoke all on function private.market_delivery_allowed(uuid,uuid,boolean)from public,anon,authenticated;grant execute on function private.market_delivery_allowed(uuid,uuid,boolean)to service_role;
create function private.queue_market_activity()returns trigger language plpgsql security definer set search_path='' as $$
declare c public.chat_conversations; recipient uuid;
begin
 if new.status='expired' then return new;end if;
 select * into c from public.chat_conversations where id=new.conversation_id;
 recipient:=case when auth.uid()=c.buyer_id then c.seller_id else c.buyer_id end;
 insert into private.push_deliveries(device_id,user_id,event_key,kind,listing_id,conversation_id,activity_id)
 select d.id,recipient,'activity:'||new.id||':'||new.status,'chat_activity',c.listing_id,c.id,new.id from public.push_devices d
 where d.user_id=recipient and d.active and d.market_actions and private.market_delivery_allowed(recipient,new.id,false)
 on conflict(device_id,event_key)do nothing;
 if new.kind='visit' and new.status='accepted' then
  insert into private.push_deliveries(device_id,user_id,event_key,kind,listing_id,conversation_id,activity_id,available_at)
  select d.id,d.user_id,'reminder:'||new.id,'visit_reminder',c.listing_id,c.id,new.id,greatest(now()+interval '1 minute',new.scheduled_at-interval '1 hour') from public.push_devices d
  where d.user_id in(c.buyer_id,c.seller_id) and d.active and d.market_actions and private.market_delivery_allowed(d.user_id,new.id,true)
  on conflict(device_id,event_key)do nothing;
 end if;return new;
end;$$;
revoke all on function private.queue_market_activity()from public,anon,authenticated;
create trigger queue_market_activity after insert or update of status on public.chat_market_activities for each row execute function private.queue_market_activity();
create or replace function public.claim_push_deliveries(p_token text) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare result jsonb;
begin
  if not public.authorize_push_worker(p_token) then raise exception 'Unauthorized' using errcode='42501'; end if;
  update private.push_deliveries q set status='discarded',last_error='expired_or_no_longer_pending'
  where status='pending' and (
    (q.kind<>'visit_reminder' and q.created_at<now()-case when q.kind<>'review_requested' then interval '1 day' else interval '7 days' end)
    or not exists(select 1 from public.push_devices d where d.id=q.device_id and d.user_id=q.user_id and d.active)
    or(q.kind in ('chat_activity','visit_reminder') and (not private.market_delivery_allowed(q.user_id,q.activity_id,q.kind='visit_reminder') or not exists(select 1 from public.push_devices where id=q.device_id and market_actions)))
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
    'expiration',extract(epoch from case when q.kind='visit_reminder' then(select scheduled_at from public.chat_market_activities where id=q.activity_id)else q.created_at+case when q.kind<>'review_requested' then interval '1 day' else interval '7 days' end end)::bigint
  )),'[]'::jsonb) into result from claimed q join public.push_devices d on d.id=q.device_id;
  return result;
end; $$;

commit;
