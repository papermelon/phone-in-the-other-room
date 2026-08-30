# Counting Sheep — recent candidate review

## Membership-sharing follow-on — 2026-08-28

The founder approved sharing from joining, with seven-night rounds organizing progress/rewards.
That extension is now implemented and independently reviewed in this task. **Verdict: SHIP local
source; HOLD distribution.** Main and QA builds pass with **698 tests each**, the actual app recovery
probe passes **15 cases**, the real PostgreSQL migration and all **three SQL suites** pass, and
Deno **20** / Screenbook Python **7** tests pass. The fresh reviewer found no remaining source blocker.

After the founder unlocked the Mac, the parent checked the same final binary: nested manual and
saved Phone Away starts both reveal Active immediately; no-round/between-round group navigation,
additional history, old round history, received cheers and live-cheer menu access pass. No-round
group/history controls also pass at accessibility-extra-large text and on iPhone SE. These are
fixture-backed interaction checks, not physical protection or remote delivery proof.

**Remaining interaction gap:** direct swipe/wheel attempts did not move the page. Accessibility
activation brings offscreen controls into view, but that is not ordinary scrolling. The parent
requested a manual scroll check; no result is recorded yet. This supersedes an earlier commentary
that incorrectly called scrolling passed. Hosted deployment, real two-account/device QA, retention
operations and privacy-policy publication remain release gates. No phone build was updated.
Full contract, preserved failed checks, final manifest and evidence:
`slumber-party-membership-sharing.md`. The recovery review below remains the historical record
for the broader August candidate; its older pending sharing decision is superseded by this approval.

The unlocked-Mac follow-up evidence is `/tmp/counting-sheep-ui-checks-20260828/`; see the membership
plan's interaction addendum for individual files. No application source changed during these checks.

## Recovery review — 2026-08-27, current task

**Verdict: SHIP for the reviewed local source candidate; HOLD TestFlight/production release
until the verification gates below pass. Risk: L (core session/protection/persistence).**
No confirmed blocking source defect remains in the bounded independent re-review. The report
below this section is the historical pre-correction review, not a verdict on the later candidate.
The founder subsequently authorized implementation orchestrated in this task and explicitly
rejected another Luna handoff. No further changes were dispatched to that task.

### Candidate and delivery diagnosis

The candidate remains the saved local checkout on `codex/night-flock-mvp`, HEAD
`cce766d1840a850a23d5c47e4a542203c26a728b`, including the August 25–26 commits from base
`407a4861c46e403ce78faa9f71f239e11d574a32`, inherited uncommitted work, Luna's implementation
and subsequent corrections, and this recovery. The new evidence directory is
`/tmp/counting-sheep-home-social-recovery-20260827/`. Its baseline hashes and reconstructed
baseline files distinguish this recovery from the inherited candidate.

The failure was not simply a model failing to follow a sufficient specification. The earlier
handoff constrained Slumber Party to a subordinate, list-only Home bridge; consolidation kept
duplicated content inside a larger card; and build/domain-test success was used without the
visual and navigation acceptance needed for the promised experience. The parent owns those
specification and acceptance failures. `home-social-recovery.md` supersedes that scope with a
core invite-only social surface, a compact personal ritual, and explicit executable checks.

### Additional defects reproduced during recovery

| Priority | Finding | Evidence / correction now implemented |
|---|---|---|
| P1 | Successful manual start clears newly installed protection and Purpose identity | The inherited F4 reorder calls `cancelAutomaticSchedule` after coordinator admission. Cleanup targets the current shared store/snapshot. Move old automatic cleanup inside admitted start, before installing the new run; rejected starts must not clear the existing barrier. |
| P1 | A partial monitoring installation can reapply protection after reporting failure | Snapshot/registry publication precedes multiple registrations. A later throw formerly cleared only the store, retaining callback authority. Roll back attempt-owned registrations and tombstone the failed occurrence; test delayed callbacks and unrelated entries. |
| P1 | Nested Phone Away start leaves the schedule above Active | Parent actual taps reproduced Home → Plan → saved row → confirmation → still on schedule, while the row was consumed. A reset token and then a lifted binding both failed retest. Destination registrations must remain on the stable Home shell through the Dashboard-to-Active switch. |
| P2 | Terminal replay can duplicate a nonqualifying Wind Down consolation reward | The terminal journal originally persisted reward/progress plans only for entitled Wind Down. A crash after consolation projection but before completion could mint a second random reward. Persist every journalled terminal projection and test the partial-write replay. |
| P2 | Earlier practice attempts can enter late-join social backfill | The single orientation practice UUID is overwritten. Persist explicit practice provenance on new history records; omit ambiguous legacy Phone Away history rather than inventing non-practice status. |
| P2 | Social display and response-order races retain stale status | The detail Timeline initially rendered at a future expiry; Home froze its display date; cache freshness compared request start against another response's completion. Use a present-time initial render, re-anchor on new canonical data/foreground, and independent monotonically issued request ordering. |
| P2 | Terminal Morning recovery could restore an already elapsed deferred barrier | The real coordinator probe reproduced expired-window shielding projection. Historical timestamps now remain settlement facts while current eligibility governs resources. |
| P2 | Short-monitor warning precision could clear late | Fractional desired ends and independently rounded warning leads could fire before the actual desired end and leave protection until the padded end. Whole-second-safe registration and warning calculations preserve the desired interval; physical callbacks still require device QA. |
| P2 | Active Morning can hide failed protection after terminal receipt reset or cold restore | Occurrence outcomes were discarded. Record resource-scoped failures, preserve the active failure through reset, reconcile cold-active restore, and retry that Morning. Final production-intent probes cover failure, reset, retry and unrelated success. |

