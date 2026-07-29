# Playbook: TestFlight Readiness

Prepare the first Counting Sheep TestFlight build from top to bottom. Product scope is fixed
by `PROJECT_BRIEF.md` and ADR-0003/0004/0006: two Release tabs, one Night Watch, no release
HealthKit or Screen Time UI.

Last reconciled with `project.yml` and the Night Watch implementation: 2026-07-18.

## 1. Human account and distribution work

- [ ] Apple Developer Program membership is active.
- [ ] App Store Connect record exists for **Counting Sheep**.
- [ ] Permanent iOS bundle ID `com.ngawangchime.countingsheep` is registered and correct.
- [ ] Team `4KZQPZR47B` is the intended distribution team.
- [ ] Family Controls distribution request is submitted for the later Screen Time milestone.
- [ ] Current artwork is cleared for distribution per `ASSET_NOTICE.md`.
- [ ] App Store privacy disclosures cover every enabled network feature and dependency.

## 2. Generated project and signing

- [ ] `project.yml` remains the only project source of truth; no hand-edited pbxproj changes.
- [ ] `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` match the planned upload.
- [ ] Automatic signing resolves for iPhone, Watch, and Live Activity targets.
- [ ] Empty/deferred entitlement files contain no speculative HealthKit or Family Controls keys.
- [ ] Screen Time report extension remains unembedded for build 1.
- [ ] `xcodegen generate` completes, then a signed archive succeeds:

```bash
xcodebuild archive \
  -project PhoneInTheOtherRoom.xcodeproj \
  -scheme PhoneInTheOtherRoom \
  -destination 'generic/platform=iOS'
```

## 3. Product identity and release scope

- [ ] iPhone and Watch display name is **Counting Sheep**.
- [ ] No active customer surface calls the ritual a Focus Run or generic focus session.
- [ ] Release exposes exactly Home and Stats.
- [ ] Farm, Friends, Shop, `MVPMockData`, HealthKit, Screen Time selection/report UI, manual
      analytics, and QA datasets are unreachable in Release.
- [ ] Home immediately communicates both quiet bookends and the Night Watch schedule.
- [ ] Stats describe protected nights and quiet bookends, not productivity output.
- [ ] App Shortcut is **Night Watch** and opens the app without silently starting a timer.

## 4. Fresh-install and setup checks

- [ ] A fresh user can set bedtime, wake time, both quiet-window lengths, and two offline cues.
- [ ] Saving outside the start window requests notification permission in context and creates
      the correct wind-down reminder.
- [ ] Inside the start window, the primary action begins Night Watch in one tap after setup.
- [ ] Honor timer is the default and never requires Watch/UWB.
- [ ] Watch-unreachable and non-UWB paths offer warm timer fallback rather than a dead end.
- [ ] QR phone bed supports camera denial/unavailability through the manual-code fallback.

## 5. Permission and privacy checks

- [ ] iOS and Watch `NSNearbyInteractionUsageDescription` strings describe one optional
      Night Watch tuck-in check.
- [ ] Camera purpose string describes only the QR phone-bed scan.
- [ ] Notifications are requested on plan save/start, never as generic re-engagement.
- [ ] Build 1 does not expose a permission request for gated Screen Time or HealthKit UI.
- [ ] No GPS or room-identification claim appears in metadata or onboarding.
- [ ] Supabase Live Activity push is either intentionally configured and disclosed or disabled.
- [ ] Logs never print raw ActivityKit push tokens, secrets, or selected Screen Time tokens.

## 6. Core Night Watch behavior

- [ ] Wind-down, overnight, and morning quiet are phases of one persisted run.
- [ ] iPhone, Watch, and Live Activity agree on the current phase and next transition.
- [ ] Starting late protects only remaining bookend time and keeps the intended-bedtime date.
- [ ] Overnight hours never enter quiet-minute totals, reward rarity, stars, sheep, or coins.
- [ ] Completion notification fires at the morning-quiet end, not at bedtime.
- [ ] Ending early is always available and uses no failure haptic, shame, or loss language.
- [ ] An unavailable placement check continues as an honor timer.
- [ ] QR/Watch placement evidence gates only the initial tuck-in; later distance never warns
      or ends the session.

