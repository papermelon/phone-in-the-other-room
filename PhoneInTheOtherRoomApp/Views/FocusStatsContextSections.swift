import SwiftUI

struct NightsContextSection: View {
    @ObservedObject var viewModel: FocusRunViewModel
    let record: NightWatchRecord?

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("CONTEXT")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(contextSubtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
                .padding(.bottom, AppSpacing.sm)

                if record != nil {
                    Divider()
                    MorningCheckInCard(record: record, presentation: .embedded)
                        .environmentObject(viewModel)
                }

                Divider()
                NightsHealthContext(
                    viewModel: viewModel,
                    record: record,
                    isEmbedded: true
                )

                Divider()
                NightsScreenTimeContext(viewModel: viewModel, isEmbedded: true)
            }
        }
    }

    private var contextSubtitle: String {
        guard let record else {
            return "Optional local context appears after a completed Wind Down."
        }
        return "Night ending \(record.plan.wakeTime.formatted(.dateTime.weekday(.wide).month(.wide).day()))"
    }
}

struct NightsHealthContext: View {
    @ObservedObject var viewModel: FocusRunViewModel
    var record: NightWatchRecord?
    var isEmbedded = false
    @State private var isExpanded = false

    var body: some View {
        Group {
            if isEmbedded {
                disclosure
                    .padding(.vertical, AppSpacing.sm)
            } else {
                PixelCard { disclosure }
            }
        }
    }

