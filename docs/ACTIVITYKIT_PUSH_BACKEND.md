# ActivityKit push backend contract

This document is the implementation contract for ADR-0005. The migrations and Edge
Functions are deployed. Following founder authorization on 12 September 2026, the Debug
and Release app configurations enable the existing remote sink for opted-in Live Activities. The active hosted development project is `counting-sheep-dev` in
Singapore. Its reference may be used for CLI linking, but no access token, database
password, secret API key, or APNs credential belongs in this repository.

## Client commands

All commands require `Authorization: Bearer <Supabase access token>`, an idempotency key,
and JSON dates in ISO-8601 UTC. The server derives the user from the JWT.

### Sync a run without requiring ActivityKit

`POST /functions/v1/focus-run-sync` records the installation and Night Watch independently
of Live Activity availability. This is the first authenticated request, so it also restores
or creates the anonymous Supabase identity. ActivityKit failure must not suppress run history.

### Upsert a token and schedule

`POST /functions/v1/live-activity-registration`

```json
{
  "schemaVersion": 2,
  "runID": "UUID",
  "activityID": "ActivityKit activity ID",
  "pushToken": "lowercase hex",
  "plannedEndAt": "2026-07-12T14:00:00Z",
  "observedAt": "2026-07-12T13:35:00Z",
  "environment": "sandbox | production",
  "installationID": "UUID",
  "runRevision": 1,
  "tokenGeneration": 1,
  "idempotencyKey": "stable command identity",
  "phase": "windDown",
  "bedtimeAt": "2026-07-12T15:00:00Z",
  "wakeAt": "2026-07-13T23:00:00Z",
  "morningQuietEndsAt": "2026-07-13T23:30:00Z",
  "eveningActivityTitle": "Read",
  "morningActivityTitle": "Open curtains"
}
```

The transaction must:

1. verify the run belongs to the authenticated user/device;
2. reject an implausible past/far-future end date;
3. upsert the activity and rotate its token generation;
4. cancel any older pending generation;
5. upsert pending bedtime, wake, and end events keyed by `activityID:eventKind`;
6. return the accepted generation and due time.

Repeated identical requests return the existing generation. A changed token or end time
increments it.

### Cancel or complete

`POST /functions/v1/live-activity-cancellation`

```json
{
  "schemaVersion": 2,
  "runID": "UUID",
  "activityID": "ActivityKit activity ID",
  "reason": "completed | endedEarly | reset | replaced",
  "occurredAt": "2026-07-12T13:50:00Z",
  "installationID": "UUID",
  "runRevision": 1,
  "idempotencyKey": "stable command identity"
}
```

The transaction marks pending events cancelled and invalidates the token. It is idempotent
when an event already ran, was cancelled, or never existed.

## APNs worker

- Cron invokes the worker every 15 seconds if the platform plan supports that safely;
  otherwise every minute. Phase precision of one minute is acceptable because the
  system timer continues counting inside each Live Activity phase.
- Claim rows in a short transaction using `FOR UPDATE SKIP LOCKED`, a lease expiry, and a
  maximum batch size.
- Dispatch is environment-locked. Development uses `APNS_ENVIRONMENT=sandbox` and
  `APNS_HOST=https://api.sandbox.push.apple.com`; a mismatched claimed row is rejected.
- Use `apns-push-type: liveactivity`, `apns-topic:
  com.ngawangchime.countingsheep.push-type.liveactivity`, and priority 10.
- Phase payloads include `aps.timestamp`, `aps.event = "update"`, and the full
  `content-state` needed to switch the Live Activity from Wind Down to the overnight interval
  and then Screen-Free Morning. The normal terminal payload uses `aps.event = "end"`, the full
  ActivityKit-compatible terminal `content-state`, and a dismissal date roughly 15 minutes
  in the future. An early end is a factual non-completion state; reset and replacement
  cancellation cancels the scheduled row and does not send completion copy.
- `staleDate` changes `ActivityViewContext.isStale`; it does not deliver a new content state,
  end an activity, or dismiss it. The local presentation now sets freshness to its next
  clock boundary and explicitly depends on `isStale`. At bedtime it can redraw the already
  saved schedule as an overnight countdown without foregrounding the app. The saved phase
  never overrides known date anchors during rendering. This display projection neither
  settles the run nor proves protection or sleep.
- A freshness change is a single invalidation, not a repeating WidgetKit timeline. Subsequent
  background state delivery and terminal dismissal still require the existing optional
  `pushType: .token` path: remote sink, deployed Edge Functions, APNs credentials, and a healthy
  scheduler. Debug and Release configurations now enable that flag. An app update resets
  freshness to the next boundary; without an update, a second precise boundary is not promised.
  Local completion remains authoritative. Physical-device acceptance of the first bedtime
  redraw remains required; see `docs/plans/live-activity-and-app-copy-2026-09-07.md`.
