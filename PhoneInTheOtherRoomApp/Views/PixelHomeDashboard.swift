import SwiftUI

struct PixelHomeDashboard: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var showRunSetup = false

    private var progress: UserProgress { viewModel.coordinator.progress }
    private var today: DailyFocusRecord { progress.todayRecord }
    private var dailyGoalMinutes: Int { AppGoals.dailyFocusMinutes }
    private var goalProgress: Double {
        min(1, Double(today.completedFocusMinutes) / Double(max(1, dailyGoalMinutes)))
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
            ) {
                showRunSetup = true
            }

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
                detail: "Complete 2 more Focus Runs to discover a new sheep!",
                icon: "cloud.fill",
                assetName: AssetSlot.Sheep.cream,
                progress: 1.0 / 3.0,
                progressLabel: "1 / 3"
            )

            OllieTipRow()
            BedtimeProtectionRow()
        }
        .navigationDestination(isPresented: $showRunSetup) {
            FocusRunSetupView()
                .environmentObject(viewModel)
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
                value: " ",
                detail: "Connected",
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
        Array(viewModel.analyticsRecords.suffix(7))
    }

    private var todayAnalytics: AnalyticsDayRecord {
        viewModel.analyticsRecords.last ?? AnalyticsDayRecord(day: Date())
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

private struct HomeDogFigure: View {
    var mood: OllieMood

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                Ellipse()
                    .fill(AppColors.stroke.opacity(0.13))
                    .frame(width: w * 0.72, height: h * 0.12)
                    .offset(y: h * 0.41)

                Capsule()
                    .fill(Color(red: 0.10, green: 0.11, blue: 0.10))
                    .frame(width: w * 0.52, height: h * 0.58)
                    .offset(y: h * 0.16)
                Capsule()
                    .fill(.white)
                    .frame(width: w * 0.27, height: h * 0.52)
                    .offset(y: h * 0.18)

                Circle()
                    .fill(Color(red: 0.10, green: 0.11, blue: 0.10))
                    .frame(width: w * 0.58, height: w * 0.58)
                    .offset(y: -h * 0.18)
                Capsule()
                    .fill(.white)
                    .frame(width: w * 0.20, height: h * 0.30)
                    .offset(y: -h * 0.18)

                ear(x: -w * 0.25, rotation: -24, width: w, height: h)
                ear(x: w * 0.25, rotation: 24, width: w, height: h)

                eye(x: -w * 0.12, width: w, height: h)
                eye(x: w * 0.12, width: w, height: h)
                Capsule()
                    .fill(AppColors.ink)
                    .frame(width: w * 0.14, height: h * 0.045)
                    .offset(y: -h * 0.08)
                Capsule()
                    .fill(Color(red: 0.92, green: 0.32, blue: 0.30))
                    .frame(width: w * 0.10, height: mood == .sad ? h * 0.018 : h * 0.08)
                    .offset(y: h * 0.005)

                bandana(width: w, height: h)
                tail(width: w, height: h)
            }
        }
    }

    private func ear(x: CGFloat, rotation: Double, width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: width * 0.07, style: .continuous)
            .fill(Color(red: 0.08, green: 0.09, blue: 0.08))
            .frame(width: width * 0.24, height: height * 0.26)
            .rotationEffect(.degrees(rotation))
            .offset(x: x, y: -height * 0.29)
    }

    private func eye(x: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        Circle()
            .fill(AppColors.ink)
            .frame(width: width * 0.06, height: width * 0.06)
            .overlay(Circle().fill(.white).frame(width: width * 0.018, height: width * 0.018).offset(x: -2, y: -2))
            .offset(x: x, y: -height * 0.15)
    }

    private func bandana(width: CGFloat, height: CGFloat) -> some View {
        Triangle()
            .fill(AppColors.grass)
            .frame(width: width * 0.52, height: height * 0.26)
            .rotationEffect(.degrees(180))
            .offset(y: height * 0.03)
            .overlay {
                Image(systemName: "cloud.fill")
                    .font(.system(size: width * 0.12, weight: .black))
                    .foregroundStyle(.white)
                    .offset(y: height * 0.04)
            }
    }

    private func tail(width: CGFloat, height: CGFloat) -> some View {
        Capsule()
            .fill(Color(red: 0.09, green: 0.10, blue: 0.09))
            .frame(width: width * 0.14, height: height * 0.34)
            .rotationEffect(.degrees(-28))
            .offset(x: -width * 0.38, y: height * 0.18)
    }
}

private struct PixelPlantView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(red: 0.58, green: 0.60, blue: 0.56))
                .frame(width: 48, height: 42)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColors.stroke, lineWidth: 2))
            stem(angle: -28, x: -14, y: -42)
            stem(angle: 14, x: 0, y: -58)
            stem(angle: 34, x: 15, y: -44)
        }
    }

    private func stem(angle: Double, x: CGFloat, y: CGFloat) -> some View {
        Capsule()
            .fill(AppColors.grass)
            .frame(width: 16, height: 50)
            .rotationEffect(.degrees(angle))
            .offset(x: x, y: y)
    }
}

private struct PixelDoorView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(AppColors.wood)
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(AppColors.stroke, lineWidth: 2.5))
            Rectangle()
                .fill(Color(red: 0.40, green: 0.23, blue: 0.12))
                .frame(width: 58, height: 118)
                .overlay(Rectangle().stroke(AppColors.stroke.opacity(0.35), lineWidth: 1))
            Circle()
                .fill(AppColors.coin)
                .overlay(Circle().stroke(AppColors.stroke, lineWidth: 1.5))
                .frame(width: 12, height: 12)
                .offset(x: 22, y: 14)
            Rectangle()
                .fill(AppColors.grassLight.opacity(0.55))
                .frame(width: 74, height: 16)
                .offset(y: 78)
                .overlay(Rectangle().stroke(AppColors.grass, lineWidth: 1.5).offset(y: 78))
        }
    }
}

private struct PixelPictureView: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(AppColors.wood)
            Rectangle()
                .fill(AppColors.sky)
                .padding(6)
            Image(systemName: "mountain.2.fill")
                .font(.title2.weight(.black))
                .foregroundStyle(AppColors.grass)
                .offset(y: 9)
            Image(systemName: "cloud.fill")
                .font(.caption.weight(.black))
                .foregroundStyle(.white)
                .offset(x: 12, y: -10)
        }
        .overlay(Rectangle().stroke(AppColors.stroke, lineWidth: 2.5))
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
            VStack(spacing: 4) {
                PixelAssetImage(name: AssetSlot.Stats.phone)
                    .frame(width: 42, height: 46)
                Text("45m")
                    .font(.system(size: 25, weight: .black, design: .monospaced))
                Text("Lower")
                    .font(pixelFont(.caption2))
                    .foregroundStyle(AppColors.grass)
            }
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

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
