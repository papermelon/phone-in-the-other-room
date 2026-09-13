# Farm / Slumber Party implementation — 12 September 2026

Local production source and isolated validation. No deployment, activation, archive, upload,
commit or push. Founder corrections supersede the initial implementation prompt's courtyard
and unresolved-policy wording. [Current decisions](../../plans/slumber-party-pasture-redesign-2026-09-12.md).

## Delivered behavior

- Preserve the original shared meadow artwork and wide framing. Real customized Shepherds
  represent people; their explicitly contributed sheep remain distinct, named, owned animals.
  Two/four/eight-member native scenes use grounded shadows, stable anchors, depth and panning.
- Integrate the actual release Home/Farm/party screens, including active Wind Down entry/return,
  People/Sheep/Lantern actions, one chronological group stream and one contextual member sheet.
  Original update IDs/cheer meanings, recipient app acknowledgements, safety actions and the
  joined-party Farm card copy remain intact. Zero recorded minutes no longer imply a cause.
- Shared visits last until recall, one per member per party and one party per sheep. Personal
  inventory/progression stays; visiting animals are omitted from the personal pasture and
  marked in the Barn. Server ownership comes from the current private saved Farm, with only
  the chosen bounded appearance projected publicly. No private Farm document social upload.
- Deliberate placements alone persist, using normalized ground anchors, scene revision 1,
  membership epochs, per-entity compare-and-set revisions and original idempotency keys.
  Account-partitioned JSON outbox/recovery and visit index survive relaunch. Stale moves
  reconcile to canonical state. Ambient motion, nudges and petting do not send messages.
- The lantern needs 12 first completed-session round grants, at most one per member per
  party-day. Two daily participants need six days; eight need two. Early endings preserve
  existing personal grants/credit and add no project contribution. Progress survives rounds
  and membership changes. Policy starts at migration activation; there is no pre-activation
  backfill. Separate eligible parties progress independently.
- Ollie stays personal by founder decision after the owned shared companion study. Fetch/gather
  is functional local play and touches no session or reward state. Tapping Ollie opens his
  details, play and owned accessories. Sheep open their existing Barn details; the Shepherd
  opens customization. Shop is an explicit link. A Residents menu provides the same destinations.
- The Shepherd preview is pinned above scrolling appearance/wardrobe controls and updates
  immediately. Ollie's accessory preview uses the same fixed-preview pattern.
- Personal background and the barn Shop tile use paper artwork in their stable slots. Four
  verified unused runtime files are retired; fitted characters/cosmetics and fallbacks remain.

## Native inspection

Ordinary DEBUG fixtures use real release views and renderers, an isolated UUID defaults suite,
local Farm state, disabled external services and completed onboarding. No Screenbook or MVP
release wiring was added. Fixtures do not establish live server, NFC or shielding behavior.

| Evidence | Result |
| --- | --- |
| [Two](08-two-final.png), [four](09-four-final.png), [eight near](10-eight-final.png), [eight far](20-eight-far-meadow.png) | Figure anchors, owner labels and usable controls on SE; native far-meadow action pans to remaining members |
| [Personal Farm](23-personal-final.png) | Refreshed scenery, real residents, accessible Residents/Play menus |
| [Ollie details](18-ollie-details.png), [scrolled Shepherd](19-shepherd-pinned-scrolled.png) | Native resident taps open their own destinations; lower skin/hair selections update the pinned model |
| [Member sheet](21-member-context.png), [retry](17-cheer-retry.png), [recipient](22-recipient-feedback.png) | Original update/date, quiet-cheer choices, retry wording and named app-receipt context |
| [Lantern earned](11-lantern-complete.png), [empty](16-empty.png), [old server](13-old-server.png) | Earned prop and no-update/unsupported source states |
| [Active Wind Down](14-active-wind-down.png), [returned live Home](24-returned-live-home.png) | Actual native entry/return retains the running timer; peer app-reported cue; no physical protection claim |
| [Light shared meadow](26-shared-light.png), [light personal Farm](27-personal-light.png) | Native light-appearance palette and readable scene controls |
| [Large-text party](15-large-type.png), [stale data](12-stale.png), [lantern details](25-lantern-details.png) | Repaired Home-to-party route, accessible controls, truthful refresh notice and scrollable project explanation |

