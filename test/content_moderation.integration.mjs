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
const owner=randomUUID(),other=randomUUID(),mod=randomUUID(),listing=randomUUID();
for(const id of [owner,other,mod]){await db.query('insert into auth.users values($1)',[id]);await db.query('insert into auth.sessions values($1,$1,null)',[id]);}
await db.query('insert into private.community_moderators values($1)',[mod]);
await db.query("insert into vehicle_listings(id,owner_id,status,vin,matricula,phone) values($1,$2,'draft','PRIVATEVIN','PRIVATEPLATE','PRIVATEPHONE')",[listing,owner]);
const path=owner+'/'+listing+'/1.jpg';
await db.query("insert into storage.objects(bucket_id,name) values('vehicle-photos',$1)",[path]);
await db.query('insert into vehicle_photos(listing_id,storage_path,position,is_primary) values($1,$2,0,true)',[listing,path]);
const scalar=async(sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0];
const deny=fn=>assert.rejects(fn,e=>e.code==='42501');
const login=async id=>{await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id??'']);await db.query("select set_config('test.session_id',$1,false)",[id??'']);await db.exec(id?'set role authenticated':'set role anon');};
const prepare=()=>scalar('select public.prepare_listing_content_check($1,$1,$2)',[owner,listing]);
const finish=(lease,outcome)=>scalar('select public.finish_listing_content_check($1,$1,$2,$3,$4)',[owner,listing,lease,outcome]);
assert.equal(await scalar("select has_function_privilege('authenticated','public.prepare_listing_content_check(uuid,uuid,uuid,text)','EXECUTE')"),false);
assert.equal(await scalar("select has_function_privilege('anon','public.finish_listing_content_check(uuid,uuid,uuid,uuid,text,jsonb,text)','EXECUTE')"),false);
await login(owner);await db.query("update vehicle_listings set status='published' where id=$1",[listing]); // Rollout starts off; existing client is preserved.
await db.exec('reset role;update private.content_moderation_config set enabled=true');
await login(other);assert.equal(await scalar('select count(*)::int from vehicle_listings where id=$1',[listing]),0);
await login(owner);await deny(()=>db.query("update vehicle_listings set status='published' where id=$1",[listing]));
await db.exec('reset role');await deny(()=>scalar('select public.prepare_listing_content_check($1,$2,$3)',[owner,other,listing]));
let check=await prepare();assert.equal(check.photos.length,1);assert.equal(check.text.includes('PRIVATEVIN'),false);assert.equal(check.text.includes('PRIVATEPLATE'),false);assert.equal(check.text.includes('PRIVATEPHONE'),false);
await login(owner);
await deny(()=>db.query('insert into vehicle_photos(listing_id,storage_path,position) values($1,$2,1)',[listing,path]));
await deny(()=>db.query("insert into storage.objects(bucket_id,name) values('vehicle-photos',$1)",[owner+'/'+listing+'/2.jpg']));
await db.query("update vehicle_listings set description='Changed while processing' where id=$1",[listing]);
await db.exec('reset role');await deny(()=>finish(check.lease_id,'approved'));
check=await prepare();await db.query('update storage.objects set version=gen_random_uuid()::text where name=$1',[path]);
assert.deepEqual(await finish(check.lease_id,'approved'),{state:'changed',published:false});
check=await prepare();assert.equal((await finish(check.lease_id,'approved')).published,true);
await login(other);assert.equal(await scalar('select count(*)::int from vehicle_listings where id=$1',[listing]),1);
await login(owner);await deny(()=>db.query("update vehicle_listings set description='Unmoderated' where id=$1",[listing]));
assert.equal((await db.query('update storage.objects set version=gen_random_uuid()::text where name=$1 returning version',[path])).rows.length,0);
await db.query("update vehicle_listings set status='draft',description='Edited draft' where id=$1",[listing]);
await db.exec('reset role');check=await prepare();assert.equal((await finish(check.lease_id,'rejected')).published,false);
let report=await scalar('select report_id from private.listing_content_checks where listing_id=$1',[listing]);assert.ok(report);
await login(other);await deny(()=>scalar('select public.community_approve_publication($1,$2)',[report,check.fingerprint]));
await login(mod);let detail=await scalar("select public.community_report_detail('listing',$1)",[report]);assert.equal(detail.automatic_state,'rejected');
await deny(()=>scalar('select public.community_approve_publication($1,$2)',[report,'forged']));
detail=await scalar('select public.community_approve_publication($1,$2,$3)',[report,check.fingerprint,'Reviewed photos and text']);assert.equal(detail.automatic_state,'approved');
assert.equal(detail.history[0].action,'approve_publication');
await db.exec('reset role');await db.query("update vehicle_listings set status='draft' where id=$1",[listing]);check=await prepare();
await db.query('delete from auth.sessions where user_id=$1',[owner]);await deny(()=>finish(check.lease_id,'approved'));
await db.query('insert into auth.sessions values($1,$1,null)',[owner]);await db.query("update private.listing_content_checks set lease_until=now()-interval '1 second' where listing_id=$1",[listing]);
await assert.rejects(prepare,/MODERATION_RATE_LIMIT/);
await db.query("update private.content_request_log set created_at=now()-interval '1 day'");check=await prepare();
await db.query('insert into private.account_deletions values($1)',[owner]);await deny(()=>finish(check.lease_id,'approved'));
await db.query('delete from private.account_deletions where user_id=$1',[owner]);assert.equal((await finish(check.lease_id,'error')).published,false);
await db.query('delete from auth.users where id=$1',[owner]);assert.equal(await scalar('select count(*)::int from private.listing_content_checks'),0);
await db.close();

