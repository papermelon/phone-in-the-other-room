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

### Human-only (parallel, start now)
- Apple Developer enrollment; reserve app name; **submit Family Controls distribution
  request**; decide permanent bundle ID; pick canonical GitHub repo and make it private.

## B. MVP polish (before or shortly after first upload)

### B1. Validate a full Night Watch on physical hardware
- **Why:** the session deliberately crosses midnight and depends on restoration, local
  notifications, ActivityKit, and optional Watch placement behavior that unit tests and a
  short simulator run cannot fully reproduce.
- **Mode:** Human + Codex · **Size:** S · **Autonomous:** no
- **Accept:** run from wind-down through morning quiet on a physical iPhone; cover locked
  screen, termination/relaunch, notification delivery, Live Activity phase changes, early
  end, and one Watch/QR fallback; record results in the TestFlight QA playbook. Repeat one
  schedule across a DST or timezone boundary before broader rollout.

### B2. Establish physical-device overnight energy baselines
- **Why:** the code is event-driven after the 2026-07-27 energy audit, but Live Activity
  display cost, UWB burst cost, optional Supabase transport, and real suspension behavior
  require device measurements rather than inference.
- **Mode:** Human + Codex · **Size:** S · **Autonomous:** no
- **Files:** `docs/ENERGY_AUDIT.md`
- **Accept:** capture at least three comparable Power Profiler traces for idle, honor-timer
  without Live Activity, honor-timer with Live Activity, and Watch placement; capture one
  full overnight on-device Performance Trace; record selected-range CPU, display, network,
  and per-app power impact plus DEBUG event counts. Confirm there is no one-second
  persistence/Watch stream and that NI ends within the placement window.

### B3. Design honest HealthKit read-access states — completed 2026-07-26
- **Why:** HealthKit intentionally does not disclose whether read access was denied;
  `authorizationStatus(for:)` only reports share/write authorization and cannot satisfy
  the old read-only acceptance criterion.
- **Mode:** Human decision + Codex · **Size:** S · **Autonomous:** no
- **Files:** `Services/HealthSleepService.swift`, build-2 Health UI copy
- **Accept:** completed with requested/no-data/error states; an empty result never claims
  access was denied. Nights explains that Apple's Sleep Score is not exposed through
  HealthKit.

## C. Architecture cleanup (post-first-upload, opportunistic)

### C2. Split AssetReadyScreens.swift (gated code)
- **Mode:** Codex · **Size:** M · **Autonomous:** yes
- **Accept:** one screen per file under `Views/MVP/`; still DEBUG-gated; builds.

### C3. Inject services into FocusSessionCoordinator
- **Why:** `.shared` coupling makes the core state machine untestable.
- **Mode:** Cursor Plan→Build · **Size:** M · **Autonomous:** no — core-loop refactor,
  human reviews
- **Accept:** coordinator constructible with test doubles; first coordinator unit tests
  exist; behavior unchanged.

## D. Product experiments (gated — check the ADR before starting)

### D1. NFC + optional app shielding after the QR phone-bed guard (ADR-0004)
- **Gate:** Family Controls approval AND build 1 stable. QR placement is already
  available without blocking; NFC and shielding remain deferred.
- **Mode:** Cursor Plan→Build for the strategy-seam design; Codex for increments
- **Size:** L · **Autonomous:** no — new entitlements, new interaction model
- **Accept:** NFC and ManagedSettings extend the existing session-guard seam; consent,
  gentle shield copy, and an emergency exit are implemented; workshop demo works on an
  iPhone without a Watch.

### D2. HealthKit sleep card (TestFlight build 2)
- **Gate:** signing settled; B3 fixed; privacy label prepared.
- **Mode:** Codex · **Size:** M · **Autonomous:** yes for code; human does portal +
  App Store Connect label
- **Accept:** optional sleep card on Stats; graceful denied/no-data states; no
  sleep-quality claims in copy.

### D3. Optional sleep-bookend Screen Time shielding (flagship differentiator)
- **Gate:** Read-only bookend reports are complete; shielding remains separately gated.
- **Mode:** Cursor Plan→Build · **Size:** L · **Autonomous:** no
- **Accept:** the existing consented app selection supports optional shields only during
  the configured quiet windows, always offers an emergency exit, and never claims to
  measure sleep. Preserve the read-only `phone-other.*` report contexts.

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

