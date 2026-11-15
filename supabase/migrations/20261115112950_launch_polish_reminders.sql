begin;
alter table public.push_devices add column offer_reminders boolean not null default false;
create index chat_pending_offer_expiry_idx on public.chat_market_activities(expires_at) where kind='offer' and status='pending';
alter table private.push_deliveries drop constraint push_deliveries_kind_check;
alter table private.push_deliveries add constraint push_deliveries_kind_check check(kind in ('chat_message','review_requested','new_listing','price_drop','chat_activity','visit_reminder','offer_reminder'));
create function private.offer_reminder_allowed(p_user uuid,p_activity uuid)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.chat_market_activities a join public.chat_conversations c on c.id=a.conversation_id
 where a.id=p_activity and a.kind='offer' and a.status='pending' and a.expires_at>now()
 and p_user<>a.creator_id and p_user in(c.buyer_id,c.seller_id)
 and private.market_delivery_allowed(p_user,p_activity,false));
$$;
revoke all on function private.offer_reminder_allowed(uuid,uuid)from public,anon,authenticated;
grant execute on function private.offer_reminder_allowed(uuid,uuid)to service_role;
create function private.queue_offer_expiry_reminders()returns void language sql security definer set search_path='' as $$
 insert into private.push_deliveries(device_id,user_id,event_key,kind,listing_id,conversation_id,activity_id)
 select d.id,d.user_id,'offer-expiry:'||a.id,'offer_reminder',c.listing_id,c.id,a.id
 from public.chat_market_activities a join public.chat_conversations c on c.id=a.conversation_id
 join public.push_devices d on d.user_id in(c.buyer_id,c.seller_id)
 where a.kind='offer' and a.status='pending' and a.expires_at>now() and a.expires_at<=now()+interval '2 hours'
 and d.active and d.offer_reminders and private.push_session_active(d.id,d.user_id)
 and private.offer_reminder_allowed(d.user_id,a.id)
 on conflict(device_id,event_key)do nothing;
$$;
revoke all on function private.queue_offer_expiry_reminders()from public,anon,authenticated;
grant execute on function private.queue_offer_expiry_reminders()to service_role;
create function private.register_launch_push_device(p_token text,p_environment text)returns void language plpgsql security definer set search_path='' as $$
begin perform private.register_market_push_device(p_token,p_environment);
 update public.push_devices set offer_reminders=true where token=p_token and environment=p_environment and user_id=auth.uid() and session_id::text=auth.jwt()->>'session_id';end;$$;
revoke all on function private.register_launch_push_device(text,text)from public,anon;
grant execute on function private.register_launch_push_device(text,text)to authenticated;
create function public.register_launch_push_device(p_token text,p_environment text)returns void language sql security invoker set search_path='' as $$select private.register_launch_push_device(p_token,p_environment);$$;
revoke all on function public.register_launch_push_device(text,text)from public,anon;
grant execute on function public.register_launch_push_device(text,text)to authenticated;

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
  on conflict(token,environment) do update set user_id=excluded.user_id,session_id=excluded.session_id,active=true,buyer_alerts=false,market_actions=false,offer_reminders=false,updated_at=now()
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
create or replace function public.claim_push_deliveries(p_token text) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare result jsonb;
begin
  if not public.authorize_push_worker(p_token) then raise exception 'Unauthorized' using errcode='42501'; end if;
  perform private.queue_offer_expiry_reminders();
  update private.push_deliveries q set status='discarded',last_error='expired_or_no_longer_pending'
  where status='pending' and (
    (q.kind<>'visit_reminder' and q.created_at<now()-case when q.kind<>'review_requested' then interval '1 day' else interval '7 days' end)
    or not exists(select 1 from public.push_devices d where d.id=q.device_id and d.user_id=q.user_id and d.active)
    or(q.kind in ('chat_activity','visit_reminder') and (not private.market_delivery_allowed(q.user_id,q.activity_id,q.kind='visit_reminder') or not exists(select 1 from public.push_devices where id=q.device_id and market_actions)))
    or (q.kind in ('new_listing','price_drop') and (not private.buyer_push_allowed(q.user_id,q.listing_id,q.kind) or not exists(select 1 from public.push_devices where id=q.device_id and buyer_alerts)))
    or(q.kind='offer_reminder' and (not private.offer_reminder_allowed(q.user_id,q.activity_id) or not exists(select 1 from public.push_devices where id=q.device_id and offer_reminders)))
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
    'expiration',extract(epoch from case when q.kind='offer_reminder' then(select expires_at from public.chat_market_activities where id=q.activity_id)when q.kind='visit_reminder' then(select scheduled_at from public.chat_market_activities where id=q.activity_id)else q.created_at+case when q.kind<>'review_requested' then interval '1 day' else interval '7 days' end end)::bigint
  )),'[]'::jsonb) into result from claimed q join public.push_devices d on d.id=q.device_id;
  return result;
end; $$;

-- Accept the new app build without changing access or collected fields.
create or replace function private.record_client_error(p_category text,p_code text,p_build integer) returns void language plpgsql security definer set search_path='' as $$
begin
 if not private.current_account_active() or not exists(select 1 from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id' and(not_after is null or not_after>now())) then raise exception 'Sign in required' using errcode='42501';end if;
 if p_category not in ('app','catalogue','publication','photo','chat','purchase') or p_code not in ('network','permission','unavailable','unknown') or (p_build is null or p_build not in (40,41,42,43,44)) then raise exception 'Invalid diagnostic category';end if;
 insert into private.client_error_totals(day,category,code,app_build)values((now() at time zone 'UTC')::date,p_category,p_code,p_build)
 on conflict(day,category,code,app_build)do update set occurrences=private.client_error_totals.occurrences+1,last_seen=now() where private.client_error_totals.last_seen<now()-interval '15 seconds';
 delete from private.client_error_totals where day<current_date-30;
end;$$;

commit;
