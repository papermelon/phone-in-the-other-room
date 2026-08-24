# Architecture Map — Counting Sheep

Practical architecture reference for humans and agents. Canonical rules live in
[`AGENTS.md`](../AGENTS.md); this file goes deeper on structure, data flow, and risk.

Last verified against code: 16 August 2026.

## 1. Stack and build system

- Swift 5.9, SwiftUI, iOS 17.0+, watchOS 10.0+
- **XcodeGen**: `project.yml` is the source of truth; `PhoneInTheOtherRoom.xcodeproj` is
  generated. Run `xcodegen generate` after adding/moving files or editing `project.yml`.
  Never hand-edit `project.pbxproj`.
- One approved SPM dependency: official `supabase-swift`, limited to optional ActivityKit,
  consented impact-data, gated feedback, and ADR-0016 Slumber Party paths. No CocoaPods
  dependencies. No CI
  (local build + test is the gate).
- Eight application/extension/test targets plus shared domain code.

## 2. Targets

| Target | Type | Sources | Notes |
|---|---|---|---|
| `PhoneInTheOtherRoom` | iOS app | `Shared/` + `PhoneInTheOtherRoomApp/` + assets | Display name "Counting Sheep". Embeds the Watch app. iPhone-only (`TARGETED_DEVICE_FAMILY: 1`). |
| `PhoneInTheOtherRoomWatchApp` | watchOS app | `Shared/` + `PhoneInTheOtherRoomWatchApp/` | Optional companion: mirrors the phone-authoritative timer for timer/NFC protection flows. UWB placement is deferred. |
| `PhoneInTheOtherRoomLiveActivity` | iOS Widget extension | `Shared/` + `PhoneInTheOtherRoomLiveActivity/` + assets | Embedded Live Activity for Lock Screen, Dynamic Island, and paired-Watch Smart Stack status. |
| `PhoneInTheOtherRoomScreenTimeReport` | iOS app extension | `Shared/` + `PhoneInTheOtherRoomScreenTimeReport/` | Embedded DeviceActivity report extension. Main app and extension compile the `SCREEN_TIME_REPORTS` paths and share scoped selections through the App Group. |
| `PhoneInTheOtherRoomDeviceActivityMonitor` | iOS app extension | `Shared/` + `PhoneInTheOtherRoomDeviceActivityMonitor/` | Applies and clears scheduled wind-down/morning shields while the app is suspended. |
| `PhoneInTheOtherRoomShieldConfiguration` | iOS app extension | `PhoneInTheOtherRoomShieldConfiguration/` + shared shield-presentation contract + local asset catalog | Role-aware ManagedSettings shield with finite first-party cues, the real protected-session end time, and a full-colour Ollie/sheep companion. |
| `PhoneInTheOtherRoomShieldAction` | iOS app extension | `PhoneInTheOtherRoomShieldAction/` | Handles role-aware Return to Quiet Time / Return to Wind Down actions on iOS 26.5+; safely closes the shielded app on older OS versions. |
| `PhoneInTheOtherRoomTests` | unit tests | `Shared/` + `Tests/` | Shared-domain coverage, including Night Watch schedule and legacy decoding. |

Schemes: `PhoneInTheOtherRoom` (builds iOS + Watch, runs tests) and
`PhoneInTheOtherRoomScreenTimeReport` (extension only).

## 3. Module map

