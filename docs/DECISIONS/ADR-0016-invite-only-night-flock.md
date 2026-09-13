# ADR-0016: Invite-Only Slumber Party

- Status: Accepted; v4 production backend deployed 2026-08-25; app/device/operations gates pending
- Date: 2026-08-25
- Decider: Founder
- Supersedes: v1–v3 Slumber Party product contract; those schemas remain legacy compatibility only
- Related: ADR-0003, ADR-0005, ADR-0006, ADR-0010, ADR-0015

## Campfire direction — 13 September 2026

The founder authorized implementing a free campfire in the existing shared meadow. The lantern
remains an earned movable improvement, with its existing progress preserved. Customized Shepherds
represent app-reported Wind Down/Phone Away sessions through a separately consented per-party
campfire version 1 contract; private task text stays private. Temporary seats and visitor positions
never overwrite deliberate arrangements. The default interval ends at planned wake for Wind Down
and planned end for Phone Away; no sleep or actual offline-activity inference is made. Revisioned
end/withdrawal, expiry and account/membership fences apply. This updates the prior lantern focal
point, not reward rules, identity, sheep ownership or four-tab routing. See the
[implemented source contract and rollout gates](../plans/campfire-implementation-2026-09-13.md).
Hosted activation is not implied by source implementation.

## Founder redesign direction — shared pasture and body doubling (12 September 2026)

Founder correction during implementation (12 September 2026): retain the existing shared
meadow artwork and its wide, open framing. It already matches the characters; the scenery
refresh belongs to the personal Farm, barn and related previews. New shared interaction,
visits, hierarchy and lantern improvement remain in scope, without replacing this backdrop.
Lantern pacing approved: 12 contributions, at most one existing completed-session round
grant per member per party-day; progress carries across rounds and membership changes.


Local production source is implemented; backend activation and physical two-device acceptance remain outstanding. This direction supersedes the
mixed Shepherd/Ollie/sheep identity choice and the prohibition on active-Wind-Down social UI
for the shared pasture. People are represented by their customized Shepherds; owned sheep are
separate contributions staying until recalled, preserving private ownership and progression.
Visiting sheep appear in the party's shared pasture together with their owners. Every current
member may arrange the group's earned decorations and structures. Accepted starting limits:
one active sheep per member per party, one party per owned sheep; its private flock entry and
progression persist with a visiting badge while the animal is drawn in the shared scene.
Founder confirmed after the working eight-person study: keep Ollie on the personal Farm for this release. Fetch/gather remain personal play; the shared companion experiment is DEBUG-only. Keep the original shared meadow; add the earned lantern as a separate movable prop.
Keep Home and Farm entries, preserving the existing Farm card title/body/eyebrow exactly.
The setting is an illustrated, slightly elevated farm diorama with meaningful gathering and
grazing areas. Eligible Wind Down/Phone Away participation earns shared decorations/improvements;
the first completed Wind Down or Phone Away receiving an existing round grant per member per party-day contributes once, starting at activation. The lantern requires 12 contributions, carries across rounds, and preserves all personal grants. Early endings do not contribute to the project.

Character positions and deliberate moves are shared in the first version. Every current member
may move any character or sheep; movement does not transfer ownership, appearance control or
recall authority. Full live multiplayer is a later direction. Timely, expiring app-reported
session cues are needed now to support body doubling and peer motivation; they do not prove
online attention, sleep or physical placement. The interactive pasture remains available during
active Wind Down without ending/pausing protection or changing ritual settlement. This does not
authorize new unsolicited notifications or reward for keeping the app open.

Preserve account/membership isolation, agreements, compatible public appearance and truthful
acknowledgements. The 12 September prototype's simulated backend, seven-night visits and local-only
arrangement are not production contracts. See the [redesign plan and answered questions](../plans/slumber-party-pasture-redesign-2026-09-12.md)
for visual batches, contracts and validation. [Implementation evidence](../evidence/pasture-redesign-20260912/README.md) distinguishes local source, isolated checks and outstanding device/rollout work. No deployment or distribution was performed.

## Earlier implementation decision — shared Farm and contextual cheers (9 September 2026)

