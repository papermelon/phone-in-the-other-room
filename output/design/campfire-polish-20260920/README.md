# Campfire polish validation — 20 September 2026

See the [implementation scope](../../../docs/plans/campfire-polish-2026-09-20.md).

Native fixtures use isolated defaults and an unconfigured network service. They simulate
presence/read state and never publish participants or change a real account's visibility.

## Reproduce

Launch a Debug build with `--campfire-buddies-qa --buddy-view=<mode>`.
Modes: `unified-loading`, `unified-refreshing`, `unified-retrying`, `unified-empty`,
`unified-failed`, `unified-stale`, `unified`, `unified-party`, `unified-party-refreshing`.
Add `--buddy-light`, `--buddy-large-text`, `--buddy-max-text`, or `--buddy-bottom` as needed. Use the Simulator’s accessibility settings
for Reduce Motion. The default fixture appearance is dark.

## Results

- Full Simulator app build passed. The final source also rebuilt successfully during the full test command below.
- Full unit suite passed: **1,104 tests, zero failures** (20 September 2026).
- The new phase test verifies current presence survives a refresh while unavailable/stale
  snapshots never gain display authority. Existing expiry, consent, membership and seating tests also passed.
- Native iPhone SE inspection confirmed populated refresh retains eight Shepherds, the
  **People here** disclosure exposes their session rows, and **Seating options** exposes **Reset seats**.
- Motion evidence: `motion-frame-1.png` and `motion-frame-2.png` differ only in the flame
  (excluding the status bar). These two captures predate the compact header refinement;
  the flame implementation is unchanged. `reduce-motion-frame-1.png` and
  `reduce-motion-frame-2.png` have identical app pixels with Simulator Reduce Motion enabled.
  The Simulator preference was restored to its original off value.
- Maximum accessibility text exposed an overflowing error overlay during inspection;
  the scene now grows to contain that text. Participant disclosures have a 44-point minimum label height. The repaired maximum-text layout was recaptured with no overlap.
- Final native inspection also covered light loading/retry and dark empty states. The private-party refresh retained its two members, and tapping Clover opened the existing session sheet.

Final layout captures: [loading](loading-light.png), [refreshing with people](refreshing-light.png), [retrying](retrying-light.png), [empty in dark mode](empty-dark.png), and [maximum-text retry controls](failed-dark-ax5.png).

Commands (review Simulator UDID):

```sh
xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=60935BFC-7044-4BE8-9712-7D1B6C568A16' -derivedDataPath /tmp/counting-sheep-first-start-build
xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=60935BFC-7044-4BE8-9712-7D1B6C568A16' -derivedDataPath /tmp/counting-sheep-first-start-build -resultBundlePath /tmp/counting-sheep-campfire-polish-final-tests.xcresult -parallel-testing-enabled NO
```

Local logs: `/tmp/counting-sheep-campfire-polish-build.log` and
`/tmp/counting-sheep-campfire-polish-final-tests.log`. The first build attempt rejected a
read-only accessibility environment override in the Debug fixture; that override was removed,
and Reduce Motion was checked using the actual Simulator preference instead.

## Remaining physical acceptance

Check slow/flaky connectivity, actual account and gathering switches, return from background,
VoiceOver reading and seat actions, and tap/hold/drag versus scrolling on a physical phone.
This pass does not deploy the backend or distribute a new app build.
