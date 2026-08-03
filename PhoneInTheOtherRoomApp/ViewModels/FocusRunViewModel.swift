import Foundation
import Combine
import UserNotifications

#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
import FamilyControls
#endif

@MainActor
final class FocusRunViewModel: ObservableObject {
    @Published var nightWatchPreferences: NightWatchPreferences = .defaults
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
    @Published var isProvisioningNFCTag = false
    @Published var phoneBedTagRegistration: PhoneBedTagRegistration?
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

    init(coordinator: FocusSessionCoordinator? = nil) {
        let savedQuietTime = PersistenceService.shared.nightWatchPreferences
        let savedReportPreferences = PersistenceService.shared.screenTimeReportPreferences
        let initialReportPreferences = savedReportPreferences
            ?? ScreenTimeReportPreferences.defaults(for: savedQuietTime)
        if savedReportPreferences == nil {
            PersistenceService.shared.screenTimeReportPreferences = initialReportPreferences
        }
        self.coordinator = coordinator ?? FocusSessionCoordinator()
        impactSharingPreferences = PersistenceService.shared.impactSharingPreferences
        impactSharingAvailable = (try? SupabaseConfiguration.load()) != nil
        notificationPreferences = notifications.preferences
        nightWatchPreferences = savedQuietTime
        windDownRoutines = PersistenceService.shared.windDownRoutines
        nextWindDownOverride = PersistenceService.shared.nextWindDownOverride
        screenTimeReportPreferences = initialReportPreferences
        offlinePurpose = persistence.offlinePurpose
        morningCheckIns = persistence.morningCheckIns
        phoneBedTagRegistration = persistence.phoneBedNFCTagRegistration
        selectedGuardKind = nightWatchPreferences.guardKind
        self.coordinator.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        self.coordinator.optionalSheepSearchBonusProvider = { [weak self] in
            self?.optionalSheepSearchBonusPoints() ?? 0
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
    }

    var activeRun: FocusRun? { coordinator.run }
    var hasConfiguredNightWatch: Bool { nightWatchPreferences.isConfigured }
    var hasRegisteredNFCTag: Bool { registeredNFCDigest != nil }
    var canBeginNightWatchNow: Bool { nightWatchPreferences.isStartWindowOpen() }
    var hasSelectedShieldingApps: Bool {
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        return !bedtimeActivitySelection.phoneOtherIsEmpty
#else
        return false
#endif
    }
    var isRunning: Bool {
        guard let state = activeRun?.state else { return false }
        return ![.setup, .completed, .endedEarly].contains(state)
    }

    var sheepSearchState: SheepSearchState { coordinator.sheepSearchState }
    var latestSheepSearchOutcome: SheepSearchOutcome? { coordinator.latestSheepSearchOutcome }

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
        saveNightWatchPreferences()
        notifications.cancelNightWatchReminder()
        persistence.automaticWindDownSchedule = nil
        quietTimeShielding.cancelAutomaticSchedule()
        let startedAt = Date()
        let plan = makePlanForNextWindDown(startedAt: startedAt)
        coordinator.start(
            configuration: FocusRunConfiguration(nightWatchPlan: plan, guardKind: selectedGuardKind),
            focusAccepted: false
        )
        notifications.scheduleNightWatchNotifications(
            for: plan,
            startedAt: startedAt,
            purpose: offlinePurpose,
            seed: activeRun?.id ?? UUID(),
            preferences: notificationPreferences
        )
        usageMonitoring.schedule(for: plan, startedAt: startedAt)
        scheduleNextAutomaticWindDown(after: (activeRun?.plannedEndAt ?? startedAt).addingTimeInterval(60))
        if selectedGuardKind == .qrCode {
            showQRCodeScanner = true
        } else if selectedGuardKind == .nfcTag {
            scanNFCTag()
        }
        showFocusModePrompt = false
    }

    func saveWindDownRoutines() {
        persistence.windDownRoutines = windDownRoutines
    }

