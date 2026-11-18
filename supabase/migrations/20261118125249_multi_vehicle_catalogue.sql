begin;
-- Existing rows and existing clients retain the original car defaults.
alter table public.vehicle_listings
 add column vehicle_category text not null default 'car',
 add column declared_brand text,
 add column declared_model text,
 add column category_details jsonb not null default '{}'::jsonb,
 alter column brand_id drop not null,
 alter column model_id drop not null;

create function private.valid_category_details(category text, details jsonb) returns boolean
language plpgsql immutable security invoker set search_path='' as $$
declare limits jsonb; k text; n numeric;
begin
 if category is null or category not in ('car','motorcycle','truck','boat') or details is null or jsonb_typeof(details)<>'object' or octet_length(details::text)>1000 then return false;end if;
 limits:=case category when 'car' then '{}' when 'motorcycle' then '{"engine_cc":10000,"seat_height_mm":2000}' when 'truck' then '{"gross_weight_kg":200000,"payload_kg":200000,"axles":20}' else '{"length_m":200,"beam_m":100,"engine_hours":1000000,"cabins":100}' end::jsonb;
 for k in select jsonb_object_keys(details) loop
  if not limits ? k or jsonb_typeof(details->k)<>'number' then return false;end if;
  n:=(details->>k)::numeric;
  if n<0 or n>(limits->>k)::numeric or (k not in ('length_m','beam_m') and n<>trunc(n)) then return false;end if;
 end loop;
 if category='truck' and details ?& array['gross_weight_kg','payload_kg'] and (details->>'payload_kg')::numeric>(details->>'gross_weight_kg')::numeric then return false;end if;
 return true;
exception when others then return false;
end;$$;
revoke all on function private.valid_category_details(text,jsonb) from public,anon;
grant execute on function private.valid_category_details(text,jsonb) to authenticated,service_role;

alter table public.vehicle_listings add constraint vehicle_category_valid check(vehicle_category in ('car','motorcycle','truck','boat')),
 add constraint vehicle_category_details_valid check(private.valid_category_details(vehicle_category,category_details)),
 add constraint vehicle_category_identity_valid check(
  (vehicle_category='car' and brand_id is not null and model_id is not null and declared_brand is null and declared_model is null)
  or (vehicle_category<>'car' and brand_id is null and model_id is null and declared_brand is not null and declared_model is not null and length(trim(declared_brand)) between 1 and 80 and length(trim(declared_model)) between 1 and 100)),
 add constraint boat_road_data_absent check(vehicle_category<>'boat' or (km=0 and transmission is null and body_type is null and doors is null and etiqueta_medioambiental is null and matricula is null and vin is null and not show_matricula_publicly and not show_vin_publicly and not coalesce(market_facts ?| array['itv','itv_until'],false)));
create index vehicle_listings_category_created_idx on public.vehicle_listings(vehicle_category,created_at desc) where status in ('published','reserved');
-- Category cannot be changed on an existing announcement: its chat and history keep their identity.
create function private.keep_vehicle_category() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if new.vehicle_category is distinct from old.vehicle_category then raise exception 'La categoría de un anuncio no se puede cambiar.' using errcode='23514';end if;
 return new;
end;$$;
revoke all on function private.keep_vehicle_category() from public,anon,authenticated;
create trigger keep_vehicle_category before update of vehicle_category on public.vehicle_listings for each row execute function private.keep_vehicle_category();
-- Explicit column grants preserve the existing RLS policies and private identifier protections.
grant select(vehicle_category,declared_brand,declared_model,category_details) on public.vehicle_listings to anon,authenticated;
grant insert(vehicle_category,declared_brand,declared_model,category_details),update(category_details,declared_brand,declared_model) on public.vehicle_listings to authenticated;

create function private.category_search_matches(c jsonb,d jsonb,category text) returns boolean language plpgsql immutable security invoker set search_path='' as $$
declare k text; f text; bound numeric; actual numeric;
begin
 if c is null or c='null'::jsonb then return true;end if;
 if jsonb_typeof(c)<>'object' or octet_length(c::text)>2000 then return false;end if;
 for k in select jsonb_object_keys(c) loop
  if left(k,4) not in ('min_','max_') then return false;end if;
  f:=substr(k,5);bound:=private.buyer_number(c->>k);actual:=private.buyer_number(d->>f);
  if bound is null or actual is null or not private.valid_category_details(category,jsonb_build_object(f,bound)) then return false;end if;
  if left(k,4)='min_' and actual<bound or left(k,4)='max_' and actual>bound then return false;end if;
 end loop;
 return true;
end;$$;
revoke all on function private.category_search_matches(jsonb,jsonb,text) from public,anon;
grant execute on function private.category_search_matches(jsonb,jsonb,text) to authenticated,service_role;

