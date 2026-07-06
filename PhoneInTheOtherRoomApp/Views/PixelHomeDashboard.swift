import SwiftUI

struct PixelHomeDashboard: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @ObservedObject private var watch: WatchConnectivityManager
    @State private var showRunSetup = false

    init(watch: WatchConnectivityManager = .shared) {
        self._watch = ObservedObject(initialValue: watch)
    }

    var body: some View {
        PixelHomeDashboardContent(
            progress: viewModel.coordinator.progress,
            analyticsRecords: viewModel.analyticsRecords,
            watchReachable: watch.isReachable
        ) {
            showRunSetup = true
        }
        .navigationDestination(isPresented: $showRunSetup) {
            FocusRunSetupView()
                .environmentObject(viewModel)
        }
    }
}

private struct PixelHomeDashboardContent: View {
    var progress: UserProgress
    var analyticsRecords: [AnalyticsDayRecord]
    var watchReachable: Bool
    var onStartRun: () -> Void

    private let sheepRewardRunGoal = 3

    private var today: DailyFocusRecord { progress.todayRecord }
    private var dailyGoalMinutes: Int { AppGoals.dailyFocusMinutes }
    private var goalProgress: Double {
        min(1, Double(today.completedFocusMinutes) / Double(max(1, dailyGoalMinutes)))
    }
    private var sheepRewardRunCount: Int {
        max(0, progress.totalCompletedRuns % sheepRewardRunGoal)
    }
    private var nextSheepRewardProgress: Double {
        Double(sheepRewardRunCount) / Double(sheepRewardRunGoal)
    }
    private var nextSheepRewardLabel: String {
        "\(sheepRewardRunCount) / \(sheepRewardRunGoal)"
    }
    private var nextSheepRewardDetail: String {
        let remaining = sheepRewardRunGoal - sheepRewardRunCount
        let runLabel = remaining == 1 ? "Focus Run" : "Focus Runs"
        return "Complete \(remaining) more \(runLabel) to discover a new sheep!"
    }
    private var watchStatusValue: String {
        watchReachable ? "Ready" : "Offline"
    }
    private var watchStatusDetail: String {
        watchReachable ? "Connected" : "Open Watch app"
    }

    var body: some View {
        VStack(spacing: 16) {
            HomeFocusProgressBlock(
                completedMinutes: today.completedFocusMinutes,
                goalMinutes: dailyGoalMinutes,
                progress: goalProgress
            )

            DogRoomScene(mood: progress.ollieDailyStatus.mood)

            PrimaryGreenCTA(
                title: "Start Focus Run",
                subtitle: "Leave your phone in another room",
                icon: "door.left.hand.open",
                assetName: AssetSlot.Home.door
            ) { onStartRun() }

            homeMetricRow

            WeeklyComparisonCard(
                focusValues: focusChartValues,
                screenValues: screenChartValues,
                focusAverage: averageFocusLabel,
                screenAverage: averageScreenTimeLabel
            )

            AchievementRow(
                title: "Touched Some Grass",
                detail: "Spend 10 hours away from your phone",
                icon: "medal.fill",
                assetName: AssetSlot.Missions.achievementIcon,
                progress: min(1, Double(progress.totalFocusMinutes) / 600),
                progressLabel: "\(min(10, progress.totalFocusMinutes / 60)) / 10"
            )

            AchievementRow(
                title: "Next Sheep Reward",
                detail: nextSheepRewardDetail,
                icon: "cloud.fill",
                assetName: AssetSlot.Sheep.cream,
                progress: nextSheepRewardProgress,
                progressLabel: nextSheepRewardLabel
            )

            OllieTipRow()
#if DEBUG
            // Wind-down scheduling is not built yet; hidden from release (no "coming soon").
            BedtimeProtectionRow()
#endif
        }
    }

    private var homeMetricRow: some View {
        HStack(spacing: 10) {
            PixelMetricCard(
                title: "Daily Streak",
                icon: "flame.fill",
                value: "\(progress.currentStreak) days",
                detail: progress.currentStreak == 0 ? "Start today" : "Keep it going!",
                accent: AppColors.amber,
                footer: "\(lastSevenDays.filter { $0.completedFocusMinutes > 0 }.count) / 7"
            )
            PixelMetricCard(
                title: "Screen Time Today",
                icon: "iphone",
                assetName: AssetSlot.Stats.phone,
                value: todayAnalytics.screenTimeMinutes.map(formatMinutes) ?? "Add data",
                detail: todayAnalytics.screenTimeSource?.rawValue ?? "Manual entry",
                accent: AppColors.lavender
            )
            PixelMetricCard(
                title: "Apple Watch",
                icon: "applewatch",
                assetName: AssetSlot.Stats.watch,
                value: watchStatusValue,
                detail: watchStatusDetail,
                accent: AppColors.grass
            )
        }
    }

    private var focusChartValues: [Double] {
        let values = lastSevenDays.map { min(1, Double($0.completedFocusMinutes) / 150) }
        return values
    }

    private var screenChartValues: [Double] {
        let values = lastSevenAnalytics.map { record -> Double in
            guard let minutes = record.screenTimeMinutes else { return 0 }
            return min(1, Double(minutes) / 480)
        }
        return values
    }

    private var averageFocusLabel: String {
        guard !lastSevenDays.isEmpty else { return "0m / day" }
        let average = lastSevenDays.reduce(0) { $0 + $1.completedFocusMinutes } / lastSevenDays.count
        return "\(average / 60)h \(average % 60)m / day"
    }