```
Shared/                        Pure domain logic (no UI, unit-testable)
├─ Models/OllieModels.swift      FocusRun, FocusRunState, UserProgress, flock count,
│                                daily records, legacy economy fields
├─ RewardModels.swift            legacy keepsake compatibility types and context
├─ ProximityClassifier.swift     legacy/shared distance buckets (placement only)
├─ FocusRunRules.swift           timing and completion eligibility
├─ SessionGuard.swift            shielding-timer/NFC guard metadata; Watch/QR legacy decode values
├─ NightWatch.swift              saved sleep-bookend plan, phases, activities, factual bookend timing
├─ WindDownScheduling.swift      versioned schedule state, recurrence, one-time periods, overlap rules, aggregation
├─ NightsHistorySummary.swift    wake-day/start-day presentation summaries for week, month, and day history
├─ NightJourneyProgress.swift    run/phase-aware wall-clock journey reducer
├─ NightJourneyTerrain.swift     periodic terrain height and slope profiles
├─ OfflinePurpose.swift          private offline intention + notification privacy choice
├─ RewardEngine.swift            protected-night progress + legacy reward updates
├─ FocusAnalytics.swift          day records, correlations, CSV/JSON export
├─ ImpactMeasurement.swift       local outcome comparison + minimised sharing record
├─ NightFlockModels.swift        seven-day rules and backward-compatible social domain
├─ NightFlockCommitment.swift    bounded shared goals, member status, setup, and shielding evidence
├─ NightFlockV2API.swift         explicit schema-two commitment commands and responses
├─ NightFlockV3API.swift         schema-three nightly metrics and grant acknowledgements
├─ NightFlockSharing.swift       independent sharing defaults, rounding, and projections
├─ NightFlockRewards.swift       bounded Slumber Party Farm grant rules and local ledger
├─ NightFlockOrientation.swift   persisted Slumber Party guide and contextual tips
├─ NightFlockPresentation.swift  aggregate and privacy presentation derivations
├─ NightFlockAPI.swift           versioned commands/state + monotonic outbox contracts
├─ NightWatchHistory.swift       90-day aggregate records + idempotent ritual events
├─ PhoneBedTag.swift             named primary/backup NDEF tag library and purpose rules
├─ PastureScene.swift             versioned local pasture layout, settling, and deterministic ambient plans
├─ QuietTimeShieldSchedule.swift schedule/status/evidence App Group contract
├─ WatchMessage.swift            typed phone↔watch message envelope + codec
├─ ScreenTimeIntegration.swift   Screen Time scopes + report context IDs (phone-other.*)
├─ SleepIntervalMath.swift       merge sleep intervals → SleepSummary
├─ MorningCheckIn.swift          private, optional morning reflections (no score/reward)
├─ Onboarding.swift              first-run Wind Down setup draft, questionnaire skip/grant rules, and protection choices
├─ WindDownProfile.swift          local questionnaire answers and Wind Down starting point
├─ WindDownProfilePresentation.swift  questionnaire and recommendation copy
├─ FirstRunJourney.swift          resumable Home/practice/Farm/Settings/Nights guide steps
├─ WelcomeReward.swift            starter sheep, pending wearable gift, and practice grant ledger
├─ SheepSearchWelcome.swift       starter and onboarding-practice search calculations
├─ SheepSearchPresentation.swift  user-facing welcome-gift and homecoming copy
├─ WindDownGuidance.swift         finite, source-linked screen-time and sleep-habit ideas
├─ SheepSearch.swift               deterministic search outcomes, posters, rarity, habitats
├─ SheepSearchState.swift          versioned outcomes, trail-map credit, and persisted state
├─ FarmModels.swift                versioned owned flock, discovery, balances, equipment, history
├─ FarmEconomyRules.swift          capacity, shearing, regrowth, sale, and balance invariants
├─ FarmMigration.swift             deterministic outcome/legacy-flock reconciliation
├─ FarmShop.swift                  fixed local catalogue, purchase, upgrade, and equipment rules
├─ Orientation.swift                versioned first-run guide (schema 6) + contextual-tip migration
├─ AppFeedback.swift             validated feedback draft/attachment/receipt protocol
├─ DistanceProvider.swift        protocol: async stream of distance readings
└─ Formatting.swift              OllieFormat timer/minute formatting

PhoneInTheOtherRoomApp/        iOS app
├─ App/                          @main entry, App Intents / Shortcuts
├─ Design/                       Theme.swift + PixelComponents.swift — design system
├─ Proximity/
│  ├─ FocusSessionCoordinator.swift            ← THE phone-authoritative run coordinator
│  └─ NearbyInteractionDistanceProvider.swift  iPhone NI session for optional placement
├─ Services/                     singletons for side effects
│  ├─ PersistenceService.swift                 JSON-in-UserDefaults store
│  ├─ WatchConnectivityManager.swift           WCSession (phone side)
│  ├─ PhoneNotificationService.swift           local notifications + tap routing
│  ├─ NightWatchUsageMonitoringService.swift   phase-scoped DeviceActivity thresholds
│  ├─ PingService.swift                        haptic/sound "whistle" at phone
│  ├─ FocusModeSuggestionService.swift         Focus Mode guidance strings
│  ├─ HealthSleepService.swift                 optional, read-only HealthKit sleep reads
│  ├─ PhoneBedNFCService.swift                 Core NFC provision/scan lifecycle
│  ├─ QuietTimeShieldingService.swift          schedule/apply/clear ManagedSettings
│  ├─ ImpactDataSyncService.swift              optional minimised Supabase upsert/delete
│  ├─ FeedbackService.swift                    gated private upload + Edge Function client
│  ├─ ScreenTimeAuthorizationService.swift     FamilyControls auth (flag-gated)
│  ├─ ScreenTimeSelectionService.swift         FamilyActivitySelection per scope
│  ├─ AnalyticsExportService.swift             JSON/CSV export to temp files
│  ├─ SupabaseClientProvider.swift             configured official Swift client
│  ├─ SupabaseAuthenticationService.swift      anonymous-session restore/create
│  ├─ SupabaseLiveActivityRemoteSink.swift     disabled-by-default push registration sink
│  ├─ NightFlockAccountService.swift           anonymous-to-Apple identity linking
│  ├─ NightFlockService.swift                  typed Edge Function client
│  └─ NightFlockOutboxService.swift            local monotonic v1/v2 retry queue
├─ ViewModels/FocusRunViewModel.swift          root view model, owns coordinator + Slumber Party VM
├─ ViewModels/NightFlockViewModel.swift        feature-gated social presentation and intents
├─ Views/
│  ├─ HomeView.swift                           navigation shell + run-state routing
│  ├─ PixelHomeDashboard.swift                 home tab
│  ├─ Components/OrientationTourOverlay.swift  shared spotlight guide for Home and contextual tips
│  ├─ FocusRunSetupView.swift                  bedtime/wake, bookends, purpose + guard
│  ├─ ActiveRunView.swift                      in-run UI + non-scrolling journey state
│  ├─ CompletionView.swift / EarlyEndView.swift
│  ├─ FocusStatsView.swift                     latest-primary Nights overview + grouped context
│  ├─ NightsWeekSection.swift                  seven-day board + all-nights navigation
│  ├─ MonthlyNightsView.swift                  shared-summary month calendar
│  ├─ NightsDayDetailView.swift                grouped day occurrences + factual record detail
│  ├─ FarmView.swift                           production Farm dashboard and destination routing
│  ├─ NightFlock/                              invite, hub, trail, pasture, safety, result views
│  ├─ FarmPastureView.swift                    paged, grounded living flock scene with local character placement
│  ├─ BarnView.swift                           owned flock, capacity, lifecycle, and pending arrivals
│  ├─ TrailBoardView.swift                     internal view name for Ollie's Search
│  ├─ TrailNotesArchiveView.swift              internal view name for Search Journal
│  ├─ FarmShopView.swift                       local purchases, upgrades, and equipment
│  ├─ ShepherdCustomizationView.swift          local player-avatar editor
│  ├─ MoreView.swift                           Compact Settings root: Your Wind Down, Connections, Privacy & data, Help & app guide
│  ├─ WindDownTimingView.swift                  compact saved schedule editor
│  ├─ WindDownScheduleView.swift                 finite Once / Repeats / Usual Wind Down editor
│  ├─ FeedbackFormView.swift                   validated form + email fallback
│  ├─ RewardShelfView.swift                    Debug internal preview only
│  ├─ Components/QRCodeScannerView.swift       retained legacy compatibility component (not release-facing)
│  ├─ Components/NightWatchReceiptCard.swift   elapsed/bookend/sleep/data-status receipt
│  ├─ Components/MorningCheckInCard.swift       collapsed, optional morning reflection
│  ├─ Components/GameComponents.swift          legacy UI retained outside run flow
│  ├─ Components/AssetPlaceholderComponents.swift  placeholder/sprite fallbacks
│  └─ MVP/AssetReadyScreens.swift              GATED: legacy Farm/Friends/Shop mock screens
└─ MockData/MVPMockData.swift                  GATED: feeds MVP screens only

PhoneInTheOtherRoomWatchApp/   watchOS companion
├─ App/                          @main
├─ Services/                     WatchConnectivityManagerWatch, WatchNotificationService
├─ ViewModels/WatchRunViewModel.swift          watch-side run state
└─ Views/                        WatchSetupView, WatchRunView, WatchWarningView,
                                 WatchCompletionView, WatchEarlyEndView, WatchOllieIconView

PhoneInTheOtherRoomLiveActivity/ iOS WidgetKit extension
├─ FocusRunLiveActivityWidget.swift              Lock Screen + Dynamic Island layouts
├─ QuietNoteWidget.swift                          configurable Lock Screen cue below the clock
└─ Info.plist                                    Widget extension declaration

PhoneInTheOtherRoomScreenTimeReport/
└─ ScreenTimeReportExtension.swift   3 DeviceActivity report scenes:
                                     today / weekly / late-night (phone-other.*)

PhoneInTheOtherRoomDeviceActivityMonitor/  background bookend shield callbacks
PhoneInTheOtherRoomShieldConfiguration/    shield appearance
PhoneInTheOtherRoomShieldAction/           shield-button response

Config/                         local Supabase xcconfig values; secrets remain untracked
supabase/                       versioned ADR-0005 migrations and Edge Functions
```

