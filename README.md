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
5. Use the default honor timer, an optional Apple Watch placement assist, or a QR phone bed.
6. Let the phone remain tucked away through morning quiet.
7. Return to one calm completion receipt, a collectible, and the quiet minutes from the
   two bookends.

The iPhone owns the wall-clock state and restoration path. The Watch is optional. Nearby
Interaction is a one-time, time-boxed tuck-in assist; it never monitors the whole night,
warns later, or ends Night Watch because distance changed.

## What ships in the first release

- Home and Stats tabs only
- Saved Night Watch schedule and requested wind-down reminder
- Wind-down, overnight, and morning-quiet phases
- Honor timer, optional Watch placement, and QR phone-bed starts
- Local completion notification and phase-aware Live Activity
- Watch companion for status, tuck-in placement, early end, and phone ping
- Local progress, rewards, streaks, sheep, coins, and quiet-bookend history
- Backwards-compatible decoding of earlier `FocusRun` and `UserProgress` data

Farm, Friends, Shop, mock data, HealthKit cards, and Screen Time UI remain gated from
Release. See [ADR-0003](docs/DECISIONS/ADR-0003-gated-features.md),
[ADR-0004](docs/DECISIONS/ADR-0004-watch-independent-sessions.md), and
[ADR-0006](docs/DECISIONS/ADR-0006-sleep-bookends-positioning.md).

## Screen Time and sleep data status

Screen Time is part of the product direction, but not a pretend integration:

- A DeviceActivity report extension and Debug-only selection/report scaffolding exist.
- The extension is not embedded in the release app.
- The app and extension do not yet share an App Group.
- Family Controls distribution approval and matching portal capabilities are required.
- The intended future boundary is the two quiet bookends, using one consented selection.
  App shielding must not cover the entire overnight interval by default.

HealthKit sleep context is also deferred. It may provide optional comparison data later,
but Counting Sheep will not grade sleep or claim that Night Watch caused better sleep.

## Platforms and architecture

- Swift 5.9 and SwiftUI
- iOS 17.0+ and watchOS 10.0+
- XcodeGen (`project.yml` is the project source of truth)
- MVVM plus one iPhone-authoritative session coordinator
- WatchConnectivity, NearbyInteraction, ActivityKit, WidgetKit, and local notifications
- Codable JSON in `UserDefaults` using the `ollie.*` key prefix
- No CoreData or SwiftData

Five targets are generated:

- `PhoneInTheOtherRoom` — iOS app
- `PhoneInTheOtherRoomWatchApp` — optional watchOS companion
- `PhoneInTheOtherRoomLiveActivity` — Lock Screen, Dynamic Island, and Smart Stack status
- `PhoneInTheOtherRoomScreenTimeReport` — deferred DeviceActivity report extension
- `PhoneInTheOtherRoomTests` — shared-domain tests

An optional Supabase-backed Live Activity push sink is present in the current worktree. It
is disabled unless explicitly configured. Local timing, notification, restore, and reward
behavior remain authoritative when the backend is absent or unavailable.

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
- HealthKit and Family Controls entitlements must not be added until the matching product
  gate and Apple portal setup are complete.

Use the same Apple Development Team for the iPhone, Watch, and embedded extensions on
physical hardware. Real-device validation is still required for Nearby Interaction,
overnight restoration, notifications, and ActivityKit transitions.

## Shortcuts

The App Shortcut is named **Night Watch**. It opens Counting Sheep at the saved bedtime
ritual; it does not silently enable a system Focus or start an unseen timer.

## Privacy

Night Watch schedules, progress, rewards, and run snapshots are local by default. No GPS
room identity or raw distance history is uploaded. Review optional backend configuration
and App Store privacy disclosures before enabling any network feature.

## Repository status

This is an active iOS/watchOS prototype, not a hosted web app. The code is available under
the [MIT License](LICENSE). Review [ASSET_NOTICE.md](ASSET_NOTICE.md) before distributing
the checked-in artwork.
