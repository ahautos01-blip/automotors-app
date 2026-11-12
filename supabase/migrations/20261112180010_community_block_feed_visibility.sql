-- Restrictive SELECT rule: hidden sellers stay hidden after app restart.
create function private.community_seller_visible(p_seller uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select not exists(select 1 from private.chat_user_blocks b
    where b.blocker_id=(select auth.uid()) and b.blocked_id=p_seller);
$$;
revoke all on function private.community_seller_visible(uuid) from public;
grant execute on function private.community_seller_visible(uuid) to anon,authenticated;
create policy community_blocked_seller_visibility on public.vehicle_listings
as restrictive for select to anon,authenticated
using(private.community_seller_visible(owner_id));

-- Notify the existing private moderation inbox when a new block is created.
-- No automated suspension: a moderator reviews the evidence first.
create function private.notify_block_for_review()
returns trigger language plpgsql security definer set search_path='' as $$
declare conversation bigint;
begin
  select id into conversation from public.chat_conversations
    where (buyer_id=new.blocker_id and seller_id=new.blocked_id)
       or (seller_id=new.blocker_id and buyer_id=new.blocked_id)
    order by id desc limit 1;
  if conversation is not null then
    insert into private.chat_reports(reporter_id,reported_id,conversation_id,reason,details)
    values(new.blocker_id,new.blocked_id,conversation,'other',
      'Usuario bloqueado. Revisar la conversación y el contenido denunciado en un máximo de 24 horas.')
    on conflict(reporter_id,conversation_id) where status in ('pending','reviewing') do nothing;
  end if;
  return new;
end;
$$;
revoke all on function private.notify_block_for_review() from public,anon,authenticated;
create trigger community_block_review after insert on private.chat_user_blocks
for each row execute function private.notify_block_for_review();

create or replace function private.manage_chat_safety(p_conversation_id bigint,p_action text,p_reason text,p_details text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.chat_conversations; me uuid:=auth.uid(); other_id uuid; created_report uuid; result jsonb;
begin
  if me is null or not private.current_account_active() then raise exception 'Authentication required' using errcode='42501'; end if;
  select * into c from public.chat_conversations where id=p_conversation_id and me in (buyer_id,seller_id);
  if not found then raise exception 'Conversation unavailable' using errcode='42501'; end if;
  other_id:=case when c.buyer_id=me then c.seller_id else c.buyer_id end;
  if p_action not in ('status','block','unblock','report') or p_action is null then raise exception 'Invalid action'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'community-chat:'||least(c.buyer_id::text,c.seller_id::text)||':'||greatest(c.buyer_id::text,c.seller_id::text),0));
  if p_action='block' then
    insert into private.chat_user_blocks(blocker_id,blocked_id) values(me,other_id) on conflict do nothing;
  elsif p_action='unblock' then
    delete from private.chat_user_blocks where blocker_id=me and blocked_id=other_id;
  elsif p_action='report' then
    if p_reason is null or p_reason not in ('fraud','harassment','inappropriate','spam','other') or char_length(coalesce(p_details,''))>1000 then raise exception 'Invalid report'; end if;
    insert into private.chat_reports(reporter_id,reported_id,conversation_id,reason,details)
      values(me,other_id,p_conversation_id,p_reason,coalesce(p_details,''))
      on conflict(reporter_id,conversation_id) where status in ('pending','reviewing') do nothing returning id into created_report;
  end if;
  result:=jsonb_build_object('blocked_by_me',exists(select 1 from private.chat_user_blocks where blocker_id=me and blocked_id=other_id),
    'messaging_allowed',private.chat_pair_allowed(c.buyer_id,c.seller_id));
  if p_action in ('block','unblock') then result:=result||jsonb_build_object('other_user_id',other_id,'viewer_id',me); end if;
  if p_action='report' then result:=result||jsonb_build_object('report_created',created_report is not null); end if;
  return result;
end;
$$;
