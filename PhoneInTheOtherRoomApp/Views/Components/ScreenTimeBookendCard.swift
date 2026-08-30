import SwiftUI

#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls)
import DeviceActivity
import FamilyControls

struct ScreenTimeBookendCard: View {
    enum Mode {
        case reports
        case settings
    }

    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Binding var showAppPicker: Bool
    var mode: Mode = .reports
    var isEmbedded = false
    @State private var selectedWindow: ScreenTimeReportPreferences.Window = .evening
    @State private var reportsExpanded = false

    var body: some View {
        Group {
            if isEmbedded {
                content
                    .padding(.vertical, AppSpacing.sm)
            } else {
                PixelCard { content }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if mode == .reports {
            reportsDisclosure
        } else {
            settingsContent
        }
    }

    private var reportsDisclosure: some View {
        DisclosureGroup(isExpanded: $reportsExpanded) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if viewModel.bedtimeActivitySelection.phoneOtherIsEmpty {
                    Text("Choose the apps or categories you want included in both reports.")
                        .font(AppTypography.body)
                    Button("Choose apps and categories", action: { showAppPicker = true })
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                } else {
                    windowPicker
                    reportSection(
                        title: selectedWindow == .evening ? "Late evening" : "After waking",
                        window: selectedWindow,
                        context: selectedWindow == .evening
                            ? .phoneOtherLateNight
                            : .phoneOtherMorningQuiet
                    )
                }
            }
            .padding(.top, AppSpacing.sm)
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "iphone.slash")
                    .foregroundStyle(AppColors.grass)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Screen Time context")
                        .font(AppTypography.headline)
                    Text(viewModel.bedtimeActivitySelection.phoneOtherIsEmpty ? "Choose apps and categories" : "Optional · one window at a time")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
        .tint(AppColors.grass)
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label("Screen Time report windows", systemImage: "iphone.slash")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.ink)
            if viewModel.bedtimeActivitySelection.phoneOtherIsEmpty {
                Text("Choose apps and categories above before configuring report windows.")
                    .font(AppTypography.body)
            } else {
                reportWindowSettings
            }
        }
    }

    private var windowPicker: some View {
        HStack(spacing: AppSpacing.xs) {
            windowButton(.evening, title: "Late evening")
            windowButton(.morning, title: "After waking")
        }
    }

    private func windowButton(
        _ window: ScreenTimeReportPreferences.Window,
        title: String
    ) -> some View {
        Button(title) {
            selectedWindow = window
        }
        .buttonStyle(PixelChipButtonStyle(isSelected: selectedWindow == window))
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Show \(title) Screen Time window")
    }

    private func reportSection(
        title: String,
        window: ScreenTimeReportPreferences.Window,
        context: DeviceActivityReport.Context
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.headline)
            Text(reportWindowLabel(for: window))
                .font(AppTypography.body)
            Text(reportDateLabel(for: window))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.grass)
                Text("Only activity from the apps and categories you selected is counted. Reports are separate from Wind Down.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
            DeviceActivityReport(context, filter: screenTimeFilter(for: window))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 250, alignment: .topLeading)
                .padding(AppSpacing.sm)
                .background(AppColors.background.opacity(0.42), in: PixelPanelShape(cut: 6))
        }
    }

    private var reportWindowSettings: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            reportWindowEditor(title: "Late evening", window: .evening)
            Divider()
            reportWindowEditor(title: "After waking", window: .morning)
        }
    }

    private func reportWindowEditor(
        title: String,
        window: ScreenTimeReportPreferences.Window
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title).font(AppTypography.headline)
            HStack(spacing: AppSpacing.sm) {
                reportTimePicker("From", window: window, isStart: true)
                reportTimePicker("To", window: window, isStart: false)
            }
            Text("This report window is separate from Wind Down.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
        }
    }

    private func reportTimePicker(
        _ title: String,
        window: ScreenTimeReportPreferences.Window,
        isStart: Bool
    ) -> some View {
        DatePicker(
            title,
            selection: Binding(
                get: { viewModel.screenTimeReportDate(for: window, isStart: isStart) },
                set: { viewModel.updateScreenTimeReportDate($0, for: window, isStart: isStart) }
            ),
            displayedComponents: .hourAndMinute
        )
        .font(AppTypography.caption)
        .frame(maxWidth: .infinity)
    }

    private func screenTimeFilter(
        for window: ScreenTimeReportPreferences.Window
    ) -> DeviceActivityFilter {
        let selection = viewModel.selection(for: .bedtime)
        let interval = viewModel.screenTimeReportPreferences.latestInterval(for: window)
        return DeviceActivityFilter(
            segment: .hourly(during: interval),
            devices: DeviceActivityFilter.Devices([.iPhone]),
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens
        )
    }

    private func reportDateLabel(
        for window: ScreenTimeReportPreferences.Window
    ) -> String {
        let interval = viewModel.screenTimeReportPreferences.latestInterval(for: window)
        let startDate = interval.start.formatted(
            .dateTime.weekday(.wide).month().day()
        )
        if Calendar.current.isDate(interval.start, inSameDayAs: interval.end) {
            return "Showing \(startDate)"
        }
        let endDate = interval.end.formatted(
            .dateTime.weekday(.wide).month().day()
        )
        return "Showing \(startDate)–\(endDate)"
    }

    private func reportWindowLabel(
        for window: ScreenTimeReportPreferences.Window
    ) -> String {
        let start = viewModel.screenTimeReportDate(for: window, isStart: true)
            .formatted(date: .omitted, time: .shortened)
        let end = viewModel.screenTimeReportDate(for: window, isStart: false)
            .formatted(date: .omitted, time: .shortened)
        return "\(start)–\(end)"
    }
}

#Preview("Screen Time selection required") {
    ScreenTimeBookendCard(showAppPicker: .constant(false))
        .environmentObject(FocusRunViewModel())
        .padding()
        .background(AppColors.paper)
}
#endif
