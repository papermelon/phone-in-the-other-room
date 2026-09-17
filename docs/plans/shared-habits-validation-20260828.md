# Shared habits candidate validation — in progress

This record distinguishes prior build 35 UI checks from the new build 36 candidate.
Evidence root: `/tmp/counting-sheep-shared-habits-20260828-170406/`.
It is not an acceptance or deployment report.

## Native checks on the previously installed local build 35

Mac was unlocked. The parent operated the iPhone 17 Screenbook simulator using native
accessibility actions, with no live participant data or hosted writes.

- At standard text size, Settings → Help & app guide → Ideas & sources → Screens and
  boundaries → Give the phone a resting place opens the expected screens.
- At Accessibility Extra Extra Extra Large, the topic and idea text wraps. Repeated native
  scroll gestures reach the explanation, example, optional context, and Relevant sources.
- Relevant sources expands and its source button opens Source details. The product-principles
  entry explicitly identifies itself as an internal design note rather than scientific evidence.
- Screenshot: `ideas-source-accessibility5.jpeg`. This is one navigation path, not a blanket
  accessibility audit of every topic or the new archive UI.
- Nights → Apple Health no-data state does not falsely infer denial. Manage access opens
  an explanatory sheet; its grabber expands and Done dismisses. Complete bottom-of-sheet
  manual scrolling still needs verification.

Actual spoken VoiceOver, physical-device gestures/performance, Health/Family Controls reads,
and multiple real accounts remain separate checks. Simulator text size was changed deliberately
for these tests; restore to large after final candidate checks.

## Build 36 candidate

- XcodeGen succeeded after adding new files and approved metadata.
- First full simulator build failed: Swift initialization captured `self` before all fields were
  initialized in the new habit projection. The owning worker corrected it.
- Second full build failed: a SwiftUI `ForEach` used a function where a key path is required.
  Subsequent attempts caught stale preview arguments, an outbox signature mismatch, optional
  outbox access, and an extension access-control error. These were corrected.
- Seventh full simulator build passed (`build-simulator-7.log`, exit 0), including the Watch
  and embedded extensions. Source changed afterward; this is not the final candidate build.
- First full test run executed 749 tests, with one failure: the date formatter produced
  `29 M08 2026` instead of `29 Aug 2026`. The formatting/calendar correction is in progress;
  a final full rerun remains required (`tests-1.log`, `tests-1.xcresult`).
- Fresh Sol backend review found publication-date validation, blocking, deletion/replay,
  migration, period/cutoff and identity problems. Corrections and targeted tests are ongoing.
  Initial 21/22-test Edge and SQL passes did not establish these untested guarantees.
- Parent independently initialized a separate PostgreSQL cluster, applied eight social
  migrations, and ran all five social SQL suites successfully. Deno passed 23/23 tests.
  Logs and source hashes are under `parent-backend/`. No production participant data was used.
- A second fresh Sol backend review still returned **fix-first**: former-account deletion
  did not invalidate archive cursors; deleting one source suppressed unrelated future statuses;
  changed-timezone rejoin duplicated summaries; JavaScript normalized impossible dates.
  Parent inspection also identified the all-history tombstone/new-epoch interaction and
  current members incorrectly appearing in the retained-former-party list. These need targeted
  regression tests, not another unmodified green test run.
- Fresh Sol app review returned **fix-first** for durable leave/retry state, command-bound
  join consent, cold receipt hydration, pending queue transfer, per-party sleep delivery and
  cursor recovery. Corrections and tests are underway. Reviews were behaviorally read-only
  on an unrestricted host, not OS-enforced isolation.
- Build 36's first native synthetic summary fixture opened correctly, but its useful data
  was below duplicate member/empty activity/round sections. The layout is being revised to
  put factual summaries in the existing member cards. Native validation must be repeated on
  the rebuilt candidate, including dates, coverage, record details and consent states.

## Release state

The live production database remains at the August 25 V4 migration. Debug's CLI-linked project
is different from Release; any deployment must specify Release explicitly.
App Store Connect showed build 35 Testing in the existing internal and external groups.
Build 36 has not been archived or uploaded by this task.
The live privacy policy still shows the July 30 disclosure; the August 28 repository draft is
not published. Publication permission/access has been requested while implementation continues.

## Subsequent parent verification and review

- `build-simulator-final2.log`: full app/Watch/extensions simulator build succeeded after
  the Home timing move and orientation-target correction.
- `tests-3.log` / `tests-3.xcresult`: **758 tests, zero failures** on that candidate.
- `recovery-probe-final.json`: **15 of 15** application recovery probes passed. Synthetic
  isolated state only; no production participants or OS permission claims.
- `parent-backend-final/`: the parent independently initialized another isolated PostgreSQL
  cluster, applied all eight social migrations, passed all five SQL suites, passed 23 Deno
  tests, and typechecked both Edge entry points. The cluster was stopped. The final reviewer
  confirmed all 18 recorded backend input hashes still match current source.
- Native Home: compact Phone away / Phone wakes appears above the unchanged hero; disclosure
  opens the remaining four timing details; start remains below the welcome text. Dark and
  light rendering were inspected. The large-text compact layout stacks correctly. Expanded
  Accessibility 5 still broke AM/PM across lines; a single-column correction was required.
- Native shared-habits: the rebuilt Accessibility 5 sleep means stack instead of squeezing
  into three columns. Date, duration and coverage are exposed through accessibility; mean
  disclosure and archive detail actions open. Accessibility activation scrolls to the target.
  Coordinate scrolling did not visibly move this screen, so manual drag/scroll is still
  **unverified**, not a pass or an established app defect.
