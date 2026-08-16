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

Members have server-generated or user-approved display names within the invite-only group. This
does not authorize a general identity directory or public profile system.

### Shared state and local authority

The v2 member projection can show: goal accepted, setup ready, phone tucked away, meaningful
partial progress, shared goal completed, morning quiet completed, and private/no update. The
last state is not successful completion. Coarse member-level progress is visible only to current
members; it is not a ranking. The local iPhone remains authoritative for Wind Down. During an
active ritual there is no Slumber Party UI, reaction, notification, realtime subscription, or
novelty. Social updates queue through the local outbox and publish asynchronously after the
appropriate local event. Network failure never blocks local start, completion, shielding, or the
fail-open emergency exit.

The v1 `phoneTucked` and `morningQuietCompleted` outbox records remain decodable and continue to
route through the v1 function. New commitment commands use an explicit schema version 2 rather
than silently changing the v1 contract. Ordinary Debug stays `NO`. TestFlight/Release archives
enable the feature.

### Screen Time and Instagram

Apple Family Controls selections are opaque tokens. Each member opens Apple's picker locally and
confirms that Instagram is included. The token and selected-app list remain local/App Group
scoped and never reach the backend. Counting Sheep may publish only coarse setup/shielding
evidence: not requested, unavailable, partial, or observed. The app must distinguish “You
confirmed Instagram is included” from “Counting Sheep observed app shielding”; the server never
claims it independently verified Instagram.

### Sharing boundaries

Slumber Party sharing and optional minimized impact/research sharing are separate controls and
records. Slumber Party never joins or silently reuses `impact_nights`. Sleep outcomes,
restfulness, HealthKit-derived values, exact schedules, exact shield timestamps, raw reports,
purpose text, private routines, Farm state, sheep, wool, and notification state remain outside
the social projection unless a future decision explicitly adds a separate control. The group
shares only the selected goal, member-level commitment state, coarse nightly status, fixed
reactions, and optional stable guidance IDs.

### Data and security

Normalized Postgres storage covers the commitment, bounded goal, lobby/start state, members,
acceptance/readiness, sharing preferences, optional guidance summaries, nightly progress,
coarse shielding evidence, reusable invite redemption, retention, blocks, reports, and
service-only moderation actions. RLS is member-only; service RPCs are called only by validated
Edge Functions. Functions derive the caller from the JWT, reject anonymous and non-Apple-linked
accounts, validate exact versioned payloads, and enforce idempotency and capacity. Tokens, raw
Screen Time reports, app lists, exact bedtime/wake timestamps, raw HealthKit samples, and exact
shield apply/clear timestamps are not stored in member-facing projections.

Retention remains bounded: invite validity is seven days with invite-row purge after 30 days,
raw nightly progress/reactions after 90 days, and completed commitment summaries after no more
than 12 months unless deleted sooner. Users can leave, block, report, delete Slumber Party data,
or delete the full online account while local Wind Down, Nights, Farm, and rewards remain.

### Workshop reward gate

This decision does not change `RewardEngine` and does not award sheep for a five-minute Wind Down
test. Before a workshop build promises a reward, the founder must choose one documented option:
an approved onboarding/starter gift, a dedicated workshop/demo mode using production models, or
wording that promises a smaller early reward rather than sheep.

## Consequences

- The feature is a narrow ADR-0016 exception; ADR-0003 still gates Friends and broader social
  features.
- Apple Sign in, Family Controls distribution, hosted migration/functions, moderation ownership,
  retention scheduling, privacy disclosures, and two-account physical QA are release gates.
- The older v1 schema and anonymous positive-state clients remain compatible during migration.
- On 2026-08-16 the founder authorized TestFlight/Release archives to compile with
  `SUPABASE_NIGHT_FLOCK_ENABLED=YES`. Ordinary Debug remains disabled. The dedicated
  `SlumberPartyQA` configuration stays the local forced-`YES` lane with QA diagnostics.
  Hosted deployment, moderation ownership, privacy publication, and two-account physical QA
  remain operational evidence, not a reason to keep the Release flag off.
- Existing `NightFlock*`, `night_flock_*`, `ollie.*`, and persisted enum identifiers remain
  implementation names for compatibility; only user-facing copy uses Counting Sheep language.
