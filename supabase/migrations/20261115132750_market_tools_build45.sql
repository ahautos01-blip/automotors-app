begin;
alter table public.vehicle_listings add column market_facts jsonb;
create function private.valid_market_facts(f jsonb) returns boolean language plpgsql immutable set search_path='' as $$
declare k text; loc jsonb; n numeric;
begin
 if f is null then return true; end if;
 if jsonb_typeof(f)<>'object' or octet_length(f::text)>3000 then return false; end if;
 for k in select jsonb_object_keys(f) loop
  if k not in ('maintenance','itv','itv_until','warranty','defects','locality') then return false;end if;
 end loop;
 if f ? 'maintenance' and coalesce(f->>'maintenance','') not in ('unknown','documented','partial','none') then return false;end if;
 if f ? 'itv' and coalesce(f->>'itv','') not in ('unknown','valid','expired','not_required') then return false;end if;
 if f ? 'warranty' and coalesce(f->>'warranty','') not in ('unknown','included','none') then return false;end if;
 if f ? 'defects' and (jsonb_typeof(f->'defects')<>'string' or length(f->>'defects')>1000) then return false;end if;
 if coalesce(f->>'itv_until','')<>'' then
  if f->>'itv_until' !~ '^\d{4}-\d{2}-\d{2}$' then return false;end if;
  perform (f->>'itv_until')::date;
 end if;
 loc:=f->'locality';
 if loc is not null and loc<>'null'::jsonb then
  if jsonb_typeof(loc)<>'object' or (select count(*) from jsonb_object_keys(loc))<>4 or not (loc ?& array['id','label','lat','lon']) then return false;end if;
  if jsonb_typeof(loc->'label')<>'string' or length(loc->>'label') not between 2 and 120 or jsonb_typeof(loc->'id')<>'string' or length(loc->>'id') not between 1 and 80 then return false;end if;
  if jsonb_typeof(loc->'lat')<>'number' or jsonb_typeof(loc->'lon')<>'number' then return false;end if;
  n:=(loc->>'lat')::numeric;if n not between 27 and 44 or n<>round(n,2) then return false;end if;
  n:=(loc->>'lon')::numeric;if n not between -19 and 5 or n<>round(n,2) then return false;end if;
 end if;
 return true;
exception when others then return false;
end;$$;
revoke all on function private.valid_market_facts(jsonb) from public,anon;
grant execute on function private.valid_market_facts(jsonb) to authenticated,service_role;
alter table public.vehicle_listings add constraint market_facts_valid check(private.valid_market_facts(market_facts));
-- Keep existing approvals byte-compatible when the new optional data is absent.
-- Existing full-row hashing and provider snapshots already cover every non-null fact.
create or replace function private.listing_content_hash(p_row jsonb) returns text language sql stable security definer set search_path='' as $$
 select encode(sha256(convert_to(jsonb_build_object('listing',
 (case when p_row->'market_facts' is null or p_row->'market_facts' in ('null'::jsonb,'{}'::jsonb) then p_row-'market_facts' else p_row end)
 -array['status','updated_at','created_at','sold_at','sold_to_buyer_id','sold_externally'],
 'photos',private.listing_photo_manifest((p_row->>'id')::uuid))::text,'UTF8')),'hex');
$$;

create function private.market_radius_matches(c jsonb,f jsonb) returns boolean language plpgsql immutable set search_path='' as $$
declare a numeric;b numeric;x numeric;y numeric;r numeric;distance double precision;
begin
 a:=private.buyer_number(c->'locality'->>'lat');b:=(c->'locality'->>'lon')::numeric;
 x:=private.buyer_number(f->'locality'->>'lat');y:=(f->'locality'->>'lon')::numeric;r:=private.buyer_number(c->>'radius_km');
 if a is null or b is null or x is null or y is null or r is null or a not between 27 and 44 or x not between 27 and 44 or b not between -19 and 5 or y not between -19 and 5 or r not between 10 and 500 then return false;end if;
 distance:=6371*acos(least(1.0,greatest(-1.0,sin(radians(a::double precision))*sin(radians(x::double precision))+cos(radians(a::double precision))*cos(radians(x::double precision))*cos(radians((y-b)::double precision)))));
 return distance<=r;
