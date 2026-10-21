
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';

function getServerKey(): string {
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')?.trim();
  if (key) return key;

  const raw = Deno.env.get('SUPABASE_SECRET_KEYS') ?? '';
  if (!raw) return '';

  try {
    const parsed = JSON.parse(raw);
    const values = Array.isArray(parsed) ? parsed : Object.values(parsed);

    for (const candidate of values) {
      if (
        typeof candidate === 'string' &&
        (candidate.startsWith('sb_secret_') || candidate.startsWith('eyJ'))
      ) {
        return candidate;
      }

      if (candidate && typeof candidate === 'object') {
        for (const nested of Object.values(candidate)) {
          if (
            typeof nested === 'string' &&
            (nested.startsWith('sb_secret_') || nested.startsWith('eyJ'))
          ) return nested;
        }
      }
    }
  } catch {
    if (raw.startsWith('sb_secret_') || raw.startsWith('eyJ')) return raw;
  }

  return '';
}

const SERVICE_ROLE_KEY = getServerKey();
const ONESIGNAL_APP_ID = Deno.env.get('ONESIGNAL_APP_ID') ?? '';
const ONESIGNAL_REST_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY') ?? '';
const CRON_SECRET = Deno.env.get('VETO_POST_TRIP_CRON_SECRET') ?? '';

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  if (
    !CRON_SECRET ||
    request.headers.get('x-veto-cron-secret') !== CRON_SECRET
  ) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 });
  }

  if (
    !SUPABASE_URL ||
    !SERVICE_ROLE_KEY ||
    !ONESIGNAL_APP_ID ||
    !ONESIGNAL_REST_API_KEY
  ) {
    console.error('Post-trip notification secrets are missing');
    return Response.json(
      { error: 'Server is not configured' },
      { status: 503 },
    );
  }

  const db = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  const { data: claimed, error: claimError } = await db.rpc(
    'v26_claim_post_trip_checkins',
    { p_limit: 20 },
  );

  if (claimError) {
    console.error('Post-trip queue claim error:', claimError.code);
    return Response.json(
      { error: 'Queue temporarily unavailable' },
      { status: 503 },
    );
  }

  let sent = 0;
  let skipped = 0;
  let retry = 0;

  for (const item of claimed ?? []) {
    let outcome = 'retry';
    let detail = '';

    try {
      const response = await fetch('https://api.onesignal.com/notifications', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Key ${ONESIGNAL_REST_API_KEY}`,
        },
        body: JSON.stringify({
          app_id: ONESIGNAL_APP_ID,
          target_channel: 'push',
          include_aliases: {
            external_id: [item.customer_user_id],
          },
          headings: {
            ar: 'طمنّا عليك بعد مشوارك 💛',
            en: 'How was your trip?',
          },
          contents: {
            ar: 'يا رب تكون وصلت بالسلامة! حصل أي موقف ضايقك مع الكابتن؟ دوس هنا وقدّم شكوى، وفريق فيتو ثانية هيتابع معاك.',
            en: 'We hope you arrived safely. If anything bothered you during the ride, tap here to contact our support team.',
          },
          data: {
            notification_type: 'post_trip_checkin',
            route: '/feedback?type=complaint',
          },
          idempotency_key: item.trip_id,
          ttl: 86400,
          priority: 5,
        }),
        signal: AbortSignal.timeout(12000),
      });

      const result = await response.json().catch(() => ({}));

      if (!response.ok) {
        detail = `OneSignal HTTP ${response.status}`;
      } else if (Number(result.recipients) === 0) {
        outcome = 'skipped';
        detail = 'No registered push subscription for this user';
      } else if (typeof result.id === 'string' && result.id.length > 0) {
        outcome = 'sent';
        detail = 'OneSignal notification created';
      } else {
        detail = 'OneSignal response had no notification ID';
      }
    } catch (error) {
      detail = error instanceof Error ? error.name : 'Network failure';
    }

    const { error: finishError } = await db.rpc(
      'v26_finish_post_trip_checkin',
      {
        p_trip_id: item.trip_id,
        p_lease_token: item.lease_token,
        p_outcome: outcome,
        p_detail: detail,
      },
    );

    if (finishError) {
      console.error('Queue finish failed:', finishError.code);
    }

    if (outcome === 'sent') sent++;
    else if (outcome === 'skipped') skipped++;
    else retry++;
  }

  return Response.json({
    ok: true,
    processed: (claimed ?? []).length,
    sent,
    skipped,
    retry,
  });
});
