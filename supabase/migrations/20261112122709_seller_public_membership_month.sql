-- Expose only membership month for profiles already visible publicly.
-- The definer can read the private join date; no other profile fields are returned.
create or replace function public.seller_member_since(p_seller_id uuid)
returns text
language sql stable security definer
set search_path = ''
as $$
  select pg_catalog.to_char(p.created_at at time zone 'UTC', 'YYYY-MM')
  from public.user_profiles p
  where p.id = p_seller_id
    and exists (select 1 from public.public_seller_profiles visible where visible.id = p.id);
$$;
revoke all on function public.seller_member_since(uuid) from public, anon, authenticated;
grant execute on function public.seller_member_since(uuid) to anon, authenticated;
comment on function public.seller_member_since(uuid) is 'Public membership month only for publicly visible seller profiles; no private profile access.';
