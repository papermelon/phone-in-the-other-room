# ADR-0016: Invite-Only Slumber Party

- Status: Accepted; TestFlight/Release archives enable Slumber Party as of 2026-08-16
- Date: 2026-08-16
- Decider: Founder
- Supersedes: the positive-only presentation portion of the 2026-08-12 decision
- Related: ADR-0003, ADR-0005, ADR-0006, ADR-0010, ADR-0015

## Context

Counting Sheep is not a social network. A bounded, invite-only group can nevertheless help
people keep a phone-away habit visible and encouraging for one week. The founder therefore
revised the earlier anonymous aggregate experiment into a shared commitment that is clear to a
tired reader and usable in a workshop without developer explanation.

## Decision

Authentication recovery never creates an anonymous user. A 401 accepts Apple ID-token
reauthentication only when its Supabase UUID matches the locally bound account.
`linked_account_required` may link Apple only to a current anonymous session and must keep the
same UUID. Missing, changed, or unexpected identities fail closed without exposing another
account's snapshot; local snapshot, ritual contexts, and outboxes remain intact while state is
reconciled after validation.

Slumber Party lets **2–8 people choose one Wind Down goal, try routines that work for them, and
encourage one another for seven nights.** The group chooses one bounded goal from the catalogue:

- Put phones away during Wind Down;
- Reach an agreed number of quiet minutes; or
- Shield a named distracting app, such as Instagram, during Wind Down.

Members keep individual bedtimes and routines. They may optionally share up to three stable
guidance ideas from the bundled Counting Sheep source library. There is no unrestricted chat,
public discovery, feed, follower graph, global leaderboard, rank, or competitive score. Fixed
positive reactions remain available inside the invited group, and blocking, reporting,
moderation, deletion, retention, and Apple-linked account requirements remain in force.

### Lobby and identity

The host creates a lobby with one shared goal and a decorative flock identity. A lobby starts its
seven nights only when at least two members have joined, every current member has accepted the
goal, every member's required local setup is ready, and the host explicitly starts it. Joining
does not auto-start the challenge. A reusable, legible invite code works until it is revoked,
expires, the party starts, or capacity reaches eight. Preview and redemption require an
authenticated Apple-linked account; the server stores a secure digest and redemption metadata
where feasible, never the reusable plaintext after its intended response.

The host device journals that plaintext before transport in a non-synchronizing,
this-device-only Keychain item bound to the Apple-linked account and lobby. Only its digest is
sent or stored remotely. Host-only pending-lobby state exposes the active invite UUID and expiry
for lost-response and relaunch reconciliation. If the local credential is unavailable,
replacement requires explicit confirmation and an atomic compare-and-swap; relaunch never
replaces it automatically.

Members have server-generated or user-approved display names within the invite-only group. This
does not authorize a general identity directory or public profile system.

### Shared state and local authority

The v2 member projection can show: goal accepted, setup ready, phone tucked away, meaningful
partial progress, shared goal completed, morning quiet completed, and private/no update. Schema
three adds rounded Wind Down and Phone Away minutes plus optional sleep duration and
restfulness when those independent controls are on. The last status is not successful
completion. Member-level progress is visible only to current members; it is not a ranking. The
local iPhone remains authoritative for Wind Down. During an active ritual there is no Slumber
Party UI, reaction, notification, realtime subscription, or novelty. Social updates queue
through the local outbox and publish asynchronously after the appropriate local event. Network
failure never blocks local start, completion, shielding, or the fail-open emergency exit.

The v1 `phoneTucked` and `morningQuietCompleted` outbox records remain decodable and continue to
route through the v1 function. Schema-two commitment commands remain compatible. Schema-three
metrics and grant commands use an explicit version rather than silently changing older
contracts. Ordinary Debug stays `NO`. TestFlight/Release archives enable the feature.

### Screen Time and Instagram

