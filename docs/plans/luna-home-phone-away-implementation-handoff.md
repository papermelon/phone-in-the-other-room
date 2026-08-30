# Luna implementation handoff — Home, Phone Away, Active session, and guidance

Prepared 2026-08-27. Select **GPT-5.6 Luna / Extra High** (`gpt-5.6-luna`, `xhigh`) in the
new thread's controls. This document does not change a thread's model or reasoning setting.

## Task

Implement all in-scope changes in `docs/plans/home-phone-away-and-guidance-review.md`, including
P0 protection repair, P0-B Purpose correctness, P1 Home consolidation, P1-B Active-page
improvements and P2 guidance/library presentation. This is an implementation task, not another
planning pass. Use the concrete recommendations as the implementation direction, including the
Active hierarchy and wording. Do not stop after the two bugs or after a visual mockup.

Resolve ordinary visual details with the existing design system. Ask only about a real product,
privacy, architecture or permission conflict. Audio/NSDR, new family account roles, remote parental
control, new experiments, backend expansion and reward rebalance remain explicitly out of scope.

## Workspace and baseline — before editing

The source project is `/Users/ngawangchime/Desktop/Developer Projects/Phone in the Other Room`.
At packet preparation it was on `codex/night-flock-mvp`, HEAD
`cce766d1840a850a23d5c47e4a542203c26a728b`, with substantial staged/unstaged/untracked work.
Those are observations, not instructions to reset or switch to that commit/branch.

Use a new thread in a worktree explicitly based on the **current working tree including local
changes**, or use the existing local checkout if the founder explicitly selects it. A default-
branch-only worktree is not a valid starting point. Verify that this packet, the full plan,
Slumber Party publication policy and all other relevant untracked source files exist. Do not
assume ignored configuration or untracked files transferred; report missing inputs without
printing secrets. Do not copy credentials or change feature flags to make validation appear green.

You are not alone in this codebase. Preserve pre-existing changes and do not revert, normalize,
overwrite, or sweep them into your own work. Do not edit another checkout from this task.
Do not spawn additional implementation agents for shared-file work.

Read AGENTS.md fully, then PROJECT_BRIEF, PRODUCT_PRINCIPLES, ARCHITECTURE,
FUTURE_AGENT_TASKS, the complete Home plan, and relevant ADRs 0012, 0014, 0016, 0017, 0018,
0019. Read the Slumber Party roadshow polish plan to preserve its existing work, not to restart it.
Follow the repository copy-review and pre-merge-review guidance; current founder decisions and
AGENTS.md take precedence over stale playbook/product wording.

Capture your actual cwd, branch/HEAD, full status (including untracked files), and baseline
tracked diff before edits. Keep a private local pre-edit snapshot of the files you will change,
including hashes, so your changes can be distinguished from inherited dirty files. Do not copy
ignored credentials. Record the snapshot location in the final handoff. Run the required baseline
XcodeGen/build checks and distinguish inherited failures from regressions you introduce.

## Verified user symptoms and implementation expectations

### 1. Phone Away protection repair

Build 33 sent Home's **Set up app protection** to the Wind Down editor. Saving Wind Down did not
authorize Screen Time. The Phone Away schedule's top button and an eligible row's play button
returned early, putting the explanation below the viewport. **Ready now** checked time eligibility
but not protection readiness. The founder successfully started Phone Away after manually using
Settings → Protection & tags → Allow → Choose apps. The core feature is not intentionally gated off.

Use one coherent protection-repair route from Home and schedule actions. Request authorization,
then obtain a non-empty app/category selection. Refresh actual authorization on return and before
preflight. Preserve the intended manual/scheduled action through repair and return to confirmation,
never auto-start just because permission was granted. If a scheduled window expired during repair,
explain it without silently substituting a manual session. Denial, cancellation, unavailable
protection and runtime failure need visible, truthful next steps.

Keep manual Phone Away accessible while idle even when an unstarted Wind Down is eligible.
Separate manual Start now from a named scheduled occurrence. Show the manual duration (existing
30-minute default, existing supported bounds, compact Change control). Anchor manual time to
actual confirmation/NFC success; scheduled sessions retain their intended end. Preserve schedules,
one-active-run behavior, automatic Wind Down reconciliation, emergency exits and NFC purpose checks.

### 2. Active Purpose correctness

Selecting Purpose currently writes App Group defaults without publishing a UI change. The label
updates only after an unrelated redraw, such as switching apps. The getter also returns the saved
cue without validating occurrence/revision/epoch, unlike the shield extension.

Make selection immediately observable on the main actor, persistent for the same valid occurrence,
and isolated across occurrences and registry versions. No polling, timer-driven defaults reads,
artificial delay or forced view recreation. Include visible failure behavior for unavailable
storage/stale identity. Update the menu's selected state and accessibility value. Keep bounded
QuietPurposeCue separate from OfflinePurposeProfile, private routines and notification consent;
do not introduce free text into App Group, social or impact data.

