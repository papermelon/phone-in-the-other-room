# Farm backup deployment and acceptance

## 7 September 2026 — account-sync production repair

Founder authorized checking and deploying the missing account-sync backend. Production
catalog inspection confirmed `20260907110000` was absent and the new function/tables did
not exist; this was not merely a stale schema cache. Release build 43 targets production
`sxjlkcccsentmhowgoqe`; the repository remains linked to development.

Deployed `20260907110000_account_identity_and_farm_sync.sql` through the Management API
with an explicit production project reference. The migration and migration-history record
committed in one transaction; PostgREST received a schema reload notification. SHA-256:
`e1983c3154b18d4603226a56d69720eb28a4f3fe063b75bed77363b70e7618e7`.
No unrelated pending migration, Edge Function, Auth configuration, signing setting or
app binary was deployed. The migration includes its account username/rate-limit tables,
provider-neutral identity predicate and retention job as authored in the account contract.

Validation:

- Existing account SQL suite passed locally before deployment.
- Production catalog confirms the migration record and new sync RPC.
- A randomized, transactional production version of the account suite passed consent,
  save/read, cross-owner isolation, legacy Apple API compatibility, username and rate-limit
  assertions, and private table/function privilege checks.
- An additional check switched to database role `authenticated` with a synthetic Apple
  identity claim and verified acceptance, save, lookup payload restoration, and retained
  revision payload restoration. The final `account_sync_smoke_pass_rolled_back` exception
  was the expected success sentinel; it rolled back all fixtures. Follow-up query found
  zero test users remaining. This proves database authorization/contract behavior, not
  native Apple token exchange or a real user's HTTPS session.
- Anonymous HTTPS calls using the Release archive's public configuration now resolve
  sync, revision and username RPCs and return 401 / 42501 permission denied, replacing
  the previous 404 / PGRST202 missing-function response.

The missing-endpoint blocker is resolved. Physical acceptance remains: reopen Profile on
the affected installed build, enable automatic sync, confirm the consent card disappears
and a confirmed save appears. Native Apple re-sign-in still needs a physical test. No
founder Farm was used as a test fixture. Password Edge Function/SMTP rollout remains
separate; deploying this SQL does not establish that password sign-in is fully configured.

## Earlier deployment record

Date: 5 September 2026. Production deployment explicitly authorized by the founder.

## Hosted result

Production: `counting-sheep-prod`, `sxjlkcccsentmhowgoqe`, Singapore.
The repository remains linked to development; production commands used the explicit
project reference and an isolated migration directory. Neither seed data nor vault
configuration was deployed. The unrelated `20260830090000` social migration was
excluded from this release.

Deployed migrations:

- `20260905090000_private_farm_save.sql`: private heads, immutable revisions,
  operation receipts, Apple-account RPC, conditional writes, retained conflicts,
  generation-fenced deletion and daily retention.
- `20260905100000_farm_revision_read.sql`: owner-only access to retained revisions
  without moving the active head.

There is no Farm Storage bucket or extra Edge Function: Postgres transactions
publish the revision/head/operation receipt together. Client roles have no direct
access to the private tables. The RPC derives ownership from the authenticated
request and verifies the non-anonymous user has an Apple identity in Auth.

The main migration SHA-256 is
`d600186b75ce87b5fff70acf16cb4d645279e1d30db6fefc50b44ee0fcb07d01`.
The deployed file matched the workspace bytes. Production verification found both
client table access and anonymous RPC access denied, daily `farm-save-retention`
active, and zero saved Farm revisions. An unauthenticated HTTPS request returned
401 / `42501`.

A synthetic, transactional production smoke test exercised account isolation,
idempotent retries, operation reuse rejection, conflicting initial saves, explicit
selection, retained-revision reads, deletion, stale-generation fencing, and account
cascade cleanup. It deliberately raised `farm_smoke_pass_rolled_back` after the
assertions to roll back all fixtures. That expected terminal error is the pass
sentinel, not a participant sign-in test. No real player Farm was uploaded.

