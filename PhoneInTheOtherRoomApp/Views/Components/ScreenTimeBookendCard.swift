import SwiftUI

#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls)
import DeviceActivity
import FamilyControls

struct ScreenTimeBookendCard: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Binding var showAppPicker: Bool

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Label("Late evening & morning screen time", systemImage: "iphone.slash")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.ink)

                if viewModel.bedtimeActivitySelection.phoneOtherIsEmpty {
                    Text("Choose the apps or categories you want included in both reports.")
                        .font(AppTypography.body)
                    Button("Choose apps", action: { showAppPicker = true })
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                } else {
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
                    Divider()
                    selectedAppsSection
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
            HStack(spacing: AppSpacing.sm) {
                reportTimePicker("From", window: window, isStart: true)
                reportTimePicker("To", window: window, isStart: false)
            }
            Text(reportDateLabel(for: window))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.grass)
            Text("Only activity from the apps and categories you selected is counted. This window is separate from Quiet Time.")
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
}

#Preview("Screen Time selection required") {
    ScreenTimeBookendCard(showAppPicker: .constant(false))
        .environmentObject(FocusRunViewModel())
        .padding()
        .background(AppColors.paper)
}
#endif
