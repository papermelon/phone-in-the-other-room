# Future Agent Tasks — Prioritised Backlog

The shared work queue for Codex, Cursor, and human sessions. Pick from the top; read
`AGENTS.md` first. When you finish a task, mark it done here (with date + session) and
file any follow-ups as new entries.

Field legend — **Mode**: Codex / Cursor Plan→Build / Cursor Build / Cursor Multitask
(parallel-safe) / Human. **Size**: S / M / L. **Autonomous**: whether an AI agent may
execute without human sign-off mid-task (final merge review still applies per
`docs/PLAYBOOKS/pre-merge-review.md`).

---

## A. Immediate TestFlight blockers (in order)

### A1. Commit the working tree in logical commits
- **Why:** the entire MVP is uncommitted on top of a single-commit history — data-loss
  risk, and no parallel agent work is safe until the tree is clean.
- **Mode:** Cursor Build (or Codex) · **Size:** M · **Autonomous:** yes (commit only —
  never push; human decides canonical repo + visibility first, see git playbook)
- **Files:** everything; slice per `docs/PLAYBOOKS/git-workflow.md` §consolidation
- **Accept:** `git status` clean; each commit builds conceptually (shared → services →
  iOS UI → watch → extension → assets → docs); nothing pushed.

### A2. MVP simplification pass (two-tab release scope)
- **Why:** the app ships five tabs, three mock-driven — the #1 "app tries to do too much"
  fix and a hard ADR-0003 requirement.
- **Mode:** Cursor Plan→Build (cross-cutting, needs judgment); Bugbot review before merge
- **Size:** L · **Autonomous:** no — human reviews the diff
- **Files:** `HomeView.swift`, `PixelComponents.swift` (`MainAppTab`),
  `FocusStatsView.swift`, `Views/MVP/AssetReadyScreens.swift` (gating),
  `MockData/MVPMockData.swift` (quarantine)
- **Accept:** Release build shows Home + Stats only; Farm/Friends/Shop + Screen Time UI
  DEBUG-gated (not "coming soon"); no `MVPMockData` reference reachable in Release;
  tests + build green.

### A3. Signing and identity pass in project.yml
- **Why:** signing is disabled, bundle IDs are `com.example.*`, no versions — archive is
  impossible.
- **Mode:** Cursor Build or Codex, single agent (never parallel with anything touching
  `project.yml`) · **Size:** M · **Autonomous:** partially — prepare everything; human
  supplies `DEVELOPMENT_TEAM` and confirms the permanent bundle ID
- **Files:** `project.yml`, regenerated `project.pbxproj`, three `.entitlements` files
  (stay empty for build 1)
- **Accept:** playbook §2 items all pass; `xcodebuild archive` succeeds once team ID is in.

### A4. Fix hardcoded dashboard values
- **Why:** `PixelHomeDashboard` shows Watch "Connected" and "1 / 3" sheep progress as
  hardcoded strings — visibly fake in testers' hands.
- **Mode:** Codex · **Size:** S · **Autonomous:** yes
- **Files:** `PixelHomeDashboard.swift`, reading `WatchConnectivityManager.isReachable`
  and `UserProgress`
- **Accept:** both values reflect live state; `#Preview` covers disconnected state.

### A5. Backgrounding-mid-run honesty
- **Why:** runs are foreground-only with no `scenePhase` handling; backgrounding silently
  degrades the session — a top crash/confusion risk in the QA script.
- **Mode:** Cursor Plan→Build (needs a design decision: pause vs. warn vs. tolerate)
- **Size:** M · **Autonomous:** no — behavior decision needs the human
- **Files:** `PhoneInTheOtherRoomApp.swift` (scenePhase), `ProximitySessionCoordinator.swift`,
  copy in run views
- **Accept:** playbook §7 backgrounding checks pass with honest, warm copy; no crash;
  behavior documented in ARCHITECTURE.md.

### A6. Bedtime-framed Stats tab (minimal, native data)
- **Why:** build-1 stats must be the pared-down, bedtime-framed surface (brief §MVP):
  nights phone slept away, bedtime streak, wind-down minutes, stars — nothing else.
- **Mode:** Codex (after A2 lands) · **Size:** M · **Autonomous:** yes
- **Files:** `FocusStatsView.swift` (reduce), copy per `skills/product-copy-review`
- **Accept:** stats tab shows only native `UserProgress` data with bedtime framing; no
  HealthKit/Screen Time/manual-entry/QA surfaces in Release; copy passes the skill.

### A7. Accessibility pass on the core run flow
- **Why:** timer, proximity state, and Watch views lack labels — App Review risk and a
  real usability gap.
- **Mode:** Cursor Multitask or Codex (disjoint from A2/A3 files after they land)
- **Size:** M · **Autonomous:** yes
- **Files:** `ActiveRunView.swift`, `CompletionView.swift`, `EarlyEndView.swift`,
  `FocusRunSetupView.swift`, Watch views
- **Accept:** playbook §8 VoiceOver/Dynamic Type items pass; a run can be completed with
  VoiceOver alone.

### Human-only (parallel, start now)
- Apple Developer enrollment; reserve app name; **submit Family Controls distribution
  request**; decide permanent bundle ID; pick canonical GitHub repo and make it private.

## B. MVP polish (before or shortly after first upload)

### B1. Doc drift alignment
- **Why:** README/PRD/IMPLEMENTATION_NOTES contradict code (AGENTS.md §16) and will
  mislead agents and App Review alike.
