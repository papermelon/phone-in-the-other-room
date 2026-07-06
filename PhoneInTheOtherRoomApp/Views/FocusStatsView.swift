import SwiftUI
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity)
import DeviceActivity
#endif
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
import FamilyControls
#endif

enum FocusStatsTab: String, CaseIterable, Identifiable {
    case today, trends, sleep, insights

    /// Sleep (HealthKit) is deferred to TestFlight build 2; Screen Time surfaces are
    /// gated until Family Controls distribution approval (ADR-0004, docs/PROJECT_BRIEF.md).
    static var visibleTabs: [FocusStatsTab] {
#if DEBUG
        allCases
#else
        [.today, .trends, .insights]
#endif
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .trends: return "Trends"
        case .sleep: return "Sleep"
        case .insights: return "Insights"
        }
    }
}

struct FocusStatsView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var selectedTab: FocusStatsTab = .today
    @State private var manualScreenTimeHours = ""
    @State private var manualScreenTimeMinutes = ""
    @State private var manualSocialHours = ""
    @State private var manualSocialMinutes = ""
    @State private var manualBedtimeScreenHours = ""
    @State private var manualBedtimeScreenMinutes = ""
    @State private var manualSleepHours = ""
    @State private var manualSleepMinutes = ""
    @State private var selectedManualDay = Calendar.current.startOfDay(for: Date())
    @State private var manualDayPageStart = 0
    @State private var manualSaveStatus = ""
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
    @State private var showDistractingPicker = false
    @State private var showProductivePicker = false
    @State private var showBedtimePicker = false
#endif

    private var progress: UserProgress { viewModel.coordinator.progress }
    private var today: DailyFocusRecord { progress.todayRecord }
    private var analyticsRecords: [AnalyticsDayRecord] { viewModel.analyticsRecords }
    private var analyticsCorrelations: [AnalyticsCorrelation] { viewModel.analyticsCorrelations }
    private var earlyReturnCount: Int {
        viewModel.coordinator.rewards.filter { $0.rarity == .consolation }.count
    }
    private var completionRate: Int? {
        let totalKnownRuns = progress.totalCompletedRuns + earlyReturnCount
        guard totalKnownRuns > 0 else { return nil }
        return Int((Double(progress.totalCompletedRuns) / Double(totalKnownRuns) * 100).rounded())
    }
    private var bestFocusTimeLabel: String {
        let completedRewards = viewModel.coordinator.rewards.filter { $0.rarity != .consolation && !$0.isDemoReward }
        guard !completedRewards.isEmpty else { return "Learning" }
        let hourCounts = Dictionary(grouping: completedRewards) { Calendar.current.component(.hour, from: $0.earnedAt) }
            .mapValues(\.count)
        guard let hour = hourCounts.max(by: { $0.value < $1.value })?.key else { return "Learning" }
        return focusWindowLabel(for: hour)
    }
    private var lastSevenDays: [DailyFocusRecord] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return progress.record(for: day, calendar: calendar) ?? DailyFocusRecord(day: day)
        }
    }
    private var isEvening: Bool {
        Calendar.current.component(.hour, from: Date()) >= 18
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PixelSegmentedPicker(title: "Stats", selection: $selectedTab, items: FocusStatsTab.visibleTabs) { $0.title }

                switch selectedTab {
                case .today:
                    todayView
                case .trends:
                    trendsView
                case .sleep:
                    sleepView
                case .insights:
                    insightsView
                }
            }
            .padding(16)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Focus Stats")
        .onAppear(perform: loadManualInputs)
        .onChange(of: selectedManualDay) { _, _ in loadManualInputs() }
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        .familyActivityPicker(
            title: ScreenTimeSelectionScope.distracting.pickerTitle,
            headerText: ScreenTimeSelectionScope.distracting.detail,
            footerText: "Counting Sheep only receives private tokens, not the names of selected apps.",
            isPresented: $showDistractingPicker,
            selection: $viewModel.distractingActivitySelection
        )
        .familyActivityPicker(
            title: ScreenTimeSelectionScope.productive.pickerTitle,
            headerText: ScreenTimeSelectionScope.productive.detail,
            footerText: "Productive selections can be separated from avoidable screen time in future rewards.",
            isPresented: $showProductivePicker,
            selection: $viewModel.productiveActivitySelection
        )
        .familyActivityPicker(
            title: ScreenTimeSelectionScope.bedtime.pickerTitle,
            headerText: ScreenTimeSelectionScope.bedtime.detail,
            footerText: "Use this for late-night screen-time reports in Sleep & Recovery.",
            isPresented: $showBedtimePicker,
            selection: $viewModel.bedtimeActivitySelection
        )
        .onChange(of: viewModel.distractingActivitySelection) { _, _ in viewModel.saveScreenTimeSelection(.distracting) }
        .onChange(of: viewModel.productiveActivitySelection) { _, _ in viewModel.saveScreenTimeSelection(.productive) }
        .onChange(of: viewModel.bedtimeActivitySelection) { _, _ in viewModel.saveScreenTimeSelection(.bedtime) }
