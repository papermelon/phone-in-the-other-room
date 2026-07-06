# Skills — Portable Agent Workflows

This folder contains reusable, tool-agnostic workflows ("skills") for recurring task
types on Counting Sheep. Each skill is a single `SKILL.md`: plain markdown, no
tool-specific syntax, usable verbatim by Codex, Cursor, Claude, ChatGPT, or a human.

## Available skills

| Skill | Use when |
|---|---|
| `testflight-review/` | Assessing whether a build is ready for TestFlight |
| `swiftui-feature/` | Adding or modifying any SwiftUI feature in this repo |
| `product-copy-review/` | Writing or reviewing any user-facing string |

Skills complement (never replace) the canonical context: agents still read
[`AGENTS.md`](../AGENTS.md) first. Skills assume that context and add procedure.

## How to invoke a skill, per tool

- **Codex:** Codex picks up `AGENTS.md` automatically. Name the skill in the prompt:
  *"Apply `skills/swiftui-feature/SKILL.md` to add X"*. Codex reads the file from the
  repo like any other.
- **Cursor:** the `.cursor/rules/counting-sheep.mdc` rule points agents here. You can also
  reference a skill directly in chat (`@skills/testflight-review/SKILL.md`).
- **Claude / ChatGPT / other chat tools:** paste or attach `AGENTS.md` + the relevant
  `SKILL.md` at the start of the session.
- **Humans:** they're checklists. Use them as-is.

## Structure of a skill

Every `SKILL.md` follows the same shape so agents can consume them predictably:

1. **Description** — what the skill does, in two sentences
2. **When to use** — trigger conditions
3. **Inputs / required context** — what to read or have before starting
4. **Procedure** — numbered steps
5. **Output format** — what the result must look like
6. **Acceptance criteria / anti-patterns** — how to know it was done right

## Adding a new skill

1. Only add a skill for a *recurring* task type (3+ expected uses). One-off procedures
   belong in `docs/PLAYBOOKS/` or nowhere.
2. Create `skills/<kebab-case-name>/SKILL.md` following the structure above.
3. Keep it under ~150 lines; link to docs/playbooks instead of duplicating them.
4. Add it to the table in this README.
5. Skills must respect the gates and principles in `AGENTS.md`, ADR-0003, and ADR-0004 —
   a skill is never a license to bypass them.
