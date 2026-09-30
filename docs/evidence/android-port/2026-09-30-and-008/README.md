# AND-008 — local guest plan-to-receipt journey

30 September 2026. The founder authorized usual-plan setup, guest start/live flows, separate overnight/Morning receipts and minimal Farm progress on the existing offline Android foundation. **This bounded slice is implemented and locally tested; physical protection and release acceptance remain pending.** No account/service integration, permissions/dependencies/modules, signing configuration, uploads, commits or pushes were added. Swift production source was not changed.

## Source and scope

- Revision: `2f3a04511eeb5bcfabdb1953dc1745f08821335c` ([captured revision](source-revision.txt)). Android and earlier roadmap/evidence were already untracked; unrelated Swift/social/backend working changes were already present. [Initial status](source-status.txt), [relevant uncommitted patch](uncommitted-baseline.patch) and [baseline hashes](baseline-sha256.json) were recorded before edits.
- [Final hashes](final-sha256.json), [comparison](source-comparison.json), [final status](final-status.txt) and [APK hash](apk-sha256.txt) identify the locally tested result. Shared Swift, relevant Swift tests and the production coordinator remain byte-identical to this task's baseline. Build/manifest/service configuration and the historical eight wire fixtures remain identical. The backlog's Android section was updated while preserving unrelated sections.
- The current authorities are `Shared/NightWatch.swift`, `WindDownScheduling.swift`, `HomeStartRouting.swift`, `PhoneAwayStartPolicy.swift`, `PersonalShield.swift`, cumulative Farm/bonus/search and independent Morning rules, plus the existing `FocusSessionCoordinator` and transaction/store contracts. AND-001–006 and AND-007 remain preserved historical evidence. Current Swift rules were recompiled and compared; historical evidence was not substituted for current-source verification.

## Implemented behavior

Home, Nights, Farm and Settings consume the same `SessionCoordinator.states`. A saved usual plan uses native clock pickers and bounded quiet durations. Saving/cancelling does not start protection or enable recurring schedules. Editing an active plan prepares the next occurrence without moving its frozen instants/zone/night identity. Active countdown and controls take priority on Home; other tabs and immediate emergency exit remain reachable.

Home uses current Swift's strict default-Phone-Away overlap rule: Wind Down is preferred when its saved start is less than thirty minutes away or the current anchored window is eligible. Explicit early admission retains the original planned start/bedtime/wake; it does not normalize bonus eligibility. Phone Away offers 5/10/15/20/25/30 minutes. Standalone Morning uses the saved Morning duration. Consent, non-empty eligible selection, operational readiness, repair and unsettled-intent guards remain in the coordinator.

Brief Access and ordinary endings open a fresh occurrence/action/phase confirmation. The current Swift phrases and Unicode normalization are ported; early-wake start-now uses a dedicated confirmation without typing, while defer/skip retain their distinct phrases. The coordinator validates a single-use identity, current occurrence/phase and bounded freshness. Input/challenges remain volatile and are cleared on leaving the activity or restarting; they are never persisted or uploaded. A user-tapped overlay now routes to the existing activity for this confirmation. Actual API-36 overlay interception, wrong/matching input, five-minute grant and emergency exit were exercised. OEM routing/coverage remain physically pending.

Terminal receipts derive from durable terminal intents and Morning occurrences, not UI counters. Overnight/Phone Away eligible credit, excluded access and bedtime bonuses remain distinct from factual before-bed minutes and independent Morning elapsed/fills. Only the parent's linked Morning appears on its receipt. Separate Morning history remains separately identifiable. Unsettled effects cannot present saved rewards. `See Farm progress`/`Back to Nights` persist acknowledgement without awarding again; history stays reopenable. A zero-credit or historical prototype receipt adds no invented reward. Saved time zones are labelled.

