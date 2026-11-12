-- Rollout is disabled until a compatible client is distributed and tested.
create table private.content_moderation_config(singleton boolean primary key default true check(singleton),enabled boolean not null default false,last_probe jsonb);
insert into private.content_moderation_config(singleton) values(true);
create table private.listing_content_checks(
 listing_id uuid primary key references public.vehicle_listings(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 state text not null check(state in ('processing','approved','rejected','error','changed')),
 fingerprint text not null,lease_id uuid not null default gen_random_uuid(),lease_until timestamptz not null,
 requested_at timestamptz not null default now(),target_status text not null default 'published' check(target_status in ('published','reserved')),
 error_code text,categories jsonb not null default '[]',report_id uuid references public.vehicle_listing_reports(id) on delete set null
);
create table private.content_request_log(user_id uuid not null references auth.users(id) on delete cascade,created_at timestamptz not null default now());
create index content_request_log_owner_time on private.content_request_log(user_id,created_at desc);
alter table private.content_moderation_config enable row level security;
alter table private.listing_content_checks enable row level security;
alter table private.content_request_log enable row level security;
revoke all on private.content_moderation_config,private.listing_content_checks,private.content_request_log from public,anon,authenticated;

create function private.content_moderation_enabled() returns boolean language sql stable security definer set search_path='' as $$
 select enabled from private.content_moderation_config where singleton;
$$;
revoke all on function private.content_moderation_enabled() from public;
grant execute on function private.content_moderation_enabled() to anon,authenticated;
create function private.listing_photo_manifest(p_id uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('path',p.storage_path,'id',p.id,'position',p.position,'primary',p.is_primary,
   'object_id',o.id,'version',o.version,'updated_at',o.updated_at,'metadata',o.metadata) order by p.position,p.id),'[]'::jsonb)
 from public.vehicle_photos p left join storage.objects o on o.bucket_id='vehicle-photos' and o.name=p.storage_path where p.listing_id=p_id;
$$;
revoke all on function private.listing_photo_manifest(uuid) from public,anon,authenticated;
create function private.listing_content_hash(p_row jsonb) returns text language sql stable security definer set search_path='' as $$
 select encode(sha256(convert_to(jsonb_build_object('listing',p_row-array['status','updated_at','created_at','sold_at','sold_to_buyer_id','sold_externally'],
 'photos',private.listing_photo_manifest((p_row->>'id')::uuid))::text,'UTF8')),'hex');
$$;
revoke all on function private.listing_content_hash(jsonb) from public,anon,authenticated;
create function private.listing_content_approved(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.listing_content_checks c join public.vehicle_listings v on v.id=c.listing_id where c.listing_id=p_id and c.user_id=v.owner_id and c.state='approved' and c.fingerprint=private.listing_content_hash(to_jsonb(v)));
$$;
revoke all on function private.listing_content_approved(uuid) from public;
grant execute on function private.listing_content_approved(uuid) to anon,authenticated;
create policy automatic_listing_visibility on public.vehicle_listings as restrictive for select to anon,authenticated
 using(not (select private.content_moderation_enabled()) or owner_id=(select auth.uid()) or private.listing_content_approved(id));

