import SwiftUI

struct NightWatchReceiptCard: View {
    let run: FocusRun?
    let sleepSummary: SleepSummary?
    let sleepAuthorization: HealthSleepService.AuthorizationState
    let screenTimeAuthorization: ScreenTimeAuthorizationService.AuthorizationState

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("YOUR WIND DOWN")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)

                receiptRow(
                    icon: "iphone.slash",
                    title: "Phone-away time",
                    value: elapsedLabel,
                    detail: "Elapsed from the moment Wind Down began"
                )

                if let run, run.isNightWatch {
                    receiptRow(
                        icon: "moon.zzz.fill",
                        title: run.nightWatchPlan?.role == .additionalQuiet ? "One-time quiet period" : "Phone-free time",
                        value: "\(run.creditedQuietMinutes) min",
                        detail: run.nightWatchPlan?.role == .additionalQuiet
                            ? "A bounded quiet period; no sleep claim"
                            : "Wind-down and after waking only"
                    )

                    if run.briefAccessUseCount > 0 {
                        receiptRow(
                            icon: "arrow.triangle.2.circlepath",
                            title: "Short breaks",
                            value: "\(run.briefAccessUseCount) short break\(run.briefAccessUseCount == 1 ? "" : "s")",
                            detail: "Selected apps were available for about five minutes"
                        )
                    }
                }

                if run?.nightWatchPlan?.role != .additionalQuiet {
                    receiptRow(
                        icon: "bed.double.fill",
                        title: "Sleep from Apple Health",
                        value: sleepValue,
                        detail: sleepDetail
                    )

                    receiptRow(
                        icon: "hourglass.bottomhalf.filled",
                        title: "Screen time around sleep",
                        value: screenTimeValue,
                        detail: screenTimeDetail
                    )
                }
            }
        }
    }

    private var elapsedLabel: String {
        guard let seconds = run?.actualDurationSeconds, seconds >= 60 else {
            return "Under 1 min"
        }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes) min" }
        let remainingMinutes = minutes % 60
        return remainingMinutes == 0
            ? "\(minutes / 60)h"
            : "\(minutes / 60)h \(remainingMinutes)m"
    }

    private var sleepValue: String {
        if let matchingSleepSummary { return matchingSleepSummary.durationLabel }
        switch sleepAuthorization {
        case .unavailable: return "Unavailable"
        case .notRequested: return "Not connected"
        case .requested: return "No sample found"
        case .error: return "Try again"
        }
    }

    private var sleepDetail: String {
        switch sleepAuthorization {
        case .unavailable:
            return "Apple Health sleep data is unavailable on this device"
        case .notRequested:
            return "Connect Apple Health in Nights to add this context"
        case .requested where matchingSleepSummary == nil:
            return "No matching sleep sample was returned for last night"
        case .requested:
            return "Sleep duration recorded by Apple Health"
        case .error:
            return "Apple Health could not complete the request"
        }
    }

    private var matchingSleepSummary: SleepSummary? {
        guard let sleepSummary, let run else { return sleepSummary }
        guard let sleepStart = sleepSummary.startDate, let sleepEnd = sleepSummary.endDate else {
            return nil
        }
        let runEnd = run.endedAt ?? run.plannedEndAt
        return sleepEnd >= run.startedAt && sleepStart <= runEnd ? sleepSummary : nil
    }

    private var screenTimeValue: String {
        switch screenTimeAuthorization {
        case .approved: return "Connected"
        case .unavailable: return "Not available yet"
        case .notDetermined: return "Not connected"
        case .denied: return "Needs permission"
        }
    }

    private var screenTimeDetail: String {
        switch screenTimeAuthorization {
        case .approved:
            return "See the separate late-evening and morning reports in Nights"
        case .unavailable:
            return "Late-evening and morning reports are unavailable on this device"
        case .notDetermined:
            return "Connect Screen Time in Nights to see both reports"
        case .denied:
            return "Screen Time access has not been granted"
        }
    }

    private func receiptRow(icon: String, title: String, value: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.grass)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(pixelFont(.body))
                    Spacer(minLength: 8)
                    Text(value)
                        .font(pixelFont(.caption))
                        .multilineTextAlignment(.trailing)
                }
                Text(detail)
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
    }
}

#Preview("Connected sleep") {
    NightWatchReceiptCard(
        run: nil,
        sleepSummary: SleepSummary(
            durationSeconds: 7.5 * 60 * 60,
            startDate: nil,
            endDate: nil
        ),
        sleepAuthorization: .requested,
        screenTimeAuthorization: .unavailable
    )
    .padding()
    .background(AppColors.paper)
}

#Preview("Data unavailable") {
    NightWatchReceiptCard(
        run: nil,
        sleepSummary: nil,
        sleepAuthorization: .notRequested,
        screenTimeAuthorization: .unavailable
    )
    .padding()
    .background(AppColors.paper)
}
