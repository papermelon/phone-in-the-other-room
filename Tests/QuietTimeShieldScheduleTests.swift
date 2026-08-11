import XCTest

final class QuietTimeShieldScheduleTests: XCTestCase {
    func testScheduleUsesRemainingWindDownAndFullMorningBookend() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = NightWatchPlan(
            intendedBedtime: start.addingTimeInterval(20 * 60),
            wakeTime: start.addingTimeInterval(8 * 60 * 60),
            protectedUntil: start.addingTimeInterval(8.5 * 60 * 60),
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
        let run = FocusRun(
            plannedDurationSeconds: plan.protectedUntil.timeIntervalSince(start),
            startedAt: start,
            state: .running,
            guardKind: .honorTimer,
            nightWatchPlan: plan
        )

        let snapshot = QuietTimeShieldScheduleBuilder.snapshot(
            for: run,
            revision: 2,
            updatedAt: start
        )

        XCTAssertEqual(snapshot?.revision, 2)
        XCTAssertEqual(snapshot?.windDownInterval?.duration, 20 * 60)
        XCTAssertEqual(snapshot?.morningQuietInterval.duration, 30 * 60)
        XCTAssertEqual(snapshot?.protectedSessionInterval?.duration, 8.5 * 60 * 60)
        XCTAssertTrue(snapshot?.contains(start.addingTimeInterval(5 * 60), in: .windDown) == true)
        XCTAssertFalse(snapshot?.contains(start.addingTimeInterval(4 * 60 * 60), in: .windDown) == true)
    }

    func testScheduleOmitsWindDownWhenRunBeginsAfterBedtime() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = NightWatchPlan(
            intendedBedtime: start.addingTimeInterval(-10 * 60),
            wakeTime: start.addingTimeInterval(7 * 60 * 60),
            protectedUntil: start.addingTimeInterval(7.5 * 60 * 60),
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
        let run = FocusRun(
            plannedDurationSeconds: plan.protectedUntil.timeIntervalSince(start),
            startedAt: start,
            state: .running,
            guardKind: .honorTimer,
            nightWatchPlan: plan
        )

        let snapshot = QuietTimeShieldScheduleBuilder.snapshot(for: run, revision: 1)

        XCTAssertNil(snapshot?.windDownInterval)
        XCTAssertEqual(snapshot?.protectedSessionInterval?.start, start)
        XCTAssertNotNil(snapshot?.morningQuietInterval)
        XCTAssertTrue(snapshot?.isEligible(at: start.addingTimeInterval(1)) == true)
    }

