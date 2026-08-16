import { assertEquals, assertStringIncludes, assertThrows } from "jsr:@std/assert@1";
import {
  handleNightFlockCommand,
  handleNightFlockState,
  NightFlockCommandDependencies,
} from "./night-flock-handlers.ts";
import { validateNightFlockCommand, validateNightFlockState } from "./night-flock.ts";

const userID = "10000000-0000-4000-8000-000000000001";
const challengeID = "20000000-0000-4000-8000-000000000001";
const key = "a".repeat(64);

Deno.test("Slumber Party payload rejects every unrecognized sensitive field", () => {
  const base = {
    schemaVersion: 1,
    command: "publishCheckIn",
    challengeID,
    day: 2,
    state: "phoneTucked",
    idempotencyKey: key,
  };
  for (const forbidden of [
    "userID", "ownerID", "runID", "startedAt", "bedtime", "wakeTime", "duration",
    "healthKit", "screenTime", "selectedApps", "nfc", "purpose", "cue", "notifications",
    "farm", "sheep", "wool", "transaction", "impactNights", "privateNight",
  ]) {
    assertThrows(
      () => validateNightFlockCommand({ ...base, [forbidden]: "forbidden" }, key),
      Error,
      "Unexpected field",
    );
  }
});

Deno.test("Slumber Party payload validates identifiers, enums, days, and invite shape", () => {
  assertThrows(() => validateNightFlockCommand({
    schemaVersion: 1,
    command: "publishCheckIn",
    challengeID: "not-a-uuid",
    day: 0,
    state: "failed",
    idempotencyKey: key,
  }, key), Error);
  assertThrows(() => validateNightFlockCommand({
    schemaVersion: 1,
    command: "join",
    shortCode: "ABC12345",
    idempotencyKey: key,
  }, key), Error, "Invalid shortCode");
  assertThrows(() => validateNightFlockCommand({
    schemaVersion: 1,
    command: "setSharing",
    enabled: "yes",
    idempotencyKey: key,
  }, key), Error, "Invalid enabled");
  assertThrows(() => validateNightFlockCommand({
    schemaVersion: 1,
    command: "leave",
    idempotencyKey: key,
  }, "b".repeat(64)), Error, "Idempotency key mismatch");
});

Deno.test("schema two accepts only bounded shared-goal and local setup fields", () => {
  const v2Key = "c".repeat(64);
  const create = validateNightFlockCommand({
    schemaVersion: 2,
    command: "createParty",
    goalKind: "shieldInstagram",
    targetMinutes: null,
    appDisplayName: "Instagram",
    identity: "moonlitMeadow",
    timeZoneIdentifier: "Asia/Singapore",
    idempotencyKey: v2Key,
  }, v2Key);
  assertEquals(create.schemaVersion, 2);
  assertThrows(() => validateNightFlockCommand({
    schemaVersion: 2,
    command: "createParty",
    goalKind: "quietMinutes",
    targetMinutes: 181,
    appDisplayName: null,
    identity: "moonlitMeadow",
    timeZoneIdentifier: "UTC",
    idempotencyKey: v2Key,
  }, v2Key), Error, "Invalid targetMinutes");
  assertThrows(() => validateNightFlockCommand({
    schemaVersion: 2,
    command: "setLocalSetup",
    challengeID,
    setupReady: true,
    shieldingEvidence: "observed",
    appTokens: ["opaque"],
    idempotencyKey: v2Key,
  }, v2Key), Error, "Unexpected field");
  assertEquals(validateNightFlockState({ schemaVersion: 2 }).schemaVersion, 2);
});

Deno.test("Slumber Party command rejects anonymous JWT callers", async () => {
  const response = await handleNightFlockCommand(commandRequest(), {
    authenticate: async () => ({ id: userID, isAnonymous: true }),
    execute: async () => ({ accepted: true }),
    deleteAccount: async () => {},
  });
  assertEquals(response.status, 403);
  assertStringIncludes(await response.text(), "Linked account required");
});

