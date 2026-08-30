# Home / Phone Away implementation report

Date: 2026-08-27

Status: F1–F10 corrections implemented in the requested execution order. This candidate is
ready for another Sol review; this report does not claim that the prior fix-first verdict has
changed.

## Candidate, baseline, and preservation

Exact worktree:

`/Users/ngawangchime/Desktop/Developer Projects/Phone in the Other Room`

- Branch: `codex/night-flock-mvp`
- HEAD: `cce766d1840a850a23d5c47e4a542203c26a728b`
- `origin/codex/night-flock-mvp`: `cce766d1840a850a23d5c47e4a542203c26a728b`
- HEAD subject: `Fix Slumber Party Apple account recovery`
- The requested handoff, accepted Home/Phone Away direction, `AGENTS.md`, and Sol's review were read before editing.
- Sol's review baseline was 664 XCTest cases / 0 failures and 19 Deno tests / 0 failures, but its verdict was fix-first.
- Correction-start status: 54 porcelain entries, including inherited tracked edits and untracked files.
- Correction-start snapshot: `/tmp/counting-sheep-sol-corrections-start.7mN4kP/`
- Snapshot hashes: status `08d2b5a51d0213e124a325a035e14d1f31a4db56b050021e1b3eeb9460230eeb`; tracked patch `3b80198065bd6917544934ede97b007e128133a484c6af99ba78659d63982a29`; untracked archive `5ae17b78a45c5b7ab9ef750364c2d2d99d52aee29d7c63b1c0711f268320385d`.
- Final status: 72 porcelain entries, recorded at `/tmp/counting-sheep-sol-corrections-final2-status.txt`.
- `git diff --check`: exit 0.
- No reset, checkout, cleanup, simulator erase, commit, push, merge, deploy, or upload was performed.

The full inherited status was preserved. The paths newly dirty or newly untracked after the
correction-start snapshot are:

```text
PhoneInTheOtherRoomApp/Design/PixelComponents.swift
PhoneInTheOtherRoomApp/Proximity/FocusSessionCoordinator.swift
PhoneInTheOtherRoomApp/Screenbook/ScreenbookFixtures.swift
PhoneInTheOtherRoomApp/Services/NightFlockOutboxService.swift
PhoneInTheOtherRoomApp/Services/QuietTimeShieldingService.swift
PhoneInTheOtherRoomApp/Views/Components/OllieRitualView.swift
PhoneInTheOtherRoomApp/Views/Components/WindDownRoutineSequenceCard.swift
PhoneInTheOtherRoomApp/Views/Onboarding/OnboardingFlowView.swift
PhoneInTheOtherRoomApp/Views/Onboarding/OnboardingRecommendationStepView.swift
PhoneInTheOtherRoomDeviceActivityMonitor/QuietTimeDeviceActivityMonitor.swift
Shared/FocusSessionStartResult.swift
Shared/HomeReceiptRouting.swift
Shared/NightFlockV4Outbox.swift
Shared/NightWatch.swift
Shared/QuietTimeShieldSchedule.swift
Tests/HomeReceiptRoutingTests.swift
Tests/QuietTimeShieldScheduleTests.swift
```

Correction edits also touched baseline-dirty files, notably
`PhoneInTheOtherRoomApp/ViewModels/FocusRunViewModel.swift`,
`PhoneInTheOtherRoomApp/Views/ActiveRunView.swift`,
`PhoneInTheOtherRoomApp/Views/ScreenFreeMorningView.swift`,
`PhoneInTheOtherRoomApp/Views/Components/WindDownGuideCard.swift`,
`PhoneInTheOtherRoomApp/Views/PixelHomeDashboard.swift`,
`PhoneInTheOtherRoomApp/ViewModels/NightFlockViewModel+V4.swift`,
`Tests/NightFlockV4Tests.swift`, `Tests/WindDownGuidanceTests.swift`, and
`docs/ARCHITECTURE.md`. All other inherited edits remain in place. `xcodegen generate` was used
after source changes; `project.yml`, targets, entitlements, signing, and tab structure were not
changed. The generated `project.pbxproj` was not hand-edited.

## Per-finding resolution

### F1 — session ownership and Home routing

`Shared/HomeReceiptRouting.swift` now gives an active Screen-Free Morning and an active run
priority over a scheduled/deferred ordinary Morning. A terminal Wind Down receipt also remains
above a separate deferred Morning. The active Screenbook scenario now calls the production
`FocusSessionCoordinator.start(...)` path and materializes the ordinary Morning instead of
assigning a run directly.

Evidence:

- `Tests/HomeReceiptRoutingTests.swift`: live Wind Down vs scheduled Morning and terminal receipt priority coverage.
- `/tmp/counting-sheep-sol-corrections-final-boundary-probe.log`: `F1 route: activeWindDown` and `Boundary probe: PASS`.
- Screenbook active capture: `tmp/screenbook/current/screens/iphone.home.active-wind-down.default.png`.

### F2 — ordinary Morning terminal integration

`FocusSessionCoordinator.finishScreenFreeMorning(...)` ends the linked ordinary parent through
the same authorized terminal transition, then clears the parent barrier and settles the Morning.
NFC still requires the tag and the emergency path still uses its existing challenge. Ordinary
early exit before the Morning window is treated as skipped; an exit after the window begins
settles actual elapsed Morning minutes. Explicit early-wake start-now/defer/skip choices remain
distinct, with the explicit defer/start-now occurrence preserved rather than accidentally
reclassified.

Evidence: coordinator boundary implementation in
`PhoneInTheOtherRoomApp/Proximity/FocusSessionCoordinator.swift`, full XCTest and QA XCTest
passes, plus Screenbook production-start materialization. NFC, emergency authorization, and
ordinary natural-morning behavior still need physical-device interaction testing.

### F3 — supported protection scheduling

`Shared/QuietTimeShieldSchedule.swift` adds a monitoring policy that pads only the
`DeviceActivitySchedule` interval to Apple's 15-minute minimum. The desired ManagedSettings
barrier and its actual end remain unchanged; a warning callback reconciles short sessions at the
desired end. Existing 5, 10, 15, and 30-minute Phone Away choices remain available, with the
existing 30-minute default. A delayed start is rebased to the remaining window and a window with
no time remaining is rejected. A failed monitor remains a failure/repair state and is never
presented as ready.

Evidence:

- `Tests/QuietTimeShieldScheduleTests.swift`: 5/10/15/30-minute padding, delayed confirmation, and no-time-remaining cases.
- `PhoneInTheOtherRoomApp/Services/QuietTimeShieldingService.swift` and
  `PhoneInTheOtherRoomDeviceActivityMonitor/QuietTimeDeviceActivityMonitor.swift`: supported
  registration and actual-end warning reconciliation.
- Debug and SlumberPartyQA builds passed with the extensions compiled.

No new product maximum was introduced. Simulator execution cannot validate Apple's live Family
Controls monitor acceptance, callback timing, or ManagedSettings behavior; those remain physical
phone checks.

### F4 — final start admission

`Shared/FocusSessionStartResult.swift` makes coordinator admission explicit. The coordinator
rejects an active run or active Screen-Free Morning before reset/materialization. The view model
consumes a scheduled source, publishes Slumber Party status, marks NFC verification, cancels
reminders, and schedules notifications/usage monitoring only after `.started`. A stale NFC or
confirmation rejection leaves the current session intact and rolls back any temporary start
transaction.

Evidence:

- `PhoneInTheOtherRoomApp/Proximity/FocusSessionCoordinator.swift` is the production admission boundary.
- `PhoneInTheOtherRoomApp/ViewModels/FocusRunViewModel.swift` gates all post-admission effects.
- The active Screenbook fixture exercises `coordinator.start(...)`, not a direct run assignment.
- `/tmp/counting-sheep-sol-corrections-final-boundary-probe.log` and both 675-test suites pass.

The confirmation/NFC race still needs an interactive physical-device check, including app
backgrounding/termination while the prompt or tag read is pending.

### F5 — durable V4 outbox acknowledgement

V4 status records now acknowledge and increment attempts by the exact sent identity:
`sourceEventID + revision + idempotencyKey`. A newer revision survives an older response or
failure, account-generation fencing remains intact, and persisted records survive service
restart. No backend state was changed and nothing was deployed.

Evidence:

- `Shared/NightFlockV4Outbox.swift`, `PhoneInTheOtherRoomApp/Services/NightFlockOutboxService.swift`, and `PhoneInTheOtherRoomApp/ViewModels/NightFlockViewModel+V4.swift`.
- `Tests/NightFlockV4Tests.swift`: revision acknowledgement/failure and restart coverage.
- `/tmp/counting-sheep-sol-corrections-final-boundary-probe.swift` compiles and exercises the
  actual app `NightFlockOutboxService`; `/tmp/counting-sheep-sol-corrections-final-boundary-probe.log`
  reports `revision 2 survives old ack/failure and restart` and `Boundary probe: PASS`.

### F6 — purpose refresh

Purpose is kept private and separate from future preferences. The view model reloads the
occurrence-scoped App Group cue after successful start/restore, phase and Morning occurrence
transitions, terminal/reset, and foreground reconciliation through the coordinator's
`onStateReconciled` callback. The active render path does not poll UserDefaults. Registry
occurrence, revision, and epoch fence stale values.