### Final local validation — frozen r3 candidate

The frozen manifest is `candidate-r3-hashes.json`, **874 paths**, SHA-256
`9379b0ead35c24687fce169a25dcba2f916074866ba58122a767aca5faa37bca`.
Every manifest path remained unchanged through the final gates and interaction retest. The
recovery changes 44 paths relative to its preserved start baseline (including documentation,
generated project and test harness), rather than replacing or resetting the inherited work.
Only report/backlog documentation is updated after that freeze.

All commands ran in the exact candidate checkout and their real exit codes were checked.
Evidence below is relative to `/tmp/counting-sheep-home-social-recovery-20260827/`.

| Check | Final result | Evidence |
|---|---|---|
| XcodeGen | Exit 0 | `xcodegen-candidate-r3.log` |
| Generic iOS Simulator build, including embedded targets | Exit 0, BUILD SUCCEEDED | `build-candidate-r3.log` |
| Main scheme full unit suite, iPhone 17e / iOS 26.5 | **690 tests, 0 failures** | `test-candidate-r3.log`, `tests-candidate-r3.xcresult` |
| Slumber Party QA configuration | Exit 0 | `qa-configuration-candidate-r3.log` |
| SlumberPartyQA build | Exit 0, BUILD SUCCEEDED | `qa-build-candidate-r3.log` |
| SlumberPartyQA full unit suite | **690 tests, 0 failures** (same suite in the QA configuration) | `qa-test-candidate-r3.log`, `qa-tests-candidate-r3.xcresult` |
| Actual app/coordinator/service recovery probes | **15 cases, all pass** | `recovery-probe-r3.json` |
| Deno function type check | Exit 0 | `deno-check-r3.log` |
| Deno shared/backend tests | **19 passed, 0 failed** | `deno-test-r3.log` |
| Python Screenbook tests | **7 passed** | `screenbook-python-r3-corrected.log` |
| Whitespace/conflict check | `git diff --check`, exit 0 | Parent rerun after source freeze |

`validation-candidate-r3-results.json` retains the exact Xcode commands and outcomes. iPhone 15
is unavailable; the installed iPhone 17e was used. The first Python rerun used the parent
folder and discovered zero tests (exit 5); it was not counted as a pass. Correcting discovery
to `scripts/screenbook/tests` ran all seven. Earlier compile, assertion and interaction failures
are retained in the evidence folder; none substitutes for these final results.

The 15 runtime cases exercise production coordinator/VM intents with isolated persistence and
explicit dependencies: ordinary early exit and partial-Morning replay, consumed decisions,
explicit Morning handoff/expired deferral, unauthorized NFC refusal, manual admission with/without
prior automatic protection, rejected admission preservation, immediate Purpose publication and
reload, nonqualifying terminal reward replay, partial monitor rollback, active-Morning failure
surviving receipt reset and repairing on retry, unrelated-success isolation, and cold active
Morning restore. Monitor rollback runs the actual installer with injected registration failures,
not a second implementation of its algorithm. These are **not physical ManagedSettings/NFC tests**.

### Actual interaction and visual evidence

- Parent taps on the final r3 binary: **Home → Plan → saved Phone Away → Start → Active**,
  without Back, tab change or leaving the app. See `final-ui/saved-start-r3-pass.png` and
  `saved-start-r3-ax.txt`. Active accessibility now correctly says Phone Away.
- Parent taps on r2: **nested manual Start now → Active**, and **Not now → same schedule with
  saved occurrence retained**. See `final-ui/manual-start-stable-shell-pass.png`,
  `manual-start-ax.txt`, and `manual-cancel-ax.txt`. The navigation implementation is unchanged
  between r2 and r3; the saved path was repeated on r3.
