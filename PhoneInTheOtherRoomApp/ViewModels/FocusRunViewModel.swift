import Foundation
import Combine
import UserNotifications

#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
import FamilyControls
#endif

struct PendingNFCTagReset: Equatable {
    let oldCredentialDigest: String
    let role: PhoneBedTagRole
    let name: String
    let purposes: Set<PhoneBedTagPurpose>
    let existingSlotID: UUID?
}

@MainActor
final class FocusRunViewModel: ObservableObject {
    @Published var nightWatchPreferences: NightWatchPreferences = .defaults
    @Published var windDownSchedule: WindDownScheduleState = WindDownScheduleState()
    @Published var windDownScheduleError: String?
    @Published var windDownRoutines: [WindDownRoutine] = []
    @Published var nextWindDownOverride: NextWindDownOverride?
    @Published var offlinePurpose: OfflinePurposeProfile = .defaultProfile
    @Published var selectedDuration: TimeInterval = 25 * 60
    @Published var durationMinutes = 25
    @Published var durationSeconds = 0
    @Published var showCustomDurationPicker = false
    @Published var showFocusModePrompt = false
    @Published var focusPromptAnswered = false
    @Published var focusAccepted = false
    @Published var focusGuidance = ""
    @Published var customDurationSelected = false
    @Published var screenTimeAuthorization: ScreenTimeAuthorizationService.AuthorizationState = .notDetermined
    @Published var screenTimeReportPreferences: ScreenTimeReportPreferences
    @Published var sleepAuthorization: HealthSleepService.AuthorizationState = .notRequested
    @Published var lastNightSleep: SleepSummary?
    @Published var recentNightSleeps: [SleepSummary] = []
    @Published var isRefreshingSleep = false
    @Published var morningCheckIns: MorningCheckInHistory = MorningCheckInHistory()
    @Published var analyticsExportURL: URL?
    @Published var analyticsExportError: String?
    @Published var manualAnalyticsEntries: [ManualAnalyticsEntry] = []
    @Published var includeAnalyticsPlaceholders = false
    @Published var analyticsExportPrivacyMode: AnalyticsExportPrivacyMode = .exactDates
    @Published var impactSharingPreferences: ImpactSharingPreferences
    @Published var impactDataSyncState: ImpactDataSyncState = .idle
    @Published var impactSharingAvailable: Bool
    @Published var notificationPreferences: NotificationPreferences
    @Published var notificationAuthorization: UNAuthorizationStatus = .notDetermined
#if DEBUG
    @Published var useAnalyticsQADataset = false
#endif
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
    @Published var distractingActivitySelection = FamilyActivitySelection()
    @Published var productiveActivitySelection = FamilyActivitySelection()
    @Published var bedtimeActivitySelection = FamilyActivitySelection()
#endif

    @Published var coordinator: FocusSessionCoordinator
    @Published var selectedGuardKind: SessionGuardKind = .nfcTag
    @Published var showQRCodeScanner = false
    @Published var qrCodeStatus = ""
    @Published var nfcStatus = ""
    @Published var liveActivityEnabled = FocusRunLiveActivityService.preferenceEnabled
    @Published var showNightWatchStartPrompt = false
    @Published var liveActivityChoiceForNextRun = FocusRunLiveActivityService.preferenceEnabled
    @Published var appShieldingChoiceForNextRun = false
    @Published private(set) var pendingWindDownStartContext: WindDownStartContext?
    @Published var nightWatchStartStatus = ""
    @Published var isScanningNFCForStart = false
    @Published var isProvisioningNFCTag = false
    @Published var pendingNFCTagReset: PendingNFCTagReset?
    @Published var phoneBedTagLibrary = PhoneBedTagLibrary()
    @Published var orientationState: CountingSheepOrientationState
    @Published var appearancePreference: AppAppearancePreference = .automatic
    @Published private(set) var rootRoute: CountingSheepRootRoute = .freshOnboarding
    /// Ephemeral navigation intent used by the practice-record handoff; it is not
    /// persisted and does not change the meaning of any recorded night.
    @Published var nightsRecordFocusID: UUID?
    @Published var shieldingEnabled: Bool
    @Published var farmActionMessage: String?
    let nightFlockViewModel: NightFlockViewModel

    private let focusService = FocusModeSuggestionService()
    private let notifications = PhoneNotificationService.shared
    let persistence: PersistenceService
    let nowProvider: () -> Date
    private let screenTimeService = ScreenTimeAuthorizationService()
    private let healthSleepService = HealthSleepService()
    private let phoneBedNFCService = PhoneBedNFCService()
    private let quietTimeShielding = QuietTimeShieldingService()
    private let usageMonitoring = NightWatchUsageMonitoringService()
    private let impactDataSyncService = ImpactDataSyncService()
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
    private let screenTimeSelectionService = ScreenTimeSelectionService.shared
#endif
    private var cancellables = Set<AnyCancellable>()
    private var pendingNightWatchPlan: NightWatchPlan?
    private var pendingNightWatchSourceOccurrenceID: UUID?
    private var pendingAdHocQuietTransaction: WindDownStartTransaction?
    private var nightWatchStartInFlight = false

    private var activeRunIsAdditionalQuiet: Bool {
        activeRun?.nightWatchPlan?.role == .additionalQuiet
    }

    private var pendingRunIsAdditionalQuiet: Bool {
        pendingNightWatchPlan?.role == .additionalQuiet
    }

    init(
        coordinator: FocusSessionCoordinator? = nil,
        persistence: PersistenceService = .shared,
        nowProvider: @escaping () -> Date = Date.init,
        startsExternalServices: Bool = true,
        nightFlockViewModel: NightFlockViewModel? = nil
    ) {
        self.persistence = persistence
        self.nowProvider = nowProvider
        self.nightFlockViewModel = nightFlockViewModel
            ?? (startsExternalServices
                ? NightFlockViewModel.configured()
                : NightFlockViewModel(featureEnabled: false))
        let savedQuietTime = persistence.nightWatchPreferences
        let savedSchedule = persistence.windDownSchedule
        let savedReportPreferences = persistence.screenTimeReportPreferences
        let initialReportPreferences = savedReportPreferences
            ?? ScreenTimeReportPreferences.defaults(for: savedQuietTime)
        if savedReportPreferences == nil {
            persistence.screenTimeReportPreferences = initialReportPreferences
        }
        self.coordinator = coordinator ?? FocusSessionCoordinator(persistence: persistence)
        impactSharingPreferences = persistence.impactSharingPreferences
        orientationState = persistence.orientationState
        appearancePreference = persistence.appearancePreference
        // The saved value is durable intent, not readiness. A missing value is
        // the fresh-install recommendation; only an explicit false opts out.
        let savedShieldingIntent = QuietTimeShieldingIntentPolicy.savedIntent(
            UserDefaults.standard.object(forKey: QuietTimeShieldingService.enabledKey) as? Bool
        )
        shieldingEnabled = startsExternalServices ? savedShieldingIntent : false
        if startsExternalServices,
           UserDefaults.standard.object(forKey: QuietTimeShieldingService.enabledKey) == nil {
            UserDefaults.standard.set(savedShieldingIntent, forKey: QuietTimeShieldingService.enabledKey)
        }
        nightsRecordFocusID = nil
        impactSharingAvailable = startsExternalServices && (try? SupabaseConfiguration.load()) != nil
        notificationPreferences = startsExternalServices ? notifications.preferences : .defaults
        var normalizedQuietTime = savedQuietTime
        normalizedQuietTime.guardKind = savedQuietTime.guardKind.releaseCompatibleKind
        nightWatchPreferences = normalizedQuietTime
        self.windDownSchedule = savedSchedule
        self.windDownRoutines = savedSchedule.routines
        self.nextWindDownOverride = savedSchedule.oneTimePeriods
            .filter(\.isAvailable)
            .sorted { $0.interval.start < $1.interval.start }
            .first
            .map { period in
                NextWindDownOverride(
                    id: period.id,
                    routineID: period.id,
                    role: period.role,
                    interval: period.interval,
                    expiresAt: period.interval.end
                )
            }
        screenTimeReportPreferences = initialReportPreferences
        offlinePurpose = persistence.offlinePurpose
        morningCheckIns = persistence.morningCheckIns
        phoneBedTagLibrary = persistence.phoneBedTagLibrary
        selectedGuardKind = normalizedQuietTime.guardKind
        if normalizedQuietTime.guardKind != savedQuietTime.guardKind {
            persistence.nightWatchPreferences = normalizedQuietTime
        }
        self.coordinator.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        self.nightFlockViewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        self.coordinator.optionalSheepSearchBonusProvider = { [weak self] in
            self?.optionalSheepSearchBonusPoints() ?? 0
        }
        self.coordinator.onPhoneAwayValidated = { [weak self] run in
            self?.nightFlockViewModel.publishV4PhoneAwayActive(for: run)
            self?.nightFlockViewModel.publishPhoneTucked(for: run)
        }
        self.coordinator.onAuthorizedEarlyExit = { [weak self] preservingLinkedMorningShield in
            if !preservingLinkedMorningShield {
                self?.prepareForEarlyWindDownExit()
            }
        }
        self.coordinator.onRunFinished = { [weak self] run, linkedMorningHandoff in
            guard let self else { return }
            self.publishSlumberPartyOutcome(for: run)
            self.reconcileOrientationAfterRun()
            if !linkedMorningHandoff {
                self.scheduleAutomaticWindDownIfNeeded()
            }
        }
        self.nightFlockViewModel.onApplyRewardGrants = { [weak self] grants in
            self?.applySlumberPartyGrants(grants)
        }
        self.nightFlockViewModel.onApplyV4RewardGrants = { [weak self] grants in
            self?.applyV4SlumberPartyGrants(grants) ?? []
        }
        self.nightFlockViewModel.onV4CheerFeedback = { [weak self] feedback in
            self?.coordinator.showSlumberPartyCheer(feedback)
        }
        screenTimeAuthorization = startsExternalServices ? screenTimeService.currentState() : .notDetermined
        if startsExternalServices {
            self.nightFlockViewModel.bootstrap()
            Task { @MainActor in
                notificationAuthorization = await notifications.authorizationStatus()
            }
        }
        if let activeRun, activeRun.state == .completed || activeRun.state == .endedEarly {
            Task { @MainActor [weak self] in
                await Task.yield()
                guard let self, let run = self.activeRun else { return }
                self.publishSlumberPartyOutcome(for: run)
            }
        }
        sleepAuthorization = startsExternalServices
            ? (healthSleepService.isAvailable
                ? (healthSleepService.hasRequestedAccess ? .requested : .notRequested)
                : .unavailable)
            : .notRequested
        manualAnalyticsEntries = persistence.manualAnalyticsEntries
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        distractingActivitySelection = screenTimeSelectionService.load(.distracting)
        productiveActivitySelection = screenTimeSelectionService.load(.productive)
        bedtimeActivitySelection = screenTimeSelectionService.load(.bedtime)
#endif
        rootRoute = CountingSheepRootRoute.resolve(
            onboardingVersion: persistence.onboardingVersion,
            currentOnboardingVersion: CountingSheepOnboarding.currentVersion,
            hasOnboardingDraft: persistence.onboardingDraft != nil,
            hasConfiguredNightWatch: savedQuietTime.isConfigured,
            hasActiveRun: self.coordinator.run != nil
        )
        if startsExternalServices {
            applyShortcutPreparationIfNeeded()
            reconcileAutomaticWindDownIfNeeded()
            if sleepAuthorization == .requested {
                refreshSleepSummary()
            }
            reconcileOrientationAfterRun()
        }
    }

    var activeRun: FocusRun? { coordinator.run }

    func briefAccessTrackerSummary(for run: FocusRun) -> QuietTimeBriefAccessTrackerSummary {
        quietTimeShielding.briefAccessTrackerSummary(for: run)
    }

    func briefAccessTrackerSummary(forScreenFreeMorning occurrence: MorningQuietOccurrence) -> QuietTimeBriefAccessTrackerSummary {
        quietTimeShielding.briefAccessTrackerSummary(forOccurrenceID: occurrence.id)
    }
    var hasConfiguredNightWatch: Bool { nightWatchPreferences.isConfigured }
    var hasRegisteredNFCTag: Bool { phoneBedTagLibrary.hasTag(for: .windDown) }
    var primaryPhoneBedTag: NamedPhoneBedTagRegistration? { phoneBedTagLibrary.primary }
    var backupPhoneBedTag: NamedPhoneBedTagRegistration? { phoneBedTagLibrary.backup }

    func hasRegisteredNFCTag(for purpose: PhoneBedTagPurpose) -> Bool {
        phoneBedTagLibrary.hasTag(for: purpose)
    }
    var canBeginNightWatchNow: Bool {
        nightWatchPreferences.isStartWindowOpen(at: nowProvider())
            || WindDownScheduleEngine.eligibleOccurrence(
                in: windDownSchedule,
                at: nowProvider(),
                primaryExtensionMinutes: nightWatchPreferences.morningQuietMinutes
            ) != nil
    }
    var upcomingQuietPeriods: [WindDownSchedulePeriod] {
        windDownSchedule.upcomingPeriods(
            after: nowProvider(),
            primaryExtensionMinutes: nightWatchPreferences.morningQuietMinutes,
            limit: 64
        )
    }
    var nextUpcomingQuietPeriod: WindDownSchedulePeriod? { upcomingQuietPeriods.first }
    var immediateAdditionalQuietMinutes: Int? {
        let now = nowProvider()
        guard let interval = immediateAdditionalQuietWindow(now: now) else { return nil }
        return Int(interval.duration / 60)
    }
    var upcomingAdditionalQuietPeriods: [WindDownSchedulePeriod] {
        upcomingQuietPeriods.filter { $0.occurrence.role == .additionalQuiet }
    }
    var nextUpcomingAdditionalQuietPeriod: WindDownSchedulePeriod? {
        upcomingAdditionalQuietPeriods.first
    }
    var currentWindDownStartContext: WindDownStartContext? {
        let now = nowProvider()
        guard let period = WindDownScheduleEngine.eligibleOccurrence(
            in: windDownSchedule,
            at: now,
            primaryExtensionMinutes: nightWatchPreferences.morningQuietMinutes
        ) else { return nil }
        return WindDownStartContext(
            period: period,
            practicePeriodID: orientationState.practicePeriodID
        )
    }