create function private.invalidate_listing_check(p_id uuid,p_owner uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or auth.uid()<>p_owner or not private.current_account_active() then raise exception 'Owner required' using errcode='42501'; end if;
 update private.listing_content_checks set state='changed',error_code='content_changed',lease_id=gen_random_uuid() where listing_id=p_id and user_id=p_owner;
end $$;
revoke all on function private.invalidate_listing_check(uuid,uuid) from public,anon;
grant execute on function private.invalidate_listing_check(uuid,uuid) to authenticated;
create function private.guard_listing_content() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if current_user not in ('anon','authenticated') or not private.content_moderation_enabled() then return new; end if;
 if tg_op='UPDATE' and ((to_jsonb(new)-array['status','updated_at','created_at','sold_at','sold_to_buyer_id','sold_externally']) is distinct from
   (to_jsonb(old)-array['status','updated_at','created_at','sold_at','sold_to_buyer_id','sold_externally']) or (new.status='draft' and old.status<>'draft')) then
   perform private.invalidate_listing_check(new.id,new.owner_id);
 end if;
 if new.status in ('published','reserved','sold') and not private.listing_content_approved(new.id) then
   raise exception 'MODERATION_REQUIRED' using errcode='42501';
 end if;
 return new;
end $$;
revoke all on function private.guard_listing_content() from public,anon,authenticated;
create trigger aa_guard_listing_content before insert or update on public.vehicle_listings for each row execute function private.guard_listing_content();

create function private.photo_upload_allowed(p_name text) returns boolean language sql stable security definer set search_path='' as $$
 select not private.content_moderation_enabled() or ((select auth.uid()) is not null and exists(select 1 from public.vehicle_listings v
   where v.owner_id=(select auth.uid()) and v.id::text=split_part(p_name,'/',2) and split_part(p_name,'/',1)=(select auth.uid())::text
     and v.status='draft' and private.listing_not_held(v.id)
     and not exists(select 1 from private.listing_content_checks c where c.listing_id=v.id and c.state='processing' and c.lease_until>now())));
$$;
revoke all on function private.photo_upload_allowed(text) from public,anon;
grant execute on function private.photo_upload_allowed(text) to authenticated;
create policy moderated_vehicle_uploads on storage.objects as restrictive for insert to authenticated
 with check(bucket_id<>'vehicle-photos' or private.photo_upload_allowed(name));
create policy moderated_vehicle_replacements on storage.objects as restrictive for update to authenticated
 using(bucket_id<>'vehicle-photos' or private.photo_upload_allowed(name)) with check(bucket_id<>'vehicle-photos' or private.photo_upload_allowed(name));
create function private.guard_photo_content() returns trigger language plpgsql security invoker set search_path='' as $$
declare listing uuid; owner uuid; state text;
begin
 if current_user not in ('anon','authenticated') or not private.content_moderation_enabled() then return coalesce(new,old); end if;
 listing:=case when tg_op='DELETE' then old.listing_id else new.listing_id end;
 if tg_op='UPDATE' and old.listing_id is distinct from new.listing_id then raise exception 'Photo reassignment forbidden' using errcode='42501'; end if;
 select owner_id,status into owner,state from public.vehicle_listings where id=listing for update;
 if not found and tg_op='DELETE' then return old; end if;
 if owner is distinct from auth.uid() or state<>'draft' or not private.photo_upload_allowed(owner::text||'/'||listing::text||'/photo') then
   raise exception 'MODERATION_REQUIRED' using errcode='42501';
 end if;
 perform private.invalidate_listing_check(listing,owner);
 return coalesce(new,old);
end $$;
revoke all on function private.guard_photo_content() from public,anon,authenticated;
create trigger guard_photo_content before insert or update or delete on public.vehicle_photos for each row execute function private.guard_photo_content();

create function public.prepare_listing_content_check(p_user_id uuid,p_session_id uuid,p_listing_id uuid,p_target_status text default 'published')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.vehicle_listings; photos jsonb; fingerprint text; lease uuid:=gen_random_uuid(); text_input text;
begin
 if p_target_status not in ('published','reserved') or not exists(select 1 from auth.sessions s where s.id=p_session_id and s.user_id=p_user_id and (s.not_after is null or s.not_after>now()))
   or exists(select 1 from private.account_deletions where user_id=p_user_id) then raise exception 'Active account required' using errcode='42501'; end if;
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
revoke all on function public.prepare_listing_content_check(uuid,uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.prepare_listing_content_check(uuid,uuid,uuid,text) to service_role;

create function public.finish_listing_content_check(p_user_id uuid,p_session_id uuid,p_listing_id uuid,p_lease_id uuid,p_outcome text,p_categories jsonb default '[]',p_error_code text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.vehicle_listings; c private.listing_content_checks; report uuid;
begin
 if not exists(select 1 from auth.sessions s where s.id=p_session_id and s.user_id=p_user_id and (s.not_after is null or s.not_after>now())) or exists(select 1 from private.account_deletions where user_id=p_user_id)
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
     insert into public.vehicle_listing_reports(reporter_id,listing_id,reason,details) values(p_user_id,v.id,'Contenido inapropiado','RevisiÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³n del filtro automÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡tico solicitada.') returning id into report;
   else update public.vehicle_listing_reports set status='pending' where id=report; end if;
   update private.listing_content_checks set report_id=report where listing_id=v.id;
 end if;
 if p_outcome='approved' and not private.listing_not_held(v.id) then return jsonb_build_object('state','held','published',false,'error_code','listing_restricted'); end if;
 return jsonb_build_object('state',p_outcome,'published',p_outcome='approved' and private.listing_not_held(v.id),'error_code',p_error_code);
end $$;
revoke all on function public.finish_listing_content_check(uuid,uuid,uuid,uuid,text,jsonb,text) from public,anon,authenticated;
grant execute on function public.finish_listing_content_check(uuid,uuid,uuid,uuid,text,jsonb,text) to service_role;

create function public.content_provider_probe_result(p_result jsonb) returns void language sql security definer set search_path='' as $$
 update private.content_moderation_config set last_probe=p_result||jsonb_build_object('checked_at',now()) where singleton;
$$;
revoke all on function public.content_provider_probe_result(jsonb) from public,anon,authenticated;
grant execute on function public.content_provider_probe_result(jsonb) to service_role;

-- Add the current automatic check to the existing case-scoped moderator view.
create or replace function private.community_report_detail(p_kind text,p_id uuid)
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
      'automatic_state',(select state from private.listing_content_checks where listing_id=report_row.listing_id),
      'automatic_fingerprint',(select fingerprint from private.listing_content_checks where listing_id=report_row.listing_id),
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

alter table private.community_review_audit drop constraint community_review_audit_action_check;
alter table private.community_review_audit add constraint community_review_audit_action_check check(action in
 ('reviewing','resolve','dismiss','hide_listing','restore_listing','restrict_chat','restore_chat','approve_publication'));
create function private.approve_listing_after_review(p_report_id uuid,p_expected_fingerprint text,p_note text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.vehicle_listing_reports; v public.vehicle_listings; c private.listing_content_checks;
begin
 if not private.is_community_moderator() then raise exception 'Moderator required' using errcode='42501'; end if;
 if char_length(coalesce(p_note,''))>1000 then raise exception 'Note too long'; end if;
 select * into r from public.vehicle_listing_reports where id=p_report_id;
 if not found then raise exception 'Report unavailable'; end if;
 select * into v from public.vehicle_listings where id=r.listing_id for update;
 perform 1 from public.vehicle_listing_reports where id=p_report_id for update;
 select * into c from private.listing_content_checks where listing_id=v.id and report_id=r.id and state in ('rejected','error') for update;
 if not found or v.status='sold' or c.fingerprint is distinct from p_expected_fingerprint or c.fingerprint<>private.listing_content_hash(to_jsonb(v))
   or not private.listing_not_held(v.id) or exists(select 1 from private.account_deletions where user_id=v.owner_id) then
   raise exception 'Content changed or listing restricted. Review the current content.' using errcode='42501';
 end if;
 update private.listing_content_checks set state='approved',error_code=null,lease_id=gen_random_uuid() where listing_id=v.id;
 update public.vehicle_listings set status=c.target_status where id=v.id;
 update public.vehicle_listing_reports set status='resolved' where id=r.id;
 insert into private.community_review_audit(listing_report_id,actor_id,action,note) values(r.id,auth.uid(),'approve_publication',coalesce(p_note,''));
 return private.community_report_detail('listing',r.id);
end $$;
revoke all on function private.approve_listing_after_review(uuid,text,text) from public,anon;
grant execute on function private.approve_listing_after_review(uuid,text,text) to authenticated;
create function public.community_approve_publication(p_report_id uuid,p_expected_fingerprint text,p_note text default '')
returns jsonb language sql security invoker set search_path='' as $$select private.approve_listing_after_review(p_report_id,p_expected_fingerprint,p_note);$$;
revoke all on function public.community_approve_publication(uuid,text,text) from public,anon;
grant execute on function public.community_approve_publication(uuid,text,text) to authenticated;

create function private.my_listing_content_checks() returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('listing_id',c.listing_id,'state',case when c.state='processing' and c.lease_until<now() then 'error' else c.state end,
   'error_code',c.error_code)),'[]'::jsonb) from private.listing_content_checks c
 where c.user_id=(select auth.uid()) and private.current_account_active();
$$;
revoke all on function private.my_listing_content_checks() from public,anon;
grant execute on function private.my_listing_content_checks() to authenticated;
create function public.my_listing_content_checks() returns jsonb language sql stable security invoker set search_path='' as $$select private.my_listing_content_checks();$$;
revoke all on function public.my_listing_content_checks() from public,anon;
grant execute on function public.my_listing_content_checks() to authenticated;
create function private.can_moderate_vehicle_photo(p_path text) returns boolean language sql stable security definer set search_path='' as $$
 select private.is_community_moderator() and exists(select 1 from public.vehicle_photos p join public.vehicle_listing_reports r on r.listing_id=p.listing_id where p.storage_path=p_path);
$$;
revoke all on function private.can_moderate_vehicle_photo(text) from public,anon;
grant execute on function private.can_moderate_vehicle_photo(text) to authenticated;
create policy moderator_case_photo_read on storage.objects for select to authenticated
 using(bucket_id='vehicle-photos' and private.can_moderate_vehicle_photo(name));
