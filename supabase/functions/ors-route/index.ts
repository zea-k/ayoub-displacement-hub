// Proxy edge function for OpenRouteService directions API.
// Keeps ORS_API_KEY secret on the server.
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { start, end, profile = "driving-car" } = await req.json();

    // Validate coordinates: [lng, lat]
    if (
      !Array.isArray(start) || start.length !== 2 ||
      !Array.isArray(end) || end.length !== 2 ||
      start.some((n) => typeof n !== "number" || !isFinite(n)) ||
      end.some((n) => typeof n !== "number" || !isFinite(n))
    ) {
      return new Response(
        JSON.stringify({ error: "Invalid coordinates. Expected start/end as [lng, lat] number arrays." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Map profiles to OSRM profile names
    const profileMap: Record<string, string> = {
      "driving-car": "driving",
      "foot-walking": "foot",
      "cycling-regular": "cycling",
    };
    const osrmProfile = profileMap[profile] ?? "driving";

    // Use the public OSRM demo server — no API key required.
    // Coordinates format: {lng},{lat};{lng},{lat}
    const url =
      `https://router.project-osrm.org/route/v1/${osrmProfile}/` +
      `${start[0]},${start[1]};${end[0]},${end[1]}` +
      `?overview=full&geometries=geojson&alternatives=false&steps=false`;

    const osrmRes = await fetch(url, {
      headers: { Accept: "application/json" },
    });
    const data = await osrmRes.json();

    if (!osrmRes.ok || data?.code !== "Ok" || !data?.routes?.length) {
      return new Response(
        JSON.stringify({
          error: data?.message || data?.code || "Routing failed",
          details: data,
        }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const route = data.routes[0];
    const coords: [number, number][] = (route.geometry?.coordinates || []).map(
      (c: number[]) => [c[1], c[0]] as [number, number], // -> [lat, lng] for Leaflet
    );

    return new Response(
      JSON.stringify({
        coords,
        distance_m: route.distance ?? 0,
        duration_s: route.duration ?? 0,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
