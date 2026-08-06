import XCTest

final class NotificationPlanningTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    func testCadenceCountsMatchTheRitualTimeline() {
        let plan = makePlan()

        XCTAssertEqual(planFor(.quiet, plan: plan).count, 4)
        XCTAssertEqual(planFor(.balanced, plan: plan).count, 7)
        XCTAssertEqual(planFor(.supportive, plan: plan).count, 9)
    }

    func testShortWindDownSkipsMidpointWhenSpacingWouldBeTooTight() {
        let plan = NightWatchPlan(
            intendedBedtime: start.addingTimeInterval(60 * 60),
            wakeTime: start.addingTimeInterval(9 * 60 * 60),
            protectedUntil: start.addingTimeInterval(9.5 * 60 * 60),
            windDownMinutes: 15,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
        let planned = planFor(.balanced, plan: plan)

        XCTAssertFalse(planned.contains { $0.id == "night-watch-wind-down-midpoint" })
        XCTAssertTrue(planned.dropFirst().enumerated().allSatisfy { index, notification in
            notification.date.timeIntervalSince(planned[index].date) >= 10 * 60
        })
    }

    func testLateStartSkipsPastLeadIns() {
        let plan = NightWatchPlan(
            intendedBedtime: start.addingTimeInterval(60 * 60),
            wakeTime: start.addingTimeInterval(9 * 60 * 60),
            protectedUntil: start.addingTimeInterval(9.5 * 60 * 60),
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
        let planned = planFor(
            .supportive,
            plan: plan,
            startedAt: start.addingTimeInterval(70 * 60),
            now: start.addingTimeInterval(70 * 60)
        )

        XCTAssertFalse(planned.contains { $0.id == "night-watch-lead-in-60" })
        XCTAssertFalse(planned.contains { $0.id == "night-watch-lead-in-30" })
        XCTAssertFalse(planned.contains { $0.id == "night-watch-lead-in-10" })
    }

    func testTipsReplaceMidpointAndStayStableForTheNight() throws {
        let plan = makePlan()
        let seed = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!
        let withoutTip = planFor(.balanced, plan: plan, seed: seed)
        let withTip = planFor(.balanced, plan: plan, seed: seed, tips: true)
        let midpoint = withTip.first { $0.id == "night-watch-wind-down-midpoint" }

        XCTAssertEqual(withTip.count, withoutTip.count)
        let tip = try XCTUnwrap(NightWatchGuidance.tip(for: .windDown, seed: seed))
        XCTAssertTrue(midpoint?.body.contains(tip) == true)
        XCTAssertFalse(withTip.contains { $0.phase == .overnight && $0.id.contains("midpoint") })
    }

    func testPersonalPurposeOnlyAppearsWithExplicitConsent() {
        let plan = makePlan()
        let consented = OfflinePurposeProfile(
            category: .custom,
            customText: "paint miniatures",
            allowsCustomTextInNotifications: true
        )
        let privatePurpose = OfflinePurposeProfile(
            category: .custom,
            customText: "paint miniatures",
            allowsCustomTextInNotifications: false
        )

        let visible = planFor(.quiet, plan: plan, purpose: consented)
        let hidden = planFor(.quiet, plan: plan, purpose: privatePurpose)

        XCTAssertTrue(visible.first { $0.id == "night-watch-wind-down-start" }?.body.contains("paint miniatures") == true)
        XCTAssertFalse(hidden.first { $0.id == "night-watch-wind-down-start" }?.body.contains("paint miniatures") == true)
    }

    func testScheduledPlanUsesPerTemplateCopyOverrides() {
        let plan = makePlan()
        let planned = NightWatchNotificationPlanBuilder.scheduledNotifications(
            for: plan,
            startedAt: start,
            cadence: .quiet,
            purpose: .defaultProfile,
            seed: UUID(),
            educationalTipsEnabled: false,
            soundsEnabled: true,
            copyOverrides: [
                NotificationCopyOverride(
                    id: .windDownStart,
                    title: "My quiet begins",
                    body: "The phone can rest now."
                )
            ],
            now: start.addingTimeInterval(-1)
        )

        let startNotification = planned.first { $0.id == "night-watch-wind-down-start" }
        XCTAssertEqual(startNotification?.title, "My quiet begins")
        XCTAssertEqual(startNotification?.body, "The phone can rest now.")
    }

    func testUsageNotificationsAreStableAndNeverCompletePhase() {
        XCTAssertEqual(
            NightWatchNotificationPlanBuilder.usageNotification(for: .overnight)?.id,
            "night-watch-usage-overnight"
        )
        XCTAssertEqual(
            NightWatchNotificationPlanBuilder.usageNotification(for: .overnight)?.playsSound,
            false
        )
        XCTAssertNil(NightWatchNotificationPlanBuilder.usageNotification(for: .complete))
    }

    func testAdditionalQuietNotificationsNeverUseSleepBookendCues() {
        let plan = NightWatchPlan.additionalQuiet(
            start: start.addingTimeInterval(60 * 60),
            end: start.addingTimeInterval(2 * 60 * 60)
        )
        let planned = planFor(.supportive, plan: plan)

        XCTAssertFalse(planned.contains { $0.id == "night-watch-sleep-time" })
        XCTAssertFalse(planned.contains { $0.id == "night-watch-phone-free-morning" })
        XCTAssertTrue(planned.contains { $0.id == "night-watch-quiet-period-complete" })
    }

    func testLegacyNotificationPreferencesKeepOptionalChannelsOff() throws {
        let legacy = Data("{\"remindersEnabled\":false}".utf8)
        let decoded = try JSONDecoder().decode(NotificationPreferences.self, from: legacy)

        XCTAssertFalse(decoded.remindersEnabled)
        XCTAssertFalse(decoded.hasChosenCadence)
        XCTAssertFalse(decoded.educationalTipsEnabled)
        XCTAssertFalse(decoded.usageAwareRemindersEnabled)
        XCTAssertFalse(decoded.morningReflectionReminderEnabled)
    }

    private func planFor(
        _ cadence: NotificationCadence,
        plan: NightWatchPlan,
        startedAt: Date = Date(timeIntervalSince1970: 1_000_000),
        now: Date = Date(timeIntervalSince1970: 900_000),
        purpose: OfflinePurposeProfile = .defaultProfile,
        seed: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        tips: Bool = false
    ) -> [PlannedNotification] {
        NightWatchNotificationPlanBuilder.scheduledNotifications(
            for: plan,
            startedAt: startedAt,
            cadence: cadence,
            purpose: purpose,
            seed: seed,
            educationalTipsEnabled: tips,
            soundsEnabled: true,
            now: now
        )
    }

    private func makePlan() -> NightWatchPlan {
        NightWatchPlan(
            intendedBedtime: start.addingTimeInterval(3 * 60 * 60),
            wakeTime: start.addingTimeInterval(11 * 60 * 60),
            protectedUntil: start.addingTimeInterval(11.5 * 60 * 60),
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
    }
}
