# Slumber Party pasture redesign — 12 September 2026

Status: local production source, migration and isolated validation implemented. No deployment,
release upload, commit or push. See [implementation evidence](../evidence/pasture-redesign-20260912/README.md).

Founder correction during implementation: **retain the current shared meadow artwork and its
wide framing**. The scenery refresh is the personal Farm, barn and related previews. The original
courtyard concepts below are historical alternatives, superseded for shared background art.
The accepted lantern policy is **12 contributions**: the first completed Wind Down or Phone Away
per member per party-day receiving an existing round grant. No early-ending project contribution,
no new personal currency; progress carries across rounds/membership changes. Two daily participants
finish in six days, eight in two days. Each eligible party progresses independently.

People remain customized Shepherds. Owned sheep visit until recalled, with one per member per
party and one party per sheep. Everyone can arrange the shared entities; recall and private
ownership stay with the owner. Active Wind Down can open the interactive pasture without changing
session or shielding state. Founder confirmed after the working study: Ollie stays on the personal Farm for this release.

## Evidence and scope

Reviewed the [prototype handoff](shared-farm-prototype-2026-09-12.md), its native
[party capture](../evidence/shared-farm-prototype-20260912/02-party.png),
[light capture](../evidence/shared-farm-prototype-20260912/12-party-light.png),
[friend card](../evidence/shared-farm-prototype-20260912/03-card-moss.png), and personal Farm
capture; inspected `SlumberPartySharedMeadowView`, `SharedMeadow`, public avatar rendering,
current product decisions and reward boundaries.

The prototype provides reusable interaction and fixture scaffolding. It is gated by
`sharedFarmPrototype`; visits and delivery transitions are simulated. Its reported 967-test
pass is prior evidence, not a test run or acceptance of the design in this planning task.
The [10 September backend evidence](../evidence/slumber-backend-20260910/deployment.md)
documents public head shape and update-cheer acknowledgement deployment. It does not establish
deployed visits, shared decoration state, new rewards or meadow greetings.

The supplied prototype screenshots still show a large repeated party header and introduction
above the scene. Characters occupy a seeded two-row arrangement; large empty ground and name
capsules dominate. On the SE capture, the lower characters reach the tab-bar edge. The friend
card still gives substantial space to explanation and the same three abstract reaction names.
Adding motion alone will not fix this hierarchy or make the setting feel inhabited.

Scope is the Slumber Party journey and its existing Home/private Farm connections. Preserve
the four tabs, existing ritual, account ownership and membership architecture. General
discovery, chat and a new currency are outside this design. Live multiplayer is the selected
longer-term direction, beyond the first version's shared placements and timely session cues.

## 1. People, animals and the shared place

- **People:** each member is represented by their own Shepherd and canonical name, with the
  supported head, hair, skin and fitted cosmetics. The same public identity serves the meadow,
  member sheet and related Home entry. This is the redesign target; retain old avatar fields
  for compatibility until a deliberate migration is implemented.
- **Sheep:** separately selected owned animals, with a discoverable owner. A sheep never doubles
  as a person's profile. Adding one is an explicit sharing action, not an upload of the flock.
- **Ollie:** founder reviewed the functional owned-companion study and chose personal-only
  Ollie for this release. Keep shared companions in DEBUG evidence only. Personal fetch/gather
  is implemented; tapping Ollie opens his details/play/owned accessories, with an explicit Shop
  link. Tapping other residents opens their own detail/customization destination. The Shepherd's
  live model stays visible above the scrolling customization controls.
- **Presence:** a Shepherd's place in the scene represents membership. Wandering, sitting or
  waving is ambient animation, not evidence that the account is online, asleep or participating.