Historical source scope below; the 12 September redesign supersedes mixed scene identities and
the active-session UI exclusion. Update-context references and truthful receipt rules remain.

Source implementation is authorized for a shared Farm containing each member's chosen
Shepherd, Ollie or explicitly selected sheep, supported clothing and head shape, readable names,
stable selection and an accessible list. Idle Home uses its existing party route. Character
selection opens the latest eligible already-shared update; fixed cheers sit beside the update.
Recipients can reopen named cheers at their original update. An app acknowledgement confirms
receipt by the recipient app, never that a person saw a cheer. These additions reuse membership,
identity, activity and reward boundaries; active Wind Down remains quiet.

The optional allowlisted public head shape extends curated appearance; it does not expose a
private Farm profile. Both the existing social-avatar agreement gate and independent server
capabilities remain required. Backend source/migrations and disposable native fixtures are
included; production deployment, sharing activation and release distribution are separate,
unapproved actions in this task. See [plan and evidence](../plans/slumber-party-shared-farm-and-cheers.md).

## Founder decisions — shared accountability (2026-08-28; implementation pending)

The following supersedes earlier product exclusions where they conflict; the deployed V4 and
membership-stream descriptions below still describe their narrower implemented contracts.

- Founder direction on 2026-08-30 makes shared Wind Down plans and factual follow-through part of
  the core Slumber Party loop. Members should see agreed nightly timing and routine ideas, followed
  by a per-night comparison between the frozen plan and Counting Sheep's factual run record.
  Implement this additively with versioned plan instances, member-night receipts, coverage, and
  explicit evidence states. Routine ideas remain unverified; unknown is not failure; the leader
  cannot edit another adult's plan. Exact selected-app identity and per-app usage remain separate
  platform gates. The implementation sequence and wire direction are in
  `docs/plans/slumber-party-social-habit-loop-implementation.md`.

- Historical 28 August social-avatar choice was Shepherd, Ollie or a selected sheep. The
  12 September redesign uses Shepherds for people and sheep as separate contributions.
  Preserve legacy decoding/appearance consent while migrating; personal Home identity is not
  overwritten by a historical social-avatar selection.
- Start with adults and a group leader who coordinates the shared habit. The future parent/child
  bedtime-negotiation use case informs the architecture, but does not authorize actual child
  accounts, unilateral schedule changes or remote enforcement now. Exact leader powers need a
  bounded specification. Friendly competition is a desired direction; scoring is not yet chosen.
- Exact app identification must be automatic before category grouping, for Singapore/SEA users.
  Self-described categories do not meet the requirement. This is a technical feasibility gate:
  the documented EU data-export capability is not a Singapore distribution solution. No new
  app-identity/usage upload is implemented or authorized by this ADR amendment alone.
- Sleep summaries show last-night duration and week/month means with coverage and a detail path.
  Exact schedules/stages and raw Health samples are not automatically added to the first slice.
- A clear agreement at joining establishes one sharing contract. Sharing is active after explicit
  acceptance; there is no per-field toggle matrix while a member. Withdrawing sharing leaves the
  party, without deleting the local account/Farm or requiring the leader's approval. Creation must
  disclose the same contract to its leader. Existing members must accept an expanded contract
  before any newly included fields upload. Withdrawal must stop local sends even while offline;
  remote membership/access removal completes on reconnect and must not wait for host transfer. A leader needs a
  transfer or dissolve-and-leave route, not a consent trap.

- Adults may join without readable Health sleep data; show “No data available” without inferring
  refusal. Health and Screen Time connection actions belong where relevant, not only in Settings.
  Health request completion, observed sleep data and system permission are distinct states.
- Later joiners should see the group's previous shared history, including earlier contributions
  from former members. Ordinary leave stops new publication and access but should retain approved
  published history. It does not authorize private pre-join uploads or cross-party access.
  Existing contributors must accept the broader audience before their history is exposed to it.
  The founder selected archive duration for the lifetime of the party, subject to legitimate
  deletion requests. Lawful continued disclosure, withdrawal/deletion, party dissolution and
  account deletion still require review. A short joining disclosure is not irrevocable consent.