Native accessibility actions opened Ollie, Shepherd, sheep and member details. Fetch changed
from fetching to toy returned; gather changed to flock gathered. Skin and hair changes remained
visible while the options scrolled. Movement secondary actions and far-meadow navigation worked.
Home → party → running Home was exercised, and an explicit switch to Nights stayed on Nights.
A tab-mount race found during capture was repaired before final verification.
Raw coordinate automation did not reliably reproduce hold/drag or camera swipe; those remain
physical-device checks. Reduce Motion has domain coverage; physical assistive-technology testing
is outstanding. Initial art/layout captures 01–07 are historical, with 01–02 explicitly rejected.

## Validation

- Full Simulator app build: see `final-build.log`. Existing unrelated Supabase initializer
  deprecation warnings remain; no new build error is left unresolved.
- Full native unit suite: **979 tests, zero failures** on final source (run 05), recorded in
  `final-tests.log` and [validation.json](validation.json).
- Eight isolated SQL suites pass: pasture, v4, membership sharing, public appearance, contextual
  cheer receipts, shared habits, private Farm save and account identity. See
  [machine results](backend-results.json) and individual `.sql.log` files.
- [Two real connections](concurrent-placements.log) race peer moves: one winner/one conflict,
  retries leave revision 1. Simultaneous daily grants add one project contribution while keeping
  both personal grants. [Edge validator](edge-validator.log): five tests pass against actual TS
  field/error validation, including bounded anchors, schema/consent and private-field rejection.
- Fresh local PostgreSQL 17 migration chain applied in `pasture_release` on `/private/tmp:55439`
  as `pasture_test`. [Runner](run-isolated-sql.py) creates only that disposable database. The
  [bootstrap](isolated-bootstrap.sql) supplies a cron-registration shim; scheduler execution is
  not claimed. The [legacy Auth adapter](legacy-auth-fixture-adapter.sql) is enabled only for four
  historical provider-metadata fixtures; disabled for current identity/privacy/pasture tests.
  Production Auth checks were not weakened. See `final-migrations.log`.
- Initial compilation/layout and legacy-layout test failures were repaired. Final evidence
  supersedes earlier failures and pre-repair screenshots. `git diff --check` passes.

## Source versus hosted capability

Migration `20260912120000_shared_pasture.sql` and three commands extend the existing v4 endpoint:
`contributePastureSheep`, `recallPastureSheep`, `movePastureEntity`. Optional `party.pasture`
version 1 carries current epoch, entities, visits and lantern. Older clients ignore the addition;
new clients retain the readable scene when the capability is absent or unsupported.

Only the existing service-role command/state paths can execute the membership-checked SQL.
Private tables/functions revoke direct client access and use RLS. Visits validate linked account,
current membership, blocks, saved active ownership and consent 1; only owners recall. All members
may move visible entities. Removal from the saved Farm or ended membership recalls visits.
Account/party deletion cascades or makes records inaccessible. Ten prior placements are retained
for recovery. Successful contribution receipts outlive the general v4 retry ledger so an old
replay cannot resurrect a recalled sheep. Existing reward and cheer ledgers remain separate.

This source is **not deployed**. [10 September deployment evidence](../slumber-backend-20260910/deployment.md)
only proves that older capability. The dedicated local PostgreSQL cluster was stopped after testing. Physical two-device transport/protection and an authorized
rollout remain in [the backlog](../../FUTURE_AGENT_TASKS.md).

## Assets and working-tree preservation

[Baseline status](baseline-status.txt), [starting hashes](baseline-sha256.json),
[changed baseline files](changed-from-baseline.json) and `source-manifest.json` distinguish this
batch from substantial unrelated existing work. No unrelated file was reset or discarded.
The original shared meadow SHA-256 remains
`a9990baa63389fb517176656934d475111985f9600557423925ea11e80c3650d`.

[Retirement record](retired-assets.json): four files, 5,561,271 bytes, were checked byte-for-byte
against committed copies and checked for static/dynamic/all-target consumers before removal.
The side-scroll test and two raw generation sheets are recoverable from Git. Generation masters
and backups are outside runtime catalogs in ignored `tmp/imagegen/pasture-redesign/`.
The image tool could not produce a true transparent barn after two attempts; its checkerboard
outputs were rejected. The integrated barn is intentionally a contained cream-paper Shop tile.
Actual tool availability was `image_gen.imagegen`; no selectable model was exposed.

[Resource measurements](resource-final.json): source catalog 62,964,191 → 60,158,922 bytes
(−2,805,269). Compiled Simulator app `Assets.car` 45,017,928 → 45,299,512 bytes (+281,584),
Watch +282,672, Live Activity +282,640, shield unchanged. Raw source retirement is not equivalent
to compiled savings; replacement art changes encoding. Embedded copies are not summed, and
these figures do not claim App Store download size.
