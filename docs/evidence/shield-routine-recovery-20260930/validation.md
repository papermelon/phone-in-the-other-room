# Shield return and routine editing — 30 September 2026

## Observed state

The founder reported Home with no active session after choosing My routine on a shield.
Read-only inspection of the connected iPhone found Counting Sheep 1.0 build 64. On
30 September, DeviceActivity status recorded application at 22:00:02, followed by
clear/schedule events when the main app opened around 22:00:16. The app had no saved
run or canonical history record for that night, and its saved automatic occurrence
had moved to 1 October at 22:00. The retained log does not identify the triggering
call or establish whether the first authorization/selection read was transient.
No physical-phone settings, session, Farm or installed build were changed. Raw local
diagnostic copies are removed after inspection; only this bounded summary is retained.

## Source repairs

- Coordinator admission resets presentation without clearing the shield or one-use
  route when materializing the same saved automatic occurrence, including over an
  older receipt. Other resets and authorized exits retain their ordinary cleanup.
- A protection-readiness failure fails open and shows repair, while retaining a due
  occurrence’s anchor so a subsequent ready state can recover tonight. Failed future
  installations still discard the uninstalled schedule.
- Account adoption/restore is blocked during a due occurrence’s active interval,
  including the gap before coordinator admission. Future and expired schedules do
  not add a restore restriction; existing run/morning/settlement restrictions remain.
- My routine explains that the session keeps running and links to Edit saved Wind Down
  routine. The editor uses activity drafts, explicit Save routine/Cancel, and next-run
  wording. It opens directly to routine choices, with a compact header. Custom typing
  updates the draft before Save, even while the text field is focused. The goal screen
  is titled My goal to distinguish it from the routine editor.

## Local checks

- Full generic iOS Simulator app/extension build passed. Log:
  `/tmp/shield-routine-build-final.log`.
- Full native unit suite passed: **1,151 tests, zero failures/skips**. Result:
  `/tmp/shield-routine-tests.xcresult`; log: `/tmp/shield-routine-tests.log`.
- [Personal-shield probe](personal-shield-probe.json) passed, including the due
  shield-to-checklist handoff, no clear during admission, unchanged active routine
  after saving future choices, and background/foreground continuity. Existing
  phrase, one-use route, optional-checklist failure, account and Morning checks pass.
- [Recovery probe](recovery-probe.json): **23 cases passed**. New cases cover keeping
  tonight’s anchor through a failed-open readiness repair and blocking account
  replacement before admission while permitting future/expired schedules. Existing
  expired-night, owner-change, monitor, NFC and independent-Morning cases pass.
- Inspected the iPhone SE layout in light/dark mode and accessibility3 Dynamic Type.
  In the actual UI, changing a custom activity and tapping Save routine retained it
  on reopening; the active checklist still showed the original activity. Cancel
  discarded an edited draft on reopening. The save action and scrolling activities
  remain reachable at large text sizes. Inspected accessibility descriptions for
  checklist checks, edit action, next-run hint and Save routine; spoken physical
  VoiceOver remains a device acceptance check.
- Final whitespace/reference checks passed. No package, target, entitlement, signing,
  persisted schema or Watch protocol changes. No project regeneration was needed.

Commands used from the repository root:

```sh
xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/wind-down-check-in-derived
xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=60935BFC-7044-4BE8-9712-7D1B6C568A16' -derivedDataPath /tmp/wind-down-check-in-derived -resultBundlePath /tmp/shield-routine-tests.xcresult
```

Native probes used the existing configured-Home Screenbook scenario with
`-screenbook-personal-shield -personal-shield-probe` and
`-screenbook-recovery-probe YES`. All use isolated defaults/Farm storage, inactive
Watch, shielding spies, and disabled external services.

Captures: [checklist](../../../output/validation/shield-routine-recovery-20260930/checklist-dark.png),
[editor](../../../output/validation/shield-routine-recovery-20260930/editor-dark.png),
[saved activity](../../../output/validation/shield-routine-recovery-20260930/editor-saved-activity.png),
[large text](../../../output/validation/shield-routine-recovery-20260930/editor-large-text.png).

These are local source/Simulator results. The affected iPhone remains on build 64;
distribution and the physical shield-return/overnight matrix remain pending in
[the backlog](../../FUTURE_AGENT_TASKS.md#shield-return-and-routine-editing--30-september-2026).
