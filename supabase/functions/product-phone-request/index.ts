import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.57.4";
import { parsePhoneNumberFromString } from "npm:libphonenumber-js@1.13.15/max";

const headers = {
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization,apikey,content-type,x-client-info",
  "Access-Control-Allow-Methods": "POST,OPTIONS",
};

const reply = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers });

const MSGCLOUD_URL = "https://msgcloud.solutions/api/integrations/execute";
const MSGCLOUD_TOKEN =
  Deno.env.get("MSGCLOUD_API_TOKEN") || "a317c1bb-a181-4592-8642-85137d486185";

const supportedCountries = new Set(["EG", "GB", "SA", "AE"]);

function productPhone(value: string): { e164: string; lookup: string; country: string } | null {
  const digits = value
    .replace(/[٠-٩]/g, (c) => String(c.charCodeAt(0) - 1632))
    .replace(/[۰-۹]/g, (c) => String(c.charCodeAt(0) - 1776));
  const normalized = digits.trim().startsWith("00")
    ? "+" + digits.trim().slice(2)
    : digits;
  const phone = parsePhoneNumberFromString(normalized, "EG");
  if (
    !phone?.isValid() ||
    !phone.country ||
    !supportedCountries.has(phone.country) ||
    !["MOBILE", "FIXED_LINE_OR_MOBILE"].includes(phone.getType() ?? "")
  ) {
    return null;
  }
  return {
    e164: phone.number,
    country: phone.country,
    lookup: phone.country === "EG" ? "0" + phone.nationalNumber : phone.number,
  };
}

async function loginBudgetV15(
  admin: SupabaseClient,
  scope: string,
  identity: string,
  secret: string,
): Promise<"limited" | "unavailable" | null> {
  try {
    const key = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(secret),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"],
    );
    const bytes = new Uint8Array(
      await crypto.subtle.sign(
        "HMAC",
        key,
        new TextEncoder().encode(scope + ":" + identity),
      ),
    );
    const subject = Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
    const { data, error } = await admin.rpc("claim_login_budget_scale_v15", {
      p_scope: scope,
      p_subject: subject,
    });
    if (error) return "unavailable";
    return data === true ? null : "limited";
  } catch {
    return "unavailable";
  }
}

function generateOtpCode(): string {
  const array = new Uint32Array(1);
  crypto.getRandomValues(array);
  const code = 1000 + (array[0] % 9000);
  return code.toString();
}

