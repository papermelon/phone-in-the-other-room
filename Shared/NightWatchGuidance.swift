import Foundation

enum NightWatchNotificationMoment {
    case windDownLeadIn(minutes: Int)
    case windDownReminder
    case sleepTime
    case phoneFreeMorning
    case complete
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
        seed: UUID
    ) -> NightWatchLiveActivityGuidance {
        switch phase {
        case .windDown:
            return NightWatchLiveActivityGuidance(
                primary: activityTitle.map { "Tonight: \($0)." }
                    ?? "Ollie is following tonight's trail.",
                secondary: tip(for: .windDown, seed: seed)
            )
        case .overnight:
            return NightWatchLiveActivityGuidance(
                primary: "Your phone is tucked away.",
                secondary: "There is nothing else to do here."
            )
        case .morningQuiet:
            return NightWatchLiveActivityGuidance(
                primary: activityTitle.map { "This morning: \($0)." }
                    ?? "Ollie is bringing the trail home.",
                secondary: tip(for: .morningQuiet, seed: seed)
            )
        case .complete:
            return NightWatchLiveActivityGuidance(
                primary: "Your phone-free night is ready.",
                secondary: "Open Counting Sheep whenever you are ready."
            )
        case nil:
            return NightWatchLiveActivityGuidance(
                primary: "Ollie is keeping the quiet.",
                secondary: nil
            )
        }
    }

    static func notificationCopy(
        for moment: NightWatchNotificationMoment,
        activityTitle: String? = nil,
        tip: String? = nil
    ) -> NightWatchNotificationCopy {
        switch moment {
        case .windDownLeadIn(let minutes):
            switch minutes {
            case 60:
                return NightWatchNotificationCopy(
                    title: "Wind Down is coming",
                    body: "In about an hour, Ollie will head out on the trail. Finish what you need, then find the phone's resting place."
                )
            case 30:
                return NightWatchNotificationCopy(
                    title: "Wind Down in 30 minutes",
                    body: "A little time before bed. Let the last scroll end gently, then send the phone to its bed."
                )
            case 10:
                return NightWatchNotificationCopy(
                    title: "Wind Down soon",
                    body: "Ten minutes until the phone rests. Find its resting place and give Ollie a clear trail."
                )
            default:
                return NightWatchNotificationCopy(
                    title: "Wind Down starts now",
                    body: "Your phone-free wind-down begins now. Put the phone to bed when you are ready."
                )
            }
        case .windDownReminder:
            let cue = tip.map { $0.hasSuffix(".") ? $0 : "\($0)." }
            return NightWatchNotificationCopy(
                title: "Ollie is ready to tuck the phone in",
                body: [
                    "Your phone-free wind-down begins now.",
                    "Put the phone to bed when you're ready.",
                    cue
                ]
                    .compactMap { $0 }
                    .joined(separator: " ")
            )
        case .sleepTime:
            return NightWatchNotificationCopy(
                title: "Sleep time has begun",
                body: "Your phone is tucked away. Ollie has the watch."
            )
        case .phoneFreeMorning:
            let activityCue = activityTitle.map { "Try \($0.lowercased())." }
            let cue = [activityCue, tip]
                .compactMap { $0 }
                .map { $0.hasSuffix(".") ? $0 : "\($0)." }
                .joined(separator: " ")
            return NightWatchNotificationCopy(
                title: "Good morning from Ollie",
                body: ["Your phone-free morning has begun.", cue]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            )
        case .complete:
            return NightWatchNotificationCopy(
                title: "Your phone can wake now",
                body: "Wind Down is complete. Your phone-free minutes are ready whenever you are."
            )
        }
    }

    private static func joinedCue(prefix: String, activityTitle: String?, tip: String?) -> String {
        let activityCue = activityTitle.map { "Try \($0.lowercased())." }
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