Selected sheep model: an ongoing visit until recalled, with private ownership and progression
preserved. The founder clarified that the animal appears in the Slumber Party shared pasture
together with its owner. Arrive beside the owner's Shepherd and expose that relationship through
selection and an owner label; do not forcibly tether it or undo deliberate shared movement.
Keep the private flock inventory/progression entry with a visiting badge; draw the animal in
its shared pasture, without a duplicate in the private scene during the visit. Accepted starting
limits: one active sheep contribution per member per party, and one party per owned sheep. The prototype's seven-night timer is
superseded. Other people moving a sheep cannot recall, trade or take it.

## 2. Art direction and scene composition

Founder follow-up extends paper-textured scenery to the personal Farm, barns and meadows as
well. Use one consistent environment-art family across both Farms and retire superseded assets
after migration. See [asset migration and retirement](farm-art-retirement-2026-09-12.md).

Selected direction: a hand-illustrated farm diorama viewed from slightly above. Retain the
paper-textured character language. Test the existing front-facing renderers against the camera;
do not select a steep isometric angle that would require incompatible character views.

Design three purposeful areas in one coherent landscape:

| Area | Visual role | Character and touch behavior |
| --- | --- | --- |
| Gathering spot by a tree, bench or lantern | Human focal point, slightly off-centre | Shepherds gather in small groups, turn or wave; selecting a person opens their card |
| Open grazing patch with flowers and a path | A readable home for contributed sheep | Sheep graze, cluster and react to a gentle nudge; selection identifies sheep and owner |
| Barn, gate and improvement site | Depth, arrivals and visible shared progress | A new visitor enters through the gate; an earned improvement changes an actual part of the place |

Use foreground grass, middle-ground residents and distant structures, consistent feet/shadows,
appropriate relative scale and controlled occlusion. Place people asymmetrically around the
setting instead of distributing them in roster slots. Richness should come from authored places
and relationships, not a busy background or more text.

Two people should feel like a small gathering in a complete place. Eight people plus visitors
should occupy connected areas with camera panning or framing controls, rather than shrinking
everybody. Keep touch areas at least 44 points; make occluded residents reachable through the
people control. Test two, four and eight members before accepting the composition.

Use compact unobtrusive names for Shepherds, with stronger name/selection treatment for the
focused person. Sheep names and ownership appear on selection. Full names, large type and all
actions remain available in the accessible member/animal list. Never solve density by making
the accessible version tiny or truncating the only available name.

Produce two composition studies of the same diorama direction, each with two- and eight-person
states, before building new scene mechanics. Image generation can help with layered scenery
after choosing the composition; generated character lookalikes must not replace production
renderers. Still artwork cannot validate gestures or physics.

### Two concrete composition studies

**A — Lantern courtyard (historical concept; shared-art replacement declined).** A curved path enters from a foreground
gate and leads toward a small barn at the rear right. An off-centre tree and lantern gathering
spot occupy the left middle ground; a broad grazing patch connects the foreground and right
side. With two members, place one Shepherd near the tree and the other alongside a sheep on
the path, with room for a friendly interaction. With eight, use small clusters around the tree,
gate and barn rather than two rows. The selected first group improvement is a lantern gathering
spot: its completion adds an actual structure and warm pool of light that members can gather
around. Thresholds remain to be specified; a decorative light is not itself a session indicator.

**B — Winding meadow.** A shallow stream or flower border divides two connected grassy areas,
with a path/bridge between them and the barn on the rear edge. Members and sheep form small
groups along the curve. Panning reveals the second area at the same readable character size.
This offers more room for larger groups, but the opening frame must still feel complete for two
people. Avoid placing an unseen friend where their session cue cannot be discovered from the
people control. Compare this composition against A before introducing extra buildings.

For both studies, present the same two/eight residents, outfit variety and selected-member
state so the comparison evaluates layout rather than different content. Use the exact production
Shepherd renderer; test front-facing art on the elevated ground plane before requesting new
poses. Overlay UI should occupy reserved space, not cover feet or the gathering area.

