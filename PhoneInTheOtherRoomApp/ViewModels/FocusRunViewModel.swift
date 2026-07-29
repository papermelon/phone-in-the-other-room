import Foundation
import Combine

#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
import FamilyControls
#endif

@MainActor
final class FocusRunViewModel: ObservableObject {
    @Published var nightWatchPreferences: NightWatchPreferences = .defaults
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
#if DEBUG
    @Published var useAnalyticsQADataset = false
#endif
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
    @Published var distractingActivitySelection = FamilyActivitySelection()
    @Published var productiveActivitySelection = FamilyActivitySelection()
    @Published var bedtimeActivitySelection = FamilyActivitySelection()
#endif

    @Published var coordinator: FocusSessionCoordinator
    @Published var selectedGuardKind: SessionGuardKind = .honorTimer
    @Published var showQRCodeScanner = false
    @Published var qrCodeStatus = ""
    @Published var nfcStatus = ""
#if DEBUG
    @Published var shieldingEnabled = UserDefaults.standard.bool(
        forKey: QuietTimeShieldingService.enabledKey
    )
#endif

    private let focusService = FocusModeSuggestionService()
    private let notifications = PhoneNotificationService.shared
    private let persistence = PersistenceService.shared
    private let screenTimeService = ScreenTimeAuthorizationService()
    private let healthSleepService = HealthSleepService()
    private let phoneBedNFCService = PhoneBedNFCService()
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
        nightWatchPreferences = savedQuietTime
        screenTimeReportPreferences = initialReportPreferences
        offlinePurpose = persistence.offlinePurpose
        morningCheckIns = persistence.morningCheckIns
        selectedGuardKind = nightWatchPreferences.guardKind
        self.coordinator.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        screenTimeAuthorization = screenTimeService.currentState()
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
        if sleepAuthorization == .requested {
            refreshSleepSummary()
        }
    }

    var activeRun: FocusRun? { coordinator.run }
    var hasConfiguredNightWatch: Bool { nightWatchPreferences.isConfigured }
    var canBeginNightWatchNow: Bool { nightWatchPreferences.isStartWindowOpen() }
    var isRunning: Bool {
        guard let state = activeRun?.state else { return false }
        return ![.setup, .completed, .endedEarly].contains(state)
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
        focusGuidance = "A legacy Shortcut prepared \(selectedDurationLabel) of phone-away time. Your saved quiet time remains the main bedtime ritual."
    }

    func requestStartRun() {
        updateSelectedDuration()
        showFocusModePrompt = true
    }

    func requestStartNightWatch() {
        saveNightWatchPreferences()
        notifications.cancelNightWatchReminder()
        let startedAt = Date()
        let plan = nightWatchPreferences.makePlan(startedAt: startedAt)
        coordinator.start(
            configuration: FocusRunConfiguration(nightWatchPlan: plan, guardKind: selectedGuardKind),
            focusAccepted: false
        )
        if let activeRun {
            notifications.scheduleNightWatchTransitions(for: activeRun, purpose: offlinePurpose)
        }
        if let plannedEndAt = activeRun?.plannedEndAt {
            notifications.scheduleNightWatchReminder(
                at: nightWatchPreferences.nextStart(after: plannedEndAt.addingTimeInterval(60)),
                purpose: offlinePurpose
            )
        }
        if selectedGuardKind == .qrCode {
            showQRCodeScanner = true
        } else if selectedGuardKind == .nfcTag {
            scanNFCTag()
        }
        showFocusModePrompt = false
    }

    func saveNightWatchPlanForTonight() {
        saveNightWatchPreferences()
        notifications.cancelNightWatchReminder()
        notifications.scheduleNightWatchReminder(
            at: nightWatchPreferences.nextStart(),
            purpose: offlinePurpose
        )
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
    }

    func saveQuietTimeDurations() {
        saveNightWatchPreferences()
        notifications.cancelNightWatchReminder()
        notifications.scheduleNightWatchReminder(
            at: nightWatchPreferences.nextStart(),
            purpose: offlinePurpose
        )
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
        notifications.scheduleRunCompletion(at: activeRun?.plannedEndAt)
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
        phoneBedNFCService.scan { [weak self] result in
            guard let self else { return }
            switch result {
            case .read(let fingerprint):
                if self.persistence.phoneBedNFCTag == nil {
                    self.persistence.phoneBedNFCTag = fingerprint
                }
                if self.coordinator.confirmNFCTag(
                    fingerprint,
                    expectedFingerprint: self.persistence.phoneBedNFCTag
                ) {
                    self.nfcStatus = "Ollie found the phone bed."
                } else {
                    self.nfcStatus = "That is not Ollie's phone-bed tag. Try the tag by the phone's resting place."
                }
            case .unavailable(let message):
                self.nfcStatus = message
            }
        }
    }

#if DEBUG
    func setShieldingEnabled(_ enabled: Bool) {
        shieldingEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: QuietTimeShieldingService.enabledKey)
        if enabled {
            coordinator.reconcileSession()
        } else {
            QuietTimeShieldingService().clear()
        }
    }
#endif

    func resetSetup() {
        coordinator.resetToSetup()
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

    func connectScreenTime() {
        Task { @MainActor in
            screenTimeAuthorization = await screenTimeService.requestAuthorization()
        }
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
        recentNightSleeps = await healthSleepService.recentNightSleeps(days: 7)
        let calendar = Calendar.current
        lastNightSleep = recentNightSleeps.first { summary in
            guard let nightEndingDate = summary.nightEndingDate else { return false }
            return calendar.isDate(nightEndingDate, inSameDayAs: Date())
        }
    }

    private func saveMorningCheckIn(_ entry: MorningCheckIn) {
        morningCheckIns.upsert(entry)
        persistence.morningCheckIns = morningCheckIns
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
