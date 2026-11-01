type Config = {url: string; serviceKey: string};
type FileEntry = {bucket: string; path: string};
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const reply = (status: number, body: unknown) => new Response(JSON.stringify(body), {
  status, headers: {'Content-Type':'application/json','Cache-Control':'no-store','Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, apikey, x-client-info, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'},
});

export function accountDeletionHandler(config: Config, fetcher: typeof fetch = fetch) {
  return async (request: Request): Promise<Response> => {
    if (request.method === 'OPTIONS') return reply(200,{ok:true});
    if (request.method !== 'POST') return reply(405,{error:'method_not_allowed'});
    const authorization = request.headers.get('Authorization') ?? '';
    if (!/^Bearer [^ ]+$/.test(authorization)) return reply(401,{error:'authentication_required'});
    let body: unknown;
    try { body = await request.json(); } catch { return reply(400,{error:'confirmation_required'}); }
    if (!body || typeof body !== 'object' || Object.keys(body).length !== 1
        || (body as {confirmation?:string}).confirmation !== 'DELETE') {
      return reply(400,{error:'confirmation_required'});
    }
    const headers = {apikey:config.serviceKey,Authorization:`Bearer ${config.serviceKey}`,'Content-Type':'application/json'};
    const call = (path: string, options: RequestInit) => fetcher(`${config.url}${path}`, {
      ...options, signal:AbortSignal.timeout(25000),
    });
    try {
      // Validate with Auth before looking at any untrusted JWT claims.
      const identity = await call('/auth/v1/user',{headers:{...headers,Authorization:authorization}});
      if (!identity.ok) return reply(401,{error:'authentication_required'});
      const user = await identity.json();
      if (!uuid.test(user.id ?? '')) return reply(401,{error:'authentication_required'});
      let sessionId: string;
      try {
        const segment = authorization.slice(7).split('.')[1];
        sessionId = JSON.parse(atob(segment.replace(/-/g,'+').replace(/_/g,'/'))).session_id;
      } catch { return reply(401,{error:'authentication_required'}); }
      if (!uuid.test(sessionId ?? '')) return reply(401,{error:'authentication_required'});
      const args = {p_user_id:user.id,p_session_id:sessionId};
      const rpc = async (name: string) => {
        const result = await call(`/rest/v1/rpc/${name}`,{method:'POST',headers,body:JSON.stringify(args)});
        if (!result.ok) throw new Error('cleanup_failed');
        const text = await result.text();
        return text ? JSON.parse(text) : null;
      };
      // Idempotent prepare freezes client writes before collecting actual Storage objects.
      const files = await rpc('prepare_account_deletion') as FileEntry[];
      if (!Array.isArray(files)) throw new Error('invalid_manifest');
      const buckets = new Map<string,string[]>();
      for (const file of files) {
        if (typeof file.bucket !== 'string' || typeof file.path !== 'string') throw new Error('invalid_manifest');
        const paths = buckets.get(file.bucket) ?? [];
        paths.push(file.path); buckets.set(file.bucket,paths);
      }
      for (const [bucket, paths] of buckets) {
        for (let offset=0;offset<paths.length;offset+=100) {
          const removed = await call(`/storage/v1/object/${encodeURIComponent(bucket)}`,{
            method:'DELETE',headers,body:JSON.stringify({prefixes:paths.slice(offset,offset+100)}),
          });
          if (!removed.ok) throw new Error('storage_failed');
        }
      }
      await rpc('cleanup_account_data');
      const deleted = await call(`/auth/v1/admin/users/${encodeURIComponent(user.id)}`,{
        method:'DELETE',headers,body:JSON.stringify({should_soft_delete:false}),
      });
      if (!deleted.ok) throw new Error('auth_delete_failed');
      return reply(200,{deleted:true});
    } catch {
      // No tokens, identifiers or personal data in logs or client errors.
      // The marker persists on partial failure; the same account can retry safely.
      return reply(503,{error:'deletion_incomplete_retry'});
    }
  };
}