async function sendSmsViaMsgCloud(
  recipient: string,
  code: string,
): Promise<{ success: boolean; error?: string }> {
  try {
    const title = `veto_otp_${Date.now()}`;
    const content = `رمز التحقق الخاص بتطبيق فيتو ثانية هو ${code}. لا تشارك الرمز مع أي شخص.`;

    // 1. Create a dynamic template with the exact OTP code in content
    await fetch(MSGCLOUD_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${MSGCLOUD_TOKEN}`,
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        category: "templates",
        action: "create",
        data: { title, content, available: true },
      }),
    });

    // 2. Fetch the newly created template ID via GET with query parameters (no body)
    const listRes = await fetch(
      `${MSGCLOUD_URL}?category=templates&action=all&perpage=1`,
      {
        method: "GET",
        headers: {
          "Authorization": `Bearer ${MSGCLOUD_TOKEN}`,
          "Accept": "application/json",
        },
      },
    );

    const listData = await listRes.json().catch(() => ({}));
    const tplId = listData?.data?.items?.[0]?.id;

    if (!tplId) {
      return { success: false, error: "failed_to_prepare_sms_template" };
    }

    // 3. Dispatch the SMS activity using this template
    const sendRes = await fetch(MSGCLOUD_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${MSGCLOUD_TOKEN}`,
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        category: "activities",
        action: "create",
        data: {
          recipients: [recipient],
          subject: "VETO SANYA OTP",
          contentType: String(tplId),
          scheduleOption: "no",
          use_delay: 0,
        },
      }),
    });

    const sendBody = await sendRes.json().catch(() => ({}));

    // 4. Cleanup the temporary template
    fetch(MSGCLOUD_URL, {
      method: "DELETE",
      headers: {
        "Authorization": `Bearer ${MSGCLOUD_TOKEN}`,
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        category: "templates",
        action: "delete",
        data: { id: String(tplId) },
      }),
    }).catch(() => {});

    if (!sendRes.ok || sendBody.status !== "success") {
      console.error("MSGCloud send failed:", sendRes.status, sendBody);
      return {
        success: false,
        error: sendBody.message || "msgcloud_delivery_failed",
      };
    }

    return { success: true };
  } catch (err) {
    console.error("MSGCloud network error:", err);
    return { success: false, error: "sms_gateway_unreachable" };
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers });
  }

  if (req.method !== "POST") {
    return reply(405, { success: false, error: "method_not_allowed" });
  }

  try {
    const text = await req.text();
    if (text.length > 4096) {
      return reply(413, { success: false, error: "request_too_large" });
    }

    const input = JSON.parse(text);
    const rawPhone = String(input?.phone ?? "");
    const phone = productPhone(rawPhone);

    if (!phone) {
      return reply(400, { success: false, error: "invalid_phone" });
    }

    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const url = Deno.env.get("SUPABASE_URL");

    if (!key || !url) {
      return reply(503, { success: false, error: "server_not_configured" });
    }

    const admin = createClient(url, key, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // ─── VERIFY OTP ACTION ─────────────────────────────────────────────────
    if (input?.action === "verify" || (input?.code && String(input?.code).trim().length > 0)) {
      const code = String(input?.code ?? "").trim();
      if (!/^\d{4}$/.test(code)) {
        return reply(200, { success: false, error: "verification_invalid" });
      }

      const claim = await admin.rpc("veto2_consume_otp", {
        p_phone: phone.lookup,
        p_code: code,
      });

      if (claim.error) {
        console.error("veto2_consume_otp error:", claim.error);
        return reply(500, { success: false, error: "verification_lookup_failed" });
      }

      if (claim.data?.success !== true) {
        return reply(200, {
          success: false,
          error: claim.data?.error ?? "verification_invalid",
        });
      }

      return reply(200, {
        success: true,
        verified: true,
        request_id: claim.data?.request_id,
      });
    }

    // ─── SEND OTP ACTION ───────────────────────────────────────────────────
    // Enforce login budget / rate limits
    const budget = await loginBudgetV15(admin, "customer", phone.lookup, key);
    if (budget) {
      return reply(budget === "limited" ? 429 : 503, {
        success: false,
        error: budget === "limited" ? "login_rate_limit" : "login_service_unavailable",
      });
    }

    const code = generateOtpCode();

    // Expire any existing pending or active codes for this phone
    await admin
      .from("verification_requests")
      .update({ status: "expired" })
      .eq("phone", phone.lookup)
      .in("status", ["pending", "code_sent"]);

    // Create a new verification request row with status = code_sent
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString(); // 10 minutes
    const { data: requestRow, error: insertError } = await admin
      .from("verification_requests")
      .insert({
        phone: phone.lookup,
        code: code,
        status: "code_sent",
        attempts: 0,
        max_attempts: 5,
        requested_at: new Date().toISOString(),
        expires_at: expiresAt,
      })
      .select("id, phone, status, expires_at")
      .single();

    if (insertError || !requestRow) {
      console.error("Failed to insert verification request:", insertError);
      return reply(500, {
        success: false,
        error: "failed_to_create_request",
      });
    }

    // Send SMS via MSGCloud
    const smsResult = await sendSmsViaMsgCloud(phone.e164, code);
    if (!smsResult.success) {
      await admin
        .from("verification_requests")
        .update({ status: "expired" })
        .eq("id", requestRow.id);

      return reply(502, {
        success: false,
        error: "sms_send_failed",
        details: smsResult.error,
      });
    }

    return reply(200, {
      success: true,
      request_id: requestRow.id,
      status: "code_sent",
      expires_at: requestRow.expires_at,
    });
  } catch (e) {
    console.error("Unhandled error:", e);
    return reply(400, { success: false, error: "invalid_request" });
  }
});
