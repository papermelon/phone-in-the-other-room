import Foundation

enum FocusRunRules {
    static let startupDistanceCheckWindowSeconds: TimeInterval = 30
    static let closeReturnCheckDelaySeconds: TimeInterval = 20
    static let scheduledDistanceCheckWindowSeconds: TimeInterval = 10
    static let manualDistanceCheckWindowSeconds: TimeInterval = 20
    static let sampledCheckMinimumDelaySeconds: TimeInterval = 45
    static let sampledCheckMaximumDelaySeconds: TimeInterval = 120
    static let closeReturnFailDistanceMeters = 2.0
    static let requiredCloseSamplesForCheck = 2
    static let allowedCloseWarnings = 3
    static let realtimeWatchMessageFreshnessSeconds: TimeInterval = 15

    static func canCompleteSuccessfully(_ run: FocusRun, demoMode: Bool) -> Bool {
        if demoMode { return true }
        guard run.guardKind.needsPlacementConfirmation else { return true }
        // Watch placement is a convenience, never a gate that can strand a timer at zero.
        return run.placementStatus == .confirmed || run.placementStatus == .unavailable
    }
}
