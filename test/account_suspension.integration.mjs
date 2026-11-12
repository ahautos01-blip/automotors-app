process.on('uncaughtException',error=>{console.error(JSON.stringify({message:error.message,code:error.code,detail:error.detail,where:error.where,position:error.position,stack:error.stack?.split('\n').slice(0,5)}));process.exit(1);});
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import {pathToFileURL} from 'node:url';
import {classify,imageDataUrl,ModerationUnavailable} from '../supabase/functions/moderate-listing/provider.ts';
import {listingModerationHandler} from '../supabase/functions/moderate-listing/core.ts';
const {PGlite}=await import(process.env.PGLITE_MODULE_PATH ? pathToFileURL(process.env.PGLITE_MODULE_PATH).href : '@electric-sql/pglite');
const db=new PGlite();
await db.exec(await readFile(new URL('./fixtures/community_schema.sql',import.meta.url),'utf8'));
await db.exec(`
create schema storage;
create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text,version text default gen_random_uuid()::text,updated_at timestamptz default now(),metadata jsonb default '{"size":100}');
alter table storage.objects enable row level security;
create policy fixture_object_owner on storage.objects to authenticated using(true) with check(true);
grant all on storage.objects to authenticated;
grant usage on schema storage to authenticated;
alter table public.vehicle_listings add column show_vin_publicly boolean default false,add column show_matricula_publicly boolean default false,add column vin text,add column matricula text,add column phone text;
alter table public.vehicle_photos add column is_primary boolean default false;
alter table public.vehicle_photos drop column id;
alter table public.vehicle_photos add column id uuid default gen_random_uuid();
alter table public.vehicle_photos enable row level security;
create policy fixture_photo_owner on public.vehicle_photos to authenticated using(exists(select 1 from public.vehicle_listings v where v.id=listing_id and v.owner_id=auth.uid())) with check(exists(select 1 from public.vehicle_listings v where v.id=listing_id and v.owner_id=auth.uid()));
grant all on public.vehicle_photos to authenticated;
grant insert on public.vehicle_listings to authenticated;
create policy fixture_listing_insert on public.vehicle_listings for insert to authenticated with check(owner_id=auth.uid());
`);
await db.exec(await readFile(new URL('../supabase/migrations/20261101205245_chat_safety_and_moderation.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../supabase/migrations/20261101213447_automatic_content_moderation.sql',import.meta.url),'utf8'));

await db.exec(`
create table public.user_profiles(id uuid primary key references auth.users(id),is_admin boolean default false);
create table public.public_seller_profile_data(id uuid primary key references auth.users(id));
create table public.seller_about_profiles(user_id uuid primary key references auth.users(id));
create table public.vehicle_reviews(id uuid primary key default gen_random_uuid(),buyer_id uuid references auth.users(id));
alter table public.public_seller_profile_data enable row level security;
alter table public.seller_about_profiles enable row level security;
alter table public.vehicle_reviews enable row level security;
create policy profile_read on public.public_seller_profile_data for select to anon,authenticated using(true);
create policy about_read on public.seller_about_profiles for select to anon,authenticated using(true);
create policy review_read on public.vehicle_reviews for select to anon,authenticated using(true);
grant select on public.public_seller_profile_data,public.seller_about_profiles,public.vehicle_reviews to anon,authenticated;
create policy account_must_be_active on public.vehicle_listings as restrictive for all to authenticated using(private.current_account_active()) with check(private.current_account_active());
create policy account_must_be_active on public.chat_messages as restrictive for all to authenticated using(private.current_account_active()) with check(private.current_account_active());
`);
await db.exec(await readFile(new URL('../supabase/migrations/20261112180010_community_block_feed_visibility.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../supabase/migrations/20261112183747_community_account_suspension.sql',import.meta.url),'utf8'));
const owner=randomUUID(),other=randomUUID(),mod=randomUUID(),admin=randomUUID(),listing=randomUUID(),report=randomUUID();
for(const id of [owner,other,mod,admin]) {
 await db.query('insert into auth.users values($1)',[id]);await db.query('insert into auth.sessions values($1,$1,null)',[id]);
 await db.query('insert into user_profiles values($1,$2)',[id,id===admin]);
}
await db.query('insert into private.community_moderators values($1)',[mod]);
await db.query("insert into vehicle_listings(id,owner_id,status) values($1,$2,'published')",[listing,owner]);
await db.query('insert into public_seller_profile_data values($1)',[owner]);
await db.query('insert into seller_about_profiles values($1)',[owner]);
await db.query('insert into vehicle_reviews(buyer_id) values($1)',[owner]);
await db.query("insert into vehicle_listing_reports(id,reporter_id,listing_id,reason) values($1,$2,$3,'Contenido inapropiado')",[report,other,listing]);
const scalar=async(sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0];
const login=async id=>{await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id??'']);await db.query("select set_config('test.session_id',$1,false)",[id??'']);await db.exec(id?'set role authenticated':'set role anon');};
const act=(action,id=report,note='Reviewed the report and evidence')=>scalar("select public.community_review_report('listing',$1,$2,$3)",[id,action,note]);
const denied=fn=>assert.rejects(fn,e=>e.code==='42501');
await login(other); await denied(()=>act('suspend_account'));
await denied(()=>db.query('select * from private.account_suspensions'));
await login(null); await denied(()=>act('suspend_account'));
await login(mod); await assert.rejects(()=>act('suspend_account',report,' '),/reason is required/);
// A prepared publication lease must not be able to publish after suspension.
await db.exec('reset role');
await db.query("insert into storage.objects(bucket_id,name) values('vehicle-photos',$1)",[owner+'/'+listing+'/one.jpg']);
await db.query('insert into vehicle_photos(listing_id,storage_path,position,is_primary) values($1,$2,0,true)',[listing,owner+'/'+listing+'/one.jpg']);
const lease=await scalar('select public.prepare_listing_content_check($1,$1,$2)',[owner,listing]);
const publishedListing=randomUUID();
await db.query("insert into vehicle_listings(id,owner_id,status) values($1,$2,'published')",[publishedListing,owner]);
await login(other);assert.equal(await scalar('select count(*)::int from vehicle_listings'),1);
const conversation=await scalar('insert into chat_conversations(listing_id,buyer_id,seller_id) values($1,$2,$3) returning id',[publishedListing,other,owner]);
await db.query("insert into chat_messages(conversation_id,sender_id,body) values($1,$2,'Evidence')",[conversation,other]);

