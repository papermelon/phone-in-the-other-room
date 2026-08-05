import Foundation

/// Qualified catalog names for the active Wind Down journey. Keeping these in
/// shared, testable data prevents a group namespace change from silently
/// producing an empty scene in a Release build.
enum NightJourneyAssets {
    static let environment = "farm/farm_hills_side_scroll_test"
    static let ollieRunFrames: [String] = (1...6).map { frame in
        "dog/dog_run_frame_0\(frame)"
    }
}
