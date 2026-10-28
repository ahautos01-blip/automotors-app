import { test } from 'node:test';
import assert from 'node:assert/strict';
import { apnsJwt, outcome, payload, type Delivery } from './core.ts';

const job: Delivery={id:'event',lease_token:'lease',attempts:1,kind:'chat_message',user_id:'recipient',
  listing_id:'listing',conversation_id:'9007199254740993',token:'secret-device-token',environment:'production',expiration:1};

test('chat payload preserves large conversation IDs and excludes device tokens and message content',()=>{
  const value=payload(job);
  assert.equal(value.conversation_id,'9007199254740993');
  assert.equal(value.user_id,'recipient');
  assert.equal(value.aps['thread-id'],'chat-9007199254740993');
  assert.ok(!JSON.stringify(value).includes(job.token));
});
test('review opens the purchase and does not carry a chat route',()=>{
  const value=payload({...job,kind:'review_requested'});
  assert.equal(value.kind,'review_requested');
  assert.ok(!('conversation_id' in value));
});
test('APNs accepted, invalid tokens, retryable errors and terminal retry limit',()=>{
  assert.equal(outcome(200,'',1).status,'sent');
  assert.equal(outcome(410,'Unregistered',1).disable,true);
  assert.equal(outcome(400,'BadDeviceToken',1).disable,true);
  assert.equal(outcome(403,'InvalidProviderToken',1).disable,false);
  assert.equal(outcome(403,'InvalidProviderToken',1).status,'pending');
  assert.equal(outcome(429,'TooManyRequests',1).status,'pending');
  assert.equal(outcome(503,'ServiceUnavailable',8).status,'failed');
  assert.equal(outcome(400,'BadPayload',1).status,'failed');
  assert.equal(outcome(0,'transport_error',1).status,'pending');
});
test('APNs JWT is signed with ES256 and the Apple team and key identifiers',async()=>{
  const keys=await crypto.subtle.generateKey({name:'ECDSA',namedCurve:'P-256'},true,['sign','verify']);
  const exported=new Uint8Array(await crypto.subtle.exportKey('pkcs8',keys.privateKey));
  const pem=`-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...exported))}\n-----END PRIVATE KEY-----`;
  const jwt=await apnsJwt(pem,'KEY123','TEAM456',123456);
  const [header,claims,signature]=jwt.split('.');
  const decode=(part:string)=>Uint8Array.from(atob(part.replaceAll('-','+').replaceAll('_','/')),c=>c.charCodeAt(0));
  assert.deepEqual(JSON.parse(new TextDecoder().decode(decode(header))),{alg:'ES256',kid:'KEY123'});
  assert.deepEqual(JSON.parse(new TextDecoder().decode(decode(claims))),{iss:'TEAM456',iat:123456});
  assert.ok(await crypto.subtle.verify({name:'ECDSA',hash:'SHA-256'},keys.publicKey,decode(signature),new TextEncoder().encode(`${header}.${claims}`)));
});
