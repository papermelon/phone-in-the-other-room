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
settles one sheep. Its hierarchy is pasture and flock overview, the latest arrival (or a quiet
pasture state), a compact trail-map status, and a finite field board. The board uses kind
"Still searching" / "Home" language rather than missing/found posters. Legacy coins, balances,
capacity, rarity, missions, upgrades, and reward shelf data remain decodable but are not read by
release UI. Field notes use sheep-search identity, clue, and home status for cosmetic/story
context only; they do not add currency, capacity, performance ranking, or a second progression
system. The field board is not shown in Home or Nights.

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

### Schedule amendment — 2026-08-08

The saved schedule is now a versioned `WindDownScheduleState`. It migrates the prior plural
routine array and singular next-period override into multiple dated one-time periods plus
recurring routines. The finite Upcoming quiet times editor supports once, daily, weekdays,
and custom weekday periods, with edit, enable/disable, cancellation, passed-period pruning,
and overlap identification. The scheduler resolves the earliest future or currently eligible
occurrence across both sources; a future additional period cannot replace a normal Wind Down
started now. Additional quiet remains factual history only and never creates protected-night or
sheep progress.

Settings includes a non-destructive Review Wind Down setup action. Reset local progress intentionally keeps
the saved plan, NFC pairing, and onboarding completion marker; it clears progress only and does
not reopen onboarding.

Completion shows a short factual receipt first. One explicit “Open Ollie's field note” action
reveals the already persisted outcome matched to that run ID. The top-aligned, finite field note
shows a persisted sheep asset, name, habitat, story, and trail evidence when a sheep is home; a
trail-only result shows only honest clue evidence. A clear “Back to the Farm” action returns to
the shipping Farm. The release surface does not present “What the quiet held,” claim that
configured activities were completed, or show locked collection slots.

Active Wind Down presents a compact, scroll-safe wall-clock journey scene with Ollie visible from
the first moment across farm, prairie, mountain, moonlit, and sunrise segments. Its illustrated
trail-mile cue is derived from persisted plan dates, restores after relaunch, respects Reduce
Motion, and never changes progression or reward value. NFC confirmation is the app-access barrier action;
ending early stays an explicit secondary emergency action. When app shielding is enabled, the
selected-app barrier begins with the eligible start (after the registered NFC tag for NFC mode)
and remains through overnight until the scheduled morning-quiet finish.

## Compatibility

Existing `NightWatchPlan`, `NightWatchRecord`, progress, reward, and sheep-search JSON continues
to decode. New role fields default to the primary sleep-bookend role for legacy records. The old
MVP Farm/Friends/Shop screens and reward shelf remain available only to the explicit Debug
internal-preview launch path until a later compatibility cleanup.
