# Automatic Wind Down and loading repair — 21 September 2026

Local source validation. No TestFlight archive/upload, physical-device test or new backend
deployment in this follow-up. The earlier invitation deployment has separate evidence.

## Checks

- XcodeGen regenerated source membership for the extracted automatic-start card and deadline helper/tests.
- Full Simulator app build passed. Final command:
  `xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/slumber-repair-derived`.
  See [build.log](build.log). An initial build found a read-only preview environment key;
  that preview was corrected before the passing build.
- Full suite: **1,112 tests, zero failures**. Command:
  `xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=71CF8F3E-9E9A-449D-93A8-B73F64869A5E' -derivedDataPath /tmp/slumber-repair-derived -resultBundlePath /tmp/wind-down-loading-tests.xcresult`.
  [tests.log](tests.log). New checks cover success/error propagation, stalled-read timeout/cancellation,
  and caller cancellation. Only debug presentation fixtures changed after this suite; the final app build passed.
- **21 recovery-probe cases passed**, including ordinary publication preserving future and due
  automatic occurrences, overdue coordinator admission retaining the scheduled anchor, and
  account change clearing/cancelling the old occurrence. [Report](recovery-probe.json).
  Ran with `-screenbook-recovery-probe YES -screenbook-run-id wind-down-loading-20260921`
  on the isolated Slumber Repair QA Simulator (`C6A90B76-4D08-4EB0-A4F7-0E63E4B8AA72`).
  These use isolated storage, the real coordinator and shielding spies, not real Screen Time operations.
- Changed-file whitespace checks passed. [Source hashes](source-sha256.json) identify the final touched code.

## Visual and accessibility inspection

Production views with local fixture state and no network service, launched with
`--slumber-repair-qa --repair-mode <mode>`; `--large-text` selects accessibility3.

- [Campfire loading](campfire-loading.png): Bramble's existing textured run frames, hop and staggered dots.
- [Motion recording](bramble-loading.mp4): the same shared loader in Slumber Party. Recorded from
  Simulator; no new image asset or animation package.
- [Large-text loading](campfire-loading-large.png): long progress text wraps alongside the sheep.
- [Large-text retry](campfire-error-large.png): stale data shows “The campfire needs an update,”
  the explanatory message and an enabled “Try again,” with no loading indicator.
- [Automatic control in Edit Wind Down](automatic-editor-large.png): the toggle and heading wrap;
  changing it in the unconfigured QA app exposes the protection-repair state. The full status and
  repair action are present in the accessibility tree and reachable in the scrolling editor.
- Accessibility tree inspected: loader is one element with the operation label and value
  “In progress”; decorative frames/dots are hidden. Toggle has its label and on/off value;
  retry/repair actions are named. No spoken VoiceOver session was performed.
- Reduce Motion uses a static first frame/dots, and inactive scenes pause TimelineView by source
  inspection. Physical Reduce Motion verification remains pending.

The newly created iPhone SE QA Simulator (`F67C68BF-EB66-48D8-83C1-FF77B4974237`)
stalled for over five minutes in first-boot CoreLocation data migration and was stopped.
Small-screen visual acceptance is **not passed**. Existing working Simulator checks above
remain valid; no unrelated Simulator was reset.

## Remaining device checks

Distribute the updated app, then verify an automatic start enabled before its boundary,
including a simultaneous ordinary account refresh, foreground/background/terminated delivery,
actual selected-app shielding, overnight/morning boundaries and the next unattended night.
Check Campfire on the affected account under slow/offline connections and after reconnection,
including party/Global changes. Source defects establish possible causes, not the exact hosted
latency or callback history of the founder's screenshots.
