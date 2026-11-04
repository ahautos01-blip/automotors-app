-- Only aggregate counts are public; individual saved_vehicles rows keep owner RLS.
create index if not exists saved_vehicles_listing_count_idx on public.saved_vehicles(listing_id);

create function public.listing_favorite_count(p_listing_id uuid)
returns bigint language plpgsql stable security definer set search_path='' as $$
declare actor uuid := (select auth.uid()); result bigint;
begin
  if actor is not null and not private.current_account_active() then return null; end if;
  if not exists (
    select 1 from public.vehicle_listings l where l.id=p_listing_id
      and (l.status in ('published','reserved','sold') or l.owner_id=actor)
      and (private.listing_not_held(l.id) or l.owner_id=actor)
      and (not private.content_moderation_enabled() or private.listing_content_approved(l.id) or l.owner_id=actor)
  ) then return null; end if;
  select count(*) into result from public.saved_vehicles f where f.listing_id=p_listing_id;
  return result;
end; $$;
revoke all on function public.listing_favorite_count(uuid) from public;
grant execute on function public.listing_favorite_count(uuid) to anon,authenticated;
comment on function public.listing_favorite_count(uuid) is 'Aggregate only for a visible listing or its owner; never reveals saver identity or grants access to saved_vehicles rows.';
