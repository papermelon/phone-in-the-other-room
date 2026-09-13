# Instruction cleanup — 7 September 2026

Implemented the repository recommendations from [the 6 September audit](agent-instruction-audit-2026-09-06.md), incorporating the founder's subsequent ADR-0023 account-owned Farm direction. This changes agent guidance and review criteria, not app behavior or deployment state.

## Changes

- AGENTS.md reduced from **622 lines / 6,444 words** at the start of this work to **85 lines / 1,640 words** (about 75% fewer words). The earlier audit measured 597 lines; intervening account directions explain the difference. Lines are not a token estimate or a quality score.
- Root guidance now contains durable constraints, topic routes, explicit completion/authorization boundaries, and one validation policy. It no longer requires a general document stack or project generation for every task.
- [Product direction](PRODUCT_DIRECTION.md) preserves detailed Home, onboarding, economy, social and capability decisions. Superseded progression and backup rules were reconciled with ADR-0020–0023 rather than copied as current rules.
- SwiftUI and TestFlight skills have short frontmatter descriptions and outcome-oriented instructions. Pure copy/config/docs do not trigger the SwiftUI workflow. TestFlight audits remain read-only; explicit blocker-fix requests include implementation and revalidation.
- The copy skill retains evidence/privacy/medical constraints and contextual judgment, with a shorter description and proportionate output for small edits.
- Cursor is a pointer to the canonical guide. Pre-merge review no longer reinstates old Farm gates, completion-only rewards, a blanket urgency ban, automatic architecture permission requests, or builds for documentation-only changes.
- The release entry points now route to current account ownership/authentication/automatic-sync acceptance. Manual backup enrollment, routine restore, and playable prior-account Farm after sign-out are no longer current acceptance criteria. Physical, identity/isolation, migration, deletion, conflict and privacy checks remain.
- ADR-0002 records the updated collaboration contract. The Git playbook starts with current-state inspection; the old one-time repository consolidation recipe is historical.

## Preservation map

| Previous guide content | Current home |
|---|---|
| Mission, names, four tabs, phone authority, compatibility | AGENTS.md product/code invariants; Product direction for details |
| Founder authority and document precedence | AGENTS.md Authority and completion; ADR-0002 |
| Account-owned Farms, guest separation, prior declined consent | AGENTS.md invariants; Product direction Accounts; ADR-0023 and account plan |
| Transaction-store/payload boundary and confirmed save | AGENTS.md invariants; Product direction Accounts; ADR-0021 and private payload contract |
| Cumulative credit and separate factual/morning/social measures | AGENTS.md invariants; Product direction Ritual/Farm; ADR-0020 |
| Detailed onboarding, gifts, guide and account entry | Product direction First run and guidance; ADR-0023 supersession is explicit |
| Flock lifecycle, search guarantees, capacity/wool/customization | Product direction Ritual/Farm; ADR-0015 and ADR-0020 |
| Social membership, agreements, archive, exact-app limits | Product direction Slumber Party and shared-habits records; linked capability plans |
| Home hero/art timing and layout approvals | Product direction Home hero and linked approved design plan |
| Build/target/module inventory and data-flow detail | Existing ARCHITECTURE.md and project.yml, read by task |
| Coding/design/accessibility safeguards | AGENTS.md conventions; relevant SwiftUI/pre-merge sections |
| Validation, release/device gates | AGENTS.md Validation; release skill and release playbooks |
| Old chronology and superseded text | Verbatim fenced pre-cleanup snapshot; no ordinary-task loading |

The [historical guide](history/agent-guide-before-cleanup-2026-09-07.md) preserves the complete pre-edit working-tree guide, including the new account directions. The [historical Git notes](history/git-consolidation-july-2026.md) preserve the removed July consolidation section. Neither is operative guidance. The original audit remains a dated finding record; its old AGENTS line locations should be read against that historical context.

## Validation and representative scenarios

This is a solo static walkthrough of instruction paths, not an independent model benchmark or execution of the app tasks below. Each scenario was checked against the revised root/skill/reference route and actual stop/completion rules.

| Scenario | Result of walkthrough |
|---|---|
| Correct a spelling error in documentation | Root permits direct edit and reference/whitespace checks; no mandatory brief/backlog read, XcodeGen, SwiftUI skill, or app build. |
| Fix spacing in a SwiftUI view | Loads touched view/tokens and SwiftUI skill; no forced domain/service creation. Relevant layout inspection and affected-target build remain; full suite remains the code merge gate. |
| Repair early-ending cumulative credit | Loads ADR-0020 and touched Shared logic; requires meaningful credit/replay/Brief Access tests, retains partial credit and independent meters. No completion-only or three-night veto. |
| Repair an account Farm load/switch fault | Routes to ADR-0023/account plan/private payload; requires owner isolation, activation/lookup failure, offline/recovery and stale-work cases. No manual backup or cross-owner inheritance assumption. |
| Audit a four-tab release candidate | Read-only product/configuration review; uses current final-build/account and device matrices. Four tabs are valid; required unverified checks prevent SHIP without falsely labelling the app broken. |
| Fix explicitly authorized release blockers | Implements repairs and verifies introduced failures; does not stop at an audit report. New external/destructive actions still need their own authorization. |
| Ordinary fix suggests adding an unapproved package | Root retains explicit dependency approval; use existing capabilities or obtain the unresolved authorization. General implementation scope is not package approval. |
| Show “Saved” after sign-in with a newer local write pending | Root and account reference reject the unsupported save claim. Only a matching confirmed server generation supports it. |
| Sign out account A and continue as guest/account B | A's Farm is removed from active play; inaccessible recovery is owner-scoped. Guest/B never inherits inventory, delayed grants or queued work. |
| A copy edit introduces anticipation | Copy skill evaluates context and truthfulness, retaining the no-guilt/medical/privacy constraints without a generic urgency veto. |

Validation evidence:

- `quick_validate.py` passed for all three repository skills. The system and bundled Python lacked PyYAML, so the validator was run in an isolated temporary virtual environment with PyYAML; no application/package configuration was changed.
- Changed Markdown local file links and named heading anchors were checked; historical fenced snapshots were excluded from live-link parsing.
- Task-scoped `git diff --check` and direct whitespace checks for new documents passed.
- Compared the current edit against a saved pre-task working-tree baseline to distinguish this cleanup from pre-existing changes. The original guide snapshot matches that baseline verbatim.
- No app build/tests, XcodeGen, app-code changes, commit, push, provider activation or distribution were performed in this cleanup. Branch: `codex/night-flock-mvp`.

## Provider-managed metadata follow-up

The audit's installed-plugin findings concern vendor-managed descriptions, not repository skills. No cache files, installed plugins, or invocation policies were changed. Editing versioned caches is not a durable upstream fix, and the request does not select plugins to remove.

Prepared replacement descriptions for a future maintained-source/upstream change:

| Skill | Proposed discovery description |
|---|---|
| figma-swiftui | Translate between SwiftUI and Figma when the task explicitly connects code with a Figma design. |
| google-docs | Create or edit Google Docs, preserving supplied templates and document structure. |
| figma-generate-diagram | Create diagrams in Figma/FigJam; load before calling generate_diagram. |

Keep the provider skills' actual tool prerequisites, data boundaries and conditional workflow details in their bodies. These proposals were not installed or sent upstream. The repository cleanup is complete; vendor metadata remains a separately identified follow-up.
