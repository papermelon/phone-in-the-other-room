# Counting Sheep — Project Brief

*(Repo/code name: "Phone in the Other Room". Canonical agent guide: [`AGENTS.md`](../AGENTS.md).)*

## One-paragraph summary

Counting Sheep is an iOS + watchOS app that protects quiet time around sleep. Before
bed, the user starts Quiet Time and physically puts the phone in another room; it
stays tucked away overnight and through a chosen morning-quiet window. An Apple Watch can make
one optional placement check using Nearby Interaction (UWB). Ollie, a pixel-art border collie,
guards the ritual and offers one user-chosen offline cue before bed and after waking. This is
a quiet-time ritual, not a productivity tool or sleep-quality tracker. The established
`NightWatch*` names remain internal for persisted-data compatibility.

## Target user

Someone who scrolls later than intended in bed, reaches for the phone immediately after
waking, and has tried willpower-based fixes that did not stick. They do not want a clinical
sleep app or drill-sergeant blocker; they want the decision taken out of the bedroom, kindly.

## The core bedtime problem

The phone within arm's reach of the bed is the failure point. Software limits are easy to
dismiss in a tired moment. Counting Sheep makes **physical distance** feel like a warm ritual,
then carries that same decision through the first quiet part of the morning.

## The behavioural loop being addressed

```
in bed or newly awake → phone is within reach → "just one check" →
doomscroll longer than intended → less time for winding down or starting the day → repeat
```

Counting Sheep breaks the loop at "phone is within reach" and replaces the extraction point
with a warmer loop:

```
requested wind-down cue → carry phone to its bed in another room →
optional QR/Watch tuck-in check → one offline evening cue → Ollie keeps the quiet →
one quiet morning cue → the phone wakes later → a small completion receipt
```

## Desired emotional tone

Warm. Cozy. Playful but calm. Like a children's-book farm at dusk. The user should feel
*cared for*, never policed, judged, or hustled. Ending a run early earns a sympathetic muddy
paw, not a failure screen. Dark-room-friendly visuals; nothing urgent, flashing, or loud.

## Key product principles (full version: `docs/PRODUCT_PRINCIPLES.md`)

1. Physical separation is the product. Everything else supports the ritual.
2. The edges of sleep are the niche. Evening and morning screen time are the differentiator.
3. Build the ritual through kind habit formation. Completion can reveal varied rewards and
   small insights; never use shame, loss-aversion, paid odds, or rewards for app opens.
4. Low friction wins. One tap to start. Setup is minutes, not a project.
5. Restraint is a feature. When unsure whether to add something: don't.

## MVP scope (first TestFlight build — decided July 2026)

**Shipped surface: two tabs.**

- **Home**: one-time quiet-time plan → saved wind-down reminder → one-tap Quiet Time →
  wind-down / overnight / morning-quiet phases → morning completion or kind early end.
  Active runs label those phases as phone-free wind-down, sleep time, and phone-free morning.
  Silent phase-change notices support bedtime and waking, followed by the requested audible
  completion. Setup also offers a private, optional reason for the quiet; custom wording stays
  in-app unless the person separately allows it in notifications.
- **Nights (one finite scroll)**: the latest quiet-time result with its finish date, the
  latest protected night, a dated seven-night view, inline quiet-time controls, optional
  Apple Health sleep duration and seven-night wake-time range, and separate consented Screen
  Time reports for selected apps in user-chosen evening and morning reporting windows. Health
  samples are matched to the night they end; an older available sample is dated and never
  presented as last night. A collapsed, optional three-question morning note records the
  person's own rough sleep-onset, restfulness, and bedtime-sleepiness reflections without
  producing a score or reward. Screen Time reports identify their report date, show selected
  app time as a share of the full window, offer tappable hourly detail, and distinguish
  Apple's exact first iPhone pickup from selected-app activity. Reporting windows are
  independent of Quiet Time durations. Overnight hours are never credited as focus or quiet
  minutes. Apple's Sleep Score remains in the Health app because HealthKit does not expose it
  to third-party apps.

**Gated out of release builds (code kept behind DEBUG):** Farm, Friends, Shop tabs;
mock-data screens. See `docs/DECISIONS/ADR-0003-gated-features.md`.

**Deferred:** Optional Screen Time shielding for the two quiet-time periods, plus NFC,
remains post-build-1 and gated separately (see
`ADR-0004`).

## Non-goals

- Generic productivity / pomodoro timing
- Medical or clinical sleep tracking, sleep-quality scoring, or health claims
- Social feeds, leaderboards, or competitive mechanics
- Engagement for its own sake — success is the user returning for the phone-away ritual,
  then using selected distracting apps less around sleep
- Android, iPad, or web versions (iPhone-first; Watch is an optional tuck-in assist)

## Success criteria for TestFlight

1. **It ships**: signed build on TestFlight, installable by external testers, no P0 crashes
   in the first two weeks.
2. **The ritual sticks**: testers complete Night Watch on 5+ of their first 14 nights.
3. **The tone lands**: qualitative feedback uses words like "cute", "calm", "gentle" — and
   nobody reports feeling guilted or nagged.
4. **The pitch is legible**: a new tester can explain what the app does after one session
   ("it puts my phone to bed and helps me wake before it, and there's a dog").
5. **The optional start choices are legible**: testers can begin with the honor timer and
   understand Watch or QR as optional phone-bed assists rather than prerequisites.
