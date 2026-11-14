-- Offer events become genuine conversation messages and reuse existing unread/push delivery.
create or replace function private.queue_market_activity()returns trigger language plpgsql security definer set search_path='' as $$
declare c public.chat_conversations; recipient uuid;
begin
 if new.status='expired' then return new;end if;
 if TG_OP='UPDATE' and old.status=new.status then return new;end if;
 if new.kind='offer' then
  insert into public.chat_messages(conversation_id,sender_id,body)
  values(new.conversation_id,case when TG_OP='INSERT' then new.creator_id else auth.uid() end,
   case new.status when 'pending' then 'Oferta de compra: ' when 'accepted' then 'Oferta aceptada: '
    when 'rejected' then 'Oferta rechazada: ' else 'Oferta cancelada: ' end
   ||replace(to_char(new.amount,'FM999999990.00'),'.',',')||' €. Abre «Ofertas y citas» para consultar la propuesta.');
  return new;
 end if;
 select * into c from public.chat_conversations where id=new.conversation_id;
 recipient:=case when auth.uid()=c.buyer_id then c.seller_id else c.buyer_id end;
 insert into private.push_deliveries(device_id,user_id,event_key,kind,listing_id,conversation_id,activity_id)
 select d.id,recipient,'activity:'||new.id||':'||new.status,'chat_activity',c.listing_id,c.id,new.id from public.push_devices d
 where d.user_id=recipient and d.active and d.market_actions and private.market_delivery_allowed(recipient,new.id,false)
 on conflict(device_id,event_key)do nothing;
 if new.kind='visit' and new.status='accepted' then
  insert into private.push_deliveries(device_id,user_id,event_key,kind,listing_id,conversation_id,activity_id,available_at)
  select d.id,d.user_id,'reminder:'||new.id,'visit_reminder',c.listing_id,c.id,new.id,greatest(now()+interval '1 minute',new.scheduled_at-interval '1 hour') from public.push_devices d
  where d.user_id in(c.buyer_id,c.seller_id) and d.active and d.market_actions and private.market_delivery_allowed(d.user_id,new.id,true)
  on conflict(device_id,event_key)do nothing;
 end if;return new;
end;$$;

-- Accept the new app build without changing access or collected fields.
create or replace function private.record_client_error(p_category text,p_code text,p_build integer) returns void language plpgsql security definer set search_path='' as $$
begin
 if not private.current_account_active() or not exists(select 1 from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id' and(not_after is null or not_after>now())) then raise exception 'Sign in required' using errcode='42501';end if;
 if p_category not in ('app','catalogue','publication','photo','chat','purchase') or p_code not in ('network','permission','unavailable','unknown') or (p_build is null or p_build not in (40,41,42)) then raise exception 'Invalid diagnostic category';end if;
 insert into private.client_error_totals(day,category,code,app_build)values((now() at time zone 'UTC')::date,p_category,p_code,p_build)
 on conflict(day,category,code,app_build)do update set occurrences=private.client_error_totals.occurrences+1,last_seen=now() where private.client_error_totals.last_seen<now()-interval '15 seconds';
 delete from private.client_error_totals where day<current_date-30;
end;$$;
