-- Generate due reminders before checking whether the network worker has work.
create or replace function private.dispatch_ios_push(p_force boolean default false) returns bigint
language plpgsql security definer set search_path='' as $$
declare request_id bigint;
begin
  if auth.uid() is not null then raise exception 'Server only' using errcode='42501'; end if;
  perform private.queue_offer_expiry_reminders();
  if not p_force and not exists(select 1 from private.push_deliveries where status='pending' and available_at<=now()) then return null; end if;
  select net.http_post(
    url:='https://ndicdhlpbyywqyjgxpnx.supabase.co/functions/v1/send-ios-push',
    headers:=jsonb_build_object('Content-Type','application/json','x-worker-token',worker_token),
    body:='{}'::jsonb,timeout_milliseconds:=60000
  ) into request_id from private.push_worker_config where singleton;
  return request_id;
end; $$;
