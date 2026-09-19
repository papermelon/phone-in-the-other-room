# Campfire visibility — private and global implementation

Prepared 15 September; implementation authorized by the founder on 16 September 2026. One Campfire experience uses **Off / My Slumber Party / Global**, superseding “Together now” and a public-only Campfire name. Source is implemented locally; the new public migration and Edge function have **not been deployed or activated**. Existing private-party backend deployment remains separate.

## Implemented source contract — 16 September

- Home and Farm open the same Campfire, independently of party membership. Private group entry starts with that party selected; the group retains members/settings, Shared Meadow, sheep visits, lantern and history. Browsing uses a separate Viewing menu and cannot change publication.
- The visibility sheet incorporates the existing versioned private disclosure and the new public disclosure. Existing authorized private sharing migrates to My Slumber Party; all other accounts start Off. Global never follows from joining a party. Global can include explicitly selected private parties, each with independent authority.
- Running sessions can be explicitly shared from now without restarting the timer. Starts capture their owner and agreement; staged agreement responses bind only their originating command and, privately, membership epoch/revision. A later receipt cannot silently authorize an earlier run. Off/narrowing stop removed-audience sends, persist withdrawal and explain pending synchronization. Future automatic admissions refresh their captured audience when the choice changes.
- Both session types appear in the same live scene and accessible list. Typed join actions use the existing Wind Down or Phone Away start flow. Morning check-ins retain the existing checkInAfter gate. Live scenery is limited to eight people; persistent membership and sheep arrangements remain in Shared Meadow.
- Global is authenticated browsing for verified accounts, including accounts with zero parties. Version 1 offers activity filters, eight-person cursor pages, counts rounded upward to a multiple of ten, preset public aliases, an explicitly previewed Shepherd, rough time-left bands, fixed encouragement with owner receipt counts, block and profile report. No public history, exact session times, private intentions, party identifiers, source/account UUIDs or Farm inventory are included in participant cards. Own delivery receipts are returned only to their owner.
- The injected NightFlockService and existing NightFlockViewModel gain independent public methods/extensions rather than a second root model. CampfireVisibilityStore is an account-partitioned versioned JSON journal with recovery copies; it is never uploaded as a Farm save. The expected owner header prevents a queued agreement following a refreshed JWT into another account.
- campfire-global validates an allowlist and invokes service-only SQL RPCs. The migration starts disabled, checks consent and terminal precedence transactionally, honors existing account blocks, applies rate limits, and exposes no client table access. Expired public sessions disappear from reads immediately; a daily job physically removes session/command records after eight days, rate buckets after two days and report snapshots after ninety days. Account deletion cascades public records. Review these operational retention defaults before activation.
- Foreground snapshots refresh every twenty seconds. Stale/failed observations do not prove presence; socket disconnection does not end an otherwise valid shared session. No WebRTC or worldwide realtime subscription is introduced.

Native fixtures and validation evidence are in [the implementation record](../../output/design/unified-campfire-20260916/README.md). General connections, chat, broader routine UX changes and global scale/operations are later slices. The roadmap below distinguishes those proposals from this implemented first slice.

## Product boundary

Campfire is the place to share current Wind Down and Phone Away sessions, with a choice of audience. It can be used within a Slumber Party or globally without creating or joining a party. Slumber Party remains the ongoing private group: membership, shared rounds/history, meadow, visiting sheep and group improvements. Participation means an app-reported session, not verified sleep, online attention, physical phone placement or completion of a hobby/task.

| Surface | Purpose | Audience and duration |
| --- | --- | --- |
| Campfire | Share current sessions, find company and encourage one another | Selected private Slumber Party audience or explicitly chosen global audience; Off hides one's own live participation |
| Slumber Party | Build an ongoing habit with people you know or mutually choose | Invite-only groups, shared history and repeated seven-night rounds |
| Shared meadow | Arrange visiting sheep and earned group improvements | Remains private to its Slumber Party |
| Your Farm | Personal progression, sheep, Ollie, wool and customization | Existing account-owned private Farm |

Navigation: retain the four tabs and a direct Campfire entry accessible without a party. A Slumber Party's Campfire entry opens the same experience scoped to that group, with group identity visible and a route back to its meadow, members and round. Do not introduce a second name for private live sessions or require two equally prominent Home cards to express the audience distinction. Opening any entry only changes what is viewed. A global profile never exposes party names, membership, private plans or meadow arrangements. The completed [Cursor UI study](cursor-fable-social-ux-handoff-2026-09-15.md) remains visual evidence; its private “Together now” naming is superseded. [Astra's review](../../output/design/social-experience-study-20260915/ASTRA_REVIEW.md) still supplies the audience, start-routing, morning-eligibility and accessibility integration corrections.

## One visible audience control

