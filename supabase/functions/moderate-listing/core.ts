import {classify,imageDataUrl,moderationModel,ModerationUnavailable} from './provider.ts';
type Config={url:string;serviceKey:string;openaiKey:string};
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const reply=(status:number,value:unknown)=>new Response(JSON.stringify(value),{status,headers:{
  'Content-Type':'application/json','Cache-Control':'no-store','Access-Control-Allow-Origin':'*',
  'Access-Control-Allow-Headers':'authorization, apikey, x-client-info, content-type','Access-Control-Allow-Methods':'POST, OPTIONS',
}});
const neutralImage='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAQAAAAEACAIAAADTED8xAAACvUlEQVR4nO3TMQEAIAzAMED5pCNjRxMFfXpn5kDV2w6ATQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMQJoBSDMAaQYgzQCkGYA0A5BmANIMwCn77ssDgNkp7XsAAAAASUVORK5CYII=';
export function listingModerationHandler(config:Config,fetcher:typeof fetch=fetch){
  const serviceHeaders={apikey:config.serviceKey,Authorization:`Bearer ${config.serviceKey}`,'Content-Type':'application/json'};
  const call=(path:string,options:RequestInit)=>fetcher(`${config.url}${path}`,{...options,signal:AbortSignal.timeout(25000)});
  const rpc=async(name:string,args:Record<string,unknown>)=>{
    const response=await call(`/rest/v1/rpc/${name}`,{method:'POST',headers:serviceHeaders,body:JSON.stringify(args)});
    if(!response.ok) throw new ModerationUnavailable(response.status===403?'listing_unavailable':'verification_failed');
    const text=await response.text();return text?JSON.parse(text):null;
  };
  return async(request:Request):Promise<Response>=>{
    if(request.method==='OPTIONS') return reply(200,{ok:true});
    if(request.method!=='POST') return reply(405,{error:'method_not_allowed'});
    const deadline=Date.now()+90000;
    const budgetFetch:typeof fetch=(url,options={})=>{
      const remaining=deadline-Date.now();
      if(remaining<=0) throw new ModerationUnavailable('provider_unavailable');
      return fetcher(url,{...options,redirect:'error',signal:AbortSignal.timeout(Math.min(25000,remaining))});
    };
    const authorization=request.headers.get('Authorization')??'';
    if(!/^Bearer [^ ]+$/.test(authorization)) return reply(401,{error:'authentication_required'});
    let body;
    try {body=await request.json();} catch {return reply(400,{error:'invalid_request'});}
    if(body?.action==='probe') {
      // Only the existing server credential can run the harmless synthetic probe.
      if(authorization!==serviceHeaders.Authorization||Object.keys(body).length!==1) return reply(403,{error:'service_required'});
      let result;
      try {
        const text=await classify('Anuncio de un automÃ³vil de segunda mano en buen estado.',config.openaiKey,budgetFetch);
        const image=await classify([{type:'image_url',image_url:{url:neutralImage}}],config.openaiKey,budgetFetch);
        result={connected:!text.flagged&&!image.flagged,text_checked:true,image_checked:true,model:moderationModel};
      } catch(error) {result={connected:false,error:error instanceof ModerationUnavailable?error.code:'provider_unavailable'};}
      try {await rpc('content_provider_probe_result',{p_result:result});} catch {return reply(503,{error:'probe_record_failed'});}
      return reply(result.connected?200:503,result);
    }
    if(body?.action!=='publish'||!uuid.test(body?.listing_id??'')||Object.keys(body).some(key=>!['action','listing_id','target_status'].includes(key))||
        (body.target_status!==undefined&&!['published','reserved'].includes(body.target_status))) return reply(400,{error:'invalid_request'});
    if(!config.openaiKey) return reply(503,{error:'provider_not_configured'});
    let args:Record<string,unknown>|undefined;
    let lease:string|undefined;
    try {
      const identity=await call('/auth/v1/user',{headers:{...serviceHeaders,Authorization:authorization}});
      if(!identity.ok) return reply(401,{error:'authentication_required'});
      const user=await identity.json();
      let sessionId:string;
      try {const segment=authorization.slice(7).split('.')[1];sessionId=JSON.parse(atob(segment.replace(/-/g,'+').replace(/_/g,'/'))).session_id;}
      catch{return reply(401,{error:'authentication_required'});}
      if(!uuid.test(user.id??'')||!uuid.test(sessionId??'')) return reply(401,{error:'authentication_required'});
      args={p_user_id:user.id,p_session_id:sessionId,p_listing_id:body.listing_id};
      const snapshot=await rpc('prepare_listing_content_check',{...args,p_target_status:body.target_status??'published'});
      lease=snapshot.lease_id;
      if(!uuid.test(lease??'')||typeof snapshot.text!=='string'||snapshot.text.length>25000||!Array.isArray(snapshot.photos)||snapshot.photos.length<1||snapshot.photos.length>15) throw new ModerationUnavailable('invalid_snapshot');
      let result=await classify(snapshot.text,config.openaiKey,budgetFetch);
      for(const photo of snapshot.photos) {
        if(result.flagged) break;
        const path=photo.path;
        if(typeof path!=='string'||!path.startsWith(`${user.id}/${body.listing_id}/`)||!/^[-a-zA-Z0-9._/]+$/.test(path)||path.split('/').some((part:string)=>!part||part==='.'||part==='..')) throw new ModerationUnavailable('invalid_photo');
        const image=await budgetFetch(`${config.url}/storage/v1/object/authenticated/vehicle-photos/${path.split('/').map(encodeURIComponent).join('/')}`,{headers:serviceHeaders});
        if(!image.ok) throw new ModerationUnavailable('photo_unavailable');
        const length=Number(image.headers.get('content-length'));
        if(length>20*1024*1024) throw new ModerationUnavailable('unsupported_image');
        const data=imageDataUrl(new Uint8Array(await image.arrayBuffer()));
        result=await classify([{type:'image_url',image_url:{url:data}}],config.openaiKey,budgetFetch);
      }
      const final=await rpc('finish_listing_content_check',{...args,p_lease_id:lease,p_outcome:result.flagged?'rejected':'approved',p_categories:result.categories,p_error_code:null});
      return reply(final.published?200:final.state==='rejected'?422:409,final);
    } catch(error) {
      const code=error instanceof ModerationUnavailable?error.code:'provider_unavailable';
      if(args&&lease) {
        try {await rpc('finish_listing_content_check',{...args,p_lease_id:lease,p_outcome:'error',p_categories:[],p_error_code:code});} catch {/* Never override a newer lease or claim publication. */}
      }
      return reply(503,{error:code,published:false});
    }
  };
}
