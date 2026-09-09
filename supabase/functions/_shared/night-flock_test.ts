import { assert, assertEquals, assertStringIncludes, assertThrows } from "jsr:@std/assert@1";
import {
  handleNightFlockCommand,
  handleNightFlockState,
  nightFlockCompletionLogRecord,
  NightFlockCommandDependencies,
} from "./night-flock-handlers.ts";
import { validateNightFlockCommand, validateNightFlockState } from "./night-flock.ts";
import { classifyNightFlockError, requestIDFor } from "./night-flock-errors.ts";
import { createInvitation, decryptInvitation, redactInvitationResult } from "./night-flock-invites.ts";

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
  assertEquals(classifyNightFlockError(new Error("agreement_timezone_mismatch")).code, "agreement_timezone_mismatch");
  assertEquals(classifyNightFlockError(new Error("invalid_receipt_chronology")).code, "invalid_receipt_chronology");
  assertEquals(classifyNightFlockError(new Error("publication_outside_plan_window")).retryable, false);
  assertEquals(classifyNightFlockError(new Error("shared_night_plan_frozen")).code, "shared_night_plan_frozen");
  assertEquals(classifyNightFlockError(new Error("receipt_actual_start_required")).retryable, false);
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

Deno.test("Slumber Party errors never mention lobbies or unavailable ownership transfer", () => {
  const legacyFailures = [
    { code: "23505", message: "night_flock_members_active_alias" },
    new Error("active_invite_exists"),
    new Error("This lobby has already started"),
    { message: "snapshot projection construction failed" },
  ];
  for (const failure of legacyFailures) {
    assert(!classifyNightFlockError(failure).error.toLowerCase().includes("lobby"));
  }
  assertEquals(
    classifyNightFlockError(new Error("host_cannot_leave")).error,
    "Delete this Slumber Party before leaving.",
  );
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

Deno.test("completion logs identify shared-night publications without retaining their payload", () => {
  for (const command of ["publishSharedNightPlan", "publishSharedNightReceipt"]) {
    const record = nightFlockCompletionLogRecord(
      "night-flock-command",
      "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
      "0-49ms",
      {
        schemaVersion: 4,
        command,
        plannedWindDownStart: "2026-08-30T14:30:00Z",
        exactAppIdentity: "must-not-log",
        routineText: "must-not-log",
      },
      200,
      null,
    );
    assertEquals(record.command, command);
    const serialized = JSON.stringify(record);
    assert(!serialized.includes("2026-08-30T14:30:00Z"));
    assert(!serialized.includes("must-not-log"));
  }
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

Deno.test("schema four accepts only exact party contracts and scoped state", () => {
  const partyID = "30000000-0000-4000-8000-000000000001";
  const sourceEventID = "40000000-0000-4000-8000-000000000001";
  const v4Key = "e".repeat(64);
  assertEquals(validateNightFlockCommand({
    schemaVersion: 4, command: "createParty", name: "Night Owls", timeZoneIdentifier: "Asia/Singapore", idempotencyKey: v4Key,
  }, v4Key).schemaVersion, 4);
  assertEquals(validateNightFlockCommand({
    schemaVersion: 4, command: "publishActivity", sourceEventID, kind: "windDown", outcome: "completed", startedAt: "2026-08-25T12:00:00Z", endedAt: "2026-08-25T12:20:00Z", windDownMinutes: 20, phoneAwayMinutes: 0, statusRevision: 1, idempotencyKey: v4Key,
  }, v4Key).command, "publishActivity");
  assertEquals(validateNightFlockCommand({
    schemaVersion: 4, command: "cheerMember", partyID, memberID: userID, cheer: "pawPrint", idempotencyKey: v4Key,
  }, v4Key).command, "cheerMember");
  assertThrows(() => validateNightFlockCommand({
    schemaVersion: 1, command: "cheerMember", partyID, memberID: userID, cheer: "pawPrint", idempotencyKey: v4Key,
  }, v4Key), Error, "Unsupported Slumber Party command");
  assertThrows(() => validateNightFlockCommand({
    schemaVersion: 4, command: "createInvite", partyID, inviteCiphertext: "must-not-arrive-from-client", idempotencyKey: v4Key,
  }, v4Key), Error, "Unexpected field");
  assertThrows(() => validateNightFlockCommand({
    schemaVersion: 4, command: "publishActivity", sourceEventID, kind: "windDown", outcome: "completed", startedAt: "2026-08-25T12:00:00Z", endedAt: "2026-08-25T12:20:00Z", windDownMinutes: 241, phoneAwayMinutes: 0, statusRevision: 1, idempotencyKey: v4Key,
  }, v4Key), Error, "Values outside bounds");
  assertEquals(validateNightFlockState({ schemaVersion: 4, scope: "list" }).schemaVersion, 4);
  assertEquals(validateNightFlockState({ schemaVersion: 4, scope: "party", partyID, cursor: "page-2" }).schemaVersion, 4);
  assertThrows(() => validateNightFlockState({ schemaVersion: 4, scope: "list", partyID }), Error, "Invalid partyID");
});

Deno.test("shared-habits validates real calendar days and IANA contributor zones", () => {
  const base = { schemaVersion: 4, command: "publishSharedHabit", partyID: challengeID, agreementID: challengeID, memberEpochID: challengeID, sourceID: challengeID, revision: 1780000000000, kind: "sleep", localDate: "2026-08-29", timeZoneIdentifier: "UTC", minutes: 420, evidence: "none", idempotencyKey: key };
  assertEquals(validateNightFlockCommand(base, key).command, "publishSharedHabit");
  assertEquals(validateNightFlockCommand({ ...base, localDate: "2028-02-29", timeZoneIdentifier: "Asia/Singapore" }, key).command, "publishSharedHabit");
  assertThrows(() => validateNightFlockCommand({ ...base, localDate: "2026-99-99" }, key), Error, "Invalid localDate");
  assertThrows(() => validateNightFlockCommand({ ...base, localDate: "2026-02-29" }, key), Error, "Invalid localDate");
  assertThrows(() => validateNightFlockCommand({ ...base, localDate: "2026-02-30" }, key), Error, "Invalid localDate");
  assertThrows(() => validateNightFlockCommand({ ...base, localDate: "2026/08/29" }, key), Error, "Invalid localDate");
  assertThrows(() => validateNightFlockCommand({ ...base, timeZoneIdentifier: "Mars/Olympus" }, key), Error, "Invalid timeZoneIdentifier");
});

Deno.test("shared-night plan and receipt require the v2-safe allowlist", () => {
  const plan = {
    schemaVersion: 4, command: "publishSharedNightPlan", partyID: challengeID, planID: userID,
    memberEpochID: challengeID, agreementID: challengeID, revision: 1, nightEndingDate: "2026-08-30",
    timeZoneIdentifier: "Asia/Singapore", plannedWindDownStart: "2026-08-30T14:30:00Z",
    intendedBedtime: "2026-08-30T15:00:00Z", intendedWakeTime: "2026-08-30T23:00:00Z",
    morningQuietEnd: "2026-08-30T23:30:00Z", beforeBedMinutes: 30, afterWakingMinutes: 30,
    eveningSuggestionIDs: ["read", "stretch"], morningSuggestionIDs: ["openCurtains"], idempotencyKey: key,
  };
  assertEquals(validateNightFlockCommand(plan, key).command, "publishSharedNightPlan");
  const revisedKey = "b".repeat(64);
  assertEquals(validateNightFlockCommand({ ...plan, revision: 2, idempotencyKey: revisedKey }, revisedKey).revision, 2);
  assertThrows(() => validateNightFlockCommand({ ...plan, selectedApps: ["forbidden"] }, key), Error, "Unexpected field");
  assertThrows(() => validateNightFlockCommand({ ...plan, supersededAt: "2026-08-30T16:00:00Z" }, key), Error, "Unexpected field");
  assertThrows(() => validateNightFlockCommand({ ...plan, eveningSuggestionIDs: ["custom text"] }, key), Error, "Invalid eveningSuggestionIDs");
  assertThrows(() => validateNightFlockCommand({ ...plan, intendedBedtime: "2026-08-30T14:00:00Z" }, key), Error, "Invalid plan chronology");
  assertThrows(() => validateNightFlockCommand({ ...plan, plannedWindDownStart: "2026-08-30T14:30:00.100Z" }, key), Error, "Invalid plannedWindDownStart");
  assertThrows(() => validateNightFlockCommand({ ...plan, beforeBedMinutes: 20 }, key), Error, "Plan bookends do not match minutes");
  assertEquals(validateNightFlockCommand({
    ...plan,
    nightEndingDate: "2026-09-01",
    plannedWindDownStart: "2026-08-31T22:30:00Z", intendedBedtime: "2026-08-31T23:00:00Z",
    intendedWakeTime: "2026-09-01T23:30:00Z", morningQuietEnd: "2026-09-02T02:30:00Z",
    afterWakingMinutes: 180,
  }, key).command, "publishSharedNightPlan");
  const cancellation = {
    schemaVersion: 4, command: "cancelSharedNightPlan", partyID: challengeID,
    memberEpochID: challengeID, agreementID: challengeID, revision: 2,
    nightEndingDate: "2026-08-30", timeZoneIdentifier: "Asia/Singapore", cancellationAuthority: "privacy", idempotencyKey: key,
  };
  assertEquals(validateNightFlockCommand(cancellation, key).command, "cancelSharedNightPlan");
  assertEquals(validateNightFlockCommand({ ...cancellation, cancellationAuthority: "schedule" }, key).cancellationAuthority, "schedule");
  assertThrows(() => validateNightFlockCommand({ ...cancellation, customRoutineText: "never" }, key), Error, "Unexpected field");
  const receipt = {
    schemaVersion: 4, command: "publishSharedNightReceipt", partyID: challengeID, receiptID: userID,
    memberEpochID: challengeID, agreementID: challengeID, sourceID: challengeID, revision: 1, nightEndingDate: "2026-08-30",
    timeZoneIdentifier: "Asia/Singapore", outcome: "unknown", protectionEvidence: "unknown", idempotencyKey: key,
  };
  assertEquals(validateNightFlockCommand(receipt, key).command, "publishSharedNightReceipt");
  const { sourceID: _sourceID, ...missingSource } = receipt;
  assertThrows(() => validateNightFlockCommand(missingSource, key), Error, "Invalid sourceID");
  assertThrows(() => validateNightFlockCommand({ ...receipt, protectionMinutes: 12 }, key), Error, "Invalid protection evidence");
  assertThrows(() => validateNightFlockCommand({ ...receipt, outcome: "partlyCompleted" }, key), Error, "Actual start required");
  assertThrows(() => validateNightFlockCommand({ ...receipt, planID: challengeID }, key), Error, "Invalid plan binding");
  assertThrows(() => validateNightFlockCommand({ ...receipt, actualStart: "2026-08-30T15:00:00Z", terminalAt: "2026-08-30T14:55:00Z" }, key), Error, "Invalid receipt chronology");
  assertThrows(() => validateNightFlockCommand({ ...receipt, actualStart: "2026-08-30T15:00:00.100Z" }, key), Error, "Invalid actualStart");
});

Deno.test("shared-habits agreement accepts the separately consented v2 contract", () => {
  const v2 = validateNightFlockCommand({
    schemaVersion: 4, command: "acceptSharedHabitsAgreement", partyID: challengeID,
    agreementVersion: 2, timeZoneIdentifier: "Asia/Singapore", idempotencyKey: key,
  }, key);
  assertEquals(v2.agreementVersion, 2);
  assertThrows(() => validateNightFlockCommand({ ...v2, agreementVersion: 3 }, key), Error, "Invalid shared habits agreement");
});

Deno.test("shared-habits accepts the installed local-date object and sends one canonical RPC payload", async () => {
  const base = {
    schemaVersion: 4,
    command: "publishSharedHabit",
    partyID: challengeID,
    agreementID: challengeID,
    memberEpochID: challengeID,
    sourceID: challengeID,
    revision: 1780000000000,
    kind: "sleep",
    timeZoneIdentifier: "UTC",
    minutes: 420,
    evidence: "none",
    idempotencyKey: key,
  };
  const sent: Record<string, unknown>[] = [];
  const dependencies: NightFlockCommandDependencies = {
    authenticate: async () => ({ id: userID, isAnonymous: false }),
    execute: async (_callerID, payload) => {
      sent.push(payload);
      return { accepted: true };
    },
    deleteAccount: async () => {},
  };
  for (const localDate of ["2026-08-29", { year: 2026, month: 8, day: 29 }]) {
    const response = await handleNightFlockCommand(commandRequest({ ...base, localDate }), dependencies);
    assertEquals(response.status, 200);
  }
  assertEquals(sent.map((payload) => payload.localDate), ["2026-08-29", "2026-08-29"]);
  assertEquals(sent[0], sent[1]);
});

Deno.test("shared-habits rejects malformed local-date objects and requires a party for every shared-habits command", () => {
  const base = {
    schemaVersion: 4,
    command: "publishSharedHabit",
    partyID: challengeID,
    agreementID: challengeID,
    memberEpochID: challengeID,
    sourceID: challengeID,
    revision: 1780000000000,
    kind: "sleep",
    localDate: { year: 2026, month: 8, day: 29 },
    timeZoneIdentifier: "UTC",
    minutes: 420,
    evidence: "none",
    idempotencyKey: key,
  };
  for (const localDate of [
    { year: 2026, month: 2, day: 29 },
    { year: 2026, month: 8, day: 29.5 },
    { year: 2026, month: 8, day: 29, extra: true },
    { year: "2026", month: 8, day: 29 },
    { year: 0, month: 1, day: 1 },
  ]) {
    assertThrows(() => validateNightFlockCommand({ ...base, localDate }, key), Error, "Invalid localDate");
  }
  const partyCommands = [
    { command: "acceptSharedHabitsAgreement", agreementVersion: 1, timeZoneIdentifier: "UTC" },
    { command: "publishSharedHabit", agreementID: challengeID, memberEpochID: challengeID, sourceID: challengeID, revision: 1, kind: "sleep", localDate: "2026-08-29", timeZoneIdentifier: "UTC", minutes: 420, evidence: "none" },
    { command: "deleteSharedHabitHistory", sourceID: challengeID },
    { command: "migrateSharedHabits", agreementID: challengeID },
  ];
  for (const command of partyCommands) {
    assertThrows(() => validateNightFlockCommand({ schemaVersion: 4, ...command, idempotencyKey: key }, key), Error, "Invalid partyID");
  }
});

Deno.test("shared-habits state translates only SQL calendar-day fields for the installed Codable contract", async () => {
  const partyID = "30000000-0000-4000-8000-000000000001";
  const sqlSnapshot = {
    agreement: {
      agreementID: challengeID,
      memberEpochID: challengeID,
      acceptedAt: "2026-08-29T12:00:00Z",
      timeZoneIdentifier: "Asia/Singapore",
      firstEligibleSleepNight: "2026-08-31",
    },
    records: [
      { recordID: challengeID, localDate: "2026-08-30", activityDate: "2026-08-29", migratedAt: "2026-08-30T01:02:03Z" },
      { recordID: userID, localDate: null, activityDate: "2026-08-28", migratedAt: "2026-08-30T04:05:06Z" },
    ],
    nextCursor: "42|2026-08-28|member|record",
    snapshotRevision: 42,
    periods: [{ memberID: userID, kind: "sleep", period: "last7Nights", endingOn: "2026-08-30", availableNights: 7, coveredNights: 2, averageMinutes: 430, method: "eligibleMean" }],
  };
  const response = await handleNightFlockState(stateRequest({ schemaVersion: 4, scope: "habits", partyID }), {
    authenticate: async () => ({ id: userID, isAnonymous: false }),
    read: async () => sqlSnapshot,
  });
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.snapshot.agreement.firstEligibleSleepNight, { year: 2026, month: 8, day: 31 });
  assertEquals(body.snapshot.records[0].localDate, { year: 2026, month: 8, day: 30 });
  assertEquals(body.snapshot.records[0].activityDate, { year: 2026, month: 8, day: 29 });
  assertEquals(body.snapshot.records[1].localDate, null);
  assertEquals(body.snapshot.records[1].activityDate, { year: 2026, month: 8, day: 28 });
  assertEquals(body.snapshot.periods[0].endingOn, { year: 2026, month: 8, day: 30 });
  assertEquals(body.snapshot.agreement.acceptedAt, sqlSnapshot.agreement.acceptedAt);
  assertEquals(body.snapshot.records[0].migratedAt, sqlSnapshot.records[0].migratedAt);
  assertEquals(body.snapshot.nextCursor, sqlSnapshot.nextCursor);
  assertEquals(body.snapshot.snapshotRevision, sqlSnapshot.snapshotRevision);
});

Deno.test("legacy schemas and non-habits state snapshots pass through unchanged", async () => {
  const partyID = "30000000-0000-4000-8000-000000000001";
  const partySnapshot = { records: [{ localDate: "2026-08-30" }], timestamp: "2026-08-30T01:02:03Z" };
  const response = await handleNightFlockState(stateRequest({ schemaVersion: 4, scope: "party", partyID }), {
    authenticate: async () => ({ id: userID, isAnonymous: false }),
    read: async () => partySnapshot,
  });
  assertEquals(response.status, 200);
  assertEquals((await response.json()).snapshot, partySnapshot);
  assertEquals(validateNightFlockState({ schemaVersion: 3 }), { schemaVersion: 3 });
});

Deno.test("shared-night state scope is additive and keeps its date adaptation", async () => {
  const partyID = "30000000-0000-4000-8000-000000000001";
  const contract = validateNightFlockState({ schemaVersion: 4, scope: "sharedNights", partyID, cursor: "4|3" });
  assertEquals(contract.schemaVersion, 4);
  if (contract.schemaVersion === 4) assertEquals(contract.scope, "sharedNights");
  const snapshot = { agreement: null, records: [], nextCursor: null, snapshotRevision: 4, periods: [], sharedNightPlans: [{ nightEndingDate: "2026-08-30" }], sharedNightReceipts: [], sharedNightsNextCursor: "4|3", sharedNightsSnapshotRevision: 4 };
  const response = await handleNightFlockState(stateRequest({ schemaVersion: 4, scope: "sharedNights", partyID }), {
    authenticate: async () => ({ id: userID, isAnonymous: false }), read: async () => snapshot,
  });
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.snapshot.sharedNightPlans[0].nightEndingDate, { year: 2026, month: 8, day: 30 });
  assertEquals(body.snapshot.sharedNightsNextCursor, "4|3");
});

Deno.test("shared-habits keeps valid 25-hour sleep windows and bounds each kind", () => {
  const base = { schemaVersion: 4, command: "publishSharedHabit", partyID: challengeID, agreementID: challengeID, memberEpochID: challengeID, sourceID: challengeID, revision: 1780000000000, kind: "sleep", localDate: "2026-08-29", timeZoneIdentifier: "UTC", minutes: 780, evidence: "none", idempotencyKey: key };
  assertEquals(validateNightFlockCommand(base, key).command, "publishSharedHabit");
  assertThrows(() => validateNightFlockCommand({ ...base, minutes: 1501 }, key), Error, "Values outside bounds");
  assertThrows(() => validateNightFlockCommand({ ...base, outcome: "completed" }, key), Error, "Invalid sleep payload");
  assertThrows(() => validateNightFlockCommand({ ...base, kind: "windDown", minutes: 181 }, key), Error, "Values outside bounds");
  assertThrows(() => validateNightFlockCommand({ ...base, kind: "phoneAway", minutes: 30, evidence: "appRecorded", protectionMinutes: 31 }, key), Error, "Values outside bounds");
});

Deno.test("schema four membership sharing fields remain opt-in and exact", () => {
  const partyID = "30000000-0000-4000-8000-000000000001";
  const sourceEventID = "40000000-0000-4000-8000-000000000001";
  const statusID = "50000000-0000-4000-8000-000000000001";
  const v4Key = "1".repeat(64);
  assertEquals(validateNightFlockCommand({
    schemaVersion: 4, command: "publishActivity", sourceEventID, kind: "windDown", outcome: "completed",
    startedAt: "2026-08-25T12:00:00Z", endedAt: "2026-08-25T12:20:00Z", windDownMinutes: 20,
    phoneAwayMinutes: 0, statusRevision: 1, sharingScope: "membership", idempotencyKey: v4Key,
  }, v4Key).sharingScope, "membership");
  assertEquals(validateNightFlockCommand({
    schemaVersion: 4, command: "react", partyID, activityID: sourceEventID, cheer: "pawPrint",
    sharingScope: "membership", idempotencyKey: v4Key,
  }, v4Key).sharingScope, "membership");
  assertEquals(validateNightFlockCommand({
    schemaVersion: 4, command: "cheerMember", partyID, memberID: userID, statusID, cheer: "pawPrint",
    idempotencyKey: v4Key,
  }, v4Key).statusID, statusID);
  assertThrows(() => validateNightFlockCommand({
    schemaVersion: 4, command: "react", partyID, activityID: sourceEventID, cheer: "pawPrint",
    sharingScope: "round", idempotencyKey: v4Key,
  }, v4Key), Error, "Invalid sharingScope");
  assertThrows(() => validateNightFlockCommand({
    schemaVersion: 4, command: "cheerMember", partyID, memberID: userID, statusID: "not-a-uuid", cheer: "pawPrint",
    idempotencyKey: v4Key,
  }, v4Key), Error, "Invalid statusID");
});

Deno.test("schema four profile avatar is additive and catalogue-bound", () => {
  const v4Key = "2".repeat(64);
  const profile = {
    schemaVersion: 4, command: "updatePublicProfile", expectedRevision: 1,
    displayName: "Moss", nameSelectionKind: "migration",
    skinToneID: "warm", hairStyleID: "waves", shepherdOutfitID: "none",
    shepherdAccessoryID: "none", ollieOrnamentID: "none",
    featuredSheepDefinitionID: "none", pastureThemeID: "pasture_meadow",
    idempotencyKey: v4Key,
  };
  assertEquals(
    validateNightFlockCommand(profile, v4Key).avatarID,
    undefined,
  );
  assertEquals(
    validateNightFlockCommand({ ...profile, avatarID: "sheep:juniper" }, v4Key).avatarID,
    "sheep:juniper",
  );
  assertThrows(
    () => validateNightFlockCommand({ ...profile, avatarID: "sheep:not-a-sheep" }, v4Key),
    Error,
    "Invalid avatarID",
  );
});

Deno.test("schema four invitation envelope round-trips and never survives response redaction", async () => {
  const keyMaterial = Uint8Array.from({ length: 32 }, (_, index) => index + 1);
  const invitation = await createInvitation(keyMaterial, 1);
  assert(/^[A-HJ-NP-Z2-9]{12}$/.test(invitation.shortCode));
  assertEquals(await decryptInvitation(invitation.envelope, keyMaterial), invitation.shortCode);
  const safe = redactInvitationResult({ accepted: true, inviteEnvelope: invitation.envelope, inviteDigest: invitation.digest });
  assertEquals(safe, { accepted: true });
  const serialized = JSON.stringify(safe);
  assert(!serialized.includes(invitation.shortCode));
  assert(!serialized.includes(invitation.digest));
  assert(!serialized.includes(invitation.envelope.inviteCiphertext));
});

Deno.test("schema four typed failures and completion logging stay secret-free", () => {
  assertEquals(classifyNightFlockError(new Error("max_parties")).code, "max_parties");
  assertEquals(classifyNightFlockError(new Error("host_cannot_leave")).code, "host_cannot_leave");
  assertEquals(classifyNightFlockError(new Error("stale_revision")).code, "stale_revision");
  assertEquals(classifyNightFlockError(new Error("name_change_limit")).code, "name_change_limit");
  assertEquals(classifyNightFlockError(new Error("client_upgrade_required")).status, 426);
  const record = nightFlockCompletionLogRecord("night-flock-command", "cccccccc-cccc-4ccc-8ccc-cccccccccccc", "0-49ms", {
    schemaVersion: 4, command: "retrieveInvite", inviteCiphertext: "secret", inviteNonce: "secret", shortCode: "ABCDEFGHJKLM",
  }, 200, null);
  assertEquals(record.schemaVersion, 4);
  assert(!JSON.stringify(record).includes("ABCDEFGHJKLM"));
  assert(!JSON.stringify(record).includes("secret"));
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

function stateRequest(body: Record<string, unknown>): Request {
  return new Request("http://local", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

Deno.test("public head shape and update cheer acknowledgement stay strictly allowlisted", () => {
  const profile = { idempotencyKey: key, schemaVersion: 4, command: "updatePublicProfile", expectedRevision: 0,
    nameSelectionKind: "initial", displayName: "Clover", skinToneID: "warm", hairStyleID: "long",
    shepherdOutfitID: "shepherd_moon_coat", shepherdAccessoryID: "none", ollieOrnamentID: "none",
    featuredSheepDefinitionID: "none", pastureThemeID: "pasture_meadow" };
  for (const headShapeID of ["pear", "round", "boxy", "triangular"]) {
    assertEquals(validateNightFlockCommand({ ...profile, headShapeID }, key).headShapeID, headShapeID);
  }
  assertThrows(() => validateNightFlockCommand({ ...profile, headShapeID: "future" }, key));
  assertEquals(validateNightFlockCommand(profile, key).headShapeID, undefined);
  const ack = { idempotencyKey: key, schemaVersion: 4, command: "acknowledgeUpdateCheer", partyID: userID, reactionID: userID };
  assertEquals(validateNightFlockCommand(ack, key).command, "acknowledgeUpdateCheer");
  assertThrows(() => validateNightFlockCommand({ ...ack, seenAt: "2026-09-09" }, key));
  assertThrows(() => validateNightFlockCommand({ ...ack, recipientMemberID: userID }, key));
});