Label the control **My visibility**, with three choices; use an adaptive menu or stacked choices at large text sizes rather than squeezing long labels into fixed-width segments.

| Choice | Meaning |
| --- | --- |
| Off | Do not publish my current Campfire presence to either audience. My timer, Farm and group membership continue. This controls live Campfire visibility, not separately agreed private group history. |
| My Slumber Party | Show my current shared session only to the chosen private party or parties. Name the destination group; if there are multiple parties, let me select them. |
| Global | Allow worldwide participants to see my minimal public session card. Party members may also see it; existing selected and consented private-party publication can continue independently. Global never exposes additional private group data. |

Remember the choice and show it on both start flows and the Campfire page. Complete any required private/public disclosure within this choice flow; do not send users to discover a second hidden enable switch. Choosing Global for the first time opens the public-card preview and disclosure before accepting the choice. With no running session, the choice governs the next start.

Browsing scope and one's publication audience are distinct. A secondary My party / Global view selector may change the people being viewed; it must never change My visibility. Off users may browse. Entry from a private group defaults the view to that group, and independent entry can restore the last viewed scope without publishing anything. This prevents exploring the global fire from silently widening an active private session.

Active-session behavior: Off or a narrower audience stops the removed audience's sends immediately and queues withdrawal, showing pending removal if offline. A broader audience requires an explicit “Share this session from now” action with the relevant agreement and preview. Publish only an allowlisted current-session projection from that accepted visibility change; do not backfill private history, intentions or earlier activity. The local timer and rewards never restart. Version the audience change so delayed retries cannot restore a withdrawn audience. This behavior is implemented in release source; the earlier DEBUG design study remains a separate prototype.

## Experience and subsequent connection phase

1. Open Campfire from Home without joining a party. See the number of currently shared sessions, split by Wind Down and Phone Away, plus activity gatherings such as Reading, Studying, Making, Resting and Wind Down. Counts are server-observed, timestamped and hidden as current when stale. Never seed fake people or inflate totals.
2. Browse a bounded scene and an accessible participant list. Show at most eight Shepherds around one fire; additional participants appear through a paginated list or another gathering, rather than shrinking everyone into one scene. This is a presentation group, not a new mandatory social membership.
3. Start either existing ritual through the existing start sheet. Review My visibility: Off, My Slumber Party, or Global. Returning users see the saved choice prominently and can change it per session; Global needs its own accepted disclosure. Private and public delivery can coexist under Global without a fourth top-level “both” choice. No session is public merely because the user opened Campfire or browsed the global view.
4. Preview the public card before first publication: chosen public name/Shepherd, session kind, selected activity and optionally curated interest tags. The first public release uses preset goals/activities and fixed encouragement. Separately authored free text can follow when its moderation path is ready. Private task/routine/reflection text is never copied.
5. After starting, the participant receives a seat based on the accepted server session. Wind Down lasts through planned wake, excluding Screen-Free Morning; Phone Away lasts to its planned end, with the existing 24-hour ceiling and terminal precedence. The public card displays a coarse remaining-time band; exact start/wake times remain internal and outside the public projection.
6. Put the phone away. Closing the app does not remove a valid shared session. Socket connectivity is not the presence clock. Ending early or withdrawing sharing stops local sends immediately and removes the public record when synchronized; a disconnected early end can remain visible until sync or expiry, with this limitation disclosed.
7. On return, see bounded encouragement and a deliberate “Connect” action if someone was helpful. The first connection phase uses mutual requests; it does not give strangers immediate messaging or access to private Slumber Parties.

Recommended discovery starts with voluntarily selected activity/interest tags, optional language and overlapping planned session windows. Do not infer hobbies from shielded apps, Health, private tasks or account history. Do not collect precise location or rank people by proximity. Let people change gatherings or broaden filters if a group is empty; sparse results are shown truthfully.

## Consent and privacy contract

- Public participation is independent of party consent. Existing party agreements, Campfire v1/v2 receipts, buddy notes and published party history cannot be migrated into a worldwide audience. No historical backfill.
- Default migration for existing users: retain authorized private Campfire sharing as My Slumber Party; otherwise start Off. Never select Global automatically. Preserve separately agreed group history. Provide clear public disclosure when Global is first chosen, plus an always-visible audience choice with distinct visual and VoiceOver labels.
- Public profile uses a separate pseudonymous identifier. Internal immutable account UUIDs, email/handle lookup keys, party member IDs and source run IDs do not appear in public cards. Reusing a Shepherd appearance is an explicit public-profile choice, not full Farm synchronization.
- One underlying run may publish independently to selected private parties and one public gathering. Capture the owner, audience epoch, effective sharing time and each exact agreement receipt at start admission or a separately confirmed visibility change. A retry cannot pick up a new audience, a new account or a later agreement. Independent per-audience statuses explain pending, accepted, declined and withdrawn publication; a saved preference alone never proves current visibility.
- Changing Global to My Slumber Party withdraws public presence while retaining eligible private publication. Off withdraws both live projections. Revoking a particular agreement also fences that audience without granting another one. These changes leave the local timer, Farm and Slumber Party membership intact. Deletion removes the applicable public profile, requests and publications, with minimal separately controlled moderation evidence retained only under the reviewed policy.
- Implemented retention: public reads omit expired/terminal sessions immediately. Internal session tombstones and command receipts are pruned after eight days, beyond the seven-day publication admission window; rate buckets after two days and report snapshots after ninety days. The migration schedules the daily deletion job using the existing pg_cron dependency. Backup retention and operational report handling require rollout review. Future unaccepted connection requests should expire after seven days. Public activity history is not offered.
- Recommend adult-only initial access, consistent with existing social direction. Age eligibility, public disclosure, moderation retention and App Store privacy disclosures require review against actual implementation and intended markets before public activation.

