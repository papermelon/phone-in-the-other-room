import Foundation

/// Tracks the one-time schedule entry created while an ad-hoc start is waiting
/// for the person's final start decision.
struct WindDownStartTransaction: Equatable {
    let createdOneTimePeriodID: UUID?

    init(createdOneTimePeriodID: UUID? = nil) {
        self.createdOneTimePeriodID = createdOneTimePeriodID
    }

    @discardableResult
    func cancel(in schedule: inout WindDownScheduleState) -> Bool {
        guard let createdOneTimePeriodID else { return false }
        return schedule.removeOneTimePeriod(id: createdOneTimePeriodID)
    }
}
