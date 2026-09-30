# Automatic Wind Down monitor cancellation — 26 September 2026

Source repair only. No archive, device installation, backend change, or distribution.

## Validation

- `xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator'`: passed, including DeviceActivity extension. Log: `/tmp/wind-down-fix-build-20260926.log`.
- `xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=A0DB65B8-F3FC-4961-8B0C-9689F51C9EA1'`: 1,138 passed, zero failed/skipped. Log: `/tmp/wind-down-fix-tests-20260926.log`. Xcode result: `~/Library/Developer/Xcode/DerivedData/PhoneInTheOtherRoom-cbapevrcjnbvryejcvolmjxokfkc/Logs/Test/Test-PhoneInTheOtherRoom-2026.09.26_09-25-54-+0800.xcresult`.
- Installed the local Simulator app on isolated Recovery QA (`329535CB-D901-434D-BE9D-7BA64A3BE900`) and launched with `-screenbook-recovery-probe YES`: all 21 cases passed. [Report](recovery-probe.json). The shielding case checks the production monitoring client with Apple's empty-list stop-all semantics, repeated empty Brief Access cleanup, idempotent installation, missing-monitor repair, rollback and explicit retirement.
- Reviewed every `stopMonitoring` / monitoring-client stop caller: other direct production calls use nonempty explicit names; filtered app calls route through the guarded client; the extension's filtered call is guarded locally. No intentional stop-all caller was removed.
- `git diff --check`: passed. Earlier quiet Profile sync changes were preserved.

## Limits

Read-only inspection of the connected phone found build 63 with automatic start/shielding enabled and a persisted 10 PM schedule. Its bounded diagnostics no longer retained the reported night boundary. Raw device/account data is not included in this artifact. Simulator checks cannot establish actual selected-app blocking, delivery while locked/closed, Home recovery on that device, or a second unattended night. Complete the existing signed-device acceptance matrix after an authorized distribution.
