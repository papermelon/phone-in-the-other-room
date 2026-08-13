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
`SheepSearchState` for a paged living pasture, finite-capacity Barn, Ollie's Search, Search Journal,
local Farm Shop, and customization. Legacy mock economies remain compatibility-only and are not
reused. The production wool economy is earned through sheep decisions, not elapsed minutes.
Farm destinations are not shown in Home or Nights.

Nights leads with a finite seven-day record and links to a monthly calendar. A recorded day can
contain multiple separately inspectable Wind Down occurrences. Quiet minutes are the union of
credited intervals, and only the designated primary sleep-bookend occurrence contributes to
protected-night progression.

The saved schedule contains one migrated primary sleep-bookend routine and optional **Phone Away**
routines. Home exposes a compact one-time Phone Away editor; recurring Phone Away routines remain
decodable and can be scheduled through the finite editor.
A one-time next-period override can adjust either kind without mutating the usual routine.
Historical records retain their plan snapshot. Overlapping recurring occurrences are rejected
before saving. Phone Away periods contribute factual history, make no sleep claim, and never create
a protected-night search attempt. Eligible completed Phone Away periods instead credit a separate,
centrally configured 100-minute meter and can resolve one bonus search after three protected Wind Downs.

Current setup offers only App Shielding or NFC + App Shielding. Legacy timer, Watch, and QR
guard kinds remain for backwards decoding and old active runs, but are not presented as choices.

### Schedule amendment — 2026-08-08

The saved schedule is now a versioned `WindDownScheduleState`. It migrates the prior plural
routine array and singular next-period override into multiple dated one-time periods plus
recurring routines. The finite Upcoming quiet times editor supports once, daily, weekdays,
and custom weekday periods, with edit, enable/disable, cancellation, passed-period pruning,
and overlap identification. The scheduler resolves the earliest future or currently eligible
occurrence across both sources; a future additional period cannot replace a normal Wind Down
started now. Phone Away never creates protected-night progress. Its elapsed time remains factual
history, while its separate meter and bonus-search rules settle only on eligible completions.

Settings is organized into Your Wind Down, Connections, and Help & app guide. Your Wind Down is
the single configuration route; there is no duplicate Review Wind Down setup action. A separate destructive
"Erase local data and start over" action. The latter clears the saved plan, NFC pairing,
onboarding marker, local history, selections, and runtime state, then opens fresh Welcome
onboarding in the same process. It does not revoke iOS permissions or delete remotely uploaded
impact records.

Completion shows a short factual receipt first. One explicit “Open Search Journal” action
reveals the already persisted outcome matched to that run ID. The top-aligned Search Journal entry
shows a persisted sheep asset, name, habitat, story, and trail evidence when a sheep is home; a
trail-only result shows only honest clue evidence. A clear “Back to the Farm” action returns to
the shipping Farm. The release surface does not present “What the quiet held,” claim that
configured activities were completed, or show locked collection slots.

Wind Down setup supports an ordered private sequence of up to three evening suggestions and two
morning suggestions, with putting the phone away fixed first. Suggestions have no checkmarks,
verification, reward, score, streak, or completion claim. Guidance appears beside routine choices,
on Home, and in phase-appropriate moments. The full locally bundled source library is reached
through the secondary “About these ideas and sources” link.

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
