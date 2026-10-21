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

const headers = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization,x-client-info,apikey,content-type', 'Content-Type': 'application/json' };
const reply = (body: unknown, status=200) => new Response(JSON.stringify(body), {status, headers});

serve(async req => {
 if(req.method==='OPTIONS') return new Response(null,{status:204,headers});
 if(req.method!=='POST') return reply({success:false,error:'method_not_allowed'},405);
 try {
  const raw=await req.text(); if(raw.length>2048) return reply({success:false,error:'invalid_request'},400);
  const body=JSON.parse(raw); const phone=String(body.phone??'').replace(/\D/g,'').replace(/^20/,'0');
  const code=String(body.code??'');
  if(!/^01[0125]\d{8}$/.test(phone)||!/^\d{4}$/.test(code)) return reply({success:false,error:'verification_invalid'});
  const url=Deno.env.get('SUPABASE_URL')??'', key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')??'';
  if(!url||!key) return reply({success:false,error:'server_not_configured'},503);
  const admin=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
  const budget=await loginBudgetV15(admin,'customer',`staff:${phone}`,key);
  if(budget) return reply({success:false,error:'login_rate_limit'},429);
  const {data: claim,error}=await admin.rpc('v16_staff_consume_code',{p_phone:phone,p_code:code});
  if(error||!claim?.id) return reply({success:false,error:'verification_invalid'});
  const email=`staff-${claim.id}@vetosanya.app`;
  let userId=claim.user_id as string|null;
  if(!userId) {
   const {data:created,error:createError}=await admin.auth.admin.createUser({email,email_confirm:true,
    password:crypto.randomUUID()+crypto.randomUUID(), app_metadata:{role:'staff',v16_staff_id:claim.id},user_metadata:{phone,full_name:claim.name}});
   if(createError||!created.user) {
    const {data:found,error:findError}=await admin.rpc('v16_staff_auth_identity',{p_staff_id:claim.id});
    if(findError||!found) return reply({success:false,error:'staff_login_retry'},409);
    userId=String(found);
   } else userId=created.user.id;
  }
  const {data:existing,error:userError}=await admin.auth.admin.getUserById(userId!);
  if(userError || !existing.user)
   return reply({success:false,error:'staff_identity_mismatch'},403);
  const isolatedStaff = existing.user.app_metadata?.role==='staff' &&
    existing.user.app_metadata?.v16_staff_id===claim.id;
  if (!isolatedStaff) {
    const { data: linked, error: linkedError } = await admin.rpc(
      'v21_staff_shared_identity_allowed',
      { p_staff_id: claim.id, p_user_id: userId, p_phone: phone },
    );
    if (linkedError || linked !== true)
      return reply({success:false,error:'staff_identity_mismatch'},403);
  }
  const {error:bindError}=await admin.rpc('v16_staff_bind',{p_staff_id:claim.id,p_user_id:userId});
  if(bindError) return reply({success:false,error:'staff_unavailable'},403);
  const {data:link,error:linkError}=await admin.auth.admin.generateLink({type:'magiclink',email:existing.user.email!});
  if(linkError||!link.properties?.email_otp) return reply({success:false,error:'staff_login_retry'},503);
  return reply({success:true,email:existing.user.email,token:link.properties.email_otp});
 } catch {return reply({success:false,error:'staff_login_unavailable'},503);}
});
