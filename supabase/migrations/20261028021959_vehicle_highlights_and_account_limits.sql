-- Limits shared by publication and featuring. Apply after the store subscription
-- schema and private.vehicle_publication_ledger have been installed.
create schema if not exists private;
create table if not exists private.vehicle_publication_ledger (
  listing_id uuid not null, owner_id uuid not null references auth.users(id) on delete cascade,
  published_at timestamptz not null default now(), primary key(listing_id,owner_id)
);
alter table private.vehicle_publication_ledger enable row level security;
revoke all on private.vehicle_publication_ledger from public, anon, authenticated;
insert into private.vehicle_publication_ledger(listing_id,owner_id,published_at)
  select id,owner_id,created_at from public.vehicle_listings
  where owner_id is not null and status in ('published','reserved','sold')
  on conflict(listing_id,owner_id) do nothing;

create or replace function private.automotors_account_limits(p_user_id uuid)
returns table(listing_limit integer, featured_limit integer)
language sql stable set search_path = '' as $$
  with plans as (
    select case s.product_id
      when 'automotors_pack_10' then 10 when 'automotors_pack_15' then 15
      when 'automotors_pack_20' then 20 when 'automotors_pro_monthly_199' then 2147483647 end as listings,
      case s.product_id when 'automotors_pack_10' then 3
      when 'automotors_pack_15' then 5 when 'automotors_pack_20' then 8
      when 'automotors_pro_monthly_199' then 15 end as featured
    from public.user_subscriptions s
    where s.user_id = p_user_id and s.status in ('active','grace_period')
      and coalesce(s.started_at, s.created_at) <= now() and s.expires_at > now()
    union all
    select case product.code when 'PACK_10' then 10 when 'PACK_15' then 15
      when 'PACK_20' then 20 when 'PRO_MONTHLY' then 2147483647 end,
      case product.code when 'PACK_10' then 3 when 'PACK_15' then 5
      when 'PACK_20' then 8 when 'PRO_MONTHLY' then 15 end
    from public.user_promotion_entitlements e
    join public.promotion_purchases p on p.id=e.purchase_id and p.user_id=e.user_id
    join public.promotion_products product on product.id=p.product_id
    where e.user_id=p_user_id and e.status='active' and p.payment_status='paid'
      and e.starts_at <= now() and e.ends_at > now()
  )
  select coalesce(max(listings), case when
    (select count(*) from private.vehicle_publication_ledger where owner_id=p_user_id) < 5
    then 5 else 3 end), coalesce(max(featured),0) from plans;
$$;
revoke all on function private.automotors_account_limits(uuid) from public, anon, authenticated;

-- A selection survives renewal, but is visible only while a verified plan is
-- active. Ranking also enforces a downgrade immediately, without a scheduled job.
create table if not exists private.vehicle_feature_selections (
  vehicle_id uuid primary key references public.vehicle_listings(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  selected_at timestamptz not null default now()
);
create index if not exists vehicle_feature_selections_user_idx
  on private.vehicle_feature_selections(user_id, selected_at, vehicle_id);
alter table private.vehicle_feature_selections enable row level security;
revoke all on private.vehicle_feature_selections from public, anon, authenticated;

create or replace function private.clear_inactive_vehicle_feature()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status not in ('published','reserved') or new.owner_id is distinct from old.owner_id then
    delete from private.vehicle_feature_selections where vehicle_id=new.id;
  end if;
  return new;
end;
$$;
revoke all on function private.clear_inactive_vehicle_feature() from public, anon, authenticated;
drop trigger if exists clear_inactive_vehicle_feature on public.vehicle_listings;
create trigger clear_inactive_vehicle_feature after update of status,owner_id
  on public.vehicle_listings for each row execute function private.clear_inactive_vehicle_feature();

create or replace function private.automotors_featured_vehicle_ids()
returns table(vehicle_id uuid) language sql stable security definer
set search_path = '' as $$
  with ranked as (
    select f.vehicle_id, limits.featured_limit,
      row_number() over (partition by f.user_id order by f.selected_at,f.vehicle_id) as position
    from private.vehicle_feature_selections f
    join public.vehicle_listings v on v.id=f.vehicle_id and v.owner_id=f.user_id
      and v.status in ('published','reserved')
    cross join lateral private.automotors_account_limits(f.user_id) limits
  ) select ranked.vehicle_id from ranked where position <= featured_limit;
$$;
revoke all on function private.automotors_featured_vehicle_ids() from public;
grant usage on schema private to anon, authenticated;
grant execute on function private.automotors_featured_vehicle_ids() to anon, authenticated;

create or replace function public.get_featured_vehicle_ids()
returns table(vehicle_id uuid) language sql stable security invoker
set search_path = '' as $$ select * from private.automotors_featured_vehicle_ids(); $$;
revoke all on function public.get_featured_vehicle_ids() from public;
grant execute on function public.get_featured_vehicle_ids() to anon, authenticated;

create or replace function private.automotors_manage_vehicle_feature(p_vehicle_id uuid, p_enabled boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_limit integer;
  v_used integer;
  v_selected boolean;
  v_status text;
begin
  if v_user is null then raise exception 'Inicia sesión para gestionar destacados.' using errcode='42501'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_user::text,0));
  select status into v_status from public.vehicle_listings
    where id=p_vehicle_id and owner_id=v_user for update;
  if not found then raise exception 'Solo puedes destacar tus propios anuncios.' using errcode='42501'; end if;
  select featured_limit into v_limit from private.automotors_account_limits(v_user);
  select exists(select 1 from private.vehicle_feature_selections where vehicle_id=p_vehicle_id and user_id=v_user) into v_selected;
  select count(*) into v_used from private.vehicle_feature_selections f
    join public.vehicle_listings v on v.id=f.vehicle_id and v.owner_id=f.user_id
    where f.user_id=v_user and v.status in ('published','reserved');
  if p_enabled is true then
    if v_status not in ('published','reserved') then
      raise exception 'Publica el anuncio antes de destacarlo.' using errcode='P0001';
    end if;
    if v_limit=0 then raise exception 'Necesitas un pack o una suscripción activa para destacar vehículos.' using errcode='P0001'; end if;
    if not v_selected and v_used>=v_limit then
      raise exception 'Has alcanzado el máximo de % vehículos destacados de tu plan.',v_limit using errcode='P0001';
    end if;
    insert into private.vehicle_feature_selections(vehicle_id,user_id) values(p_vehicle_id,v_user)
      on conflict(vehicle_id) do update set user_id=excluded.user_id,selected_at=now()
      where private.vehicle_feature_selections.user_id<>excluded.user_id;
  elsif p_enabled is false then
    delete from private.vehicle_feature_selections where vehicle_id=p_vehicle_id and user_id=v_user;
  end if;
  return jsonb_build_object('limit',v_limit,
    'used',(select count(*) from private.vehicle_feature_selections f join public.vehicle_listings v
      on v.id=f.vehicle_id and v.owner_id=f.user_id where f.user_id=v_user and v.status in ('published','reserved')),
    'selected',exists(select 1 from private.vehicle_feature_selections where vehicle_id=p_vehicle_id and user_id=v_user),
    'featured',exists(select 1 from private.automotors_featured_vehicle_ids() f where f.vehicle_id=p_vehicle_id),
    'can_feature',v_status in ('published','reserved'));
