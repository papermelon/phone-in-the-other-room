import SwiftUI

#Preview("Ready now and paused") {
    let now = Date()
    let viewModel = FocusRunViewModel()
    viewModel.windDownSchedule = WindDownScheduleState(oneTimePeriods: [
        WindDownOneTimePeriod(
            title: "A ready quiet time",
            interval: DateInterval(start: now.addingTimeInterval(-60), end: now.addingTimeInterval(5 * 60))
        ),
        WindDownOneTimePeriod(
            title: "Paused later",
            interval: DateInterval(start: now.addingTimeInterval(60 * 60), end: now.addingTimeInterval(90 * 60)),
            enabled: false
        )
    ])

    return NavigationStack {
        WindDownScheduleView()
            .environmentObject(viewModel)
    }
}
