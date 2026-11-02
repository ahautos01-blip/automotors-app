-- In-app buyer watchlists. No external email/push delivery is added here.
begin;
alter table public.saved_vehicles
  add column reference_price numeric check(reference_price >= 0),
  add column notify_price_drops boolean not null default false;
alter table public.vehicle_search_alerts
  add column previous_price numeric,
  add column current_price numeric;
alter table public.vehicle_search_alerts drop constraint vehicle_search_alerts_search_required;
alter table public.vehicle_search_alerts add constraint vehicle_search_alerts_search_required
  check(alert_type in ('review_requested','price_drop') or search_id is not null);
create unique index favorite_price_alert_once on public.vehicle_search_alerts(user_id,listing_id)
  where alert_type='price_drop' and search_id is null;
create index saved_vehicles_price_watch_idx on public.saved_vehicles(listing_id,user_id) where notify_price_drops;
-- Only preferences may be updated by clients, never the server's reference price or owner.
grant update(notify_price_drops) on public.saved_vehicles to authenticated;
create policy "users adjust own favorite price alerts" on public.saved_vehicles for update to authenticated
  using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
-- Keep the existing owner RLS; inbox content is server-owned.
revoke all on public.vehicle_search_alerts from anon,authenticated;
grant select on public.vehicle_search_alerts to authenticated;
grant update(read_at) on public.vehicle_search_alerts to authenticated;
revoke truncate,references,trigger on public.saved_vehicle_searches from anon,authenticated;

create function private.capture_favorite_price() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  if tg_op='INSERT' then
    select price into new.reference_price from public.vehicle_listings where id=new.listing_id;
    if new.reference_price is null then
      raise exception 'Anuncio no disponible.' using errcode='42501';
    end if;
  elsif new.notify_price_drops and not old.notify_price_drops and new.reference_price is null then
    select price into new.reference_price from public.vehicle_listings where id=new.listing_id;
  end if;
  return new;
end; $$;
revoke all on function private.capture_favorite_price() from public,anon,authenticated;
create trigger capture_favorite_price before insert or update on public.saved_vehicles
  for each row execute function private.capture_favorite_price();

create function private.normalize_buyer_search(value text) returns text
language sql immutable security invoker set search_path='' as $$
  select trim(regexp_replace(translate(lower(coalesce(value,'')),
    'àáâäãåèéêëìíîïòóôöõùúûüñç','aaaaaaeeeeiiiiooooouuuunc'), '[[:space:]_.,/-]+',' ','g'));
$$;
create function private.buyer_number(value text) returns numeric
language sql immutable security invoker set search_path='' as $$
  select case when length(value)<24 and value ~ '^[0-9]+([.][0-9]+)?$' then value::numeric end;
$$;
create function private.buyer_search_matches(c jsonb,v jsonb,brand text,model text) returns boolean
language plpgsql immutable security invoker set search_path='' as $$
declare k text; pair text[]; expected text; actual text; bound numeric; val numeric; word text; document text;
begin
  if jsonb_typeof(c)<>'object' then return false; end if;
  foreach k in array array['brand','model','fuel','transmission','body_type','label','color'] loop
    expected:=private.normalize_buyer_search(c->>k);
    if expected in ('','todos','todas') then continue; end if;
    actual:=private.normalize_buyer_search(case k when 'brand' then brand when 'model' then model
      when 'label' then v->>'etiqueta_medioambiental' else v->>k end);
    if k='brand' then
      if expected='vw' then expected:='volkswagen'; end if;
      if actual='vw' then actual:='volkswagen'; end if;
    end if;
    if k='transmission' and expected='automatico' then
      if actual not like 'automatico%' then return false; end if;
    elsif k='color' then
      if position(expected in actual)=0 then return false; end if;
    elsif actual<>expected then return false;
    end if;
  end loop;
  foreach pair slice 1 in array array[
    ['min_price','price'],['max_price','price'],['min_year','year'],['max_year','year'],
    ['min_km','km'],['max_km','km'],['min_cv','cv'],['max_cv','cv'],['min_cc','cilindrada_cc'],
    ['max_doors','doors'],['min_seats','seats']] loop
    if nullif(c->>pair[1],'') is null then continue; end if;
    bound:=private.buyer_number(c->>pair[1]); val:=private.buyer_number(v->>pair[2]);
    -- Malformed or absent data cannot satisfy a requested numeric constraint.
    if bound is null or val is null then return false; end if;
    if left(pair[1],3)='min' and val<bound or left(pair[1],3)='max' and val>bound then return false; end if;
  end loop;
  document:=regexp_replace(private.normalize_buyer_search(concat_ws(' ',brand,model,v->>'version',v->>'fuel',v->>'transmission',v->>'body_type')),
    '\m(volkswagen|vw)\M','volkswagen vw','g');
  for word in select regexp_split_to_table(private.normalize_buyer_search(c->>'query'),' +') loop
    if word<>'' and position(word in document)=0 then return false; end if;
  end loop;
  if jsonb_typeof(c->'equipment')='array' then
    for word in select jsonb_array_elements_text(c->'equipment') loop
      if not exists(select 1 from jsonb_array_elements_text(case when jsonb_typeof(v->'equipment')='array' then v->'equipment' else '[]'::jsonb end) e
        where private.normalize_buyer_search(e)=private.normalize_buyer_search(word)) then return false; end if;
    end loop;
  end if;
  return true;
