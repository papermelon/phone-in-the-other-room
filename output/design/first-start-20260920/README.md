# First-start sheet — 20 September 2026

Implemented the first experiment from the [Mobbin brief](../../../docs/plans/mobbin-first-night-2026-09-14.md).
The sheet opens full height. Its protection summary precedes optional controls, and a native
bottom inset keeps the appropriate next action and cancellation reachable.

- Permission and permission repair request access only; they do not open the picker or start a session.
- Empty selection opens Apple's picker; returning does not confirm a start.
- Ready uses the existing mode-specific start and NFC confirmation path.
- Failed protection retries the existing protection intent; setup repair is also reachable.
- Unavailable protection explains the problem and offers exit.
- Existing privacy, Campfire, Lock Screen, duration and private-task controls remain.

The existing repair view was moved without behavior changes. Shared readiness/action routing
has a unit regression check. Debug previews use isolated persistence and presentation-only
readiness; they are not evidence of actual authorization, shielding or NFC behavior.

## Validation

- `xcodegen generate`: passed; the generated project includes the extracted repair view and Debug fixture.
- Full app build: passed on the iPhone SE Simulator (iOS 26.5), using:
  `xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=60935BFC-7044-4BE8-9712-7D1B6C568A16' -derivedDataPath /tmp/counting-sheep-first-start-build`.
  Log: `/tmp/counting-sheep-first-start-build-verified.log`.
- Full unit suite: **1,101 tests passed, 0 failures**, including
  `ShieldingReadinessTests.testFirstStartAdvancesSetupBeforeOfferingAnExplicitStart`.
  Command: `xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=60935BFC-7044-4BE8-9712-7D1B6C568A16' -derivedDataPath /tmp/counting-sheep-first-start-build -resultBundlePath /tmp/counting-sheep-first-start-tests.xcresult -parallel-testing-enabled NO`.
  Log: `/tmp/counting-sheep-first-start-tests.log`; result bundle:
  `/tmp/counting-sheep-first-start-tests.xcresult`.
- `git diff --check`: passed. The extracted repair view was compared with its original body
  and is unchanged.
- Native accessibility-tree inspection: protection title/detail precede the primary action;
  setup actions have a no-start hint, and NFC ready announces registered-tag confirmation.
  This is an accessibility-tree check, not a spoken VoiceOver pass.
- Inspected the screenshots below. Primary labels wrap at accessibility size, and the final
  Lock Screen toggle can be scrolled fully above the footer. Toggled the preview-only control
  to confirm reachability. Opened the repair link and returned to preflight.
- No physical authorization, shielding, NFC, distribution or backend activation was performed.

| Evidence | What was inspected |
| --- | --- |
| [Authorization](se-authorization.png) | Protection step and primary action visible on iPhone SE, enlarged text |
| [Bottom controls](se-bottom-controls.png) | Final toggle clears the fixed action bar |
| [Denied](se-denied.png) | Permission restoration and Settings entry |
| [Phone Away](se-empty-phone-away.png) | Empty-selection action and existing Phone Away copy |
| [Accessibility size](se-empty-accessibility3.png) | AX3 text, wrapped primary action |
| [Accessibility bottom](se-bottom-accessibility3.png) | Tasks, visibility and final toggle remain scrollable above footer |
| [Runtime failure](se-runtime-failure.png) | Failure context, setup repair link and retry action |
| [NFC ready, dark](se-ready-nfc-dark.png) | Selection count, readiness/evidence distinction and retained start wording |
| [Unavailable, dark](se-unavailable-dark.png) | No start action; explanation and exit |

Accessibility-size captures used the launch argument
`-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXL`.
Normal-size failure/NFC/unavailable captures used `UICTContentSizeCategoryL`; other captures
used the Simulator's existing XXXL text size. The Simulator's original light appearance and
XXXL content size were restored after the visual review.

## Reproduce the native layout fixture

Build the Debug app, install it on a test Simulator, and launch with `--first-start-preview`.
Use one state flag: `--denied`, `--revoked`, `--empty`, `--ready`, `--failure`, or `--unavailable`.
No flag shows the authorization step. Add `--nfc` for tag wording or `--phone-away` for duration,
tasks and Phone Away copy. Use Simulator appearance and content-size controls for dark and
accessibility-size review. The fixture displays the production sheet; readiness is simulated.

## Remaining device acceptance

On a physical iPhone, exercise initial authorization, denial and restoration, empty selection,
selection dismissal, foreground return from Settings, runtime apply/restore failure, and
registered/mismatched/cancelled NFC. Confirm setup never starts a session; start still requires
its own explicit action. Perform a spoken VoiceOver pass and first-use observation with a
person. Simulator layouts and unit tests do not establish those physical behaviors.