- **Mode:** Cursor Multitask or Codex · **Size:** S · **Autonomous:** yes
- **Files:** `README.md`, `docs/PRD.md`, `docs/IMPLEMENTATION_NOTES.md`,
  `docs/CHARLIE_AUDIT_ROADMAP.md`
- **Accept:** every drift item in AGENTS.md §16 fixed; §16 emptied to "none known".

### B2. Copy pass over the core flow
- **Why:** tone is the product; every string should pass the copy skill before testers
  see it.
- **Mode:** Codex with `skills/product-copy-review/SKILL.md` · **Size:** S ·
  **Autonomous:** yes (drop-in revisions; human skims the table)
- **Files:** run-flow views, notifications, alerts
- **Accept:** review table produced; zero hard-rule violations remain.

### B3. Fix HealthSleepService authorization check
- **Why:** it optimistically returns `.authorized` without checking status — wrong the
  moment HealthKit ships (build 2), cheap to fix now.
- **Mode:** Codex · **Size:** S · **Autonomous:** yes
- **Files:** `Services/HealthSleepService.swift`
- **Accept:** real `authorizationStatus` consulted post-request; denied path returns
  honest state; unit-testable logic extracted to `Shared/` where feasible.

### B4. Analytics export privacy fix or gate
- **Why:** `relativeDays` mode doesn't redact ISO dates — a privacy bug if export ships.
- **Mode:** Codex · **Size:** S · **Autonomous:** yes
- **Files:** `Shared/FocusAnalytics.swift`, `Services/AnalyticsExportService.swift`, tests
- **Accept:** either redaction works (with test) or export is DEBUG-gated for build 1.

## C. Architecture cleanup (post-first-upload, opportunistic)

### C1. Split FocusStatsView.swift (1,232 lines)
- **Mode:** Codex · **Size:** M · **Autonomous:** yes — mechanical extraction, no behavior
  change; easier after A6 shrinks it
- **Accept:** no file over ~400 lines; build/tests green; no functional diff.

### C2. Split AssetReadyScreens.swift (1,413 lines, gated code)
- **Mode:** Codex · **Size:** M · **Autonomous:** yes
- **Accept:** one screen per file under `Views/MVP/`; still DEBUG-gated; builds.

### C3. Remove unused RewardShelfViewModel; finish-or-delete demo mode
- **Why:** dead and half-wired code misleads agents with limited context.
- **Mode:** Codex · **Size:** S · **Autonomous:** yes (deletion default; reviving demo
  mode needs a human yes)
- **Files:** `ViewModels/`, `Proximity/DemoDistanceProvider.swift`, `FocusRunViewModel`
- **Accept:** no unreferenced types; demo mode either reachable or gone.

### C4. Inject services into ProximitySessionCoordinator
- **Why:** `.shared` coupling makes the core state machine untestable.
- **Mode:** Cursor Plan→Build · **Size:** M · **Autonomous:** no — core-loop refactor,
  human reviews
- **Accept:** coordinator constructible with test doubles; first coordinator unit tests
  exist; behavior unchanged.

### C5. App Group + Screen Time extension embedding
- **Why:** prerequisite for shipping any Screen Time feature (extension can't read app
  selections today; extension isn't embedded).
- **Mode:** Cursor Plan→Build · **Size:** L · **Autonomous:** no — entitlements + build
  config; blocked on Family Controls approval
- **Accept:** extension embedded, `SCREEN_TIME_REPORTS` on main target, selections shared
  via App Group, archive still signs.

## D. Product experiments (gated — check the ADR before starting)

### D1. QR/NFC bedtime sessions (ADR-0004) — top post-build-1 bet
- **Gate:** Family Controls approval AND build 1 stable. QR first, then NFC.
- **Mode:** Cursor Plan→Build for the strategy-seam design; Codex for increments
- **Size:** L · **Autonomous:** no — new entitlements, new interaction model
- **Accept:** ADR-0004 architecture direction followed (session-guard strategies);
  anti-addiction constraints implemented (consent, gentle shield, emergency exit);
  workshop demo flow works end-to-end on a non-Watch iPhone.

### D2. HealthKit sleep card (TestFlight build 2)
- **Gate:** signing settled; B3 fixed; privacy label prepared.
- **Mode:** Codex · **Size:** M · **Autonomous:** yes for code; human does portal +
  App Store Connect label
- **Accept:** optional sleep card on Stats; graceful denied/no-data states; no
  sleep-quality claims in copy.

### D3. Late-night Screen Time report (flagship differentiator)
- **Gate:** C5 done; Family Controls approved.
- **Mode:** Cursor Plan→Build · **Size:** L · **Autonomous:** no
- **Accept:** `phone-other.late-night` scene surfaces bedtime screen time inside Stats;
  copy bedtime-framed and kind.

## E. Later / explicitly postponed (do not start; citable refusals)

- **Farm reintroduction** — ADR-0003 gates 0–3, after D1.
- **Shop** — after Farm; anti-addiction review required.
- **Friends / social** — requires its own ADR; default no (ADR-0003).
- **Design-system convergence** (retire `GameComponents`) — opportunistic only.
- **New persistence layer / CoreData / SwiftData** — not needed at this scale.
- **CI pipeline** — valuable, but after first TestFlight; local gate suffices now.
- **Android / iPad / web** — out of scope (brief §non-goals).
- **Any analytics/tracking SDK** — conflicts with the privacy posture; needs human decision.

---

*Maintenance: keep sections ordered by priority; completed tasks move to a dated
"Done" list at the bottom; new tasks must include all fields.*

## Done

*(nothing yet)*
