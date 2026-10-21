import { createClient } from 'npm:@supabase/supabase-js@2.57.4';



const url = Deno.env.get('SUPABASE_URL')!;

const server = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {

  auth: { persistSession: false, autoRefreshToken: false },

});

const allowedOrigins = new Set((Deno.env.get('QUOTE_ALLOWED_ORIGINS') ?? '').split(',').map(x => x.trim()).filter(Boolean));



function isAllowedOrigin(origin: string | null): boolean {

  // Native Android/iOS clients normally do not send a browser Origin header.

  if (!origin) return true;

  if (allowedOrigins.has(origin)) return true;



  // Flutter Web development: allow localhost/loopback on any port only.

  try {

    const parsed = new URL(origin);

    const host = parsed.hostname;

    const isLocal = host === 'localhost' || host === '127.0.0.1' || host === '::1' || host === '[::1]';

    return isLocal && (parsed.protocol === 'http:' || parsed.protocol === 'https:');

  } catch {

    return false;

  }

}

function reply(req: Request, status: number, data: unknown): Response {

  const headers: Record<string, string> = { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'Vary': 'Origin' };

  const origin = req.headers.get('origin');

  if (origin && isAllowedOrigin(origin)) headers['Access-Control-Allow-Origin'] = origin;

  headers['Access-Control-Allow-Headers'] = 'authorization, apikey, content-type, x-client-info';

  headers['Access-Control-Allow-Methods'] = 'POST, OPTIONS';

  return new Response(JSON.stringify(data), { status, headers });

}

function coordinate(value: unknown, max: number): number {

  if (typeof value !== 'number' || !Number.isFinite(value) || Math.abs(value) > max) throw new Error('invalid_coordinates');

  return Number(value.toFixed(7));

}