const safe={results:[{flagged:false,categories:{violence:false,sexual:false}}]};
const flagged={results:[{flagged:true,categories:{violence:true,sexual:false}}]};
for(const invalid of [{},{results:[]},{results:[{flagged:false,categories:{}}]},{results:[{flagged:'false',categories:{violence:false}}]},{results:[{flagged:false,categories:{violence:true}}]}]) {
 await assert.rejects(()=>classify('Fixture','test-key',async()=>Response.json(invalid)),e=>e instanceof ModerationUnavailable&&e.code==='provider_invalid_response');
}
await assert.rejects(()=>classify('Fixture',''),/provider_not_configured/);
await assert.rejects(()=>classify('Fixture','test-key',async()=>new Response('{}',{status:429})),/provider_rate_limit/);
assert.equal((await classify('Fixture','test-key',async()=>Response.json(flagged))).flagged,true);
assert.throws(()=>imageDataUrl(new Uint8Array([1,2,3])),/unsupported_image/);
const png=new Uint8Array([137,80,78,71,13,10,26,10]);assert.ok(imageDataUrl(png).startsWith('data:image/png;base64,'));
const token='head.'+Buffer.from(JSON.stringify({session_id:owner})).toString('base64url')+'.signature';
const request=(body,authorization='Bearer '+token)=>new Request('https://test/moderate-listing',{method:'POST',headers:{Authorization:authorization,'Content-Type':'application/json'},body:JSON.stringify(body)});
function mock({provider=safe,change=false,errorAt=''}={}) {
 const calls=[];
 const handler=listingModerationHandler({url:'https://project.test',serviceKey:'service-secret',openaiKey:'openai-secret'},async(url,options)=>{
   const where=new URL(url);calls.push({url,path:where.pathname,options});
   if(where.pathname===errorAt) return new Response('{}',{status:503});
   if(where.hostname==='api.openai.com') return Response.json(provider);
   if(where.pathname==='/auth/v1/user') return Response.json({id:owner});
   if(where.pathname.endsWith('/prepare_listing_content_check')) return Response.json({lease_id:mod,text:'Fixture ad',photos:[{path}]});
   if(where.pathname.startsWith('/storage/')) return new Response(png);
   if(where.pathname.endsWith('/finish_listing_content_check')) {
     const args=JSON.parse(options.body);return Response.json(change?{state:'changed',published:false}:{state:args.p_outcome,published:args.p_outcome==='approved'});
   }
   return Response.json(null);
 });return {handler,calls};
}
let m=mock();assert.equal((await m.handler(request({action:'publish',listing_id:listing},''))).status,401);assert.equal(m.calls.length,0);
assert.equal((await m.handler(request({action:'probe'}))).status,403);assert.equal(m.calls.length,0);
assert.equal((await m.handler(request({action:'publish',listing_id:listing,approved:true}))).status,400);
m=mock();let response=await m.handler(request({action:'publish',listing_id:listing}));assert.equal(response.status,200);assert.equal((await response.json()).published,true);
assert.equal(m.calls.filter(x=>x.url.includes('api.openai.com')).length,2);
const apiBodies=m.calls.filter(x=>x.url.includes('api.openai.com')).map(x=>JSON.parse(x.options.body));assert.equal(JSON.stringify(apiBodies).includes('service-secret'),false);assert.equal(JSON.stringify(apiBodies).includes(owner),false);
m=mock({provider:flagged});response=await m.handler(request({action:'publish',listing_id:listing}));assert.equal(response.status,422);assert.equal(m.calls.some(x=>x.path.startsWith('/storage/')),false);
m=mock({change:true});assert.equal((await m.handler(request({action:'publish',listing_id:listing}))).status,409);
m=mock({errorAt:'/storage/v1/object/authenticated/vehicle-photos/'+path});assert.equal((await m.handler(request({action:'publish',listing_id:listing}))).status,503);
assert.equal(JSON.parse(m.calls.at(-1).options.body).p_outcome,'error');
m=mock();response=await m.handler(request({action:'probe'},'Bearer service-secret'));assert.equal(response.status,200);assert.equal((await response.json()).connected,true);
console.log('PASS: content-bound approvals, rollout guards, ownership/live sessions, photo replacement denial, changed/expired checks, rate limits, human appeal, provider failures, private-key isolation and synthetic connection probe.');
