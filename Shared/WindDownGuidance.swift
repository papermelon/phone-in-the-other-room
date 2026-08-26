import Foundation

enum WindDownGuidanceTopic: String, Codable, CaseIterable, Identifiable {
    case screenBoundary
    case lightAndTiming
    case sleepCues
    case morning
    case settle
    case environment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .screenBoundary: return "Screens and boundaries"
        case .lightAndTiming: return "Light and timing"
        case .sleepCues: return "Gentle sleep cues"
        case .morning: return "A clear morning"
        case .settle: return "Letting the mind settle"
        case .environment: return "A calmer room"
        }
    }
}

struct WindDownGuidanceItem: Codable, Equatable, Identifiable {
    let id: String
    let topic: WindDownGuidanceTopic
    let title: String
    let body: String
    let phase: NightWatchPhase?
    let sourceIDs: [String]
}

enum WindDownGuidanceLibrary {
    static let items: [WindDownGuidanceItem] = [
        WindDownGuidanceItem(
            id: "phone-bed",
            topic: .screenBoundary,
            title: "Give the phone a resting place",
            body: "A phone in another room removes one easy reason to keep checking. Let the quiet hold the rest.",
            phase: .windDown,
            sourceIDs: ["counting-sheep-principles"]
        ),
        WindDownGuidanceItem(
            id: "quiet-hour",
            topic: .lightAndTiming,
            title: "Let the last hour get quieter",
            body: "Use the time before bed for calmer things and gentler light when you can.",
            phase: .windDown,
            sourceIDs: ["nhlbi-healthy-sleep"]
        ),
        WindDownGuidanceItem(
            id: "leave-room-after-heavy-meal",
            topic: .lightAndTiming,
            title: "Leave room after a heavy meal",
            body: "If you have a large meal close to bedtime, try leaving a little more room before bed when you can. Your own timing is the useful guide.",
            phase: .windDown,
            sourceIDs: ["nhlbi-healthy-sleep"]
        ),
        WindDownGuidanceItem(
            id: "personal-caffeine-cutoff",
            topic: .lightAndTiming,
            title: "Try an earlier caffeine cutoff",
            body: "Caffeine can linger for hours. Try an earlier personal cutoff and notice how the evening feels.",
            phase: .windDown,
            sourceIDs: ["nhlbi-healthy-sleep"]
        ),
        WindDownGuidanceItem(
            id: "steady-wake",
            topic: .lightAndTiming,
            title: "Give morning a familiar shape",
            body: "A reasonably steady wake time gives your body clock a clearer morning cue.",
            phase: .morningQuiet,
            sourceIDs: ["nhlbi-healthy-sleep", "nhlbi-sleep-wake-cycle"]
        ),
        WindDownGuidanceItem(
            id: "morning-light",
            topic: .morning,
            title: "Let daylight arrive first",
            body: "Opening the curtains or stepping outside gives the day a natural light cue.",
            phase: .morningQuiet,
            sourceIDs: ["nhlbi-sleep-wake-cycle"]
        ),
        WindDownGuidanceItem(
            id: "rest-not-performance",
            topic: .settle,
            title: "Sleep does not need to be forced",
            body: "If sleep is slow, let resting comfortably be enough for this moment. The night is not a test.",
            phase: .windDown,
            sourceIDs: ["va-stimulus-control", "counting-sheep-booklet"]
        ),
        WindDownGuidanceItem(
            id: "bed-as-cue",
            topic: .sleepCues,
            title: "Keep the bed a quiet cue",
            body: "When you can, leave scrolling and work outside the bed so the room can feel more like a place for rest.",
            phase: .windDown,
            sourceIDs: ["va-stimulus-control"]
        ),
        WindDownGuidanceItem(
            id: "calm-room",
            topic: .environment,
            title: "Make the room feel ready",
            body: "A cooler, quieter, darker room can make settling in feel a little easier.",
            phase: .windDown,
            sourceIDs: ["nhlbi-healthy-sleep"]
        ),
        WindDownGuidanceItem(
            id: "daytime-shape",
            topic: .morning,
            title: "Give the day some daylight and movement",
            body: "Outdoor time and daytime movement can help give the day a clearer shape before evening arrives.",
            phase: nil,
            sourceIDs: ["nhlbi-healthy-sleep", "nhlbi-circadian-treatment"]
        )
    ]

    static func items(for topic: WindDownGuidanceTopic) -> [WindDownGuidanceItem] {
        items.filter { $0.topic == topic }
    }

    static func items(for phase: NightWatchPhase) -> [WindDownGuidanceItem] {
        // Unphased ideas belong in the source-linked guide, never in an active-night cue.
        items.filter { $0.phase == phase }
    }

    /// Returns one stable Home idea from the person's selected routines. The
    /// routine order is intentional: evening ideas are the primary Home
    /// context, with morning ideas as the finite fallback.
    static func homeGuidance(
        eveningRoutine: [WindDownRoutineStep],
        morningRoutine: [WindDownRoutineStep]
    ) -> WindDownGuidanceItem? {
        selectedGuidance(in: eveningRoutine, expectedPhase: .windDown)
            ?? selectedGuidance(in: morningRoutine, expectedPhase: .morningQuiet)
    }

    /// Returns one idea only when it belongs to the selected routine for the
    /// current Wind Down phase. Overnight and complete phases intentionally
    /// have no active guidance placement.
    static func activeGuidance(
        for phase: NightWatchPhase,
        plan: NightWatchPlan
    ) -> WindDownGuidanceItem? {
        switch phase {
        case .windDown:
            return selectedGuidance(in: plan.eveningRoutine, expectedPhase: .windDown)
        case .morningQuiet:
            return selectedGuidance(in: plan.morningRoutine, expectedPhase: .morningQuiet)
        case .overnight, .complete:
            return nil
        }
    }

    static func featured(for phase: NightWatchPhase, seed: UUID) -> WindDownGuidanceItem? {
        let choices = items(for: phase)
        guard !choices.isEmpty else { return nil }
        let seedValue = seed.uuidString.unicodeScalars.reduce(UInt(0)) { partial, scalar in
            (partial &* 31) &+ UInt(scalar.value)
        }
        return choices[Int(seedValue % UInt(choices.count))]
    }

    private static func selectedGuidance(
        in routine: [WindDownRoutineStep],
        expectedPhase: NightWatchPhase
    ) -> WindDownGuidanceItem? {
        routine.lazy
            .compactMap { step -> WindDownGuidanceItem? in
                guard let guidanceID = step.guidanceID,
                      let item = items.first(where: { $0.id == guidanceID }),
                      item.phase == expectedPhase else {
                    return nil
                }
                return item
            }
            .first
    }
}
