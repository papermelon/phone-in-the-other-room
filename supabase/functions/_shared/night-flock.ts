import { normalizeSharedHabitsLocalDate } from "./night-flock-shared-habits-wire.ts";

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const idempotencyPattern = /^[0-9a-f]{64}$/;

const commandFields: Record<string, string[]> = {
  createFlock: ["schemaVersion", "command", "identity", "timeZoneIdentifier", "idempotencyKey"],
  createInvite: ["schemaVersion", "command", "idempotencyKey"],
  revokeInvite: ["schemaVersion", "command", "inviteID", "idempotencyKey"],
  join: ["schemaVersion", "command", "shortCode", "idempotencyKey"],
  leave: ["schemaVersion", "command", "idempotencyKey"],
  setSharing: ["schemaVersion", "command", "enabled", "idempotencyKey"],
  block: ["schemaVersion", "command", "memberID", "idempotencyKey"],
  report: ["schemaVersion", "command", "memberID", "reason", "idempotencyKey"],
  publishCheckIn: ["schemaVersion", "command", "challengeID", "day", "state", "idempotencyKey"],
  react: ["schemaVersion", "command", "checkInID", "reaction", "idempotencyKey"],
  deleteNightFlockData: ["schemaVersion", "command", "idempotencyKey"],
  deleteAccount: ["schemaVersion", "command", "idempotencyKey"],
};

const commitmentCommandFields: Record<string, string[]> = {
  createParty: [
    "schemaVersion", "command", "goalKind", "targetMinutes", "appDisplayName",
    "identity", "timeZoneIdentifier", "idempotencyKey",
  ],
  createInvite: ["schemaVersion", "command", "idempotencyKey"],
  replaceInvite: ["schemaVersion", "command", "expectedInviteID", "inviteID", "inviteDigest", "idempotencyKey"],
  previewInvite: ["schemaVersion", "command", "shortCode", "idempotencyKey"],
  redeemInvite: ["schemaVersion", "command", "shortCode", "idempotencyKey"],
  acceptGoal: ["schemaVersion", "command", "challengeID", "idempotencyKey"],
  setLocalSetup: ["schemaVersion", "command", "challengeID", "setupReady", "shieldingEvidence", "idempotencyKey"],
  setSharingPreferences: ["schemaVersion", "command", "shareGoalProgress", "shareRoutineIdeas", "idempotencyKey"],
  setRoutineIdeas: ["schemaVersion", "command", "challengeID", "guidanceIDs", "idempotencyKey"],
  startChallenge: ["schemaVersion", "command", "challengeID", "idempotencyKey"],
  publishProgress: ["schemaVersion", "command", "challengeID", "day", "status", "shieldingEvidence", "idempotencyKey"],
};

export type NightFlockCommandPayload = Record<string, unknown> & {
  schemaVersion: 1 | 2 | 3 | 4;
  command: string;
  idempotencyKey: string;
};

