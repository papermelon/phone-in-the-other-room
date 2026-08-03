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
    let fraction: Double
    let segment: NightJourneySegment

    static func resolve(plan: NightWatchPlan, at date: Date) -> Self {
        let start = plan.role == .additionalQuiet
            ? plan.intendedBedtime
            : plan.intendedBedtime.addingTimeInterval(TimeInterval(-plan.windDownMinutes * 60))
        let end = max(start, plan.protectedUntil)
        let fraction = min(1, max(0, date.timeIntervalSince(start) / end.timeIntervalSince(start)))
        let segment: NightJourneySegment
        switch fraction {
        case ..<0.25: segment = .prairie
        case ..<0.55: segment = .mountain
        case ..<0.82: segment = .moonlit
        default: segment = .sunrise
        }
        return Self(fraction: fraction, segment: segment)
    }
}