Farm presents actual carried Wind Down timer and bonus progress, independent Phone Away/Morning meters, wool, active/pending sheep and the latest real search. Unknown catalog IDs get a display fallback without changing persisted IDs. Full onboarding/starter/welcome, shearing/Shop/customization, tasks/goals, automatic routines, reflection, NFC and social/account UI were not scaffolded.

## Storage, migration and replay

The existing checksummed `AtomicFile` authority is now **document v3**, adding only saved `NightPreferences` and acknowledged receipt IDs. There is no second session, reward, plan or receipt store. Strict v1/v2 migration preserves consent, selections, frozen occurrence/access data, guest ledgers and reward identities. V1 retains reward version 0. V2 historical receipts stay in Nights and are acknowledged for initial routing, avoiding an old-receipt barrage; this changes no economy state. V2 bodies containing v3 fields, v3 bodies missing required metadata, unknown fields/newer schemas and corrupt checksums are rejected without destructive normalization.

Native migration verifies v1 and v2 original bytes become the recovery copy after the first successful v3 save; unknown future sheep/rarity IDs and carried progress survive. Native interruption checks cover terminal-intent/effect writes at `before-primary`, `primary-before-finish` and `after-primary`, plus Morning settlement. Restart replay grants each reward exactly once. Failed acknowledgement leaves the receipt pending and saved economy unchanged. Storage/runtime failure remains fail-open and repair-gated; no blocker observation or later interruption-gap credit is fabricated.

A coordinator bug exposed by the new live UI was repaired centrally: ending an independently active Morning by its occurrence ID while Phone Away is also live now ends only that Morning. Global emergency/consent withdrawal still terminate all relevant protection. The regression test verifies Phone Away remains live and continues its own accounting.

## Actual verification

Commands ran from `android/`, using the existing JDK 17/SDK 36/build-tools 35.0.0 toolchain and cached dependencies. Every Gradle command used `--offline`.

```sh
. ./env-local.sh
emulator -avd counting-sheep-isolated-api36 -no-snapshot -no-boot-anim \
  -no-audio -no-window -gpu swiftshader -port 5580
python3 compatibility/run.py
ANDROID_SERIAL=emulator-5580 ./gradlew --offline \
  :app:assembleDebug :app:testDebugUnitTest :app:lintDebug \
  :app:connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.isolatedPrototype=true
```

The emulator launch was redirected to [emulator.log](emulator.log); [identity](emulator-properties.txt) records model/API/fingerprint. It was a disposable API-36 `sdk_gphone64_arm64` emulator, not a personal device. Permission changes were gated by explicit instrumentation opt-in/model checks and cleaned up. Screenshots use only the synthetic installed guest/test target.

