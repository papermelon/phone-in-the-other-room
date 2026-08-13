# Ollie's Search and Sheep Homecomings

Counting Sheep marks the phone-away ritual, not time asleep and not time spent in the app.
Ollie guards and guides. The first three completed protected nights bring a sheep home; later
protected nights advance a probabilistic search with visible trail progress and bad-luck
protection.

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

Completion creates one persisted search outcome. The factual receipt keeps wind-down and
morning-quiet minutes separate. Core ritual evidence affects trail strength; optional HealthKit,
Screen Time, and self-reported habits can add search evidence. Rarity affects encounter weighting,
wool yield, regrowth, trade value, art, and story.

## Canonical presentation

The completion receipt offers one explicit “Open Search Journal” action. A found entry names
the sheep and whether it entered the active flock or is waiting at The Barn gate. A clue note
records honest search evidence and links to Ollie's Search. Farm owns the living flock,
lifecycle, economy, and customization presentation. Exact search odds remain optional.

An early-ended Night Watch adds no search outcome. It still receives the factual receipt. Sheep
lifecycle changes occur through explicit Farm actions, not through the early-end settlement path.

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
- credited wind-down and morning-quiet minutes, kept separate;
- whether users understand that the first three searches guarantee homecomings and later
  searches can produce clues, odds, or rarer sheep;
- selected-app use around sleep when the person explicitly enables Screen Time reports; and
- whether users understand shearing, trading, pending arrivals, and Shop prices;
- which play styles emerge and whether one balance path dominates; and
- qualitative reports that the Farm gives Wind Down a meaningful narrative payoff.

Evaluate the Farm against protected-night return behavior, comprehension, strategy diversity,
and qualitative attachment. Page dwell time and currency totals are diagnostic context rather
than standalone success criteria.
