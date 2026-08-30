# TestFlight 36 — candidate handoff

2026-08-28. Build 36 includes the Home timing move above Ollie, the approved Home/animation
work, connection and Ideas & sources refinements, and capability-gated Slumber Party
avatar/shared-habits/archive implementation. The real phone is not automatically updated.

## Accepted source

- Branch: `codex/night-flock-mvp`; base HEAD `cce766d1840a850a23d5c47e4a542203c26a728b`.
- This is a dirty candidate containing inherited work, not only one patch. Its exact
  1,135-file source snapshot is `accepted-review-before.json` in the evidence directory.
  Parent docs were updated after that snapshot; implementation remains frozen.
- Evidence: `/tmp/counting-sheep-shared-habits-20260828-170406/`.
- Build: `build-simulator-final6.log`, succeeded.
- Tests: `tests-5.log` / `tests-5.xcresult`, **760 passed / 0 failed**.
- App recovery: `recovery-probe-accepted.json`, **15/15 passed** in synthetic simulator state.
- Backend: `parent-backend-final/`, eight migrations, five SQL suites, 23 Deno tests and
  both Edge entry points passed. No production participant data or deployment.
- Fresh Sol verdict: **ship for private TestFlight on unchanged August 25 backend**, risk M.
  No blocking findings. Review was behaviorally read-only; parent verified no mutations.

## Latest Home adjustment

Compact Phone away / Phone wakes timing now sits above the unchanged Ollie/window/plant
hero. Expand to see Bed, You wake, Before bed and After waking, or edit the plan. Start
and protection repair remain below the welcome text; the Slumber Party bridge and Phone
Away section retain their structure. Home has a single plan orientation anchor.

Native visual evidence: `home-timing-above-hero-dark.jpeg`, `home-small-screen.jpeg`,
`home-timing-expanded-ax5-fixed.jpeg`. Normal iPhone 17/SE and iPhone 17 largest text were
checked; this is not complete spoken VoiceOver or physical-device performance QA.

## Runtime scope and holds

Current production is still the August 25 V4 backend. New shared-habits agreements, sleep
publication and archive commands remain unavailable until explicit capability support.
Old-backend create/join/leave must not strand privacy fences or advertise new retention.

The avatar, membership-sharing and shared-habits migrations/functions have NOT been
activated by this work. Publication of the reviewed public privacy policy and App Privacy
reconciliation remain prerequisites for expanded data activation, alongside physical
Health/Screen Time and three-account QA. Singapore verified exact-app export remains
unsupported through the current public Apple integration; no bypass is implemented.

## Distribution

Approved version: 1.0 (36). Approved Health purpose text mentions consented Slumber Party
sleep summaries. No entitlement, target, tab or dependency change was authorized here.

Final candidate archive is `CountingSheep-36-accepted.xcarchive` under the evidence root.
Archive/export/upload status must be updated with actual evidence below. The two earlier
build-36 archives are superseded because source changed after they were produced.

No public App Store release, new testers, public invitation links, or website publication
is authorized by the private-beta acceptance. Existing internal and external TestFlight
groups are the requested distribution scope; upload does not prove processing, group
availability, or installation on the founder's phone.


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
