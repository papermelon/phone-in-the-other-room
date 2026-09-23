# Campfire bedtime, profiles and wardrobe production deployment — 23 September 2026

Founder authorization: deploy wardrobe sharing, then explicitly include its Global profile prerequisite and the separate private bedtime migration in one reviewed release.

Production project: `counting-sheep-prod` (`sxjlkcccsentmhowgoqe`, Singapore). The repository remains linked to development. Only `20260919130000_campfire_bedtime.sql`, `20260920120000_campfire_profiles.sql` and `20260923120000_campfire_wardrobe.sql` were applied. `20260830090000_night_flock_shared_night_plans.sql` remains pending. No app archive, TestFlight distribution, secrets or Cron configuration changed.

## Validation and rollout

- `deno check` passed for `night-flock-command` and `campfire-global`; 35 private Edge tests, 9 Global Edge tests and 6 Campfire validator tests passed. `git diff --check` passed.
- Production preflight confirmed all three migrations absent and fingerprinted the functions they replace. A single rolled-back production transaction applied the exact three migrations, ran the legacy bedtime upgrade, bedtime behavior, Global profile, channel and wardrobe SQL suites with randomized synthetic accounts, and then rolled back. The exact deployment script, including migration-record inserts, also passed a rollback rehearsal. A follow-up query confirmed no rehearsal schema or migration records remained.
- Deployed `night-flock-command` version 8 first, so the optional intended-bedtime field was accepted before its capability appeared. Applied the three SQL migrations in one transaction with five-second lock and 90-second statement timeouts, fingerprint and absence guards, exact source stored in migration history, and a PostgREST schema reload. Deployed `campfire-global` version 2 against the new schema. Both functions report ACTIVE; private command JWT verification is on, Global Campfire uses its internal authentication check.
- Production migration records match the reviewed source MD5 values: bedtime `186067988b791ab5affbdbd4e3403697`, profiles `9cf320e8b9bb0072f59429b87ac09f92`, wardrobe `12d1dfdd245f7c69248d6f35eedbd77a`. The four-argument Global state, profile detail and wardrobe table exist; private sessions have the bedtime column and private profiles have the Ollie coat column. Authenticated callers have no direct execute grant on profile detail.
- Rolled-back synthetic post-deployment SQL tests passed for bedtime, profiles, channels and wardrobe. Unauthenticated HTTP POSTs to both Edge functions returned 401.
- Production `db lint --level warning` exited successfully with no errors. It reported two existing unused-variable warnings and two text-literal-to-JSONB initialization warnings in the now-wrapped Global state function; the exercised state paths returned correctly in SQL tests.

The wardrobe SQL test initially failed during rehearsal because its local test variable `profile` made a column reference ambiguous. The test query now qualifies the table column; the first transaction rolled back and all later rehearsals and post-deployment tests passed. This did not affect production data.

## Remaining acceptance

Backend source and schema are live. The updated native app is not distributed by this deployment. Verify exact clothing and fuller-coat appearance with two signed-in devices across private Slumber Party and Global Campfire, including old-client fallback, opt-in version-2 Global profile consent, withdrawal, dynamic type and VoiceOver. No physical two-account result is claimed here.
