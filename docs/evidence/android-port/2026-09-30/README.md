# AND-001–006 implementation evidence — 30 September 2026

Founder authorized this bounded slice on 30 September 2026. Implementation is offline under `android/`; no services were configured, production tests run, backend mutated, builds uploaded, commits created or pushes made. Android platform/data lead responsibilities were handled in this chat. Later milestones remain pending. This record distinguishes local proof from physical acceptance and Play review.

## Source and toolchain baseline

- Source HEAD: `2f3a04511eeb5bcfabdb1953dc1745f08821335c`. The roadmap was untracked; `project.yml`, generated Xcode project and backlog were already modified. [Baseline patch](uncommitted-baseline.patch), [status](source-status.txt), [iOS checksums](ios-baseline.sha256), [backend migration inventory](backend-migrations.txt), [asset path manifest](asset-manifest.txt). These are local source inventories, not server deployment evidence. No artwork was ported in this prototype.
- Swift production source is unchanged. The temporary Swift host package symlinks current Shared codecs. It guards unrelated ActivityKit code for iOS and removes only `OllieNeckwearPose`'s host-incompatible CGPoint Equatable conformance in a temporary rendering copy. No payload, domain or production decoder changes.
- macOS arm64; Apple Swift 6.3.3. Java Corretto **17.0.20.1+12**, Gradle **8.13**, AGP **8.13.2**, Kotlin/compiler plugins **2.2.21**. Android SDK platform **36 revision 2**, build-tools **35.0.0**, command-line tools **19.0**, platform-tools **37.0.1**, emulator **37.1.11**. Installed SDK/JDK/caches are workspace-local and ignored. The official Gradle wrapper and distribution checksum are retained as project files; [actual version output](toolchain-versions.txt) separates Gradle's embedded Kotlin 2.0.21 from the app compiler plugin 2.2.21; no commit was made.
- [AGP compatibility](https://developer.android.com/build/releases/agp-8-13-0-release-notes) supports API 36.1 with Gradle 8.13/JDK 17. [Current Play floor](https://developer.android.com/google/play/requirements/target-sdk) is API 36 for new phone apps/updates from 31 August 2026. `compileSdk=targetSdk=36`, `minSdk=29`; actual minimum-OS device acceptance is pending. Versions are compatible stable pins, not a claim to be the newest releases. Recheck requirements at any submission.
- Debug ID `com.ngawangchime.countingsheep.prototype.debug`; even the unused release build configuration retains `com.ngawangchime.countingsheep.prototype`. The proposed permanent release identity is not configured. One application module. No accounts, URLs, secrets, SDK transport or Internet permission.

## Dependency inventory

Exact direct pins are in `android/build.gradle.kts` and `android/app/build.gradle.kts`; resolved graph is in [dependencies](dependencies.txt).

| Dependency/tool | Pin | Why present |
| --- | --- | --- |
| AGP / Gradle / Java | 8.13.2 / 8.13 / 17 | Build, lint, packaging; compatible stable API-36 toolchain. |
| Kotlin Android, Compose compiler, serialization plugin | 2.2.21 | Kotlin compilation and native Compose/JSON code generation. |
| Compose BOM, Material3, UI preview/tooling | 2025.10.01 BOM | Small accessible native interface and representative previews; tooling debug only. |
| AndroidX activity-compose | 1.11.0 | Native Activity/Compose lifecycle and content host. |
| lifecycle-runtime-compose | 2.9.4 | Lifecycle-aware state collection. |
| coroutines-android | 1.10.2 | StateFlow and UI countdown refresh; no background-continuity claim. |
| serialization-json | 1.9.0 | Versioned local state and lossless wire trees. |
| JUnit | 4.13.2 | Bounded JVM domain/codec checks. |
| AndroidX test runner / ext JUnit | 1.6.2 / 1.2.1 | Isolated native instrumentation. |
| UI Automator | 2.3.0 | Synthetic target interaction/interception proof, test APK only. |

No navigation, DI, database, WorkManager, Supabase, Firebase, tracking or custom state-machine library was added. AndroidX transitive initialization/profile components appear in the merged manifest. Version-update lint suggestions are retained; they do not require adding newer dependencies to this slice.

## Permissions, collection and policy fit

The [merged manifest](merged-debug-manifest.xml) is the actual debug inventory, not just the hand-written manifest.

| Mechanism | Actual declaration/data | Boundary |
| --- | --- | --- |
| Accessibility service | Exported service protected by system `BIND_ACCESSIBILITY_SERVICE`; `TYPE_WINDOW_STATE_CHANGED`, `canRetrieveWindowContent=false`, `isAccessibilityTool=false` | Explicit separate in-app disclosure, affirmative accept/refuse/withdraw. Events are ignored before consent. Reads only package metadata after consent; volatile last package, persisted occurrence/blocker timestamp. No text/nodes/screenshots/window/notification content. |
| App visibility | `MAIN/LAUNCHER` and `MAIN/HOME` intent queries | No `QUERY_ALL_PACKAGES`. Labels/flags from PackageManager; device-local package selection. System/updated-system apps, launchers, the native default dialer and this package are excluded. Built-in browsers may be unavailable deliberately. |
| Blocking | `TYPE_ACCESSIBILITY_OVERLAY` | No `SYSTEM_ALERT_WINDOW`, no automatic background activity launch. Home and emergency actions remain in the overlay; system navigation/permission repair remain reachable. No settings manipulation or disable/uninstall prevention. |
| Boundaries | Non-exported receiver; inexact AlarmManager plus live Handler | No exact-alarm permission, notification permission, boot receiver permission, foreground-service permission/type, Usage Access, battery exemption, NFC, Health, location, contacts, camera, storage, device-owner, root or VPN permission. |
| Native dependencies | App-scoped signature `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`; profile installer receiver requires system `DUMP`; debug PreviewActivity | Not access to personal content/network. No Internet permission. |
| Storage/backup | Private internal checksummed AtomicFile and prior-generation recovery; all-domain backup/transfer exclusions and `allowBackup=false` | Selection, consent and active intervals stay device-local. Actual OEM transfer/restore test pending. No wholesale upload path. |

Official review: [Accessibility API/overlay](https://developer.android.com/reference/android/view/WindowManager.LayoutParams#TYPE_ACCESSIBILITY_OVERLAY), [service event configuration](https://developer.android.com/guide/topics/ui/accessibility/service), [scoped queries](https://developer.android.com/training/package-visibility/declaring), [broad visibility policy](https://support.google.com/googleplay/android-developer/answer/10158779?hl=en), [accessibility declaration/disclosure](https://support.google.com/googleplay/android-developer/answer/10964491?hl=en), and [sensitive API policy](https://support.google.com/googleplay/android-developer/answer/16558241?hl=en).

Policy inference: deterministic user-configured package blocking with minimum data and a reversible opt-in is a candidate for review, **not Play approval**. Counting Sheep is not an accessibility tool for disability support. A later submission needs the accessibility declaration, matching listing/privacy/Data Safety disclosures and a reviewer video showing refusal, consent, enablement and blocking. No declaration/submission was made. Test automation reads only its synthetic fixture/own overlay; that is not a capability granted to the product service.

Disclosure/declaration draft: “This experiment uses Android Accessibility to receive package names when windows change and cover selected apps. Package selections and the last blocker timestamp stay on this phone. It does not read screen text, window content, screenshots or notification content. Nothing is uploaded. System apps are excluded. You can refuse, disable the service or uninstall at any time.” Purpose: app functionality, selected-app self-control, explicit fixed rules. Final Play answers and recording remain pending for a release candidate.

## Timing and recovery findings

One coordinator owns admission, the absolute planned start/end and UUID occurrence, access ledger, terminal reasons and repair fence. UI, service and alarms send intents to it; one AtomicFile authority stores all prototype state. The phone is local authority; no reward/session transfer is implemented.

Access proposal is written before its boundary alarm, committed before clearing the overlay, and clipped to five minutes/planned end. Early terminal exits clip intervals to actual end. Pending grants cannot clear after reconnection. Expired grants and sessions reconcile on app resume, service connection, eligible window event, boundary callback and clock/time-zone broadcasts. Every delayed callback consults current identity/state; old callbacks cannot restore old protection or override newer access. Requested status, registered **inexact** work, actual overlay timestamp, failure and unknown coverage are separately displayed. No enabled-service-to-observed shortcut.

Runtime apply/cleanup/service/storage failure opens protection and sets an explicit repair requirement. Storage corruption/incompatible files remain preserved and write-fenced; recovery data never resumes blocking automatically. Monotonic/wall/boot samples detect clock jumps/reboot; absolute planned boundaries remain fixed. A process restart cannot invent historical blocker coverage. No Farm credit is calculated in this slice.

The automatic-start spike persists a delayed occurrence, uses `setAndAllowWhileIdle` (inexact) and a Handler while the process lives. Native instrumentation exercises a one-second delayed start and a four-second interval with an already observed synthetic target still open, then actual expiry. It demonstrates this configuration only. [Alarm documentation](https://developer.android.com/develop/background-work/services/alarms) and [Doze guidance](https://developer.android.com/training/monitoring-device-state/doze-standby) warn of delayed work. Listener exact alarms without permission remain process-bound; durable exact PendingIntent alarms require additional platform/policy decisions. `USE_EXACT_ALARM` is restricted; `SCHEDULE_EXACT_ALARM` is separately granted/revocable. Neither was requested. No foreground service type was invented; binding is the AccessibilityService mechanism. Force-stop cancels/interrupts this experiment; no continuity is claimed.

## Compatibility proof

[Fixture exporter](../../../../android/compatibility/run.py) uses actual `FarmBackupPayload(document:)`, `decodeRemote` and `fingerprint`. Eight committed synthetic fixtures cover Farm 3/4 × rich/optional-absent × Foundation numeric/server-style ISO dates. No real user data/server reads. Kotlin-origin values independently change wool, lineage/sheep identities, a fractional date, unknown ball ID and Fetch score, then return through Swift and Kotlin. All fields are compared semantically, including receipts/UUID-keyed dictionaries, ownership context, inventory, rewards, optional presence, dates and schema versions; representation differences like scientific numeric notation and map order are not data loss.

All 8 Swift → Kotlin → Swift equality/fingerprint checks pass. Kotlin → Swift → Kotlin also passes. All 23 shared malformed/newer fixtures are rejected by both clients: wire/economy/component versions, missing ledgers/balance, malformed/negative/fractional/quoted amounts, out-of-range Fetch, explicit optional null, duplicate inventory, invalid UUID, invalid calendar/trailing/offset dates and unknown fields. Kotlin additionally rejects malformed JSON, duplicate JSON keys and excessive nesting. Accepted unknown **catalog values** remain intact; unknown **fields/schema versions** cannot produce an encoded candidate.

Ownership is not a `FarmBackupPayload` root field. The fixed synthetic owner lives in exchange metadata and a social member UUID; this proof does not validate auth, same-account identity, request-token pinning or server synchronization. Server ISO behavior is emulated through the installed Swift adapter's documented date strategy, with no server contact. The Kotlin codec is a conservative lossless schema gate, not a permissive domain port. No upload API exists, and incompatible input is never replaced with an empty Farm. Future domain/sync work must retain original pending request bytes/operation identity and pass the Swift lossless check before upload.

Results: [codec log](codec-proof.log), [synthetic exchange](fixture-results.json), [unit/native results](test-results-summary.json). Original fixtures live in `android/compatibility/fixtures/`; generated exchange files remain under ignored `android/build/compatibility` and are hashed in evidence.

## Device evidence and exact commands

No physical device or pre-existing Android SDK/AVD was available. [Pre-emulator adb inventory](physical-device-inventory.txt) contains no devices. A disposable arm64 Pixel 7 profile was created: `emulator-5580`, Android 16/API 36, build fingerprint `google/sdk_gphone64_arm64/emu64a:16/BE2A.250530.026.F3/13894323:userdebug/dev-keys`, 1080×2400/420 dpi, emulator 37.1.11, SwiftShader, headless, snapshots/audio disabled. [Configuration](device-configuration.txt), [emulator log](emulator.log). The emulator was gracefully stopped after inspection, with font scale restored and the prototype service disabled; its isolated AVD/APKs remain on this workspace.

The full final command and local setup are recorded in [commands](commands.md); key gates:

```sh
# From repository root with the recorded Java/Gradle/SDK environment:
python3 android/compatibility/run.py
android/gradlew -p android :app:assembleDebug :app:testDebugUnitTest :app:lintDebug \
  :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.isolatedPrototype=true
```

`ANDROID_SERIAL=emulator-5580` isolates instrumentation. The two native tests cover actual overlay interception (a touch cannot reach the full-screen test button), Brief Access enabling target interaction, observed automatic start/normal expiry, an actual overlay emergency-exit tap, and AtomicFile corruption/recovery/write fencing. Initial checks found and repaired a pending-grant reconciliation bug, date error wrapping/semantic-number comparison issues in the harness, and UI Automator suppression of services. Final results refer to repaired source, not failed attempts. No iOS app build/project regeneration was needed for this independent Android target; the current Swift payload codecs were compiled/exercised directly.

Layout inspection passed for [fresh disclosure](ui-disclosure.png) and explicit refusal at [150% text](ui-refusal-large.png), including [scrolled consent/refusal controls](ui-refusal-large-scrolled.png). Font scale was restored to 1.0 on the disposable emulator. Selection rows have checkbox semantics and minimum 48dp targets. These screenshots are native test tooling, not product capture capability.

Physical enforcement, OEM overnight behavior, battery cost, TalkBack and minimum-OS coverage are **pending**, not inferred from emulator tests. Emulator screenshots/layout inspection are separate from overnight or physical enforcement proof.

## Exact remaining device acceptance procedure

Use disposable/test-profile phones: Pixel, Samsung and one relevant SEA OEM; include API 29 and current API 36. Record model/build/security patch, APK SHA-256, permission/service state, battery optimization, charger/brightness/connectivity and timestamps for each run. Use synthetic target apps only, no founder Farm/account. Install the debug APK locally; no upload/sign-in.

1. Fresh install: refuse disclosure; verify no permission redirect/start/event collection. Accept separately, enable in Settings, select a non-system target. Confirm Counting Sheep, launcher, Settings, dialer/emergency controls and service disable/uninstall remain reachable. Test large text/TalkBack and landscape; read every disclosure/control without clipping.
2. Start manually. Launch target from launcher, deep link, notification and recents. **Attempt a target interaction** under the overlay and record success/failure, not just an enabled-service flag. Test target already open at delayed start, unselected app, keyboard, notification shade, Back/Home, lock/unlock, split screen and PiP. Record uncovered routes explicitly; do not promise website/in-app-browser protection. System/updated-system apps should remain unselectable.
3. Request Brief Access mid-session; export `files/session.json` through `adb run-as` and verify committed UUID/start/end before use. Check five-minute restoration while target stays open, after switching apps, lock/unlock, process death and re-entry. Repeat near a two-minute session end to prove clipping; end early during access. Inject an old occurrence callback while a new session/grant is active and verify no stale restore.
4. Exercise normal end/confirmation and overlay emergency exit. Disable the service during protection: selected app opens, failure/unknown evidence is honest, new start requires reconnect and repair. Terminate/force-stop/reboot; record the interruption and next-entry repair. **Expect no force-stop continuity**. Change clock/time zone and verify frozen boundaries/clock-discontinuity behavior. Corrupt an isolated session file after preserving it; verify no overwrite/automatic blocking and explicit recovery notice.
5. Schedule the inexact two-minute experiment under normal, battery-saver, restricted-background and Doze conditions. Record requested, registered and actual start/expiry times separately, including missed/late alarms. Run at least two full evenings/overnights per OEM, with a five-minute grant crossing a locked period. If the service/overlay does not meet coverage, keep the Phase 1 gate open and decide a narrower promise/mechanism with the founder.
6. Battery measurement: paired eight-hour idle and active-prototype runs, same phone/configuration and starting charge, no charger, repeat twice. On the **isolated** device reset batterystats at each start, save `dumpsys batterystats --charged` and battery-level deltas at end, record wakeups/CPU and service survival. Report raw conditions/results; no emulator battery percentage is a physical measurement.
7. Test OEM backup/device-transfer/reinstall exclusions with synthetic state; verify no selection/active occurrence transfers. Reinstall may require fresh consent/service setup. Preserve raw incompatible fixture/session files before any cleanup.

## Next slice

Close the physical protection/overnight/battery gates before accepting a public protection promise or full UI port. AND-007 can then extend the existing coordinator/store into anchored Wind Down and independent morning settlement, cumulative credit/bonus/access union and idempotent reward replay using the shared fixtures. AND-008 follows with a real guest start-to-receipt journey. Full Farm/Shop/social/auth, SDK sync, Firebase, additional sensitive permissions, production and distribution remain pending/outside this authorization. AND-001/002/006 local proofs are complete; AND-003/004/005 implementation/local experiments are complete with physical gates pending. No blanket Phase 1 acceptance or revised launch-date promise.
