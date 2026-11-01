-- A durable marker freezes writes while Storage/Auth cleanup is retried.
create table private.account_deletions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  requested_at timestamptz not null default now()
);
alter table private.account_deletions enable row level security;
revoke all on private.account_deletions from public, anon, authenticated;

create function private.current_account_active()
returns boolean language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) is not null
    and exists (select 1 from auth.users u where u.id = (select auth.uid()))
    and not exists (select 1 from private.account_deletions d where d.user_id = (select auth.uid()));
$$;
revoke all on function private.current_account_active() from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.current_account_active() to authenticated;

-- Restrictive policies add to existing ownership rules, never replace them.
do $$
declare table_name text;
begin
  foreach table_name in array array[
    'user_profiles','vehicle_listings','vehicle_photos','chat_conversations',
    'chat_messages','saved_vehicles','saved_vehicle_searches','vehicle_search_alerts',
    'vehicle_listing_reports','vehicle_reviews','push_devices'
  ] loop
    execute format('create policy account_must_be_active on public.%I as restrictive for all to authenticated using ((select private.current_account_active())) with check ((select private.current_account_active()))',table_name);
  end loop;
end;
$$;
create policy account_must_be_active on storage.objects as restrictive
for all to authenticated
using ((select private.current_account_active()))
with check ((select private.current_account_active()));

create function public.prepare_account_deletion(p_user_id uuid, p_session_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare files jsonb;
begin
  if not exists (select 1 from auth.sessions s where s.id=p_session_id
      and s.user_id=p_user_id and (s.not_after is null or s.not_after > now())) then
    raise exception 'Active session required' using errcode='42501';
  end if;
  insert into private.account_deletions(user_id) values(p_user_id) on conflict do nothing;
  select coalesce(jsonb_agg(jsonb_build_object('bucket',o.bucket_id,'path',o.name)), '[]'::jsonb)
    into files from storage.objects o
    where to_jsonb(o)->>'owner_id'=p_user_id::text
       or to_jsonb(o)->>'owner'=p_user_id::text
       or (o.bucket_id in ('vehicle-photos','profile-photos','verification-documents')
         and split_part(o.name,'/',1)=p_user_id::text);
  return files;
end;
$$;
revoke all on function public.prepare_account_deletion(uuid,uuid) from public,anon,authenticated;
grant execute on function public.prepare_account_deletion(uuid,uuid) to service_role;

create function public.cleanup_account_data(p_user_id uuid, p_session_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from auth.sessions s join private.account_deletions d on d.user_id=s.user_id
      where s.id=p_session_id and s.user_id=p_user_id
        and (s.not_after is null or s.not_after > now())) then
    raise exception 'Active deletion session required' using errcode='42501';
  end if;
  if exists (select 1 from storage.objects o where to_jsonb(o)->>'owner_id'=p_user_id::text
      or to_jsonb(o)->>'owner'=p_user_id::text
      or (o.bucket_id in ('vehicle-photos','profile-photos','verification-documents')
        and split_part(o.name,'/',1)=p_user_id::text)) then
    raise exception 'Storage cleanup required';
  end if;
  delete from public.vehicle_promotions where user_id=p_user_id
    or purchase_id in (select id from public.promotion_purchases where user_id=p_user_id);
  delete from public.user_promotion_entitlements where user_id=p_user_id
    or purchase_id in (select id from public.promotion_purchases where user_id=p_user_id);
  delete from public.promotion_purchases where user_id=p_user_id;
  -- The live owner FK is SET NULL, so delete listings explicitly, never orphan them.
  delete from public.vehicle_listings where owner_id=p_user_id;
  -- Remaining profile/chat/review/device/search rows cascade through Auth deletion.
end;
$$;
revoke all on function public.cleanup_account_data(uuid,uuid) from public,anon,authenticated;
grant execute on function public.cleanup_account_data(uuid,uuid) to service_role;