### 3. Home and Active layout

Home: combine Tonight/Ollie/schedule/protection/action into one Wind Down card; preserve a visible
Phone Away entry; retain one prominent list-derived Slumber Party bridge; remove duplicate generic
copy and permanent explanation. Preserve receipt, morning recovery and orientation routing/targets.

Active: preserve the journey art, but use one primary timer and remove its duplicate illustration
time badge. Make the current phase and next transition/end explicit. Use **This time is for** with
the selected purpose. App-facing menu labels may be Rest, Reading, Work, Time offline, Something
else while stored enum values remain compatible. Retain one actual protection status and reachable
exit. Include a compact noninteractive phase strip for the primary ritual when it fits; collapse
to a single clear phase line at accessibility sizes. Phone Away has no overnight progression.
Use chosen phase cues without a full source/explanation card in the live session. Remove fake
elapsed-time “clues mapped” counts from visible and accessibility text. Do not change reward rules.

### 4. Guidance/library

Implement occasional contextual, dismissible Home guidance backed by a visual browsable library.
No random tip per app open, no personal-outcome claims, no generated advice, and no new notifications.
Use one stable idea identity across onboarding/routine selection/Home/phase cue/detail. Define and
document a small deterministic eligibility/dismissal policy with injected time and persistence;
unchanged context must not immediately resurface a dismissed card. Respect disabled guidance.

Use Evening, Morning and Phone-away space as visual navigation groupings. Provide concise idea
detail, rationale and inspectable source metadata/links. Distinguish external guidance from internal
product rationale. Preserve **About these ideas and sources** as a reliable entry point. Add-to-
routine actions must use real mapped routine steps, respect three evening/two morning limits and
ask before replacing anything. Background education is not a tracked task. Verify primary-source
links and claim fidelity before shipping revised health-related content; make no clinical-review claim.

## Execution order and constraints

1. Reproduce/trace defects; introduce focused Shared policy tests where appropriate.
2. Implement protection repair and Purpose observation/identity fixes; build/test.
3. Consolidate Home and Active UI; add representative previews and perform visual checks.
4. Implement the guide/source/dismissal flow; verify persistence, source links and accessibility.
5. Update affected canonical docs/ADRs/backlog to distinguish implemented behavior from remaining QA.
6. Run full validation and produce the review handoff below. Do not omit P2 because P0 passed.

Use production models and existing design tokens. Views send intents; pure decisions belong in
Shared; side effects belong in services. Keep Codable compatibility, consented shielding, fail-open
behavior, local authority, independent Wind Down/Sunrise/Phone Away accounting, practice privacy,
V4 account binding and per-party idempotency. Preserve recent onboarding, Farm and Slumber Party work.

No new dependencies, targets, entitlements, signing/version changes, tab restructuring, production
deployment, TestFlight upload or backend mutation. Stop and obtain explicit approval if such a change
is truly necessary. Do not push, commit, amend, rebase, tag, reset, clean or publish a PR in this task.

## Verification and final deliverable

Run XcodeGen as required, generic iOS Simulator build and full unit suite with an available
simulator, plus relevant SlumberPartyQA/other existing regression checks affected by shared changes.
Preserve full logs and actual exit statuses; a successful tail/filter is not proof of build success.
Review the plan's complete matrix, including permissions, NFC, delayed confirmation, cancellation,
double taps, schedule expiry/collision, Purpose without backgrounding, cross-session identity,
morning/deferred/receipt routing, VoiceOver, large Dynamic Type, Reduce Motion and light/dark.

Use available simulator/screenbook tooling for UI evidence. Family Controls, NFC and two-account
physical-device behavior require actual device evidence; never equate pure tests or screenshots
with those checks. When unavailable, supply an ordered human checklist and mark it unverified.

Write `docs/plans/home-phone-away-implementation-report.md` containing:

- Exact thread identity if available, cwd/worktree, start/final HEAD and dirty status.
- Pre-edit snapshot location and a clear list of inherited versus newly changed files/hunks.
- P0/P0-B/P1/P1-B/P2 acceptance checklist with evidence, not blanket completion assertions.
- Exact build/test commands, exit results, log/result-bundle paths and UI screenshot paths.
- Any design details settled during implementation, remaining risks and precise physical QA steps.
- Any blocked/incomplete criteria and why; do not mark the whole task done if required work remains.

Finish with a concise handoff for Sol High. Do not merge/copy the worktree into the original
checkout or claim the forthcoming independent review has passed. If Sol finds a defect, corrections
should continue in this same implementation thread against the same worktree and report.
