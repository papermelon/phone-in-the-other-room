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
    @State private var showsHealthAccessHelp = false

    var body: some View {
        Group {
            if isEmbedded {
                disclosure
                    .padding(.vertical, AppSpacing.sm)
            } else {
                PixelCard { disclosure }
            }
        }
        .sheet(isPresented: $showsHealthAccessHelp) {
            HealthConnectionAccessHelpSheet()
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
        switch viewModel.healthSleepConnectionPresentation {
        case .unavailable:
            return "Unavailable on this iPhone"
        case .connect:
            return "Optional · not connected"
        case .checking:
            return "Checking for sleep data…"
        case let .dataAvailable(sampleDate, _):
            return "Sleep data available · \(sampleDate.formatted(.dateTime.month(.abbreviated).day()))"
        case .noData:
            return "No sleep data for this period"
        case .staleData:
            return "Couldn’t refresh sleep context"
        }
    }

    @ViewBuilder
    private var healthDetails: some View {
        switch viewModel.healthSleepConnectionPresentation {
        case .unavailable:
            Text("Apple Health sleep data is unavailable on this device.")
                .font(AppTypography.body)
        case .connect:
            Text("Connect Apple Health to show optional sleep duration and available stage context beside your nights.")
                .font(AppTypography.body)
            Button("Connect Apple Health", action: viewModel.connectAppleHealthSleep)
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
        case .checking:
            HStack(spacing: AppSpacing.sm) {
                ProgressView()
                    .tint(AppColors.grass)
                Text("Checking for sleep data…")
                    .font(AppTypography.body)
            }
        case .dataAvailable, .noData, .staleData:
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if let availableSleep {
                    sleepDetails(availableSleep.sleep, isStale: availableSleep.isStale)
                    if let comparison = viewModel.sleepOutcomeComparison {
                        Divider()
                        comparisonDetails(comparison)
                    }
                } else {
                    Text(noDataDetail)
                        .font(AppTypography.body)
                }
                healthRefreshAction
            }
        }
    }

    private var noDataDetail: String {
        switch viewModel.healthSleepConnectionPresentation {
        case .noData:
            return "Apple Health did not return a matching sleep sample for this period. This does not tell Counting Sheep whether read access was allowed."
        case .staleData:
            return "Counting Sheep could not refresh Apple Health just now. Any older sleep context stays dated rather than being treated as current."
        default:
            return "No matching sleep sample is available yet."
        }
    }

    private var healthRefreshAction: some View {
        let title: String
        switch viewModel.healthSleepConnectionPresentation {
        case .staleData: title = "Retry"
        default: title = "Refresh"
        }
        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Button(title, action: viewModel.retryAppleHealthConnection)
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
            Button("Manage access") { showsHealthAccessHelp = true }
                .buttonStyle(.plain)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.grass)
                .frame(minHeight: 44, alignment: .leading)
                .accessibilityHint("Explains how to review Apple Health access")
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
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls)
    @State private var showAppPicker = false
#endif

    var body: some View {
        Group {
            ScreenTimeConnectionStatusCard(
                presentation: viewModel.screenTimeConnectionPresentation,
                onConnect: viewModel.connectScreenTime,
                onChooseSelection: {
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls)
                    showAppPicker = true
#endif
                },
                isEmbedded: isEmbedded
            )
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls)
            if viewModel.screenTimeAuthorization == .approved,
               !viewModel.bedtimeActivitySelection.phoneOtherIsEmpty {
                Divider()
                ScreenTimeBookendCard(
                    showAppPicker: $showAppPicker,
                    mode: .reports,
                    isEmbedded: isEmbedded
                )
                .environmentObject(viewModel)
            }
#endif
        }
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls)
        .familyActivityPicker(
            headerText: "Choose apps or categories for reports and future Wind Down or Phone Away app protection.",
            footerText: "Changing this does not alter a current session. Your selection stays in Apple’s Screen Time system; website entries are ignored.",
            isPresented: $showAppPicker,
            selection: $viewModel.bedtimeActivitySelection
        )
        .onChange(of: viewModel.bedtimeActivitySelection) { _, _ in
            viewModel.saveScreenTimeSelection(.bedtime)
        }
#endif
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