    private var averageScreenTimeLabel: String {
        let values = lastSevenAnalytics.compactMap(\.screenTimeMinutes)
        guard !values.isEmpty else { return "No data" }
        let average = values.reduce(0, +) / values.count
        return "\(average / 60)h \(average % 60)m / day"
    }

    private var lastSevenDays: [DailyFocusRecord] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return progress.record(for: day, calendar: calendar) ?? DailyFocusRecord(day: day)
        }
    }

    private var lastSevenAnalytics: [AnalyticsDayRecord] {
        Array(analyticsRecords.suffix(7))
    }

    private var todayAnalytics: AnalyticsDayRecord {
        analyticsRecords.last ?? AnalyticsDayRecord(day: Date())
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 { return "\(minutes / 60)h \(minutes % 60)m" }
        return "\(minutes)m"
    }
}

private struct HomeFocusProgressBlock: View {
    var completedMinutes: Int
    var goalMinutes: Int
    var progress: Double

    var body: some View {
        VStack(spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(completedMinutes)")
                    .font(.system(size: 46, weight: .black, design: .monospaced))
                Text("/ \(goalMinutes) min")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(AppColors.muted)
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 23, weight: .black))
            }
            Text("Focus Time Today")
                .font(.system(size: 23, weight: .black, design: .monospaced))
            ProgressStarBar(
                progress: progress,
                leftLabel: "0 min",
                rightLabel: "\(goalMinutes) min"
            )
            .padding(.horizontal, 18)
        }
        .foregroundStyle(AppColors.ink)
    }
}

private struct DogRoomScene: View {
    var mood: OllieMood

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear

            HStack(alignment: .bottom) {
                VStack(spacing: 28) {
                    PixelAssetImage(name: AssetSlot.Home.window)
                        .frame(width: 62, height: 54)
                    PixelAssetImage(name: AssetSlot.Home.plant)
                        .frame(width: 82, height: 114)
                }
                Spacer()
                PixelAssetImage(name: AssetSlot.Home.door)
                    .frame(width: 88, height: 164)
                    .padding(.bottom, 4)
            }
            .padding(.horizontal, 10)

            PixelAssetImage(name: AssetSlot.Dog.idle)
                .frame(width: 216, height: 254)
                .offset(y: 8)
        }
        .frame(height: 286)
        .accessibilityLabel("Ollie in the focus room")
    }
}

private struct OllieTipRow: View {
    var body: some View {
        HStack(spacing: 14) {
            PixelAssetImage(name: AssetSlot.Dog.idle)
                .frame(width: 82, height: 82)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Ollie's Tip")
                        .font(pixelFont(.subheadline))
                    Text("New")
                        .font(pixelFont(.caption2))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.grass, in: Capsule())
                }
                Text("Even short breaks from your phone can boost focus, mood, and sleep. Your brain loves a good reset!")
                    .font(pixelFont(.caption2))
                    .lineSpacing(3)
            }
            Spacer()
        }
        .padding(14)
        .background(AppColors.panel.opacity(0.88), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.stroke.opacity(0.18), lineWidth: 1))
    }
}

private struct BedtimeProtectionRow: View {
    var body: some View {
        HStack(spacing: 16) {
            PixelAssetImage(name: AssetSlot.Home.bedtimeMoon)
                .frame(width: 72)
            VStack(alignment: .leading, spacing: 6) {
                Text("Bedtime Protection")
                    .font(pixelFont(.subheadline))
                Text("Set a phone-away wind-down to sleep better.")
                    .font(pixelFont(.caption2))
            }
            Spacer()
            VStack(spacing: 8) {
                Text("Not Set")
                    .font(pixelFont(.caption2))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: 8))
                Text("Set Wind-Down")
                    .font(pixelFont(.caption2))
                    .foregroundStyle(AppColors.grass)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppColors.grass, lineWidth: 1.4))
            }
            Image(systemName: "chevron.right")
                .font(.title2.weight(.black))
                .foregroundStyle(AppColors.muted)
        }
        .padding(14)
        .background(AppColors.panel.opacity(0.88), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.stroke.opacity(0.18), lineWidth: 1))
    }
}

#Preview("Watch disconnected") {
    NavigationStack {
        ScrollView {
            PixelHomeDashboardContent(
                progress: PixelHomeDashboardPreviewData.progress,
                analyticsRecords: PixelHomeDashboardPreviewData.analyticsRecords,
                watchReachable: false,
                onStartRun: {}
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(AppColors.paper)
    }
}

private enum PixelHomeDashboardPreviewData {
    static var progress: UserProgress {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        return UserProgress(
            totalCompletedRuns: 4,
            totalFocusMinutes: 135,
            currentStreak: 2,
            longestStreak: 5,
            rewardsCollected: 4,
            ollieLevel: 2,
            dailyFocusRecords: [
                DailyFocusRecord(day: today, completedFocusMinutes: 45, successfulRuns: 1, rewardsEarned: 1),
                DailyFocusRecord(day: yesterday, completedFocusMinutes: 90, successfulRuns: 2, rewardsEarned: 2)
            ],
            sheepBalance: 9,
            coinBalance: 45,
            totalSheepEarned: 9,
            totalCoinsEarned: 45
        )
    }

    static var analyticsRecords: [AnalyticsDayRecord] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return AnalyticsDayRecord(day: day, screenTimeMinutes: 180 + offset * 12)
        }
    }
}