await login(mod); const result=await act('suspend_account');assert.equal(result.account_suspended,true);
await login(owner);assert.deepEqual(await scalar('select public.community_account_status()'),{active:false,suspended:true});
assert.equal(await scalar('select count(*)::int from chat_messages'),0);
await denied(()=>db.query("insert into chat_messages(conversation_id,sender_id,body) values($1,$2,'Bypass')",[conversation,owner]));
await login(other);await denied(()=>db.query("insert into chat_messages(conversation_id,sender_id,body) values($1,$2,'New message')",[conversation,other]));
await login(owner);

assert.equal(await scalar('select count(*)::int from vehicle_listings'),0);
await denied(()=>db.query("insert into vehicle_listings(id,owner_id,status) values($1,$2,'draft')",[randomUUID(),owner]));
await denied(()=>db.query("update vehicle_listings set description='Bypass' where id=$1 returning id",[listing]).then(r=>{if(r.rows.length===0)throw {code:'42501'};}));
for(const who of [other,null]) {
 await login(who);
 for(const table of ['vehicle_listings','public_seller_profile_data','seller_about_profiles','vehicle_reviews']) assert.equal(await scalar('select count(*)::int from '+table),0,table);
}
await db.exec('reset role');assert.equal(await scalar('select count(*)::int from auth.sessions where user_id=$1',[owner]),1); // Old JWT/session still exists, but is denied.
await denied(()=>scalar('select public.prepare_listing_content_check($1,$1,$2)',[owner,listing]));
await denied(()=>scalar("select public.finish_listing_content_check($1,$1,$2,$3,'approved')",[owner,listing,lease.lease_id]));
await db.query("update private.listing_content_checks set state='error',report_id=$1 where listing_id=$2",[report,listing]);
await login(mod);await denied(()=>scalar('select public.community_approve_publication($1,$2,$3)',[report,lease.fingerprint,'Reviewed all content']));
await login(mod);assert.equal((await scalar("select public.community_report_detail('listing',$1)",[report])).account_suspended,true);
const history=await scalar("select public.community_report_detail('listing',$1)",[report]);assert.equal(history.history[0].action,'suspend_account');
await act('restore_account');
await login(owner);assert.deepEqual(await scalar('select public.community_account_status()'),{active:true,suspended:false});
await login(other);assert.equal(await scalar('select count(*)::int from vehicle_listings'),1);
// Moderator/administrator protection is independent of UI.
await db.exec('reset role');
for(const protectedId of [mod,admin]) {
 const id=randomUUID(),r=randomUUID();await db.query("insert into vehicle_listings(id,owner_id,status) values($1,$2,'published')",[id,protectedId]);
 await db.query("insert into vehicle_listing_reports(id,reporter_id,listing_id,reason) values($1,$2,$3,'Otro')",[r,other,id]);
 await login(mod);await denied(()=>act('suspend_account',r));await db.exec('reset role');
}
await login(mod);await assert.rejects(()=>act('suspend_account',randomUUID()),/Report unavailable/);
await db.exec('reset role');await db.query('delete from auth.sessions where user_id=$1',[mod]);
await login(mod);await denied(()=>act('suspend_account'));
await db.close();console.log('PASS: audited suspension/restore, old-session denial, hidden listings/profiles/reviews, publication race denied, private markers, protected admins and authenticated moderator checks.');
