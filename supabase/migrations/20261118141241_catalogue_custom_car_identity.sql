begin;
-- The owner may declare a make/model absent from the reference catalogue.
-- Free names are part of the existing moderation text and content fingerprint.
-- Keep real catalogue FKs for existing cars; never write local suggestion IDs.
alter table public.vehicle_listings drop constraint vehicle_category_identity_valid;
alter table public.vehicle_listings add constraint vehicle_category_identity_valid check(
 (vehicle_category='car' and brand_id is not null and model_id is not null and brand_id>0 and model_id>0 and declared_brand is null and declared_model is null)
 or (brand_id is null and model_id is null and declared_brand is not null and declared_model is not null and length(trim(declared_brand)) between 1 and 80 and length(trim(declared_model)) between 1 and 100)
);
create or replace function private.record_client_error(p_category text,p_code text,p_build integer) returns void language plpgsql security definer set search_path='' as $$
begin
 if not private.current_account_active() or not exists(select 1 from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id' and(not_after is null or not_after>now())) then raise exception 'Sign in required' using errcode='42501';end if;
 if p_category not in ('app','catalogue','publication','photo','chat','purchase') or p_code not in ('network','permission','unavailable','unknown') or (p_build is null or p_build not in (40,41,42,43,44,45,46,47,48,49,50,51,52)) then raise exception 'Invalid diagnostic category';end if;
 insert into private.client_error_totals(day,category,code,app_build)values((now() at time zone 'UTC')::date,p_category,p_code,p_build)
 on conflict(day,category,code,app_build)do update set occurrences=private.client_error_totals.occurrences+1,last_seen=now() where private.client_error_totals.last_seen<now()-interval '15 seconds';
 delete from private.client_error_totals where day<current_date-30;
end;$$;
create or replace function private.record_market_usage(p_stage text,p_build integer) returns void language plpgsql security definer set search_path='' as $$
begin
 if not private.metrics_actor_active() then raise exception 'Active session required' using errcode='42501';end if;
 if p_stage is null or p_stage not in ('catalogue','detail','contact','publication_start','publication_complete') or (p_build is null or p_build not in (45,46,47,48,49,50,51,52)) then raise exception 'Invalid usage stage';end if;
 insert into private.market_usage_totals(day,stage,app_build)values((now() at time zone 'UTC')::date,p_stage,p_build)
 on conflict(day,stage,app_build)do update set occurrences=private.market_usage_totals.occurrences+1,last_seen=now() where private.market_usage_totals.last_seen<now()-interval '15 seconds';
 delete from private.market_usage_totals where day<current_date-30;
end;$$;





commit;
