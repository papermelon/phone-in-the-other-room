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

enum AutomaticWindDownStatusPresentation: Equatable {
    case off
    case scheduled(Date)
    case needsRepair(title: String, detail: String)
    case preparing

    static func resolve(
        enabled: Bool,
        scheduledStart: Date?,
        repairNeeded: Bool,
        readiness: ShieldingReadiness
    ) -> Self {
        guard enabled else { return .off }
        // A current, actionable prerequisite takes priority over a historical
        // failure marker so repair names the step the person can take now.
        if readiness != .ready {
            return .needsRepair(title: readiness.title, detail: readiness.detail)
        }
        if repairNeeded {
            return .needsRepair(
                title: "Automatic Wind Down needs repair",
                detail: "The last automatic start could not prepare or request app protection. Review your selection, then retry automatic scheduling."
            )
        }
        if let scheduledStart { return .scheduled(scheduledStart) }
        return .preparing
    }

    var title: String {
        switch self {
        case .off: return "Automatic Wind Down is off"
        case .scheduled: return "Automatic Wind Down is ready"
        case let .needsRepair(title, _): return title
        case .preparing: return "Preparing the next automatic start"
        }
    }

    var detail: String {
        switch self {
        case .off:
            return "A reminder can still invite you to begin with Put phone away."
        case let .scheduled(start):
            return "Next automatic start: \(OllieFormat.dateAndTime(start)). Selected-app limits are scheduled with it."
        case let .needsRepair(_, detail):
            return "Automatic start is waiting. \(detail)"
        case .preparing:
            return "The next eligible repeating Wind Down will appear here after its local schedule is installed."
        }
    }

    var needsRepair: Bool {
        if case .needsRepair = self { return true }
        return false
    }
}

/// Only a successfully installed future monitor admits the automatic timer.
/// Readiness and an attempted installation do not establish a schedule.
enum AutomaticWindDownInstallationDecision {
    static func canSaveSchedule(after outcome: QuietTimeShieldingOutcome) -> Bool {
        outcome == .scheduled
    }
}
