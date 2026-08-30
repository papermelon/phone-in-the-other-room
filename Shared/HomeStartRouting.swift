import Foundation

/// A one-shot navigation intent emitted only after the phone-authoritative
/// coordinator has admitted a run. It lets the shell reveal the run without
/// making navigation another owner of session state.
struct HomeStartAdmission: Equatable, Identifiable {
    let id: UUID
}

enum HomeStartRoutingPolicy {
    static func windDownHeading(
        intendedBedtime: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        guard let intendedBedtime,
              intendedBedtime > now,
              calendar.isDate(intendedBedtime, inSameDayAs: now) else {
            return "WIND DOWN"
        }
        return "TONIGHT"
    }

    static func admission(for result: FocusSessionStartResult) -> HomeStartAdmission? {
        guard case let .started(run) = result else { return nil }
        return HomeStartAdmission(id: run.id)
    }

    static func shouldRoute(
        admission: HomeStartAdmission?,
        activeRunID: UUID?
    ) -> Bool {
        guard let admission, let activeRunID else { return false }
        return admission.id == activeRunID
    }
}
