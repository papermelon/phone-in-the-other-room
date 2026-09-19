# Production Campfire Buddies deployment — 13 September 2026

Founder authorization: “deploying the new backend, configuring push delivery, proceed with these.” Target verified from the current project listing and existing Release deployment evidence as **counting-sheep-prod**, `sxjlkcccsentmhowgoqe`, Singapore, ACTIVE_HEALTHY. The checkout remains linked to development; all hosted commands explicitly targeted production.

## Deployed and configured

- Applied `20260913140000_campfire_buddies.sql` and `20260913150000_campfire_alert_delivery.sql`, with their exact migration-history statements, in one transaction using five-second lock and sixty-second statement timeouts. Hosted migration SHA-256 values match the [source hashes](source-sha256.json).
- `night-flock-command` and `night-flock-state`: **version 7**, ACTIVE, gateway `verify_jwt=true`.
- `campfire-device` and `campfire-dispatch`: **version 2**, ACTIVE, gateway `verify_jwt=false`; handlers independently enforce verified account identity or the private dispatch secret. The repository config now records these gateway choices. Versions reflect the final secret propagation revision.
- Set `APNS_ALERT_TOPIC=com.ngawangchime.countingsheep`. Verified existing `APNS_ENVIRONMENT=production` and production APNs host by comparing secret digests. Existing APNs signing key, key ID, team ID and dispatcher secret were reused, without rotation or exposing their values.
- Configured Vault `campfire_dispatch_url` and `campfire_dispatch_secret`. The secret was copied entirely inside PostgreSQL from the existing Live Activity scheduler credential after checking that its digest matched the hosted Edge `DISPATCH_SECRET`. No credential material was printed, downloaded or placed in tracked files.
- Confirmed existing pg_net, pg_cron and Vault extensions. The new minute `campfire-alert-dispatch` job and daily `campfire-buddies-retention` job are active. Observed successful scheduled invocations and two matching HTTP 200 worker responses with `{"processed":0}`. Daily pruning is scheduled; this record does not claim its first daily execution has occurred.

## Exact source and scope

The deployed bundle starts from freshly downloaded production Slumber Party source and applies only the Campfire Buddies validator/command changes plus the new device/dispatch functions and their dependencies. The unrelated shared-night-plan migration/capabilities remain withheld. No blanket migration push was used. [Production Edge diff](production-edge.patch), [Edge hashes](edge-source-sha256.json), and [download verification](download-verification.json) identify the actual deployment; all **14** downloaded source files matched byte-for-byte.

The source tree contains uncommitted prior app/Fetch work. This deployment did not commit, push, archive or distribute the app. No signing, entitlement, Auth policy, real party preference, account or Farm data was changed by deployment. Test fixtures were randomized and rolled back. The APNs topic is a project secret/configuration entry; existing signing credentials and Live Activity behavior remain intact.

## Verification

- Before deployment, the two migrations and three SQL suites (Buddies, base Campfire, shared pasture) passed against the hosted schema in a fully rolled-back transaction: [rehearsal](dry-run.json).
- After deployment, all three suites passed again in a rolled-back transaction: [post-tests](post-tests.json). [Cleanup verification](fixtures-clean.json) confirmed **zero** fixture users remained.
- Exact Edge bundle: **32 Deno regression tests**, **13 Node wire/push checks**, no failures. All four entrypoints type-checked using the cached Deno 2.9.6 runtime. The inherited production regression selection excludes the four unrelated undeployed shared-night tests and their corresponding four error assertions, as in the [prior scoped release](../campfire-deploy-20260913/test-scope.json).
- All six new private tables have RLS enabled and deny direct SELECT to anon, authenticated and service_role. Public worker/device/state RPCs deny execution to anon/authenticated and permit service_role. [Postflight](postflight.json).
- All four functions returned **401** for both missing and invalid credentials: [eight HTTP probes](unauthenticated-probes.json).
- [Push configuration verification](push-config-verification.json) confirms the production environment, host, main app topic and signing-field presence. This validates configuration, not receipt of a notification on a phone.
- [Function revisions](functions-after.json) and [verification summary](verification-summary.json) record final observed state.

## Guarded activation

Automatic approval review rejected an initial combined configuration/dispatch command before execution because it could send pre-existing messages. Read-only hosted checks then proved **zero registered devices, buddy sessions and alert events**. The approved safer activation held table locks and asserted those counts remained zero before writing Vault configuration. It did not explicitly invoke dispatch. Subsequent scheduled invocations processed zero events. No test notification was sent to a real party member.

The first download comparison attempt failed because its temporary destination directory was absent. Creating that local directory and retrying completed source verification; no production mutation occurred during that failed read.

## Remaining device acceptance

Push backend configuration and scheduled worker execution are complete. A new authorized app build is required to expose consent version 2, register device tokens and receive the new notifications. At postflight there were **zero** Campfire device registrations and **zero** real buddy sessions/events, so no APNs send or physical notification receipt is claimed.

Still verify on two isolated physical devices/accounts: consent and notification opt-in, actual production APNs delivery, quiet hours/Focus, active-session suppression, automatic/private Wind Downs, buddy acceptance/reflection, early-end/retry, blocked/departed members, expired notification routing, token rotation and account switching. Existing physical shielding/accessibility gates remain separate. Use no founder Farm as a disposable fixture.

## Recovery evidence

[Previous SQL definitions](before-functions.sql) and [downloaded previous Edge source](before-edge-source.zip) are retained as schema/source recovery evidence. No fresh full-data backup is claimed. The migrations are additive and retain renamed implementations; any rollback must preserve newly shared data and require separate authorization. No rollback or destructive operation was performed.

CLI 2.117.0. Isolated deployment workspace: `/private/tmp/campfire-buddies-deploy-20260913`.