- On the iPhone, successful completion ends immediately while the app is active. A
  background completion can retain final content for roughly 15 minutes; returning to the
  app dismisses completed/orphaned surfaces, including retained local completion handles.
  Early endings, reset and replacement dismiss immediately. Active linked Morning timers
  retain their surface after the parent Wind Down has ended.
- Treat 2xx as delivered; 400 invalid/expired token responses as terminal; 429 and 5xx as
  retryable. Retry with jittered exponential backoff, capped before token/run retention.
- Check the row generation immediately before send. A stale generation exits without APNs.
- Never log the raw token, APNs JWT, private key, authorization header, or full request body.

## Suggested Supabase layout

```text
supabase/
  migrations/
    <timestamp>_activitykit_delivery.sql
  functions/
    _shared/apns.ts
    _shared/auth.ts
    live-activity-registration/index.ts
    live-activity-cancellation/index.ts
    live-activity-dispatch/index.ts
  tests/
    activitykit_delivery.sql
    apns_payload_test.ts
```

The development project is approved and this structure now exists locally. RLS protects
the only client-readable table; token and delivery tables have no client policies. The
dispatch function uses the service role only inside the server runtime.

## Development project activation

Hosted status rechecked 12 September 2026: release project `sxjlkcccsentmhowgoqe`
has all four active Edge Functions, the Live Activity tables, the required secret names,
and an active once-per-minute `live-activity-dispatch` Cron. Three recent Cron runs
succeeded and their HTTP responses were 200 with zero due events. Secret digests confirm
production APNs environment/host. Development project `gftqcxfbzngopwndvjyp` also has an
active once-per-minute scheduler and the expected sandbox APNs environment/host and
credential names. No secret values were printed, no customer records changed, and no
server deployment or scheduler mutation was needed. Credential presence and idle-worker
success do not prove APNs delivery to a device.

The remaining acceptance checks are a new signed physical-device build, background phase
and completion delivery, app-reopen dismissal, retry/token rotation, and offline/relaunch
fallbacks. Independent or rescheduled Morning-only activities still use their local path;
the existing remote schedule covers the original Wind Down plan.

1. Start Docker Desktop, then run `npx supabase start` and
   `npx supabase db reset` to validate the migration locally.
2. In the hosted development dashboard, enable Auth → Anonymous Sign-Ins. Do not confuse
   an anonymous authenticated user with the public publishable key.
3. Authenticate the CLI with `npx supabase login`, then link with
   `npx supabase link --project-ref gftqcxfbzngopwndvjyp`. Do not paste an access token or
   database password into chat or source.
4. Preview with `npx supabase db push --dry-run`; deploy only after the local reset passes.
5. Deploy the four functions. Run sync, registration, and cancellation require user JWTs; dispatch
   uses its own `DISPATCH_SECRET` and has platform JWT verification disabled.
6. Add APNs and dispatch secrets directly to the development project's function secrets.
7. Add a once-per-minute Cron invocation only after the dispatch function and database
   tests pass.

## Secrets

Expected Supabase Edge Function secrets:

- `APNS_KEY_ID`
- `APNS_TEAM_ID`
- `APNS_PRIVATE_KEY_P8`
- `APNS_LIVE_ACTIVITY_TOPIC` =
  `com.ngawangchime.countingsheep.push-type.liveactivity`
- `APNS_HOST` = `https://api.sandbox.push.apple.com` in development
- `APNS_ENVIRONMENT` = `sandbox` in development
- `DISPATCH_SECRET`

Supabase provides its own project URL/service-role environment to deployed functions. Do
not invent a repository `.env` containing production values. Add secrets directly with the
Supabase dashboard secret manager or authenticated CLI input on the developer machine.

## Retention and deletion

- Delete or irreversibly redact raw push tokens shortly after a terminal run (target: 7 days).
- Keep delivery attempt metadata for 30 days, excluding secrets.
- Delete stale unclaimed device/activity registrations after 30 days.
- Account deletion immediately cancels pending events, deletes tokens, then deletes or
  anonymizes product data according to the published policy.
- Backups containing deleted data expire through the documented backup-retention window.

## Rollout and rollback

1. Create separate Supabase development and production projects.
2. Apply migrations and automated database/function tests to development.
3. Add sandbox APNs secrets and exercise a Debug physical-device build.
4. Add the concrete iOS sink behind a remotely removable feature flag.
5. Confirm token rotation, reschedule, cancellation, duplicate dispatch, APNs 410, 429/5xx,
   app force-quit, network loss, and local fallback cases.
6. Configure production APNs secrets, deploy production, then ship to internal TestFlight.
7. Monitor registration, due-lag, success, retry, permanent failure, and stale-lease metrics.
8. Roll back by disabling client registration and the Cron worker. Local notification and
   app-reopen completion continue unchanged; pending rows can be cancelled in one SQL update.
