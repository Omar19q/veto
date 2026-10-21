// V27: deliver an already-authorized public.notifications row via OneSignal.
// Existing database webhook authentication stays unchanged. Do not call from clients.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function env(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing Edge secret: ${name}`);
  return value;
}

function androidChannel(type: string, data: Record<string, unknown>): string {
  if (type === "verification") return "veto_verification_v22";
  if (type === "offer" && data.market_order_id) return "veto_market_order_v3";
  if (type === "offer") return "veto_offer_v2";
  if (type === "chat") return "veto_chat_v2";
  return "veto_general_v2";
}

function validImage(value: unknown): string | undefined {
  if (typeof value !== "string" || value.length > 1200) return undefined;
  try {
    const url = new URL(value);
    // No arbitrary URLs: only the dedicated public notification-image bucket.
    const project = new URL(env("SUPABASE_URL"));
    if (url.protocol !== "https:" || url.origin !== project.origin ||
        !url.pathname.startsWith("/storage/v1/object/public/veto-notification-images/")) return undefined;
    return url.toString();
  } catch { return undefined; }
}

Deno.serve(async (request) => {
  try {
    if (request.method !== "POST") return new Response("Method Not Allowed", {status: 405});
    const expected = env("PUSH_WEBHOOK_SECRET");
    if (!request.headers.get("x-veto-webhook-secret") ||
        request.headers.get("x-veto-webhook-secret") !== expected) {
      return Response.json({ok: false, error: "Unauthorized"}, {status: 401});
    }
    const payload = await request.json();
    // Ignore caller-controlled title and user ID. Read the persisted row from DB
    // by its UUID to avoid forged recipient/payload from a leaked webhook URL.
    const recordId = (payload?.record?.id ?? payload?.id)?.toString() ?? "";
    if (!/^[a-f0-9-]{36}$/i.test(recordId)) {
      return Response.json({ok: false, error: "invalid_notification_id"}, {status: 400});
    }
    // Support legacy service-role and new Supabase secret-key environments.
    let adminKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() || "";
    if (!adminKey) {
      const raw = Deno.env.get("SUPABASE_SECRET_KEYS") ?? "";
      const find = (v: unknown): string => {
        if (typeof v === "string" && (v.startsWith("sb_secret_") || v.startsWith("eyJ"))) return v;
        if (Array.isArray(v)) return v.map(find).find(Boolean) ?? "";
        if (v && typeof v === "object") return Object.values(v).map(find).find(Boolean) ?? "";
        return "";
      };
      try { adminKey = find(JSON.parse(raw)); } catch { adminKey = find(raw); }
    }
    if (!adminKey) throw new Error("Missing Supabase server credential");
    const db = createClient(env("SUPABASE_URL"), adminKey, {
      auth: {autoRefreshToken:false, persistSession:false},
    });
    const {data: record, error: lookupError} = await db.from("notifications")
      .select("id,user_id,notification_type,title,body,data")
      .eq("id", recordId).maybeSingle();
    if (lookupError) throw lookupError;
    if (!record || !record.user_id) {
      return Response.json({ok: true, sent: 0, skipped: "missing_notification"});
    }
    // Do not deliver customer arrival/status push to an unrelated captain.
    // The lifecycle RPC can remain unchanged; this checks the persisted
    // trip/customer association BEFORE dispatch to OneSignal.
    const metadata = (record.data && typeof record.data === "object" && !Array.isArray(record.data))
      ? record.data as Record<string,unknown> : {};
    const status = String(metadata.status ?? metadata.trip_status ?? metadata.event ?? "");
    const tripId = String(metadata.trip_id ?? "");
    if (record.notification_type === "trip" &&
        ["arriving", "arrived", "started"].includes(status) &&
        /^[a-f0-9-]{36}$/i.test(tripId)) {
      const {data: trip, error: tripError} = await db.from("trips")
        .select("customer_id").eq("id", tripId).maybeSingle();
      if (tripError) throw tripError;
      if (!trip?.customer_id) {
        return Response.json({ok: true, sent: 0, skipped: "missing_trip_customer"});
      }
      const {data: customer, error: customerError} = await db.from("customers")
        .select("user_id").eq("id", trip.customer_id).maybeSingle();
      if (customerError) throw customerError;
      if (!customer?.user_id || String(customer.user_id) !== String(record.user_id)) {
        return Response.json({ok: true, sent: 0, skipped: "not_customer_recipient"});
      }
    }
    const kind = String(record.notification_type ?? "system");
    const raw = (record.data && typeof record.data === "object" && !Array.isArray(record.data))
      ? record.data as Record<string,unknown> : {};
    const image = validImage(raw.image_url);
    const notification = {
      app_id: env("ONESIGNAL_APP_ID"),
      target_channel: "push",
      include_aliases: {external_id: [String(record.user_id)]},
      headings: {en: String(record.title || "VETO SANYA"), ar: String(record.title || "فيتو ثانية")},
      contents: {en: String(record.body || " "), ar: String(record.body || " ")},
      data: {...raw, notification_id: recordId, notification_type: kind},
      idempotency_key: recordId,
      priority: (["offer", "verification", "trip"].includes(kind) ? 10 : 5),
      ttl: kind === "offer" ? 60 : 86400,
      existing_android_channel_id: androidChannel(kind, raw),
      ...(image ? {big_picture:image, chrome_web_image:image} : {}),
    };
    const res = await fetch("https://api.onesignal.com/notifications", {
      method:"POST", signal:AbortSignal.timeout(14000),
      headers:{"Content-Type":"application/json",Authorization:`Key ${env("ONESIGNAL_REST_API_KEY")}`},
      body:JSON.stringify(notification),
    });
    const parsed = await res.json().catch(() => ({}));
    if (!res.ok || !parsed.id) {
      console.warn("OneSignal delivery skipped/rejected", recordId, res.status, JSON.stringify(parsed));
      return Response.json({
        ok: true,
        sent: 0,
        skipped: "onesignal_rejected",
        status: res.status,
        details: parsed?.errors ?? "not_subscribed",
      }, {status: 200});
    }
    return Response.json({ok:true, accepted:true, message_id:parsed.id,
      recipients:typeof parsed.recipients === "number" ? parsed.recipients : null});
  } catch (e) {
    console.error("OneSignal webhook failure", e instanceof Error ? e.message : "unknown");
    return Response.json({ok:false, error:"push_unavailable"},{status:503});
  }
});