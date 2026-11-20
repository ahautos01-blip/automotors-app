begin;
alter table public.user_profiles add column market_locality jsonb;
alter table public.user_profiles add constraint profile_market_locality_valid
 check (market_locality is null or private.valid_market_facts(jsonb_build_object('locality',market_locality)));
alter table public.vehicle_listings add column seller_location jsonb not null default '{}'::jsonb;

-- This is derived public municipality information, never a street address.
-- Always overwrite client input before the moderation/ownership guards run.
create function private.sync_listing_profile_location() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 select coalesce(jsonb_strip_nulls(jsonb_build_object(
  'city',nullif(btrim(p.city),''),'province',nullif(btrim(p.province),''),
  'locality',p.market_locality)),'{}'::jsonb)
 into new.seller_location from public.user_profiles p where p.id=new.owner_id;
 new.seller_location:=coalesce(new.seller_location,'{}'::jsonb);
 return new;
end;$$;
revoke all on function private.sync_listing_profile_location() from public,anon,authenticated;
create trigger a0_sync_listing_profile_location before insert or update
 on public.vehicle_listings for each row execute function private.sync_listing_profile_location();

create function private.validate_profile_market_locality() returns trigger
language plpgsql set search_path='' as $$
begin
 if tg_op='UPDATE' and (new.city is distinct from old.city or new.province is distinct from old.province)
   and new.market_locality is not distinct from old.market_locality then new.market_locality:=null;end if;
 if new.market_locality is not null and
   (nullif(btrim(new.city),'') is null or not private.valid_market_facts(jsonb_build_object('locality',new.market_locality))) then
  raise exception 'Invalid profile municipality' using errcode='23514';
 end if;
 return new;
end;$$;
revoke all on function private.validate_profile_market_locality() from public,anon,authenticated;
create trigger validate_profile_market_locality before insert or update
 on public.user_profiles for each row execute function private.validate_profile_market_locality();

create function private.refresh_profile_listing_locations() returns trigger
language plpgsql security definer set search_path='' as $$
declare loc jsonb;
begin
 loc:=jsonb_strip_nulls(jsonb_build_object('city',nullif(btrim(new.city),''),
  'province',nullif(btrim(new.province),''),'locality',new.market_locality));
 update public.vehicle_listings set seller_location=loc
 where owner_id=new.id and seller_location is distinct from loc;
 return new;
end;$$;
revoke all on function private.refresh_profile_listing_locations() from public,anon,authenticated;
create trigger refresh_profile_listing_locations after insert or update of city,province,market_locality
 on public.user_profiles for each row execute function private.refresh_profile_listing_locations();

-- Keep content approvals byte-compatible: this server-computed field cannot
-- be supplied independently by a seller. All editable listing content remains hashed.
do $$declare definition text;begin
 definition:=pg_get_functiondef('private.listing_content_hash(jsonb)'::regprocedure);
 if position('-array[''status''' in definition)=0 then raise exception 'Unexpected content hash definition';end if;
 execute replace(definition,'-array[''status''','-array[''seller_location'',''status''');
 definition:=pg_get_functiondef('private.guard_listing_content()'::regprocedure);
 if position('-array[''status''' in definition)=0 then raise exception 'Unexpected content guard definition';end if;
 execute replace(definition,'-array[''status''','-array[''seller_location'',''status''');
end;$$;

create function private.listing_search_facts(v jsonb) returns jsonb
language sql immutable set search_path='' as $$
 select case when v ? 'seller_location' then
  (coalesce(nullif(v->'market_facts','null'::jsonb),'{}'::jsonb)-'locality') ||
  case when v->'seller_location'->'locality' is null or v->'seller_location'->'locality'='null'::jsonb
   then '{}'::jsonb else jsonb_build_object('locality',v->'seller_location'->'locality') end
 else coalesce(nullif(v->'market_facts','null'::jsonb),'{}'::jsonb) end;
$$;
revoke all on function private.listing_search_facts(jsonb) from public,anon;
grant execute on function private.listing_search_facts(jsonb) to authenticated,service_role;
do $$declare definition text;begin
 definition:=pg_get_functiondef('private.buyer_search_matches(jsonb,jsonb,text,text)'::regprocedure);
 if position('private.market_radius_matches(c,v->''market_facts'')' in definition)=0 then
  raise exception 'Unexpected saved-search definition';end if;
 execute replace(definition,'private.market_radius_matches(c,v->''market_facts'')',
  'private.market_radius_matches(c,private.listing_search_facts(v))');
end;$$;

-- Existing announcements retain their status, photos and moderation approvals.
update public.vehicle_listings v set seller_location=jsonb_strip_nulls(jsonb_build_object(
 'city',nullif(btrim(p.city),''),'province',nullif(btrim(p.province),''),'locality',p.market_locality))
from public.user_profiles p where p.id=v.owner_id;
comment on column public.vehicle_listings.seller_location is
 'Server-managed public municipality from owner profile; no street, GPS history or private address.';
commit;