    /// Home keeps the nightly ritual in the dominant position even when a
    /// separate Phone Away period happens to be eligible at the same moment.
    var currentPrimaryWindDownStartContext: WindDownStartContext? {
        guard let context = currentWindDownStartContext, context.kind == .primary else { return nil }
        return context
    }

    var currentPhoneAwayStartContext: WindDownStartContext? {
        guard let context = currentWindDownStartContext, context.isAdditionalQuiet else { return nil }
        return context
    }
    var readyOneTimeQuietPeriodID: UUID? {
        guard let eligible = WindDownScheduleEngine.eligibleOccurrence(
            in: windDownSchedule,
            at: nowProvider(),
            primaryExtensionMinutes: nightWatchPreferences.morningQuietMinutes
        ), !eligible.recurring else { return nil }
        return eligible.sourceID
    }
    var hasSelectedShieldingApps: Bool {
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        return !bedtimeActivitySelection.phoneOtherIsEmpty
#else
        return false
#endif
    }
    var shieldingSelectionSummary: String {
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        return bedtimeActivitySelection.phoneOtherSelectionSummary
#else
        return "selected apps"
#endif
    }
    var shieldingReadiness: ShieldingReadiness {
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        if case .failed = coordinator.shieldingState { return .runtimeFailure }
        switch screenTimeAuthorization {
        case .approved:
            return hasSelectedShieldingApps ? .ready : .noSelection
        case .notDetermined: return .authorizationRequired
        case .denied(let message):
            return message.localizedCaseInsensitiveContains("revok") ? .revoked : .denied
        case .unavailable: return .unavailable
        }
#else
        return .unavailable
#endif
    }
    var isRunning: Bool {
        guard let state = activeRun?.state else { return false }
        return ![.setup, .completed, .endedEarly].contains(state)
    }

    var sheepSearchState: SheepSearchState { coordinator.sheepSearchState }
    var latestSheepSearchOutcome: SheepSearchOutcome? { coordinator.latestSheepSearchOutcome }
    var farmState: FarmState { coordinator.farmState }

    func revealDeliveredWindDownBenefit(for runID: UUID) {
        coordinator.revealDeliveredWindDownBenefit(for: runID)
    }

    var isEarlyWakeAvailable: Bool {
        guard let run = activeRun else { return false }
        return MorningQuietIntentEngine.isAvailable(run: run, at: nowProvider())
    }

    var activeScreenFreeMorning: MorningQuietOccurrence? {
        persistence.windDownMorningSettlementJournal.morningOccurrences
            .filter { $0.outcome == .active }
            .sorted { $0.scheduledStart < $1.scheduledStart }
            .first
    }

    var deferredScreenFreeMorning: MorningQuietOccurrence? {
        persistence.windDownMorningSettlementJournal.morningOccurrences
            .filter { $0.outcome == .scheduled }
            .sorted { $0.scheduledStart < $1.scheduledStart }
            .first
    }

    var latestScreenFreeMorning: MorningQuietOccurrence? {
        persistence.windDownMorningSettlementJournal.morningOccurrences
            .filter { $0.outcome == .finished || $0.outcome == .skipped }
            .sorted { ($0.endedAt ?? $0.scheduledEnd) > ($1.endedAt ?? $1.scheduledEnd) }
            .first
    }

    var homeReceiptRoute: HomeReceiptRoute {
        HomeReceiptRouting.route(
            activeRun: activeRun,
            journal: persistence.windDownMorningSettlementJournal
        )
    }

    var screenFreeMorningOccurrences: [MorningQuietOccurrence] {
        persistence.windDownMorningSettlementJournal.morningOccurrences
    }

    var currentPurposeCue: QuietPurposeCue? {
        guard let defaults = UserDefaults(suiteName: QuietTimeShieldPresentationStorage.appGroupIdentifier) else {
            return nil
        }
        return QuietPurposeCueState.load(from: defaults)?.cue
    }

    func setCurrentPurposeCue(_ cue: QuietPurposeCue) {
        guard let defaults = UserDefaults(suiteName: QuietTimeShieldPresentationStorage.appGroupIdentifier) else { return }
        let registry = QuietTimeShieldScheduleRegistryStorage.load(from: defaults)
        let occurrenceID = activeScreenFreeMorning?.id ?? activeRun?.id
        guard let occurrenceID else { return }
        let entry = registry.entry(for: occurrenceID)
        QuietPurposeCueState.save(
            QuietPurposeCueState(
                occurrenceID: entry?.occurrenceID ?? occurrenceID,
                revision: entry?.revision ?? 1,
                epoch: entry?.epoch ?? 1,
                cue: cue
            ),
            to: defaults
        )
    }

    func screenFreeMorningOccurrences(on day: Date, calendar: Calendar = .current) -> [MorningQuietOccurrence] {
        screenFreeMorningOccurrences.filter {
            calendar.isDate($0.scheduledStart, inSameDayAs: day)
        }
        .sorted { $0.scheduledStart < $1.scheduledStart }
    }

    /// Starts the NFC scan only after the user selected a morning action. The
    /// selection remains in memory until the matching tag passes, so cancelled
    /// and mismatched scans leave the journal untouched.
    func chooseEarlyWake(_ intent: MorningQuietIntent) {
        guard intent == .keepWindDownRunning || isEarlyWakeAvailable else { return }
        guard intent != .keepWindDownRunning else {
            nfcStatus = "Wind Down is still running."
            return
        }
        guard EarlyWakeProtectionStartPolicy.canCommit(
            intent: intent,
            readiness: shieldingReadiness
        ) else {
            nfcStatus = shieldingReadiness.detail
            return
        }
        guard activeRun?.guardKind == .nfcTag else {
            _ = coordinator.transitionToEarlyMorning(intent: intent, reason: .userEnded, at: nowProvider())
            return
        }
        nfcStatus = ""
        let purpose = currentNFCPurpose
        guard phoneBedTagLibrary.hasTag(for: purpose) else {
            nfcStatus = "Your Wind Down tag is unavailable. Wind Down is still running. Use the emergency exit only if needed."
            return
        }
        phoneBedNFCService.scan(isAdditionalQuiet: false) { [weak self] result in
            guard let self else { return }
            switch result {
            case .read(let read):
                guard self.phoneBedTagLibrary.authenticatingTag(
                    digest: read.digest,
                    purpose: purpose
                ) != nil,
                      self.coordinator.confirmNFCTag(read.digest, expectedFingerprint: read.digest) else {
                    self.nfcStatus = "That is not your Wind Down tag. Wind Down is still running."
                    return
                }
                self.markNFCTagVerified(read.digest, purpose: purpose)
                guard self.coordinator.transitionToEarlyMorning(
                    intent: intent,
                    reason: .nfcTagAuthenticated,
                    at: self.nowProvider()
                ) != nil else {
                    self.nfcStatus = "Wind Down is still running. Try again from the early-wake choices."
                    return
                }
                self.nfcStatus = "Wind Down tag confirmed."
            case .cancelled:
                self.nfcStatus = "No tag was read. Wind Down is still running."
            case .unavailable:
                self.nfcStatus = "NFC is not available. Wind Down is still running. Use the emergency exit only if needed."
            }
        }
    }

    func finishScreenFreeMorning(_ occurrenceID: UUID) {
        _ = coordinator.finishScreenFreeMorning(occurrenceID: occurrenceID, at: nowProvider())
    }

    var isOrientationActive: Bool { orientationState.isGuideActive }

    var firstRunAdvanceContext: FirstRunAdvanceContext {
        let ledger = persistence.welcomeRewardLedger
        let granted = ledger.pendingWearableGrant != nil || ledger.claimedWearableGrant != nil
        let equipped = welcomeWearableIsEquipped
        return FirstRunAdvanceContext(
            practiceCompleted: orientationState.milestones.contains(.practiceCompleted),
            slumberPartyAvailable: nightFlockViewModel.featureEnabled,
            showClaimWearable: granted
                && ledger.pendingWearableGrant != nil
                && !orientationState.hasRecorded(.claimedWearable)
                && !orientationState.skippedLessons.contains(.farmClaimWearable),
            showEquipWearable: granted
                && !equipped
                && !orientationState.hasRecorded(.equippedWearable)
                && !orientationState.skippedLessons.contains(.farmEquipWearable)
        )
    }

    private var welcomeWearableIsEquipped: Bool {
        let itemID = persistence.welcomeRewardLedger.claimedWearableGrant?.itemID
            ?? persistence.welcomeRewardLedger.pendingWearableGrant?.itemID
        guard let itemID else { return false }
        return coordinator.farmState.shepherd.outfitItemID == itemID
            || coordinator.farmState.shepherd.accessoryItemID == itemID
    }

    var firstRunRequestedTab: MainAppTab? {
        guard orientationState.isGuideActive else { return nil }
        switch FirstRunJourney.surface(for: orientationState.currentStep) {
        case .home: return .home
        case .farm: return .farm
        case .settings: return .settings
        case .nights: return .nights
        }
    }

    var isWindDownAppearanceActive: Bool {
        isRunning || (hasConfiguredNightWatch && canBeginNightWatchNow)
    }

    var appearanceResolution: AppAppearanceResolution {
        appearancePreference.resolution(isWindDownReadyOrActive: isWindDownAppearanceActive)
    }

    var pendingNightWatchIsAdditionalQuiet: Bool {
        pendingWindDownStartContext?.isAdditionalQuiet == true
    }

    var pendingNightWatchEndsAt: Date? {
        pendingNightWatchPlan?.protectedUntil
    }

    var pendingNightWatchTitle: String? {
        pendingWindDownStartContext?.title
    }

    var willShieldPendingNightWatch: Bool {
        shieldingReadiness == .ready
    }

    var pendingStartNeedsShieldingSetup: Bool {
        shieldingReadiness != .ready
    }

    func markOrientation(_ milestone: CountingSheepOrientationMilestone) {
        orientationState.mark(milestone)
        persistence.orientationState = orientationState
    }

    func contextualTip(
        from candidates: [CountingSheepContextualTip]
    ) -> CountingSheepContextualTip? {
        guard !isRunning else { return nil }
        return orientationState.nextContextualTip(from: candidates, isWindDownActive: isRunning)
    }

    func acknowledgeContextualTip(_ tip: CountingSheepContextualTip) {
        guard !isRunning else { return }
        orientationState.markContextualTipSeen(tip)
        persistence.orientationState = orientationState
    }

    func disableContextualTips() {
        orientationState.disableContextualTips()
        persistence.orientationState = orientationState
    }

    func dismissOrientation() {
        orientationState.dismiss()
        persistence.orientationState = orientationState
    }

    func dismissFirstRunContinueCard() {
        orientationState.dismissContinueCard()
        persistence.orientationState = orientationState
    }

    func advanceOrientationTour() {
        orientationState.advanceTour(context: firstRunAdvanceContext)
        persistence.orientationState = orientationState
    }

    func skipOrientationLesson() {
        orientationState.skipCurrentLesson(context: firstRunAdvanceContext)
        persistence.orientationState = orientationState
    }

    func moveBackInOrientationTour() {
        orientationState.moveBack(context: firstRunAdvanceContext)
        persistence.orientationState = orientationState
    }

    func completeOrientationTour() {
        orientationState.completeTour()
        persistence.orientationState = orientationState
    }

    func resumeOrientation() {
        orientationState.resume()
        persistence.orientationState = orientationState
    }

    func offerFarmGuideIfNeeded() {
        guard orientationState.activeChapter == nil,
              !orientationState.completedChapters.contains(.farmTour),
              orientationState.status != .skipped,
              orientationState.status != .completed else { return }
        orientationState.offerChapter(.farmTour)
        persistence.orientationState = orientationState
    }

    func startFarmGuide() {
        orientationState.startOfferedChapter()
        persistence.orientationState = orientationState
    }

    func deferFarmGuide() {
        orientationState.deferActiveChapter()
        persistence.orientationState = orientationState
    }

    func dismissHomeHandoff() {
        orientationState.deferredChapters.insert(.homeBasics)
        persistence.orientationState = orientationState
    }

    func dismissPracticeOffer() {
        orientationState.markContextualTipSeen(.practice)
        persistence.orientationState = orientationState
    }

    var lastPracticeGrantBroughtSheep: Bool {
        coordinator.lastOnboardingPracticeGrantedSheep
    }

    func replayOrientation() {
        orientationState.replay()
        persistence.orientationState = orientationState
    }

    func recordFirstRunFarmAction(_ action: FirstRunFarmAction) {
        guard !orientationState.hasRecorded(action) else { return }
        orientationState.recordFarmAction(action)
        persistence.orientationState = orientationState
    }

    func markPracticeRewardRoutedToFarm() {
        orientationState.markPracticeRewardRoutedToFarm()
        persistence.orientationState = orientationState
    }

    func acknowledgeSlumberPartyUnavailable() {
        orientationState.acknowledgeSlumberPartyUnavailable()
        persistence.orientationState = orientationState
    }

    private func prepareOrientationTour(showAfterOnboarding: Bool) {
        orientationState = .fresh
        if !showAfterOnboarding {
            orientationState.dismiss()
        }
        persistence.orientationState = orientationState
    }

    @discardableResult
    func startOrientationPractice() -> Bool {
        guard !isRunning, activeRun == nil,
              ScreenTimeProtectionStartPolicy.canStart(shieldingReadiness) else {
            nightWatchStartStatus = shieldingReadiness.detail
            return false
        }
        let now = Date()

        // A person may cancel the normal start confirmation or return after a
        // preflight issue. Reuse the still-valid practice period instead of
        // leaving an unstartable duplicate in the finite schedule.
        if let existingID = orientationState.practicePeriodID,
           let existing = windDownSchedule.oneTimePeriods.first(where: { $0.id == existingID }) {
            if existing.isEligible(at: now) {
                requestStartNightWatch(sourceID: existingID)
                return showNightWatchStartPrompt
            }
            cancelOneTimeQuiet(id: existingID)
        }

        let window = QuietPeriodScheduling.defaultWindow(
            now: now,
            preset: .startNowPractice
        )
        let periodID = UUID()
        guard addOneTimeAdditionalQuiet(
            id: periodID,
            title: "Practice quiet",
            start: window.start,
            end: window.end,
            now: now
        ) else { return false }
        orientationState.recordPracticePeriod(periodID)
        persistence.orientationState = orientationState
        requestStartNightWatch(sourceID: periodID)
        return showNightWatchStartPrompt
    }

