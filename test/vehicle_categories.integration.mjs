import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
const {PGlite}=await import(pathToFileURL(process.env.PGLITE_MODULE_PATH).href);
const db=new PGlite();
// Shared real RLS fixture and watchlist setup; no production credentials or users.
const source=await readFile(new URL('./buyer_watchlists.integration.mjs',import.meta.url),'utf8');
const setup=source.slice(source.indexOf("await db.exec(await readFile"),source.indexOf('const migration='));
await (new Function('db','readFile','URL','base',`return (async()=>{${setup.replaceAll('import.meta.url','base')}})()`))(db,readFile,URL,import.meta.url);
await db.exec(await readFile(new URL('../supabase/migrations/20261102212151_buyer_watchlists_and_price_alerts.sql',import.meta.url),'utf8'));
await db.exec(`alter table vehicle_listings add created_at timestamptz default now(),add doors int,add etiqueta_medioambiental text,add matricula text,add vin text,add show_matricula_publicly boolean not null default false,add show_vin_publicly boolean not null default false,add market_facts jsonb;
alter table vehicle_listings alter brand_id set not null,alter model_id set not null;
create function private.listing_photo_manifest(uuid) returns jsonb language sql as $$select '[]'::jsonb$$;
create function private.market_radius_matches(jsonb,jsonb) returns boolean language sql as $$select true$$;
create function private.listing_content_hash(p_row jsonb)returns text language sql as $$select encode(sha256(convert_to(jsonb_build_object('listing',p_row-'market_facts'-array['status','updated_at','created_at','sold_at','sold_to_buyer_id','sold_externally'],'photos','[]'::jsonb)::text,'UTF8')),'hex')$$;`);
const id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const oldHash=(await db.query('select private.listing_content_hash(to_jsonb(v)) h from vehicle_listings v where id=$1',[id])).rows[0].h;
await db.exec(await readFile(new URL('../supabase/migrations/20261118125249_multi_vehicle_catalogue.sql',import.meta.url),'utf8'));
assert.equal((await db.query('select private.listing_content_hash(to_jsonb(v)) h from vehicle_listings v where id=$1',[id])).rows[0].h,oldHash,'Existing approvals stay byte-compatible');
for(const [category,details,ok] of [
 ['boat',{length_m:12.5,engine_hours:400},true],['boat',{km:100},false],['boat',{length_m:-1},false],['boat',{cabins:1.5},false],
 ['motorcycle',{engine_cc:125},true],['motorcycle',{engine_cc:'125'},false],['truck',{gross_weight_kg:3500,payload_kg:1500,axles:2},true],
 ['truck',{gross_weight_kg:3500,payload_kg:4500},false],['car',{},true],['car',{engine_hours:12},false],['plane',{},false],
])assert.equal((await db.query('select private.valid_category_details($1,$2::jsonb) ok',[category,JSON.stringify(details)])).rows[0].ok,ok,category+JSON.stringify(details));
const buyer='22222222-2222-4222-8222-222222222222',seller='11111111-1111-4111-8111-111111111111';
const boat='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
await db.query("insert into saved_vehicle_searches(user_id,name,criteria)values($1,'Cars','{}'),($1,'Boats','{\"vehicle_category\":\"boat\",\"category_filters\":{\"min_length_m\":10}}')",[buyer]);
await db.query("insert into vehicle_listings(id,owner_id,status,vehicle_category,declared_brand,declared_model,category_details,km)values($1,$2,'draft','boat','Beneteau','Oceanis','{\"length_m\":12.5,\"engine_hours\":400}',0)",[boat,seller]);
await db.query("update vehicle_listings set status='published' where id=$1",[boat]);
const alerts=(await db.query('select s.name,a.message from vehicle_search_alerts a join saved_vehicle_searches s on s.id=a.search_id where a.listing_id=$1',[boat])).rows;
assert.equal(alerts.length,1);assert.equal(alerts[0].name,'Boats');assert.match(alerts[0].message,/Beneteau Oceanis/);
const firstBoatHash=(await db.query('select private.listing_content_hash(to_jsonb(v)) h from vehicle_listings v where id=$1',[boat])).rows[0].h;
await db.query("update vehicle_listings set category_details='{\"length_m\":13}' where id=$1",[boat]);
assert.notEqual((await db.query('select private.listing_content_hash(to_jsonb(v)) h from vehicle_listings v where id=$1',[boat])).rows[0].h,firstBoatHash,'Category facts are moderated');
await assert.rejects(()=>db.query("update vehicle_listings set vehicle_category='car' where id=$1",[boat]),e=>e.code==='23514');
await assert.rejects(()=>db.query("update vehicle_listings set km=900 where id=$1",[boat]),e=>e.code==='23514');
await assert.rejects(()=>db.query("update vehicle_listings set market_facts='{\"itv\":\"valid\"}' where id=$1",[boat]),e=>e.code==='23514');
await assert.rejects(()=>db.query("insert into vehicle_listings(id,vehicle_category,declared_brand,declared_model)values(gen_random_uuid(),'boat','','Model')"),e=>e.code==='23514');
assert.equal((await db.query("select private.buyer_search_matches('{\"vehicle_category\":\"boat\",\"category_filters\":{\"min_length_m\":20}}',to_jsonb(v),'Beneteau','Oceanis') ok from vehicle_listings v where id=$1",[boat])).rows[0].ok,false);
await db.exec('set role anon');await assert.rejects(()=>db.query("select private.valid_category_details('car','{}')"),e=>e.code==='42501');
await db.close();console.log('Vehicle categories: schema, compatibility, moderation fingerprints, constraints and alert isolation passed.');
