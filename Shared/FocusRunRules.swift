import Foundation

enum FocusRunRules {
    /// Product progression threshold for a qualifying protected-night search.
    /// This is a phone-away span, not a claim about hours asleep.
    static let minimumProtectedNightSearchSpanMinutes = 420
    /// The coordinator never creates a run with less than one meaningful
    /// minute. Schedule validation uses the same floor for late starts.
    static let minimumMeaningfulDurationSeconds: TimeInterval = 60
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

    /// Minutes from the eligible Wind Down start through morning-quiet completion.
    /// Overnight time is included in this span for search eligibility only; quiet
    /// credit remains the two bookends.
    static func protectedSpanMinutes(for run: FocusRun) -> Int {
        guard let plan = run.nightWatchPlan, plan.role.isProgressionEligible else {
            let end = run.endedAt ?? run.plannedEndAt
            return max(0, Int(end.timeIntervalSince(run.startedAt) / 60))
        }
        let plannedStart = plan.intendedBedtime.addingTimeInterval(
            TimeInterval(-plan.windDownMinutes * 60)
        )
        let eligibleStart = max(run.startedAt, plannedStart)
        let completion = min(run.endedAt ?? plan.protectedUntil, plan.protectedUntil)
        return max(0, Int(completion.timeIntervalSince(eligibleStart) / 60))
    }

    static func qualifiesForProtectedNightSearch(_ run: FocusRun, demoMode: Bool = false) -> Bool {
        guard run.completedSuccessfully else { return false }
        guard !run.isPractice else { return false }
        guard run.isProgressionEligibleNightWatch else { return false }
        guard canCompleteSuccessfully(run, demoMode: demoMode) else { return false }
        return protectedSpanMinutes(for: run) >= minimumProtectedNightSearchSpanMinutes
    }
}
