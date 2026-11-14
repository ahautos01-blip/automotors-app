-- Accept the new app build without changing access or collected fields.
create or replace function private.record_client_error(p_category text,p_code text,p_build integer) returns void language plpgsql security definer set search_path='' as $$
begin
 if not private.current_account_active() or not exists(select 1 from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id' and(not_after is null or not_after>now())) then raise exception 'Sign in required' using errcode='42501';end if;
 if p_category not in ('app','catalogue','publication','photo','chat','purchase') or p_code not in ('network','permission','unavailable','unknown') or (p_build is null or p_build not in (40,41)) then raise exception 'Invalid diagnostic category';end if;
 insert into private.client_error_totals(day,category,code,app_build)values((now() at time zone 'UTC')::date,p_category,p_code,p_build)
 on conflict(day,category,code,app_build)do update set occurrences=private.client_error_totals.occurrences+1,last_seen=now() where private.client_error_totals.last_seen<now()-interval '15 seconds';
 delete from private.client_error_totals where day<current_date-30;
end;$$;
