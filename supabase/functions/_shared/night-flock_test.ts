import { assert, assertEquals, assertStringIncludes, assertThrows } from "jsr:@std/assert@1";
import {
  handleNightFlockCommand,
  handleNightFlockState,
  nightFlockCompletionLogRecord,
  NightFlockCommandDependencies,
} from "./night-flock-handlers.ts";
import { validateNightFlockCommand, validateNightFlockState } from "./night-flock.ts";
import { classifyNightFlockError, requestIDFor } from "./night-flock-errors.ts";

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

Deno.test("schema two validates recoverable create and compare-and-swap replacement", () => {
  const inviteID = "30000000-0000-4000-8000-000000000001";
  const expectedInviteID = "40000000-0000-4000-8000-000000000001";
  const digest = "b".repeat(64);
  const create = validateNightFlockCommand({
    schemaVersion: 2, command: "createInvite", inviteID, inviteDigest: digest,
    idempotencyKey: key,
  }, key);
  assertEquals(create.inviteID, inviteID);
  assertEquals(create.inviteDigest, digest);
  assertEquals(validateNightFlockCommand({
    schemaVersion: 2, command: "createInvite", idempotencyKey: key,
  }, key).schemaVersion, 2);
  assertThrows(() => validateNightFlockCommand({
    schemaVersion: 2, command: "createInvite", inviteID, idempotencyKey: key,
  }, key), Error, "Invalid invite credential pair");
  assertEquals(validateNightFlockCommand({
    schemaVersion: 2, command: "replaceInvite", expectedInviteID, inviteID,
    inviteDigest: digest, idempotencyKey: key,
  }, key).command, "replaceInvite");
  for (const schemaVersion of [1, 3]) {
    assertThrows(() => validateNightFlockCommand({
      schemaVersion, command: "replaceInvite", expectedInviteID, inviteID,
      inviteDigest: digest, idempotencyKey: key,
    }, key), Error, "Unsupported Slumber Party command");
  }
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

Deno.test("Night Flock envelopes echo a valid request ID in the body and header", async () => {
  const requestID = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
  const response = await handleNightFlockCommand(commandRequest(undefined, requestID), {
    authenticate: async () => ({ id: userID, isAnonymous: false }),
    execute: async () => ({ accepted: true }),
    deleteAccount: async () => {},
  });
  const body = await response.json();
  assertEquals(response.headers.get("X-Request-ID"), requestID);
  assertEquals(body.requestID, requestID);
});

Deno.test("invalid or missing request IDs are replaced with canonical UUIDs", () => {
  for (const candidate of [null, "", "not-a-request-id", "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaZ"]) {
    const value = requestIDFor(candidate);
    assert(/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(value));
  }
  assertEquals(requestIDFor("AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA"), "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa");
});

Deno.test("known database details map to typed errors and unknown details are redacted", () => {
  assertEquals(classifyNightFlockError(new Error("One active Slumber Party allowed")).code, "active_membership_exists");
  assertEquals(classifyNightFlockError(new Error("Invite expired")).status, 410);
  assertEquals(classifyNightFlockError(new Error("Current membership required")).recovery, "reconcileMembership");
  assertEquals(classifyNightFlockError(new Error("Host permission required")).code, "host_permission_required");
  assertEquals(classifyNightFlockError(new Error("This lobby has already started")).code, "lobby_started");
  assertEquals(classifyNightFlockError(new Error("Slumber Party is full")).code, "flock_full");
  assertEquals(classifyNightFlockError(new Error("Blocked membership cannot be joined")).code, "blocked_membership");
  assertEquals(classifyNightFlockError(new Error("Slumber Party unavailable for this account")).code, "account_unavailable");
  assertEquals(classifyNightFlockError(new Error("upstream service unavailable")).status, 503);
  const alias = classifyNightFlockError({ code: "23505", message: "night_flock_members_active_alias" });
  assertEquals(alias.code, "alias_conflict");
  assertEquals(alias.recovery, null);
  for (const constraint of [
    "night_flock_members_one_active_flock_per_user",
    "night_flock_members_one_active_record_per_flock",
  ]) {
    const active = classifyNightFlockError({ code: "23505", details: constraint });
    assertEquals(active.code, "active_membership_exists");
    assertEquals(active.status, 409);
    assertEquals(active.recovery, "reconcileMembership");
  }
  assertEquals(classifyNightFlockError({ code: "23505", details: "night_flock_invites_flock_id_member_id_key" }).code, "invite_member_constraint");
  for (const detail of ["A reusable invitation already exists", "active_invite_exists"]) {
    const activeInvite = classifyNightFlockError(new Error(detail));
    assertEquals(activeInvite.code, "active_invite_exists");
    assertEquals(activeInvite.status, 409);
    assertEquals(activeInvite.retryable, false);
    assertEquals(activeInvite.recovery, "reconcile");
    assert(!activeInvite.error.includes(detail));
  }
  assertEquals(classifyNightFlockError({ message: "snapshot projection construction failed" }).code, "snapshot_construction_failed");
  const unknown = classifyNightFlockError(new Error("secret-account-token=do-not-reflect")).error;
  assertEquals(unknown, "Slumber Party could not complete that request.");
});

Deno.test("completion logs have an exact allowlist and redact a comprehensive secret fixture", () => {
  const secretFixture = [
    "alias=Moonlit Meadow", "userID=10000000-0000-4000-8000-000000000001",
    "memberID=20000000-0000-4000-8000-000000000001", "flockID=30000000-0000-4000-8000-000000000001",
    "challengeID=40000000-0000-4000-8000-000000000001", "invite=ABCD23456789", "digest=deadbeef",
    "idempotency=eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
    "AppleIdentityToken=secret", "selectedApps=private", "HealthKit=450", "2026-08-22T23:15:00Z",
    "routine=read", "metrics=rested", "raw database error", "password=secret",
  ].join(" ");
  const record = nightFlockCompletionLogRecord(
    "night-flock-command",
    "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
    "0-49ms",
    { schemaVersion: 2, command: "redeemInvite", secretFixture },
    409,
    classifyNightFlockError({ code: "23505", message: "night_flock_members_active_alias" }),
  );
  assertEquals(Object.keys(record).sort(), [
    "code", "command", "elapsedDurationBucket", "endpoint", "outcome", "requestID", "schemaVersion", "status",
  ].sort());
  const serialized = JSON.stringify(record);
  for (const secret of ["Moonlit Meadow", "10000000-0000-4000-8000-000000000001", "ABCD23456789", "AppleIdentityToken", "selectedApps", "HealthKit", "raw database error"]) {
    assert(!serialized.includes(secret));
  }
  assertEquals(record.requestID, "dddddddd-dddd-4ddd-8ddd-dddddddddddd");
});

Deno.test("comprehensive PostgREST details never enter response or request-correlated envelope", async () => {
  const requestID = "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee";
  const secretFixture = "night_flock_members_active_alias user=10000000-0000-4000-8000-000000000001 member=20000000-0000-4000-8000-000000000001 flock=30000000-0000-4000-8000-000000000001 challenge=40000000-0000-4000-8000-000000000001 invite=ABCD23456789 digest=deadbeef idempotency=ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff AppleToken=secret selectedApps=private HealthKit=450 exactTime=2026-08-22T23:15:00Z routine=read metrics=rested raw DB detail";
  const response = await handleNightFlockCommand(commandRequest(undefined, requestID), {
    authenticate: async () => ({ id: userID, isAnonymous: false }),
    execute: async () => { throw { code: "23505", message: secretFixture }; },
    deleteAccount: async () => {},
  });
  const text = await response.text();
  const body = JSON.parse(text);
  assertEquals(response.status, 409);
  assertEquals(response.headers.get("X-Request-ID"), requestID);
  assertEquals(body.requestID, requestID);
  assertEquals(body.code, "alias_conflict");
  for (const secret of ["10000000-0000-4000-8000-000000000001", "ABCD23456789", "AppleToken", "selectedApps", "HealthKit", "raw DB detail"]) {
    assert(!text.includes(secret));
  }
});

Deno.test("legacy error strings remain compatible without exposing backend details", async () => {
  const secret = "apple-token=secret-health-selectedApps";
  const response = await handleNightFlockCommand(commandRequest({
    schemaVersion: 1,
    command: "publishCheckIn",
    challengeID,
    day: 2,
    state: "phoneTucked",
    idempotencyKey: key,
  }, "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"), {
    authenticate: async () => ({ id: userID, isAnonymous: false }),
    execute: async () => { throw new Error(secret); },
    deleteAccount: async () => {},
  });
  const text = await response.text();
  assertEquals(response.status, 500);
  assert(!text.includes(secret));
  assert(!text.includes("apple-token"));
  assertStringIncludes(text, '"error":"Slumber Party could not complete that request."');
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
}, requestID = "cccccccc-cccc-4ccc-8ccc-cccccccccccc"): Request {
  return new Request("http://local", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "idempotency-key": String(body.idempotencyKey),
      "X-Request-ID": requestID,
    },
    body: JSON.stringify(body),
  });
}
