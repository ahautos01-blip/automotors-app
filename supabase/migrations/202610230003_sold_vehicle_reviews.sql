-- AUTOMOTORS: marcar vehículos como vendidos y reseñas verificadas.
-- Revisar la estructura de vehicle_listings antes de aplicar en producción.

alter table public.vehicle_listings
  add column if not exists sold_to_buyer_id uuid references auth.users(id) on delete set null,
  add column if not exists sold_at timestamptz;

create index if not exists vehicle_listings_sold_to_buyer_idx
  on public.vehicle_listings(sold_to_buyer_id, sold_at desc)
  where sold_to_buyer_id is not null;

create table if not exists public.vehicle_reviews (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.vehicle_listings(id) on delete cascade,
  buyer_id uuid not null references auth.users(id) on delete cascade,
  seller_id uuid not null references auth.users(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  review_text text not null check (char_length(trim(review_text)) between 1 and 2000),
  created_at timestamptz not null default now(),
  constraint vehicle_reviews_one_per_buyer_listing unique (listing_id, buyer_id),
  constraint vehicle_reviews_different_users check (buyer_id <> seller_id)
);

create index if not exists vehicle_reviews_seller_created_idx
  on public.vehicle_reviews(seller_id, created_at desc);
create index if not exists vehicle_reviews_listing_idx
  on public.vehicle_reviews(listing_id, created_at desc);

alter table public.vehicle_reviews enable row level security;

grant select, insert on public.vehicle_reviews to authenticated;

-- Las reseñas publicadas son visibles en el perfil del vendedor.
drop policy if exists "reviews are publicly readable" on public.vehicle_reviews;
create policy "reviews are publicly readable"
  on public.vehicle_reviews for select
  to anon, authenticated
  using (true);

-- Solo el comprador seleccionado al marcar el anuncio como vendido puede reseñar.
drop policy if exists "verified sold buyer can review once" on public.vehicle_reviews;
create policy "verified sold buyer can review once"
  on public.vehicle_reviews for insert
  to authenticated
  with check (
    buyer_id = auth.uid()
    and exists (
      select 1
      from public.vehicle_listings vl
      where vl.id = listing_id
        and vl.owner_id = seller_id
        and vl.status = 'sold'
        and vl.sold_to_buyer_id = auth.uid()
    )
  );

-- No permitir modificar ni borrar reseñas mediante el cliente.
revoke update, delete on public.vehicle_reviews from anon, authenticated;

-- Solo el propietario del anuncio puede marcarlo como vendido y seleccionar
-- a un comprador que haya contactado mediante chat de ese anuncio.
create or replace function public.mark_vehicle_sold(
  p_listing_id uuid,
  p_buyer_id uuid
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

  update public.vehicle_listings
  set status = 'sold',
      sold_to_buyer_id = p_buyer_id,
      sold_at = now()
  where id = p_listing_id
    and owner_id = v_seller_id
    and status = 'published';

  if not found then
    raise exception 'No se encontró un anuncio publicado de tu propiedad.';
  end if;
end;
$$;

grant execute on function public.mark_vehicle_sold(uuid, uuid) to authenticated;

-- Nota: si vehicle_listings usa un estado distinto de 'sold', ajustar el literal
-- de esta migración y el filtro de la aplicación para mantenerlo consistente.
