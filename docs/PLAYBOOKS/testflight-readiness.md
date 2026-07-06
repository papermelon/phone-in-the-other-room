# Playbook: TestFlight Readiness

Step-by-step preparation for shipping the first TestFlight build of Counting Sheep.
Work top-to-bottom; earlier sections block later ones. Scope decisions are fixed in
`docs/PROJECT_BRIEF.md` (two tabs; gated features per ADR-0003/0004) — do not relitigate
them here.

State when this playbook was written (July 2026): the project is deliberately configured
for **unsigned local development**. Everything in §1–§2 is expected to be red at first.

## 1. Apple account prerequisites (human tasks, start immediately)

- [ ] Apple Developer Program membership active.
- [ ] Decide the permanent bundle ID root (e.g. `com.<org>.countingsheep`) — it cannot
      change after first upload.
- [ ] **Submit the Family Controls distribution request** (Apple form: "Family Controls
      Distribution"). Not needed for build 1, but the approval lead time is weeks —
      submit before you need it. (ADR-0004 depends on it.)
- [ ] Create the App Store Connect app record (name "Counting Sheep"; check availability
      early — names are contested).
- [ ] Register the App ID(s) with HealthKit capability (needed by build 2, harmless now).

## 2. Build identity and signing (in `project.yml`, then `xcodegen generate`)

- [ ] Replace `bundleIdPrefix: com.example` and all `com.example.*` bundle IDs with the
      real root. Watch app keeps the `.watchkitapp` suffix and its
      `WKCompanionAppBundleIdentifier` must match the new iOS bundle ID exactly.
- [ ] Set `DEVELOPMENT_TEAM` to the real team ID.
- [ ] Remove `CODE_SIGNING_ALLOWED: NO`, `CODE_SIGNING_REQUIRED: NO`, and the empty
      `CODE_SIGN_IDENTITY` overrides; use automatic signing.
- [ ] Set `MARKETING_VERSION` (e.g. `0.1.0`) and `CURRENT_PROJECT_VERSION` (e.g. `1`)
      for iOS + Watch targets.
- [ ] Wire `CODE_SIGN_ENTITLEMENTS` only for entitlements that are real *and* enabled in
      the portal. For build 1 (no HealthKit, no Screen Time) the empty entitlement files
      are correct — do not add keys speculatively (signing will fail).
- [ ] `xcodegen generate`, then verify Archive succeeds:
      `xcodebuild archive -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS'`
- [ ] The Screen Time report extension stays **unembedded** in build 1 (it ships later
      with ADR-0004 work). Confirm it is not in the app's dependencies in `project.yml`.

## 3. App identity checks

- [ ] Display name "Counting Sheep" on iPhone and Watch (`CFBundleDisplayName`).
- [ ] App icon renders (1024 universal for iOS 17+ is acceptable); Watch icon present.
- [ ] No user-visible string says "Phone in the Other Room" (repo name may — that's fine).
- [ ] Replace redacted/placeholder art that `ASSET_NOTICE.md` flags before public builds,
      or confirm the current art is cleared for distribution.

## 4. Scope and mock-data checks (per ADR-0003)

- [ ] Release build shows exactly two tabs: Home and Stats.
- [ ] Farm / Friends / Shop and all Screen Time UI are unreachable in Release
      (DEBUG-gated), with no "coming soon" placeholders.
- [ ] `MVPMockData` is not referenced by any Release code path (grep it).
- [ ] `PixelHomeDashboard` hardcoded values fixed: Watch connection status reflects
      `WatchConnectivityManager` reality; sheep reward progress reads `UserProgress`.
- [ ] `FocusStatsView` DEBUG placeholder/QA datasets cannot appear in Release.
- [ ] Stats copy is bedtime-framed ("nights your phone slept in the other room").

## 5. Onboarding checks

- [ ] Fresh-install flow: a new user can reach a started Focus Run without confusion —
      including pairing expectations ("open the Watch app").
- [ ] The no-Watch / no-UWB user gets an honest, warm explanation (the `unsupported`
      path), not a dead end.
- [ ] Notification permission is requested in context (when starting a run), not at launch.

## 6. Permission and privacy checks

- [ ] Privacy strings present and consistent with the app name:
      `NSNearbyInteractionUsageDescription` (iOS + Watch). No HealthKit/Screen Time
      strings needed in build 1 (features absent) — remove or keep consistent if present.
- [ ] App Store privacy "nutrition label" prepared: build 1 collects nothing off-device
      (UserDefaults only, no analytics SDKs, no network calls). Verify that stays true.
- [ ] Analytics export (if reachable in build 1) writes only to user-visible share sheets;
      check the known `relativeDays` redaction bug before shipping export, or gate export.
- [ ] No accounts, no tracking, no third-party SDKs — confirm and state in review notes.

## 7. Crash-risk checks

- [ ] Background the app mid-run, lock the phone, return after 10 min: no crash, honest
      state (foreground-only limitation is communicated, not silently broken).
- [ ] Kill the app mid-run and relaunch: state restores or resets gracefully via
      `ollie.lastRun`.
- [ ] Watch out of range / Bluetooth off mid-run: `signalLost` path works, copy is kind.
- [ ] Run on a non-UWB device: `unsupported` path, no NI crash.
- [ ] Decode of old persisted JSON (`UserProgress` legacy test) passes.
- [ ] Midnight rollover during an active run: daily record lands on a sane day.
- [ ] Watch app launched with phone unreachable: rehydration path doesn't hang.

## 8. UI polish checks

- [ ] Dynamic Type: core flow (dashboard, setup, active run, completion) survives large
      text sizes without truncation of critical info.
- [ ] Dark-room comfort: evening screens have no white flashes or harsh contrast.
- [ ] VoiceOver: run timer, proximity state, and primary buttons are labeled; the run can
      be started and ended with VoiceOver alone.
- [ ] Watch screens legible at a glance; complications/notifications render.
- [ ] No debug UI, console spam, or developer text in Release.

## 9. Manual QA script (run on hardware before each upload)

1. Fresh install (delete app + Watch app first). Complete onboarding.
2. Start a 15-minute Focus Run; walk the phone to another room; confirm Watch shows
   distance and state transitions (grace → waiting → running).
3. Trigger a warning: bring the phone back mid-run; confirm warning state and recovery.
4. Complete the run; confirm stars/reward/streak update and persist after app restart.
5. Start another run and end it early; confirm the muddy-paw consolation, no shame copy.
6. "Whistle" from the Watch; confirm the phone pings.
7. Check Stats tab reflects both runs, bedtime-framed.
8. Repeat run start with Watch unreachable (airplane mode on Watch): honest failure.
9. TestFlight-install the build on a second device model if available.

## 10. Do NOT add before TestFlight

- HealthKit sleep card (build 2), Screen Time reports/pickers, NFC/QR sessions (ADR-0004)
- Farm/Friends/Shop reintroduction (ADR-0003)
- New dependencies, analytics SDKs, or accounts
- Design-system refactors, file splits, or architecture cleanups not on the blocker list
- Any new feature that hasn't passed the belonging test in `docs/PRODUCT_PRINCIPLES.md`

Ship the smallest honest build. Everything else has a gate and a place in
`docs/FUTURE_AGENT_TASKS.md`.