    @discardableResult
    func addAdditionalWindDown(title: String, start: WindDownClockTime, end: WindDownClockTime) -> Bool {
        let routine = WindDownRoutine(
            title: title,
            role: .additionalQuiet,
            start: start,
            end: end
        )
        let calendar = Calendar.current
        let existingOccurrences = windDownRoutines.flatMap { routine in
            (0...7).compactMap { offset -> WindDownOccurrence? in
                guard let day = calendar.date(byAdding: .day, value: offset, to: Date()) else { return nil }
                return WindDownScheduleEngine.occurrence(for: routine, on: day, calendar: calendar)
            }
        }
        let candidateOccurrences = existingOccurrences + (0...7).compactMap { offset -> WindDownOccurrence? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: Date()) else { return nil }
            return WindDownScheduleEngine.occurrence(for: routine, on: day, calendar: calendar)
        }
        guard (try? WindDownScheduleEngine.validateNoOverlaps(candidateOccurrences)) != nil else { return false }
        windDownRoutines.append(routine)
        saveWindDownRoutines()
        return true
    }

    func adjustNextWindDown(start: Date, end: Date, role: WindDownOccurrenceRole = .additionalQuiet) {
        guard end > start else { return }
        let routineID = windDownRoutines.first(where: { $0.role == role })?.id ?? UUID()
        let override = NextWindDownOverride(
            routineID: routineID,
            role: role,
            interval: DateInterval(start: start, end: end),
            expiresAt: end
        )
        nextWindDownOverride = override
        persistence.nextWindDownOverride = override
        scheduleAutomaticWindDownIfNeeded()
    }

    func clearNextWindDownOverride() {
        nextWindDownOverride = nil
        persistence.nextWindDownOverride = nil
        scheduleAutomaticWindDownIfNeeded()
    }

    private func makePlanForNextWindDown(startedAt: Date) -> NightWatchPlan {
        guard var override = nextWindDownOverride,
              override.isAvailable(at: startedAt) else {
            return nightWatchPreferences.makePlan(startedAt: startedAt)
        }
        _ = override.consume(at: startedAt)
        nextWindDownOverride = nil
        persistence.nextWindDownOverride = nil
        if override.role == .additionalQuiet {
            return NightWatchPlan.additionalQuiet(
                start: override.interval.start,
                end: override.interval.end,
                activity: nightWatchPreferences.eveningActivity
            )
        }
        let bedtime = override.interval.end
        let wakeComponents = DateComponents(hour: nightWatchPreferences.wakeHour, minute: nightWatchPreferences.wakeMinute)
        let calendar = Calendar.current
        let wake = calendar.nextDate(after: bedtime, matching: wakeComponents, matchingPolicy: .nextTime) ?? bedtime.addingTimeInterval(8 * 60 * 60)
        let protectedUntil = calendar.date(byAdding: .minute, value: nightWatchPreferences.morningQuietMinutes, to: wake) ?? wake.addingTimeInterval(30 * 60)
        return NightWatchPlan(
            intendedBedtime: bedtime,
            wakeTime: wake,
            protectedUntil: protectedUntil,
            windDownMinutes: max(15, Int(override.interval.duration / 60)),
            morningQuietMinutes: nightWatchPreferences.morningQuietMinutes,
            eveningActivity: nightWatchPreferences.eveningActivity,
            morningActivity: nightWatchPreferences.morningActivity,
            role: .primarySleepBookend
        )
    }

    func saveNightWatchPlanForTonight() {
        saveNightWatchPreferences()
        scheduleAutomaticWindDownIfNeeded()
    }

    func saveOnboardingDraft(_ draft: OnboardingDraft) {
        persistence.onboardingDraft = draft
    }

    func applyOnboardingDraft(_ draft: OnboardingDraft) {
        nightWatchPreferences = draft.makeNightWatchPreferences()
        offlinePurpose = draft.makeOfflinePurpose()
        selectedGuardKind = nightWatchPreferences.guardKind
        persistence.nightWatchPreferences = nightWatchPreferences
        persistence.offlinePurpose = offlinePurpose
        persistence.screenTimeReportPreferences = ScreenTimeReportPreferences.defaults(
            for: nightWatchPreferences
        )
        screenTimeReportPreferences = persistence.screenTimeReportPreferences
            ?? ScreenTimeReportPreferences.defaults(for: nightWatchPreferences)
        shieldingEnabled = draft.shieldingEnabled
        UserDefaults.standard.set(
            draft.shieldingEnabled,
            forKey: QuietTimeShieldingService.enabledKey
        )
        var updatedNotificationPreferences = draft.makeNotificationPreferences()
        updatedNotificationPreferences.usageAwareRemindersEnabled =
            draft.usageAwareRemindersEnabled && canUseUsageAwareReminders
        notificationPreferences = updatedNotificationPreferences
        notifications.preferences = updatedNotificationPreferences
        persistence.completeOnboarding()
        scheduleAutomaticWindDownIfNeeded()
    }

    func setRemindersEnabled(_ enabled: Bool) {
        var updated = notificationPreferences
        updated.remindersEnabled = enabled
        notificationPreferences = updated
        notifications.preferences = updated
        if enabled {
            scheduleAutomaticWindDownIfNeeded()
        } else {
            usageMonitoring.cancel()
        }
    }

    var canUseUsageAwareReminders: Bool {
        screenTimeAuthorization == .approved && hasSelectedShieldingApps
    }

    func updateNotificationPreferences(_ preferences: NotificationPreferences) {
        var updated = preferences
        updated.hasChosenCadence = true
        if !canUseUsageAwareReminders {
            updated.usageAwareRemindersEnabled = false
        }
        notificationPreferences = updated
        notifications.preferences = updated
        if updated.remindersEnabled {
            scheduleAutomaticWindDownIfNeeded()
            if let activeRun, let plan = activeRun.nightWatchPlan {
                usageMonitoring.schedule(for: plan, startedAt: activeRun.startedAt)
            }
        } else {
            usageMonitoring.cancel()
        }
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
        nightWatchPreferences.guardKind = selectedGuardKind
        nightWatchPreferences.isConfigured = true
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
        selectedGuardKind = kind
        nightWatchPreferences.guardKind = kind
        guard nightWatchPreferences.isConfigured else { return }
        persistence.nightWatchPreferences = nightWatchPreferences
        scheduleAutomaticWindDownIfNeeded()
    }

    func setAutomaticStartEnabled(_ enabled: Bool) {
        nightWatchPreferences.automaticStartEnabled = enabled
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
            qrCodeStatus = "Ollie saved this as your phone bed."
        }
        if coordinator.confirmQRCode(normalizedCode, expectedCode: persistence.phoneBedQRCode) {
            showQRCodeScanner = false
            qrCodeStatus = ""
        } else {
            qrCodeStatus = "That code belongs somewhere else. Try the code by your phone's resting place."
        }
    }

    func scanNFCTag() {
        nfcStatus = ""
        guard registeredNFCDigest != nil else {
            nfcStatus = "Set up this phone-bed tag first, or continue without a placement check."
            return
        }
        phoneBedNFCService.scan { [weak self] result in
            guard let self else { return }
            switch result {
            case .read(let read):
                let expectedDigest = self.registeredNFCDigest
                if self.coordinator.confirmNFCTag(
                    read.digest,
                    expectedFingerprint: expectedDigest
                ) {
                    if var registration = self.phoneBedTagRegistration {
                        registration.lastVerifiedAt = Date()
                        self.phoneBedTagRegistration = registration
                        self.persistence.phoneBedNFCTagRegistration = registration
                    }
                    self.nfcStatus = "Ollie found the phone bed."
                } else {
                    self.nfcStatus = "That is not Ollie's phone-bed tag. Try the tag by the phone's resting place."
                }
            case .cancelled:
                self.nfcStatus = "The tag can wait. Try again, or continue without a placement check."
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
                    self.nfcStatus = "That is not Ollie's phone-bed tag. Wind Down is still running."
                    return
                }
                if var registration = self.phoneBedTagRegistration {
                    registration.lastVerifiedAt = Date()
                    self.phoneBedTagRegistration = registration
                    self.persistence.phoneBedNFCTagRegistration = registration
                }
                self.nfcStatus = "Phone-bed tag confirmed."
                self.cancelActiveRunNotifications()
                self.coordinator.endEarly(reason: .nfcTagAuthenticated)
            case .cancelled:
                self.nfcStatus = "No tag was read. Wind Down is still running."
            case .unavailable(let message):
                self.nfcStatus = message
            }
        }
    }

    func emergencyEndWindDown() {
        cancelActiveRunNotifications()
        coordinator.endEarly(reason: .emergencyBypass)
    }

    func endWindDownEarly() {
        cancelActiveRunNotifications()
        coordinator.endEarly()
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
                    self.nfcStatus = "Ollie saved this as your phone bed."
                }
            case .cancelled:
                self.nfcStatus = forActiveRun
                    ? "No changes made. Wind Down is still running with your current tag."
                    : "No changes made. Your current phone-bed tag is still ready."
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
              nightWatchPreferences.automaticStartEnabled,
              let schedule = persistence.automaticWindDownSchedule else {
            return
        }

        let now = Date()
        guard now >= schedule.startedAt else {
            if shieldingEnabled {
                quietTimeShielding.scheduleAutomatic(for: schedule, at: now)
            }
            return
        }

        guard now < schedule.plan.protectedUntil else {
            notifications.cancelNightWatchReminder()
            persistence.automaticWindDownSchedule = nil
            if let override = nextWindDownOverride, override.expiresAt <= now {
                nextWindDownOverride = nil
                persistence.nextWindDownOverride = nil
            }
            coordinator.reconcileExpiredAutomaticNightWatch(
                plan: schedule.plan,
                guardKind: nightWatchPreferences.guardKind,
                startedAt: schedule.startedAt,
                endedAt: schedule.plan.protectedUntil
            )
            scheduleNextAutomaticWindDown()
            return
        }

        notifications.cancelNightWatchReminder()
        if let override = nextWindDownOverride,
           override.interval.start == schedule.startedAt {
            nextWindDownOverride = nil
            persistence.nextWindDownOverride = nil
        }
        coordinator.start(
            configuration: FocusRunConfiguration(
                nightWatchPlan: schedule.plan,
                guardKind: nightWatchPreferences.guardKind
            ),
            focusAccepted: false,
            startedAt: schedule.startedAt,
            autoConfirmPlacement: true
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
              nightWatchPreferences.automaticStartEnabled else {
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
            return
        }
        scheduleNextAutomaticWindDown()
    }

    private func scheduleNextAutomaticWindDown(after date: Date = Date()) {
        if let override = nextWindDownOverride, override.isAvailable(at: date) {
            let plan: NightWatchPlan
            if override.role == .additionalQuiet {
                plan = NightWatchPlan.additionalQuiet(
                    start: override.interval.start,
                    end: override.interval.end,
                    activity: nightWatchPreferences.eveningActivity
                )
            } else {
                let calendar = Calendar.current
                let bedtime = override.interval.end
                let wakeComponents = DateComponents(hour: nightWatchPreferences.wakeHour, minute: nightWatchPreferences.wakeMinute)
                let wake = calendar.nextDate(after: bedtime, matching: wakeComponents, matchingPolicy: .nextTime) ?? bedtime.addingTimeInterval(8 * 60 * 60)
                let protectedUntil = calendar.date(byAdding: .minute, value: nightWatchPreferences.morningQuietMinutes, to: wake) ?? wake.addingTimeInterval(30 * 60)
                plan = NightWatchPlan(
                    intendedBedtime: bedtime,
                    wakeTime: wake,
                    protectedUntil: protectedUntil,
                    windDownMinutes: max(15, Int(override.interval.duration / 60)),
                    morningQuietMinutes: nightWatchPreferences.morningQuietMinutes,
                    eveningActivity: nightWatchPreferences.eveningActivity,
                    morningActivity: nightWatchPreferences.morningActivity
                )
            }
            let schedule = AutomaticWindDownSchedule(startedAt: override.interval.start, plan: plan)
            persistence.automaticWindDownSchedule = schedule
            notifications.cancelNightWatchReminder()
            notifications.scheduleAutomaticWindDownNotifications(
                at: schedule.startedAt,
                plan: plan,
                purpose: offlinePurpose,
                seed: schedule.id,
                preferences: notificationPreferences
            )
            usageMonitoring.schedule(
                for: plan,
                startedAt: schedule.startedAt,
                repeatsDaily: false
            )
            if shieldingEnabled && plan.role == .primarySleepBookend {
                quietTimeShielding.scheduleAutomatic(for: schedule)
            }
            return
        }
        let routines = windDownRoutines.isEmpty
            ? [WindDownRoutine.primary(from: nightWatchPreferences)]
            : windDownRoutines
        let next = routines
            .filter { $0.automaticStartEnabled }
            .compactMap { routine -> WindDownOccurrence? in
                guard let occurrence = WindDownScheduleEngine.nextOccurrence(for: routine, after: date) else {
                    return nil
                }
                if occurrence.interval.start > date {
                    return occurrence
                }
                return WindDownScheduleEngine.nextOccurrence(
                    for: routine,
                    after: occurrence.interval.end.addingTimeInterval(1)
                )
            }
            .min { $0.interval.start < $1.interval.start }
        let startDate = next?.interval.start ?? nightWatchPreferences.nextStart(after: date)
        let plan: NightWatchPlan
        if let next, next.role == .additionalQuiet {
            plan = NightWatchPlan.additionalQuiet(
                start: next.interval.start,
                end: next.interval.end,
                activity: nightWatchPreferences.eveningActivity
            )
        } else {
            plan = nightWatchPreferences.makePlan(startedAt: startDate)
        }
        let schedule = AutomaticWindDownSchedule(startedAt: startDate, plan: plan)
        persistence.automaticWindDownSchedule = schedule
        notifications.cancelNightWatchReminder()
        notifications.scheduleAutomaticWindDownNotifications(
            at: startDate,
            plan: plan,
            purpose: offlinePurpose,
            seed: schedule.id,
            preferences: notificationPreferences
        )
        usageMonitoring.schedule(for: plan, startedAt: startDate, repeatsDaily: plan.role == .primarySleepBookend)
        if shieldingEnabled && plan.role == .primarySleepBookend {
            quietTimeShielding.scheduleAutomatic(for: schedule)
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
        }
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
        morningCheckIns.entry(for: Date()) ?? MorningCheckIn(
            day: Date(),
            sleepOnset: nil,
            restfulness: nil,
            bedtimeSleepiness: nil
        )
    }

    func updateMorningSleepOnset(_ value: SleepOnsetEstimate?) {
        var entry = todayMorningCheckIn
        entry.sleepOnset = value
        saveMorningCheckIn(entry)
    }

    func updateMorningRestfulness(_ value: MorningRestfulness?) {
        var entry = todayMorningCheckIn
        entry.restfulness = value
        saveMorningCheckIn(entry)
    }

    func updateBedtimeSleepiness(_ value: BedtimeSleepiness?) {
        var entry = todayMorningCheckIn
        entry.bedtimeSleepiness = value
        saveMorningCheckIn(entry)
    }

    private func loadRecentSleepSummaries() async {
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
