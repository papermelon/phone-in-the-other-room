# ADR-0010: Launch Shell, Flock Arrival, and Multiple Wind Down Periods

- Status: Accepted; Farm and result presentation superseded by ADR-0015
- Date: 2026-08-03
- Decider: Founder
- Related: ADR-0006, ADR-0007, ADR-0009

## Decision

The launch shell has four root destinations: Home, Nights, Farm, and Settings. Settings is a
finite root screen for plan configuration, connections, privacy, feedback, and internal previews.
Friends remains unavailable from release navigation. Farm Shop is nested under Farm and does not
create a fifth root destination.

ADR-0015 supersedes the former static Farm presentation. Release Farm uses `FarmState` and
`SheepSearchState` for a paged living pasture, finite-capacity Barn, Trail Board, Trail Notes,
local Farm Shop, and customization. Legacy mock economies remain compatibility-only and are not
reused. The production wool economy is earned through sheep decisions, not elapsed minutes.
Farm destinations are not shown in Home or Nights.

Nights leads with a finite seven-day record and links to a monthly calendar. A recorded day can
contain multiple separately inspectable Wind Down occurrences. Quiet minutes are the union of
credited intervals, and only the designated primary sleep-bookend occurrence contributes to
protected-night progression.

The saved schedule contains one migrated primary sleep-bookend routine and optional **Phone Break**
routines. Home exposes a compact one-time Phone Break editor; recurring Phone Break routines remain
decodable and can be scheduled through the finite editor.
A one-time next-period override can adjust either kind without mutating the usual routine.
Historical records retain their plan snapshot. Overlapping recurring occurrences are rejected
before saving. Phone Break periods contribute factual history, make no sleep claim, and never create
a protected-night search attempt. Eligible completed Phone Breaks instead credit a separate
75-minute meter and can resolve one bonus search after three protected Wind Downs.

Current setup offers only App Shielding or NFC + App Shielding. Legacy timer, Watch, and QR
guard kinds remain for backwards decoding and old active runs, but are not presented as choices.

### Schedule amendment — 2026-08-08

The saved schedule is now a versioned `WindDownScheduleState`. It migrates the prior plural
routine array and singular next-period override into multiple dated one-time periods plus
recurring routines. The finite Upcoming quiet times editor supports once, daily, weekdays,
and custom weekday periods, with edit, enable/disable, cancellation, passed-period pruning,
and overlap identification. The scheduler resolves the earliest future or currently eligible
occurrence across both sources; a future additional period cannot replace a normal Wind Down
started now. Phone Break never creates protected-night progress. Its elapsed time remains factual
history, while its separate meter and bonus-search rules settle only on eligible completions.

Settings includes a non-destructive Review Wind Down setup action and a separate destructive
"Erase local data and start over" action. The latter clears the saved plan, NFC pairing,
onboarding marker, local history, selections, and runtime state, then opens fresh Welcome
onboarding in the same process. It does not revoke iOS permissions or delete remotely uploaded
impact records.

Completion shows a short factual receipt first. One explicit “Open Ollie's Trail Notes” action
reveals the already persisted outcome matched to that run ID. The top-aligned, finite Trail Note
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
internal-preview launch path. They are distinct from the production Farm and nested Farm Shop.
