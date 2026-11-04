import { apnsJwt, outcome, payload, type Delivery } from './core.ts';

const apiUrl = Deno.env.get('SUPABASE_URL')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const reply = (status: number, value: unknown) => new Response(JSON.stringify(value), {
  status, headers: {'Content-Type':'application/json','Cache-Control':'no-store'},
});
let jwt: {value: string; issued: number} | undefined;
let apnsClient: Deno.HttpClient | undefined;

async function rpc(name: string, args: Record<string,unknown>) {
  const response = await fetch(`${apiUrl}/rest/v1/rpc/${name}`, {
    method:'POST',
    headers:{apikey:serviceKey,Authorization:`Bearer ${serviceKey}`,'Content-Type':'application/json'},
    body:JSON.stringify(args), signal:AbortSignal.timeout(15000),
  });
  if (!response.ok) throw new Error(`Database operation failed: ${name}`);
  const body = await response.text();
  return body ? JSON.parse(body) : null;
}

Deno.serve(async request => {
  if (request.method !== 'POST') return reply(405,{error:'Method not allowed'});
  const workerToken = request.headers.get('x-worker-token');
  if (!workerToken || workerToken.length !== 64) return reply(401,{error:'Unauthorized'});
  try {
    if (!await rpc('authorize_push_worker',{p_token:workerToken})) return reply(401,{error:'Unauthorized'});
    apnsClient ??= Deno.createHttpClient({http1:false,http2:true});
    const pem = Deno.env.get('APNS_PRIVATE_KEY');
    const keyId = Deno.env.get('APNS_KEY_ID');
    const teamId = Deno.env.get('APNS_TEAM_ID');
    const bundleId = Deno.env.get('IOS_BUNDLE_ID');
    // Keep jobs pending until the APNs key has been configured. Do not burn retries.
    if (!pem || !keyId || !teamId || !bundleId) return reply(503,{
      error:'apns_not_configured',
      missing:['APNS_PRIVATE_KEY','APNS_KEY_ID','APNS_TEAM_ID','IOS_BUNDLE_ID'].filter(name=>!Deno.env.get(name)),
    });
    const now = Math.floor(Date.now()/1000);
    if (!jwt || now-jwt.issued>=2700) jwt={value:await apnsJwt(pem,keyId,teamId,now),issued:now};
    const jobs = await rpc('claim_push_deliveries',{p_token:workerToken}) as Delivery[];
    let accepted=0;
    // Bounded batches, with per-device leases and independent retries.
    for (let offset=0;offset<jobs.length;offset+=5) {
      await Promise.all(jobs.slice(offset,offset+5).map(async job => {
        let result;
        try {
          const host=job.environment==='sandbox'?'api.sandbox.push.apple.com':'api.push.apple.com';
          const response=await fetch(`https://${host}/3/device/${job.token}`,{
            method:'POST',client:apnsClient,
            headers:{authorization:`bearer ${jwt!.value}`,'apns-topic':bundleId,
              'apns-push-type':'alert','apns-priority':'10','apns-id':job.id,
              'apns-expiration':String(job.expiration),'Content-Type':'application/json'},
            body:JSON.stringify(payload(job)),signal:AbortSignal.timeout(10000),
          });
          const body=await response.text();
          let reason='';
          try { reason=body ? JSON.parse(body).reason ?? '' : ''; } catch { reason='invalid_response'; }
          result=outcome(response.status,reason,job.attempts);
          const retryAfter=Number(response.headers.get('retry-after'));
          if (Number.isFinite(retryAfter) && retryAfter>0) result.retry=Math.min(3600,Math.max(result.retry,retryAfter));
        } catch { result=outcome(0,'transport_error',job.attempts); }
        await rpc('finish_push_delivery',{
          p_id:job.id,p_lease_token:job.lease_token,p_status:result.status,p_error:result.error,
          p_retry_seconds:result.retry,p_disable_device:result.disable,
        });
        if(result.status==='sent') accepted++;
      }));
    }
    return reply(200,{processed:jobs.length,accepted});
  } catch {
    // Never log the request headers, APNs tokens, private key or database bodies.
    return reply(500,{error:'push_worker_failed'});
  }
});