## Technical design

Reuse `FocusSessionCoordinator` and the existing `NightWatchPlan`; no parallel session state machine. Reuse `CampfireRules` for expiry, mixed-mode participants and seating where applicable. Extract scene/list presentation from `SlumberPartyPastureView` behind a narrow display model, rather than constructing a fake `NightFlockV4PartyDetail` for strangers.

The first implementation adds authenticated public commands/reads to the injected `NightFlockService`, with discovery and delivery in `NightFlockViewModel+GlobalCampfire` and audience choices in `NightFlockViewModel+CampfireVisibility`. Keep pure eligibility, matching and replay rules in `Shared/`. An injected publisher can fan out an admitted/terminal run and explicitly accepted visibility changes to independent party and public outboxes without affecting protection or reward settlement. Prefer the current Supabase package; no WebRTC is needed for this scope.

Proposed additive private storage and APIs:

| Record | Responsibility |
| --- | --- |
| Public-profile record | Owner UUID privately mapped to public profile ID; allowlisted appearance, display name and selected tags; moderation state |
| Public-sharing agreement | Version, receipt UUID, revision, accepted time, enabled state; withdrawal rotates/fences receipt |
| Public session | Owner/source key, agreement, audience epoch/effective sharing time, kind, activity, start/expiry, revision, ended marker, server observation and public session ID |
| Gathering view | Implemented activity filter and eight-person cursor pages; server-assigned sharding/capacity is a later scaling step |
| Encouragement | Fixed allowed type, sender/recipient/session scope, rate limits and expiry |
| Connection request | Requester, recipient, mutual state, expiry, block fences; separate from a party invitation |
| Moderation report | Bounded reported content snapshot, reporter, target, state and restricted operational access |

Implemented endpoint: `campfire-global`, with a read command (gathering, bounded participants and own delivery receipt) and agreement, publish/end, encouragement, block and report commands. Mutual connection/respond commands remain future work. Validate all writes in the server transaction; clients cannot choose another account's identity, claim arbitrary counts or forge acceptance. Server projections redact identifiers and data by audience. Use unique owner/source/receipt keys, compare-and-set revisions, end-before-start tombstones, consent epochs and account-partitioned versioned JSON outboxes.

