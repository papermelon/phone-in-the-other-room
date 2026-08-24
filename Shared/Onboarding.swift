import Foundation

enum OnboardingVisibleStepEffect: Equatable {
    case none
    case grantStartingPoint
    case skipQuestionnaire
    case keepCompletedProfile
}

enum CountingSheepOnboarding {
    static let currentVersion = 1
    static let versionKey = "ollie.onboarding.version"
    static let draftKey = "ollie.onboarding.draft"
}

enum OnboardingWelcomePage: Int, CaseIterable, Codable, Identifiable {
    case countingSheep
    case windDown
    case phoneAway
    case ollie

    var id: Int { rawValue }

    var eyebrow: String {
        switch self {
        case .countingSheep: return "COUNTING SHEEP"
        case .windDown: return "WIND DOWN"
        case .phoneAway: return "PHONE AWAY"
        case .ollie: return "OLLIE"
        }
    }

    var title: String {
        switch self {
        case .countingSheep: return "Give the phone a resting place."
        case .windDown: return "Wind Down holds the whole night."
        case .phoneAway: return "Phone Away is a shorter stretch."
        case .ollie: return "Ollie keeps watch."
        }
    }

    var detail: String {
        switch self {
        case .countingSheep:
            return "Counting Sheep helps make room around sleep by giving the phone a resting place in another room."
        case .windDown:
            return "Wind Down spans quiet before bed, overnight phone separation, and quiet after waking."
        case .phoneAway:
            return "Phone Away is a shorter phone-free period outside the usual Wind Down. App protection pauses the chosen apps and categories while the phone rests."
        case .ollie:
            return "Ollie keeps watch and searches for missing sheep while you follow through."
        }
    }
}

enum CountingSheepOnboardingStep: Int, CaseIterable, Codable, Identifiable {
    case welcome
    case quiet
    case schedule
    case protection
    case automaticStart
    case ready
    case profile
    case recommendation
    case gift

    var id: Int { rawValue }

    /// Advanced notification choices remain in Settings. Keep the legacy case so an
    /// older saved draft still decodes, then normalize it in the flow to the plan screen.
    static let visibleSteps: [Self] = [
        .welcome, .profile, .recommendation, .schedule, .quiet, .protection, .gift, .ready
    ]

    var visibleIndex: Int {
        Self.visibleSteps.firstIndex(of: self) ?? Self.visibleSteps.count - 1
    }

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .profile: return "Starting point"
        case .recommendation: return "Your starting point"
        case .quiet: return "Optional cues"
        case .schedule: return "Your night"
        case .protection: return "App protection"
        case .gift: return "Welcome gift"
        case .automaticStart: return "Advanced reminders"
        case .ready: return "Saved plan"
        }
    }

    var progress: Double {
        Double(visibleIndex + 1) / Double(Self.visibleSteps.count)
    }
}

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
    var profileSkipped = false
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
    var automaticStartEnabled = true
    var remindersEnabled = true
    var notificationCadence: NotificationCadence = .balanced
    var notificationSoundsEnabled = true
    var educationalTipsEnabled = false
    var usageAwareRemindersEnabled = false
    var morningReflectionReminderEnabled = false

    private enum CodingKeys: String, CodingKey {
        case step, welcomePage, profileAnswers, profileSkipped
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
        profileSkipped = try container.decodeIfPresent(Bool.self, forKey: .profileSkipped) ?? false
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
        automaticStartEnabled = try container.decodeIfPresent(Bool.self, forKey: .automaticStartEnabled) ?? true
        remindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? true
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

    mutating func applyRecommendation(_ recommendation: WindDownProfileRecommendation) {
        bedtimeHour = recommendation.bedtimeHour
        bedtimeMinute = recommendation.bedtimeMinute
        wakeHour = recommendation.wakeHour
        wakeMinute = recommendation.wakeMinute
        windDownMinutes = recommendation.desiredWindDownMinutes
        // Recommendations are examples and timing cues, not silent routine
        // enrollment. Existing authored arrays remain untouched.
    }

    mutating func skipProfile() {
        profileSkipped = true
    }

    /// Continue from the current visible setup page. Returning `.grantStartingPoint`
    /// means the questionnaire was completed and the pending wearable should be saved.
    @discardableResult
    mutating func continueVisibleStep() -> OnboardingVisibleStepEffect {
        if step == .welcome, let nextPage = OnboardingWelcomePage(rawValue: welcomePage.rawValue + 1) {
            welcomePage = nextPage
            return .none
        }
        if step == .profile {
            profileSkipped = false
            applyRecommendation(profileRecommendation)
        }
        let shouldGrant = (step == .profile || step == .recommendation) && !profileSkipped
        moveToNextVisibleStep()
        return shouldGrant ? .grantStartingPoint : .none
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
            step = .schedule
            return .skipQuestionnaire
        case .recommendation:
            // The questionnaire already completed; skip only the result screen.
            step = .schedule
            return profileSkipped ? .skipQuestionnaire : .keepCompletedProfile
        case .gift:
            moveToNextVisibleStep()
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
        if profileSkipped, next == .recommendation || next == .gift {
            next = CountingSheepOnboardingStep.visibleSteps
                .dropFirst(index + 1)
                .first { $0 != .recommendation && $0 != .gift }
                ?? .schedule
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
        let openEndedPurpose = PhoneFreeCue.normalized(eveningCueText) ?? customPurpose
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
        draft.automaticStartEnabled = preferences.automaticStartEnabled
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
