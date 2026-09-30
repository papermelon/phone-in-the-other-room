# Counting Sheep offline Android local milestone

AND-001–008. Saved usual plans, guest start/live flows, separate durable receipts and minimal Farm progress plus guest introduction, starter/welcome and real shearing use one offline application module, one coordinator and one durable transaction. The same authority calculates genuine local guest credit, wool growth, deterministic searches and independent Morning settlement. No account, backend, full Farm/Shop/social UI, NFC or wearable implementation. Debug ID: `com.ngawangchime.countingsheep.prototype.debug`. Release configuration also retains `.prototype`; the proposed permanent `com.ngawangchime.countingsheep` ID is not used. No production URLs, credentials, networking SDKs or Internet permission.

## Build and run

Use JDK 17, Android SDK platform 36 and build-tools 35.0.0. Gradle 8.13 is included through the official wrapper with its distribution SHA-256. AGP 8.13.2 supports API 36; minSdk is 29. Set `JAVA_HOME` and `ANDROID_HOME`, or create an ignored `local.properties` containing `sdk.dir=/absolute/path/to/sdk`.

```sh
cd android
# Only for the workspace-local SDK/JDK installed during this implementation:
. ./env-local.sh
./gradlew --offline :app:assembleDebug :app:testDebugUnitTest :app:lintDebug
adb -s YOUR_ISOLATED_DEVICE install -r app/build/outputs/apk/debug/app-debug.apk
adb -s YOUR_ISOLATED_DEVICE shell am start -n com.ngawangchime.countingsheep.prototype.debug/com.ngawangchime.countingsheep.prototype.ui.MainActivity
```

First builds fetch pinned dependencies from Google/Maven Central/Gradle; the installed app stays offline. Generated SDKs/caches, local paths and build products are ignored. On SDK command-line tools 19.0, `sdkmanager`/`avdmanager` have a launcher quoting bug in paths containing spaces. Use a normal SDK path without spaces, or invoke their Java main class with a quoted tools-directory property/classpath. The evidence records the exact local workaround.

Install a non-system **isolated test app**, read the disclosure and accept or refuse. After accepting, enable the service through Android Settings, return and select apps. Start manually, test Brief Access, end normally, or use the immediate emergency exit. A failed service needs reconnection plus **Check service and repair** before another start. An unreadable/newer session file stays preserved and write-fenced: export its bytes via `adb run-as` before clearing/reinstalling this disposable prototype. Do not use a personal Farm/account as test data.

Selection covers visible launcher apps. Counting Sheep, launchers, the default dialer, system/updated-system apps are excluded conservatively; many built-in apps (including some browsers) cannot be selected. Settings and emergency controls remain available. Refusal/withdrawal does not open Android permission setup. Disabling/uninstalling remains under Android's control.

## Checks

```sh
# macOS + Swift, from repo root, with Android build environment set:
python3 android/compatibility/run.py
```

This compiles the current Swift codecs/rules in a temporary host package, runs 195 current Swift timing/access/credit/bonus/settlement/store/routing/phrase tests, regenerates deterministic reference fixtures twice, compares Kotlin timing/credit/growth/bonus/search/Morning plus guest routing/duration/Unicode phrase, starter/skip, four-rarity shear yield and shorn/regrowing/ready semantics, performs the existing 8 Swift → Kotlin → Swift and Kotlin → Swift → Kotlin wire exchanges, and rejects malformed/newer documents in both languages. It never reads app defaults, personal files or server data. The harness only adapts unrelated host rendering/ActivityKit compilation. `FarmWireSchema` is a conservative snapshot of the inspected wire contract. Its lossless JSON tree is a codec experiment, not an Android Farm-domain model or an upload authorization. Original incompatible bytes must stay quarantined; the prototype has no upload method. Wire ownership is external to the payload: a synthetic owner UUID travels only in exchange metadata.

Instrumentation changes accessibility settings **only after explicit disposable-emulator opt-in** and verifies `sdk_gphone` identity. Never run this opt-in against a personal device. Test content and UI Automator are confined to the synthetic target/overlay; the product service cannot retrieve content.

