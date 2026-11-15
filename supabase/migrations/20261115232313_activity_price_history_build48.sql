begin;
-- Public prices only, never draft prices or retrospective invented changes.
create table public.listing_price_history(
 id bigint generated always as identity primary key,
 listing_id uuid not null references public.vehicle_listings(id) on delete cascade,
 price numeric not null check(price>0),recorded_at timestamptz not null default clock_timestamp()
);
alter table public.listing_price_history enable row level security;
revoke all on public.listing_price_history from public,anon,authenticated;
grant select on public.listing_price_history to anon,authenticated;
create index listing_price_history_listing_time_idx on public.listing_price_history(listing_id,recorded_at desc,id desc);
create policy visible_listing_price_history on public.listing_price_history for select to anon,authenticated using(
 exists(select 1 from public.vehicle_listings l where l.id=listing_id and l.status in ('published','reserved'))
);
create function private.capture_public_listing_price()returns trigger language plpgsql security definer set search_path='' as $$
declare previous numeric;
begin
 if new.status not in ('published','reserved') or new.price is null or new.price<=0 then return new;end if;
 if not private.listing_not_held(new.id) then return new;end if;
 select h.price into previous from public.listing_price_history h where h.listing_id=new.id order by h.recorded_at desc,h.id desc limit 1;
 if previous is distinct from new.price then insert into public.listing_price_history(listing_id,price)values(new.id,new.price);end if;
 return new;
end;$$;
revoke all on function private.capture_public_listing_price() from public,anon,authenticated;
create trigger zz_capture_public_listing_price after insert or update of price,status on public.vehicle_listings for each row execute function private.capture_public_listing_price();
-- Establish only today's visible baseline; do not infer historical prices.
insert into public.listing_price_history(listing_id,price) select id,price from public.vehicle_listings where status in ('published','reserved') and price>0 and private.listing_not_held(id);

create function public.my_market_activity()returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare offers jsonb;visits jsonb;unread bigint;
begin
 if not private.metrics_actor_active() then raise exception 'Active session required' using errcode='42501';end if;
 select coalesce(jsonb_agg(to_jsonb(q) order by expires_at),'[]'::jsonb)into offers from(
 select a.id,c.id::text conversation_id,a.expires_at,case when c.seller_id=auth.uid() then 'seller' else 'buyer' end role
 from public.chat_market_activities a join public.chat_conversations c on c.id=a.conversation_id join public.vehicle_listings l on l.id=c.listing_id
 where auth.uid() in (c.buyer_id,c.seller_id) and a.kind='offer' and a.status='pending' and a.creator_id<>auth.uid() and a.expires_at>now() and l.status in ('published','reserved')
 and private.chat_pair_allowed(c.buyer_id,c.seller_id) and private.listing_not_held(l.id)
 order by a.expires_at limit 50)q;
 select coalesce(jsonb_agg(to_jsonb(q) order by scheduled_at),'[]'::jsonb)into visits from(
 select a.id,c.id::text conversation_id,a.scheduled_at
 from public.chat_market_activities a join public.chat_conversations c on c.id=a.conversation_id join public.vehicle_listings l on l.id=c.listing_id
 where auth.uid() in (c.buyer_id,c.seller_id) and a.kind='visit' and a.status='accepted' and a.scheduled_at>now() and a.scheduled_at<=now()+interval '30 days' and l.status in ('published','reserved')
 and private.chat_pair_allowed(c.buyer_id,c.seller_id) and private.listing_not_held(l.id)
 order by a.scheduled_at limit 50)q;
 select public.chat_inbox_unread_count() into unread;
 return jsonb_build_object('offers',offers,'visits',visits,'unread_conversations',unread);
end;$$;
revoke all on function public.my_market_activity() from public,anon;
grant execute on function public.my_market_activity() to authenticated;
create or replace function private.record_client_error(p_category text,p_code text,p_build integer) returns void language plpgsql security definer set search_path='' as $$
begin
 if not private.current_account_active() or not exists(select 1 from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id' and(not_after is null or not_after>now())) then raise exception 'Sign in required' using errcode='42501';end if;
 if p_category not in ('app','catalogue','publication','photo','chat','purchase') or p_code not in ('network','permission','unavailable','unknown') or (p_build is null or p_build not in (40,41,42,43,44,45,46,47,48)) then raise exception 'Invalid diagnostic category';end if;
 insert into private.client_error_totals(day,category,code,app_build)values((now() at time zone 'UTC')::date,p_category,p_code,p_build)
 on conflict(day,category,code,app_build)do update set occurrences=private.client_error_totals.occurrences+1,last_seen=now() where private.client_error_totals.last_seen<now()-interval '15 seconds';
 delete from private.client_error_totals where day<current_date-30;
end;$$;
create or replace function private.record_market_usage(p_stage text,p_build integer) returns void language plpgsql security definer set search_path='' as $$
begin
 if not private.metrics_actor_active() then raise exception 'Active session required' using errcode='42501';end if;
 if p_stage is null or p_stage not in ('catalogue','detail','contact','publication_start','publication_complete') or (p_build is null or p_build not in (45,46,47,48)) then raise exception 'Invalid usage stage';end if;
 insert into private.market_usage_totals(day,stage,app_build)values((now() at time zone 'UTC')::date,p_stage,p_build)
 on conflict(day,stage,app_build)do update set occurrences=private.market_usage_totals.occurrences+1,last_seen=now() where private.market_usage_totals.last_seen<now()-interval '15 seconds';
 delete from private.market_usage_totals where day<current_date-30;
end;$$;


commit;
