import XCTest

final class QuietTimeShieldScheduleTests: XCTestCase {
    func testMonitoringPolicyKeepsShortSessionEndExactWithPlatformPadding() {
        let start = Date(timeIntervalSince1970: 10_000)
        for minutes in [5, 10, 15, 30] {
            let desired = DateInterval(
                start: start,
                end: start.addingTimeInterval(TimeInterval(minutes * 60))
            )
            let window = QuietTimeShieldMonitoringPolicy.window(
                for: desired,
                requestedAt: start
            )

            XCTAssertNotNil(window)
            XCTAssertEqual(window?.desired.end, desired.end)
            XCTAssertGreaterThanOrEqual(
                window?.monitoring.duration ?? 0,
                QuietTimeShieldMonitoringPolicy.minimumInterval
            )
            XCTAssertEqual(window?.warningLead, TimeInterval(max(0, 15 - minutes) * 60))
        }
    }

    func testMonitoringPolicyRebasesDelayedConfirmationWithoutExtendingTheBarrier() {
        let originalStart = Date(timeIntervalSince1970: 20_000)
        let requestedAt = originalStart.addingTimeInterval(11 * 60)
        let desiredEnd = originalStart.addingTimeInterval(16 * 60)
        let desired = DateInterval(start: originalStart, end: desiredEnd)

        let window = QuietTimeShieldMonitoringPolicy.window(
            for: desired,
            requestedAt: requestedAt
        )

        XCTAssertEqual(window?.monitoring.start, requestedAt)
        XCTAssertEqual(window?.desired.end, desiredEnd)
        XCTAssertEqual(window?.monitoring.end, requestedAt.addingTimeInterval(15 * 60))
        XCTAssertEqual(window?.warningLead, 10 * 60)
        XCTAssertEqual(window?.warningTime?.minute, 10)
    }

    func testMonitoringPolicyRejectsWindowWithNoTimeRemaining() {
        let now = Date(timeIntervalSince1970: 30_000)
        let desired = DateInterval(start: now.addingTimeInterval(-30), end: now)
        XCTAssertNil(QuietTimeShieldMonitoringPolicy.window(for: desired, requestedAt: now))
    }

    func testMonitoringPolicyUsesWholeSecondEndpointsAndNeverWarnsBeforeFractionalDesiredEnd() {
        let desiredStart = Date(timeIntervalSince1970: 10_000.25)
        let requestedAt = Date(timeIntervalSince1970: 10_000.35)

        for minutes in [5, 10, 15, 30] {
            let desired = DateInterval(
                start: desiredStart,
                end: desiredStart.addingTimeInterval(TimeInterval(minutes * 60))
            )
            let window = try! XCTUnwrap(
                QuietTimeShieldMonitoringPolicy.window(for: desired, requestedAt: requestedAt)
            )

            XCTAssertEqual(window.desired, desired)
            XCTAssertEqual(window.monitoring.start.timeIntervalSince1970, 10_001)
            XCTAssertEqual(window.monitoring.end.timeIntervalSince1970.rounded(.towardZero), window.monitoring.end.timeIntervalSince1970)
            XCTAssertGreaterThanOrEqual(
                window.monitoring.duration,
                QuietTimeShieldMonitoringPolicy.minimumInterval
            )
            if let warningTime = window.warningTime {
                let warningDate = window.monitoring.end.addingTimeInterval(-warningSeconds(warningTime))
                XCTAssertGreaterThanOrEqual(
                    warningDate,
                    desired.end,
                    "\(minutes)-minute warning must not precede the desired end"
                )
                if minutes == 5 {
                    XCTAssertEqual(window.monitoring.end.timeIntervalSince1970, 10_901)
                    XCTAssertEqual(warningSeconds(warningTime), 600)
                    XCTAssertEqual(warningDate.timeIntervalSince1970, 10_301)
                }
            }
        }
    }

