# Counting Sheep

> Contributors and agents: read [AGENTS.md](AGENTS.md) first. It is the canonical guide.
> Product scope lives in [docs/PROJECT_BRIEF.md](docs/PROJECT_BRIEF.md).

**Counting Sheep** is an iPhone and Apple Watch bedtime-ritual app built around one idea:

> Put your phone to bed. Wake up before it does.

Ollie, a border collie, keeps Night Watch while the phone rests in another room. One
phone-away session spans a quiet wind-down, the overnight interval, and a short
morning-quiet bookend. Counting Sheep records the quiet minutes at the two edges of sleep;
it never counts overnight hours as focus, scores sleep quality, or promises a sleep outcome.

The repository folder and target names still use the code name **Phone in the Other Room**.

## Current product loop

1. Save an intended bedtime and wake time.
2. Choose a modest quiet window before bed and after waking.
3. Pick one gentle offline cue for each bookend, such as reading, stretching, breakfast,
   or opening the curtains.
4. At wind-down, tuck the phone away and begin Night Watch.
5. Use the default honor timer, an optional Apple Watch placement assist, QR phone bed, or
   locally registered NFC phone-bed tag.
6. Let the phone remain tucked away through morning quiet.
7. Return to one calm completion receipt; one equal sheep settles into the cumulative flock.

The iPhone owns the wall-clock state and restoration path. The Watch is optional. Nearby
Interaction is a one-time, time-boxed tuck-in assist; it never monitors the whole night,
warns later, or ends Night Watch because distance changed.

## What ships in the first release

- Home, Nights, and Farm tabs, with More as a top-right utility sheet
- Saved Night Watch schedule and requested wind-down reminder
- Wind-down, overnight, and morning-quiet phases
- Honor timer plus optional Watch, QR, and NFC phone-bed starts
- Optional selected-app shielding during wind-down and morning quiet only
- Optional read-only Apple Health sleep duration/stages and local outcome comparison
- Separately consented, minimised impact sharing with stop/delete controls
- Local completion notification and phase-aware Live Activity
- Watch companion for status, tuck-in placement, early end, and phone ping
- One-night-one-sheep flock, local streak record, and quiet-bookend history
- Optional private in-app feedback with a release-safe email fallback
- Backwards-compatible decoding of earlier `FocusRun` and `UserProgress` data

Farm, Friends, Shop, the legacy reward shelf, mock data, adaptive coaching, and social
features remain gated from Release and ordinary Debug navigation. See
[ADR-0003](docs/DECISIONS/ADR-0003-gated-features.md),
[ADR-0004](docs/DECISIONS/ADR-0004-watch-independent-sessions.md), and
[ADR-0006](docs/DECISIONS/ADR-0006-sleep-bookends-positioning.md), and
[ADR-0007](docs/DECISIONS/ADR-0007-launch-navigation-flock-and-feedback.md).

## Screen Time and sleep data status

Screen Time reports and selection are embedded. Optional ManagedSettings shields use that
same selection only during the two quiet bookends and lift overnight. The new monitor,
shield-configuration, and shield-action targets exported with Apple Distribution profiles
carrying Family Controls on 2026-07-30. Physical-device proof and App Store server
validation are still required before submission.

HealthKit requests read access only to `sleepAnalysis`. It shows time asleep and available
core/deep/REM stages from one coherent source, then compares protected and other measured
nights locally when sample sizes are sufficient. Counting Sheep reports association, not
causation or a sleep-quality score.

## Platforms and architecture

- Swift 5.9 and SwiftUI
- iOS 17.0+ and watchOS 10.0+
- XcodeGen (`project.yml` is the project source of truth)
- MVVM plus one iPhone-authoritative session coordinator
- WatchConnectivity, NearbyInteraction, ActivityKit, WidgetKit, and local notifications
- Codable JSON in `UserDefaults` using the `ollie.*` key prefix
- No CoreData or SwiftData

Eight targets are generated:

- `PhoneInTheOtherRoom` — iOS app
- `PhoneInTheOtherRoomWatchApp` — optional watchOS companion
- `PhoneInTheOtherRoomLiveActivity` — Lock Screen, Dynamic Island, and Smart Stack status
- `PhoneInTheOtherRoomScreenTimeReport` — DeviceActivity report extension
- `PhoneInTheOtherRoomDeviceActivityMonitor` — quiet-window shield scheduling
- `PhoneInTheOtherRoomShieldConfiguration` — custom shield appearance
- `PhoneInTheOtherRoomShieldAction` — shield-button response
- `PhoneInTheOtherRoomTests` — shared-domain tests

Optional Supabase-backed Live Activity and feedback transports are present. Each is disabled
unless explicitly configured. Local timing, notification, restore, flock, and email-fallback
behavior remain available when the backend is absent or unavailable.

## Build and test

Install XcodeGen, then run:

```bash
xcodegen generate
xcodebuild build \
  -project PhoneInTheOtherRoom.xcodeproj \
  -scheme PhoneInTheOtherRoom \
  -destination 'generic/platform=iOS Simulator'
```

List available simulators with `xcrun simctl list devices available`, then run tests with
one installed device name:

```bash
xcodebuild test \
  -project PhoneInTheOtherRoom.xcodeproj \
  -scheme PhoneInTheOtherRoom \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

The shared scheme builds the iPhone app, embedded Watch app, and Live Activity extension.
Do not hand-edit `PhoneInTheOtherRoom.xcodeproj/project.pbxproj`; regenerate it from
`project.yml`.

## Permissions and hardware behavior

- Notifications are requested in context when saving or starting Night Watch.
- Camera access is used only for the optional QR phone-bed scan.
- Nearby Interaction is used only for the optional Watch tuck-in assist and degrades to
  the honor timer on unsupported or unreachable setups.
- No GPS location permission is requested.
- HealthKit reads only sleep analysis. Family Controls covers reports and optional shielding.
  The matching production capabilities/profiles must exist for every embedded target.

Use the same Apple Development Team for the iPhone, Watch, and embedded extensions on
physical hardware. Real-device validation is still required for Nearby Interaction,
overnight restoration, notifications, and ActivityKit transitions.

## Shortcuts

The App Shortcut is named **Night Watch**. It opens Counting Sheep at the saved bedtime
ritual; it does not silently enable a system Focus or start an unseen timer.

## Privacy

Detailed schedules, ritual events, reflections, HealthKit context, progress, and rewards
are local by default. Optional impact sharing omits exact dates/times, raw Health samples,
source names, app selections, NFC identity, and free text. See
[the 1.0 data map](docs/PRIVACY_DATA_MAP.md).

## Repository status

This is an active iOS/watchOS prototype, not a hosted web app. The code is available under
the [MIT License](LICENSE). Review [ASSET_NOTICE.md](ASSET_NOTICE.md) before distributing
the checked-in artwork.