- Parent taps on r3: **Home → Open group** preserves Moss's live Phone Away label and the
  eligible cheer control. See `final-ui/social-detail-r3.png` and `social-detail-r3-ax.txt`.
  This retest caught and then verified the correction to the future-expiry initial render.
- Home composition was personally inspected in light/dark, on the smaller SE and at large
  accessibility text; final standard-dark capture is `final-ui/home-r3-full.png`. The summary
  uses separate readable times and a proportionate mascot; the social section uses people and
  factual activity. This is not complete accessibility acceptance: lower sections, every state
  and all small-device interactions still need coverage.

The interactive fixture uses the production navigation and start intents but substitutes unavailable
Screen Time readiness and social transport, fixes its clock, and supplies synthetic members.
Its “ready / None selected” combination is a fixture seam, not proof that a real empty selection
can start. A missing shield status strip in these Active fixtures is likewise not physical proof.
Purpose's actual setter/publication/reload is covered by the isolated identity-seeded runtime
probe; real-device menu selection and natural phase transitions remain a physical check.

### Remaining release gates and product decision

These are verification gaps or pending decisions, **not additional confirmed source defects**:

1. **P1 release gate — protection on a physical phone:** grant/deny/revoke/repair; 5/10/15/30-minute
   sessions and late saved-window starts; exact shield removal while backgrounded/terminated;
   NFC cancel/wrong/retired/replacement tags; emergency exits; ordinary/explicit Morning finishes
   and restart; overnight, DST/time-zone, Watch and Live Activity behavior. A padded valid monitor
   plus warning callback is code-tested, but platform callback delivery is not established here.
2. **P1 release gate — real two-account social/recovery:** verify current-member cache freshness,
   terminal-status clearing, expiry, reconnect, queued revision ordering, cheers, late-join
   backfill and independent per-party grants; Apple expected-account recovery, cancellation and
   account-scoped queue quarantine. SQL/pgTAP has not run against a database, and no production
   backend state/deployment was inspected or altered during this recovery.
3. **P2 product acceptance — social life between rounds:** existing v4 still requires an active
   seven-night round for shared sessions. This can leave a joined group waiting even with the
   improved UI. Recommend sharing from joining, with rounds organizing progress/rewards, but
   obtain explicit approval and define compatibility/retention before changing that contract.
   No private Purpose, routines, exact schedules, app selections, Health or full Farm data was
   added to uploads. Ambiguous legacy Phone Away history is conservatively omitted from backfill
   so earlier practice attempts cannot be mistaken for eligible shared activity.
4. **Release/experience coverage:** full fresh-install/resume onboarding, real Farm gestures and
   accessibility, all Home states/small screens, signed archive/distribution entitlements,
   privacy publication and moderation/retention operations remain unverified. No upload or
   TestFlight build was produced by this recovery.

### Independent acceptance and preservation

A fresh, behaviorally read-only Sol advisor reviewed the accumulated August candidate and then
re-reviewed the bounded corrections against the frozen r3 manifest. Its final verdict was
**SHIP the reviewed local source candidate**, explicitly excluding TestFlight/production approval.
It independently checked the source, manifest, saved parent-run test/probe outputs and screenshots;
it did not claim to have performed the parent's taps or physical-device tests. The parent concurs
that there is no remaining confirmed source blocker in that reviewed scope, while withholding
release acceptance and complete social-product acceptance for the listed gates/decision.

After source verification, only this report, the recovery plan and backlog status were updated.
The source manifest still identifies the tested application. Existing uncommitted work is retained;
no fixes were sent to Luna, no commit/reset/push occurred, and no production account, deployment,
entitlement, signing, tab structure or installed user-phone build was changed. The old review and
correction prompt below are historical evidence, not instructions to dispatch another task.

### Review coverage and boundaries

A fresh Sol advisor inspected the accumulated candidate, including Home/Active, protection/NFC,
onboarding and gift/draft guidance, Farm gesture/lifecycle and grant settlement, Slumber Party
publication/outbox/cache/status/cheers and server contracts, Apple recovery binding/quarantine,
and independent Wind Down/Morning/Phone Away rewards. No additional confirmed Apple account,
Farm ownership, welcome-gift, or independent sheep-grant defect was established in that pass.
This is a risk-focused review, not an exhaustive audit of every changed line or collateral asset.
The advisor was behaviorally read-only; this host's unrestricted filesystem permissions do not
provide OS-enforced read-only isolation. Parent runs the builds, probes and UI checks.

Seven-night rounds still gate shared activity. Making parties active from joining, with rounds
organizing progress instead of gating sharing, is a pending founder decision. No new private
data upload, backend deployment, tab restructuring, commit, push, signing change, or distribution
was performed by this recovery.

## Historical review — before Luna's corrections and this recovery

Date: 2026-08-27. Verdict: **FIX-FIRST**. Pre-merge result: request changes; risk **L**.

