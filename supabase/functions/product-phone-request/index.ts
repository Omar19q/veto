import {createClient} from 'npm:@supabase/supabase-js@2.57.4';
import {productPhone} from '../_shared/product_phone_veto2.ts';
import {loginBudgetV15} from '../_shared/login_budget_scale_v15.ts';
const headers={'Content-Type':'application/json','Cache-Control':'no-store','Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'POST,OPTIONS'};
const reply=(status:number,body:unknown)=>new Response(JSON.stringify(body),{status,headers});
Deno.serve(async req=>{
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers});
 if(req.method!=='POST')return reply(405,{success:false,error:'method_not_allowed'});
 try{
  const text=await req.text();if(text.length>4096)return reply(413,{success:false,error:'request_too_large'});
  const input=JSON.parse(text),phone=productPhone(String(input?.phone??''));
  if(!phone||phone.country==='EG')return reply(400,{success:false,error:'invalid_international_phone'});
  const key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),url=Deno.env.get('SUPABASE_URL');
  if(!key||!url)return reply(503,{success:false,error:'server_not_configured'});
  const admin=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
  const budget=await loginBudgetV15(admin,'customer',phone.lookup,key);
  if(budget)return reply(budget==='limited'?429:503,{success:false,error:budget==='limited'?'login_rate_limit':'login_service_unavailable'});
  const result=await admin.rpc('v51_international_verification_request',{p_phone:phone.lookup});
  if(result.error)return reply(503,{success:false,error:'verification_request_failed'});
  // Only request ID and lifecycle status, never the verification code.
  return reply(200,result.data);
 }catch(_){return reply(400,{success:false,error:'invalid_request'});}
});
