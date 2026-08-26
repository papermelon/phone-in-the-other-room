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
    const reason = requireString(body, "reason");
    if (!["completed", "endedEarly", "reset", "replaced"].includes(reason)) {
      throw new Error("Invalid reason");
    }
    const client = await authenticatedClient(request);
    const idempotencyKey = requireString(body, "idempotencyKey");
    if (request.headers.get("idempotency-key") !== idempotencyKey) {
      throw new Error("Idempotency key mismatch");
    }
    const { error } = await client.rpc("cancel_live_activity", {
      p_run_id: requireString(body, "runID"),
      p_activity_id: requireString(body, "activityID"),
      p_reason: reason,
      p_occurred_at: requireString(body, "occurredAt"),
      p_run_revision: requirePositiveInteger(body, "runRevision"),
      p_idempotency_key: idempotencyKey,
    });
    if (error) throw error;
    return json({ cancelled: true });
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
