export interface Delivery {
  id: string;
  lease_token: string;
  attempts: number;
  kind: 'chat_message' | 'review_requested';
  user_id: string;
  listing_id: string;
  conversation_id: string | null;
  token: string;
  environment: 'sandbox' | 'production';
  expiration: number;
}

// Do not put chat text or sender details on the lock screen.
export function payload(job: Delivery) {
  return {
    aps: {
      alert: job.kind === 'chat_message'
        ? { title: 'Nuevo mensaje en AUTOMOTORS', body: 'Tienes un mensaje nuevo. Pulsa para abrir la conversación.' }
        : { title: 'Valora tu compra', body: 'El vendedor ha confirmado tu compra. Cuéntanos tu experiencia.' },
      sound: 'default',
      'thread-id': job.kind === 'chat_message' ? `chat-${job.conversation_id}` : 'purchase-reviews',
    },
    notification_id: job.id,
    kind: job.kind,
    user_id: job.user_id,
    listing_id: job.listing_id,
    ...(job.kind === 'chat_message' ? { conversation_id: job.conversation_id } : {}),
  };
}

export function outcome(status: number, reason: string, attempts: number) {
  if (status === 200) return { status: 'sent', error: null, retry: 60, disable: false };
  const invalidToken = status === 410 || (status === 400 && reason === 'BadDeviceToken');
  const retryable = status === 403 || status === 429 || status >= 500 || status === 0;
  return {
    status: retryable && attempts < 8 ? 'pending' : 'failed',
    error: reason.replace(/[^a-zA-Z0-9_-]/g, '').slice(0,80) || `http_${status}`,
    retry: status === 403 ? 900 : Math.min(3600, 30 * 2 ** attempts),
    disable: invalidToken,
  };
}

function base64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replaceAll('+','-').replaceAll('/','_').replaceAll('=','');
}

export async function apnsJwt(pem: string, keyId: string, teamId: string, now: number): Promise<string> {
  const normalized = pem.replaceAll('\\n','\n');
  const body = normalized.replace(/-----[^-]+-----/g,'').replace(/\s/g,'');
  const key = await crypto.subtle.importKey('pkcs8',Uint8Array.from(atob(body),c=>c.charCodeAt(0)),
    {name:'ECDSA',namedCurve:'P-256'},false,['sign']);
  const encode = (value: unknown) => base64url(new TextEncoder().encode(JSON.stringify(value)));
  const input = `${encode({alg:'ES256',kid:keyId})}.${encode({iss:teamId,iat:now})}`;
  const signature = await crypto.subtle.sign({name:'ECDSA',hash:'SHA-256'},key,new TextEncoder().encode(input));
  return `${input}.${base64url(new Uint8Array(signature))}`;
}
