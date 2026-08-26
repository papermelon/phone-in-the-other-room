# Battery and energy audit — 2026-07-31

Scope: the working implementation from session start through placement, foreground and
background phase transitions, completion, restoration, and restart. Findings marked
“proven” come directly from code inspection. Items marked “profile” need physical-device
measurement before drawing a conclusion.

## Ranked findings

### 🔴 Foreground one-second session cascade — proven, fixed

1. **Previous behavior:** `FocusSessionCoordinator` fired every second, updated and
   republished the full `FocusRun`, JSON-encoded and wrote `ollie.lastRun`, and sent a full
   WatchConnectivity state message.
2. **Energy mechanism:** repeated main-thread wakeups, root SwiftUI invalidation, JSON work,
   disk-backed defaults writes, and phone-to-Watch transport.
3. **Overnight/background:** the timer was explicitly invalidated on `.background`, so this
   was not a suspended-app overnight loop. It remained costly whenever the app stayed active.
4. **Change:** one-shot timers now fire only at the next actual phase boundary or completion.
   The iPhone and Watch countdowns and progress use absolute `Date` ranges rendered by SwiftUI.
5. **Expected benefit:** up to 3,600 timer fires, persistence writes, view-model publishes,
   and Watch state sends per foreground hour are reduced to start, lifecycle, phase, and
   terminal events.
6. **Trade-off:** a foreground phase transition may be coalesced by up to one second. Local
   notifications and remote Live Activity phase events remain system-managed.

The active-run progress card subsequently contained a separate `TimelineView(.periodic(...,
by: 1))` for its custom elapsed label. That view was replaced with date-relative
`ProgressView`/`Text` rendering on 2026-07-31; no app-owned one-second UI schedule remains.

### 🟠 Nearby Interaction placement burst — proven, bounded; semantics unchanged

1. **Behavior:** Watch placement starts one `NISession` on each device. The Watch sends each
   distance callback over WatchConnectivity; the phone also processes its own NI callbacks.
   The phone display is kept awake during the check.
2. **Energy mechanism:** UWB/Bluetooth ranging, callback processing, radio messages, and the
   lit display are comparatively expensive.
3. **Overnight/background:** the burst is capped at 30 seconds and stops on confirmation,
   timeout/unavailability, background, reset, or finish. It is not continuous overnight.
4. **Change/proposal:** keep placement-only ranging. Unconfirmed samples now stay in memory
   instead of writing the full run for every callback; background and terminal placement
   events still persist. Profile callback counts first; if transport is material, rate-limit
   Watch distance messages or use them only as a fallback to phone-side readings.
5. **Expected benefit:** the current architecture already avoids hours of UWB use. A later
   transport throttle could reduce energy within the short setup burst.
6. **Trade-off:** removing Watch samples without device testing could reduce placement
   reliability. No sampling change was made in this pass.

### 🟠 Visible Watch countdown timer — proven, fixed

1. **Previous behavior:** `WatchRunView` used a one-second Combine timer while visible.
2. **Energy mechanism:** it woke the Watch app and recomputed the view every second.
3. **Overnight/background:** limited to the visible Watch view, not a background loop.
4. **Change:** system timer text now renders from the absolute target date; a cancellable
   sleeping task wakes only at a phase boundary to refresh surrounding phase copy.
5. **Expected benefit:** no app-owned one-second countdown loop on Watch.
6. **Trade-off:** none expected; phase copy changes only when the phase actually changes.

### 🟠 Optional Supabase / APNs delivery — proven bounded client work; profile framework internals

1. **Behavior:** only when `SUPABASE_LIVE_ACTIVITY_PUSH_ENABLED` is enabled, run sync,
   token registration, and cancellation call Edge Functions. Temporary failures retry after
   2 and 8 seconds. The server schedules two phase pushes plus terminal handling.
2. **Energy mechanism:** network radio activation, authentication refresh, JSON, and retries.
3. **Overnight/background:** there is no client polling loop. Server-to-APNs phase delivery
   does not require app execution. Client requests occur at lifecycle events and token changes.
4. **Proposal:** retain the event model. Use DEBUG transport logs and Network/Power Profiler
   to confirm request counts and inspect any Supabase Auth refresh behavior.
5. **Expected benefit:** no change is justified without evidence; the path is disabled by
   default and already event-driven.
6. **Trade-off:** cancelling or deferring event delivery would make Live Activity phase
   transitions less reliable while the app is suspended.

### 🟡 QR camera and whistle audio — proven, short-lived

1. **Behavior:** the QR sheet runs `AVCaptureSession` until the view disappears. The whistle
   activated an `AVAudioSession` and previously left it active.
2. **Energy mechanism:** camera capture is expensive while visible; an unnecessarily active
   audio session can retain system audio resources.
3. **Overnight/background:** neither is a recurring overnight feature. iOS interrupts camera
   capture when backgrounded, and the sheet stops it when dismissed.
4. **Change:** the whistle now deactivates its audio session when the system alert completes.
   Camera behavior remains unchanged.
