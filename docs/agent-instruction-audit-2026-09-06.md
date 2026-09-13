# Agent instruction audit — 6 September 2026

The highest-value cleanup is to remove contradictory instructions and make context loading conditional. The repository has useful domain safeguards, but older adapters and skills can still steer an agent toward obsolete product decisions or unnecessary stopping points.

## Basis and scope

Based on Eric Provencher’s [Rethinking skills and prompts for GPT-6 Astra](https://x.com/pvncher/status/2095991462416490862), published 4 September 2026. X returned HTTP 403; the article’s text blocks were retrieved through the [FxTwitter public mirror](https://api.fxtwitter.com/status/2095991462416490862). Embedded illustration text was not inspected. The criteria used here are narrow skill triggers, contextual reading, progressive disclosure, outcome-oriented workflows, proportionate validation, and explicit completion/decision boundaries. These are audit criteria, not evidence that every shorter prompt performs better.

Current [OpenAI model guidance](https://developers.openai.com/api/docs/guides/latest-model) also identifies conflicting instructions as a source of premature pauses and recommends making user-instruction precedence explicit.

Inspected the current working-tree AGENTS.md, all three repository skills, skills/README.md, the Cursor adapter, pre-merge and Git playbooks, and final-build acceptance. Used targeted code checks for current Home routing and cumulative credit. Separately reviewed the descriptions exposed in this session’s installed-skill catalog; this is not a full audit of every installed plugin body, other repositories, or old worktrees. Findings concern instruction quality, not application security or release readiness.

The branch was `codex/night-flock-mvp`, with extensive existing changes. No app code or instruction files were edited. The canonical startup command, `xcodegen generate`, ran successfully and wrote the generated project, which was already modified before this audit. No app build/test, commit, push, or deployment was performed.

## Findings, ranked

### 1. High — Old adapters and skills can reject approved work

- [.cursor/rules/counting-sheep.mdc:24](../.cursor/rules/counting-sheep.mdc#L24) prohibits Farm/Shop and Screen Time UI work alongside genuinely quarantined MVP/mock code. Its blanket urgency ban also conflicts with the current contextual copy direction.
- [skills/swiftui-feature/SKILL.md:17](../skills/swiftui-feature/SKILL.md#L17) requires refusal/escalation when the belonging test fails. AGENTS.md:454 explicitly calls that test a decision aid rather than a veto over founder direction.
- The same skill’s lines 26–28 route Farm/Shop/Health/shielding gates through old ADR-0003/0004; line 73 reinstates a blanket urgency prohibition.
- [docs/PLAYBOOKS/pre-merge-review.md:15](PLAYBOOKS/pre-merge-review.md#L15) retains completion-only reward wording and blanket urgency restrictions. Line 25 requires approval for every new singleton or architecture pattern, while AGENTS.md:274 allows a singleton with a strong reason.

**Effect:** the canonical hierarchy resolves these conflicts in principle, but every task must rediscover that resolution. A literal agent may pause, reject approved work, or propose reverting current behavior.

**Recommendation:** remove duplicated product gates from the Cursor adapter. Point to the current decision relevant to the touched feature. Replace the skill’s product veto with a requirement to explain unresolved tradeoffs while honoring explicit founder decisions. Preserve mock quarantine, evidence/privacy boundaries, and dependency approval.

### 2. High — The TestFlight skill tests the wrong product

[skills/testflight-review/SKILL.md:37](../skills/testflight-review/SKILL.md#L37) requires two Release tabs. AGENTS.md:548 requires four: Home, Nights, Farm, Settings. HomeView.swift’s routing includes Nights and Farm, consistent with the current direction. The skill also points at old gates and does not route to the new [final-build acceptance checklist](PLAYBOOKS/final-build-acceptance.md), which covers Farm save/restore, account isolation, and cumulative credit.

**Effect:** a conforming release can receive a false failure while newer acceptance requirements are missed.

**Recommendation:** delete the hardcoded tab count from the skill; reference the current release contract. Make final-build acceptance the entry point for a release candidate and the detailed TestFlight matrix a supporting reference. Preserve the distinction between source evidence, signed artifacts, hosted state, and physical-device evidence.

### 3. High — The canonical file carries superseded rules as present-tense instructions

AGENTS.md:44–50 approves cumulative Farm credit, including early endings and an independent Phone Away meter. Lines 320–325 and 342–349 still describe completion-only search and the old three-night gate. Lines 32–35 authorize the Application Support transaction store, but line 177 still describes persistence as UserDefaults-only. The top-level exceptions do resolve these cases; the remaining wording nevertheless creates unnecessary conflict.

The current Shared/CumulativeFarmCredit.swift defines the 420/100-minute thresholds and retained partial progress, supporting the newer direction.

**Recommendation:** replace obsolete current-tense paragraphs with the current rule and a link to ADR-0020/0021. Keep compatibility and migration history in those decision records. Keep planned, implemented, deployed, and validated states explicitly separate.

### 4. Medium — Unconditional reading consumes substantial context

Measured with `wc -lw`:

| Document | Lines | Words |
|---|---:|---:|
| AGENTS.md | 597 | 6,202 |
| PROJECT_BRIEF.md | 265 | 2,904 |
| PRODUCT_PRINCIPLES.md | 252 | 2,629 |
| ARCHITECTURE.md | 878 | 8,884 |
| FUTURE_AGENT_TASKS.md | 813 | 7,812 |

AGENTS.md:484–486 mandates the brief/principles and backlog check before code edits. The always-on Cursor adapter repeats these reads before any change. The SwiftUI skill adds architecture sections and neighboring files. AGENTS + brief + principles already total 11,735 words, before task-specific source. Checking the backlog need not mean reading all of it, but current routing does not encourage targeted retrieval.

**Recommendation:** keep a concise root guide containing durable invariants, ownership, commands, and a task-to-reference map. Move detailed product chronology and the long file inventory to existing references. Read product documents for product decisions, persistence contracts for persistence work, and release matrices for release work. A provisional 100–150-line root is a useful editing target, not a hard requirement or a reason to delete necessary safeguards.

### 5. Medium — Validation instructions overlap and run outside their useful scope

AGENTS.md:458 runs XcodeGen before every task, including this audit. AGENTS.md:464 mandates build/test after any code change. The SwiftUI skill repeats full-suite validation at lines 42 and 58, then invokes the full pre-merge checklist at line 62. The Cursor adapter requires tests before declaring any work done. Pre-merge’s final paragraph even requires a green build for an S-rated documentation change.

**Effect:** these are overlapping obligations, not proof that agents actually rerun identical tests. They encourage redundant work and obscure which result satisfies which gate. Unconditional project generation also introduces a write into a read-only review.

**Recommendation:** one validation policy, linked elsewhere. Generate when project inputs/source membership change or the project is absent. Use affected checks during implementation and retain the full app suite as the explicit merge/release gate. Reuse valid results for the same relevant source/configuration; rerun after changes or unresolved failures. Documentation-only audits need reference/format checks. Preserve physical QA requirements for NFC, shielding, Watch, Health, and backup claims.

### 6. Medium — Workflow recipes and permission boundaries can end tasks prematurely

The SwiftUI skill forces domain → tests → services → view model → view ordering even for presentation-only work. Its anti-patterns forbid new design tokens and growing PixelComponents.swift, broader than AGENTS.md’s instruction to reuse design tokens and avoid specified oversized files.

AGENTS.md:488 requires confirmation whenever project.yml, targets, signing, entitlements, or tab structure are touched. That combines consequential capability decisions with routine project maintenance and does not locally explain how existing authorization satisfies the gate. The TestFlight skill is intentionally read-only, appropriate for an audit, but should not become a stopping rule for a separate request to fix release blockers.

**Recommendation:** specify final properties and applicable checks instead of mandatory implementation order. State that already-authorized local implementation includes debugging, inspection, and fixing introduced failures. Ask only for an unresolved decision or unapproved external/destructive action; continue independent preparation. Preserve explicit approval boundaries for new dependencies, unapproved production effects, and sensitive capability changes. Keep review-only behavior for review-only requests.

### 7. Medium — Some installed skill descriptions have unnecessarily broad triggers

This finding is limited to session-visible metadata:

- `figma:figma-swiftui` says to trigger whenever Swift, SwiftUI, iOS, iPhone, or iPad is mentioned, even though the workflow is Figma translation. That is especially broad for this native iOS repository. Suggested description: “Translate between SwiftUI and Figma when the task explicitly connects code with a Figma design.”
- `google-drive:google-docs` embeds extensive implementation rules in its description. Keep the trigger short and put native-copy, smart-chip, and protected-control details in conditional references.
- `figma:figma-generate-diagram` has a broad any-diagram trigger. Scope discovery to creating diagrams in Figma/FigJam while preserving the required prerequisite before its tool is called.

Do not infer that descriptions were truncated in this session or that every listed plugin is harmful. No such measurement was made. Provider-managed cache files are not durable customization targets; suggest upstream fixes or curate enabled capabilities when appropriate. The uninstalled recommendations in the user message are not installed skill bodies.

### 8. Low — Useful skills need small routing corrections, not wholesale removal

The repository has only three skills: SwiftUI feature (74 lines), TestFlight review (72), and product copy (105). Skill count/body size is not the main local issue.

The copy skill already distinguishes factual evidence from invitations, gives relevant examples, and judges pressure in context. Preserve it. Its mandatory full review table can be conditional for multi-string audits rather than every single-label edit. The other two skills are plain repository playbooks without discovery frontmatter; that is not a defect for explicit file-based invocation. If native automatic discovery is desired, package them using the [documented skill format](https://learn.chatgpt.com/docs/build-skills) and narrow descriptions.

The Git playbook prominently describes a one-commit July snapshot; the current HEAD has 58 reachable commits. Move its one-time consolidation recipe into historical notes so ordinary Git work starts with current inspection rather than old repository restructuring advice.

## Recommended cleanup order and acceptance

1. Correct contradictory gates and the two-tab release check first.
2. Reconcile the canonical persistence/progression paragraphs with ADR-0020/0021.
3. Turn the root and adapters into conditional routers; consolidate validation once.
4. Replace rigid implementation ordering with concrete completion criteria.
5. Address overly broad installed-skill metadata separately from repository edits.

Evaluate the revised instructions against representative tasks: a spelling correction, a SwiftUI layout fix, cumulative-credit logic, a Farm persistence repair, a release audit, and an explicitly authorized blocker fix. Check that each loads relevant references, performs appropriate validation, preserves real product/privacy constraints, and stops only at a genuine unresolved boundary. Include an attempt to introduce an unapproved dependency and a request to claim unverified backup success; the cleanup must retain those constraints.

This audit proposes changes only. Shorter instructions should be accepted based on those task outcomes, not word-count reduction alone.