end;
$$;
revoke all on function private.automotors_manage_vehicle_feature(uuid,boolean) from public, anon;
grant execute on function private.automotors_manage_vehicle_feature(uuid,boolean) to authenticated;
create or replace function public.manage_vehicle_feature(p_vehicle_id uuid, p_enabled boolean default null)
returns jsonb language sql security invoker set search_path = '' as $$
  select private.automotors_manage_vehicle_feature(p_vehicle_id,p_enabled);
$$;
revoke all on function public.manage_vehicle_feature(uuid,boolean) from public, anon;
grant execute on function public.manage_vehicle_feature(uuid,boolean) to authenticated;

create or replace function private.automotors_can_publish()
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_limit integer; v_count bigint;
begin
  if v_user is null then return false; end if;
  select listing_limit into v_limit from private.automotors_account_limits(v_user);
  select count(*) into v_count from public.vehicle_listings
    where owner_id=v_user and status in ('published','reserved');
  return v_count<v_limit;
end;
$$;
revoke all on function private.automotors_can_publish() from public, anon;
grant execute on function private.automotors_can_publish() to authenticated;
create or replace function public.can_publish_vehicle_listing()
returns boolean language sql security invoker set search_path = '' as $$
  select private.automotors_can_publish();
$$;
revoke all on function public.can_publish_vehicle_listing() from public, anon;
grant execute on function public.can_publish_vehicle_listing() to authenticated;

create or replace function private.enforce_vehicle_publication_quota()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_limit integer; v_count bigint;
begin
  if new.owner_id is null or new.status not in ('published','reserved','sold') then return new; end if;
  if tg_op='UPDATE' then
    if new.owner_id is distinct from old.owner_id then
      raise exception 'No puedes transferir un anuncio publicado a otra cuenta.' using errcode='42501';
    end if;
    if old.status in ('published','reserved') then return new; end if;
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.owner_id::text,0));
  select listing_limit into v_limit from private.automotors_account_limits(new.owner_id);
  select count(*) into v_count from public.vehicle_listings
    where owner_id=new.owner_id and status in ('published','reserved') and id<>new.id;
  if new.status in ('published','reserved') and v_count>=v_limit then
    raise exception 'Has alcanzado el límite de % anuncios activos de tu cuenta.',v_limit using errcode='P0001';
  end if;
  insert into private.vehicle_publication_ledger(listing_id,owner_id) values(new.id,new.owner_id)
    on conflict(listing_id,owner_id) do nothing;
  return new;
end;
$$;
revoke all on function private.enforce_vehicle_publication_quota() from public, anon, authenticated;
-- Supersede the older repository trigger too, if it was installed.
drop trigger if exists enforce_automotors_listing_limits on public.vehicle_listings;
drop trigger if exists enforce_vehicle_publication_quota on public.vehicle_listings;
create trigger enforce_vehicle_publication_quota before insert or update of status,owner_id
  on public.vehicle_listings for each row execute function private.enforce_vehicle_publication_quota();
