import XCTest

final class QuietTimeShieldPresentationTests: XCTestCase {
    func testRoleResolutionSelectsEachPrimaryPhaseAndAdditionalQuiet() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let windDownEnd = start.addingTimeInterval(30 * 60)
        let bedtime = start.addingTimeInterval(60 * 60)
        let wake = start.addingTimeInterval(8 * 60 * 60)
        let end = start.addingTimeInterval(8.5 * 60 * 60)
        let primary = QuietTimeShieldPresentationSnapshot(
            runID: UUID(),
            revision: 1,
            role: .primaryWindDown,
            protectedSessionInterval: DateInterval(start: start, end: end),
            windDownInterval: DateInterval(start: start, end: windDownEnd),
            morningQuietInterval: DateInterval(start: wake, end: end),
            updatedAt: start
        )
        let additional = QuietTimeShieldPresentationSnapshot(
            runID: UUID(),
            revision: 1,
            role: .additionalQuiet,
            protectedSessionInterval: DateInterval(start: start, end: bedtime),
            windDownInterval: nil,
            morningQuietInterval: DateInterval(start: bedtime, end: bedtime),
            updatedAt: start
        )

        XCTAssertEqual(primary.cueGroup(at: start.addingTimeInterval(5 * 60)), .windDown)
        XCTAssertEqual(primary.cueGroup(at: start.addingTimeInterval(2 * 60 * 60)), .overnight)
        XCTAssertEqual(primary.cueGroup(at: wake.addingTimeInterval(5 * 60)), .morningQuiet)
        XCTAssertEqual(additional.cueGroup(at: start.addingTimeInterval(5 * 60)), .additionalQuiet)
    }

    func testProtectedSessionEndIsTheDisplayedRealEndDate() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let protectedEnd = start.addingTimeInterval(8 * 60 * 60)
        let snapshot = QuietTimeShieldPresentationSnapshot(
            runID: UUID(),
            revision: 1,
            protectedSessionInterval: DateInterval(start: start, end: protectedEnd),
            windDownInterval: DateInterval(start: start, end: start.addingTimeInterval(30 * 60)),
            morningQuietInterval: DateInterval(
                start: start.addingTimeInterval(7.5 * 60 * 60),
                end: start.addingTimeInterval(7.75 * 60 * 60)
            ),
            updatedAt: start
        )

        XCTAssertEqual(snapshot.protectedEndDate, protectedEnd)
    }

    func testLegacyPresentationSnapshotDefaultsToPrimaryWindDown() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = QuietTimeShieldPresentationSnapshot(
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

        let decoded = try XCTUnwrap(QuietTimeShieldPresentationSnapshot.decode(legacyData))

        XCTAssertEqual(decoded.role, .primaryWindDown)
        XCTAssertEqual(decoded.schemaVersion, QuietTimeShieldPresentationSnapshot.currentSchemaVersion)
    }

    func testCueCatalogIsFiniteGroupedAndDeterministic() {
        let runID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let date = Date(timeIntervalSince1970: 1_800_000_000)

        for group in QuietTimeShieldCueGroup.allCases {
            let cues = ShieldCueCatalog.cues(for: group)
            XCTAssertFalse(cues.isEmpty)
            XCTAssertEqual(
                ShieldCueCatalog.cue(for: group, runID: runID, date: date),
                ShieldCueCatalog.cue(for: group, runID: runID, date: date)
            )
            XCTAssertTrue(cues.contains(ShieldCueCatalog.cue(for: group, runID: runID, date: date)))
            XCTAssertTrue(cues.allSatisfy { !$0.contains("\"") })
        }

        XCTAssertEqual(
            ShieldCueCatalog.additionalQuiet,
            [
                "The next few minutes do not need a screen.",
                "Leave the scroll here. Let your attention land somewhere else.",
                "One less check can make a little more room."
            ]
        )
        XCTAssertEqual(
            ShieldCueCatalog.overnight,
            ["Your phone is tucked away. There is nothing else to do here."]
        )
    }

    func testMalformedOrMissingScheduleFallsBackWithoutAUserFacingQuote() {
        XCTAssertNil(QuietTimeShieldPresentationSnapshot.decode(nil))
        XCTAssertNil(QuietTimeShieldPresentationSnapshot.decode(Data("not-json".utf8)))

        let fallback = ShieldCueCatalog.cue(
            for: .windDown,
            runID: nil,
            date: Date(timeIntervalSince1970: 1_800_000_000)
        )
        XCTAssertTrue(ShieldCueCatalog.windDown.contains(fallback))
        XCTAssertFalse(fallback.contains("“"))
        XCTAssertFalse(fallback.contains("”"))
    }
}
