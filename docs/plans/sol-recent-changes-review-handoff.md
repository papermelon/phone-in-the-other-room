# Sol High review handoff — Counting Sheep recent changes

Prepared 2026-08-27. Run after Luna completes the implementation packet. Select **GPT-5.6 Sol /
High** (`gpt-5.6-sol`, `high`) in this planning/review thread's controls. Text alone does not switch
the model. Do not start reviewing unfinished moving code.

## Task and source of truth

Review the actual code and all recent integrated changes, not only Luna's summary or last diff.
Use `docs/plans/home-phone-away-and-guidance-review.md`,
`docs/plans/luna-home-phone-away-implementation-handoff.md`, and Luna's
`docs/plans/home-phone-away-implementation-report.md` as the scope/evidence inputs.

First resolve the exact implementation cwd/worktree and final HEAD/status from the handoff.
If Luna used an isolated worktree, inspect and run verification there; this chat's original cwd
does not automatically contain Luna's code. Do not merge or copy files merely to review them.
Confirm the candidate is stable and fully includes the pre-existing local work. If the report is
missing or points to a different candidate, resolve that before giving a verdict.

Treat earlier diagnoses and implementation completion claims as hypotheses to verify. Review
against current founder decisions and AGENTS.md, then the brief, principles, architecture,
relevant ADRs and pre-merge/TestFlight/Slumber Party playbooks. Do not reinstate superseded product
prohibitions or treat old V1–V3 Slumber Party behavior as the current contract.

## Explicit review scope

The default recent-change base is **407a486**, the parent of the August 25 release batch.
Resolve its full commit ID and verify it is an ancestor. This deliberately includes:

- `ae4a9a0` — August 25 Wind Down release batch.
- `827f5a2` — August 25 interactive Farm pasture work.
- `dcff101` — August 26 TestFlight candidate/onboarding work.
- `cce766d` — August 26 Slumber Party Apple account recovery.
- All inherited staged/unstaged/untracked changes present when Luna began, including Slumber
  Party roadshow polish, account error handling, Farm interactions, Home and start-sheet changes.
- All Luna implementation commits/deltas and any additional candidate changes since that snapshot.

Inventory both the base-to-candidate tracked diff and untracked files: a plain Git diff does not
include untracked files. Record branch, base/head hashes and candidate status. Do not assume build
33 has a corresponding Git tag; only testflight-9 and testflight-10 were found when this packet was
prepared. Distinguish newly introduced findings from inherited defects, but report release blockers
regardless of authorship. The broad base is intentional; do not silently narrow to Luna's touched files.

Inventory all changes and group coverage by subsystem. Inspect code, configuration and resource
integration thoroughly; classify low-risk collateral/binary changes separately and disclose the
depth of inspection. Do not imply every asset or flow was visually/device tested if it was not.

## Review priorities

1. **Session correctness:** manual/scheduled Wind Down and Phone Away intent identity;
   authorization and app selection; direct repair routing; cancellation/denial/retry; scheduled
   expiry during repair; manual time anchored at actual start; automatic-start collisions;
   one authoritative active run; background/termination restore; truthful visible errors.
2. **Purpose freshness and isolation:** immediate main-actor observation; same-session restore;
   occurrence/revision/epoch fencing; no stale cue or cross-session bleed; unavailable storage;
   no polling workaround or leakage into notification/social/impact fields.
3. **Safety/privacy:** consented app/category selection; no false shield evidence; fail-open
   runtime failures and reachable emergency exit; NFC purpose/retired-tag recovery; App Group
   boundaries; backwards-compatible decoding; no secrets in code, logs or reports.
4. **Independent settlement:** Wind Down, Screen-Free Morning/Sunrise and Phone Away remain
   isolated; actual bookend minutes; no overnight inflation; no duplicate reward on retry/restore;
   no practice pollution; receipt/deferred-morning priorities preserved.
5. **Home/Active/guidance UX:** all plan criteria, no duplicate protection/schedule blocks, useful
   Phone Away access, one Slumber Party bridge, correct active timing labels, removed fake clue
   claims, selected routine cues, durable dismissals, valid deep links and source types, no
   silent routine replacement, no generic advice presented as personal evidence.
6. **Onboarding regressions:** optional six-question chapter, skip/resume, explicit-answer
   profiling, welcome gift claim/equip isolation, practice, reminders, automatic-start defaults,
   contextual guide targeting and accessibility after Home layout changes.
7. **Slumber Party V4 and Apple recovery:** expected Apple-linked UUID fencing, no anonymous
   recovery creation, account-scoped queue quarantine, strict schema boundary, expiring statuses,
   no false absence/compliance claims, practice status exclusion, fixed cheers, durable outbox,
   per-party reward fan-out/idempotency, Home/Farm routing and active-session suppression. Review
   changed server contracts and tests offline; do not deploy or exercise destructive production calls.
8. **Farm:** tap versus drag behavior, hit targets, persisted scene positions, removed/replaced
   files, accessibility/Reduce Motion, wool/ownership/cosmetics compatibility and V4 grant display.
9. **Release surface:** Watch/Live Activity/notification consistency, generated-project inclusion,
   extension resources/flags and physical-device gates. No claimed signing/TestFlight success
   without actual evidence for the candidate.

## Review method and boundaries

Review directly in Sol High. Do not implement fixes, refactor, change product scope, commit, push,
tag, change backend state or launch a replacement implementation thread. This is a behavioral
no-source-edit instruction, not a claim of OS-enforced read-only sandboxing. Build artifacts and
the review report are allowed. Capture candidate state before and after validation. If required
XcodeGen regeneration changes generated project files, report that delta explicitly; do not hand-
edit or silently restore it. Stop for approval where environment permissions require it.

Independently rerun the generic simulator build/full unit suite and relevant existing QA checks.
Read failures and verify actual command exit statuses. Inspect UI evidence and exercise available
simulator flows, especially menu selection without backgrounding and repair-sheet routing.
Do not count pure domain tests as SwiftUI observation or Family Controls/NFC device coverage.
For each physical test, record whether it was personally observed, founder-reported for this exact
candidate, or unverified. Build-33 workaround success does not verify a new build's fix.

Produce findings first, ordered by severity. Each finding needs a concrete file/line, trigger,
user impact, causal explanation and minimal correction; avoid speculative nits and restating
intent as proof. Validate apparent bugs against current behavior before reporting them.

Write `docs/plans/recent-changes-sol-review.md` with:

- Exact candidate/base/head/worktree and complete reviewed scope.
- Findings grouped by severity and by new/inherited origin where known.
- Coverage matrix across the priorities above; explicitly unreviewed areas and why.
- Independent commands/results/artifact paths and remaining device/release checks.
- Verdict: **ship**, **fix-first**, or **rethink**. Distinguish code acceptance from actual
  TestFlight/public-release readiness; incomplete critical review/verification is not ship.
- A concise correction packet for the existing Luna thread if changes are required.

Return the verdict and critical findings in this thread. Send no corrections automatically unless
the founder asks. After corrections, review the updated diff and rerun affected/full checks before
changing the verdict. Never treat the pre-correction report as approval of changed code.
