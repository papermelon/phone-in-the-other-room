# Campfire live-presence repair — 13 September 2026

Founder device feedback: the fire remained lit with no active sessions; an inactive party member
remained visible and overlapped the active member’s temporary seat. The error appeared while
opening/refreshing Slumber Party. Source repair follows this clarified product intent.

## Diagnosis and implementation

The prior scene rendered the entire membership list and a permanent fire. It moved active members
to separate fixed anchors without reserving space against inactive saved positions. Membership
was visually indistinguishable from presence. This was a presentation defect, not evidence that
the other person had started a run.

- Live sessions is the default. Its figures come from exactly the current session rows used by
  the activity labels. Zero current sessions means zero figures and no fire.
- Idle members, visiting sheep, the earned lantern and saved arrangements remain in an explicitly
  labelled Shared meadow view. Active seats never write to those positions. Save feedback updates
  the existing scene controller instead of replacing view identity and resetting the chosen view.
- One through eight participants have distinct seats, with bounded/truncated visual name labels;
  full names remain in the accessible activity rows. Activity and planned-end labels stay visible.
- Realtime is supplemented by one canonical detail refresh every 20 seconds while this view is
  foregrounded and visible. The existing per-party request guard coalesces concurrent signals.
  Background/disappear cancels the cadence; no session heartbeat or protection transition changes.
- Stale/unconfirmed observations never show live figures. Beginning a retry after stale data does
  not itself restore presence; a successful canonical response is required.
- Service-unavailable copy now says the server could not be reached. Connection/relay and gateway
  errors preserve the actual outgoing X-Request-ID instead of inventing another support ID.

## Error investigation limits

The screenshot’s `6bb51f1b-a8f1-4014-afa9-0c15ca692cc5` did not match the queried recent log output.
The shipped service maps URL/relay failures and unstructured 5xx responses to service_unavailable;
its former fallback could generate a replacement request ID. This establishes the meaning of the
banner, but does not establish the exact underlying error for this occurrence. It is not a report
that any member ended their session. No production outage or specific SQL failure is claimed.

Read-only production inspection confirmed all three expected tables (party signals, statuses,
reactions) are in `supabase_realtime`. No member rows were queried and no backend writes/deployment
were performed. The existing deployed campfire contract is sufficient for this native repair.
The logs dashboard became unavailable during follow-up inspection, and the Mac was locked during
native interaction inspection. No raw hosted logs or member data are included here.

## Validation

- Full Simulator app build: `build-final.log`.
- Full native suite: `tests-accepted.log`; final outcome is recorded in `validation.json`.
- Meaningful regressions cover inactive-member exclusion, removal on expiry/stale data, confirmed
  observation rules, one-through-eight nonoverlapping participant bounds, and outgoing request-ID
  retention after an unstructured gateway failure. Existing consent, epoch, owner and outbox tests
  remain in the full suite.
- The first geometry test run caught four-person spacing and an out-of-bounds upper seat. Both
  were repaired before the successful final geometry suite. An isolated-fixture Swift exclusivity
  error was also corrected before successful builds.
- Native iPhone SE captures use unique disposable fixture defaults and disable external services:
  [empty](empty-party.png), [one active](campfire-solo.png), [two active](active-party.png),
  [eight active](large-party.png), [stale](stale-party.png), [expired](campfire-expired.png), and
  [large text](campfire-solo-large.png). Source/capture command: [capture-native.py](capture-native.py).
  Large-text inspection prompted a vertical Sharing header; labels retain the full accessible name.
- Source whitespace and changed-document links checked. Physical taps, dragging, VoiceOver speech,
  realtime cross-device timing, early-end offline delivery and actual shielding remain unverified.

No archive, TestFlight upload, commit, push or new backend deployment was performed in this repair.
An updated native build is required before the founder will see these changes on the phone.
