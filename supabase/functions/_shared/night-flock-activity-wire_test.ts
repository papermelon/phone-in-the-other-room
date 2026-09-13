import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { validateNightFlockCommand } from "./night-flock.ts";
import { handleNightFlockCommand } from "./night-flock-handlers.ts";

const key = "a".repeat(64);
const reference = Date.UTC(2001, 0, 1);
const startedAt = "2026-09-09T16:00:00.000Z";
const endedAt = "2026-09-09T16:20:00.000Z";
const activity = {
  schemaVersion: 4 as const, command: "publishActivity", idempotencyKey: key,
  sourceEventID: "10000000-0000-4000-8000-000000000001",
  kind: "windDown", outcome: "completed", sharingScope: "membership",
  startedAt: (Date.parse(startedAt) - reference) / 1000,
  endedAt: (Date.parse(endedAt) - reference) / 1000,
  windDownMinutes: 20, phoneAwayMinutes: 0, statusRevision: 3,
};

Deno.test("shipped Foundation dates reach SQL as ISO, identically across retries", async () => {
  const received: unknown[] = [];
  for (let i = 0; i < 2; i++) {
    const response = await handleNightFlockCommand(new Request("https://example.invalid", {
      method: "POST", headers: {"Content-Type": "application/json", "Idempotency-Key": key},
      body: JSON.stringify(activity),
    }), {
      deleteAccount: async () => { throw new Error("unexpected deletion"); },
      authenticate: async () => ({id: activity.sourceEventID, isAnonymous: false}),
      execute: async (_id, payload) => { received.push(payload); return {accepted: true}; },
    });
    assertEquals(response.status, 200);
  }
  assertEquals(received[0], {...activity, startedAt, endedAt});
  assertEquals(received[0], received[1]);
});

Deno.test("ISO activity payloads and their idempotency hashes remain unchanged", () => {
  const body = {...activity, startedAt, endedAt};
  assertEquals(validateNightFlockCommand({...body}, key), body);
});

Deno.test("status accepts Foundation reference seconds without changing scope", () => {
  const body = {schemaVersion: 4 as const, command: "publishStatus", idempotencyKey: key,
    sourceEventID: activity.sourceEventID, status: "windDownCompleted", revision: 3,
    sharingScope: "membership", observedAt: activity.endedAt};
  assertEquals(validateNightFlockCommand({...body}, key), {...body, observedAt: endedAt});
});

Deno.test("timestamp compatibility preserves chronology, type, privacy and duration checks", () => {
  for (const value of [null, true, {}, [], Number.NaN, Infinity, 1e30, "not a date"]) {
    assertThrows(() => validateNightFlockCommand({...activity, startedAt: value}, key));
  }
  assertThrows(() => validateNightFlockCommand({...activity, endedAt: activity.startedAt - 1}, key));
  assertThrows(() => validateNightFlockCommand({...activity, privateFarm: {}}, key));
  assertThrows(() => validateNightFlockCommand({...activity, windDownMinutes: 181}, key));
  assertThrows(() => validateNightFlockCommand({...activity}, "b".repeat(64)));
});