- **2026-07-27 · Codex + human direction:** Added an ADR-gated development preview for
  NDEF phone-bed registration/confirmation and ManagedSettings shielding. The shared
  policy applies only to wind-down and morning quiet and clears overnight or whenever a
  run ends/resets. Release controls remain hidden until the first TestFlight gate passes.
  Reliable suspended/terminated transitions still require a separately registered and
  approved DeviceActivityMonitor extension.

- **2026-07-27 · Codex:** Removed Home CTA truncation by giving its title and schedule room
  to wrap, reducing fixed icon chrome, and shortening the schedule to the bed and phone-wake
  times. Before-bed and after-waking settings now share the same duration choices—15, 30,
  45, 60, 90, 120, or 180 minutes—through readable menus that preserve independent values.

- **2026-07-27 · Codex:** Made Nights data provenance explicit. The latest quiet-time card
  now shows an early-ended attempt when it is newer than the last protected night, and all
  key records show their date. Apple Health summaries retain their night-ending date, so an
  older sample is labelled as older instead of appearing as last night. Screen Time reports
  now use iPhone-only data, combine matching hourly streams, keep quiet hours visible, show
  selected-app time against the full report window, and allow each hour to be tapped for its
  exact duration. Removed the ambiguous unattributed-pickup count.

- **2026-07-27 · Codex:** Added a deliberately small CBT-I-informed context layer to Nights:
  an optional, collapsed three-question morning note with no score or rewards; a seven-night
  Apple Health wake-time range; and Screen Time report timing for Apple's exact first pickup
  plus the latest active reporting hour. Morning reflections stay in local UserDefaults and
  retain at most 45 days. Physical-device HealthKit and DeviceActivity QA remains required.

- **2026-07-26 · Codex:** Decoupled the Nights Screen Time report ranges from Quiet Time.
  People can now choose separate start and end times for late-evening and after-waking
  reports, see every selected app or category through Apple's privacy-preserving labels,
  and add, remove, or replace the shared selection. Added persisted preferences and interval
  coverage, including a report window that crosses midnight.

- **2026-07-26 · Codex:** Reworked the shipping reward loop into rotating keepsake
  families plus cumulative, never-losable protected-night milestones. New rewards retain
  a factual snapshot of the two credited bookends and selected offline cues; duration,
  warnings, streaks, placement method, and optional health/report data do not improve the
  keepsake tier. Completion now reconnects the reveal to the person's offline purpose, and
  the finite shelf explains each keepsake without rarity pressure or locked-slot teasing.
  Added legacy-decode and reward-selection coverage plus `docs/REWARDS.md`.

- **2026-07-26 · Codex + human decision:** Renamed the shipping Stats tab to Nights and
  replaced its Nights/Trends/Sleep/Insights segmentation with one finite scroll. Simplified
  Home to tonight's plan, an optional offline purpose, and one primary action; removed the
  manual Screen Time prompt and economy-heavy dashboard row. New plans retain 30/30 quiet
  defaults with selectable durations. Custom purpose text is local and in-app by default,
  with a separate opt-in before it can appear in reminders. Added read-only Screen Time
  report contexts for the configured before-bed and after-waking windows; physical-device
  report QA remains required.

- **2026-07-25 · Codex + human portal confirmation:** Completed C5 after Family Controls
  Distribution and `group.com.ngawangchime.countingsheep` were assigned to the containing
  app and report extension. The DeviceActivity report is embedded, both targets carry the
  approved entitlements, the main app compiles the reporting UI, and scoped selections
  migrate into App Group defaults without moving unrelated local progress. This enables
  read-only reporting only; shielding, NFC, and all-night blocking remain gated by ADR-0004.

- **2026-07-18 · Codex + human approval:** Enabled the existing read-only HealthKit sleep
  integration for Release, restored its prior authorization state, and refreshes last-night
  sleep on launch. Added a Debug-only immediate Night Watch start for backend/device QA and
  made the gated Farm preview derive its sheep count and occupied slots from authoritative
  `UserProgress` instead of the hardcoded 28-sheep mock.

