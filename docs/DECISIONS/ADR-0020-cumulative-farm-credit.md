# ADR-0020 — Cumulative Farm credit

Accepted by founder request, 5 September 2026. Local implementation; not distributed.

## Problem and decision

A five-hour Wind Down could produce zero search progress, while shorn sheep waited
for completed-night counters to advance. Farm now earns cumulative timer credit:
Wind Down searches cost 420 minutes; Phone Away searches cost 100 minutes. Early
endings retain all eligible credit. There is no minimum session duration, per-run
credit cap, or three-Wind-Down gate for the new Phone Away meter. Existing independent
first-three and bad-luck guarantees remain. No completion bonus is added in this slice.

Wind Down includes the overnight timer, bounded by the saved planned end and actual
terminal time. The scheduled linked Screen-Free Morning window is excluded because
that existing separate ledger already rewards it. Factual before-bed/morning records,
completion counters, Health observations and social wire metrics remain distinct.
Screen-Free Morning's existing eligible-elapsed policy is unchanged in this slice.

## Accounting and recovery

`FocusRun.farmCreditVersion` is 1 for new runs and 0 for legacy decoded runs. Active
legacy runs upgrade unless an old immutable Wind Down benefit was already resolved.
The latter retains its original reward contract. New runs bypass the old primary
hidden-search and Phone Away settlement engines; keepsake/actual completion history
continues independently in RewardEngine.

`CumulativeFarmCredit` lives inside `FarmState`, under the existing `ollie.farm.state`
key. One save includes consumed interval unions, immutable run receipts, meter
remainders, deterministic search outcomes, owned arrivals, and sheep regrowth. The
Search Journal is a replayable projection. A terminal snapshot including access
intervals is saved before cleanup. Replaying a run or overlapping another run cannot
credit a consumed span twice. No receipt IDs or consumed spans are pruned: unlike the
90-day detailed history, these minimal local accounting records last until local reset.
No new data is uploaded.

Every granted access interval is captured before clearing shields. Overlapping access
intervals are unioned and clipped before subtraction; fractional minutes carry forward.
The active access ledger retains all intervals, and archived run entries retain their
intervals through the existing bounded cross-run handoff history. If a legacy count
outlives its timestamps, that session gets no additional credit and says why; prior
credit is retained. This is timer accounting, not continuous enforcement attestation.

Wool regrowth stores remaining seconds on each sheep. Existing completed-night growth
is converted once without regression: common/uncommon/rare/legendary sheep need the
remaining equivalent of 2/3/4/5 seven-hour units. New session credit advances active
sheep, and any positive growth changes the shorn visual to regrowing. Shearing starts
that sheep's full regrowth duration. Phone Away also advances regrowth, second for second.

## Migration

Already completed legacy sessions and rewards are preserved, with their spans reserved.
The old banked Phone Away meter transfers once. Early-ended history is backfilled only
when it has an end timestamp, explicit non-practice provenance, and zero access uses.
Uncertain history is omitted; no fabricated verified minutes or goodwill currency is
created. Historical growth applies only after the sheep arrived and its last known
shearing; a missing shearing transaction prevents historical regrowth backfill. The
migration and its generated outcomes commit together and are idempotent.

## Shield and receipts

The shield says which mode is on, when selected-app limits end, and that five-minute
access leaves the timer running. Its primary button closes the shielded app. iOS 26.4+
has one explicit five-minute confirmation plus system Cancel; earlier OS versions use
the clearly labelled direct action. Website shields retain no access action. Actual
grants may be shorter near session end. All selected apps/categories unlock together;
this implementation does not promise attempted-app-only access or a two-minute option.

Farm receipts show credited minutes separately from elapsed/before-bed minutes, and
Farm/Ollie's Search show carried progress. Technical callback language is replaced by
plain tracking explanations. No full sheep is promised before a search resolves.

## Platform limits and verification

Apple invokes DeviceActivity start/end callbacks when the device is in use, so a missing
callback is not evidence of user misconduct. Automatic reblocking is OS scheduled and
requires physical-device overnight/termination QA. Simulator arithmetic and replay tests
do not establish real Family Controls enforcement. Absolute stored dates bound credit
across midnight and DST; manual clock manipulation is not an anti-cheat guarantee.

Sources:
- https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor/intervaldidend(for:)
- https://developer.apple.com/documentation/deviceactivity/deviceactivityschedule/nextinterval
- https://developer.apple.com/documentation/managedsettings/shieldactionresponse/close

Tests cover early endings, access overlap/clipping, cross-mode overlap, fractional carry,
multiple searches, legacy decode/backfill, uncertain history, repeated reload/projection,
retention beyond the old ID cap, partial wool growth, and morning exclusion.
