-- The current client saves this section, but the live table was missing.
create table public.seller_about_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  about_us text not null default '' check (char_length(about_us) <= 2000),
  updated_at timestamptz not null default now()
);
alter table public.seller_about_profiles enable row level security;
grant select on public.seller_about_profiles to anon,authenticated;
grant insert,update on public.seller_about_profiles to authenticated;
create policy seller_about_public_read on public.seller_about_profiles
for select to anon,authenticated using (true);
create policy seller_about_professional_insert on public.seller_about_profiles
for insert to authenticated with check (
  user_id=(select auth.uid()) and exists (select 1 from public.user_profiles p
    where p.id=(select auth.uid()) and lower(p.account_type) in ('autonomo','empresa'))
);
create policy seller_about_professional_update on public.seller_about_profiles
for update to authenticated using (
  user_id=(select auth.uid()) and exists (select 1 from public.user_profiles p
    where p.id=(select auth.uid()) and lower(p.account_type) in ('autonomo','empresa'))
) with check (
  user_id=(select auth.uid()) and exists (select 1 from public.user_profiles p
    where p.id=(select auth.uid()) and lower(p.account_type) in ('autonomo','empresa'))
);
create policy account_must_be_active on public.seller_about_profiles as restrictive
for all to authenticated using ((select private.current_account_active()))
with check ((select private.current_account_active()));
