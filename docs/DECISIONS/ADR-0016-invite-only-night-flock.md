# ADR-0016: Invite-Only Slumber Party

- Status: Accepted; v4 production backend deployed 2026-08-25; app/device/operations gates pending
- Date: 2026-08-25
- Decider: Founder
- Supersedes: v1–v3 Slumber Party product contract; those schemas remain legacy compatibility only
- Related: ADR-0003, ADR-0005, ADR-0006, ADR-0010, ADR-0015

## Context

Counting Sheep is not a social network. A bounded, invite-only group can nevertheless help people
encourage one another around a phone-away habit. Earlier Slumber Party versions modeled a single
seven-night goal/challenge with readiness, sharing choices, aliases, and one global reward path.
The founder has replaced that model with one user-facing party: a long-lived group that can run
repeated fixed seven-night rounds. This ADR records the contract implemented by the local v4 source.

## Decision

Authentication recovery never creates an anonymous user. A 401 accepts Apple ID-token
reauthentication only when its Supabase UUID matches the locally bound account.
`linked_account_required` may link Apple only to a current anonymous session and must keep the
same UUID. Missing, changed, or unexpected identities fail closed without exposing another
account's snapshot; local snapshot, ritual contexts, and outboxes remain intact while state is
reconciled after validation.

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

A member may join an active round. On joining, the member can backfill all factual Wind Down and
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

Party detail is people-first: it shows current members, factual round records, curated snapshots,
and statuses with `revision`, `observed_at`, and `expires_at`. Fixed cheers are the only social
reaction and can encourage a member during an active Wind Down or Phone Away before its completed
record exists. Realtime may make membership, curated profiles, statuses, and cheers feel prompt
using a sanitized party revision signal, but clients reconcile every silent delivery from durable
state and ledger records; stale or absent realtime is never interpreted as activity or completion.

### Local authority, fan-out, and active-ritual boundary

The local iPhone remains authoritative for Wind Down and Phone Away. Local start, protection,
completion, reward settlement, and the fail-open emergency exit never wait for a party request or
response. An account-level local activity ledger first records factual activity; a transactional
per-party fan-out then evaluates every eligible current party, up to the five-party cap, and
creates independent party records and rewards. Thus the same local activity can earn separately
in each eligible party without duplicate delivery inside a party. Grants are server-authoritative,
idempotent, and applied from an account inbox once per grant ID.

During an active Wind Down there is no Slumber Party UI, feed, panel, badge, in-app reaction, or
social navigation. Best-effort silent Live Activity and Watch feedback may appear on a system
surface immediately, with accumulated completion cheers reconciled later from the durable ledger.
It is never an in-app ritual interruption or a dependency of local completion. Network or social
failure fails quietly and cannot block the ritual.

### Privacy, invites, and version fence

Slumber Party never uploads or exposes a full Farm, inventory, wool balance, exact schedules,
private routine/reflection text, Family Controls tokens, app lists, raw reports, NFC, purpose,
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
