# Global Campfire production deployment — 20 September 2026

Founder authorization: “Let’s do global deployment/activation.” Production identity was verified with the existing CLI login and Release project reference: **counting-sheep-prod**, `sxjlkcccsentmhowgoqe`, Singapore, ACTIVE_HEALTHY. Development remains the checkout's linked project; every hosted command specified the production reference.

## Deployed and activated

- Applied only `20260916120000_global_campfire.sql`, including its exact migration-history statement, in one transaction with five-second lock and sixty-second statement timeouts. The initial setting was disabled. Requested PostgREST schema reload afterward.
- Deployed only `campfire-global`, **version 1, ACTIVE**, from an isolated four-file bundle. Gateway `verify_jwt=false` is intentional: the handler verifies the bearer user through Auth, rejects anonymous accounts, and owner-fences writes; SQL independently requires a verified account. No other Edge metadata changed.
- Enabled `private.global_campfire_settings.enabled` after successful validation. A rolled-back verified-account probe confirmed `available=true`, schema version 1 and that browsing does not create a public profile/agreement. Global is available without a private Slumber Party.
- Registered active daily `global-campfire-retention` at `35 3 * * *` (03:35 UTC). The SQL suite exercised the prune function, but this record does not claim the first scheduled execution has occurred.

Existing users were not enrolled, their choices were not widened, and private sessions were not backfilled. No founder account/Farm was used as a test fixture. No native build was distributed, no signing/Auth/APNs configuration was changed, and nothing was committed or pushed. The private bedtime migration `20260919130000` and the older withheld shared-night migration remain undeployed.

## Verification

- [Preflight](preflight.json): Global schema absent; existing verified-account/block helpers and pg_cron present. Before/after function inventories show only the new Global function.
- [Rehearsal](dry-run.json): exact migration plus full Global SQL suite against hosted dependencies, entirely rolled back.
- [Post-deployment suite](post-tests.json): passed again while disabled. Before the retention tests, table locks and assertions established that the Global tables were empty. Fixture IDs were randomized; tests, deletion and retention mutations rolled back together.
- [Source SHA-256](source-sha256.json); hosted migration content matched local source via PostgreSQL MD5 comparison. All four [downloaded Edge files](download-verification.json) matched byte-for-byte.
- Six Node wire-validation tests passed; Deno type-check passed. [Tests](edge-tests.log), [check](edge-check.log).
- [Both HTTP probes](unauthenticated-probes.json) returned 401 for missing/invalid credentials; the endpoint is present. These probes do not establish a successful authenticated device request.
- [Privileges](pre-activation.json): all seven new tables have RLS and deny direct SELECT to anon, authenticated and service_role. [Postflight](postflight.json): public RPCs deny anon/authenticated execution and permit service_role; enabled=true; zero retained fixture users; cron active; private bedtime migration absent.
- Native Ollie repair: full app Simulator build and **1,079 unit tests passed**, plus native alert inspection. [Native evidence](../../../output/design/campfire-global-20260920/README.md).

Reproducible hosted workflow used CLI 2.117.0: `db query --linked --project-ref sxjlkcccsentmhowgoqe --file <reviewed SQL>`, then `functions deploy campfire-global --project-ref sxjlkcccsentmhowgoqe --no-verify-jwt --use-api --workdir <isolated bundle>`. No blanket migration push. Temporary reviewed scripts/bundle are at `/private/tmp/global-campfire-deploy-20260920`; no credentials were printed or added to tracked files.

## Remaining acceptance and recovery

On two disposable physical accounts: refresh/open Global with no party; browse while Off without appearing; explicitly share Wind Down and Phone Away; check different activity filters, encouragement, block/report, early end, expiry, offline Off/reconnect, account switch and conflicting second-device choices. Verify real shielding and notifications separately. An already-capable installed client can refresh Global now; new native seating/navigation/play-alert changes need a future authorized distribution.

Observe the first scheduled retention run, establish the human moderation/support owner and broader connection age/disclosure policy, and collect real production load and backup/restore evidence. No staffed moderation operation, full-data backup, physical QA or authenticated end-to-end HTTP pass is claimed here.

The existing server setting can disable public projection/new publication without removing data or changing private parties/local sessions. It is the first containment option if a later incident requires rollback; leave withdrawals/block/report paths available. This deployment did not perform a rollback. Do not drop public tables or rewind user agreement revisions to recover. Retain new records and use an additive repair with appropriate authorization.
