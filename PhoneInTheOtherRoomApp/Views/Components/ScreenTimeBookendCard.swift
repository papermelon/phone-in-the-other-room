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

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Label("Late evening & morning screen time", systemImage: "iphone.slash")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.ink)

                if viewModel.bedtimeActivitySelection.phoneOtherIsEmpty {
                    Text(
                        mode == .settings
                            ? "Choose the apps or categories you want included in both reports."
                            : "Choose the apps and report windows in More to see them here."
                    )
                        .font(AppTypography.body)
                    if mode == .settings {
                        Button("Choose apps", action: { showAppPicker = true })
                            .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    }
                } else {
                    if mode == .reports {
                        reportSection(
                            title: "Late evening",
                            window: .evening,
                            context: .phoneOtherLateNight
                        )
                        Divider()
                        reportSection(
                            title: "After waking",
                            window: .morning,
                            context: .phoneOtherMorningQuiet
                        )
                    } else {
                        reportWindowSettings
                        Divider()
                        selectedAppsSection
                    }
                }
            }
        }
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
            Text("Only activity from the apps and categories you selected is counted. This window is separate from Wind Down.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
            DeviceActivityReport(context, filter: screenTimeFilter(for: window))
                .frame(maxWidth: .infinity)
                .frame(height: 250)
                .padding(AppSpacing.sm)
                .background(AppColors.background.opacity(0.42), in: PixelPanelShape(cut: 6))
                .clipped()
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

    private var selectedAppsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Apps included in both reports")
                .font(AppTypography.headline)
            Text("Every app and category below is counted. You can add, remove, or replace them whenever you like.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
            selectionLabels
            Button("Change apps and categories", action: { showAppPicker = true })
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.grass)
                .buttonStyle(.plain)
                .frame(minHeight: 44, alignment: .leading)
        }
    }

    @ViewBuilder
    private var selectionLabels: some View {
        let selection = viewModel.bedtimeActivitySelection
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            ForEach(Array(selection.applicationTokens), id: \.self) { token in
                Label(token)
                    .font(AppTypography.body)
            }
            ForEach(Array(selection.categoryTokens), id: \.self) { token in
                Label(token)
                    .font(AppTypography.body)
            }
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surfaceMuted.opacity(0.45), in: PixelPanelShape(cut: 4))
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
