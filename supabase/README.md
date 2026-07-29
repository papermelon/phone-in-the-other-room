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
npx deno check \
  supabase/functions/live-activity-registration/index.ts \
  supabase/functions/live-activity-cancellation/index.ts \
  supabase/functions/focus-run-sync/index.ts \
  supabase/functions/live-activity-dispatch/index.ts
```

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
```

Add `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY_P8`,
`APNS_LIVE_ACTIVITY_TOPIC`, `APNS_HOST`, `APNS_ENVIRONMENT`, and `DISPATCH_SECRET` through Supabase function secrets. The
platform supplies the Supabase URL and server keys. Do not add secret values to a local
tracked file.

For development, `APNS_HOST` is `https://api.sandbox.push.apple.com` and
`APNS_ENVIRONMENT` is `sandbox`.

## iOS development configuration

Create `Config/Supabase.local.xcconfig` only on the developer Mac. It is ignored by Git;
do not overwrite it if it already exists. Paste the Singapore development values there:

```xcconfig
SUPABASE_URL = https:/$()/gftqcxfbzngopwndvjyp.supabase.co
SUPABASE_PUBLISHABLE_KEY = sb_publishable_REPLACE_LOCALLY
SUPABASE_LIVE_ACTIVITY_PUSH_ENABLED = NO
```

Keep the feature disabled until migrations, functions, Cron, Sandbox APNs credentials,
and physical-device checks are ready. Only the publishable key belongs in this file.

Release and TestFlight builds read `Config/Supabase.release.local.xcconfig`, which is also
ignored. Populate it only with the separate production project URL and publishable key;
keep its feature flag `NO` until production migrations, functions, Cron, and production
APNs credentials have been verified. Development credentials must never ship in Release.
