# Codex Handoff — July 2026

Durable session handoff after the Cursor/Fable window. Read this once at your first
Codex session, then work from `docs/FUTURE_AGENT_TASKS.md` for scoped tasks.

**Product:** Counting Sheep (repo/code name: Phone in the Other Room)  
**Canonical agent memory:** `AGENTS.md` (always read first)  
**Work queue:** `docs/FUTURE_AGENT_TASKS.md`  
**Last Cursor/Fable session:** 2026-07-07

---

## What landed in the Cursor/Fable window

All work is committed on `main`. **Nothing has been pushed** to GitHub.

| Commit (recent) | What |
|---|---|
| `fff6214` → `ce0b12d` | Agent OS: `AGENTS.md`, docs, ADRs, playbooks, skills |
| `e6998bc` → `bf6ae5f` | Full MVP codebase: shared logic, services, pixel UI, Watch, Screen Time extension scaffold, assets |
| `a6e42e1` | **A2:** Release = Home + Stats only; Farm/Friends/Shop + mock layer DEBUG-gated |
| `f745945` | **A3 prep:** `com.papermelon.countingsheep` bundle IDs, auto signing, v0.1.0/1, entitlements wired (empty) |
| `c175598` | **B1:** Doc drift fixed (README, PRD, IMPLEMENTATION_NOTES, CHARLIE_AUDIT_ROADMAP) |
| `21af0ab` | **A7 + B2 (iOS run flow):** VoiceOver labels/hints; shame-free early-end copy |

**Verification at session end:** 18/18 unit tests pass; Debug and Release simulator builds succeed.

---

## Human decisions still blocking TestFlight

Do these yourself (Codex cannot):

1. **Apple Developer Program** — enrollment active.
2. **Permanent bundle ID** — confirm or change `com.papermelon.countingsheep` in `project.yml` *before* first App Store Connect upload (permanent after that).
3. **`DEVELOPMENT_TEAM`** — paste your Team ID into `project.yml`, run `xcodegen generate`, verify archive.
4. **Canonical GitHub repo** — local `origin` is `papermelon/phone-in-the-other-room`. Decide vs `counting-sheep-app`; make the canonical repo **private** before first push with real signing config.
5. **Family Controls distribution request** — submit to Apple now (weeks lead time; needed post-build-1 for Screen Time / ADR-0004).

---

## Next Codex tasks (priority order)

From `docs/FUTURE_AGENT_TASKS.md` — pick top-down:

1. **A3-remainder** — after human supplies team ID + confirmed bundle ID.
2. **A6** — pare Release Stats to native `UserProgress` + bedtime framing only.
3. **A7b** — Watch accessibility pass.
4. **B2b** — notification + Watch copy pass (`skills/product-copy-review/SKILL.md`).
5. **B4a** — sheep-reward celebration after 3-run cycle (Bugbot finding).
6. **B4** — analytics export privacy redaction or DEBUG gate.
7. **A5** — backgrounding-mid-run (needs human behavior decision first).

**Do not start without ADR gates:** Farm/Friends/Shop (ADR-0003), NFC/QR sessions (ADR-0004), Screen Time UI in Release, HealthKit card (build 2).

---

## Codex operating notes (Jul 2026)

**Codex is good at:** reading the full repo; surgical Swift edits in `Shared/` + tests; following `skills/` and playbooks; running `xcodegen generate`, `xcodebuild build/test`; logical commits when asked; backlog tasks marked **Autonomous: yes**.

**Codex is not Cursor:** no parallel subagents, no Bugbot, no Multitask. Run one scoped task per session. For cross-cutting refactors (A5, C4, C5), plan in chat first or split into small Codex increments.

**Hard rules (from `AGENTS.md`):**
- Never hand-edit `project.pbxproj` — edit `project.yml`, then `xcodegen generate`.
- Never push, force-push, or amend without explicit human instruction.
- Run tests before declaring done: `xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,name=iPhone 17'`
- Do not wire `Views/MVP/` or `MockData/` into Release paths.

**Validation commands:**
```bash
xcodegen generate   # after project.yml or file add/remove
xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator'
xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,name=iPhone 17'
```

---

## Copy-paste: first Codex session prompt