Deno.test("Slumber Party command derives caller and never accepts a body owner", async () => {
  let receivedCaller = "";
  const dependencies: NightFlockCommandDependencies = {
    authenticate: async () => ({ id: userID, isAnonymous: false }),
    execute: async (caller) => {
      receivedCaller = caller;
      return { accepted: true, snapshot: null };
    },
    deleteAccount: async () => {},
  };
  const response = await handleNightFlockCommand(commandRequest(), dependencies);
  assertEquals(response.status, 200);
  assertEquals(receivedCaller, userID);

  const bodyWithOwner = JSON.parse(await commandRequest().text());
  bodyWithOwner.userID = "30000000-0000-4000-8000-000000000001";
  const rejected = await handleNightFlockCommand(commandRequest(bodyWithOwner), dependencies);
  assertEquals(rejected.status, 400);
});

Deno.test("account deletion occurs only after the service command authorizes it", async () => {
  const calls: string[] = [];
  const response = await handleNightFlockCommand(commandRequest({
    schemaVersion: 1,
    command: "deleteAccount",
    idempotencyKey: key,
  }), {
    authenticate: async () => ({ id: userID, isAnonymous: false }),
    execute: async () => {
      calls.push("command");
      return { accepted: true, deleteAccount: true };
    },
    deleteAccount: async () => {
      calls.push("delete");
    },
  });
  assertEquals(response.status, 200);
  assertEquals(calls, ["command", "delete"]);
});

Deno.test("state endpoint rejects anonymous callers without reading social state", async () => {
  let readCount = 0;
  const response = await handleNightFlockState(new Request("http://local", {
    method: "POST",
    body: JSON.stringify({ schemaVersion: 1 }),
  }), {
    authenticate: async () => ({ id: userID, isAnonymous: true }),
    read: async () => {
      readCount += 1;
      return null;
    },
  });
  assertEquals(response.status, 403);
  assertEquals(readCount, 0);
});

Deno.test("schema three rejects tokens, out-of-bounds minutes, and extra fields", () => {
  const v3Key = "d".repeat(64);
  const accepted = validateNightFlockCommand({
    schemaVersion: 3,
    command: "publishNightMetrics",
    challengeID,
    day: 1,
    status: "morningQuietCompleted",
    shieldingEvidence: "observed",
    windDownMinutes: 40,
    phoneAwayMinutes: 10,
    sleepDurationMinutes: 450,
    restfulness: "rested",
    idempotencyKey: v3Key,
  }, v3Key);
  assertEquals(accepted.schemaVersion, 3);
  assertThrows(() => validateNightFlockCommand({
    schemaVersion: 3,
    command: "publishNightMetrics",
    challengeID,
    day: 1,
    status: "morningQuietCompleted",
    shieldingEvidence: "observed",
    windDownMinutes: 40,
    phoneAwayMinutes: 10,
    sleepDurationMinutes: 450,
    restfulness: "rested",
    applicationTokens: ["opaque"],
    idempotencyKey: v3Key,
  }, v3Key), Error, "Unexpected field");
  assertThrows(() => validateNightFlockCommand({
    schemaVersion: 3,
    command: "publishNightMetrics",
    challengeID,
    day: 1,
    status: "morningQuietCompleted",
    shieldingEvidence: "observed",
    windDownMinutes: 181,
    phoneAwayMinutes: 0,
    sleepDurationMinutes: null,
    restfulness: null,
    idempotencyKey: v3Key,
  }, v3Key), Error, "Values outside bounds");
  assertThrows(() => validateNightFlockCommand({
    schemaVersion: 3,
    command: "publishNightMetrics",
    challengeID,
    day: 1,
    status: "morningQuietCompleted",
    shieldingEvidence: "observed",
    windDownMinutes: 40,
    phoneAwayMinutes: 0,
    sleepDurationMinutes: null,
    restfulness: null,
    memberID: userID,
    idempotencyKey: v3Key,
  }, v3Key), Error, "Unexpected field");
  assertEquals(validateNightFlockState({ schemaVersion: 3 }).schemaVersion, 3);
});

function commandRequest(body: Record<string, unknown> = {
  schemaVersion: 1,
  command: "publishCheckIn",
  challengeID,
  day: 2,
  state: "phoneTucked",
  idempotencyKey: key,
}): Request {
  return new Request("http://local", {
    method: "POST",
    headers: { "content-type": "application/json", "idempotency-key": String(body.idempotencyKey) },
    body: JSON.stringify(body),
  });
}
