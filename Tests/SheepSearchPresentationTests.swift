import XCTest

final class SheepSearchPresentationTests: XCTestCase {
    func testStarterAndPracticeNotesAreWelcomeGiftsNotWindDowns() {
        let starter = SheepSearchEngine.calculateStarter(now: Date(timeIntervalSince1970: 1)).outcome
        let practice = SheepSearchEngine.calculateOnboardingPractice(
            runID: UUID(uuidString: "00000000-0000-0000-0000-000000000088")!,
            now: Date(timeIntervalSince1970: 2)
        ).outcome

        XCTAssertTrue(SheepSearchPresentation.originLine(for: starter).hasPrefix("Welcome gift"))
        XCTAssertTrue(SheepSearchPresentation.originLine(for: practice).hasPrefix("Practice gift"))
        XCTAssertEqual(SheepSearchPresentation.foundEyebrow(for: .starter), "A WELCOME GIFT")
        XCTAssertEqual(SheepSearchPresentation.foundHeadline(for: .onboardingPractice), "Practice brought a welcome gift home.")
        XCTAssertEqual(SheepSearchPresentation.barnArrivalLabel(for: .starter), "Welcome gift")
        XCTAssertFalse(SheepSearchPresentation.originLine(for: starter).localizedCaseInsensitiveContains("wind down"))
        XCTAssertFalse(SheepSearchPresentation.originLine(for: starter).localizedCaseInsensitiveContains("protected"))
        XCTAssertFalse(SheepSearchPresentation.originLine(for: starter).localizedCaseInsensitiveContains("search"))
        XCTAssertFalse(SheepSearchPresentation.showsTrailMetrics(for: .starter))
    }

    func testCompletedWindDownAndPhoneAwayNotesDescribeAFindNotASearch() {
        XCTAssertEqual(SheepSearchPresentation.foundHeadline(for: .windDown), "Ollie found a missing sheep.")
        XCTAssertEqual(SheepSearchPresentation.originLabel(for: .windDown), "After Wind Down")
        XCTAssertEqual(SheepSearchPresentation.originLabel(for: .phoneBreak), "After Phone Away")
        XCTAssertEqual(SheepSearchPresentation.openedByLine(for: .phoneBreak), "After 100 Phone Away minutes")
        XCTAssertFalse(SheepSearchPresentation.foundHeadline(for: .windDown).localizedCaseInsensitiveContains("search"))
        XCTAssertFalse(SheepSearchPresentation.originLabel(for: .windDown).localizedCaseInsensitiveContains("protected"))
    }

    func testSunriseOriginAndThreeSourceExplanationStaySeparate() {
        XCTAssertEqual(SheepSearchPresentation.originLabel(for: .sunrise), "Sunrise Trail")
        XCTAssertEqual(SheepSearchExplainerPresentation.sources.map(\.id), [.windDown, .sunrise, .phoneBreak])
        XCTAssertTrue(SheepSearchExplainerPresentation.rulesDetail.contains("first three"))
        XCTAssertTrue(SheepSearchExplainerPresentation.rulesDetail.contains("20%, 30%, 40%, then 50%"))
        XCTAssertTrue(SheepSearchExplainerPresentation.sources[0].detail.contains("does not change"))
    }

    func testLegacySocialRawValueHasTruthfulWindDownPresentation() {
        XCTAssertEqual(NightFlockMemberNightStatus.morningQuietCompleted.rawValue, "morningQuietCompleted")
        XCTAssertEqual(NightFlockMemberNightStatus.morningQuietCompleted.title, "Qualifying Wind Down completed")
        XCTAssertFalse(NightFlockMemberNightStatus.morningQuietCompleted.title.localizedCaseInsensitiveContains("morning"))
    }
}