The personal ritual / Slumber Party bridge / contextual guidance direction does not need a rethink. The candidate needs corrections before acceptance. Green builds and domain tests do not cover several broken production integrations below. This is not TestFlight or public-release approval.

## Prioritized findings

### F1 — P1: A normal Wind Down routes Home away from its active session

**Location:** `Shared/HomeReceiptRouting.swift:26–36`; integration at `PhoneInTheOtherRoomApp/Views/HomeView.swift:389–405` and `PhoneInTheOtherRoomApp/Proximity/FocusSessionCoordinator.swift:946–972`.

**Origin:** inherited August 25 release batch, present before Luna.

Starting an ordinary primary Wind Down immediately persists its usual morning as a `.scheduled` occurrence. The router treats every scheduled morning as a deliberately deferred morning and returns that route *before* checking the running Wind Down. Home consequently renders the deferred-morning card and idle dashboard instead of `ActiveRunView`. The timer, Purpose, and normal/emergency exit controls disappear from Home even though the run and protection continue. Home also treats this as a screen that owns its scrolling, while the dashboard branch does not.

**Verification:** an independent executable using the actual candidate reducer returned `deferredScreenFreeMorning` for a running session with its own scheduled morning. The existing active Screenbook fixture assigns `coordinator.run` directly (`ScreenbookFixtures.swift:57`); it never performs the production start that creates the morning, so its good-looking capture misses this defect.

**Correction:** distinguish a future morning belonging to the current live run from a morning explicitly deferred after terminal Wind Down. Keep the live session reachable before future-morning dashboard content. Cover ordinary start, explicit defer, Phone Away during a deferred window, terminal receipt priority, and actual Home scrolling/navigation.

### F2 — P1: Finishing an ordinary Screen-Free Morning leaves its parent barrier running

**Location:** `PhoneInTheOtherRoomApp/Proximity/FocusSessionCoordinator.swift:654–677`; `PhoneInTheOtherRoomApp/Services/QuietTimeShieldingService.swift:203–245`.

**Origin:** inherited August 25 release batch.

Let a normal Wind Down reach its usual wake time, then press **Finish Screen-Free Morning** before the configured end. The method marks only the morning occurrence finished and clears only its registry entry. The still-running parent Wind Down remains registered through `protectedUntil`. Registry cleanup explicitly keeps protection applied when that parent remains. Home can return to an active Wind Down, and selected apps stay limited after the user finished the morning.

**Verification:** the candidate's cleanup policy returned `keepShielded` with the parent entry for this exact pair of overlapping intervals. The actual coordinator finish method does not terminate/handoff that parent. This is code/policy reproduction, not a physical ManagedSettings observation.

**Correction:** coordinate the ordinary linked-parent terminal path and the independent morning finish path using existing authorization rules. Finishing must not leave the same ritual's barrier behind or settle Wind Down twice. Preserve unrelated future schedules, explicit deferred mornings, NFC/emergency authorization, and actual elapsed Sunrise minutes. Also test ordinary early/emergency Wind Down exit before wake: the current method leaves its scheduled morning in the journal, and foreground reconciliation can activate it later. Resolve that behavior explicitly rather than conflating it with the user's **defer** choice.

### F3 — P1: Offered short Phone Away/practice durations cannot use the installed monitoring schedule

**Location:** `PhoneInTheOtherRoomApp/Services/QuietTimeShieldingService.swift:675–707`; new choices at `Shared/PhoneAwayStartPolicy.swift:41–45`.

**Origin:** inherited scheduling defect, newly exposed more broadly by Luna's 5/10/15-minute manual choices. Five-minute onboarding practice and late starts in saved windows also use this path.

The monitor is registered from `max(interval.start, now + 1 second)` to the actual short session end, with no platform minimum handling. Apple documents a **15-minute minimum monitoring interval**; 5 and 10 minutes violate it, and the extra second also makes an exactly 15-minute immediate interval too short. The throwing registration is caught as monitoring failure, which clears shielding while the already-created timer continues. A picker-ready state therefore does not mean these offered sessions can start with working protection. [Apple: intervalTooShort](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/monitoringerror/intervaltooshort).

**Verification:** actual schedule construction and error path inspected against Apple's platform contract. No claim that this was reproduced with Family Controls on a physical phone.

**Correction:** implement and device-verify a platform-valid short-session monitoring strategy that preserves the exact consented shield end, or bring an explicit duration/product decision back to the founder. Do not silently lengthen shielding, remove the five-minute practice promise, or describe a failed barrier as ready. Cover 5/10/15/30 minutes, delayed confirmation, and a saved window with less than 15 minutes left.

### F4 — P1: Final confirmation can replace a run that started while the sheet was open

