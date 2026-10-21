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

// Admin-only quick login code.
// The Flutter admin screen sends ONLY:
// { code: "662010" }

const ADMIN_CODE = "662010";
const ADMIN_EMAIL = "admin@vetosanya.com";

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

    const code = String(body?.code ?? "").trim();

    if (code !== ADMIN_CODE) {
      return json(
        {
          success: false,
          error: "invalid_code",
        },
        401,
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

    // Find the configured admin account.
    const { data: usersPage, error: usersError } =
      await admin.auth.admin.listUsers({
        page: 1,
        perPage: 1000,
      });

    if (usersError) {
      console.error("admin user list error:", usersError);

      return json(
        {
          success: false,
          error: "admin_lookup_failed",
        },
        500,
      );
    }

    const authUser = usersPage.users.find(
      (user) =>
        (user.email ?? "").toLowerCase() === ADMIN_EMAIL.toLowerCase(),
    );

    if (!authUser) {
      return json(
        {
          success: false,
          error: "admin_account_not_found",
        },
        404,
      );
    }

    // Make the DB/Auth role authoritative.
    const { error: updateError } =
      await admin.auth.admin.updateUserById(
        authUser.id,
        {
          app_metadata: {
            ...(authUser.app_metadata ?? {}),
            role: "admin",
          },
          user_metadata: {
            ...(authUser.user_metadata ?? {}),
            role: "admin",
          },
        },
      );

    if (updateError) {
      console.error("admin metadata update error:", updateError);

      return json(
        {
          success: false,
          error: "admin_metadata_update_failed",
        },
        500,
      );
    }

    // Ensure the admin profile is marked correctly when user_profiles exists.
    const { error: profileError } = await admin
      .from("user_profiles")
      .upsert(
        {
          id: authUser.id,
          full_name:
            (authUser.user_metadata?.full_name as string | undefined) ??
            "Veto Sanya Admin",
          user_role: "admin",
          is_active: true,
        },
        {
          onConflict: "id",
        },
      );

    // Don't fail login only because the optional profile synchronization
    // failed. Auth metadata remains authoritative.
    if (profileError) {
      console.error("admin profile sync warning:", profileError);
    }

    // Generate a one-time magic-link OTP for the existing Admin Auth user.
    // Flutter receives email + email_otp and calls verifyOTP().
    const { data: link, error: linkError } =
      await admin.auth.admin.generateLink({
        type: "magiclink",
        email: authUser.email!,
      });

    if (linkError || !link) {
      console.error("generateLink error:", linkError);

      return json(
        {
          success: false,
          error: "admin_session_generation_failed",
        },
        500,
      );
    }

    const properties =
      link.properties && typeof link.properties === "object"
        ? (link.properties as Record<string, unknown>)
        : {};

    const token =
      typeof properties.email_otp === "string"
        ? properties.email_otp.trim()
        : "";

    if (!token) {
      console.error("generateLink did not return email_otp");

      return json(
        {
          success: false,
          error: "no_auth_token",
        },
        500,
      );
    }

    return json({
      success: true,
      email: authUser.email,
      token,
      token_type: "magiclink",
      user_id: authUser.id,
      role: "admin",
    });
  } catch (error) {
    console.error("admin-code-login unexpected error:", error);

    return json(
      {
        success: false,
        error: "internal_error",
      },
      500,
    );
  }
});

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