# Ollie fetch progression — first slice, 25 September 2026

The founder asked for skill-based ball flicking, large-text repairs, field-corner reach,
and ideas for progression and Shop additions. The interaction repairs are implemented
separately. The founder approved implementing the proposed progression on 25 September.
The first slice below is implemented in source; distribution and physical-device acceptance
are separate. The later Shop additions and milestone ideas remain deferred.

## Implemented first progression slice

Keep free fetch available. Offer an optional five-throw practice round: land the ball near
a patch of clover, with a smaller inner ring for a more accurate throw. Begin with broad,
nearby targets, then introduce farther targets and alternating corners. Give calm per-throw
feedback and a personal best at the end. Replay is a choice; there is no countdown or
requirement to play every day.

Skill comes from direction and flick strength. Avoid random wind or hidden accuracy boosts
in the first version so the player can learn a consistent motion. Keep free fetch's direction
menu. Practice needs an equally deliberate accessible aiming control (direction and strength)
before it can claim comparable scoring; preset destination throws must not award precision
scores automatically. Reduce Motion changes presentation, not the result.

## Shop additions, in order (later items remain proposals)

| Addition | What it adds | Prerequisite |
| --- | --- | --- |
| Ball designs: moss, sunset, stitched wool | Owned/equipped appearance during flight, pickup and return; identical physics | Ball renderer and backward-compatible equipment/inventory contract |
| Clover target mat | Places the practice targets into the Farm as a visible prop | A free basic practice mode; purchase changes appearance, not access to basic skill play |
| Toy basket | Displays owned balls and offers a natural place to change the equipped toy | Several worthwhile ball designs and a placement that leaves throwing space clear |
| Rope toy or flying disc | A genuinely different throw arc and Ollie retrieval animation | Validate the base flick feel first; author fitted carry art and teach the new behavior |

Use the existing wool balance and Shop ownership/equip patterns. Set prices against the
existing catalog once the first items and their art are scoped; no new currency is needed.
Preview the equipped item before purchase. Inventory and equipment must follow the verified
account Farm and private sync contract, including old-save defaults and unknown item IDs.

## Longer-term progression

Practice milestones could unlock target arrangements and keepsakes for the toy basket:
first accurate landing, reaching each corner, then a five-throw accuracy challenge. Keep
these as play accomplishments, distinct from night records, search credit and wool growth.
Fetch currently grants no rewards. Any persistent mastery ledger or reward conversion needs
an explicit product decision and migration/sync design before implementation.

The first slice includes target practice and two cosmetic balls. Observe whether people can intentionally
repeat a landing and understand why a throw went short or wide before adding obstacles,
new toy physics, more levels, or social scoring. Active-session pauses still apply.

## Implementation contract

- Five fixed clover targets progress from a broad nearby patch through alternating grass
  corners. Inner ring earns 3 points, outer ring 1, outside 0; maximum 15. The ring stays
  visible through pickup/return. Score each landing once, finish only after the fifth handoff.
- Free fetch retains destination presets. Practice rejects those presets and provides
  adjustable heading/strength with the same travel projection and landing guide as swiping.
  Both controls can reach every inner ring; Reduce Motion changes presentation only.
- Moss Ball costs 3 wool; Sunset Ball costs 4 wool, alongside existing entry-level cosmetics.
  Shop cards and previews use the same native ball rendering as every fetch phase. Purchase
  equips the ball; owned balls can be switched or put aside for the free original ball.
- `FarmState.fetchPracticeBest` is an optional 0–15 integer. Only completed rounds can raise
  it. No mastery ledger, wool, search credit, daily requirement, or social score is added.
  A completion callback is fenced to the Farm scope and lineage captured before practice.
- `FarmEquipment.fetchBallItemID` is optional. Missing or unknown IDs render the original
  ball; unknown IDs remain in the save. Both fields use existing account-scoped transaction
  storage and the private Farm payload. Nil fields remain omitted for old-payload compatibility.
- Scrolling between the field and its controls keeps play active; leaving the whole game,
  changing pasture, backgrounding or starting an active session cancels it.

Validation is recorded in [the implementation evidence](../../output/design/fetch-progression-20260925/README.md).