This agreement does not grant Apple permissions, authorize access-control workarounds, or prove
that missing sleep data means withholding. Privacy withdrawal/deletion remains distinct from
ordinary leave; pending sends and the leaver's group cache are removed without automatically
cascading into deletion of the permitted group archive. Explicit deletion requests still need
enforced handling and cannot be defeated by the retained-history preference.
No member data may upload before consent or beyond the reviewed permitted data route. Keep
local sessions, emergency exit and independent reward ledgers intact. Implementation sequencing:
`docs/plans/slumber-party-shared-habits-and-guide.md`; platform evidence and unsent Apple inquiry:
`docs/plans/slumber-party-singapore-app-data-feasibility.md`.

### Presentation and disclosure clarification — 2026-08-31

- Create and join disclose the baseline contract before the action: the Shepherd display name,
  curated Farm appearance, app-recorded Wind Down/Phone Away round activity, and rounded minutes
  are shared with the invite-only group. Exact times, private routine/purpose/reflection text,
  selected apps/categories, NFC/tag data, raw Screen Time/Health samples, full Farm inventory and
  wool remain private under the base contract. These records are self-reported by the member's
  iPhone to Slumber Party, not independently verified.
- The UI describes a party as one long-lived group organized by repeated seven-night rounds. It
  does not revive goals, readiness ceremonies, or “seven-night group” language.
- Shared Habits, plan comparison, social-avatar transport, sleep summaries, and archive history
  appear only when the exact capability and accepted agreement authorize the surface. An older
  server does not produce a broken, unavailable, or “coming later” advertisement.
- Account-recovery copy covers both valid branches: link the temporary anonymous account in place,
  or reopen an existing Apple-owned Counting Sheep account after temporary account-scoped social
  work is quarantined. Local Wind Down and Farm data remain untouched.
- Shepherd-name copy identifies its Slumber Party audience and the enforced limit of two successful
  changes in a rolling 14-day window after free initial/migration selection.
- Leave, host dissolve, explicit invite replacement, block, report-submitted, and request-accepted
  states name their actual local/server effect. Copy does not promise investigation, response time,
  removal, retention, or another moderation outcome that operations have not established.

## Founder decision — sharing from joining (2026-08-27)

Implementation clarification (2026-08-28): the shared-habits candidate removes the old client
scan that republished private local records when entering a round. Retaining past history now
means an explicit migration of the author's already group-shared coarse records under the
expanded agreement. It never means scanning private pre-join Health/session history. The
versioned archive is independent of the active membership stream and reward ledger. Its
implementation and release gates are in `plans/shared-habits-implementation-20260828.md`.

The founder explicitly approved member activity sharing immediately on joining, including before
and between rounds. Seven-night rounds organize progress and rewards; they no longer gate all
social activity. This supersedes round-only presentation/publication wording below for capable
new clients/backends. Earlier clients' current-round backfill remains compatibility behavior,
not authorization for the new archive to import private local history.

Use an additive membership stream with explicit server capability and old-server fallback.
A fresh membership epoch on rejoin fences activity, statuses and both cheer participants; general
observations/completions must occur in the current epoch. Private terminal watermarks prevent
stale live-status resurrection. General stream records use optional round association and never
mint round grants. Round storage/eligibility/idempotency remains independent and unchanged.

The added stream retains the same allowlisted factual fields, has a 90-day retention boundary
and a latest-100 recent-activity projection. No private Purpose/routines, exact schedules,
selected apps, Health or full Farm state is added. General pre-membership history is not
backfilled. This decision authorizes local implementation, not an unreviewed hosted deployment.
Contract, validation and rollout status: `docs/plans/slumber-party-membership-sharing.md`.

## Context

Counting Sheep is not a social network. A bounded, invite-only group can nevertheless help people
encourage one another around a phone-away habit. Earlier Slumber Party versions modeled a single
seven-night goal/challenge with readiness, sharing choices, aliases, and one global reward path.
The founder has replaced that model with one user-facing party: a long-lived group that can run
repeated fixed seven-night rounds. This ADR records the contract implemented by the local v4 source.

## Decision

### Founder clarification — core social surface, 2026-08-27

