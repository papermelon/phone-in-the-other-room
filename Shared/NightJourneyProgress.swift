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
    /// A visual trail marker, not physical-distance or reward accounting.
    static let illustratedTrailMiles = 1.2

    let fraction: Double
    let segment: NightJourneySegment

    var illustratedMiles: Double {
        fraction * Self.illustratedTrailMiles
    }

    static func resolve(plan: NightWatchPlan, at date: Date) -> Self {
        let start = plan.role == .additionalQuiet
            ? plan.intendedBedtime
            : plan.intendedBedtime.addingTimeInterval(TimeInterval(-plan.windDownMinutes * 60))
        let end = max(start, plan.protectedUntil)
        let duration = max(1, end.timeIntervalSince(start))
        let fraction = min(1, max(0, date.timeIntervalSince(start) / duration))
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
