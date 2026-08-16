import XCTest

final class WindDownGuidanceTests: XCTestCase {
    func testEveryGuidanceItemHasSourceAndShortBody() {
        XCTAssertFalse(WindDownGuidanceLibrary.items.isEmpty)
        XCTAssertTrue(WindDownGuidanceLibrary.items.allSatisfy { !$0.sourceIDs.isEmpty })
        XCTAssertTrue(WindDownGuidanceLibrary.items.allSatisfy { $0.body.count <= 180 })
        XCTAssertEqual(Set(WindDownGuidanceLibrary.items.map(\.id)).count, WindDownGuidanceLibrary.items.count)
        XCTAssertTrue(WindDownGuidanceLibrary.items.allSatisfy { $0.sourceIDs.contains("nhlbi-healthy-sleep") || $0.sourceIDs.contains("counting-sheep-principles") || $0.sourceIDs.contains("nhlbi-sleep-wake-cycle") || $0.sourceIDs.contains("va-stimulus-control") || $0.sourceIDs.contains("counting-sheep-booklet") || $0.sourceIDs.contains("nhlbi-circadian-treatment") })
    }

    func testMealAndCaffeineCardsAreWindDownOnlyAndNonPrescriptive() throws {
        let meal = try XCTUnwrap(WindDownGuidanceLibrary.items.first { $0.id == "leave-room-after-heavy-meal" })
        let caffeine = try XCTUnwrap(WindDownGuidanceLibrary.items.first { $0.id == "personal-caffeine-cutoff" })
        XCTAssertEqual(meal.phase, .windDown)
        XCTAssertEqual(caffeine.phase, .windDown)
        XCTAssertEqual(meal.sourceIDs, ["nhlbi-healthy-sleep"])
        XCTAssertEqual(caffeine.sourceIDs, ["nhlbi-healthy-sleep"])
        XCTAssertFalse(meal.body.contains("must"))
        XCTAssertFalse(caffeine.body.contains("must"))
        XCTAssertFalse(caffeine.body.contains("after 2"))
    }

    func testOvernightHasNoActivePhaseGuidance() {
        XCTAssertTrue(WindDownGuidanceLibrary.items(for: .overnight).isEmpty)
        XCTAssertNil(NightWatchGuidance.tip(for: .overnight, seed: UUID()))
    }

    func testFeaturedGuidanceIsStableForTheSameRun() {
        let seed = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!

        XCTAssertEqual(
            WindDownGuidanceLibrary.featured(for: .windDown, seed: seed),
            WindDownGuidanceLibrary.featured(for: .windDown, seed: seed)
        )
    }

    func testHomeGuidancePrefersTheFirstSelectedEveningIdeaDeterministically() {
        let evening = [
            WindDownRoutineStep.suggested(.read, phase: .evening),
            WindDownRoutineStep.suggested(.journal, phase: .evening)
        ]
        let morning = [WindDownRoutineStep.suggested(.openCurtains, phase: .morning)]

        let first = WindDownGuidanceLibrary.homeGuidance(
            eveningRoutine: evening,
            morningRoutine: morning
        )
        let second = WindDownGuidanceLibrary.homeGuidance(
            eveningRoutine: evening,
            morningRoutine: morning
        )

        XCTAssertEqual(first?.id, "quiet-hour")
        XCTAssertEqual(first, second)
    }

    func testActiveGuidanceMatchesOnlyTheSelectedRoutinePhase() {
        let plan = NightWatchPlan(
            intendedBedtime: Date(timeIntervalSince1970: 10_000),
            wakeTime: Date(timeIntervalSince1970: 40_000),
            protectedUntil: Date(timeIntervalSince1970: 42_000),
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains,
            eveningRoutine: [WindDownRoutineStep.suggested(.read, phase: .evening)],
            morningRoutine: [WindDownRoutineStep.suggested(.openCurtains, phase: .morning)]
        )

        XCTAssertEqual(
            WindDownGuidanceLibrary.activeGuidance(for: .windDown, plan: plan)?.id,
            "quiet-hour"
        )
        XCTAssertEqual(
            WindDownGuidanceLibrary.activeGuidance(for: .morningQuiet, plan: plan)?.id,
            "morning-light"
        )
        XCTAssertNil(WindDownGuidanceLibrary.activeGuidance(for: .overnight, plan: plan))
        XCTAssertNil(WindDownGuidanceLibrary.activeGuidance(for: .complete, plan: plan))
    }

    func testUnassociatedRoutinesProduceNoGuidance() {
        let evening = [WindDownRoutineStep.suggested(.prepareTomorrow, phase: .evening)]
        let morning = [WindDownRoutineStep.suggested(.breakfast, phase: .morning)]

        let selected = WindDownGuidanceLibrary.homeGuidance(
            eveningRoutine: evening,
            morningRoutine: morning
        )

        XCTAssertNil(selected)
    }

    func testPlacementReturnsAtMostOneItemAndDoesNotUseMealOrCaffeineByDefault() {
        let selected = WindDownGuidanceLibrary.homeGuidance(
            eveningRoutine: [WindDownRoutineStep.suggested(.read, phase: .evening)],
            morningRoutine: [WindDownRoutineStep.suggested(.openCurtains, phase: .morning)]
        )
        let placements = [selected].compactMap { $0 }

        XCTAssertLessThanOrEqual(placements.count, 1)
        XCTAssertFalse(placements.contains { $0.id == "leave-room-after-heavy-meal" })
        XCTAssertFalse(placements.contains { $0.id == "personal-caffeine-cutoff" })
    }
}
