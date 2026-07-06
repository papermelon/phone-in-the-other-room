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

### A3-remainder. Finish signing (human inputs needed)
- **Why:** A3 prep landed 2026-07-07 (bundle IDs `com.papermelon.countingsheep`,
  automatic signing, entitlements wired, version 0.1.0/1) but two human inputs remain.
- **Mode:** Human + Codex · **Size:** S
- **Steps:** (1) human confirms or changes the permanent bundle ID root in `project.yml`
  (permanent after first App Store Connect upload); (2) human supplies the Apple
  Developer Team ID for `DEVELOPMENT_TEAM`; (3) run `xcodegen generate`; (4) verify
  `xcodebuild archive` succeeds.
- **Accept:** archive succeeds with real team ID.

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

### A7b. Accessibility pass on the Watch views
- **Why:** the iOS run flow got its accessibility pass on 2026-07-07 (see Done), but
  Watch views were out of that session's scope and still lack labels.
- **Mode:** Codex · **Size:** S · **Autonomous:** yes
- **Files:** `PhoneInTheOtherRoomWatchApp/Views/*.swift`
- **Accept:** playbook §8 VoiceOver items pass on Watch; a run can be completed with
  VoiceOver alone end to end.

### Human-only (parallel, start now)
- Apple Developer enrollment; reserve app name; **submit Family Controls distribution
  request**; decide permanent bundle ID; pick canonical GitHub repo and make it private.

## B. MVP polish (before or shortly after first upload)

### B2b. Copy pass on notifications and Watch strings
- **Why:** the iOS run-flow copy pass landed 2026-07-07, but notification strings
  (`PhoneNotificationService`, `WatchNotificationService`) and Watch view strings were
  out of scope.
- **Mode:** Codex with `skills/product-copy-review/SKILL.md` · **Size:** S ·
  **Autonomous:** yes
- **Files:** `Services/PhoneNotificationService.swift`,
  `PhoneInTheOtherRoomWatchApp/Services/WatchNotificationService.swift`, Watch views
- **Accept:** review table produced; zero hard-rule violations remain.

### B3. Fix HealthSleepService authorization check
- **Why:** it optimistically returns `.authorized` without checking status — wrong the
  moment HealthKit ships (build 2), cheap to fix now.
- **Mode:** Codex · **Size:** S · **Autonomous:** yes
- **Files:** `Services/HealthSleepService.swift`
- **Accept:** real `authorizationStatus` consulted post-request; denied path returns
  honest state; unit-testable logic extracted to `Shared/` where feasible.

### B4a. Sheep-reward cycle celebration moment
- **Why:** `PixelHomeDashboard` computes next-sheep progress as `totalCompletedRuns % 3`,
  so immediately after earning a sheep the row shows "0 / 3" with no acknowledgment of the
  completed cycle (found by Bugbot, 2026-07-07). Minor, but the celebration moment is the
  product's whole reward philosophy.
- **Mode:** Codex · **Size:** S · **Autonomous:** yes
- **Files:** `PhoneInTheOtherRoomApp/Views/PixelHomeDashboard.swift`
- **Accept:** just-earned state shows warm acknowledgment (e.g. "A new sheep joined the
  flock!") before rolling to the next cycle; copy passes the copy skill.

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

- **2026-07-07 · Codex:** A4. Fixed hardcoded dashboard values. `PixelHomeDashboard`
  now reads Watch reachability from `WatchConnectivityManager.isReachable`, derives next
  sheep reward progress from `UserProgress.totalCompletedRuns`, and includes a
  disconnected-Watch preview.
- **2026-07-07 · Cursor/Fable:** A1. Working tree committed in 10 logical commits
  (shared → services → iOS UI → Watch → extension → assets → docs → agent OS).
  Nothing pushed; canonical-repo decision still with the human.
- **2026-07-07 · Cursor/Fable:** A2. Two-tab release scope. `MainAppTab.visibleTabs`
  and `FocusStatsTab.visibleTabs` gate Farm/Friends/Shop, the sleep tab, all MVP mock
  screens, `MVPMockData`, mock-backed components, and Screen Time UI behind DEBUG.
  Removed fake values (45m claim, 28-sheep floor, "/ 60" capacity). Bugbot reviewed
  (finding filed as B4a). 18/18 tests; Debug + Release builds green.
- **2026-07-07 · Cursor/Fable:** A3 (prep). Bundle IDs → `com.papermelon.countingsheep`
  (pending human confirmation), automatic signing, entitlement files wired (empty),
  MARKETING_VERSION 0.1.0 / build 1. Team ID still needed — see A3-remainder.
- **2026-07-07 · Cursor/Fable:** B1. Doc drift fixed across README/PRD/
  IMPLEMENTATION_NOTES/CHARLIE_AUDIT_ROADMAP; AGENTS.md §16 register cleared.
- **2026-07-07 · Cursor/Fable:** A7 (iOS) + B2 (run flow). VoiceOver labels/hints on
  the run flow, decorative scenes hidden, 44pt stepper targets; early-end screen made
  shame-free (happy Ollie), jargon removed. Watch views remain — see A7b/B2b.
