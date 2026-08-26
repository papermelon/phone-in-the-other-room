import Foundation

enum OnboardingProtectionChoice: String, Codable, CaseIterable, Identifiable {
    case appShielding
    case nfcAndAppShielding

    var id: String { rawValue }

    var guardKind: SessionGuardKind {
        switch self {
        case .appShielding: return .honorTimer
        case .nfcAndAppShielding: return .nfcTag
        }
    }

    var title: String {
        switch self {
        case .appShielding: return "App limits"
        case .nfcAndAppShielding: return "NFC + app limits"
        }
    }

    var detail: String {
        switch self {
        case .appShielding:
            return "Choose apps to pause for Wind Down and Screen-Free Morning. No tag needed. Counting Sheep stays available."
        case .nfcAndAppShielding:
            return "A Wind Down tag starts app protection; selected apps are paused for Wind Down and Screen-Free Morning. Counting Sheep stays available, with an emergency exit if you need your phone back sooner."
        }
    }
}

struct OnboardingDraft: Codable, Equatable {
    var step: CountingSheepOnboardingStep = .welcome
    var welcomePage: OnboardingWelcomePage = .countingSheep
    var profileAnswers: WindDownProfileAnswer = .defaults
    var completedProfileQuestions: Set<WindDownProfileQuestion> = []
    var profileQuestionIndex = 0
    var profileSkipped = false
    var selectedWelcomeGiftItemID: String?
    var bedtimeHour = 23
    var bedtimeMinute = 0
    var wakeHour = 7
    var wakeMinute = 0
    var windDownMinutes = 30
    var morningQuietMinutes = 30
    var eveningActivity: PhoneFreeActivity = .read
    var morningActivity: PhoneFreeActivity = .openCurtains
    var eveningCueText: String?
    var morningCueText: String?
    // Examples belong in the recommendation/editor UI. A fresh onboarding
    // draft waits for the person to author or add a routine idea.
    var eveningRoutine: [WindDownRoutineStep] = []
    var morningRoutine: [WindDownRoutineStep] = []
    var purposeCategory: OfflinePurposeCategory = .rest
    var customPurpose: String?
    var allowsCustomTextInNotifications = false
    var protectionChoice: OnboardingProtectionChoice = .appShielding
    var shieldingEnabled = true
    /// Opaque, user-authored confirmation only. Older drafts decode as false;
    /// it never represents named-app inspection or retroactive verification.
    var protectionSelectionSelfConfirmed = false
    var automaticStartEnabled = false
    var remindersEnabled = false
    var notificationCadence: NotificationCadence = .balanced
    var notificationSoundsEnabled = true
    var educationalTipsEnabled = false
    var usageAwareRemindersEnabled = false
    var morningReflectionReminderEnabled = false

    private enum CodingKeys: String, CodingKey {
        case step, welcomePage, profileAnswers, completedProfileQuestions, profileQuestionIndex
        case profileSkipped, selectedWelcomeGiftItemID
        case bedtimeHour, bedtimeMinute, wakeHour, wakeMinute
        case windDownMinutes, morningQuietMinutes, eveningActivity, morningActivity
        case eveningCueText, morningCueText, eveningRoutine, morningRoutine
        case purposeCategory, customPurpose, allowsCustomTextInNotifications
        case protectionChoice, shieldingEnabled, protectionSelectionSelfConfirmed, automaticStartEnabled
        case remindersEnabled, notificationCadence, notificationSoundsEnabled
        case educationalTipsEnabled, usageAwareRemindersEnabled, morningReflectionReminderEnabled
    }

    init() {}