#endif
    }

    private var todayView: some View {
        VStack(spacing: 16) {
#if DEBUG
            // Screen Time surfaces are gated until Family Controls approval (ADR-0004).
            screenTimeSetupCard
            mockFallbackStats
#endif
            statsCard(title: "Tonight") {
                PixelStatsMetricRow(icon: "iphone.slash", title: "Phone-away minutes", value: "\(today.completedFocusMinutes) min", detail: "Time your phone rested in the other room")
                PixelStatsMetricRow(icon: "star.fill", title: "Tonight's star", value: today.bestStar?.title ?? "None yet", detail: nextStarCaption)
#if DEBUG
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls)
                if canShowScreenTimeReport(.distracting) {
                    ScreenTimeReportRow(
                        icon: "hourglass",
                        title: "Screen time so far",
                        detail: "Selected apps and categories today",
                        context: .phoneOtherToday,
                        filter: todayScreenTimeFilter
                    )
                } else {
                    PixelStatsMetricRow(icon: "hourglass", title: "Screen time so far", value: screenTimeSetupStatus(.distracting), detail: "Connect Screen Time and choose apps/categories")
                }
#else
                PixelStatsMetricRow(icon: "hourglass", title: "Screen time so far", value: viewModel.screenTimeAuthorization.label, detail: "Requires FamilyControls and DeviceActivity on iOS")
#endif
#endif
                if isEvening {
                    PixelStatsMetricRow(icon: "moon.stars.fill", title: "Evening wind-down", value: eveningGoalValue, detail: "After 6pm, protect the wind-down window")
                }
            }
            starSummary
        }
    }

    private var trendsView: some View {
        VStack(spacing: 16) {
            weeklyBars
            statsCard(title: "Trend markers") {
#if DEBUG
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls)
                if canShowScreenTimeReport(.distracting) {
                    ScreenTimeReportRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Screen time trend",
                        detail: "Selected app/category use over the last 7 days",
                        context: .phoneOtherWeekly,
                        filter: weeklyScreenTimeFilter
                    )
                } else {
                    PixelStatsMetricRow(icon: "chart.line.uptrend.xyaxis", title: "Screen time trend", value: screenTimeSetupStatus(.distracting), detail: "Choose apps/categories to start the report")
                }
#else
                PixelStatsMetricRow(icon: "chart.line.uptrend.xyaxis", title: "Screen time trend", value: "Unavailable", detail: "Requires FamilyControls and DeviceActivity on iOS")
#endif
#endif
                PixelStatsMetricRow(icon: "checkmark.seal.fill", title: "Completion rate", value: completionRate.map { "\($0)%" } ?? "No runs yet", detail: "\(progress.totalCompletedRuns) completed, \(earlyReturnCount) ended early")
                PixelStatsMetricRow(icon: "clock.fill", title: "Best wind-down time", value: bestFocusTimeLabel, detail: "Based on completed reward times")
            }
            analyticsHistoryCard
#if DEBUG
            screenTimeCategorySetup
            mockSessionHistory
#endif
            recentHistory
        }
    }

    private var sleepView: some View {
        VStack(spacing: 16) {
            IntegrationSetupCard(
                title: "Connect Apple Health",
                detail: "Requests HealthKit sleep permission and reads last night's sleep samples.",
                icon: "heart.text.square.fill",
                actionTitle: viewModel.sleepAuthorization == .authorized ? "Refresh" : "Connect",
                action: viewModel.sleepAuthorization == .authorized ? viewModel.refreshSleepSummary : viewModel.connectAppleHealthSleep
            )
            statsCard(title: "Sleep & Recovery") {
                PixelStatsMetricRow(icon: "bed.double.fill", title: "Last night sleep", value: viewModel.lastNightSleep?.durationLabel ?? viewModel.sleepAuthorization.label, detail: "HealthKit sleep analysis")
                PixelStatsMetricRow(icon: "iphone.slash", title: "Bedtime phone-away minutes", value: "Not connected", detail: "Use evening Focus Runs before sleep")
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls)
                if canShowScreenTimeReport(.bedtime) {
                    ScreenTimeReportRow(
                        icon: "moon.zzz.fill",
                        title: "Late screen time",
                        detail: "Selected bedtime apps in the wind-down window",
                        context: .phoneOtherLateNight,
                        filter: lateNightScreenTimeFilter
                    )
                } else {
                    PixelStatsMetricRow(icon: "moon.zzz.fill", title: "Late screen time", value: screenTimeSetupStatus(.bedtime), detail: "Choose bedtime apps/categories")
                }
#else
                PixelStatsMetricRow(icon: "moon.zzz.fill", title: "Late screen time", value: "Unavailable", detail: "Requires FamilyControls and DeviceActivity on iOS")
#endif
            }
            screenTimeCategorySetup
        }
    }

    private var insightsView: some View {
        VStack(spacing: 16) {
            manualAnalyticsEntryCard
            habitInsightsCard
            loggedDaysCard
            analyticsExportCard
#if DEBUG
            analyticsQACard
#endif
        }
    }

