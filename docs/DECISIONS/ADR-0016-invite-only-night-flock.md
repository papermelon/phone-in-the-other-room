# ADR-0016: Invite-Only Slumber Party

- Status: Accepted; implementation is disabled by default pending hosted and physical QA
- Date: 2026-08-12
- Decider: Founder
- Supersedes: ADR-0003's Friends/social restriction only for the narrow feature defined here
- Related: ADR-0005, ADR-0006, ADR-0010, ADR-0015

## Context

Counting Sheep deliberately competes with social apps and should not become one. A small,
time-bounded group can nevertheless make the phone-away ritual feel companionable without a
feed, comparison, failure display, or reason to keep looking at the phone. The founder approved
one production-data vertical slice and explicitly authorized the required app entitlement,
configuration, account-linking, schema, and Edge Function work.

The legacy mock Friends screens remain unsuitable: they use mock data, imply a general social
graph, and do not implement consent, privacy, blocking, moderation, deletion, or retention.

## Decision

### Product boundary

Slumber Party is an invite-only group of two to eight people sharing one seven-night challenge.
Each person can have one active membership, and each flock can have one pending or active
challenge. A flock uses one preset identity and server-generated aliases; there are no editable
names, free text, Contacts access, public discovery, friend graph, feed, chat, leaderboard, or
competitive rank.

The first member creates a pending flock. The challenge starts in its locked IANA timezone when
the second member joins. The MVP has one challenge and does not automatically begin another.

### Identity and consent

The existing anonymous Supabase session is linked to Sign in with Apple through the installed
`supabase-swift` ID-token linking API. Linking must preserve the Auth user UUID and every row it
owns. Creating, joining, reading, or mutating Slumber Party requires an Apple-linked account;
Counting Sheep's local ritual does not require an account.

Joining establishes challenge-level consent. Each member can disable positive sharing globally,
and every eligible primary Wind Down preflight offers **Keep tonight private**. That per-night
choice resets for the next preflight.

### Shared state and presentation

Only two positive, monotonic states exist for one member/challenge/day:

`none → phoneTucked → morningQuietCompleted`

`phoneTucked` is queued only after an eligible primary Wind Down is actually running and its
phone-away barrier is validated. `morningQuietCompleted` is queued only after successful primary
completion. Additional quiet, early endings, and private nights publish nothing. Exact bedtime,
wake time, duration, run identity, and early-end reason never enter the social request or peer
projection.

Home may show one compact aggregate before Wind Down. The hub is nested under Farm. Active Wind
Down has no Slumber Party panel, badge, reaction, notification, realtime subscription, or novelty.
Morning completion may show one finite result card and an anonymous shared pasture. System aliases
appear only in the roster; completion entries are unnamed. For flocks of two or three, aggregates
use qualitative wording whenever a count would identify an absence. No UI lists who did not share
or presents an explicit failure.

The seven-day result is a factual group Trail Note. Slumber Party never grants wool, sheep, a rarity
roll, Farm inventory, economic value, or individual rank and never changes the local reward or
search result.

### Data isolation and server boundary

Normalized Postgres tables cover profiles, flocks, memberships, invites, challenges, check-ins,
reactions, blocks, reports, and service-only moderation actions. Invite plaintext is returned once;
only its SHA-256 digest is stored. Invites expire after seven days.

Clients cannot write protected social tables or execute the service RPCs. Authenticated Edge
Functions derive the caller from the JWT, reject anonymous and non-Apple-linked accounts, validate
an exact versioned payload, and call service-role RPCs. Peer state omits Auth owner IDs, local run
IDs, exact timestamps, and private-night state. `impact_nights`, local/cloud run records, HealthKit,
Screen Time selections, NFC, purposes/cues, notifications, and all Farm/economy data are separate
data sources and permissions.

The app uses a local monotonic outbox and stable challenge/member/day/run-derived idempotency.
Network work never gates local start or completion. Safe foreground activation retries queued
positive state. With `SUPABASE_NIGHT_FLOCK_ENABLED=NO`, the feature is hidden and creates no
Slumber Party client, Auth session, or network request.

### Safety, deletion, and retention

Blocking creates mutual invisibility immediately and removes the blocker from the shared flock.
Reports accept fixed reason enums only. Moderation actions are service-only.

The app exposes deletion of Slumber Party data and deletion of the full online account. Local Wind
Down, Nights, Farm, and rewards remain on the device. Server retention is:

- invite validity: seven days; invite-row purge: 30 days;
- raw check-ins and reactions: 90 days;
- aggregate completed summaries: no more than 12 months unless deleted sooner.

## Consequences

- Slumber Party is a bounded companion ritual, not authorization for Friends or a general social
  platform. ADR-0003 continues to gate the legacy Friends screens and every broader social idea.
- Sign in with Apple capability and Supabase Apple provider setup become external release gates.
- Moderation operations, abuse handling, retention scheduling, and two-account physical QA are
  required before enabling production.
- Local Wind Down remains authoritative and fully usable through backend, account, or network
  failure.
- The user-facing name is **Slumber Party**. Existing `NightFlock*`, `night_flock_*`, function,
  migration, feature-flag, and storage identifiers remain stable implementation names; this rename
  does not rewrite persisted data or change the schema and privacy boundary.