    private var disclosure: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            healthDetails
                .padding(.top, AppSpacing.sm)
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "heart.text.square.fill")
                    .foregroundStyle(AppColors.grass)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Apple Health")
                        .font(AppTypography.headline)
                    Text(summary)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
        .tint(AppColors.grass)
    }

    private var matchedSleep: SleepSummary? {
        guard let record else { return viewModel.lastNightSleep }
        return viewModel.recentNightSleeps.first { sleep in
            guard let date = sleep.nightEndingDate ?? sleep.endDate else { return false }
            return Calendar.current.isDate(date, inSameDayAs: record.plan.wakeTime)
        }
    }

    private var availableSleep: (sleep: SleepSummary, isStale: Bool)? {
        if let matchedSleep { return (matchedSleep, false) }
        if let older = viewModel.recentNightSleeps.first { return (older, true) }
        return nil
    }

    private var summary: String {
        switch viewModel.sleepAuthorization {
        case .unavailable: return "Unavailable on this iPhone"
        case .notRequested: return "Optional · not connected"
        case .error: return "Could not load sleep context"
        case .requested:
            if viewModel.isRefreshingSleep { return "Checking Apple Health…" }
            guard let availableSleep else { return "No matching sleep sample yet" }
            return availableSleep.isStale
                ? "Latest sample: \(nightEndingLabel(for: availableSleep.sleep))"
                : "Sleep recorded for \(nightEndingLabel(for: availableSleep.sleep))"
        }
    }

    @ViewBuilder
    private var healthDetails: some View {
        switch viewModel.sleepAuthorization {
        case .unavailable:
            Text("Apple Health sleep data is unavailable on this device.")
                .font(AppTypography.body)
        case .notRequested:
            Text("Connect Apple Health in Settings when you want sleep duration and available stage context beside your nights.")
                .font(AppTypography.body)
        case .error:
            Text("Apple Health could not complete the request. You can try again from the Health app or Settings.")
                .font(AppTypography.body)
        case .requested:
            if viewModel.isRefreshingSleep {
                HStack(spacing: AppSpacing.sm) {
                    ProgressView()
                        .tint(AppColors.grass)
                    Text("Checking Apple Health…")
                        .font(AppTypography.body)
                }
            } else if let availableSleep {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    sleepDetails(availableSleep.sleep, isStale: availableSleep.isStale)
                    if let comparison = viewModel.sleepOutcomeComparison {
                        Divider()
                        comparisonDetails(comparison)
                    }
                }
            } else {
                Text("No sleep sample was found for this night. Health context will appear when Apple has a matching sample.")
                    .font(AppTypography.body)
            }
        }
    }

    private func sleepDetails(_ sleep: SleepSummary, isStale: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(isStale ? "Latest available sample" : "Matching sleep sample")
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.muted)
            Text(sleep.durationLabel)
                .font(AppTypography.display(30))
            Text(nightEndingLabel(for: sleep))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.grass)
            if let start = sleep.startDate, let end = sleep.endDate {
                Text(OllieFormat.timeRange(from: start, to: end))
                    .font(AppTypography.body)
            }
            if sleep.stages.hasStages {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppSpacing.sm) {
                        stageMetric("Core", seconds: sleep.stages.coreSeconds)
                        stageMetric("Deep", seconds: sleep.stages.deepSeconds)
                        stageMetric("REM", seconds: sleep.stages.remSeconds)
                    }
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        stageMetric("Core", seconds: sleep.stages.coreSeconds)
                        stageMetric("Deep", seconds: sleep.stages.deepSeconds)
                        stageMetric("REM", seconds: sleep.stages.remSeconds)
                    }
                }
            } else {
                Text("Apple Health did not provide separate Core, Deep, or REM stages for this sample.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
            if let wakeRange = SleepIntervalMath.wakeTimeRange(for: viewModel.recentNightSleeps) {
                Text("Wake-time range over \(wakeRange.sampleCount) available nights: \(wakeRangeLabel(wakeRange)). This is context, not a grade.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

    private func comparisonDetails(_ comparison: SleepOutcomeComparison) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("YOUR LOCAL COMPARISON")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            Text(comparisonSentence(comparison))
                .font(AppTypography.body)
            Text("This is an association in your available records, not proof that Wind Down caused the difference.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
        }
    }

    private func comparisonSentence(_ comparison: SleepOutcomeComparison) -> String {
        let difference = comparison.differenceMinutes
        let comparisonText: String
        if difference == 0 {
            comparisonText = "the same"
        } else {
            comparisonText = "\(abs(difference)) minutes \(difference > 0 ? "longer" : "shorter")"
        }
        return "Across \(comparison.protectedNightCount) nights the phone slept in the other room and \(comparison.baselineNightCount) other measured nights, recorded sleep averaged \(comparisonText) on those phone-away nights."
    }

    private func stageMetric(_ title: String, seconds: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
            Text(durationLabel(seconds))
                .font(AppTypography.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func nightEndingLabel(for sleep: SleepSummary) -> String {
        let date = sleep.nightEndingDate ?? sleep.endDate ?? Date()
        return "night ending \(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))"
    }

    private func durationLabel(_ seconds: TimeInterval) -> String {
        let minutes = OllieFormat.minutes(seconds)
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    private func wakeRangeLabel(_ range: WakeTimeRange) -> String {
        range.minutes >= 60 ? "\(range.minutes / 60)h \(range.minutes % 60)m" : "\(range.minutes)m"
    }
}

struct NightsScreenTimeContext: View {
    @ObservedObject var viewModel: FocusRunViewModel
    var isEmbedded = false

    var body: some View {
        switch viewModel.screenTimeAuthorization {
        case .unavailable:
            statusContent(
                detail: "Unavailable on this iPhone. Counting Sheep keeps working without it."
            )
        case .notDetermined:
            statusContent(
                detail: "Optional · connect in Settings for separate evening and morning reports."
            )
        case .denied:
            statusContent(
                detail: "Access is off. You can change it later in Settings."
            )
        case .approved:
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls)
            ScreenTimeBookendCard(
                showAppPicker: .constant(false),
                mode: .reports,
                isEmbedded: isEmbedded
            )
            .environmentObject(viewModel)
#else
            statusContent(
                detail: "Connected, but the report extension is unavailable in this build."
            )
#endif
        }
    }

    @ViewBuilder
    private func statusContent(detail: String) -> some View {
        let content = HStack(spacing: AppSpacing.sm) {
            Image(systemName: "iphone.slash")
                .foregroundStyle(AppColors.grass)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Screen Time")
                    .font(AppTypography.headline)
                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }

        if isEmbedded {
            content.padding(.vertical, AppSpacing.sm)
        } else {
            PixelCard { content }
        }
    }
}

#Preview("Nights context · disconnected") {
    let viewModel = FocusRunViewModel()
    viewModel.sleepAuthorization = .notRequested
    viewModel.screenTimeAuthorization = .notDetermined
    return NightsContextSection(viewModel: viewModel, record: nil)
        .padding()
        .background(AppColors.paper)
}

#Preview("Nights context · unavailable · dark") {
    let viewModel = FocusRunViewModel()
    viewModel.sleepAuthorization = .unavailable
    viewModel.screenTimeAuthorization = .unavailable
    return NightsContextSection(viewModel: viewModel, record: nil)
        .padding()
        .background(AppColors.paper)
        .preferredColorScheme(.dark)
}
