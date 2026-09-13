# Production campfire and shared-pasture deployment — 13 September 2026

Founder authorization: “Ok deploy backend migrations and edge functions.” Target verified from
Release configuration and the live project list as `counting-sheep-prod`,
`sxjlkcccsentmhowgoqe`, Singapore, ACTIVE_HEALTHY. The checkout remains linked to development;
every hosted CLI command explicitly targeted production. Source commit: `98cec98`.

## Applied scope

- `20260912120000_shared_pasture.sql`: owned-sheep visits, persisted party placements and the
  12-contribution lantern. Its contribution policy starts at this migration's activation.
- `20260913120000_campfire_sessions.sql`: separate version 1 opt-in, bounded app-reported
  presence, receipt/epoch checks, terminal precedence and expiry projection.
- `night-flock-command` and `night-flock-state`: version **5**, ACTIVE, `verify_jwt=true`.

Both exact migrations and their history rows were committed in one transaction, with five-second
lock and sixty-second statement timeouts, followed by schema reload. SHA-256 values read from
hosted migration history match [the repository sources](source-sha256.json).
No blanket migration push was used. `20260830090000_night_flock_shared_night_plans.sql` remains
withheld, as do its agreement-v2 and shared-night Edge capabilities. Development, secrets, Auth
settings, Cron jobs, app flags, archives and distribution were not changed.

The Edge bundle starts from downloaded production version 4 and adds only the five pasture/campfire
command allowlists and validation branches, the two actionable owned-sheep errors, and their
safe command logging. Existing activity-date compatibility and all other deployed behavior remain.
The [exact patch](production-edge.patch) and [source hashes](edge-source-sha256.json) identify it;
this is intentionally a subset of repository Edge source. Both deployed functions were downloaded
and matched that tested bundle byte-for-byte.

The first Edge attempt stopped during local config parsing because the isolated workspace lacked
a referenced email template. Copying the existing template directory allowed the retry to deploy;
no template, Auth setting or production function was changed by that failed attempt.

## Verification

- Before applying: both migrations plus the complete pasture/campfire SQL fixture suites passed
  against hosted schema in a rolled-back transaction. [Rehearsal](dry-run.json).
- After applying: both suites passed again in a rolled-back transaction. Fixtures use randomized
  UUIDs and verified-email test identities; no Auth bypass or real account data was used.
  [Post-deployment suites](post-tests.json); postflight confirmed **zero** fixture users remain.
- Exact deployed Edge bundle: **32 regression tests**, **8 wire-validation tests**, zero failures;
  both entrypoints type-check. The four undeployed shared-night tests and four corresponding
  error assertions were excluded only from this deployment subset; [test scope](test-scope.json).
- All eight new private tables have RLS enabled and deny direct SELECT to anon, authenticated and
  service_role. The public state RPC denies anon/authenticated execution and permits service_role.
  Both deployed endpoints return **401** to unauthenticated probes.
- [Postflight](postflight.json), [function revisions](functions-after.json), and
  [verification summary](verification-summary.json) record the observed results.

No native implementation changed during deployment; the preceding full Simulator build and
1,014-test results remain the native evidence. Hosted SQL and unauthenticated HTTP checks do not
establish authenticated physical two-device transport, offline recovery or real shielding.

## Recovery and remaining acceptance

Pre-deployment affected SQL definitions are saved in [before-functions.sql](before-functions.sql)
and complete downloaded Edge source in [before-edge-source.zip](before-edge-source.zip).
These are schema/source recovery records; a fresh full-data backup was not established or claimed.
The additive migrations preserve renamed implementations. Any rollback must preserve newly created
user data and be separately authorized; no destructive rollback was performed.

Physical acceptance remains: two disposable accounts/devices, consent/start/expiry/withdrawal,
offline early end and reconnect, killed/reopened app, visits/recall/concurrent placements,
leave/block/rejoin, account switching, actual shielding and accessibility. New native visuals and
controls require an updated app build; this deployment does not distribute one.

CLI 2.115.0; temporary workspace `/private/tmp/campfire-deploy-20260913`.