## 7. Restoration and edge cases

- [ ] Lock/background during wind-down, overnight, and morning quiet; returning shows the
      correct phase without restarting the clock.
- [ ] Terminate and relaunch in each phase; `ollie.lastRun` restores or completes gracefully.
- [ ] Relaunch after the planned end reconciles completion and records the intended-bedtime day.
- [ ] Test a run across local midnight.
- [ ] Test spring-forward and fall-back schedules on physical hardware where practical.
- [ ] Change timezone during a test plan and record the chosen policy/result.
- [ ] Watch unreachable or Bluetooth disabled mid-run does not alter iPhone authority.
- [ ] Legacy `FocusRun` and `UserProgress` JSON decode tests pass.

## 8. ActivityKit, notifications, and Watch

- [ ] Live Activity starts once, shows phase-aware copy, and counts to the next transition.
- [ ] Lock Screen, Dynamic Island, and paired-Watch Smart Stack layouts remain legible.
- [ ] Local morning notification is the reliable completion fallback without remote push.
- [ ] Reset, early end, replacement, and completion dismiss the matching Live Activity.
- [ ] Watch rehydrates after launch and presents the same Night Watch plan.
- [ ] Watch placement stops after confirmation/unavailability and releases Nearby Interaction.
- [ ] Ping Phone works with reachable and queued delivery paths.

## 9. UI, accessibility, and bedtime comfort

- [ ] Core screens survive large Dynamic Type without hiding primary actions or phase time.
- [ ] VoiceOver can configure, begin, understand, and end Night Watch.
- [ ] Timers announce the next Night Watch transition rather than an unexplained duration.
- [ ] Decorative art is hidden; meaningful Ollie/phone-bed imagery has concise labels.
- [ ] Touch targets meet 44-point minimums.
- [ ] Evening surfaces are calm, with no urgent colors, flashing, or loud celebration.
- [ ] Copy contains no medical promise, productivity jargon, reward tease, or missed-night guilt.

## 10. Local merge gate

- [ ] `xcodegen generate`
- [ ] Debug simulator build succeeds for the shared scheme.
- [ ] Release simulator build succeeds for the shared scheme.
- [ ] Full unit suite passes on an available iPhone simulator.
- [ ] `git diff --check` is clean.
- [ ] Release simulator visual pass confirms two tabs and no gated UI.
- [ ] Human reviews L-risk coordinator/state changes before merge.

## 11. Physical overnight QA script

1. Fresh-install iPhone and Watch apps.
2. Save a near-term bedtime/wake plan and allow notifications.
3. Begin with honor timer; lock the phone through all three phases.
4. Verify Live Activity transitions and morning notification.
5. Relaunch and confirm the completion receipt, quiet-minute split, reward, and Stats date.
6. Repeat with Watch placement; turn off Bluetooth after tuck-in and confirm the timer continues.
7. Repeat with QR; test camera permission denial and manual fallback.
8. End once during wind-down and once during morning quiet; confirm accurate partial minutes.
9. Ping the phone from Watch.
10. Install the TestFlight build on a second supported iPhone model and repeat the core path.

## 12. Do not add to build 1

- Embedded Screen Time reports, FamilyActivityPicker, or ManagedSettings shielding
- HealthKit sleep card
- NFC phone-bed interaction
- Farm, Friends, Shop, or social/backend engagement features
- New analytics/tracking SDKs
- A second morning timer, generic duration picker, or all-day productivity mode

Ship the smallest honest Night Watch. Deferred features stay in `FUTURE_AGENT_TASKS.md`.
