# ADR-0010: Launch Shell, Flock Arrival, and Multiple Wind Down Periods

- Status: Accepted
- Date: 2026-08-03
- Decider: Founder
- Related: ADR-0006, ADR-0007, ADR-0009

## Decision

The launch shell has four root destinations: Home, Nights, Farm, and Settings. Settings is a
finite root screen for plan configuration, connections, privacy, feedback, and internal previews.
Friends and Shop remain unavailable from release navigation.

Farm is a rehabilitation of the existing farm presentation and assets. Release Farm reads only
the persisted sheep-search field book and presents an equal flock: one protected primary night
settles one sheep. Legacy coins, balances, capacity, rarity, missions, upgrades, and reward shelf
data remain decodable but are not read by release UI. Beneath the flock, Farm includes the
existing finite, horizontally snapping Missing Posters carousel. Posters use sheep-search
identity, clue, and found status for cosmetic/story context only; they do not add currency,
capacity, performance ranking, or a second progression system. The poster board is not shown in
Home or Nights.

Nights leads with a finite seven-day record and links to a monthly calendar. A recorded day can
contain multiple separately inspectable Wind Down occurrences. Quiet minutes are the union of
credited intervals, and only the designated primary sleep-bookend occurrence contributes to
protected-night progression.

The saved schedule contains one migrated primary sleep-bookend routine and optional additional
bounded quiet routines. Home exposes a compact one-time additional-quiet editor; recurring
additional routines remain decodable but are not automatically scheduled by the current UI.
A one-time next-period override can adjust either kind without mutating the usual routine.
Historical records retain their plan snapshot. Overlapping recurring occurrences are rejected
before saving. Additional quiet periods contribute factual history but make no sleep claim and
never create a sheep-search attempt.

Current setup offers only App Shielding or NFC + App Shielding. Legacy timer, Watch, and QR
guard kinds remain for backwards decoding and old active runs, but are not presented as choices.

Settings includes a non-destructive Review Wind Down setup action. Reset local progress intentionally keeps
the saved plan, NFC pairing, and onboarding completion marker; it clears progress only and does
not reopen onboarding.

Completion shows a short factual receipt first. A user action reveals the individual sheep or
trail result, then the flock settlement. The release surface does not present “What the quiet
held,” claim that configured activities were completed, or show locked collection slots.

Active Wind Down presents a compact, scroll-safe wall-clock journey scene with Ollie visible from
the first moment across farm, prairie, mountain, moonlit, and sunrise segments. Its illustrated
trail-mile cue is derived from persisted plan dates, restores after relaunch, respects Reduce
Motion, and never changes progression or reward value. NFC confirmation is a tuck-in action;
ending early stays an explicit secondary emergency action.

## Compatibility

Existing `NightWatchPlan`, `NightWatchRecord`, progress, reward, and sheep-search JSON continues
to decode. New role fields default to the primary sleep-bookend role for legacy records. The old
MVP Farm/Friends/Shop screens and reward shelf remain available only to the explicit Debug
internal-preview launch path until a later compatibility cleanup.
