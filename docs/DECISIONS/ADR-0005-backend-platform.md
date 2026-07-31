# ADR-0005: Supabase as the product backend

- **Status:** Accepted; Singapore development schema/functions deployed, physical delivery validation pending
- **Date:** 2026-07-12
- **Decision owner:** Product owner

## Context

Counting Sheep needs a small backend now to end ActivityKit Live Activities when iOS is
not running. The same backend may later own accounts, cross-device sync, focus history,
progression, collectibles, subscriptions, configuration, ordinary notifications, and
carefully gated social features. The current app is offline-first and stores Codable JSON
in UserDefaults. It has no networking, account, server analytics, or cloud persistence
layer.

App Store 1.0 also needs an ethically bounded way to answer whether the ritual changes
completed quiet time and whether those behavioural changes are associated with measured
sleep outcomes. Detailed history remains local; this is not authorization for wholesale
cloud sync.

## Decision

Use **hosted Supabase** as the primary backend for the next three to five years:

- Postgres is the source of truth for cloud identities, focus runs, schedules, progress,
  social relationships, moderation state, and entitlements.
- Supabase Auth introduces anonymous/device-scoped identities first, then Sign in with
  Apple and other clients without changing ownership keys.
- Edge Functions expose narrow authenticated commands and deliver APNs requests.
- Postgres stores a durable outbox of scheduled ActivityKit events. Supabase Cron invokes
  a worker frequently; the worker atomically claims due rows with `FOR UPDATE SKIP LOCKED`.
- Realtime is used only where a product surface needs it, not for timers.
- Storage holds user-generated media if sharing is later approved.

The accepted trade-off is Supabase's roughly US$25/month production baseline and a
polling scheduler rather than a native per-job durable timer. That cost buys one provider,
standard Postgres, Auth, row-level security, Storage, Realtime, backups, logs, and official
Swift support. It removes more solo-developer operational work than it adds.

## Why not the alternatives

### Convex

Convex has the best integrated scheduled-function and realtime development experience,
and it now has a Swift client. It remains a weaker fit because its custom document
database, function API, and auth integrations are more opinionated than SQL/Postgres.
Counting Sheep's likely relationships—users, runs, inventories, grants, subscriptions,
friend edges, moderation, and deletion/audit jobs—benefit from constraints, transactions,
SQL reporting, and portable migrations. Moving away later would require rewriting both
data access and reactive queries.

### Cloudflare-native (Workers + D1 + Workflows/Durable Objects + Queues + R2)

Cloudflare is the least expensive and its Workflows or Durable Object alarms are excellent
for one-off scheduling. It is not the lowest-burden complete product backend: authentication,
authorization, relational policy enforcement, migrations, point-in-time recovery, realtime
fan-out, and account deletion would span several products and more custom code. D1's
per-database limits also make long-term history/social modelling more operationally involved.
If Cloudflare were selected, D1—not Neon—would be the initial primary database to preserve
the single-provider benefit; Neon would be introduced only after measured D1 constraints.

### Cloudflare Workers + Neon Postgres

Neon supplies standard Postgres and good scale-to-zero economics, but this combination
splits auth/data and edge execution across providers while still requiring custom realtime,
object storage integration, scheduling orchestration, and authorization. It recreates much
of Supabase with more integration and incident surface. Standard Postgres is valuable, but
not enough here to justify the second provider.

## ActivityKit delivery design

The backend is advisory for presentation, not authoritative for reward completion. The
iPhone remains authoritative and reconciles completion on app reopen. A local notification
remains scheduled for every run.

1. The iPhone requests the Live Activity with `pushType: .token`.
2. Every value from `pushTokenUpdates` is upserted with the run ID, ActivityKit activity
   ID, planned end, APNs environment, and an authenticated owner/device identity.
3. Postgres transactionally supersedes the old token and upserts one pending `end` outbox
   row keyed by `(activity_id, event_kind)`.
4. A frequent Cron worker claims due outbox rows, creates an ES256 APNs provider JWT, and
   posts an ActivityKit `event: end` payload.
5. APNs success or a permanent invalid-token response marks the job terminal. Transient
   failures retry with bounded exponential backoff and jitter.
6. An early end, reset, changed end time, token rotation, or replacement activity updates
   or cancels the same idempotency key. Duplicate workers cannot send a logically different
   result because the claimed row includes a generation number.
7. Expired tokens, completed jobs, and request logs are removed on retention schedules.

APNs delivery is not guaranteed. A push-end improves stale presentation; it does not grant
rewards or replace local notification and app-reopen reconciliation.

## Stable initial domain

- `users`: Supabase Auth identity and deletion state.
- `devices`: installation ID, owner, platform, app version, APNs environment, last seen.
- `focus_runs`: client-generated UUID, owner/device, planned times, status, guard kind,
  timestamps, and monotonic `revision`.
- `live_activities`: ActivityKit activity ID, run ID, current encrypted-at-rest push token,
  environment, observed/invalidated timestamps, and token generation.
- `scheduled_events`: run/activity, kind, due time, status, attempt count, next attempt,
  generation, lease, APNs response code/reason, and unique idempotency key.
- `delivery_attempts`: short-retention operational records without raw tokens or payload secrets.
- `impact_nights`: separately consented, date-free nightly measures (quiet completion,
  shield evidence, sleep duration/stages where present, and categorical restfulness).
  RLS ties rows to the anonymous account; the user can delete every row through
  `delete_my_impact_data`.
- `app_feedback`: launch-gated support reports accepted through an authenticated Edge
  Function, with private Storage attachments and no client table reads. Resend delivery,
  retry, rate-limit, and retention boundaries are defined by ADR-0007.

Progression, inventory, friendships, subscriptions, and moderation get separate normalized
tables when their gated product milestones are approved. Do not encode them into a generic
JSON profile now.

## Consequences

- Local UserDefaults remains the app's source during the first backend increment; cloud
  migration is additive and separately reviewed.
- The first client endpoint can accept an anonymous Supabase JWT plus an installation ID.
  It must never trust a client-supplied owner ID.
- Raw ActivityKit tokens are treated as credentials: encrypted or tightly protected in the
  database, excluded from logs, and deleted after terminal retention.
- The official Swift package, schema, and disabled-by-default development transport may be
  versioned now that the Singapore development project and anonymous-auth direction are approved.
  Hosted migrations, functions, secrets, and Cron remain explicit deployment steps.
- Optional impact sharing is purpose-limited and off by default. Exact dates/times, raw
  HealthKit samples, Health source names, app selections, NFC identities, and free text do
  not enter `impact_nights`. See `docs/PRIVACY_DATA_MAP.md`.
- Optional feedback is independently disabled by default. It may use Supabase and Resend
  only after ADR-0007's privacy, delivery, retry, retention, and physical-device gates pass;
  email fallback remains available without enabling the backend.