The first screen should contain: one compact party title; the usable pasture; a small current
session/peer cue; and access to People, Sheep and the shared improvement. Additional details
scroll below. At large accessibility sizes the equivalent list may take priority, while the
scene remains reachable. Repeated explanatory paragraphs are not a substitute for these controls.

## 3. Screen hierarchy and member journey

### Home and Farm entry points; founder copy constraint

Accepted navigation: retain entry from both Home and Farm, with different purposes. Home surfaces
timely peer-session cues and a relevant new response; Farm provides the stable connection from
personal identity/animals to the shared pasture. Both use the existing party state and destination
screens, with consistent one-party/multiple-party routing and a predictable return to the source
tab. Do not duplicate the party feed or full roster on either entry card.

The founder explicitly requires keeping the retained Farm card's existing title and copy.
Preserve the joined-party variant verbatim (source: `NightFlockPresentation`, `.farm`):

- Eyebrow: **SLUMBER PARTY · YOUR FARM**
- Title: **Your Farm look travels with you**
- Detail: **Your curated Farm look appears in your parties. Completed shared moments can bring wool home.**

Keep the existing no-party create/join variant and capability/consent handling appropriate to
that state. Do not silently replace the retained card text with new visit, project or physics
marketing. The shared-improvement direction preserves existing personal grants; new copy must
not redefine the current wool sentence as a promise that every shared moment earns wool.

### Give each piece of information a primary home

The founder's IMG_7802 shows the same members as meadow characters, an accessible list entry
and full People cards. Keep the meadow plus its accessible list equivalent; remove the second
full People-card section in the redesign. Move member-specific summary details into the same
member sheet opened by both the character and the list. Preserve access to allowed sleep
summaries/coverage, plans and group controls; removing duplication must not remove capabilities.

| Information | Primary presentation | Other surfaces |
| --- | --- | --- |
| Who belongs and current reported session | Pasture and equivalent People list | Compact Home cue; member sheet details |
| A member's latest update, sleep/plan details | Member sheet | One concise group-stream preview linking to the same update |
| Chronological shared moments | One group stream with earlier records on demand | Contextual links; no second full history stream of the same records |
| Group improvement and round progress | Compact group summary with its detail view | Scene change or brief new-event cue |
| Sharing/receipt explanations | Relevant detail or help surface | Short state-specific feedback where an action occurs |

The two matching Phone Away cards in IMG_7803 require record-identity investigation. They may
be distinct short sessions with identical rounded text or the same source projected twice.
Existing `legacyRoundHistoryActivities` suppresses linked round records already represented
in the membership stream, but a screenshot cannot establish the source IDs or root cause.
Trace activity ID, source/run linkage, roundActivityID, membership epoch and pagination/retry
merging. Deduplicate confirmed duplicate representations by stable source identity, retaining
all legitimate cheer references. Never collapse separate sessions merely because member, date,
rounded minutes and outcome match. Show time or a compact expandable session grouping when
distinct valid records otherwise look identical. Add isolated cases for both situations in
the implementation batch; do not delete backend records as a visual cleanup.

Party detail opens with a compact title and group-controls button, followed immediately by the
pasture. Remove the repeated large title/instruction card. Make the scene and a usable action
visible before scrolling on SE-sized screens, clear of the bottom tabs.

1. **Idle Home or private Farm → party:** the existing entry previews a real new greeting,
   visitor or earned change when available. Private flock selection offers the visit action
   once a supported party and sharing agreement exist.
2. **Pasture:** compact People, Sheep and group-project controls. Selection opens one member
   sheet or sheep sheet; there is no second full roster of duplicate cards underneath.
3. **Member sheet:** Shepherd/name, fresh app-reported session state where available, latest
   eligible update with date and context, response action beside it, and earlier updates on demand.
   Own sheet provides own contributions and received responses. A member without an update still
   has a useful profile and sheep presence.
4. **Shared ritual:** keep tonight's agreed plan and current round summary discoverable below
   the pasture, with details on demand. Do not bury the approved shared-plan experience inside
   a single miscellaneous history disclosure.
