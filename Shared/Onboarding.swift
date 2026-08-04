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

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .quiet: return "Make room for quiet"
        case .schedule: return "Shape your night"
        case .protection: return "Protect the quiet"
        case .automaticStart: return "Let Ollie begin"
        case .ready: return "Tonight's plan"
        }
    }

    var progress: Double {
        Double(rawValue + 1) / Double(Self.allCases.count)
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
        case .appShielding: return "App Shielding"
        case .nfcAndAppShielding: return "NFC + App Shielding"
        }
    }

    var detail: String {
        switch self {
        case .appShielding:
            return "Selected apps stay limited through Wind Down and sleep. No NFC tag needed."
        case .nfcAndAppShielding:
            return "A phone-bed tag confirms where the phone is tucked away, while selected apps rest too."
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
            guardKind: selectedGuardKind,
            isConfigured: true,
            automaticStartEnabled: automaticStartEnabled
        )
    }

    func makeOfflinePurpose() -> OfflinePurposeProfile {
        OfflinePurposeProfile(
            category: purposeCategory,
            customText: purposeCategory == .custom ? customPurpose : nil,
            allowsCustomTextInNotifications: purposeCategory == .custom
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
        Self(
            step: .welcome,
            bedtimeHour: preferences.bedtimeHour,
            bedtimeMinute: preferences.bedtimeMinute,
            wakeHour: preferences.wakeHour,
            wakeMinute: preferences.wakeMinute,
            windDownMinutes: preferences.windDownMinutes,
            morningQuietMinutes: preferences.morningQuietMinutes,
            eveningActivity: preferences.eveningActivity,
            morningActivity: preferences.morningActivity,
            // A first-run user should understand the no-hardware path before being
            // invited to add an NFC tag. Existing plans are not routed through onboarding.
            protectionChoice: .appShielding,
            shieldingEnabled: true,
            automaticStartEnabled: preferences.automaticStartEnabled
        )
    }

    static func replay(from preferences: NightWatchPreferences) -> Self {
        var draft = defaults(from: preferences)
        draft.protectionChoice = preferences.guardKind == .nfcTag
            ? .nfcAndAppShielding
            : .appShielding
        return draft
    }
}
