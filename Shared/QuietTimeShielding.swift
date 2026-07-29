import Foundation

enum QuietTimeShieldingPolicy {
    static func shouldShield(run: FocusRun?, at date: Date, isEnabled: Bool) -> Bool {
        guard isEnabled, let run,
              ![.setup, .completed, .endedEarly].contains(run.state) else { return false }
        switch run.nightWatchPhase(at: date) {
        case .windDown, .morningQuiet: return true
        case .overnight, .complete, nil: return false
        }
    }
}