5. **New activity and responses:** a compact stream or inbox, opening the original context.
   Explain sharing once near its action; place evidence, coverage and delivery details where
   they help interpret a specific update. Empty state, unavailable data and stale data differ.

## 4. Play and responses

Founder follow-up explicitly requests richer interactions and physics in both the personal and
shared Farms. See [developer research and concrete experiments](farm-interaction-research-2026-09-12.md)
for sources, current implementation limits and a common motion layer. Evaluate Ollie's role
through fetch/gather behavior; its shared inclusion remains undecided, not automatically omitted.

Prototype tap to select, hold/drag to move, and release to settle as separate gestures. Petting
or nudging a sheep gives a short squash/bounce/recovery; Ollie can react to nearby movement;
Shepherds can turn/wave where supported by the renderer. Use bounded collisions, speed limits,
ground constraints and stable resting places. Protect scrolling and camera movement from
accidental grabs. Offer equivalent explicit actions for accessibility.

Selected first shared model: everyone sees the same residents, unlocked structures, deliberately
placed decorations and persisted character positions. Every current member may move any
Shepherd or sheep. A drag commits its final placement to the group; other clients reconcile it.
This is a shared action, unlike the prototype's local-only movement. It is not a greeting or
claim that the moved person is active. Ownership, customization and recall remain owner-only.

Use normalized ground anchors tied to a scene revision, not device pixels. Local ambient
movement stays bounded around those anchors. Everyone shares the same resting arrangement
across different screens and relaunches. Immediate touch feedback is local; pending, saved and
failed placement must be distinguishable. Send final drop positions first, not a continuous
stream of finger coordinates. Full live movement transport is later scope.

Use per-entity revisions and idempotent move intents. For the first version, propose accepting
one concurrent move and rejecting a stale competing revision, then smoothly reconciling to the
server position. Do not let delayed offline commands overwrite newer moves silently. Local
collision responses must not cascade into unbounded shared writes; validate each final placement
and retain usable paths and selection. Petting without a placement remains local feedback.

Give a response an understandable intention and a small character expression. Explore a wave
and a supportive celebration using the existing fixed-cheer transport where meaning fits.
Do not silently rename a persisted reaction to a materially different meaning. A deliberate
Send action names the recipient and context; avoid a mandatory three-screen explanation for
every repeat send. An inline visual preview can explain the first use.

Recipients can reopen the sender and original context. Pending, server accepted, received by
the recipient app and retryable failure remain distinct. Presentation of a response animation
needs durable deduplication independent of network acknowledgement so refresh/relaunch cannot
repeat the celebration. No implied read receipt. Greetings without an update require a new
context capability, not a fabricated activity.

### Body doubling, including active Wind Down

The interactive pasture is explicitly allowed during the viewer's active Wind Down. Provide a
clear route from live Home and back to the running session; keep its timer/state visible without
repeating a large session card over the scene. Opening, dragging or leaving the pasture must not
pause/end the ritual, clear shielding, fabricate Brief Access, change a plan or add reward credit.
Keep completion/emergency routing intact and network failure independent of local protection.

Timely cues are part of the first version, not deferred with full multiplayer. Reuse the existing
membership-scoped `sharedLiveStatuses`/compatible `liveStatuses` with revision, observed time and
expiry. `NightFlockService.startV4Realtime` already treats changes as hints to retrieve canonical
state. Extend this reconciliation for scene state; verify deployed subscriptions and two-device
latency instead of inferring availability from source.

On idle Home and in the pasture, members can notice a friend's active reported session, inspect
its mode, and start their own eligible ritual through the existing coordinator. Seeing a cue
never automatically starts, schedules or changes a session. Use a small mode symbol/state label
and restrained environmental treatment near the Shepherd. The accessible list conveys the same
information. Scene behavior should make being together legible without a roster of absentees.

