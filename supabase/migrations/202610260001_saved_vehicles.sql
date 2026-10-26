-- AUTOMOTORS: favoritos de anuncios para compradores.
-- Idempotente: permite aplicarse aunque la tabla ya se haya creado manualmente.

create table if not exists public.saved_vehicles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  listing_id uuid not null references public.vehicle_listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint saved_vehicles_user_listing_unique unique (user_id, listing_id)
);

create index if not exists saved_vehicles_user_created_idx
  on public.saved_vehicles(user_id, created_at desc);

alter table public.saved_vehicles enable row level security;

grant select, insert, delete on public.saved_vehicles to authenticated;

drop policy if exists "users can read own saved vehicles" on public.saved_vehicles;
create policy "users can read own saved vehicles"
  on public.saved_vehicles for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "users can save own vehicles" on public.saved_vehicles;
create policy "users can save own vehicles"
  on public.saved_vehicles for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "users can remove own saved vehicles" on public.saved_vehicles;
create policy "users can remove own saved vehicles"
  on public.saved_vehicles for delete
  to authenticated
  using (user_id = auth.uid());

-- No se permite modificar filas existentes desde el cliente.
revoke update on public.saved_vehicles from anon, authenticated;