## 4. Data flow

### Wind Down lifecycle (implemented by the internal Night Watch model)

```mermaid
stateDiagram-v2
    [*] --> setup
    setup --> windDown: required app protection + timer guard authorized
    setup --> windDown: required app protection + NFC guard authenticated
    windDown --> overnight: intended bedtime reached
    overnight --> morningQuiet: saved wake time reached
    morningQuiet --> completed: morning bookend elapsed
    windDown --> endedEarly: configured end or emergency exit
    overnight --> endedEarly: configured end or emergency exit
    morningQuiet --> endedEarly: configured end or emergency exit
    completed --> setup: reset
    endedEarly --> setup: reset
```

Sequence per Night Watch (persisted internally as `FocusRun` for data compatibility):

1. `PixelHomeDashboard` → `FocusRunSetupView` saves `NightWatchPreferences`: bedtime,
   wake time, quiet-window lengths, an ordered private sequence of up to three evening and two
   morning suggestions (putting the phone away is fixed first in the evening), and the placement
   guard. Suggestions have no checkmarks, verification, reward, score, streak, or completion claim.
   Outside the start window, the app saves the plan and schedules a wind-down reminder.
   The user-facing actions are **Put phone away**, **Start now**, and **Plan**. Guidance sits beside
   routine choices, on Home, and in phase-appropriate moments. Home selects at most one compact
   routine-linked idea below the primary Wind Down action; active primary Wind Down selects at
   most one item for the current evening or morning phase after essential controls, and suppresses
   guidance overnight. Phone Away has no guidance placement. The full source library is local
   and reached from the secondary **About these ideas and sources** link; “finite guide” is not
   user-facing copy.
2. `FocusRunViewModel.requestStartNightWatch()` anchors a `NightWatchPlan` to tonight and
   starts `FocusSessionCoordinator`. One phone-authoritative coordinator owns Wind Down and a
   linked, independently settled Screen-Free Morning occurrence; there is no competing app-root
   state machine.
3. The iPhone coordinator creates the run and schedules one foreground timer for the next
   semantic boundary (bedtime, wake time, or `plan.protectedUntil`), never a repeating
   countdown timer. SwiftUI renders visible countdowns from absolute dates. The view model
   schedules silent sleep-time and phone-free-morning transitions plus the audible completion
   the user requested. The coordinator persists and mirrors the run only at meaningful state
   and lifecycle events; when the optional ActivityKit delivery path is deployed, the backend
   sends phase updates at the same two boundaries so the Live Activity can advance while the
   app is suspended.
4. The honor-timer path completes without either device being foregrounded. Current release
   setup offers App Shielding (`.honorTimer`) or NFC + App Shielding (`.nfcTag`). Legacy
   `.watchPlacement` and `.qrCode` values remain decodable and normalize to the timer for new
   release flows; their older implementation is not user-selectable. `.nfcTag` reads a
   provisioned NDEF record and compares its local token digest against a versioned library.
   The library supports one named primary and one optional named backup; either can be assigned
   to Wind Down, Phone Away, or both. A failed scan can explicitly pair a replacement writable
   tag without restarting the current run. The old slot remains authoritative until a successful
   write, duplicate credentials are rejected, and only a tag assigned to the active mode can
   authenticate it. Replaced credentials are retained as local digests so a retired physical tag
   is rejected with a resync-from-Settings message instead of receiving success feedback or being
   silently overwritten. Names and purposes remain local and are never written to NFC. When automatic
   Wind Down is enabled, the saved plan
   schedules the selected local notification cadence and future DeviceActivity shielding
   while the app is closed; optional usage-aware monitoring is installed independently for
   wind-down, overnight, and morning quiet, with one generic three-minute cue per phase.
   The next app activation reconstructs the local run.
   Notification copy is resolved by the shared `NotificationCopyResolver` from a stable
   template ID, the current plan context, and local overrides. Settings previews call the
   same resolver before pending `UNNotificationRequest` values are rebuilt. Supported
   placeholders are optional (`{activity}`, `{purpose}`, `{time}`, and `{minutes}`); fixed
   protection notices bypass overrides.
5. The Watch mirrors the authoritative run and never starts one from schedule defaults.
   An explicit no-run state from the iPhone clears any stale Watch application context.
6. Required app protection derives a protected-session DeviceActivity schedule from this same
   `NightWatchPlan`. Every new Wind Down, Screen-Free Morning, and Phone Away start requires
   Family Controls authorization plus a non-empty opaque app/category selection. Runtime apply
   failure fails open and routes to repair; it is not a timer-only alternative. Readiness is a
   separate Screen Time state; changing the future preference cannot lift an active run's
   requested barrier. NFC authenticates start/end only and does not decide whether shielding is
   requested. After an eligible start (or the registered NFC tag confirmation),
   ManagedSettings applies through wind-down, overnight, and morning quiet, then clears
   on terminal/reset/replacement. A bounded App Group status history distinguishes observed
   shield time from a requested schedule; legacy two-bookend snapshots remain decodable.
   The app/category-only Brief Access action stores a versioned pending/scheduled grant
   record with run ID, schedule revision, nonce, clamped expiry, and one-shot restore
   activity name. Its bounded per-run ledger survives extension-only cleanup until the
   main app imports the factual count into the active run/history record. Restore callbacks
   accept a grant only for the same run/revision; a pending or stale callback instead
   reconciles the current schedule and reapplies its existing shield when that phase is
   still eligible. Web domains never advertise or receive Brief Access.
   The App Group snapshot carries a backwards-compatible `QuietTimeShieldRole` (legacy
   snapshots resolve to primary Wind Down). Shield Configuration selects a deterministic
   first-party cue for Phone Away, Wind Down, overnight, or morning
   quiet and uses the protected-session interval—not a bookend—as the displayed end time.
   Its Ollie/sheep icon is decorative; the companion sheep is not a search result, reward,
   or owned flock item.
