# Shared habits: independent implementation record

2026-08-28. Independent local implementation complete; final native/device and rollout gates remain. Not a phone build or deployment report.

## Candidate and boundary

Saved checkout: `codex/night-flock-mvp`, starting HEAD
`cce766d1840a850a23d5c47e4a542203c26a728b`, with inherited uncommitted changes.
Before this work, 1,104 files, hashes, git status and the accumulated diff were preserved at
`/tmp/counting-sheep-implementation-20260828-155330/`. Review this turn against its `baseline/`,
not HEAD alone. Do not sweep inherited Home, animation, shielding or backend changes into a commit.

The founder authorized implementation here and selected group-history retention for the lifetime
of the party, subject to legitimate deletion requests. Archive disclosure, contributor migration,
withdrawal/deletion and dissolution handling still require review. This pass does not deploy an
archive or expand Health/app-data collection. Verified exact-app sharing for Singapore remains
blocked on a sanctioned customer route.

## Lanes

1. Contextual connections: truthful observed Health data, native request/refresh/help and
   Screen Time picker in Nights; optional Connections overview remains.
2. Ideas & sources: compact topics, focused ideas and a browsable complete source registry;
   preserve optional routines and onboarding draft behavior.
3. Social presentation: one chosen Shepherd/Ollie/discovered-sheep identity, compact factual
   member cards and useful group details. Any new avatar wire field must be additive/capability
   gated, with honest old-server behavior and no sensitive-data changes.

Configured Terra High roles handle bounded implementation. Parent owns decomposition, documents,
integration and verification. Home hero, personal session state/rewards, tabs, signing and targets
remain outside the change scope. No deployment, beta upload or App Store action is authorized.

## Acceptance evidence

- Candidate snapshot: completed before mutations.
- Initial `xcodegen generate`: passed.
- Screenbook doctor: passed; Xcode 26.6, iOS 26.5, iPhone 17 runtime available.
- Screenbook Python tests: seven passed; registry/schema reconciled to the nine existing Swift scenarios.
- Existing local SQL suites: membership sharing, v4 and legacy suites passed against the pre-avatar schema, using an isolated Unix-socket-only PostgreSQL instance.
- First integrated Debug build: failed with two integration causes (cross-file private setter and an async operation extracted into a synchronous helper); corrections requested. This is not acceptance evidence.
- Final generic Debug simulator build: passed (`build-reviewed.log`). A subsequent test build includes the final preview additions.
- Full Swift suite after review corrections: 734 passed, zero failed/skipped (`tests-reviewed.xcresult`, `tests-reviewed-summary.json`).
- Deno Edge tests: 21 passed, zero failed (`deno-tests.log`).
- Additive avatar migration: applied cleanly in isolated local PostgreSQL. All four legacy/v4/membership/avatar suites passed; the avatar test fixture's initial missing linked account was corrected before the final run (`sql/final-verification.json`). The temporary server was stopped.
- Python Screenbook tests: seven passed (`screenbook-tests-final.log`).
- Native simulator checks: guide → topic → idea → internal-source navigation; Health Connect directly from Nights → native Apple sheet → declined/no-data feedback; consistent Settings no-data state; compact member cards → Group details → identity picker; immediate local Ollie and discovered Mabel selection. No hosted actions were performed.
- First fresh review: fix-first for missing Health help in Nights and offscreen avatar service feedback. Both corrected, then rebuilt/retested.
- Second fresh review: **ship, local independent slice only**; no blocking code findings. See `shared-habits-independent-sol-review.md`.
- Final corrected help-sheet/feedback interaction and large-text checks: not completed because the Mac locked. A previous attempted accessibility capture was at standard size due to Screenbook's global override; it is explicitly not accessibility evidence.

Physical Health/Family Controls consent and two-account hosted propagation cannot be established
from unit tests or simulator fixtures. Their remaining gates will be listed explicitly in the
final delivery record; no claim of phone-update or release completion follows from a local build.

## Parent review corrections before acceptance

- Preserve first-use Health Connect; do not let an unsolicited empty query hide the request action.
- Fence both query and native-authorization completion against a local-data reset.
- Disclose that the common Screen Time selection serves reports and future app protection, not reports alone.
- Keep Group details live after actions, show failures, suppress duplicate requests, and dismiss removed groups.
- Keep avatar picker feedback observable after a save rather than caching a transient status string.
- Preserve exact PostgREST RPC parameter names and explicit service-role-only execution privileges in the additive migration.
- Preserve a deliberate local avatar choice across legacy refreshes without overwriting a recovered server choice on a pristine installation.

The UI worker inadvertently invoked a Screenbook list command that starts build preparation; that attempt is not used as validation. Parent builds and test artifacts are authoritative.

## Delivered behavior

- Health UI reports actual dated observations rather than treating “access requested” as connection status. Native request and query completion cannot restore state after reset. Nights offers Connect/Refresh/Retry and the same scrollable Manage access help as Connections.
- Screen Time has contextual connection/selection actions; picker wording discloses reports and future app protection. Existing active-session shielding snapshots are preserved.
- The library retains ten ideas and seven sources, organized into six topics. Source details distinguish external references from internal product notes; optional routine additions preserve onboarding drafts.
- Slumber Party shows one identity with factual existing activity/status instead of the repeated avatar/Ollie/sheep strip. Group details contains actual people/invitation/admin controls and the identity chooser.
- People may choose Shepherd, Ollie or a discovered sheep. Existing Shepherd/Ollie cosmetics are retained; sheep have their catalogue appearance. Choice survives trading and legacy server refresh. Unsupported servers receive no new avatar field; UI labels the choice as local until acknowledged.

## Remaining release boundary

The avatar backend source is **not deployed**. New sensitive sleep/app summaries and the approved
party-lifetime archive are **not implemented** in this slice. Verified exact-app sharing for
Singapore/SEA still needs a sanctioned platform route; manual labels are not substituted for
verification. Consent migration, deletion/withdrawal and dissolution handling remain separate
work. Physical Health/Family Controls and two-account propagation/recovery require on-device QA.

No signing, target/tab, project.yml, hosted configuration, distribution or phone-build changes
were made. XcodeGen regenerated its project only. Changes remain in the inherited working tree;
no sweeping commit or push was made. The preserved baseline plus implementation.diff identifies
this pass independently of earlier work.

## Evidence location

`/tmp/counting-sheep-implementation-20260828-155330/` contains full command logs, result bundles,
SQL results, baseline hashes/diff, review mutation guards and native PNGs. The final candidate
was installed only on the dedicated simulator. Screenshots are deterministic fixtures, not
proof of real user data, hosted sharing or permission grants.
