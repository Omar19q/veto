import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
// Cross-instance atomic limiter. Identifiers are HMACed, never persisted raw.
export async function loginBudgetV15(admin: SupabaseClient, scope: string, identity: string,
  secret: string): Promise<'limited' | 'unavailable' | null> {
  try {
    const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret),
      { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
    const bytes = new Uint8Array(await crypto.subtle.sign('HMAC', key,
      new TextEncoder().encode(scope + ':' + identity)));
    const subject = Array.from(bytes, b => b.toString(16).padStart(2,'0')).join('');
    const { data, error } = await admin.rpc('claim_login_budget_scale_v15', {
      p_scope: scope, p_subject: subject,
    });
    if (error) return 'unavailable';
    return data === true ? null : 'limited';
  } catch { return 'unavailable'; }
}
