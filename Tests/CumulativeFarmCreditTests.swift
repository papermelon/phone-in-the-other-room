import XCTest

final class CumulativeFarmCreditTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 100_000)

    private func run(minutes: Double, offset: Double = 0, phoneAway: Bool = false) -> FocusRun {
        let began = start.addingTimeInterval(offset * 60)
        let plan = NightWatchPlan(intendedBedtime: began, wakeTime: began.addingTimeInterval(12 * 3600),
            protectedUntil: began.addingTimeInterval(12 * 3600), windDownMinutes: 30, morningQuietMinutes: 0,
            eveningActivity: .read, morningActivity: .openCurtains,
            role: phoneAway ? .additionalQuiet : .primarySleepBookend)
        var run = FocusRun(plannedDurationSeconds: 12 * 3600, startedAt: began, state: .endedEarly, nightWatchPlan: plan)
        run.endedAt = began.addingTimeInterval(minutes * 60)
        return run
    }

    private func farm() -> FarmState {
        var farm = FarmState.empty
        farm.migrateCumulativeCredit(records: [], searchState: .empty, protectedNightCount: 0)
        return farm
    }

    func testFiveHoursThirtyEightMinutesSurvivesEarlyEnding() throws {
        var farm = farm()
        let run = run(minutes: 338)
        farm.settleCumulativeCredit(run: run, searchState: .empty)
        XCTAssertEqual(farm.cumulativeCredit?.receipts[run.id]?.creditedSeconds, 338 * 60)
        XCTAssertEqual(farm.cumulativeCredit?.windDownSeconds, 338 * 60)
        XCTAssertEqual(farm.cumulativeCredit?.outcomes.count, 0)
    }

    func testCarryAcrossNightsFindsSheepAndReplayingSaveCannotDuplicate() throws {
        var farm = farm()
        let first = run(minutes: 338)
        let second = run(minutes: 82, offset: 1440)
        farm.settleCumulativeCredit(run: first, searchState: .empty)
        farm = try JSONDecoder().decode(FarmState.self, from: JSONEncoder().encode(farm))
        farm.settleCumulativeCredit(run: second, searchState: .empty)
        XCTAssertEqual(farm.cumulativeCredit?.windDownSeconds, 0)
        XCTAssertEqual(farm.sheep.count, 1)
        let saved = farm
        farm.settleCumulativeCredit(run: second, searchState: .empty)
        farm.settleCumulativeCredit(run: first, searchState: .empty)
        XCTAssertEqual(farm, saved)
    }

    func testAccessIntervalsAreClippedMergedAndExcludedOnce() {
        var farm = farm()
        var run = run(minutes: 60)
        run.briefAccessUseCount = 3
        run.briefAccessIntervals = [
            DateInterval(start: start.addingTimeInterval(-60), end: start.addingTimeInterval(120)),
            DateInterval(start: start.addingTimeInterval(60), end: start.addingTimeInterval(180)),
            DateInterval(start: start.addingTimeInterval(3500), end: start.addingTimeInterval(3800))
        ]
        farm.settleCumulativeCredit(run: run, searchState: .empty)
        XCTAssertEqual(farm.cumulativeCredit?.receipts[run.id]?.excludedAccessSeconds, 280)
        XCTAssertEqual(farm.cumulativeCredit?.windDownSeconds, 3320)
    }

    func testOverlappingDifferentRunIDsCannotCreditSameTimeTwice() {
        var farm = farm()
        farm.settleCumulativeCredit(run: run(minutes: 60), searchState: .empty)
        farm.settleCumulativeCredit(run: run(minutes: 60, offset: 30), searchState: .empty)
        XCTAssertEqual(farm.cumulativeCredit?.windDownSeconds, 90 * 60)
    }

    func testOverlappingModesCannotCreditSameTimeTwice() {
        var farm = farm()
        farm.settleCumulativeCredit(run: run(minutes: 60), searchState: .empty)
        farm.settleCumulativeCredit(run: run(minutes: 60, phoneAway: true), searchState: .empty)
        XCTAssertEqual(farm.cumulativeCredit?.phoneAwaySeconds, 0)
    }

    func testPhoneAwayShortEarlySessionsAccumulateWithoutWindDownGate() {
        var farm = farm()
        for n in 0..<20 {
            farm.settleCumulativeCredit(run: run(minutes: 5, offset: Double(n * 10), phoneAway: true), searchState: .empty)
        }
        XCTAssertEqual(farm.cumulativeCredit?.phoneAwaySeconds, 0)
        XCTAssertEqual(farm.cumulativeCredit?.outcomes.first?.origin, .phoneBreak)
        XCTAssertEqual(farm.sheep.count, 1)
    }

    func testMultipleSearchesCarryRemainderAndReplayDeterministically() throws {
        var farm = farm()
        let run = run(minutes: 250, phoneAway: true)
        let initial = farm
        farm.settleCumulativeCredit(run: run, searchState: .empty)
        var retry = initial
        retry.settleCumulativeCredit(run: run, searchState: .empty)
        XCTAssertEqual(farm.cumulativeCredit?.outcomes, retry.cumulativeCredit?.outcomes)
        XCTAssertEqual(farm.sheep.count, 2)
        XCTAssertEqual(farm.cumulativeCredit?.phoneAwaySeconds, 50 * 60)
        var search = SheepSearchState.empty
        for outcome in farm.cumulativeCredit?.outcomes ?? [] { search.append(outcome) }
        for outcome in farm.cumulativeCredit?.outcomes ?? [] { search.append(outcome) }
        XCTAssertEqual(search.outcomes.count, 2)
    }

    func testMissingAccessTimestampsNeverBecomeUnexcludedCredit() {
        var farm = farm()
        let first = run(minutes: 60)
        farm.settleCumulativeCredit(run: first, searchState: .empty)
        var missing = run(minutes: 120, offset: 1440)
        missing.briefAccessUseCount = 1
        farm.settleCumulativeCredit(run: missing, searchState: .empty)
        XCTAssertEqual(farm.cumulativeCredit?.windDownSeconds, 3600)
        XCTAssertEqual(farm.cumulativeCredit?.receipts[missing.id]?.trackingIncomplete, true)
    }

    func testSubminuteTimeCarriesAndPlannedEndCapsRecovery() {
        var farm = farm()
        farm.settleCumulativeCredit(run: run(minutes: 0.5), searchState: .empty)
        farm.settleCumulativeCredit(run: run(minutes: 0.5, offset: 1), searchState: .empty)
        XCTAssertEqual(farm.cumulativeCredit?.windDownSeconds, 60)
        var late = run(minutes: 900, offset: 1440)
        late.plannedEndAt = late.startedAt.addingTimeInterval(600)
        farm.settleCumulativeCredit(run: late, searchState: .empty)
        XCTAssertEqual(farm.cumulativeCredit?.receipts[late.id]?.creditedSeconds, 600)
    }

    func testMorningWindowDoesNotAlsoEarnWindDownCredit() {
        var farm = farm()
        var attempt = run(minutes: 90)
        attempt.nightWatchPlan?.wakeTime = start.addingTimeInterval(3600)
        attempt.nightWatchPlan?.morningQuietMinutes = 30
        farm.settleCumulativeCredit(run: attempt, searchState: .empty)
        XCTAssertEqual(farm.cumulativeCredit?.receipts[attempt.id]?.creditedSeconds, 3600)
    }

    func testReceiptIdentitySurvivesMoreThanLegacyLedgerLimit() throws {
        var farm = farm()
        let first = run(minutes: 1)
        farm.settleCumulativeCredit(run: first, searchState: .empty)
        for n in 1...150 {
            farm.settleCumulativeCredit(run: run(minutes: 1, offset: Double(n * 2)), searchState: .empty)
        }
        farm = try JSONDecoder().decode(FarmState.self, from: JSONEncoder().encode(farm))
        let saved = farm
        farm.settleCumulativeCredit(run: first, searchState: .empty)
        XCTAssertEqual(farm, saved)
    }

    func testAccessHistorySurvivesLongRunAndSameRunRevisionRollover() throws {
        let id = UUID()
        let uses = (0..<25).map { index in
            QuietTimeBriefAccessUse(nonce: UUID(), requestedAt: start.addingTimeInterval(Double(index * 600)),
                expiresAt: start.addingTimeInterval(Double(index * 600 + 300)))
        }
        var state = QuietTimeBriefAccessState(runID: id, scheduleRevision: 1,
            successfulUseCount: uses.count, successfulUses: uses, updatedAt: start)
        state = try JSONDecoder().decode(QuietTimeBriefAccessState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(state.successfulUses.count, 25)
        state.carryingLedgerForward(to: id, revision: 2, at: start.addingTimeInterval(20_000))
        state.successfulUses = [QuietTimeBriefAccessUse(nonce: UUID(), requestedAt: start.addingTimeInterval(20_100),
            expiresAt: start.addingTimeInterval(20_400))]
        state.successfulUseCount = 1
        state.archiveCurrentRun(at: start.addingTimeInterval(20_400))
        XCTAssertEqual(state.completedRunCounts.first?.uses?.count, 26)
        XCTAssertEqual(state.durableCount(for: id), 26)
        state.archiveCurrentRun(at: start.addingTimeInterval(20_500))
        XCTAssertEqual(state.completedRunCounts.first?.uses?.count, 26)
    }

    func testPracticeAndActiveSessionsDoNotGrant() {
        var farm = farm()
        var attempt = run(minutes: 500)
        attempt.isPractice = true
        farm.settleCumulativeCredit(run: attempt, searchState: .empty)
        attempt.isPractice = false
        attempt.state = .running
        farm.settleCumulativeCredit(run: attempt, searchState: .empty)
        XCTAssertEqual(farm.cumulativeCredit?.receipts.count, 0)
    }

    func testPartialCreditVisiblyRegrowsWoolAndShearingResetsOnlyThatSheep() throws {
        var farm = farm()
        farm.settleCumulativeCredit(run: run(minutes: 420), searchState: .empty)
        let sheep = try XCTUnwrap(farm.sheep.first)
        _ = try farm.shear(sheepID: sheep.id, protectedNightCount: 0, at: start.addingTimeInterval(420 * 60))
        farm.settleCumulativeCredit(run: run(minutes: 338, offset: 1440), searchState: .empty)
        XCTAssertEqual(FarmEconomyRules.woolVisualState(for: farm.sheep[0], protectedNightCount: 0), .regrowing)
        XCTAssertEqual(farm.sheep[0].regrowthSecondsRemaining, 502 * 60)
        XCTAssertEqual(farm.sheep[0].timesSheared, 1)
    }

    func testLegacyDecodeAndMigrationAreIdempotent() throws {
        let old = try JSONEncoder().encode(FarmState.empty)
        var farm = try JSONDecoder().decode(FarmState.self, from: old)
        let early = run(minutes: 338)
        let record = NightWatchRecord(id: early.id, plan: try XCTUnwrap(early.nightWatchPlan), startedAt: early.startedAt,
            endedAt: early.endedAt, startMethod: .honorTimer, outcome: .endedEarly, isPractice: false)
        farm.migrateCumulativeCredit(records: [record], searchState: .empty, protectedNightCount: 0)
        XCTAssertEqual(farm.cumulativeCredit?.windDownSeconds, 338 * 60)
        let migrated = farm
        farm.migrateCumulativeCredit(records: [record], searchState: .empty, protectedNightCount: 0)
        XCTAssertEqual(farm, migrated)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(early)) as? [String: Any])
        json.removeValue(forKey: "farmCreditVersion")
        json.removeValue(forKey: "briefAccessIntervals")
        let legacy = try JSONDecoder().decode(FocusRun.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(legacy.farmCreditVersion, 0)
        XCTAssertEqual(legacy.briefAccessIntervals, [])
    }

    func testMigrationPreservesCompletedRewardsAndRejectsAmbiguousHistory() throws {
        var farm = FarmState.empty
        let run = run(minutes: 420)
        let plan = try XCTUnwrap(run.nightWatchPlan)
        let completed = NightWatchRecord(id: run.id, plan: plan, startedAt: run.startedAt, endedAt: run.endedAt,
            startMethod: .honorTimer, outcome: .completed, isPractice: false)
        let overlapping = NightWatchRecord(id: UUID(), plan: plan, startedAt: run.startedAt, endedAt: run.endedAt,
            startMethod: .honorTimer, outcome: .endedEarly, isPractice: false)
        let unknown = NightWatchRecord(id: UUID(), plan: plan, startedAt: start.addingTimeInterval(86400),
            endedAt: start.addingTimeInterval(90000), startMethod: .honorTimer, outcome: .endedEarly, briefAccessUseCount: 1)
        farm.migrateCumulativeCredit(records: [completed, overlapping, unknown], searchState: .empty, protectedNightCount: 3)
        XCTAssertEqual(farm.cumulativeCredit?.windDownSeconds, 0)
        XCTAssertEqual(farm.sheep.count, 0)
        XCTAssertNil(farm.cumulativeCredit?.receipts[unknown.id])
    }
}