#if DEBUG
    private var analyticsQACard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "testtube.2")
                        .font(.title3.weight(.black))
                        .foregroundStyle(AppColors.grass)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Analytics QA")
                            .font(pixelFont(.headline))
                        Text(viewModel.useAnalyticsQADataset ? "Showing sample 30-day analytics data" : "Showing your local analytics data")
                            .font(PixelTypography.title(.caption2))
                            .foregroundStyle(AppColors.muted)
                    }
                }
                Text("The sample dataset is in-memory only, so it exercises correlations and exports without changing real focus history or manual entries.")
                    .font(PixelTypography.title(.caption2))
                    .foregroundStyle(AppColors.muted)
                HStack(spacing: 10) {
                    Button(action: viewModel.showAnalyticsQADataset) {
                        Label("Use sample", systemImage: "chart.xyaxis.line")
                    }
                    Button(action: viewModel.hideAnalyticsQADataset) {
                        Label("Use local", systemImage: "iphone")
                    }
                }
                .buttonStyle(PixelButtonStyle(tint: AppColors.grass))
            }
        }
    }
#endif

    private func statsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        PixelCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(pixelFont(.headline))
                content()
            }
        }
    }

    private var screenTimeSetupCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "hourglass")
                        .font(.title2.weight(.black))
                        .frame(width: 36)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connect Screen Time")
                            .font(pixelFont(.headline))
                        Text("Authorize Screen Time, then choose which apps and categories count toward screen-time and bedtime reports.")
                            .font(PixelTypography.title(.caption2))
                            .foregroundStyle(AppColors.muted)
                        Button(action: viewModel.connectScreenTime) {
                            Text(viewModel.screenTimeAuthorization == .approved ? "Connected" : "Connect")
                                .font(pixelFont(.caption2))
                                .foregroundStyle(AppColors.grass)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .overlay(PixelPanelShape(cut: 5).stroke(AppColors.stroke, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
                Divider()
                screenTimePickerButton(.distracting)
#endif
            }
        }
    }

    private var screenTimeCategorySetup: some View {
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        PixelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Screen Time Sources")
                    .font(pixelFont(.headline))
                screenTimePickerButton(.distracting)
                screenTimePickerButton(.productive)
                screenTimePickerButton(.bedtime)
            }
        }
#else
        PixelCard {
            Text("Screen Time setup requires FamilyControls on iOS.")
                .font(PixelTypography.title(.caption))
                .foregroundStyle(AppColors.muted)
        }
#endif
    }

    private var habitInsightsCard: some View {
        statsCard(title: "What Ollie can check now") {
            Text("Manual logs can only compare the numbers you enter. App-specific social media and bedtime-window patterns will be much better once Screen Time is connected; sleep will be better once Apple Health is connected.")
                .font(PixelTypography.title(.caption2))
                .foregroundStyle(AppColors.muted)
            HabitInsightRow(
                icon: "moon.zzz.fill",
                title: "Bedtime scrolling",
                value: bedtimeInsightValue,
                detail: bedtimeInsightDetail
            )
            HabitInsightRow(
                icon: "bubble.left.and.bubble.right.fill",
                title: "Social scrolling",
                value: socialInsightValue,
                detail: socialInsightDetail
            )
            HabitInsightRow(
                icon: "iphone.slash",
                title: "Phone-away practice",
                value: focusInsightValue,
                detail: focusInsightDetail
            )
        }
    }

    private var loggedDaysCard: some View {
        statsCard(title: loggedDaysTitle) {
            PixelStatsMetricRow(
                icon: "checklist",
                title: "Logged days",
                value: "\(loggedManualDayCount)",
                detail: analyticsDatasetDetail
            )
            PixelStatsMetricRow(
                icon: "iphone.slash",
                title: "Screen Time + focus",
                value: "\(pairedScreenTimeDayCount) days",
                detail: pairedScreenTimeDayCount < 3 ? "Log 3 days to start seeing a pattern." : "Enough days for an early screen-time clue."
            )
            PixelStatsMetricRow(
                icon: "bed.double.fill",
                title: "Sleep + focus",
                value: "\(pairedSleepDayCount) days",
                detail: pairedSleepDayCount < 3 ? "Log 3 days to start seeing a pattern." : "Enough days for an early sleep clue."
            )
        }
    }

    private var loggedDaysTitle: String {
#if DEBUG
        if viewModel.useAnalyticsQADataset {
            return "Sample log progress"
        }
#endif
        return "Log progress"
    }

    private var analyticsDatasetDetail: String {
#if DEBUG
        if viewModel.useAnalyticsQADataset {
            return "Temporary sample data for testing the screen."
        }
#endif
        if loggedManualDayCount == 0 {
            return "No Screen Time or sleep logs yet."
        }
        return "Saved manually on this phone."
    }

    private var manualAnalyticsEntryCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Daily Screen Time & Sleep Log")
                    .font(pixelFont(.headline))
                Text("Pick a day, add total Screen Time and the sleep that followed it, then save. Social and bedtime screen time are optional until Screen Time can fill them automatically.")
                    .font(PixelTypography.title(.caption2))
                    .foregroundStyle(AppColors.muted)
