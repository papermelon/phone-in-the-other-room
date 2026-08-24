# Ollie's Search and Sheep Homecomings

Counting Sheep marks the phone-away ritual, not time asleep and not time spent in the app.
Ollie guards and guides. A new Farm starts with one sheep. The first three qualifying
protected nights bring another sheep home; later protected nights advance a probabilistic
search with visible trail progress and bad-luck protection. A qualifying Wind Down search
needs a primary Wind Down whose eligible phone-away span reaches 420 minutes. That span is a Farm progression rule,
not a description of hours asleep, and overnight time still never becomes credited quiet
minutes.

## The loop

```mermaid
flowchart LR
    Plan[Choose the two quiet bookends] --> Away[Put the phone in its other-room bed]
    Away --> Evening[Phone-free wind-down]
    Evening --> Night[Ollie keeps Night Watch]
    Night --> Morning[Phone-free morning]
    Morning --> Search[Sheep found or trail advanced]
    Search --> Note[Search Journal]
    Note --> Arrival[Active flock or pending gate]
    Arrival --> Choice[Keep, shear, trade, or customize]
    Choice --> Plan
```

Reaching the boundary resolves one private persisted Wind Down outcome; an authorized terminal
action delivers it and its receipt reveals it. The factual receipt keeps wind-down and
Screen-Free Morning minutes separate. Morning minutes do not affect new Wind Down odds. Optional HealthKit,
Screen Time, and self-reported habits can add search evidence. Rarity affects encounter weighting,
wool yield, regrowth, trade value, art, and story.

## Three independent Farm paths

- **Wind Down:** reaching 420 eligible phone-away minutes creates one private result. Screen-Free
  Morning never changes its result, odds, or drought state.
- **Sunrise Trail:** at least 15 actual Screen-Free Morning minutes bank actual time capped by the
  configured window. Each 100-minute fill grants 1 wool and one separate look. Its first three
  looks guarantee a homecoming; later looks use its own 20/30/40/50 ladder, with the next look
  guaranteed after four clues.
- **Phone Away:** completed Phone Away minutes use a separate 100-minute meter and its own
  first-three/ladder/bad-luck state. Brief Access does not subtract Sunrise elapsed minutes.

Every fill and arrival is idempotent. Farm capacity still applies: a found sheep is recorded in
Search Journal and waits at The Barn gate when the active flock is full.

## Canonical presentation

The completion receipt offers one explicit “Open Search Journal” action. A found note names
the sheep and whether it entered the active flock or is waiting at The Barn gate. After Wind
Down or Phone Away, the note says Ollie found a missing sheep or kept a clue—not that a search
is still happening. Welcome-gift notes use that name. Farm owns the living flock, lifecycle,
economy, and customization presentation. Exact chance figures remain optional.

An ending before 420 minutes adds no Wind Down search outcome. An ending after a previously
entitled boundary retains the already resolved outcome. It still receives the factual receipt. Sheep
lifecycle changes occur through explicit Farm actions, not through the early-end settlement path.

The first successful five-minute onboarding practice grants exactly one additional Farm sheep
as a welcome gift on a new Farm. Existing farms do not receive that gift from a leftover
completed-practice `lastRun`. That sheep is a real catalogue discovery, occupies Barn
capacity, and can later be sheared or traded. It does not consume a protected-night
guarantee, a Phone Away guarantee, or the 100-minute Phone Away meter. Incomplete or
early-ended practice grants nothing. Settlement is idempotent by practice run identity, and
only the first successful practice on a new Farm grants a sheep.

Completing the local Wind Down starting-point questionnaire creates a pending one-time shepherd
wearable from the production Farm Shop catalogue. The gift is owned, not silently equipped.

## Slumber Party gifts

Shared nights can grant modest Farm rewards, separate from Wind Down searches, Phone Away
searches, and welcome gifts. Constants live in `NightFlockRewardRules`:

- 1 wool for a qualifying shared night, once per member per challenge day;
- an unowned cheap Farm item, or 3 wool, after three qualifying nights;
- one guaranteed Slumber Party sheep search after the party completes with at least four
  qualifying nights;
- 2 wool as a group completion bonus when at least two members meet that four-night threshold.

Opening the app, inviting, joining, sending reactions, or changing settings never creates a
grant. The authenticated backend computes each grant once. The iPhone applies the backend grant
ID once through `ollie.nightFlock.rewards`.

