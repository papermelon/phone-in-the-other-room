type Environment = "sandbox" | "production";

export interface APNsEndEvent {
  pushToken: string;
  environment: Environment;
  plannedEndAt: string;
}

export interface APNsResult {
  status: number;
  reason: string;
  outcome: "delivered" | "retry" | "terminal";
}

export interface APNsUpdateEvent {
  pushToken: string;
  environment: Environment;
  plannedEndAt: string;
  phase: string;
  bedtimeAt: string | null;
  wakeAt: string | null;
  morningQuietEndsAt: string | null;
  eveningActivityTitle: string | null;
  morningActivityTitle: string | null;
}

let cachedProviderToken: { value: string; createdAt: number } | undefined;

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Server configuration missing ${name}`);
  return value;
}

function base64URL(data: Uint8Array | string): string {
  const bytes = typeof data === "string"
    ? new TextEncoder().encode(data)
    : data;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll(
    "=",
    "",
  );
}

function privateKeyBytes(pem: string): Uint8Array {
  const normalized = pem.replaceAll("\\n", "\n");
  const encoded = normalized
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replaceAll(/\s/g, "");
  const binary = atob(encoded);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

async function providerToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedProviderToken && now - cachedProviderToken.createdAt < 45 * 60) {
    return cachedProviderToken.value;
  }

  const header = base64URL(
    JSON.stringify({ alg: "ES256", kid: requiredEnvironment("APNS_KEY_ID") }),
  );
  const payload = base64URL(
    JSON.stringify({ iss: requiredEnvironment("APNS_TEAM_ID"), iat: now }),
  );
  const unsigned = `${header}.${payload}`;
  const keyBytes = privateKeyBytes(requiredEnvironment("APNS_PRIVATE_KEY_P8"));
  const keyData = keyBytes.buffer.slice(
    keyBytes.byteOffset,
    keyBytes.byteOffset + keyBytes.byteLength,
  ) as ArrayBuffer;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" },
      key,
      new TextEncoder().encode(unsigned),
    ),
  );
  const value = `${unsigned}.${base64URL(signature)}`;
  cachedProviderToken = { value, createdAt: now };
  return value;
}

export async function sendLiveActivityEnd(
  event: APNsEndEvent,
): Promise<APNsResult> {
  const configuredEnvironment = requiredEnvironment("APNS_ENVIRONMENT");
  if (
    configuredEnvironment !== "sandbox" &&
    configuredEnvironment !== "production"
  ) {
    throw new Error("Server configuration has invalid APNS_ENVIRONMENT");
  }
  if (event.environment !== configuredEnvironment) {
    throw new Error(
      "Claimed event does not match the configured APNs environment",
    );
  }
  const host = requiredEnvironment("APNS_HOST").replace(/\/$/, "");
  const expectedHost = configuredEnvironment === "sandbox"
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com";
  if (host !== expectedHost) {
    throw new Error("Server configuration has invalid APNS_HOST");
  }
  const plannedEnd = new Date(event.plannedEndAt);
  // ActivityKit uses Codable's default Date representation inside content-state:
  // seconds since Apple's 2001 reference date, not the APNs envelope's Unix timestamps.
  const plannedEndReferenceSeconds = plannedEnd.getTime() / 1000 - 978307200;
  const now = Math.floor(Date.now() / 1000);
  const response = await fetch(`${host}/3/device/${event.pushToken}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${await providerToken()}`,
      "apns-push-type": "liveactivity",
      "apns-topic": requiredEnvironment("APNS_LIVE_ACTIVITY_TOPIC"),
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      aps: {
        timestamp: now,
        event: "end",
        "dismissal-date": now,
        "content-state": {
          plannedEndAt: plannedEndReferenceSeconds,
          isComplete: true,
        },
      },
    }),
  });

  let reason = response.statusText || "Unknown";
  try {
    const body = await response.json() as { reason?: string };
    if (body.reason) reason = body.reason;
  } catch {
    // APNs commonly returns an empty body for success.
  }

  if (response.ok) {
    return { status: response.status, reason: "Success", outcome: "delivered" };
  }
  if (response.status === 429 || response.status >= 500) {
    return { status: response.status, reason, outcome: "retry" };
  }
  return { status: response.status, reason, outcome: "terminal" };
}

export async function sendLiveActivityUpdate(
  event: APNsUpdateEvent,
): Promise<APNsResult> {
  const configuredEnvironment = requiredEnvironment("APNS_ENVIRONMENT");
  if (
    configuredEnvironment !== "sandbox" &&
    configuredEnvironment !== "production"
  ) {
    throw new Error("Server configuration has invalid APNS_ENVIRONMENT");
  }
  if (event.environment !== configuredEnvironment) {
    throw new Error(
      "Claimed event does not match the configured APNs environment",
    );
  }
  const host = requiredEnvironment("APNS_HOST").replace(/\/$/, "");
  const expectedHost = configuredEnvironment === "sandbox"
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com";
  if (host !== expectedHost) {
    throw new Error("Server configuration has invalid APNS_HOST");
  }

  const toReferenceSeconds = (value: string | null): number | null => {
    if (!value) return null;
    return new Date(value).getTime() / 1000 - 978307200;
  };
  const plannedEndReferenceSeconds = toReferenceSeconds(event.plannedEndAt);
  if (plannedEndReferenceSeconds === null) {
    throw new Error("Update event is missing planned end");
  }

  const now = Math.floor(Date.now() / 1000);
  const response = await fetch(`${host}/3/device/${event.pushToken}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${await providerToken()}`,
      "apns-push-type": "liveactivity",
      "apns-topic": requiredEnvironment("APNS_LIVE_ACTIVITY_TOPIC"),
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      aps: {
        timestamp: now,
        event: "update",
        "content-state": {
          plannedEndAt: plannedEndReferenceSeconds,
          isComplete: false,
          phase: event.phase,
          bedtimeAt: toReferenceSeconds(event.bedtimeAt),
          wakeAt: toReferenceSeconds(event.wakeAt),
          morningQuietEndsAt: toReferenceSeconds(event.morningQuietEndsAt),
          eveningActivityTitle: event.eveningActivityTitle,
          morningActivityTitle: event.morningActivityTitle,
        },
      },
    }),
  });

  let reason = response.statusText || "Unknown";
  try {
    const body = await response.json() as { reason?: string };
    if (body.reason) reason = body.reason;
  } catch {
    // APNs commonly returns an empty body for success.
  }

  if (response.ok) {
    return { status: response.status, reason: "Success", outcome: "delivered" };
  }
  if (response.status === 429 || response.status >= 500) {
    return { status: response.status, reason, outcome: "retry" };
  }
  return { status: response.status, reason, outcome: "terminal" };
}