#if DEBUG
                if viewModel.useAnalyticsQADataset {
                    Text("Sample QA data is active. Saved manual inputs still persist, but the Insights dataset is using the temporary sample values.")
                        .font(PixelTypography.title(.caption2))
                        .foregroundStyle(AppColors.muted)
                }
#endif

                manualDayPicker

                if let entry = selectedManualEntry {
                    Text("Saved \(entry.updatedAt.formatted(.relative(presentation: .named)))")
                        .font(PixelTypography.title(.caption2))
                        .foregroundStyle(AppColors.grass)
                } else {
                    Text("No log saved for this day yet")
                        .font(PixelTypography.title(.caption2))
                        .foregroundStyle(AppColors.muted)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Total Screen Time for \(selectedManualDayLabel)")
                        .font(pixelFont(.caption))
                    HStack(spacing: 10) {
                        analyticsNumberField("Hours", text: $manualScreenTimeHours)
                        analyticsNumberField("Minutes", text: $manualScreenTimeMinutes)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Social or scrolling")
                        .font(pixelFont(.caption))
                    HStack(spacing: 10) {
                        analyticsNumberField("Hours", text: $manualSocialHours)
                        analyticsNumberField("Minutes", text: $manualSocialMinutes)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Screen time near bedtime")
                        .font(pixelFont(.caption))
                    HStack(spacing: 10) {
                        analyticsNumberField("Hours", text: $manualBedtimeScreenHours)
                        analyticsNumberField("Minutes", text: $manualBedtimeScreenMinutes)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Sleep after \(selectedManualDayLabel)")
                        .font(pixelFont(.caption))
                    HStack(spacing: 10) {
                        analyticsNumberField("Hours", text: $manualSleepHours)
                        analyticsNumberField("Minutes", text: $manualSleepMinutes)
                    }
                }

                HStack(spacing: 10) {
                    Button("Save") {
                        saveManualInputs()
                    }
                    Button(selectedManualEntry == nil ? "Clear form" : "Remove day") {
                        clearManualInputs()
                    }
                }
                .buttonStyle(PixelButtonStyle(tint: AppColors.grass))

                if !manualSaveStatus.isEmpty {
                    Text(manualSaveStatus)
                        .font(PixelTypography.title(.caption2))
                        .foregroundStyle(AppColors.grass)
                }

                Divider()
                manualLogCalendar
            }
        }
    }

    private var manualDayPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Logging for")
                    .font(pixelFont(.caption))
                Spacer()
                Button("Newer") {
                    manualDayPageStart = max(0, manualDayPageStart - 7)
                }
                .disabled(manualDayPageStart == 0)
                Button("Older") {
                    manualDayPageStart = min(23, manualDayPageStart + 7)
                }
            }
            .font(PixelTypography.title(.caption2))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recentManualDays, id: \.self) { day in
                        Button {
                            selectedManualDay = day
                        } label: {
                            VStack(spacing: 3) {
                                Text(day.formatted(.dateTime.weekday(.abbreviated)))
                                Text(day.formatted(.dateTime.month(.abbreviated).day()))
                            }
                            .font(PixelTypography.title(.caption2))
                            .foregroundStyle(Calendar.current.isDate(day, inSameDayAs: selectedManualDay) ? .white : AppColors.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Calendar.current.isDate(day, inSameDayAs: selectedManualDay) ? AppColors.grass : AppColors.surfaceMuted)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var manualLogCalendar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Log map")
                    .font(pixelFont(.caption))
                Spacer()
                Text("\(loggedManualDayCount)/30 days")
                    .font(PixelTypography.title(.caption2))
                    .foregroundStyle(AppColors.muted)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8) {
                ForEach(manualCalendarDays, id: \.self) { day in
                    manualCalendarDayButton(day)
                }
            }
            HStack(spacing: 12) {
                logLegendDot(color: AppColors.grass, label: "screen")
                logLegendDot(color: AppColors.coin, label: "bedtime")
                logLegendDot(color: AppColors.lavender, label: "sleep")
            }
        }
    }

    private func manualCalendarDayButton(_ day: Date) -> some View {
        let entry = viewModel.manualAnalyticsEntry(for: day)
        let selected = Calendar.current.isDate(day, inSameDayAs: selectedManualDay)
        return Button {
            selectedManualDay = day
            if let offset = dayOffsetFromToday(day) {
                manualDayPageStart = min(23, max(0, (offset / 7) * 7))
            }
        } label: {
            VStack(spacing: 4) {
                Text(day.formatted(.dateTime.day()))
                    .font(pixelFont(.caption2))
                    .foregroundStyle(selected ? .white : AppColors.ink)
                HStack(spacing: 2) {
                    Circle()
                        .fill(entry?.screenTimeMinutes == nil ? AppColors.muted.opacity(0.22) : AppColors.grass)
                    Circle()
                        .fill(entry?.bedtimeScreenTimeMinutes == nil && entry?.socialScreenTimeMinutes == nil ? AppColors.muted.opacity(0.22) : AppColors.coin)
                    Circle()
                        .fill(entry?.sleepMinutes == nil ? AppColors.muted.opacity(0.22) : AppColors.lavender)
                }
                .frame(height: 4)
            }
            .frame(height: 42)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? AppColors.grass : (entry == nil ? AppColors.surface : AppColors.surfaceMuted))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(selected ? AppColors.stroke : AppColors.stroke.opacity(0.18), lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func logLegendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(PixelTypography.title(.caption2))
                .foregroundStyle(AppColors.muted)
        }
    }

    private var analyticsExportCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Export local dataset")
                    .font(pixelFont(.headline))
                Text("Exports stay on device until you share them. JSON includes correlations; CSV is one row per day.")
                    .font(PixelTypography.title(.caption2))
                    .foregroundStyle(AppColors.muted)
                Picker("Date privacy", selection: $viewModel.analyticsExportPrivacyMode) {
                    Text("Exact dates").tag(AnalyticsExportPrivacyMode.exactDates)
                    Text("Relative days").tag(AnalyticsExportPrivacyMode.relativeDays)
                }
                .pickerStyle(.segmented)
                Toggle("Include demo placeholder rows", isOn: $viewModel.includeAnalyticsPlaceholders)
                    .font(pixelFont(.caption))
                    .tint(AppColors.grass)
                HStack(spacing: 10) {
                    Button(action: viewModel.prepareAnalyticsJSONExport) {
                        Label("JSON", systemImage: "curlybraces")
                    }
                    Button(action: viewModel.prepareAnalyticsCSVExport) {
                        Label("CSV", systemImage: "tablecells")
                    }
                }
                .buttonStyle(PixelButtonStyle(tint: AppColors.grass))
                if let url = viewModel.analyticsExportURL {
                    ShareLink(item: url) {
                        Label("Share \(url.pathExtension.uppercased()) export", systemImage: "square.and.arrow.up")
                    }
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                }
                if let error = viewModel.analyticsExportError {
                    Text(error)
                        .font(PixelTypography.title(.caption2))
                        .foregroundStyle(.red)
                }
            }
        }
    }

