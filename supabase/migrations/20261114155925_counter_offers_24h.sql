begin;
alter table public.chat_market_activities add column reply_to uuid references public.chat_market_activities(id) on delete set null;
create index chat_market_reply_to_idx on public.chat_market_activities(reply_to) where reply_to is not null;
alter table public.chat_market_activities drop constraint chat_market_activities_status_check;
alter table public.chat_market_activities add constraint chat_market_activities_status_check check(status in ('pending','accepted','rejected','cancelled','expired','countered'));
create or replace function private.chat_market_action(p_conversation bigint,p_action text,p_id uuid,p_kind text,p_amount numeric,p_scheduled timestamptz,p_place text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c public.chat_conversations; a public.chat_market_activities; v public.vehicle_listings; result jsonb;
begin
 select * into c from public.chat_conversations where id=p_conversation;
 if c.id is null or not private.chat_pair_allowed(c.buyer_id,c.seller_id)
 or not exists(select 1 from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id' and (not_after is null or not_after>now())) then raise exception 'Conversation unavailable' using errcode='42501';end if;
 if p_action='list' then
  select coalesce(jsonb_agg(to_jsonb(q)),'[]') into result from(
   select history_item.*,case when history_item.status='pending' and history_item.expires_at<=now() then 'expired' else history_item.status end display_status
   from public.chat_market_activities history_item where history_item.conversation_id=c.id order by history_item.created_at desc,history_item.id desc limit 100)q;
  return result;
 end if;
 select * into v from public.vehicle_listings where id=c.listing_id;
 if p_action='counter' then
  perform pg_advisory_xact_lock(c.id);
  select * into a from public.chat_market_activities where id=p_id and conversation_id=c.id for update;
  if a.id is null or a.kind<>'offer' or a.creator_id=auth.uid() or a.status<>'pending' or a.expires_at<=now() then raise exception 'Cannot counter this offer';end if;
  if v.status not in ('published','reserved') or not private.listing_not_held(v.id) then raise exception 'Listing unavailable';end if;
  if p_amount is null or p_amount<=0 or p_amount>100000000 or p_amount<>round(p_amount,2) or p_amount=a.amount then raise exception 'Invalid counter offer';end if;
  if (select count(*) from public.chat_market_activities where creator_id=auth.uid() and created_at>now()-interval '1 day')>=20 then raise exception 'Daily proposal limit';end if;
  update public.chat_market_activities set status='countered',updated_at=now() where id=a.id;
  insert into public.chat_market_activities(conversation_id,creator_id,kind,amount,expires_at,reply_to)
   values(c.id,auth.uid(),'offer',p_amount,now()+interval '24 hours',a.id) returning * into a;
 elsif p_action='create' then
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
   case when p_kind='visit' then p_scheduled else now()+interval '24 hours' end) returning * into a;
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

create or replace function private.queue_market_activity()returns trigger language plpgsql security definer set search_path='' as $$
declare c public.chat_conversations; recipient uuid;
begin
 if new.status in ('expired','countered') then return new;end if;
 if TG_OP='UPDATE' and old.status=new.status then return new;end if;
 if new.kind='offer' then
  insert into public.chat_messages(conversation_id,sender_id,body)
  values(new.conversation_id,case when TG_OP='INSERT' then new.creator_id else auth.uid() end,
   case new.status when 'pending' then case when new.reply_to is null then 'Oferta de compra: ' else 'Contraoferta: ' end when 'accepted' then 'Oferta aceptada: '
    when 'rejected' then 'Oferta rechazada: ' else 'Oferta cancelada: ' end
   ||replace(to_char(new.amount,'FM999999990.00'),'.',',')||case when new.status='pending' then ' €. Válida durante 24 horas desde su envío.' else ' €.' end||' Abre «Ofertas y citas» para consultar la propuesta.');
  return new;
 end if;
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


-- Accept the new app build without changing access or collected fields.
create or replace function private.record_client_error(p_category text,p_code text,p_build integer) returns void language plpgsql security definer set search_path='' as $$
begin
 if not private.current_account_active() or not exists(select 1 from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id' and(not_after is null or not_after>now())) then raise exception 'Sign in required' using errcode='42501';end if;
 if p_category not in ('app','catalogue','publication','photo','chat','purchase') or p_code not in ('network','permission','unavailable','unknown') or (p_build is null or p_build not in (40,41,42,43)) then raise exception 'Invalid diagnostic category';end if;
 insert into private.client_error_totals(day,category,code,app_build)values((now() at time zone 'UTC')::date,p_category,p_code,p_build)
 on conflict(day,category,code,app_build)do update set occurrences=private.client_error_totals.occurrences+1,last_seen=now() where private.client_error_totals.last_seen<now()-interval '15 seconds';
 delete from private.client_error_totals where day<current_date-30;
end;$$;

-- Pending offers also have a maximum validity of 24 hours from their original creation.
update public.chat_market_activities set expires_at=least(expires_at,created_at+interval '24 hours') where kind='offer' and status='pending';
update public.chat_market_activities set status='expired',updated_at=now() where kind='offer' and status='pending' and expires_at<=now();
commit;
