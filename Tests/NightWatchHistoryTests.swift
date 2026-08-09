import XCTest

final class NightWatchHistoryTests: XCTestCase {
    func testPhoneBedRegistrationMatchesOnlyItsRegisteredTag() {
        let registration = PhoneBedTagRegistration(
            id: UUID(),
            tokenDigest: "registered-tag",
            registeredAt: Date()
        )

        XCTAssertTrue(registration.matches(scannedDigest: "registered-tag"))
        XCTAssertFalse(registration.matches(scannedDigest: "another-tag"))
    }

    func testHistoryDeduplicatesIdempotentEventsAndOrdersByOccurrence() {
        let runID = UUID()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var history = NightWatchHistory(now: start)

        history.append(
            RitualEvent(
                runID: runID,
                occurredAt: start.addingTimeInterval(30),
                recordedAt: start.addingTimeInterval(31),
                kind: .placementConfirmed,
                source: .observed,
                idempotencyKey: "\(runID):placement"
            ),
            now: start
        )
        history.append(
            RitualEvent(
                runID: runID,
                occurredAt: start,
                recordedAt: start.addingTimeInterval(32),
                kind: .sessionStarted,
                source: .observed,
                idempotencyKey: "\(runID):start"
            ),
            now: start
        )
        history.append(
            RitualEvent(
                runID: runID,
                occurredAt: start.addingTimeInterval(35),
                recordedAt: start.addingTimeInterval(36),
                kind: .placementConfirmed,
                source: .observed,
                idempotencyKey: "\(runID):placement"
            ),
            now: start
        )

        XCTAssertEqual(history.events(for: runID).map(\.kind), [.sessionStarted, .placementConfirmed])
    }

    func testHistoryUpsertsLatestRecordForRun() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let run = makeRun(startedAt: start)
        var history = NightWatchHistory(now: start)
        let active = run.nightWatchRecord(updatedAt: start)!
        var completed = active
        completed.outcome = .completed
        completed.endedAt = active.plan.protectedUntil
        completed.creditedWindDownMinutes = 30
        completed.creditedMorningQuietMinutes = 30
        completed.updatedAt = active.plan.protectedUntil

        history.upsert(active, now: start)
        history.upsert(completed, now: active.plan.protectedUntil)

        XCTAssertEqual(history.records.count, 1)
        XCTAssertEqual(history.record(for: run.id)?.outcome, .completed)
        XCTAssertEqual(history.record(for: run.id)?.creditedWindDownMinutes, 30)
    }

    func testHistoryDropsDetailedDataOlderThanRetentionWindow() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let oldDate = now.addingTimeInterval(-TimeInterval(100 * 24 * 60 * 60))
        let oldRun = makeRun(startedAt: oldDate)
        let recentRun = makeRun(startedAt: now)
        let history = NightWatchHistory(
            records: [
                oldRun.nightWatchRecord(updatedAt: oldDate)!,
                recentRun.nightWatchRecord(updatedAt: now)!
            ],
            events: [
                RitualEvent(
                    runID: oldRun.id,
                    occurredAt: oldDate,
                    recordedAt: oldDate,
                    kind: .sessionStarted,
                    source: .observed
                ),
                RitualEvent(
                    runID: recentRun.id,
                    occurredAt: now,
                    recordedAt: now,
                    kind: .sessionStarted,
                    source: .observed
                )
            ],
            now: now
        )

        XCTAssertNil(history.record(for: oldRun.id))
        XCTAssertNotNil(history.record(for: recentRun.id))
        XCTAssertTrue(history.events(for: oldRun.id).isEmpty)
    }

    func testNightWatchRecordLegacyDecodeDefaultsNewProtectionFields() throws {
        let run = makeRun(startedAt: Date(timeIntervalSince1970: 1_800_000_000))
        let record = run.nightWatchRecord()!
        let encoded = try JSONEncoder().encode(record)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "shieldedWindDownMinutes")
        object.removeValue(forKey: "shieldedMorningQuietMinutes")
        object.removeValue(forKey: "shieldProtectionEvidence")
        object.removeValue(forKey: "briefAccessUseCount")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(NightWatchRecord.self, from: legacyData)

        XCTAssertEqual(decoded.shieldedWindDownMinutes, 0)
        XCTAssertEqual(decoded.shieldedMorningQuietMinutes, 0)
        XCTAssertEqual(decoded.shieldProtectionEvidence, .notRequested)
        XCTAssertEqual(decoded.briefAccessUseCount, 0)
    }

    private func makeRun(startedAt: Date) -> FocusRun {
        let plan = NightWatchPlan(
            intendedBedtime: startedAt.addingTimeInterval(30 * 60),
            wakeTime: startedAt.addingTimeInterval(8 * 60 * 60),
            protectedUntil: startedAt.addingTimeInterval(8.5 * 60 * 60),
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
        return FocusRun(
            plannedDurationSeconds: plan.protectedUntil.timeIntervalSince(startedAt),
            startedAt: startedAt,
            state: .running,
            guardKind: .nfcTag,
            nightWatchPlan: plan
        )
    }
}
