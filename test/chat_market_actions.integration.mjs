process.on('uncaughtException',e=>{console.error(e.message,e.query?.slice(0,200));process.exit(1)});
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import {randomUUID} from 'node:crypto';
const {PGlite}=await import(pathToFileURL(process.env.PGLITE_MODULE_PATH).href);const db=new PGlite();
await db.exec(await readFile(new URL('./fixtures/community_schema.sql',import.meta.url),'utf8'));
await db.exec(`create schema extensions;create function extensions.gen_random_bytes(n int) returns bytea language sql as $$select decode(repeat('00',n),'hex')$$;
alter table vehicle_listings add sold_externally boolean default false,add sold_to_buyer_id uuid;
create table vehicle_reviews(listing_id uuid,buyer_id uuid);
create table saved_vehicle_searches(id uuid primary key,user_id uuid,notify_new_listings boolean,notify_price_drops boolean);
create table saved_vehicles(listing_id uuid,user_id uuid,notify_price_drops boolean);
create table vehicle_search_alerts(id uuid primary key default gen_random_uuid(),user_id uuid,search_id uuid,listing_id uuid,alert_type text,created_at timestamptz default now(),current_price numeric,read_at timestamptz);
create table private.account_suspensions(user_id uuid);
create table private.chat_user_blocks(blocker_id uuid,blocked_id uuid);
create table private.test_listing_holds(listing_id uuid);
create function private.community_subject_active(u uuid) returns boolean language sql as $$select not exists(select 1 from private.account_suspensions where user_id=u)$$;
create function private.listing_not_held(v uuid) returns boolean language sql as $$select not exists(select 1 from private.test_listing_holds where listing_id=v)$$;
create function private.content_moderation_enabled() returns boolean language sql as $$select false$$;
create function private.listing_content_approved(v uuid) returns boolean language sql as $$select true$$;`);
await db.exec(await readFile(new URL('../supabase/fixes/enable_ios_push.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../supabase/migrations/20261113113148_buyer_push_alerts.sql',import.meta.url),'utf8'));
await db.exec('alter role service_role bypassrls;grant select on all tables in schema public to service_role');

