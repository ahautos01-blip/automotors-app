import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import {
  APPLE_PRODUCT_IDS,
  appleServerApi,
  appleVerifier,
  configuredAppleEnvironment,
  subscriptionState,
  timestamp,
} from "../_shared/apple_store.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Método no permitido." }, 405);

  const authorization = req.headers.get("Authorization") ?? "";
  const token = authorization.replace(/^Bearer\s+/i, "").trim();
  if (!token) return json({ error: "Inicia sesión para verificar la compra." }, 401);

  let input: Record<string, unknown>;
  try {
    input = await req.json();
  } catch {
    return json({ error: "La petición no contiene JSON válido." }, 400);
  }

  if (input.platform !== "apple") {
    return json({ error: "La verificación de Google Play aún no está configurada." }, 501);
  }
  const productId = typeof input.productId === "string" ? input.productId : "";
  const transactionId = typeof input.transactionId === "string" ? input.transactionId : "";
  if (!APPLE_PRODUCT_IDS.has(productId) || !/^\d{1,32}$/.test(transactionId)) {
    return json({ error: "La compra no contiene un producto o identificador válido." }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? req.headers.get("apikey");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json({ error: "La verificación de compras no está configurada." }, 503);
  }

  const authClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await authClient.auth.getUser(token);
  if (authError || !authData.user) {
    return json({ error: "Tu sesión ha caducado. Inicia sesión de nuevo." }, 401);
  }

  try {
    const environment = configuredAppleEnvironment();
    const bundleId = Deno.env.get("IOS_BUNDLE_ID");
    const api = appleServerApi(environment);
    const verifier = appleVerifier(environment);
    const response = await api.getTransactionInfo(transactionId);
    if (!response.signedTransactionInfo) {
      return json({ error: "Apple no devolvió una transacción verificable." }, 422);
    }

    const transaction = await verifier.verifyAndDecodeTransaction(response.signedTransactionInfo);
    if (
      transaction.transactionId !== transactionId ||
      transaction.productId !== productId ||
      transaction.bundleId !== bundleId ||
      transaction.type !== "Auto-Renewable Subscription" ||
      !transaction.originalTransactionId
    ) {
      return json({ error: "La transacción no coincide con AUTOMOTORS o con el producto solicitado." }, 422);
    }

    const statusResponse = await api.getAllSubscriptionStatuses(transaction.originalTransactionId);
    const candidates = (statusResponse.data ?? []).flatMap((group: any) => group.lastTransactions ?? []);
    let matching: { status: unknown; transaction: Record<string, unknown>; renewal: Record<string, unknown> | null } | null = null;
    for (const item of candidates) {
      if (typeof item.signedTransactionInfo !== "string") continue;
      const candidate = await verifier.verifyAndDecodeTransaction(item.signedTransactionInfo);
      if (
        candidate.originalTransactionId !== transaction.originalTransactionId ||
        !APPLE_PRODUCT_IDS.has(candidate.productId ?? "")
      ) continue;
      const renewal = typeof item.signedRenewalInfo === "string"
        ? await verifier.verifyAndDecodeRenewalInfo(item.signedRenewalInfo)
        : null;
      if (!matching || Number(candidate.signedDate ?? 0) > Number(matching.transaction.signedDate ?? 0)) {
        matching = {
          status: item.status,
          transaction: candidate as unknown as Record<string, unknown>,
          renewal: renewal as unknown as Record<string, unknown> | null,
        };
      }
    }
    if (!matching) return json({ error: "Apple aún no confirma el estado de esta suscripción." }, 503);

    const state = subscriptionState(matching.status, matching.transaction, matching.renewal);
    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: applied, error: applyError } = await admin.rpc(
      "apply_verified_store_subscription",
      {
        p_user_id: authData.user.id,
        p_provider: "apple",
        p_product_id: matching.transaction.productId,
        p_transaction_id: matching.transaction.transactionId,
        p_original_transaction_id: matching.transaction.originalTransactionId,
        p_status: state.status,
        p_started_at: timestamp(matching.transaction.purchaseDate),
        p_expires_at: state.expiresAt,
        p_auto_renewing: state.autoRenewing,
        p_verified_at: new Date().toISOString(),
      },
    );
    if (applyError) {
      if (applyError.message.includes("already linked to another AUTOMOTORS account")) {
        return json({ error: "Esta suscripción ya está vinculada a otra cuenta AUTOMOTORS." }, 409);
      }
      console.error("Could not persist verified Apple subscription.", applyError.code ?? "database_error");
      return json({ error: "No se pudo guardar la suscripción verificada." }, 500);
    }

    return json({ verified: true, status: state.status, applied: applied === true });
  } catch (error) {
    console.error("Apple purchase verification failed.", error instanceof Error ? error.name : "unknown_error");
    return json({ error: "Apple no pudo confirmar la compra. No se ha concedido acceso." }, 503);
  }
});
