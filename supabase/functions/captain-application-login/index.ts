import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

async function loginBudgetV15(admin: any, scope: string, identity: string, secret: string): Promise<'limited' | 'unavailable' | null> {
  try {
    const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
    const bytes = new Uint8Array(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(scope + ':' + identity)));
    const subject = Array.from(bytes, b => b.toString(16).padStart(2,'0')).join('');
    const { data, error } = await admin.rpc('claim_login_budget_scale_v15', { p_scope: scope, p_subject: subject });
    if (error) return 'unavailable';
    return data === true ? null : 'limited';
  } catch { return 'unavailable'; }
}

const headers = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,x-client-info,apikey,content-type','Content-Type':'application/json'};
const reply=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers});

serve(async req=>{
 if(req.method==='OPTIONS') return reply({});
 if(req.method!=='POST') return reply({error:'method_not_allowed'},405);
 try {
  const raw=await req.text(); if(raw.length>2048) return reply({error:'request_too_large'},413);
  const body=JSON.parse(raw); let phone=String(body.phone??'').replace(/\D/g,'');
  if(phone.startsWith('20')&&phone.length===12) phone='0'+phone.slice(2);
  const code=String(body.code??'').trim();
  if(!/^01[0125]\d{8}$/.test(phone)||!/^\d{4}$/.test(code)) return reply({error:'verification_invalid'},400);
  const key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const admin=createClient(Deno.env.get('SUPABASE_URL')!,key,{auth:{persistSession:false,autoRefreshToken:false}});
  const budget=await loginBudgetV15(admin,'captain',phone,key); if(budget) return reply({error:'login_rate_limit'},429);
  const reserved=await admin.rpc('v16_phone_reserved',{p_phone:phone});
  if(reserved.error) throw reserved.error;
  if(reserved.data) return reply({error:'account_role_conflict'},409);
  for(const table of ['customers','captains']) {
   const found=await admin.from(table).select('id').eq('phone',phone).maybeSingle();
   if(found.error) throw found.error;
   if(found.data) return reply({error:'account_role_conflict'},409);
  }
  const consumed=await admin.rpc('v16_consume_application_code',{p_phone:phone,p_code:code});
  if(consumed.error) throw consumed.error;
  if(consumed.data!==true) return reply({error:'verification_invalid'},400);
  const binding=await admin.from('v16_captain_identities').select('user_id').eq('phone',phone).maybeSingle();
  if(binding.error) throw binding.error;
  let user;
  if(binding.data){
   const result=await admin.auth.admin.getUserById(binding.data.user_id); if(result.error) throw result.error; user=result.data.user;
  }else{
   const email=`applicant_${phone}@vetosanya.internal`;
   const profile=await admin.from('user_profiles').select('id').eq('phone',phone).maybeSingle();
   if(profile.error) throw profile.error;
   if(profile.data){const existing=await admin.auth.admin.getUserById(profile.data.id); if(existing.error) throw existing.error; user=existing.data.user;}
   else {const made=await admin.auth.admin.createUser({email,password:crypto.randomUUID()+crypto.randomUUID(),email_confirm:true,user_metadata:{phone,role:'customer'},app_metadata:{v16_applicant:true}}); if(made.error) throw made.error; user=made.data.user;}
  }
  if(!user||user.app_metadata?.v16_applicant!==true||!user.email) return reply({error:'account_role_conflict'},409);
  const bound=await admin.from('v16_captain_identities').upsert({user_id:user.id,phone,verified_at:new Date().toISOString()},{onConflict:'user_id'}); if(bound.error) throw bound.error;
  const link=await admin.auth.admin.generateLink({type:'magiclink',email:user.email}); if(link.error) throw link.error;
  return reply({success:true,email:user.email,token:link.data.properties.email_otp});
 }catch{ return reply({error:'application_login_failed'},500); }
});