    /// Creates a bounded additional-quiet period and prepares the same start
    /// confirmation used by every other Wind Down entry point. The schedule
    /// mutation is rolled back when the confirmation cannot be prepared.
    @discardableResult
    func startNewOneTimeAdditionalQuietNow(
        duration: TimeInterval = 30 * 60,
        title: String = "Phone Away",
        now: Date = Date()
    ) -> Bool {
        guard !isRunning else {
            windDownScheduleError = "Finish the current phone-away session before starting Phone Away."
            return false
        }
        guard ScreenTimeProtectionStartPolicy.canStart(shieldingReadiness) else {
            windDownScheduleError = shieldingReadiness.detail
            return false
        }

        guard let window = immediateAdditionalQuietWindow(now: now, maximumDuration: duration) else {
            windDownScheduleError = "Your next scheduled Wind Down begins too soon for Phone Away."
            return false
        }
        // Manual Phone Away is a transient start transaction. It must not add
        // or consume a saved occurrence, even when its interval overlaps one.
        pendingAdHocQuietTransaction = nil
        pendingNightWatchSourceOccurrenceID = nil
        pendingWindDownStartContext = WindDownStartContext(
            kind: .oneTimeQuiet,
            title: title,
            interval: window
        )
        pendingNightWatchPlan = NightWatchPlan.additionalQuiet(
            start: window.start,
            end: window.end,
            activity: nightWatchPreferences.eveningActivity,
            cueText: nightWatchPreferences.eveningCueText
        )
        liveActivityChoiceForNextRun = liveActivityEnabled
        appShieldingChoiceForNextRun = shieldingEnabled && shieldingReadiness == .ready
        nightWatchStartStatus = ""
        showNightWatchStartPrompt = true
        guard showNightWatchStartPrompt else {
            windDownScheduleError = "Phone Away could not be prepared just now."
            return false
        }
        return true
    }

    private func immediateAdditionalQuietWindow(
        now: Date,
        maximumDuration: TimeInterval = QuietPeriodPreset.general.duration
    ) -> DateInterval? {
        // Manual Phone Away is intentionally independent of saved windows. A
        // saved occurrence remains available for its own scheduled action.
        return QuietPeriodScheduling.immediateWindow(
            now: now,
            maximumDuration: maximumDuration,
            nextScheduledStart: nil
        )
    }

    private func reconcileOrientationAfterRun() {
        guard let run = activeRun,
              let practiceRunID = orientationState.practiceRunID,
              run.id == practiceRunID,
              run.completedSuccessfully else { return }
        markOrientation(.practiceCompleted)
        orientationState.recordPracticeCompleted(context: firstRunAdvanceContext)
        persistence.orientationState = orientationState
    }

    func markOrientationPracticeRecordViewedIfPresent() {
        guard orientationState.milestones.contains(.practiceCompleted),
              let practiceRunID = orientationState.practiceRunID,
              nightWatchRecords.contains(where: { $0.id == practiceRunID }) else { return }
        markOrientation(.practiceRecordViewed)
    }

    func focusNightsRecord(_ recordID: UUID?) {
        nightsRecordFocusID = recordID
    }

    func clearNightsRecordFocus() {
        nightsRecordFocusID = nil
    }

    /// Reads the terminal Search Journal entry by its persisted run identity. The search
    /// engine resolves outcomes in the coordinator; terminal views only reveal
    /// the saved record and never calculate a new one.
    func sheepSearchOutcome(for runID: UUID) -> SheepSearchOutcome? {
        persistence.sheepSearchState.outcomes.first { $0.runID == runID }
    }

    /// Reads the durable Phone Away settlement for a terminal run. Receipts
    /// use this record rather than deriving credit from the current meter.
    func phoneAwaySearchSettlement(for runID: UUID) -> PhoneAwaySearchSettlementRecord? {
        persistence.sheepSearchState.phoneAwaySettlement(for: runID)
    }

    func setSheepSearchExactOddsEnabled(_ enabled: Bool) {
        var state = coordinator.sheepSearchState
        state.showExactOdds = enabled
        coordinator.sheepSearchState = state
        persistence.sheepSearchState = state
    }

    func setAppearancePreference(_ preference: AppAppearancePreference) {
        appearancePreference = preference
        persistence.appearancePreference = preference
    }

    private func optionalSheepSearchBonusPoints() -> Int {
        var points = 0
        if sleepAuthorization == .requested, lastNightSleep != nil {
            points += 2
        }
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        if screenTimeAuthorization == .approved, !bedtimeActivitySelection.phoneOtherIsEmpty {
            points += 2
        }
#endif
        if let recentReflection = morningCheckIns.entries.first, !recentReflection.isEmpty {
            points += 1
        }
        return min(5, points)
    }

    func chooseDuration(minutes: Int) {
        durationMinutes = minutes
        durationSeconds = 0
        customDurationSelected = false
        updateSelectedDuration()
    }

    func chooseCustomDuration() {
        customDurationSelected = true
        showCustomDurationPicker = true
    }

    var selectedDurationLabel: String {
        let minutes = Int(selectedDuration / 60)
        let seconds = Int(selectedDuration) % 60
        if seconds == 0 { return "\(minutes) min" }
        if minutes == 0 { return "\(seconds) sec" }
        return "\(minutes) min \(seconds) sec"
    }

    func updateSelectedDuration() {
        selectedDuration = TimeInterval((durationMinutes * 60) + durationSeconds)
    }

    func applyShortcutPreparationIfNeeded() {
        guard let duration = FocusRunShortcutStore.consumePendingDuration() else { return }
        durationMinutes = Int(duration) / 60
        durationSeconds = Int(duration) % 60
        selectedDuration = duration
        customDurationSelected = !Self.presetMinutes.contains(durationMinutes) || durationSeconds != 0
        focusGuidance = "A legacy Shortcut prepared \(selectedDurationLabel) of phone-away time. Your saved Wind Down remains the main bedtime ritual."
    }

    func requestStartRun() {
        guard ScreenTimeProtectionStartPolicy.canStart(shieldingReadiness) else {
            focusGuidance = shieldingReadiness.detail
            return
        }
        updateSelectedDuration()
        showFocusModePrompt = true
    }

    func requestStartNightWatch(sourceID: UUID? = nil) {
        guard WindDownStartGate.canPresentPreflight(
            isRunning: isRunning,
            startInFlight: nightWatchStartInFlight
        ) else { return }
        guard ScreenTimeProtectionStartPolicy.canStart(shieldingReadiness) else {
            nightWatchStartStatus = shieldingReadiness.detail
            return
        }
        saveNightWatchPreferences()
        let requestedAt = Date()
        let eligible: WindDownSchedulePeriod?
        if let sourceID {
            eligible = WindDownScheduleEngine.eligibleOccurrence(
                in: windDownSchedule,
                at: requestedAt,
                sourceID: sourceID,
                primaryExtensionMinutes: nightWatchPreferences.morningQuietMinutes
            )
            guard eligible != nil else {
                nightWatchStartStatus = "That quiet window has passed or is too short to start now."
                return
            }
        } else {
            eligible = WindDownScheduleEngine.eligibleOccurrence(
                in: windDownSchedule,
                at: requestedAt,
                primaryExtensionMinutes: nightWatchPreferences.morningQuietMinutes
            )
        }
        // Retain the resolved one-time identity through preflight. It is
        // revalidated and consumed only after authorization/start succeeds;
        // recurring identities remain stable without mutating the routine.
        pendingNightWatchSourceOccurrenceID = WindDownStartSourcePolicy.sourceID(
            explicitSourceID: sourceID,
            eligible: eligible
        )
        pendingWindDownStartContext = eligible.map {
            WindDownStartContext(
                period: $0,
                practicePeriodID: orientationState.practicePeriodID
            )
        }
        if pendingWindDownStartContext?.kind == .primary {
            nightFlockViewModel.resetNextPrimaryRunSharing()
        }
        pendingNightWatchPlan = eligible.map {
            WindDownScheduleEngine.plan(
                for: $0,
                preferences: nightWatchPreferences,
                startedAt: requestedAt
            )
        } ?? makePlanForNextWindDown(startedAt: requestedAt)
        liveActivityChoiceForNextRun = liveActivityEnabled
        appShieldingChoiceForNextRun = shieldingEnabled && shieldingReadiness == .ready
        nightWatchStartStatus = ""
        showNightWatchStartPrompt = true
    }

    func cancelNightWatchStart() {
        guard !nightWatchStartInFlight else { return }
        isScanningNFCForStart = false
        rollbackPendingAdHocQuiet()
        pendingNightWatchPlan = nil
        pendingNightWatchSourceOccurrenceID = nil
        pendingWindDownStartContext = nil
        nightWatchStartStatus = ""
        showNightWatchStartPrompt = false
    }

    func confirmNightWatchStart() {
        guard pendingNightWatchPlan != nil, !nightWatchStartInFlight else { return }
        guard ScreenTimeProtectionStartPolicy.canStart(shieldingReadiness) else {
            nightWatchStartStatus = shieldingReadiness.detail
            return
        }
        if selectedGuardKind == .nfcTag {
            scanNFCTag()
        } else {
            startPendingNightWatch()
        }
    }

    private func startPendingNightWatch() {
        guard let requestedPlan = pendingNightWatchPlan,
              !nightWatchStartInFlight,
              ScreenTimeProtectionStartPolicy.canStart(shieldingReadiness) else {
            if pendingNightWatchPlan != nil { nightWatchStartStatus = shieldingReadiness.detail }
            return
        }
        nightWatchStartInFlight = true
        let startedAt = Date()
        let plan: NightWatchPlan
        if let sourceID = pendingNightWatchSourceOccurrenceID {
            guard let eligible = WindDownScheduleEngine.eligibleOccurrence(
                in: windDownSchedule,
                at: startedAt,
                sourceID: sourceID,
                primaryExtensionMinutes: nightWatchPreferences.morningQuietMinutes
            ), eligible.sourceID == sourceID else {
                rollbackPendingAdHocQuiet()
                nightWatchStartInFlight = false
                nightWatchStartStatus = "That quiet window has passed or is too short to start now."
                nfcStatus = nightWatchStartStatus
                return
            }
            plan = WindDownScheduleEngine.plan(
                for: eligible,
                preferences: nightWatchPreferences,
                startedAt: startedAt
            )
        } else {
            plan = requestedPlan
        }
        let liveActivityRequested = liveActivityChoiceForNextRun
        let appShieldingRequested = true
        liveActivityEnabled = liveActivityRequested
        UserDefaults.standard.set(
            liveActivityRequested,
            forKey: FocusRunLiveActivityService.preferenceKey
        )
        let sourceID = pendingNightWatchSourceOccurrenceID
        pendingNightWatchPlan = nil
        pendingNightWatchSourceOccurrenceID = nil
        pendingWindDownStartContext = nil
        showNightWatchStartPrompt = false
        notifications.cancelNightWatchReminder()
        persistence.automaticWindDownSchedule = nil
        quietTimeShielding.cancelAutomaticSchedule()
        let runID = UUID()
        if plan.role == .primarySleepBookend {
            nightFlockViewModel.preparePrimaryRun(
                runID: runID,
                at: startedAt,
                share: nightFlockViewModel.shareNextPrimaryRun
            )
            nightFlockViewModel.publishV4WindDownStarting(runID: runID, at: startedAt)
        }
        coordinator.start(
            configuration: FocusRunConfiguration(
                nightWatchPlan: plan,
                guardKind: selectedGuardKind,
                isPractice: WindDownStartContext.isPracticeOccurrence(
                    sourceID: sourceID,
                    practicePeriodID: orientationState.practicePeriodID
                )
            ),
            focusAccepted: false,
            startedAt: startedAt,
            autoConfirmPlacement: selectedGuardKind == .nfcTag,
            appShieldingRequested: appShieldingRequested,
            liveActivityRequested: liveActivityRequested,
            runID: runID
        )
        if let sourceID,
           sourceID == orientationState.practicePeriodID,
           let runID = activeRun?.id {
            orientationState.recordPracticeRun(runID)
            persistence.orientationState = orientationState
        }
        consumeScheduledOccurrence(sourceID)
        pendingAdHocQuietTransaction = nil
        notifications.scheduleNightWatchNotifications(
            for: plan,
            startedAt: startedAt,
            purpose: offlinePurpose,
            seed: activeRun?.id ?? UUID(),
            preferences: notificationPreferences
        )
        usageMonitoring.schedule(for: plan, startedAt: startedAt)
        nightWatchStartInFlight = false
        nightWatchStartStatus = ""
    }

    func saveWindDownRoutines() {
        windDownSchedule.routines = windDownRoutines
        persistence.windDownSchedule = windDownSchedule
    }

    func saveWindDownSchedule() {
        guard !isRunning else { return }
        windDownRoutines = windDownSchedule.routines
        persistence.windDownSchedule = windDownSchedule
        nextWindDownOverride = windDownSchedule.oneTimePeriods
            .filter(\.isAvailable)
            .sorted { $0.interval.start < $1.interval.start }
            .first
            .map { period in
                NextWindDownOverride(
                    id: period.id,
                    routineID: period.id,
                    role: period.role,
                    interval: period.interval,
                    expiresAt: period.interval.end
                )
            }
        scheduleAutomaticWindDownIfNeeded()
    }

    func setWindDownRoutineAutomaticStart(_ enabled: Bool, for routineID: UUID) {
        guard !isRunning else { return }
        guard let index = windDownRoutines.firstIndex(where: { $0.id == routineID }) else { return }
        windDownRoutines[index].automaticStartEnabled = enabled
        saveWindDownRoutines()
        scheduleAutomaticWindDownIfNeeded()
    }