Evidence: `FocusRunViewModel.swift`, `FocusSessionCoordinator.swift`, existing purpose/registry
tests, 675 XCTest passes, and Debug/QA builds. Natural clock transition and return/restore on a
physical phone remain open.

### F7 — active-page content

`WindDownRoutineSequenceCard` renders the actual frozen selected evening or morning optional
sequence for the primary Wind Down in its matching phase. Screen-Free Morning shows its linked
morning sequence and its NFC finish/emergency affordances. Overnight and Phone Away do not show
bedtime checklists or source discovery. The active Screenbook capture visibly includes the
optional sequence card and the honest “An invitation, not a checklist” framing.

Evidence:

- `PhoneInTheOtherRoomApp/Views/ActiveRunView.swift`
- `PhoneInTheOtherRoomApp/Views/ScreenFreeMorningView.swift`
- `PhoneInTheOtherRoomApp/Views/Components/WindDownRoutineSequenceCard.swift`
- `tmp/screenbook/current/screens/iphone.home.active-wind-down.default.png`

The Screenbook render is production-view evidence, not interaction proof; physical phase
transitions and accessibility interaction remain to be tested.

### F8 — occasional guidance and deep links

Home guidance now has an explicit persisted display policy keyed by idea, day, and routine
context, with a three-day repeat interval and consistent persisted dismissal handling. A displayed
compact idea links directly to its own `WindDownGuidanceDetailView`; the full local source library
remains available from the secondary “About these ideas and sources” route. The three-day cadence
is an implementation assumption for Sol/founder review, not a new product prohibition.

Evidence: `Shared/WindDownGuidanceSources.swift`, `FocusRunViewModel.swift`,
`WindDownGuideCard.swift`, `WindDownGuidanceDetailView.swift`, guidance XCTest coverage, and
Screenbook Home capture. The standard Home capture also shows the personal Wind Down card,
secondary Phone Away, and repair state without replacing the ritual with a permanent explanatory
card.

### F9 — honest mappings and context ownership

Only mappings with an honest semantic match remain automatic. Caffeine timing and heavy-meal
timing do not invent a “prepare a bag” action; unrelated routine activities do not receive
misleading guidance IDs. Onboarding passes the live `OnboardingDraft` into the library/detail
route, while saved-routine detail uses the view model mutation path. Replacement and exact
selected activity/title behavior are covered at the Shared boundary.

Evidence:

- `Shared/WindDownGuidanceSources.swift` and `Shared/NightWatch.swift`.
- `PhoneInTheOtherRoomApp/Views/Onboarding/OnboardingFlowView.swift` and
  `OnboardingRecommendationStepView.swift`.
- `PhoneInTheOtherRoomApp/Views/Components/WindDownGuidanceDetailView.swift`.
- `Tests/WindDownGuidanceTests.swift` and the full 675-test runs.

### F10 — Home mascot/layout and bridge

Home now uses `HomeOllieIdleView(presentation: .homeCompact)` with a 54-point canvas, so the
164-point mascot is scaled inside a matching wrapper rather than clipped by it. The Home CTA
subtitle has a minimum scale factor for narrow widths. The personal Wind Down remains primary,
Phone Away remains secondary, and the configured Home surface has one prominent Slumber Party
bridge; the first-run guide's separate contextual stage is not an additional Home bridge.

Evidence:

- `PhoneInTheOtherRoomApp/Views/Components/OllieRitualView.swift`
- `PhoneInTheOtherRoomApp/Views/PixelHomeDashboard.swift`
- `PhoneInTheOtherRoomApp/Design/PixelComponents.swift`
- Standard iPhone 17 Screenbook Home capture: `tmp/screenbook/current/screens/iphone.home.configured.default.png`.
- Accessibility-size SE captures: `/tmp/counting-sheep-sol-corrections-se-iphone.home.configured.default-recapture.png` and `/tmp/counting-sheep-sol-corrections-se-iphone.home.active-wind-down.default-recapture.png`.

The SE captures show legible large text and scrollable continuation, but they are not VoiceOver
or tap interaction proof. The active capture includes a simulator notification permission sheet;
the underlying production active surface and routine card are visible.

## Validation commands and actual results

The iPhone 15 simulator was not available. The available iOS simulator used for XCTest was
`iPhone 17e`.

