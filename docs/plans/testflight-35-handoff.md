# TestFlight 1.0 (35) — candidate and delivery record

2026-08-28. **Build 35 uploaded successfully and accepted for processing.** Processing completion
and internal/external tester availability are not yet confirmed.

## Authorization and boundary

The founder approved preparing/uploading the next private TestFlight candidate, including
build-number and signing preparation, then explicitly included external TestFlight testing.
Use the existing Counting Sheep — Internal QA and Counting Sheep — QA groups. No new testers,
public links, App Store release, backend deployment, or device-data reset is authorized here.
The earlier distribution holds do not prevent producing this beta for the remaining device QA.

## Exact candidate

- Checkout: `codex/night-flock-mvp`, HEAD `cce766d1840a850a23d5c47e4a542203c26a728b`,
  with the accumulated previously reviewed Home/session/social/motion work preserved.
- Live App Store Connect confirmed build 34 was the latest upload. The source build number was
  still 11 because previous Xcode uploads renumbered it. This candidate sets it explicitly to 35.
- This packaging pass changes only `project.yml`'s build number and generated `project.pbxproj`.
  Three transient Xcode scheme normalizations returned to byte-identical HEAD content.
- No source, asset, feature flag, entitlement, or target changes were made during packaging.
- No commit, push, or tag was created; the frozen source manifest records 1,095 files.

## Parent validation and independent review

Evidence directory: `/tmp/counting-sheep-testflight-20260828/`.

| Check | Result / evidence |
| --- | --- |
| Source preservation | `preparation-baseline.json`, `candidate-35-source-hashes.json`, `packaging-source-delta.json`; only version metadata and generated project differ. |
| XcodeGen | Parent reran successfully after the bounded worker change. |
| Release archive | `archive-35.log`: ARCHIVE SUCCEEDED, exit 0. |
| App Store distribution export | `export-35.log`: EXPORT SUCCEEDED, exit 0. |
| Signed payload | `export-35-verification.json`: seven bundles (main, Watch, five extensions), all 1.0 (35), valid signatures, no debugging entitlement, required capabilities authorized by distribution profiles. |
| Extension placement | Screen Time Report under `Extensions`; four other extensions under `PlugIns`. |
| Motion assets | `export-35-assets.json`: all 64 new motion assets bundled. Motion review launch flags absent from the shipped executable. |
| Symbols | Main app and archive dSYM UUID match: `D86D659C-A87A-3D27-9C46-4DD2611C1C51` (arm64). |
| Exact source tests | Prior final motion pass: 721 tests, zero failures; 15 recovery probes passed. No Swift/assets changed during this packaging pass; these are not newly rerun tests. |
| Fresh packaging review | Sol verdict: SHIP for private internal/external TestFlight only; no blocking findings. Reviewer independently checked source delta, payload/profile/signature relationships and IPA contents. |
| Review isolation | Behavioral read-only on an unrestricted host. Before/after audit of 1,303 source/artifact files found no changes, missing files or additions. Guard: `/tmp/testflight35-review-before.json`; audit: `/tmp/testflight35-review-state-audit.json`. |

Reference exported IPA: `Export-35/Counting Sheep.ipa`, 138,502,571 bytes.
SHA-256: `2646effd95affa93755822284b6a39d091c464d654b9f593c502312d9e0fe5b8`.

Both export/upload configurations use manual Apple Distribution signing, the seven verified
profiles, and `manageAppVersionAndBuildNumber=false`. `testFlightInternalTestingOnly=false`
permits the authorized external beta; it does not submit an App Store release.

## Unchanged backend and remaining acceptance

Release flags remain Slumber Party YES, hosted feedback NO, remote Live Activity delivery NO.
The membership-sharing extension remains undeployed by this task. On the existing backend,
the client retains the round-only capability fallback; this beta must not promise that the new
post-join/between-round sharing contract is live.

Physical Phone Away/Purpose/protection/early exit, overnight restoration, Apple recovery,
two-account behavior, scrolling/dragging, accessibility, animation performance and long residence
still need device QA. Public privacy reconciliation, retention/moderation operations and public
release acceptance remain separate. Upload/processing is not evidence that a phone has installed
the update or that these behaviors passed.

## Delivery

The parent completed the authorized CLI upload using `export-prep/upload-options.plist` and
the same frozen archive. `upload-35.log` records **Upload succeeded** at 10:15:12 Singapore time,
**Uploaded package is processing**, and **EXPORT SUCCEEDED**; the process exited 0. The upload
export may repack/resign the archive, so the reference IPA hash above is not asserted to be the
exact transport-package hash.

Repeated browser navigation/read timeouts prevented verifying processing completion or assigning
the new build to the existing external QA group. Chrome is running, its extension is installed and
enabled, and the native-host manifest diagnostic passes. The supported next recovery step is a
fresh Chrome window/profile reconnect with the founder's permission. No new tester, public link,
group membership, public release, or backend change was made. Do not equate upload success with
external availability or installation on the founder's phone.