#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
    private func screenTimePickerButton(_ scope: ScreenTimeSelectionScope) -> some View {
        Button {
            showPicker(for: scope)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon(for: scope))
                    .font(.headline.weight(.black))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(AppColors.grass)
                VStack(alignment: .leading, spacing: 3) {
                    Text(scope.title)
                        .font(pixelFont(.caption))
                    Text(viewModel.selection(for: scope).phoneOtherSelectionSummary)
                        .font(PixelTypography.title(.caption2))
                        .foregroundStyle(AppColors.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.black))
            }
            .padding(10)
            .overlay(PixelPanelShape(cut: 6).stroke(AppColors.stroke.opacity(0.28), lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.screenTimeAuthorization != .approved)
        .opacity(viewModel.screenTimeAuthorization == .approved ? 1 : 0.52)
    }

    private func showPicker(for scope: ScreenTimeSelectionScope) {
        guard viewModel.screenTimeAuthorization == .approved else {
            viewModel.connectScreenTime()
            return
        }
        switch scope {
        case .distracting: showDistractingPicker = true
        case .productive: showProductivePicker = true
        case .bedtime: showBedtimePicker = true
        }
    }

    private func icon(for scope: ScreenTimeSelectionScope) -> String {
        switch scope {
        case .distracting: return "iphone"
        case .productive: return "briefcase.fill"
        case .bedtime: return "moon.zzz.fill"
        }
    }

    private func canShowScreenTimeReport(_ scope: ScreenTimeSelectionScope) -> Bool {
        viewModel.screenTimeAuthorization == .approved && !viewModel.selection(for: scope).phoneOtherIsEmpty
    }

    private func screenTimeSetupStatus(_ scope: ScreenTimeSelectionScope) -> String {
        guard viewModel.screenTimeAuthorization == .approved else { return viewModel.screenTimeAuthorization.label }
        return viewModel.selection(for: scope).phoneOtherIsEmpty ? "Choose apps" : "Connected"
    }
#endif

    private var starSummary: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Focus stars")
                    .font(pixelFont(.headline))
                HStack(spacing: 16) {
                    ForEach(FocusStarTier.allCases) { tier in
                        VStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.title2.weight(.black))
                                .foregroundStyle(focusStarColor(for: tier))
                            Text("\(progress.starCount(for: tier))")
                                .font(pixelFont(.headline))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var nextStarCaption: String {
        guard let nextTier = FocusStarTier.allCases.first(where: { today.completedFocusMinutes < $0.thresholdMinutes }) else {
            return "All daily stars earned"
        }
        let remaining = max(0, nextTier.thresholdMinutes - today.completedFocusMinutes)
        return "\(remaining) min to \(nextTier.title.lowercased())"
    }

    private var eveningGoalValue: String {
        let eveningMinutes = today.completedFocusMinutes
        if eveningMinutes >= 30 { return "Met" }
        return "\(max(0, 30 - eveningMinutes)) min left"
    }

    private func focusWindowLabel(for hour: Int) -> String {
        switch hour {
        case 5..<12: return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<22: return "Evening"
        default: return "Late night"
        }
    }

#if DEBUG
    private var mockFallbackStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mock fallback")
                .font(AppTypography.title)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 154), spacing: 12)], spacing: 12) {
                ForEach(MVPMockData.statistics.prefix(4)) { statistic in
                    StatsCard(statistic: statistic)
                }
            }
            Text("Debug-only sample data when Screen Time entitlements are unavailable.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
        }
        .padding(14)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
    }

    private var mockSessionHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mock session history")
                .font(AppTypography.title)
            ForEach(MVPMockData.sessions.prefix(3)) { session in
                FocusSessionCard(session: session)
            }
        }
        .padding(14)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
    }