**Location:** `PhoneInTheOtherRoomApp/ViewModels/FocusRunViewModel.swift:1159–1167`; `PhoneInTheOtherRoomApp/Proximity/FocusSessionCoordinator.swift:140–145`.

**Origin:** inherited commit-boundary defect, still present in Luna's revised start transaction.

Open a manual Phone Away confirmation before an opted-in automatic Wind Down, background the app across that automatic start, then return and confirm the still-pending action. Foreground reconciliation can create the automatic run, but final confirmation checks only pending-plan/in-flight/readiness state. `coordinator.start` rejects an active morning but does not reject an active run; it resets the current run and installs the new one. The existing ritual can be replaced without its authorized terminal action or receipt. Conversely, if a morning became active, coordinator start silently returns while the caller continues consuming its saved source and scheduling notifications.

**Verification:** traced Home's sheet lifetime, app foreground reconciliation, final-confirmation side effects, and coordinator admission. This interleaving was not exercised through the GUI.

**Correction:** revalidate authoritative run/morning ownership immediately before *any* commit side effects, including after NFC callbacks. Make coordinator admission return a result; consume the occurrence and publish/schedule only after success. Cancel or explain stale confirmations without replacing the active session. Add a race regression, not only another pure preflight assertion.

### F5 — P2: An old Slumber Party acknowledgement deletes a newer queued status

**Location:** `PhoneInTheOtherRoomApp/Services/NightFlockOutboxService.swift:154–156`; caller `PhoneInTheOtherRoomApp/ViewModels/NightFlockViewModel+V4.swift:436–448`.

**Origin:** inherited August 25 V4 implementation, unchanged by Luna.

While revision 1 (`windDownStarting`) is in flight, revision 2 (`phoneAwayActive`) can replace it in the durable outbox. A successful response for revision 1 removes *all* status records with that source ID, including revision 2. A failed/interrupted concurrent send of revision 2 then has nothing durable to retry. This can leave members seeing a starting status instead of the newer active state. Account-generation fencing does not distinguish revisions within one account.

**Verification:** independent executable compiled the actual `NightFlockOutboxService` and Shared models. After enqueue rev1 → capture sent record → enqueue rev2 → acknowledge rev1, remaining queued records were **0**.

**Correction:** acknowledge/remove the exact sent revision/idempotency identity, leaving a replacement queued. Serialize/coalesce drains as appropriate and check the source-activity lane's equivalent remove-by-ID behavior. Test delayed acknowledgement, concurrent flush, newer enqueue, failure, and restart.

### F6 — P2: Cached Purpose does not refresh at automatic morning identity changes

**Location:** `PhoneInTheOtherRoomApp/ViewModels/FocusRunViewModel.swift:466–504`; boundary path `PhoneInTheOtherRoomApp/Proximity/FocusSessionCoordinator.swift:683–731`.

**Origin:** Luna's new observable cache fixes same-menu selection, but occurrence-transition integration is incomplete.

Choose a Purpose during Wind Down and leave the app foregrounded into the usual morning boundary. The coordinator changes the morning occurrence to `.active`; `currentPurposeCueIdentity` now resolves the morning UUID, but no reload is called by that boundary. Coordinator forwarding only sends `objectWillChange`, which does not recompute the stored `@Published currentPurposeCue`. The morning view can display/check the previous Wind Down cue until another explicit reload or selection. The shield extension correctly rejects the old identity, so the two surfaces disagree.

**Verification:** inspected every reload call and the natural morning timer/restore paths. Same-menu publication is present; interactive menu selection and this transition remain unobserved on device.

**Correction:** publish/reconcile Purpose from actual occurrence and registry-identity transitions, after committed state changes. Cover natural morning start/end, early-wake choices, same-session restore, replacement revision/epoch, and missing App Group storage. Do not add timer polling or broaden the private cue payload.

### F7 — P2: Removing the Active explainer also removed the chosen-routine experience

**Location:** `PhoneInTheOtherRoomApp/Views/ActiveRunView.swift:152–203`; related `PhoneInTheOtherRoomApp/Views/ScreenFreeMorningView.swift:13–97`.

**Origin:** Luna removed the previous active guidance card but did not implement its planned replacement.

The production Night Watch branch shows the scene, generic heading/time, Purpose, protection and exit, but never the selected evening/morning routine. `phoneFreeCue` remains in the *other* branch and itself requires a Night Watch plan, so it does not restore this behavior. The separate morning screen also omits the selected morning sequence. Onboarding's promise to bring back the private choices at Wind Down is therefore not carried through.

**Verification:** code branch inspection plus the newly captured active Wind Down screen. The full source/explainer card is correctly gone, but there is no selected routine cue in its place.

