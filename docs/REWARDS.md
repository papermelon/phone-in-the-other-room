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
    Search --> Arrival[Homecoming or clue and factual receipt]
    Arrival --> Nights[Cumulative flock in Nights]
    Nights --> Plan
```

Completion creates one search outcome. The factual receipt keeps wind-down and morning-quiet
minutes separate. Core ritual evidence affects trail strength; optional HealthKit, Screen Time,
and self-reported habits provide positive-only bonuses. Rarity affects cosmetic/story identity,
never power or essential access.

## Canonical presentation

The completion card says that Ollie found a sheep or advanced the trail, shows the relevant
poster/field clue, and includes the factual quiet-time receipt. Nights shows found identities,
active wanted posters, habitats, trail distance, and rarity labels. Exact odds are optional.

An early-ended Night Watch adds no sheep. It still receives warm copy and the factual receipt;
no sheep or previously completed night is lost.

## Persisted compatibility

`RewardItem`, `RewardContext`, rarity, coin and sheep balances, total earned fields, and
Ollie level remain encoded and decoded so existing users lose no data. The release UI does
not read those legacy economy values. The old keepsake shelf is available only through the
explicit Debug internal-preview flag until a later compatibility cleanup.

## Evidence boundary

Counting Sheep is **CBT-I-informed, not CBT-I treatment**. The 2021 American Academy of
Sleep Medicine guideline recommends clinician-delivered, multi-component CBT-I for chronic
insomnia and explicitly cautions that sleep hygiene alone is not an adequate treatment.
Stimulus control—one component—works to strengthen the bed as a cue for sleep and establish
a consistent wake time. The 2025 VA/DoD guidance likewise describes CBT-I as a structured,
multi-component intervention with clinical considerations.

The app stays on the non-clinical side of that boundary:

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
- **Purposeful accumulation:** protected nights advance a search, wanted posters create
  anticipation, and rare sheep remain cosmetic/story rewards. No paid odds or sheep power.
- **Mindful screen-time management:** the rewarded behavior is physical separation during
  the selected bookends. Optional Screen Time reports can supply context elsewhere but
  never determine the sheep.
- **Kindness:** the flock cannot shrink; shorter attempts receive warmth rather than punishment.
- **Finite attention:** one arrival appears at completion and Nights remains a finite record.

## Evaluation

Judge this loop by protected behavior, not collection engagement:

- completed Night Watches in a tester's first 14 nights;
- credited wind-down and morning-quiet minutes, kept separate;
- whether users understand that the first three searches guarantee homecomings and later
  searches can produce clues, odds, or rarer sheep;
- selected-app use around sleep when the person explicitly enables Screen Time reports; and
- qualitative reports that rewards feel calm, meaningful, and non-compulsive.

Do not optimize completion-screen opens, flock-page dwell time, notification taps, rarity
demand, or currency accumulation.
