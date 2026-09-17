# Home restoration and shared-habits activation — build 37

## Accepted scope

**Latest status, 28 August 2026 at 22:26 Singapore:** policy published and verified; reviewed
Release backend deployed and metadata/security checks passed; build 37 shows **Testing** in
both Internal QA and external **Counting Sheep — QA**. Device installation and physical
two-account/performance/accessibility QA are not established. Earlier paused-status entries
below are the chronological record, superseded by the activation evidence at the end.

Founder request on 28 August: restore the bordered Wind Down timing card above the current
Ollie/window/plant hero, restore the green contextual start action, make Ollie's authored
animations noticeable, and activate the prepared shared-habit service. Preserve the rest
of the accepted Home layout, four tabs, current character art, and independent reward rules.

The first implementation had interpreted “move timing above Ollie” too narrowly: it moved
the compact row rather than restoring the older visual hierarchy. This correction restores
the range, moon and two bookend cells, with precise phone timing behind a disclosure. It does
not bring back the legacy combined quiet-minute metric or five-tab navigation.

## Implemented and reviewed

- Bordered timing card above the hero; Before bed and After waking inset cells.
- One green start action below the hero: eligible Wind Down first, otherwise eligible saved
  Phone Away or immediate Phone Away. Protection repair and missing NFC setup still take
  precedence. The lower Phone Away row retains planning without a duplicate quick-start CTA.
- “Tonight” only describes an upcoming bedtime on the current calendar day. Other resolved
  periods use “Wind Down.” All displayed times come from the resolved primary period.
- Accessibility sizes use separate full-width Bed/You wake rows and unrestricted CTA text.
- Ollie's production neutral pauses are shorter: first tilt after one second, full cycle
  39.39 seconds. Authored poses, five-second rest, cosmetics and pause gates are retained.
- Build number 37, using the founder's existing approval to increment for the new candidate.

Implementation used the existing Terra worker. Parent inspected source and native UI and ran
the build/tests. A reused Sol reviewer returned **ship for this bounded source delta** after
the heading correction; a fresh review context could not be spawned because the task's
agent-thread limit was reached. Reviews were read-only by instruction, not OS sandboxing.

## Parent verification

Evidence root: `/tmp/counting-sheep-home-restoration-20260828-204351/`.

- `build-final.log`: BUILD SUCCEEDED, exit 0.
- `tests-final.xcresult` / `tests-final.log`: **762 tests, zero failures**, exit 0.
- `git diff --check`: passed.
- `home-standard-final.jpg`: normal bordered timing and green Wind Down action.
- `home-ax5-header-final.jpg`: largest accessibility text has readable Bed/You wake rows.
- `home-phoneaway-final.jpg`: Phone Away contextual green action in the interactive fixture.
- `phoneaway-admitted-final.jpg`: the confirmation dismisses into Active Phone Away without
  navigating out/back. This fixture simulates protection; it does not verify Family Controls.
- 58-second native Home recording uses normal production motion cadence; parent inspected
  tilt, ears, tongue, rest and rise. See the motion implementation document for evidence.
- `archive-37.log`: ARCHIVE SUCCEEDED; `export-37.log`: EXPORT SUCCEEDED.
- `verified-37.json`: all seven exported bundles are 1.0 (37), correctly distribution signed
  with no debug entitlement; five Family Controls targets carry the App Group. Main app has
  HealthKit, Apple sign-in and the approved Health purpose wording. Deep strict signatures pass.
- Exported IPA SHA-256: `2c306470c968545fc6058e6464a990935af9346129ada3e877a5c416aadc7390`.
  Apple's upload process can repackage/re-sign; this is the local export hash only.
- `accepted-source-37.json` captures 1,136 source files. Inherited dirty work was preserved.

Native scroll gestures did not move the simulator view through this control connection.
Spoken VoiceOver, full AX5 action visual verification, physical performance/gestures,
Health/Screen Time and multi-account archive QA remain open. No claim of those checks passing.

## Activation: not yet live

The server warning means the Release backend does not advertise the new shared-habits
contract. It is not an Apple Health permission error and cannot be fixed by a member's settings.

Fresh explicit-Release audit and dry run found exactly three missing migrations:

1. `20260827120000_night_flock_membership_sharing.sql`
2. `20260828170000_night_flock_v4_social_avatar.sql`
3. `20260828180000_night_flock_shared_habits_archive.sql`

All 18 backend input hashes still match the previously accepted local SQL/Deno validation.
No new entitlement, secret or client flag is needed. The new migration exposes capability
support immediately; deployment must account for installed compatible clients discovering it.
Matching command/state Edge functions must be deployed against the explicit Release project,
with JWT verification preserved. The repository's CLI-linked project is Debug: do not use an
unqualified linked deployment. Do not read participant records or fabricate consent to test it.

Founder authorized publication of the reviewed policy at
`https://countingsheepproject.com/app-privacy-policy.html` and confirmed SiteGround sign-in.
SiteGround authentication was visible, but repeated browser action/read timeouts persisted
after a founder-approved fresh Chrome window. Extension and native-host checks passed. The
founder has been asked to reinstall the Browser plugin. **No website or backend mutation has
been made in this pass.** A public-ready HTML copy is prepared in the evidence directory as
`app-privacy-policy.html`; repository-only draft notice is omitted and effective date is
28 August 2026. It is prepared, not published.

After publication, verify the actual live policy, deploy the reviewed backend slice, verify
migration/function metadata and restricted privileges, and inspect existing retention-scheduler
metadata without running destructive cleanup. Repository App Privacy answers already cover
linked Health/App Functionality/User ID; live App Store reconciliation is still unverified.

