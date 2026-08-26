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
docker exec -i supabase_db_counting-sheep psql -U postgres -d postgres \
  -v ON_ERROR_STOP=1 < supabase/tests/night_flock_v4_test.sql
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

The Slumber Party source contract is additive: v1–v3 migration/command shapes remain explicitly
fenced legacy compatibility, invite recovery is installed by
`20260824150000_night_flock_invite_recovery.sql`, and
`20260825110000_night_flock_parties_v4.sql` implements the current long-lived named party,
repeatable seven-night rounds, five-party membership, curated profiles, factual records/statuses,
fixed cheers, moderation, and account-safe deletion. Edge requests never carry Family Controls
tokens, selected-app lists, exact schedules, raw Health data, or full Farm inventory. Run both
Night Flock SQL tests after `db reset`. Production received all five Slumber Party migrations,
both JWT-protected functions, and versioned invitation secrets with explicit founder approval on
2026-08-25; updated app distribution and physical/operational release gates remain separate.

## Hosted development project

Authenticate and link interactively. Never place the access token or database password in
this repository, terminal transcripts shared publicly, or chat.

This repository is linked to the development project. Release/TestFlight uses the separate
production project. Never assume that an unqualified linked-project deployment updates the
production backend; an approved production command must specify its verified project reference.

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

Slumber Party additionally requires Supabase Auth's Apple provider and verified manual-linking
support; all five ordered Slumber Party migrations through
`20260825110000_night_flock_parties_v4.sql`; both authenticated functions; and
`NIGHT_FLOCK_INVITE_KEY_V1`, containing 32 random bytes encoded as base64.
`NIGHT_FLOCK_INVITE_KEY_VERSION` selects the active version. Rotate by provisioning the next
version before changing the selector and retain older keys until their invitations are retired.
Production schema/functions/secrets and the enabled Apple provider were verified on 2026-08-25;
actual device linking, approved v4 retention scheduling, moderation ownership, privacy updates,
and physical QA are still outstanding. Establish a moderation queue and document who can create
service-only moderation actions before broader rollout. Do not reuse impact or ActivityKit tables
as Slumber Party sources. The deployment sequence and rollback criteria are recorded in
`docs/SLUMBER_PARTY_DEPLOYMENT_RUNBOOK.md`.

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

Keep `SUPABASE_NIGHT_FLOCK_ENABLED = NO` in ordinary Debug/local files. TestFlight/Release
archives compile with `YES`. The tracked `Config/Supabase.slumber-party-qa.xcconfig` remains the
local forced-`YES` lane for the dedicated `PhoneInTheOtherRoomSlumberPartyQA` scheme after ignored
local development values load. Never replace an existing local xcconfig or paste hosted
credentials into a tracked example.
