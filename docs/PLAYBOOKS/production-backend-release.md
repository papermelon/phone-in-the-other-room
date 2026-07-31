# Production Backend Release — App Store 1.0

Use this playbook for the two pending 2026-07-30 migrations and the matching
`live-activity-registration` Edge Function. It changes the production Supabase project and
requires explicit human approval.

## Scope

- Add the separately consented `impact_nights` table, RLS policies, and deletion RPC.
- Remove the ambiguous default-argument Live Activity registration overload.
- Preserve both the original ten-argument registration API and the currently deployed
  sixteen-argument API during rollout.
- Deploy the updated Edge Function to use the explicit `register_live_activity_v2` name.

Do not deploy unrelated functions, change secrets, enable new Cron jobs, or modify stored
rows as part of this release.

## Preflight

From the repository root:

```bash
npx supabase migration list --linked
npx supabase db push --dry-run --linked
npx supabase db lint --linked --level warning
npx deno check \
  supabase/functions/live-activity-registration/index.ts \
  supabase/functions/live-activity-cancellation/index.ts \
  supabase/functions/focus-run-sync/index.ts \
  supabase/functions/live-activity-dispatch/index.ts
```

Expected before deployment:

- remote migrations end at `20260727010000`;
- dry run lists exactly `20260730090000` and `20260730100000`;
- lint reports the existing `register_live_activity` ambiguity and no unrelated new error;
- all four Edge Functions type-check.

## Deploy

Apply migrations first. The compatibility wrapper keeps the already-deployed registration
function working, so there is no required outage window.

```bash
npx supabase db push --linked
npx supabase functions deploy live-activity-registration
```

Do not deploy from a directory or branch whose pending migration list differs from the
preflight evidence.

## Immediate verification

```bash
npx supabase migration list --linked
npx supabase db push --dry-run --linked
npx supabase db lint --linked --level warning
```

Required result:

- local and remote migration versions match through `20260730100000`;
- dry run reports no pending migrations;
- the registration-overload lint error is gone.

In the Supabase dashboard:

1. Confirm `impact_nights` exists and RLS is enabled.
2. Confirm `live-activity-registration` has a new deployment time.
3. Confirm the minute Cron worker remains active and successful.
4. Do not inspect or copy raw push tokens.

## Device verification

With a separately approved physical-device install:

1. Start an honor-timer Quiet Time with Live Activity enabled.
2. Confirm one successful registration invocation and no 4xx/5xx response.
3. Confirm bedtime and wake phase events are scheduled once per activity generation.
4. End early and confirm cancellation remains idempotent.
5. Enable optional impact sharing through its consent prompt.
6. Confirm one row for the anonymous owner, with relative night and minimised fields only.
7. Use “Delete shared data”; confirm the row is removed while local Nights history remains.

Never use real personal reflection text, selected-app tokens, NFC payloads, or raw Health
samples as dashboard test fixtures.

## Failure handling

- **Migration fails before commit:** stop. Supabase migrations are transactional; inspect
  the reported statement and do not mark the version as applied manually.
- **Edge Function deployment fails:** the sixteen-argument compatibility wrapper allows the
  previous deployed function to continue. Fix/type-check and retry only the registration
  function.
- **Post-deploy lint still reports ambiguity:** do not upload the app. Verify the v2 rename
  and that the sixteen-argument compatibility wrapper has no default arguments.
- **Impact insert/delete fails:** leave optional impact sharing out of the App Store build
  until RLS and deletion pass. Local outcome comparisons do not depend on the backend.
- **Live Activity registration fails:** disable
  `SUPABASE_LIVE_ACTIVITY_PUSH_ENABLED` in the Release configuration and rebuild rather
  than treating remote delivery as authoritative.
