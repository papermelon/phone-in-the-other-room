# Shield recovery validation — 20 September 2026

Source repair and Simulator evidence only. No signed archive, physical shielding acceptance or distribution was performed.

- Full app and extension Simulator build: **passed** after the final title correction. Command: `xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator'`. Full local log: `/private/tmp/shield-recovery-build-final.log`; [summary](build-summary.txt).
- Full unit suite: **1,082 tests, zero failures**. Command: `xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=A0DB65B8-F3FC-4961-8B0C-9689F51C9EA1' -resultBundlePath /private/tmp/shield-recovery-final-20260920.xcresult`. See [summary](tests-summary.txt); full local log is `/private/tmp/shield-recovery-tests-final.log`. This includes the explicit ending-parent handoff correction. Only the navigation title changed afterward.
- Isolated native coordinator/monitor probe: **passed**, no failures. See [JSON](personal-shield-probe.json). Covers altered/replayed confirmation rejection, keyboard-free Start now, ending-parent handoff and six fake monitor admission/cleanup cycles.
- Native UI: iPhone SE Simulator, iOS 26.5, large text. [Start morning](start-morning.png) presents a confirmation button without a keyboard or sleep phrase. Tapping it reaches [active Morning](morning-active.png) with the full planned duration and **My morning** action. The fixture uses injected shielding; it cannot prove real app blocking.

Launch fixture: `-screenbook-scenario iphone.home.configured.default -screenbook-run-id shield-recovery-20260920 -screenbook-personal-shield -personal-shield-probe -personal-shield-overnight -personal-shield-start-morning -personal-shield-dark`.

Remaining physical acceptance, including repeated restoration without reopening the app, is recorded in the [repair note](../../../docs/plans/shield-access-and-early-wake-repair-2026-09-20.md). VoiceOver and actual Family Controls/NFC behavior still require device acceptance.
