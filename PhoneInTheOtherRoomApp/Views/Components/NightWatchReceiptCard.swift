import SwiftUI

struct NightWatchReceiptCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let run: FocusRun?
    let sleepSummary: SleepSummary?
    let sleepAuthorization: HealthSleepService.AuthorizationState
    let screenTimeAuthorization: ScreenTimeAuthorizationService.AuthorizationState
    let screenFreeMorning: MorningQuietOccurrence?
    let record: NightWatchRecord?
    let farmCredit: FarmCreditReceipt?

    init(
        run: FocusRun?,
        sleepSummary: SleepSummary?,
        sleepAuthorization: HealthSleepService.AuthorizationState,
        screenTimeAuthorization: ScreenTimeAuthorizationService.AuthorizationState,
        screenFreeMorning: MorningQuietOccurrence? = nil,
        record: NightWatchRecord? = nil,
        farmCredit: FarmCreditReceipt? = nil
    ) {
        self.run = run
        self.sleepSummary = sleepSummary
        self.sleepAuthorization = sleepAuthorization
        self.screenTimeAuthorization = screenTimeAuthorization
        self.screenFreeMorning = screenFreeMorning
        self.record = record
        self.farmCredit = farmCredit
    }

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                compactRow(
                    icon: run?.nightWatchPlan?.role == .additionalQuiet ? "timer" : "moon.fill",
                    title: run?.nightWatchPlan?.role == .additionalQuiet ? "Phone Away" : "Wind Down",
                    value: elapsedLabel
                )
                if run?.nightWatchPlan?.role != .additionalQuiet, let screenFreeMorning {
                    compactRow(icon: "sun.max.fill", title: "Screen-Free Morning", value: morningSummary(screenFreeMorning))
                }

                if let credit = farmCredit,
                   !credit.migrated || credit.creditedSeconds > 0 || credit.trackingIncomplete {
                    receiptRow(icon: "leaf.fill", title: "Farm progress",
                        value: "\(Int(credit.creditedSeconds / 60)) min",
                        detail: credit.trackingIncomplete
                            ? "Timing is incomplete. Previously saved progress stays."
                            : "Time added to wool growth and Ollie’s search.")
                }

                DisclosureGroup("Timer & progress details") {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        if let credit = farmCredit {
                            Text(credit.detail)
                                .foregroundStyle(AppColors.secondaryText)
                        }
                        if let run, run.isNightWatch {
                            receiptRow(icon: "clock",
                                title: run.nightWatchPlan?.role == .additionalQuiet ? "Phone Away timer" : "Before bedtime",
                                value: "\(run.isProgressionEligibleNightWatch ? run.creditedWindDownMinutes : run.creditedQuietMinutes) min",
                                detail: recordedMinutesDetail(for: run))
                            if run.briefAccessUseCount > 0 {
                                receiptRow(icon: "arrow.triangle.2.circlepath", title: "Brief Access",
                                    value: "\(run.briefAccessUseCount) use\(run.briefAccessUseCount == 1 ? "" : "s")",
                                    detail: "The timer continued while selected-app limits were lifted.")
                            }
                        }
                    }
                    .padding(.top, AppSpacing.sm)
                }
                .font(AppTypography.caption)
                .tint(AppColors.grass)
                .frame(minHeight: 44)

                DisclosureGroup("Health & app protection") {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        if let run, run.isNightWatch {
                            let evidence = QuietTimeShieldReceiptPresentation.make(
                                shieldingRequested: run.appShieldingRequested, record: record)
                            receiptRow(icon: evidence.systemImage, title: "App protection record",
                                value: evidence.value, detail: evidence.detail)
                        }
                        if run?.nightWatchPlan?.role != .additionalQuiet {
                            receiptRow(icon: "bed.double.fill", title: "Sleep from Apple Health",
                                value: sleepValue, detail: sleepDetail)
                            receiptRow(icon: "chart.bar", title: "Screen Time reports",
                                value: screenTimeValue, detail: screenTimeDetail)
                        }
                    }
                    .padding(.top, AppSpacing.sm)
                }
                .font(AppTypography.caption)
                .tint(AppColors.grass)
                .frame(minHeight: 44)
            }
        }
    }

    private func morningSummary(_ morning: MorningQuietOccurrence) -> String {
        switch morning.outcome {
        case .scheduled: return "Planned · \(OllieFormat.time(morning.scheduledStart))"
        case .active: return "In progress"
        case .skipped: return "Skipped"
        case .finished: return "\(morning.eligibleElapsedMinutes(at: morning.endedAt ?? morning.scheduledEnd)) min"
        }
    }

    private func compactRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.grass)
                .accessibilityHidden(true)
            if dynamicTypeSize.isAccessibilitySize {
                stackedReceiptRowHeader(title: title, value: value)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack {
                        Text(title).fixedSize()
                        Spacer(minLength: AppSpacing.xs)
                        Text(value).fixedSize()
                    }
                    stackedReceiptRowHeader(title: title, value: value)
                }
            }
        }
        .font(AppTypography.body)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) timer: \(value)")
    }

    private var elapsedLabel: String {
        guard let run else { return "Under 1 min" }
        let seconds = FocusRunRules.receiptDurationSeconds(for: run)
        guard seconds >= 60 else {
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
        case .approved: return "Access granted"
        case .unavailable: return "Not available yet"
        case .notDetermined: return "Not connected"
        case .denied: return "Needs permission"
        }
    }

    private var screenTimeDetail: String {
        switch screenTimeAuthorization {
        case .approved:
            return "Authorization is separate from observed selected-app limits and optional usage reports"
        case .unavailable:
            return "Late-evening and morning reports are unavailable on this device"
        case .notDetermined:
            return "Connect Screen Time in Nights to see both reports"
        case .denied:
            return "Screen Time access has not been granted"
        }
    }

    private func receiptRow(icon: String, title: String, value: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.grass)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                if dynamicTypeSize.isAccessibilitySize {
                    stackedReceiptRowHeader(title: title, value: value)
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(title)
                                .font(AppTypography.caption)
                            Spacer(minLength: AppSpacing.xs)
                            Text(value)
                                .font(AppTypography.caption)
                                .multilineTextAlignment(.trailing)
                        }
                        stackedReceiptRowHeader(title: title, value: value)
                    }
                }
                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
    }

    private func stackedReceiptRowHeader(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title)
                .font(AppTypography.caption)
            Text(value)
                .font(AppTypography.caption)
        }
    }

    private func recordedMinutesDetail(for run: FocusRun) -> String {
        run.nightWatchPlan?.role == .additionalQuiet
            ? "Elapsed timer minutes. Farm progress excludes brief access and is saved separately."
            : "Time on the timer before your planned bedtime. Farm progress also includes eligible overnight time."
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
