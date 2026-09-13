# Protection repair and Slumber Party entry

7 September 2026 · Local source changes; not distributed to TestFlight.

The founder's screenshots show an automatic Wind Down repair warning whose button
opened generic protection information, and Slumber Party stopped on a redacted loading
card. The screenshots do not establish the underlying iOS or server failure.

## Confirmed source defects and repair

- Settings' repair button opened `AppShieldExplainerSheet`. It now opens the existing
  Screen Time repair view with an automatic-start context, permission/selection controls,
  an explicit scheduling retry, and the resulting schedule or repair state.
- A persisted automatic-repair marker obscured current missing authorization/selection.
  Current readiness now names the actionable prerequisite before historical failure copy.
- Automatic scheduling ignored the monitor-installation result and saved a ready schedule
  even on failure. A future monitor must return `scheduled` before the automatic timer and
  notifications are saved. Failure cancels the attempt and preserves the repair marker.
- Slumber Party entry could set loading, then return when the matching account Farm had
  not loaded. The hub now shows account connection/recovery controls in that state.
  Entry cleanup leaves loading when no operation remains, and an overlapping entry request
  is coalesced so account activation can trigger a fresh read after the old attempt finishes.
- The hub no longer fires two independent initial reads. Entry loads the party list before
  processing ordinary queued sharing work; destructive-intent reconciliation keeps its
  existing order. Pull to refresh retries entry. Initial loading retains readable text.

The verified account UUID / committed Farm owner fence remains in place. These changes do
not sign anyone in, enroll declined sync consent, alter sharing agreements, or deploy a
backend change.

## Validation and remaining evidence

Validation logs and screenshots are under `tmp/device-repair-review/`.

- Final full iOS Simulator app build passed using the repository merge-gate command.
- Full unit suite passed: 878 tests, zero failures, using iPhone 17e simulator
  `71CF8F3E-9E9A-449D-93A8-B73F64869A5E`. This includes the new monitor-outcome admission
  and repair-prerequisite priority cases, plus existing account-owner fence coverage.
  Final follow-up edits were view/copy-only and passed the subsequent full build.
- Changed-file whitespace checks passed. An initial screenshot-fixture compile error was
  corrected before the successful suite and final build.
- Visual acceptance is blocked: the isolated Recovery QA simulator stalled at app launch;
  a second booted iPhone 17e also timed out after 35 seconds. The captured image is the
  simulator Home screen, not acceptance evidence. Dynamic Type and VoiceOver remain
  unverified. Debug fixture flags on `iphone.home.configured.default` are
  `-screenbook-protection-repair` and `-screenbook-slumber-entry`; add
  `-screenbook-slumber-loading` to inspect the readable in-flight state.
- The suite does not exercise the complete live account/network entry flow. No backend or
  founder-account operation was performed.

Physical-device acceptance remains: restore Screen Time access, save/review the opaque selection, retry installation, and confirm the next
scheduled start on the affected phone. Exercise Slumber Party with a delayed account Farm
load, successful recovery, and a second member. Correlate any remaining network rejection
with the installed build and the failed request's support reference before claiming that
live sharing is repaired.