const v4CommandFields: Record<string, string[]> = {
  createParty: ["schemaVersion", "command", "name", "timeZoneIdentifier", "idempotencyKey"],
  renameParty: ["schemaVersion", "command", "partyID", "name", "idempotencyKey"],
  startRound: ["schemaVersion", "command", "partyID", "timeZoneIdentifier", "idempotencyKey"],
  createInvite: ["schemaVersion", "command", "partyID", "idempotencyKey"],
  replaceInvite: ["schemaVersion", "command", "partyID", "expectedInviteID", "idempotencyKey"],
  revokeInvite: ["schemaVersion", "command", "partyID", "inviteID", "idempotencyKey"],
  retrieveInvite: ["schemaVersion", "command", "partyID", "idempotencyKey"],
  previewInvite: ["schemaVersion", "command", "inviteCode", "idempotencyKey"],
  redeemInvite: ["schemaVersion", "command", "inviteCode", "idempotencyKey"],
  leaveParty: ["schemaVersion", "command", "partyID", "idempotencyKey"],
  deleteParty: ["schemaVersion", "command", "partyID", "idempotencyKey"],
  blockMember: ["schemaVersion", "command", "partyID", "memberID", "idempotencyKey"],
  reportMember: ["schemaVersion", "command", "partyID", "memberID", "reason", "idempotencyKey"],
  deleteAccount: ["schemaVersion", "command", "idempotencyKey"],
  updatePublicProfile: [
    "schemaVersion", "command", "expectedRevision", "displayName", "nameSelectionKind", "skinToneID", "hairStyleID", "shepherdOutfitID", "shepherdAccessoryID", "ollieOrnamentID", "featuredSheepDefinitionID", "pastureThemeID", "idempotencyKey",
  ],
  publishActivity: [
    "schemaVersion", "command", "sourceEventID", "kind", "outcome", "startedAt", "endedAt", "windDownMinutes", "phoneAwayMinutes", "statusRevision", "sharingScope", "idempotencyKey",
  ],
  completeBackfill: ["schemaVersion", "command", "partyID", "roundID", "cursor", "idempotencyKey"],
  publishStatus: ["schemaVersion", "command", "sourceEventID", "status", "revision", "observedAt", "sharingScope", "idempotencyKey"],
  react: ["schemaVersion", "command", "partyID", "activityID", "cheer", "sharingScope", "idempotencyKey"],
  cheerMember: ["schemaVersion", "command", "partyID", "memberID", "cheer", "statusID", "idempotencyKey"],
  acknowledgeGrant: ["schemaVersion", "command", "grantID", "idempotencyKey"],
  acceptSharedHabitsAgreement: ["schemaVersion", "command", "partyID", "agreementVersion", "timeZoneIdentifier", "idempotencyKey"],
  publishSharedHabit: ["schemaVersion", "command", "partyID", "agreementID", "memberEpochID", "sourceID", "revision", "kind", "localDate", "timeZoneIdentifier", "minutes", "outcome", "protectionMinutes", "evidence", "idempotencyKey"],
  deleteSharedHabitHistory: ["schemaVersion", "command", "partyID", "sourceID", "allSources", "idempotencyKey"],
  migrateSharedHabits: ["schemaVersion", "command", "partyID", "agreementID", "idempotencyKey"],
  publishSharedNightPlan: ["schemaVersion", "command", "partyID", "planID", "memberEpochID", "agreementID", "revision", "nightEndingDate", "timeZoneIdentifier", "plannedWindDownStart", "intendedBedtime", "intendedWakeTime", "morningQuietEnd", "beforeBedMinutes", "afterWakingMinutes", "eveningSuggestionIDs", "morningSuggestionIDs", "idempotencyKey"],
  cancelSharedNightPlan: ["schemaVersion", "command", "partyID", "memberEpochID", "agreementID", "revision", "nightEndingDate", "timeZoneIdentifier", "cancellationAuthority", "idempotencyKey"],
  publishSharedNightReceipt: ["schemaVersion", "command", "partyID", "receiptID", "memberEpochID", "agreementID", "planID", "planRevision", "sourceID", "revision", "nightEndingDate", "timeZoneIdentifier", "actualStart", "terminalAt", "outcome", "windDownMinutes", "protectionMinutes", "protectionEvidence", "emergencyExitUsed", "idempotencyKey"],
};

const socialCommandFields: Record<string, string[]> = {
  setSharingPreferences: [
    "schemaVersion", "command", "shareGoalProgress", "shareWindDownCompletion",
    "shareWindDownMinutes", "sharePhoneAwayMinutes", "sharePhoneTuckedAway",
    "shareShieldingStatus", "shareRoutineIdeas", "shareSleepDuration",
    "shareRestfulness", "idempotencyKey",
  ],
  publishNightMetrics: [
    "schemaVersion", "command", "challengeID", "day", "status", "shieldingEvidence",
    "windDownMinutes", "phoneAwayMinutes", "sleepDurationMinutes", "restfulness",
    "idempotencyKey",
  ],
  acknowledgeGrant: ["schemaVersion", "command", "grantID", "idempotencyKey"],
};