**Correction:** render the selected optional sequence for the appropriate primary phase, distinct from this-session Purpose. No source navigation, completion controls, overnight prompt or bedtime checklist in Phone Away. Preserve the active run's frozen choices rather than reading subsequently edited future preferences.

### F8 — P2: Home guidance is still a permanent explanation until manually dismissed

**Location:** `PhoneInTheOtherRoomApp/ViewModels/FocusRunViewModel.swift:511–527`; `PhoneInTheOtherRoomApp/Views/Components/WindDownGuideCard.swift:15–36`.

**Origin:** incomplete Luna guidance refinement.

For any configured routine with a matching idea, every idle Home visit returns the same first evening/morning item. Only dismissal suppresses it; there is no shown-state/context opportunity policy. The **WHY THIS MAY HELP** framing and full explanation remain, as the fresh Home capture shows. Dismissal adds a seven-day stored cooldown, but an in-memory ID set suppresses that item indefinitely until the view model is recreated. The tip's source link also opens the full index instead of its own idea detail.

**Correction:** finish the approved occasional/contextual behavior with an explicit, testable display policy and consistent persisted/in-memory suppression. No random advice feed is needed. Deep-link a displayed tip to its own detail and keep the full library reachable separately. Reframe the Home surface as a compact optional idea. The seven-day choice is an implementation assumption, not a founder-approved requirement.

### F9 — P2: Several library “Add” actions substitute an unrelated routine activity

**Location:** `Shared/WindDownGuidanceSources.swift:158–167`; `PhoneInTheOtherRoomApp/ViewModels/FocusRunViewModel.swift:530–568`.

**Origin:** new Luna source-library integration.

For example, **Try an earlier caffeine cutoff** adds **Prepare tomorrow’s clothes or bag**, and **Leave room after a heavy meal** adds **Make a caffeine-free warm drink**. These are not the idea the user selected. The guidance ID is then attached to the substituted action, affecting later contextual selection. Shared-activity duplicate detection can also claim an idea is already added merely because another idea maps to the same activity.

**Correction:** offer Add only for an honest, supported mapping; leave general background guidance browsable without an Add action, as the handoff specifies. If a new concrete routine activity is wanted, obtain that product decision rather than inventing a substitute. Test actual persisted titles/IDs and duplicate/replacement behavior. Also connect the library to the onboarding draft when entered there: the new detail action currently targets saved preferences (or is unavailable before configuration), while onboarding edits a separate draft.

### F10 — P2: The compact Home mascot overflows its header

**Location:** `PhoneInTheOtherRoomApp/Views/PixelHomeDashboard.swift:273–274`; fixed child size in `PhoneInTheOtherRoomApp/Views/Components/OllieRitualView.swift:109–120`.

**Origin:** new Luna Home layout.

The parent proposes 54×54, but `.cardCompanion` fixes its own canvas at 164×164. An outer SwiftUI frame does not scale that child. Ollie consequently spills above/outside the Home card and is clipped by the top viewport; this is visible at standard text size in the fresh iPhone 17 Home capture. The multiline schedule/header is also much taller than the intended compact summary.

**Correction:** use an appropriately sized component presentation or make the asset honor the compact canvas; do not just clip away the dog. Verify the Home card at standard/accessibility text sizes and on a smaller iPhone. Keep essential CTA text readable; the captured repair CTA subtitle is already truncated.

## Candidate and scope

- Implementation task located and confirmed idle: **Implement Home Phone Away handoff**, `01a04229-4396-7362-8429-66dff77bc4bf`, host `local`.
- Report located first: `docs/plans/home-phone-away-implementation-report.md`.
- Actual candidate: `/Users/ngawangchime/Desktop/Developer Projects/Phone in the Other Room` — the saved local checkout, not one of the other detached worktrees.
- Branch: `codex/night-flock-mvp`.
- HEAD: `cce766d1840a850a23d5c47e4a542203c26a728b`.
- Verified ancestor/base: `407a4861c46e403ce78faa9f71f239e11d574a32`.
- Included commits: `ae4a9a0` (Aug 25 release batch), `827f5a2` (Aug 25 Farm pasture), `dcff101` (Aug 26 TestFlight/onboarding), `cce766d` (Aug 26 Apple recovery).
- Also included all inherited dirty/untracked work and Luna's uncommitted implementation. Base-to-working-copy inventory: **279 tracked changed paths + 10 untracked files** before this review report. The two files removed in inherited pasture work were also checked against Luna's pre-edit inventory, even though their add-then-delete lifecycle disappears from the broad base diff.
- Luna's pre-edit snapshot: `/tmp/counting-sheep-home-phone-away-preedit.EGiLPm`. Compared candidate files against that snapshot, falling back to HEAD for paths clean before Luna. The review is not limited to Luna's 25 changed/new paths.
- Exact review fingerprint: SHA-256 of `before-hashes.json` is `eba7775f766ecb73b8b86401dadf4b5260a1e1b12896ddcba8ccbbdf5ec78437`.
- Build 33 was the founder's symptom report, not an independently verified tag or this candidate's binary identity.

