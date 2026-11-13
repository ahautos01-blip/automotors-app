-- Authenticated visits only, deduplicated per listing/account/day (UTC).
-- No IP, device identifier, anonymous tracking or visitor identity returned to sellers.
create function private.metrics_actor_active() returns boolean
language sql stable security definer set search_path='' as $$
 select private.current_account_active() and exists (
   select 1 from auth.sessions s where s.user_id=(select auth.uid())
   and s.id::text=(select auth.jwt()->>'session_id')
   and (s.not_after is null or s.not_after>now()));
$$;
revoke all on function private.metrics_actor_active() from public,anon;
grant execute on function private.metrics_actor_active() to authenticated;

create table public.listing_view_days (
 listing_id uuid not null references public.vehicle_listings(id) on delete cascade,
 viewer_id uuid not null references auth.users(id) on delete cascade,
 viewed_on date not null default (timezone('UTC',now())::date),
 primary key(listing_id,viewer_id,viewed_on)
);
alter table public.listing_view_days enable row level security;
revoke all on public.listing_view_days from public,anon,authenticated;
grant select,insert on public.listing_view_days to authenticated;
create policy listing_view_actor_guard on public.listing_view_days as restrictive
for all to authenticated using((select private.metrics_actor_active()))
with check((select private.metrics_actor_active()));
create policy view_own_record on public.listing_view_days for select to authenticated
using(viewer_id=(select auth.uid()));
create policy record_visible_listing on public.listing_view_days for insert to authenticated
with check(viewer_id=(select auth.uid()) and viewed_on=timezone('UTC',now())::date
 and exists(select 1 from public.vehicle_listings l where l.id=listing_id
   and l.owner_id<>(select auth.uid()) and l.status in ('published','reserved','sold')));

create function private.seller_listing_metrics()
returns table(listing_id uuid,views bigint,favorites bigint,conversations bigint)
language plpgsql stable security definer set search_path='' as $$
begin
 if not private.metrics_actor_active() then raise exception 'Active session required' using errcode='42501'; end if;
 return query select l.id,
  (select count(*) from public.listing_view_days v where v.listing_id=l.id),
  (select count(*) from public.saved_vehicles f where f.listing_id=l.id),
  (select count(*) from public.chat_conversations c where c.listing_id=l.id and c.seller_id=(select auth.uid()))
 from public.vehicle_listings l where l.owner_id=(select auth.uid());
end; $$;
revoke all on function private.seller_listing_metrics() from public,anon;
grant execute on function private.seller_listing_metrics() to authenticated;
create function public.my_listing_metrics()
returns table(listing_id uuid,views bigint,favorites bigint,conversations bigint)
language sql stable security invoker set search_path='' as $$ select * from private.seller_listing_metrics(); $$;
revoke all on function public.my_listing_metrics() from public,anon;
grant execute on function public.my_listing_metrics() to authenticated;
comment on table public.listing_view_days is 'One registered-account visit per listing/day UTC, excluding owners. Insert requires listing visibility and a live active session. Sellers receive counts only.';
