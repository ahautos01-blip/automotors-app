-- Allow sellers to choose whether vehicle identifiers appear on the public listing.
alter table public.vehicle_listings
  add column if not exists show_matricula_publicly boolean not null default false,
  add column if not exists show_vin_publicly boolean not null default false;

comment on column public.vehicle_listings.show_matricula_publicly is
  'Whether the seller explicitly allows the vehicle registration plate to appear on the public listing.';
comment on column public.vehicle_listings.show_vin_publicly is
  'Whether the seller explicitly allows the VIN/chassis number to appear on the public listing.';