export function validateNightFlockCommand(
  body: Record<string, unknown>,
  headerIdempotencyKey: string | null,
): NightFlockCommandPayload {
  if (body.schemaVersion !== 1 && body.schemaVersion !== 2 && body.schemaVersion !== 3 && body.schemaVersion !== 4) {
    throw new Error("Unsupported schemaVersion");
  }
  const command = requireString(body, "command");
  const allowedFields = body.schemaVersion === 4
    ? v4CommandFields[command]
    : body.schemaVersion === 3
    ? socialCommandFields[command]
    : body.schemaVersion === 2
    ? commitmentCommandFields[command]
    : commandFields[command];
  if (!allowedFields) throw new Error("Unsupported Slumber Party command");
  const exactFields = body.schemaVersion === 2 && command === "createInvite" &&
      (body.inviteID !== undefined || body.inviteDigest !== undefined)
    ? [...allowedFields, "inviteID", "inviteDigest"]
    : body.schemaVersion === 4 && command === "updatePublicProfile" && body.avatarID !== undefined
    ? [...allowedFields, "avatarID"]
    : allowedFields;
  requireExactFields(body, exactFields);
  const idempotencyKey = requireString(body, "idempotencyKey").toLowerCase();
  if (!idempotencyPattern.test(idempotencyKey)) throw new Error("Invalid idempotencyKey");
  if (headerIdempotencyKey?.toLowerCase() !== idempotencyKey) {
    throw new Error("Idempotency key mismatch");
  }

  if (body.schemaVersion === 4) {
    validateV4Command(body, command);
  } else if (body.schemaVersion === 3) {
    validateSocialCommand(body, command);
  } else if (body.schemaVersion === 2) {
    validateCommitmentCommand(body, command);
  } else switch (command) {
    case "createFlock":
      requireEnum(body, "identity", ["moonlitMeadow", "orchardGate", "starlightHill"]);
      if (!/^[A-Za-z0-9_+\-/]{1,64}$/.test(requireString(body, "timeZoneIdentifier"))) {
        throw new Error("Invalid timeZoneIdentifier");
      }
      break;
    case "join":
      if (!/^[A-HJ-NP-Z2-9]{12}$/.test(requireString(body, "shortCode").toUpperCase())) {
        throw new Error("Invalid shortCode");
      }
      body.shortCode = requireString(body, "shortCode").toUpperCase();
      break;
    case "setSharing":
      if (typeof body.enabled !== "boolean") throw new Error("Invalid enabled");
      break;
    case "block":
      requireUUID(body, "memberID");
      break;
    case "revokeInvite":
      requireUUID(body, "inviteID");
      break;
    case "report":
      requireUUID(body, "memberID");
      requireEnum(body, "reason", [
        "unwantedContact", "harmfulConduct", "impersonation", "otherSafetyConcern",
      ]);
      break;
    case "publishCheckIn": {
      requireUUID(body, "challengeID");
      const day = body.day;
      if (typeof day !== "number" || !Number.isSafeInteger(day) || day < 1 || day > 7) {
        throw new Error("Invalid day");
      }
      requireEnum(body, "state", ["phoneTucked", "morningQuietCompleted"]);
      break;
    }
    case "react":
      requireUUID(body, "checkInID");
      requireEnum(body, "reaction", ["warmWave", "moonGlow", "pawPrint"]);
      break;
  }

  return { ...body, schemaVersion: body.schemaVersion, command, idempotencyKey } as NightFlockCommandPayload;
}

export type NightFlockStateContract = { schemaVersion: 1 | 2 | 3 } | {
  schemaVersion: 4; scope: "list" | "party" | "habits" | "sharedNights"; partyID?: string; cursor?: string;
};

export function validateNightFlockState(body: Record<string, unknown>): NightFlockStateContract {
  if (body.schemaVersion === 4) {
    requireExactFields(body, ["schemaVersion", "scope", "partyID", "cursor"]);
    const scope = requireEnum(body, "scope", ["list", "party", "habits", "sharedNights"]) as "list" | "party" | "habits" | "sharedNights";
    if (scope === "party" || scope === "habits" || scope === "sharedNights") requireUUID(body, "partyID");
    if (scope === "list" && body.partyID !== undefined) throw new Error("Invalid partyID");
    if (body.cursor !== undefined && (typeof body.cursor !== "string" || body.cursor.length < 1 || body.cursor.length > 128)) {
      throw new Error("Invalid cursor");
    }
    return { schemaVersion: 4, scope, partyID: body.partyID as string | undefined, cursor: body.cursor as string | undefined };
  }
  requireExactFields(body, ["schemaVersion"]);
  if (body.schemaVersion !== 1 && body.schemaVersion !== 2 && body.schemaVersion !== 3) {
    throw new Error("Unsupported schemaVersion");
  }
  return { schemaVersion: body.schemaVersion };
}