A later realtime phase should deliver minimal gathering revision hints, then fetch an authorized snapshot. The current public implementation uses foreground polling. Do not broadcast profile data on a global channel: a block/withdrawal may occur while a socket remains subscribed. Every read rechecks access and filters blocked participants. Use authenticated private channels and server-controlled topics. Supabase supports channel authorization through RLS; it evaluates access at connection/join, so revocation must also fence reads and reconcile existing subscriptions. [Supabase Realtime authorization](https://supabase.com/docs/guides/realtime/authorization).

Global scale requires bounded work: topic/shard channels, cursor pagination, coalesced invalidation, cached aggregate counts, indexed expiry queries and a scheduled sweeper. Subscribe only to the visible gathering; keep the existing 20-second foreground fallback initially, with backoff/jitter during failure. Avoid one subscription per worldwide user or one database reload per global event. Blocks change the viewer's eligible list; aggregate wording must state its scope instead of suggesting every worldwide account is represented.

A WebRTC phase would be justified by a separately chosen live audio/video experience. It would require signaling, media permissions, relay infrastructure and moderation appropriate to that experience; it would not replace account, consent or session storage. [WebRTC connection model](https://webrtc.org/getting-started/peer-connections).

## Connecting with people

Phase one provides shared presence, activity tags and fixed encouragement. Phase two adds a bounded mutual “Connect” request, a small saved-connections list and opt-in invitations to a future shared session. After mutual acceptance, either person can explicitly invite the other to a Slumber Party using its existing disclosure; acceptance never imports prior private history into the global surface.

Default proposed controls: one outstanding request per pair, a daily sending limit, no push for repeated requests, decline and block, cooldown after decline, and an independent opt-in for connection notifications. Apply blocks across global discovery, requests, encouragement and party joining using the existing account-level boundary. A connection alone grants no historical schedule, precise wake time, private Farm or party visibility.

Direct chat, voice/video, automatic matching with a named stranger and public free-text intentions are later optional slices. They are not prerequisites for meaningful discovery and mutual reconnection. These are proposed sequencing decisions, not a ban on the founder's broader social direction.

## Moderation and release operations

Public names and profiles already introduce user content, even without chat. Implement filtering of public names/text, participant/profile reporting, immediate blocking, rate limits, restricted moderation tools, published support contact and an operational owner who can process reports. Test removal/suspension and appeal handling with disposable accounts before public beta. Apple's user-generated-content guidelines require filtering, reporting with timely responses, blocking and contact information. [Apple App Review Guidelines, 1.2](https://developer.apple.com/app-store/review/guidelines/#user-generated-content).

Keep public discovery behind a server capability and independent kill switch. Turning it off stops new global publication and removes public projections without changing local protection, private parties or settled rewards. Do not award wool, Farm credit or lantern progress for sitting at a fire, sending encouragement or acquiring connections.

## Delivery sequence and acceptance

| Phase | Concrete deliverable | Acceptance |
| --- | --- | --- |
| 0 — current party repair | Visible Campfire setup in both start flows; own-session explanation; adaptive large-text controls | Two different accounts share Wind Down and Phone Away concurrently; both see both seats. Off/new consent is explained without retroactive upload. Validate on replacement for build 51. |
| 1 — design and contract | Apply the unified Campfire visibility direction; settle public profile preview, audience-change/retention contract and accessible states | Paper-art prototypes for small phone, light/dark, largest Dynamic Type and eight participants; browsing never publishes; Off/private/Global transitions and final public payload reviewed |
| 2 — backend and model | Add public profile/agreements/session storage, APIs, bounded gathering assignment, blocked projections, outbox replay and kill switch | Isolated SQL/API tests for identity spoofing, late start/end, consent races, simultaneous devices, withdrawal and no private-party leakage |
| 3 — app presence/discovery | Shared Campfire entry/view, Off/private/Global visibility, mixed-mode scene/list, filters and fixed encouragement | Account with zero parties can discover and join; both audiences can coexist with independent receipts under Global; narrowing/withdrawal and explicit widening reject stale retries; offline UI never invents presence |
| 4 — mutual connections | Requests, accept/decline/block, saved connections and explicit party invitations | Stranger cannot message, join a private group or obtain private history through a connection; duplicate/abusive requests bounded |
| 5 — controlled rollout | Moderation operation, load test, internal multi-device beta, gradual public activation | Full build/unit gate, isolated backend suite, real shielding/push/background/account-switch tests and written rollback evidence |

Initial performance targets to validate, not current guarantees: new/ended sessions converge on foreground peers within five seconds under healthy realtime; within the fallback interval plus request time when realtime is unavailable. Test 1k and 10k concurrently shared sessions with bounded 8-avatar/50-row views and bursty starts; measure fan-out, query latency, stale time, battery/network usage and cost before choosing an initial rollout cap. Account for iOS suspension: continuous background publication is not required.

Record product outcomes using minimal aggregate instrumentation: public opt-in, consent/setup drop-off, successful shared starts, return check-ins, accepted connections and blocks/reports. Avoid optimizing for time spent browsing Campfire; measure whether people start and return to their chosen sessions. Keep factual timer outcomes separate from self-reported habit progress.

## Decisions and external gates before public activation

Recommended defaults are independent Home/Farm access, adult-only initial release, explicit public opt-in, preset activities/interests, coarse public timing, no public activity history, and mutual connections before free chat. Founder review should settle these alongside public-name reuse versus a separate alias, whether viewers need an account, first topic set, operating/moderation ownership and rollout size. Local implementation uses verified-account browsing, a separate preset public alias, and the activity set described above. Confirm operating ownership, age eligibility, retention, disclosures and rollout size before activation; local implementation does not authorize deployment or distribution.

## Build 51 report and current limits

The founder supplied two screenshots from different accounts, both build 51: a Wind Down ending around 07:00 appears on both phones while the other phone is running Phone Away. The founder had enabled Slumber Party and did not know Campfire had separate consent. Current source and SQL allow both kinds; the client hides setup when no Campfire agreement is enabled. This is a likely explanation, not a verified observation of either device's consent receipt or historical server request.

The local repair exposes that setup and explains next-session eligibility. It does not change the public audience, bypass consent or claim the two physical phones have been repaired by a local build. Confirm agreement status and repeat with a new shared session on each account after distributing the updated app. Preserve their Farms; use disposable accounts for destructive/race tests.
