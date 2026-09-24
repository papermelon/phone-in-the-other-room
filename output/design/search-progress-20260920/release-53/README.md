# Build 53 candidate — 20 September 2026

## Scope and live checks

Founder requested completion of the pending interaction/accessibility checks and the next build.
App Store Connect was inspected live: highest upload is 1.0 (52), Complete, created
19 September at 8:49 PM. The repository allocator dry run selected 53.

On the dedicated iPhone 17 / iOS 26.5 QA Simulator, isolated Screenbook fixtures:
- Farm header expands and collapses the production card.
- Expanded rules scroll completely above the fixed tab bar.
- Collapsing after scrolling restores the compact card and following Farm content.
- accessibility3 text scrolls to the final Phone Away rule without truncation.
- Accessibility tree exposes collapsed/expanded state, progress, ordered rule elements;
  decorative artwork is hidden.

Actual spoken VoiceOver focus/activation remains UNVERIFIED. macOS VoiceOver was enabled,
but the automation produced no reliable speech/focus evidence; its original off state
was restored. Founder agreed to check on an iPhone after this build is available.
This is not a claim of full physical-device release acceptance.

## Validation so far

- Prior Debug build and 1,094 unit tests passed; relevant source hashes still matched.
- Fresh isolated Farm save/account harness: 80 tests passed, zero failures.
- 14 tracked property lists and entitlements passed plutil lint.
- Whitespace check passed.
- Release iPhone 17 / iOS 26.5 Simulator build passed with `-jobs 1 ONLY_ACTIVE_ARCH=YES`.
  The generic dual-architecture attempt was canceled under severe memory pressure;
  its replacement preserves Release optimization and all scheme dependencies.
- A premature concurrent test attempt hit Xcode's locked build database; the sequential rerun
  passed all 1,094 tests with zero failures.

The release uses the existing workspace, including pre-existing changes in other features.
No source-control commit/push or signing/capability changes are part of this task.
## Distribution result

**1.0 (53) uploaded successfully at 11:18 Singapore on 20 September 2026.**
App Store Connect subsequently showed upload **Complete**, build **Ready to Submit**,
and assignment to **Counting Sheep — Internal QA** with two invitees. Ready to Submit
is Apple's build-list status; no external beta review or public release was submitted.
[Build 53](https://appstoreconnect.apple.com/teams/aa91d2a7-42f7-4e21-bc98-ebe0a1fb88f2/apps/6788186681/testflight/ios/f21af7ae-f4d9-49c9-b58d-3a12e29efee0).

- Signed Release archive succeeded; script verified version 1.0 (53) across seven bundles.
- Distribution export succeeded. Deep/strict signature verification passed; all seven
  bundles use distribution profiles, get-task-allow=false, and matching team/application
  identifiers and relevant capability entitlements.
- Upload succeeded from the same archive, with automatic renumbering disabled.
- Archive identity and reference IPA SHA-256 are in `archive-identity.json` and
  `export-verification.json`. Apple can repackage/re-sign the upload; the IPA hash is
  the local reference package, not a claim about Apple's final bytes.
- Compiled flags: Night Flock YES, Live Activity Push YES, Feedback NO. No configuration
  activation or backend deployment was performed here.
- The recorded functional source stayed unchanged through archive/export. Only the
  intended build-number bump differs from the tested snapshot.

The shared card also passed live expansion, full-rule scrolling and collapse on the
Ollie's Search route. See `../live-ollies-search-expanded.png` and
`../live-ollies-search-collapsed.png`.

Scope: internal QA candidate. Full public-release acceptance remains **DO NOT SHIP**
until the required physical-device/account/overnight matrix is completed. Spoken
VoiceOver is explicitly assigned to the founder's iPhone check, as agreed in this task.
No installation or spoken-navigation success on that iPhone is claimed.
