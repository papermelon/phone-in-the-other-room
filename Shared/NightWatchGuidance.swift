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
        let choices: [String]
        switch phase {
        case .windDown:
            choices = [
                "Dim one light and let the room feel later.",
                "Leave tomorrow's first task on paper.",
                "Put a paper book where the phone used to be.",
                "Try a few slow stretches before settling in.",
                "Prepare one small thing for the morning.",
                "Let a warm drink mark the end of the day."
            ]
        case .morningQuiet:
            choices = [
                "Open the curtains and let daylight arrive first.",
                "Drink some water before checking the day.",
                "Get dressed before the phone wakes.",
                "Let breakfast be the first thing on the menu.",
                "Step outside for a little morning air.",
                "Write down one thought before reading anyone else's."
            ]
        case .overnight, .complete:
            return nil
        }

        return choices[stableIndex(seed: seed, phase: phase, count: choices.count)]
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
                    ?? "Let the evening get quieter.",
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
                    ?? "Let the phone wake after you do.",
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
                    body: "In about an hour, Ollie will help the phone settle. Finish what you need, then find its resting place."
                )
            case 30:
                return NightWatchNotificationCopy(
                    title: "Wind Down in 30 minutes",
                    body: "A little time before bed. Let the last scroll end gently, then put the phone to bed."
                )
            case 10:
                return NightWatchNotificationCopy(
                    title: "Wind Down soon",
                    body: "Ten minutes until the phone rests. Find the NFC phone-bed tag and one quiet thing to do."
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
