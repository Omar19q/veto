import { createClient } from "npm:@supabase/supabase-js@2.57.4";
import { productPhone } from "../_shared/product_phone_veto2.ts";
import { loginBudgetV15 } from "../_shared/login_budget_scale_v15.ts";

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
const MSGCLOUD_TEMPLATE_ID =
  Deno.env.get("MSGCLOUD_TEMPLATE_ID") || "79378";

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
    const payload = {
      category: "activities",
      action: "create",
      data: {
        recipients: [recipient],
        subject: "VETO SANYA OTP",
        contentType: MSGCLOUD_TEMPLATE_ID,
        template_parameters: [code],
        scheduleOption: "no",
        use_delay: 0,
      },
    };

    const res = await fetch(MSGCLOUD_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${MSGCLOUD_TOKEN}`,
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    const body = await res.json().catch(() => ({}));
    if (!res.ok || body.status !== "success") {
      console.error("MSGCloud send failed:", res.status, body);
      return {
        success: false,
        error: body.message || "msgcloud_delivery_failed",
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

    // Enforce login budget / rate limits
    const budget = await loginBudgetV15(admin, "customer", phone.lookup, key);
    if (budget) {
      return reply(budget === "limited" ? 429 : 503, {
        success: false,
        error: budget === "limited" ? "login_rate_limit" : "login_service_unavailable",
      });
    }

    // Generate 4-digit OTP code
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