    func testLegacyScheduleSnapshotDefaultsToPrimaryWindDownAndMigratesSchema() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = QuietTimeShieldScheduleSnapshot(
            schemaVersion: 2,
            runID: UUID(),
            revision: 1,
            protectedSessionInterval: DateInterval(
                start: start,
                end: start.addingTimeInterval(8 * 60 * 60)
            ),
            windDownInterval: DateInterval(start: start, end: start.addingTimeInterval(30 * 60)),
            morningQuietInterval: DateInterval(
                start: start.addingTimeInterval(8 * 60 * 60),
                end: start.addingTimeInterval(8.5 * 60 * 60)
            ),
            updatedAt: start
        )
        let encoded = try JSONEncoder().encode(snapshot)
        var legacyObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "role")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)

        let decoded = try JSONDecoder().decode(
            QuietTimeShieldScheduleSnapshot.self,
            from: legacyData
        )

        XCTAssertEqual(decoded.role, .primaryWindDown)
        XCTAssertEqual(decoded.schemaVersion, QuietTimeShieldScheduleSnapshot.currentSchemaVersion)
    }

    func testAdditionalQuietPlanWritesAdditionalQuietShieldRole() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = NightWatchPlan.additionalQuiet(
            start: start,
            end: start.addingTimeInterval(30 * 60)
        )
        let run = FocusRun(
            plannedDurationSeconds: 30 * 60,
            startedAt: start,
            state: .running,
            guardKind: .honorTimer,
            nightWatchPlan: plan
        )

        let snapshot = QuietTimeShieldScheduleBuilder.snapshot(for: run, revision: 1)

        XCTAssertEqual(snapshot?.role, .additionalQuiet)
    }

    func testShieldScheduleWindowsIncludeRoleInEquality() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let interval = DateInterval(start: start, end: start.addingTimeInterval(30 * 60))
        let primary = QuietTimeShieldScheduleSnapshot(
            runID: UUID(),
            revision: 1,
            role: .primaryWindDown,
            protectedSessionInterval: interval,
            windDownInterval: interval,
            morningQuietInterval: interval,
            updatedAt: start
        )
        var additional = primary
        additional.role = .additionalQuiet

        XCTAssertFalse(primary.hasSameWindows(as: additional))
    }

    func testAutomaticScheduleRepeatsAtTheSameLocalTimeEachDay() {
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: 22, minute: 30, second: 0, of: Date())!
        let plan = NightWatchPlan(
            intendedBedtime: start.addingTimeInterval(30 * 60),
            wakeTime: start.addingTimeInterval(8 * 60 * 60),
            protectedUntil: start.addingTimeInterval(8.5 * 60 * 60),
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
        let schedule = AutomaticWindDownSchedule(startedAt: start, plan: plan)
        let snapshot = QuietTimeShieldScheduleBuilder.snapshot(for: schedule, revision: 1)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: start)!

        XCTAssertTrue(snapshot.repeatsDaily)
        XCTAssertTrue(snapshot.contains(nextDay.addingTimeInterval(5 * 60), in: .windDown))
        XCTAssertFalse(snapshot.contains(nextDay.addingTimeInterval(2 * 60 * 60), in: .windDown))
    }

    func testRepeatingScheduleCannotApplyBeforeItsFirstScheduledWindow() {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let start = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: tomorrow)!
        let plan = NightWatchPlan(
            intendedBedtime: start.addingTimeInterval(60 * 60),
            wakeTime: start.addingTimeInterval(9 * 60 * 60),
            protectedUntil: start.addingTimeInterval(9.5 * 60 * 60),
            windDownMinutes: 60,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
        let snapshot = QuietTimeShieldScheduleBuilder.snapshot(
            for: AutomaticWindDownSchedule(startedAt: start, plan: plan),
            revision: 1
        )

        let sameClockTimeToday = calendar.date(bySettingHour: 22, minute: 15, second: 0, of: Date())!
        XCTAssertTrue(snapshot.contains(sameClockTimeToday, in: .windDown))
        XCTAssertFalse(snapshot.isEligible(at: sameClockTimeToday))
        XCTAssertTrue(snapshot.isEligible(at: start))
    }

    func testStaleCallbackWindowStillReconcilesTheCurrentActiveWindow() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = QuietTimeShieldScheduleSnapshot(
            runID: UUID(),
            revision: 4,
            protectedSessionInterval: DateInterval(
                start: start,
                end: start.addingTimeInterval(8 * 60 * 60)
            ),
            windDownInterval: DateInterval(
                start: start,
                end: start.addingTimeInterval(30 * 60)
            ),
            morningQuietInterval: DateInterval(
                start: start.addingTimeInterval(8 * 60 * 60),
                end: start.addingTimeInterval(8.5 * 60 * 60)
            ),
            updatedAt: start,
            repeatsDaily: false
        )

        XCTAssertEqual(
            QuietTimeShieldSchedulePolicy.activeWindow(
                in: snapshot,
                at: start.addingTimeInterval(45 * 60)
            ),
            .protectedSession
        )
    }

    func testProtectionSummaryUsesObservedStatusWindows() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = NightWatchPlan(
            intendedBedtime: start.addingTimeInterval(30 * 60),
            wakeTime: start.addingTimeInterval(8 * 60 * 60),
            protectedUntil: start.addingTimeInterval(8.5 * 60 * 60),
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
        let run = FocusRun(
            plannedDurationSeconds: plan.protectedUntil.timeIntervalSince(start),
            startedAt: start,
            state: .completed,
            guardKind: .nfcTag,
            nightWatchPlan: plan
        )
        let statuses = [
            status(run: run, value: .applied, window: .windDown, at: start),
            status(run: run, value: .cleared, window: .windDown, at: plan.intendedBedtime),
            status(run: run, value: .applied, window: .morningQuiet, at: plan.wakeTime),
            status(run: run, value: .cleared, window: .morningQuiet, at: plan.protectedUntil)
        ]

        let summary = QuietTimeShieldEvidenceMath.summary(
            for: run,
            statuses: statuses,
            at: plan.protectedUntil
        )

        XCTAssertEqual(summary.windDownMinutes, 30)
        XCTAssertEqual(summary.morningQuietMinutes, 30)
        XCTAssertEqual(summary.evidence, .observed)
    }

    func testProtectionSummaryCanUseAutomaticScheduleEvidence() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = NightWatchPlan(
            intendedBedtime: start.addingTimeInterval(30 * 60),
            wakeTime: start.addingTimeInterval(8 * 60 * 60),
            protectedUntil: start.addingTimeInterval(8.5 * 60 * 60),
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
        let run = FocusRun(
            plannedDurationSeconds: plan.protectedUntil.timeIntervalSince(start),
            startedAt: start,
            state: .completed,
            guardKind: .nfcTag,
            nightWatchPlan: plan
        )
        let scheduleID = UUID()
        let statuses = [
            QuietTimeShieldStatusSnapshot(
                runID: scheduleID,
                revision: 1,
                status: .applied,
                window: .windDown,
                observedAt: start
            ),
            QuietTimeShieldStatusSnapshot(
                runID: scheduleID,
                revision: 1,
                status: .cleared,
                window: .windDown,
                observedAt: plan.intendedBedtime
            )
        ]

        let summary = QuietTimeShieldEvidenceMath.summary(
            for: run,
            statuses: statuses,
            at: plan.protectedUntil,
            additionalRunIDs: [scheduleID]
        )

        XCTAssertEqual(summary.windDownMinutes, 30)
        XCTAssertEqual(summary.evidence, .partial)
    }

    private func status(
        run: FocusRun,
        value: QuietTimeShieldStatus,
        window: QuietTimeShieldWindow,
        at date: Date
    ) -> QuietTimeShieldStatusSnapshot {
        QuietTimeShieldStatusSnapshot(
            runID: run.id,
            revision: 1,
            status: value,
            window: window,
            observedAt: date
        )
    }
}
