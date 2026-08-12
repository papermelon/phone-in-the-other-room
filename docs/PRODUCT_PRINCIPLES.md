# Product Principles — Counting Sheep

Current product guidance for deciding what to build and how it should feel. Product hypotheses
and taste judgments remain revisable through explicit founder direction; technical, legal,
privacy, and platform constraints should be named separately. Canonical guide:
[`AGENTS.md`](../AGENTS.md).

## Philosophy

Counting Sheep succeeds when people use distracting apps *less around sleep*. That inverts the usual
app incentive, and every design decision must respect the inversion: we cannot measure
success by engagement, session length, or opens. The product is a **ritual** — carrying the
phone to another room and letting Ollie stand guard through a quiet wind-down and a short
quiet time after waking. The app exists to make that ritual easy to start, warm to complete, and safe
to fail.

The emotional register is a children's-book farm at dusk: soft, patient, a bit whimsical.
The user is tired. Meet them there.

## Habit formation and Farm progression

Counting Sheep deliberately competes with the pull of social apps. It should become a
habitual part of a sleep-bookends ritual—not by keeping people scrolling, but by making the
phone-away choice feel warm, rewarding, and worth repeating.

1. **One night, one search.** The first three completed protected nights guarantee a sheep.
   After that, each completed night advances Ollie's search and may find a sheep. Encounter
   odds, rarity, streak momentum, wanted posters, and a favoured Trail Board lead can shape
   anticipation. Search outcomes are persisted once and protected by a bad-luck guarantee.
   Completed additional-quiet periods may map up to 75 quiet minutes for a future,
   non-guaranteed search: each 15 minutes can add one percentage point, up to five.
   Guaranteed searches and early endings consume none; additional quiet never finds a sheep.
2. **Discovery and ownership differ.** Ollie's Trail Notes and catalogue discoveries remain
   historical records. The active flock is finite inventory: sheep can stay, be sheared for
   wool, or be traded to another farm for wool without erasing the discovery.
3. **Several play styles should work.** A collector can expand toward 60 active sheep; a wool
   farmer can manage regrowth; a trader can exchange sheep for immediate wool and capacity; a catalogue player can pursue new
   definitions; and a decorator can spend on Ollie, Your Shepherd, collectibles, and the Farm.
4. **Capacity creates a decision.** A full Barn sends new sheep to a persisted arrival gate.
   The player makes room, expands, or sells; the app does not invent a silent outcome.
5. **Progress stays linked to the ritual.** Wool regrowth advances through completed protected
   nights. App opens, overnight hours, and passive wall-clock waiting do not manufacture Farm
   output.
6. **Blocking stays consensual.** The user picks
   what's blocked, shield copy is gentle, and an emergency exit is always available. We add
   friction, never bars.
7. **Offline cues remain suggestions, not Farm gates.** The user may choose one evening and one
   morning activity. Never require a checklist, photo, AI proof, or completed habit to end
   Night Watch or regain essential phone access.

## How to evaluate new mechanics

Describe the concrete loop, the behavior it rewards, the information the player sees, and what
happens after absence. Evaluate urgency, scarcity, randomness, monetization, and loss through
their actual implementation and effect. Do not replace that analysis with a generic blacklist,
and do not present an agent's preference as founder intent.

The current Farm uses explicit local prices, deterministic settled outcomes, finite inventory,
and user-directed lifecycle actions. Later mechanics should record their own rules and tradeoffs
in an ADR rather than inheriting an assumed prohibition.

## Does this feature belong? (the belonging test)

A feature proposal should answer these five questions:

1. **Ritual test** — does it make the phone-away sleep-bookends ritual easier, warmer, or more
   trustworthy? (Not "is it cool", not "do competitors have it".)
2. **Sleep-bookends test** — does it serve the wind-down, overnight separation, or
   morning-quiet continuation? Generic-focus features dilute the positioning (ADR-0006).
3. **Experience test** — what emotion, pressure, and player decision does it create in context?
4. **Subtraction test** — is the app still legible with it added? If a new tester can no
   longer explain the app in one sentence, it doesn't belong yet.
5. **Cost test** — does its review/entitlement/maintenance cost fit the current stage?
   (E.g. HealthKit and Screen Time carry real App Review tax.)

Use the answers to expose tradeoffs and sequencing. The test is a decision aid, not a veto over
explicit founder direction.

## Wind Down UX principles

- **Dark-room friendly.** Evening screens must be comfortable at night: warm darks, low
  contrast jumps, no pure white flashes, nothing animated aggressively.
- **One tap to the ritual.** From app open to run started should be a single decision.
  Configuration lives elsewhere, not in the bedtime path.
- **Wind down, don't rev up.** The pre-sleep flow should get *quieter* as it progresses.
  The completion moment belongs to the morning, not to a late-night celebration.
- **Never make the phone more interesting at night.** The journey remains the default and
  offers no interactive clues or autoplay reveal. During a run, the four finite utility
  roots remain reachable so a person can adjust preferences or inspect their own records;
  a persistent return control leads directly back to Wind Down. This access exception must
  not become a feed, game loop, sheep teaser, or reason to keep holding the phone.
- **Keep Slumber Party outside the active ritual.** Before Wind Down, Home may show one quiet
  positive aggregate. During Wind Down there is no social panel, live update, reaction,
  notification, or novelty. The morning shared pasture is finite, unnamed, and positive-only.
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
- **Share the smallest social truth.** Slumber Party publishes only `phoneTucked` and
  `morningQuietCompleted` for an explicitly shared eligible night. Private nights, additional
  quiet, absence, early endings, times, durations, HealthKit, Screen Time, NFC, purpose,
  notification, Farm, sheep, wool, and impact data do not enter its contracts. Small-flock
  aggregates must not reveal which person is absent.

## Durable product commitments

1. Optimise for healthier bedtime behaviour, not time inside Counting Sheep.
2. Support the ritual; do not become the ritual.
3. Measure only what creates understandable user value.
4. Label observation, inference, and self-report honestly.
5. Treat sleep outcomes as context and association, never proof or diagnosis.
6. Prefer one small, transparent experiment over opaque scores or AI advice.
7. Make return states and absence consequences explicit product decisions.
8. Keep NFC optional, shielding consensual, and the emergency exit obvious.
9. Earn trust locally before asking to share minimised impact data.
10. Graduation or lower-frequency use is a successful outcome.

## Copywriting tone

Voice: Ollie's farm — warm, brief, lightly playful, never clinical, never corporate,
never drill-sergeant. Full guide with examples: `skills/product-copy-review/SKILL.md`.

- Say "phone slept in the other room", not "screen time reduced by 47 minutes".
- Say "wake up before your phone does", not "optimize your morning productivity".
- Say "your trail is waiting", never "you lost everything".
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

## Current implementation exclusions

- No medical/sleep-quality claims or scores.
- No general Friends, social comparison, or backend avatar profile in the current Farm scope.
  ADR-0016 separately permits only the invite-only seven-night Slumber Party companion ritual.
- No real-money purchase path in ADR-0015; Farm Shop prices use local wool only.
- No automatic sheep expiration, breeding, or seasonal migration in the first lifecycle slice.
- No generic productivity framing; progression remains the payoff of the sleep-bookend ritual.
- No unsequenced mock-backed features: production surfaces use real models and persisted data.