Slumber Party is intended to be a core reason friends, couples, and families use and return to
Counting Sheep. The earlier roadshow restriction to a subordinate, list-only Home bridge is
superseded. Idle Home may use the same member-visible party data as detail, with recognizable
people, factual shared activity, current statuses and clear feedback. No extra upload is needed
merely to expose already shared data on Home. See `docs/plans/home-social-recovery.md`.

The originally deployed v4 lifecycle gates activity on host-started seven-night rounds. The
subsequent founder decision above approves separating sharing from reward-round eligibility
through an explicit additive capability. Exact schedules, app selections, private purposes/routines, Health
data and full Farm state are not newly authorized for sharing. Existing local session authority,
account isolation, active-session boundaries and independent reward settlement remain in force.

Authentication recovery never creates an anonymous user. A 401 on a bound installation accepts
Apple ID-token reauthentication only when its Supabase UUID matches the locally bound account.
On an unbound installation, `linked_account_required` first tries to link Apple to the current
anonymous session without changing its UUID. If Apple reports that the identity already owns a
Counting Sheep account, a verified Apple sign-in may reopen that existing account on this phone.
Before admitting the different account UUID, the client quarantines account-scoped snapshots,
ritual-sharing contexts, and outboxes so temporary-anonymous work cannot be replayed as the Apple
account. Local Wind Down, Farm, and other non-social data remain untouched. Invalid local bindings,
non-Apple authenticated sessions, and mismatches against an existing binding still fail closed.

### Party, rounds, and membership

A Slumber Party is one long-lived invite-only group of 2–8 people, with a customizable name and
fixed seven-night rounds. There is no goal picker, pasture identity, readiness ceremony,
orientation wall, or per-field sharing matrix. The host starts a round when there are at least two
members. Joining never starts a round. Starting another round preserves the party's name and
members. A person can belong to at most five concurrent parties; the cap is enforced
transactionally.

The active invite remains redeemable while a round is active. Every current member may retrieve
and share it, but only the host can create, explicitly replace, or revoke it. An ordinary member
may leave. The host cannot leave and must delete the party for everyone; ownership transfer is
future work.
Deletion tombstones the party, revokes invites, deactivates membership, and preserves already
earned account-inbox grants. It also creates only the minimum moderation audit needed for the
configured retention period.

A member may join an active round. On joining, the member can backfill all app-recorded Wind Down and
Phone Away records from that round. Backfill is an idempotent self-report of local history, not a
claim of independent verification. All current members see the round's records and statuses.

### Canonical profile and party presentation

Each account has one canonical display name used in Farm and every Slumber Party. It is requested
before the first party is created or joined and remains editable from the Shepherd customization
screen. Initial setup and v4 migration selection are free. Afterwards the server permits at most
two successful display name changes in a rolling 14-day window. The curated public profile is
deliberately small: the
canonical name, Shepherd look, Ollie ornament, featured sheep definition, and pasture theme. It
updates routinely for all current parties. The server accepts only allowlisted catalogue
identifiers and revisions. This profile is visible only through parties and Farm; it creates no
directory, discovery, feed, chat, follower graph, leaderboard, rank, or competitive score.

Party detail is people-first: it shows current members, app-recorded/self-reported round records, curated snapshots,
and statuses with `revision`, `observed_at`, and `expires_at`. Fixed cheers are the only social
reaction and can encourage a member during an active Wind Down or Phone Away before its completed
record exists. Realtime may make membership, curated profiles, statuses, and cheers feel prompt
using a sanitized party revision signal, but clients reconcile every silent delivery from durable
state and ledger records; stale or absent realtime is never interpreted as activity or completion.

### Local authority, fan-out, and active-ritual boundary

The local iPhone remains authoritative for Wind Down and Phone Away. Local start, protection,
completion, reward settlement, and the fail-open emergency exit never wait for a party request or
response. An account-level local activity ledger first records app-recorded activity; a transactional
per-party fan-out then evaluates every eligible current party, up to the five-party cap, and
creates independent party records and rewards. Thus the same local activity can earn separately
in each eligible party without duplicate delivery inside a party. Grants are server-authoritative,
idempotent, and applied from an account inbox once per grant ID.

