-- Disambiguate the history table alias from the proposal record variable.
create or replace function private.chat_market_action(p_conversation bigint,p_action text,p_id uuid,p_kind text,p_amount numeric,p_scheduled timestamptz,p_place text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c public.chat_conversations; a public.chat_market_activities; v public.vehicle_listings; result jsonb;
begin
 select * into c from public.chat_conversations where id=p_conversation;
 if c.id is null or not private.chat_pair_allowed(c.buyer_id,c.seller_id)
 or not exists(select 1 from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id' and (not_after is null or not_after>now())) then raise exception 'Conversation unavailable' using errcode='42501';end if;
 if p_action='list' then
  select coalesce(jsonb_agg(to_jsonb(q)),'[]') into result from(
   select history_item.*,case when history_item.status='pending' and history_item.expires_at<now() then 'expired' else history_item.status end display_status
   from public.chat_market_activities history_item where history_item.conversation_id=c.id order by history_item.created_at desc,history_item.id desc limit 100)q;
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
