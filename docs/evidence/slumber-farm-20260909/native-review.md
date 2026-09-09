# Shared Farm native review — 9 September 2026

For the separately scoped commits and their exact-tree validation, see
[the commit record](commit-validation.md).

These are actual SwiftUI release views, rendered by the existing SlumberPartyQA app build on
iOS 26.5 Simulators. The DEBUG launch branch only supplies disposable data and isolated storage;
the Farm, member sheet, contextual cheers and recipient entry are integrated into normal source.
No founder Farm, real account, production transport, or Screenbook was used.

## Screens and interactions

| State | Native evidence | Observed result |
|---|---|---|
| Two members, light | [Shared Farm](farm-light.png) | Clover's round-head, long-haired Shepherd retains moon coat and beanie; Moss's Ollie retains moss bandana. Readable names and distinct targets share the existing Farm backdrop. |
| Small screen, dark | [iPhone SE Farm](farm-small.png) | Characters and names fit without overlap; the screen scrolls. |
| Exact member selection | [Moss's update](friend-update.png) | Tapping Moss opens Moss, dated 9 September, Wind Down 45 rounded minutes, with cheers directly beside that update. |
| Pending | [Queued feedback](pending.png) | Pending is visible without claiming acceptance or receipt. This image uses a prepared pending fixture. |
| Failed send | [Retry](retry.png) | Tapping a cheer with no fixture transport produces Try again and truthful unconfirmed wording. |
| Recipient discovery | [Named receipt](recipient-dark.png) | Tapping the From Moss entry opens Clover's original 30-minute update, with Moss · Moon glow and app-received wording. This is prepared server state, not proof of remote delivery. |
| No eligible update | [Empty state](no-update.png) | Names the selected member and explicitly avoids inferring participation from absence. |
| Unsupported head | [Appearance fallback](unsupported-appearance.png) | Explains unsupported details; retains the supported long hair, outfit and beanie. |
| Older server | [Compatibility](old-server.png) | Cheers remain available; copy states this server cannot confirm receipt by the recipient's app. |
| Stale/offline presentation | [Stale member update](stale-update.png) | Selecting Moss retains the last-received warning and exposes Refresh updates. This is a simulated stale state, not a physical network test. |
| Eight members | [Upper Farm](large-party.png), [lower Farm and list](large-party-list.png) | Stable rows retain readable names and full targets. The list expands. Selecting River's explicitly chosen Juniper sheep opens River's honest no-update sheet. |
| Accessibility text on iPhone SE | [Update](update-accessibility3.png), [cheer controls](accessibility-cheer-controls.png) | Actual `.accessibility3` SwiftUI environment: text wraps, all three cheers stack vertically, and tapping Paw print exposes readable retry feedback. |

Accessibility inspection confirmed button traits, member names/character labels, selection value,
and hints explaining that selection opens the member's latest update and cheers. The list contains
all eight named member buttons. This is accessibility-tree inspection, not spoken VoiceOver testing.
The native fixture forces accessibility3 only with `--farm-accessibility`; the ordinary release
screen inherits the user's environment. `update-accessibility.png` is an earlier large-text capture,
not evidence of an accessibility-category size.

Reduce Motion was enabled through Simulator Settings and read back as 1 during dark-mode receipt,
large-party and edge-state inspection. The composition remained stable; no new decorative motion
is used. The setting was restored to its original 0 afterward. Physical motion/VoiceOver checks
remain in [the rollout backlog](../../FUTURE_AGENT_TASKS.md).

## Reproduction and validation

Generate source membership with `xcodegen generate`. No new targets, dependencies, entitlements,
signing changes, or tab changes were introduced. Existing dirty-tree work was preserved.

```sh
xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/slumber-farm-20260909/Build
xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=7A411907-C7E4-4144-84FC-1AE7F2C6DEA1' -derivedDataPath /tmp/slumber-farm-20260909/Build
xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoomSlumberPartyQA -destination 'platform=iOS Simulator,id=7A411907-C7E4-4144-84FC-1AE7F2C6DEA1' -derivedDataPath /tmp/slumber-farm-20260909/Build
npx --yes deno test --allow-env supabase/functions/_shared/night-flock_test.ts
```

Results: final generic build succeeded; standard suite **939 passed, 0 failed**; final existing
SlumberPartyQA suite **939 passed, 0 failed**; Edge suite **32 passed, 0 failed**. Evidence is in
`/tmp/slumber-farm-20260909/`: `build-exact-final.log`, `tests-final.log`, `tests-final.xcresult`,
`qa-capture.log`, `qa-capture.xcresult`, and `edge-tests.log`.

Native capture devices were the dedicated Counting Sheep Shepherd Art Study (iPhone 17) and
Counting Sheep Review iPhone SE Simulators. Install the QA product and launch bundle
`com.ngawangchime.countingsheep` with `--slumber-farm-fixture` and `--farm-state=...`.
Supported modes: farm, friend, recipient, empty, unsupported, old-server, pending, stale,
large-party. Add `--farm-accessibility` for accessibility3. Every launch creates a new defaults
suite and isolated storage scope. The commit preparation uses the compatible defaults initializer;
the earlier captures explicitly selected a temporary Farm directory. No remote send success is
synthesized from a failed send.

The isolated PostgreSQL 17 cluster used only a Unix socket in `/tmp/slumber-farm-20260909`, port
55439, with no TCP listener. A fresh database applied the repository's Slumber Party migration
chain and this new migration against minimal Supabase auth schemas/roles. Five existing suites
and the new receipt suite passed. The final receipt test additionally passed against the exact
current account verification functions extracted from the September 7 account migration, using
an Apple identity recipient and a verified email sender. An unverified account with misleading
provider metadata remains ineligible. The full private Farm migration was not tested here.

The committed SQL test covers unique reactions, repeat acknowledgement, sender/outsider/third
member denial, actual authenticated-role privilege denial, original update linkage, retention
past the global latest-100 feed, block and leave/rejoin visibility, optional head compatibility,
and unsupported head rejection. Logs: `final-*.log`, `current-account-receipts.log` in the same
temporary evidence directory. New Swift tests cover deterministic selection and placement,
mirrored updates, profile compatibility, participant receipt deduplication, persisted queue
reopening, account-epoch clearing, membership changes and missing target rejection.

## Deployment boundary

[Backend source hashes](backend-source-sha256.txt) identify the reviewed migration and Edge files.
Repository deployment records establish earlier V4/date-adapter deployment; they do not establish
these new capabilities. No migration deployment, production activation, release upload, commit
or push occurred. Two-device delivery/reconnect, account switching, membership/consent changes,
overnight Wind Down quiet behavior and physical assistive technology remain explicit rollout
checks in [the backlog](../../FUTURE_AGENT_TASKS.md).