end; $$;
revoke all on function private.normalize_buyer_search(text),private.buyer_number(text),private.buyer_search_matches(jsonb,jsonb,text,text) from public,anon,authenticated;

-- Internal cross-user event fanout; no public RPC or client inbox writes.
create function private.create_buyer_watch_alerts() returns trigger
language plpgsql security definer set search_path='' as $$
declare s record; brand text; model text; kind text; heading text; body text; drop_price boolean:=false;
begin
  if new.status not in ('published','reserved') or not private.listing_not_held(new.id)
    or (private.content_moderation_enabled() and not private.listing_content_approved(new.id)) then return new; end if;
  if tg_op='INSERT' then
    if new.status<>'published' then return new; end if;
  else
    drop_price:=new.price is not null and old.price is not null and new.price<old.price;
    if not drop_price and not (new.status='published' and old.status not in ('published','reserved','sold')) then return new; end if;
  end if;
  kind:=case when drop_price then 'price_drop' else 'new_listing' end;
  heading:=case when drop_price then 'Bajada de precio' else 'Nuevo anuncio' end;
  select b.name,m.name into brand,model from public.vehicle_brands b join public.vehicle_models m on m.brand_id=b.id
    where b.id=new.brand_id and m.id=new.model_id;
  body:=concat_ws(' ',brand,model,case when drop_price then 'ha bajado de precio.' else 'coincide con una búsqueda que has guardado.' end);
  for s in select * from public.saved_vehicle_searches where user_id is distinct from new.owner_id
    and (drop_price and notify_price_drops or not drop_price and notify_new_listings) loop
    if not private.buyer_search_matches(s.criteria,to_jsonb(new),brand,model) then continue; end if;
    insert into public.vehicle_search_alerts(user_id,search_id,listing_id,alert_type,title,message,previous_price,current_price)
    values(s.user_id,s.id,new.id,kind,heading,body,case when drop_price then old.price end,new.price)
    on conflict(search_id,listing_id,alert_type) do update set
      previous_price=excluded.previous_price,current_price=excluded.current_price,message=excluded.message,
      read_at=null,created_at=now() where excluded.alert_type='price_drop';
  end loop;
  if drop_price then
    insert into public.vehicle_search_alerts(user_id,listing_id,alert_type,title,message,previous_price,current_price)
      select f.user_id,new.id,'price_drop',heading,concat_ws(' ',brand,model,'de tus favoritos ha bajado de precio.'),old.price,new.price
      from public.saved_vehicles f where f.listing_id=new.id and f.notify_price_drops and f.user_id is distinct from new.owner_id
      on conflict(user_id,listing_id) where alert_type='price_drop' and search_id is null do update set
        previous_price=excluded.previous_price,current_price=excluded.current_price,message=excluded.message,read_at=null,created_at=now();
  end if;
  return new;
end; $$;
revoke all on function private.create_buyer_watch_alerts() from public,anon,authenticated;
drop trigger vehicle_listing_search_alerts_insert on public.vehicle_listings;
drop trigger vehicle_listing_search_alerts_price on public.vehicle_listings;
-- Remove the old public definer endpoint once its triggers have been replaced.
drop function public.create_vehicle_search_alerts();
create trigger buyer_watch_events after insert or update of price,status on public.vehicle_listings
  for each row execute function private.create_buyer_watch_alerts();
commit;
