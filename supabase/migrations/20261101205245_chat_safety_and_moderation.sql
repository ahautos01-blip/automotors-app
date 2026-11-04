-- Private safety data: no direct Data API table access.
create table private.chat_user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(blocker_id,blocked_id), check(blocker_id<>blocked_id)
);
create table private.community_moderators (
  user_id uuid primary key references auth.users(id) on delete cascade
);
create table private.chat_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reported_id uuid not null references auth.users(id) on delete cascade,
  conversation_id bigint not null references public.chat_conversations(id) on delete cascade,
  reason text not null check(reason in ('fraud','harassment','inappropriate','spam','other')),
  details text not null default '' check(char_length(details)<=1000),
  status text not null default 'pending' check(status in ('pending','reviewing','resolved','dismissed')),
  created_at timestamptz not null default now(), check(reporter_id<>reported_id)
);
create unique index one_open_chat_report on private.chat_reports(reporter_id,conversation_id)
  where status in ('pending','reviewing');
create index chat_reports_queue on private.chat_reports(created_at desc,id desc);
create table private.chat_restrictions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table private.listing_moderation_holds (
  listing_id uuid primary key references public.vehicle_listings(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table private.community_review_audit (
  id uuid primary key default gen_random_uuid(),
  chat_report_id uuid references private.chat_reports(id) on delete cascade,
  listing_report_id uuid references public.vehicle_listing_reports(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null check(action in ('reviewing','resolve','dismiss','hide_listing','restore_listing','restrict_chat','restore_chat')),
  note text not null default '' check(char_length(note)<=1000),
  created_at timestamptz not null default now(),
  check((chat_report_id is null)<>(listing_report_id is null))
);
do $$ declare name text; begin
  foreach name in array array['chat_user_blocks','community_moderators','chat_reports','chat_restrictions','listing_moderation_holds','community_review_audit'] loop
    execute format('alter table private.%I enable row level security',name);
    execute format('revoke all on private.%I from public,anon,authenticated',name);
  end loop;
end $$;

create function private.is_community_moderator()
returns boolean language sql stable security definer set search_path='' as $$
  select (select auth.uid()) is not null and private.current_account_active()
    and exists(select 1 from private.community_moderators m where m.user_id=(select auth.uid()))
    and exists(select 1 from auth.sessions s where s.user_id=(select auth.uid())
      and s.id::text=(select auth.jwt()->>'session_id') and (s.not_after is null or s.not_after>now()));
$$;
revoke all on function private.is_community_moderator() from public,anon;
grant execute on function private.is_community_moderator() to authenticated;

create function private.chat_pair_allowed(p_buyer uuid,p_seller uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select (select auth.uid()) in (p_buyer,p_seller) and p_buyer<>p_seller
    and private.current_account_active()
    and (select count(*) from auth.users where id in (p_buyer,p_seller))=2
    and not exists(select 1 from private.account_deletions where user_id in (p_buyer,p_seller))
    and not exists(select 1 from private.chat_restrictions where user_id in (p_buyer,p_seller))
    and not exists(select 1 from private.chat_user_blocks where
      (blocker_id=p_buyer and blocked_id=p_seller) or (blocker_id=p_seller and blocked_id=p_buyer));
$$;
revoke all on function private.chat_pair_allowed(uuid,uuid) from public,anon;
grant execute on function private.chat_pair_allowed(uuid,uuid) to authenticated;

create function private.listing_not_held(p_listing uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select not exists(select 1 from private.listing_moderation_holds where listing_id=p_listing);
$$;
revoke all on function private.listing_not_held(uuid) from public;
grant execute on function private.listing_not_held(uuid) to anon,authenticated;
create policy moderation_listing_visibility on public.vehicle_listings as restrictive for select to anon,authenticated
using (private.listing_not_held(id) or owner_id=(select auth.uid()));
create policy moderation_listing_update on public.vehicle_listings as restrictive for update to authenticated
using (true) with check(private.listing_not_held(id));

create function private.valid_chat_listing(p_listing uuid,p_buyer uuid,p_seller uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select (select auth.uid())=p_buyer and private.chat_pair_allowed(p_buyer,p_seller)
    and exists(select 1 from public.vehicle_listings v where v.id=p_listing
      and v.owner_id=p_seller and v.status in ('published','reserved'))
    and private.listing_not_held(p_listing);
$$;
revoke all on function private.valid_chat_listing(uuid,uuid,uuid) from public,anon;
grant execute on function private.valid_chat_listing(uuid,uuid,uuid) to authenticated;
create policy valid_listing_and_chat_pair on public.chat_conversations as restrictive for insert to authenticated
with check(private.valid_chat_listing(listing_id,buyer_id,seller_id));

-- Serialize sends and blocks for a pair; no last-second send after block commits.
create function private.guard_chat_send()
returns trigger language plpgsql security invoker set search_path='' as $$
declare c public.chat_conversations;
begin
  if current_user not in ('anon','authenticated') then return new; end if;
  select * into c from public.chat_conversations where id=new.conversation_id;
  if not found or new.sender_id is distinct from auth.uid() then
    raise exception 'CHAT_UNAVAILABLE' using errcode='42501';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'community-chat:'||least(c.buyer_id::text,c.seller_id::text)||':'||greatest(c.buyer_id::text,c.seller_id::text),0));
  if not private.chat_pair_allowed(c.buyer_id,c.seller_id) then
    raise exception 'CHAT_UNAVAILABLE' using errcode='42501';
  end if;
  return new;
end;
$$;
revoke all on function private.guard_chat_send() from public,anon,authenticated;
revoke insert on public.chat_messages from authenticated;
grant insert(conversation_id,sender_id,body) on public.chat_messages to authenticated;
create trigger guard_chat_send before insert on public.chat_messages
for each row execute function private.guard_chat_send();

create function private.manage_chat_safety(p_conversation_id bigint,p_action text,p_reason text,p_details text)
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
  if p_action='report' then result:=result||jsonb_build_object('report_created',created_report is not null); end if;
  return result;
end;
$$;
revoke all on function private.manage_chat_safety(bigint,text,text,text) from public,anon;
grant execute on function private.manage_chat_safety(bigint,text,text,text) to authenticated;
create function public.community_chat_safety(p_conversation_id bigint,p_action text default 'status',p_reason text default null,p_details text default null)
returns jsonb language sql security invoker set search_path='' as $$
  select private.manage_chat_safety(p_conversation_id,p_action,p_reason,p_details);
$$;
revoke all on function public.community_chat_safety(bigint,text,text,text) from public,anon;
grant execute on function public.community_chat_safety(bigint,text,text,text) to authenticated;
create function public.community_moderation_access()
returns boolean language sql stable security invoker set search_path='' as $$ select private.is_community_moderator(); $$;
revoke all on function public.community_moderation_access() from public,anon;
grant execute on function public.community_moderation_access() to authenticated;

create function private.community_reports(p_before_created timestamptz,p_before_id uuid,p_before_kind text,p_include_closed boolean)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
  if not private.is_community_moderator() then raise exception 'Moderator required' using errcode='42501'; end if;
  if (p_before_created is not null or p_before_id is not null or p_before_kind is not null) and (p_before_created is null or p_before_id is null or p_before_kind is null or p_before_kind not in ('chat','listing')) then raise exception 'Invalid cursor'; end if;
  select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at desc,q.id desc,q.kind desc),'[]'::jsonb) into result from (
    select * from (
      select id,'chat'::text kind,reason,details,status,created_at from private.chat_reports
      union all
      select id,'listing'::text kind,reason,details,status,created_at from public.vehicle_listing_reports
    ) all_reports where (p_include_closed or status in ('pending','reviewing'))
      and (p_before_created is null or (created_at,id,kind)<(p_before_created,p_before_id,p_before_kind))
    order by created_at desc,id desc,kind desc limit 50
  ) q;
  return result;
end;
$$;
revoke all on function private.community_reports(timestamptz,uuid,text,boolean) from public,anon;
grant execute on function private.community_reports(timestamptz,uuid,text,boolean) to authenticated;
create function public.community_reports(p_before_created timestamptz default null,p_before_id uuid default null,p_before_kind text default null,p_include_closed boolean default false)
returns jsonb language sql stable security invoker set search_path='' as $$
  select private.community_reports(p_before_created,p_before_id,p_before_kind,p_include_closed);
$$;
revoke all on function public.community_reports(timestamptz,uuid,text,boolean) from public,anon;
grant execute on function public.community_reports(timestamptz,uuid,text,boolean) to authenticated;

create function private.community_report_messages(p_report_id uuid,p_before_id bigint)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare r private.chat_reports; result jsonb;
begin
  if not private.is_community_moderator() then raise exception 'Moderator required' using errcode='42501'; end if;
  select * into r from private.chat_reports where id=p_report_id;
  if not found then raise exception 'Report unavailable'; end if;
  select coalesce(jsonb_agg(to_jsonb(m) order by m.id),'[]'::jsonb) into result from (
    select id,body,created_at,case when sender_id=r.reporter_id then 'reporter' else 'reported' end sender_role
    from public.chat_messages where conversation_id=r.conversation_id and (p_before_id is null or id<p_before_id)
    order by id desc limit 50
  ) m;
  return result;
end;
$$;
revoke all on function private.community_report_messages(uuid,bigint) from public,anon;
grant execute on function private.community_report_messages(uuid,bigint) to authenticated;
create function public.community_report_messages(p_report_id uuid,p_before_id bigint default null)
returns jsonb language sql stable security invoker set search_path='' as $$ select private.community_report_messages(p_report_id,p_before_id); $$;
revoke all on function public.community_report_messages(uuid,bigint) from public,anon;
grant execute on function public.community_report_messages(uuid,bigint) to authenticated;

create function private.community_report_detail(p_kind text,p_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb; report_row record; listing_row record; messages jsonb;
begin
  if not private.is_community_moderator() then raise exception 'Moderator required' using errcode='42501'; end if;
  if p_kind='chat' then
    select * into report_row from private.chat_reports where id=p_id;
    if not found then raise exception 'Report unavailable'; end if;
    messages:=private.community_report_messages(report_row.id,null);
    result:=jsonb_build_object('id',report_row.id,'kind','chat','reason',report_row.reason,'details',report_row.details,'status',report_row.status,
      'created_at',report_row.created_at,'messages',messages,'chat_restricted',exists(select 1 from private.chat_restrictions where user_id=report_row.reported_id));
  elsif p_kind='listing' then
    select * into report_row from public.vehicle_listing_reports where id=p_id;
    if not found then raise exception 'Report unavailable'; end if;
    select * into listing_row from public.vehicle_listings where id=report_row.listing_id;
    result:=jsonb_build_object('id',report_row.id,'kind','listing','reason',report_row.reason,'details',report_row.details,'status',report_row.status,
      'created_at',report_row.created_at,'listing',jsonb_build_object('year',listing_row.year,'version',listing_row.version,'description',listing_row.description,'price',listing_row.price),
      'photos',coalesce((select jsonb_agg(q.storage_path order by q.position) from (select storage_path,position from public.vehicle_photos where listing_id=report_row.listing_id order by position,id limit 20) q),'[]'::jsonb),
      'listing_held',not private.listing_not_held(report_row.listing_id),
      'chat_restricted',exists(select 1 from private.chat_restrictions where user_id=listing_row.owner_id));
  else raise exception 'Invalid report kind'; end if;
  return result||jsonb_build_object('history',coalesce((select jsonb_agg(to_jsonb(a) order by a.created_at desc) from (
    select action,note,created_at from private.community_review_audit
    where (p_kind='chat' and chat_report_id=p_id) or (p_kind='listing' and listing_report_id=p_id)
    order by created_at desc,id desc limit 20
  ) a),'[]'::jsonb));
end;
$$;
revoke all on function private.community_report_detail(text,uuid) from public,anon;
grant execute on function private.community_report_detail(text,uuid) to authenticated;
create function public.community_report_detail(p_kind text,p_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$ select private.community_report_detail(p_kind,p_id); $$;
revoke all on function public.community_report_detail(text,uuid) from public,anon;
grant execute on function public.community_report_detail(text,uuid) to authenticated;

create function private.community_review_report(p_kind text,p_id uuid,p_action text,p_note text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare target_user uuid; target_listing uuid; new_status text;
begin
  if not private.is_community_moderator() then raise exception 'Moderator required' using errcode='42501'; end if;
  if char_length(coalesce(p_note,''))>1000 or p_action is null or p_action not in
    ('reviewing','resolve','dismiss','hide_listing','restore_listing','restrict_chat','restore_chat') then raise exception 'Invalid review action'; end if;
  if p_kind='chat' then
    select reported_id into target_user from private.chat_reports where id=p_id for update;
    if not found then raise exception 'Report unavailable'; end if;
  elsif p_kind='listing' then
    select r.listing_id,v.owner_id into target_listing,target_user from public.vehicle_listing_reports r
      join public.vehicle_listings v on v.id=r.listing_id where r.id=p_id for update of r;
    if not found then raise exception 'Report unavailable'; end if;
  else raise exception 'Invalid report kind'; end if;
  new_status:=case when p_action='reviewing' then 'reviewing' when p_action='dismiss' then 'dismissed' else 'resolved' end;
  if p_action in ('hide_listing','restore_listing') then
    if target_listing is null then raise exception 'Listing action requires listing report'; end if;
    if p_action='hide_listing' then insert into private.listing_moderation_holds(listing_id) values(target_listing) on conflict do nothing;
    else delete from private.listing_moderation_holds where listing_id=target_listing; end if;
  elsif p_action in ('restrict_chat','restore_chat') then
    if target_user is null then raise exception 'User unavailable'; end if;
    if p_action='restrict_chat' then insert into private.chat_restrictions(user_id) values(target_user) on conflict do nothing;
    else delete from private.chat_restrictions where user_id=target_user; end if;
  end if;
  if p_kind='chat' then update private.chat_reports set status=new_status where id=p_id;
  else update public.vehicle_listing_reports set status=new_status where id=p_id; end if;
  insert into private.community_review_audit(chat_report_id,listing_report_id,actor_id,action,note)
    values(case when p_kind='chat' then p_id end,case when p_kind='listing' then p_id end,auth.uid(),p_action,coalesce(p_note,''));
  return private.community_report_detail(p_kind,p_id);
end;
$$;
revoke all on function private.community_review_report(text,uuid,text,text) from public,anon;
grant execute on function private.community_review_report(text,uuid,text,text) to authenticated;
create function public.community_review_report(p_kind text,p_id uuid,p_action text,p_note text default '')
returns jsonb language sql security invoker set search_path='' as $$ select private.community_review_report(p_kind,p_id,p_action,p_note); $$;
revoke all on function public.community_review_report(text,uuid,text,text) from public,anon;
grant execute on function public.community_review_report(text,uuid,text,text) to authenticated;
