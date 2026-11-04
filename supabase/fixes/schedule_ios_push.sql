-- The worker authenticates this private credential; no service key is stored in cron.
begin;
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;
create function private.dispatch_ios_push(p_force boolean default false) returns bigint
language plpgsql security definer set search_path='' as $$
declare request_id bigint;
begin
  if auth.uid() is not null then raise exception 'Server only' using errcode='42501'; end if;
  if not p_force and not exists(select 1 from private.push_deliveries where status='pending' and available_at<=now()) then return null; end if;
  select net.http_post(
    url:='https://ndicdhlpbyywqyjgxpnx.supabase.co/functions/v1/send-ios-push',
    headers:=jsonb_build_object('Content-Type','application/json','x-worker-token',worker_token),
    body:='{}'::jsonb,timeout_milliseconds:=60000
  ) into request_id from private.push_worker_config where singleton;
  return request_id;
end; $$;
revoke all on function private.dispatch_ios_push(boolean) from public,anon,authenticated;
select cron.schedule('automotors-ios-push','* * * * *','select private.dispatch_ios_push();');
commit;