    @discardableResult
    func addAdditionalWindDown(
        title: String,
        start: WindDownClockTime,
        end: WindDownClockTime,
        recurrence: WindDownRecurrence = .daily
    ) -> Bool {
        guard !isRunning, recurrence.isValid else {
            windDownScheduleError = "Choose at least one day for this repeating Phone Away."
            return false
        }
        let routine = WindDownRoutine(
            title: title,
            role: .additionalQuiet,
            start: start,
            end: end,
            recurrence: recurrence,
            automaticStartEnabled: true
        )
        var candidate = windDownSchedule
        candidate.routines.append(routine)
        guard acceptsSchedule(candidate) else { return false }
        windDownSchedule = candidate
        saveWindDownSchedule()
        return true
    }

    private func expandedOccurrence(
        for routine: WindDownRoutine,
        on day: Date,
        calendar: Calendar
    ) -> WindDownOccurrence? {
        guard let occurrence = WindDownScheduleEngine.occurrence(for: routine, on: day, calendar: calendar) else {
            return nil
        }
        guard routine.role == .primarySleepBookend else { return occurrence }
        let end = calendar.date(
            byAdding: .minute,
            value: nightWatchPreferences.morningQuietMinutes,
            to: occurrence.interval.end
        ) ?? occurrence.interval.end
        return WindDownOccurrence(
            id: occurrence.id,
            routineID: occurrence.routineID,
            role: occurrence.role,
            interval: DateInterval(start: occurrence.interval.start, end: end),
            state: occurrence.state
        )
    }

    @discardableResult
    func addOneTimeAdditionalQuiet(
        title: String,
        start: Date,
        end: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        addOneTimeAdditionalQuiet(
            id: UUID(),
            title: title,
            start: start,
            end: end,
            now: now,
            calendar: calendar
        )
    }

    @discardableResult
    private func addOneTimeAdditionalQuiet(
        id: UUID,
        title: String,
        start: Date,
        end: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard !isRunning else { return false }
        guard let interval = normalizedOneTimeInterval(start: start, end: end, now: now, calendar: calendar) else {
            return false
        }
        let item = WindDownOneTimePeriod(
            id: id,
            title: title,
            role: .additionalQuiet,
            interval: interval
        )
        var candidate = windDownSchedule
        candidate.oneTimePeriods.append(item)
        guard acceptsSchedule(candidate) else { return false }
        windDownSchedule = candidate
        saveWindDownSchedule()
        return true
    }

    @discardableResult
    private func addOneTimePeriod(
        title: String,
        start: Date,
        end: Date,
        role: WindDownOccurrenceRole,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard !isRunning else { return false }
        guard let interval = normalizedOneTimeInterval(start: start, end: end, now: now, calendar: calendar) else {
            return false
        }
        let item = WindDownOneTimePeriod(
            title: title,
            role: role,
            interval: interval
        )
        var candidate = windDownSchedule
        candidate.oneTimePeriods.append(item)
        guard acceptsSchedule(candidate) else { return false }
        windDownSchedule = candidate
        saveWindDownSchedule()
        return true
    }

    @discardableResult
    func updateOneTimeQuiet(
        id: UUID,
        title: String,
        start: Date,
        end: Date,
        enabled: Bool = true,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard !isRunning,
              let index = windDownSchedule.oneTimePeriods.firstIndex(where: { $0.id == id }),
              let interval = normalizedOneTimeInterval(start: start, end: end, now: now, calendar: calendar) else {
            return false
        }
        var candidate = windDownSchedule
        candidate.oneTimePeriods[index].title = title
        candidate.oneTimePeriods[index].interval = interval
        candidate.oneTimePeriods[index].enabled = enabled
        if enabled { candidate.oneTimePeriods[index].cancelledAt = nil }
        guard acceptsSchedule(candidate) else { return false }
        windDownSchedule = candidate
        saveWindDownSchedule()
        return true
    }

    func setOneTimeQuietEnabled(_ enabled: Bool, id: UUID) {
        guard !isRunning, let index = windDownSchedule.oneTimePeriods.firstIndex(where: { $0.id == id }) else { return }
        windDownSchedule.oneTimePeriods[index].enabled = enabled
        if enabled { windDownSchedule.oneTimePeriods[index].cancelledAt = nil }
        saveWindDownSchedule()
    }

    func cancelOneTimeQuiet(id: UUID) {
        guard !isRunning else { return }
        _ = windDownSchedule.removeOneTimePeriod(id: id)
        saveWindDownSchedule()
    }

    private func rollbackPendingAdHocQuiet() {
        guard let transaction = pendingAdHocQuietTransaction else { return }
        _ = transaction.cancel(in: &windDownSchedule)
        pendingAdHocQuietTransaction = nil
        saveWindDownSchedule()
    }

    @discardableResult
    func updateAdditionalRoutine(
        id: UUID,
        title: String,
        start: WindDownClockTime,
        end: WindDownClockTime,
        recurrence: WindDownRecurrence,
        enabled: Bool
    ) -> Bool {
        guard !isRunning, recurrence.isValid,
              let index = windDownSchedule.routines.firstIndex(where: { $0.id == id && $0.role == .additionalQuiet }) else {
            if !recurrence.isValid {
                windDownScheduleError = "Choose at least one day for this repeating Phone Away."
            }
            return false
        }
        var candidate = windDownSchedule
        candidate.routines[index].title = title
        candidate.routines[index].start = start
        candidate.routines[index].end = end
        candidate.routines[index].recurrence = recurrence
        candidate.routines[index].enabled = enabled
        guard acceptsSchedule(candidate) else { return false }
        windDownSchedule = candidate
        saveWindDownSchedule()
        return true
    }

    func setAdditionalRoutineEnabled(_ enabled: Bool, id: UUID) {
        guard !isRunning, let index = windDownSchedule.routines.firstIndex(where: { $0.id == id }) else { return }
        windDownSchedule.routines[index].enabled = enabled
        saveWindDownSchedule()
    }

    func cancelAdditionalRoutine(id: UUID) {
        guard !isRunning else { return }
        windDownSchedule.routines.removeAll { $0.id == id && $0.role == .additionalQuiet }
        saveWindDownSchedule()
    }

    private func validateSchedule(_ schedule: WindDownScheduleState) throws {
        guard schedule.routines.allSatisfy({ $0.recurrence.isValid }) else {
            throw WindDownScheduleError.invalidRecurrence
        }
        guard schedule.oneTimePeriods.allSatisfy({ $0.interval.end > $0.interval.start }) else {
            throw WindDownScheduleError.invalidInterval
        }
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let routines = schedule.routines.flatMap { routine in
            (0...370).compactMap { offset -> WindDownOccurrence? in
                guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                      let occurrence = WindDownScheduleEngine.occurrence(for: routine, on: day, calendar: calendar) else {
                    return nil
                }
                return WindDownScheduleEngine.expandedOccurrence(
                    occurrence,
                    routine: routine,
                    primaryExtensionMinutes: nightWatchPreferences.morningQuietMinutes,
                    calendar: calendar
                )
            }
        }
        let oneTimes = schedule.oneTimePeriods.compactMap { $0.occurrence() }
        let routineOccurrences = routines.filter { routineOccurrence in
            guard routineOccurrence.role == .primarySleepBookend else { return true }
            return !oneTimes.contains {
                $0.role == .primarySleepBookend && $0.interval.intersects(routineOccurrence.interval)
            }
        }
        try WindDownScheduleEngine.validateNoOverlaps(routineOccurrences + oneTimes)
    }

    private func acceptsSchedule(_ candidate: WindDownScheduleState) -> Bool {
        do {
            try validateSchedule(candidate)
            windDownScheduleError = nil
            return true
        } catch let error as WindDownScheduleError {
            switch error {
            case let .overlappingOccurrences(first, second):
                let firstTitle = scheduleTitle(for: first, in: candidate)
                let secondTitle = scheduleTitle(for: second, in: candidate)
                windDownScheduleError = "“\(firstTitle)” and “\(secondTitle)” overlap. Choose a different window."
            case .invalidInterval:
                windDownScheduleError = "Choose a future quiet window with an ending time after its start."
            case .invalidRecurrence:
            windDownScheduleError = "Choose at least one day for this repeating Phone Away."
            }
            return false
        } catch {
            windDownScheduleError = "Choose a future quiet window that does not overlap another period."
            return false
        }
    }

    private func scheduleTitle(for id: UUID, in schedule: WindDownScheduleState) -> String {
        if let period = schedule.oneTimePeriods.first(where: { $0.id == id }) {
            return period.userFacingTitle
        }
        if let routine = schedule.routines.first(where: { $0.id == id }) {
            return routine.userFacingTitle
        }
        return "Phone-away time"
    }

    private func normalizedOneTimeInterval(
        start: Date,
        end: Date,
        now: Date,
        calendar: Calendar
    ) -> DateInterval? {
        do {
            let interval = try QuietPeriodScheduling.normalizedInterval(
                requestedStart: start,
                end: end,
                now: now,
                minimumRemainingDuration: FocusRunRules.minimumMeaningfulDurationSeconds
            )
            windDownScheduleError = nil
            return interval
        } catch let error as QuietPeriodSchedulingError {
            switch error {
            case .invalidInterval:
                windDownScheduleError = "Choose a quiet window with an ending time after its start."
            case .expired:
                windDownScheduleError = "That quiet window has already ended."
            case .insufficientRemainingDuration:
                windDownScheduleError = "Leave at least one minute for Ollie to keep the quiet."
            }
        } catch {
            windDownScheduleError = "Choose a valid quiet window."
        }
        return nil
    }

    @discardableResult
    func adjustNextWindDown(start: Date, end: Date, role: WindDownOccurrenceRole = .additionalQuiet) -> Bool {
        if let existing = windDownSchedule.oneTimePeriods.first(where: { $0.role == role }) {
            return updateOneTimeQuiet(
                id: existing.id,
                title: existing.title,
                start: start,
                end: end,
                enabled: true
            )
        }
        return addOneTimePeriod(
            title: role == .primarySleepBookend ? "Adjusted Wind Down" : "Phone Away",
            start: start,
            end: end,
            role: role
        )
    }

    func clearNextWindDownOverride() {
        guard !isRunning else { return }
        if let legacyOverride = nextWindDownOverride {
            windDownSchedule.oneTimePeriods.removeAll { $0.id == legacyOverride.id }
        }
        saveWindDownSchedule()
    }

    private func makePlanForNextWindDown(startedAt: Date) -> NightWatchPlan {
        let calendar = Calendar.current
        guard let eligible = WindDownScheduleEngine.eligibleOccurrence(
            in: windDownSchedule,
            at: startedAt,
            calendar: calendar,
            primaryExtensionMinutes: nightWatchPreferences.morningQuietMinutes
        ) else {
            // A saved period in the future is informational only. Starting now
            // always uses the normal Wind Down plan.
            return nightWatchPreferences.makePlan(startedAt: startedAt)
        }
        return WindDownScheduleEngine.plan(
            for: eligible,
            preferences: nightWatchPreferences,
            startedAt: startedAt,
            calendar: calendar
        )
    }

    func saveNightWatchPlanForTonight() {
        saveNightWatchPreferences()
        markOrientation(.windDownSaved)
        scheduleAutomaticWindDownIfNeeded()
    }

    func saveOnboardingDraft(_ draft: OnboardingDraft) {
        persistence.onboardingDraft = draft
    }

    func applyOnboardingDraft(
        _ draft: OnboardingDraft,
        preserveAdvancedNotifications: Bool = false,
        showTourAfterOnboarding: Bool? = nil
    ) {
        let updatedPreferences = draft.makeNightWatchPreferences()
        nightWatchPreferences = updatedPreferences
        offlinePurpose = draft.makeOfflinePurpose()
        selectedGuardKind = updatedPreferences.guardKind
        persistence.nightWatchPreferences = nightWatchPreferences
        persistence.offlinePurpose = offlinePurpose
        persistence.screenTimeReportPreferences = ScreenTimeReportPreferences.defaults(
            for: nightWatchPreferences
        )
        screenTimeReportPreferences = persistence.screenTimeReportPreferences
            ?? ScreenTimeReportPreferences.defaults(for: nightWatchPreferences)
        // Keep consented intent even when Family Controls is denied or has no
        // selection yet. Start preflight will explain the fail-open path.
        shieldingEnabled = draft.shieldingEnabled
        UserDefaults.standard.set(
            shieldingEnabled,
            forKey: QuietTimeShieldingService.enabledKey
        )
        var updatedNotificationPreferences = preserveAdvancedNotifications
            ? notificationPreferences
            : draft.makeNotificationPreferences()
        updatedNotificationPreferences.remindersEnabled = draft.remindersEnabled
        if !preserveAdvancedNotifications {
            updatedNotificationPreferences.usageAwareRemindersEnabled =
                draft.usageAwareRemindersEnabled && canUseUsageAwareReminders
        }
        notificationPreferences = updatedNotificationPreferences
        notifications.preferences = updatedNotificationPreferences

        // Keep the Home schedule and the legacy preferences in sync. Reusing the
        // primary routine identity preserves edits made from Settings and keeps
        // additional quiet periods beside the saved sleep-bookend plan.
        var updatedSchedule = windDownSchedule
        let existingPrimaryID = updatedSchedule.routines.first(where: {
            $0.role == .primarySleepBookend
        })?.id
        let primaryRoutine = draft.makePrimaryWindDownRoutine(existingID: existingPrimaryID)
        if let primaryIndex = updatedSchedule.routines.firstIndex(where: {
            $0.role == .primarySleepBookend
        }) {
            updatedSchedule.routines[primaryIndex] = primaryRoutine
        } else {
            updatedSchedule.routines.insert(primaryRoutine, at: 0)
        }
        windDownSchedule = updatedSchedule
        windDownRoutines = updatedSchedule.routines
        persistence.windDownSchedule = updatedSchedule
        persistence.completeOnboarding()
        if let showTourAfterOnboarding {
            prepareOrientationTour(showAfterOnboarding: showTourAfterOnboarding)
        }
        rootRoute = .home
        scheduleAutomaticWindDownIfNeeded()
    }

    func setRemindersEnabled(_ enabled: Bool) {
        var updated = notificationPreferences
        updated.remindersEnabled = enabled
        notificationPreferences = updated
        notifications.preferences = updated
        if enabled {
            if isRunning { reschedulePendingActiveRunNotifications() }
            else { scheduleAutomaticWindDownIfNeeded() }
        } else {
            notifications.cancelAllNightWatchNotifications()
            usageMonitoring.cancel()
        }
    }

