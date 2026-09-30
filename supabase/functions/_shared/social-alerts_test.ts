import { socialAlertPayload } from "./social-alerts.ts";

Deno.test("social alerts have account-bound opaque routes and no urgent interruption", () => {
  const payload = socialAlertPayload({ eventID: "support:example", ownerID: "owner", title: "Counting Sheep", body: "You received encouragement." });
  if (payload.socialEventID !== "support:example" || payload.socialOwnerID !== "owner") throw new Error("Lost route binding");
  if (payload.aps["interruption-level"] !== "passive" || "sound" in payload.aps || "badge" in payload.aps) throw new Error("Intrusive social alert");
});
