# Product Principles — Counting Sheep

Durable rules for deciding what to build, how it should feel, and what to refuse.
These are hard constraints, not preferences. Canonical guide: [`AGENTS.md`](../AGENTS.md).

## Philosophy

Counting Sheep succeeds when people use their phone *less* at night. That inverts the usual
app incentive, and every design decision must respect the inversion: we cannot measure
success by engagement, session length, or opens. The product is a **ritual** — carrying the
phone to another room and letting Ollie stand guard — and the app exists to make that ritual
easy to start, warm to complete, and safe to fail.

The emotional register is a children's-book farm at dusk: soft, patient, a bit whimsical.
The user is tired. Meet them there.

## Anti-addiction principles (hard boundaries)

1. **No variable-ratio manipulation.** Rewards may vary in rarity, but never in a way that
   drives compulsive checking. The reward moment happens once, at completion — the app never
   teases "come back to see what you got".
2. **No loss-aversion streak mechanics.** A streak is a record of care, not a hostage. A
   missed night resets nothing punitively and generates no "you'll lose everything!" copy.
3. **No infinite or bottomless surfaces.** No feeds, no endless scrolls, no autoplaying
   sequences. Every screen has a floor.
4. **No engagement bait.** No badges for opening the app, no daily-login rewards, no
   notification designed to pull the user in at night. Notifications exist only to support
   an active run or a ritual the user asked for.
5. **No guilt or shame, ever.** Not in copy, not in visuals, not in mechanics. An early-ended
   run earns a sympathetic consolation (the muddy paw), not a failure state.
6. **Blocking must stay consensual.** If/when app-blocking ships (ADR-0004): the user picks
   what's blocked, shield copy is gentle, and an emergency exit is always available. We add
   friction, never bars.

## Playful, not manipulative — the distinction

Playful: Ollie has moods. Sheep have names. Completing a night feels like tucking the farm
in. Collection exists to be *looked at fondly*, not to be completed compulsively.

Manipulative: countdowns that pressure, red badges, "your friends did X", limited-time
rewards, progress bars that reset on failure. None of this ships, regardless of metrics.

The test: **would this mechanic still feel kind if the user ignored the app for a month?**
If returning after a month feels like being welcomed back, it's playful. If it feels like
being billed for absence, it's manipulative.

## Does this feature belong? (the belonging test)

A feature belongs only if it passes all five:

1. **Ritual test** — does it make the phone-away bedtime ritual easier, warmer, or more
   trustworthy? (Not "is it cool", not "do competitors have it".)
2. **Bedtime test** — does it serve the bedtime niche specifically? Generic-focus features
   dilute the positioning (ADR-0001).
3. **Kindness test** — can it be built without guilt, pressure, or engagement bait?
4. **Subtraction test** — is the app still legible with it added? If a new tester can no
   longer explain the app in one sentence, it doesn't belong yet.
5. **Cost test** — does its review/entitlement/maintenance cost fit the current stage?
   (E.g. HealthKit and Screen Time carry real App Review tax.)

When a feature fails the test but seems valuable later, record it as gated with explicit
milestones (see ADR-0003) rather than half-shipping it.

## Bedtime / sleep UX principles

- **Dark-room friendly.** Evening screens must be comfortable at night: warm darks, low
  contrast jumps, no pure white flashes, nothing animated aggressively.
- **One tap to the ritual.** From app open to run started should be a single decision.
  Configuration lives elsewhere, not in the bedtime path.
- **Wind down, don't rev up.** The pre-sleep flow should get *quieter* as it progresses.
  The completion moment belongs to the morning, not to a late-night celebration.
- **Never make the phone more interesting at night.** No content to browse while a run is
  active. The active-run screen is a status, not a destination — the phone is in another
  room anyway.
- **Respect the morning.** Morning is when rewards land, stats are glanced at, and streak
  warmth is felt. Design celebration moments for waking hours.
- **Honest measurement, humble claims.** We count nights and minutes. We never claim to
  measure or improve sleep quality — that's a medical claim we refuse (ADR-0001).

## Copywriting tone

Voice: Ollie's farm — warm, brief, lightly playful, never clinical, never corporate,
never drill-sergeant. Full guide with examples: `skills/product-copy-review/SKILL.md`.

- Say "phone slept in the other room", not "screen time reduced by 47 minutes".
- Say "tonight's a fresh start", never "you broke your streak".
- Say "helps you wind down", never "improves your sleep" (medical claim).
- Prefer concrete farm imagery over abstraction: Ollie guards, sheep settle, the barn light
  goes out.
- Short sentences. A tired reader at 11pm should never re-read a line.

## Visual design tone

- Pixel/paper farm aesthetic (the `Theme.swift` / `PixelComponents.swift` system) is the
  canonical direction. Warm palette, soft edges, cozy density.
- Nothing urgent-looking: no alarm reds, no aggressive pulsing, no full-screen takeovers.
- Ollie and the sheep carry the personality; UI chrome stays quiet so they can.
- Empty states are cozy, not sad ("the pasture is quiet tonight"), and never nag.

## What to avoid (summary blacklist)

- Streak-loss threats, guilt copy, shame states, "disappointed" mascot moods
- Engagement notifications, re-engagement campaigns, badges for app opens
- Feeds, leaderboards, social comparison, competitive mechanics
- Medical/sleep-quality claims or scores
- Paywalls on kindness (consolations, emergency unlocks must never be monetised)
- Generic productivity framing ("crush your goals", "maximize focus")
- Dark-pattern friction (hard-to-find exits, confirm-shaming, countdown pressure)
- Feature sprawl — when in doubt, do less (the app's #1 recorded risk)
