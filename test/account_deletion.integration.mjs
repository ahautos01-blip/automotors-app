import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import {accountDeletionHandler} from '../supabase/functions/delete-account/core.ts';
const {PGlite} = await import(process.env.PGLITE_MODULE_PATH
  ? pathToFileURL(process.env.PGLITE_MODULE_PATH).href : '@electric-sql/pglite');
const db = new PGlite();
const uid='11111111-1111-4111-8111-111111111111';
const other='22222222-2222-4222-8222-222222222222';
const sid='33333333-3333-4333-8333-333333333333';
await db.exec(`
  create role anon; create role authenticated; create role service_role bypassrls;
  create schema auth; create schema storage; create schema private;
  create table auth.users(id uuid primary key);
  create table auth.sessions(id uuid primary key,user_id uuid references auth.users on delete cascade,not_after timestamptz);
  create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
  grant usage on schema auth,storage to authenticated;
  create table storage.objects(bucket_id text,name text,owner_id text);
  alter table storage.objects enable row level security;
  create policy existing_storage_access on storage.objects to authenticated using(true) with check(true);
  grant all on storage.objects to authenticated;
  create table public.user_profiles(id uuid primary key references auth.users on delete cascade);
  create table public.vehicle_listings(id uuid primary key,owner_id uuid references auth.users on delete set null);
  create table public.promotion_purchases(id uuid primary key,user_id uuid references user_profiles on delete restrict);
  create table public.vehicle_promotions(id uuid,user_id uuid references user_profiles on delete restrict,purchase_id uuid references promotion_purchases);
  create table public.user_promotion_entitlements(id uuid,user_id uuid references user_profiles on delete restrict,purchase_id uuid references promotion_purchases);
`);
for(const name of ['vehicle_photos','chat_conversations','chat_messages','saved_vehicles','saved_vehicle_searches','vehicle_search_alerts','vehicle_listing_reports','vehicle_reviews','push_devices']) {
  await db.exec(`create table public.${name}(id int)`);
}
for(const name of ['user_profiles','vehicle_listings','vehicle_photos','chat_conversations','chat_messages','saved_vehicles','saved_vehicle_searches','vehicle_search_alerts','vehicle_listing_reports','vehicle_reviews','push_devices']) {
  await db.exec(`alter table public.${name} enable row level security; create policy existing_access on public.${name} to authenticated using(true) with check(true); grant all on public.${name} to authenticated;`);
}
await db.exec(await readFile(new URL('../supabase/migrations/20261101203355_account_deletion_and_session_guards.sql',import.meta.url),'utf8'));
await db.query('insert into auth.users values($1),($2)',[uid,other]);
await db.query('insert into auth.sessions values($1,$2,null)',[sid,uid]);
await db.query('insert into public.user_profiles values($1),($2)',[uid,other]);
await db.query('insert into public.vehicle_listings values($1,$2),($2,$1)',[uid,other]);
await db.query("insert into storage.objects values('profile-photos',$1,$2),('vehicle-photos',$3,null)",[uid+'/photo',uid,other+'/photo']);
const scalar=async(sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0];
for(const role of ['anon','authenticated']) {
  assert.equal(await scalar(`select has_function_privilege('${role}','public.prepare_account_deletion(uuid,uuid)','EXECUTE')`),false);
  assert.equal(await scalar(`select has_function_privilege('${role}','public.cleanup_account_data(uuid,uuid)','EXECUTE')`),false);
}
await assert.rejects(()=>db.query('select public.prepare_account_deletion($1,$2)',[other,sid]),e=>e.code==='42501');
const manifest=await scalar('select public.prepare_account_deletion($1,$2)',[uid,sid]);
assert.deepEqual(manifest,[{bucket:'profile-photos',path:uid+'/photo'}]);
await assert.rejects(()=>db.query('select public.cleanup_account_data($1,$2)',[uid,sid]),/Storage cleanup required/);
await db.query("select set_config('request.jwt.claim.sub',$1,false)",[uid]);
await db.exec('set role authenticated');
assert.equal(await scalar('select count(*)::int from public.user_profiles'),0);
await assert.rejects(()=>db.exec("insert into storage.objects values('profile-photos','new','owner')"),e=>e.code==='42501');
await db.exec('reset role');
await db.query("select set_config('request.jwt.claim.sub',$1,false)",[other]);
await db.exec('set role authenticated');
assert.equal(await scalar('select count(*)::int from public.user_profiles'),2); // Existing RLS fixture permits reads; active guard adds no permission.
await db.exec('reset role');
// This represents Storage API completion, not production SQL deletion of files.
await db.query('delete from storage.objects where owner_id=$1',[uid]);
await db.query('insert into public.promotion_purchases values($1,$2)',[sid,uid]);
await db.query('insert into public.vehicle_promotions values($1,$2,$1)',[sid,uid]);
await db.query('insert into public.user_promotion_entitlements values($1,$2,$1)',[sid,uid]);
await db.query('select public.cleanup_account_data($1,$2)',[uid,sid]);
await db.query('select public.cleanup_account_data($1,$2)',[uid,sid]); // Safe retry.
assert.equal(await scalar('select count(*)::int from public.vehicle_listings where owner_id=$1',[uid]),0);
assert.equal(await scalar('select count(*)::int from public.vehicle_listings where owner_id=$1',[other]),1);
await db.query('delete from auth.users where id=$1',[uid]);
await db.query("select set_config('request.jwt.claim.sub',$1,false)",[uid]);
await db.exec('set role authenticated');
assert.equal(await scalar('select private.current_account_active()'),false);
await assert.rejects(()=>db.exec("insert into storage.objects values('profile-photos','stale','owner')"),e=>e.code==='42501');
await db.close();

