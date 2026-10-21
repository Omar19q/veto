import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, type SupabaseClient, type User } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return response({ success: false, error: "method_not_allowed" }, 405);
  try {
    const body = await req.json();
    const phone = normalizePhone(String(body?.phone ?? ""));
    const code = String(body?.code ?? "").trim();
    if (!phone || !/^\d{4}$/.test(code)) return response({ success: false, error: "verification_invalid" });

    const url = Deno.env.get("SUPABASE_URL") ?? "";
    const key = adminKey();
    if (!url || !key) return response({ success: false, error: "server_not_configured" }, 503);
    const admin = createClient(url, key, { auth: { autoRefreshToken: false, persistSession: false } });

    const { data: membership, error: membershipError } = await admin
      .from("merchant_memberships")
      .select("id,supermarket_id,user_id,phone,full_name,is_active")
      .eq("phone", phone).eq("is_active", true).maybeSingle();
    if (membershipError) return fail("merchant_lookup_failed", membershipError);
    if (!membership) return response({ success: false, error: "merchant_not_found" });

    const verification = await verifyAndConsumeCode(admin, phone, code);
    if (!verification.ok) return response({ success: false, error: verification.error });

    let user = await resolveMerchantUser(admin, membership.user_id, phone);
    if (!user) {
      const created = await admin.auth.admin.createUser({
        email: merchantEmail(phone),
        email_confirm: true,
        password: randomPassword(),
        // Do not put phone in Auth metadata. user_profiles.phone is unique and
        // old orphan profiles must not make auth.users insertion fail.
        user_metadata: { full_name: membership.full_name, role: "merchant" },
        app_metadata: { role: "merchant" },
      });
      if (created.error || !created.data.user) {
        console.error("merchant auth creation failed", created.error);
        // A concurrent request can win the create. Resolve once more before failing.
        user = await resolveMerchantUser(admin, null, phone);
        if (!user) return fail("merchant_auth_creation_failed", created.error);
      } else {
        user = created.data.user;
      }
    }

    const hardened = await admin.auth.admin.updateUserById(user.id, {
      password: randomPassword(),
      user_metadata: { ...(user.user_metadata ?? {}), full_name: membership.full_name, role: "merchant" },
      app_metadata: { ...(user.app_metadata ?? {}), role: "merchant" },
    });
    if (hardened.error || !hardened.data.user) return fail("merchant_auth_hardening_failed", hardened.error);
    user = hardened.data.user;

    const linkMembership = await admin.from("merchant_memberships")
      .update({ user_id: user.id, updated_at: new Date().toISOString() })
      .eq("id", membership.id);
    if (linkMembership.error) return fail("merchant_auth_link_failed", linkMembership.error);

    // Keep the login identity role authoritative. The phone remains in the
    // membership table; this avoids a collision with a legacy customer profile.
    const profile = await admin.from("user_profiles").upsert({
      id: user.id,
      full_name: membership.full_name,
      user_role: "merchant",
      is_active: true,
    }, { onConflict: "id" });
    if (profile.error) return fail("merchant_profile_sync_failed", profile.error);

    const email = user.email?.trim().toLowerCase() ?? "";
    if (!email) return response({ success: false, error: "merchant_auth_not_found" }, 500);
    const link = await admin.auth.admin.generateLink({ type: "magiclink", email });
    const token = String((link.data?.properties as Record<string, unknown> | undefined)?.email_otp ?? "").trim();
    if (link.error || !token) return fail("merchant_session_generation_failed", link.error);

    return response({
      success: true,
      email,
      token,
      token_type: "magiclink",
      supermarket_id: membership.supermarket_id,
      user_id: user.id,
    });
  } catch (error) {
    console.error("merchant-code-login failed", error);
    return response({ success: false, error: "internal_error" }, 500);
  }
});