Existing party members must accept the expanded agreement in the app before new summaries
are published. Activation does not grant Health access, backfill private pre-join records, or
enable unsupported automatic Singapore app-identity/usage export.

## Distribution

`upload-37.log` records **Uploaded package is processing**, **Upload succeeded**, and
**EXPORT SUCCEEDED** at 21:32 Singapore on 28 August; command exit 0. Apple accepted build 37
for processing. Processing completion, external-group availability and installation on the
user's phone are not yet established. Public App Store release is not approved by this source
verdict. No product source changed after the accepted archive snapshot; only release notes.

The founder's Plugins screenshot shows no installable Browser entry. The initial reinstall
instruction was not applicable to that UI; do not install unrelated search results. Browser
connection recovery must use the actual Computer use/browser settings or an available supported
connection, not invented installation steps.
Official browser troubleshooting subsequently confirmed **Settings → Computer Use → Google
Chrome** as the connection/reinstallation surface (Manage when installed, Install otherwise).
The supported direct link is `codex://settings/computer-use/google-chrome`.

### Browser recovery follow-up, 28 August, approximately 21:53 Singapore

After the founder confirmed the Chrome extension reinstall, SiteGround navigation and File
Manager interactions worked. The exact existing file was located at
`countingsheepproject.com/public_html/app-privacy-policy.html` (7,061 bytes, July 30 version).
It was downloaded successfully despite the browser's download-event listener timing out.
The local backup is `previous-public-policy.html` in the evidence directory; SHA-256:
`ab28966f4b59ac76d4019ae8994409d3d1caad4170f28c715f879b9f5a0fd23d`.

The supported file chooser opened, but setting the replacement file failed with **Not allowed**.
The browser's upload troubleshooting requires Chrome → Extensions → ChatGPT → Details →
**Allow access to file URLs**. That permission has not been changed by the agent. No replacement
upload, public policy update or backend deployment occurred. SiteGround File Manager is marked
for handoff; publication authorization remains valid for the unchanged reviewed artifact.

The previously open App Store Connect page showed build 36 testing in both QA groups. It
predated build 37's upload, so it is not evidence of build 37's status. An explicit refresh then
timed out; processing completion and external availability for build 37 remain unverified.

## Activation completed — 28 August 2026, 22:26 Singapore

The founder enabled Chrome file-URL access and confirmed readiness. The unchanged reviewed
HTML artifact was uploaded through SiteGround File Manager, replacing only
`countingsheepproject.com/public_html/app-privacy-policy.html`. SiteGround confirmed one
successful upload. The public URL was reloaded and its full rendered policy inspected: effective
date 28 August 2026, expanded per-party agreement, future-member archive visibility, ordinary
leave retention, deletion/withdrawal rights, sleep-summary scope, and Singapore app-data limits.
No repository-only draft notice is present. `published-policy-dom.txt` records this evidence.
The uploaded artifact SHA-256 is
`93073d4e8d4e854d11e472963bf3eb5fdc6fb23093d720cd5678bf588ca2663e`.

All 18 accepted backend input hashes were rechecked unchanged. Fresh Release dry run listed
exactly the three expected migrations, no seeds or roles. The matching `night-flock-command`
and `night-flock-state` functions were deployed first: their existing RPC names and signatures
remain compatible while the database capability is still absent. The three migrations were
then applied successfully to the explicit Release project. No unqualified linked deployment,
secret change, unrelated function deployment, participant-record inspection, fabricated
agreement, manual data cleanup, or cron creation occurred.

Post-deployment evidence in the same evidence directory:

- `activation-preflight.log`, `activation-functions-deploy.log`, and
  `activation-migrations-deploy.log`: all commands exit 0.
- `activation-postflight.log`: database up to date, zero pending migrations.
- `activation-metadata.sql` / `.log`: three migration versions recorded; shared-habits and
  avatar capabilities installed; all three archive tables deny direct anon/authenticated
  SELECT; command/state/purge entrypoints deny anon/authenticated EXECUTE and allow service
  role execution. Archive tables are in `private` and use ACL isolation, not row-level policies.
  The updated membership cleanup wrapper is installed.
- `functions-before.log` / `functions-after.log`: exactly the two intended handlers changed,
  both version 2, ACTIVE, `verify_jwt=true`.
- `activation-unauthenticated-checks.json`: both endpoints return HTTP 401 without credentials.
- `activation-retention-metadata.log`: Cron exists, but no job directly invokes
  `purge_night_flock_retention`. An external operational caller has not been established.
  Do not interpret installation of the purge function as proof that scheduled retention runs.

Build 37 completed Apple processing and was added to the already-authorized external QA group
with scoped What to Test notes. After submission, the authoritative build row showed
**Testing**, both **Counting Sheep — Internal QA** and **Counting Sheep — QA**, and 90-day
expiry. `testflight37-status.txt` records the row and test notes. A click timeout occurred,
but the resulting Testing state and closed dialog confirmed completion; no duplicate submission
was made. Installation on the founder's phone is not verified.

The live App Privacy page points to the correct policy URL and already declares linked Health
and User ID for App Functionality and Analytics, plus linked Device ID and Product Interaction.
`app-store-privacy-dom.txt` captures the read-only check. No privacy-label edit was made.
The public App Store draft is still attached to build 2 with stale review text saying Slumber
Party is disabled and shielding can be skipped. That draft was not submitted or changed;
update its build, screenshots, description and reviewer instructions before public release.

Remaining acceptance gates: physical two-account agreement/publication/history/deletion and
Apple recovery tests; Health/Screen Time/background/overnight evidence; spoken VoiceOver,
manual gestures and physical motion/performance; retention/moderation operations. Members must
accept the expanded agreement before contributing the new summaries. This activation does not
enable automatic exact-app identity/usage sharing in Singapore or upload private pre-join data.
