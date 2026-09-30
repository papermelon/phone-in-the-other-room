# AND-007 commands and isolation

Run from the repository workspace unless a directory is specified. Existing workspace-local SDK/JDK/caches were reused; no dependencies, permissions or services were added to the application. Gradle/Swift/adb were permitted to use local process sockets. All Gradle commands below used `--offline`. No production endpoint/account/fixture was involved.

## Final gates

```sh
cd android
. ./env-local.sh
# Confirmed disposable emulator: sdk_gphone64_arm64, serial emulator-5580.
adb -s emulator-5580 shell getprop ro.product.model
# Reset a stale binding left by a suppressed service during screen inspection:
adb -s emulator-5580 shell settings delete secure enabled_accessibility_services
adb -s emulator-5580 shell settings put secure accessibility_enabled 0
adb -s emulator-5580 shell settings put system font_scale 1.0
ANDROID_SERIAL=emulator-5580 ./gradlew --offline \
  :app:assembleDebug :app:testDebugUnitTest :app:lintDebug :app:connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.isolatedPrototype=true \
  > ../docs/evidence/android-port/2026-09-30-and-007/final-verification.log 2>&1
```

Exit 0, `BUILD SUCCESSFUL in 35s`: 42 JVM unit tests, six native tests, debug build and lint. Explicit disposable-emulator opt-in and model checks gate instrumentation settings changes. Native transaction tests use only `cacheDir/and007-isolated-domain`, cleared before/after each case. The preflight's separate attempted empty-list `settings put ... ''` returned `Bad arguments` because adb dropped the empty argument; it changed no setting. `accessibility_enabled 0` effectively reset the binding. For a future explicit disposable reset use `settings delete secure enabled_accessibility_services` before enabling, rather than an empty put.

```sh
# In android/, with env-local.sh sourced:
cd ..
python3 android/compatibility/run.py \
  > docs/evidence/android-port/2026-09-30-and-007/parity-proof.log 2>&1
```

Exit 0: current temporary Swift package build; 142 current Swift tests; generated synthetic domain fixtures twice with matching SHA-256; newly generated wire values compare against all eight unchanged original fixtures; Kotlin semantic/wire tests; Swift wire equality/fingerprint return; Kotlin return verification. Internally the harness runs:

```sh
swift build --package-path "$TEMP_PACKAGE" --jobs 4
swift test --package-path "$TEMP_PACKAGE" --jobs 4
# Temporary compiled binary:
CodecProof generate "$GENERATED_FIXTURES"
CodecProof generate "$GENERATED_FIXTURES"
CodecProof compare "$GENERATED_FIXTURES" android/compatibility/fixtures
android/gradlew -p android --offline :app:testDebugUnitTest \
  --tests '*FarmPayloadCodecTest' --tests '*DomainParityTest' --rerun-tasks
CodecProof verify android/compatibility/fixtures android/build/compatibility
android/gradlew -p android --offline :app:testDebugUnitTest \
  --tests '*FarmPayloadCodecTest' --tests '*DomainParityTest' --rerun-tasks -DverifySwift=true
```

The variables above represent temporary directories created by `run.py`; no personal defaults, Farm or server data are read. Exact subprocess arguments are in that harness. After its filtered runs, restore the full report:

```sh
cd android
. ./env-local.sh
./gradlew --offline :app:testDebugUnitTest \
  > ../docs/evidence/android-port/2026-09-30-and-007/full-unit-results.log 2>&1
```

Exit 0, all 42 tests pass. [Suite summary](test-results-summary.json), the five `TEST-*.xml` unit reports and [native XML](native-test-results.xml) were copied into evidence with the lint report. Build APKs and ignored fixture exchange outputs are hashed in `artifact-sha256.json`. Entry/final source SHA-256 and git status were recorded; `git diff --check` passes. Documentation references and changed-file whitespace were checked separately.

## Failure/repair evidence

- Early app compile/fixture errors were repaired before successful checks; logs `initial-build.log`, `domain-build.log` and `local-verification.log` reflect intermediate successful source, not the final source gate.
- Initial native cold-launch run: `instrumentation-initial-failure.log`, one overlay wait failure while the Activity launched late under concurrent build load. Repeated full instrumentation on the warmed emulator passed. No wait duration was increased.
- Later native run: `instrumentation-stale-binding-failure.log`, one “Service must actually connect” failure after manual `uiautomator dump` suppressed/unbound the service. Reset on the disposable emulator, then the final six-test run passed. Product service reconnect/failure repair behavior remains explicit; an enabled setting alone is not accepted as a connection.
- Regression verification after the pending-write fence/codec checks: `./gradlew --offline :app:testDebugUnitTest --tests '*SessionDomainTest' --tests '*SessionDocumentTest'`; exit 0, `repair-regressions.log`. The final full suite contains those cases.

## Emulator and UI inspection

The existing AVD was launched from `android/` with its existing `env-local.sh`:

```sh
emulator -avd counting-sheep-isolated-api36 -no-snapshot -no-boot-anim \
  -no-audio -no-window -gpu swiftshader -port 5580 \
  > ../docs/evidence/android-port/2026-09-30-and-007/emulator.log 2>&1
```

After final native tests, install only the existing debug/test APKs and launch the app:

```sh
adb -s emulator-5580 install -r app/build/outputs/apk/debug/app-debug.apk
adb -s emulator-5580 install -r app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk
adb -s emulator-5580 shell am start -n \
  com.ngawangchime.countingsheep.prototype.debug/com.ngawangchime.countingsheep.prototype.ui.MainActivity
```

The disclosure was accepted through its visible button, the synthetic target selected and short Wind Down started through visible controls. Existing service settings were enabled only on this confirmed disposable emulator. Screen captures use `adb shell screencap -p /sdcard/and007-ui.png` plus `adb pull` to this evidence directory; this is external QA tooling, not an app permission. Plain `uiautomator dump` was avoided during final live inspection because it suppresses the service. Internal files were read only with `adb -s emulator-5580 shell run-as com.ngawangchime.countingsheep.prototype.debug cat files/session.json` into the three `ui-synthetic-session-*.json` files. They contain only the synthetic test package/local guest scenario.

`settings put system font_scale 1.5` plus scrolling exercises large text; `settings put system font_scale 1.0` restores it. Final cleanup disables this prototype service, removes its temporary screenshot from sdcard and gracefully stops this isolated emulator. No other serial/device or personal setting was targeted. A separate physical acceptance pass remains pending.
