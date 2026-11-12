export const moderationModel='omni-moderation-2024-09-26';
export class ModerationUnavailable extends Error {
  readonly code:string;
  constructor(code:string){super(code);this.code=code;}
}
export type Classification={flagged:boolean;categories:string[]};
export async function classify(input:unknown,apiKey:string,fetcher:typeof fetch=fetch):Promise<Classification> {
  if(!apiKey) throw new ModerationUnavailable('provider_not_configured');
  let response:Response;
  try {
    response=await fetcher('https://api.openai.com/v1/moderations',{
      method:'POST',headers:{Authorization:`Bearer ${apiKey}`,'Content-Type':'application/json'},
      body:JSON.stringify({model:moderationModel,input}),signal:AbortSignal.timeout(25000),
    });
  } catch {throw new ModerationUnavailable('provider_unavailable');}
  if(!response.ok) throw new ModerationUnavailable(response.status===429?'provider_rate_limit':response.status===401?'provider_auth_failed':response.status===403?'provider_permission_denied':'provider_unavailable');
  let data;
  try {data=await response.json();} catch {throw new ModerationUnavailable('provider_invalid_response');}
  const result=data?.results?.[0];
  if(!Array.isArray(data?.results)||data.results.length!==1||typeof result?.flagged!=='boolean'||
      !result.categories||typeof result.categories!=='object'||Array.isArray(result.categories)) throw new ModerationUnavailable('provider_invalid_response');
  const entries=Object.entries(result.categories);
  if(entries.length===0||entries.some(([,flag])=>typeof flag!=='boolean')) throw new ModerationUnavailable('provider_invalid_response');
  const categories=entries.filter(([,flag])=>flag===true).map(([name])=>name);
  // Never accept contradictory provider data or a newly flagged category.
  if(!result.flagged&&categories.length>0) throw new ModerationUnavailable('provider_invalid_response');
  return {flagged:result.flagged,categories};
}
export function imageDataUrl(bytes:Uint8Array):string {
  if(bytes.length===0||bytes.length>20*1024*1024) throw new ModerationUnavailable('unsupported_image');
  const mime=bytes[0]===0xff&&bytes[1]===0xd8&&bytes[2]===0xff?'image/jpeg':
    bytes[0]===137&&bytes[1]===80&&bytes[2]===78&&bytes[3]===71?'image/png':
    String.fromCharCode(...bytes.subarray(0,4))==='RIFF'&&String.fromCharCode(...bytes.subarray(8,12))==='WEBP'?'image/webp':null;
  if(!mime) throw new ModerationUnavailable('unsupported_image');
  const chunks:string[]=[];
  for(let i=0;i<bytes.length;i+=8192) chunks.push(String.fromCharCode(...bytes.subarray(i,i+8192)));
  return `data:${mime};base64,${btoa(chunks.join(''))}`;
}
