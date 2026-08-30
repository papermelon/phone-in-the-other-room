# Product Principles — Counting Sheep

Current product guidance for deciding what to build and how it should feel. Product hypotheses
and taste judgments remain revisable through explicit founder direction; technical, legal,
privacy, and platform constraints should be named separately. Canonical guide:
[`AGENTS.md`](../AGENTS.md).

## Philosophy

### Current Slumber Party direction — 2026-08-28

The founder's next-slice decisions supersede older blanket exclusions of social comparison and
new habit information in this document. Slumber Party should support adult mutual accountability
and potentially friendly competition, with a coordinating leader and a chosen Shepherd/Ollie/sheep
identity. Verified exact-app breakdowns for Singapore/SEA are essential, not replaceable by
self-described categories. Sleep duration and week/month means should be legible and explorable.
One explicit agreement accompanies joining; the agreed sharing is then on, with leaving as the
new-sharing stop rather than granular field switches. Adults may join without Health data.
Contextual connection controls must reflect actual evidence, not conflate a permission request
with readable data. Later members should see prior group history, and ordinary leaving should
preserve earlier contributions. This requires a reviewed archive/audience contract and meaningful
privacy withdrawal/deletion; past disclosure is not irrevocable. Respect system permissions,
missing-data uncertainty and offline withdrawal. No new upload is
implied by this product direction: platform feasibility, exact leader/competition rules,
archive duration, audience migration and privacy review precede implementation/release. The existing narrower
V4 implementation and local-first protections remain factual until deliberately changed.
See `plans/slumber-party-shared-habits-and-guide.md` and ADR-0016.

Counting Sheep succeeds when people use distracting apps *less around sleep*. That inverts the usual
app incentive, and every design decision must respect the inversion: we cannot measure
success by engagement, session length, or opens. The product is a **ritual** — carrying the
phone to another room and letting Ollie stand guard through a quiet wind-down and a short
quiet time after waking. The app exists to make that ritual easy to start, warm to complete, and safe
to fail.

The emotional register is a children's-book farm at dusk: soft, patient, a bit whimsical.
The user is tired. Meet them there.

First-run behavioral guidance must be honest and optional. Six short categorical questions stay
local, support only non-clinical patterns justified by explicitly supplied answers, and never
silently choose a schedule or routine. A genuine welcome cosmetic belongs to every new person,
including someone who skips that check-in; choosing one claims it exactly once, with an explicit
wear-now or keep-for-later decision. A schedule describes when Wind Down is planned, an optional
authorized reminder can prompt the person, and only the person's action begins it by default.

## Habit formation and Farm progression

Counting Sheep deliberately competes with the pull of social apps. It should become a
habitual part of a sleep-bookends ritual—not by keeping people scrolling, but by making the
phone-away choice feel warm, rewarding, and worth repeating.

1. **One night, one homecoming.** A new Farm begins with one starter sheep. The first three
   qualifying Wind Downs guarantee a sheep. A qualifying night needs a successfully completed
   primary Wind Down whose protected span from eligible start through morning quiet is at
   least 420 minutes; that span is never described as seven hours asleep.
   After those three nights, each completed qualifying Wind Down may bring another sheep home.
   Chance, rarity, wanted posters, and a favoured Ollie's Search lead can shape anticipation.
   Outcomes are persisted once and protected by a bad-luck guarantee. Completed Phone Away
   periods credit actual quiet minutes to a separate, centrally configured 100-minute meter
   (with carry-over), then Ollie looks for a missing sheep after the first three Wind Downs.
   The first three of those Phone Away finds also guarantee a sheep; later ones use a 20%,
   30%, 40%, 50% ladder, then a guarantee after four clue-only results. Phone Away never
   changes Wind Down odds. The onboarding-practice sheep consumes neither guarantee counter
   nor the meter.
2. **Discovery and ownership differ.** Search Journal and catalogue discoveries remain
   historical records. The active flock is finite inventory: sheep can stay, be sheared for
   wool, or be traded to another farm for wool without erasing the discovery.