function validateV4Command(body: Record<string, unknown>, command: string): void {
  const partyCommands = new Set([
    "renameParty", "startRound", "createInvite", "replaceInvite", "revokeInvite", "retrieveInvite",
    "leaveParty", "deleteParty", "completeBackfill", "react", "blockMember", "reportMember", "cheerMember",
    "acceptSharedHabitsAgreement", "publishSharedHabit", "deleteSharedHabitHistory", "migrateSharedHabits", "publishSharedNightPlan", "cancelSharedNightPlan", "publishSharedNightReceipt",
  ]);
  if (partyCommands.has(command)) requireUUID(body, "partyID");
  switch (command) {
    case "createParty":
    case "renameParty":
      requireBoundedText(body, "name", 1, 48);
      if (command === "createParty" && !isTimeZoneIdentifier(requireString(body, "timeZoneIdentifier"))) throw new Error("Invalid timeZoneIdentifier");
      break;
    case "startRound": if (!isTimeZoneIdentifier(requireString(body, "timeZoneIdentifier"))) throw new Error("Invalid timeZoneIdentifier"); break;
    case "replaceInvite": requireUUID(body, "expectedInviteID"); break;
    case "revokeInvite": requireUUID(body, "inviteID"); break;
    case "previewInvite":
    case "redeemInvite":
      if (!/^[A-HJ-NP-Z2-9]{12}$/.test(requireString(body, "inviteCode").toUpperCase())) throw new Error("Invalid inviteCode");
      body.inviteCode = requireString(body, "inviteCode").toUpperCase();
      if ((body.sharedHabitsAgreementVersion === undefined) !== (body.sharedHabitsAgreementID === undefined) || (body.sharedHabitsAgreementVersion === undefined) !== (body.sharedHabitsTimeZoneIdentifier === undefined)) throw new Error("Invalid shared habits agreement");
      if (body.sharedHabitsAgreementVersion !== undefined) { if (body.sharedHabitsAgreementVersion !== 1) throw new Error("Unsupported shared habits agreement"); requireUUID(body, "sharedHabitsAgreementID"); if (!isTimeZoneIdentifier(requireString(body, "sharedHabitsTimeZoneIdentifier"))) throw new Error("Invalid shared habits agreement"); }
      break;
    case "updatePublicProfile":
      if (typeof body.expectedRevision !== "number" || !Number.isSafeInteger(body.expectedRevision) || body.expectedRevision < 0) throw new Error("Invalid expectedRevision");
      validateDisplayName(body);
      requireEnum(body, "nameSelectionKind", ["initial", "migration", "change"]);
      validateFlatPresentation(body);
      if (body.avatarID !== undefined) validateAvatarID(body);
      break;
    case "publishActivity":
      requireUUID(body, "sourceEventID");
      requireEnum(body, "kind", ["windDown", "phoneAway"]);
      requireEnum(body,"outcome",["completed","partlyCompleted"]); for(const field of ["startedAt","endedAt"]){if(typeof body[field]!=="string"||Number.isNaN(Date.parse(body[field])))throw new Error(`Invalid ${field}`);} if(Date.parse(body.endedAt as string)<Date.parse(body.startedAt as string))throw new Error("Invalid activity interval"); for(const field of ["windDownMinutes","phoneAwayMinutes","statusRevision"]){if(typeof body[field]!=="number"||!Number.isSafeInteger(body[field])||(body[field] as number)<0)throw new Error(`Invalid ${field}`);} if((body.windDownMinutes as number)>180||(body.phoneAwayMinutes as number)>240)throw new Error("Values outside bounds");
      validateMembershipSharingScope(body);
      break;
    case "publishStatus": requireUUID(body,"sourceEventID"); requireEnum(body,"status",["windDownStarting","phoneAwayActive","windDownCompleted","phoneAwayCompleted"]); if(typeof body.revision!=="number"||!Number.isSafeInteger(body.revision)||body.revision<0)throw new Error("Invalid revision"); if(typeof body.observedAt!=="string"||Number.isNaN(Date.parse(body.observedAt)))throw new Error("Invalid observedAt"); validateMembershipSharingScope(body); break;
    case "completeBackfill":
      requireUUID(body, "roundID");
      requireBoundedText(body, "cursor", 1, 128);
      break;
    case "react":
      requireUUID(body, "activityID"); requireEnum(body, "cheer", ["warmWave", "moonGlow", "pawPrint"]); validateMembershipSharingScope(body);
      break;
    case "blockMember": requireUUID(body, "memberID"); break;
    case "reportMember": requireUUID(body, "memberID"); requireEnum(body, "reason", ["unwantedContact", "harmfulConduct", "impersonation", "otherSafetyConcern"]); break;
    case "cheerMember": requireUUID(body, "memberID"); requireEnum(body, "cheer", ["warmWave", "moonGlow", "pawPrint"]); if(body.statusID!==undefined) requireUUID(body,"statusID"); break;
    case "acknowledgeGrant": requireUUID(body, "grantID"); break;
    case "acceptSharedHabitsAgreement":
      if ((body.agreementVersion !== 1 && body.agreementVersion !== 2) || !isTimeZoneIdentifier(requireString(body, "timeZoneIdentifier"))) throw new Error("Invalid shared habits agreement");
      break;
    case "publishSharedHabit":
      requireUUID(body, "agreementID"); requireUUID(body, "memberEpochID"); requireUUID(body, "sourceID");
      if (typeof body.revision !== "number" || !Number.isSafeInteger(body.revision) || body.revision < 0) throw new Error("Invalid revision");
      requireEnum(body, "kind", ["sleep", "windDown", "phoneAway"]);
      body.localDate = normalizeSharedHabitsLocalDate(body.localDate);
      if (!isTimeZoneIdentifier(requireString(body, "timeZoneIdentifier"))) throw new Error("Invalid timeZoneIdentifier");
      if (typeof body.minutes !== "number" || !Number.isSafeInteger(body.minutes) || body.minutes < 0) throw new Error("Values outside bounds");
      const maximumMinutes = body.kind === "windDown" ? 180 : 1_500;
      if (body.minutes > maximumMinutes) throw new Error("Values outside bounds");
      if (body.outcome !== undefined && body.outcome !== null) requireEnum(body, "outcome", ["completed", "partlyCompleted"]);
      if (body.protectionMinutes !== undefined && body.protectionMinutes !== null && (typeof body.protectionMinutes !== "number" || !Number.isSafeInteger(body.protectionMinutes) || body.protectionMinutes < 0 || body.protectionMinutes > body.minutes)) throw new Error("Values outside bounds");
      requireEnum(body, "evidence", ["none", "appRecorded"]);
      if (body.protectionMinutes !== undefined && body.protectionMinutes !== null && body.evidence !== "appRecorded") throw new Error("Invalid protection evidence");
      if (body.kind === "sleep" && (body.outcome !== undefined || body.protectionMinutes !== undefined || body.evidence !== "none")) throw new Error("Invalid sleep payload");
      break;
    case "deleteSharedHabitHistory":
      if ((body.sourceID === undefined) === (body.allSources === undefined)) throw new Error("Invalid deletion target");
      if (body.sourceID !== undefined) requireUUID(body, "sourceID");
      if (body.allSources !== undefined && body.allSources !== true) throw new Error("Invalid deletion target");
      break;
    case "migrateSharedHabits": requireUUID(body, "agreementID"); break;
    case "publishSharedNightPlan":
      requireUUID(body, "planID"); requireUUID(body, "memberEpochID"); requireUUID(body, "agreementID");
      validateSharedNightRevision(body); body.nightEndingDate = normalizeSharedHabitsLocalDate(body.nightEndingDate);
      validateSharedNightMinutes(body, "beforeBedMinutes"); validateSharedNightMinutes(body, "afterWakingMinutes");
      validateSharedNightTimes(body, ["plannedWindDownStart", "intendedBedtime", "intendedWakeTime", "morningQuietEnd"]);
      validatePlanChronology(body);
      if (!isTimeZoneIdentifier(requireString(body, "timeZoneIdentifier"))) throw new Error("Invalid timeZoneIdentifier");
      validateSuggestionIDs(body, "eveningSuggestionIDs", 3); validateSuggestionIDs(body, "morningSuggestionIDs", 2);
      break;
    case "cancelSharedNightPlan":
      requireUUID(body, "memberEpochID"); requireUUID(body, "agreementID");
      validateSharedNightRevision(body); body.nightEndingDate = normalizeSharedHabitsLocalDate(body.nightEndingDate);
      if (!isTimeZoneIdentifier(requireString(body, "timeZoneIdentifier"))) throw new Error("Invalid timeZoneIdentifier");
      requireEnum(body, "cancellationAuthority", ["schedule", "privacy"]);
      break;
    case "publishSharedNightReceipt":
      requireUUID(body, "receiptID"); requireUUID(body, "memberEpochID"); requireUUID(body, "agreementID");
      if ((body.planID === undefined) !== (body.planRevision === undefined)) throw new Error("Invalid plan binding");
      if (body.planID !== undefined) requireUUID(body, "planID"); requireUUID(body, "sourceID");
      validateSharedNightRevision(body); if (body.planRevision !== undefined && (!Number.isSafeInteger(body.planRevision) || (body.planRevision as number) < 0)) throw new Error("Invalid planRevision");
      body.nightEndingDate = normalizeSharedHabitsLocalDate(body.nightEndingDate); if (!isTimeZoneIdentifier(requireString(body, "timeZoneIdentifier"))) throw new Error("Invalid timeZoneIdentifier");
      validateOptionalTimes(body, ["actualStart", "terminalAt"]); validateReceiptChronology(body); requireEnum(body, "outcome", ["completed", "partlyCompleted", "unknown"]);
      if ((body.outcome === "completed" || body.outcome === "partlyCompleted") && body.actualStart === undefined) throw new Error("Actual start required");
      if (body.windDownMinutes !== undefined) validateSharedNightMinutes(body, "windDownMinutes");
      if (body.protectionMinutes !== undefined) validateSharedNightMinutes(body, "protectionMinutes");
      requireEnum(body, "protectionEvidence", ["observed", "partial", "unavailable", "failedOpen", "unknown"]);
      if (body.protectionMinutes !== undefined && body.protectionEvidence !== "observed" && body.protectionEvidence !== "partial") throw new Error("Invalid protection evidence");
      if (body.emergencyExitUsed !== undefined && typeof body.emergencyExitUsed !== "boolean") throw new Error("Invalid emergencyExitUsed");
      break;
  }
}

