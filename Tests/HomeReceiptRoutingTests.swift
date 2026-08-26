import XCTest

final class HomeReceiptRoutingTests: XCTestCase {
    func testActiveMorningWinsOverUnreadWindDownReceipt() {
        let runID = UUID()
        let now = Date(timeIntervalSince1970: 1_000)
        let occurrence = MorningQuietOccurrence(
            scheduledStart: now, scheduledEnd: now.addingTimeInterval(30 * 60), actualStart: now, outcome: .active
        )
        let journal = WindDownMorningSettlementJournal(
            windDownBenefits: [WindDownBenefitSettlement(runID: runID, entitledAt: now, phoneAwaySpanMinutes: 420, deliveredAt: now)],
            morningOccurrences: [occurrence]
        )
        XCTAssertEqual(HomeReceiptRouting.route(activeRun: nil, journal: journal), .activeScreenFreeMorning(occurrence.id))
    }

    func testDeferredMorningKeepsUnreadReceiptRecoverable() {
        let runID = UUID()
        let now = Date(timeIntervalSince1970: 1_000)
        let occurrence = MorningQuietOccurrence(
            scheduledStart: now.addingTimeInterval(60 * 60), scheduledEnd: now.addingTimeInterval(90 * 60), outcome: .scheduled
        )
        let journal = WindDownMorningSettlementJournal(
            windDownBenefits: [WindDownBenefitSettlement(runID: runID, entitledAt: now, phoneAwaySpanMinutes: 420, deliveredAt: now)],
            morningOccurrences: [occurrence]
        )
        XCTAssertEqual(
            HomeReceiptRouting.route(activeRun: nil, journal: journal),
            .deferredScreenFreeMorning(occurrenceID: occurrence.id, unreadWindDownRunID: runID)
        )
    }

    func testHiddenBenefitNeverRoutesAsUnreadReceipt() {
        let runID = UUID()
        let now = Date(timeIntervalSince1970: 1_000)
        let journal = WindDownMorningSettlementJournal(
            windDownBenefits: [WindDownBenefitSettlement(runID: runID, entitledAt: now, phoneAwaySpanMinutes: 420)]
        )
        XCTAssertEqual(HomeReceiptRouting.route(activeRun: nil, journal: journal), .dashboard)
    }

    func testTerminalRunRoutesToItsFiniteReceiptBeforeDashboard() {
        let now = Date(timeIntervalSince1970: 1_000)
        let run = FocusRun(
            plannedDurationSeconds: 60,
            startedAt: now,
            state: .completed,
            guardKind: .honorTimer
        )
        XCTAssertEqual(
            HomeReceiptRouting.route(activeRun: run, journal: .init()),
            .terminalWindDownReceipt(run.id)
        )
    }
}
