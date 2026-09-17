import Foundation

enum NightWatchNotificationMoment {
    case windDownLeadIn(minutes: Int)
    case windDownReminder
    case windDownMidpoint
    case sleepTime
    case phoneFreeMorning
    case morningMidpoint
    case usageCue(NightWatchPhase)
    case complete
    case morningReflection
    case shieldingFailed
    case quietPeriodComplete
}

struct NightWatchNotificationCopy: Equatable {
    var title: String
    var body: String
}

struct NightWatchLiveActivityGuidance: Equatable {
    var primary: String
    var secondary: String?
}

struct NightWatchGuidance {
    static func tip(for phase: NightWatchPhase, seed: UUID) -> String? {
        guard phase == .windDown || phase == .morningQuiet else { return nil }
        return WindDownGuidanceLibrary.featured(for: phase, seed: seed)?.body
    }

    static func liveActivityDetail(
        for phase: NightWatchPhase?,
        activityTitle: String?,
        seed: UUID
    ) -> String {
        let guidance = liveActivityGuidance(
            for: phase,
            activityTitle: activityTitle,
            seed: seed
        )
        return [guidance.primary, guidance.secondary]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    static func liveActivityGuidance(
        for phase: NightWatchPhase?,
        activityTitle: String?,
        seed: UUID,
        routineTitles: [String]? = nil
    ) -> NightWatchLiveActivityGuidance {
        let titles = (routineTitles ?? activityTitle.map { [$0] } ?? [])
            .compactMap(PhoneFreeCue.normalized)
        switch phase {
        case .windDown, .morningQuiet:
            guard let first = titles.first else {
                return NightWatchLiveActivityGuidance(
                    primary: phase == .windDown ? "Leave your phone in its spot." : "Ease into your morning.",
                    secondary: nil
                )
            }
            return NightWatchLiveActivityGuidance(
                primary: sentence(first),
                secondary: titles.count > 1
                    ? "Your other ideas: " + titles.dropFirst().joined(separator: " · ")
                    : nil
            )
        case .overnight:
            return NightWatchLiveActivityGuidance(
                primary: "Settle in for the night.",
                secondary: "Your countdown now runs until morning."
            )
        case .complete:
            return NightWatchLiveActivityGuidance(
                primary: "Time to begin your day.",
                secondary: "Your night’s summary will be waiting in Counting Sheep."
            )
        case nil:
            return NightWatchLiveActivityGuidance(
                primary: "Leave your phone in its spot.",
                secondary: nil
            )
        }
    }

    private static func sentence(_ text: String) -> String {
        guard let last = text.last, !".!?…".contains(last) else { return text }
        return text + "."
    }

    static func notificationCopy(
        for moment: NightWatchNotificationMoment,
        activityTitle: String? = nil,
        tip: String? = nil,
        role: QuietTimeShieldRole = .primaryWindDown
    ) -> NightWatchNotificationCopy {
        switch moment {
        case .windDownLeadIn(let minutes):
            switch minutes {
            case 60:
                return NightWatchNotificationCopy(
                    title: "Wind Down is coming",
                    body: "Your planned Wind Down begins in about an hour."
                )
            case 30:
                return NightWatchNotificationCopy(
                    title: "Wind Down in 30 minutes",
                    body: "Your planned Wind Down begins in 30 minutes."
                )
            case 10:
                return NightWatchNotificationCopy(
                    title: "Wind Down soon",
                    body: "Your planned Wind Down begins in 10 minutes."
                )
            default:
                return NightWatchNotificationCopy(
                    title: "Wind Down starts now",
                    body: "Your planned Wind Down can begin now. Tap to start when you are ready."
                )
            }
        case .windDownReminder:
            let cue = tip.map { $0.hasSuffix(".") ? $0 : "\($0)." }
            return NightWatchNotificationCopy(
                title: "Wind Down can begin now",
                body: [
                    "Tap to start your planned Wind Down when you are ready.",
                    cue
                ]
                    .compactMap { $0 }
                    .joined(separator: " ")
            )
        case .windDownMidpoint:
            return NightWatchNotificationCopy(
                title: tip == nil ? "Wind Down is underway" : "A Wind Down idea",
                body: tip
                    ?? activityTitle.map(sentence)
                    ?? "Leave your phone in its spot and take a little time to settle in."
            )
        case .sleepTime:
            let cue = tip.map { $0.hasSuffix(".") ? $0 : "\($0)." }
            return NightWatchNotificationCopy(
                title: "Time for bed",
                body: [
                    "Settle in for the night. Your next countdown runs until morning.",
                    cue
                ]
                    .compactMap { $0 }
                    .joined(separator: " ")
            )
        case .phoneFreeMorning:
            let activityCue = activityTitle.map(sentence)
            let cue = [activityCue, tip]
                .compactMap { $0 }
                .map { $0.hasSuffix(".") ? $0 : "\($0)." }
                .joined(separator: " ")
            return NightWatchNotificationCopy(
                title: "Screen-Free Morning began",
                body: ["The Screen-Free Morning timer is running.", cue]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            )
        case .morningMidpoint:
            return NightWatchNotificationCopy(
                title: "Screen-Free Morning continues",
                body: tip ?? "A little room to begin the day at your own pace."
            )
        case .usageCue(let phase):
            switch phase {
            case .windDown:
                return NightWatchNotificationCopy(
                    title: "Wind Down is waiting",
                    body: "That check can wait. Return to your Wind Down when you are ready."
                )
            case .overnight:
                return NightWatchNotificationCopy(
                    title: "A late check can wait",
                    body: "The overnight phase is still running. Return to Wind Down when you are ready."
                )
            case .morningQuiet:
                return NightWatchNotificationCopy(
                    title: "Screen-Free Morning is still here",
                    body: "Let your morning come before your phone. Return when you’re ready."
                )
        case .complete:
            return NightWatchNotificationCopy(
                title: "Wind Down timer ended",
                body: "Your session summary is ready in Counting Sheep."
            )
            }
        case .complete:
            return NightWatchNotificationCopy(
                title: "Wind Down timer ended",
                body: "Your session summary is ready in Counting Sheep."
            )
        case .morningReflection:
            return NightWatchNotificationCopy(
                title: "A small morning note",
                body: "If you have a moment, notice how the night felt. There is nothing to score."
            )
        case .shieldingFailed:
            return NightWatchNotificationCopy(
                title: "Selected-app limits need attention",
                body: shieldingFailureBody(for: role)
            )
        case .quietPeriodComplete:
            return NightWatchNotificationCopy(
                title: "Phone Away timer ended",
                body: "Your session summary is ready in Counting Sheep."
            )
        }
    }

    private static func shieldingFailureBody(for role: QuietTimeShieldRole) -> String {
        let mode: String
        switch role {
        case .primaryWindDown: mode = "Wind Down"
        case .additionalQuiet: mode = "Phone Away"
        case .screenFreeMorning: mode = "Screen-Free Morning"
        }
        return "Selected apps could not be limited for this \(mode). The timer continues."
    }

    private static func joinedCue(prefix: String, activityTitle: String?, tip: String?) -> String {
        let activityCue = activityTitle.map(sentence)
        return [prefix, activityCue, tip]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    private static func stableIndex(
        seed: UUID,
        phase: NightWatchPhase,
        count: Int
    ) -> Int {
        let seedValue = seed.uuidString.unicodeScalars.reduce(UInt(0)) { partial, scalar in
            (partial &* 31) &+ UInt(scalar.value)
        }
        let phaseOffset = UInt(NightWatchPhase.allCases.firstIndex(of: phase) ?? 0)
        return Int((seedValue &+ phaseOffset) % UInt(count))
    }
}
