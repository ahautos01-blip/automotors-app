import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

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

async function hasVehicleLookupEntitlement(userId: string): Promise<boolean> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) throw new Error("Configuración interna de Supabase incompleta.");

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const now = new Date().toISOString();
  const { data: entitlements, error: entitlementError } = await admin
    .from("user_promotion_entitlements")
    .select("purchase_id")
    .eq("user_id", userId)
    .eq("status", "active")
    .gt("ends_at", now);

  if (entitlementError) throw entitlementError;
  const purchaseIds = (entitlements ?? [])
    .map((row: { purchase_id: string | null }) => row.purchase_id)
    .filter((id: string | null): id is string => Boolean(id));
  if (purchaseIds.length === 0) return false;

  const { data: purchases, error: purchaseError } = await admin
    .from("promotion_purchases")
    .select("id, promotion_products!inner(code)")
    .eq("user_id", userId)
    .eq("payment_status", "paid")
    .in("id", purchaseIds);

  if (purchaseError) throw purchaseError;
  return (purchases ?? []).some((purchase: any) => {
    const product = Array.isArray(purchase.promotion_products)
      ? purchase.promotion_products[0]
      : purchase.promotion_products;
    const code = String(product?.code ?? "").toUpperCase();
    return code === "PACK_20" || code === "PRO_MONTHLY";
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Método no permitido." }, 405);

  let input: Record<string, unknown>;
  try {
    input = await req.json();
  } catch {
    return json({ error: "La petición no contiene JSON válido." }, 400);
  }

  const authorization = req.headers.get("Authorization") ?? "";
  const token = authorization.replace(/^Bearer\s+/i, "").trim();
  if (!token) return json({ error: "Inicia sesión para utilizar esta función." }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? req.headers.get("apikey");
  if (!supabaseUrl || !anonKey) {
    return json({ error: "No se pudo verificar la sesión." }, 500);
  }

  const authClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await authClient.auth.getUser(token);
  if (authError || !authData.user) {
    return json({ error: "Tu sesión no es válida. Inicia sesión de nuevo." }, 401);
  }

  let entitled: boolean;
  try {
    entitled = await hasVehicleLookupEntitlement(authData.user.id);
  } catch (error) {
    console.error("No se pudo comprobar el acceso a la búsqueda de vehículos:", error);
    return json({ error: "No se pudo comprobar tu plan. Inténtalo de nuevo más tarde." }, 500);
  }

  if (!entitled) {
    return json({
      error: "Esta función está disponible exclusivamente con PACK 20 o una suscripción AUTOMOTORS PRO activa.",
      code: "PLAN_REQUIRED",
      allowed: false,
    }, 403);
  }

  if (input.access_only === true) return json({ allowed: true });

  const apiKey = Deno.env.get("APIVEHICULO_API_KEY");
  if (!apiKey) {
    return json({
      error: "La búsqueda automática aún no está activada. Falta configurar la clave segura del proveedor en Supabase.",
      code: "PROVIDER_NOT_CONFIGURED",
    }, 503);
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
      headers: { "Authorization": `Bearer ${apiKey}`, "Accept": "application/json" },
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