```
You are working on Counting Sheep (repo folder: Phone in the Other Room), an iOS + watchOS
SwiftUI app that helps people put their phone in another room before bed. Mascot: Ollie.

Before any edit, read AGENTS.md fully, then docs/CODEX_HANDOFF.md and
docs/FUTURE_AGENT_TASKS.md. Follow docs/PRODUCT_PRINCIPLES.md — no guilt copy, no medical
claims, no dark-pattern gamification.

Current state (2026-07-07): main branch has the agent OS, two-tab Release MVP (Home +
Stats), DEBUG-gated mock screens, signing prep with com.papermelon.countingsheep bundle
IDs (team ID still empty). 18/18 tests pass. Nothing pushed to GitHub.

Your task this session: [PICK ONE FROM FUTURE_AGENT_TASKS — e.g. A6]

Procedure:
1. Read the task acceptance criteria in docs/FUTURE_AGENT_TASKS.md.
2. If the task names a skill, read and follow it (e.g. skills/product-copy-review/SKILL.md).
3. Implement minimally; match existing SwiftUI/MVVM conventions in AGENTS.md.
4. Run xcodegen generate if needed, then xcodebuild test (iPhone 17 simulator).
5. Self-review against docs/PLAYBOOKS/pre-merge-review.md.
6. Update docs/FUTURE_AGENT_TASKS.md (move task to Done with date) if you finish it.
7. Commit with a clear message if I ask; never push unless I explicitly say so.

Report: what changed, test output, risks, and what human input is still needed.
```

---

## Copy-paste: milestone prompts (use in order)

### Milestone 1 — TestFlight archive (human + Codex)

*Run after Apple Developer account is active.*

```
Task A3-remainder from docs/FUTURE_AGENT_TASKS.md.

Human inputs (I will provide):
- Confirmed bundle ID root: [com.papermelon.countingsheep or my choice]
- DEVELOPMENT_TEAM: [10-char team ID]

Update project.yml with the team ID. Run xcodegen generate. Verify:
  xcodebuild archive -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS'

Apply skills/testflight-review/SKILL.md and report blockers only (don't fix unrelated items).
Do not add HealthKit or Family Controls entitlement keys — build 1 stays empty.
Commit if I ask; never push.
```

### Milestone 2 — Release Stats bedtime MVP (Codex, autonomous)

```
Task A6 from docs/FUTURE_AGENT_TASKS.md.

Apply skills/swiftui-feature/SKILL.md and skills/product-copy-review/SKILL.md.

Goal: In Release configuration, FocusStatsView shows ONLY native UserProgress data
(streak, phone-away minutes, stars, recent runs) with gentle bedtime framing. Hide or
DEBUG-gate: manual analytics entry, HealthKit card, Screen Time setup/reports, analytics
QA card, export if it has the relativeDays privacy bug (or fix B4 first).

Do not delete DEBUG scaffolding — gate it. Run tests. Update FUTURE_AGENT_TASKS Done section.
```

### Milestone 3 — Polish pass (Codex, 2–3 small sessions)

Session A — `Task A7b`: Watch VoiceOver labels on all Watch views.  
Session B — `Task B2b`: copy review on PhoneNotificationService + WatchNotificationService + Watch view strings.  
Session C — `Task B4a`: celebrate sheep earned at end of 3-run cycle on PixelHomeDashboard.

Each session: one task, tests green, update backlog.

### Milestone 4 — TestFlight readiness audit (Codex)

```
Apply skills/testflight-review/SKILL.md against the current main branch.

Walk docs/PLAYBOOKS/testflight-readiness.md section by section. Verify claims against
code and project.yml — do not trust README alone.

Output: blocker table (item / status / risk S-M-L / owner human vs agent). No code changes
unless I approve fixes from the report.
```

### Milestone 5 — Crash hardening (human decision + Codex)

```
Task A5 from docs/FUTURE_AGENT_TASKS.md — but first propose options:

When the user backgrounds mid-run, should we: (a) pause and resume, (b) show a warm
warning on return, or (c) tolerate silently with honest copy?

After I pick one, implement in PhoneInTheOtherRoomApp.swift (scenePhase) +
ProximitySessionCoordinator + run views. Document behavior in docs/ARCHITECTURE.md.
Run tests.
```

### Milestone 6 — Post-TestFlight (only after build 1 ships)

```
Read docs/DECISIONS/ADR-0004-watch-independent-sessions.md.

Do NOT implement yet unless Family Controls approval is confirmed. Instead: produce a
technical design for generalizing the verification seam (UWB vs QR/NFC session guard).
Max 1 page in docs/ — no code until I approve.
```

---

## Known open issues (not blockers for build 1)

- Sheep reward UI shows "0 / 3" immediately after earning a sheep (B4a).
- Analytics export `relativeDays` may leak ISO dates (B4).
- Runs are foreground-only; backgrounding behavior undefined (A5).
- HealthSleepService authorization check is optimistic (B3).
- Watch accessibility incomplete (A7b).

---

*Maintained by agents when major session handoffs occur. Update the date and Done list
in FUTURE_AGENT_TASKS.md when you finish work.*
