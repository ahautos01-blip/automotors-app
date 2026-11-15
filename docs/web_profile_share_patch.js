const params=new URL(location.href).searchParams;
const seller=params.get('seller');
const validId=value=>/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value||'');
const api='https://ndicdhlpbyywqyjgxpnx.supabase.co/rest/v1/';
const headers={apikey:'sb_publishable_TBWahz_XJ9lcoBdSSxfpNQ_vhzdDTlu'};
async function loadProfile(){
 const title=document.querySelector('#title'),facts=document.querySelector('#facts'),open=document.querySelector('#open'),description=document.querySelector('#description');
 if(!validId(seller)||params.has('listing')){title.textContent='Enlace de perfil no válido';return;}
 try{
  const response=await fetch(api+'public_seller_profiles?select=id,full_name,business_name,account_type,city,province&id=eq.'+encodeURIComponent(seller),{headers});
  if(!response.ok)throw Error('unavailable');const profile=(await response.json())[0];
  if(!profile||!['empresa','autonomo'].includes(profile.account_type)){title.textContent='Este perfil profesional no está disponible.';return;}
  document.title='Perfil profesional · AUTOMOTORS';
  document.querySelector('.eyebrow').textContent='PERFIL PROFESIONAL';
  title.textContent=profile.business_name||profile.full_name||'Profesional AUTOMOTORS';
  facts.textContent=[profile.city,profile.province].filter(Boolean).join(', ');
  open.textContent='Ver perfil y vehículos en AUTOMOTORS ↗';open.href='com.automotors.automotorsbase://seller?seller='+encodeURIComponent(seller);open.hidden=false;
  document.querySelector('#help').textContent='Abre el perfil con una versión compatible de AUTOMOTORS. Los datos profesionales son declarados por el vendedor.';
  const stock=await fetch(api+'vehicle_listings?select=id,price,year,vehicle_brands(name),vehicle_models(name)&owner_id=eq.'+encodeURIComponent(seller)+'&status=in.(published,reserved)&order=created_at.desc&limit=20',{headers});
  if(!stock.ok){description.textContent='No se pudo cargar el inventario. Abre el perfil en la app.';return;}
  const cars=await stock.json();description.textContent=cars.length?'Vehículos publicados y reservados:':'Todavía no hay vehículos públicos.';
  let previous=description;
  for(const car of cars){const p=document.createElement('p'),link=document.createElement('a');link.textContent=[car.vehicle_brands?.name,car.vehicle_models?.name,car.year,Number(car.price).toLocaleString('es-ES',{style:'currency',currency:'EUR'})].filter(Boolean).join(' · ');link.href='/anuncio/?listing='+encodeURIComponent(car.id);p.append(link);previous.after(p);previous=p;}
 }catch(_){title.textContent='No se pudo cargar el perfil';facts.textContent='Comprueba la conexión o vuelve a intentarlo más tarde.';}
}
const id=new URL(location.href).searchParams.get('listing');const title=document.querySelector('#title'),facts=document.querySelector('#facts'),open=document.querySelector('#open');
async function load(){
 if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id||'')){title.textContent='Enlace de anuncio no válido';return;}
 try{
 const response=await fetch('https://ndicdhlpbyywqyjgxpnx.supabase.co/rest/v1/vehicle_listings?select=id,status,year,km,price,description,vehicle_brands(name),vehicle_models(name)&id=eq.'+encodeURIComponent(id)+'&status=in.(published,reserved,sold)',{headers:{apikey:'sb_publishable_TBWahz_XJ9lcoBdSSxfpNQ_vhzdDTlu'}});
 if(!response.ok)throw Error('unavailable');const rows=await response.json();const car=rows[0];if(!car){title.textContent='Este anuncio ya no está disponible.';facts.textContent='Puede haberse retirado o no ser público.';return;}
 title.textContent=[car.vehicle_brands?.name,car.vehicle_models?.name].filter(Boolean).join(' ')||'Vehículo anunciado';
 facts.textContent=[Number(car.price).toLocaleString('es-ES',{style:'currency',currency:'EUR'}),car.year,Number(car.km).toLocaleString('es-ES')+' km',car.status==='sold'?'Vendido':car.status==='reserved'?'Reservado':'Publicado'].join(' · ');
 document.querySelector('#description').textContent=car.description||'';open.href='com.automotors.automotorsbase://listing?listing='+encodeURIComponent(id);open.hidden=false;
 }catch(_){title.textContent='No se pudo consultar el anuncio';facts.textContent='Comprueba la conexión o vuelve a intentarlo más tarde.';}
}
if(params.has('seller')){loadProfile();}else{load();}
