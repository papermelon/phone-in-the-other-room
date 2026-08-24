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
  schemaVersion: 1 | 2 | 3;
  command: string;
  idempotencyKey: string;
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
  if (body.schemaVersion !== 1 && body.schemaVersion !== 2 && body.schemaVersion !== 3) {
    throw new Error("Unsupported schemaVersion");
  }
  const command = requireString(body, "command");
  const allowedFields = body.schemaVersion === 3
    ? socialCommandFields[command]
    : body.schemaVersion === 2
    ? commitmentCommandFields[command]
    : commandFields[command];
  if (!allowedFields) throw new Error("Unsupported Slumber Party command");
  const exactFields = body.schemaVersion === 2 && command === "createInvite" &&
      (body.inviteID !== undefined || body.inviteDigest !== undefined)
    ? [...allowedFields, "inviteID", "inviteDigest"]
    : allowedFields;
  requireExactFields(body, exactFields);
  const idempotencyKey = requireString(body, "idempotencyKey").toLowerCase();
  if (!idempotencyPattern.test(idempotencyKey)) throw new Error("Invalid idempotencyKey");
  if (headerIdempotencyKey?.toLowerCase() !== idempotencyKey) {
    throw new Error("Idempotency key mismatch");
  }

  if (body.schemaVersion === 3) {
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

export function validateNightFlockState(body: Record<string, unknown>): { schemaVersion: 1 | 2 | 3 } {
  requireExactFields(body, ["schemaVersion"]);
  if (body.schemaVersion !== 1 && body.schemaVersion !== 2 && body.schemaVersion !== 3) {
    throw new Error("Unsupported schemaVersion");
  }
  return { schemaVersion: body.schemaVersion };
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
