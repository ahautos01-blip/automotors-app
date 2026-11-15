import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
const script=await readFile(new URL('../docs/web_profile_share_patch.js',import.meta.url),'utf8');
const id='12345678-1234-1234-1234-123456789abc';
async function run(query,profile){
 const nodes=new Map();const calls=[];const elements=[];
 const element=()=>({textContent:'',hidden:true,href:'',children:[],append(value){this.children.push(value);},after(value){elements.push(value);}});
 const document={title:'',querySelector(key){if(!nodes.has(key))nodes.set(key,element());return nodes.get(key);},createElement:element};
 vm.runInNewContext(script,{URL,document,location:{href:'https://automotors.info/anuncio/?'+query},fetch:async(url)=>{calls.push(url);return {ok:true,json:async()=>url.includes('public_seller_profiles')?(profile?[profile]:[]):[]};}});
 for(let i=0;i<10;i++)await Promise.resolve();
 return {nodes,calls,document,elements};
}
let result=await run('seller='+id,{account_type:'empresa',business_name:'<script>alert(1)</script>',city:'Mataró',province:'Barcelona'});
assert.equal(result.nodes.get('#title').textContent,'<script>alert(1)</script>');assert.equal(result.nodes.get('#open').href,'com.automotors.automotorsbase://seller?seller='+id);assert.equal(result.nodes.get('#open').hidden,false);
assert.ok(result.calls.every(url=>!url.includes('user_profiles')&&!url.includes('email')&&!url.includes('fiscal')));
result=await run('seller=bad');assert.equal(result.calls.length,0);assert.equal(result.nodes.get('#open').hidden,true);
result=await run('seller='+id+'&listing='+id);assert.equal(result.calls.length,0);
result=await run('seller='+id);assert.equal(result.nodes.get('#open').hidden,true);assert.match(result.nodes.get('#title').textContent,/no está disponible/);
result=await run('seller='+id,{account_type:'particular',full_name:'Private fixture'});assert.equal(result.nodes.get('#open').hidden,true);assert.ok(!result.nodes.get('#title').textContent.includes('Private fixture'));
console.log('PASS public profile fallback, target validation, no private fields, text-only rendering.');
