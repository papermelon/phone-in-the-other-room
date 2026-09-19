const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
// A queued write must not follow a refreshed JWT into another account.
// The authenticated identity remains authoritative; this is a match fence.
export function validatesCampfireOwner(expected: string | null, authenticated: string): boolean {
  return expected !== null && uuid.test(expected) && expected.toLowerCase() === authenticated.toLowerCase();
}
export const publicCampfireNames = ["Fern", "Willow", "Clover", "River", "Sage", "Maple", "Robin", "Wren", "Hazel", "Rowan", "Juniper", "Aspen"];
const activities = ["phoneAway", "reading", "studying", "making", "chores", "resting"];
const fields: Record<string, string[]> = {
  state: ["command", "gathering", "cursor"],
  agreement: ["id", "command", "expectedRevision", "consentVersion", "enabled", "publicName", "appearance"],
  publish: ["id", "command", "agreementID", "sourceID", "kind", "activity", "startedAt", "expiresAt", "ended"],
  encourage: ["id", "command", "targetID"],
  block: ["id", "command", "targetID"],
  report: ["id", "command", "targetID", "reason"],
};
const appearanceValues: Record<string, string[]> = {
  skinToneID: ["porcelain", "warm", "olive", "brown", "deep"],
  hairStyleID: ["cropped", "waves", "curls", "coils", "long"],
  shepherdOutfitID: ["none", "shepherd_moss_coat", "shepherd_moon_coat", "shepherd_field_overalls", "shepherd_star_keeper_cloak"],
  shepherdAccessoryID: ["none", "shepherd_wool_hat", "shepherd_clover_headscarf", "shepherd_moon_beanie"],
};

export function validateGlobalCampfire(input: Record<string, unknown>): Record<string, unknown> {
  const c = { ...input };
  const command = c.command;
  if (typeof command !== "string" || !fields[command] || Object.keys(c).some(k => !fields[command].includes(k))) throw new Error("Invalid Campfire fields");
  if (command === "state") {
    if (!["all", "windDown", ...activities].includes(String(c.gathering ?? "all"))) throw new Error("Invalid gathering");
    if (c.cursor != null && !uuid.test(String(c.cursor))) throw new Error("Invalid cursor");
    return c;
  }
  if (typeof c.id !== "string" || !/^[0-9a-f-]{36,64}$/i.test(c.id)) throw new Error("Invalid command ID");
  if (command === "agreement") {
    if (c.consentVersion !== 1 || typeof c.enabled !== "boolean" || !Number.isSafeInteger(c.expectedRevision) || Number(c.expectedRevision) < 0) throw new Error("Invalid agreement");
    if (c.enabled) {
      if (!publicCampfireNames.includes(String(c.publicName))) throw new Error("Choose a public name");
      const appearance = c.appearance as Record<string, unknown>;
      if (!appearance || Array.isArray(appearance) || Object.keys(appearance).length !== 4 ||
          Object.entries(appearanceValues).some(([k, values]) => !values.includes(String(appearance[k])))) throw new Error("Invalid public appearance");
    } else if (c.publicName !== undefined || c.appearance !== undefined) throw new Error("Withdrawal cannot update profile");
  } else if (command === "publish") {
    for (const key of ["agreementID", "sourceID"]) if (!uuid.test(String(c[key]))) throw new Error("Invalid session identity");
    if (!["windDown", "phoneAway"].includes(String(c.kind)) || typeof c.ended !== "boolean") throw new Error("Invalid session");
    if (c.kind === "windDown" ? c.activity != null : !activities.includes(String(c.activity))) throw new Error("Invalid activity");
    for (const key of ["startedAt", "expiresAt"]) {
      // Existing Swift FunctionInvokeOptions uses Foundation's 2001 epoch.
      const value = c[key];
      const date = typeof value === "number" ? new Date(Date.UTC(2001, 0, 1) + value * 1000) : new Date(String(value));
      if (!Number.isFinite(date.getTime())) throw new Error("Invalid session time");
      c[key] = date.toISOString();
    }
    const duration = Date.parse(String(c.expiresAt)) - Date.parse(String(c.startedAt));
    if (duration <= 0 || duration > 86400000) throw new Error("Invalid session duration");
  } else {
    if (!uuid.test(String(c.targetID))) throw new Error("Invalid target");
    if (command === "report" && c.reason !== "profile") throw new Error("Invalid report reason");
  }
  return c;
}
