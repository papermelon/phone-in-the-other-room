# Wind Down automatic-start and late-reopen repair

17 September 2026 · Local source repair; not distributed.

The [21 September follow-up](wind-down-loading-repair-2026-09-21.md) fixes ordinary
account synchronization replacing a due occurrence and moves its control to Edit Wind Down.

The founder reported automatic Wind Down failing across devices, with selected apps
accessible throughout the night. The supplied receipt showed 21h 12m after reopening
late. These establish symptoms, not the installed build or individual monitor failures.

## Source defects repaired

- Cold restoration and foreground completion wrote the reconciliation time into
  `endedAt`. Completion now uses `plannedEndAt`; receipts also bound older saved
  timestamps by the plan without rewriting settled Farm rewards.
- Automatic start lacked a foreground boundary timer. One timer now invokes the
  existing coordinator admission path at the saved start.
- Missing automatic schedules are reinstalled on recovery. A saved schedule whose
  run has already settled advances instead of materializing that run again.
- Expired automatic recovery discarded and reinstalled the successor installed
  synchronously by completion, risking a second installation failure. It now
  consumes only its own schedule identity and preserves the installed successor.
- Future-monitor reinstallation failures now clear the ready schedule and retain
  the existing protection-repair state rather than being ignored.
- Unchanged automatic monitors now retain their identity. The installer checks both
  registrations, repairs missing registrations, stops replaced registry monitors,
  and removes orphaned registry names from older cancellations.
- Preparing the ordinary linked Morning could replace the continuous parent monitor.
  A Morning inside its parent's installed interval now preserves that monitor and
  Brief Access identity. Independently rescheduled Mornings still install separately.

Current permission/selection is refreshed before automatic admission. Scheduling and
timer completion remain distinct from observed shielding evidence. No production
operation, archive, or upload is included.

## Validation

Evidence directory: `tmp/wind-down-repair-20260916/`. Added unit cases cover
late/legacy receipt bounds, actual early endings, automatic-start boundaries,
settled-run replay, and Morning containment/identity. The isolated Screenbook probe
exercises cold/warm coordinator completion, successor preservation, installation
failure, and the production installer's reuse, repair, cleanup, and rollback with spies.

- Final full Simulator build passed:
  `xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator'`.
  See `build-final.log`.
- Full unit suite passed: 1,059 tests, zero failures, using
  `xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=71CF8F3E-9E9A-449D-93A8-B73F64869A5E' -resultBundlePath tmp/wind-down-repair-20260916/tests.xcresult`.
- All 18 isolated recovery-probe cases passed on Recovery QA
  `329535CB-D901-434D-BE9D-7BA64A3BE900`; see `recovery-probe.json` and `readiness.json`.
  Monitor operations use spies; this does not establish actual platform shielding.
- The production early-ending receipt was inspected at accessibility text size.
  Its duration stacks without clipping and its accessibility label reads
  “Wind Down timer: 5h 38m”; see `receipt-accessibility.png`. The first capture
  (`receipt.png`) was obscured by a test-Simulator notification prompt and is not
  layout acceptance evidence. Notification access was declined in that disposable
  Simulator. A physical VoiceOver session was not performed.
- Changed-file whitespace checks passed. No project regeneration was needed.

## Signed-device acceptance

On each affected phone, install the repaired build and open it to reconcile the saved
schedule. Check selected-app access before start, at start with the app backgrounded
and terminated, overnight, and after the morning boundary. Repeat with the app open
across start, after dismissing a receipt, and after repeated schedule edits. Reopen in
the evening and confirm bounded receipt duration and the next installed start.
Include a second unattended night, revoked permission, empty selection, Brief Access,
and NFC emergency exit.

The Simulator cannot prove callback delivery or actual blocking. Consecutive
unattended recurrence, non-daily routines, and multiple nights of history reconstruction
still need explicit evidence: the legacy automatic snapshot uses daily repetition
with a single saved occurrence.