- **2026-07-18 · Codex:** Decoupled Supabase Night Watch identity/history from ActivityKit
  token delivery. Starting a local run now restores or creates anonymous auth and syncs the
  device/run independently; terminal status follows completion or early end. Fixed XcodeGen
  xcconfig attachment, added the development push entitlement, extended the hosted schema
  for overnight end times, hid phone-finding UI outside Watch placement, and relabelled the
  reward shelf affordance.

- **2026-07-18 · Codex + human confirmation:** Aligned project-level Night Watch
  presentation. Both Nearby Interaction prompts now describe the optional tuck-in check,
  and the iPhone launch screen uses an adaptive warm neutral color asset instead of the
  generated empty launch dictionary. Regenerated the project and verified Debug, Release,
  packaged plist/assets, simulator presentation, and all 33 tests.
- **2026-07-18 · Codex:** Repositioned the active product around one phase-aware Night
  Watch spanning wind-down, overnight, and morning quiet. Added persisted bedtime/wake
  preferences, configurable quiet bookends, gentle offline cues, wind-down reminders,
  phase-aware iPhone/Watch/Live Activity surfaces, morning completion, and quiet-minute
  reward accounting that excludes overnight hours. Legacy runs still decode and retain
  their prior behavior. Added schedule/reward/compatibility tests and ADR-0006. Family
  Controls reports and shielding remain behind C5/D3 and human entitlement approval. Added
  an adaptive night palette and reconciled README, PRD, architecture, implementation notes,
  asset map, and TestFlight QA with the implemented product and ADR-0005 dependency.
- **2026-07-11 · Codex + human decision:** Added the embedded WidgetKit/ActivityKit
  Live Activity. A Focus Run now starts a glanceable Lock Screen/Dynamic Island status
  (also available to the paired Watch Smart Stack) using the system timer; it ends when
  the run is finished in-app. `NSSupportsLiveActivities` is enabled and a signed archive
  confirms the extension bundle is embedded. Completion-only intermittent reward variety
  is now the documented habit-formation direction.
- **2026-07-11 · Codex:** Focus Run feedback fixes. Starting from setup now returns
  directly to the active run, an unavailable Watch placement check automatically falls
  back to the timer, and completed Watch/timer runs now reach the reward + one gentle progress note.
  The return-to-phone copy explicitly welcomes a progress check without claiming to infer
  physical distance. Watch Ollie now uses the same pixel-art assets as iPhone.
- **2026-07-11 · Codex + human decision:** Focus Run architecture reset (steps 1–10).
  The iPhone now owns timing, restore, completion, and local notification scheduling.
  The default phone-away timer does not require the Watch or either app to stay open.
  Watch/UWB is a short optional placement assist; its old continuous warning, sampled
  check, demo, and fallback-coordinator paths were removed. A non-blocking QR phone-bed
  guard with manual fallback is available; NFC and Family Controls shielding remain gated.
- **2026-07-11 · Codex + human:** A3-remainder. Confirmed permanent bundle root
  `com.ngawangchime.countingsheep`, configured Team ID `4KZQPZR47B`, generated Xcode-managed
  iPhone/Watch provisioning profiles, and completed a signed Release archive.
- **2026-07-11 · Codex:** A6. Release Stats now exposes only Today and Trends backed by
  native `UserProgress` and reward data, with bedtime-framed nights, streak, minutes,
  stars, and recent history. HealthKit, Screen Time, manual logs, QA, analytics history,
  and export remain Debug-only. Removed the remaining Screen Time cards from Release Home.
- **2026-07-11 · Codex:** A7b + B2b. Added Watch VoiceOver labels/hints across setup,
  running, warning, completion, and early-end flows. Replaced framework jargon, warning
  pressure, productivity framing, and punitive early-end presentation with gentle copy.
- **2026-07-11 · Codex:** B4a. The third-run sheep cycle now holds a `3 / 3` celebration
  state with “A new sheep joined the flock!” before progress rolls forward.
- **2026-07-11 · Codex:** B4. Analytics export is unreachable in Release because the
  Insights surface is Debug-only; the known relative-date issue cannot ship in build 1.
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
