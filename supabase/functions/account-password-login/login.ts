import { createClient } from "npm:@supabase/supabase-js@2";
import { json, parseJsonObject } from "../_shared/http.ts";
import { serviceClient } from "../_shared/supabase.ts";

type ServiceClient = {
  rpc: (
    name: string,
    args: Record<string, unknown>,
  ) => PromiseLike<{ data: unknown; error: unknown }>;
};

type PasswordClient = {
  auth: {
    signInWithPassword: (credentials: {
      email: string;
      password: string;
      options?: { captchaToken?: string };
    }) => Promise<{ data: { session: unknown }; error: unknown }>;
  };
};

export type AccountPasswordLoginDependencies = {
  service: () => ServiceClient;
  password: () => PasswordClient;
  rateLimitSecret: () => string | undefined;
  requireCaptcha: () => boolean;
  clientIP: (request: Request) => string | null;
  limits: () => { ip: number; identifier: number; windowSeconds: number };
};

const invalidCredentials = () =>
  json({ error: "Invalid username or password" }, 401);

export function accountPasswordLoginHandler(
  dependencies: AccountPasswordLoginDependencies = liveDependencies(),
) {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }
    try {
      const body = await parseJsonObject(request);
      const identifierForLimit = loginIdentifierForLimit(body.username);
      const username = normalizeLoginUsername(body.username);
      const password = credentialString(body.password, 1024);
      const captchaToken = optionalCaptchaToken(body.captchaToken);
      const ip = dependencies.clientIP(request);
      const secret = dependencies.rateLimitSecret();
      if (!ip || !secret) {
        return json({ error: "Sign-in is temporarily unavailable" }, 503);
      }
      if (dependencies.requireCaptcha() && !captchaToken) {
        return json({ error: "Verification required" }, 400);
      }

      const [ipDigest, identifierDigest] = await Promise.all([
        digest(secret, `ip:${ip}`),
        digest(secret, `identifier:${identifierForLimit}`),
      ]);
      const limits = dependencies.limits();
      const rate = await dependencies.service().rpc(
        "account_password_login_rate_limit_v1",
        {
          p_ip_digest: ipDigest,
          p_identifier_digest: identifierDigest,
          p_ip_limit: limits.ip,
          p_identifier_limit: limits.identifier,
          p_window_seconds: limits.windowSeconds,
        },
      );
      if (rate.error || rate.data !== true) {
        return json({ error: "Try again later" }, 429);
      }
      if (!username || !password) return invalidCredentials();

      // The service-only RPC returns an email only inside this function.  It is
      // intentionally followed by the same Auth call for an absent username.
      const lookup = await dependencies.service().rpc(
        "account_username_login_email_v1",
        {
          p_username: username,
        },
      );
      const email = typeof lookup.data === "string"
        ? lookup.data
        : unknownLoginEmail(username);
      const { data, error } = await dependencies.password().auth
        .signInWithPassword({
          email,
          password,
          options: captchaToken ? { captchaToken } : undefined,
        });
      // The fallback preserves Auth's timing path, but it can never
      // authenticate an absent registry entry even if that address exists.
      if (
        lookup.error || typeof lookup.data !== "string" || error ||
        !data.session
      ) return invalidCredentials();
      return json(data.session);
    } catch {
      // Input, database, and Auth failures deliberately have no credential detail.
      return invalidCredentials();
    }
  };
}

export function normalizeLoginUsername(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const username = value.trim().replace(/^@/, "").toLowerCase();
  return /^[a-z][a-z0-9_]{2,23}$/.test(username) ? username : null;
}

function loginIdentifierForLimit(value: unknown): string {
  if (typeof value !== "string" || value.length > 64) return "<invalid>";
  const trimmed = value.trim().replace(/^@/, "").toLowerCase();
  return trimmed.length > 0 ? trimmed : "<invalid>";
}

function credentialString(value: unknown, maxLength: number): string | null {
  return typeof value === "string" && value.length > 0 &&
      value.length <= maxLength
    ? value
    : null;
}

function optionalCaptchaToken(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 && value.length <= 4096
    ? value
    : undefined;
}

function unknownLoginEmail(username: string): string {
  // A syntactically valid non-routable-looking address keeps Auth verification
  // on the same path while never disclosing whether the username was present.
  return `missing-${username}@invalid.countingsheep.local`;
}

async function digest(secret: string, value: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(signature)].map((byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}

function liveDependencies(): AccountPasswordLoginDependencies {
  return {
    service: serviceClient,
    password: () =>
      createClient(
        requiredEnvironment("SUPABASE_URL"),
        requiredEnvironment("SUPABASE_ANON_KEY"),
        {
          auth: { persistSession: false },
        },
      ),
    rateLimitSecret: () =>
      Deno.env.get("ACCOUNT_PASSWORD_LOGIN_RATE_LIMIT_SECRET"),
    requireCaptcha: () =>
      Deno.env.get("ACCOUNT_PASSWORD_LOGIN_REQUIRE_CAPTCHA") === "true",
    clientIP: trustedClientIP,
    limits: () => ({
      ip: positiveEnvironment("ACCOUNT_PASSWORD_LOGIN_IP_LIMIT", 20),
      identifier: positiveEnvironment(
        "ACCOUNT_PASSWORD_LOGIN_IDENTIFIER_LIMIT",
        5,
      ),
      windowSeconds: positiveEnvironment(
        "ACCOUNT_PASSWORD_LOGIN_WINDOW_SECONDS",
        300,
      ),
    }),
  };
}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Server configuration missing ${name}`);
  return value;
}

function positiveEnvironment(name: string, fallback: number): number {
  const value = Deno.env.get(name);
  if (!value) return fallback;
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 1 || parsed > 3600) {
    throw new Error(`Invalid ${name}`);
  }
  return parsed;
}

function trustedClientIP(request: Request): string | null {
  // Hosted deployment must have its trusted gateway overwrite this header.  The
  // documented production gate verifies that behavior before this function ships.
  const forwarded = request.headers.get("x-forwarded-for");
  return forwarded?.split(",")[0]?.trim() ||
    request.headers.get("cf-connecting-ip");
}
