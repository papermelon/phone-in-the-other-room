# Fetch swipe repair — 20 September 2026

Implemented locally: throws begin on the ball’s 64-point touch area; taps do not throw.
Swipe travel and projected momentum determine the landing point. Fetch has separate grass
bounds, and Ollie stands inward at edge pickups. The ready ball is larger and centered in
the foreground. Status text wraps, accessibility text sizes use stacked controls, and the
Shepherd nameplate stays inside the card. Direction-menu throws remain available.

## Validation

- Full generic iOS Simulator app build passed, including the final DEBUG controls fixture:
  `xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom
  -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/counting-sheep-search-build
  -jobs 2`. See `build.log` and `visual-build.log`.
- The unmodified full test suite could not compile the concurrently added
  `Tests/CampfireProfileTests.swift`: it references `NightFlockViewModel`,
  `FocusRunViewModel` and `PersistenceService`, which are outside the unit target.
  See `full-suite-blocker.log`. This file was not changed by the fetch task.
- With only that file excluded by a command-line build setting, **1,096 tests passed,
  zero failures**, including all **8 fetch domain and 6 fetch view-model tests**. See `tests.log`.
  This is not an unrestricted full-suite pass.
- Test command: `xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom
  -destination 'platform=iOS Simulator,id=F67BB254-5939-41AA-AD11-2B8EAD8E7885'
  -derivedDataPath /private/tmp/counting-sheep-search-build
  -resultBundlePath /private/tmp/fetch-swipe-available-tests-20260920.xcresult
  -parallel-testing-enabled NO -jobs 2 EXCLUDED_SOURCE_FILE_NAMES=CampfireProfileTests.swift`.
- `git diff --check` passed. Touched source hashes are in `source-sha256.txt`.

## Remaining native acceptance

The Mac was locked, blocking CUA gesture/VoiceOver checks. An older QA Simulator stalled
launching the app, and the fresh Simulator stalled in first-boot CoreLocation migration.
The only captured image is the stalled Simulator home screen, not successful fetch evidence.
**Large-text visual acceptance and actual swipe/scroll arbitration remain unverified.**

After unlocking, use the DEBUG launch arguments `--slumber-farm-fixture --farm-state=fetch
--fetch-review --fetch-ready`. Add `--fetch-largest-text` for accessibility size 5, and
`--fetch-controls-only` to inspect the production controls in isolation. Check the full Farm
at large text, ball-only gesture capture, off-ball scrolling, all corners, repeated throws,
Done, VoiceOver direction choices, and Reduce Motion. Confirm flick feel on a physical iPhone.

No archive, TestFlight upload, purchase, persistence change, commit or push was performed.
Progression and Shop additions remain proposals in `docs/plans/fetch-progression-2026-09-20.md`.
