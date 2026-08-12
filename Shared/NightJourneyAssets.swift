import Foundation

/// Qualified catalog names for the active Wind Down journey. Keeping these in
/// shared, testable data prevents a group namespace change from silently
/// producing an empty scene in a Release build.
enum NightJourneyAssets {
    static let ollieHomeIdleFrames: [String] = (1...6).map { frame in
        "dog/dog_classic_home_idle_frame_0\(frame)"
    }

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
    /// Bottom edge of the lowest visible paw in each registered 512×512 frame.
    /// Anchoring this point to the terrain prevents passing frames from floating.
    static let ollieRunGroundAnchors: [Double] = [500, 500, 451, 501, 500, 451].map { Double($0) / 512 }

    static let companionSheepRunFrames: [String] = (1...6).map { frame in
        "sheep/sheep_bramble_chase_run_frame_0\(frame)"
    }
    static let companionSheepRunGroundAnchors: [Double] = [455, 455, 405, 455, 455, 405].map { Double($0) / 512 }
}
