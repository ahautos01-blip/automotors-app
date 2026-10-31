-- Repair applied to the AUTOMOTORS production database on 2026-10-28.
-- Run only when vehicle_reviews and the invitation trigger are absent.
begin;
create table public.vehicle_reviews (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.vehicle_listings(id) on delete cascade,
  buyer_id uuid not null references auth.users(id) on delete cascade,
  seller_id uuid not null references auth.users(id) on delete cascade,
  rating smallint not null check (rating between 0 and 5),
  communication_rating smallint not null check (communication_rating between 0 and 5),
  trust_rating smallint not null check (trust_rating between 0 and 5),
  vehicle_condition_rating smallint not null check (vehicle_condition_rating between 0 and 5),
  review_text text not null check (char_length(trim(review_text)) between 1 and 2000),
  created_at timestamptz not null default now(),
  constraint vehicle_reviews_one_per_buyer_listing unique (listing_id, buyer_id),
  constraint vehicle_reviews_different_users check (buyer_id <> seller_id)
);
create index vehicle_reviews_seller_created_idx on public.vehicle_reviews(seller_id,created_at desc);
create index vehicle_reviews_buyer_idx on public.vehicle_reviews(buyer_id);
alter table public.vehicle_reviews enable row level security;
revoke all on public.vehicle_reviews from anon,authenticated;
grant select on public.vehicle_reviews to anon,authenticated;
grant insert on public.vehicle_reviews to authenticated;
create policy "reviews are publicly readable" on public.vehicle_reviews for select
to anon,authenticated using (true);
create policy "verified sold buyer can review once" on public.vehicle_reviews for insert
to authenticated with check (
  buyer_id=(select auth.uid()) and exists (
    select 1 from public.vehicle_listings vl
    where vl.id=vehicle_reviews.listing_id and vl.owner_id=vehicle_reviews.seller_id
      and vl.status='sold' and not vl.sold_externally
      and vl.sold_to_buyer_id=(select auth.uid())
  )
);
-- Use the existing in-app inbox; review invitations do not belong to a saved search.
alter table public.vehicle_search_alerts alter column search_id drop not null;
alter table public.vehicle_search_alerts drop constraint vehicle_search_alerts_alert_type_check;
alter table public.vehicle_search_alerts add constraint vehicle_search_alerts_alert_type_check
  check (alert_type in ('new_listing','price_drop','review_requested'));
alter table public.vehicle_search_alerts add constraint vehicle_search_alerts_search_required
  check (alert_type='review_requested' or search_id is not null);
create unique index vehicle_review_invitation_once
  on public.vehicle_search_alerts(user_id,listing_id) where alert_type='review_requested';
-- Internal trigger needs to insert into the buyer's inbox, which the seller cannot write.
create or replace function private.invite_verified_buyer_review()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.status='sold' and not new.sold_externally
     and new.sold_to_buyer_id is not null and new.owner_id is not null
     and new.sold_to_buyer_id<>new.owner_id
     and (old.status is distinct from new.status
          or old.sold_to_buyer_id is distinct from new.sold_to_buyer_id
          or old.sold_externally is distinct from new.sold_externally)
     and not exists (
       select 1 from public.vehicle_reviews r
       where r.listing_id=new.id and r.buyer_id=new.sold_to_buyer_id
     ) then
    insert into public.vehicle_search_alerts(user_id,listing_id,alert_type,title,message)
    values(new.sold_to_buyer_id,new.id,'review_requested','Valora tu compra',
      'El vendedor ha confirmado tu compra. Puedes valorar la comunicación, la confianza y el estado del vehículo desde la ficha del coche vendido en el perfil del vendedor.')
    on conflict (user_id,listing_id) where alert_type='review_requested' do nothing;
  end if;
  return new;
end;
$$;
revoke all on function private.invite_verified_buyer_review() from public,anon,authenticated;
create trigger invite_verified_buyer_review after update of status,sold_to_buyer_id,sold_externally
on public.vehicle_listings for each row execute function private.invite_verified_buyer_review();
-- Recover pending invitations for sales confirmed before the trigger existed.
insert into public.vehicle_search_alerts(user_id,listing_id,alert_type,title,message)
select v.sold_to_buyer_id,v.id,'review_requested','Valora tu compra',
  'El vendedor ha confirmado tu compra. Puedes valorar la comunicación, la confianza y el estado del vehículo desde la ficha del coche vendido en el perfil del vendedor.'
from public.vehicle_listings v
where v.status='sold' and not v.sold_externally
  and v.sold_to_buyer_id is not null and v.owner_id is not null
  and v.sold_to_buyer_id<>v.owner_id
  and not exists(select 1 from public.vehicle_reviews r where r.listing_id=v.id and r.buyer_id=v.sold_to_buyer_id)
on conflict (user_id,listing_id) where alert_type='review_requested' do nothing;
notify pgrst,'reload schema';
commit;