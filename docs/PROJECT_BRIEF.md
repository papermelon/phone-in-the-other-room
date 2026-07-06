# Counting Sheep — Project Brief

*(Repo/code name: "Phone in the Other Room". Canonical agent guide: [`AGENTS.md`](../AGENTS.md).)*

## One-paragraph summary

Counting Sheep is an iOS + watchOS app that helps people stop doomscrolling in bed by making
it warm, easy, and gently rewarding to physically put the phone in another room before sleep.
At bedtime you start a "Focus Run", carry your phone to another room, and your Apple Watch
verifies the separation using Nearby Interaction (UWB). Ollie, a pixel-art border collie,
guards your focus while the phone is away and celebrates when the night is complete. The app
is a bedtime ritual, not a productivity tool: cozy farm aesthetics, no guilt, no manipulation,
and rewards that celebrate rest rather than engagement.

## Target user

Someone who takes their phone to bed intending to sleep, ends up scrolling for an hour or
more, feels worse for it, and has tried willpower-based fixes (grayscale mode, Screen Time
limits, "I'll just check one thing") that didn't stick. They don't want a clinical sleep app
or a drill-sergeant blocker — they want the decision taken out of the bedroom, kindly.

## The core bedtime problem

The phone within arm's reach of the bed is the failure point. Screen Time limits are
dismissable; willpower at 11pm is weakest. The only intervention that reliably works is
**physical distance** — but it feels like a punishment, so people don't sustain it.

## The behavioural loop being addressed

```
in bed → bored/anxious → phone is within reach → "just one check" →
doomscroll → later sleep, worse rest → more tired and anxious tomorrow → repeat
```

Counting Sheep breaks the loop at "phone is within reach" and replaces the extraction point
with a warmer loop:

```
bedtime cue → carry phone to the other room (the ritual walk) →
Watch verifies separation → Ollie stands guard → wind down and sleep →
morning: a completed night, a small celebration, a growing record of
"nights my phone slept in the other room"
```

## Desired emotional tone

Warm. Cozy. Playful but calm. Like a children's-book farm at dusk. The user should feel
*cared for*, never policed, judged, or hustled. Ending a run early earns a sympathetic muddy
paw, not a failure screen. Dark-room-friendly visuals; nothing urgent, flashing, or loud.

## Key product principles (full version: `docs/PRODUCT_PRINCIPLES.md`)

1. Physical separation is the product. Everything else supports the ritual.
2. Bedtime is the niche. Bedtime screen time is the differentiator — not generic focus.
3. Celebrate, never punish. No loss-aversion streaks, no shame copy, no dark patterns.
4. Low friction wins. One tap to start. Setup is minutes, not a project.
5. Restraint is a feature. When unsure whether to add something: don't.

## MVP scope (first TestFlight build — decided July 2026)

**Shipped surface: two tabs.**

- **Home**: pixel dashboard, Ollie, start a Focus Run → setup → active run → completion /
  early end → reward shelf. (This flow is fully implemented and tested.)
- **Stats (minimal, bedtime-framed, native data only)**: nights your phone slept in the other
  room, bedtime streak, evening wind-down minutes, daily stars. No HealthKit, no Screen Time
  in build 1.

**Gated out of release builds (code kept behind DEBUG):** Farm, Friends, Shop tabs;
all Screen Time UI; mock-data screens. See `docs/DECISIONS/ADR-0003-gated-features.md`.

**Deferred:** HealthKit sleep card → TestFlight build 2. Screen Time late-night report and
NFC/QR watch-independent sessions → post-build-1, gated on Apple's Family Controls
distribution approval (request submitted early; see `ADR-0004`).

## Non-goals

- Generic productivity / pomodoro timing
- Medical or clinical sleep tracking, sleep-quality scoring, or health claims
- Social feeds, leaderboards, or competitive mechanics
- Engagement maximisation of any kind — success is the user *not* using their phone
- Android, iPad, or web versions (iPhone-first; Watch as verifier)

## Success criteria for TestFlight

1. **It ships**: signed build on TestFlight, installable by external testers, no P0 crashes
   in the first two weeks.
2. **The ritual sticks**: testers complete a bedtime Focus Run on 5+ of their first 14 nights.
3. **The tone lands**: qualitative feedback uses words like "cute", "calm", "gentle" — and
   nobody reports feeling guilted or nagged.
4. **The pitch is legible**: a new tester can explain what the app does after one session
   ("it gets my phone out of the bedroom, and there's a dog").
5. **Watch-optional demand is confirmed or denied**: we learn how many interested testers
   are blocked by not owning an Apple Watch (validates ADR-0004 priority).
