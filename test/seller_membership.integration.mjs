import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
const {PGlite}=await import(pathToFileURL(process.env.PGLITE_MODULE_PATH).href);
const db=new PGlite();
await db.exec(`create role anon; create role authenticated;
create table public.user_profiles(id uuid primary key,created_at timestamptz);
alter table public.user_profiles enable row level security;
create table public.public_seller_profile_data(id uuid primary key);
create view public.public_seller_profiles with(security_invoker=true) as select id from public.public_seller_profile_data;
grant usage on schema public to anon,authenticated;
grant select on public.public_seller_profile_data,public.public_seller_profiles to anon,authenticated;
insert into public.user_profiles values('11111111-1111-1111-1111-111111111111','2024-04-17T23:12:00Z'),('22222222-2222-2222-2222-222222222222','2023-03-01T00:00:00Z');
insert into public.public_seller_profile_data values('11111111-1111-1111-1111-111111111111');`);
await db.exec(await readFile(new URL('../supabase/migrations/20261112122709_seller_public_membership_month.sql',import.meta.url),'utf8'));
for(const role of ['anon','authenticated']) {
 await db.exec(`set role ${role}`);
 assert.equal((await db.query(`select public.seller_member_since('11111111-1111-1111-1111-111111111111') as month`)).rows[0].month,'2024-04');
 assert.equal((await db.query(`select public.seller_member_since('22222222-2222-2222-2222-222222222222') as month`)).rows[0].month,null);
 assert.equal((await db.query(`select public.seller_member_since(null) as month`)).rows[0].month,null);
 await assert.rejects(db.query('select * from public.user_profiles'),/permission denied/);
 await db.exec('reset role');
}
await db.exec(`delete from public.public_seller_profile_data;set role anon;`);
assert.equal((await db.query(`select public.seller_member_since('11111111-1111-1111-1111-111111111111') as month`)).rows[0].month,null);
await db.close();
console.log('Membership: public month, hidden/deleted sellers, null IDs and private profile isolation passed.');
