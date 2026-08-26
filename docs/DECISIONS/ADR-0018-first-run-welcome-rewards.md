# ADR-0018: First-Run Wind Down Starting Point and Welcome Rewards

- Status: Accepted
- Date: 2026-08-16
- Decider: Founder
- Related: ADR-0015, `docs/REWARDS.md`, `docs/PRODUCT_PRINCIPLES.md`

ADR-0019 keeps welcome gifts separate from the new Sunrise Trail. Screen-Free Morning settlement
never consumes a welcome, Wind Down, or Phone Away guarantee.

## Context

The shipping Farm currently begins empty. Search guarantees are tied to completed protected
nights and a separate Phone Away meter, and the five-minute onboarding practice is a real
recorded run that awards no sheep. Workshop and first-run copy therefore had no honest early
Farm payoff without consuming a protected-night guarantee.

The founder directed a universal first-run journey: every new Farm starts with one sheep, an
optional local questionnaire produces a non-clinical Wind Down starting point, every person can
independently choose and immediately claim one finished Shepherd welcome wearable, and the first successful practice grants a
second sheep. Search guarantees stay independent of that practice gift. A qualifying
protected-night search also requires a 420-minute protected span.

## Decision

- A fresh Farm receives exactly one starter sheep (`mabel`). Replay is idempotent. Existing
  farms with search history, discoveries, or owned sheep do not receive a retroactive starter.
- Questionnaire answers stay on-device under `ollie.windDown.profile`. User-facing language
  is “Wind Down starting point.” The app does not diagnose a sleep condition or assign a
  medical sleep type. Answers do not include diagnosis, medication history, insomnia scores,
  or sensitive free text.
- The optional questionnaire contains six categorical questions: bedtime delay, automatic
  reaching, first morning phone check, overnight phone location, main friction, and desired
  change. Each answer remains optional in persisted data; legacy defaults and missing values
  never become behavioral evidence. Small deterministic rules derive one primary starting
  pattern, and only independently supported evidence can produce a secondary pattern. The main
  friction may resolve ties; a desired change may favor an already supported pattern but cannot
  invent one. No score, diagnosis, medication history, or clinical claim is shown.
- Timing, quiet duration, app selection, and ordered routine ideas belong to their explicit
  setup stages. A recommendation may explain or prioritize useful local source-linked ideas but
  must not silently change the person's selected schedule or routine.
- Custom routine wording stays distinct from the person's broader offline purpose. Editing an
  evening idea must not rewrite that purpose or turn the routine into notification/Lock Screen
  copy; future curated-anchor projection belongs to the separate Phase-2 work.
- The welcome wearable is a genuine gift, independent of the questionnaire and its result.
  Every first-run person, including someone who skips the questions, may choose exactly one of
  `shepherd_wool_hat`, `shepherd_moss_coat`, or `shepherd_moon_coat`. Both **Wear now** and
  **Keep for later** immediately own and claim that chosen item through the existing idempotent
  welcome ledger. Wearing uses the effect-aware Farm equipment path; keeping preserves the
  existing outfit, accessory, hair, and skin tone. An older pending grant is claimed in place,
  and existing claimed ownership never issues a second item.
- Reminder setup is explained and optional. The final plan states both the person's reminder
  choice and actual system authorization. Automatic Wind Down starts off: a schedule describes
  the planned time, a reminder may prompt, and the person opens the app to begin.
- The first successful five-minute onboarding practice grants `pippin` as a real Farm sheep
  and catalogue discovery, but only on a first-run Farm. Existing farms with search history,
  discoveries, or owned sheep do not receive a leftover-`lastRun` practice gift on upgrade.
  Replay of an already persisted practice outcome remains idempotent. The sheep occupies Barn
  capacity and can later be sheared or traded. It consumes neither protected-night nor Phone
  Away guarantee counters, and it neither credits nor spends the 100-minute Phone Away meter.
  Incomplete or early-ended practice grants nothing. Settlement is idempotent by practice run
  identity, and only the first successful practice on a new Farm grants a sheep.
- The first three qualifying protected Wind Down searches guarantee a sheep. Independently,
  the first three completed 100-minute Phone Away meter searches also guarantee a sheep.
  After each track’s first three searches, that track uses its normal chance ladder and
  bad-luck protection.
- A qualifying protected-night search requires a successfully completed primary Wind Down
  whose protected span from eligible Wind Down start through morning-quiet completion is at
  least 420 minutes. This is a product progression rule. Copy must not call it seven hours
  asleep. The former two-bookend credit clause is superseded by ADR-0019: Wind Down reward,
  progress, and shared Wind Down metrics use its factual wind-down bookend; Screen-Free
  Morning minutes settle independently through Sunrise Trail.
- New `SheepSearchOrigin` values `.starter` and `.onboardingPractice`, new Farm transaction
  kinds, and the welcome ledger decode safely beside existing persisted data. Unknown future
  origins decode as `.unspecified` and do not consume guarantee counters. Settled historical
  outcomes are not rewritten.
- User-facing copy does not say “Wind Down search” or “protected night.” First-run sheep and
  the independently chosen Shepherd wearable are **welcome gifts**. After a completed Wind Down or Phone Away,
  a found sheep is “Ollie found a missing sheep.” Clues stay clues. Search Journal remains the
  Farm history place; Ollie’s Search remains the missing-sheep board.

## Consequences

- New players see a living Farm before their first completed Wind Down.
- Practice is a truthful welcome gift without inflating Wind Down progress. Existing farms do
  not receive that gift from a leftover completed-practice `lastRun`.
- Short completed nights can still retain their factual Wind Down bookend without opening a
  Wind Down find; Screen-Free Morning remains an independent Sunrise Trail occurrence under
  ADR-0019.
- The optional questionnaire/result and independent explicit wear-or-keep gift stage ship in
  first-run onboarding. Phase-2 notification/Live-Activity routine projection and remote privacy
  cleanup are not completed by this decision.
  This ADR does not change `project.yml`, entitlements, tabs, or hosted backends.
