# Exact local verification commands and outcomes

Working directory: `/Users/ngawangchime/Desktop/Developer Projects/Phone in the Other Room`.
No commit/push/upload/backend command was run. Network access was used only for official SDK/JDK/Gradle/dependency setup and official documentation research. Device mutations targeted the created disposable emulator only.

## Baseline and installation

```sh
git status --short
git rev-parse HEAD
git diff -- project.yml PhoneInTheOtherRoom.xcodeproj/project.pbxproj docs/FUTURE_AGENT_TASKS.md > docs/evidence/android-port/2026-09-30/uncommitted-baseline.patch
shasum -a 256 project.yml PhoneInTheOtherRoom.xcodeproj/project.pbxproj
curl -fL --retry 2 https://dl.google.com/android/repository/commandlinetools-mac-13114758_latest.zip -o android/.toolchain/commandlinetools.zip
curl -fL --retry 2 https://corretto.aws/downloads/latest/amazon-corretto-17-aarch64-macos-jdk.tar.gz -o android/.toolchain/jdk.tar.gz
curl -fL --retry 2 https://services.gradle.org/distributions/gradle-8.13-bin.zip -o android/.toolchain/gradle.zip
curl -fL https://services.gradle.org/distributions/gradle-8.13-bin.zip.sha256 -o android/.toolchain/gradle.sha256
unzip -q android/.toolchain/commandlinetools.zip -d android/.toolchain
tar -xzf android/.toolchain/jdk.tar.gz -C android/.toolchain
mkdir -p android/.toolchain/sdk/cmdline-tools
mv android/.toolchain/cmdline-tools android/.toolchain/sdk/cmdline-tools/latest
unzip -q android/.toolchain/gradle.zip -d android/.toolchain
ln -sfn "$PWD/android/.toolchain" /private/tmp/counting-sheep-android
export JAVA_HOME=/private/tmp/counting-sheep-android/amazon-corretto-17.jdk/Contents/Home
export GRADLE_USER_HOME="$PWD/android/.toolchain/gradle-home"
```

The initial sandbox download/DNS, Gradle lock-listener socket and adb socket attempts were unavailable; authorized setup/checks succeeded with sandbox escalation. No approval rejection occurred. SDK shell launchers also failed because their tools-directory JVM property was unquoted in a workspace path containing spaces. A temporary `.toolchain/sdk-manager` script invokes Java directly:

```sh
base="$PWD/android/.toolchain"
yes | "$base/amazon-corretto-17.jdk/Contents/Home/bin/java" \
  "-Dcom.android.sdklib.toolsdir=$base/sdk/cmdline-tools/latest" \
  -classpath "$base/sdk/cmdline-tools/latest/lib/sdkmanager-classpath.jar" \
  com.android.sdklib.tool.sdkmanager.SdkManagerCli --sdk_root="$base/sdk" --licenses
"$base/amazon-corretto-17.jdk/Contents/Home/bin/java" \
  "-Dcom.android.sdklib.toolsdir=$base/sdk/cmdline-tools/latest" \
  -classpath "$base/sdk/cmdline-tools/latest/lib/sdkmanager-classpath.jar" \
  com.android.sdklib.tool.sdkmanager.SdkManagerCli --sdk_root="$base/sdk" \
  'platform-tools' 'platforms;android-36' 'build-tools;35.0.0' 'emulator' \
  'system-images;android-36;google_apis;arm64-v8a'
android/.toolchain/gradle-8.13/bin/gradle -p android wrapper --gradle-version 8.13 --distribution-type bin
```

Licenses/setup/wrapper succeeded. Wrapper `distributionSha256Sum` was set to the published checksum and the downloaded distribution was verified against it. Java/SDK cache paths are ignored; the generated standard wrapper sources/JAR remain in `android/`.

## Isolated emulator and native tests

