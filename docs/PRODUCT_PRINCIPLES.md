# Product Principles — Counting Sheep

Durable rules for deciding what to build, how it should feel, and what to refuse.
These are hard constraints, not preferences. Canonical guide: [`AGENTS.md`](../AGENTS.md).

## Philosophy

Counting Sheep succeeds when people use distracting apps *less around sleep*. That inverts the usual
app incentive, and every design decision must respect the inversion: we cannot measure
success by engagement, session length, or opens. The product is a **ritual** — carrying the
phone to another room and letting Ollie stand guard through a quiet wind-down and a short
quiet time after waking. The app exists to make that ritual easy to start, warm to complete, and safe
to fail.

The emotional register is a children's-book farm at dusk: soft, patient, a bit whimsical.
The user is tired. Meet them there.

## Habit-formation guardrails (hard boundaries)

Counting Sheep deliberately competes with the pull of social apps. It should become a
habitual part of a sleep-bookends ritual—not by keeping people scrolling, but by making the
phone-away choice feel warm, rewarding, and worth repeating.

1. **One night, one sheep.** A completed protected night settles exactly one equal sheep
   into the flock. The arrival happens once after the ritual, never after an app open,
   refresh, or paid action. Longer bookends, fewer warnings, Watch ownership, and an
   unbroken streak do not improve its value. Do not show rarity, odds, countdowns, locked
   slots, currencies, or future-arrival teasers. See `docs/REWARDS.md`.
2. **No loss-aversion streak mechanics.** A streak is a record of care, not a hostage. A
   missed night resets nothing punitively and generates no "you'll lose everything!" copy.
3. **No infinite or bottomless surfaces.** No feeds, no endless scrolls, no autoplaying
   sequences. Every screen has a floor.
4. **No empty engagement bait.** No badges for opening the app, no daily-login rewards,
   no paid randomness, and no notification designed to pull the user in at night.
   Notifications exist only to support an active run or a ritual the user asked for.
5. **No guilt or shame, ever.** Not in copy, not in visuals, not in mechanics. An early-ended
   run gets a warm factual receipt, adds no sheep, and loses nothing.
6. **Blocking must stay consensual.** If/when app-blocking ships (ADR-0004): the user picks
   what's blocked, shield copy is gentle, and an emergency exit is always available. We add
   friction, never bars.
7. **Offline cues are suggestions, not gates.** The user may choose one evening and one
   morning activity. Never require a checklist, photo, AI proof, or completed habit to end
   Night Watch or regain essential phone access.

## Playful, not manipulative — the distinction

Playful: Ollie has moods. Sheep may have names later. The flock can be *looked at fondly*,
but every sheep represents the same completed ritual and the flock is never a compulsion.

Manipulative: rewards for mere app opens, paid random outcomes, countdowns that pressure,
red badges, "your friends did X", limited-time rewards, progress bars that reset on
failure. None of this ships, regardless of metrics.

The test: **would this mechanic still feel kind if the user ignored the app for a month?**
If returning after a month feels like being welcomed back, it's playful. If it feels like
being billed for absence, it's manipulative.

## Does this feature belong? (the belonging test)

A feature belongs only if it passes all five:

1. **Ritual test** — does it make the phone-away sleep-bookends ritual easier, warmer, or more
   trustworthy? (Not "is it cool", not "do competitors have it".)
2. **Sleep-bookends test** — does it serve the wind-down, overnight separation, or
   morning-quiet continuation? Generic-focus features dilute the positioning (ADR-0006).
3. **Kindness test** — can it be built without guilt, pressure, or engagement bait?
4. **Subtraction test** — is the app still legible with it added? If a new tester can no
   longer explain the app in one sentence, it doesn't belong yet.
5. **Cost test** — does its review/entitlement/maintenance cost fit the current stage?
   (E.g. HealthKit and Screen Time carry real App Review tax.)

When a feature fails the test but seems valuable later, record it as gated with explicit
milestones (see ADR-0003) rather than half-shipping it.

## Wind Down UX principles

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
  warmth is felt. Keep the chosen morning-quiet window calm; do not turn it into a routine
  checklist or an app-browsing session.
- **One session, not two timers.** Phone-free time before bed, overnight separation, and quiet
  time after waking are phases of one internal `NightWatch*` session. Independent morning
  focus sessions do not belong.
- **Start small; let people choose.** New plans begin with 30 quiet minutes before bed and
  30 after waking. Longer windows, including a fuller 60-minute wind-down, are selectable
  options rather than a moral standard.
- **Remember the reason, not another task.** A person may name what the offline time makes
  room for—a book, side project, hobby, relationship, or simply rest. Bring that reason
  back gently; never require proof or turn it into a checklist.
- **Private by default.** Custom purpose text stays inside the app unless the person
  separately chooses to let it appear in notification copy.
- **Count the quiet, never the sleep.** Rewards and progress may credit quiet minutes before
  bed and after waking. Overnight hours are recorded only as the internal session interval and
  never converted into focus minutes, stars, or inflated economy.
- **Honest measurement, humble claims.** We count protected nights and quiet bookend minutes.
  With permission, we may show measured sleep duration/stages and self-reported restfulness
  as outcomes. We may describe within-person changes or associations with sample sizes; we
  never say the ritual caused an improvement, diagnose a condition, or issue a sleep score.
- **Reflection without grading.** Optional morning questions may help someone notice their
  own sleep context, but they stay private, produce no score, and never change rewards.
- **CBT-I-informed, not CBT-I treatment.** Favor gentle cues such as going to bed when sleepy
  and keeping wake times steady. Do not prescribe sleep restriction, diagnose insomnia, or
  present the app as a substitute for care.
- **Local insight before cloud collection.** Detailed behavioural events, exact dates,
  HealthKit samples, source names, app selections, and personal reflections stay local.
  Optional impact sharing must be purpose-limited, separately consented, date-free, minimal,
  inspectable in copy, stoppable, and deletable.

## Product constitution

1. Optimise for healthier bedtime behaviour, not time inside Counting Sheep.
2. Support the ritual; do not become the ritual.
3. Measure only what creates understandable user value.
4. Label observation, inference, and self-report honestly.
5. Treat sleep outcomes as context and association, never proof or diagnosis.
6. Prefer one small, transparent experiment over opaque scores or AI advice.
7. Help people recover; never punish absence.
8. Keep NFC optional, shielding consensual, and the emergency exit obvious.
9. Earn trust locally before asking to share minimised impact data.
10. Graduation or lower-frequency use is a successful outcome.

## Copywriting tone

Voice: Ollie's farm — warm, brief, lightly playful, never clinical, never corporate,
never drill-sergeant. Full guide with examples: `skills/product-copy-review/SKILL.md`.

- Say "phone slept in the other room", not "screen time reduced by 47 minutes".
- Say "wake up before your phone does", not "optimize your morning productivity".
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
- Engagement notifications, re-engagement campaigns, badges for app opens, paid random rewards
- Feeds, leaderboards, social comparison, competitive mechanics
- Medical/sleep-quality claims or scores
- Paywalls on kindness (consolations, emergency unlocks must never be monetised)
- Generic productivity framing ("crush your goals", "maximize focus")
- Dark-pattern friction (hard-to-find exits, confirm-shaming, countdown pressure)
- Feature sprawl — when in doubt, do less (the app's #1 recorded risk)