3. **Several play styles should work.** A collector can expand toward 60 active sheep; a wool
   farmer can manage regrowth; a trader can exchange sheep for immediate wool and capacity; a catalogue player can pursue new
   definitions; and a decorator can spend on Ollie, Your Shepherd, collectibles, and the Farm.
4. **Capacity creates a decision.** A full Barn sends new sheep to a persisted arrival gate.
   The player makes room, expands, or sells; the app does not invent a silent outcome.
5. **Progress stays linked to the ritual.** Wool regrowth advances through completed Wind
   Downs. App opens, overnight hours, and passive wall-clock waiting do not manufacture Farm
   output.
6. **Blocking stays consensual.** The user picks
   what's blocked, shield copy is gentle, and an emergency exit is always available. We add
   friction, never bars.
7. **Offline cues remain suggestions, not Farm gates.** Wind Down setup may hold an ordered
   private sequence of up to three evening suggestions and two morning suggestions; putting the
   phone away is always first. Never show checkmarks or claim verification, reward, score, streak,
   or completion for a suggestion. Never require a checklist, photo, AI proof, or completed habit
   to end Night Watch or regain essential phone access.

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
- **Keep Slumber Party outside the active ritual.** The feature-gated v4 surface leads from
  Farm and Home to Your Slumber Parties, a people-first list and detail for long-lived,
  invite-only groups with fixed seven-night rounds. During Wind Down there is no in-app social
  panel, live update, reaction, notification, or novelty. Silent Live Activity or Watch feedback
  is best-effort system-surface feedback only and reconciles later; it never changes the ritual.
  Current members can see factual round records, revisioned expiring statuses, curated profile
  snapshots, and fixed cheers. Routines, schedules, absence explanations, Health data, and other
  private details are never shared.
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
- **General sleep-health guidance, not insomnia treatment.** Favor gentle educational cues such as
  going to bed when sleepy and keeping wake times steady. Do not prescribe sleep restriction,
  diagnose insomnia, present the app as a substitute for care, or claim that qualified clinical
  review of the bundled guidance has occurred. The full local source library is reachable through
  “About these ideas and sources.”
- **Local insight before cloud collection.** Detailed behavioural events, exact dates,
  HealthKit samples, source names, app selections, and personal reflections stay local.
  Optional impact sharing must be purpose-limited, separately consented, date-free, minimal,
  inspectable in copy, stoppable, and deletable.
- **Make shared activity worth returning to.** Slumber Party is a core social feature, not a
  subordinate Home link (founder clarification, 2026-08-27). Idle Home can show the same
  member-visible people, factual moments and current statuses as party detail. Clear feedback
  and reliable updates are part of that value. The previous list-only Home restriction no longer
  applies; newly shared fields and sharing outside rounds require an explicit contract decision.
- **Share a clear social truth.** Slumber Party v4 uses one party-level contract, not a sharing
  matrix: all current members see the active round's factual Wind Down and Phone Away records,
  revisioned statuses that expire, curated profile snapshots, and fixed cheers. A party is not a
  public social profile or a discovery surface. The canonical display name appears in Farm and in
  every party; the initial or migration selection is free, then only two successful changes are
  allowed in each rolling 14-day window. Its curated snapshot may contain only the selected
  Shepherd look, Ollie ornament, featured sheep definition, and pasture theme, using allowlisted
  catalogue identifiers and revisions. No full Farm, inventory, wool, exact schedules, private
  routine or reflection text, Family Controls token, app list, raw report, raw HealthKit sample,
  NFC, purpose, notification, or impact data enters the social contract. A member may backfill
  factual activity after joining an active round; the server treats it as idempotent self-report,
  not verification. One qualifying local activity may earn separately in each eligible party,
  up to the five-party cap. Opening the app, inviting, joining, cheering, or changing settings
  never creates rewards.

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