7. At 420 eligible minutes, the coordinator privately resolves one immutable Wind Down outcome in
   the standard-defaults settlement journal. On authorized terminal delivery, `RewardEngine`
   retains compatibility updates while crediting only the factual Wind Down bookend; Screen-Free
   Morning settles independently into Sunrise Trail from actual eligible minutes. The journal
   then projects the resolved result and one individual `FlockSheep` arrival into `FarmState`.
   Available arrivals enter the active flock; capacity overflow remains pending. The completed
   protected-night count also advances wool regrowth. Progress is attributed to the intended-
   bedtime date, then `PersistenceService` saves and the Watch gets the terminal message. See
   `docs/REWARDS.md` and ADR-0015.
8. `HomeView` routes to `CompletionView` / `EarlyEndView` based on `activeRun.state`.
   Both outcomes show the same factual receipt: elapsed phone-away time, the Wind Down
   bookend, and a separate Screen-Free Morning factual row where applicable, plus optional
   Apple Health sleep context and an explicit Screen Time availability
   state. The separate Nights tab stays finite and observational: seven-day results, monthly
   drill-down, reflection, Health context, and consented selected-app results. Farm owns the
   active flock, lifecycle, catalogue, Shop, and customization presentation; Settings owns plan
   and report configuration. Chosen report windows do not
   alter Wind Down or Phone Away. Missing data is never estimated.
   When ADR-0016's flag is enabled, Home and Farm may show one full-width contextual Slumber Party
   card supporting the shared seven-night goal; routines, schedules, absence, Health data, and
   private details remain unshared. Members may see named coarse progress inside the invited
   group. None of these surfaces changes rewards.
9. During an active Night Watch, Home is replaced by the live journey while Nights, Farm,
   and Settings remain mounted in the same four-tab shell. A persistent return strip resets
   nested navigation and returns to Home. Run start, app activation, and active-run notification
   routing make Home the default. ActiveRunPresentation supplies role-aware copy,
   accessibility, guidance, exit, and shielding-status affordances; Phone Away uses
   its actual plan end date and never borrows primary Wind Down phase language. Terminal
   receipts temporarily replace the shell. Completed Phone Away receipts read the persisted
   per-run settlement record, distinguishing practice, below-minimum time, credited banking,
   a full locked meter, and a resolved Phone Away bonus search in Search Journal; they never
   infer progress from the current meter.
10. `NightJourneyProgress` resolves overall, phase, and segment progress from the active
    `FocusRun`; `NightJourneyTerrainProfile` supplies a periodic height and derivative used by
    both the Canvas foreground and Ollie's foot alignment. Backdrops pan/zoom only within safe
    crop bounds, and deterministic clues at 20/55/82 percent never affect search resolution.
11. Successful Phone Away runs settle through pure Shared logic. The settlement applies at least
   15 credited minutes and the centrally configured 100-minute per-run cap to the versioned
   `SheepTrailMapState` nested in `SheepSearchState`; it banks one full locked meter before
   three protected Wind Downs, then keeps one carried remainder after unlock. A per-run
   `PhoneAwaySearchSettlementRecord` stores eligibility, applied delta, meter before/after, and
   any stable outcome ID. The coordinator persists that search snapshot before projecting Farm,
   and `PersistenceService.farmState` replays persisted found outcomes on launch through the
   existing idempotent Farm arrival path. Practice and early endings settle as ineligible, and
   no Phone Away settlement changes protected-night progress, Wind Down drought/starter state,
   rewards, wool, or Slumber Party state. The deterministic 20/30/40/50/100 ladder and Phone
   Away clue counter never alter Wind Down odds.
   Home and the Phone Away schedule offer a separate **Start now** action. It creates a
   temporary bounded occurrence for the single start transaction; Not now rolls it back, while
   starting consumes it. Scheduled rows keep their exact occurrence identity through
   confirmation, and the future-period editor does not participate in this path. Starting one
   never changes progress by itself. An eligible completion can fill the Phone Away meter and
   open its separate bonus search, but never changes protected-night progress or Wind Down odds.
12. After first-run setup, the `HomeView` shell presents a versioned, resumable first-run
    guide persisted as `ollie.orientation.state` (schema 6). Initial setup covers narrative
    welcome pages, the Wind Down starting-point questionnaire, sourced recommendations, schedule,
    optional shielding, a profile-gift announcement, and the saved-plan summary. The in-app
    guide offers a four-tip Home Basics chapter, pauses for exploration, and offers a four-tip
    Around the Farm chapter only after a user-initiated Farm visit. Practice, Slumber Party,
    Settings, and Nights are contextual destinations. Chapter presentation and resume routing are
    persisted while legacy journey JSON migrates to the nearest valid destination. A chapter-specific
    Resume card appears only for a genuinely paused chapter and can be dismissed. Completing the
    questionnaire owns the pending wearable even if the result screen
    is skipped; skipping the questions themselves does not grant it. Onboarding presents a direct
    keep-or-wear choice, and generic guide navigation never equips the gift. Resume returns
    to the current surface, including the practice sheet, and a coach still appears if a spotlight
    target is missing. Skipping a lesson does not grant rewards.
    Practice grants the second starter sheep only after a successful five-minute completion.
    Contextual tips stay suppressed during an active Wind Down. Settings can resume or replay the
    guide. Older three-step tour JSON remains decodable.

### Slumber Party run boundary

`FocusRunViewModel` owns and forwards one `NightFlockViewModel`; there is no second app-root or
session coordinator. A primary manual start creates its final run UUID before
`FocusSessionCoordinator.start`. If the challenge is active, membership sharing is enabled, and
the preflight was not private, the Slumber Party view model stores a local run-share context.

The coordinator calls `onPhoneAwayValidated` only after the selected NFC/honor guard has actually
made the run valid. That callback enqueues `phoneTucked`; successful primary completion enqueues
schema-three nightly metrics. A completed Phone Away can queue rounded minutes for the same
challenge day. An early end removes the context without a command. Automatic runs have no
context. Stable challenge/member/day/run-derived hashes make retries idempotent, and foreground
activation drains the monotonic UserDefaults outbox. Network work is asynchronous and never
gates local run state.

### Slumber Party shared commitment v2

