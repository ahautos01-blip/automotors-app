import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import { Buffer } from "node:buffer";
import {
  APPLE_PRODUCT_IDS,
  appleServerApi,
  appleVerifier,
  Environment,
  subscriptionState,
  timestamp,
} from "../_shared/apple_store.ts";

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}

function environmentFromUnverifiedPayload(signedPayload: string): Environment {
  const payloadPart = signedPayload.split(".")[1];
  if (!payloadPart) throw new Error("Malformed signed notification.");
  const payload = JSON.parse(Buffer.from(payloadPart, "base64url").toString("utf8"));
  const value = payload?.data?.environment;
  if (value === "Sandbox") return Environment.SANDBOX;
  if (value === "Production") return Environment.PRODUCTION;
  throw new Error("Notification has no valid App Store environment.");
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "Método no permitido." }, 405);

  let input: Record<string, unknown>;
  try {
    input = await req.json();
  } catch {
    return json({ error: "La notificación no contiene JSON válido." }, 400);
  }
  const signedPayload = typeof input.signedPayload === "string" ? input.signedPayload : "";
  if (!signedPayload) return json({ error: "Falta la notificación firmada por Apple." }, 400);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) return json({ error: "Configuración interna incompleta." }, 503);

  let admin: ReturnType<typeof createClient>;
  try {
    const environment = environmentFromUnverifiedPayload(signedPayload);
    const verifier = appleVerifier(environment);
    const notification = await verifier.verifyAndDecodeNotification(signedPayload);
    const notificationId = notification.notificationUUID;
    const notificationType = notification.notificationType ?? "UNKNOWN";
    if (!notificationId) return json({ error: "Apple no proporcionó un identificador de notificación." }, 400);

    admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { error: insertError } = await admin.from("store_notification_events").insert({
      provider: "apple",
      provider_event_id: notificationId,
      event_type: notificationType,
      processing_status: "pending",
    });
    if (insertError && insertError.code !== "23505") {
      console.error("Could not record Apple notification.", insertError.code ?? "database_error");
      return json({ error: "No se pudo registrar la notificación." }, 503);
    }

    const { data: existingEvent, error: eventReadError } = await admin
      .from("store_notification_events")
      .select("processing_status")
      .eq("provider", "apple")
      .eq("provider_event_id", notificationId)
      .maybeSingle();
    if (eventReadError) return json({ error: "No se pudo consultar el estado de la notificación." }, 503);
    if (existingEvent?.processing_status === "processed" || existingEvent?.processing_status === "ignored") {
      return json({ received: true, duplicate: true });
    }

    const data = notification.data;
    if (!data?.signedTransactionInfo) {
      await admin.from("store_notification_events")
        .update({ processing_status: "ignored", processed_at: new Date().toISOString() })
        .eq("provider", "apple")
        .eq("provider_event_id", notificationId);
      return json({ received: true, ignored: true });
    }

    const transaction = await verifier.verifyAndDecodeTransaction(data.signedTransactionInfo);
    const productId = transaction.productId ?? "";
    const originalTransactionId = transaction.originalTransactionId ?? "";
    if (
      transaction.bundleId !== Deno.env.get("IOS_BUNDLE_ID") ||
      !APPLE_PRODUCT_IDS.has(productId) ||
      !originalTransactionId
    ) {
      await admin.from("store_notification_events")
        .update({ processing_status: "ignored", processed_at: new Date().toISOString() })
        .eq("provider", "apple")
        .eq("provider_event_id", notificationId);
      return json({ received: true, ignored: true });
    }

    const { data: linkedSubscription, error: lookupError } = await admin
      .from("user_subscriptions")
      .select("user_id")
      .eq("provider", "apple")
      .eq("provider_original_id", originalTransactionId)
      .maybeSingle();
    if (lookupError) return json({ error: "No se pudo localizar la suscripción." }, 503);
    if (!linkedSubscription) {
      // Apple retries non-2xx notifications, so a purchase racing its first
      // verification remains recoverable instead of being silently discarded.
      return json({ error: "La compra aún no está vinculada a una cuenta." }, 503);
    }

    const notificationRenewal = data.signedRenewalInfo
      ? await verifier.verifyAndDecodeRenewalInfo(data.signedRenewalInfo)
      : null;
    const api = appleServerApi(environment);
    const statusResponse = await api.getAllSubscriptionStatuses(originalTransactionId);
    const candidates = (statusResponse.data ?? []).flatMap((group: any) => group.lastTransactions ?? []);
    let current: { status: unknown; transaction: Record<string, unknown>; renewal: Record<string, unknown> | null } | null = null;
    for (const item of candidates) {
      if (typeof item.signedTransactionInfo !== "string") continue;
      const candidate = await verifier.verifyAndDecodeTransaction(item.signedTransactionInfo);
      if (
        candidate.originalTransactionId !== originalTransactionId ||
        !APPLE_PRODUCT_IDS.has(candidate.productId ?? "")
      ) continue;
      const renewal = typeof item.signedRenewalInfo === "string"
        ? await verifier.verifyAndDecodeRenewalInfo(item.signedRenewalInfo)
        : null;
      if (!current || Number(candidate.signedDate ?? 0) > Number(current.transaction.signedDate ?? 0)) {
        current = {
          status: item.status,
          transaction: candidate as unknown as Record<string, unknown>,
          renewal: renewal as unknown as Record<string, unknown> | null,
        };
      }
    }
    if (!current) return json({ error: "Apple aún no confirma el estado de esta suscripción." }, 503);
    const currentTransaction = current.transaction;
    const renewal = current.renewal ?? notificationRenewal as unknown as Record<string, unknown> | null;
    const state = subscriptionState(
      current.status,
      currentTransaction,
      renewal,
    );
    const finalStatus = currentTransaction.revocationDate != null
      ? "revoked"
      : state.status;
    const { error: applyError } = await admin.rpc("apply_verified_store_subscription", {
      p_user_id: linkedSubscription.user_id,
      p_provider: "apple",
      p_product_id: currentTransaction.productId,
      p_transaction_id: currentTransaction.transactionId,
      p_original_transaction_id: originalTransactionId,
      p_status: finalStatus,
      p_started_at: timestamp(currentTransaction.purchaseDate),
      p_expires_at: state.expiresAt,
      p_auto_renewing: state.autoRenewing,
      p_verified_at: new Date().toISOString(),
    });
    if (applyError) {
      console.error("Could not update subscription from Apple notification.", applyError.code ?? "database_error");
      return json({ error: "No se pudo actualizar la suscripción." }, 503);
    }

    await admin.from("store_notification_events")
      .update({ processing_status: "processed", processed_at: new Date().toISOString(), error_code: null })
      .eq("provider", "apple")
      .eq("provider_event_id", notificationId);
    return json({ received: true });
  } catch (error) {
    console.error("Apple server notification rejected.", error instanceof Error ? error.name : "unknown_error");
    return json({ error: "La notificación no superó la validación de Apple." }, 400);
  }
});
