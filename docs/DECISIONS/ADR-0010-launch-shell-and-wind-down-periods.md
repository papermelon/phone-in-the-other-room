# ADR-0010: Launch Shell, Flock Arrival, and Multiple Wind Down Periods

- Status: Accepted
- Date: 2026-08-03
- Decider: Founder
- Related: ADR-0006, ADR-0007, ADR-0009

## Decision

The launch shell has three root destinations: Home, Nights, and Farm. More is a utility
sheet from the Home top bar and remains the finite place for plan configuration, connections,
privacy, feedback, and internal previews. Friends and Shop remain unavailable from release
navigation.

Farm is a rehabilitation of the existing farm presentation and assets. Release Farm reads only
the persisted sheep-search field book and presents an equal flock: one protected primary night
settles one sheep. Legacy coins, balances, capacity, rarity, missions, upgrades, and reward shelf
data remain decodable but are not read by release UI.

Nights leads with a finite seven-day record and links to a monthly calendar. A recorded day can
contain multiple separately inspectable Wind Down occurrences. Quiet minutes are the union of
credited intervals, and only the designated primary sleep-bookend occurrence contributes to
protected-night progression.

The saved schedule contains one migrated primary sleep-bookend routine and optional additional
bounded quiet routines. A one-time next-period override can adjust either kind without mutating
the usual routine. Historical records retain their plan snapshot. Overlapping recurring
occurrences are rejected before saving. Additional quiet periods contribute factual history but
make no sleep claim and never create a sheep-search attempt.

Completion shows a short factual receipt first. A user action reveals the individual sheep or
trail result, then the flock settlement. The release surface does not present “What the quiet
held,” claim that configured activities were completed, or show locked collection slots.

Active Wind Down is normally non-scrolling. A wall-clock journey scene places Ollie across a
small set of farm, prairie, mountain, moonlit, and sunrise segments. Journey progress is derived
from persisted plan dates, restores after relaunch, respects Reduce Motion, and never changes
progression or reward value.

## Compatibility

Existing `NightWatchPlan`, `NightWatchRecord`, progress, reward, and sheep-search JSON continues
to decode. New role fields default to the primary sleep-bookend role for legacy records. The old
MVP Farm/Friends/Shop screens and reward shelf remain available only to the explicit Debug
internal-preview launch path until a later compatibility cleanup.
