import Foundation

enum AutomaticWindDownSchedulingDecision: Equatable {
    case preserveActiveRun
    case cancelIneligibleSchedule
    case cancelMissingWindDownTag
    case schedule

    static func resolve(
        isRunActive: Bool,
        isConfigured: Bool,
        hasAutomaticRoutine: Bool,
        guardKind: SessionGuardKind,
        hasWindDownTag: Bool
    ) -> Self {
        if isRunActive {
            return .preserveActiveRun
        }
        guard isConfigured, hasAutomaticRoutine else {
            return .cancelIneligibleSchedule
        }
        if guardKind == .nfcTag, !hasWindDownTag {
            return .cancelMissingWindDownTag
        }
        return .schedule
    }
}
