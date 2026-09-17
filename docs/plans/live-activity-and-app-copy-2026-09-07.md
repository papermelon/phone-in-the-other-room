# Live Activity and app copy — 7 September 2026

Local source implementation following IMG_8320, IMG_8322, and IMG_8323. Not distributed.

## Findings and behavior

The old Live Activity took the first routine activity's short label, prepended “Tonight:”,
and attached a separately selected educational tip. This produced “Tonight: Change clothes.”
with an unrelated paragraph about keeping work out of bed. Other chosen ideas appeared
in the active app's routine card, but did not rotate through the Live Activity. Optional
midpoint notifications follow notification cadence and educational-tip preferences; they
are not timers for each chosen activity.

The local Live Activity now carries the frozen evening/morning idea lists. It shows the
first full action and the remaining ideas together. Empty lists stay empty rather than
reviving a legacy default. Custom text keeps its case and punctuation, with UTF-8 limits
for the ActivityKit payload budget. Older content states retain their single-title fallback.
The new arrays are local activity fields; they are not added to remote registration or
Slumber Party sharing contracts. General guidance remains in the app/library and optional
notifications; it is no longer randomly paired with a chosen Lock Screen idea.

The old widget preferred the last app-sent phase and marked its content fresh until the
whole run ended. At bedtime its evening timer could therefore stay at zero until an app
update. Rendering now uses anchored dates before the old phase, and the app sets freshness
to the next boundary. Both Lock Screen and Dynamic Island explicitly depend on `isStale`;
the system's first bedtime invalidation projects the saved overnight countdown without
requesting a new run, settling rewards, or claiming sleep/protection evidence.

This is a display projection, not repeated background content delivery. A second exact
boundary or terminal dismissal without a foreground update still needs the existing APNs
path, currently disabled in the local release configuration. No new background entitlement,
server activation, or silent enrollment was introduced. Physical proof of the first
bedtime transition is still required.

Primary platform references:
[Apple's Live Activity update model](https://developer.apple.com/documentation/activitykit),
[staleDate](https://developer.apple.com/documentation/activitykit/activitycontent/staledate),
and [ActivityViewContext.isStale](https://developer.apple.com/documentation/widgetkit/activityviewcontext/isstale).

## Copy review

Reviewed current copy owners across onboarding, routine setup, the active Home journey,
Lock Screen, notifications, receipts/Nights, Farm/help, settings and Slumber Party.
Changed strings favor a clear action, time, object, or destination. Existing consent,
protection, medical, reward and account-ownership boundaries remain intact. This is a broad
editorial pass, not a claim that every app string or localized layout has been approved.

| Surface | Before | Revision / purpose |
| --- | --- | --- |
| Lock Screen | Tonight: Change clothes. | Change into your sleepwear. Uses the complete action. |
| Routine secondary text | Unrelated general tip | The other selected ideas, in the saved order. |
| Overnight | Wind Down continues overnight. The timer is still running. | Settle in for the night. Morning starts at [time]. Names the next boundary. |
| Bedtime notification | Wind Down: overnight | Time for bed. Explains the next countdown. |
| Activity choices | Write / Jot it down / Breathing or relaxation | Write down tomorrow's plans / Write down what's on your mind / Take a few slow breaths. |
| Routine help | Invitations / checklist boilerplate | Explains that ideas appear together and have no individual timers or check-offs. |
| Onboarding | Across the edges of sleep | Before bed, overnight, and after waking. |
| Profile questions | What might the evening quiet hold? | What would you like to do before bed? |
| Home overnight | The timer continues until Screen-Free Morning. | Your countdown now runs until morning. |
| Morning boundary | Wind Down ends at [time] | Screen-Free Morning ends at [time]. Corrects the mode. |
| Receipts | The elapsed timer record is available below. | Your session summary is below. |
| Farm guide | The Barn has a size | Make room for your flock. Explains the capacity choice. |
| Wool guide | Wool over completed Wind Downs | Wind Down and Phone Away credit, including shorter sessions; excludes Brief Access. Aligns with ADR-0020. |
| Settings | Quiet windows / cues | Bedtime and wake time / notifications and countdowns. |
| Slumber Party | Share small moments | Share sessions and send quiet cheers. Names supported actions. |
| Shared ideas | Planned context, not a checklist | Shared ideas don't show which steps someone has done. |

Long consent, source and support details were not removed merely to shorten copy. No custom
user-authored ideas or notification overrides are rewritten in persistent storage.

## Validation

Final local validation:

- Full `xcodebuild build` for scheme `PhoneInTheOtherRoom` with
  `generic/platform=iOS Simulator`: passed, including the app and Live Activity extension.
- Full `xcodebuild test` on iPhone 17e (`71CF8F3E-9E9A-449D-93A8-B73F64869A5E`):
  885 tests passed, zero failures. Two legacy cue expectations initially used the old
  short labels; those expectations were updated and the full suite rerun successfully.
- Final follow-up adds only the DEBUG system-display probe; it passed the full app build.
- Changed-file whitespace checks passed.
- Simulator app launch eventually succeeded. The isolated local ActivityKit request was
  accepted and the system showed its Live Activity permission prompt. However, the Lock
  Screen framebuffer remained black and did not expose the activity text for inspection.
  `lock-screen-probe.png` records this failure, not visual acceptance. No background
  display handoff or large-text/VoiceOver layout pass is claimed from that attempt.

Logs: `tmp/live-activity-copy-review/`. The DEBUG probe uses
`-screenbook-scenario iphone.home.configured.default -screenbook-live-activity`:
45 seconds until bedtime, then a countdown to ten minutes after launch. It creates only a
local Live Activity (`pushType: nil`), with no session, account request, shielding, or rewards.
Do not use this probe to claim end-to-end protected-session behavior.

Regression coverage includes old content-state decoding, first-boundary staleness, stale
phase vs. current clock, terminal/Phone Away precedence, routine ordering, empty routines,
custom punctuation, and payload size with composed emoji. Preview states include three ideas,
large text, and an old evening payload whose bedtime has passed.

Physical acceptance: start a short Wind Down, lock the phone before bedtime, and verify the
label and overnight countdown change without opening the app. Repeat offline, after app
termination, with an early end, and with a later foreground update. Inspect Lock Screen and
Dynamic Island text at supported sizes with VoiceOver. Do not call rendering tests proof of
real device ActivityKit delivery, shielding, sleep, or independently authorized morning starts.
