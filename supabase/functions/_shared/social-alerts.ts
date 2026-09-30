import { serviceClient } from "./supabase.ts";
import { sendCampfireAlert } from "./apns.ts";

export function socialAlertPayload(event: { eventID: string; ownerID: string; title: string; body: string }) {
  return {
    aps: { alert: { title: event.title, body: event.body }, "thread-id": "counting-sheep-inbox", "interruption-level": "passive" },
    socialEventID: event.eventID, socialOwnerID: event.ownerID,
  };
}

export async function dispatchSocialAlerts(): Promise<number> {
  const client = serviceClient();
  const { data, error } = await client.rpc("claim_social_alerts");
  if (error) throw new Error("Could not claim social alerts");
  let processed = 0;
  await Promise.all((data ?? []).map(async (event: { id: string; lease: string }) => {
    const settle = async (action: string, token: string | null = null, accepted = false) => {
      const { data, error } = await client.rpc("settle_social_alert", {
        p_id: event.id, p_lease: event.lease, p_action: action, p_token: token, p_accepted: accepted,
      });
      return !error && data === true;
    };
    try {
      const { data: payload, error } = await client.rpc("social_alert_payload", { p_id: event.id, p_lease: event.lease });
      if (error) return;
      if (!payload) { await settle("terminal"); return; }
      if (payload.defer) { await settle("defer"); return; }
      let retry = false;
      for (const device of payload.devices ?? []) {
        // Recheck account ownership, quiet state, blocks and withdrawn sources
        // immediately before each device send, including a multi-device batch.
        const { data: current, error: refreshError } = await client.rpc("social_alert_payload", { p_id: event.id, p_lease: event.lease });
        if (refreshError) { retry = true; break; }
        if (!current) { await settle("terminal"); return; }
        if (current.defer) { await settle("defer"); return; }
        if (!current.devices?.some((d: { token: string }) => d.token === device.token)) continue;
        try {
          const result = await sendCampfireAlert({ token: device.token, environment: device.environment, id: event.id,
            expiresAt: current.expiresAt, payload: socialAlertPayload(current) });
          if (result.outcome === "retry") retry = true;
          else if (!await settle("device", device.token, result.outcome === "delivered")) retry = true;
        } catch { retry = true; }
      }
      if (await settle(retry ? "retry" : "finish")) processed++;
    } catch { /* The bounded lease preserves retry identity after transport failure. */ }
  }));
  return processed;
}
