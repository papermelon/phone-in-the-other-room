# ADR-0009: Lost Sheep Search, Wanted Posters, and Rarity

- Status: Accepted; Farm lifecycle and economy amended by ADR-0015
- Date: 2026-08-01
- Decider: Founder
- Related: ADR-0006, ADR-0007, `docs/PRODUCT_PRINCIPLES.md`

## Context

Counting Sheep now has a farm, a flock, and Ollie the border collie shepherd. The nightly
Wind Down should give Ollie a clear job: follow the trail of sheep that have wandered from the
pasture and bring them home. Anticipation, rarity, and visible search progress are intentional
habit-forming mechanics, not incidental decoration.

## Decision

The first three completed protected Wind Downs guarantee a sheep from the starter wanted-poster
board. After that, every completed Wind Down resolves exactly once into either a sheep encounter
or a trail-only result. Trail-only results increase distance, strengthen future odds, and advance
bad-luck protection. A configured threshold guarantees a future encounter after repeated
successful no-find nights.

Search strength combines core Wind Down evidence with optional positive-only bonuses. Core inputs
include quiet-window completion, schedule adherence, shielding evidence, placement confirmation,
and recent protected-night consistency. Optional HealthKit, Screen Time, and self-reported habit
signals may add bonuses or open habitat affinities. Missing permissions, missing data, poor sleep,
or skipped reflections never reduce the chance.

Sheep have four rarity levels: common, uncommon, rare, and legendary. Rarity affects encounter
weights, Ollie's Search treatment, art, story, wool yield, regrowth, and trade value. It never changes
essential access or creates a sleep score. Each owned sheep has a unique identity; repeated
catalogue archetypes receive stable local names.

Wanted posters appear in a finite, deterministic catalogue. The starter board is available from
the first run; later posters arrive through completion milestones, habitat access, and occasional
seeded arrivals. Posters do not expire in the first release. Exact encounter odds are hidden by
default and can be enabled in Settings; the default presentation uses qualitative trail strength and
habitat eligibility.

Ollie's Search presentation uses an adaptive native SwiftUI poster grid. Missing sheep use
silhouettes or obscured palettes, clue fragments, habitat, and rarity hints rather than revealing
the full-colour discovery asset. One missing definition can be tracked; after a successful
encounter roll its selection weight is tripled without changing the encounter probability.
Active Wind Down screens do not expose the board, and no poster-arrival notification pulls the
user back into the app at night.

Search outcomes are local, deterministic after resolution, persisted by run ID, and never rerolled
on relaunch. Trail distance is a story estimate based on quiet-window evidence and bonuses, not a
GPS or Health measurement.

## Consequences

- Completion becomes a meaningful morning homecoming rather than a generic reward receipt.
- No-find nights still create progress and reasons to continue.
- The first three nights teach the mechanic before probability and rarity are introduced.
- The collection and individually owned flock can grow without changing the Wind Down state
  machine. Ollie's Search remains a secondary Farm surface rather than a Home or Nights lead.
- The old mock Farm remains a gated compatibility surface; the production Farm is defined by
  ADR-0015, which supersedes ADR-0010's earlier presentation limits.

Legacy search and rarity fields remain backward-decodable. `SheepSearchState` is authoritative
for outcomes and deterministic search resolution; `FarmState` is authoritative for owned flock,
capacity, wool, purchases, and equipment. See ADR-0015.

## Out of scope

- Paid loot boxes or paid odds
- Sheep gameplay powers or advantages
- Sleep diagnosis, sleep-quality grading, or penalties for missing Health data
- Automatic or random ownership loss, and rerolling completed outcomes
