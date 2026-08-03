# ADR-0009: Lost Sheep Search, Wanted Posters, and Rarity

- Status: Accepted
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
weights, poster treatment, art, and story only. Sheep never grant power, currency, essential
access, or a sleep score. Each sheep has a unique identity, while designs may share a base body
and differ through markings and accessories.

Wanted posters appear in a finite, deterministic catalogue. The starter board is available from
the first run; later posters arrive through completion milestones, habitat access, and occasional
seeded arrivals. Posters do not expire in the first release. Exact encounter odds are hidden by
default and can be enabled in More; the default presentation uses qualitative trail strength and
habitat eligibility.

Poster presentation uses a native SwiftUI, bounty-poster-inspired composition rather than a
bitmap feed: a finite snapping carousel of missing posters appears on Home, Nights provides a
Missing/Home/All poster board, and completion can stamp the resolved poster FOUND — HOME. The
composition uses muted parchment, ink, portrait framing, trail clues, breed and rarity seals, and
Ollie's return-home language while retaining Counting Sheep's own sheep art and pixel/paper
palette. Active Wind Down screens do not expose the carousel, and no poster-arrival notification
pulls the user back into the app at night.

Search outcomes are local, deterministic after resolution, persisted by run ID, and never rerolled
on relaunch. Trail distance is a story estimate based on quiet-window evidence and bonuses, not a
GPS or Health measurement.

## Consequences

- Completion becomes a meaningful morning homecoming rather than a generic reward receipt.
- No-find nights still create progress and reasons to continue.
- The first three nights teach the mechanic before probability and rarity are introduced.
- The collection can grow through generated and curated art without changing the Wind Down state
  machine.
- Farm remains a gated navigation decision; Nights can host the first field-book and poster board.

## Out of scope

- Paid loot boxes or paid odds
- Sheep gameplay powers or advantages
- Sleep diagnosis, sleep-quality grading, or penalties for missing Health data
- Poster expiration, destructive collection loss, or rerolling completed outcomes
