# Playbook: Git and Codebase State

How to manage version control on this repo — for humans and agents. The repo's history is
unusually thin (see below), so this playbook starts with a one-time consolidation and then
defines the ongoing workflow.

## Current state (verified July 2026)

- Local branch `main` has **one commit**: `fff6214 "Prepare open source redacted
  publication"`, matching remote `origin` = `github.com/papermelon/phone-in-the-other-room`.
- The **entire MVP is an uncommitted working-tree delta** on top of that commit
  (pixel UI, Watch changes, Screen Time extension, docs, assets).
- A second GitHub repo, `github.com/papermelon/counting-sheep-app`, exists with
  **unrelated history** (an earlier prototype; different HEAD). This codebase has never
  been pushed there.
- The published snapshot was deliberately **redacted for open source** (`ASSET_NOTICE.md`);
  the working tree contains newer generated art.

## One-time consolidation (human decisions, agent-assisted)

1. **Pick one canonical GitHub repo.** Recommendation: keep using
   `phone-in-the-other-room` as origin (it already has the right history) and either
   rename it to `counting-sheep-app` on GitHub (GitHub redirects old URLs) after
   archiving/renaming the old prototype repo, or archive the prototype and keep names as
   they are. Do not maintain two active repos.
2. **Make the canonical repo private** before pushing anything further. The next pushes
   will contain un-redacted art, real bundle IDs, and release configuration — none of
   which belong in the public redacted snapshot. (Re-open-sourcing later is a deliberate
   separate decision.)
3. **Commit the working tree in logical commits** (see commit guidance below). Suggested
   slicing for the current delta: shared domain changes → services → iOS UI/pixel design
   layer → Watch app → Screen Time extension scaffold → assets → docs/agent-OS files.
4. Push `main` once 1–2 are done. Tag the pre-delta state first if desired
   (`git tag pre-mvp fff6214`).

## Ongoing workflow

- **Branching:** short-lived feature branches off `main`, one concern per branch
  (`fix/health-auth-status`, `feat/stats-bedtime-framing`, `chore/doc-drift`). Merge back
  promptly; no long-running branches.
- **`main` is always buildable:** green `xcodebuild test` before merge (see
  `docs/PLAYBOOKS/pre-merge-review.md` §8).
- **Commit messages:** imperative summary line ≤ 72 chars, body explains *why* when
  non-obvious. One logical change per commit. Never commit `DerivedData/`, `build/`, or
  secrets (`.gitignore` already covers these).
- **Generated files:** `PhoneInTheOtherRoom.xcodeproj` is generated but **is committed**
  (so the project opens without XcodeGen installed). When `project.yml` changes, commit
  the regenerated project in the same commit.
- **Tag every TestFlight upload:** `git tag testflight-<build-number>` on the exact
  commit archived. This is the crash-symbolication and rollback anchor.
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
