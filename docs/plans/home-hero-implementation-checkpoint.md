# Home hero implementation checkpoint

2026-08-28. **Historical Home-layout checkpoint; later animation evidence is in
`ollie-motion-implementation.md`. Do not treat either source checkpoint as release approval.**

## Candidate and ownership

Work remains in `/Users/ngawangchime/Desktop/Developer Projects/Phone in the Other Room`,
branch `codex/night-flock-mvp`, based on HEAD `cce766d1840a850a23d5c47e4a542203c26a728b`.
The large inherited working tree was preserved. This pass did not change account recovery,
backend transport, reward settlement, protection services, signing, project.yml or tab structure.
XcodeGen regenerated the project normally. No push, deployment or updated phone build occurred.

The before-edit source hashes and copies are in `/tmp/counting-sheep-home-hero-20260828/`.
`r8-changed-hashes.json` identifies the reviewed Home slice; comparison to HEAD alone includes
substantial older work and is not a useful attribution of this pass.

The parent retained orchestration, specifications, image attempts, code inspection, Xcode runs
and UI checks. Terra High workers implemented bounded native/social/prototype changes. Sol High
checkpoint reviews were read-only by instruction, with before/after hashes checked; the actual
filesystem permission profile was unrestricted, not an enforced read-only sandbox. Runtime
model/effort identifiers were not independently exposed by the reviewer, so the configured role
is recorded without claiming separate runtime attestation.

## Implemented

- Personal Ollie welcome above a compact Wind Down summary; one small window and plant.
- Collapsed phone-away/phone-wake timing; expandable factual bed/wake/bookend details and edit.
  Missing NFC tag routes to full setup, while protection repair retains its focused destination.
- Recognizable Slumber Party members/current statuses and one recent factual highlight. The
  round badge moves intact to a new row when necessary. Full history remains in the group.
  Party scope, membership filtering, stale-data behavior and existing transport remain intact.
- Stable per-visit highlight selection, including persisting its replacement after expiry.
  No live status is described as “No current status,” not a false absence of all shared activity.
- Native four-pane window: daytime 06:00–18:00 and nighttime otherwise, using the iPhone's
  current local time zone. It refreshes at minute boundaries/foreground/viewport re-entry and
  pauses offscreen/backgrounded. No GPS or sunrise/sunset claim. The sky is a native UI graphic;
  the generated Ollie artwork has not been edited as a workaround.
- Existing idle animation receives visibility/Reduce Motion handling. Farm thumbnails default
  to static; the selected pasture can opt in outside dragging/active Wind Down/background.
- Shepherd removed from the current/default preview and absent from the native hero. The
  studio retains an unchecked comparison control outside the mock app. When enabled, the visible
  pair is centered and shares a ground line. This is not a new saved app setting or avatar restyle.

## Review corrections made

The initial checkpoint failed tests because two new test files imported the app module instead
of using the target's directly compiled Shared sources. That was fixed. Review also corrected
the NFC setup destination, preference-versus-resolved-occurrence duration mismatch, highlight
expiry selection, narrow-layout overflow count, misleading member fallback, viewport initial-size
race, duplicate bottom padding and window composition. Parse-only worker checks did not count
as acceptance. Subsequent Sol review found no additional actionable code defects in the r6
checkpoint; the parent then checked the window's placement and opaque night palette corrections.
The subsequent r8 Sol recheck accepted this **partial checkpoint**, found no new actionable
findings or unreported blockers, and confirmed the final screenshots/logs and manifest hashes.
That checkpoint's verdict was **fix-first** because the requested animation and QA scope was
unfinished. The subsequent authorized motion pass is recorded separately below.

## Actual verification

Artifacts below are relative to `/tmp/counting-sheep-home-hero-20260828/`.

| Check | Result / evidence |
| --- | --- |
| XcodeGen | Ran at start and after new source files. |
| Final generic simulator build | `build-r8.log`: **BUILD SUCCEEDED**. |
| Final main unit suite | `test-r8.log`, `tests-r8.xcresult`: **716 tests, zero failures, TEST SUCCEEDED** on iPhone 17e. |
| Recovery probes | `ui-r7/recovery-probe.json`: **15 cases, no failures**; only window palette/icon changed afterward. |
| Native regular-size Home | Inspected r2/r5/r6/r7/r8 captures; `ui-r8/home-day.png` and `home-night.png` show final placement and distinct skies. Night used a test-process UTC override; day used Asia/Singapore. |
| Immediate Phone Away | r5 UI activation: Home Start now → confirmation → Active without back navigation/app switch. |
| Scheduled Phone Away | r6 UI activation: Plan → saved After dinner start → confirmation → Active; `ui-r6/scheduled-start-active.png`. |
| Timing disclosure | Opened and collapsed in the native simulator; bed/wake/bookend rows appeared. |
| Prototype comparison | Inspected at 390 and 320 widths; default is Ollie alone. Latest narrow comparison is `output/design/home-minimal-20260828/personal-shepherd-320.png`. |
| Whitespace | `git diff --check` passed. |

## Remaining work and verification gaps

1. **Animation-source gap superseded by the authorized 2026-08-28 motion pass.** Local Vision
   segmentation and deterministic registration produced true alpha assets without another
   image API. Original generated checkerboards remain source references, not app textures.
   Processing provenance is in `output/design/ollie-motion-20260828/provenance.json`.
2. The motion pass implements ear tuck, tongue, flop/rest/rise and all three finished cosmetic
   sets in Home and Farm. It also fixes Home's visibility measurement, which had kept the
   visible hero paused. See `ollie-motion-implementation.md` for exact native evidence and
   remaining interaction, accessibility and physical performance gates. Earlier checkpoint
   validation above must not be mistaken for validation of the later animation candidate.
3. The ordinary screenshot fixture has no real protection registry identity. Its Purpose menu
   could be activated but did not retain a choice; that is **not a passed UI test**. The separate
   isolated-registry probe passed immediate publication/reload. Physical protection-session
   integration and a fully representative UI fixture still need checking.
4. New-layout swipe scrolling was not established through automation. Controls were reachable
   by accessibility activation. The founder's earlier scrolling confirmation applied to the
   preceding candidate, not this new layout. Recheck scrolling, focus order, VoiceOver, larger
   text and all states on the finished candidate.
5. The attempted iPhone SE launch stalled, then ended with Mach error -308 when the isolated
   simulator was shut down. No successful new SE capture is claimed. Narrow browser captures
   do not substitute for native small-device QA.
6. This pass reran the main configuration, not a new SlumberPartyQA test run. Previous main/QA
   698-test and backend evidence belongs to the inherited candidate. Physical/two-account,
   overnight protection, Apple recovery, distribution/privacy/retention and rollout gates remain.

## Next action

Follow the later motion report for final native evidence, source review and remaining
interaction/accessibility checks. Keep orchestration in this task.
Do not mark the whole implementation complete merely because the Home layout builds.