    init(step: CountingSheepOnboardingStep) {
        self.init()
        self.step = step
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        step = try container.decodeIfPresent(CountingSheepOnboardingStep.self, forKey: .step) ?? .welcome
        welcomePage = try container.decodeIfPresent(OnboardingWelcomePage.self, forKey: .welcomePage) ?? .countingSheep
        profileAnswers = try container.decodeIfPresent(WindDownProfileAnswer.self, forKey: .profileAnswers) ?? .defaults
        completedProfileQuestions = try container.decodeIfPresent(
            Set<WindDownProfileQuestion>.self,
            forKey: .completedProfileQuestions
        ) ?? []
        profileQuestionIndex = min(
            max(0, try container.decodeIfPresent(Int.self, forKey: .profileQuestionIndex) ?? 0),
            max(0, CountingSheepOnboarding.profileQuestions.count - 1)
        )
        profileSkipped = try container.decodeIfPresent(Bool.self, forKey: .profileSkipped) ?? false
        selectedWelcomeGiftItemID = try container.decodeIfPresent(String.self, forKey: .selectedWelcomeGiftItemID)
        bedtimeHour = try container.decodeIfPresent(Int.self, forKey: .bedtimeHour) ?? 23
        bedtimeMinute = try container.decodeIfPresent(Int.self, forKey: .bedtimeMinute) ?? 0
        wakeHour = try container.decodeIfPresent(Int.self, forKey: .wakeHour) ?? 7
        wakeMinute = try container.decodeIfPresent(Int.self, forKey: .wakeMinute) ?? 0
        windDownMinutes = try container.decodeIfPresent(Int.self, forKey: .windDownMinutes) ?? 30
        morningQuietMinutes = try container.decodeIfPresent(Int.self, forKey: .morningQuietMinutes) ?? 30
        eveningActivity = try container.decodeIfPresent(PhoneFreeActivity.self, forKey: .eveningActivity) ?? .read
        morningActivity = try container.decodeIfPresent(PhoneFreeActivity.self, forKey: .morningActivity) ?? .openCurtains
        eveningCueText = PhoneFreeCue.normalized(try container.decodeIfPresent(String.self, forKey: .eveningCueText))
        morningCueText = PhoneFreeCue.normalized(try container.decodeIfPresent(String.self, forKey: .morningCueText))
        eveningRoutine = WindDownRoutineStep.normalized(
            try container.decodeIfPresent([WindDownRoutineStep].self, forKey: .eveningRoutine)
                ?? WindDownRoutineStep.migrated(
                    phase: .evening,
                    activity: eveningActivity,
                    cueText: eveningCueText
                ),
            for: .evening
        )
        morningRoutine = WindDownRoutineStep.normalized(
            try container.decodeIfPresent([WindDownRoutineStep].self, forKey: .morningRoutine)
                ?? WindDownRoutineStep.migrated(
                    phase: .morning,
                    activity: morningActivity,
                    cueText: morningCueText
                ),
            for: .morning
        )
        purposeCategory = try container.decodeIfPresent(OfflinePurposeCategory.self, forKey: .purposeCategory) ?? .rest
        customPurpose = try container.decodeIfPresent(String.self, forKey: .customPurpose)
        allowsCustomTextInNotifications = try container.decodeIfPresent(Bool.self, forKey: .allowsCustomTextInNotifications) ?? false
        protectionChoice = try container.decodeIfPresent(OnboardingProtectionChoice.self, forKey: .protectionChoice) ?? .appShielding
        shieldingEnabled = try container.decodeIfPresent(Bool.self, forKey: .shieldingEnabled) ?? true
        protectionSelectionSelfConfirmed = try container.decodeIfPresent(
            Bool.self,
            forKey: .protectionSelectionSelfConfirmed
        ) ?? false
        automaticStartEnabled = try container.decodeIfPresent(Bool.self, forKey: .automaticStartEnabled) ?? false
        remindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? false
        notificationCadence = try container.decodeIfPresent(NotificationCadence.self, forKey: .notificationCadence) ?? .balanced
        notificationSoundsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationSoundsEnabled) ?? true
        educationalTipsEnabled = try container.decodeIfPresent(Bool.self, forKey: .educationalTipsEnabled) ?? false
        usageAwareRemindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .usageAwareRemindersEnabled) ?? false
        morningReflectionReminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .morningReflectionReminderEnabled) ?? false
    }

    var selectedGuardKind: SessionGuardKind { protectionChoice.guardKind }

    var profileRecommendation: WindDownProfileRecommendation {
        WindDownProfileMapper.recommendation(for: profileAnswers)
    }

    var hasCompletedProfileQuestions: Bool {
        CountingSheepOnboarding.profileQuestions.allSatisfy(completedProfileQuestions.contains)
    }

    var currentProfileQuestion: WindDownProfileQuestion {
        CountingSheepOnboarding.profileQuestions[
            min(profileQuestionIndex, CountingSheepOnboarding.profileQuestions.count - 1)
        ]
    }

    var hasAnsweredCurrentProfileQuestion: Bool {
        completedProfileQuestions.contains(currentProfileQuestion)
    }

    var currentStageNumber: Int {
        (journeySteps.firstIndex(of: step) ?? 0) + 1
    }

    var stageCount: Int { journeySteps.count }

    var journeySteps: [CountingSheepOnboardingStep] {
        guard profileSkipped else { return CountingSheepOnboardingStep.visibleSteps }
        return CountingSheepOnboardingStep.visibleSteps.filter { $0 != .recommendation }
    }

    var visiblePageCount: Int {
        OnboardingWelcomePage.visiblePages.count + journeySteps.count - 1
    }

    var visiblePageNumber: Int {
        if step == .welcome {
            return welcomePage.normalizedForCurrentFlow.visibleIndex + 1
        }
        let stepIndex = journeySteps.firstIndex(of: step) ?? max(0, journeySteps.count - 1)
        return OnboardingWelcomePage.visiblePages.count + stepIndex
    }

    mutating func applyRecommendation(_ recommendation: WindDownProfileRecommendation) {
        // Recommendations explain explicit answers only. Schedule, quiet-window,
        // and routine choices remain owned by their dedicated setup stages.
        _ = recommendation
    }

    mutating func skipProfile() {
        profileSkipped = true
    }

    /// `.grantStartingPoint` remains source-compatible with existing callers but now
    /// means persist the reviewed behavioral result only; gifts have their own stage.
    @discardableResult
    mutating func continueVisibleStep() -> OnboardingVisibleStepEffect {
        if step == .welcome {
            let nextPageIndex = welcomePage.normalizedForCurrentFlow.visibleIndex + 1
            if OnboardingWelcomePage.visiblePages.indices.contains(nextPageIndex) {
                welcomePage = OnboardingWelcomePage.visiblePages[nextPageIndex]
                return .none
            }
        }
        if step == .profile {
            if profileQuestionIndex + 1 < CountingSheepOnboarding.profileQuestions.count {
                profileQuestionIndex += 1
                return .none
            }
            profileSkipped = false
            applyRecommendation(profileRecommendation)
        }
        let shouldPersistStartingPoint = step == .recommendation && !profileSkipped
        moveToNextVisibleStep()
        return shouldPersistStartingPoint ? .grantStartingPoint : .none
    }

    /// Skip the current visible setup page without finishing onboarding.
    @discardableResult
    mutating func skipVisibleStep() -> OnboardingVisibleStepEffect {
        switch step {
        case .welcome:
            step = .profile
            return .none
        case .profile:
            profileSkipped = true
            step = .gift
            return .skipQuestionnaire
        case .recommendation:
            // The questionnaire already completed; skip only the result screen.
            step = .gift
            return profileSkipped ? .skipQuestionnaire : .keepCompletedProfile
        case .gift:
            step = .schedule
            return .none
        default:
            return .none
        }
    }

    mutating func moveToNextVisibleStep() {
        guard let index = CountingSheepOnboardingStep.visibleSteps.firstIndex(of: step),
              index + 1 < CountingSheepOnboardingStep.visibleSteps.count else {
            return
        }
        var next = CountingSheepOnboardingStep.visibleSteps[index + 1]
        if profileSkipped, next == .recommendation {
            next = CountingSheepOnboardingStep.visibleSteps
                .dropFirst(index + 1)
                .first { $0 != .recommendation }
                ?? .gift
        }
        step = next
    }

    func makeNightWatchPreferences() -> NightWatchPreferences {
        NightWatchPreferences(
            bedtimeHour: bedtimeHour,
            bedtimeMinute: bedtimeMinute,
            wakeHour: wakeHour,
            wakeMinute: wakeMinute,
            windDownMinutes: windDownMinutes,
            morningQuietMinutes: morningQuietMinutes,
            eveningActivity: eveningActivity,
            morningActivity: morningActivity,
            eveningCueText: eveningCueText,
            morningCueText: morningCueText,
            eveningRoutine: eveningRoutine,
            morningRoutine: morningRoutine,
            guardKind: selectedGuardKind,
            isConfigured: true,
            automaticStartEnabled: automaticStartEnabled
        )
    }

    func makePrimaryWindDownRoutine(existingID: UUID? = nil) -> WindDownRoutine {
        WindDownRoutine.primary(
            from: makeNightWatchPreferences(),
            id: existingID ?? UUID()
        )
    }

    func makeOfflinePurpose() -> OfflinePurposeProfile {
        let openEndedPurpose = PhoneFreeCue.normalized(customPurpose)
        let category = openEndedPurpose == nil ? purposeCategory : .custom
        return OfflinePurposeProfile(
            category: category,
            customText: openEndedPurpose,
            allowsCustomTextInNotifications: category == .custom
                && allowsCustomTextInNotifications
        )
    }

    func makeNotificationPreferences() -> NotificationPreferences {
        NotificationPreferences(
            remindersEnabled: remindersEnabled,
            cadence: notificationCadence,
            hasChosenCadence: true,
            soundsEnabled: notificationSoundsEnabled,
            educationalTipsEnabled: educationalTipsEnabled,
            usageAwareRemindersEnabled: usageAwareRemindersEnabled,
            morningReflectionReminderEnabled: morningReflectionReminderEnabled
        )
    }

    static func defaults(from preferences: NightWatchPreferences = .defaults) -> Self {
        var draft = Self()
        draft.bedtimeHour = preferences.bedtimeHour
        draft.bedtimeMinute = preferences.bedtimeMinute
        draft.wakeHour = preferences.wakeHour
        draft.wakeMinute = preferences.wakeMinute
        draft.windDownMinutes = preferences.windDownMinutes
        draft.morningQuietMinutes = preferences.morningQuietMinutes
        draft.eveningActivity = preferences.eveningActivity
        draft.morningActivity = preferences.morningActivity
        draft.eveningCueText = preferences.eveningCueText
        draft.morningCueText = preferences.morningCueText
        draft.eveningRoutine = preferences.eveningRoutine
        draft.morningRoutine = preferences.morningRoutine
        // A first-run user should understand the no-hardware path before being
        // invited to add an NFC tag. Existing plans are not routed through onboarding.
        draft.protectionChoice = .appShielding
        draft.shieldingEnabled = true
        draft.automaticStartEnabled = preferences.isConfigured
            ? preferences.automaticStartEnabled
            : false
        return draft
    }

    static func replay(from preferences: NightWatchPreferences) -> Self {
        var draft = defaults(from: preferences)
        draft.protectionChoice = preferences.guardKind == .nfcTag
            ? .nfcAndAppShielding
            : .appShielding
        return draft
    }
}