    func testMonitoringPolicyRejectsSubsecondRemainderThatCannotFormAWholeSecondRegistration() {
        let requestedAt = Date(timeIntervalSince1970: 50_000.35)
        let desired = DateInterval(
            start: requestedAt.addingTimeInterval(-60),
            end: requestedAt.addingTimeInterval(0.20)
        )

        XCTAssertNil(QuietTimeShieldMonitoringPolicy.window(for: desired, requestedAt: requestedAt))
    }

    func testMonitoringPolicyFractionalGridKeepsSerializedWarningOnOrAfterDesiredEnd() throws {
        for fractionalSecond in [0.01, 0.25, 0.99] {
            let desiredStart = Date(timeIntervalSince1970: 60_000 + fractionalSecond)
            let requestedAt = desiredStart.addingTimeInterval(0.10)
            let desired = DateInterval(
                start: desiredStart,
                end: desiredStart.addingTimeInterval(5 * 60)
            )
            let window = try XCTUnwrap(
                QuietTimeShieldMonitoringPolicy.window(for: desired, requestedAt: requestedAt)
            )

            XCTAssertEqual(
                window.monitoring.start.timeIntervalSince1970,
                requestedAt.timeIntervalSince1970.rounded(.up)
            )
            XCTAssertEqual(
                window.monitoring.end.timeIntervalSince1970,
                window.monitoring.end.timeIntervalSince1970.rounded(.towardZero)
            )
            XCTAssertGreaterThanOrEqual(window.monitoring.duration, 15 * 60)
            let warning = try XCTUnwrap(window.warningTime)
            XCTAssertGreaterThanOrEqual(
                window.monitoring.end.addingTimeInterval(-warningSeconds(warning)),
                desired.end
            )
        }
    }

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
        legacyObject.removeValue(forKey: "registryRevision")
        legacyObject.removeValue(forKey: "registryEpoch")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)

        let decoded = try JSONDecoder().decode(
            QuietTimeShieldScheduleSnapshot.self,
            from: legacyData
        )

        XCTAssertEqual(decoded.role, .primaryWindDown)
        XCTAssertEqual(decoded.registryRevision, 1)
        XCTAssertEqual(decoded.registryEpoch, 1)
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

    func testLegacyBookendMonitorWindowsRemainPartialEvidence() {
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
        XCTAssertEqual(summary.evidence, .partial)
    }

    func testDelayedMonitorApplyAndMainAppTerminalClearProduceObservedEvidence() {
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
            nightWatchPlan: plan
        )
        let statuses = [
            status(
                run: run,
                value: .applied,
                window: .protectedSession,
                at: start.addingTimeInterval(2.2)
            ),
            QuietTimeShieldStatusSnapshot(
                runID: run.id,
                revision: 1,
                status: .cleared,
                window: nil,
                observedAt: plan.protectedUntil.addingTimeInterval(0.5),
                provenance: .mainApp
            )
        ]

        let summary = QuietTimeShieldEvidenceMath.summary(
            for: run,
            statuses: statuses,
            at: plan.protectedUntil
        )

        // The callback timestamp intentionally does not backfill the
        // unobserved first seconds.
        XCTAssertEqual(summary.windDownMinutes, 29)
        XCTAssertEqual(summary.morningQuietMinutes, 30)
        XCTAssertEqual(summary.evidence, .observed)
    }

    func testMonitorApplyWithoutTerminalClearProducesPartialEvidence() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = NightWatchPlan.additionalQuiet(
            start: start,
            end: start.addingTimeInterval(30 * 60)
        )
        let run = FocusRun(
            plannedDurationSeconds: 30 * 60,
            startedAt: start,
            state: .completed,
            nightWatchPlan: plan
        )

        let summary = QuietTimeShieldEvidenceMath.summary(
            for: run,
            statuses: [status(
                run: run,
                value: .applied,
                window: .protectedSession,
                at: start
            )],
            at: plan.protectedUntil
        )

        XCTAssertEqual(summary.evidence, .partial)
    }

    func testGlobalMonitorClearCreatesAnObservedGap() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = NightWatchPlan.additionalQuiet(
            start: start,
            end: start.addingTimeInterval(30 * 60)
        )
        let run = FocusRun(
            plannedDurationSeconds: 30 * 60,
            startedAt: start,
            state: .completed,
            nightWatchPlan: plan
        )
        let statuses = [
            status(run: run, value: .applied, window: .protectedSession, at: start),
            QuietTimeShieldStatusSnapshot(
                runID: run.id,
                revision: 1,
                status: .cleared,
                window: nil,
                observedAt: start.addingTimeInterval(10 * 60),
                provenance: .deviceActivityMonitor
            ),
            status(
                run: run,
                value: .applied,
                window: .protectedSession,
                at: start.addingTimeInterval(15 * 60)
            ),
            QuietTimeShieldStatusSnapshot(
                runID: run.id,
                revision: 1,
                status: .cleared,
                window: nil,
                observedAt: plan.protectedUntil,
                provenance: .deviceActivityMonitor
            )
        ]

        let summary = QuietTimeShieldEvidenceMath.summary(
            for: run,
            statuses: statuses,
            at: plan.protectedUntil
        )

        XCTAssertEqual(summary.evidence, .partial)
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
                observedAt: start,
                provenance: .deviceActivityMonitor
            ),
            QuietTimeShieldStatusSnapshot(
                runID: scheduleID,
                revision: 1,
                status: .cleared,
                window: .windDown,
                observedAt: plan.intendedBedtime,
                provenance: .deviceActivityMonitor
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

    func testPriorDayRepeatingScheduleApplyCannotBecomeCurrentObservedEvidence() {
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
            nightWatchPlan: plan
        )
        let scheduleID = UUID()
        let statuses = [
            QuietTimeShieldStatusSnapshot(
                runID: scheduleID,
                revision: 1,
                status: .applied,
                window: .protectedSession,
                observedAt: start.addingTimeInterval(-24 * 60 * 60),
                provenance: .deviceActivityMonitor
            ),
            QuietTimeShieldStatusSnapshot(
                runID: run.id,
                revision: 1,
                status: .cleared,
                window: nil,
                observedAt: plan.protectedUntil.addingTimeInterval(0.5),
                provenance: .mainApp
            )
        ]

        let summary = QuietTimeShieldEvidenceMath.summary(
            for: run,
            statuses: statuses,
            at: plan.protectedUntil,
            additionalRunIDs: [scheduleID]
        )

        XCTAssertEqual(summary.windDownMinutes, 0)
        XCTAssertEqual(summary.morningQuietMinutes, 0)
        XCTAssertEqual(summary.evidence, .unavailable)
    }

    func testLateReconciliationClearCannotCompleteHistoricalOccurrenceEvidence() {
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
            nightWatchPlan: plan
        )
        let repeatingScheduleID = UUID()
        let statuses = [
            QuietTimeShieldStatusSnapshot(
                runID: repeatingScheduleID,
                revision: 1,
                status: .applied,
                window: .protectedSession,
                observedAt: start.addingTimeInterval(2),
                provenance: .deviceActivityMonitor
            ),
            QuietTimeShieldStatusSnapshot(
                runID: repeatingScheduleID,
                revision: 1,
                status: .cleared,
                window: nil,
                observedAt: plan.protectedUntil.addingTimeInterval(24 * 60 * 60),
                provenance: .mainApp
            )
        ]

        let summary = QuietTimeShieldEvidenceMath.summary(
            for: run,
            statuses: statuses,
            at: plan.protectedUntil,
            additionalRunIDs: [repeatingScheduleID]
        )

        XCTAssertEqual(summary.evidence, .partial)
    }

    func testMainAppApplyDoesNotBecomeObservedMonitorEvidence() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = NightWatchPlan.additionalQuiet(
            start: start,
            end: start.addingTimeInterval(30 * 60)
        )
        let run = FocusRun(
            plannedDurationSeconds: 30 * 60,
            startedAt: start,
            state: .completed,
            nightWatchPlan: plan
        )
        let status = QuietTimeShieldStatusSnapshot(
            runID: run.id,
            revision: 1,
            status: .applied,
            window: .protectedSession,
            observedAt: start,
            provenance: .mainApp
        )

        let summary = QuietTimeShieldEvidenceMath.summary(
            for: run,
            statuses: [status],
            at: plan.protectedUntil
        )

        XCTAssertEqual(summary.windDownMinutes, 0)
        XCTAssertEqual(summary.morningQuietMinutes, 0)
        XCTAssertEqual(summary.evidence, .unavailable)
    }

    func testMonitorFailureAfterApplyProducesPartialEvidence() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = NightWatchPlan.additionalQuiet(
            start: start,
            end: start.addingTimeInterval(30 * 60)
        )
        let run = FocusRun(
            plannedDurationSeconds: 30 * 60,
            startedAt: start,
            state: .completed,
            nightWatchPlan: plan
        )
        let statuses = [
            status(run: run, value: .applied, window: .protectedSession, at: start),
            status(
                run: run,
                value: .failed,
                window: .protectedSession,
                at: start.addingTimeInterval(10 * 60)
            )
        ]

        let summary = QuietTimeShieldEvidenceMath.summary(
            for: run,
            statuses: statuses,
            at: plan.protectedUntil
        )

        XCTAssertEqual(summary.evidence, .partial)
    }

    func testLegacyStatusDecodesWithUnknownProvenanceAndCannotBecomeObserved() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = NightWatchPlan.additionalQuiet(
            start: start,
            end: start.addingTimeInterval(30 * 60)
        )
        let run = FocusRun(
            plannedDurationSeconds: 30 * 60,
            startedAt: start,
            state: .completed,
            nightWatchPlan: plan
        )
        let encoded = try JSONEncoder().encode(QuietTimeShieldStatusSnapshot(
            schemaVersion: 1,
            runID: run.id,
            revision: 1,
            status: .applied,
            window: .protectedSession,
            observedAt: start,
            provenance: .mainApp
        ))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "provenance")
        let decoded = try JSONDecoder().decode(
            QuietTimeShieldStatusSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertEqual(decoded.schemaVersion, QuietTimeShieldStatusSnapshot.currentSchemaVersion)
        XCTAssertEqual(decoded.provenance, .legacyUnknown)
        XCTAssertEqual(
            QuietTimeShieldEvidenceMath.summary(
                for: run,
                statuses: [decoded],
                at: plan.protectedUntil
            ).evidence,
            .unavailable
        )
    }

    func testReceiptPresentationSeparatesRequestedEvidenceFromAuthorization() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = NightWatchPlan.additionalQuiet(
            start: start,
            end: start.addingTimeInterval(30 * 60)
        )
        var run = FocusRun(
            plannedDurationSeconds: 30 * 60,
            startedAt: start,
            state: .completed,
            nightWatchPlan: plan
        )
        run.endedAt = plan.protectedUntil
        run.completedSuccessfully = true
        let observedRecord = try XCTUnwrap(run.nightWatchRecord(
            updatedAt: plan.protectedUntil,
            shieldProtectionEvidence: .observed
        ))

        XCTAssertEqual(
            QuietTimeShieldReceiptPresentation.make(
                shieldingRequested: true,
                record: observedRecord
            ).value,
            "Observed"
        )
        XCTAssertEqual(
            QuietTimeShieldReceiptPresentation.make(
                shieldingRequested: true,
                record: nil
            ).value,
            "Unavailable"
        )
        XCTAssertEqual(
            QuietTimeShieldReceiptPresentation.make(
                shieldingRequested: false,
                record: observedRecord
            ).value,
            "Not requested"
        )
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
            observedAt: date,
            provenance: .deviceActivityMonitor
        )
    }

    private func warningSeconds(_ components: DateComponents) -> TimeInterval {
        TimeInterval(
            (components.hour ?? 0) * 3_600
                + (components.minute ?? 0) * 60
                + (components.second ?? 0)
        )
    }
}
