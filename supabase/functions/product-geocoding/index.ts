import {createClient} from 'npm:@supabase/supabase-js@2.57.4';
import {geoRequest,addressRows} from './core.ts';
const origins=new Set((Deno.env.get('PRODUCT_ALLOWED_ORIGINS')??'').split(',').map(v=>v.trim()).filter(Boolean));
function allowed(origin:string|null){if(!origin)return true;if(origins.has(origin))return true;try{return ['localhost','127.0.0.1','[::1]'].includes(new URL(origin).hostname);}catch{return false;}}
function reply(req:Request,status:number,payload:unknown){const headers:Record<string,string>={'Content-Type':'application/json','Cache-Control':'no-store','Vary':'Origin','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'POST, OPTIONS'};const origin=req.headers.get('origin');if(origin&&allowed(origin))headers['Access-Control-Allow-Origin']=origin;return new Response(JSON.stringify(payload),{status,headers});}
Deno.serve(async(req:Request)=>{
 if(!allowed(req.headers.get('origin')))return reply(req,403,{error:'origin_not_allowed'});
 if(req.method==='OPTIONS')return reply(req,200,{});
 if(req.method!=='POST')return reply(req,405,{error:'method_not_allowed'});
 const project=Deno.env.get('SUPABASE_URL')??'';
 // Production promotion is authorized; provider credentials remain server-only.
 if(Deno.env.get('PRODUCT_GEOCODING_ENABLED')!=='true')return reply(req,503,{error:'geocoding_not_enabled'});
 const key=Deno.env.get('GEOAPIFY_SERVER_KEY');
 if(!key)return reply(req,503,{error:'geocoding_not_configured'});
 try{
  const authorization=req.headers.get('authorization')??'';
  if(!authorization.startsWith('Bearer '))return reply(req,401,{error:'authentication_required'});
  const client=createClient(project,Deno.env.get('SUPABASE_ANON_KEY')??'',{global:{headers:{Authorization:authorization}},auth:{persistSession:false,autoRefreshToken:false}});
  const {data,error}=await client.auth.getUser(authorization.slice(7));
  if(error||!data.user)return reply(req,401,{error:'authentication_required'});
  const text=await req.text();if(text.length>4096)return reply(req,413,{error:'request_too_large'});
  const body=JSON.parse(text);if(!body||Array.isArray(body)||typeof body!=='object')return reply(req,400,{error:'invalid_request'});
  const url=geoRequest(body,key);
  const budget=await client.rpc('v51_geocoding_budget');
  if(budget.error)return reply(req,503,{error:'budget_check_unavailable'});
  if(budget.data!==true)return reply(req,429,{error:'geocoding_rate_limit'});
  const upstream=await fetch(url,{signal:AbortSignal.timeout(6500)});
  if(!upstream.ok)return reply(req,502,{error:'geocoding_provider_unavailable'});
  const raw=await upstream.json();
  if(body.operation==='route'){
   const route=raw.features?.[0];const distance=route?.properties?.distance,time=route?.properties?.time;
   if(!Number.isFinite(distance)||distance<=0||!Number.isFinite(time)||time<=0)return reply(req,502,{error:'route_unavailable'});
   return reply(req,200,{distance_km:distance/1000,duration_minutes:time/60,geometry:route.geometry,source:'geoapify',financial_quote:false});
  }
  return reply(req,200,{results:addressRows(raw),source:'geoapify',user_confirmation_required:true});
 }catch(e){return reply(req,e instanceof SyntaxError||e instanceof Error&&['invalid_coordinates','invalid_query','invalid_operation'].includes(e.message)?400:502,{error:e instanceof Error&&['invalid_coordinates','invalid_query','invalid_operation'].includes(e.message)?e.message:'geocoding_unavailable'});}
});