    var canUseUsageAwareReminders: Bool {
        screenTimeAuthorization == .approved && hasSelectedShieldingApps
    }

    func updateNotificationPreferences(
        _ preferences: NotificationPreferences,
        markCadenceChosen: Bool = true
    ) {
        var updated = preferences
        updated.hasChosenCadence = markCadenceChosen
            ? true
            : preferences.hasChosenCadence
        if !canUseUsageAwareReminders {
            updated.usageAwareRemindersEnabled = false
        }
        notificationPreferences = updated
        notifications.preferences = updated
        if updated.remindersEnabled {
            if isRunning { reschedulePendingActiveRunNotifications() }
            else { scheduleAutomaticWindDownIfNeeded() }
        } else {
            notifications.cancelAllNightWatchNotifications()
            usageMonitoring.cancel()
        }
    }

    /// Rebuilds only future alerts from the immutable plan captured by the
    /// active run. Timing and protection edits remain next-run preferences.
    func reschedulePendingActiveRunNotifications() {
        guard let activeRun, let plan = activeRun.nightWatchPlan else { return }
        guard notificationPreferences.remindersEnabled else {
            notifications.cancelAllNightWatchNotifications()
            usageMonitoring.cancel()
            return
        }
        notifications.scheduleNightWatchNotifications(
            for: plan,
            startedAt: activeRun.startedAt,
            purpose: offlinePurpose,
            seed: activeRun.id,
            preferences: notificationPreferences
        )
        usageMonitoring.schedule(for: plan, startedAt: activeRun.startedAt)
    }

    func updateNotificationCopy(
        for templateID: NotificationTemplateID,
        title: String?,
        body: String?
    ) {
        var updated = notificationPreferences
        updated.setCopyOverride(
            NotificationCopyOverride(id: templateID, title: title, body: body)
        )
        updateNotificationPreferences(updated, markCadenceChosen: false)
    }

    func resetNotificationCopy(for templateID: NotificationTemplateID) {
        var updated = notificationPreferences
        updated.resetCopy(for: templateID)
        updateNotificationPreferences(updated, markCadenceChosen: false)
    }

    func resetAllNotificationCopies() {
        var updated = notificationPreferences
        updated.resetAllCopies()
        updateNotificationPreferences(updated, markCadenceChosen: false)
    }

    func refreshNotificationAuthorization() {
        Task { @MainActor in
            notificationAuthorization = await notifications.authorizationStatus()
        }
    }

    func openNotificationSettings() {
        notifications.openSystemSettings()
    }

    func openAppSettings() {
        notifications.openSystemSettings()
    }

    var nightWatchBedtimeDate: Date {
        nightWatchPreferences.bedtimeDate()
    }

    var nightWatchWakeDate: Date {
        nightWatchPreferences.wakeDate()
    }

    var nightWatchScheduleLabel: String {
        let bedtime = nightWatchBedtimeDate.formatted(date: .omitted, time: .shortened)
        let wake = nightWatchWakeDate.formatted(date: .omitted, time: .shortened)
        return "\(bedtime) to \(wake)"
    }

    func updateNightWatchBedtime(_ date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        nightWatchPreferences.bedtimeHour = components.hour ?? nightWatchPreferences.bedtimeHour
        nightWatchPreferences.bedtimeMinute = components.minute ?? nightWatchPreferences.bedtimeMinute
    }

    func updateNightWatchWakeTime(_ date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        nightWatchPreferences.wakeHour = components.hour ?? nightWatchPreferences.wakeHour
        nightWatchPreferences.wakeMinute = components.minute ?? nightWatchPreferences.wakeMinute
    }

    func saveNightWatchPreferences() {
        selectedGuardKind = selectedGuardKind.releaseCompatibleKind
        nightWatchPreferences.guardKind = selectedGuardKind
        nightWatchPreferences.isConfigured = true
        // Keep the user's explicit shielding choice. Readiness is checked before
        // a run starts; saving a bedtime edit must not silently turn an enabled
        // shield off just because Family Controls is temporarily refreshing.
        UserDefaults.standard.set(shieldingEnabled, forKey: QuietTimeShieldingService.enabledKey)
        persistence.nightWatchPreferences = nightWatchPreferences
        persistence.offlinePurpose = offlinePurpose
        let existingPrimary = windDownRoutines.first(where: { $0.role == .primarySleepBookend })
        let primary = WindDownRoutine.primary(
            from: nightWatchPreferences,
            id: existingPrimary?.id ?? UUID()
        )
        windDownRoutines = [primary] + windDownRoutines.filter { $0.role != .primarySleepBookend }
        saveWindDownRoutines()
    }

    func selectGuardKind(_ kind: SessionGuardKind) {
        selectedGuardKind = kind.releaseCompatibleKind
        nightWatchPreferences.guardKind = selectedGuardKind
        guard nightWatchPreferences.isConfigured else { return }
        persistence.nightWatchPreferences = nightWatchPreferences
        scheduleAutomaticWindDownIfNeeded()
    }

    func selectProtectionChoice(_ choice: WindDownProtectionChoice) {
        selectedGuardKind = choice.guardKind
        nightWatchPreferences.guardKind = choice.guardKind
        // Both release choices are app-shielding methods. Selecting either is
        // an affirmative future intent even if Family Controls setup still
        // needs to be completed; readiness is handled at run preflight.
        shieldingEnabled = true
        UserDefaults.standard.set(shieldingEnabled, forKey: QuietTimeShieldingService.enabledKey)
        guard nightWatchPreferences.isConfigured else { return }
        persistence.nightWatchPreferences = nightWatchPreferences
        scheduleAutomaticWindDownIfNeeded()
    }

    func saveTimingDraft(
        bedtime: Date,
        wake: Date,
        windDownMinutes: Int,
        morningQuietMinutes: Int
    ) {
        updateNightWatchBedtime(bedtime)
        updateNightWatchWakeTime(wake)
        nightWatchPreferences.windDownMinutes = min(180, max(15, windDownMinutes))
        nightWatchPreferences.morningQuietMinutes = min(180, max(15, morningQuietMinutes))
        saveQuietTimeDurations()
    }

    func setAutomaticStartEnabled(_ enabled: Bool) {
        nightWatchPreferences.automaticStartEnabled = enabled
        if let index = windDownRoutines.firstIndex(where: { $0.role == .primarySleepBookend }) {
            windDownRoutines[index].automaticStartEnabled = enabled
            saveWindDownRoutines()
        }
        guard nightWatchPreferences.isConfigured else { return }
        persistence.nightWatchPreferences = nightWatchPreferences
        scheduleAutomaticWindDownIfNeeded()
    }

    func saveQuietTimeDurations() {
        saveNightWatchPreferences()
        scheduleAutomaticWindDownIfNeeded()
    }

    func updateOfflinePurpose(
        category: OfflinePurposeCategory,
        customText: String?,
        allowsCustomTextInNotifications: Bool
    ) {
        offlinePurpose = OfflinePurposeProfile(
            category: category,
            customText: customText,
            allowsCustomTextInNotifications: allowsCustomTextInNotifications
        )
    }

    func updatePhoneFreeCue(evening: Bool, text: String) {
        let normalized = PhoneFreeCue.normalized(text)
        if evening {
            nightWatchPreferences.eveningCueText = normalized
        } else {
            nightWatchPreferences.morningCueText = normalized
        }
        saveNightWatchPreferences()
    }

    func answerFocusPrompt(_ accepted: Bool) {
        focusPromptAnswered = true
        focusAccepted = accepted
        focusGuidance = focusService.guidance(accepted: accepted)
    }

    func startRun(focusAccepted accepted: Bool) {
        guard ScreenTimeProtectionStartPolicy.canStart(shieldingReadiness) else {
            focusGuidance = shieldingReadiness.detail
            showFocusModePrompt = false
            return
        }
        answerFocusPrompt(accepted)
        coordinator.start(configuration: FocusRunConfiguration(duration: selectedDuration, guardKind: selectedGuardKind), focusAccepted: accepted)
        notifications.scheduleLegacyCompletion(at: activeRun?.plannedEndAt)
        if selectedGuardKind == .qrCode {
            showQRCodeScanner = true
        } else if selectedGuardKind == .nfcTag {
            scanNFCTag()
        }
        showFocusModePrompt = false
    }

    func acceptQRCode(_ code: String) {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCode.isEmpty else {
            qrCodeStatus = "That code could not be read. Try again."
            return
        }
        let isAdditionalQuiet = pendingRunIsAdditionalQuiet || activeRunIsAdditionalQuiet
        if persistence.phoneBedQRCode == nil {
            persistence.phoneBedQRCode = normalizedCode
            qrCodeStatus = isAdditionalQuiet ? "Phone-bed code saved." : "Wind Down code saved."
        }
        if coordinator.confirmQRCode(normalizedCode, expectedCode: persistence.phoneBedQRCode) {
            showQRCodeScanner = false
            qrCodeStatus = ""
        } else {
            qrCodeStatus = isAdditionalQuiet
                ? "That is not your phone-bed code. Try again."
                : "That is not your Wind Down code. Try again."
        }
    }

    func scanNFCTag() {
        nfcStatus = ""
        let purpose = currentNFCPurpose
        guard phoneBedTagLibrary.hasTag(for: purpose) else {
            nfcStatus = pendingRunIsAdditionalQuiet || activeRunIsAdditionalQuiet
                ? "Set up a Phone Away tag in Settings before starting with NFC."
                : "Set up a Wind Down tag in Settings before starting with NFC."
            return
        }
        let isPendingStart = pendingNightWatchPlan != nil && activeRun == nil
        guard WindDownStartGate.canBeginNFCRead(
            forPendingStart: isPendingStart,
            hasActiveRun: activeRun != nil,
            startInFlight: nightWatchStartInFlight,
            scanInFlight: isScanningNFCForStart
        ) else { return }
        isScanningNFCForStart = isPendingStart
        phoneBedNFCService.scan(
            isAdditionalQuiet: pendingRunIsAdditionalQuiet || activeRunIsAdditionalQuiet
        ) { [weak self] result in
            guard let self else { return }
            self.isScanningNFCForStart = false
            switch result {
            case .read(let read):
                guard self.phoneBedTagLibrary.authenticatingTag(
                    digest: read.digest,
                    purpose: purpose
                ) != nil else {
                    self.nfcStatus = self.pendingNightWatchPlan != nil
                        ? (self.pendingRunIsAdditionalQuiet
                            ? "That tag is not set up for Phone Away. Phone Away has not started."
                            : "That tag is not set up for Wind Down. Wind Down has not started.")
                        : (self.activeRunIsAdditionalQuiet
                            ? "That tag is not set up for Phone Away. Phone Away is still running."
                            : "That tag is not set up for Wind Down. Wind Down is still running.")
                    return
                }
                if self.pendingNightWatchPlan != nil,
                   self.activeRun == nil {
                    self.markNFCTagVerified(read.digest, purpose: purpose)
                    self.nfcStatus = self.pendingRunIsAdditionalQuiet
                        ? "Phone Away is starting."
                        : "Wind Down is starting."
                    self.startPendingNightWatch()
                    return
                }
                if self.coordinator.confirmNFCTag(
                    read.digest,
                    expectedFingerprint: read.digest
                ) {
                    self.markNFCTagVerified(read.digest, purpose: purpose)
                    self.nfcStatus = self.activeRunIsAdditionalQuiet
                        ? "Phone Away tag confirmed."
                        : "Wind Down tag confirmed."
                } else {
                    self.nfcStatus = self.activeRunIsAdditionalQuiet
                        ? "That is not your Phone Away tag. Phone Away is still running."
                        : "That is not your Wind Down tag. Wind Down is still running."
                }
            case .cancelled:
                if self.pendingNightWatchPlan != nil {
                    self.nfcStatus = self.pendingRunIsAdditionalQuiet
                        ? "No tag was read. Phone Away has not started."
                        : "No tag was read. Wind Down has not started."
                } else {
                    self.nfcStatus = self.activeRunIsAdditionalQuiet
                        ? "No tag was read. Phone Away is still running."
                        : "No tag was read. Wind Down is still running."
                }
            case .unavailable(let message):
                self.nfcStatus = message
            }
        }
    }

    func requestEndWindDown() {
        guard activeRun?.guardKind == .nfcTag else {
            endWindDownEarly()
            return
        }
        nfcStatus = ""
        let purpose = currentNFCPurpose
        guard phoneBedTagLibrary.hasTag(for: purpose) else {
            nfcStatus = activeRunIsAdditionalQuiet
                ? "The saved Phone Away tag is missing. Phone Away is still running. Use the emergency exit to end without the tag."
                : "The saved Wind Down tag is missing. Wind Down is still running. Use the emergency exit to end without the tag."
            return
        }
        phoneBedNFCService.scan(isAdditionalQuiet: activeRunIsAdditionalQuiet) { [weak self] result in
            guard let self else { return }
            switch result {
            case .read(let read):
                guard self.phoneBedTagLibrary.authenticatingTag(
                    digest: read.digest,
                    purpose: purpose
                ) != nil else {
                    self.nfcStatus = self.activeRunIsAdditionalQuiet
                        ? "That tag is not set up for Phone Away. Phone Away is still running."
                        : "That tag is not set up for Wind Down. Wind Down is still running."
                    return
                }
                self.markNFCTagVerified(read.digest, purpose: purpose)
                self.nfcStatus = self.activeRunIsAdditionalQuiet
                    ? "Phone Away tag confirmed. App limits are being cleared."
                    : "Wind Down tag confirmed. App limits are being cleared."
                self.performAuthorizedEarlyExit(reason: .nfcTagAuthenticated)
            case .cancelled:
                self.nfcStatus = self.activeRunIsAdditionalQuiet
                    ? "No tag was read. Phone Away is still running."
                    : "No tag was read. Wind Down is still running."
            case .unavailable:
                self.nfcStatus = self.activeRunIsAdditionalQuiet
                    ? "NFC is not available. Phone Away is still running. Use the emergency exit to end without the tag."
                    : "NFC is not available. Wind Down is still running. Use the emergency exit to end without the tag."
            }
        }
    }

