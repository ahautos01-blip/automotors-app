import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
const {PGlite}=await import(pathToFileURL(process.env.PGLITE_MODULE_PATH).href);
const db=new PGlite();
const fixture=await readFile(new URL('./vehicle_categories.integration.mjs',import.meta.url),'utf8');
const setup=fixture.slice(fixture.indexOf('const source='),fixture.indexOf("await db.exec('set role anon')"));
await (new Function('db','assert','readFile','URL','base',`return (async()=>{${setup.replaceAll(',import.meta.url',',base')}})()`))(db,assert,readFile,URL,import.meta.url);
const old='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const before=(await db.query('select private.listing_content_hash(to_jsonb(v)) h from vehicle_listings v where id=$1',[old])).rows[0].h;
await db.exec(await readFile(new URL('../supabase/migrations/20261118141241_catalogue_custom_car_identity.sql',import.meta.url),'utf8'));
assert.equal((await db.query('select private.listing_content_hash(to_jsonb(v)) h from vehicle_listings v where id=$1',[old])).rows[0].h,before);
await db.exec(await readFile(new URL('../supabase/migrations/20261118163133_publication_redesign_build53.sql',import.meta.url),'utf8'));
assert.match((await db.query("select pg_get_functiondef('private.record_client_error(text,text,integer)'::regprocedure) d")).rows[0].d,/51,52,53/);
await db.exec(await readFile(new URL('../supabase/migrations/20261118175853_national_identity_build54.sql',import.meta.url),'utf8'));
assert.match((await db.query("select pg_get_functiondef('private.record_client_error(text,text,integer)'::regprocedure) d")).rows[0].d,/51,52,53,54/);
const custom='cccccccc-cccc-4ccc-8ccc-cccccccccccc',owner='11111111-1111-4111-8111-111111111111';
await db.exec(await readFile(new URL('../supabase/migrations/20261119191112_ios_interaction_build55.sql',import.meta.url),'utf8'));
for (const signature of ['private.record_client_error(text,text,integer)', 'private.record_market_usage(text,integer)']) {
 assert.match((await db.query('select pg_get_functiondef($1::regprocedure) d',[signature])).rows[0].d,/53,54,55/);
}
await db.exec(await readFile(new URL('../supabase/migrations/20261120115756_whole_app_ios_build56.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../supabase/migrations/20261120122921_home_contact_fix_build57.sql',import.meta.url),'utf8'));
for (const signature of ['private.record_client_error(text,text,integer)', 'private.record_market_usage(text,integer)']) {
 assert.match((await db.query('select pg_get_functiondef($1::regprocedure) d',[signature])).rows[0].d,/54,55,56/);
}
// The shared chat fixture intentionally has no listing INSERT API; add the
// owner-only insert boundary for this synthetic publication scenario.
await db.exec("grant insert on vehicle_listings to authenticated;create policy catalogue_owner_insert on vehicle_listings for insert to authenticated with check(owner_id=auth.uid())");
await db.query("select set_config('request.jwt.claim.sub',$1,false)",[owner]);await db.exec('set role authenticated');
await db.query("insert into vehicle_listings(id,owner_id,status,vehicle_category,brand_id,model_id,declared_brand,declared_model)values($1,$2,'draft','car',null,null,'Historic brand','Rare model')",[custom,owner]);
await db.exec('reset role');
const fingerprint=(await db.query('select private.listing_content_hash(to_jsonb(v)) h from vehicle_listings v where id=$1',[custom])).rows[0].h;
await db.query("update vehicle_listings set declared_model='Updated model' where id=$1",[custom]);
assert.notEqual((await db.query('select private.listing_content_hash(to_jsonb(v)) h from vehicle_listings v where id=$1',[custom])).rows[0].h,fingerprint,'Custom car names are covered by moderation');
for(const invalid of ["brand_id=-1,model_id=-2,declared_brand=null,declared_model=null","brand_id=1,model_id=null","declared_brand=' '","declared_model=null"]){
 await assert.rejects(()=>db.query(`update vehicle_listings set ${invalid} where id=$1`,[custom]),e=>e.code==='23514');
}
await db.query("select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false)");await db.exec('set role authenticated');
assert.equal((await db.query("update vehicle_listings set declared_brand='Not mine' where id=$1 returning id",[custom])).rows.length,0);
await db.exec('reset role');assert.equal((await db.query('select declared_brand from vehicle_listings where id=$1',[custom])).rows[0].declared_brand,'Historic brand');
await db.close();console.log('PASS custom car identity, real-ID compatibility, moderated names, invalid local IDs and ownership boundaries.');
