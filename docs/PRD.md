# Phone in the Other Room PRD

## Product Identity

Repo / code name: **Phone in the Other Room** (folder names and target names still use this).

In-app identity / shipping display name: **Counting Sheep** (`CFBundleDisplayName` in `project.yml`).

Mascot: Ollie, an original stylized brown-and-white Border Collie with upright ears, a white face blaze, brown eye patches, round expressive eyes, energetic posture, and a happy tongue-out personality.

## Core Promise

Instead of fighting your phone, you send it to the other room and let Ollie guard your focus.

The user starts a Focus Run, leaves the iPhone behind, and uses Apple Watch as the active companion. If the user stays away until the planned duration ends, Ollie returns with a reward. If the user comes back early and remains too close after a warning grace period, Ollie comes back sad but encouraging.

## MVP Scope

The MVP is an active foreground iOS plus watchOS focus-session game. The iPhone app remains open on a "leave me here" screen during a run. The Watch app is the glanceable active companion while the user is away.

The app is not a lost-phone product, a generic Pomodoro timer, a GPS tracker, an always-on detector, or a replacement for Find My.

## Core Loop

1. User opens Phone in the Other Room.
2. User chooses a Focus Run duration with a minute/second picker.
3. User taps **Send Ollie Out**.
4. User sees a Focus Mode pop-up prompt and approves or skips it.
5. Placement grace starts, defaulting to 60 seconds.
6. User leaves the iPhone in another room.
7. Apple Watch becomes the primary interface.
8. Proximity is validated through Nearby Interaction or fallback state.
9. Ollie guards the Focus Run.
10. Completion grants a collectible reward.
11. Early return warns first, then ends early only after sustained closeness.

## States

Focus run states: setup, placementGrace, waitingForPhoneAway, running, warningPhoneTooClose, completed, endedEarly, signalLost, unsupported, demo.

Proximity buckets: waitingForDistance, withYou, sameRoom, doorway, probablyOtherRoom, signalLost, unsupported, demo.

Ollie moods: waiting, excited, running, guarding, alert, proud, happy, sad, sleepy.

## Timing Defaults

- Placement grace: 60 seconds
- Warning grace: 60 seconds
- Signal lost grace: 20 seconds
- Default run: 25 minutes

A run succeeds if the planned end time has passed and the run did not end early. Coming back after the planned duration counts as success. A run only fails early after phone-away was validated, the run is still before its planned end, the phone becomes too close, warning state appears first, and closeness remains sustained beyond warning grace.

## Proximity Classifier

Default thresholds:

- withYouMax: 1.5 meters
- sameRoomMax: 5 meters
- otherRoomMin: 8 meters
- staleAfter: 8 seconds
- sustainedSamples: 3 readings

The classifier uses recent readings, freshness, source, support state, smoothing, confidence, and run context. It avoids flicker and never fails from one noisy sample.

Battery-aware checking: the start of a Focus Run keeps a short startup distance window open while the user puts the phone down and accepts any permission prompts. After that, the app rests Nearby Interaction and wakes short randomized check windows. A user can also request a check from iPhone or Apple Watch to see a fresh distance reading during the run. Close-phone checks warn the user on both devices before repeated warnings can end the run.

## Rewards and Progress

Completed runs earn Ollie-themed rewards such as Ollie Mail, First Run Ribbon, Tiny Tennis Ball, Field Map, Sheep Badge, and Focus Trophy. Early-ended runs do not earn a main reward but may earn a consolation Muddy Paw Print.

Progress is local only: completed runs, focus minutes, streak, longest streak, rewards collected, Ollie level, daily focus records, focus stars, sheep balance, and coin balance.

Daily focus stars are awarded from completed other-room minutes: silver at 15 minutes, gold at 30 minutes, diamond at 60 minutes, and rainbow at 120 minutes. These thresholds provide a friendly daily mission without requiring continuous background monitoring. Ollie's idle daily status reflects today's focus rhythm instead of using body-shape or shame-based language.

Sheep are earned from completed Focus Run minutes and represent the farm resource. Coins are also earned locally for now and are intended to buy future cosmetics for Ollie and the room. A later economy pass can add sheep selling, conversion rates, caps, upgrades, and item pricing.

The stats surface is organized into three views:

- Today: other-room minutes, current daily star, screen time so far, and an evening phone-away goal after 6pm.
- Trends: 7-day other-room minutes, screen time trend, completion rate, and best focus time.
- Sleep & Recovery: last night sleep, bedtime phone-away minutes, and late screen time.

Screen Time requires the Family Controls capability and Screen Time API extensions. The code scaffolding exists (authorization request, FamilyActivityPicker source selection, DeviceActivityReport views, and a report extension target), and actual totals would be produced by the Device Activity report extension inside Apple's privacy sandbox. Status: scaffolded in code but **not entitlement-wired** — the entitlement files are empty, the Family Controls capability is not set up, and the feature is deferred per the `docs/PROJECT_BRIEF.md` MVP scope.

Health sleep requires the HealthKit capability and user permission to read `sleepAnalysis` samples. After permission, the app can query last-night sleep directly from the main iOS app. Status: scaffolded in code but **not entitlement-wired** — deferred per the `docs/PROJECT_BRIEF.md` MVP scope.

## Privacy

No cloud database, analytics, GPS, room identity, third-party tracking, or uploaded distance readings. The prototype stores only lightweight local state, progress, rewards, calibration thresholds, and recent events.

## Prototyping Approach

Failure and feedback paths should be tested deliberately: noisy readings, unsupported hardware, Watch reachability loss, early return, and warning recovery. The product should stay privacy-preserving, local-first, and kind: Ollie warns, recovers, and encourages rather than shaming the user.

## Technical Requirements

- SwiftUI iOS app target
- SwiftUI watchOS app target
- Shared Swift models and engines
- WatchConnectivity message plumbing
- NearbyInteraction provider where supported
- Friendly unsupported states when distance checks are unavailable
- UserDefaults persistence
- AVFAudio phone ping sound
- WatchKit haptics
- Focus Mode suggestion flow that never silently toggles Focus
- Shortcuts/App Intent support for preparing a Focus Run so the user can build a Shortcut with Apple's Set Focus action and Open App action

## Demo Acceptance

The 3-minute demo must show: home, duration selection, Send Ollie Out, Focus prompt, placement grace, active guarding, warning/recovery on supported hardware, completion, reward reveal, reward shelf, and optional early-end path.
