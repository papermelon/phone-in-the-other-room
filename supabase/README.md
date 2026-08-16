# Counting Sheep Supabase backend

This folder is source-controlled backend infrastructure for the development Supabase
project. It contains no real credentials.

## Local validation

Prerequisites: Node 20+ and Docker Desktop running.

```bash
npx supabase start
npx supabase db reset
npx supabase db lint --local
docker exec -i supabase_db_counting-sheep psql -U postgres -d postgres \
  -v ON_ERROR_STOP=1 < supabase/tests/activitykit_delivery_test.sql
docker exec -i supabase_db_counting-sheep psql -U postgres -d postgres \
  -v ON_ERROR_STOP=1 < supabase/tests/impact_data_test.sql
docker exec -i supabase_db_counting-sheep psql -U postgres -d postgres \
  -v ON_ERROR_STOP=1 < supabase/tests/app_feedback_test.sql
docker exec -i supabase_db_counting-sheep psql -U postgres -d postgres \
  -v ON_ERROR_STOP=1 < supabase/tests/night_flock_test.sql
npx deno check \
  supabase/functions/live-activity-registration/index.ts \
  supabase/functions/live-activity-cancellation/index.ts \
  supabase/functions/focus-run-sync/index.ts \
  supabase/functions/live-activity-dispatch/index.ts \
  supabase/functions/submit-feedback/index.ts \
  supabase/functions/feedback-email-delivery/index.ts \
  supabase/functions/night-flock-command/index.ts \
  supabase/functions/night-flock-state/index.ts
npx deno test --allow-env \
  supabase/functions/_shared/apns_test.ts \
  supabase/functions/_shared/feedback_test.ts \
  supabase/functions/_shared/night-flock_test.ts
```

The Slumber Party source contract is additive: the original migration and schema-one commands
remain compatible, while `20260816100000_night_flock_shared_commitment_v2.sql` adds the bounded
shared-goal lobby, member setup/sharing, reusable invite redemption, nightly progress, and coarse
shielding evidence tables/RPCs. Schema-two requests are validated in the Edge Functions and never
carry Family Controls tokens, selected-app lists, exact schedules, or raw Health data. Run the
Night Flock SQL test after `db reset`; it covers the explicit host-start gate and member-only
projection. Do not deploy this migration or the functions without the ADR-0016 release gates.

## Hosted development project

Authenticate and link interactively. Never place the access token or database password in
this repository, terminal transcripts shared publicly, or chat.

```bash
npx supabase login
npx supabase link --project-ref gftqcxfbzngopwndvjyp
npx supabase db push --dry-run
```

After review, apply the migration and deploy:

```bash
npx supabase db push
npx supabase functions deploy live-activity-registration
npx supabase functions deploy live-activity-cancellation
npx supabase functions deploy focus-run-sync
npx supabase functions deploy live-activity-dispatch --no-verify-jwt
npx supabase functions deploy submit-feedback
npx supabase functions deploy feedback-email-delivery --no-verify-jwt
# Deploy Slumber Party only after every ADR-0016 release gate is approved:
npx supabase functions deploy night-flock-command
npx supabase functions deploy night-flock-state
```

Apply `20260730100000_fix_live_activity_rpc_overload.sql` and deploy the updated
`live-activity-registration` function in the same maintenance window. The original
ten-argument `register_live_activity` remains available to older clients. A no-default
sixteen-argument compatibility wrapper keeps the currently deployed Edge Function working
during rollout; updated schema-version-2 registrations use `register_live_activity_v2`.

Add `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY_P8`,
`APNS_LIVE_ACTIVITY_TOPIC`, `APNS_HOST`, `APNS_ENVIRONMENT`, and `DISPATCH_SECRET` through Supabase function secrets. The
platform supplies the Supabase URL and server keys. Do not add secret values to a local
tracked file.

Feedback additionally requires `RESEND_API_KEY`, `FEEDBACK_FROM_EMAIL`,
`FEEDBACK_TO_EMAIL`, and a high-entropy `FEEDBACK_DELIVERY_SECRET`. Keep the recipient and
verified sender in secrets, not source. Configure Supabase Cron to POST
`feedback-email-delivery` every ten minutes with the same secret in the
`x-feedback-delivery-secret` header. The function retries pending notification rows once per
run, stops after five attempts, and removes feedback rows/private attachments after 180
days. The support mailbox owner must follow the matching 180-day deletion process.

Slumber Party additionally requires Supabase Auth's Apple provider, manual-linking support,
deployment of `20260812120000_night_flock_mvp.sql` followed by
`20260816100000_night_flock_shared_commitment_v2.sql`, both authenticated functions, and a daily
service-role schedule for `purge_night_flock_retention(now())`. Establish a moderation queue and
document who can create service-only moderation actions before enabling the client. Do not reuse
the impact or ActivityKit tables as Slumber Party sources. The deployment sequence and rollback
criteria are recorded in `docs/SLUMBER_PARTY_DEPLOYMENT_RUNBOOK.md`.

For development, `APNS_HOST` is `https://api.sandbox.push.apple.com` and
`APNS_ENVIRONMENT` is `sandbox`.

## iOS development configuration

Create `Config/Supabase.local.xcconfig` only on the developer Mac. It is ignored by Git;
do not overwrite it if it already exists. Paste the Singapore development values there:

```xcconfig
SUPABASE_URL = https:/$()/gftqcxfbzngopwndvjyp.supabase.co
SUPABASE_PUBLISHABLE_KEY = sb_publishable_REPLACE_LOCALLY
SUPABASE_LIVE_ACTIVITY_PUSH_ENABLED = NO
SUPABASE_FEEDBACK_ENABLED = NO
SUPABASE_NIGHT_FLOCK_ENABLED = NO
```

Keep the feature disabled until migrations, functions, Cron, Sandbox APNs credentials,
and physical-device checks are ready. Only the publishable key belongs in this file.

Release and TestFlight builds read `Config/Supabase.release.local.xcconfig`, which is also
ignored. The feedback route remains disabled with `SUPABASE_FEEDBACK_ENABLED = NO` until the
explicit launch approval. Development credentials must never ship in Release. The
production schema and functions are deployed, but Resend credentials/domain, Cron retry,
privacy publication, mailbox retention, and physical-iPhone upload/accessibility checks
remain external launch gates; until those pass, notification rows remain retryable and the
iOS form offers its recoverable prefilled-email fallback after a backend failure.

Keep `SUPABASE_NIGHT_FLOCK_ENABLED = NO` in every local and Release file until the hosted
migration, functions, retention schedule, Apple provider, privacy publication, moderation runbook,
and physical two-account create/join/share/private/block/report/delete matrix all pass. The tracked
`Config/Supabase.slumber-party-qa.xcconfig` is the sole non-production exception: it enables the
dedicated `PhoneInTheOtherRoomSlumberPartyQA` scheme after the ignored local development values are
loaded. It does not authorize deployment or a production enablement. Never replace an existing
local xcconfig or paste hosted credentials into a tracked example.
