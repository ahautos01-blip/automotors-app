begin;
create table private.chat_inbox_preferences(
 user_id uuid not null references auth.users(id) on delete cascade,
 conversation_id bigint not null references public.chat_conversations(id) on delete cascade,
 deleted_at timestamptz,pinned_at timestamptz,
 primary key(user_id,conversation_id)
);
alter table private.chat_inbox_preferences enable row level security;
revoke all on private.chat_inbox_preferences from public,anon,authenticated;
create index chat_inbox_conversation_idx on private.chat_inbox_preferences(conversation_id);
create index chat_inbox_latest_message_idx on public.chat_messages(conversation_id,created_at desc,id desc);
create index chat_inbox_unread_idx on public.chat_messages(conversation_id,sender_id) where read_at is null;

create function private.my_chat_inbox_flags() returns table(conversation_id bigint,deleted_at timestamptz,pinned_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if not private.metrics_actor_active() then raise exception 'Active session required' using errcode='42501';end if;
 return query select p.conversation_id,p.deleted_at,p.pinned_at from private.chat_inbox_preferences p
 join public.chat_conversations c on c.id=p.conversation_id
 where p.user_id=(select auth.uid()) and (select auth.uid()) in (c.buyer_id,c.seller_id);
end;$$;
revoke all on function private.my_chat_inbox_flags() from public,anon;
grant execute on function private.my_chat_inbox_flags() to authenticated;

create function private.chat_inbox_action(p_conversation_id bigint,p_action text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not private.metrics_actor_active() then raise exception 'Active session required' using errcode='42501';end if;
 if p_action is null or p_action not in ('hide','restore','pin','unpin') then raise exception 'Invalid inbox action' using errcode='22023';end if;
 perform 1 from public.chat_conversations c where c.id=p_conversation_id and (select auth.uid()) in (c.buyer_id,c.seller_id) for update;
 if not found then raise exception 'Conversation unavailable' using errcode='42501';end if;
 insert into private.chat_inbox_preferences(user_id,conversation_id)values(auth.uid(),p_conversation_id)on conflict do nothing;
 if p_action='hide' then update private.chat_inbox_preferences set deleted_at=now(),pinned_at=null where user_id=auth.uid() and conversation_id=p_conversation_id;
 elsif p_action='restore' then update private.chat_inbox_preferences set deleted_at=null where user_id=auth.uid() and conversation_id=p_conversation_id;
 elsif p_action='pin' then update private.chat_inbox_preferences set pinned_at=now(),deleted_at=null where user_id=auth.uid() and conversation_id=p_conversation_id;
 else update private.chat_inbox_preferences set pinned_at=null where user_id=auth.uid() and conversation_id=p_conversation_id;
 end if;
end;$$;
revoke all on function private.chat_inbox_action(bigint,text) from public,anon;
grant execute on function private.chat_inbox_action(bigint,text) to authenticated;
create function public.chat_inbox_action(p_conversation_id bigint,p_action text)returns void language sql security invoker set search_path='' as $$select private.chat_inbox_action(p_conversation_id,p_action);$$;
revoke all on function public.chat_inbox_action(bigint,text) from public,anon;
grant execute on function public.chat_inbox_action(bigint,text) to authenticated;

-- Public reads remain invoker functions: conversation and message RLS still apply.
create function public.chat_inbox_snapshot() returns jsonb language sql stable security invoker set search_path='' as $$
 with flags as materialized(select * from private.my_chat_inbox_flags()), items as(
 select c.id::text as id,c.listing_id,c.buyer_id,c.seller_id,c.updated_at,
 coalesce(f.deleted_at is not null,false) as deleted,coalesce(f.pinned_at is not null,false) as pinned,f.pinned_at,
 left(m.body,180) as last_message,m.created_at as last_message_at,coalesce(m.sender_id=auth.uid(),false) as last_message_by_me,
 (select count(*) from public.chat_messages u where u.conversation_id=c.id and u.sender_id<>auth.uid() and u.read_at is null) as unread_count
 from public.chat_conversations c left join flags f on f.conversation_id=c.id
 left join lateral(select body,created_at,sender_id from public.chat_messages t where t.conversation_id=c.id order by t.created_at desc,t.id desc limit 1)m on true
 where auth.uid() in (c.buyer_id,c.seller_id) and private.metrics_actor_active()
 )select coalesce(jsonb_agg(to_jsonb(items) order by pinned desc,pinned_at desc nulls last,coalesce(last_message_at,updated_at) desc,id),'[]'::jsonb) from items;
$$;
revoke all on function public.chat_inbox_snapshot() from public,anon;
grant execute on function public.chat_inbox_snapshot() to authenticated;
create function public.chat_inbox_unread_count() returns bigint language sql stable security invoker set search_path='' as $$
 with flags as materialized(select * from private.my_chat_inbox_flags())
 select count(distinct c.id) from public.chat_conversations c join public.chat_messages m on m.conversation_id=c.id
 left join flags f on f.conversation_id=c.id
 where auth.uid() in (c.buyer_id,c.seller_id) and m.sender_id<>auth.uid() and m.read_at is null and f.deleted_at is null and private.metrics_actor_active();
$$;
revoke all on function public.chat_inbox_unread_count() from public,anon;
grant execute on function public.chat_inbox_unread_count() to authenticated;

-- A fresh message restores visibility but never erases old messages or blocks anyone.
create function private.reopen_chat_inbox_on_message() returns trigger language plpgsql security definer set search_path='' as $$
declare c public.chat_conversations;
begin
 select * into c from public.chat_conversations where id=new.conversation_id for update;
 if not found or new.sender_id is null or new.sender_id not in (c.buyer_id,c.seller_id) then return new;end if;
 update private.chat_inbox_preferences set deleted_at=null where conversation_id=c.id and user_id in (c.buyer_id,c.seller_id) and deleted_at is not null;
 return new;
end;$$;
revoke all on function private.reopen_chat_inbox_on_message() from public,anon,authenticated;
create trigger zz_reopen_chat_inbox after insert on public.chat_messages for each row execute function private.reopen_chat_inbox_on_message();
comment on table private.chat_inbox_preferences is 'Per-participant inbox organization only. No messages deleted. New messages restore visibility; personal organization actions never change the other participant preferences.';
create or replace function private.record_client_error(p_category text,p_code text,p_build integer) returns void language plpgsql security definer set search_path='' as $$
begin
 if not private.current_account_active() or not exists(select 1 from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id' and(not_after is null or not_after>now())) then raise exception 'Sign in required' using errcode='42501';end if;
 if p_category not in ('app','catalogue','publication','photo','chat','purchase') or p_code not in ('network','permission','unavailable','unknown') or (p_build is null or p_build not in (40,41,42,43,44,45,46,47)) then raise exception 'Invalid diagnostic category';end if;
 insert into private.client_error_totals(day,category,code,app_build)values((now() at time zone 'UTC')::date,p_category,p_code,p_build)
 on conflict(day,category,code,app_build)do update set occurrences=private.client_error_totals.occurrences+1,last_seen=now() where private.client_error_totals.last_seen<now()-interval '15 seconds';
 delete from private.client_error_totals where day<current_date-30;
end;$$;
create or replace function private.record_market_usage(p_stage text,p_build integer) returns void language plpgsql security definer set search_path='' as $$
begin
 if not private.metrics_actor_active() then raise exception 'Active session required' using errcode='42501';end if;
 if p_stage is null or p_stage not in ('catalogue','detail','contact','publication_start','publication_complete') or (p_build is null or p_build not in (45,46,47)) then raise exception 'Invalid usage stage';end if;
 insert into private.market_usage_totals(day,stage,app_build)values((now() at time zone 'UTC')::date,p_stage,p_build)
 on conflict(day,stage,app_build)do update set occurrences=private.market_usage_totals.occurrences+1,last_seen=now() where private.market_usage_totals.last_seen<now()-interval '15 seconds';
 delete from private.market_usage_totals where day<current_date-30;
end;$$;

commit;
