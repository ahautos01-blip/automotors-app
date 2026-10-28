// Run with Node and @electric-sql/pglite@0.3.14 installed, or set
// PGLITE_MODULE_PATH to its dist/index.js. All fixtures stay in memory.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { pathToFileURL } from 'node:url';
const { PGlite } = await import(process.env.PGLITE_MODULE_PATH
  ? pathToFileURL(process.env.PGLITE_MODULE_PATH).href : '@electric-sql/pglite');
const db = new PGlite();
await db.exec(`
  create role anon; create role authenticated;
  create schema auth;
  create table auth.users(id uuid primary key);
  create function auth.uid() returns uuid language sql stable as
    $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
  grant usage on schema auth to anon,authenticated;
  grant execute on function auth.uid() to anon,authenticated;
  create table public.vehicle_listings(id uuid primary key default gen_random_uuid(),
    owner_id uuid not null references auth.users(id),status text not null,created_at timestamptz default now());
  create table public.user_subscriptions(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id),
    product_id text,provider text default 'apple',status text,started_at timestamptz default now(),
    expires_at timestamptz,created_at timestamptz default now());
  create table public.promotion_products(id bigint primary key,code text);
  create table public.promotion_purchases(id uuid primary key,user_id uuid,product_id bigint,payment_status text);
  create table public.user_promotion_entitlements(id uuid primary key,user_id uuid,purchase_id uuid,
    status text,starts_at timestamptz,ends_at timestamptz);
`);
await db.exec(await readFile(new URL('../supabase/migrations/20261028021644_vehicle_highlights_and_account_limits.sql', import.meta.url), 'utf8'));
const rows = async (sql, args=[]) => (await db.query(sql,args)).rows;
const scalar = async (sql,args=[]) => Object.values((await rows(sql,args))[0])[0];
const login = async user => { await db.query("select set_config('request.jwt.claim.sub',$1,false)",[user ?? '']); };
const createUser = async () => { const id=randomUUID(); await db.query('insert into auth.users values($1)',[id]); await login(id); return id; };
const publish = async user => scalar("insert into public.vehicle_listings(owner_id,status) values($1,'published') returning id",[user]);
const manage = (id, enabled=null) => scalar('select public.manage_vehicle_feature($1,$2)',[id,enabled]);
const reject = async (fn, text) => assert.rejects(fn, e => e.message.includes(text));
const featuredCount = user => scalar('select count(*)::integer from public.get_featured_vehicle_ids() f join public.vehicle_listings v on v.id=f.vehicle_id where v.owner_id=$1',[user]);

const free=await createUser();
const welcome=[];
for(let i=0;i<5;i++) welcome.push(await publish(free));
assert.equal(await scalar('select count(*)::integer from private.vehicle_publication_ledger where owner_id=$1',[free]),5);
await db.query('delete from public.vehicle_listings where id=$1',[welcome[0]]);
await reject(()=>publish(free),'límite de 3');
await db.query("update public.vehicle_listings set status='sold' where id=$1",[welcome[1]]);
await reject(()=>publish(free),'límite de 3');
await db.query("update public.vehicle_listings set status='sold' where id=$1",[welcome[2]]);
const sixth=await publish(free);
assert.equal(await scalar('select public.can_publish_vehicle_listing()'),false);
await db.query('delete from public.vehicle_listings where id=$1',[sixth]);
await publish(free);
assert.equal(await scalar('select count(*)::integer from private.vehicle_publication_ledger where owner_id=$1',[free]),7);
await reject(()=>manage(welcome[3],true),'Necesitas un pack');
console.log('PASS: five lifetime welcome publications, then three reusable active slots; deletion retains history.');

for (const [product, listings, limit] of [
  ['automotors_pack_10',10,3], ['automotors_pack_15',15,5],
  ['automotors_pack_20',20,8], ['automotors_pro_monthly_199',25,15],
]) {
  const user=await createUser();
  await db.query("insert into public.user_subscriptions(user_id,product_id,status,expires_at) values($1,$2,'active',now()+interval '1 day')",[user,product]);
  const ids=[];
  for(let i=0;i<listings;i++) ids.push(await publish(user));
  if(limit!==15) await reject(()=>publish(user),`límite de ${listings}`);
  for(let i=0;i<limit;i++) await manage(ids[i],true);
  assert.equal((await manage(ids[0],true)).used,limit); // A replay cannot consume another slot.
  await reject(()=>manage(ids[limit],true),`máximo de ${limit}`);
  assert.equal(await featuredCount(user),limit);
  await db.query("update public.vehicle_listings set status='sold' where id=$1",[ids[0]]);
  assert.equal(await featuredCount(user),limit-1);
  await manage(ids[limit],true);
  assert.equal(await featuredCount(user),limit);
  await manage(ids[1],false);
  assert.equal(await featuredCount(user),limit-1);
  await manage(ids[1],true);
  await login(free);
  await reject(()=>manage(ids[1],false),'propios anuncios');
  await login(null);
  await reject(()=>manage(ids[1],true),'Inicia sesión');
  await login(user);
  await db.query("update public.user_subscriptions set status='revoked' where user_id=$1",[user]);
  assert.equal(await featuredCount(user),0);
  await reject(()=>manage(ids[limit+1],true),'Necesitas un pack');
  await db.query("update public.user_subscriptions set status='active',expires_at=now()-interval '1 second' where user_id=$1",[user]);
  assert.equal(await featuredCount(user),0);
  await db.query("update public.user_subscriptions set expires_at=now()+interval '1 day' where user_id=$1",[user]);
  assert.equal(await featuredCount(user),limit);
  if(limit===15) {
    await db.query("update public.user_subscriptions set product_id='automotors_pack_10' where user_id=$1",[user]);
    assert.equal(await featuredCount(user),3);
    await reject(()=>manage(ids[20],true),'máximo de 3');
  }
  console.log(`PASS: ${product}: ${limit} featured; replay, sale, removal, ownership, revocation, expiry, renewal and downgrade.`);
}

// Check the actual authenticated role: RPC works, direct table access does not.
await login(free);
await db.exec('set role authenticated');
assert.equal((await manage(welcome[3])).limit,0);
await reject(()=>rows('select * from private.vehicle_feature_selections'),'permission denied');
await reject(()=>rows('select * from private.automotors_account_limits($1)',[free]),'permission denied');
await db.exec('reset role');
await login(null);
await db.exec('set role anon');
await rows('select * from public.get_featured_vehicle_ids()');
await reject(()=>manage(welcome[3],true),'permission denied');
await db.exec('reset role');
console.log('PASS: authenticated/anonymous permissions prevent direct grants and cross-account quota reads.');
await db.close();