CREATE OR REPLACE FUNCTION private.buyer_search_matches(c jsonb, v jsonb, brand text, model text)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare k text; pair text[]; expected text; actual text; bound numeric; val numeric; word text; document text;
begin
  if jsonb_typeof(c)<>'object' then return false; end if;
  if coalesce(c->>'vehicle_category','car')<>coalesce(v->>'vehicle_category','car') then return false;end if;
  if not private.category_search_matches(c->'category_filters',v->'category_details',coalesce(v->>'vehicle_category','car')) then return false;end if;
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
  if c ? 'locality' and not private.market_radius_matches(c,v->'market_facts') then return false; end if;
  return true;
end; $function$
;

CREATE OR REPLACE FUNCTION private.community_overview()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare result jsonb;
begin
 if not private.is_community_moderator() then raise exception 'Moderator access required' using errcode='42501'; end if;
 select jsonb_build_object(
  'open_reports',(select count(*) from public.vehicle_listing_reports where status in ('pending','reviewing'))+(select count(*) from private.chat_reports where status in ('pending','reviewing')),
  'drafts',(select count(*) from public.vehicle_listings where status='draft'),
  'pending_checks',(select count(*) from private.listing_content_checks c join public.vehicle_listings v on v.id=c.listing_id where v.status='draft' and (c.state='changed' or c.state='processing' and c.lease_until>=now())),
  'failed_checks',(select count(*) from private.listing_content_checks c join public.vehicle_listings v on v.id=c.listing_id where v.status='draft' and (c.state in ('error','rejected') or c.state='processing' and c.lease_until<now())),
  'checks',coalesce((select jsonb_agg(to_jsonb(q)) from (
    select v.id listing_id,concat_ws(' ',coalesce(v.declared_brand,b.name),coalesce(v.declared_model,m.name),v.year::text) title,
     case when c.state='processing' and c.lease_until<now() then 'error' else c.state end state,c.report_id,c.requested_at
    from private.listing_content_checks c join public.vehicle_listings v on v.id=c.listing_id
    left join public.vehicle_brands b on b.id=v.brand_id left join public.vehicle_models m on m.id=v.model_id
    where v.status='draft' and c.state<>'approved' order by c.requested_at desc,c.listing_id limit 100
  )q),'[]'::jsonb)
 ) into result;
 return result;
end; $function$
;

CREATE OR REPLACE FUNCTION private.create_buyer_watch_alerts()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  brand:=coalesce(new.declared_brand,brand);model:=coalesce(new.declared_model,model);
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
end; $function$
;

CREATE OR REPLACE FUNCTION private.listing_content_hash(p_row jsonb)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select encode(sha256(convert_to(jsonb_build_object('listing',
 (case when p_row->'market_facts' is null or p_row->'market_facts' in ('null'::jsonb,'{}'::jsonb) then p_row-'market_facts' else p_row end)
 -(case when coalesce(p_row->>'vehicle_category','car')='car' and coalesce(p_row->'category_details','{}')='{}'::jsonb and p_row->>'declared_brand' is null and p_row->>'declared_model' is null then array['vehicle_category','category_details','declared_brand','declared_model'] else array[]::text[] end)
 -array['status','updated_at','created_at','sold_at','sold_to_buyer_id','sold_externally'],
 'photos',private.listing_photo_manifest((p_row->>'id')::uuid))::text,'UTF8')),'hex');
$function$;;


create or replace function private.record_client_error(p_category text,p_code text,p_build integer) returns void language plpgsql security definer set search_path='' as $$
begin
 if not private.current_account_active() or not exists(select 1 from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id' and(not_after is null or not_after>now())) then raise exception 'Sign in required' using errcode='42501';end if;
 if p_category not in ('app','catalogue','publication','photo','chat','purchase') or p_code not in ('network','permission','unavailable','unknown') or (p_build is null or p_build not in (40,41,42,43,44,45,46,47,48,49,50,51)) then raise exception 'Invalid diagnostic category';end if;
 insert into private.client_error_totals(day,category,code,app_build)values((now() at time zone 'UTC')::date,p_category,p_code,p_build)
 on conflict(day,category,code,app_build)do update set occurrences=private.client_error_totals.occurrences+1,last_seen=now() where private.client_error_totals.last_seen<now()-interval '15 seconds';
 delete from private.client_error_totals where day<current_date-30;
end;$$;
create or replace function private.record_market_usage(p_stage text,p_build integer) returns void language plpgsql security definer set search_path='' as $$
begin
 if not private.metrics_actor_active() then raise exception 'Active session required' using errcode='42501';end if;
 if p_stage is null or p_stage not in ('catalogue','detail','contact','publication_start','publication_complete') or (p_build is null or p_build not in (45,46,47,48,49,50,51)) then raise exception 'Invalid usage stage';end if;
 insert into private.market_usage_totals(day,stage,app_build)values((now() at time zone 'UTC')::date,p_stage,p_build)
 on conflict(day,stage,app_build)do update set occurrences=private.market_usage_totals.occurrences+1,last_seen=now() where private.market_usage_totals.last_seen<now()-interval '15 seconds';
 delete from private.market_usage_totals where day<current_date-30;
end;$$;




commit;