await db.exec('grant usage on schema private to anon');
await db.exec(`alter table auth.users add email_confirmed_at timestamptz;create table private.chat_restrictions(user_id uuid);create table private.community_moderators(user_id uuid);create table private.chat_reports(id uuid primary key,conversation_id bigint);create table public.public_seller_profile_data(id uuid);
create function private.community_seller_visible(u uuid)returns boolean language sql security definer set search_path='' as $$select not exists(select 1 from private.chat_user_blocks where blocker_id=auth.uid() and blocked_id=u)$$;
create function private.is_community_moderator()returns boolean language sql security definer set search_path='' as $$select private.current_account_active() and exists(select 1 from private.community_moderators where user_id=auth.uid()) and exists(select 1 from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id')$$;`);
const suspension=await readFile(new URL('../supabase/migrations/20261112183747_community_account_suspension.sql',import.meta.url),'utf8');
for(const marker of ['create or replace function private.current_account_active()','create or replace function private.chat_pair_allowed']){
 const a=suspension.indexOf(marker);await db.exec(suspension.slice(a,suspension.indexOf('$$;',a)+3));
}
const metrics=await readFile(new URL('../supabase/migrations/20261113104810_seller_listing_metrics.sql',import.meta.url),'utf8');
await db.exec(metrics.slice(metrics.indexOf('create function private.metrics_actor_active'),metrics.indexOf('create table public.listing_view_days')));
await db.exec(await readFile(new URL('../supabase/migrations/20261114140730_chat_market_actions.sql',import.meta.url),'utf8'));
const buyer=randomUUID(),seller=randomUUID(),outsider=randomUUID(),mod=randomUUID(),listing=randomUUID();
for(const id of[buyer,seller,outsider,mod]){await db.query('insert into auth.users(id,email_confirmed_at)values($1,now())',[id]);await db.query('insert into auth.sessions values($1,$1,null)',[id]);}
await db.query('insert into private.community_moderators values($1)',[mod]);
await db.query('insert into public_seller_profile_data values($1)',[seller]);
await db.query("insert into vehicle_listings(id,owner_id,status)values($1,$2,'published')",[listing,seller]);
const conversation=(await db.query('insert into chat_conversations(listing_id,buyer_id,seller_id)values($1,$2,$3)returning id',[listing,buyer,seller])).rows[0].id;
const login=async id=>{await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id??'']);await db.query("select set_config('test.session_id',$1,false)",[id??'']);await db.exec(id?'set role authenticated':'set role anon');};
const action=async(a,id=null,kind=null,amount=null,time=null,place=null)=>(await db.query('select chat_market_action($1,$2,$3,$4,$5,$6,$7) result',[conversation,a,id,kind,amount,time,place])).rows[0].result;
await login(buyer);const offer=await action('create',null,'offer',12000);
await assert.rejects(()=>action('accept',offer.id));
await assert.rejects(()=>action('create',null,'offer',13000));
await assert.rejects(()=>db.query("insert into chat_market_activities(conversation_id,creator_id,kind,amount,expires_at)values($1,$2,'offer',10,now())",[conversation,buyer]),e=>e.code==='42501');
await login(outsider);await assert.rejects(()=>action('list'),e=>e.code==='42501');assert.equal((await db.query('select * from chat_market_activities')).rows.length,0);
await login(seller);assert.equal((await action('accept',offer.id)).status,'accepted');await assert.rejects(()=>action('reject',offer.id));
await login(buyer);const visit=await action('create',null,'visit',null,new Date(Date.now()+7200000).toISOString(),'Parking público');
await login(seller);assert.equal((await action('accept',visit.id)).status,'accepted');
await db.exec('reset role');assert.equal((await db.query('select status from vehicle_listings where id=$1',[listing])).rows[0].status,'published');
// Reminder queued only for capable devices, and revoked on cancellation.
for(const [id,token]of[[buyer,'a'],[seller,'b']])await db.query("insert into push_devices(user_id,session_id,token,environment,buyer_alerts,market_actions)values($1,$1,repeat($2,64),'production',true,true)",[id,token]);
await login(buyer);const next=await action('create',null,'offer',11000);await login(seller);await action('reject',next.id);
await login(buyer);await action('cancel',visit.id);const visit2=await action('create',null,'visit',null,new Date(Date.now()+10800000).toISOString(),'Taller');await login(seller);await action('accept',visit2.id);
await db.exec('reset role');assert.equal((await db.query("select count(*)::int n from private.push_deliveries where kind='visit_reminder' and activity_id=$1",[visit2.id])).rows[0].n,2);
assert.equal((await db.query('select private.market_delivery_allowed($1,$2,true) ok',[buyer,visit2.id])).rows[0].ok,true);
await login(buyer);await action('cancel',visit2.id);await db.exec('reset role');assert.equal((await db.query('select private.market_delivery_allowed($1,$2,true) ok',[buyer,visit2.id])).rows[0].ok,false);
await db.query('insert into private.chat_user_blocks values($1,$2)',[buyer,seller]);await login(buyer);await assert.rejects(()=>action('list'),e=>e.code==='42501');await db.exec('reset role');await db.exec('delete from private.chat_user_blocks');
// Aggregated diagnostics never store identity or free text.
await login(buyer);await db.query("select record_client_error('chat','unknown',40)");await db.query("select record_client_error('chat','unknown',40)");await assert.rejects(()=>db.query("select record_client_error('private conversation','password',40)"));
await assert.rejects(()=>db.query('select client_error_summary()'),e=>e.code==='42501');
await db.exec('reset role');const report=randomUUID();await db.query('insert into private.chat_reports values($1,$2)',[report,conversation]);await login(buyer);await assert.rejects(()=>db.query('select community_report_activities($1)',[report]),e=>e.code==='42501');await login(mod);assert.ok((await db.query('select community_report_activities($1) data',[report])).rows[0].data.length>0);const summary=(await db.query('select client_error_summary() data')).rows[0].data;assert.equal(summary[0].occurrences,1);assert.ok(!JSON.stringify(summary).includes(buyer));
await db.exec('reset role');const worker=(await db.query('select worker_token from private.push_worker_config')).rows[0].worker_token;await db.exec('set role service_role');const jobs=(await db.query('select claim_push_deliveries($1) jobs',[worker])).rows[0].jobs;assert.ok(jobs.every(j=>j.kind!=='visit_reminder'));await db.exec('reset role');
await login(null);await assert.rejects(()=>action('list'),e=>e.code==='42501');const trust=(await db.query('select seller_trust_summary($1) result',[seller])).rows[0].result;assert.deepEqual(trust,{email_confirmed:true});
await login(buyer);await db.exec('reset role');await db.query('delete from auth.sessions where user_id=$1',[buyer]);await login(buyer);await assert.rejects(()=>action('list'),e=>e.code==='42501');
await db.close();console.log('PASS participant-only offers/visits, state transitions, no automatic sale, reminder capability and cancellation, blocks, aggregate diagnostics, trust minimalism and revoked sessions.');