#endif

    private var recentHistory: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent history")
                    .font(pixelFont(.headline))
                if progress.recentFocusRecords.isEmpty {
                    Text("Complete a Focus Run to start filling this trail.")
                        .font(PixelTypography.title(.caption))
                        .foregroundStyle(AppColors.muted)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 12) {
                        ForEach(progress.recentFocusRecords) { record in
                            VStack(spacing: 6) {
                                Text(record.day.formatted(.dateTime.day()))
                                    .font(pixelFont(.caption2))
                                    .foregroundStyle(AppColors.muted)
                                Image(systemName: record.bestStar == nil ? "star" : "star.fill")
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(record.bestStar.map(focusStarColor(for:)) ?? AppColors.muted.opacity(0.35))
                                Text("\(record.completedFocusMinutes)")
                                    .font(pixelFont(.caption2))
                            }
                        }
                    }
                }
            }
        }
    }

    private var weeklyBars: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Last 7 days")
                    .font(pixelFont(.headline))
                HStack(alignment: .lastTextBaseline) {
                    Text("\(lastSevenDays.reduce(0) { $0 + $1.completedFocusMinutes })")
                        .font(.system(.largeTitle, design: .monospaced).weight(.black))
                    Text("other-room min")
                        .font(PixelTypography.title(.caption))
                        .foregroundStyle(AppColors.muted)
                }
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(lastSevenDays) { record in
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(record.bestStar.map(focusStarColor(for:)) ?? AppColors.muted.opacity(0.25))
                                .frame(height: max(8, min(120, CGFloat(record.completedFocusMinutes) / 120 * 120)))
                            Text(record.day.formatted(.dateTime.weekday(.narrow)))
                                .font(pixelFont(.caption2))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                Text("Stars unlock at 15, 30, 60, and 120 completed minutes.")
                    .font(PixelTypography.title(.caption2))
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

    private var analyticsHistoryCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("30-day analytics history")
                    .font(pixelFont(.headline))
                ForEach(analyticsRecords.suffix(7)) { record in
                    AnalyticsHistoryRow(record: record)
                }
                Text("Open Insights to export all 30 rows.")
                    .font(PixelTypography.title(.caption2))
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

    private func analyticsNumberField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .keyboardType(.numberPad)
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
    }

    private var selectedManualEntry: ManualAnalyticsEntry? {
        viewModel.manualAnalyticsEntry(for: selectedManualDay)
    }

    private var selectedManualDayLabel: String {
        if Calendar.current.isDateInToday(selectedManualDay) {
            return "today"
        }
        if Calendar.current.isDateInYesterday(selectedManualDay) {
            return "yesterday"
        }
        return selectedManualDay.formatted(.dateTime.month(.abbreviated).day())
    }

    private var recentManualDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (manualDayPageStart..<(manualDayPageStart + 7)).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }

    private var manualCalendarDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<30).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }

    private var loggedManualDayCount: Int {
#if DEBUG
        if viewModel.useAnalyticsQADataset {
            return analyticsRecords.filter { $0.screenTimeMinutes != nil || $0.sleepMinutes != nil }.count
        }
#endif
        return viewModel.manualAnalyticsEntries.count
    }

    private var pairedScreenTimeDayCount: Int {
        analyticsRecords.filter { $0.screenTimeMinutes != nil }.count
    }

    private var pairedSleepDayCount: Int {
        analyticsRecords.filter { $0.sleepMinutes != nil }.count
    }

    private var pairedBedtimeScreenDayCount: Int {
        analyticsRecords.filter { $0.bedtimeScreenTimeMinutes != nil && $0.sleepMinutes != nil }.count
    }

    private var pairedSocialDayCount: Int {
        analyticsRecords.filter { $0.socialScreenTimeMinutes != nil && $0.sleepMinutes != nil }.count
    }

    private var bedtimeInsightValue: String {
        guard pairedBedtimeScreenDayCount >= 3 else { return "\(pairedBedtimeScreenDayCount)/3 nights" }
        return bedtimeSleepDifference.map { $0 < 0 ? "Less sleep" : "Holding steady" } ?? "Watch this"
    }

    private var bedtimeInsightDetail: String {
        guard pairedBedtimeScreenDayCount >= 3 else {
            return "Needs Screen Time bedtime-window data, or optional bedtime minutes logged by hand."
        }
        guard let difference = bedtimeSleepDifference else {
            return "No clear bedtime pattern yet."
        }
        if difference < -20 {
            return "Nights with more bedtime screen time are averaging \(abs(difference)) min less sleep."
        }
        if difference > 20 {
            return "Your logged sleep is not dipping on higher bedtime-screen nights so far."
        }
        return "Bedtime screen time and sleep look fairly mixed so far."
    }

    private var socialInsightValue: String {
        guard pairedSocialDayCount >= 3 else { return "\(pairedSocialDayCount)/3 days" }
        let average = averageLogged(\.socialScreenTimeMinutes)
        return average.map(formatHoursMinutes) ?? "Watching"
    }

    private var socialInsightDetail: String {
        guard pairedSocialDayCount >= 3 else {
            return "Needs Screen Time app/category data, or optional social minutes logged by hand."
        }
        return "Average social or scrolling time on logged days."
    }

    private var focusInsightValue: String {
        let focusDays = analyticsRecords.filter { $0.focusMinutes > 0 }.count
        return "\(focusDays) days"
    }

    private var focusInsightDetail: String {
        let screenDays = pairedScreenTimeDayCount
        if screenDays < 3 {
            return "Add Screen Time logs to compare with phone-away days."
        }
        return "Phone-away time is ready to compare with your screen habits."
    }

    private var bedtimeSleepDifference: Int? {
        let records = analyticsRecords.compactMap { record -> (screen: Int, sleep: Int)? in
            guard let screen = record.bedtimeScreenTimeMinutes, let sleep = record.sleepMinutes else { return nil }
            return (screen, sleep)
        }
        guard records.count >= 3 else { return nil }
        let sortedScreens = records.map(\.screen).sorted()
        let median = sortedScreens[sortedScreens.count / 2]
        let high = records.filter { $0.screen >= median }.map(\.sleep)
        let low = records.filter { $0.screen < median }.map(\.sleep)
        guard !high.isEmpty, !low.isEmpty else { return nil }
        return average(high) - average(low)
    }

    private func averageLogged(_ keyPath: KeyPath<AnalyticsDayRecord, Int?>) -> Int? {
        let values = analyticsRecords.compactMap { $0[keyPath: keyPath] }
        guard !values.isEmpty else { return nil }
        return average(values)
    }

    private func average(_ values: [Int]) -> Int {
        values.reduce(0, +) / max(1, values.count)
    }

    private func dayOffsetFromToday(_ day: Date) -> Int? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let selected = calendar.startOfDay(for: day)
        return calendar.dateComponents([.day], from: selected, to: today).day
    }

    private func loadManualInputs() {
        manualSaveStatus = ""
        manualScreenTimeHours = ""
        manualScreenTimeMinutes = ""
        manualSocialHours = ""
        manualSocialMinutes = ""
        manualBedtimeScreenHours = ""
        manualBedtimeScreenMinutes = ""
        manualSleepHours = ""
        manualSleepMinutes = ""

        guard let entry = selectedManualEntry else { return }
        if let screenTime = entry.screenTimeMinutes {
            manualScreenTimeHours = "\(screenTime / 60)"
            manualScreenTimeMinutes = "\(screenTime % 60)"
        }
        if let social = entry.socialScreenTimeMinutes {
            manualSocialHours = "\(social / 60)"
            manualSocialMinutes = "\(social % 60)"
        }
        if let bedtimeScreen = entry.bedtimeScreenTimeMinutes {
            manualBedtimeScreenHours = "\(bedtimeScreen / 60)"
            manualBedtimeScreenMinutes = "\(bedtimeScreen % 60)"
        }
        if let sleep = entry.sleepMinutes {
            manualSleepHours = "\(sleep / 60)"
            manualSleepMinutes = "\(sleep % 60)"
        }
    }

    private func saveManualInputs() {
        viewModel.saveManualAnalyticsEntry(
            day: selectedManualDay,
            screenTimeMinutes: minutes(hours: manualScreenTimeHours, minutes: manualScreenTimeMinutes),
            socialScreenTimeMinutes: minutes(hours: manualSocialHours, minutes: manualSocialMinutes),
            bedtimeScreenTimeMinutes: minutes(hours: manualBedtimeScreenHours, minutes: manualBedtimeScreenMinutes),
            sleepMinutes: minutes(hours: manualSleepHours, minutes: manualSleepMinutes)
        )
        manualSaveStatus = "Saved log for \(selectedManualDayLabel)."
        loadManualInputs()
        manualSaveStatus = "Saved log for \(selectedManualDayLabel)."
    }

    private func clearManualInputs() {
        manualScreenTimeHours = ""
        manualScreenTimeMinutes = ""
        manualSocialHours = ""
        manualSocialMinutes = ""
        manualBedtimeScreenHours = ""
        manualBedtimeScreenMinutes = ""
        manualSleepHours = ""
        manualSleepMinutes = ""
        viewModel.saveManualAnalyticsEntry(day: selectedManualDay, screenTimeMinutes: nil, sleepMinutes: nil)
        manualSaveStatus = "Removed log for \(selectedManualDayLabel)."
    }

    private func minutes(hours: String, minutes: String) -> Int? {
        let hourValue = Int(hours.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let minuteValue = Int(minutes.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let total = max(0, hourValue * 60 + min(59, max(0, minuteValue)))
        return total == 0 ? nil : total
    }

    private func formatHoursMinutes(_ minutes: Int) -> String {
        "\(minutes / 60)h \(minutes % 60)m"
    }

    private func analyticsSourceBreakdown(_ keyPath: KeyPath<AnalyticsDayRecord, AnalyticsMetricSource?>) -> String {
        let counts = Dictionary(grouping: analyticsRecords.compactMap { $0[keyPath: keyPath] }) { $0 }
            .mapValues(\.count)
        guard !counts.isEmpty else { return "No paired values yet" }
        return counts
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { "\($0.value) \($0.key.rawValue)" }
            .joined(separator: ", ")
    }
}

private struct HabitInsightRow: View {
    var icon: String
    var title: String
    var value: String
    var detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(AppColors.grass, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(pixelFont(.caption))
                Text(detail)
                    .font(PixelTypography.title(.caption2))
                    .foregroundStyle(AppColors.muted)
            }
            Spacer()
            Text(value)
                .font(.system(.headline, design: .monospaced).weight(.black))
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct CorrelationMetricRow: View {
    var correlation: AnalyticsCorrelation

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.headline.weight(.black))
                .foregroundStyle(AppColors.grass)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(correlation.title)
                    .font(pixelFont(.caption))
                Text("\(correlation.directionLabel) · \(correlation.sampleSize) paired days")
                    .font(PixelTypography.title(.caption2))
                    .foregroundStyle(AppColors.muted)
                Text(correlation.provenanceLabel)
                    .font(PixelTypography.title(.caption2))
                    .foregroundStyle(AppColors.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(correlation.coefficientLabel)
                    .font(.system(.headline, design: .monospaced).weight(.black))
                Text(correlation.strengthLabel)
                    .font(PixelTypography.title(.caption2))
                    .foregroundStyle(AppColors.muted)
            }
        }
    }
}

