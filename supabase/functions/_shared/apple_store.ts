import { Buffer } from "node:buffer";
import {
  AppStoreServerAPIClient,
  Environment,
  SignedDataVerifier,
} from "@apple/app-store-server-library";

export { Environment };

export const APPLE_PRODUCT_IDS = new Set([
  "automotors_pack_10",
  "automotors_pack_15",
  "automotors_pack_20",
  "automotors_pro_monthly_199",
]);

export type AppleEnvironment = Environment;

export function configuredAppleEnvironment(): AppleEnvironment {
  const value = Deno.env.get("APPLE_STORE_ENVIRONMENT");
  if (value === "Sandbox") return Environment.SANDBOX;
  if (value === "Production") return Environment.PRODUCTION;
  throw new Error("APPLE_STORE_ENVIRONMENT must be Sandbox or Production.");
}

export function appleVerifier(environment: AppleEnvironment): SignedDataVerifier {
  const bundleId = required("IOS_BUNDLE_ID");
  const appIdValue = Deno.env.get("APPLE_APP_ID");
  const appAppleId = environment === Environment.PRODUCTION
    ? Number(appIdValue)
    : undefined;
  if (environment === Environment.PRODUCTION && (!appIdValue || !Number.isSafeInteger(appAppleId))) {
    throw new Error("APPLE_APP_ID is required for Production verification.");
  }

  const rootCertificates = ["APPLE_ROOT_CA_G2_BASE64", "APPLE_ROOT_CA_G3_BASE64"]
    .map((name) => required(name))
    .map((encoded) => Buffer.from(encoded.replace(/\s/g, ""), "base64"));

  return new SignedDataVerifier(rootCertificates, true, environment, bundleId, appAppleId);
}

export function appleServerApi(environment: AppleEnvironment): AppStoreServerAPIClient {
  return new AppStoreServerAPIClient(
    Buffer.from(required("APPLE_IAP_PRIVATE_KEY"), "utf8"),
    required("APPLE_IAP_KEY_ID"),
    required("APPLE_IAP_ISSUER_ID"),
    required("IOS_BUNDLE_ID"),
    environment,
  );
}

export function required(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`${name} is not configured.`);
  return value;
}

export function timestamp(value: unknown): string | null {
  if (typeof value !== "number" || !Number.isFinite(value) || value <= 0) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

export function subscriptionState(
  appleStatus: unknown,
  transaction: Record<string, unknown>,
  renewal: Record<string, unknown> | null,
): { status: "active" | "grace_period" | "expired" | "revoked"; expiresAt: string; autoRenewing: boolean } {
  const now = Date.now();
  const graceExpiry = timestamp(renewal?.gracePeriodExpiresDate);
  const transactionExpiry = timestamp(transaction.expiresDate);
  if (!transactionExpiry) throw new Error("Apple transaction has no valid expiry date.");

  let status: "active" | "grace_period" | "expired" | "revoked";
  let expiresAt = transactionExpiry;
  if (transaction.revocationDate != null || Number(appleStatus) === 5) {
    status = "revoked";
  } else if (graceExpiry && Date.parse(graceExpiry) > now) {
    status = "grace_period";
    expiresAt = graceExpiry;
  } else if (Number(appleStatus) === 1 && Date.parse(transactionExpiry) > now) {
    status = "active";
  } else {
    status = "expired";
  }

  return {
    status,
    expiresAt,
    autoRenewing: renewal?.autoRenewStatus === 1,
  };
}
