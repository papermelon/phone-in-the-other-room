import Foundation

enum NightWatchNotificationMoment {
    case windDownReminder
    case sleepTime
    case phoneFreeMorning
    case complete
}

struct NightWatchNotificationCopy: Equatable {
    var title: String
    var body: String
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
        switch phase {
        case .windDown:
            return joinedCue(
                prefix: "Wind down without the screen.",
                activityTitle: activityTitle,
                tip: tip(for: .windDown, seed: seed)
            )
        case .overnight:
            return "Sleep time. Your phone is tucked away."
        case .morningQuiet:
            return joinedCue(
                prefix: "Keep this morning phone-free.",
                activityTitle: activityTitle,
                tip: tip(for: .morningQuiet, seed: seed)
            )
        case .complete:
            return "Your phone-free night is ready."
        case nil:
            return "Your phone-away time is keeping on."
        }
    }

    static func notificationCopy(
        for moment: NightWatchNotificationMoment,
        activityTitle: String? = nil,
        tip: String? = nil
    ) -> NightWatchNotificationCopy {
        switch moment {
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
                body: "Night Watch is complete. Your phone-free minutes are ready whenever you are."
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
