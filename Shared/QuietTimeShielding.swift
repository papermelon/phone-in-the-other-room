import Foundation

enum QuietTimeShieldingOutcome: Equatable {
    case disabled
    case noSelection
    case scheduled
    case applied
    case cleared
    case failed(String)
}

enum QuietTimeShieldingIntentPolicy {
    /// Readiness (authorization and selection) is intentionally not folded into
    /// this durable preference. Missing storage is the recommended default;
    /// only an explicit saved false opts out.
    static func savedIntent(_ value: Bool?) -> Bool {
        value ?? true
    }
}

enum QuietTimeShieldingPolicy {
    static func shouldShield(run: FocusRun?, at date: Date, isEnabled: Bool) -> Bool {
        // `isEnabled` is retained for source compatibility with older callers;
        // active-run intent is immutable and lives on FocusRun.
        _ = isEnabled
        guard let run,
              run.appShieldingRequested,
              ![.setup, .completed, .endedEarly].contains(run.state) else { return false }
        if run.guardKind == .nfcTag && run.placementStatus != .confirmed {
            return false
        }
        guard date >= run.startedAt, date < run.plannedEndAt else { return false }
        return true
    }
}
