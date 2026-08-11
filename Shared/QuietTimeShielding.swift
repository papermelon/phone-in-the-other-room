import Foundation

enum QuietTimeShieldingOutcome: Equatable {
    case disabled
    case noSelection
    case scheduled
    case applied
    case cleared
    case failed(String)
}

enum QuietTimeShieldingPolicy {
    static func shouldShield(run: FocusRun?, at date: Date, isEnabled: Bool) -> Bool {
        guard isEnabled, let run,
              ![.setup, .completed, .endedEarly].contains(run.state) else { return false }
        if run.guardKind == .nfcTag && run.placementStatus != .confirmed {
            return false
        }
        guard date >= run.startedAt, date < run.plannedEndAt else { return false }
        return true
    }
}