Review evidence is under `/tmp/counting-sheep-sol-review-20260827/`: full before hashes, status, base-to-candidate binary patch, complete inventory/numstat, Luna-origin inventory, logs, result bundles, and probes. Temporary evidence is not a substitute for retaining this report with the candidate.

## Coverage and limits

This was a broad, risk-focused review of all requested subsystems, with deeper tracing at session/protection/settlement and account/outbox boundaries. It was not an exhaustive line-by-line audit of every changed file or visual inspection of every asset.

| Area | Independently inspected | Result / remaining gap |
|---|---|---|
| Home, start, scheduling | Dashboard and root routing; source-specific eligibility; direct picker repair; manual re-anchoring; confirm/cancel/NFC commit; automatic foreground path | Original Wind Down-editor misroute is removed. F1/F4 remain. Picker denial/retry/expiry and actual tap-through require device/interactive proof. |
| Active and Purpose | Production view branches; observable cue publication and registry identity; natural/explicit morning transitions; scene labels | F6/F7. Same-menu setter now publishes immediately. Screenbook is static and has no real App Group cue identity. |
| Protection and NFC | Consented selection path; monitoring registration/clear; registry/tombstones; shield cue matching; NFC inspection/write-before-commit and retired-tag policy | F2/F3. No token-boundary widening found in examined paths. Real authorization, monitor callbacks, tag writes and failure recovery unverified. |
| Independent settlement | Coordinator finish/restore; hidden Wind Down entitlement/delivery; factual bookend credit; Sunrise reducer/projection markers; Phone Away and practice reducers; receipt priority | Existing tests pass; F1/F2 expose integration gaps. No additional deterministic reward-duplication defect established. Crash-point/device tests remain required. |
| Onboarding | Two-page intro; six explicit-answer questions; skip/resume; welcome claim/wear/keep path; draft application; manual-start defaults; routine editor/guide wiring | First welcome screen inspected. Practice affected by F3; new library draft integration needs correction/coverage under F9. Full fresh-install/relaunch journey not exercised. |
| Farm | Inherited tap/long-press/drag controller; cancellation/persisted positions; Reduce Motion/active-run suppression; ownership/wool/Shop paths; V4 grant-to-Farm transaction keys | Populated Farm visually inspected; tests pass. No additional confirmed Farm defect. Real gesture arbitration, interrupted drags, accessibility actions and multi-pasture interaction unverified. |
| Slumber Party V4 | Publication/practice exclusion, list/member/detail presentation derivations, outbox, grant adapter and idempotency, realtime refresh, Home routing | F5. Production two-account/realtime/cheer/backfill flows not exercised. No active-session social UI intentionally added; F1 can nevertheless expose the idle dashboard during a run. |
| Apple recovery | Expected UUID binding; anonymous-link-first/existing-account path; local social generation quarantine; stale callback handling; legacy/schema boundaries | No additional confirmed identity-switch defect found in examined paths. Provider/reentrancy/cancellation and two-account recovery not integration-tested by the Shared suite. |
| Server contracts | V4 activity fan-out/grants/status expiry; auth caller derivation; service-only functions/RLS/fence; invitation redaction/encryption boundaries; Deno tests | Type check + 19 tests pass. SQL/pgTAP not executed against a database; no live backend state or deployment inspected/changed. |
| Release surfaces | Changed project configuration/entitlement delta; Watch and Live Activity morning transport/priority; notification call sites; resource inclusion | Generic and QA schemes build. No signed archive/distribution entitlement proof, paired Watch, physical overnight, DST/time-zone travel, or public privacy/operations sign-off. |
| Low-risk collateral | Complete inventory includes 46 asset/collateral/output paths and 3 agent configuration files | Runtime asset integration built; selected rendered screens inspected. Printed PDFs, all art variants and agent configuration semantics were not exhaustively reviewed. |

## Independent validation

All commands ran in the candidate cwd. Shells captured the command exit status directly; log tails did not determine success.

