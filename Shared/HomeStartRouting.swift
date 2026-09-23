import Foundation

/// A one-shot navigation intent emitted only after the phone-authoritative
/// coordinator has admitted a run. It lets the shell reveal the run without
/// making navigation another owner of session state.
struct HomeStartAdmission: Equatable, Identifiable {
    let id: UUID
}

enum HomeStartRoutingPolicy {
    /// Prefer the nightly ritual when the default Phone Away would cross its
    /// start. This is manual admission only; automatic scheduling stays exact.
    static func windDownPeriod(
        in schedule: WindDownScheduleState,
        at now: Date,
        calendar: Calendar = .current,
        primaryExtensionMinutes: Int = 0
    ) -> WindDownSchedulePeriod? {
        if let active = WindDownScheduleEngine.eligibleOccurrences(
            in: schedule, at: now, calendar: calendar,
            primaryExtensionMinutes: primaryExtensionMinutes
        ).first(where: { $0.occurrence.role == .primarySleepBookend }) {
            return active
        }
        // Filter first so unrelated Phone Away entries cannot hide the next night.
        let primarySchedule = WindDownScheduleState(
            oneTimePeriods: schedule.oneTimePeriods.filter { $0.role == .primarySleepBookend },
            routines: schedule.routines.filter { $0.role == .primarySleepBookend }
        )
        guard let next = primarySchedule.upcomingPeriods(
            after: now, calendar: calendar,
            primaryExtensionMinutes: primaryExtensionMinutes, limit: 1
        ).first,
              next.occurrence.interval.start < now.addingTimeInterval(
                TimeInterval(PhoneAwayDurationPolicy.defaultMinutes * 60)
              ) else { return nil }
        return next
    }

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