```sh
export ANDROID_AVD_HOME="$PWD/android/.toolchain/avd"
mkdir -p "$ANDROID_AVD_HOME"
"$JAVA_HOME/bin/java" "-Dcom.android.sdkmanager.toolsdir=$PWD/android/.toolchain/sdk/cmdline-tools/latest" \
  -classpath android/.toolchain/sdk/cmdline-tools/latest/lib/avdmanager-classpath.jar \
  com.android.sdklib.tool.AvdManagerCli create avd --name counting-sheep-isolated-api36 \
  --package 'system-images;android-36;google_apis;arm64-v8a' --device pixel_7 \
  --path "$ANDROID_AVD_HOME/counting-sheep-isolated-api36.avd" < /dev/null
android/.toolchain/sdk/platform-tools/adb devices -l
android/.toolchain/sdk/emulator/emulator -avd counting-sheep-isolated-api36 -no-snapshot \
  -no-boot-anim -no-audio -no-window -gpu swiftshader -port 5580
export ANDROID_SERIAL=emulator-5580
```

Pre-emulator adb inventory was empty; no physical Android phone. Emulator booted successfully. An initial instrumentation attempt failed because default UI Automator suppressed accessibility services. Fixed using `Configurator.setUiAutomationFlags(FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES)`; subsequent real interception tests passed. The instrumentation opt-in refuses non-`sdk_gphone` devices before modifying accessibility settings.

## Final validation

```sh
python3 android/compatibility/run.py
android/gradlew -p android :app:assembleDebug :app:testDebugUnitTest :app:lintDebug \
  :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.isolatedPrototype=true
android/gradlew -p android :app:dependencies --configuration debugRuntimeClasspath
git diff --check
shasum -a 256 project.yml PhoneInTheOtherRoom.xcodeproj/project.pbxproj
```

Codec command compiles Swift, exports 8 synthetic fixtures, executes the Kotlin codec test, verifies Swift equality/fingerprints plus rejected fixtures, then executes the Kotlin semantic return check. PASS in both directions; 23 shared incompatible documents rejected by both codecs. JVM suite: 16 tests, 0 failures. Native suite: 2 tests, 0 failures/skips on API 36. Build succeeds; lint succeeds with 0 errors and 12 advisory warnings (compatible version pins, API-31 false accessibility-tool attribute ignored on API 29/30, and native Uri.parse versus KTX). No baseline suppression file or skipped failing checks. Final source/configuration and APK hashes are in `validation-hashes.json`. iOS project/source baseline remains intact.

After trimming whitespace in `app/build.gradle.kts`, `:app:assembleDebug :app:testDebugUnitTest :app:lintDebug` was rerun ([log](format-config-validation.log)). This passed in 14 seconds after the sandbox socket denial was retried with authorized escalation. Native source/configuration affecting instrumentation was unchanged; its successful two-test evidence is reused.

UI inspection uses locally installed main/test APKs and synthetic content only:

```sh
adb -s emulator-5580 install -r android/app/build/outputs/apk/debug/app-debug.apk
adb -s emulator-5580 install -r android/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk
adb -s emulator-5580 shell am start -W -n com.ngawangchime.countingsheep.prototype.debug/com.ngawangchime.countingsheep.prototype.ui.MainActivity
adb -s emulator-5580 exec-out screencap -p
adb -s emulator-5580 shell settings put system font_scale 1.5
adb -s emulator-5580 shell input swipe 550 2100 550 750 600
adb -s emulator-5580 shell settings put system font_scale 1.0
```

Screenshots/scroll checks cover fresh disclosure, explicit refusal and 150% text. Touch targets are at least 48dp; selection rows use checkbox toggle semantics; full TalkBack/physical accessibility acceptance is pending. Screenshots are produced by test tooling, not by the product service. System setting changes are confined to the disposable emulator. Native route/overnight/battery checks still pending are enumerated in README.

Final cleanup: `adb -s emulator-5580 shell settings get system font_scale` returned `1.0`; enabled accessibility services contained the literal empty marker `''` (no valid service component); `adb -s emulator-5580 emu kill` gracefully stopped the disposable emulator. The local AVD and installed debug/test APKs remain available for a future isolated run. No personal device was touched.
