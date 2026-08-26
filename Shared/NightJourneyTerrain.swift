import Foundation

struct NightJourneyTerrainProfile: Equatable {
    let baseline: Double
    let primaryAmplitude: Double
    let secondaryAmplitude: Double
    let phase: Double

    func normalizedHeight(at position: Double) -> Double {
        let x = wrapped(position)
        let primary = sin(2 * .pi * x + phase) * primaryAmplitude
        let secondary = sin(4 * .pi * x + phase * 0.6) * secondaryAmplitude
        return min(0.88, max(0.64, baseline + primary + secondary))
    }

    func normalizedSlope(at position: Double) -> Double {
        let x = wrapped(position)
        return cos(2 * .pi * x + phase) * 2 * .pi * primaryAmplitude
            + cos(4 * .pi * x + phase * 0.6) * 4 * .pi * secondaryAmplitude
    }

    private func wrapped(_ position: Double) -> Double {
        let remainder = position.truncatingRemainder(dividingBy: 1)
        return remainder >= 0 ? remainder : remainder + 1
    }

    static func profile(for segment: NightJourneySegment) -> Self {
        switch segment {
        case .prairie: return Self(baseline: 0.76, primaryAmplitude: 0.018, secondaryAmplitude: 0.008, phase: 0.4)
        case .mountain: return Self(baseline: 0.76, primaryAmplitude: 0.065, secondaryAmplitude: 0.020, phase: 0.9)
        case .moonlit: return Self(baseline: 0.79, primaryAmplitude: 0.014, secondaryAmplitude: 0.006, phase: 1.7)
        case .sunrise: return Self(baseline: 0.76, primaryAmplitude: 0.030, secondaryAmplitude: 0.010, phase: 2.2)
        }
    }
}