async function verifyAndConsumeCode(admin: SupabaseClient, phone: string, code: string): Promise<{ ok: boolean; error?: string }> {
  const lookup = await admin.from("verification_requests")
    .select("id,code,status,attempts,max_attempts,expires_at")
    .eq("phone", phone).in("status", ["pending", "code_sent"])
    .order("created_at", { ascending: false }).limit(1).maybeSingle();
  if (lookup.error) return { ok: false, error: "verification_lookup_failed" };
  const row = lookup.data;
  if (!row) return { ok: false, error: "verification_invalid" };
  if (row.status !== "code_sent" || !row.code) return { ok: false, error: "verification_pending" };
  const attempts = Number(row.attempts ?? 0);
  const max = Number(row.max_attempts ?? 5);
  if (attempts >= max) return { ok: false, error: "verification_attempts_exceeded" };
  if (!row.expires_at || new Date(row.expires_at).getTime() <= Date.now()) {
    await admin.from("verification_requests").update({ status: "expired" }).eq("id", row.id);
    return { ok: false, error: "verification_expired" };
  }
  if (row.code !== code) {
    const next = attempts + 1;
    await admin.from("verification_requests").update({ attempts: next, status: next >= max ? "expired" : "code_sent" })
      .eq("id", row.id).eq("status", "code_sent").eq("attempts", attempts);
    return { ok: false, error: next >= max ? "verification_attempts_exceeded" : "verification_invalid" };
  }
  const consumed = await admin.from("verification_requests")
    .update({ status: "verified", verified_at: new Date().toISOString(), attempts: attempts + 1 })
    .eq("id", row.id).eq("status", "code_sent").eq("attempts", attempts).eq("code", code)
    .select("id").maybeSingle();
  return consumed.data ? { ok: true } : { ok: false, error: "verification_invalid" };
}

async function resolveMerchantUser(admin: SupabaseClient, linkedId: unknown, phone: string): Promise<User | null> {
  if (linkedId) {
    const linked = await admin.auth.admin.getUserById(String(linkedId));
    if (linked.data.user) return linked.data.user;
  }
  const emails = new Set([merchantEmail(phone), `merchant_${phone}@vetosanya.internal`]);
  for (let page = 1; page <= 100; page++) {
    const users = await admin.auth.admin.listUsers({ page, perPage: 1000 });
    if (users.error) break;
    const found = users.data.users.find((item) => emails.has((item.email ?? "").toLowerCase()));
    if (found) return found;
    if (users.data.users.length < 1000) break;
  }
  return null;
}

function adminKey(): string {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
  if (legacy) return legacy;
  const current = Deno.env.get("SUPABASE_SECRET_KEYS")?.trim();
  if (!current) return "";
  try { return findSecretKey(JSON.parse(current)) ?? ""; }
  catch (_) { return findSecretKey(current) ?? ""; }
}
function findSecretKey(value: unknown): string | null {
  if (typeof value === "string") {
    const candidate = value.trim();
    return candidate.startsWith("sb_secret_") || candidate.startsWith("eyJ") ? candidate : null;
  }
  if (Array.isArray(value)) {
    for (const item of value) { const key = findSecretKey(item); if (key) return key; }
  } else if (value && typeof value === "object") {
    for (const item of Object.values(value)) { const key = findSecretKey(item); if (key) return key; }
  }
  return null;
}
function merchantEmail(phone: string): string { return `merchant.${phone}@vetosanya.app`; }
function normalizePhone(value: string): string {
  let phone = value.replace(/\D/g, "");
  if (phone.startsWith("20") && phone.length === 12) phone = `0${phone.slice(2)}`;
  return /^01\d{9}$/.test(phone) ? phone : "";
}
function randomPassword(): string { return `VS!${crypto.randomUUID()}${crypto.randomUUID().slice(0, 20)}`; }
function response(data: unknown, status = 200): Response { return new Response(JSON.stringify(data), { status, headers: cors }); }
function fail(code: string, error: unknown): Response {
  console.error(code, error);
  const reason = error && typeof error === "object" && "message" in error ? String((error as { message: unknown }).message).slice(0, 240) : undefined;
  return response({ success: false, error: code, ...(reason ? { reason } : {}) }, 500);
}


