import XCTest

final class WindDownGuidanceTests: XCTestCase {
    func testEveryGuidanceItemHasSourceAndShortBody() {
        XCTAssertFalse(WindDownGuidanceLibrary.items.isEmpty)
        XCTAssertTrue(WindDownGuidanceLibrary.items.allSatisfy { !$0.sourceIDs.isEmpty })
        XCTAssertTrue(WindDownGuidanceLibrary.items.allSatisfy { $0.body.count <= 180 })
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