enum OnboardingReminderReadiness: Equatable {
    case off
    case enabledAndAuthorized
    case enabledWithoutAuthorization
}

struct OnboardingReadinessSummary: Equatable {
    let nextWindDownStart: Date
    let intendedBedtime: Date
    let intendedWakeTime: Date
    let morningQuietEnd: Date
    let isLaterToday: Bool
    let eveningAnchors: [String]
    let morningAnchors: [String]
    let appProtectionReady: Bool
    let reminderReadiness: OnboardingReminderReadiness
    let startsAutomatically: Bool

    init(
        draft: OnboardingDraft,
        appProtectionReady: Bool,
        notificationAuthorized: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        let preferences = draft.makeNightWatchPreferences()
        let start = preferences.nextStart(after: now, calendar: calendar)
        let plan = preferences.makePlan(startedAt: start, calendar: calendar)
        nextWindDownStart = start
        intendedBedtime = plan.intendedBedtime
        intendedWakeTime = plan.wakeTime
        morningQuietEnd = plan.protectedUntil
        isLaterToday = calendar.isDate(start, inSameDayAs: now)
        eveningAnchors = [WindDownRoutineStep.phoneAwayTitle] + draft.eveningRoutine.map(\.title)
        morningAnchors = draft.morningRoutine.map(\.title)
        self.appProtectionReady = appProtectionReady
        reminderReadiness = !draft.remindersEnabled
            ? .off
            : (notificationAuthorized ? .enabledAndAuthorized : .enabledWithoutAuthorization)
        startsAutomatically = draft.automaticStartEnabled
    }
}
