# ADR-0014 — Progress-Aware Search Journey and Active Navigation

## Status

Accepted, 2026-08-07.

## Context

The original active illustration repeated one background beneath a time-driven run cycle.
It cut visibly at the image boundary, did not align Ollie to the ground, and used fictional
mileage that did not help a tired person understand how much of the current phase remained.
The full-screen run route also prevented access to notification and plan preferences.

Additional quiet periods need a warm connection to the lost-sheep story without becoming a
second sheep-search loophole or implying that any environmental clue guarantees a reward.
The app shield also needs a companion visual that feels native to the active journey without
being mistaken for progression.

## Decision

The active scene is a finite, wall-clock journey through prairie, mountain, moonlit, and
sunrise backdrops. Images use bounded crop motion rather than repetition. A periodic SwiftUI
Canvas terrain supplies both the visible path and Ollie's foot height and slope; gait advances
from foreground distance. Deterministic, non-interactive environmental clues appear at stable
progress thresholds and do not participate in reward resolution. Reduce Motion displays a
static aligned scene with reached evidence. The scene reports real time to the next phase.

Completed Phone Break runs credit their actual quiet minutes to a versioned trail map in
`SheepSearchState`, with a 75-minute search cost and up to one carried remainder. Credit starts
at 15 minutes, caps at 75 minutes per run, and never comes from practice or early endings.
After three protected Wind Downs, the next eligible completed Phone Break resolves one separate
bonus search on a deterministic 20/30/40/50/100 ladder. Its clue counter and outcomes are
isolated from Wind Down odds and bad-luck protection. Legacy map-bonus fields remain decodable.

As explicit product direction, a non-collectible companion sheep may appear beside Ollie on
the app shield. It is decorative only: it does not represent a resolved search, a promised
reward, or an owned sheep in the flock.

During an active Night Watch, the four release tabs remain available. Home is the default live
journey; other roots show a persistent timed return control that clears nested navigation.
Starting/restoring a run, foreground activation, and active-run notification routing return to
Home. Completion and early-end receipts temporarily replace the shell. Timing, protection, and
shield-selection edits affect the next run, while appearance and notification preferences may
update immediately; notification changes rebuild only still-future alerts for the unchanged run.

## Consequences

- The active journey remains honest and non-interactive: no collectible, found, or owned sheep
  appears before the persisted protected-night Trail Note is opened.
- Phone Break has positive, capped narrative value without becoming an alternate protected-night
  progression system; a found sheep still uses the ordinary Farm arrival flow.
- Tab access is a deliberate exception to the normal “status, not destination” principle and
  may not be expanded into engagement feeds or nighttime reveal hooks.
- Generated scenery and clue bitmaps are local catalog assets; no dependency, entitlement,
  target, network API, or notification category is added.
