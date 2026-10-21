import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ success: false, error: "method_not_allowed" }, 405);
  }

  try {
    const url = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!url || !serviceKey || !anonKey) {
      return json({ success: false, error: "server_not_configured" }, 503);
    }
    if (!authHeader.toLowerCase().startsWith("bearer ")) {
      return json({ success: false, error: "unauthorized" }, 401);
    }

    const callerClient = createClient(url, anonKey, {
      auth: { autoRefreshToken: false, persistSession: false },
      global: { headers: { Authorization: authHeader } },
    });
    const { data: callerData, error: callerError } =
      await callerClient.auth.getUser();
    if (callerError || !callerData.user) {
      return json({ success: false, error: "unauthorized" }, 401);
    }

    const admin = createClient(url, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const {data:owner,error:ownerError}=await callerClient.rpc('v16_is_owner');
    if(ownerError || owner !== true) return json({success:false,error:'admin_access_required'},403);

    const { data: captains, error: captainError } = await admin
      .from("captains")
      .select("id,user_id,full_name,phone")
      .order("created_at", { ascending: true })
      .limit(1000);
    if (captainError) {
      console.error("captain list failed", captainError);
      return json({ success: false, error: "captain_list_failed" }, 500);
    }

    let updated = 0;
    let skipped = 0;
    let failed = 0;

    // Sequential updates avoid Auth rate spikes. Passwords are generated and
    // consumed only inside this trusted function and are never returned.
    for (const captain of captains ?? []) {
      const userId = String(captain.user_id ?? "").trim();
      if (!userId) {
        skipped += 1;
        continue;
      }

      const { data: existing, error: lookupError } =
        await admin.auth.admin.getUserById(userId);
      if (lookupError || !existing.user) {
        console.error("captain Auth user lookup failed", captain.id, lookupError);
        failed += 1;
        continue;
      }

      const { data: hardened, error: updateError } =
        await admin.auth.admin.updateUserById(userId, {
          password: createRandomPassword(),
          user_metadata: {
            ...(existing.user.user_metadata ?? {}),
            full_name: captain.full_name,
            phone: captain.phone,
            role: "captain",
          },
          app_metadata: {
            ...(existing.user.app_metadata ?? {}),
            role: "captain",
          },
        });
      if (updateError || !hardened.user) {
        console.error("captain credential rotation failed", captain.id, updateError);
        failed += 1;
        continue;
      }
      updated += 1;
    }

    await admin.from("audit_logs").insert({
      admin_id: callerData.user.id,
      action: "rotate_captain_credentials",
      entity_type: "captain_security",
      details: { updated, skipped, failed },
    });

    return json({
      success: failed === 0,
      updated,
      skipped,
      failed,
      error: failed === 0 ? null : "some_captain_credentials_failed",
    }, failed === 0 ? 200 : 500);
  } catch (error) {
    console.error("rotate-captain-credentials failed", error);
    return json({ success: false, error: "internal_error" }, 500);
  }
});

function createRandomPassword(): string {
  return `VS!${crypto.randomUUID()}${crypto.randomUUID().slice(0, 20)}`;
}

function json(payload: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(payload), { status, headers: corsHeaders });
}