    var emergencyExitChallenge: EmergencyExitChallenge? {
        coordinator.emergencyExitChallenge
    }

    func beginEmergencyExitChallenge() -> Bool {
        coordinator.beginEmergencyExitChallenge()
    }

    func submitEmergencyExitWord(_ word: String) -> Bool {
        coordinator.submitEmergencyExitWord(word)
    }

    func submitEmergencyExitReason(_ reason: String) -> Bool {
        coordinator.submitEmergencyExitReason(reason)
    }

    func submitEmergencyExitConfirmation(_ reason: String) -> Bool {
        coordinator.submitEmergencyExitConfirmation(reason)
    }

    func cancelEmergencyExitChallenge() {
        coordinator.cancelEmergencyExitChallenge()
    }

    func confirmEmergencyExit() -> Bool {
        coordinator.confirmEmergencyExit()
    }

    func endWindDownEarly() {
        performAuthorizedEarlyExit(reason: .userEnded)
    }

    private func performAuthorizedEarlyExit(reason: EarlyEndReason) {
        // The coordinator validates before invoking its cleanup callback. This
        // leaves an active NFC run untouched after an unverified attempt.
        coordinator.endEarly(reason: reason)
    }

    /// An automatic DeviceActivity schedule can outlive the in-app run. Remove the
    /// current schedule before ending so its extension cannot reapply a shield after
    /// an NFC or emergency exit. `onRunFinished` then installs the next occurrence.
    private func prepareForEarlyWindDownExit() {
        cancelActiveRunNotifications()
        persistence.automaticWindDownSchedule = nil
        quietTimeShielding.cancelAutomaticSchedule()
    }

    private func cancelActiveRunNotifications() {
        notifications.cancelAllNightWatchNotifications()
        usageMonitoring.cancel()
    }

    /// Writes a new credential and commits its slot only after the physical write succeeds.
    func provisionNFCTag(
        forActiveRun: Bool = false,
        role: PhoneBedTagRole = .primary,
        name: String = NamedPhoneBedTagRegistration.defaultName,
        purposes: Set<PhoneBedTagPurpose> = NamedPhoneBedTagRegistration.allPurposes,
        intent: PhoneBedTagProvisionIntent = .normalPairing,
        expectedCredentialDigest: String? = nil
    ) {
        guard intent == .normalPairing || !forActiveRun && !isRunning else {
            nfcStatus = "Resync is available only from Settings while no run is active. Nothing changed."
            return
        }
        isProvisioningNFCTag = true
        nfcStatus = ""
        let existingSlot = phoneBedTagLibrary.tag(for: role)
        var compatiblePurposes = purposes.isEmpty
            ? NamedPhoneBedTagRegistration.allPurposes
            : purposes
        if forActiveRun, activeRun?.guardKind == .nfcTag {
            compatiblePurposes.insert(currentNFCPurpose)
        }
        phoneBedNFCService.provision(
            isAdditionalQuiet: forActiveRun && activeRunIsAdditionalQuiet,
            intent: intent,
            knownCredentialDigests: Set(phoneBedTagLibrary.tags.map(\.tokenDigest)),
            previouslyPairedCredentialDigests: phoneBedTagLibrary.previouslyPairedTokenDigests,
            expectedCredentialDigest: expectedCredentialDigest
        ) { [weak self] result in
            guard let self else { return }
            self.isProvisioningNFCTag = false
            switch result {
            case .registered(let registration):
                guard PhoneBedTagSlotCommitPolicy.shouldCommit(.physicalWriteSucceeded) else { return }
                if let expectedCredentialDigest {
                    self.phoneBedTagLibrary.retireCredential(expectedCredentialDigest)
                }
                let namedRegistration = NamedPhoneBedTagRegistration(
                    id: existingSlot?.id ?? UUID(),
                    name: name,
                    tokenDigest: registration.tokenDigest,
                    registeredAt: Date(),
                    lastVerifiedAt: registration.lastVerifiedAt,
                    role: role,
                    purposes: compatiblePurposes
                )
                self.phoneBedTagLibrary.replace(role: role, with: namedRegistration)
                self.persistPhoneBedTagLibrary()
                if !forActiveRun {
                    self.scheduleAutomaticWindDownIfNeeded()
                }
                if forActiveRun,
                   self.activeRun?.guardKind == .nfcTag,
                   namedRegistration.supports(self.currentNFCPurpose) {
                    if self.activeRun?.placementStatus == .awaitingConfirmation {
                        _ = self.coordinator.confirmNFCTag(
                            namedRegistration.tokenDigest,
                            expectedFingerprint: namedRegistration.tokenDigest
                        )
                        self.nfcStatus = self.activeRunIsAdditionalQuiet
                            ? "New tag paired. Phone Away is starting."
                            : "New tag paired. Wind Down is starting."
                    } else {
                        self.nfcStatus = self.activeRunIsAdditionalQuiet
                            ? "New tag paired. Tap it again to end Phone Away."
                            : "New tag paired. Tap it again to end Wind Down."
                    }
                } else {
                    self.nfcStatus = "Tag saved. Suggested label: \(namedRegistration.suggestedLabel)."
                }
            case .resetRequired(let digest):
                guard expectedCredentialDigest == nil else {
                    self.nfcStatus = "That tag changed before it could be reset. Nothing changed."
                    return
                }
                self.pendingNFCTagReset = PendingNFCTagReset(
                    oldCredentialDigest: digest,
                    role: role,
                    name: NamedPhoneBedTagRegistration.normalizedName(name),
                    purposes: compatiblePurposes,
                    existingSlotID: existingSlot?.id
                )
                self.nfcStatus = "This is a previously used Counting Sheep tag. Choose “Reset and pair this tag” to replace its old credential."
            case .alreadyPaired(let digest):
                if let existing = self.phoneBedTagLibrary.tag(matching: digest) {
                    self.nfcStatus = "\(existing.name) is already paired. Rename it or change its uses instead."
                } else {
                    self.nfcStatus = "That Counting Sheep tag is already paired. Edit its name or uses instead."
                }
            case .previouslyPaired:
                let purpose = (forActiveRun && self.activeRunIsAdditionalQuiet) || purposes.contains(.phoneAway)
                    ? "Phone Away"
                    : "Wind Down"
                self.nfcStatus = "This tag was paired before but is no longer active for \(purpose). To use it again, resync it from Settings."
            case .cancelled:
                self.nfcStatus = forActiveRun
                    ? (self.activeRunIsAdditionalQuiet
                        ? "No changes made. Phone Away is still running with your current tag."
                        : "No changes made. Wind Down is still running with your current tag.")
                    : "No changes made. Your current Wind Down tag is still ready."
            case .unavailable(let message):
                self.nfcStatus = message
            }
        }
    }

    /// Starts the Settings-only recovery scan. Blank tags are paired through
    /// the ordinary path; occupied Counting Sheep credentials pause here for
    /// explicit confirmation before a second session can write.
    func beginResetAndPairNFCTag(
        role: PhoneBedTagRole,
        name: String,
        purposes: Set<PhoneBedTagPurpose>
    ) {
        guard !isRunning else {
            nfcStatus = "Reset and pairing is unavailable while Wind Down is active. Nothing changed."
            return
        }
        pendingNFCTagReset = nil
        provisionNFCTag(
            role: role,
            name: name,
            purposes: purposes,
            intent: .settingsResetAndPair
        )
    }

    func confirmResetAndPairNFCTag() {
        guard let pendingNFCTagReset else { return }
        self.pendingNFCTagReset = nil
        provisionNFCTag(
            role: pendingNFCTagReset.role,
            name: pendingNFCTagReset.name,
            purposes: pendingNFCTagReset.purposes,
            intent: .settingsResetAndPair,
            expectedCredentialDigest: pendingNFCTagReset.oldCredentialDigest
        )
    }

    func cancelResetAndPairNFCTag() {
        pendingNFCTagReset = nil
        nfcStatus = "No changes made. The tag’s existing credential is unchanged."
    }

    /// A retired physical tag can only be rewritten from Settings. The old
    /// digest stays retired; the stable slot receives a fresh credential after
    /// Core NFC confirms the physical write.
    func resyncRetiredNFCTag(role: PhoneBedTagRole) {
        guard let tag = phoneBedTagLibrary.tag(for: role) else {
            nfcStatus = "Resync is available only from Settings while no run is active. Nothing changed."
            return
        }
        beginResetAndPairNFCTag(
            role: role,
            name: tag.name,
            purposes: tag.purposes
        )
    }

    func testNFCTag() {
        nfcStatus = ""
        phoneBedNFCService.scan { [weak self] result in
            guard let self else { return }
            switch result {
            case .read(let read):
                guard let recognized = self.phoneBedTagLibrary.tag(matching: read.digest) else {
                    if self.phoneBedTagLibrary.wasPreviouslyPaired(digest: read.digest) {
                        self.nfcStatus = "This tag was paired before but is no longer active. To use it again, resync it from Settings."
                        return
                    }
                    self.nfcStatus = "That tag is not paired. You can add it as a backup or replace an existing tag."
                    return
                }
                self.markNFCTagVerified(read.digest)
                self.nfcStatus = "Recognized \(recognized.name). Uses: \(recognized.purposesDescription). No run was changed."
            case .cancelled:
                self.nfcStatus = "No tag was read. Nothing changed."
            case .unavailable(let message):
                self.nfcStatus = message
            }
        }
    }

    func renameNFCTag(id: UUID, name: String) {
        phoneBedTagLibrary.rename(id: id, to: name)
        persistPhoneBedTagLibrary()
        if let tag = phoneBedTagLibrary.tags.first(where: { $0.id == id }) {
            nfcStatus = "Name saved. Suggested label: \(tag.suggestedLabel)."
        }
    }

    func changeNFCTagPurposes(id: UUID, purposes: Set<PhoneBedTagPurpose>) {
        guard !purposes.isEmpty else {
            nfcStatus = "Choose Wind Down, Phone Away, or both."
            return
        }
        phoneBedTagLibrary.changePurposes(id: id, to: purposes)
        persistPhoneBedTagLibrary()
        scheduleAutomaticWindDownIfNeeded()
        nfcStatus = "Tag uses updated."
    }

    func forgetNFCTag(id: UUID) {
        phoneBedTagLibrary.forget(id: id)
        persistPhoneBedTagLibrary()
        nfcStatus = "Counting Sheep forgot that tag. Its name was never written to the tag."
        scheduleAutomaticWindDownIfNeeded()
    }

    func resetNFCTag() {
        persistence.resetPhoneBedNFCTag()
        phoneBedTagLibrary = PhoneBedTagLibrary()
        nfcStatus = "The paired tags have been forgotten. Set up a new one whenever you are ready."
        scheduleAutomaticWindDownIfNeeded()
    }

    private var currentNFCPurpose: PhoneBedTagPurpose {
        pendingRunIsAdditionalQuiet || activeRunIsAdditionalQuiet ? .phoneAway : .windDown
    }

    private func markNFCTagVerified(
        _ digest: String,
        purpose: PhoneBedTagPurpose? = nil
    ) {
        guard phoneBedTagLibrary.markVerified(
            digest: digest,
            purpose: purpose,
            at: nowProvider()
        ) != nil else { return }
        persistPhoneBedTagLibrary()
    }

    private func persistPhoneBedTagLibrary() {
        persistence.phoneBedTagLibrary = phoneBedTagLibrary
    }