function validateSharedNightRevision(body: Record<string, unknown>): void { if (!Number.isSafeInteger(body.revision) || (body.revision as number) < 0) throw new Error("Invalid revision"); }
function validateSharedNightTimes(body: Record<string, unknown>, keys: string[]): void { for (const key of keys) { const instant = typeof body[key] === "string" ? Date.parse(body[key] as string) : Number.NaN; if (Number.isNaN(instant) || instant % 300_000 !== 0) throw new Error(`Invalid ${key}`); } }
function validateOptionalTimes(body: Record<string, unknown>, keys: string[]): void { for (const key of keys) if (body[key] !== undefined) { const instant = typeof body[key] === "string" ? Date.parse(body[key] as string) : Number.NaN; if (Number.isNaN(instant) || instant % 300_000 !== 0) throw new Error(`Invalid ${key}`); } }
function validateSharedNightMinutes(body: Record<string, unknown>, key: string): void { if (!Number.isSafeInteger(body[key]) || (body[key] as number) < 0 || (body[key] as number) > 180) throw new Error("Values outside bounds"); }
function validatePlanChronology(body: Record<string, unknown>): void {
  const start = Date.parse(body.plannedWindDownStart as string);
  const bedtime = Date.parse(body.intendedBedtime as string);
  const wake = Date.parse(body.intendedWakeTime as string);
  const quietEnd = Date.parse(body.morningQuietEnd as string);
  if (!(start <= bedtime && bedtime < wake && wake <= quietEnd)) throw new Error("Invalid plan chronology");
  if (bedtime - start !== Number(body.beforeBedMinutes) * 60_000 ||
      quietEnd - wake !== Number(body.afterWakingMinutes) * 60_000) {
    throw new Error("Plan bookends do not match minutes");
  }
}
function validateReceiptChronology(body: Record<string, unknown>): void {
  if (body.actualStart === undefined || body.terminalAt === undefined) return;
  if (Date.parse(body.terminalAt as string) < Date.parse(body.actualStart as string)) {
    throw new Error("Invalid receipt chronology");
  }
}
function validateSuggestionIDs(body: Record<string, unknown>, key: string, maximum: number): void { const value = body[key]; if (!Array.isArray(value) || value.length > maximum || new Set(value).size !== value.length || !value.every((entry) => typeof entry === "string" && ["read", "shower", "prepareTomorrow", "stretch", "journal", "makeTea", "openCurtains", "breakfast", "morningWalk", "getReady", "brushTeeth", "quietConversation", "makeBed", "brainDump", "sleepwear", "relaxation", "quietMusic", "calmHobby"].includes(entry))) throw new Error(`Invalid ${key}`); }

