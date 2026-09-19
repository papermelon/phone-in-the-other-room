export function validateCampfireDevice(body: Record<string, unknown>, callerID: string): void {
  const fields = body.unregister === true ? ["ownerID", "installationID", "unregister", "revision"]
    : ["ownerID", "installationID", "token", "environment", "enabled", "quietUntil", "timeZone", "quietStart", "quietEnd", "revision"];
  if (Object.keys(body).some(key => !fields.includes(key))) throw new Error("Unexpected device field");
  if (String(body.ownerID).toLowerCase() !== callerID.toLowerCase()) throw new Error("Unauthorized");
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(String(body.installationID))) throw new Error("Invalid installation");
  if (!Number.isSafeInteger(body.revision) || Number(body.revision) < 1) throw new Error("Invalid device revision");
  if (body.unregister === true) return;
  if (typeof body.token !== "string" || !/^[0-9a-f]{32,512}$/.test(body.token)
    || !["sandbox", "production"].includes(String(body.environment)) || typeof body.enabled !== "boolean"
    || typeof body.quietUntil !== "string" || !Number.isFinite(Date.parse(body.quietUntil))
    || typeof body.timeZone !== "string" || body.timeZone.length > 100
    || ![body.quietStart, body.quietEnd].every(value => Number.isInteger(value) && Number(value) >= 0 && Number(value) <= 23)) throw new Error("Invalid device preferences");
}

export function campfireAlertPayload(event: { partyID: string; sourceID: string; title: string; body: string }) {
  return { aps: { alert: { title: event.title, body: event.body }, "thread-id": `campfire-${event.partyID}`, "interruption-level": "active" },
    campfirePartyID: event.partyID, campfireSourceID: event.sourceID };
}