private struct AnalyticsHistoryRow: View {
    var record: AnalyticsDayRecord

    var body: some View {
        HStack(spacing: 10) {
            Text(record.day.formatted(.dateTime.weekday(.abbreviated).day()))
                .font(pixelFont(.caption2))
                .frame(width: 52, alignment: .leading)
            miniBar(value: record.focusMinutes, maxValue: 120, color: AppColors.grass)
            Text("\(record.focusMinutes)m")
                .font(PixelTypography.title(.caption2))
                .frame(width: 44, alignment: .trailing)
            Text(record.screenTimeMinutes.map { "\($0)m screen" } ?? "screen n/a")
                .font(PixelTypography.title(.caption2))
                .foregroundStyle(AppColors.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(record.sleepMinutes.map { "\($0 / 60)h \($0 % 60)m" } ?? "sleep n/a")
                .font(PixelTypography.title(.caption2))
                .foregroundStyle(AppColors.muted)
        }
    }

    private func miniBar(value: Int, maxValue: Int, color: Color) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width * min(1, CGFloat(value) / CGFloat(max(1, maxValue)))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppColors.muted.opacity(0.16))
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: max(3, width))
            }
        }
        .frame(height: 8)
    }
}

#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls)
extension FocusStatsView {
    var todayScreenTimeFilter: DeviceActivityFilter {
        makeScreenTimeFilter(scope: .distracting, segment: .daily(during: todayInterval))
    }

