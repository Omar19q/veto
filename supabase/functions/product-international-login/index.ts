import { productPhone } from "../_shared/product_phone_veto2.ts";
import { loginBudgetV15 } from "../_shared/login_budget_scale_v15.ts";
import { staffPhoneReservedV16 } from "../_shared/staff_phone_v16.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, type User } from "npm:@supabase/supabase-js@2.57.4";

const headers = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

const reply = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), { status, headers });

const fail = (error: string, status = 200) =>
  reply({ success: false, error }, status);

function normalizePhone(value: unknown): string {
 const parsed=productPhone(String(value??""));
 return parsed && parsed.country!=="EG" ? parsed.lookup : "";
}

function randomPassword(): string {
 return `VS!${crypto.randomUUID()}`;
}

type Admin = ReturnType<typeof createClient>;

async function findByEmail(
  admin: Admin,
  email: string,
): Promise<User | null> {
  for (let page = 1; page <= 100; page++) {
    const { data, error } = await admin.auth.admin.listUsers({
      page,
      perPage: 1000,
    });

    if (error) throw error;

    const match = data.users.find(
      (user: User) =>
        user.email?.trim().toLowerCase() === email,
    );

    if (match) return match;
    if (data.users.length < 1000) break;
  }

  return null;
}

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers,
    });
  }

  if (req.method !== "POST") {
    return fail("method_not_allowed", 405);
  }

  try {
    const body = await req.json().catch(() => ({}));

    const phone = normalizePhone(body?.phone);
    const code = String(body?.code ?? "").trim();

    if (!phone || !/^\d{4}$/.test(code)) {
      return fail("verification_invalid");
    }

    const url = Deno.env.get("SUPABASE_URL");
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!url || !key) {
      return fail("server_not_configured", 503);
    }

    const admin = createClient(url, key, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // Captain accounts must use their own login flow.
    const captainResult = await admin
      .from("captains")
      .select("id")
      .eq("phone", phone)
      .maybeSingle();

    if (captainResult.error) {
      return fail("account_lookup_failed", 500);
    }

    if (captainResult.data) {
      return fail("captain_account");
    }

    const budget=await loginBudgetV15(admin,'customer',phone,key);
    if(budget)return fail(budget==='limited'?'login_rate_limit':'login_service_unavailable',budget==='limited'?429:503);
    if(await staffPhoneReservedV16(admin,phone))return fail('staff_account',403);
    const reserved=await admin.rpc('v16_applicant_phone_reserved',{p_phone:phone});
    if(reserved.error)return fail('account_lookup_failed',503);
    if(reserved.data)return fail('captain_application_account',409);
    // Claim on the trusted server under a row lock before any Auth token exists.
    const claim=await admin.rpc('veto2_consume_otp',{p_phone:phone,p_code:code});
    if(claim.error)return fail('verification_lookup_failed',503);
    if(claim.data?.success!==true)return fail(claim.data?.error??'verification_invalid');
    // A failed Auth preparation now requires a fresh manual request; never issue
    // two sessions by racing the same four-digit verification.
    // Preserve the hardened customer/account/blocked-state checks.
    const found = await admin
      .from("customers")
      .select("id,user_id,is_active")
      .eq("phone", phone)
      .maybeSingle();

    if (found.error) {
      return fail("customer_lookup_failed", 500);
    }

    let customer = found.data;

    if (customer?.is_active === false) {
      return fail("customer_inactive");
    }

    const defaultEmail = `intl_${phone.slice(1)}@vetosanya.app`;
    let user: User | null = null;

    if (customer?.user_id) {
      const existing =
        await admin.auth.admin.getUserById(
          String(customer.user_id),
        );

      if (existing.error || !existing.data.user) {
        return fail("customer_auth_not_found", 500);
      }

      user = existing.data.user;
    } else {
      user = await findByEmail(admin, defaultEmail);

      if (!user) {
        const created =
          await admin.auth.admin.createUser({
            email: defaultEmail,
            password: randomPassword(),
            email_confirm: true,
            user_metadata: {
              phone,
              role: "customer",
            },
            app_metadata: {
              role: "customer",
            },
          });

        user =
          created.data?.user ??
          await findByEmail(admin, defaultEmail);

        if (!user) {
          console.error(
            "customer Auth creation failed",
            created.error,
          );

          return fail(
            "customer_auth_creation_failed",
            500,
          );
        }
      }
    }

    if (!user || !user.email) {
      return fail("customer_auth_not_found", 500);
    }

    // Never turn an admin or captain identity into a customer.
    if (
      ["admin", "captain"].includes(
        String(user.app_metadata?.role ?? ""),
      )
    ) {
      return fail("account_role_mismatch", 403);
    }

    let profile = await admin
      .from("user_profiles")
      .select("id,user_role,is_active")
      .eq("id", user.id)
      .maybeSingle();

    if (profile.error) {
      return fail("customer_profile_sync_failed", 500);
    }

    if (profile.data?.is_active === false) {
      return fail("account_blocked", 403);
    }

    if (
      profile.data &&
      profile.data.user_role !== "customer"
    ) {
      return fail("account_role_mismatch", 403);
    }

    if (!profile.data) {
      const added = await admin
        .from("user_profiles")
        .insert({
          id: user.id,
          phone,
          full_name: "",
          user_role: "customer",
        });

      if (added.error) {
        profile = await admin
          .from("user_profiles")
          .select("id,user_role,is_active")
          .eq("id", user.id)
          .maybeSingle();

        if (
          profile.error ||
          !profile.data ||
          profile.data.user_role !== "customer" ||
          profile.data.is_active !== true
        ) {
          return fail(
            "customer_profile_sync_failed",
            500,
          );
        }
      }
    }

    // Preserve name and blocked status.
    const profileUpdate = await admin
      .from("user_profiles")
      .update({ phone })
      .eq("id", user.id);

    if (profileUpdate.error) {
      return fail("customer_profile_sync_failed", 500);
    }

    if (customer && !customer.user_id) {
      const linked = await admin
        .from("customers")
        .update({ user_id: user.id })
        .eq("id", customer.id)
        .is("user_id", null)
        .select("id,user_id,is_active")
        .maybeSingle();

      if (linked.error || !linked.data) {
        return fail("customer_auth_link_failed", 500);
      }

      customer = linked.data;
    } else if (!customer) {
      const inserted = await admin
        .from("customers")
        .insert({
          user_id: user.id,
          phone,
          full_name: "",
          wallet_balance: 0,
        })
        .select("id,user_id,is_active")
        .single();

      if (inserted.error || !inserted.data) {
        const raced = await admin
          .from("customers")
          .select("id,user_id,is_active")
          .eq("phone", phone)
          .maybeSingle();

        if (
          raced.error ||
          !raced.data ||
          raced.data.user_id !== user.id ||
          raced.data.is_active !== true
        ) {
          console.error(
            "customer creation failed",
            inserted.error,
          );

          return fail(
            "customer_profile_creation_failed",
            500,
          );
        }

        customer = raced.data;
      } else {
        customer = inserted.data;
      }
    }

    if (
      !customer ||
      customer.user_id !== user.id ||
      customer.is_active === false
    ) {
      return fail("customer_auth_link_failed", 500);
    }

    // Replace old predictable passwords with random credentials.
    const hardened =
      await admin.auth.admin.updateUserById(
        user.id,
        {
          password: randomPassword(),
          user_metadata: {
            ...(user.user_metadata ?? {}),
            phone,
            role: "customer",
          },
        },
      );

    if (hardened.error || !hardened.data.user) {
      console.error(
        "customer Auth hardening failed",
        hardened.error,
      );

      return fail(
        "customer_auth_hardening_failed",
        500,
      );
    }

    const email =
      hardened.data.user.email?.trim().toLowerCase() ?? "";

    if (!email) {
      return fail("customer_auth_not_found", 500);
    }

    // Prepare the Auth session token.
    const link = await admin.auth.admin.generateLink({
      type: "magiclink",
      email,
    });

    const props = (link.data?.properties ?? {}) as
      Record<string, unknown>;

    const token =
      typeof props.email_otp === "string"
        ? props.email_otp.trim()
        : "";

    if (link.error || !token) {
      console.error(
        "customer token generation failed",
        link.error,
      );

      return fail(
        "customer_session_generation_failed",
        500,
      );
    }

    return reply({
      success: true,
      email,
      token,
      token_type: "magiclink",
      user_id: user.id,
      customer_id: customer.id,
    });
  } catch (error) {
    console.error("international-login failed", error);

    return fail("internal_error", 500);
  }
});