The v2 path is additive to the v1 positive-state path. `NightFlockCommitment.swift` owns the
bounded goal catalogue, member setup/status, optional guidance IDs, and coarse shielding evidence.
`NightFlockV2API.swift` encodes schema-two commands; the Edge Functions validate them and route to
the timestamped commitment RPCs in `20260816100000_night_flock_shared_commitment_v2.sql`. The
database keeps a pending lobby until at least two members have accepted the goal and completed
local setup; only the host can explicitly start it. Reusable invites are hashed and capacity
limited. RLS exposes projections only to current members, while service RPCs enforce Apple-linked
authentication, idempotency, blocks, reports, retention, and deletion.

Invitation creation remains schema two but is recoverable. Before create or replacement, the
client stores one account-and-lobby-bound plaintext candidate in the non-synchronizing,
this-device-only Keychain. The server receives only its UUID, SHA-256 digest, and stable
idempotency key. Host-only snapshots expose the active invite UUID and expiry. Relaunch only
reconciles; replacing a missing local code is an explicit compare-and-swap mutation.

### Slumber Party social metrics and rewards v3

Schema three is additive. `NightFlockSharing.swift` owns independent sharing defaults and rounded
minute bounds. `NightFlockV3API.swift` publishes nightly metrics and grant acknowledgements.
`NightFlockRewards.swift` applies server-authoritative grants once through
`ollie.nightFlock.rewards`. The migration `20260816220000_night_flock_social_rewards_v3.sql`
stores member sharing columns, `night_flock_shared_metrics`, and `night_flock_reward_grants`.
v1/v2 clients keep their contracts; unknown schema versions fail closed.

Default-on fields after join consent: shared-goal progress, Wind Down completed/partly completed,
rounded Wind Down minutes, rounded Phone Away minutes, phone tucked away, and coarse shielding
status. Explicit opt-ins: sourced routine ideas, sleep duration, and restfulness. Hidden fields
are omitted from member projections; goal progress does not force completion or tucked-away
visibility. Sleep and restfulness never reuse impact-sharing consent. Join and lobby-create
screens disclose the default-on fields before someone joins. Raw minute values outside the
published bounds are rejected by the client helper and the API; they are not clamped-and-accepted.
Terminal Wind Down publish restores the queued run context and keeps v3 metrics. Sleep duration
and restfulness can update the same challenge day after the morning note or a later HealthKit
read, without sending reflection text or raw samples.

A qualifying shared night (`sharedGoalCompleted` or `morningQuietCompleted`) can grant 1 wool,
once per member per challenge day. Three qualifying nights grant an unowned cheap Farm item or
3 wool. Completing the party with at least four qualifying nights grants one guaranteed
Slumber Party sheep search that does not consume Wind Down or Phone Away guarantees. A group
completion bonus of 2 wool requires two members to meet that four-night threshold. Reactions,
invites, joins, and setting changes never grant rewards. The client applies a pending grant
once and acknowledges the backend grant ID.

### Farm Shop economy

`FarmShopCatalog` is the single fixed source for the 31 production items: four sequential Barn
capacity upgrades and 27 permanent discretionary purchases. Wool remains the only currency.
Tiered items stay visible, but both presentation and `FarmState.purchase` evaluate the same
`FarmShopUnlockRequirement`: tier 1 at 3 qualifying Wind Downs or 4 discoveries, tier 2 at 10 or
8, and tier 3 at 25 or all 12. `FarmState.unlockedShopTier` makes an achieved tier permanent.

Equipment is separate from ownership. Ollie and Shepherd slots replace only the matching worn
item. Decorations occupy named pasture zones, with one visible item per zone; replacement stores
the prior prop without removing ownership. Keepsakes use four deterministic display slots, and
overflow remains safely owned. Schema-v3 decoding maps legacy arrays into those zones and slots
in stable order. The user-initiated analytics export includes only aggregate wool earned/spent by
transaction kind, current balance, owned count, and flock/capacity counts—no Farm names or
transaction timestamps.

The member projection never contains Family Controls tokens, selected-app lists, raw Screen Time
reports, exact schedules, exact shield timestamps, or raw HealthKit samples. Instagram remains a
member confirmation plus coarse local shielding observation. Social sharing uses its own
preferences and outbox; impact and research sharing remains a separate local/cloud contract.

The UI persists first-entry orientation at `ollie.nightFlock.orientation`, v2 pending records at
`ollie.nightFlock.commitmentOutbox`, and v3 metrics at `ollie.nightFlock.metricsOutbox`. Active
Wind Down still removes Slumber Party navigation and queues any allowed social event
asynchronously.

Home and Farm remove Slumber Party navigation when a run becomes active. `ActiveRunView` has no
Slumber Party dependency, state, panel, badge, reaction, notification, or realtime subscription.

### Backgrounding during a run

Elapsed time is wall-clock based, so it continues while the iPhone app is in the
background. On background, the coordinator cancels its next-boundary timer and any in-progress
optional placement check, then saves the run snapshot. On foreground it reconciles against
the wall clock, schedules only the next boundary, and shows a warm return status. It does not
require a fresh Watch reading, so a person can use or put down either device after starting
the run.

The Live Activity uses the system timer for the current phase when explicitly enabled, so it remains glanceable on the
Lock Screen and Dynamic Island while the app is backgrounded. Its Lock Screen layout gives
the status/timer and message separate vertical regions: the person's selected offline
activity is primary, followed by one stable phase-appropriate cue. It does not shrink or
truncate a combined paragraph to create artificial compactness. ActivityKit does not execute a
WidgetKit timeline for phase changes, so the optional backend sends bedtime and morning-quiet
updates in addition to the final end event. It is requested with `pushType: .token`, and
`FocusRunLiveActivityService` observes every token rotation, associates it with the run and
ActivityKit activity IDs, and emits only a short SHA-256 fingerprint to diagnostics. The
local Live Activity is enabled by default for new installs and can be turned off in Settings;
DEBUG can force either state with `-ollie.debug.enableLiveActivity YES` or
`-ollie.debug.disableLiveActivity YES`. The remote sink is also disabled in the local
configurations. Without it, iOS can mark the activity stale at
the planned end but cannot deliver an exact phase or terminal transition, end it, or dismiss
it until the app next finishes or restores the run; `staleDate` alone is not an update
mechanism. Exact background transitions require the existing optional `pushType: .token`
ActivityKit path, including the remote sink, deployed functions, APNs credentials, and
scheduler. The local completion notification and app-reopen reconciliation remain the
completion fallbacks. See
`ACTIVITYKIT_PUSH_BACKEND.md` for the server lifecycle contract.

