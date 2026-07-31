# Implementation Notes

This is a practical supplement to `AGENTS.md` and `docs/ARCHITECTURE.md`. It records the
current UI and integration boundaries; those canonical files win if this note drifts.

## Active release navigation

`MainAppTab.visibleTabs` exposes only:

```text
Home
Stats
```

Farm, Friends, and Shop remain compiled only for Debug exploration and are backed by
`MVPMockData`. They must not enter a Release path before ADR-0003's milestones. There is no
Missions tab. Do not add new code to `Views/MVP/` or `MockData/` as part of Night Watch work.

## Night Watch implementation

The active product is one phone-authoritative Night Watch rather than an arbitrary-duration
focus timer.

- `Shared/NightWatch.swift` owns saved schedule semantics, phase boundaries, offline cues,
  reminder start calculation, and quiet-minute accounting.
- `FocusRun` carries an optional `NightWatchPlan`. Keeping the existing type and storage
  names preserves earlier JSON and Watch message compatibility.
- `FocusRunViewModel` persists `NightWatchPreferences`, prepares tonight's plan, schedules
  notifications, and sends the start intent to `FocusSessionCoordinator`.
- `FocusSessionCoordinator` remains the only iPhone run state machine. It moves through
  phases by wall clock and restores the same persisted run after backgrounding or relaunch.
- iPhone, Watch, and Live Activity derive their phase and next transition from the plan.
- `RewardEngine` credits only elapsed wind-down and morning-quiet minutes; overnight time is
  deliberately excluded from economy and progress.

New plans default to the NFC phone-bed guard. The honor timer remains an available fallback;
Watch/UWB and QR confirm only the initial phone-bed ritual. Automatic Wind Down can send
lead-in reminders and schedule selected-app shielding while the app is closed. Continuous
distance warnings are legacy-only states retained for decoding compatibility, not active
product behavior.

## Design and reusable components

Canonical tokens and components live in:

```text
PhoneInTheOtherRoomApp/Design/Theme.swift
PhoneInTheOtherRoomApp/Design/PixelComponents.swift
PhoneInTheOtherRoomApp/Views/Components/AssetPlaceholderComponents.swift
```

New Night Watch UI uses the pixel/paper design layer. `GameComponents.swift` is a legacy
layer and should not receive new features. `AssetSlot` remains the central registry for
catalog names and all missing artwork must keep its placeholder fallback.

`AppColors` supplies adaptive warm-light and night palettes. The app respects system
appearance during the day and requests the night palette while a Night Watch is active or
its bedtime start window is open. Morning completion may return to the system appearance.

## Targets and build generation

`project.yml` generates eight targets:

1. iPhone app
2. embedded Watch app
3. embedded Live Activity extension
4. embedded Screen Time report extension
5. embedded Device Activity monitor extension
6. embedded shield-configuration extension
7. embedded shield-action extension
8. shared-domain unit tests

New files under existing source globs are discovered by XcodeGen. Run `xcodegen generate`
after adding, deleting, or moving files. Never edit `project.pbxproj` by hand.

Signing uses the repository's current bundle IDs and team configuration. Any future edit to
`project.yml`, bundle identity, capabilities, entitlements, targets, or tab structure needs
explicit human confirmation under `AGENTS.md`.

## App Store 1.0 integrations

### Screen Time

Authorization, selection, read-only reports, and optional bookend shielding compile in
Release. One consented selection is shared through the App Group. A DeviceActivity monitor
applies the two schedules; separate configuration/action extensions own appearance and
button behavior. Never add an all-night shield or separate morning session coordinator.
An App Store export produced production profiles carrying Family Controls for every Screen
Time target on 2026-07-30. Physical-device behavior and App Store server validation remain
release gates.

### HealthKit

Release requests read access only to `sleepAnalysis` and shows interval, duration, and
available stages from one coherent source. Requested/no-data/error states remain honest
because HealthKit does not disclose denial of read access. Local comparisons are
sample-qualified and non-causal.

### Hosted Live Activity delivery

Local ActivityKit status and completion notifications are authoritative. The optional
Supabase sink is disabled unless configuration explicitly enables it. Backend or network
failure must never change local run completion, restore, or rewards.

## Validation focus

Shared Night Watch changes require tests for schedule anchoring, cross-midnight phases,
late starts, DST behavior, quiet-minute accounting, and legacy decoding. Physical-device QA
must still cover a full overnight run, termination/relaunch, locked-screen notifications,
Live Activity phase changes, Watch/QR fallback, and timezone changes.
