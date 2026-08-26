# ADR-0002: How AI Agents Collaborate on This Repository

- Status: Accepted
- Date: 2026-07-07
- Deciders: Founder
- Related: `AGENTS.md`, `docs/PLAYBOOKS/`, `skills/`, `.cursor/rules/counting-sheep.mdc`

## Context

This project is built with heavy AI assistance across multiple tools — Codex (primary,
ongoing), Cursor (intensive short windows), and potentially Claude/ChatGPT and future
agents. Each tool has different context limits, different memory conventions, and no
shared state. Without a repo-native operating system, every session re-derives project
understanding, drifts on conventions, and risks over-eager changes (the repo already
contains a mock-screen layer that grew faster than the shipped product).

## Decision

Project knowledge lives **in the repository**, structured in four layers by durability:

| Layer | Location | Role | Changes when |
|---|---|---|---|
| 1. Canonical memory | `AGENTS.md` | Single source of truth: mission, architecture, conventions, checklists, gates | Conventions or architecture change |
| 2. Durable context | `docs/` (brief, architecture, principles, `DECISIONS/`) | Deep background, product boundaries, decision history | Decisions are made or reversed |
| 3. Reusable workflows | `docs/PLAYBOOKS/` + `skills/` | Step-by-step procedures for recurring task types | Procedures improve |
| 4. Tool adapters | `.cursor/rules/` (and future per-tool config) | Thin pointers back to layers 1–3; never duplicate content | Tools change |

Rules of operation:

1. **`AGENTS.md` is canonical.** Codex reads it natively; every other agent must read it
   before editing code. Where any document disagrees with it, `AGENTS.md` wins, and the
   drift should be reported or fixed.
2. **Docs are durable context, not session notes.** `docs/` files describe what is true
   and decided. Session-specific plans and scratch work do not get committed there.
3. **Skills and playbooks are the reusable workflows.** Recurring task types (TestFlight
   review, SwiftUI features, copy review, pre-merge checks, git operations) have written
   procedures. Agents follow them rather than improvising, and improve them in place when
   they find better procedures.
4. **Tool adapters stay thin.** `.cursor/rules/counting-sheep.mdc` (and any future
   `CLAUDE.md`-style file) contains pointers and hard constraints only. Duplicating
   content across adapters is how drift starts — don't.
5. **Decisions get ADRs.** Anything that constrains future work (positioning, gated
   features, architectural direction) is recorded in `docs/DECISIONS/` with status,
   rationale, and revisit criteria — so future agents don't relitigate it from scratch.
6. **Prompts should cite files.** Humans directing agents should reference these files
   ("follow AGENTS.md", "use skills/testflight-review") instead of restating context.
   Agents should ask for the referenced file rather than guessing when one is mentioned
   but unavailable.
7. **The backlog is shared state.** `docs/FUTURE_AGENT_TASKS.md` is the queue of scoped,
   prioritised work with acceptance criteria and an autonomous-safety flag. Agents pick
   from it, and file follow-ups into it.

### Per-tool invocation pattern

- **Codex:** reads `AGENTS.md` automatically. For task-specific procedures, the prompt
  should name the skill or playbook path (e.g. "apply `skills/swiftui-feature/SKILL.md`").
- **Cursor:** the `.cursor/rules/counting-sheep.mdc` rule auto-applies and directs agents
  to layers 1–3. Skills in `skills/` can be read directly by path.
- **Claude / ChatGPT / other:** paste or attach `AGENTS.md` plus the relevant skill file
  at session start. These files are plain markdown by design; no tool-specific syntax.

### Update discipline

- Whoever changes behavior updates the docs in the same change set.
- `AGENTS.md` §16 tracks known drift in legacy docs until they are aligned.
- Adapters and skills are reviewed whenever a new tool joins the workflow.

## Consequences

- New sessions in any tool reach working context in one file read instead of a repo crawl.
- Over-eager changes are constrained by written gates (ADR-0003/0004, feature-creep table)
  that agents can cite when refusing work.
- Cost: docs must be maintained. Mitigated by keeping one canonical file, thin adapters,
  and folding doc updates into the definition of done (`AGENTS.md` §12).