The same WidgetKit extension also exposes a static `QuietNoteWidget` in the
`accessoryRectangular` family. Its text comes from the person's explicit Quiet Note
editor value in the existing App Group, with the App Intent widget configuration retained
as the first-install fallback. It is normalized to a short Unicode-safe value and is not
copied from the private `OfflinePurposeProfile`. The widget uses a `.never` timeline and
reloads after an in-app save; active phase and countdown state remain exclusive to the
Live Activity. Tapping it opens `countingsheep://quiet-note` in the app.

Energy-specific implementation notes and the physical-device profiling matrix live in
[`ENERGY_AUDIT.md`](ENERGY_AUDIT.md).

**Authority:** the iPhone coordinator is authoritative for run state. The Watch displays,
measures, and can request early end or "whistle" (`pingPhone`). An early-end request from
Watch is rejected while the active guard is NFC, because the registered tag must be read
by the iPhone.

### WatchConnectivity strategy (both sides)

1. Always `updateApplicationContext` with latest state (survives launches).
2. If reachable, `sendMessage`; on error fall back to `transferUserInfo`.
3. If unreachable, queue critical messages (`startFocusRun`, pings, early end) via
   `transferUserInfo`.
4. Watch can rehydrate via `pingWatch` → phone's `currentStateProvider` snapshot.

## 5. View / component organisation

- `HomeView` is the single navigation shell: its four tabs remain available during an active
  Night Watch, Home becomes the live journey, and terminal receipts temporarily override it.
- One root `@StateObject` per platform (`FocusRunViewModel` / `WatchRunViewModel`),
  distributed via `.environmentObject`. Views are thin; intents go to the view model.
- `OllieRitualView` maps the existing setup, placement, Night Watch phase, completion, and
  early-end presentation states to still-image poses. It does not own or duplicate run state.
- `HomeOllieIdleView` uses a registered six-frame Ollie loop for a brief blink, ear twitch,
  head tilt, and settle on the configured Home dashboard; Reduce Motion holds frame one.
- `NightJourneyView` animates the approved six-frame Ollie cycle with a smaller current-batch
  Bramble sheep running ahead as decorative scenery. The companion is not a search result,
  reward, or owned flock item.
- `AppMotion` in `Theme.swift` is the iOS motion vocabulary. Shipping motion respects
  Reduce Motion by removing spatial/repeating effects while retaining brief fades where useful.
- Two design layers exist (known debt): the canonical pixel Theme
  (`Design/Theme.swift` + `PixelComponents.swift`) and the legacy dark
  `GameComponents.swift` used by active-run screens. Build new UI on the pixel Theme.

## 6. Persistence assumptions

- `UserDefaults.standard` + `JSONEncoder`/`JSONDecoder`, via `PersistenceService.shared`:

| Key | Type | Purpose |
|---|---|---|
| `ollie.progress` | `UserProgress` | protected-night flock count, quiet bookend minutes, daily records, legacy economy fields |
| `ollie.rewards` | `[RewardItem]` | legacy keepsakes retained for compatible decoding/internal preview |
| `ollie.thresholds` | `ThresholdProfile` | proximity calibration |
| `ollie.lastRun` | `FocusRun?` | last run snapshot |
| `ollie.analytics.manualEntries` | `[ManualAnalyticsEntry]` | manual stat entries |
| `ollie.nightWatch.preferences` | `NightWatchPreferences` | bedtime, wake time, bookends, offline cues, placement guard |
| `ollie.nightWatch.schedule` | `WindDownScheduleState` | versioned dated one-time periods and recurring routines; migrated from the two legacy schedule keys |
| `ollie.nightWatch.routines` | `[WindDownRoutine]` | migrated primary routine plus optional additional bounded periods |
| `ollie.nightWatch.nextOverride` | `NextWindDownOverride?` | legacy compatibility mirror; migrated into the versioned schedule and consumed once |
| `ollie.offlinePurpose` | `OfflinePurposeProfile` | optional in-app intention and explicit custom-notification opt-in |
| `ollie.screenTime.reportPreferences` | `ScreenTimeReportPreferences` | independent evening and morning Screen Time report windows |
| `ollie.screenTime.briefAccessState` (App Group) | `QuietTimeBriefAccessState` | active temporary grant plus bounded per-run completed-use ledger |
| `ollie.morningCheckIns` | `MorningCheckInHistory` | up to 45 days of private optional morning reflections |
| `ollie.onboarding.version` | `Int` | completed first-run onboarding version |
| `ollie.onboarding.draft` | `OnboardingDraft` | resumable first-run setup choices |
| `ollie.windDown.profile` | `WindDownProfileRecord` | local Wind Down starting-point answers and deterministic recommendations |
| `ollie.welcome.rewards` | `WelcomeRewardLedger` | idempotent starter, pending wearable gift, and practice-sheep grants |
| `ollie.orientation.state` | `CountingSheepOrientationState` | schema-6 chapter-scoped guide status, presentation state, contextual tips, Farm tutorial actions, practice identity, and resume routing |
| `ollie.notifications.preferences` | `NotificationPreferences` | cadence, authorization choices, sounds, optional channels, and versioned local message overrides |
| `ollie.notifications.remindersEnabled` | `Bool` | backwards-compatible mirror of the notification master switch |
| `ollie.sheepSearch.state` | `SheepSearchState` | found sheep, outcomes including starter/practice/Wind Down/Phone Away origins, trail-map minutes/run IDs, separate guarantee counters, trail distance, no-find protection, odds preference |
| `ollie.farm.state` | `FarmState` | versioned individual flock, pending arrivals, discovery history, capacity, wool, Shop ownership/equipment, avatar, and transaction history including starter and welcome-gift records; schema v3 retains the v2 cash-to-wool migration and adds permanent Shop unlock tiers plus named decoration zones and four bounded keepsake slots |
| `ollie.farm.pastureScene` | `PastureSceneSnapshot` | versioned local-only normalized placement for active sheep and each pasture's Ollie and Shepherd; autonomous behavior stays ephemeral and stale entities are pruned |
| `ollie.nightWatch.history` | `NightWatchHistory` | up to 90 days of aggregate records and idempotent observed/inferred/self-reported/system events |
| `ollie.phoneBedNFCTags.library` | `PhoneBedTagLibrary` | only SHA-256 digests (including local retired-credential history) plus local name, purpose, and timestamps persist in defaults; the generated UUID bearer credential is written only to the physical NDEF tag; names and purposes are never written to NFC; the credential, name, and purpose are never transmitted |
| `ollie.impactSharing.preferences` | `ImpactSharingPreferences` | explicit optional-sharing state and consent date |
| `ollie.impactSharing.records` | `[ImpactUploadRecord]` | date-free retry cache for consented impact rows |
| `ollie.nightFlock.outbox` | `[NightFlockOutboxRecord]` | bounded local retry queue containing only positive state contracts |
| `ollie.nightFlock.runContexts` | `[NightFlockRunShareContext]` | up to 32 local consent/idempotency contexts; never uploaded as run IDs |
| `ollie.nightFlock.stagedDestructiveEffect` | `NightFlockDestructiveLocalEffect` | local-only no-replay recovery journal for an accepted destructive command awaiting authoritative state; the outbox actor clears it last, after all v1/v2/v3/context lanes, so relaunch reconciles before any flush |
| `ollie.nightFlock.pendingDestructiveIntent` | `NightFlockPendingDestructiveIntent` | local-only preflight journal for a leave, block, sharing-off, or Slumber Party-data deletion command; restart loads authoritative state to determine whether it applied, never replays the command, and keeps all outbox lanes paused until resolved |
| `ollie.nightFlock.pendingAccountDeletionIntent` | `Bool` | durable preflight journal for a full online-account deletion; it closes all Slumber Party transport and local producers before the request, and an ambiguous response remains local fail-closed with no account inspection, recovery, flush, or remote deletion replay |
| `ollie.nightFlock.acceptedAccountDeletion` | `Bool` | durable local tombstone written after an accepted full account-deletion response; relaunch finalizes local lane clearing and local sign-out before removing it, never replaying the remote deletion |
| `ollie.nightFlock.expectedLinkedUserID` | valid UUID string | local-only expected Supabase account binding used solely to reject wrong-account recovery; an invalid persisted value fails closed rather than being treated as absent; it is never uploaded as a new social field and local reset/confirmed online-account deletion clear it |
| `ollie.appearance.preference` | `AppAppearancePreference` | Automatic, Light, or Dark app appearance choice |