The 12 September founder direction permits opening and interacting with the shared pasture
during active Wind Down, including truthful peer-session cues. Earlier no-social-UI guards are
implementation to revise, not a veto on this direction. Deliberate pasture interaction does not
pause/end protection or change the local session. Best-effort silent Live Activity/Watch feedback
and durable cheer reconciliation remain; no new unsolicited interruption policy is selected.
Network or social failure cannot block the ritual or local completion.

### Privacy, invites, and version fence

The local v2 social-loop source is capability- and agreement-gated; hosted migration/deployment and
physical multi-account validation remain separate. It may share immutable rounded next-seven-night
plan instances, comparison bookends, bundled idea IDs, and factual receipts. Slumber Party never
uploads or exposes a full Farm, inventory, wool balance, a recurrence schedule, private routine/reflection
text, Family Controls tokens, app lists or per-app use, raw reports, NFC, purpose,
notification state, impact data, or raw Health data. It never joins or reuses `impact_nights`.
Apple-linked authentication, blocking, reporting, moderation, member-only RLS, and minimum
retention remain in force. A member can submit an existing fixed-reason safety report or block
another current member; blocking separates those accounts across their shared groups. The existing
in-app account deletion path remains available to a person with v4 memberships or history.

Invite ciphertext is encrypted, recoverable by service code only, and never appears in RLS
projections, Realtime payloads, logs, or support evidence. Digest and idempotency material are
equally excluded from logs. Host replacement is an explicit compare-and-swap operation; relaunch
reconciles and never replaces automatically.

Before deploying the v4 command function, provision the hosted Edge secret
`NIGHT_FLOCK_INVITE_KEY_V1` with exactly 32 cryptographically random bytes encoded as base64.
`NIGHT_FLOCK_INVITE_KEY_VERSION` defaults to `1`. Versioned rotation first provisions the new
`NIGHT_FLOCK_INVITE_KEY_Vn`, then changes the active version while retaining every earlier key
needed by an existing active invitation; retire an older key only after its invitations have
expired, been revoked, or been replaced. Key material never belongs in tracked files, logs,
diagnostics, screenshots, or support evidence. Missing or prematurely retired keys break
invitation creation or recovery and are a hard hosted-release blocker.

V4 is additive behind an unambiguous version fence. Old v1–v3 clients retain only explicitly
labeled legacy decode/state paths and must never receive an arbitrary v4 party. A client that
cannot prove a safe schema receives `unsupported_schema` or its own compatible legacy projection,
not a fallback to another party. Existing legacy fields such as `phoneTucked`,
`morningQuietCompleted`, goals, aliases, readiness, orientation, and sharing preferences are
compatibility data only, not v4 presentation or behavior.

### Workshop reward gate

This decision does not award sheep for a five-minute Wind Down test. Slumber Party Farm grants
are determined per eligible party round from the server-authoritative fan-out path. Workshop copy
must not promise grants for a practice run.

## Consequences

- The feature is a narrow ADR-0016 exception; ADR-0003 still gates Friends and broader social
  features.
- Apple Sign in, Family Controls distribution, the versioned hosted invitation-encryption secret,
  v4 migrations/functions, moderation ownership, retention scheduling, privacy disclosures, and
  two-account physical QA are release gates.
- Mixed-version rollout is v4-migration-first: historical migrations, existing invite recovery,
  the v4 fence and service-only recoverable-invite migration, provisioned versioned invitation
  encryption, and matching state/command functions. The founder explicitly approved production
  backend deployment on 2026-08-25; all five Slumber Party migrations, both JWT-protected
  functions, and invitation-key version 1 are now present. Updated app distribution, physical
  two-account validation, moderation/retention operations, and privacy publication remain open.
- The 2026-08-16 compile-flag decision remains: TestFlight/Release archives compile with
  `SUPABASE_NIGHT_FLOCK_ENABLED=YES`, ordinary Debug remains disabled, and
  `SlumberPartyQA` remains a local forced-`YES` diagnostics lane. The production backend
  deployment does not establish moderation readiness, privacy publication, updated app
  distribution, or physical QA completion.
- Existing `NightFlock*`, `night_flock_*`, `ollie.*`, and persisted enum identifiers remain
  implementation names for compatibility; only user-facing copy uses Counting Sheep language.
