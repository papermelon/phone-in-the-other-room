import {
  errorResponse,
  json,
  parseJsonObject,
  requireString,
} from "../_shared/http.ts";
import { authenticatedClient } from "../_shared/supabase.ts";

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }
  try {
    const body = await parseJsonObject(request);
    if (body.schemaVersion !== 2) throw new Error("Unsupported schemaVersion");
    const environment = requireString(body, "environment");
    if (environment !== "sandbox" && environment !== "production") {
      throw new Error("Invalid environment");
    }
    const client = await authenticatedClient(request);
    const idempotencyKey = requireString(body, "idempotencyKey");
    if (request.headers.get("idempotency-key") !== idempotencyKey) {
      throw new Error("Idempotency key mismatch");
    }
    const { data, error } = await client.rpc("register_live_activity_v2", {
      p_run_id: requireString(body, "runID"),
      p_installation_id: requireString(body, "installationID"),
      p_activity_id: requireString(body, "activityID"),
      p_push_token: requireString(body, "pushToken"),
      p_planned_end_at: requireString(body, "plannedEndAt"),
      p_observed_at: requireString(body, "observedAt"),
      p_environment: environment,
      p_run_revision: requirePositiveInteger(body, "runRevision"),
      p_client_token_generation: requirePositiveInteger(
        body,
        "tokenGeneration",
      ),
      p_idempotency_key: idempotencyKey,
      p_phase: typeof body.phase === "string" ? body.phase : null,
      p_bedtime_at: typeof body.bedtimeAt === "string" ? body.bedtimeAt : null,
      p_wake_at: typeof body.wakeAt === "string" ? body.wakeAt : null,
      p_morning_quiet_ends_at: typeof body.morningQuietEndsAt === "string"
        ? body.morningQuietEndsAt
        : null,
      p_evening_activity_title: typeof body.eveningActivityTitle === "string"
        ? body.eveningActivityTitle
        : null,
      p_morning_activity_title: typeof body.morningActivityTitle === "string"
        ? body.morningActivityTitle
        : null,
    });
    if (error) throw error;
    return json({ accepted: true, ...(Array.isArray(data) ? data[0] : data) });
  } catch (error) {
    return errorResponse(error);
  }
});

function requirePositiveInteger(
  body: Record<string, unknown>,
  key: string,
): number {
  const value = body[key];
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 1) {
    throw new Error(`Invalid ${key}`);
  }
  return value;
}