```sh
cd android
. ./env-local.sh
export ANDROID_SERIAL=emulator-5580
./gradlew --offline :app:connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.isolatedPrototype=true
```

The test APK contains a separate launcher target; it adds no application module. UI Automator must use `FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES`, otherwise the test framework suppresses the service being tested. Local unit tests exercise the actual coordinator through start, access, early/normal/emergency endings, early-wake choices, standalone/deferred Morning, overlapping protection, restart and interrupted settlement. Native file tests exercise AtomicFile migration, publication failures, lost acknowledgements, starter/shear transactions, Morning effects and preserved corrupt/newer/recovery bytes. The native guest test exercises actual introduction/starter/welcome, one real shear, disabled regrowing action with 150% text in landscape, plan saving, consent/selection, start, wrong/matching phrase input, early ending, early-wake handoff, separate receipts, Farm navigation, emergency exit and large-text/landscape plan controls. Later timestamps in its Morning settlement are synthetic domain inputs, not a real-time overnight observation. Physical acceptance remains separate.

## Capability boundary

One coordinator and one version-4 checksummed AtomicFile transaction own consent, selection, frozen anchored plan/occurrences, access, evidence, local guest Farm and terminal intents/effect markers. Version-1, version-2 and version-3 prototype files migrate without dropping consent/selection/occurrence/access; v1 reward version remains 0, and v2 credit/reward identities remain intact. No historical rewards or bonuses are invented. Saved usual-plan preferences, receipt acknowledgements, starter/welcome ledger and permanent shear receipts share this transaction. Farm schema 2 adds harvest ordinals without replacing existing progress. v3 plan/receipt acknowledgements remain intact. Historical receipts remain in Nights without automatically reopening on migration. Original v1 bytes survive as the first recovery copy. Unknown fields/newer schemas/corruption fence writes and preserve original bytes. Brief Access is five minutes or the earlier session end; intent is durable before scheduling/commit/clear. Intervals remain in the ledger and are clipped to actual early endings. Pending grants do not survive reconnection as permission to clear. Stale occurrence/alarm inputs consult the current state and cannot restore an old grant. Runtime failure opens protection and requires repair. Countdown display derives from wall timestamps; monotonic/boot samples detect clock changes and reboot.

Only `TYPE_WINDOW_STATE_CHANGED` package metadata is read after consent. The service uses `TYPE_ACCESSIBILITY_OVERLAY` and cannot read nodes, text, screenshots or notifications. The blocker timestamp proves an observed overlay event, not continuous coverage, sleep or placement. System UI/window transitions can dismiss the overlay; an already-open app without a new event, PiP, split screen, browser content and OEM behavior are unproven.

Automatic-start **experiment**: a persisted start/end, inexact `setAndAllowWhileIdle` boundary and live-process Handler. No exact-alarm, notification, boot, battery-exemption or foreground-service permission is requested. Inexact alarms may be late; the handler cannot survive process death or guarantee Doze timing. Re-entry/service connection/window events reconcile bounds. Force-stop interrupts service/alarms; there is no force-stop-continuity claim. Clock/reboot discontinuity fails open and requires repair; saved zone/night identity and planned boundaries stay fixed. See [AND-007 evidence](../docs/evidence/android-port/2026-09-30-and-007/README.md) and the [consolidated pending physical checklist](../docs/plans/android-port-physical-acceptance-checklist-2026-09-30.md) before extending the product promise.

## Exercise AND-008 in Android Studio

Open this `android/` directory as the project, choose JDK 17 for Gradle and the existing SDK platform 36/build-tools 35.0.0. The workspace-local installations are `.toolchain/amazon-corretto-17.jdk/Contents/Home` and `.toolchain/sdk`; `env-local.sh` supplies those paths for terminal checks. Run the `app` debug configuration on an isolated emulator. Install the existing test APK to make its non-system synthetic launcher target selectable.

```sh
# android/ terminal, disposable emulator only
. ./env-local.sh
./gradlew --offline :app:assembleDebugAndroidTest
adb -s emulator-5580 install -r app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk
```