For destructive Slumber Party changes, a pending ordinary intent resolves from authoritative state before
any flush. Full account deletion is stricter: a pending preflight closes all Slumber Party activity and
never replays remotely; only an accepted tombstone continues through local lane clearing, verified sign-out,
and final tombstone removal.

The older `ollie.phoneBedNFCTag` and `ollie.phoneBedNFCTag.registration` keys are migration-only.
On first library access, either legacy value becomes one primary tag named “Wind Down tag,”
assigned to Wind Down and Phone Away, and both legacy keys are removed. Local reset clears all
three keys.

- No CoreData / SwiftData. Core state stays in standard defaults. The App Group is limited
  to Screen Time selections plus shield schedule/status contracts needed by extensions;
  legacy standard-default selection keys migrate forward without overwriting shared data.
- Codable models are the schema. Changing them requires backwards-compatible decoding;
  a legacy-decode test exists in `Tests/` and must keep passing.
- Watch and phone do not share persistence; the Watch is rehydrated over WatchConnectivity.

`FocusRunViewModel.eraseLocalDataAndStartOver()` is the scoped local reset boundary. It clears
the explicit standard-default key list in `Shared/CountingSheepStorage.swift`, asks the owning
notification, HealthKit, NFC, usage-monitoring, shielding, and Live Activity services to clear
their runtime state, and clears the explicit Screen Time/Brief Access App Group keys. It resets
the coordinator and root route in memory, then opens a fresh Welcome draft in the same process.
The installation transport identifier is intentionally retained so previously uploaded optional
Live Activity delivery records are not re-identified by a local reset; remote impact records are
also never deleted by this operation. iOS notification, Family Controls, and HealthKit grants
cannot be revoked programmatically here.

### Optional hosted backend

The main iOS target alone links the official `supabase-swift` package. A stable configured
client restores or refreshes an anonymous Supabase session and creates an anonymous user
only when no stored session exists. Live Activity registration/cancellation is injected
through `FocusRunLiveActivityRemoteSink` and remains disabled by default through
`SUPABASE_LIVE_ACTIVITY_PUSH_ENABLED`. Configuration or network failure never changes the
local coordinator's authority, local notification, flock, or reopen reconciliation.

The versioned `supabase/` backend contains the ActivityKit delivery schema, the optional
`impact_nights` table, gated feedback delivery, and the independently gated Slumber Party schema.
Impact rows use relative nights and exclude exact dates/times, source
names, app tokens, NFC identity, raw Health samples, and free text. The user can stop future
sharing or call a scoped deletion RPC without deleting local history. The backend and Edge
Functions remain separately deployed. Client-visible tables use RLS with `auth.uid()`; raw tokens, worker queues, and
delivery administration have no direct client grants.

Feedback uses anonymous auth, direct uploads to the private `feedback-attachments` bucket,
and an authenticated idempotent `submit-feedback` function. `app_feedback` has no client
read/write grants. A service-only database RPC serializes each user's rolling five-per-day
limit. Resend notification failures remain pending; a secret-protected scheduled function
retries every ten minutes up to five attempts and purges rows/private objects after 180 days.
`SUPABASE_FEEDBACK_ENABLED` remains off until the independent production gate passes; the
iOS form then uses Mail instead. ADR-0005/0007 and `ACTIVITYKIT_PUSH_BACKEND.md` define the
cloud boundaries.

Slumber Party is independently controlled by `SUPABASE_NIGHT_FLOCK_ENABLED` (ordinary Debug `NO`;
TestFlight/Release `YES`). With the flag off, its app surfaces are absent and it does not create a
Supabase session or make a request. Entry creates or restores an anonymous session only when needed, then Sign in with Apple
links that identity in place and verifies the Auth UUID did not change. A successful link and a
validated linked session bind the Supabase UUID locally. Recovery never creates an anonymous
session: a 401 requires Apple ID-token reauthentication to that same UUID, while
`linked_account_required` may only link the current valid anonymous session in place. Missing,
changed, or unprovable identities fail closed, preserve the snapshot, run contexts, and all three
outboxes, then reconcile rather than replay a direct mutation. Slumber Party server RPCs
also require Apple in Auth app metadata, so another non-anonymous provider is insufficient.

`night-flock-command` and `night-flock-state` derive the caller from the JWT, validate exact
schema-version-one payloads, and alone call service-role RPCs. Protected tables have RLS enabled,
no authenticated client write grants, one active membership per user, one pending/active challenge
per flock, and an eight-member trigger protected by an advisory lock. State projections include
system aliases only in the roster and omit Auth owner IDs, run IDs, exact timestamps, and private
state. Plain invite codes are returned once and stored only as SHA-256 digests.

