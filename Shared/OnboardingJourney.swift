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
    static let profileQuestions: [WindDownProfileQuestion] = [
        .bedtimeDelay, .automaticReaching, .morningChecking,
        .overnightLocation, .awayFriction, .desiredChange
    ]
}

enum OnboardingPresentationMode: Equatable {
    case firstRun
    case replay
    case fixture

    var preservesExistingSettings: Bool { self == .replay }
}

enum OnboardingWelcomePage: Int, CaseIterable, Codable, Identifiable {
    case countingSheep
    case windDown
    case phoneAway
    case ollie

    var id: Int { rawValue }

    /// The earlier four-page introduction remains decodable, but the current
    /// first run tells the same story in two meaningfully different pages.
    static let visiblePages: [Self] = [.countingSheep, .ollie]

    var normalizedForCurrentFlow: Self {
        switch self {
        case .countingSheep, .windDown: return .countingSheep
        case .phoneAway, .ollie: return .ollie
        }
    }

    var visibleIndex: Int {
        Self.visiblePages.firstIndex(of: normalizedForCurrentFlow) ?? 0
    }

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
        case .countingSheep: return "Put the phone to bed before you."
        case .windDown: return "Wind Down holds the whole night."
        case .phoneAway: return "Phone Away is a shorter stretch."
        case .ollie: return "Ollie keeps watch."
        }
    }

    var detail: String {
        switch self {
        case .countingSheep:
            return "Counting Sheep helps you make a little space between your screen and your sleep — before bed, overnight, and after you wake."
        case .windDown:
            return "Wind Down spans quiet before bed, overnight phone separation, and quiet after waking."
        case .phoneAway:
            return "Phone Away is a shorter phone-free period outside the usual Wind Down. App protection pauses the chosen apps and categories while the phone rests."
        case .ollie:
            return ""
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

    /// Integer raw values never change: existing drafts and capture fixtures store them.
    /// Reminder permission lives on Schedule; the legacy automatic-start case still decodes.
    static let visibleSteps: [Self] = [
        .welcome, .profile, .recommendation, .gift, .schedule, .quiet, .protection, .ready
    ]

    var visibleIndex: Int {
        Self.visibleSteps.firstIndex(of: self) ?? Self.visibleSteps.count - 1
    }

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .profile: return "Starting point"
        case .recommendation: return "Your starting point"
        case .quiet: return "Your routine"
        case .schedule: return "Your Wind Down plan"
        case .protection: return "App protection"
        case .gift: return "Your Shepherd & welcome gift"
        case .automaticStart: return "Advanced reminders"
        case .ready: return "Saved plan"
        }
    }

    var progress: Double {
        Double(visibleIndex + 1) / Double(Self.visibleSteps.count)
    }
}
