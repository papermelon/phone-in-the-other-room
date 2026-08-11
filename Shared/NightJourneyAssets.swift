import Foundation

/// Qualified catalog names for the active Wind Down journey. Keeping these in
/// shared, testable data prevents a group namespace change from silently
/// producing an empty scene in a Release build.
enum NightJourneyAssets {
    static let backdrops: [NightJourneySegment: String] = [
        .prairie: "farm/farm_journey_prairie_backdrop",
        .mountain: "farm/farm_journey_mountain_backdrop",
        .moonlit: "farm/farm_journey_moonlit_backdrop",
        .sunrise: "farm/farm_journey_sunrise_backdrop"
    ]
    static let clueAssets = [
        "farm/farm_journey_clue_hoofprints",
        "farm/farm_journey_clue_wool",
        "farm/farm_journey_clue_gate",
        "farm/farm_journey_clue_bell"
    ]
    static let ollieRunFrames: [String] = (1...6).map { frame in
        "dog/dog_classic_run_frame_0\(frame)"
    }
}