## Apple configuration

Production dashboard inspection verified Apple enabled, manual linking enabled,
and native client ID `com.ngawangchime.countingsheep`. The Release configuration
resolves to the same production project. Existing Debug and Release entitlements
contain Sign in with Apple. No credential, signing identity, target or entitlement
was changed. Native nonce verification is used by the app's existing account
service. Real Apple authentication still requires the physical-device test below.

The CLI could deploy through its active access path, but the older stored Keychain
credential returned 403 for Auth configuration. Dashboard inspection supplied the
configuration evidence; no credential was rotated or exposed.

## App candidate

The app uses the existing shared Apple-linked account for standalone Farm backup,
even with the social feature disabled. Backup consent is independent of party
sharing. Welcome offers returning-player sign-in; the saved-plan page offers backup
before onboarding completion. Farm and Settings lead to Account & Farm backup.

Local metadata includes owner, generation, base revision, pending operation and
last confirmed payload fingerprint. Ambiguous network results retain the same
operation for retry. Restoring first preserves a local recovery copy, defers while
run/morning work remains, and restores Farm reward counters separately from local
Nights evidence. Backup layout/appearance application has a durable pending marker.

The stateless PostgREST request pins the token from the checked shared account;
the Supabase client itself rewrites request Authorization using its latest session,
so merely setting a header on its RPC builder would not provide that guarantee.

## Validation and remaining acceptance

- Final generic iOS Simulator build passed; final signed generic iOS Release build passed.
- Final full app suite: **859 tests, zero failures**, after the transport, account
  fencing and restore-continuity changes.
- Focused Foundation suite: 27 tests, zero failures.
- Farm SQL suite passed locally, including retention preserving ten resolved copies,
  the head and unresolved conflicts.
- Existing ActivityKit, feedback, impact and v4 SQL suites passed on the available
  local database. Broader social suites encountered its pre-existing missing/newer
  migration mismatch; they were not represented as a clean full SQL regression run.

The connected iPhone 16 Pro was still passcode-locked at the final device check.
The final signed Release device build passed. Its bundle ID is
`com.ngawangchime.countingsheep`, version 39, production Supabase URL, and signed
Apple entitlement `[Default]` under the existing team. It has not been installed
on the locked device. Real Apple sign-in, interrupted-network restore, two-device conflict, update,
reinstall and VoiceOver acceptance have not been claimed. Do not erase or reinstall
the founder's app/data for a test; use a disposable installation/account for that leg.
No TestFlight or App Store distribution is authorized or implied by this deployment.

The in-app backup disclosure is implemented. `PUBLIC_PRIVACY_POLICY.md` contains a
repository candidate backup section; public-site publication is separate from that
file edit. No claim that the live policy changed is made here.

## Rollback and operations

To stop access, revoke execution on both Farm RPCs from `authenticated`, or ship
backup disabled in the app. Preserve private tables and revision data; do not drop
them as a rollback. The `farm-save-retention` Cron job runs daily at 03:00 UTC.
Inspect its run history for failures. Current copies and unresolved conflicts are
retained; older resolved copies are pruned after 30 days while retaining at least
ten. Whole-account deletion cascades through all three Farm tables.

## Final review

Risk: L (persisted ownership, authentication and server writes). Production
permission was explicit. Review checked private-payload boundaries, source-pinned
account tokens, local generation/lineage fences, confirmed-save semantics,
operation receipts, conflict preservation, restore deferral, replay identifiers,
local history separation, and deletion cascade. Remaining device acceptance is
explicit, rather than inferred from simulator tests.

Copy review (repository product-copy-review skill):

