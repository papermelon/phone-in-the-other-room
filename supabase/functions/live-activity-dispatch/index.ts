import {
  sendLiveActivityEnd,
  sendLiveActivityUpdate,
} from "../_shared/apns.ts";
import { errorResponse, json } from "../_shared/http.ts";
import { serviceClient } from "../_shared/supabase.ts";

interface ClaimedEvent {
  event_id: string;
  lease_id: string;
  push_token: string;
  environment: "sandbox" | "production";
  planned_end_at: string;
  attempt_count: number;
}

interface EventPayload {
  event_kind: "bedtime" | "wake" | "end";
  planned_end_at: string;
  bedtime_at: string | null;
  wake_at: string | null;
  morning_quiet_ends_at: string | null;
  evening_activity_title: string | null;
  morning_activity_title: string | null;
}

function retryDate(attempt: number): string {
  const base = Math.min(15 * 60, 15 * 2 ** Math.max(0, attempt - 1));
  const jitter = Math.floor(Math.random() * Math.max(1, base * 0.25));
  return new Date(Date.now() + (base + jitter) * 1000).toISOString();
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }
  try {
    const expected = Deno.env.get("DISPATCH_SECRET");
    const customSecret = request.headers.get("x-dispatch-secret");
    const bearerSecret = request.headers.get("authorization");
    if (
      !expected ||
      (customSecret !== expected && bearerSecret !== `Bearer ${expected}`)
    ) {
      return json({ error: "Unauthorized" }, 401);
    }
    const client = serviceClient();
    const workerID = crypto.randomUUID();
    const { data, error } = await client.rpc("claim_due_live_activity_events", {
      p_worker_id: workerID,
      p_limit: 50,
    });
    if (error) throw error;
    const events = (data ?? []) as ClaimedEvent[];

    const results = [];
    for (const event of events) {
      const { data: leaseIsCurrent, error: leaseError } = await client.rpc(
        "validate_live_activity_lease",
        { p_event_id: event.event_id, p_lease_id: event.lease_id },
      );
      if (leaseError) throw leaseError;
      if (!leaseIsCurrent) continue;
      const { data: payload, error: payloadError } = await client.rpc(
        "live_activity_event_payload",
        { p_event_id: event.event_id, p_lease_id: event.lease_id },
      );
      if (payloadError) throw payloadError;
      const eventPayload = (Array.isArray(payload) ? payload[0] : payload) as
        | EventPayload
        | null;
      if (!eventPayload) continue;

      const result = eventPayload.event_kind === "end"
        ? await sendLiveActivityEnd({
          pushToken: event.push_token,
          environment: event.environment,
          plannedEndAt: eventPayload.planned_end_at,
        })
        : await sendLiveActivityUpdate({
          pushToken: event.push_token,
          environment: event.environment,
          plannedEndAt: eventPayload.planned_end_at,
          phase: eventPayload.event_kind === "bedtime" ? "overnight" : "morningQuiet",
          bedtimeAt: eventPayload.bedtime_at,
          wakeAt: eventPayload.wake_at,
          morningQuietEndsAt: eventPayload.morning_quiet_ends_at,
          eveningActivityTitle: eventPayload.evening_activity_title,
          morningActivityTitle: eventPayload.morning_activity_title,
        });
      const cappedOutcome =
        result.outcome === "retry" && event.attempt_count >= 6
          ? "terminal"
          : result.outcome;
      const { error: recordError } = await client.rpc(
        "record_live_activity_delivery",
        {
          p_event_id: event.event_id,
          p_lease_id: event.lease_id,
          p_outcome: cappedOutcome,
          p_apns_status: result.status,
          p_apns_reason: result.reason,
          p_retry_at: cappedOutcome === "retry"
            ? retryDate(event.attempt_count)
            : null,
        },
      );
      if (recordError) throw recordError;
      results.push({
        eventID: event.event_id,
        status: result.status,
        outcome: cappedOutcome,
      });
    }
    return json({ claimed: events.length, results });
  } catch (error) {
    return errorResponse(error);
  }
});
