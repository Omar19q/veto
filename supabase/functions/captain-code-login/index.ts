import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
  "Content-Type": "application/json",
};

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders,
    });
  }

  if (req.method !== "POST") {
    return json(
      {
        success: false,
        error: "method_not_allowed",
      },
      405,
    );
  }

  try {
    const body = await req.json().catch(() => ({}));

    const phone = normalizePhone(String(body?.phone ?? ""));
    const code = String(body?.code ?? "").trim();

    if (!/^01[0125]\d{8}$/.test(phone)) {
      return json(
        {
          success: false,
          error: "invalid_phone",
        },
        400,
      );
    }

    if (!/^\d{4}$/.test(code)) {
      return json(
        {
          success: false,
          error: "invalid_code_format",
        },
        400,
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      console.error("Missing Supabase server configuration");

      return json(
        {
          success: false,
          error: "server_not_configured",
        },
        503,
      );
    }

    const admin = createClient(
      supabaseUrl,
      serviceRoleKey,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      },
    );

    // 1) Find latest verification request
    const { data: verification, error: verificationError } =
      await admin
        .from("verification_requests")
        .select("*")
        .eq("phone", phone)
        .in("status", ["pending", "code_sent"])
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();

    if (verificationError) {
      console.error(
        "verification lookup error:",
        verificationError,
      );

      return json(
        {
          success: false,
          error: "verification_lookup_failed",
        },
        500,
      );
    }

    if (!verification) {
      return json(
        {
          success: false,
          error: "verification_invalid",
        },
        401,
      );
    }

    // 2) Expiration
    const expiresAt = verification.expires_at
      ? new Date(verification.expires_at)
      : null;

    if (
      !expiresAt ||
      Number.isNaN(expiresAt.getTime()) ||
      expiresAt <= new Date()
    ) {
      await admin
        .from("verification_requests")
        .update({
          status: "expired",
        })
        .eq("id", verification.id);

      return json(
        {
          success: false,
          error: "verification_invalid",
        },
        401,
      );
    }

    // 3) Attempts protection
    const attempts =
      Number(
        verification.attempts ??
        verification.attempt_count ??
        0
      );

    const maxAttempts =
      Number(verification.max_attempts ?? 5);

    if (attempts >= maxAttempts) {
      return json(
        {
          success: false,
          error: "verification_attempts_exceeded",
        },
        429,
      );
    }

    await admin
      .from("verification_requests")
      .update({
        attempts: attempts + 1,
      })
      .eq("id", verification.id);

    // 4) Verify code
    const storedCode = String(
      verification.code ??
      verification.verification_code ??
      "",
    ).trim();

    if (!storedCode || storedCode !== code) {
      return json(
        {
          success: false,
          error: "verification_invalid",
        },
        401,
      );
    }

    // 5) Find captain
    const { data: captain, error: captainError } =
      await admin
        .from("captains")
        .select(
          "id,user_id,captain_status,phone,full_name"
        )
        .eq("phone", phone)
        .maybeSingle();

    if (captainError) {
      console.error(
        "captain lookup error:",
        captainError,
      );

      return json(
        {
          success: false,
          error: "captain_lookup_failed",
        },
        500,
      );
    }

    if (!captain) {
      return json(
        {
          success: false,
          error: "captain_not_found",
        },
        404,
      );
    }

    if (
      captain.captain_status != null &&
      captain.captain_status !== "active"
    ) {
      return json(
        {
          success: false,
          error: "captain_inactive",
        },
        403,
      );
    }

    // IMPORTANT:
    // Captain MUST already be linked to the same Auth user.
    // Never create a second account.
    if (!captain.user_id) {
      return json(
        {
          success: false,
          error: "captain_account_not_linked",
        },
        409,
      );
    }

    // 6) Check profile and block status
    const { data: profile, error: profileError } =
      await admin
        .from("user_profiles")
        .select("id,user_role,is_active,phone,full_name")
        .eq("id", captain.user_id)
        .maybeSingle();

    if (profileError) {
      console.error(
        "profile lookup error:",
        profileError,
      );

      return json(
        {
          success: false,
          error: "profile_lookup_failed",
        },
        500,
      );
    }

    if (!profile) {
      return json(
        {
          success: false,
          error: "profile_not_found",
        },
        404,
      );
    }

    if (profile.is_active === false) {
      return json(
        {
          success: false,
          error: "account_blocked",
        },
        403,
      );
    }

    // 7) Get the SAME Auth user
    const {
      data: authUserData,
      error: authUserError,
    } =
      await admin.auth.admin.getUserById(
        captain.user_id,
      );

    if (
      authUserError ||
      !authUserData?.user
    ) {
      console.error(
        "captain auth lookup error:",
        authUserError,
      );

      return json(
        {
          success: false,
          error: "captain_auth_not_found",
        },
        409,
      );
    }

    const authUser = authUserData.user;
    const email = authUser.email;

    if (!email) {
      return json(
        {
          success: false,
          error: "captain_auth_email_missing",
        },
        409,
      );
    }

    // 8) Make sure metadata says captain,
    // WITHOUT creating another Auth user
    const { error: metadataError } =
      await admin.auth.admin.updateUserById(
        authUser.id,
        {
          app_metadata: {
            ...(authUser.app_metadata ?? {}),
            role: "captain",
          },
          user_metadata: {
            ...(authUser.user_metadata ?? {}),
            role: "captain",
            phone,
            full_name:
              captain.full_name ??
              profile.full_name ??
              "",
          },
        },
      );

    if (metadataError) {
      console.error(
        "captain metadata error:",
        metadataError,
      );

      return json(
        {
          success: false,
          error: "captain_auth_update_failed",
        },
        500,
      );
    }

    // 9) Sync profile role but NEVER unblock it here
    const { error: profileSyncError } =
      await admin
        .from("user_profiles")
        .update({
          phone,
          full_name:
            captain.full_name ??
            profile.full_name ??
            "",
          user_role: "captain",
        })
        .eq("id", captain.user_id);

    if (profileSyncError) {
      console.error(
        "captain profile sync error:",
        profileSyncError,
      );

      return json(
        {
          success: false,
          error: "captain_profile_sync_failed",
        },
        500,
      );
    }

    // 10) Generate one-time login token
    const {
      data: link,
      error: linkError,
    } =
      await admin.auth.admin.generateLink({
        type: "magiclink",
        email,
      });

    if (linkError || !link) {
      console.error(
        "generateLink error:",
        linkError,
      );

      return json(
        {
          success: false,
          error: "captain_session_generation_failed",
        },
        500,
      );
    }

    const properties =
      link.properties &&
      typeof link.properties === "object"
        ? link.properties as Record<string, unknown>
        : {};

    const token =
      typeof properties.email_otp === "string"
        ? properties.email_otp.trim()
        : "";

    if (!token) {
      return json(
        {
          success: false,
          error: "no_auth_token",
        },
        500,
      );
    }

    // 11) Consume verification request only after
    // the login token was successfully generated.
    const {
      data: consumed,
      error: consumeError,
    } =
      await admin
        .from("verification_requests")
        .update({
          status: "verified",
          verified_at: new Date().toISOString(),
        })
        .eq("id", verification.id)
        .in("status", ["pending", "code_sent"])
        .select("id")
        .maybeSingle();

    if (
      consumeError ||
      !consumed
    ) {
      console.error(
        "verification finalize error:",
        consumeError,
      );

      return json(
        {
          success: false,
          error: "verification_invalid",
        },
        401,
      );
    }

    return json({
      success: true,
      email,
      token,
      token_type: "magiclink",
      captain_id: captain.id,
      user_id: captain.user_id,
      role: "captain",
    });
  } catch (error) {
    console.error(
      "captain-code-login unexpected error:",
      error,
    );

    return json(
      {
        success: false,
        error: "internal_error",
      },
      500,
    );
  }
});

function normalizePhone(value: string): string {
  let digits = value.replace(/\D/g, "");

  if (
    digits.startsWith("20") &&
    digits.length === 12
  ) {
    digits = `0${digits.slice(2)}`;
  }

  return digits;
}

function json(
  payload: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(
    JSON.stringify(payload),
    {
      status,
      headers: corsHeaders,
    },
  );
}