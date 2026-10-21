import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { from_lat, from_lng, to_lat, to_lng, with_geometry } =
      await req.json();

    if (
      from_lat == null ||
      from_lng == null ||
      to_lat == null ||
      to_lng == null
    ) {
      return new Response(
        JSON.stringify({ error: "Missing coordinates" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Read ORS API key or fallback to OSRM server
    const orsApiKey = Deno.env.get("ORS_API_KEY");
    const osrmBase = Deno.env.get("OSRM_ROUTING_URL") || "https://router.project-osrm.org";

    if (!orsApiKey && osrmBase) {
      const overview = with_geometry === true ? "full" : "false";
      const osrmUrl = `${osrmBase.replace(/\/$/, '')}/route/v1/driving/${from_lng},${from_lat};${to_lng},${to_lat}?overview=${overview}&geometries=polyline`;
      const osrmRes = await fetch(osrmUrl, {
        headers: { 'User-Agent': 'VETO-SANYA/1.0 (health route integration)' },
        signal: AbortSignal.timeout(10000),
      });
      if (!osrmRes.ok) {
        return new Response(
          JSON.stringify({ error: "Routing unavailable", status: osrmRes.status }),
          {
            status: 502,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }
      const osrmData = await osrmRes.json();
      const route = osrmData.routes?.[0];
      if (!route) {
        return new Response(
          JSON.stringify({ error: "No route found" }),
          {
            status: 404,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }
      const distanceKm = Number(((route.distance ?? 0) / 1000.0).toFixed(2));
      const durationMinutes = Number(((route.duration ?? 0) / 60.0).toFixed(1));
      let routePoints: number[][] = [];
      if (with_geometry === true && route.geometry) {
        routePoints = decodePolyline(route.geometry);
      }
      return new Response(
        JSON.stringify({
          distance_km: distanceKm,
          duration_minutes: durationMinutes,
          route_points: routePoints,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (!orsApiKey) {
      return new Response(
        JSON.stringify({ error: "Routing service not configured" }),
        {
          status: 503,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const orsUrl =
      "https://api.heigit.org/openrouteservice/v2/directions/driving-car/json";

    const body = {
      coordinates: [
        [from_lng, from_lat],
        [to_lng, to_lat],
      ],
      instructions: false,
      geometry: with_geometry === true,
      geometry_simplify: false,
    };

    const orsResponse = await fetch(orsUrl, {
      method: "POST",
      headers: {
        Authorization: orsApiKey,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify(body),
    });

    if (!orsResponse.ok) {
      const errText = await orsResponse.text();
      console.error("ORS error:", orsResponse.status, errText);
      return new Response(
        JSON.stringify({
          error: "Routing service error",
          status: orsResponse.status,
        }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const data = await orsResponse.json();
    const routes = data?.routes;
    if (!routes || routes.length === 0) {
      return new Response(
        JSON.stringify({ error: "No route found" }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const route = routes[0];
    const summary = route.summary;
    const distanceKm = (summary?.distance ?? 0) / 1000.0;
    const durationMinutes = (summary?.duration ?? 0) / 60.0;

    // Decode geometry if requested
    let routePoints: number[][] = [];
    if (with_geometry === true && route.geometry) {
      routePoints = decodePolyline(route.geometry);
    }

    return new Response(
      JSON.stringify({
        distance_km: distanceKm,
        duration_minutes: durationMinutes,
        route_points: routePoints,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    console.error("get-route error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});

/**
 * Decode Google-encoded polyline (used by ORS geometry field).
 * Returns array of [lat, lng] pairs.
 */
function decodePolyline(encoded: string): number[][] {
  const points: number[][] = [];
  let index = 0;
  let lat = 0;
  let lng = 0;

  while (index < encoded.length) {
    let b: number;
    let shift = 0;
    let result = 0;
    do {
      b = encoded.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    const dlat = result & 1 ? ~(result >> 1) : result >> 1;
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    const dlng = result & 1 ? ~(result >> 1) : result >> 1;
    lng += dlng;

    points.push([lat / 1e5, lng / 1e5]);
  }
  return points;
}