- The fresh review still returned **fix-first**. Old-server archive deletion was exposed
  without capability support and could strand the durable publication fence. Migration and
  deletion also swallowed typed authentication recovery errors. Both are being corrected;
  the 758-test pass predates those corrections and cannot accept them.
- `archive-36.log` succeeded, but it predates these review corrections and is **not the
  accepted release candidate**. It has not been exported/uploaded. A new archive is required.
- Browser connection instability/timeouts prevented a fresh App Store Connect availability
  check. No group assignment, privacy publication, backend deployment or phone update occurred.

Remaining: final corrected build/tests/review; expanded Home Accessibility 5 check; small-screen,
spoken VoiceOver, physical Health/Family Controls/performance and multi-account checks; reviewed
privacy publication and explicit Release backend rollout; accepted signed beta upload/processing.


## Home placement and compatibility correction follow-up

- The timing summary now precedes the existing Ollie/window/plant hero. Only the timing
  presentation moved; setup/start/repair actions stay below the hero. Configured Home has
  exactly one home-plan orientation anchor. Empty split sections render no spacer.
- Native iPhone 17 normal dark/light and iPhone SE normal-size layouts were inspected.
  The expanded timing at iPhone 17 Accessibility 5 now uses a single column and keeps
  AM/PM readable. Evidence: `home-timing-above-hero-dark.jpeg`, `home-small-screen.jpeg`,
  `home-timing-expanded-ax5-fixed.jpeg`. SE Accessibility 5 was not established. Simulator
  text sizes were restored to Large after checks.
- `build-simulator-final3.log` succeeded and `tests-4.log` / `tests-4.xcresult` executed
  **760 tests with zero failures**. `recovery-probe-corrected.json` passed **15/15**
  synthetic app recovery probes. These precede the final disclosure/request-admission edits.
- The subsequent bounded review found new sharing agreement copy exposed on the old
  backend. The worker gated the disclosure and create label, made invite copy neutral,
  and rechecks authority immediately before refresh/deletion transport. Full builds 4 and
  5 caught redundant optional-self bindings introduced by these guards; both were corrected.
  Final build/test verification is still pending at this entry.
- `archive-36-final.log` also succeeded, but later source corrections invalidate it as a
  distributable candidate. Neither archive has been exported/uploaded. Backend and live
  policy remain unchanged. No physical phone build has been updated.


## Final source acceptance

- `build-simulator-final6.log`: **BUILD SUCCEEDED**, exit 0.
- `tests-5.log` / `tests-5.xcresult`: **760 tests, zero failures**, exit 0.
- Reinstalled this app on the isolated iPhone 17 simulator;
  `recovery-probe-accepted.json`: **15/15 passed**.
- Fresh bounded Sol review: **ship for local source and private TestFlight 36 against
  the unchanged August 25 backend**, risk M, no blocking findings. Expanded agreement,
  archive and Health publication stay capability-gated. Membership-sharing support is
  independent. The corrected refresh/delete admission checks preserve account authority.
- Parent independently compared all 1,135 captured candidate files after review: no
  mutations. Backend's 18 recorded inputs are unchanged. The review was behaviorally
  read-only on an unrestricted host; no enforced-isolation claim.
- New final archive is being built at `CountingSheep-36-accepted.xcarchive`. Only this
  archive, after its own successful validation/export, is eligible for upload. Earlier
  archives are superseded, not release artifacts.

The source verdict is not public-release approval. Spoken VoiceOver, physical gesture and
performance checks, Health/Family Controls, three-account archive QA, public policy and
App Privacy reconciliation, backend activation, and App Store processing remain open.


## Accepted distribution package

- `archive-36-accepted.log`: **ARCHIVE SUCCEEDED**, exit 0.
- `export-36.log`: **EXPORT SUCCEEDED**, exit 0.
- `export-36-verification.json`: all seven bundles are version **1.0 (36)** with matching
  distribution application identifiers and `get-task-allow=false`. Main app plus report,
  monitor, shield configuration and shield action have matching Family Controls/App Group
  entitlements in both signed code and profiles. Main HealthKit and Sign in with Apple
  capabilities also match. Deep strict codesign verification passed.
- Local reference IPA: `export-36/Counting Sheep.ipa`, 139,213,196 bytes,
  SHA-256 `f2fee1b38231311016da58f08fc72a30fd9377d1fd58cec1db442a0263e9a96a`.
  Upload may repack/re-sign; this is not asserted to be Apple's exact payload hash.
- Upload started using the existing Xcode account and seven verified profiles, with
  automatic build renumbering disabled and external testing not excluded. Await actual
  `upload-36.log` completion; processing/group availability is not yet established.


## Upload result — 2026-08-28 20:14 Singapore

`upload-36.log` records **Uploaded package is processing**, **Upload succeeded**, and
**EXPORT SUCCEEDED**, exit 0, at 20:14:34. The accepted build is **1.0 (36)**.

Processing completion, assignment/availability in the existing Internal QA and external
QA groups, and installation on the founder's phone have **not** been verified. Browser
reconnection could list App Store Connect tabs but reading the group page timed out again;
no group mutation or new tester invitation was attempted. A human can check build 36 in
App Store Connect and the existing groups once processing finishes.

The Release backend and public website remain unchanged. Expanded Health/shared-habits
and archive activation still requires reviewed privacy publication/App Privacy reconciliation
and physical multi-account checks. No Singapore exact-app capability is claimed.