Slumber Party tables do not reference `focus_runs`, `impact_nights`, HealthKit, Screen Time, NFC,
notifications, or any Farm/economy table. Retention purges invites after 30 days, raw check-ins and
reactions after 90 days, and aggregate completed summaries after 12 months. The hosted scheduler,
migration/functions, Apple provider, and moderation operating process remain deployment gates.

## 7. Known architectural risks

1. **Protection evidence is intentionally bounded.** Current release starts require a selected-app
   barrier, using either the timer guard or NFC + app shielding. Honor timer, Watch-placement, and
   QR values remain persisted-data compatibility only; they are not release-facing fallbacks or
   start signals. NFC authenticates the normal end action with the same registered tag; a multi-step emergency
   bypass remains available and is recorded locally. For an active NFC-tag run, the iPhone
   coordinator owns an ephemeral, run-bound two-step reason reflection before it accepts
   that bypass: the user names what they need the phone for, then retypes that reason with
   forgiving local normalization. The reason is stored only on the iPhone under an `ollie.*` key;
   it is never persisted in the shared run payload, logged, uploaded, or available to the Watch.
   Successful authentication consumes the challenge before notification, usage-monitor, shield,
   Live Activity, and automatic-schedule cleanup begins. A timer-guard run can use the ordinary
   authorized end path; it does not represent an unshielded alternative.
2. **Night Watch intentionally crosses midnight.** Date boundaries, daylight-saving
   changes, timezone changes, termination, and background restoration need physical-device
   QA in addition to the pure scheduling tests. The continuous app barrier is not progression;
   Wind Down progression uses its factual wind-down bookend, while Screen-Free Morning settles
   independently through Sunrise Trail (ADR-0019).
3. **Screen Time needs physical-device QA.** The report/monitor/configuration/action
   extensions are embedded locally, but the three new shield bundle IDs still need Family
   Controls distribution assignment and continuous barrier transitions need physical proof.
   App/category shields use the iOS 26.4+ system submenu for Brief Access, with role-specific
   protected-time-purpose choices serving as the five-minute confirmation; system Cancel is the
   only no-op. The run-scoped pause/allotted-minute tracker appears on both the shield and active-
   run UI. Older OS versions use the direct five-minute button, and web domains never advertise
   Brief Access. Continue Wind Down opens Counting Sheep on iOS 26.5+ and keeps the close fallback
   on older systems.
   Authorization, picker persistence, report rendering, empty states, and distribution
   profiles must still be exercised on a physical iPhone.
4. **Legacy mock layer remains compiled in Debug.** Friends and the old Farm/Shop/reward shelf
   still render `MVPMockData`; they appear only inside More with
   `-ollie.debug.enableMockScreens YES`. The production Farm and Farm Shop are separate real-data
   surfaces backed by `FarmState`.
5. **Oversized files.** `AssetReadyScreens.swift` and `PixelComponents.swift` resist safe
   editing by agents with limited context.
6. **Singleton coupling.** Services are reached via `.shared` from the coordinator, which
   makes unit-testing the coordinator itself hard (currently untested; only `Shared/` is).
7. **UserDefaults as the detailed-history store.** The 90-day bound is appropriate now;
   schema growth or richer user inspection may justify a local database later.
8. **ActivityKit remote delivery is disabled by default.** Token observation, lifecycle
   contracts, and the approved Supabase implementation exist, but deployment, secrets, and
   APNs delivery still require validation. Local completion behavior remains authoritative.
9. **Feedback delivery is disabled by default.** Resend secrets/domain, scheduled retry,
   hosted migration, private-object behavior, mailbox retention, and a physical-device
   upload must all pass before enabling it. Email fallback is the release-safe path.
10. **Slumber Party is compiled on for TestFlight/Release and off for ordinary Debug.** Hosted
    deployment, Apple/Supabase configuration, moderation operations, retention scheduling, and
    physical two-account QA remain operational evidence for a working party, not a compile-flag
    gate.

## 8. Recommended architecture direction

- Keep MVVM + coordinator; it fits. Do not introduce new architecture patterns (TCA,
  Redux, etc.) — the codebase is small and the pattern works.
- Keep wind-down, overnight, and morning quiet as phases of the same persisted run. New
  morning features must extend `NightWatchPlan`, not introduce a parallel session model.
- The session-guard seam retains `SessionGuardKind` (`.honorTimer`, `.watchPlacement`,
  `.qrCode`, `.nfcTag`) for persisted-data compatibility. Current release UI exposes only the
  shielding timer (`.honorTimer` raw compatibility) and NFC + app shielding; Watch-placement and
  QR never reappear as release-facing starts. Keep completion phone-authoritative and preserve an emergency exit.
- Keep the App Group limited to Screen Time/Shield extension contracts; do not migrate
  unrelated progress, rewards, HealthKit history, or reflections into it.
- Converge run-screen UI onto the pixel Theme; retire `GameComponents` gradually.
- Inject services into `FocusSessionCoordinator` (init parameters defaulting to
  `.shared`) to make it testable — mechanical, low-risk refactor.
- Keep cloud work additive and permission-separated: ActivityKit delivery, explicitly consented
  minimised impact rows, and ADR-0016's narrow Slumber Party tables never become shared data sources.

## 9. Clean up before App Store 1.0

1. Keep general Friends, the legacy Farm/Shop/shelf, and `MVPMockData` behind the explicit Debug
   flag. Slumber Party is the separate ADR-0016 production slice and stays release-hidden until its
   explicit feature flag and external gates are approved.
2. Register/approve/sign the three new shield extension IDs.
3. Increment the build number and produce a distribution archive.
4. `HealthSleepService` uses requested/no-data/error states because HealthKit does not
   disclose whether read access was denied. Do not regress to an “authorized” read state.
5. Manually validate NFC tag lifecycle, background/terminated shielding, HealthKit stages,
   optional impact deletion, run restore, and Watch timer mirroring on physical hardware; QR and
   Watch-placement remain legacy decode/migration coverage rather than release flows.
6. Accessibility pass on the core run flow (timer, proximity state, Watch views).
7. Keep backend feedback disabled unless every ADR-0007/TestFlight gate is proven.

## 10. Explicitly postponed

- Splitting the oversized files (do opportunistically, not as a pre-TestFlight project)
- Removing `GameComponents` / design-system convergence
- Screen Time shielding (separate from the embedded read-only report; ADR-0004 gates apply)
- Physical-device proof for NFC-authenticated ending and terminated-app shielding
- Coordinator dependency injection refactor
- Any new persistence layer
