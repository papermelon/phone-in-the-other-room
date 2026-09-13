import Foundation

enum OnboardingVisibleStepEffect: Equatable {
    case none
    case grantStartingPoint
    case skipQuestionnaire
    case keepCompletedProfile
}

/// New plans can reach Home before protection setup. Existing interrupted drafts
/// retain their original route so no questionnaire, gift, or account step is lost.
enum OnboardingJourneyRoute: String, Codable {
    case legacy
    case planFirst
}

enum OnboardingPersonalizationStep {
    case startingPoint
    case welcomeGift
}

enum CountingSheepOnboarding {
    static let currentVersion = 1
    static let versionKey = "ollie.onboarding.version"
    static let draftKey = "ollie.onboarding.draft"
    static let profileQuestions: [WindDownProfileQuestion] = [
        .bedtimeDelay, .automaticReaching, .morningChecking,
        .overnightLocation, .awayFriction, .desiredChange
    ]

    static func acceptsCommittedRestoreRoute(
        presentationMode: OnboardingPresentationMode,
        onboardingVersion: Int
    ) -> Bool {
        presentationMode == .firstRun && onboardingVersion < currentVersion
    }
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
            return "Counting Sheep helps you physically put your phone in another room across the edges of sleep — before bed, overnight, and after you wake."
        case .windDown:
            return "Wind Down spans quiet before bed, overnight phone separation, and quiet after waking."
        case .phoneAway:
            return "Phone Away is a separate elapsed-time record outside Wind Down. Use it to make room beyond doomscrolling apps for reading, making, movement, cooking, conversation, rest, work, or anything else you value."
        case .ollie:
            return "You are the shepherd tending this Farm. Ollie is your capable border-collie sheepdog: he watches the ritual and searches for missing sheep."
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
    // Appended so the raw values used by saved drafts and capture fixtures stay stable.
    case account

    var id: Int { rawValue }

    /// Integer raw values never change: existing drafts and capture fixtures store them.
    /// Reminder permission lives on Schedule; the legacy automatic-start case still decodes.
    static let visibleSteps: [Self] = [.welcome, .schedule, .quiet, .ready]

    static let legacyVisibleSteps: [Self] = [
        .welcome, .profile, .recommendation, .gift, .account, .schedule, .quiet, .protection, .ready
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
        case .account: return "Your Farm account"
        case .automaticStart: return "Advanced reminders"
        case .ready: return "Review your plan"
        }
    }

    var progress: Double {
        Double(visibleIndex + 1) / Double(Self.visibleSteps.count)
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
