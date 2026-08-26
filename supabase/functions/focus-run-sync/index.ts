import {
  errorResponse,
  json,
  parseJsonObject,
  requireString,
} from "../_shared/http.ts";
import { authenticatedClient } from "../_shared/supabase.ts";

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const body = await parseJsonObject(request);
    if (body.schemaVersion !== 1) throw new Error("Unsupported schemaVersion");
    const status = requireString(body, "status");
    if (!["active", "completed", "ended_early", "cancelled"].includes(status)) {
      throw new Error("Invalid status");
    }
    const idempotencyKey = requireString(body, "idempotencyKey");
    if (request.headers.get("idempotency-key") !== idempotencyKey) {
      throw new Error("Idempotency key mismatch");
    }

    const client = await authenticatedClient(request);
    const { error } = await client.rpc("sync_focus_run", {
      p_run_id: requireString(body, "runID"),
      p_installation_id: requireString(body, "installationID"),
      p_planned_end_at: requireString(body, "plannedEndAt"),
      p_observed_at: requireString(body, "observedAt"),
      p_status: status,
      p_run_revision: requirePositiveInteger(body, "runRevision"),
      p_app_version: typeof body.appVersion === "string" ? body.appVersion : null,
      p_idempotency_key: idempotencyKey,
    });
    if (error) throw error;
    return json({ accepted: true });
  } catch (error) {
    return errorResponse(error);
  }
});

function requirePositiveInteger(body: Record<string, unknown>, key: string): number {
  const value = body[key];
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 1) {
    throw new Error(`Invalid ${key}`);
  }
  return value;
}
