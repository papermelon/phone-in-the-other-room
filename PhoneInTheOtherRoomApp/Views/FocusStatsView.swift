import SwiftUI

#if SCREEN_TIME_REPORTS && canImport(DeviceActivity)
import DeviceActivity
#endif
struct FocusStatsView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    private var progress: UserProgress { viewModel.coordinator.progress }
    private var completedRecords: [DailyFocusRecord] {
        progress.dailyFocusRecords
            .filter { $0.successfulRuns > 0 }
            .sorted { $0.day > $1.day }
    }
    private var recentNight: DailyFocusRecord? { completedRecords.first }
    private var latestQuietTimeResult: NightWatchRecord? {
        viewModel.nightWatchRecords
            .filter { $0.outcome != .active }
            .max { resultDate($0) < resultDate($1) }
    }
    private var latestProtectedResult: NightWatchRecord? {
        viewModel.nightWatchRecords
            .filter { $0.outcome == .completed }
            .max { resultDate($0) < resultDate($1) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header
                flockCard
                SheepWantedPostersCard(
                    searchState: viewModel.sheepSearchState,
                    protectedNightNumber: progress.totalCompletedRuns + 1
                )
                if let outcome = viewModel.latestSheepSearchOutcome {
                    SheepSearchOutcomeCard(
                        outcome: outcome,
                        showExactOdds: viewModel.sheepSearchState.showExactOdds
                    )
                }
                recentNightCard
                sleepCard
                sleepOutcomeCard
                MorningCheckInCard()
                    .environmentObject(viewModel)
                sevenNightCard
                screenTimeCard
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .task {
            if viewModel.sleepAuthorization == .requested {
                viewModel.refreshSleepSummary()
            }
        }
    }

    private var sleepOutcomeCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                sectionTitle("Wind Down & sleep", icon: "chart.xyaxis.line")
                if let comparison = viewModel.sleepOutcomeComparison {
                    Text(
                        comparison.differenceMinutes >= 0
                            ? "\(comparison.differenceMinutes) min more sleep on average"
                            : "\(abs(comparison.differenceMinutes)) min less sleep on average"
                    )
                        .font(AppTypography.headline)
                    Text(
                        "Protected nights averaged \(sleepMinutesLabel(comparison.protectedAverageSleepMinutes)); other measured nights averaged \(sleepMinutesLabel(comparison.baselineAverageSleepMinutes))."
                    )
                        .font(AppTypography.body)
                    Text(
                        "Based on \(comparison.protectedNightCount) protected and \(comparison.baselineNightCount) other nights. This is an association in your own history, not proof that Wind Down caused the change."
                    )
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                } else if viewModel.sleepAuthorization == .requested {
                    let protectedCount = viewModel.impactSamples.filter {
                        $0.completedRitual && $0.sleepMinutes != nil
                    }.count
                    let baselineCount = viewModel.impactSamples.filter {
                        !$0.completedRitual && $0.sleepMinutes != nil
                    }.count
                    Text("A little more history will make this comparison useful.")
                        .font(AppTypography.body)
                    Text("Counting Sheep waits for at least two protected nights and two other nights with Apple Health sleep data. Right now: \(protectedCount) protected, \(baselineCount) other.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                } else {
                    Text("Connect Apple Health to compare completed Wind Down with measured sleep duration and available stages.")
                        .font(AppTypography.body)
                    Text("The comparison is calculated on this iPhone.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Nights")
                .font(AppTypography.display(34))
            Text("A simple record of the quiet you protected around sleep.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.muted)
        }
    }

    private var flockCard: some View {
        PixelCard {
            HStack(spacing: AppSpacing.md) {
                PixelAssetImage(name: AssetSlot.Sheep.common)
                    .frame(width: 70, height: 70)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("YOUR FLOCK")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text("\(viewModel.sheepSearchState.foundSheepIDs.count) sheep found")
                        .font(AppTypography.headline)
                    Text("Ollie has followed \(String(format: "%.1f", viewModel.sheepSearchState.totalTrailDistance)) trail kilometres. Every found sheep has its own story.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var recentNightCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                sectionTitle("Latest Wind Down", icon: "moon.stars.fill")
                if let result = latestQuietTimeResult {
                    Text(result.outcome == .endedEarly ? "Ended early" : "Protected night")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.grass)
                    Text("\(quietMinutes(result)) min")
                        .font(AppTypography.display(32))
                    Text(
                        result.outcome == .endedEarly
                            ? "Wind Down recorded before the session ended. Overnight hours are not counted."
                            : "Phone-free time before bed and after waking. Overnight hours are not counted."
                    )
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    Text("Finished \(resultDateLabel(resultDate(result)))")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                    if result.outcome == .endedEarly {
                        latestProtectedNightSummary
                    }
                } else if let recentNight {
                    Text("Protected night")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.grass)
                    Text("\(recentNight.completedFocusMinutes) min")
                        .font(AppTypography.display(32))
                    Text("Phone-free time before bed and after waking. Overnight hours are not counted.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    Text("Night beginning \(nightDateLabel(recentNight.day))")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                } else {
                    Text("Your first Wind Down will appear here.")
                        .font(AppTypography.body)
                    Text("Counting Sheep records quiet minutes before bed and after waking.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
    }

    @ViewBuilder
    private var sleepCard: some View {
        switch viewModel.sleepAuthorization {
        case .unavailable:
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    sectionTitle("Sleep from Apple Health", icon: "bed.double.fill")
                    Text("Apple Health sleep data is unavailable on this device.")
                        .font(AppTypography.body)
                }
            }
        case .notRequested:
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    sectionTitle("Sleep from Apple Health", icon: "bed.double.fill")
                    Text("Connect Apple Health in More to show sleep context beside your nights.")
                        .font(AppTypography.body)
                }
            }
        case .error:
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    sectionTitle("Sleep from Apple Health", icon: "bed.double.fill")
                    Text("Apple Health could not complete the request. You can try again from the Health app or Settings.")
                        .font(AppTypography.body)
                }
            }
        case .requested:
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    sectionTitle("Sleep from Apple Health", icon: "bed.double.fill")
                    if let sleep = viewModel.lastNightSleep {
                        Text(nightEndingLabel(for: sleep))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.grass)
                        Text(sleep.durationLabel)
                            .font(AppTypography.display(32))
                        if let start = sleep.startDate, let end = sleep.endDate {
                            Text("\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))")
                                .font(AppTypography.body)
                        }
                        if sleep.stages.hasStages {
                            HStack(spacing: AppSpacing.sm) {
                                sleepStageMetric("Core", seconds: sleep.stages.coreSeconds)
                                sleepStageMetric("Deep", seconds: sleep.stages.deepSeconds)
                                sleepStageMetric("REM", seconds: sleep.stages.remSeconds)
                            }
                        }
                        Text(sleepSourceDetail(sleep))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    } else {
                        Text("No sleep sample was found for \(expectedNightEndingLabel).")
                            .font(AppTypography.body)
                        if let olderSleep = viewModel.recentNightSleeps.first {
                            Divider()
                            Text("Latest available Apple Health sample")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.muted)
                            Text(olderSleep.durationLabel)
                                .font(AppTypography.headline)
                            Text(nightEndingLabel(for: olderSleep))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.grass)
                        }
                    }
                    Text("Apple's Sleep Score can be viewed in the Health app, but Apple does not currently expose that score through HealthKit.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
    }

    private var sevenNightCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                sectionTitle("Last 7 nights", icon: "calendar")
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    quietMetric(value: "\(lastSevenProtectedCount)", label: "protected")
                    quietMetric(value: "\(lastSevenMinutes)m", label: "Wind Down")
                    if let wakeTimeRange {
                        quietMetric(value: wakeRangeLabel(wakeTimeRange), label: "wake range")
                    }
                }
                HStack(spacing: AppSpacing.sm) {
                    ForEach(lastSevenDays, id: \.day) { record in
                        VStack(spacing: AppSpacing.xs) {
                            Circle()
                                .fill(record.successfulRuns > 0 ? AppColors.grass : AppColors.surfaceMuted)
                                .frame(width: 18, height: 18)
                                .overlay(Circle().stroke(AppColors.stroke.opacity(0.16), lineWidth: 1))
                            Text(record.day.formatted(.dateTime.weekday(.narrow)))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.muted)
                            Text(record.day.formatted(.dateTime.day()))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            record.day.formatted(.dateTime.weekday(.wide).month().day())
                        )
                        .accessibilityValue(
                            record.successfulRuns > 0
                                ? "\(record.completedFocusMinutes) quiet minutes"
                                : "No protected night"
                        )
                    }
                }
                Text("Blank nights are simply blank. Tonight can always be a fresh start.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                if let wakeTimeRange {
                    Text("Wake range uses \(wakeTimeRange.sampleCount) nights returned by Apple Health. It is context, not a grade.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
    }

    @ViewBuilder
    private var screenTimeCard: some View {
        switch viewModel.screenTimeAuthorization {
        case .unavailable:
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    sectionTitle("Late evening & morning screen time", icon: "iphone.slash")
                    Text("Screen Time reports are unavailable on this device.")
                        .font(AppTypography.body)
                    Text("On a supported iPhone, both reports appear here in Nights.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
        case .notDetermined:
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    sectionTitle("Late evening & morning screen time", icon: "iphone.slash")
                    Text("Connect Screen Time and choose report windows in More.")
                        .font(AppTypography.body)
                }
            }
        case .denied:
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    sectionTitle("Late evening & morning screen time", icon: "iphone.slash")
                    Text("Screen Time access is off. Counting Sheep will keep working without it.")
                        .font(AppTypography.body)
                    Text("You can change permission later in Settings.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
        case .approved:
            approvedScreenTimeCard
        }
    }

    @ViewBuilder
    private var approvedScreenTimeCard: some View {
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls)
        ScreenTimeBookendCard(showAppPicker: .constant(false), mode: .reports)
            .environmentObject(viewModel)
#else
        EmptyView()
#endif
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(AppTypography.headline)
            .foregroundStyle(AppColors.ink)
    }

    private func quietMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(value)
                .font(AppTypography.display(28))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lastSevenDays: [DailyFocusRecord] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }
            return progress.record(for: day, calendar: calendar) ?? DailyFocusRecord(day: day)
        }
    }

    private var lastSevenProtectedCount: Int {
        lastSevenDays.filter { $0.successfulRuns > 0 }.count
    }

    private var lastSevenMinutes: Int {
        lastSevenDays.reduce(0) { $0 + $1.completedFocusMinutes }
    }

    private var wakeTimeRange: WakeTimeRange? {
        SleepIntervalMath.wakeTimeRange(for: viewModel.recentNightSleeps)
    }

    private func wakeRangeLabel(_ range: WakeTimeRange) -> String {
        if range.minutes >= 60 {
            return "\(range.minutes / 60)h \(range.minutes % 60)m"
        }
        return "\(range.minutes)m"
    }

    @ViewBuilder
    private var latestProtectedNightSummary: some View {
        if let protectedResult = latestProtectedResult,
           protectedResult.id != latestQuietTimeResult?.id {
            Divider()
            Text("Latest protected night")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
            Text("\(quietMinutes(protectedResult)) min · finished \(resultDateLabel(resultDate(protectedResult)))")
                .font(AppTypography.body)
        } else if let recentNight {
            Divider()
            Text("Latest protected night")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
            Text("\(recentNight.completedFocusMinutes) min · \(nightDateLabel(recentNight.day))")
                .font(AppTypography.body)
        }
    }

    private var expectedNightEndingLabel: String {
        "the night ending \(nightDateLabel(Date()))"
    }

    private func nightEndingLabel(for sleep: SleepSummary) -> String {
        let date = sleep.nightEndingDate ?? sleep.endDate ?? Date()
        return "Night ending \(nightDateLabel(date))"
    }

    private func sleepStageMetric(
        _ title: String,
        seconds: TimeInterval
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
            Text(sleepDurationLabel(seconds))
                .font(AppTypography.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sleepSourceDetail(_ sleep: SleepSummary) -> String {
        let source = sleep.sourceName.map { " from \($0)" } ?? ""
        if sleep.stages.hasStages {
            return "Sleep duration and available stages recorded in Apple Health\(source)."
        }
        return "Time asleep recorded in Apple Health\(source). Stages were not available for this night."
    }

    private func sleepDurationLabel(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds / 60))
        return sleepMinutesLabel(minutes)
    }

    private func sleepMinutesLabel(_ minutes: Int) -> String {
        minutes >= 60
            ? "\(minutes / 60)h \(minutes % 60)m"
            : "\(minutes)m"
    }

    private func nightDateLabel(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private func resultDateLabel(_ date: Date) -> String {
        date.formatted(
            .dateTime.weekday(.wide).month(.wide).day().hour().minute()
        )
    }

    private func resultDate(_ record: NightWatchRecord) -> Date {
        record.endedAt ?? record.updatedAt
    }

    private func quietMinutes(_ record: NightWatchRecord) -> Int {
        record.creditedWindDownMinutes + record.creditedMorningQuietMinutes
    }
}

#Preview("Empty nights") {
    NavigationStack {
        FocusStatsView()
            .environmentObject(FocusRunViewModel())
    }
}