    var weeklyScreenTimeFilter: DeviceActivityFilter {
        makeScreenTimeFilter(scope: .distracting, segment: .daily(during: lastSevenDaysInterval))
    }

    var lateNightScreenTimeFilter: DeviceActivityFilter {
        makeScreenTimeFilter(scope: .bedtime, segment: .hourly(during: lateNightInterval))
    }

    func makeScreenTimeFilter(
        scope: ScreenTimeSelectionScope,
        segment: DeviceActivityFilter.SegmentInterval
    ) -> DeviceActivityFilter {
        let selection = viewModel.selection(for: scope)
        return DeviceActivityFilter(
            segment: segment,
            devices: .all,
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens
        )
    }

    var todayInterval: DateInterval {
        Calendar.current.dateInterval(of: .day, for: Date()) ?? DateInterval(start: Date(), end: Date())
    }

    var lastSevenDaysInterval: DateInterval {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date())) ?? Date()
        return DateInterval(start: start, end: end)
    }

    var lateNightInterval: DateInterval {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let hour = calendar.component(.hour, from: now)
        if hour >= 18 {
            let eveningStart = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now) ?? todayStart
            return DateInterval(start: eveningStart, end: now)
        }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday) ?? yesterday
        let end = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: now) ?? now
        return DateInterval(start: start, end: max(now, end))
    }
}
#endif

#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls)
struct ScreenTimeReportRow: View {
    var icon: String
    var title: String
    var detail: String
    var context: DeviceActivityReport.Context
    var filter: DeviceActivityFilter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PixelStatsMetricRow(icon: icon, title: title, value: "Report", detail: detail)
            DeviceActivityReport(context, filter: filter)
                .frame(minHeight: 70)
        }
    }
}
#endif