exception when others then return false;
end;$$;
revoke all on function private.market_radius_matches(jsonb,jsonb) from public,anon,authenticated;
create or replace function private.buyer_search_matches(c jsonb,v jsonb,brand text,model text) returns boolean
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
  if c ? 'locality' and not private.market_radius_matches(c,v->'market_facts') then return false; end if;
  return true;
end; $$;

create function private.my_market_dashboard() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare n bigint;
begin
 if not private.metrics_actor_active() then raise exception 'Active session required' using errcode='42501';end if;
 select count(*) into n from public.chat_market_activities a
 join public.chat_conversations c on c.id=a.conversation_id
 join public.vehicle_listings l on l.id=c.listing_id
 where c.seller_id=auth.uid() and l.owner_id=auth.uid() and a.creator_id<>auth.uid() and a.kind='offer' and a.status='pending' and a.expires_at>now()
 and l.status in ('published','reserved') and private.chat_pair_allowed(c.buyer_id,c.seller_id) and private.listing_not_held(l.id);
 return jsonb_build_object('pending_offers',n);
end;$$;
revoke all on function private.my_market_dashboard() from public,anon;
grant execute on function private.my_market_dashboard() to authenticated;
create function public.my_market_dashboard() returns jsonb language sql stable security invoker set search_path='' as $$select private.my_market_dashboard();$$;
revoke all on function public.my_market_dashboard() from public,anon;
grant execute on function public.my_market_dashboard() to authenticated;

create table private.market_usage_totals(day date not null,stage text not null,app_build integer not null,occurrences bigint not null default 1,last_seen timestamptz not null default now(),primary key(day,stage,app_build));
alter table private.market_usage_totals enable row level security;
revoke all on private.market_usage_totals from public,anon,authenticated;
create function private.record_market_usage(p_stage text,p_build integer) returns void language plpgsql security definer set search_path='' as $$
begin
 if not private.metrics_actor_active() then raise exception 'Active session required' using errcode='42501';end if;
 if p_stage is null or p_stage not in ('catalogue','detail','contact','publication_start','publication_complete') or p_build is distinct from 45 then raise exception 'Invalid usage stage';end if;
 insert into private.market_usage_totals(day,stage,app_build)values((now() at time zone 'UTC')::date,p_stage,p_build)
 on conflict(day,stage,app_build)do update set occurrences=private.market_usage_totals.occurrences+1,last_seen=now() where private.market_usage_totals.last_seen<now()-interval '15 seconds';
 delete from private.market_usage_totals where day<current_date-30;
end;$$;
revoke all on function private.record_market_usage(text,integer) from public,anon;
grant execute on function private.record_market_usage(text,integer) to authenticated;
create function public.record_market_usage(p_stage text,p_build integer) returns void language sql security invoker set search_path='' as $$select private.record_market_usage(p_stage,p_build);$$;
revoke all on function public.record_market_usage(text,integer) from public,anon;
grant execute on function public.record_market_usage(text,integer) to authenticated;
create function private.market_usage_summary() returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not private.metrics_actor_active() or not private.is_community_moderator() then raise exception 'Moderator required' using errcode='42501';end if;
 return coalesce((select jsonb_agg(to_jsonb(t)-'last_seen' order by t.day desc,t.stage) from private.market_usage_totals t where t.day>=current_date-6),'[]'::jsonb);
end;$$;
revoke all on function private.market_usage_summary() from public,anon;
grant execute on function private.market_usage_summary() to authenticated;
create function public.market_usage_summary() returns jsonb language sql stable security invoker set search_path='' as $$select private.market_usage_summary();$$;
revoke all on function public.market_usage_summary() from public,anon;
grant execute on function public.market_usage_summary() to authenticated;
commit;
