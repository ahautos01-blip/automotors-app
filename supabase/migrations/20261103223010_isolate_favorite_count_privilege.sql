-- Keep the privileged aggregate behind a private, visibility-checked function.
-- Public API remains SECURITY INVOKER; saved_vehicles row permissions are unchanged.
alter function public.listing_favorite_count(uuid) set schema private;
create function public.listing_favorite_count(p_listing_id uuid)
returns bigint language sql stable security invoker set search_path='' as $$
  select private.listing_favorite_count(p_listing_id);
$$;
revoke all on function public.listing_favorite_count(uuid) from public;
grant execute on function public.listing_favorite_count(uuid) to anon,authenticated;
comment on function public.listing_favorite_count(uuid) is 'Read-only public aggregate; private implementation enforces listing visibility and never returns saver identities.';