Distinguish planned timing, a fresh active report, expired/unknown report, completed update and
future actual presence in the pasture. Session status is not an online indicator, proof of sleep
or proof of continuous physical placement. Stop/expiry clears active cues even after a missed
realtime event. Disconnection shows last-known/unknown state; it must not leave a character
permanently marked active. Background iOS delivery is best effort. Establish a measured freshness
target in a two-device test, including delayed launch and reconnect.

The founder's UI change authorizes deliberate interaction, not new unsolicited notifications,
sounds or reward for keeping the app open. Preserve existing notification policy, comfortable
night visuals and Reduce Motion while making touch available. Future live multiplayer adds
explicit ephemeral presence, movement ordering, rate limits and disconnect handling using the
same membership and durable anchors.

## 5. Reward proposal — visible shared improvements

Selected reward direction: participation grows a shared improvement, such as a flower patch,
lantern area or shelter. Contributing a sheep makes it part of that place and its completion
celebration. Keep the relationship visible so the reward is attached to the pasture itself.

Use existing eligible party participation and server-authoritative grant machinery as the
starting point. Do not calculate grants from an animation, time spent visiting, repeated cheers,
Health sleep duration or a zero/nonzero displayed minute count. Do not reinterpret private Farm
credit or already-settled party rewards. Existing approved per-party fan-out remains intact.

The approved contract above fixes qualifying events, threshold, progress between rounds and treatment
of early endings, two-versus-eight-member pacing, multi-party participation, new members, recalled
or traded sheep, leavers and party deletion. Give every project completion and personal grant
stable identities and replay tests. Shared ownership of a placed improvement differs from private
ownership of a sheep. Prefer progress that stays; no group reset due to an absent member.

New personal wool/cosmetics and sheep reward multipliers are outside the selected first slice;
existing personal grants remain. The approved 12-contribution threshold introduces no second currency. Sheep contribute presence and attachment; their mere time on screen does not
generate the selected participation reward.

## 6. Architecture, consent and compatibility

- Reuse `PastureScene`, `SharedMeadowSceneController`, production renderers, existing member and
  update selectors, the account-scoped outbox and durable receipt projection. Refactor reusable
  prototype components into production only after validating the composition and behavior.
- Keep person identity, owned-sheep contribution and local scene entity as separate roles linked
  to existing member IDs. A catalogue ID alone is not proof that an account owns a sheep. Define
  an opaque contribution reference with server-validated ownership and bounded public appearance;
  do not disclose a private inventory or Farm document to other members.
- Verify the curated public Shepherd fields for members whose old selected avatar was Ollie or
  sheep. Explain the presentation transition; publish only agreed fields under a compatible
  capability. Do not expose absent private head/hair/outfit data merely to avoid a fallback.
- Add visit, shared-layout/project and extra greeting capabilities only as needed. Preserve old
  client decoding, unsupported-server fallback, account switching, membership epochs, blocks,
  leave and deletion. Document archive behavior separately from current scene visibility.
- Every current member may move any character/sheep, enforced through the existing party boundary.
  Only the owner selects/recalls their sheep or changes their appearance. Shared decoration editing
  is also open to every current member, as selected by the founder. Reuse the revision/conflict
  rules for placements; arranging structures does not authorize deleting group rewards or
  modifying another member's private Farm.
  Server revisions, rate limiting, invalid-location rejection and a recoverable arrangement
  protect shared editing. Do not add a lock that defeats the selected everyone-can-move rule.
- Replace the prototype's required expiry with recall-based lifecycle. Ownership transfer, trade,
  removal and leaving must invalidate inappropriate active contributions without deleting private
  animals or already-earned grants. Keep archived history separate from current scene visibility.
- Audit all active-Wind-Down guards in Home routing, party views, send actions and animation.
  Replace only those needed for the newly permitted pasture experience; preserve shielding,
  coordinator transitions, emergency exit, settlement, privacy and notification boundaries.

