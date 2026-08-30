import Foundation

/// The action the person chose before protection repair or the final start
/// confirmation. Keeping it typed prevents a scheduled period from silently
/// becoming a manual Phone Away, or a manual start from borrowing a schedule.
enum PhoneAwayStartAction: Equatable {
    case manual(durationMinutes: Int)
    case scheduled(UUID)
}

enum PhoneAwayStartPreflight: Equatable {
    case ready(PhoneAwayStartAction)
    case needsProtectionRepair(PhoneAwayStartAction, ShieldingReadiness)
    case alreadyRunning

    var action: PhoneAwayStartAction? {
        switch self {
        case .ready(let action), .needsProtectionRepair(let action, _): return action
        case .alreadyRunning: return nil
        }
    }
}

enum PhoneAwayStartPolicy {
    static func preflight(
        action: PhoneAwayStartAction,
        isRunning: Bool,
        readiness: ShieldingReadiness
    ) -> PhoneAwayStartPreflight {
        guard !isRunning else { return .alreadyRunning }
        guard readiness == .ready else {
            return .needsProtectionRepair(action, readiness)
        }
        return .ready(action)
    }
}

/// The bounded choices shown before a manual Phone Away starts. The lower
/// bound is the same five-minute floor used by immediate-window scheduling;
/// the upper bound preserves the existing thirty-minute default window.
enum PhoneAwayDurationPolicy {
    static let defaultMinutes = Int(QuietPeriodPreset.general.duration / 60)
    static let minimumMinutes = Int(QuietPeriodScheduling.minimumImmediateDuration / 60)
    static let maximumMinutes = Int(QuietPeriodPreset.general.duration / 60)
    static let options = [5, 10, 15, 20, 25, 30]

    static func normalized(_ minutes: Int) -> Int {
        min(max(minutes, minimumMinutes), maximumMinutes)
    }

    static func label(for minutes: Int) -> String {
        "\(normalized(minutes)) minutes"
    }
}