5. **Expected benefit:** small cleanup after an occasional action.
6. **Trade-off:** none expected; other audio receives a normal deactivation notification.

### 🟠 Live Activity presentation — countdown efficient; user-controlled

1. **Behavior:** the widget uses `Text(timerInterval:countsDown:showsHours:)` with absolute
   bedtime, wake, and completion dates.
2. **Energy mechanism:** iOS renders the changing countdown; the app does not push seconds.
3. **Overnight/background:** `activity.update()` occurs only on restoration/reconciliation
   and semantic phase changes. Scheduled APNs handles suspended phase changes.
4. **Change:** local Live Activity is enabled by default for new installs and is user-controlled
   in Settings. DEBUG can opt in or out explicitly with `-ollie.debug.enableLiveActivity YES` or
   `-ollie.debug.disableLiveActivity YES`. Local Supabase Live Activity transport remains `NO`
   in both local xcconfig files.
5. **Expected benefit:** normal sessions avoid the Dynamic Island/Lock Screen surface,
   ActivityKit token observation, and optional push-registration/network work. The app still
   owns timing through the same one-shot boundary architecture.
6. **Trade-off:** the glanceable countdown and paired-Watch Smart Stack status are absent by
   default. Re-enable only for controlled comparison or a later product decision; ActivityKit
   also limits an active Live Activity to eight hours.

### 🟢 Dormant background architecture — proven

There are no `BGTask` loops, background fetch loops, Core Location, Core Motion, generic
Bluetooth scans, recurring URLSession work, or continuous animation attached to the active
session. Local notifications are one-shot requests owned by iOS. HealthKit and DeviceActivity
queries occur on their own user-visible surfaces, not as overnight session monitoring.

## DEBUG diagnostics

Unified logging uses subsystem `com.ngawangchime.countingsheep` and these categories:

- `Energy.Session`: boundary timer creation/cancellation and resource teardown snapshots
- `Energy.Persistence`: write count and spacing per defaults key
- `Energy.WatchConnectivity.Phone` / `.Watch`: message count, type, spacing, reachability
- `Energy.NearbyInteraction.Phone` / `.Watch`: NI start, stop, duration, and callback count
- `LiveActivity`: start/update/end counts and token-observer lifecycle
- `LiveActivityTransport`: actual Supabase attempt and outcome

The logs and counters compile only in DEBUG, except pre-existing rare error logs. To profile a
session with a Live Activity, add this launch argument to the Debug Run action:

```text
-ollie.debug.enableLiveActivity YES
```

Normal behavior is now Live Activity-on for new installs, with a visible Settings toggle. End any existing session before recording so a prior
Live Activity cleanup does not contaminate the first measurement.

## Controlled profiling procedure

Use a physical iPhone and paired Watch. Simulator measurements do not represent radio,
display, suspension, or battery behavior.

1. Keep device model, OS, battery range, brightness, Always-On setting, network, Watch
   reachability, and thermal state constant. Disconnect power and profile wirelessly.
2. In Xcode choose **Product → Profile**, start with a blank Instruments trace, and add
   **Power Profiler** and **CPU Profiler**. Add Network and File Activity when isolating
   transport or persistence.
3. Record at least three repetitions of each short scenario and compare equal-duration
   selected ranges. Record CPU, GPU, display, networking, disk activity, wakeups, and the
   per-app power-impact average; do not compare battery percentage from a single run.
4. Capture these scenarios:
   - **A — baseline:** first record the device with the app terminated, then a separate
     idle-app/background trace.
   - **B — session without Live Activity:** use the normal build, honor timer, start the
     session, lock the phone, and record.
   - **C — Live Activity countdown:** add `-ollie.debug.enableLiveActivity YES` and repeat the
     same honor-timer schedule and display conditions.
   - **D — NI/UWB:** choose Watch placement and record from just before start through
     confirmation or the 30-second timeout. Inspect both device logs and WatchConnectivity
     message spacing.
   - **E — full overnight:** use the normal configuration and collect an on-device Power
     Profiler Performance Trace from before start until after completion.
5. For scenario E on current iOS/Xcode, enable Developer Mode, then
   **Settings → Developer → Performance Trace → Power Profiler**, select Counting Sheep,
   and start/stop the Performance Trace control from Control Center. Export the trace and
   open it in Instruments.
6. In the Xcode console, filter on the subsystem above. A healthy honor-timer overnight
   trace should show no one-second persistence or WatchConnectivity stream, no NI start,
   only boundary/lifecycle writes, and Live Activity updates only at reconciliation or
   phase changes.

Apple’s current guidance recommends Power Profiler plus CPU Profiler, equal-condition repeated
comparisons, and on-device Performance Trace for long background cases:
[Profile and optimize power usage](https://developer.apple.com/videos/play/wwdc2025/226/).
Apple also documents that NI produces periodic callbacks while running and that
`invalidate()` stops a session:
[NI lifecycle](https://developer.apple.com/documentation/nearbyinteraction/initiating-and-maintaining-a-session),
[invalidate](https://developer.apple.com/documentation/nearbyinteraction/nisession/invalidate%28%29).