| Check | Actual outcome and evidence |
| --- | --- |
| Debug APK, complete JVM suite and lint | Passed in [final-milestone-validation.log](final-milestone-validation.log). **51 tests, zero failures/skips/errors** across six suites ([XML](jvm-results/)). Lint: **zero errors, twelve existing warnings** ([XML](lint-results.xml)); dependency upgrade hints were not used to change scope. |
| Current Swift rules/codecs | **154 tests, zero failures**, including Home routing and Personal Shield tests added to the host proof. [Final parity log](parity-final.log). No native iOS build is claimed or needed for this Android-only change. |
| Deterministic fixture generation | Current Swift exported twice with identical SHA-256; semantic comparisons against all eight preserved AND-006 wire fixtures passed. [Reference snapshot](domain-reference.json), [summary](fixture-summary.json). |
| Kotlin semantic parity | Eight anchored timing cases, sixteen Morning identities, fifteen credit sequences/**37** settlement steps, two Morning sequences/**16** settlement steps, six Home routing boundaries, three live phrase phases, three early-wake confirmations, six Unicode normalization cases and six Phone Away duration choices matched current Swift. Idempotency and codec exchanges passed in both directions. |
| Native instrumentation | **8 tests, zero failures/skips/errors** in [native-results.xml](native-results.xml). Includes real AtomicFile migration/recovery/replay, the existing overlay target-interaction experiment, and actual guest plan/consent/selection/start/access/end/early-wake/receipt/Farm/emergency controls. |
| Larger text and landscape | The native guest test successfully reached and saved the plan at **150% text**, portrait and landscape. [Portrait](guest-plan-large-text.png), [landscape Save](guest-plan-landscape-save.png). This is bounded emulator UI evidence, not a spoken TalkBack or all-device accessibility pass. |
| Permission/configuration scope | [APK permissions](apk-permissions.txt) and baseline hashes confirm no new application permission, dependency/module or sensitive data access. |
| Source/doc inspection | Relevant production Swift unchanged, historical evidence preserved, references checked and whitespace checks passed. [Copy review](copy-review.md) records protection/timer/bonus/guest wording and inspected screenshots. |

The native guest test uses real user-facing controls through Phone Away and early-wake handoff. Its final thirty-minute Morning settlement uses a synthetic terminal timestamp through the actual coordinator; it does **not** wait thirty minutes or prove overnight protection. Existing domain tests use injected clock/disk failures and actual settlement logic. No test-only state machine, production fixture import or data-reset button was added.

### Failures found and repaired

- The first build ran before the details file had been written because of a shell working-directory mistake; unresolved UI references were corrected by writing the intended file and rebuilding.
- New receipt tests caught simultaneous overnight/Morning ordering; the projection now prioritizes the overnight record. A missing-field test was changed to remove the field structurally rather than rely on JSON comma placement.
- Current Swift fixtures exposed NEL (`U+0085`) normalization. A JVM-only regex flag then crashed Android's ICU engine; the final portable character class passes both host parity and native input. [Initial parity](parity.log), [Android failure](verification-repaired.log), [repaired host parity](parity-final.log), [final native pass](final-milestone-validation.log).
- Final screenshot inspection caught a stale one-second UI sample immediately after admission; the display now uses the latest coordinator clock as its lower bound. Native Morning countdown is checked against its thirty-minute window. Screenshots wait for animations to settle. The added countdown selector initially used an unavailable UI Automator method; it was corrected to the existing `By.text(Pattern)` API.
- UI Automator's child-text enabled state did not represent the parent disabled button. The test now taps wrong input and verifies no grant. A configuration-change stale node is retried using a fresh node. The landscape test's swipe originally began on the navigation bar; moving the gesture into the content pane verifies Save is reachable. Earlier logs and before-repair screenshots remain in this directory. No failed check is treated as passed.

## Exercise in Android Studio and remaining gates

Open `android/`, use JDK 17 and SDK 36/build-tools 35.0.0, and run the `app` debug configuration on an isolated emulator. Home → **Set up usual plan** → **Save usual plan**. Settings → accept/refuse disclosure, enable the service through Android Settings, select a non-system isolated target and repair if needed. Home then offers admitted starts, access/end confirmations and immediate emergency exit. Nights reopens receipts; Farm shows real local progress.

Settings → **Internal scenario controls** retains the real short Wind Down (`1 + 1 + 15 minutes`) for exercising the overnight minute and early-wake choices without moving the OS clock. Standalone Morning, two-minute Phone Away and delayed-start experiments use the same authority. Install the existing test APK to expose its synthetic selectable launcher target; exact commands are in [android/README.md](../../../../android/README.md).

**All physical checks remain pending** in the [single consolidated acceptance checklist](../../../plans/android-port-physical-acceptance-checklist-2026-09-30.md): Pixel/Samsung/SEA OEM routes, service survival, overnight/Doze/battery, API-29 minimum OS, transfer exclusions, larger text and TalkBack. These still gate protection claims and release readiness. No force-stop continuity, NFC, account ownership/sync, production activation, Play acceptance or distribution is claimed.

Recommended next bounded solo slice: guest introduction/starter/welcome and one genuine wool/shearing action, consuming this authority and receipts. Full Farm/Shop/social/account scope needs its own implementation authorization; AND-009 remains pending.