## 7. Small batches and acceptance

| Batch | Concrete outcome | Acceptance |
| --- | --- | --- |
| A. Settle direction | Record the six founder answers below and remaining detailed choices | Old avatar/quiet rules explicitly superseded; prototype assumptions not promoted silently |
| B. Native visual study | Two-person and eight-person diorama using real customized Shepherds and separate sheep | Scene appears above the fold; grounded feet, readable selection, no inaccessible overlaps; dark/light and SE review |
| C. Touch and navigation | Character interaction, member/update selection, sheep visit flow, accessible list | Finger-tested tap/drag/pan distinction; no accidental send; stable deterministic selection; Reduce Motion and VoiceOver equivalents |
| D. Durable social integration | Public identity migration, visits, shared placements, timely status cues and replies in release screens | Account/leave/block fences; concurrent/offline moves; start/stop/expiry/reconnect; real recipient acknowledgement on two accounts; active-session routing preserves protection |
| E. Reward slice | One shared improvement using existing participation/grant foundations | Server-authoritative eligibility, exactly-once settlement, pacing review, no duplicate grant on switching/rejoining/replay |
| F. Release validation | Actual release-path screens and rollout evidence | Full app build/unit suite; screenshots; two-device offline/reopen/quiet checks; deployment and upload separately authorized |

Representative states: fresh party with no sheep or updates; two distinctive Shepherds with
outfits; eight people and visitors; selected person versus selected sheep; new response; pending
or failed send; stale/offline data with last known residents; unsupported server; recalled sheep;
blocked/left member; account switch; project in progress and completed; active Wind Down.

One correctness question must be verified before adopting the prototype copy: the presentation
functions turn `completed + roundedMinutes == 0` into “started after bedtime” without a bedtime
comparison input. That does not by itself prove the claimed cause. Check the producer and
rounding contract, and use neutral recorded-minute wording unless the evidence establishes it.

## 8. Founder answers and follow-up decisions

The primary decisions and subsequent clarifications are recorded below:

| Question | Selected answer |
| --- | --- |
| Visual direction | Slightly elevated illustrated farm diorama with barn, paths, gathering spot and grazing sheep |
| First reward | Shared decorations and pasture improvements from eligible Wind Down/Phone Away participation |
| Shared state | Persistent positions and deliberate moves now; live multiplayer eventually; timely habit cues needed now for body doubling |
| Sheep lifecycle | Stays until recalled; private ownership and progression preserved |
| During active Wind Down | Interactive shared pasture remains available |
| Who can move characters | Everyone may move any character or sheep, with changes visible to the group |
| Where visiting sheep appear | In the Slumber Party shared pasture together with their owner |
| Who arranges group decorations/structures | Everyone |
| Sheep limits | One active sheep per member per party; an owned sheep visits one party at a time |
| Private pasture while visiting | Retain flock entry/progression with visiting badge; animal is drawn in shared pasture |
| Starting composition/project | Original wide shared meadow; separate earned lantern prop |
| Entry points | Keep Home and Farm, preserving the Farm card title/copy |
| Ollie | Personal Farm fetch/gather; shared companion retained as a DEBUG-only study |

The founder accepted the recommended starting choices after the navigation/duplication review.
The remaining work is concrete design and engineering validation rather than another broad
product questionnaire:

- Validate the approved 12-contribution policy on two physical accounts and confirm deployment order.
- Inspect the original shared meadow at two/four/eight members and preserve its wide proportions.
- Founder reviewed the working shared companion study and chose personal-only Ollie for this release.
- Define shared-move conflict/offline recovery and scenery boundaries using existing membership
  permissions. All members may arrange characters/sheep and earned scenery; animal ownership,
  recall and customization remain with the owner.

These agreed choices prepare the plan for implementation. They do not establish new deployed
capabilities or authorize deployment, distribution, commits or pushes in this planning turn.
