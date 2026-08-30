import Foundation

/// The final start admission is owned by the phone-authoritative coordinator.
/// Callers must not consume a schedule source or publish a start until this
/// result says that the new run was actually admitted.
enum FocusSessionStartRejection: Equatable {
    case activeRun(UUID)
    case activeScreenFreeMorning(UUID)
}

enum FocusSessionStartResult: Equatable {
    case started(FocusRun)
    case rejected(FocusSessionStartRejection)
}