Apple Family Controls selections are opaque tokens. Each member opens Apple's picker locally and
confirms that Instagram is included. The token and selected-app list remain local/App Group
scoped and never reach the backend. Counting Sheep may publish only coarse setup/shielding
evidence: not requested, unavailable, partial, or observed. The app must distinguish “You
confirmed Instagram is included” from “Counting Sheep observed app shielding”; the server never
claims it independently verified Instagram.

### Sharing boundaries

Slumber Party sharing and optional minimized impact/research sharing are separate controls and
records. Slumber Party never joins or silently reuses `impact_nights`. Exact schedules, exact
shield timestamps, raw reports, purpose text, private routines, private reflection text, Family
Controls tokens, app lists, NFC, and notification state remain outside the social projection.
Inside the invited group, independently controlled fields may include named aliases, shared-goal
progress, Wind Down completed or partly completed, rounded Wind Down and Phone Away minutes,
phone tucked away, coarse shielding evidence, optionally selected guidance IDs, optional sleep
duration, optional restfulness, and fixed reactions. Default-on fields follow clear join
consent; sleep duration and restfulness stay explicit opt-ins.

### Farm rewards

A qualifying shared night can grant 1 wool, once per member per challenge day. Three qualifying
nights grant an unowned cheap Farm item or 3 wool. Completing the seven-night party with at
least four qualifying nights grants one guaranteed Slumber Party sheep search that does not
consume Wind Down, Phone Away, or onboarding-practice guarantees. A group-wide completion bonus
of 2 wool requires two members to meet that four-night threshold. Opening the app, inviting,
joining, sending reactions, or changing settings never generates rewards. Grants are
server-authoritative and idempotent; the client applies each backend grant ID once.

### Data and security

Normalized Postgres storage covers the commitment, bounded goal, lobby/start state, members,
acceptance/readiness, sharing preferences, optional guidance summaries, nightly progress,
rounded shared minutes, optional sleep/restfulness, social reward grants, coarse shielding
evidence, reusable invite redemption, retention, blocks, reports, and service-only moderation
actions. RLS is member-only; service RPCs are called only by validated Edge Functions. Functions
derive the caller from the JWT, reject anonymous and non-Apple-linked accounts, validate exact
versioned payloads, and enforce idempotency and capacity. Tokens, raw Screen Time reports, app
lists, exact bedtime/wake timestamps, raw HealthKit samples, and exact shield apply/clear
timestamps are not stored in member-facing projections.

Retention remains bounded: invite validity is seven days with invite-row purge after 30 days,
raw nightly progress/reactions after 90 days, and completed commitment summaries after no more
than 12 months unless deleted sooner. Users can leave, block, report, delete Slumber Party data,
or delete the full online account while local Wind Down, Nights, Farm, and rewards remain.

### Workshop reward gate

This decision does not award sheep for a five-minute Wind Down test. Slumber Party Farm grants
follow the schema-three shared-night schedule only. Workshop copy must not promise those grants
for a practice run.

## Consequences

- The feature is a narrow ADR-0016 exception; ADR-0003 still gates Friends and broader social
  features.
- Apple Sign in, Family Controls distribution, hosted migration/functions, moderation ownership,
  retention scheduling, privacy disclosures, and two-account physical QA are release gates.
- The older v1 schema and anonymous positive-state clients remain compatible during migration.
- Mixed-version rollout is migration-first: historical migrations, the invite-recovery migration,
  matching state/command functions, hosted non-production legacy/new-client validation, physical
  two-account QA, then a new app/TestFlight build. Production remains human-gated after that order.
- On 2026-08-16 the founder authorized TestFlight/Release archives to compile with
  `SUPABASE_NIGHT_FLOCK_ENABLED=YES`. Ordinary Debug remains disabled. The dedicated
  `SlumberPartyQA` configuration stays the local forced-`YES` lane with QA diagnostics.
  Hosted deployment, moderation ownership, privacy publication, and two-account physical QA
  remain operational evidence, not a reason to keep the Release flag off.
- Existing `NightFlock*`, `night_flock_*`, `ollie.*`, and persisted enum identifiers remain
  implementation names for compatibility; only user-facing copy uses Counting Sheep language.
