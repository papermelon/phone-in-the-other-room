# Campfire implementation — 13 September 2026

The founder authorized campfire implementation after the Shop/Ollie pass. This implements the
free gathering-place direction from the [collection/flow review](shop-ollie-and-campfire-2026-09-13.md).
Local production source is implemented. Hosted rollout and physical two-device acceptance are
separate, outstanding gates. No deployment, archive, upload, commit or push was performed.

## Product behavior

- Campfire is free on day one within each existing Slumber Party meadow. It does not add a tab.
  People use their customized Shepherds. Ollie and purchased Ollie clothing stay on personal
  surfaces; purchased personal décor and keepsakes do not transfer into shared ownership.
- Default Wind Down presence lasts from admitted start to the anchored planned wake time,
  excluding Screen-Free Morning. Phone Away lasts to its saved planned end. Both are bounded
  to 24 hours. These are app-reported sessions, never proof of sleep or actual offline activity.
- Phone Away offers an optional per-start bounded intention: Phone Away, Reading, Studying,
  Making something, Chores, Resting. The captured choice travels with the existing local plan.
  Automatic/legacy plans have no inferred intention. Private task titles/routine text are absent
  from the new public command. New sessions reset the manual choice to Phone Away.
- Each party separately opts into campfire agreement version 1. The disclosure names recipients,
  session kind, start/planned end, optional intention, offline uncertainty and withdrawal. Existing
  members are not silently enrolled. Only sessions starting after that receipt can publish;
  enabling during a running session starts sharing with the next session. Private Wind Down
  decisions still fence publication. Turning campfire sharing off leaves other agreed sharing
  and the local timer intact.
- Active Shepherds and their visiting sheep use temporary, deterministic gathering positions.
  These positions never enter the saved arrangement or movement outbox; the ordinary positions
  return after end/expiry. Gathered figures open their existing member/visit cards, without drag
  writes to temporary seats. The background remains the existing paper meadow.
- The shared lantern keeps its existing 12-contribution progress and movable prop. It is an
  earned extra light beside the free gathering place. The first completed-session round grant
  per member per party-day still contributes once. Presence/scene visits never award wool or
  project credit. The personal Shop Barn Lanterns remain separate.

## Additive contract

`party.pasture.campfire` version 1 carries the caller's consent receipt and the latest session per
visible active member. Omission or an unknown version leaves live sharing unavailable with a
readable meadow. New Edge commands are `setCampfireSharing` and `publishCampfireSession`.
They use the existing authenticated v4 endpoint, existing public profile and membership epochs.

Consent is a compare-and-set revision. Each accepted change rotates its agreement UUID and clears
presence. A delayed acceptance cannot reverse a newer withdrawal; a previous UUID cannot publish
under a new agreement. An end is revision 2, a start revision 1. Tombstones prevent a delayed
start from resurrecting an ended source. Latest source is chosen before current/ended filtering.
Active epochs, linked accounts, block rules and current agreement IDs are checked on the server.
No private pre-consent session backfill or public Farm payload is added.

The local plan captures its immutable account owner at manual admission or automatic scheduling.
Restored sessions cannot publish under a different account; legacy/guest plans with no captured
owner remain unshared. The account-partitioned JSON pasture outbox stores captured receipt/epoch/revision/idempotency
identity. An end replaces a queued start; revocation removes queued publication before network
work. In-flight commands are checked against the current queue before dispatch. A start already
sent may be visible until the later withdrawal/end syncs. Relaunch and canonical party refresh
reconcile the phone's existing current/terminal run without changing the session coordinator.
Successful publications refresh observations without selecting another party behind the user.

The session's planned validity does not require foreground heartbeats. The screen invalidates at
expiry without a network poll; stale party observations stop presenting current campfire seats.
Offline early endings may remain as the last app report until the update arrives or validity
expires. Pending, acknowledged and retry copy distinguishes a running session from an ended one.
The start/protection path never waits for campfire transport. No new notifications, dependencies,
entitlements, targets, reward rules or protection transitions were introduced.

## Validation and rollout

See [local evidence](../../output/design/campfire-20260913/README.md) for actual build/test results,
native screenshots and limitations. Migration `20260913120000_campfire_sessions.sql` follows the
shared-pasture migration `20260912120000_shared_pasture.sql`. Deploy both missing migrations and
matching Edge command validation only under a separately authorized rollout. Older apps ignore
the added projection. Existing habit agreements retain their versions and meaning.

Physical acceptance must cover two disposable accounts/devices, before-bed → overnight → wake,
Phone Away intention, early end offline/reconnect, killed/reopened app, consent withdrawal,
leave/rejoin/block, account A/B isolation, simultaneous preference edits and real shielding.
The Mac lock prevented native tap/VoiceOver automation in this pass; Simulator render and domain
checks do not substitute for physical accessibility or protection validation.