Deno.serve(async (req: Request) => {

  const origin = req.headers.get('origin');

  if (req.method === 'OPTIONS') {

    if (!isAllowedOrigin(origin)) return reply(req, 403, { error: 'origin_not_allowed' });

    return reply(req, 200, {});

  }

  if (!isAllowedOrigin(origin)) return reply(req, 403, { error: 'origin_not_allowed' });

  if (req.method !== 'POST') return reply(req, 405, { error: 'post_required' });

  const token = req.headers.get('authorization')?.replace(/^Bearer\s+/i, '');

  if (!token) return reply(req, 401, { error: 'authentication_required' });

  const { data: auth, error: authError } = await server.auth.getUser(token);

  if (authError || !auth.user) return reply(req, 401, { error: 'authentication_required' });

  try {

    const bodyText = await req.text();

    if (bodyText.length > 2048) return reply(req, 413, { error: 'request_too_large' });

    const input = JSON.parse(bodyText);

    const fromLat = coordinate(input.pickup_lat, 90), fromLng = coordinate(input.pickup_lng, 180);

    const toLat = coordinate(input.destination_lat, 90), toLng = coordinate(input.destination_lng, 180);

    if (!['car_ride', 'motorcycle_ride', 'package', 'vito_market'].includes(input.service_type)) throw new Error('invalid_service');

    if (fromLat === toLat && fromLng === toLng) throw new Error('choose_different_destination');

    const { data: slot, error: slotError } = await server.rpc('claim_route_quote_slot', { p_user_id: auth.user.id });

    if (slotError) return reply(req, 503, { error: 'quote_service_unavailable' });

    if (slot !== true) return reply(req, 429, { error: 'quote_rate_limit' });

    // Configure an operated OSRM server; the public demo is not a production routing SLA.

    const base = Deno.env.get('OSRM_ROUTING_URL');

    if (!base) return reply(req, 503, { error: 'routing_not_configured' });

    const routeUrl = new URL(base);

    if (routeUrl.protocol !== 'https:' || routeUrl.username || routeUrl.password || routeUrl.search || routeUrl.hash) throw new Error('invalid_routing_configuration');

    routeUrl.pathname = `${routeUrl.pathname.replace(/\/$/, '')}/route/v1/driving/${fromLng},${fromLat};${toLng},${toLat}`;

    routeUrl.search = 'overview=false&alternatives=false&steps=false';

    const response = await fetch(routeUrl, {

      headers: { 'User-Agent': 'VETO-SANYA/1.0 (isolated routing integration)' },

      signal: AbortSignal.timeout(10000), redirect: 'error',

    });

    if (!response.ok) return reply(req, 503, { error: 'routing_unavailable' });

    const result = await response.json();

    const route = result.routes?.[0];

    const snapped = result.waypoints;

    if (result.code !== 'Ok' || !route || !Number.isFinite(route.distance) || !Number.isFinite(route.duration)

      || route.distance <= 0 || route.distance > 1000000 || route.duration <= 0 || route.duration > 86400

      || !Array.isArray(snapped) || snapped.length !== 2 || snapped.some(w => !Number.isFinite(w.distance) || w.distance > 300)) {

      return reply(req, 422, { error: 'route_not_supported' });

    }

    const category = input.ride_category_id;
    if(category != null && !['veto_economy','veto_comfort','veto_premium','veto_ladies','veto_moto','veto_parcel'].includes(category)) throw new Error('invalid_category');
    const quoteParams = category == null ? {

      p_user_id: auth.user.id, p_service: input.service_type,

      p_pickup_lat: fromLat, p_pickup_lng: fromLng, p_destination_lat: toLat, p_destination_lng: toLng,

      p_distance_km: Math.max(0.001, Math.round(route.distance) / 1000),

      p_duration_minutes: Math.max(1, Math.ceil(route.duration / 60)),

    } : {p_user:auth.user.id,p_category:category,p_service:input.service_type,p_from_lat:fromLat,p_from_lng:fromLng,p_to_lat:toLat,p_to_lng:toLng,p_km:Math.max(0.001,Math.round(route.distance)/1000),p_minutes:Math.max(1,Math.ceil(route.duration/60))};
    const {data,error}=await server.rpc(category==null?'issue_route_pricing_quote':'v3_issue_category_quote',quoteParams);

    if (error) {

      const known = ['category_unavailable', 'category_price_unavailable', 'global_pricing_not_configured', 'service_unavailable', 'customer_required', 'quote_rate_limit'];

      return reply(req, error.message.includes('quote_rate_limit') ? 429 : 422, {

        error: known.find(code => error.message.includes(code)) ?? 'quote_failed',

      });

    }

    if (input.timeout_retry_trip_id != null) {

      if (typeof input.timeout_retry_trip_id !== 'string' ||

          !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(input.timeout_retry_trip_id)) {

        return reply(req, 422, { error: 'invalid_retry_reference' });

      }

      // Auth UID comes from verified bearer token, never from caller-supplied role/phone.
      // Preserve the original category; the existing retry engine retains its
      // ownership, time window, coordinates, lineage and 10% retry rules.
      const {data: sourceTrip, error: sourceError} = await server.from('trips')
        .select('ride_category_id_v3').eq('id', input.timeout_retry_trip_id).maybeSingle();
      if (sourceError || !sourceTrip ||
          (sourceTrip.ride_category_id_v3 ?? null) !== (category ?? null)) {
        return reply(req, 422, {error: 'retry_category_mismatch'});
      }

      const { data: adjusted, error: retryError } = await server.rpc('v28_apply_search_retry_quote', {

        p_quote_id: data.id,

        p_trip_id: input.timeout_retry_trip_id,

        p_user_id: auth.user.id,

      });

      if (retryError || !adjusted) return reply(req, 422, { error: 'retry_not_available' });

      return reply(req, 200, adjusted);

    }

    return reply(req, 200, data);

  } catch (error) {

    const message = error instanceof Error ? error.message : '';

    const known = ['invalid_coordinates', 'invalid_service', 'choose_different_destination'];

    return reply(req, 422, { error: known.includes(message) ? message : 'quote_unavailable' });

  }

});

