-- Integration test. No message, token, session or queue entry is committed.
begin;
do $test$
declare
  c public.chat_conversations;
  buyer_session uuid:=gen_random_uuid();
  seller_session uuid:=gen_random_uuid();
  buyer_device uuid;
  seller_device uuid;
  message bigint;
  worker text;
  jobs jsonb;
  job jsonb;
begin
  select cc.* into c from public.chat_conversations cc join public.vehicle_listings v on v.id=cc.listing_id
    where v.status='sold' and v.sold_to_buyer_id=cc.buyer_id and v.owner_id=cc.seller_id limit 1;
  if c.id is null then raise exception 'A verified sale is required for this integration test'; end if;
  insert into auth.sessions(id,user_id,created_at,updated_at) values
    (buyer_session,c.buyer_id,now(),now()),(seller_session,c.seller_id,now(),now());
  perform set_config('request.jwt.claim.sub',c.buyer_id::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',c.buyer_id,'session_id',buyer_session,'role','authenticated')::text,true);
  set local role authenticated;
  perform public.register_push_device(repeat('a',64),'sandbox');
  select id into buyer_device from public.push_devices where token=repeat('a',64);
  reset role;
  perform set_config('request.jwt.claim.sub',c.seller_id::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',c.seller_id,'session_id',seller_session,'role','authenticated')::text,true);
  set local role authenticated;
  perform public.register_push_device(repeat('b',64),'production');
  select id into seller_device from public.push_devices where token=repeat('b',64);
  if exists(select 1 from public.push_devices where id=buyer_device) then raise exception 'Device token RLS leak'; end if;
  begin
    perform public.claim_push_deliveries(repeat('0',64));
    raise exception 'Authenticated client accessed worker';
  exception when insufficient_privilege then null; end;
  reset role;
  -- A new buyer message must notify only the seller, never the sender.
  perform set_config('request.jwt.claim.sub',c.buyer_id::text,true);
  set local role authenticated;
  insert into public.chat_messages(conversation_id,sender_id,body)
    values(c.id,c.buyer_id,'ROLLBACK ONLY: APNs integration test') returning id into message;
  reset role;
  if not exists(select 1 from private.push_deliveries where device_id=seller_device and message_id=message)
     or exists(select 1 from private.push_deliveries where device_id=buyer_device and message_id=message) then
    raise exception 'Incorrect chat notification recipient';
  end if;
  if not exists(select 1 from private.push_deliveries where device_id=buyer_device and kind='review_requested') then
    raise exception 'Missing recovered review push';
  end if;
  select worker_token into worker from private.push_worker_config;
  set local role service_role;
  begin
    perform public.claim_push_deliveries(repeat('0',64));
    raise exception 'Wrong worker credential accepted';
  exception when insufficient_privilege then null; end;
  jobs:=public.claim_push_deliveries(worker);
  if jsonb_array_length(jobs)<>2 then raise exception 'Unexpected claim count'; end if;
  if public.claim_push_deliveries(worker)<>'[]'::jsonb then raise exception 'Leased jobs claimed twice'; end if;
  job:=jobs->0;
  perform public.finish_push_delivery((job->>'id')::uuid,gen_random_uuid(),'sent');
  reset role;
  if (select status from private.push_deliveries where id=(job->>'id')::uuid)<>'pending' then raise exception 'Stale lease completed a job'; end if;
  set local role service_role;
  perform public.finish_push_delivery((job->>'id')::uuid,(job->>'lease_token')::uuid,'sent');
  reset role;
  if (select status from private.push_deliveries where id=(job->>'id')::uuid)<>'sent' then raise exception 'Completion missing'; end if;
  -- Reading a message before dispatch cancels its outstanding push.
  update private.push_deliveries set status='pending',lease_token=null,lease_until=null where message_id=message;
  update public.chat_messages set read_at=now() where id=message;
  set local role service_role;
  perform public.claim_push_deliveries(worker);
  reset role;
  if (select status from private.push_deliveries where message_id=message)<>'discarded' then raise exception 'Read message was not discarded'; end if;
  -- Token rebinding clears the previous account's deliveries.
  perform set_config('request.jwt.claim.sub',c.seller_id::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',c.seller_id,'session_id',seller_session,'role','authenticated')::text,true);
  set local role authenticated;
  perform public.register_push_device(repeat('a',64),'sandbox');
  reset role;
  if exists(select 1 from private.push_deliveries where device_id=buyer_device) then raise exception 'Previous account queue retained'; end if;
  delete from auth.sessions where id in (buyer_session,seller_session);
  if exists(select 1 from public.push_devices where id in (buyer_device,seller_device)) then raise exception 'Revoked session retained device'; end if;
end;
$test$;
rollback;
select 'Passed: chat recipient, no self notification, review recovery, token isolation, worker authentication, leases, stale callbacks, read suppression, account rebinding, logout cleanup. All test writes rolled back.' as verification;
