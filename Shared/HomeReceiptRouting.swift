import Foundation

/// Pure Home precedence. A hidden Wind Down payload is never an input to this
/// route: only terminal delivery and receipt read markers may influence Home.
enum HomeReceiptRoute: Equatable {
    case activeScreenFreeMorning(UUID)
    case deferredScreenFreeMorning(occurrenceID: UUID, unreadWindDownRunID: UUID?)
    case terminalWindDownReceipt(UUID)
    case activeWindDown
    case unreadWindDownReceipt(UUID)
    case dashboard
}

enum HomeReceiptRouting {
    static func route(
        activeRun: FocusRun?,
        journal: WindDownMorningSettlementJournal
    ) -> HomeReceiptRoute {
        if let active = journal.morningOccurrences
            .filter({ $0.outcome == .active })
            .sorted(by: { $0.scheduledStart < $1.scheduledStart })
            .first {
            return .activeScreenFreeMorning(active.id)
        }
        let unread = journal.oldestUnreadDeliveredBenefit?.runID
        if let deferred = journal.morningOccurrences
            .filter({ $0.outcome == .scheduled })
            .sorted(by: { $0.scheduledStart < $1.scheduledStart })
            .first {
            return .deferredScreenFreeMorning(occurrenceID: deferred.id, unreadWindDownRunID: unread)
        }
        if let activeRun, activeRun.state == .completed || activeRun.state == .endedEarly {
            return .terminalWindDownReceipt(activeRun.id)
        }
        if let activeRun, ![.setup, .completed, .endedEarly].contains(activeRun.state) {
            return .activeWindDown
        }
        if let unread { return .unreadWindDownReceipt(unread) }
        return .dashboard
    }
}
