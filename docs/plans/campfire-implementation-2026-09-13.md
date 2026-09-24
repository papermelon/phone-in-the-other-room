# Campfire implementation — 13 September 2026

The founder authorized campfire implementation after the Shop/Ollie pass. This implements the
free gathering-place direction from the [collection/flow review](shop-ollie-and-campfire-2026-09-13.md).
Source is implemented and committed. The founder-authorized production backend rollout completed
on 13 September: [deployment evidence](../evidence/campfire-deploy-20260913/deployment.md).
Physical two-device acceptance and updated app distribution remain separate, outstanding gates.

## Bedtime presentation extension

The [19 September private bedtime contract](campfire-bedtime-2026-09-19.md) extends
current primary sessions with an optional frozen intended bedtime and local sleeping
pose. Existing sharing receipts remain valid; the technical capability is additive.
It supersedes awake-only art and defensive sleep-disclaimer copy on the private live
surface. Deployment/distribution/physical acceptance of this extension remain pending.

## Subsequent Buddies iteration

The founder approved the [Buddies source contract](campfire-buddies-implementation-2026-09-13.md)
later on 13 September. It adds agreement version 2, explicit authored intentions, volunteer support,
return check-ins and ordinary APNs invitations. The version 1 behavior and deployment recorded below
remain the compatibility baseline; its statement about no new notifications describes that iteration.
Buddies backend activation and push configuration are [verified](../evidence/campfire-buddies-deploy-20260913/deployment.md); device distribution and physical notification receipt remain pending.

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
- Founder correction after device feedback: the default Live sessions scene renders only members
  with a current, supported, freshly observed shared session. No active shared sessions means no
  fire and no characters. Membership and saved positions never imply activity. Current participants
  have distinct automatic seats and activity/planned-end labels; these seats are not editable.
- Shared meadow is a separate, explicitly labelled view for saved member positions, owned-sheep
  visits and the earned lantern. It keeps its existing arrangement controls. Switching views or
  a save acknowledgement does not reset the other view or persist temporary campfire positions.
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
expiry without a network request. While the party screen is visible and foregrounded, a
20-second canonical refresh supplements realtime invalidation; it stops on background/disappear.
Stale/unconfirmed party observations stop presenting current campfire seats, and retrying a failed
refresh does not itself restore live presence.
Offline early endings may remain as the last app report until the update arrives or validity
expires. Pending, acknowledged and retry copy distinguishes a running session from an ended one.
The start/protection path never waits for campfire transport. No new notifications, dependencies,
entitlements, targets, reward rules or protection transitions were introduced.

## Validation and rollout

See [local evidence](../../output/design/campfire-20260913/README.md) for actual build/test results,
native screenshots and limitations. Migration `20260913120000_campfire_sessions.sql` follows the
shared-pasture migration `20260912120000_shared_pasture.sql`. Both migrations and matching Edge
command validation were deployed under the founder’s separate authorization on 13 September,
with migration checksums and downloaded Edge source verified. Older apps ignore
the added projection. Existing habit agreements retain their versions and meaning.

Physical acceptance must cover two disposable accounts/devices, before-bed → overnight → wake,
Phone Away intention, early end offline/reconnect, killed/reopened app, consent withdrawal,
leave/rejoin/block, account A/B isolation, simultaneous preference edits and real shielding.
The Mac lock prevented native tap/VoiceOver automation in this pass; Simulator render and domain
checks do not substitute for physical accessibility or protection validation.

## Device-feedback repair — 13 September

The earlier implementation left all members and an always-lit fire in the scene, then overrode
only active members’ positions. The founder’s screenshots exposed a collision between an active
seat and an inactive member’s saved position. The correction above supersedes that presentation.
A service-unavailable error is separate from activity presence; it cannot establish that someone
ended a run. Connection/gateway errors now retain the original outgoing request ID instead of
minting a replacement that cannot be correlated with the server. The clearer message names the
connection failure. See [repair evidence](../../output/design/campfire-live-repair-20260913/README.md).
