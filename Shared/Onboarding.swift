import Foundation

enum CountingSheepOnboarding {
    static let currentVersion = 1
    static let versionKey = "ollie.onboarding.version"
    static let draftKey = "ollie.onboarding.draft"
}

enum CountingSheepOnboardingStep: Int, CaseIterable, Codable, Identifiable {
    case welcome
    case quiet
    case schedule
    case protection
    case automaticStart
    case ready

    var id: Int { rawValue }

    /// Advanced notification choices remain in Settings. Keep the legacy case so an
    /// older saved draft still decodes, then normalize it in the flow to the plan screen.
    static let visibleSteps: [Self] = [.welcome, .schedule, .quiet, .protection, .ready]

    var visibleIndex: Int {
        Self.visibleSteps.firstIndex(of: self) ?? Self.visibleSteps.count - 1
    }

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .quiet: return "Optional cues"
        case .schedule: return "Your night"
        case .protection: return "Optional shielding"
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
            return "Choose apps to limit from Wind Down start through your morning quiet window. No tag needed. Counting Sheep stays available."
        case .nfcAndAppShielding:
            return "A Wind Down tag starts the app limits; selected apps stay limited through your morning quiet window. Counting Sheep stays available, with an emergency exit if you need your phone back sooner."
        }
    }
}

struct OnboardingDraft: Codable, Equatable {
    var step: CountingSheepOnboardingStep = .welcome
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
    var eveningRoutine: [WindDownRoutineStep] = [
        .suggested(.read, phase: .evening)
    ]
    var morningRoutine: [WindDownRoutineStep] = [
        .suggested(.openCurtains, phase: .morning)
    ]
    var purposeCategory: OfflinePurposeCategory = .rest
    var customPurpose: String?
    var allowsCustomTextInNotifications = false
    var protectionChoice: OnboardingProtectionChoice = .appShielding
    var shieldingEnabled = true
    var automaticStartEnabled = true
    var remindersEnabled = true
    var notificationCadence: NotificationCadence = .balanced
    var notificationSoundsEnabled = true
    var educationalTipsEnabled = false
    var usageAwareRemindersEnabled = false
    var morningReflectionReminderEnabled = false

    private enum CodingKeys: String, CodingKey {
        case step, bedtimeHour, bedtimeMinute, wakeHour, wakeMinute
        case windDownMinutes, morningQuietMinutes, eveningActivity, morningActivity
        case eveningCueText, morningCueText, eveningRoutine, morningRoutine
        case purposeCategory, customPurpose, allowsCustomTextInNotifications
        case protectionChoice, shieldingEnabled, automaticStartEnabled
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
        automaticStartEnabled = try container.decodeIfPresent(Bool.self, forKey: .automaticStartEnabled) ?? true
        remindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? true
        notificationCadence = try container.decodeIfPresent(NotificationCadence.self, forKey: .notificationCadence) ?? .balanced
        notificationSoundsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationSoundsEnabled) ?? true
        educationalTipsEnabled = try container.decodeIfPresent(Bool.self, forKey: .educationalTipsEnabled) ?? false
        usageAwareRemindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .usageAwareRemindersEnabled) ?? false
        morningReflectionReminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .morningReflectionReminderEnabled) ?? false
    }

    var selectedGuardKind: SessionGuardKind { protectionChoice.guardKind }

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