| Command / lane | Exit | Result / artifact |
|---|---:|---|
| `xcodegen generate` | 0 | `/tmp/counting-sheep-sol-corrections-final2-xcodegen.log` |
| `xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator'` | 0 | `BUILD SUCCEEDED`; `/tmp/counting-sheep-sol-corrections-final2-build.log` |
| `xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,name=iPhone 17e'` | 0 | 675 tests, 0 failures; `/tmp/counting-sheep-sol-corrections-final2-tests.log`; `/tmp/counting-sheep-sol-corrections-final2-tests.xcresult` |
| `sh scripts/validate-slumber-party-qa.sh` | 0 | QA flag/compiler-condition validation; `/tmp/counting-sheep-sol-corrections-final2-qa-validation.log` |
| `xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoomSlumberPartyQA -configuration SlumberPartyQA -destination 'generic/platform=iOS Simulator'` | 0 | `BUILD SUCCEEDED`; `/tmp/counting-sheep-sol-corrections-final2-qa-build.log` |
| `xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoomSlumberPartyQA -configuration SlumberPartyQA -destination 'platform=iOS Simulator,name=iPhone 17e'` | 0 | 675 tests, 0 failures; `/tmp/counting-sheep-sol-corrections-final2-qa-test.log`; `/tmp/counting-sheep-sol-corrections-final2-qa-tests.xcresult` |
| `npx --yes deno check supabase/functions/night-flock-command/index.ts supabase/functions/night-flock-state/index.ts` | 0 | `/tmp/counting-sheep-sol-corrections-final2-deno-check.log` |
| `npx --yes deno test --allow-env supabase/functions/_shared/night-flock_test.ts` | 0 | 19 passed, 0 failed; `/tmp/counting-sheep-sol-corrections-final2-deno-test.log` |
| `python3 scripts/screenbook/screenbook.py doctor` | 0 | simulator/tooling ready; `/tmp/counting-sheep-sol-corrections-final2-screenbook-doctor.log` |
| `python3 -m unittest discover scripts/screenbook/tests` | 0 | `/tmp/counting-sheep-sol-corrections-final2-screenbook-tests.log` |
| `python3 scripts/screenbook/screenbook.py capture --all` | 0 | 5/5 captures; `/tmp/counting-sheep-sol-corrections-final2-screenbook-capture.log` |
| `python3 scripts/screenbook/screenbook.py verify` | 0 | 5 scenarios PASS; `/tmp/counting-sheep-sol-corrections-final2-screenbook-verify.log`; manifest SHA-256 `611b33725f6f601acaa30ab3f1dad3d9489a2d5f066532ce955ae27a66bfef53` |
| Actual production boundary probe compile/run | 0 | F1 route and actual outbox service restart/interleaving probe PASS; source `/tmp/counting-sheep-sol-corrections-boundary-probe.swift`; output `/tmp/counting-sheep-sol-corrections-final-boundary-probe.log` |
| `git diff --check` | 0 | clean whitespace check |

## UI evidence

- Actual installed Debug app Home screenshot, preserving the simulator's existing local state:
  `/tmp/counting-sheep-sol-corrections-final-real-home-2.png`. This is the real app binary and
  shows a Phone Away terminal receipt with the resumable Home guide overlay; it is not an
  interaction proof.
- Production-view configured Home: `tmp/screenbook/current/screens/iphone.home.configured.default.png`.
- Production-view active Wind Down: `tmp/screenbook/current/screens/iphone.home.active-wind-down.default.png`.
- Small-device/accessibility-size captures listed under F10.
- Gallery: `/Users/ngawangchime/Desktop/Developer Projects/Phone in the Other Room/tmp/screenbook/site/index.html`.
- Computer-use UI control was unavailable because the Mac was locked and automatic unlock was not
  available. No claim of interactive tap/VoiceOver proof is made.

## Remaining physical-device checks and review gates

These were not silently treated as simulator-passed:

- Family Controls authorization/revocation, opaque app/category selection, actual
  DeviceActivity registration/callbacks, ManagedSettings apply/clear, failed-monitor repair, and
  5/10/15-minute short-session behavior on a real phone.
- NFC start/end wrong-tag, cancel, unavailable, retired-tag, replacement-tag, and emergency-exit
  behavior.
- Confirmation/NFC race with a run or ordinary Morning becoming active, including background,
  termination, relaunch, and restore.
- Natural wake/Morning transition, purpose refresh after epoch/revision changes, notification and
  Live Activity behavior, timezone/DST changes, and overnight background recovery.
- Paired Apple Watch reachable/unreachable mirroring and terminal synchronization.
- Accessibility interaction/VoiceOver and layout at smaller phones and large content sizes.
- Signed archive/TestFlight distribution, privacy strings/labels, and the human-owned two-account
  Slumber Party physical QA and moderation/retention gates.

No backend state, migration, feature flag, deployment, account, or remote service was changed by
this correction pass. The exact remaining product-review question is whether the assumed three-day
Home guidance opportunity cadence is right; the implementation keeps it local, persisted, and
dismissible pending Sol/founder review.

Sol should review this resulting candidate again rather than relying on the previously green
test counts alone.
