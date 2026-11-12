// All roles, rows and migrations run in an isolated in-memory Postgres.
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
const {PGlite} = await import(process.env.PGLITE_MODULE_PATH
  ? pathToFileURL(process.env.PGLITE_MODULE_PATH).href : '@electric-sql/pglite');
const db = new PGlite();
await db.exec(`
  create role anon; create role authenticated; create role service_role;
  create schema private;
  create table public.user_profiles(id int primary key,is_admin boolean default false,
    estado_verificacion text default 'no_solicitada', motivo_rechazo text, full_name text);
  grant select,insert,update on public.user_profiles to authenticated, service_role;
  insert into public.user_profiles values (1,false,'No solicitada',null,'Owner');
`);
await db.exec(await readFile(new URL('../supabase/migrations/20261101202728_protect_profile_authority.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../supabase/migrations/20261101203242_preserve_profile_default_status.sql',import.meta.url),'utf8'));
await db.exec('set role authenticated');
const denied = sql => assert.rejects(()=>db.exec(sql), e=>e.code==='42501');
await denied('update public.user_profiles set is_admin=true where id=1');
await denied("update public.user_profiles set estado_verificacion='aprobada' where id=1");
await denied("update public.user_profiles set estado_verificacion='Aprobada' where id=1");
await denied("update public.user_profiles set motivo_rechazo='forged' where id=1");
await denied("insert into public.user_profiles(id,is_admin) values(2,true)");
await denied("insert into public.user_profiles(id,estado_verificacion) values(2,'aprobada')");
await db.exec("update public.user_profiles set full_name='Edited',estado_verificacion='Pendiente' where id=1");
await db.exec("insert into public.user_profiles(id,estado_verificacion) values(2,'No aplicable')");
await db.exec("insert into public.user_profiles(id) values(3) on conflict(id) do update set full_name='Safe upsert'");
await db.exec("insert into public.user_profiles(id) values(3) on conflict(id) do update set full_name='Safe upsert'");
await db.exec('reset role; set role service_role');
await db.exec("update public.user_profiles set is_admin=true,estado_verificacion='aprobada',motivo_rechazo='server decision' where id=1");
await db.exec('reset role; set role authenticated');
await db.exec("update public.user_profiles set full_name='Safe edit' where id=1");
await denied('update public.user_profiles set is_admin=false where id=1');
await denied('update public.user_profiles set motivo_rechazo=null where id=1');
const {rows}=await db.query('select is_admin,estado_verificacion,full_name from public.user_profiles where id=1');
assert.deepEqual(rows,[{is_admin:true,estado_verificacion:'aprobada',full_name:'Safe edit'}]);
await db.close();
console.log('PASS: self-promotion and forged verification denied; normal profile edits, review requests and trusted server decisions preserved.');
