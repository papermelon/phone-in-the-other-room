import Foundation

enum NightJourneySegment: String, Codable, CaseIterable, Equatable {
    case prairie
    case mountain
    case moonlit
    case sunrise

    var title: String {
        switch self {
        case .prairie: return "The prairie path"
        case .mountain: return "The mountain pass"
        case .moonlit: return "The moonlit trail"
        case .sunrise: return "The way home"
        }
    }
}

struct NightJourneyProgress: Equatable {
    let overallFraction: Double
    let phaseFraction: Double
    let segmentFraction: Double
    let segment: NightJourneySegment
    let phase: NightWatchPhase
    let nextTransition: Date?

    /// Compatibility for existing callers while progress is now phase-aware.
    var fraction: Double { overallFraction }

    static func resolve(run: FocusRun, at date: Date) -> Self? {
        guard let plan = run.nightWatchPlan else { return nil }
        let overallStart = plan.role == .additionalQuiet
            ? max(run.startedAt, plan.intendedBedtime)
            : max(run.startedAt, plan.intendedBedtime.addingTimeInterval(TimeInterval(-plan.windDownMinutes * 60)))
        let overall = normalized(date, from: overallStart, to: plan.protectedUntil)
        let phase = plan.phase(at: date)

        let phaseBounds: (Date, Date)
        switch phase {
        case .windDown:
            let plannedStart = plan.role == .additionalQuiet
                ? plan.intendedBedtime
                : plan.intendedBedtime.addingTimeInterval(TimeInterval(-plan.windDownMinutes * 60))
            phaseBounds = (max(run.startedAt, plannedStart), plan.role == .additionalQuiet ? plan.protectedUntil : plan.intendedBedtime)
        case .overnight:
            phaseBounds = (max(run.startedAt, plan.intendedBedtime), plan.wakeTime)
        case .morningQuiet:
            phaseBounds = (max(run.startedAt, plan.wakeTime), plan.protectedUntil)
        case .complete:
            phaseBounds = (plan.protectedUntil, plan.protectedUntil)
        }
        let phaseProgress = phase == .complete ? 1 : normalized(date, from: phaseBounds.0, to: phaseBounds.1)

        let segment: NightJourneySegment
        let segmentProgress: Double
        switch phase {
        case .windDown:
            if phaseProgress < 0.5 {
                segment = .prairie
                segmentProgress = phaseProgress / 0.5
            } else {
                segment = .mountain
                segmentProgress = (phaseProgress - 0.5) / 0.5
            }
        case .overnight:
            segment = .moonlit
            segmentProgress = phaseProgress
        case .morningQuiet, .complete:
            segment = .sunrise
            segmentProgress = phaseProgress
        }

        return Self(
            overallFraction: overall,
            phaseFraction: phaseProgress,
            segmentFraction: min(1, max(0, segmentProgress)),
            segment: segment,
            phase: phase,
            nextTransition: plan.nextTransition(after: date)
        )
    }

    private static func normalized(_ date: Date, from start: Date, to end: Date) -> Double {
        let duration = end.timeIntervalSince(start)
        guard duration > 0 else { return date > start ? 1 : 0 }
        return min(1, max(0, date.timeIntervalSince(start) / duration))
    }
}
