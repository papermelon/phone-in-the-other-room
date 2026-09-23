const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
// A queued write must not follow a refreshed JWT into another account.
// The authenticated identity remains authoritative; this is a match fence.
export function validatesCampfireOwner(expected: string | null, authenticated: string): boolean {
  return expected !== null && uuid.test(expected) && expected.toLowerCase() === authenticated.toLowerCase();
}
export const publicCampfireNames = ["Fern", "Willow", "Clover", "River", "Sage", "Maple", "Robin", "Wren", "Hazel", "Rowan", "Juniper", "Aspen"];
const activities = ["phoneAway", "reading", "studying", "making", "chores", "resting"];
const fields: Record<string, string[]> = {
  state: ["command", "gathering", "cursor", "channelID"],
  channel: ["id", "command", "agreementID", "sourceID", "channelID"],
  detail: ["command", "participantID", "memberID"],
  profile: ["id", "command", "agreementID", "sourceID", "profile", "capturedAt"],
  agreement: ["id", "command", "expectedRevision", "consentVersion", "enabled", "publicName", "appearance"],
  publish: ["id", "command", "agreementID", "sourceID", "kind", "activity", "startedAt", "expiresAt", "ended", "channelID"],
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
const wardrobeValues: Record<string, string[]> = {
  shepherdShirtID: ["none", "shepherd_berry_shirt", "shepherd_dusk_shirt", "shepherd_amber_shirt"],
  shepherdOuterwearID: ["none", "shepherd_open_moss_coat"],
  ollieCoatID: ["classic", "fuller"],
};
function validWardrobe(a: Record<string, unknown>): boolean {
  const present = Object.keys(wardrobeValues).filter(key => a[key] !== undefined);
  return (present.length === 0 || present.length === Object.keys(wardrobeValues).length) &&
    Object.entries(wardrobeValues).every(([key, values]) => a[key] === undefined || values.includes(String(a[key])));
}

export function validateGlobalCampfire(input: Record<string, unknown>): Record<string, unknown> {
  const c = { ...input };
  const command = c.command;
  if (typeof command !== "string" || !fields[command] || Object.keys(c).some(k => !fields[command].includes(k))) throw new Error("Invalid Campfire fields");
  if (c.channelID != null && (!Number.isSafeInteger(c.channelID) || Number(c.channelID) < 0 || Number(c.channelID) > 1000000)) throw new Error("Invalid channel");
  if (command === "detail") {
    if ((c.participantID == null) === (c.memberID == null) || !uuid.test(String(c.participantID ?? c.memberID))) throw new Error("Invalid profile target");
    return c;
  }
  if (command === "state") {
    if (!["all", "windDown", ...activities].includes(String(c.gathering ?? "all"))) throw new Error("Invalid gathering");
    if (c.cursor != null && !uuid.test(String(c.cursor))) throw new Error("Invalid cursor");
    return c;
  }
  if (typeof c.id !== "string" || !/^[0-9a-f-]{36,64}$/i.test(c.id)) throw new Error("Invalid command ID");
  if (command === "channel") {
    if (!uuid.test(String(c.agreementID)) || !uuid.test(String(c.sourceID)) || !Number.isSafeInteger(c.channelID) || Number(c.channelID) < 1) throw new Error("Invalid channel change");
  } else if (command === "profile") {
    if (!uuid.test(String(c.agreementID)) || !uuid.test(String(c.sourceID)) || typeof c.capturedAt !== "string" || !Number.isFinite(Date.parse(c.capturedAt))) throw new Error("Invalid profile receipt");
    validateCampfireProfile(c.profile);
  } else if (command === "agreement") {
    if (![1, 2].includes(c.consentVersion as number) || typeof c.enabled !== "boolean" || !Number.isSafeInteger(c.expectedRevision) || Number(c.expectedRevision) < 0) throw new Error("Invalid agreement");
    if (c.enabled) {
      if (c.consentVersion === 1 ? !publicCampfireNames.includes(String(c.publicName)) : typeof c.publicName !== "string" || !/^[\p{L}\p{M}\p{N} '’‐‑-]{2,24}$/u.test(c.publicName)) throw new Error("Choose a public name");
      const appearance = c.appearance as Record<string, unknown>;
      if (!appearance || Array.isArray(appearance) || Object.keys(appearance).some(k => ![...Object.keys(appearanceValues), ...Object.keys(wardrobeValues), "headShapeID"].includes(k)) || !validWardrobe(appearance) || (appearance.headShapeID != null && !["pear", "round", "boxy", "triangular"].includes(String(appearance.headShapeID))) ||
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

function object(value: unknown, keys: string[]): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value) || Object.keys(value).some(k => !keys.includes(k))) throw new Error("Invalid profile fields");
  return value as Record<string, unknown>;
}
function strings(value: unknown, limit = 5000): void {
  if (!Array.isArray(value) || value.length > limit || value.some(v => typeof v !== "string" || v.length > 2048)) throw new Error("Invalid profile list");
}
export function validateCampfireProfile(value: unknown): void {
  const p = object(value, ["session", "tasks", "routines", "intention", "history", "partyNames", "inventory", "sheep", "appearance", "decorations", "collectibles", "ollieAccessory", "barnCapacityLevel"]);
  if (JSON.stringify(p).length > 1000000) throw new Error("Profile too large");
  for (const key of ["session", "tasks", "routines", "history", "partyNames", "inventory"]) strings(p[key]);
  if (typeof p.intention !== "string" || p.intention.length > 2048 || typeof p.ollieAccessory !== "string" || p.ollieAccessory.length > 100 || !Number.isSafeInteger(p.barnCapacityLevel) || Number(p.barnCapacityLevel) < 0 || Number(p.barnCapacityLevel) > 100) throw new Error("Invalid profile");
  const a = object(p.appearance, [...Object.keys(appearanceValues), ...Object.keys(wardrobeValues), "headShapeID"]);
  if (!validWardrobe(a) || Object.entries(appearanceValues).some(([k, values]) => !values.includes(String(a[k]))) || (a.headShapeID != null && !["pear", "round", "boxy", "triangular"].includes(String(a.headShapeID)))) throw new Error("Invalid appearance");
  for (const [key, keys] of [["decorations", ["leftMeadow", "rightMeadow", "centerHorizon", "leftFence", "waterEdge", "barnCorner"]], ["collectibles", ["left", "centerLeft", "centerRight", "right"]]] as const) {
    const items = object(p[key], [...keys]);
    if (Object.values(items).some(v => typeof v !== "string" || !/^[a-z0-9_]{1,100}$/.test(v))) throw new Error("Invalid Farm item");
  }
  if (!Array.isArray(p.sheep) || p.sheep.length > 5000) throw new Error("Invalid sheep");
  for (const sheep of p.sheep) {
    const s = object(sheep, ["id", "definitionID", "name", "status", "cosmetics"]);
    if (!uuid.test(String(s.id)) || typeof s.definitionID !== "string" || !/^[a-z0-9_]{1,100}$/.test(s.definitionID) || typeof s.name !== "string" || s.name.length > 100 || !["active", "pending", "sold"].includes(String(s.status))) throw new Error("Invalid sheep");
    strings(s.cosmetics, 20);
  }
}
