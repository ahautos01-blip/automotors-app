-- AUTOMOTORS: editable professional seller introduction and verified reviews.
-- Apply to a staging Supabase project first, then production after review.

alter table public.vehicle_listings
  add column if not exists sold_externally boolean not null default false;

alter table public.vehicle_reviews
  add column if not exists communication_rating smallint,
  add column if not exists trust_rating smallint,
  add column if not exists vehicle_condition_rating smallint;

-- Existing reviews predate the three-axis form; preserve them with their old
-- rating copied into each dimension before making the new fields mandatory.
update public.vehicle_reviews
set communication_rating = coalesce(communication_rating, rating),
    trust_rating = coalesce(trust_rating, rating),
    vehicle_condition_rating = coalesce(vehicle_condition_rating, rating);

alter table public.vehicle_reviews
  alter column communication_rating set not null,
  alter column trust_rating set not null,
  alter column vehicle_condition_rating set not null;

alter table public.vehicle_reviews
  drop constraint if exists vehicle_reviews_rating_check,
  add constraint vehicle_reviews_rating_check check (rating between 0 and 5),
  add constraint vehicle_reviews_communication_check check (communication_rating between 0 and 5),
  add constraint vehicle_reviews_trust_check check (trust_rating between 0 and 5),
  add constraint vehicle_reviews_condition_check check (vehicle_condition_rating between 0 and 5);

create table if not exists public.seller_about_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  about_us text not null default '' check (char_length(about_us) <= 2000),
  updated_at timestamptz not null default now()
);

alter table public.seller_about_profiles enable row level security;
grant select on public.seller_about_profiles to anon, authenticated;
grant insert, update on public.seller_about_profiles to authenticated;

drop policy if exists "seller about is publicly readable" on public.seller_about_profiles;
create policy "seller about is publicly readable"
  on public.seller_about_profiles for select to anon, authenticated using (true);

drop policy if exists "professionals manage their seller about" on public.seller_about_profiles;
create policy "professionals manage their seller about"
  on public.seller_about_profiles for all to authenticated
  using (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.public_seller_profiles p
      where p.id = (select auth.uid())
        and lower(p.account_type) in ('autonomo', 'empresa')
    )
  )
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.public_seller_profiles p
      where p.id = (select auth.uid())
        and lower(p.account_type) in ('autonomo', 'empresa')
    )
  );

-- Replace the earlier chat-only function with support for explicitly
-- recording an external sale. The buyer path remains tied to a real chat.
drop function if exists public.mark_vehicle_sold(uuid, uuid);
create function public.mark_vehicle_sold(
  p_listing_id uuid,
  p_buyer_id uuid,
  p_sold_externally boolean default false
) returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_seller_id uuid := auth.uid();
begin
  if v_seller_id is null then
    raise exception 'Debes iniciar sesión.';
  end if;
  if coalesce(p_sold_externally, false) then
    if p_buyer_id is not null then
      raise exception 'Una venta externa no puede asignarse a un comprador del chat.';
    end if;
  else
    if p_buyer_id is null or p_buyer_id = v_seller_id then
      raise exception 'Selecciona un comprador válido.';
    end if;
    if not exists (
      select 1 from public.chat_conversations c
      where c.listing_id = p_listing_id
        and c.seller_id = v_seller_id
        and c.buyer_id = p_buyer_id
    ) then
      raise exception 'El comprador debe haberte contactado por el chat de este anuncio.';
    end if;
  end if;

  update public.vehicle_listings
  set status = 'sold',
      sold_to_buyer_id = case when p_sold_externally then null else p_buyer_id end,
      sold_externally = coalesce(p_sold_externally, false),
      sold_at = now()
  where id = p_listing_id
    and owner_id = v_seller_id
    and status in ('published', 'reserved');

  if not found then
    raise exception 'No se encontró un anuncio activo de tu propiedad.';
  end if;
end;
$$;

revoke all on function public.mark_vehicle_sold(uuid, uuid, boolean) from public, anon;
grant execute on function public.mark_vehicle_sold(uuid, uuid, boolean) to authenticated;

-- AUTOMOTORS PRO has unlimited active listings while limiting the number of
-- distinct vehicles featured at once to fifteen. Keep this server-side cap
-- conditional so older environments without the promotions table can migrate.
create or replace function public.enforce_automotors_pro_featured_limit()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner uuid;
  v_is_pro boolean;
  v_featured_count integer;
begin
  if new.status <> 'active'
     or new.starts_at > now()
     or new.ends_at <= now() then
    return new;
  end if;

  select vl.owner_id into v_owner
  from public.vehicle_listings vl
  where vl.id = new.vehicle_id;
  if v_owner is null then
    return new;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_owner::text, 1));
  select exists (
    select 1 from public.user_subscriptions us
    where us.user_id = v_owner
      and us.product_id = 'automotors_pro_monthly_199'
      and us.status in ('active', 'grace_period')
      and (us.expires_at is null or us.expires_at > now())
  ) into v_is_pro;
  if not v_is_pro then
    return new;
  end if;

  select count(distinct vp.vehicle_id)::integer into v_featured_count
  from public.vehicle_promotions vp
  join public.vehicle_listings vl on vl.id = vp.vehicle_id
  where vl.owner_id = v_owner
    and vp.status = 'active'
    and vp.starts_at <= now()
    and vp.ends_at > now()
    and vp.vehicle_id <> new.vehicle_id;

  if v_featured_count >= 15 then
    raise exception 'AUTOMOTORS PRO permite destacar hasta 15 vehículos a la vez.'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

revoke all on function public.enforce_automotors_pro_featured_limit() from public, anon, authenticated;

do $$
begin
  if to_regclass('public.vehicle_promotions') is not null then
    execute 'drop trigger if exists enforce_automotors_pro_featured_limit on public.vehicle_promotions';
    execute 'create trigger enforce_automotors_pro_featured_limit before insert or update of vehicle_id, status, starts_at, ends_at on public.vehicle_promotions for each row execute function public.enforce_automotors_pro_featured_limit()';
  end if;
end;
$$;