    func setShieldingEnabled(_ enabled: Bool) {
        shieldingEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: QuietTimeShieldingService.enabledKey)
        // The active run owns an immutable protection plan. Settings changes
        // are saved now but must not apply or lift its existing shields.
        if isRunning {
            if enabled, screenTimeAuthorization != .approved {
                connectScreenTime()
            }
            return
        }
        if enabled {
            if screenTimeAuthorization != .approved {
                connectScreenTime()
            }
            coordinator.reconcileSession()
            scheduleAutomaticWindDownIfNeeded()
        } else {
            persistence.automaticWindDownSchedule = nil
            quietTimeShielding.cancelAutomaticSchedule()
            scheduleAutomaticWindDownIfNeeded()
        }
    }

    /// Rehydrates an automatic run after the app returns from the background or is
    /// relaunched. DeviceActivity handles the shield while the app is closed.
    func reconcileAutomaticWindDownIfNeeded() {
        guard !isRunning,
              nightWatchPreferences.isConfigured,
              hasAutomaticWindDownRoutine,
              let schedule = persistence.automaticWindDownSchedule else {
            return
        }

        guard case .schedule = AutomaticWindDownProtectionDecision.resolve(
            readiness: shieldingReadiness
        ) else {
            recordAutomaticProtectionRepair()
            return
        }

        persistence.automaticWindDownProtectionRepairNeeded = false

        let now = Date()
        if let sourceID = schedule.sourceOccurrenceID,
           windDownSchedule.oneTimePeriods.contains(where: { $0.id == sourceID }) {
            // One-time windows are manual even when an older build persisted
            // them as automatic schedules. Clear the stale callback without
            // materializing a run or applying shielding.
            persistence.automaticWindDownSchedule = nil
            quietTimeShielding.cancelAutomaticSchedule()
            scheduleNextAutomaticWindDown(after: now)
            return
        }
        guard now >= schedule.startedAt else {
            quietTimeShielding.scheduleAutomatic(for: schedule, at: now)
            return
        }

        guard now < schedule.plan.protectedUntil else {
            notifications.cancelNightWatchReminder()
            persistence.automaticWindDownSchedule = nil
            consumeScheduledOccurrence(schedule.sourceOccurrenceID)
            coordinator.reconcileExpiredAutomaticNightWatch(
                plan: schedule.plan,
                guardKind: nightWatchPreferences.guardKind,
                startedAt: schedule.startedAt,
                endedAt: schedule.plan.protectedUntil,
                appShieldingRequested: schedule.appShieldingRequested,
                liveActivityRequested: liveActivityEnabled,
                runID: schedule.id
            )
            scheduleNextAutomaticWindDown()
            return
        }

        notifications.cancelNightWatchReminder()
        consumeScheduledOccurrence(schedule.sourceOccurrenceID)
        coordinator.start(
            configuration: FocusRunConfiguration(
                nightWatchPlan: schedule.plan,
                guardKind: nightWatchPreferences.guardKind
            ),
            focusAccepted: false,
            startedAt: schedule.startedAt,
            autoConfirmPlacement: true,
            appShieldingRequested: schedule.appShieldingRequested,
            liveActivityRequested: liveActivityEnabled,
            runID: schedule.id
        )
        if let activeRun, let plan = activeRun.nightWatchPlan {
            notifications.scheduleNightWatchNotifications(
                for: plan,
                startedAt: activeRun.startedAt,
                purpose: offlinePurpose,
                seed: activeRun.id,
                preferences: notificationPreferences
            )
            usageMonitoring.schedule(for: plan, startedAt: activeRun.startedAt)
        }
    }

    private func scheduleAutomaticWindDownIfNeeded() {
        switch AutomaticWindDownSchedulingDecision.resolve(
            isRunActive: isRunning,
            isConfigured: nightWatchPreferences.isConfigured,
            hasAutomaticRoutine: hasAutomaticWindDownRoutine,
            guardKind: selectedGuardKind,
            hasWindDownTag: hasRegisteredNFCTag
        ) {
        case .preserveActiveRun:
            return
        case .cancelIneligibleSchedule:
            persistence.automaticWindDownSchedule = nil
            notifications.cancelNightWatchReminder()
            quietTimeShielding.cancelAutomaticSchedule()
            usageMonitoring.cancel()
            // A manual plan can still have its explicitly requested prompt.
            // This never creates an automatic run or a background shield schedule.
            if nightWatchPreferences.isConfigured, notificationPreferences.remindersEnabled {
                notifications.scheduleNextWindDownReminder(
                    at: nightWatchPreferences.nextStart(),
                    purpose: offlinePurpose,
                    preferences: notificationPreferences
                )
            }
            return
        case .cancelMissingWindDownTag:
            persistence.automaticWindDownSchedule = nil
            notifications.cancelNightWatchReminder()
            // No active run is being preserved here. Stop the stale DeviceActivity
            // monitor and shared shield snapshot before keeping reminder-only cues.
            quietTimeShielding.cancelAutomaticSchedule()
            let startDate = nightWatchPreferences.nextStart()
            notifications.scheduleAutomaticWindDownNotifications(
                at: startDate,
                plan: nightWatchPreferences.makePlan(startedAt: startDate),
                purpose: offlinePurpose,
                seed: UUID(),
                preferences: notificationPreferences
            )
            usageMonitoring.cancel()
            notifications.reconcileUpcomingWindDownNotifications(
                for: windDownSchedule,
                primaryExtensionMinutes: nightWatchPreferences.morningQuietMinutes,
                purpose: offlinePurpose,
                preferences: notificationPreferences
            )
            return
        case .schedule:
            guard case .schedule = AutomaticWindDownProtectionDecision.resolve(
                readiness: shieldingReadiness
            ) else {
                recordAutomaticProtectionRepair()
                return
            }
        }
        scheduleNextAutomaticWindDown()
        notifications.reconcileUpcomingWindDownNotifications(
            for: windDownSchedule,
            primaryExtensionMinutes: nightWatchPreferences.morningQuietMinutes,
            purpose: offlinePurpose,
            preferences: notificationPreferences
        )
    }

    private var hasAutomaticWindDownRoutine: Bool {
        let hasRepeating = windDownSchedule.routines.contains {
            $0.enabled && $0.automaticStartEnabled
        }
        // A saved one-time period is a manual invitation. It must not create a
        // background run or shielding schedule merely because it was saved.
        return hasRepeating || (windDownRoutines.isEmpty && nightWatchPreferences.automaticStartEnabled)
    }

    private func scheduleNextAutomaticWindDown(after date: Date = Date()) {
        guard case .schedule = AutomaticWindDownProtectionDecision.resolve(
            readiness: shieldingReadiness
        ) else {
            recordAutomaticProtectionRepair()
            return
        }
        var state = windDownSchedule
        state.prunePassedOneTimePeriods(at: date)
        windDownSchedule = state
        persistence.windDownSchedule = state

        let automaticState = WindDownScheduleState(
            oneTimePeriods: [],
            routines: state.routines.filter { $0.enabled && $0.automaticStartEnabled }
        )
        let next = automaticState.upcomingPeriods(
            after: date,
            primaryExtensionMinutes: nightWatchPreferences.morningQuietMinutes,
            limit: 1
        ).first
        let startDate = next?.occurrence.interval.start ?? nightWatchPreferences.nextStart(after: date)
        guard startDate > date else {
            persistence.automaticWindDownSchedule = nil
            notifications.cancelNightWatchReminder()
            quietTimeShielding.cancelAutomaticSchedule()
            usageMonitoring.cancel()
            return
        }
        let plan = next.map {
            WindDownScheduleEngine.plan(
                for: $0,
                preferences: nightWatchPreferences,
                startedAt: startDate
            )
        } ?? nightWatchPreferences.makePlan(startedAt: startDate)
        let schedule = AutomaticWindDownSchedule(
            startedAt: startDate,
            plan: plan,
            sourceOccurrenceID: next?.sourceID,
            appShieldingRequested: true
        )
        persistence.automaticWindDownProtectionRepairNeeded = false
        persistence.automaticWindDownSchedule = schedule
        notifications.cancelNightWatchReminder()
        notifications.scheduleAutomaticWindDownNotifications(
            at: startDate,
            plan: plan,
            purpose: offlinePurpose,
            seed: schedule.id,
            preferences: notificationPreferences
        )
        usageMonitoring.schedule(for: plan, startedAt: startDate, repeatsDaily: false)
        if plan.role == .primarySleepBookend {
            quietTimeShielding.scheduleAutomatic(for: schedule)
        }
    }

    /// Keep a missed automatic start recoverable without creating a timer-only
    /// run or recording any shield evidence. The next foreground Home state
    /// reads the same readiness and offers the focused repair route.
    private func recordAutomaticProtectionRepair() {
        persistence.automaticWindDownSchedule = nil
        persistence.automaticWindDownProtectionRepairNeeded = true
        notifications.cancelNightWatchReminder()
        quietTimeShielding.cancelAutomaticSchedule()
        usageMonitoring.cancel()
    }

    private func consumeScheduledOccurrence(_ id: UUID?) {
        guard let id else { return }
        guard windDownSchedule.consumeOneTimePeriod(id: id) else { return }
        persistence.windDownSchedule = windDownSchedule
        nextWindDownOverride = windDownSchedule.oneTimePeriods
            .filter(\.isAvailable)
            .sorted { $0.interval.start < $1.interval.start }
            .first
            .map { period in
                NextWindDownOverride(
                    id: period.id,
                    routineID: period.id,
                    role: period.role,
                    interval: period.interval,
                    expiresAt: period.interval.end
                )
            }
    }

    func resetSetup() {
        coordinator.resetToSetup()
        usageMonitoring.cancel()
        phoneBedNFCService.cancel()
        resetTransientSetupState()
    }

    private func resetTransientSetupState() {
        showCustomDurationPicker = false
        showFocusModePrompt = false
        focusPromptAnswered = false
        focusAccepted = false
        focusGuidance = ""
        customDurationSelected = false
        selectedGuardKind = nightWatchPreferences.guardKind
        showQRCodeScanner = false
        qrCodeStatus = ""
        nfcStatus = ""
        showNightWatchStartPrompt = false
        nightWatchStartStatus = ""
        isScanningNFCForStart = false
        isProvisioningNFCTag = false
        pendingNFCTagReset = nil
        pendingNightWatchPlan = nil
        pendingNightWatchSourceOccurrenceID = nil
        pendingWindDownStartContext = nil
        pendingAdHocQuietTransaction = nil
        nightWatchStartInFlight = false
    }

    func eraseLocalDataAndStartOver() {
        // Publish the non-forced appearance before changing the run route so a
        // reset out of a dark active Wind Down settles in one coherent update.
        appearancePreference = .automatic
        persistence.appearancePreference = .automatic

        phoneBedNFCService.cancel()
        coordinator.resetToSetup(clearPersistedRun: false)
        coordinator.resetLiveActivityToFreshInstallDefaults()
        resetTransientSetupState()
        usageMonitoring.cancel()
        notifications.resetLocalState()
        quietTimeShielding.resetLocalState()
        healthSleepService.resetLocalState()
        FocusRunShortcutStore.clearPendingDuration()
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        screenTimeSelectionService.clearAllSelections()
#endif

        persistence.resetLocalProductData()

        nightWatchPreferences = .defaults
        windDownSchedule = WindDownScheduleState()
        windDownRoutines = []
        nextWindDownOverride = nil
        offlinePurpose = .defaultProfile
        screenTimeReportPreferences = ScreenTimeReportPreferences.defaults(
            for: nightWatchPreferences
        )
        morningCheckIns = MorningCheckInHistory()
        manualAnalyticsEntries = []
        impactSharingPreferences = ImpactSharingPreferences()
        impactDataSyncState = .idle
        notificationPreferences = notifications.preferences
        notificationAuthorization = .notDetermined
        screenTimeAuthorization = screenTimeService.currentState()
        sleepAuthorization = healthSleepService.isAvailable ? .notRequested : .unavailable
        lastNightSleep = nil
        recentNightSleeps = []
        isRefreshingSleep = false
        analyticsExportURL = nil
        analyticsExportError = nil
        shieldingEnabled = false
        liveActivityEnabled = FocusRunLiveActivityService.preferenceEnabled
        liveActivityChoiceForNextRun = liveActivityEnabled
        selectedGuardKind = .nfcTag
        phoneBedTagLibrary = PhoneBedTagLibrary()
        orientationState = .fresh
        nightsRecordFocusID = nil
        selectedDuration = 25 * 60
        durationMinutes = 25
        durationSeconds = 0

#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        distractingActivitySelection = FamilyActivitySelection()
        productiveActivitySelection = FamilyActivitySelection()
        bedtimeActivitySelection = FamilyActivitySelection()
#endif

        coordinator.progress = .empty
        coordinator.rewards = []
        coordinator.sheepSearchState = .empty
        coordinator.latestSheepSearchOutcome = nil
        coordinator.farmState = .empty
        persistence.welcomeRewardLedger = .empty
        persistence.windDownProfileRecord = nil
        persistence.sheepSearchState = .empty
        let welcome = WelcomeRewardEngine.reconcile(
            farm: .empty,
            search: .empty,
            ledger: .empty
        )
        coordinator.sheepSearchState = welcome.search
        coordinator.farmState = welcome.farm
        coordinator.latestSheepSearchOutcome = welcome.outcome
        persistence.sheepSearchState = welcome.search
        persistence.farmState = welcome.farm
        persistence.welcomeRewardLedger = welcome.ledger
        persistence.nightFlockRewardLedger = .empty
        farmActionMessage = nil
        coordinator.events = []
        coordinator.latestReward = nil
        coordinator.pingPulseCount = 0
        rootRoute = .freshOnboarding
    }

    func connectScreenTime() {
        Task { @MainActor in
            _ = await requestScreenTimeAuthorization()
        }
    }

    @discardableResult
    func requestScreenTimeAuthorization() async -> Bool {
        screenTimeAuthorization = await screenTimeService.requestAuthorization()
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        if screenTimeAuthorization == .approved {
            bedtimeActivitySelection = screenTimeSelectionService.load(.bedtime)
        }
#endif
        return screenTimeAuthorization == .approved
    }

    func setLiveActivityEnabled(_ enabled: Bool) {
        liveActivityEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: FocusRunLiveActivityService.preferenceKey)
        coordinator.setLiveActivityEnabled(enabled)
    }

    func retryShielding() {
        guard let run = activeRun else { return }
        coordinator.reconcileShieldingNow(for: run)
    }

    func requestNotificationPermission() async -> Bool {
        let granted = await notifications.requestAuthorization()
        notificationAuthorization = await notifications.authorizationStatus()
        return granted
    }

    func screenTimeReportDate(
        for window: ScreenTimeReportPreferences.Window,
        isStart: Bool
    ) -> Date {
        let minute = screenTimeReportPreferences.minute(for: window, isStart: isStart)
        return Calendar.current.date(
            bySettingHour: minute / 60,
            minute: minute % 60,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    func updateScreenTimeReportDate(
        _ date: Date,
        for window: ScreenTimeReportPreferences.Window,
        isStart: Bool
    ) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return }
        screenTimeReportPreferences.setMinute(
            hour * 60 + minute,
            for: window,
            isStart: isStart
        )
        persistence.screenTimeReportPreferences = screenTimeReportPreferences
    }

#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
    func saveScreenTimeSelection(_ scope: ScreenTimeSelectionScope) {
        switch scope {
        case .distracting:
            distractingActivitySelection = distractingActivitySelection.appsAndCategoriesOnly
            screenTimeSelectionService.save(distractingActivitySelection, for: scope)
        case .productive:
            productiveActivitySelection = productiveActivitySelection.appsAndCategoriesOnly
            screenTimeSelectionService.save(productiveActivitySelection, for: scope)
        case .bedtime:
            bedtimeActivitySelection = bedtimeActivitySelection.appsAndCategoriesOnly
            screenTimeSelectionService.save(bedtimeActivitySelection, for: scope)
            // A non-empty selection is an explicit affirmative choice and turns
            // future runs back on, while preserving the per-run skip control.
            if hasSelectedShieldingApps {
                shieldingEnabled = true
                UserDefaults.standard.set(true, forKey: QuietTimeShieldingService.enabledKey)
                persistence.automaticWindDownProtectionRepairNeeded = false
                scheduleAutomaticWindDownIfNeeded()
            }
            if !canUseUsageAwareReminders {
                var updated = notificationPreferences
                updated.usageAwareRemindersEnabled = false
                notificationPreferences = updated
                notifications.preferences = updated
                usageMonitoring.cancel()
            }
        }
    }

    func selection(for scope: ScreenTimeSelectionScope) -> FamilyActivitySelection {
        switch scope {
        case .distracting: return distractingActivitySelection
        case .productive: return productiveActivitySelection
        case .bedtime: return bedtimeActivitySelection
        }
    }
