import SwiftUI

#if SCREEN_TIME_REPORTS && canImport(DeviceActivity)
import DeviceActivity
#endif
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
import FamilyControls
#endif

struct FocusStatsView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
    @State private var showBedtimePicker = false
#endif

    private var progress: UserProgress { viewModel.coordinator.progress }
    private var completedRecords: [DailyFocusRecord] {
        progress.dailyFocusRecords
            .filter { $0.successfulRuns > 0 }
            .sorted { $0.day > $1.day }
    }
    private var recentNight: DailyFocusRecord? { completedRecords.first }
    private var latestQuietTimeResult: RewardItem? {
        viewModel.coordinator.rewards
            .filter { $0.context != nil }
            .max { $0.earnedAt < $1.earnedAt }
    }
    private var latestProtectedResult: RewardItem? {
        viewModel.coordinator.rewards
            .filter {
                $0.rarity != .consolation
                    && ($0.context?.protectedNightNumber ?? 0) > 0
            }
            .max { $0.earnedAt < $1.earnedAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header
                recentNightCard
                sleepCard
                MorningCheckInCard()
                    .environmentObject(viewModel)
                sevenNightCard
                currentPlanCard
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
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        .familyActivityPicker(
            headerText: "Choose only the apps or categories you want Counting Sheep to show around sleep.",
            footerText: "Your selection stays in Apple's Screen Time system. Website entries are ignored.",
            isPresented: $showBedtimePicker,
            selection: $viewModel.bedtimeActivitySelection
        )
        .onChange(of: viewModel.bedtimeActivitySelection) { _, _ in
            viewModel.saveScreenTimeSelection(.bedtime)
        }
#endif
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

    private var recentNightCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                sectionTitle("Latest quiet time", icon: "moon.stars.fill")
                if let result = latestQuietTimeResult, let context = result.context {
                    Text(result.rarity == .consolation ? "Ended early" : "Protected night")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.grass)
                    Text("\(context.quietMinutes) min")
                        .font(AppTypography.display(32))
                    Text(
                        result.rarity == .consolation
                            ? "Quiet time recorded before the session ended. Overnight hours are not counted."
                            : "Phone-free time before bed and after waking. Overnight hours are not counted."
                    )
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    Text("Finished \(resultDateLabel(result.earnedAt))")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                    if result.rarity == .consolation {
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
                    Text("Your first quiet time will appear here.")
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
            IntegrationSetupCard(
                title: "Sleep from Apple Health",
                detail: "Connect Apple Health to show last night's time asleep and sleep window.",
                icon: "bed.double.fill",
                actionTitle: "Connect",
                action: viewModel.connectAppleHealthSleep
            )
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
                        Text("Time asleep recorded by Apple Health.")
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
                    quietMetric(value: "\(lastSevenMinutes)m", label: "quiet time")
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

    private var currentPlanCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                QuietWindowDurationEditor()
                    .environmentObject(viewModel)
                Text(viewModel.offlinePurpose.inAppDisplayPhrase)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.grass)
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
            IntegrationSetupCard(
                title: "Late evening & morning screen time",
                detail: "Connect Screen Time to see selected app use in evening and morning windows you choose.",
                icon: "iphone.slash",
                actionTitle: "Connect",
                action: viewModel.connectScreenTime
            )
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
        ScreenTimeBookendCard(showAppPicker: $showBedtimePicker)
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
           protectedResult.id != latestQuietTimeResult?.id,
           let context = protectedResult.context {
            Divider()
            Text("Latest protected night")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
            Text("\(context.quietMinutes) min · finished \(resultDateLabel(protectedResult.earnedAt))")
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

    private func nightDateLabel(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private func resultDateLabel(_ date: Date) -> String {
        date.formatted(
            .dateTime.weekday(.wide).month(.wide).day().hour().minute()
        )
    }
}

#Preview("Empty nights") {
    NavigationStack {
        FocusStatsView()
            .environmentObject(FocusRunViewModel())
    }
}
