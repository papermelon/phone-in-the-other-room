# Phone in the Other Room PRD

## Product Identity

Public project name: **Phone in the Other Room**.

In-app identity: **Phone in the Other Room**.

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

Proximity buckets: withYou, sameRoom, doorway, probablyOtherRoom, signalLost, unsupported, demo.

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

## Rewards and Progress

Completed runs earn Ollie-themed rewards such as Ollie Mail, First Run Ribbon, Tiny Tennis Ball, Field Map, Sheep Badge, and Focus Trophy. Early-ended runs do not earn a main reward but may earn a consolation Muddy Paw Print.

Progress is local only: completed runs, focus minutes, streak, longest streak, rewards collected, and Ollie level.

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