| Location | Reviewed claim | Verdict |
|---|---|---|
| Farm status | Saved here / last server-confirmed copy | Keep; confirmation is separate from local commit. |
| Disclosure | Farm inventory, names, dates and reward-accounting intervals uploaded privately | Keep; explicitly opt-in and separate from social consent. |
| Restore | Unselected local recovery copy retained; progress not combined | Keep; archive write precedes atomic replacement. |
| Conflicts | Both copies kept for explicit selection | Keep; losing conditional upload creates a retained branch. |
| Delete online copies | Local Farm kept, remote copies removed, cannot undo | Keep; generation fencing prevents stale retries from recreating deleted data. |
| Account deletion | Online Farm and account data removed; local data kept | Keep; uses the existing account deletion flow plus Auth foreign-key cascades. |

No commit/push was made: the workspace contains substantial unrelated founder work,
and existing modified files overlap this implementation. No unrelated changes were
reverted or swept into a commit.

## Physical-device preflight result

The non-mutating attempt to copy the app preferences before installation failed:
CoreDevice `12040`, underlying `kAMDMobileImageMounterDeviceLocked`. The developer
disk image could not mount because NC's iPhone was locked. No device preferences
were copied, no app was installed/reinstalled, and no player data was uploaded.
Unlock the phone before retrying preflight and installing the signed update;
complete native Apple confirmation on the device. The candidate is at
`/tmp/counting-sheep-farm-device-build/Build/Products/Release-iphoneos/Counting Sheep.app`.


## Release-review fixes — 5 September 2026

- Restore now publishes the committed Farm and clears the old last-run reference
  before fallible appearance acknowledgement. If that acknowledgement fails, the
  UI states that the Farm was restored and appearance cleanup needs retry; the
  durable marker remains and Check account retries it.
- All account-deletion entry points use the shared deletion preflight. Farm backup
  must pause durably first; failure stops deletion. Deletion blocks Farm transport
  synchronously before staging, during ambiguous/pending recovery and after an
  accepted tombstone, including app relaunch before journal restoration finishes.
  Farm requests recheck authorization after acquiring their account session.
- Upload staging rechecks the operation context after account lookup; a concurrent
  pause or local reset cannot stage an old operation into the current save.
- Keeping a Farm on an empty account accepts the successful initial put directly,
  rather than selecting against its now-stale empty head.
- Both account-deletion confirmations disclose online Farm deletion.

Focused regression coverage executes the actual FarmBackupViewModel, persistence
adapter and file store in the host harness, substituting only the Apple/Supabase
boundary classes. This does not establish real Apple or HTTP integration. The
full final-candidate matrix is in `docs/PLAYBOOKS/final-build-acceptance.md`.
No additional backend migration or production mutation was required for these fixes.

Copy review:

| Location | Change | Verdict |
|---|---|---|
| Restore cleanup failure | States that Farm restore succeeded while appearance acknowledgement needs retry | Keep: follows the committed Farm, retains the retry marker. |
| Account deletion preflight | Explains that backup could not pause safely and deletion needs retry | Keep: no deletion request is sent. |
| Slumber Party deletion | Names Counting Sheep account and online Farm copies | Keep: matches the existing account cascade, preserves local-data distinction. |

Validation after the review fixes:

- Full app suite: **860 tests, zero failures** (`/tmp/farm-backup-fixes-app-tests.log`).
- Focused host suite: **34 tests, zero failures**, including seven actual backup
  view-model regressions (`/tmp/farm-backup-fixes-tests.log`).
- Generic Simulator build passed (`/tmp/farm-backup-fixes-build.log`).
- The first concurrent app-test attempt hit an Xcode build-database lock; the
  subsequent run after the conflicting build completed passed. This was a build
  orchestration failure, not a failing application assertion.
- `git diff --check` passed. Physical Apple/device acceptance, public policy
  publication, archive validation and distribution remain unperformed in this pass.
- Final signed generic iOS Release build passed
  (`/tmp/farm-backup-fixes-device-build.log`). The updated candidate remains at
  `/tmp/counting-sheep-farm-device-build/Build/Products/Release-iphoneos/Counting Sheep.app`.
  It was not installed, archived or distributed during this fixes pass.