| Command / check | Actual result | Evidence under review directory unless noted |
|---|---|---|
| `xcodegen generate` | Success; **no candidate file content changed** | `project-before.pbxproj`, `before-hashes.json`, `validation-content-delta.json` |
| `xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator'` | Exit 0, BUILD SUCCEEDED | `build.log`, `build.exit` |
| `xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,name=iPhone 17e' -resultBundlePath /tmp/counting-sheep-sol-review-20260827/tests.xcresult` | Exit 0, **664 tests / 0 failures** | `test.log`, `tests.xcresult` |
| `sh scripts/validate-slumber-party-qa.sh` | Exit 0; QA and Release flag YES, QA compiler condition correctly scoped | `slumber-validation.log` |
| `xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoomSlumberPartyQA -configuration SlumberPartyQA -destination 'generic/platform=iOS Simulator'` | Exit 0, BUILD SUCCEEDED | `qa-build.log` |
| `xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoomSlumberPartyQA -destination 'platform=iOS Simulator,name=iPhone 17e' -resultBundlePath /tmp/counting-sheep-sol-review-20260827/qa-tests.xcresult` | Exit 0, **664 tests / 0 failures** | `qa-test.log`, `qa-tests.xcresult` |
| `npx --yes deno check supabase/functions/night-flock-command/index.ts supabase/functions/night-flock-state/index.ts` | Exit 0 | `deno-check.log` |
| `npx --yes deno test --allow-env supabase/functions/_shared/night-flock_test.ts` | Exit 0, **19 passed / 0 failed** | `deno-test.log` |
| `python3 scripts/screenbook/screenbook.py doctor`, `capture --all`, `verify` | Success; **5 fresh captures**, verify PASS | `screenbook-*.log`; `tmp/screenbook/current/manifest.json` |
| Independent compiled probe against candidate Shared + actual outbox service | F1 route, F2 cleanup policy and F5 queue loss reproduced | `ReviewProbe.swift`, `probe-build.log`, `probe-results.txt` |
| `git diff --check` | Exit 0 | Rechecked before report delivery |

The iPhone 15 requested by the canonical command is not installed. Tests used iPhone 17e UUID `71CF8F3E-9E9A-449D-93A8-B73F64869A5E`, iOS 26.5. Xcode 26.6 / XcodeGen 2.45.4. Screenbook created/used its dedicated iPhone 17 simulator and isolated DerivedData, without touching user simulator data.

The temporary macOS probe excluded the unrelated iOS-only `FocusRunLiveActivity.swift`; an initial attempt including it failed on ActivityKit's macOS unavailability. The final compile and executable succeeded. No substitute implementation of the tested reducer/service was used.

### UI evidence

Fresh screenshots were opened and inspected for all five existing scenarios:

- `tmp/screenbook/current/screens/iphone.onboarding.welcome.default.png`
- `tmp/screenbook/current/screens/iphone.home.configured.default.png`
- `tmp/screenbook/current/screens/iphone.home.active-wind-down.default.png`
- `tmp/screenbook/current/screens/iphone.home.early-end.default.png`
- `tmp/screenbook/current/screens/iphone.farm.populated.default.png`

Manifest hash: `57f193bc7636162b1e83c2be9dd3abfcc5996a2744c402c8304549d8239dc2c3`.

Computer Use could not obtain a Simulator app window (`noWindowsAvailable`). Automated Screenbook capture succeeded independently of that GUI limitation. No interactive Purpose/picker/drag success is claimed. The fixture's active run bypasses real start side effects, and its protection/social services are fixtures, so these images cannot clear F1–F6 or physical release gates. Only standard light-mode iPhone 17 captures were personally inspected; no dark mode, small-phone or accessibility-size screenshot pass was completed.

## Ship gates and correction handoff

1. Correct F1–F4 before another candidate is accepted. Add production-boundary coverage, particularly ordinary morning ownership and final start admission.
2. Correct F5–F10 to finish the approved implementation scope. Re-run the complete build/test gates and affected server/QA checks; capture the new Home/Active and real start flows.
3. Physically verify Family Controls grant/deny/revoke/repair, short sessions, saved-window expiry during repair, NFC cancel/wrong/retired/replacement tags, emergency exits, foreground/background/termination and overnight restore, and morning finishes. Verify Purpose immediately without switching apps and across the natural morning boundary.
4. Run the documented Slumber Party two-account matrix, including expected-account Apple recovery, failure/cancellation, backfill, fixed cheers, reconnect, duplicate/out-of-order status and independent per-party rewards. Keep SQL/pgTAP and signed archive/distribution/operations/privacy checks as explicit remaining gates.

All physical tests above are **unverified for this exact candidate**. The founder's build-33 workaround success is earlier evidence, not candidate verification. No live account, backend, production data, signing configuration, push, commit, deployment or upload was changed in this review.

Final content comparison (`final-review-content-delta.json`) found **zero changes to pre-existing files**. Only this report and the correction prompt were added; final Git status is retained in `status-after-review.txt`.

Prepared correction prompt: `docs/plans/luna-recent-changes-corrections.md`. Destination remains **Implement Home Phone Away handoff** (`01a04229-4396-7362-8429-66dff77bc4bf`). **Not sent.** Corrections need a new review against the changed candidate; this report never implies approval of a later diff.
