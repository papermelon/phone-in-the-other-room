# Production deployment — 10 September 2026

Founder authorization: “Please deploy the backend changes and fix this.” Target verified as
`counting-sheep-prod` / `sxjlkcccsentmhowgoqe` (Singapore). The repository remains linked to
`gftqcxfbzngopwndvjyp` development; every hosted CLI operation specified production explicitly.

## Diagnosis and repair

The screenshot request `dc20a483-2ec6-4e9f-b928-d89118f4bb32` appears in production logs at
01:14:19 Singapore: schema 4 `publishActivity`, HTTP 400, `invalid_request`. The logs intentionally
contain neither the payload nor private activity details, so they do not identify an individual
rejected field. Source inspection and a disposable reproduction identify a concrete mismatch:
`NightFlockService.invoke` uses `FunctionInvokeOptions`' default `JSONEncoder`, encoding `Date`
as seconds since 2001-01-01. The downloaded v3 validator rejects this with `Invalid startedAt`.

The new activity wire adapter accepts these shipped numeric dates and existing ISO strings for
v4 activity start/end and status observation. It normalizes numbers before validation/RPC hashing;
ISO payloads remain unchanged. Existing strict fields, chronology, duration bounds, authentication,
sharing scopes and source-event deduplication are preserved. The installed app can retry without
an app release. No founder account was used to reproduce or test a publication.

## Deployed scope

- `night-flock-command` and `night-flock-state`: version **4**, ACTIVE, `verify_jwt=true`.
- Exact migration `20260909090000_slumber_party_farm_cheer_receipts.sql`, SHA-256
  `8ecc5c6a3aad89e85c152795535b1c1e71446728c475996127e9b097cb3110b5`.
- Optional public head-shape capability, latest/cheered-member update projection, durable
  participant-only app acknowledgements. No human “seen” claim.

Edge deployed first, then the one migration and migration-history insertion in a single
transaction with schema reload. No blanket `db push`; no shared-night-plan/v2-agreement migration,
private Farm change, secret rotation, app upload or release. The Edge bundle was built from the
previously deployed v3 sources plus only the Farm/cheer validator changes and activity-date fix.
Repository source additionally contains undeployed shared-night work; do not infer its rollout
from these function versions. [Production patch](production-edge.patch) and
[hash manifest](source-sha256.json) identify the precise subset. Both functions were downloaded
after deployment and matched that tested bundle byte-for-byte.

## Validation

- Complete repository Edge suite: **36 passed** ([log](edge-tests.log)).
- Exact deployed subset: **32 passed** ([log](deploy-edge-tests.log)); four tests exclusively for
  undeployed shared-night features and their four error assertions were excluded from this subset.
  The repository suite still runs those tests and passes. Regression covers Foundation dates,
  ISO compatibility, deterministic retries, status dates, invalid values, chronology and privacy.
- Hosted migration dry run plus SQL suite passed, rolled back before deployment.
- Hosted SQL suite passed again after deployment: Apple and verified-email fixture identities,
  unverified rejection, latest-update retention beyond 100 items, duplicate cheers/acknowledgements,
  sender denial, recipient confirmation recoverable by sender, outsider/third-member isolation,
  blocking, leave/rejoin, legacy profile writes retaining head shape, and direct-role denial.
- Randomized fixture identities existed only in rollback transactions; postflight found **0**
  remaining. The receipt-count assertion was scoped to the fixture reaction for safe coexistence.
- Both unauthenticated HTTP probes returned **401**. Migration history and restricted state-RPC
  privileges verified; see adjacent JSON evidence.
- No native source/UI changed in this repair, so no new app build or screenshots were produced.
  Earlier native build/visual evidence remains in the 9 September records. Hosted SQL and local
  handler tests do not substitute for an authenticated two-device end-to-end run.

Reproduction/CLI workspace: `/tmp/slumber-backend-20260910`. Used Supabase CLI 2.115.0
`functions download/deploy/list --project-ref sxjlkcccsentmhowgoqe --use-api` (use-api for
source transfer), and `db query --linked --project-ref sxjlkcccsentmhowgoqe --file … --output json`.
Saved the affected pre-deployment SQL definitions and downloaded function sources before writes.
The backup API returned no listed backups and PITR disabled; a fresh full-data backup was not
established. This was an additive transactional migration, tested against hosted schema with
rollback first. Existing renamed SQL implementations remain available; rollback must preserve any
new receipt data rather than dropping user records. No backup restore was attempted.

## Remaining device checks

Reopen Slumber Party and refresh to replay the pending activity. The last observed real publication
log was pre-deployment; a successful physical-device retry has not yet been observed. Complete the
existing disposable two-account cheer/relaunch, membership/account-switch and active Wind Down
quiet checks. These and a future explicit native encoder/transport test are recorded in the backlog.
