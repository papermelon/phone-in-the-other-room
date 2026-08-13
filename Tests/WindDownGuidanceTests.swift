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
}
