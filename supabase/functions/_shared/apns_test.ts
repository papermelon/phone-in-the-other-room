import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  ACTIVITYKIT_REFERENCE_EPOCH_SECONDS,
  COMPLETION_DISMISSAL_SECONDS,
  activityKitReferenceSeconds,
  buildLiveActivityEndPayload,
} from "./apns.ts";

const event = {
  plannedEndAt: "2026-08-08T15:00:00.000Z",
  phase: null,
  bedtimeAt: "2026-08-08T15:00:00.000Z",
  wakeAt: "2026-08-08T23:00:00.000Z",
  morningQuietEndsAt: "2026-08-08T23:30:00.000Z",
  eveningActivityTitle: "Read",
  morningActivityTitle: "Open curtains",
};

Deno.test("normal terminal payload includes the full compatible completed state", () => {
  const now = new Date("2026-08-08T14:59:58.000Z");
  const payload = buildLiveActivityEndPayload(event, now);

  assertEquals(payload.aps.event, "end");
  assertEquals(
    payload.aps["dismissal-date"],
    Math.floor(now.getTime() / 1000) + COMPLETION_DISMISSAL_SECONDS,
  );
  assertEquals(payload.aps["content-state"], {
    plannedEndAt: activityKitReferenceSeconds(event.plannedEndAt),
    isComplete: true,
    phase: "complete",
    terminalStatus: "completed",
    bedtimeAt: activityKitReferenceSeconds(event.bedtimeAt),
    wakeAt: activityKitReferenceSeconds(event.wakeAt),
    morningQuietEndsAt: activityKitReferenceSeconds(event.morningQuietEndsAt),
    eveningActivityTitle: "Read",
    morningActivityTitle: "Open curtains",
  });
});

Deno.test("normal completion dismissal is future-dated by roughly fifteen minutes", () => {
  const now = new Date("2026-08-08T14:59:58.900Z");
  const payload = buildLiveActivityEndPayload(event, now);

  assert(payload.aps["dismissal-date"] > Math.floor(now.getTime() / 1000));
  assertEquals(
    payload.aps["dismissal-date"] - Math.floor(now.getTime() / 1000),
    COMPLETION_DISMISSAL_SECONDS,
  );
});

Deno.test("early cancellation state is factual and never presented as completed", () => {
  const now = new Date("2026-08-08T14:59:58.000Z");
  const payload = buildLiveActivityEndPayload(
    { ...event, terminalStatus: "endedEarly" },
    now,
  );

  assertEquals(payload.aps["dismissal-date"], Math.floor(now.getTime() / 1000));
  assertEquals(payload.aps["content-state"].isComplete, false);
  assertEquals(payload.aps["content-state"].phase, null);
  assertEquals(payload.aps["content-state"].terminalStatus, "endedEarly");
});

Deno.test("ActivityKit dates use Codable's seconds since the 2001 reference epoch", () => {
  const date = "2026-08-08T15:00:00.000Z";
  assertEquals(
    activityKitReferenceSeconds(date),
    Date.parse(date) / 1000 - ACTIVITYKIT_REFERENCE_EPOCH_SECONDS,
  );
});
