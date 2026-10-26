import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Método no permitido." }, 405);

  const apiKey = Deno.env.get("APIVEHICULO_API_KEY");
  if (!apiKey) {
    return json({
      error: "La búsqueda automática aún no está activada. Falta configurar la clave segura del proveedor en Supabase.",
      code: "PROVIDER_NOT_CONFIGURED",
    }, 503);
  }

  let input: Record<string, unknown>;
  try {
    input = await req.json();
  } catch {
    return json({ error: "La petición no contiene JSON válido." }, 400);
  }

  const plate = typeof input.plate === "string" ? input.plate.toUpperCase().replace(/[^A-Z0-9]/g, "") : "";
  const vin = typeof input.vin === "string" ? input.vin.toUpperCase().replace(/[^A-Z0-9]/g, "") : "";
  if (Boolean(plate) === Boolean(vin)) {
    return json({ error: "Introduce una matrícula o un VIN, pero no ambos a la vez." }, 400);
  }
  if (plate && plate.length < 5) return json({ error: "Revisa la matrícula introducida." }, 400);
  if (vin && vin.length !== 17) return json({ error: "El VIN debe tener 17 caracteres." }, 400);

  const url = new URL("https://api.apivehiculo.com/v1/vehicles/lookup");
  if (plate) {
    url.searchParams.set("plate", plate);
    url.searchParams.set("country", "ES");
  } else {
    url.searchParams.set("vin", vin);
  }

  try {
    const response = await fetch(url, {
      method: "GET",
      headers: { "Authorization": \`Bearer \${apiKey}\`, "Accept": "application/json" },
      signal: AbortSignal.timeout(15000),
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      const providerMessage = typeof payload?.message === "string" ? payload.message : "";
      if (response.status === 404) return json({ error: "No se encontró el vehículo. Comprueba la matrícula o el VIN." }, 404);
      if (response.status === 429) return json({ error: "Se ha alcanzado el límite de consultas del proveedor. Inténtalo más tarde." }, 429);
      if (response.status === 401 || response.status === 403) return json({ error: "La clave del proveedor no es válida o no tiene acceso." }, 502);
      return json({ error: providerMessage || "El proveedor no pudo completar la consulta." }, 502);
    }

    const data = payload?.data;
    if (!data || typeof data !== "object") return json({ error: "El proveedor devolvió una respuesta sin datos del vehículo." }, 502);
    return json({ data });
  } catch {
    return json({ error: "No se pudo conectar con el proveedor. Inténtalo de nuevo." }, 502);
  }
});
