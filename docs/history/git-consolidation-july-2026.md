# Historical Git consolidation notes — July 2026

These describe an old snapshot, not the current branch or instructions to rename, publish,
restructure, or push a repository. Inspect current state and follow [the Git playbook](../PLAYBOOKS/git-workflow.md).

~~~~text
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

~~~~
