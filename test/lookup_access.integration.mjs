import assert from 'node:assert/strict';
import { hasActiveLookupSubscription } from '../supabase/functions/lookup-vehicle/lookup_access.ts';
const now=Date.parse('2026-10-28T03:00:00Z');
const row=(product_id,status='active') => ({product_id,status,
  started_at:new Date(now-1000).toISOString(),expires_at:new Date(now+1000).toISOString()});
for(const product of ['automotors_pack_20','automotors_pro_monthly_199']) {
  assert.equal(hasActiveLookupSubscription([row(product)],now),true);
  assert.equal(hasActiveLookupSubscription([row(product,'grace_period')],now),true);
  for(const status of ['pending','revoked','expired','canceled'])
    assert.equal(hasActiveLookupSubscription([row(product,status)],now),false);
  assert.equal(hasActiveLookupSubscription([{...row(product),expires_at:new Date(now).toISOString()}],now),false);
  assert.equal(hasActiveLookupSubscription([{...row(product),started_at:new Date(now+1000).toISOString()}],now),false);
  assert.equal(hasActiveLookupSubscription([{...row(product),expires_at:null}],now),false);
}
for(const product of ['automotors_pack_10','automotors_pack_15','unknown'])
  assert.equal(hasActiveLookupSubscription([row(product)],now),false);
assert.equal(hasActiveLookupSubscription([],now),false);
console.log('PASS: lookup requires a verified, current PACK 20 or PRO; lower plans, invalid dates and revoked purchases stay locked.');
