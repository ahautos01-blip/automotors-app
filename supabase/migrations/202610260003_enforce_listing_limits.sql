-- AUTOMOTORS: enforce listing limits server-side.
-- Repository migration only. Do NOT apply to production until reviewed and tested
-- in a separate Supabase project and the subscription verifier is operational.
-- Depends on 202610230001_ad_pack_payments.sql and vehicle_listings.owner_id/status.

alter table public.vehicle_listings
  add column if not exists first_published_at timestamptz;

-- Existing non-draft listings have already been published at least once.
update public.vehicle_listings
set first_published_at = coalesce(first_published_at, created_at)
where status in ('published', 'reserved', 'sold');

create index if not exists vehicle_listings_owner_first_published_idx
  on public.vehicle_listings(owner_id, first_published_at)
  where first_published_at is not null;

create index if not exists vehicle_listings_owner_active_status_idx
  on public.vehicle_listings(owner_id, status)
  where status in ('published', 'reserved');

create or replace function public.enforce_automotors_listing_limits()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner uuid;
  v_product_id text;
  v_limit integer := 5;
  v_active_count integer := 0;
  v_lifetime_count integer := 0;
  v_is_active boolean;
begin
  v_owner := coalesce(new.owner_id, auth.uid());

  if v_owner is null then
    raise exception 'Inicia sesión para publicar un anuncio.'
      using errcode = '42501';
  end if;

  -- Bind new listings to the authenticated owner if the client omitted owner_id.
  if new.owner_id is null then
    new.owner_id := v_owner;
  end if;
  if auth.uid() is not null and new.owner_id is distinct from auth.uid() then
    raise exception 'No puedes publicar o modificar anuncios de otra cuenta.'
      using errcode = '42501';
  end if;

  v_is_active := new.status in ('published', 'reserved');
  if tg_op = 'UPDATE' then
    if new.first_published_at is null then
      new.first_published_at := old.first_published_at;
    end if;
  end if;

  -- Preserve first publication time even if the listing is later sold/unpublished.
  if v_is_active and new.first_published_at is null then
    new.first_published_at := now();
  end if;

  -- Draft edits and non-active transitions do not consume an active slot.
  if not v_is_active then
    return new;
  end if;

  -- Serialize publication decisions per user to avoid concurrent over-publishing.
  perform pg_advisory_xact_lock(hashtextextended(v_owner::text, 0));

  select us.product_id
    into v_product_id
  from public.user_subscriptions us
  where us.user_id = v_owner
    and us.status in ('active', 'grace_period')
    and (us.expires_at is null or us.expires_at > now())
  order by us.expires_at desc nulls last, us.updated_at desc
  limit 1;

  if v_product_id is not null then
    v_limit := case v_product_id
      when 'automotors_pack_10' then 10
      when 'automotors_pack_15' then 15
      when 'automotors_pack_20' then 20
      when 'automotors_pro_monthly_199' then null
      else 5
    end;
  else
    -- Free allowance: five lifetime publications, with at most five active.
    select count(*)::integer into v_lifetime_count
    from public.vehicle_listings vl
    where vl.owner_id = v_owner
      and vl.first_published_at is not null
      and vl.id is distinct from new.id;

    if new.first_published_at is not null and v_lifetime_count >= 5 then
      if tg_op = 'INSERT' then
        raise exception 'Has agotado tus 5 publicaciones gratuitas. Contrata un plan para publicar más anuncios.'
          using errcode = 'P0001';
      elsif old.first_published_at is null then
        raise exception 'Has agotado tus 5 publicaciones gratuitas. Contrata un plan para publicar más anuncios.'
          using errcode = 'P0001';
      end if;
    end if;
  end if;

  if v_limit is not null then
    select count(*)::integer into v_active_count
    from public.vehicle_listings vl
    where vl.owner_id = v_owner
      and vl.status in ('published', 'reserved')
      and vl.id is distinct from new.id;

    if v_active_count >= v_limit then
      raise exception 'Has alcanzado el límite de anuncios activos de tu plan.'
        using errcode = 'P0001';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_automotors_listing_limits
  on public.vehicle_listings;

create trigger enforce_automotors_listing_limits
before insert or update of status, owner_id
on public.vehicle_listings
for each row
execute function public.enforce_automotors_listing_limits();

-- Clients must not call the trigger function directly.
revoke all on function public.enforce_automotors_listing_limits() from public, anon, authenticated;