// Edge tests never send network requests: exercise authentication and failure ordering.
const token='header.'+Buffer.from(JSON.stringify({session_id:sid})).toString('base64url')+'.signature';
const req=(body={confirmation:'DELETE'},authorization='Bearer '+token,method='POST')=>new Request('https://test/delete-account',{method,headers:{Authorization:authorization,'Content-Type':'application/json'},...(method==='POST'?{body:JSON.stringify(body)}:{})});
function mock(failAt='') {
  const calls=[];
  const handler=accountDeletionHandler({url:'https://project.test',serviceKey:'server-secret'},async(url,options)=>{
    const path=new URL(url).pathname;calls.push({path,options});
    if(path===failAt) return new Response('{}',{status:500});
    if(path==='/auth/v1/user') return Response.json({id:uid});
    if(path.endsWith('prepare_account_deletion')) return Response.json([{bucket:'profile-photos',path:uid+'/photo'}]);
    return Response.json({});
  });
  return {handler,calls};
}
let m=mock();
assert.equal((await m.handler(req({},'', 'GET'))).status,405);
assert.equal((await m.handler(req({confirmation:'DELETE'},''))).status,401);
assert.equal((await m.handler(req({confirmation:'DELETE',user_id:other}))).status,400);
assert.equal(m.calls.length,0);
m=mock('/auth/v1/user');assert.equal((await m.handler(req())).status,401);assert.equal(m.calls.length,1);
m=mock('/storage/v1/object/profile-photos');assert.equal((await m.handler(req())).status,503);
assert.equal(m.calls.some(x=>x.path.endsWith('cleanup_account_data')||x.path.includes('/admin/users')),false);
m=mock('/rest/v1/rpc/cleanup_account_data');assert.equal((await m.handler(req())).status,503);
assert.equal(m.calls.some(x=>x.path.includes('/admin/users')),false);
m=mock();assert.deepEqual(await (await m.handler(req())).json(),{deleted:true});
assert.deepEqual(m.calls.map(x=>x.path),['/auth/v1/user','/rest/v1/rpc/prepare_account_deletion','/storage/v1/object/profile-photos','/rest/v1/rpc/cleanup_account_data','/auth/v1/admin/users/'+uid]);
const args=JSON.parse(m.calls[1].options.body);assert.deepEqual(args,{p_user_id:uid,p_session_id:sid});
assert.equal(m.calls[0].options.headers.Authorization,'Bearer '+token);
assert.equal(m.calls[4].options.headers.Authorization,'Bearer server-secret');
console.log('PASS: account ownership, live sessions, stale JWT denial, Storage-first cleanup, safe retries, legacy FK cleanup and Edge authentication/failure ordering.');