## Farm lifecycle and economy

Every found outcome creates an individual `FlockSheep`. Catalogue discovery and Search Journal stay
recorded after an owned sheep is traded. The active flock begins at 12 spaces and can expand to 60;
overflow waits at the arrival gate.

Shearing keeps the sheep and yields 1/2/4/7 wool for common/uncommon/rare/legendary sheep. Wool
regrows after 2/3/4/5 subsequently completed protected nights. Trading a sheep to another farm
returns 3/6/13/30 wool; a sheep traded while regrowing returns 75% of its base value. The local
Farm Shop spends wool on Barn capacity, Ollie and shepherd wearables, Farm decoration, and collectibles.
See ADR-0015 for the full rules.

## Persisted compatibility

`RewardItem`, `RewardContext`, legacy coin and sheep balances, total earned fields, and Ollie
level remain encoded and decoded so existing users lose no data. They are not mapped into the
new `FarmState.woolBalance`. Version-one `FarmState.cashBalance` is different: schema v2 converts
that retired Farm currency to wool at five cash per wool, rounding any remainder up once. The old keepsake shelf remains an explicit Debug
internal preview until a later compatibility cleanup.

## Evidence boundary

Counting Sheep offers general sleep-health education; it is **not insomnia treatment**. The 2021 American Academy of
Sleep Medicine guideline recommends clinician-delivered, multi-component CBT-I for chronic
insomnia and explicitly cautions that sleep hygiene alone is not an adequate treatment.
Stimulus control—one component—works to strengthen the bed as a cue for sleep and establish
a consistent wake time. The 2025 VA/DoD guidance likewise describes CBT-I as a structured,
multi-component intervention with clinical considerations.

The app stays on the non-clinical side of that boundary. The sources are reference material; this
document does not claim that qualified clinical review of Counting Sheep's guidance has occurred:

- the phone has a consistent resting place outside the bedroom;
- a saved wind-down and wake boundary make the ritual easier to repeat;
- offline cues suggest calmer alternatives without proof or checklists;
- the completion copy notices behavior and purpose, never sleep quality; and
- there is no sleep restriction prescription, sleep-efficiency score, diagnosis, or claim
  to treat insomnia.

Sources:

- [AASM behavioral and psychological treatments guideline (2021)](https://pmc.ncbi.nlm.nih.gov/articles/PMC7853203/)
- [VA/DoD chronic insomnia and OSA guideline pocket card (2025)](https://healthquality.va.gov/HEALTHQUALITY/guidelines/CD/insomnia/I-OSA-2025-Pocket-Card_final_20250205.pdf)

## Product-principle checks

- **Slow living:** the reveal repeats what the quiet made room for and the two offline cues;
  it adds no routine checklist.
- **Purposeful accumulation:** protected nights advance search and wool regrowth; wanted trails,
  finite capacity, shearing, trading, expansion, and customization give arrivals meaning.
- **Mindful screen-time management:** the rewarded behavior is physical separation during
  the selected bookends. Optional Screen Time reports can supply context elsewhere but
  never determine the sheep.
- **Player agency:** collectors, wool producers, traders, catalogue completers, and decorators
  can value the same sheep differently.
- **Finite attention:** one outcome appears at completion; Farm destinations remain finite and
  the active flock has a 60-sheep ceiling.

## Evaluation

Judge this loop by protected behavior, not collection engagement:

- completed Night Watches in a tester's first 14 nights;
- factual wind-down and Screen-Free Morning minutes, kept separate; only the former feeds
  Wind Down reward/progress, while the latter settles through Sunrise Trail;
- whether users understand that the first three qualifying protected-night searches and the
  first three Phone Away meter searches guarantee homecomings, that a 420-minute protected
  span is required for a Wind Down search, and that later searches can produce clues, odds,
  or rarer sheep;
- selected-app use around sleep when the person explicitly enables Screen Time reports; and
- whether users understand shearing, trading, pending arrivals, and Shop prices;
- which play styles emerge and whether one balance path dominates; and
- qualitative reports that the Farm gives Wind Down a meaningful narrative payoff.

Evaluate the Farm against protected-night return behavior, comprehension, strategy diversity,
and qualitative attachment. Page dwell time and currency totals are diagnostic context rather
than standalone success criteria.
