# Playbook: Git and codebase state

Inspect the current branch, status, and relevant history before Git operations. Do not
assume the July one-commit snapshot is current. The [old consolidation notes](../history/git-consolidation-july-2026.md)
are historical only. Authorization follows [AGENTS.md](../../AGENTS.md#authority-and-completion).

## Ongoing workflow

- **Branching:** short-lived feature branches off `main`, one concern per branch
  (use `codex/` by default for agent-created branches, or the requested name). Merge back
  promptly; no long-running branches.
- **Validation:** use [the root validation policy](../../AGENTS.md#validation); code
  merges retain the full app build/unit-suite gate. Reuse matching evidence.
- **Commit messages:** imperative summary line ≤ 72 chars, body explains *why* when
  non-obvious. One logical change per commit. Never commit `DerivedData/`, `build/`, or
  secrets (`.gitignore` already covers these).
- **Generated files:** `PhoneInTheOtherRoom.xcodeproj` is generated but **is committed**
  (so the project opens without XcodeGen installed). When `project.yml` changes, commit
  the regenerated project in the same commit.
- **For an explicitly authorized release tag:** use `git tag testflight-<build-number>`
  on the exact commit archived. This is the crash-symbolication and rollback anchor.
- **Parallel agents:** only after the working tree is clean; one agent at a time may touch
  `project.yml`, entitlements, or tab/navigation structure. Parallel work must be on
  disjoint files, each on its own branch.

## Rules for AI agents (hard)

- Commit when asked or when a task's definition of done includes it — in small logical
  commits with clear messages.
- **Never push, force-push, amend, rebase, or tag without explicit human instruction.**
- Never run destructive commands (`reset --hard`, `clean -fd`, branch deletion) on your
  own initiative.
- Never commit likely-secret files (`.env`, credentials, provisioning profiles,
  `.p8`/`.p12` keys).
- If the working tree contains unrelated uncommitted changes, do not sweep them into your
  commit — stage only what your task touched, and report the rest.
- Report the repo state (branch, commits made) at the end of any session that changed it.

## Quick reference

```bash
git status --short                 # what's changed
git add <specific paths>          # stage only your task's files
git commit -m "Fix HealthKit authorization status check"
git tag testflight-42             # after a TestFlight upload (human)
xcodegen generate                 # after project.yml changes, commit the result too
```
