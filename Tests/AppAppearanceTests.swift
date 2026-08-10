import XCTest

final class AppAppearanceTests: XCTestCase {
    func testFreshInstallationDefaultsToAutomatic() {
        XCTAssertEqual(AppAppearancePreference.automatic.resolution(isWindDownReadyOrActive: false), .system)
    }

    func testAutomaticFollowsSystemDuringOrdinaryUseAndDarkensWindDown() {
        XCTAssertEqual(AppAppearancePreference.automatic.resolution(isWindDownReadyOrActive: false), .system)
        XCTAssertEqual(AppAppearancePreference.automatic.resolution(isWindDownReadyOrActive: true), .dark)
    }

    func testExplicitChoicesWinDuringWindDownAndOnboarding() {
        XCTAssertEqual(AppAppearancePreference.light.resolution(isWindDownReadyOrActive: false), .light)
        XCTAssertEqual(AppAppearancePreference.light.resolution(isWindDownReadyOrActive: true), .light)
        XCTAssertEqual(AppAppearancePreference.dark.resolution(isWindDownReadyOrActive: false), .dark)
        XCTAssertEqual(AppAppearancePreference.dark.resolution(isWindDownReadyOrActive: true), .dark)
    }

    func testTappingLightSelectsItFromAutomaticAndDark() {
        XCTAssertEqual(
            AppAppearancePreference.selection(afterTapping: .light, from: .automatic),
            .light
        )
        XCTAssertEqual(
            AppAppearancePreference.selection(afterTapping: .light, from: .dark),
            .light
        )
    }

    func testTappingDarkSelectsItFromAutomaticAndLight() {
        XCTAssertEqual(
            AppAppearancePreference.selection(afterTapping: .dark, from: .automatic),
            .dark
        )
        XCTAssertEqual(
            AppAppearancePreference.selection(afterTapping: .dark, from: .light),
            .dark
        )
    }

    func testTappingTheSelectedChoiceReturnsToAutomatic() {
        XCTAssertEqual(
            AppAppearancePreference.selection(afterTapping: .light, from: .light),
            .automatic
        )
        XCTAssertEqual(
            AppAppearancePreference.selection(afterTapping: .dark, from: .dark),
            .automatic
        )
    }

    func testTappingAutomaticKeepsTheSystemPreference() {
        for current in AppAppearancePreference.allCases {
            XCTAssertEqual(
                AppAppearancePreference.selection(afterTapping: .automatic, from: current),
                .automatic
            )
        }
    }

    func testAllChoicesRoundTripThroughCodable() throws {
        for preference in AppAppearancePreference.allCases {
            let data = try JSONEncoder().encode(preference)
            XCTAssertEqual(try JSONDecoder().decode(AppAppearancePreference.self, from: data), preference)
        }
    }
}