On first launch, choose **Begin as a local guest**, read the welcome and **Open my Farm**. A fresh Farm gets Mabel once, with wool ready; an established Farm keeps its inventory and receives no extra starter. In Farm, scroll to **Shear Mabel • 1 wool**. It saves one wool and starts 840 eligible timer minutes of regrowth. The button disables while wool regrows; restart preserves the wool and harvest receipt. Guest introduction and shearing need no Accessibility permission. Guest data has no backup or account and is lost with cleared app data/uninstall.

Then open **Home**. Choose **Set up usual plan**, select bedtime/wake with Android's clock picker, choose quiet durations and **Save usual plan**. Saving never starts protection or enables automatic routines. In **Settings**, read/accept or refuse the disclosure, enable the prototype service in Android Settings and select a test app. Repair an unavailable service before another protected start.

Home offers Phone Away (5–30 minutes), the saved Wind Down near its start time, and standalone Screen-Free Morning. An upcoming Wind Down within the default Phone Away overlap asks for explicit early start while retaining the planned bedtime/wake. Countdown and phase derive from frozen timestamps. **Five-minute Brief Access** and ordinary End open a fresh phrase confirmation; emergency exit is immediate. During the overnight phase, choose Morning now, at the usual time or skipped. All four tabs stay reachable during a live occurrence.

After ending, the saved receipt temporarily opens over the shell. Overnight/Phone Away credit, excluded access, bedtime bonus and separate linked Morning appear as distinct records. **See Farm progress** durably acknowledges the receipt without rewarding again; **Nights** can reopen history. Farm presents genuine carried search progress, separate bonus, wool and earned inventory. There is no verified account or sync.

For a short Wind Down outside the usual clock window, open **Settings → Internal scenario controls → Wind Down scenario • 1 + 1 + 15 minutes**. This uses the same coordinator and produces the same guest receipts. The existing two-minute and delayed-start experiments plus standalone fifteen-minute Morning remain there. Internal controls are explicitly diagnostic; the optional questionnaire, practice/Pippin reward, Shepherd wearable gift, tasks/goals/routines, NFC and full Farm/Shop UI remain later work.
For fast deterministic scenarios and injected interruptions, run `GuestFarmActionsTest`, `GuestJourneyTest`, `SessionDomainTest`, `SessionDocumentTest` and `DomainParityTest` from `app/src/test` with Gradle in Android Studio. They invoke the same coordinator and settlement used by the installed app, with injected timestamps/disk failures; no real-time overnight wait is needed. Native `DomainStoreInstrumentationTest` uses only an isolated cache directory; the explicit emulator opt-in above also gates it. There is no disk-failure button or production fixture import path.

Wind Down's 420-minute meter and Phone Away's independent 100-minute meter retain early-ended credit and subtract the union of recorded Brief Access. Timer credit grows active sheep's remaining wool seconds; the version-2 bedtime bonus adds 20% search units once per frozen night and grows neither wool nor factual minutes. Deterministic search identities, first-three guarantees, droughts, capacity/pending arrivals and carried fractions persist. Morning retains Swift's elapsed policy including Brief Access: at least fifteen eligible minutes, independent 100-minute fills granting one wool plus a Sunrise search. Ready active sheep can be sheared for 1/2/4/7 wool by common/uncommon/rare/legendary rarity; regrowth takes 2/3/4/5 seven-hour credit units. Harvest identity is `shear:<uppercase sheep UUID>:<ordinal>`. The starter does not consume a search ordinal. Morning fills and bedtime bonuses do not regrow wool. Full Shop/Farm artwork and other interactions remain later work.

Terminal intent and its Morning disposition persist before platform cleanup. Inventory, meters, reward identities and the replay marker publish together in the next atomic generation. Interrupted effects replay exactly once; an unacknowledged write can be retried with the same identities. A failed live write fails open, retains a bounded interrupted snapshot for explicit repair and never credits the later repair gap. An interrupted local guest save can be retried through repair without Accessibility consent; a protected start still requires consent, selection and an operational service. Recovery never resumes protection automatically. This is **localGuest**, not verified account-owned state or a cloud-compatible Farm replacement; the existing lossless wire codec remains separate from local domain authoring.