function validateMembershipSharingScope(body: Record<string, unknown>): void {
  if (body.sharingScope !== undefined && body.sharingScope !== "membership") {
    throw new Error("Invalid sharingScope");
  }
}

function validateDisplayName(body: Record<string, unknown>): void { const value=requireString(body,"displayName").normalize("NFC").trim().replace(/\s+/gu," "); if(Array.from(value).length<2||Array.from(value).length>24||!/^[\p{L}\p{M}\p{N} '’\-‐‑]+$/u.test(value))throw new Error("Invalid displayName"); body.displayName=value; }
function validateFlatPresentation(p: Record<string,unknown>): void { requireEnum(p,"skinToneID",["porcelain","warm","olive","brown","deep"]); requireEnum(p,"hairStyleID",["cropped","waves","curls","coils","long"]); requireEnum(p,"shepherdOutfitID",["none","shepherd_moss_coat","shepherd_moon_coat","shepherd_field_overalls","shepherd_star_keeper_cloak"]); requireEnum(p,"shepherdAccessoryID",["none","shepherd_wool_hat","shepherd_clover_headscarf","shepherd_moon_beanie"]); requireEnum(p,"ollieOrnamentID",["none","ollie_moss_bandana","ollie_moon_kerchief","ollie_brass_bell","ollie_clover_collar","ollie_sunrise_scarf","ollie_star_keeper_cape"]); requireEnum(p,"featuredSheepDefinitionID",["none","mabel","pippin","bramble","clementine","oat","midnight","juniper","hazel","ramsey","luna","marigold","wisp"]); requireEnum(p,"pastureThemeID",["pasture_meadow","pasture_moonlit","pasture_sunrise"]); }
function validateAvatarID(body: Record<string, unknown>): void { requireEnum(body, "avatarID", ["shepherd", "ollie", "sheep:mabel", "sheep:pippin", "sheep:bramble", "sheep:clementine", "sheep:oat", "sheep:midnight", "sheep:juniper", "sheep:hazel", "sheep:ramsey", "sheep:luna", "sheep:marigold", "sheep:wisp"]); }

function isTimeZoneIdentifier(value: string): boolean {
  if (!/^[A-Za-z0-9_+\-/]{1,64}$/.test(value)) return false;
  try { Intl.DateTimeFormat("en-US", { timeZone: value }).format(0); return true; }
  catch { return false; }
}
function requireBoundedText(body: Record<string, unknown>, key: string, minimum: number, maximum: number): string {
  const value = requireString(body, key).trim();
  if (value.length < minimum || value.length > maximum || /[\u0000-\u001f\u007f]/.test(value)) throw new Error(`Invalid ${key}`);
  body[key] = value;
  return value;
}

function validateCommitmentCommand(body: Record<string, unknown>, command: string): void {
  switch (command) {
    case "createInvite": {
      const hasID = body.inviteID !== undefined;
      const hasDigest = body.inviteDigest !== undefined;
      if (hasID !== hasDigest) throw new Error("Invalid invite credential pair");
      if (hasID) {
        requireUUID(body, "inviteID");
        requireDigest(body, "inviteDigest");
      }
      break;
    }
    case "replaceInvite":
      requireUUID(body, "expectedInviteID");
      requireUUID(body, "inviteID");
      requireDigest(body, "inviteDigest");
      break;
    case "createParty":
      requireEnum(body, "goalKind", ["phoneAway", "quietMinutes", "shieldInstagram"]);
      requireEnum(body, "identity", ["moonlitMeadow", "orchardGate", "starlightHill"]);
      if (body.targetMinutes !== undefined && body.targetMinutes !== null &&
          (typeof body.targetMinutes !== "number" || !Number.isSafeInteger(body.targetMinutes) || body.targetMinutes < 5 || body.targetMinutes > 180)) {
        throw new Error("Invalid targetMinutes");
      }
      if (body.appDisplayName !== undefined && body.appDisplayName !== null &&
          (typeof body.appDisplayName !== "string" || body.appDisplayName.length > 40)) {
        throw new Error("Invalid appDisplayName");
      }
      if (body.goalKind === "quietMinutes" &&
          (typeof body.targetMinutes !== "number" || !Number.isSafeInteger(body.targetMinutes))) {
        throw new Error("Invalid targetMinutes");
      }
      if (!/^[A-Za-z0-9_+\-/]{1,64}$/.test(requireString(body, "timeZoneIdentifier"))) {
        throw new Error("Invalid timeZoneIdentifier");
      }
      break;
    case "previewInvite":
    case "redeemInvite":
      if (!/^[A-HJ-NP-Z2-9]{12}$/.test(requireString(body, "shortCode").toUpperCase())) {
        throw new Error("Invalid shortCode");
      }
      body.shortCode = requireString(body, "shortCode").toUpperCase();
      break;
    case "acceptGoal":
    case "startChallenge":
      requireUUID(body, "challengeID");
      break;
    case "setLocalSetup":
      requireUUID(body, "challengeID");
      if (typeof body.setupReady !== "boolean") throw new Error("Invalid setupReady");
      requireEnum(body, "shieldingEvidence", ["notRequested", "unavailable", "partial", "observed"]);
      break;
    case "setSharingPreferences":
      if (typeof body.shareGoalProgress !== "boolean" || typeof body.shareRoutineIdeas !== "boolean") {
        throw new Error("Invalid sharing preferences");
      }
      break;
    case "setRoutineIdeas":
      requireUUID(body, "challengeID");
      if (!Array.isArray(body.guidanceIDs) || body.guidanceIDs.length > 3 ||
          body.guidanceIDs.some((value) => typeof value !== "string" || value.length < 1 || value.length > 80)) {
        throw new Error("Invalid guidanceIDs");
      }
      break;
    case "publishProgress":
      requireUUID(body, "challengeID");
      if (typeof body.day !== "number" || !Number.isSafeInteger(body.day) || body.day < 1 || body.day > 7) {
        throw new Error("Invalid day");
      }
      requireEnum(body, "status", [
        "goalAccepted", "setupReady", "phoneTuckedAway", "partiallyCompleted",
        "sharedGoalCompleted", "morningQuietCompleted", "privateNoUpdate",
      ]);
      requireEnum(body, "shieldingEvidence", ["notRequested", "unavailable", "partial", "observed"]);
      break;
  }
}

function validateSocialCommand(body: Record<string, unknown>, command: string): void {
  switch (command) {
    case "setSharingPreferences":
      for (const key of [
        "shareGoalProgress", "shareWindDownCompletion", "shareWindDownMinutes",
        "sharePhoneAwayMinutes", "sharePhoneTuckedAway", "shareShieldingStatus",
        "shareRoutineIdeas", "shareSleepDuration", "shareRestfulness",
      ]) {
        if (typeof body[key] !== "boolean") throw new Error("Invalid sharing preferences");
      }
      break;
    case "publishNightMetrics":
      requireUUID(body, "challengeID");
      if (typeof body.day !== "number" || !Number.isSafeInteger(body.day) || body.day < 1 || body.day > 7) {
        throw new Error("Invalid day");
      }
      requireEnum(body, "status", [
        "goalAccepted", "setupReady", "phoneTuckedAway", "partiallyCompleted",
        "sharedGoalCompleted", "morningQuietCompleted", "privateNoUpdate",
      ]);
      requireEnum(body, "shieldingEvidence", ["notRequested", "unavailable", "partial", "observed"]);
      if (typeof body.windDownMinutes !== "number" || !Number.isSafeInteger(body.windDownMinutes)
          || body.windDownMinutes < 0 || body.windDownMinutes > 180) {
        throw new Error("Values outside bounds");
      }
      if (typeof body.phoneAwayMinutes !== "number" || !Number.isSafeInteger(body.phoneAwayMinutes)
          || body.phoneAwayMinutes < 0 || body.phoneAwayMinutes > 240) {
        throw new Error("Values outside bounds");
      }
      if (body.sleepDurationMinutes !== null && body.sleepDurationMinutes !== undefined
          && (typeof body.sleepDurationMinutes !== "number" || !Number.isSafeInteger(body.sleepDurationMinutes)
            || body.sleepDurationMinutes < 0 || body.sleepDurationMinutes > 720)) {
        throw new Error("Values outside bounds");
      }
      if (body.restfulness !== null && body.restfulness !== undefined) {
        requireEnum(body, "restfulness", ["notMuch", "somewhat", "rested", "notSure"]);
      }
      break;
    case "acknowledgeGrant":
      requireUUID(body, "grantID");
      break;
  }
}

function requireExactFields(body: Record<string, unknown>, fields: string[]): void {
  const expected = new Set(fields);
  const unexpected = Object.keys(body).filter((key) => !expected.has(key));
  if (unexpected.length > 0) throw new Error(`Unexpected field ${unexpected[0]}`);
}

function requireString(body: Record<string, unknown>, key: string): string {
  const value = body[key];
  if (typeof value !== "string" || value.length === 0) throw new Error(`Invalid ${key}`);
  return value;
}

function requireUUID(body: Record<string, unknown>, key: string): string {
  const value = requireString(body, key);
  if (!uuidPattern.test(value)) throw new Error(`Invalid ${key}`);
  return value.toLowerCase();
}

function requireDigest(body: Record<string, unknown>, key: string): string {
  const value = requireString(body, key).toLowerCase();
  if (!idempotencyPattern.test(value)) throw new Error(`Invalid ${key}`);
  body[key] = value;
  return value;
}

function requireEnum(body: Record<string, unknown>, key: string, values: string[]): string {
  const value = requireString(body, key);
  if (!values.includes(value)) throw new Error(`Invalid ${key}`);
  return value;
}
