begin;
-- A read-only overview, protected by the existing live-session moderator check.
create function private.community_overview() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not private.is_community_moderator() then raise exception 'Moderator access required' using errcode='42501'; end if;
 select jsonb_build_object(
  'open_reports',(select count(*) from public.vehicle_listing_reports where status in ('pending','reviewing'))+(select count(*) from private.chat_reports where status in ('pending','reviewing')),
  'drafts',(select count(*) from public.vehicle_listings where status='draft'),
  'pending_checks',(select count(*) from private.listing_content_checks c join public.vehicle_listings v on v.id=c.listing_id where v.status='draft' and (c.state='changed' or c.state='processing' and c.lease_until>=now())),
  'failed_checks',(select count(*) from private.listing_content_checks c join public.vehicle_listings v on v.id=c.listing_id where v.status='draft' and (c.state in ('error','rejected') or c.state='processing' and c.lease_until<now())),
  'checks',coalesce((select jsonb_agg(to_jsonb(q)) from (
    select v.id listing_id,concat_ws(' ',b.name,m.name,v.year::text) title,
     case when c.state='processing' and c.lease_until<now() then 'error' else c.state end state,c.report_id,c.requested_at
    from private.listing_content_checks c join public.vehicle_listings v on v.id=c.listing_id
    left join public.vehicle_brands b on b.id=v.brand_id left join public.vehicle_models m on m.id=v.model_id
    where v.status='draft' and c.state<>'approved' order by c.requested_at desc,c.listing_id limit 100
  )q),'[]'::jsonb)
 ) into result;
 return result;
end; $$;
revoke all on function private.community_overview() from public,anon;
grant execute on function private.community_overview() to authenticated;
create function public.community_overview() returns jsonb language sql stable security invoker set search_path='' as $$ select private.community_overview(); $$;
revoke all on function public.community_overview() from public,anon;
grant execute on function public.community_overview() to authenticated;
commit;
