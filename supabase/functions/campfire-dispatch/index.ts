import { serviceClient } from "../_shared/supabase.ts";
import { sendCampfireAlert } from "../_shared/apns.ts";
import { campfireAlertPayload } from "../_shared/campfire-alerts.ts";
import { json } from "../_shared/http.ts";

Deno.serve(async request => {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const secret = Deno.env.get("DISPATCH_SECRET");
  if (!secret || request.headers.get("x-dispatch-secret") !== secret) return json({ error: "Unauthorized" }, 401);
  const client = serviceClient();
  const { data, error } = await client.rpc("claim_campfire_alerts");
  if (error) return json({ error: "Could not claim invitations" }, 503);
  let processed = 0;
  await Promise.all((data ?? []).map(async (event: { id: string; lease: string }) => {
    try {
      // Refresh authorization and expiry immediately before handing an alert to APNs.
      const { data: payload, error: payloadError } = await client.rpc("campfire_alert_payload", { p_id: event.id, p_lease: event.lease });
      if (payloadError) return;
      if (payload?.defer) {
        await client.rpc("defer_campfire_alert", { p_id: event.id, p_lease: event.lease });
        return;
      }
      let retry = false;
      await Promise.all((payload?.devices ?? []).map(async (device: { token: string; environment: "sandbox" | "production" }) => {
        try {
        const result = await sendCampfireAlert({ token: device.token, environment: device.environment, id: event.id,
          expiresAt: payload.expiresAt, payload: campfireAlertPayload(payload) });
        retry ||= result.outcome === "retry";
        if (result.outcome !== "retry") {
          const { error: receiptError } = await client.rpc("record_campfire_alert_device", { p_id: event.id, p_lease: event.lease, p_token: device.token });
          if (receiptError) retry = true;
        }
        } catch { retry = true; }
      }));
      const { error: finishError } = await client.rpc("finish_campfire_alert", { p_id: event.id, p_lease: event.lease, p_retry: retry });
      if (!finishError) processed++;
    } catch { /* The lease expires; bounded retries preserve the original event. */ }
  }));
  return json({ processed });
});
