-- Suspension markers are private. Only a case-scoped moderator action writes them.
create table private.account_suspensions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  note text not null check(char_length(note) between 1 and 1000)
);
alter table private.account_suspensions enable row level security;
revoke all on private.account_suspensions from public,anon,authenticated;

create or replace function private.current_account_active()
returns boolean language sql stable security definer set search_path='' as $$
  select (select auth.uid()) is not null
    and exists(select 1 from auth.users where id=(select auth.uid()))
    and not exists(select 1 from private.account_deletions where user_id=(select auth.uid()))
    and not exists(select 1 from private.account_suspensions where user_id=(select auth.uid()));
$$;

create function private.community_subject_active(p_user uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select not exists(select 1 from private.account_suspensions where user_id=p_user);
$$;
revoke all on function private.community_subject_active(uuid) from public;
grant execute on function private.community_subject_active(uuid) to anon,authenticated;
create policy community_suspended_seller_visibility on public.vehicle_listings
as restrictive for select to anon,authenticated using(private.community_subject_active(owner_id));
create policy community_suspended_profile_visibility on public.public_seller_profile_data
as restrictive for select to anon,authenticated using(private.community_subject_active(id));
create policy community_suspended_about_visibility on public.seller_about_profiles
as restrictive for select to anon,authenticated using(private.community_subject_active(user_id));
create policy community_suspended_review_visibility on public.vehicle_reviews
as restrictive for select to anon,authenticated using(private.community_subject_active(buyer_id));

create function private.current_community_account_status()
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('active',private.current_account_active(),
    'suspended',(select auth.uid()) is not null and exists(
      select 1 from private.account_suspensions where user_id=(select auth.uid())));
$$;
revoke all on function private.current_community_account_status() from public,anon;
grant execute on function private.current_community_account_status() to authenticated;
create function public.community_account_status()
returns jsonb language sql stable security invoker set search_path='' as $$
  select private.current_community_account_status();
$$;
revoke all on function public.community_account_status() from public,anon;
grant execute on function public.community_account_status() to authenticated;

alter table private.community_review_audit drop constraint community_review_audit_action_check;
alter table private.community_review_audit add constraint community_review_audit_action_check
check(action in ('reviewing','resolve','dismiss','hide_listing','restore_listing','restrict_chat','restore_chat','approve_publication','suspend_account','restore_account'));

create or replace function private.chat_pair_allowed(p_buyer uuid,p_seller uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select (select auth.uid()) in (p_buyer,p_seller) and p_buyer<>p_seller
    and private.current_account_active()
    and (select count(*) from auth.users where id in (p_buyer,p_seller))=2
    and not exists(select 1 from private.account_suspensions where user_id in (p_buyer,p_seller))
    and not exists(select 1 from private.account_deletions where user_id in (p_buyer,p_seller))
    and not exists(select 1 from private.chat_restrictions where user_id in (p_buyer,p_seller))
    and not exists(select 1 from private.chat_user_blocks where
      (blocker_id=p_buyer and blocked_id=p_seller) or (blocker_id=p_seller and blocked_id=p_buyer));
$$;

create or replace function private.community_report_detail(p_kind text,p_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb; report_row record; listing_row record; messages jsonb; subject uuid;
begin
  if not private.is_community_moderator() then raise exception 'Moderator required' using errcode='42501'; end if;
  if p_kind='chat' then
    select * into report_row from private.chat_reports where id=p_id;
    if not found then raise exception 'Report unavailable'; end if;
    subject:=report_row.reported_id;
    messages:=private.community_report_messages(report_row.id,null);
    result:=jsonb_build_object('id',report_row.id,'kind','chat','reason',report_row.reason,'details',report_row.details,'status',report_row.status,
      'created_at',report_row.created_at,'messages',messages,'chat_restricted',exists(select 1 from private.chat_restrictions where user_id=report_row.reported_id));
  elsif p_kind='listing' then
    select * into report_row from public.vehicle_listing_reports where id=p_id;
    if not found then raise exception 'Report unavailable'; end if;
    select * into listing_row from public.vehicle_listings where id=report_row.listing_id;
    subject:=listing_row.owner_id;
    result:=jsonb_build_object('id',report_row.id,'kind','listing','reason',report_row.reason,'details',report_row.details,'status',report_row.status,
      'created_at',report_row.created_at,'listing',jsonb_build_object('year',listing_row.year,'version',listing_row.version,'description',listing_row.description,'price',listing_row.price),
      'photos',coalesce((select jsonb_agg(q.storage_path order by q.position) from (select storage_path,position from public.vehicle_photos where listing_id=report_row.listing_id order by position,id limit 20) q),'[]'::jsonb),
      'automatic_state',(select state from private.listing_content_checks where listing_id=report_row.listing_id),
      'automatic_fingerprint',(select fingerprint from private.listing_content_checks where listing_id=report_row.listing_id),
      'listing_held',not private.listing_not_held(report_row.listing_id),
      'chat_restricted',exists(select 1 from private.chat_restrictions where user_id=listing_row.owner_id));
  else raise exception 'Invalid report kind'; end if;
  result:=result||jsonb_build_object('account_suspended',exists(select 1 from private.account_suspensions where user_id=subject));
  return result||jsonb_build_object('history',coalesce((select jsonb_agg(to_jsonb(a) order by a.created_at desc) from (
    select action,note,created_at from private.community_review_audit
    where (p_kind='chat' and chat_report_id=p_id) or (p_kind='listing' and listing_report_id=p_id)
    order by created_at desc,id desc limit 20
  ) a),'[]'::jsonb));
end;
$$;

create or replace function private.community_review_report(p_kind text,p_id uuid,p_action text,p_note text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare target_user uuid; target_listing uuid; new_status text;
begin
  if not private.is_community_moderator() then raise exception 'Moderator required' using errcode='42501'; end if;
  if char_length(coalesce(p_note,''))>1000 or p_action is null or p_action not in
    ('reviewing','resolve','dismiss','hide_listing','restore_listing','restrict_chat','restore_chat','suspend_account','restore_account') then raise exception 'Invalid review action'; end if;
  if p_kind='chat' then
    select reported_id into target_user from private.chat_reports where id=p_id;
    if not found then raise exception 'Report unavailable'; end if;
  elsif p_kind='listing' then
    select r.listing_id,v.owner_id into target_listing,target_user from public.vehicle_listing_reports r
      join public.vehicle_listings v on v.id=r.listing_id where r.id=p_id;
    if not found then raise exception 'Report unavailable'; end if;
  else raise exception 'Invalid report kind'; end if;
  if p_action in ('suspend_account','restore_account') then
    if target_user is null or char_length(trim(coalesce(p_note,'')))=0 then raise exception 'A reason is required'; end if;
    -- Protect the holder/moderators and serialize suspend/restore operations.
    if target_user=auth.uid() or exists(select 1 from private.community_moderators where user_id=target_user)
      or exists(select 1 from public.user_profiles where id=target_user and is_admin=true) then
      raise exception 'Protected account' using errcode='42501';
    end if;
    perform 1 from auth.users where id=target_user for update;
    if not found then raise exception 'User unavailable'; end if;
  end if;
  -- Lock the subject first, then the report, matching the publication path.
  if p_kind='chat' then perform 1 from private.chat_reports where id=p_id for update;
  else perform 1 from public.vehicle_listing_reports where id=p_id for update; end if;
  if not found then raise exception 'Report unavailable'; end if;
  if p_action in ('suspend_account','restore_account') then
    if p_action='suspend_account' then
      insert into private.account_suspensions(user_id,actor_id,note) values(target_user,auth.uid(),trim(p_note))
      on conflict(user_id) do nothing;
    else delete from private.account_suspensions where user_id=target_user; end if;
  end if;
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

create or replace function public.prepare_listing_content_check(p_user_id uuid,p_session_id uuid,p_listing_id uuid,p_target_status text default 'published')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.vehicle_listings; photos jsonb; fingerprint text; lease uuid:=gen_random_uuid(); text_input text;
begin
 perform 1 from auth.users where id=p_user_id for share;
 if p_target_status not in ('published','reserved') or not exists(select 1 from auth.sessions s where s.id=p_session_id and s.user_id=p_user_id and (s.not_after is null or s.not_after>now()))
   or exists(select 1 from private.account_deletions where user_id=p_user_id) or exists(select 1 from private.account_suspensions where user_id=p_user_id) then raise exception 'Active account required' using errcode='42501'; end if;
 select * into v from public.vehicle_listings where id=p_listing_id and owner_id=p_user_id for update;
 if not found or v.status='sold' or not private.listing_not_held(v.id) then raise exception 'Listing unavailable' using errcode='42501'; end if;
 if exists(select 1 from private.listing_content_checks where listing_id=v.id and state='processing' and lease_until>now()) then raise exception 'MODERATION_BUSY' using errcode='55P03'; end if;
 if (select count(*) from private.content_request_log where user_id=p_user_id and created_at>now()-interval '10 minutes')>=5 then raise exception 'MODERATION_RATE_LIMIT' using errcode='P0001'; end if;
 photos:=private.listing_photo_manifest(v.id);
 if jsonb_array_length(photos) not between 1 and 15 or exists(select 1 from jsonb_array_elements(photos) p
   where p->>'object_id' is null or coalesce((p->'metadata'->>'size')::numeric,0)>20971520 or not starts_with(p->>'path',p_user_id::text||'/'||v.id::text||'/')) then raise exception 'Invalid listing photos' using errcode='22023'; end if;
 update public.vehicle_listings set status='draft' where id=v.id;
 fingerprint:=private.listing_content_hash(to_jsonb(v));
 insert into private.listing_content_checks(listing_id,user_id,state,fingerprint,lease_id,lease_until,target_status)
 values(v.id,p_user_id,'processing',fingerprint,lease,now()+interval '3 minutes',p_target_status)
 on conflict(listing_id) do update set user_id=excluded.user_id,state='processing',fingerprint=excluded.fingerprint,lease_id=excluded.lease_id,
   lease_until=excluded.lease_until,requested_at=now(),target_status=excluded.target_status,error_code=null,categories='[]';
 insert into private.content_request_log(user_id) values(p_user_id);
 delete from private.content_request_log where user_id=p_user_id and created_at<now()-interval '1 day';
 text_input:=(to_jsonb(v)-array['id','owner_id','phone','vin','matricula','created_at','updated_at','sold_at','sold_to_buyer_id','sold_externally','status'])::text;
 if v.show_vin_publicly then text_input:=text_input||coalesce(v.vin,''); end if;
 if v.show_matricula_publicly then text_input:=text_input||coalesce(v.matricula,''); end if;
 return jsonb_build_object('lease_id',lease,'fingerprint',fingerprint,'text',text_input,'photos',photos);
end $$;

create or replace function public.finish_listing_content_check(p_user_id uuid,p_session_id uuid,p_listing_id uuid,p_lease_id uuid,p_outcome text,p_categories jsonb default '[]',p_error_code text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.vehicle_listings; c private.listing_content_checks; report uuid;
begin
 perform 1 from auth.users where id=p_user_id for share;
 if not exists(select 1 from auth.sessions s where s.id=p_session_id and s.user_id=p_user_id and (s.not_after is null or s.not_after>now())) or exists(select 1 from private.account_deletions where user_id=p_user_id) or exists(select 1 from private.account_suspensions where user_id=p_user_id)
   then raise exception 'Active account required' using errcode='42501'; end if;
 select * into v from public.vehicle_listings where id=p_listing_id and owner_id=p_user_id for update;
 if not found then raise exception 'Listing unavailable' using errcode='42501'; end if;
 select * into c from private.listing_content_checks where listing_id=v.id and user_id=p_user_id and lease_id=p_lease_id and state='processing' and lease_until>now() for update;
 if not found then raise exception 'Check expired' using errcode='42501'; end if;
 if p_outcome not in ('approved','rejected','error') or p_outcome is null then raise exception 'Invalid result'; end if;
 if c.fingerprint<>private.listing_content_hash(to_jsonb(v)) then
   update private.listing_content_checks set state='changed',error_code='content_changed' where listing_id=v.id;
   return jsonb_build_object('state','changed','published',false);
 end if;
 update private.listing_content_checks set state=p_outcome,categories=p_categories,error_code=p_error_code where listing_id=v.id;
 if p_outcome='approved' and private.listing_not_held(v.id) then
   begin
     update public.vehicle_listings set status=c.target_status where id=v.id;
   exception when raise_exception then
     update private.listing_content_checks set state='error',error_code='publication_limit' where listing_id=v.id;
     return jsonb_build_object('state','error','error_code','publication_limit','published',false);
   end;
 elsif p_outcome='rejected' then
   select id into report from public.vehicle_listing_reports where listing_id=v.id and reporter_id=p_user_id limit 1;
   if report is null then
     insert into public.vehicle_listing_reports(reporter_id,listing_id,reason,details) values(p_user_id,v.id,'Contenido inapropiado','Revisión del filtro automático solicitada.') returning id into report;
   else update public.vehicle_listing_reports set status='pending' where id=report; end if;
   update private.listing_content_checks set report_id=report where listing_id=v.id;
 end if;
 if p_outcome='approved' and not private.listing_not_held(v.id) then return jsonb_build_object('state','held','published',false,'error_code','listing_restricted'); end if;
 return jsonb_build_object('state',p_outcome,'published',p_outcome='approved' and private.listing_not_held(v.id),'error_code',p_error_code);
end $$;


create or replace function private.approve_listing_after_review(p_report_id uuid,p_expected_fingerprint text,p_note text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.vehicle_listing_reports; v public.vehicle_listings; c private.listing_content_checks;
begin
 if not private.is_community_moderator() then raise exception 'Moderator required' using errcode='42501'; end if;
 if char_length(coalesce(p_note,''))>1000 then raise exception 'Note too long'; end if;
 select * into r from public.vehicle_listing_reports where id=p_report_id;
 if not found then raise exception 'Report unavailable'; end if;
 perform 1 from auth.users where id=(select owner_id from public.vehicle_listings where id=r.listing_id) for share;
 select * into v from public.vehicle_listings where id=r.listing_id for update;
 perform 1 from public.vehicle_listing_reports where id=p_report_id for update;
 select * into c from private.listing_content_checks where listing_id=v.id and report_id=r.id and state in ('rejected','error') for update;
 if not found or v.status='sold' or c.fingerprint is distinct from p_expected_fingerprint or c.fingerprint<>private.listing_content_hash(to_jsonb(v))
   or not private.listing_not_held(v.id) or exists(select 1 from private.account_deletions where user_id=v.owner_id) or exists(select 1 from private.account_suspensions where user_id=v.owner_id) then
   raise exception 'Content changed or listing restricted. Review the current content.' using errcode='42501';
 end if;
 update private.listing_content_checks set state='approved',error_code=null,lease_id=gen_random_uuid() where listing_id=v.id;
 update public.vehicle_listings set status=c.target_status where id=v.id;
 update public.vehicle_listing_reports set status='resolved' where id=r.id;
 insert into private.community_review_audit(listing_report_id,actor_id,action,note) values(r.id,auth.uid(),'approve_publication',coalesce(p_note,''));
 return private.community_report_detail('listing',r.id);
end $$;
