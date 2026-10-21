// VETO SANYA — route-price-quote (V28)
// Complete replacement for Supabase Edge Functions / route-price-quote / index.ts
// The existing PostgreSQL pricing RPC stays authoritative for all amounts.
// V28 search-timeout retry is handled by a separate, server-only RPC.

import { createClient } from 'npm:@supabase/supabase-js@2.57.4';

const supabaseUrl = Deno.env.get('SUPABASE_URL');
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error('Supabase server configuration is missing');
}

const server = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const allowedOrigins = new Set(
  (Deno.env.get('QUOTE_ALLOWED_ORIGINS') ?? '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean),
);

const services = new Set([
  'car_ride',
  'motorcycle_ride',
  'package',
  'vito_market',
]);

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isAllowedOrigin(origin: string | null): boolean {
  // Native mobile clients generally do not send the browser Origin header.
  if (!origin) return true;
  if (allowedOrigins.has(origin)) return true;

  // Keep local Flutter Web development working on different local ports.
  try {
    const parsed = new URL(origin);
    const isLocal = [
      'localhost', '127.0.0.1', '[::1]', '::1',
    ].includes(parsed.hostname);
    return isLocal &&
      (parsed.protocol === 'http:' || parsed.protocol === 'https:');
  } catch {
    return false;
  }
}

function reply(req: Request, status: number, data: unknown): Response {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'Vary': 'Origin',
    'Access-Control-Allow-Headers':
      'authorization, apikey, content-type, x-client-info',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };

  const origin = req.headers.get('origin');
  if (origin && isAllowedOrigin(origin)) {
    headers['Access-Control-Allow-Origin'] = origin;
  }

  return new Response(JSON.stringify(data), { status, headers });
}