#endif

    func connectAppleHealthSleep() {
        Task { @MainActor in
            sleepAuthorization = await healthSleepService.requestSleepAccess()
            if sleepAuthorization == .requested {
                await loadRecentSleepSummaries()
            }
        }
    }

    func refreshSleepSummary() {
        Task { @MainActor in
            guard sleepAuthorization == .requested else { return }
            await loadRecentSleepSummaries()
        }
    }

    var todayMorningCheckIn: MorningCheckIn {
        morningCheckIn(for: Date())
    }

    func morningCheckIn(for date: Date) -> MorningCheckIn {
        morningCheckIns.entry(for: date) ?? MorningCheckIn(
            day: date,
            sleepOnset: nil,
            restfulness: nil,
            bedtimeSleepiness: nil
        )
    }

    func updateMorningSleepOnset(_ value: SleepOnsetEstimate?) {
        updateMorningSleepOnset(value, for: Date())
    }

    func updateMorningSleepOnset(_ value: SleepOnsetEstimate?, for date: Date) {
        var entry = morningCheckIn(for: date)
        entry.sleepOnset = value
        saveMorningCheckIn(entry)
    }

    func updateMorningRestfulness(_ value: MorningRestfulness?) {
        updateMorningRestfulness(value, for: Date())
    }

    func updateMorningRestfulness(_ value: MorningRestfulness?, for date: Date) {
        var entry = morningCheckIn(for: date)
        entry.restfulness = value
        saveMorningCheckIn(entry)
    }

    func updateBedtimeSleepiness(_ value: BedtimeSleepiness?) {
        updateBedtimeSleepiness(value, for: Date())
    }

    func updateBedtimeSleepiness(_ value: BedtimeSleepiness?, for date: Date) {
        var entry = morningCheckIn(for: date)
        entry.bedtimeSleepiness = value
        saveMorningCheckIn(entry)
    }

    private func loadRecentSleepSummaries() async {
        isRefreshingSleep = true
        defer { isRefreshingSleep = false }
        recentNightSleeps = await healthSleepService.recentNightSleeps(days: 30)
        let calendar = Calendar.current
        lastNightSleep = recentNightSleeps.first { summary in
            guard let nightEndingDate = summary.nightEndingDate else { return false }
            return calendar.isDate(nightEndingDate, inSameDayAs: Date())
        }
        linkHealthOutcomesToRitualHistory()
        let supplementWindow = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        if let lastNightSleep, let nightEndingDate = lastNightSleep.nightEndingDate ?? lastNightSleep.endDate {
            publishSlumberPartyMetricSupplement(at: nightEndingDate)
        }
        for record in persistence.nightWatchHistory.records
            where record.outcome == .completed
            && record.role == .primarySleepBookend
            && record.plan.wakeTime >= supplementWindow {
            publishSlumberPartyMetricSupplement(at: record.plan.wakeTime)
        }
        if impactSharingPreferences.isEnabled {
            await syncImpactData()
        }
    }

    private func saveMorningCheckIn(_ entry: MorningCheckIn) {
        morningCheckIns.upsert(entry)
        persistence.morningCheckIns = morningCheckIns
        notifications.cancelMorningReflectionReminder()
        if let record = persistence.nightWatchHistory.records.first(where: {
            Calendar.current.isDate($0.plan.wakeTime, inSameDayAs: entry.day)
        }) {
            persistence.appendRitualEvent(
                RitualEvent(
                    runID: record.id,
                    kind: .morningReflectionSaved,
                    source: .selfReported,
                    idempotencyKey: "\(record.id.uuidString):morning-reflection",
                    payload: ["answerSummary": entry.summary]
                )
            )
        }
        publishSlumberPartyMetricSupplement(at: entry.day)
    }

    private func linkHealthOutcomesToRitualHistory() {
        let calendar = Calendar.current
        for record in persistence.nightWatchHistory.records {
            guard let sleep = recentNightSleeps.first(where: { summary in
                guard let date = summary.nightEndingDate ?? summary.endDate else {
                    return false
                }
                return calendar.isDate(date, inSameDayAs: record.plan.wakeTime)
            }) else { continue }
            persistence.appendRitualEvent(
                RitualEvent(
                    runID: record.id,
                    kind: .healthOutcomeLinked,
                    source: .system,
                    idempotencyKey: "\(record.id.uuidString):health-outcome",
                    payload: [
                        "hasStages": sleep.stages.hasStages ? "true" : "false",
                        "sourceAvailable": sleep.sourceName == nil ? "false" : "true"
                    ]
                )
            )
        }
    }

    var analyticsRecords: [AnalyticsDayRecord] {
        FocusAnalyticsEngine.dayRecords(
            progress: analyticsProgress,
            days: 30,
            manualEntries: analyticsManualEntries,
            screenTimePlaceholders: includeAnalyticsPlaceholders ? placeholderScreenTimeMinutes : [:],
            sleepPlaceholders: includeAnalyticsPlaceholders ? placeholderSleepMinutes : [:]
        )
    }

    var analyticsCorrelations: [AnalyticsCorrelation] {
        FocusAnalyticsEngine.correlations(for: analyticsRecords)
    }

    var analyticsExportPackage: AnalyticsExportPackage {
        FocusAnalyticsEngine.exportPackage(
            records: analyticsRecords,
            privacyMode: analyticsExportPrivacyMode,
            farmEconomy: farmState.economySnapshot
        )
    }

    var impactSamples: [NightImpactSample] {
        ImpactMeasurementEngine.samples(
            history: persistence.nightWatchHistory,
            sleeps: recentNightSleeps,
            checkIns: morningCheckIns
        )
    }

    var nightWatchRecords: [NightWatchRecord] {
        persistence.nightWatchHistory.records
    }

    var sleepOutcomeComparison: SleepOutcomeComparison? {
        ImpactMeasurementEngine.sleepComparison(for: impactSamples)
    }

    func setImpactSharingEnabled(_ isEnabled: Bool) {
        if isEnabled {
            guard impactSharingAvailable else {
                impactDataSyncState = .unavailable
                return
            }
            impactSharingPreferences.isEnabled = true
            impactSharingPreferences.consentedAt =
                impactSharingPreferences.consentedAt ?? Date()
            persistence.impactSharingPreferences = impactSharingPreferences
            Task { @MainActor in
                await syncImpactData()
            }
        } else {
            impactSharingPreferences.isEnabled = false
            persistence.impactSharingPreferences = impactSharingPreferences
            impactDataSyncState = .idle
        }
    }

    func deleteSharedImpactData() {
        Task { @MainActor in
            impactDataSyncState = .syncing
            let result = await impactDataSyncService.deleteSharedData()
            impactDataSyncState = result
            guard result == .synced else { return }
            impactSharingPreferences = ImpactSharingPreferences()
            persistence.impactSharingPreferences = impactSharingPreferences
            persistence.deleteImpactUploadRecords()
        }
    }

    private func syncImpactData() async {
        guard impactSharingPreferences.isEnabled,
              let consentedAt = impactSharingPreferences.consentedAt else { return }
        let existing = Dictionary(
            uniqueKeysWithValues: persistence.impactUploadRecords.map {
                ($0.relativeNight, $0.id)
            }
        )
        let records = ImpactMeasurementEngine.uploadRecords(
            for: impactSamples,
            consentedAt: consentedAt,
            existingIDs: existing,
            appVersion: Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "unknown"
        )
        persistence.impactUploadRecords = records
        guard !records.isEmpty else { return }
        impactDataSyncState = .syncing
        impactDataSyncState = await impactDataSyncService.sync(records)
    }

    func prepareAnalyticsJSONExport() {
        do {
            analyticsExportURL = try AnalyticsExportService.writeJSON(package: analyticsExportPackage)
            analyticsExportError = nil
        } catch {
            analyticsExportError = error.localizedDescription
        }
    }

    func prepareAnalyticsCSVExport() {
        do {
            analyticsExportURL = try AnalyticsExportService.writeCSV(records: analyticsRecords, privacyMode: analyticsExportPrivacyMode)
            analyticsExportError = nil
        } catch {
            analyticsExportError = error.localizedDescription
        }
    }

    func saveManualAnalyticsEntry(
        day: Date = Date(),
        screenTimeMinutes: Int?,
        socialScreenTimeMinutes: Int? = nil,
        bedtimeScreenTimeMinutes: Int? = nil,
        sleepMinutes: Int?
    ) {
        let calendar = Calendar.current
        let normalizedDay = calendar.startOfDay(for: day)
        var entries = manualAnalyticsEntries.filter { !calendar.isDate($0.day, inSameDayAs: normalizedDay) }

        if screenTimeMinutes != nil || socialScreenTimeMinutes != nil || bedtimeScreenTimeMinutes != nil || sleepMinutes != nil {
            entries.append(
                ManualAnalyticsEntry(
                    day: normalizedDay,
                    screenTimeMinutes: screenTimeMinutes,
                    socialScreenTimeMinutes: socialScreenTimeMinutes,
                    bedtimeScreenTimeMinutes: bedtimeScreenTimeMinutes,
                    sleepMinutes: sleepMinutes,
                    updatedAt: Date(),
                    calendar: calendar
                )
            )
        }

        entries.sort { $0.day > $1.day }
        manualAnalyticsEntries = Array(entries.prefix(90))
        persistence.manualAnalyticsEntries = manualAnalyticsEntries
        analyticsExportURL = nil
    }

    func manualAnalyticsEntry(for day: Date = Date()) -> ManualAnalyticsEntry? {
        let calendar = Calendar.current
        return manualAnalyticsEntries.first { calendar.isDate($0.day, inSameDayAs: day) }
    }

#if DEBUG
    func showAnalyticsQADataset() {
        useAnalyticsQADataset = true
        includeAnalyticsPlaceholders = false
        analyticsExportURL = nil
        analyticsExportError = nil
    }

    func hideAnalyticsQADataset() {
        useAnalyticsQADataset = false
        analyticsExportURL = nil
        analyticsExportError = nil
    }
#endif

    private static let presetMinutes = [3, 10, 25, 60]

    private var analyticsProgress: UserProgress {
#if DEBUG
        if useAnalyticsQADataset {
            return Self.qaAnalyticsProgress()
        }
#endif
        return coordinator.progress
    }

    private var analyticsManualEntries: [ManualAnalyticsEntry] {
#if DEBUG
        if useAnalyticsQADataset {
            return Self.qaManualAnalyticsEntries()
        }
#endif
        return manualAnalyticsEntries
    }

    private var placeholderScreenTimeMinutes: [Date: Int] {
        analyticsPlaceholderSeries(base: 285, step: -7, floor: 90, ceiling: 360)
    }

    private var placeholderSleepMinutes: [Date: Int] {
        analyticsPlaceholderSeries(base: 410, step: 5, floor: 300, ceiling: 540)
    }

    private func analyticsPlaceholderSeries(base: Int, step: Int, floor: Int, ceiling: Int) -> [Date: Int] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return Dictionary(uniqueKeysWithValues: (0..<14).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let focusMinutes = coordinator.progress.record(for: day, calendar: calendar)?.completedFocusMinutes ?? 0
            let value = min(ceiling, max(floor, base + (offset * step) - (focusMinutes / 2)))
            return (day, value)
        })
    }

#if DEBUG
    private static func qaAnalyticsProgress(endingAt date: Date = Date(), calendar: Calendar = .current) -> UserProgress {
        let records = qaDailyFocusRecords(endingAt: date, calendar: calendar)
        let totalFocusMinutes = records.reduce(0) { $0 + $1.completedFocusMinutes }
        let totalCompletedRuns = records.reduce(0) { $0 + $1.successfulRuns }
        let rewardsCollected = records.reduce(0) { $0 + $1.rewardsEarned }

        return UserProgress(
            totalCompletedRuns: totalCompletedRuns,
            totalFocusMinutes: totalFocusMinutes,
            currentStreak: records.prefix { $0.completedFocusMinutes > 0 }.count,
            longestStreak: 11,
            rewardsCollected: rewardsCollected,
            ollieLevel: 3,
            dailyFocusRecords: records,
            sheepBalance: max(0, totalFocusMinutes / 15),
            coinBalance: max(0, totalFocusMinutes / 3),
            totalSheepEarned: max(0, totalFocusMinutes / 15),
            totalCoinsEarned: max(0, totalFocusMinutes / 3)
        )
    }

    private static func qaDailyFocusRecords(endingAt date: Date = Date(), calendar: Calendar = .current) -> [DailyFocusRecord] {
        let end = calendar.startOfDay(for: date)
        return (0..<30).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: end) else { return nil }
            let focusMinutes = qaFocusMinutes(forOffsetFromToday: offset)
            return DailyFocusRecord(
                day: day,
                completedFocusMinutes: focusMinutes,
                successfulRuns: focusMinutes == 0 ? 0 : max(1, focusMinutes / 35),
                warnings: offset.isMultiple(of: 6) ? 1 : 0,
                rewardsEarned: focusMinutes >= 25 ? 1 : 0
            )
        }
    }

    private static func qaManualAnalyticsEntries(endingAt date: Date = Date(), calendar: Calendar = .current) -> [ManualAnalyticsEntry] {
        let end = calendar.startOfDay(for: date)
        return (0..<30).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: end) else { return nil }
            let focusMinutes = qaFocusMinutes(forOffsetFromToday: offset)
            let screenTimeMinutes = min(420, max(95, 335 - focusMinutes + ((offset % 5) * 11)))
            let socialScreenTimeMinutes = min(screenTimeMinutes, max(15, 130 - (focusMinutes / 3) + ((offset % 4) * 9)))
            let bedtimeScreenTimeMinutes = min(screenTimeMinutes, max(0, 85 - (focusMinutes / 4) + ((offset % 5) * 6)))
            let sleepMinutes = min(540, max(300, 380 + (focusMinutes / 3) - ((offset % 4) * 8)))
            return ManualAnalyticsEntry(
                day: day,
                screenTimeMinutes: screenTimeMinutes,
                socialScreenTimeMinutes: socialScreenTimeMinutes,
                bedtimeScreenTimeMinutes: bedtimeScreenTimeMinutes,
                sleepMinutes: sleepMinutes,
                updatedAt: Date(),
                calendar: calendar
            )
        }
    }

    private static func qaFocusMinutes(forOffsetFromToday offset: Int) -> Int {
        let pattern = [0, 15, 25, 40, 60, 90, 120, 30, 75, 50]
        return pattern[offset % pattern.count]
    }
#endif
}
