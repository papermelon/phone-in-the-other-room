import Foundation
import Combine
import UserNotifications

#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
import FamilyControls
#endif

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
    @Published var shieldingPreflightMessage: String?
    @Published var liveActivityEnabled = FocusRunLiveActivityService.preferenceEnabled
    @Published var showNightWatchStartPrompt = false
    @Published var liveActivityChoiceForNextRun = FocusRunLiveActivityService.preferenceEnabled
    @Published var nightWatchStartStatus = ""
    @Published var isScanningNFCForStart = false
    @Published var quietAppearanceEnabled = UserDefaults.standard.bool(forKey: "ollie.quietAppearance.enabled")
    @Published var isProvisioningNFCTag = false
    @Published var phoneBedTagRegistration: PhoneBedTagRegistration?
    @Published var orientationState: CountingSheepOrientationState
    /// Ephemeral navigation intent used by the orientation card; it is not
    /// persisted and does not change the meaning of any recorded night.
    @Published var nightsRecordFocusID: UUID?
    @Published var shieldingEnabled = UserDefaults.standard.bool(
        forKey: QuietTimeShieldingService.enabledKey
    )

    private let focusService = FocusModeSuggestionService()
    private let notifications = PhoneNotificationService.shared
    private let persistence = PersistenceService.shared
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
    private var nightWatchStartInFlight = false

    init(coordinator: FocusSessionCoordinator? = nil) {
        let savedQuietTime = PersistenceService.shared.nightWatchPreferences
        let savedSchedule = PersistenceService.shared.windDownSchedule
        let savedReportPreferences = PersistenceService.shared.screenTimeReportPreferences
        let initialReportPreferences = savedReportPreferences
            ?? ScreenTimeReportPreferences.defaults(for: savedQuietTime)
        if savedReportPreferences == nil {
            PersistenceService.shared.screenTimeReportPreferences = initialReportPreferences
        }
        self.coordinator = coordinator ?? FocusSessionCoordinator()
        impactSharingPreferences = PersistenceService.shared.impactSharingPreferences
        orientationState = PersistenceService.shared.orientationState
        nightsRecordFocusID = nil
        impactSharingAvailable = (try? SupabaseConfiguration.load()) != nil
        notificationPreferences = notifications.preferences
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
        phoneBedTagRegistration = persistence.phoneBedNFCTagRegistration
        selectedGuardKind = normalizedQuietTime.guardKind
        if normalizedQuietTime.guardKind != savedQuietTime.guardKind {
            PersistenceService.shared.nightWatchPreferences = normalizedQuietTime
        }
        self.coordinator.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        self.coordinator.optionalSheepSearchBonusProvider = { [weak self] in
            self?.optionalSheepSearchBonusPoints() ?? 0
        }
        self.coordinator.onRunFinished = { [weak self] in
            guard let self else { return }
            self.reconcileOrientationAfterRun()
            self.scheduleAutomaticWindDownIfNeeded()
        }
        screenTimeAuthorization = screenTimeService.currentState()
        Task { @MainActor in
            notificationAuthorization = await notifications.authorizationStatus()
        }
        sleepAuthorization = healthSleepService.isAvailable
            ? (healthSleepService.hasRequestedAccess ? .requested : .notRequested)
            : .unavailable
        manualAnalyticsEntries = persistence.manualAnalyticsEntries
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        distractingActivitySelection = screenTimeSelectionService.load(.distracting)
        productiveActivitySelection = screenTimeSelectionService.load(.productive)
        bedtimeActivitySelection = screenTimeSelectionService.load(.bedtime)
#endif
        applyShortcutPreparationIfNeeded()
        reconcileAutomaticWindDownIfNeeded()
        if sleepAuthorization == .requested {
            refreshSleepSummary()
        }
        reconcileOrientationAfterRun()
    }

    var activeRun: FocusRun? { coordinator.run }
    var hasConfiguredNightWatch: Bool { nightWatchPreferences.isConfigured }
    var hasRegisteredNFCTag: Bool { registeredNFCDigest != nil }
    var canBeginNightWatchNow: Bool {
        nightWatchPreferences.isStartWindowOpen()
            || WindDownScheduleEngine.eligibleOccurrence(
                in: windDownSchedule,
                at: Date(),
                primaryExtensionMinutes: nightWatchPreferences.morningQuietMinutes
            ) != nil
    }
    var upcomingQuietPeriods: [WindDownSchedulePeriod] {
        windDownSchedule.upcomingPeriods(
            after: Date(),
            primaryExtensionMinutes: nightWatchPreferences.morningQuietMinutes,
            limit: 64
        )
    }
    var nextUpcomingQuietPeriod: WindDownSchedulePeriod? { upcomingQuietPeriods.first }
    var upcomingAdditionalQuietPeriods: [WindDownSchedulePeriod] {
        upcomingQuietPeriods.filter { $0.occurrence.role == .additionalQuiet }
    }
    var nextUpcomingAdditionalQuietPeriod: WindDownSchedulePeriod? {
        upcomingAdditionalQuietPeriods.first
    }
    var readyOneTimeQuietPeriodID: UUID? {
        WindDownScheduleEngine.eligibleOccurrence(
            in: windDownSchedule,
            at: Date(),
            primaryExtensionMinutes: nightWatchPreferences.morningQuietMinutes
        )?.sourceID
    }
    var hasSelectedShieldingApps: Bool {
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        return !bedtimeActivitySelection.phoneOtherIsEmpty
#else
        return false
#endif
    }
    var shieldingReadiness: ShieldingReadiness {
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        switch screenTimeAuthorization {
        case .approved:
            return hasSelectedShieldingApps ? .ready : .noSelection
        case .notDetermined: return .authorizationRequired
        case .denied: return .denied
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

    var isOrientationActive: Bool { orientationState.isVisibleOnHome }

    var pendingNightWatchIsAdditionalQuiet: Bool {
        pendingNightWatchPlan?.role == .additionalQuiet
    }

    var pendingNightWatchEndsAt: Date? {
        pendingNightWatchPlan?.protectedUntil
    }

    var pendingNightWatchTitle: String? {
        guard let sourceID = pendingNightWatchSourceOccurrenceID else { return nil }
        return WindDownScheduleEngine.eligibleOccurrence(
            in: windDownSchedule,
            at: Date(),
            primaryExtensionMinutes: nightWatchPreferences.morningQuietMinutes
        ).flatMap { $0.sourceID == sourceID ? $0.title : nil }
    }

    var willShieldPendingNightWatch: Bool {
        shieldingEnabled && shieldingReadiness == .ready
    }

    func markOrientation(_ milestone: CountingSheepOrientationMilestone) {
        orientationState.mark(milestone)
        persistence.orientationState = orientationState
    }

    func dismissOrientation() {
        orientationState.dismiss()
        persistence.orientationState = orientationState
    }

    func resumeOrientation() {
        orientationState.resume()
        persistence.orientationState = orientationState
    }

    func skipOrientationPermanently() {
        orientationState.skipPermanently()
        persistence.orientationState = orientationState
    }

    func replayOrientation() {
        orientationState.replay()
        persistence.orientationState = orientationState
    }

    @discardableResult
    func startOrientationPractice() -> Bool {
        guard !isRunning, activeRun == nil else { return false }
        let now = Date()

        // A person may cancel the normal start confirmation or return after a
        // preflight issue. Reuse the still-valid practice period instead of
        // leaving an unstartable duplicate in the finite schedule.
        if let existingID = orientationState.practicePeriodID,
           let existing = windDownSchedule.oneTimePeriods.first(where: { $0.id == existingID }) {
            if existing.isEligible(at: now) {
                requestStartNightWatch()
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
        requestStartNightWatch()
        return showNightWatchStartPrompt
    }

    private func reconcileOrientationAfterRun() {
        guard let run = activeRun,
              let practiceRunID = orientationState.practiceRunID,
              run.id == practiceRunID,
              run.completedSuccessfully else { return }
        markOrientation(.practiceCompleted)
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

    /// Reads the terminal field note by its persisted run identity. The search
    /// engine resolves outcomes in the coordinator; terminal views only reveal
    /// the saved record and never calculate a new one.
    func sheepSearchOutcome(for runID: UUID) -> SheepSearchOutcome? {
        persistence.sheepSearchState.outcomes.first { $0.runID == runID }
    }

    func setSheepSearchExactOddsEnabled(_ enabled: Bool) {
        var state = coordinator.sheepSearchState
        state.showExactOdds = enabled
        coordinator.sheepSearchState = state
        persistence.sheepSearchState = state
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
        updateSelectedDuration()
        showFocusModePrompt = true
    }

    func requestStartNightWatch() {
        guard WindDownStartGate.canPresentPreflight(
            isRunning: isRunning,
            startInFlight: nightWatchStartInFlight
        ) else { return }
        if shieldingEnabled && shieldingReadiness != .ready {
            shieldingPreflightMessage = shieldingReadiness.detail
            return
        }
        saveNightWatchPreferences()
        let requestedAt = Date()
        pendingNightWatchSourceOccurrenceID = WindDownScheduleEngine.eligibleOccurrence(
            in: windDownSchedule,
            at: requestedAt,
            primaryExtensionMinutes: nightWatchPreferences.morningQuietMinutes
        )?.sourceID
        pendingNightWatchPlan = makePlanForNextWindDown(startedAt: requestedAt)
        liveActivityChoiceForNextRun = liveActivityEnabled
        nightWatchStartStatus = ""
        showNightWatchStartPrompt = true
    }

    func cancelNightWatchStart() {
        guard !nightWatchStartInFlight else { return }
        isScanningNFCForStart = false
        pendingNightWatchPlan = nil
        pendingNightWatchSourceOccurrenceID = nil
        nightWatchStartStatus = ""
        showNightWatchStartPrompt = false
    }

    func confirmNightWatchStart() {
        guard pendingNightWatchPlan != nil, !nightWatchStartInFlight else { return }
        if selectedGuardKind == .nfcTag {
            scanNFCTag()
        } else {
            startPendingNightWatch()
        }
    }

    private func startPendingNightWatch() {
        guard let requestedPlan = pendingNightWatchPlan, !nightWatchStartInFlight else { return }
        nightWatchStartInFlight = true
        let startedAt = Date()
        let plan: NightWatchPlan
        if let sourceID = pendingNightWatchSourceOccurrenceID {
            guard let eligible = WindDownScheduleEngine.eligibleOccurrence(
                in: windDownSchedule,
                at: startedAt,
                primaryExtensionMinutes: nightWatchPreferences.morningQuietMinutes
            ), eligible.sourceID == sourceID else {
                nightWatchStartInFlight = false
                nightWatchStartStatus = "That quiet window has passed or is too short to start now."
                nfcStatus = nightWatchStartStatus
                return
            }
            plan = makePlanForNextWindDown(startedAt: startedAt)
        } else {
            plan = requestedPlan
        }
        let liveActivityRequested = liveActivityChoiceForNextRun
        liveActivityEnabled = liveActivityRequested
        UserDefaults.standard.set(
            liveActivityRequested,
            forKey: FocusRunLiveActivityService.preferenceKey
        )
        let sourceID = pendingNightWatchSourceOccurrenceID
        pendingNightWatchPlan = nil
        pendingNightWatchSourceOccurrenceID = nil
        showNightWatchStartPrompt = false
        notifications.cancelNightWatchReminder()
        persistence.automaticWindDownSchedule = nil
        quietTimeShielding.cancelAutomaticSchedule()
        coordinator.start(
            configuration: FocusRunConfiguration(nightWatchPlan: plan, guardKind: selectedGuardKind),
            focusAccepted: false,
            startedAt: startedAt,
            autoConfirmPlacement: selectedGuardKind == .nfcTag,
            liveActivityRequested: liveActivityRequested
        )
        if let sourceID,
           sourceID == orientationState.practicePeriodID,
           let runID = activeRun?.id {
            orientationState.recordPracticeRun(runID)
            persistence.orientationState = orientationState
        }
        consumeScheduledOccurrence(sourceID)
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
            windDownScheduleError = "Choose at least one day for this repeating quiet time."
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
        windDownSchedule.oneTimePeriods.removeAll { $0.id == id }
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
                windDownScheduleError = "Choose at least one day for this repeating quiet time."
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
                windDownScheduleError = "Choose at least one day for this repeating quiet time."
            }
            return false
        } catch {
            windDownScheduleError = "Choose a future quiet window that does not overlap another period."
            return false
        }
    }

    private func scheduleTitle(for id: UUID, in schedule: WindDownScheduleState) -> String {
        if let period = schedule.oneTimePeriods.first(where: { $0.id == id }) {
            return period.title
        }
        if let routine = schedule.routines.first(where: { $0.id == id }) {
            return routine.title
        }
        return "Quiet time"
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
            title: role == .primarySleepBookend ? "Adjusted Wind Down" : "One-time quiet period",
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
        preserveAdvancedNotifications: Bool = false
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
        shieldingEnabled = draft.shieldingEnabled && shieldingReadiness == .ready
        UserDefaults.standard.set(
            shieldingEnabled,
            forKey: QuietTimeShieldingService.enabledKey
        )
        var updatedNotificationPreferences = preserveAdvancedNotifications
            ? notificationPreferences
            : draft.makeNotificationPreferences()
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
        shieldingEnabled = shieldingReadiness == .ready
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
            updateOfflinePurpose(
                category: normalized == nil ? offlinePurpose.category : .custom,
                customText: normalized,
                allowsCustomTextInNotifications: offlinePurpose.allowsCustomTextInNotifications
            )
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
            qrCodeStatus = "Ollie could not read that code. Try again."
            return
        }
        if persistence.phoneBedQRCode == nil {
            persistence.phoneBedQRCode = normalizedCode
            qrCodeStatus = "Wind Down code saved."
        }
        if coordinator.confirmQRCode(normalizedCode, expectedCode: persistence.phoneBedQRCode) {
            showQRCodeScanner = false
            qrCodeStatus = ""
        } else {
            qrCodeStatus = "That is not your Wind Down code. Try again."
        }
    }

    func scanNFCTag() {
        nfcStatus = ""
        guard registeredNFCDigest != nil else {
            nfcStatus = "Set up a Wind Down tag in Settings before starting with NFC."
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
        phoneBedNFCService.scan { [weak self] result in
            guard let self else { return }
            self.isScanningNFCForStart = false
            switch result {
            case .read(let read):
                let expectedDigest = self.registeredNFCDigest
                if self.pendingNightWatchPlan != nil,
                   self.activeRun == nil {
                    guard read.digest == expectedDigest else {
                        self.nfcStatus = "That is not your Wind Down tag. The session has not started."
                        return
                    }
                    if var registration = self.phoneBedTagRegistration {
                        registration.lastVerifiedAt = Date()
                        self.phoneBedTagRegistration = registration
                        self.persistence.phoneBedNFCTagRegistration = registration
                    }
                    self.nfcStatus = "Wind Down is starting."
                    self.startPendingNightWatch()
                    return
                }
                if self.coordinator.confirmNFCTag(
                    read.digest,
                    expectedFingerprint: expectedDigest
                ) {
                    if var registration = self.phoneBedTagRegistration {
                        registration.lastVerifiedAt = Date()
                        self.phoneBedTagRegistration = registration
                        self.persistence.phoneBedNFCTagRegistration = registration
                    }
                    self.nfcStatus = "Wind Down tag confirmed."
                } else {
                    self.nfcStatus = "That is not your Wind Down tag. Wind Down is still running."
                }
            case .cancelled:
                self.nfcStatus = self.pendingNightWatchPlan != nil
                    ? "No tag was read. Wind Down has not started."
                    : "No tag was read. Wind Down is still running."
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
        guard let expectedDigest = registeredNFCDigest else {
            nfcStatus = "The saved tag is missing. Use the emergency exit if you need your apps now."
            return
        }
        phoneBedNFCService.scan { [weak self] result in
            guard let self else { return }
            switch result {
            case .read(let read):
                let matchesRegisteredTag = self.phoneBedTagRegistration?
                    .matches(scannedDigest: read.digest)
                    ?? (read.digest == expectedDigest)
                guard matchesRegisteredTag else {
                    self.nfcStatus = "That is not your Wind Down tag. Wind Down is still running."
                    return
                }
                if var registration = self.phoneBedTagRegistration {
                    registration.lastVerifiedAt = Date()
                    self.phoneBedTagRegistration = registration
                    self.persistence.phoneBedNFCTagRegistration = registration
                }
                self.nfcStatus = "Wind Down tag confirmed. Apps to rest can now be limited."
                self.prepareForEarlyWindDownExit()
                self.coordinator.endEarly(reason: .nfcTagAuthenticated)
            case .cancelled:
                self.nfcStatus = "No tag was read. Wind Down is still running."
            case .unavailable(let message):
                self.nfcStatus = message
            }
        }
    }

    func emergencyEndWindDown() {
        prepareForEarlyWindDownExit()
        coordinator.endEarly(reason: .emergencyBypass)
    }

    func endWindDownEarly() {
        prepareForEarlyWindDownExit()
        coordinator.endEarly()
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

    /// Writes and registers a new tag. When called from an active NFC Wind Down,
    /// the current run is kept and the new tag becomes its replacement guard.
    func provisionNFCTag(forActiveRun: Bool = false) {
        isProvisioningNFCTag = true
        nfcStatus = ""
        phoneBedNFCService.provision { [weak self] result in
            guard let self else { return }
            self.isProvisioningNFCTag = false
            switch result {
            case .registered(let registration):
                self.phoneBedTagRegistration = registration
                self.persistence.phoneBedNFCTagRegistration = registration
                self.persistence.phoneBedNFCTag = nil
                if !forActiveRun {
                    self.scheduleAutomaticWindDownIfNeeded()
                }
                if forActiveRun, self.activeRun?.guardKind == .nfcTag {
                    if self.activeRun?.placementStatus == .awaitingConfirmation {
                        _ = self.coordinator.confirmNFCTag(
                            registration.tokenDigest,
                            expectedFingerprint: registration.tokenDigest
                        )
                        self.nfcStatus = "New tag paired. Wind Down is starting."
                    } else {
                        self.nfcStatus = "New tag paired. Tap it again to end Wind Down."
                    }
                } else {
                    self.nfcStatus = "Wind Down tag saved."
                }
            case .cancelled:
                self.nfcStatus = forActiveRun
                    ? "No changes made. Wind Down is still running with your current tag."
                    : "No changes made. Your current Wind Down tag is still ready."
            case .unavailable(let message):
                self.nfcStatus = message
            }
        }
    }

    func resetNFCTag() {
        persistence.resetPhoneBedNFCTag()
        phoneBedTagRegistration = nil
        nfcStatus = "The old tag has been forgotten. Set up a new one whenever you are ready."
        scheduleAutomaticWindDownIfNeeded()
    }

    private var registeredNFCDigest: String? {
        phoneBedTagRegistration?.tokenDigest ?? persistence.phoneBedNFCTag
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
            quietTimeShielding.clear()
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
            if shieldingEnabled {
                quietTimeShielding.scheduleAutomatic(for: schedule, at: now)
            }
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
        guard !isRunning else { return }
        guard nightWatchPreferences.isConfigured,
              hasAutomaticWindDownRoutine else {
            persistence.automaticWindDownSchedule = nil
            notifications.cancelNightWatchReminder()
            quietTimeShielding.cancelAutomaticSchedule()
            usageMonitoring.cancel()
            return
        }
        guard selectedGuardKind != .nfcTag || hasRegisteredNFCTag else {
            persistence.automaticWindDownSchedule = nil
            notifications.cancelNightWatchReminder()
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
            sourceOccurrenceID: next?.sourceID
        )
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
        if shieldingEnabled && plan.role == .primarySleepBookend {
            quietTimeShielding.scheduleAutomatic(for: schedule)
        }
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
    }

    func resetLocalProgress() {
        resetSetup()
        notifications.cancelAllNightWatchNotifications()
        usageMonitoring.cancel()
        persistence.automaticWindDownSchedule = nil
        quietTimeShielding.cancelAutomaticSchedule()

        persistence.resetLocalProgress()
        coordinator.progress = .empty
        coordinator.rewards = []
        coordinator.sheepSearchState = .empty
        coordinator.latestSheepSearchOutcome = nil
        coordinator.events = []
        morningCheckIns = persistence.morningCheckIns
        manualAnalyticsEntries = persistence.manualAnalyticsEntries
        analyticsExportURL = nil
        analyticsExportError = nil
        impactDataSyncState = .idle

        // Keep the saved bedtime plan, but rebuild its next requested reminder if
        // automatic Wind Down was enabled before the reset.
        scheduleAutomaticWindDownIfNeeded()
    }

    func connectScreenTime() {
        Task { @MainActor in
            screenTimeAuthorization = await screenTimeService.requestAuthorization()
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
            if screenTimeAuthorization == .approved {
                bedtimeActivitySelection = screenTimeSelectionService.load(.bedtime)
            }
#endif
        }
    }

    func setLiveActivityEnabled(_ enabled: Bool) {
        liveActivityEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: FocusRunLiveActivityService.preferenceKey)
        coordinator.setLiveActivityEnabled(enabled)
    }

    func setQuietAppearanceEnabled(_ enabled: Bool) {
        quietAppearanceEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "ollie.quietAppearance.enabled")
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
        FocusAnalyticsEngine.exportPackage(records: analyticsRecords, privacyMode: analyticsExportPrivacyMode)
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