function coordinate(value: unknown, maxAbsoluteValue: number): number {
  if (
    typeof value !== 'number' ||
    !Number.isFinite(value) ||
    Math.abs(value) > maxAbsoluteValue
  ) {
    throw new Error('invalid_coordinates');
  }
  return Number(value.toFixed(7));
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

// The percentage and internal lineage stay in PostgreSQL for auditing.
// The app only needs the updated fare, distance, duration, expiry and quote ID.
function publicRetryQuote(value: Record<string, unknown>): Record<string, unknown> {
  const output = { ...value };
  delete output.v28_retry_source_trip_id;
  delete output.v28_retry_root_trip_id;
  delete output.v28_retry_root_created_at;

  if (isRecord(output.pricing_snapshot)) {
    const snapshot = { ...output.pricing_snapshot };
    delete snapshot.v28_retry_multiplier;
    delete snapshot.v28_retry_root_trip_id;
    delete snapshot.v28_retry_root_created_at;
    output.pricing_snapshot = snapshot;
  }
  return output;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return isAllowedOrigin(req.headers.get('origin'))
      ? reply(req, 200, {})
      : reply(req, 403, { error: 'origin_not_allowed' });
  }

  if (!isAllowedOrigin(req.headers.get('origin'))) {
    return reply(req, 403, { error: 'origin_not_allowed' });
  }
  if (req.method !== 'POST') {
    return reply(req, 405, { error: 'post_required' });
  }

  const token = req.headers.get('authorization')?.replace(/^Bearer\s+/i, '');
  if (!token) {
    return reply(req, 401, { error: 'authentication_required' });
  }

  const { data: auth, error: authError } = await server.auth.getUser(token);
  if (authError || !auth.user) {
    return reply(req, 401, { error: 'authentication_required' });
  }

  try {
    const bodyText = await req.text();
    if (bodyText.length > 2048) {
      return reply(req, 413, { error: 'request_too_large' });
    }

    const input: unknown = JSON.parse(bodyText);
    if (!isRecord(input)) {
      return reply(req, 422, { error: 'invalid_request' });
    }

    const fromLat = coordinate(input.pickup_lat, 90);
    const fromLng = coordinate(input.pickup_lng, 180);
    const toLat = coordinate(input.destination_lat, 90);
    const toLng = coordinate(input.destination_lng, 180);

    if (typeof input.service_type !== 'string' ||
        !services.has(input.service_type)) {
      throw new Error('invalid_service');
    }
    if (fromLat === toLat && fromLng === toLng) {
      throw new Error('choose_different_destination');
    }

    // Optional: supplied only when the customer chooses to retry a search that
    // was automatically cancelled after ten minutes. Never apply a markup for
    // ordinary "Repeat trip" from trip history.
    const retryId = input.timeout_retry_trip_id;
    const wantsTimeoutRetry = retryId !== undefined && retryId !== null;
    if (wantsTimeoutRetry &&
        (typeof retryId !== 'string' || !uuidPattern.test(retryId))) {
      return reply(req, 422, { error: 'invalid_retry_reference' });
    }

    // Existing per-user anti-abuse guard; do not bypass it for retries.
    const { data: slot, error: slotError } = await server.rpc(
      'claim_route_quote_slot',
      { p_user_id: auth.user.id },
    );
    if (slotError) {
      return reply(req, 503, { error: 'quote_service_unavailable' });
    }
    if (slot !== true) {
      return reply(req, 429, { error: 'quote_rate_limit' });
    }

    const routingBase = Deno.env.get('OSRM_ROUTING_URL');
    if (!routingBase) {
      return reply(req, 503, { error: 'routing_not_configured' });
    }

    let routeUrl: URL;
    try {
      routeUrl = new URL(routingBase);
      if (
        routeUrl.protocol !== 'https:' ||
        routeUrl.username || routeUrl.password ||
        routeUrl.search || routeUrl.hash
      ) {
        throw new Error('invalid_route_url');
      }
    } catch {
      return reply(req, 503, { error: 'routing_not_configured' });
    }

    routeUrl.pathname =
      `${routeUrl.pathname.replace(/\/$/, '')}/route/v1/driving/` +
      `${fromLng},${fromLat};${toLng},${toLat}`;
    routeUrl.search = 'overview=false&alternatives=false&steps=false';

    let result: unknown;
    try {
      const response = await fetch(routeUrl, {
        signal: AbortSignal.timeout(10000),
        redirect: 'error',
      });
      if (!response.ok) {
        return reply(req, 503, { error: 'routing_unavailable' });
      }
      result = await response.json();
    } catch {
      return reply(req, 503, { error: 'routing_unavailable' });
    }

    if (!isRecord(result)) {
      return reply(req, 422, { error: 'route_not_supported' });
    }
    const routes = result.routes;
    const waypoints = result.waypoints;
    const route = Array.isArray(routes) ? routes[0] : null;
    const validRoute =
      result.code === 'Ok' &&
      isRecord(route) &&
      typeof route.distance === 'number' &&
      Number.isFinite(route.distance) &&
      route.distance > 0 && route.distance <= 1_000_000 &&
      typeof route.duration === 'number' &&
      Number.isFinite(route.duration) &&
      route.duration > 0 && route.duration <= 86_400 &&
      Array.isArray(waypoints) && waypoints.length === 2 &&
      waypoints.every((waypoint) =>
        isRecord(waypoint) &&
        typeof waypoint.distance === 'number' &&
        Number.isFinite(waypoint.distance) &&
        waypoint.distance >= 0 && waypoint.distance <= 300
      );

    if (!validRoute || !isRecord(route)) {
      return reply(req, 422, { error: 'route_not_supported' });
    }
    // TypeScript knows the values are numbers after validation above.
    const distanceMeters = route.distance as number;
    const durationSeconds = route.duration as number;

    const { data: quote, error: quoteError } = await server.rpc(
      'issue_route_pricing_quote',
      {
        p_user_id: auth.user.id,
        p_service: input.service_type,
        p_pickup_lat: fromLat,
        p_pickup_lng: fromLng,
        p_destination_lat: toLat,
        p_destination_lng: toLng,
        p_distance_km: Math.max(0.001, Math.round(distanceMeters) / 1000),
        p_duration_minutes: Math.max(1, Math.ceil(durationSeconds / 60)),
      },
    );

    if (quoteError) {
      const known = [
        'global_pricing_not_configured',
        'service_unavailable',
        'customer_required',
        'quote_rate_limit',
      ];
      return reply(req, quoteError.message.includes('quote_rate_limit') ? 429 : 422, {
        error: known.find((code) => quoteError.message.includes(code)) ?? 'quote_failed',
      });
    }

    if (!isRecord(quote) || typeof quote.id !== 'string' ||
        !uuidPattern.test(quote.id)) {
      return reply(req, 503, { error: 'quote_service_unavailable' });
    }

    if (!wantsTimeoutRetry) {
      return reply(req, 200, quote);
    }

    // The V28 SQL validates the caller's Auth UID, the original trip owner,
    // the service, matching coordinates, no active trip and the original
    // one-hour eligibility window, and applies the 10% ONLY on the server.
    const { data: adjusted, error: retryError } = await server.rpc(
      'v28_apply_search_retry_quote',
      {
        p_quote_id: quote.id,
        p_trip_id: retryId,
        p_user_id: auth.user.id,
      },
    );
    if (retryError || !isRecord(adjusted) ||
        typeof adjusted.id !== 'string') {
      return reply(req, 422, { error: 'retry_not_available' });
    }

    return reply(req, 200, publicRetryQuote(adjusted));
  } catch (error) {
    const message = error instanceof Error ? error.message : '';
    const known = [
      'invalid_coordinates',
      'invalid_service',
      'choose_different_destination',
    ];
    return reply(req, 422, {
      error: known.includes(message) ? message : 'quote_unavailable',
    });
  }
});
