import SwiftUI

struct HealthConnectionStatusCard: View {
    let presentation: HealthSleepConnectionPresentation
    let onConnect: () -> Void
    let onRefresh: () -> Void
    var isEmbedded = false
    @State private var showsAccessHelp = false

    var body: some View {
        Group {
            if isEmbedded {
                content.padding(.vertical, AppSpacing.sm)
            } else {
                PixelCard { content }
            }
        }
        .sheet(isPresented: $showsAccessHelp) {
            HealthConnectionAccessHelpSheet()
        }
    }

    private var content: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: "bed.double.fill")
                .foregroundStyle(AppColors.grass)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Apple Health")
                    .font(AppTypography.headline)
                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                action
            }
            Spacer(minLength: 0)
        }
    }

}

struct HealthConnectionAccessHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Manage Apple Health access")
                        .font(AppTypography.display(28))
                        .accessibilityAddTraits(.isHeader)
                    Text("In Health, open your profile, then Apps and Services, and choose Counting Sheep.")
                        .font(AppTypography.body)
                    Text("Apple does not tell an app whether you allowed its sleep-data read request. An empty result can also mean there is no matching sleep sample yet.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.lg)
            }
            .background(AppColors.paper.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: dismiss.callAsFunction)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

extension HealthConnectionStatusCard {
    private var detail: String {
        switch presentation {
        case .unavailable:
            return "Apple Health sleep data is unavailable on this iPhone. Your Wind Down history stays local."
        case .connect:
            return "Optional sleep duration and stages beside your Wind Down history."
        case .checking:
            return "Checking for sleep data…"
        case let .dataAvailable(sampleDate, checkedAt):
            return "Sleep data available for \(sampleDate.formatted(.dateTime.month(.abbreviated).day())). Last checked \(checkedAt.formatted(.dateTime.hour().minute()))."
        case let .noData(checkedAt):
            return "No sleep data available for this period. Last checked \(checkedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))."
        case let .staleData(sampleDate, checkedAt, _):
            if let sampleDate {
                let checked = checkedAt.map {
                    " Last checked \($0.formatted(.dateTime.month(.abbreviated).day().hour().minute()))."
                } ?? ""
                return "Couldn’t refresh Apple Health. Latest saved sample is from \(sampleDate.formatted(.dateTime.month(.abbreviated).day())).\(checked)"
            }
            return "Apple Health could not be checked. Try again when you’re ready."
        }
    }

    @ViewBuilder
    private var action: some View {
        switch presentation {
        case .unavailable, .checking:
            EmptyView()
        case .connect:
            Button("Connect Apple Health", action: onConnect)
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
                .accessibilityHint("Requests optional sleep-data access from Apple Health")
        case .dataAvailable, .noData:
            Button("Refresh", action: onRefresh)
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
            Button("Manage access") { showsAccessHelp = true }
                .buttonStyle(.plain)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.grass)
                .frame(minHeight: 44, alignment: .leading)
        case .staleData:
            Button("Retry", action: onRefresh)
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
            Button("Manage access") { showsAccessHelp = true }
                .buttonStyle(.plain)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.grass)
                .frame(minHeight: 44, alignment: .leading)
        }
    }
}

struct ScreenTimeConnectionStatusCard: View {
    let presentation: ScreenTimeConnectionPresentation
    let onConnect: () -> Void
    let onChooseSelection: () -> Void
    var isEmbedded = false

    var body: some View {
        Group {
            if isEmbedded {
                content.padding(.vertical, AppSpacing.sm)
            } else {
                PixelCard { content }
            }
        }
    }

    private var content: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: "iphone.slash")
                .foregroundStyle(AppColors.grass)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Screen Time")
                    .font(AppTypography.headline)
                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                action
            }
            Spacer(minLength: 0)
        }
    }

    private var detail: String {
        switch presentation {
        case .unavailable:
            return "Screen Time reports are unavailable on this iPhone."
        case .connect:
            return "Choose optional app and category reports for late evening and after waking."
        case .needsAttention:
            return "Screen Time access needs attention. Connecting does not change a current Wind Down or its emergency exit."
        case .chooseSelection:
            return "Screen Time is connected. Choose the apps and categories used for reports and future protection setup."
        case let .configured(selectionSummary):
            return "Configured for \(selectionSummary). Reports stay separate from the current protection status."
        }
    }

    @ViewBuilder
    private var action: some View {
        switch presentation {
        case .unavailable:
            EmptyView()
        case .connect:
            Button("Connect Screen Time", action: onConnect)
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
        case .needsAttention:
            Button("Try Screen Time again", action: onConnect)
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
            Text("If Apple does not offer a prompt, review Family Controls access in Settings.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
        case .chooseSelection:
            Button("Choose apps and categories", action: onChooseSelection)
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
        case .configured:
            Button("Change selection", action: onChooseSelection)
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
        }
    }
}

#Preview("Connection status · empty") {
    HealthConnectionStatusCard(
        presentation: .noData(checkedAt: .now),
        onConnect: {},
        onRefresh: {}
    )
    .padding()
    .background(AppColors.paper)
}

#Preview("Connection status · error") {
    HealthConnectionStatusCard(
        presentation: .staleData(sampleDate: nil, checkedAt: nil, error: "Preview"),
        onConnect: {},
        onRefresh: {}
    )
    .padding()
    .background(AppColors.paper)
    .preferredColorScheme(.dark)
}

#Preview("Screen Time connection · empty and needs attention") {
    VStack(spacing: AppSpacing.md) {
        ScreenTimeConnectionStatusCard(
            presentation: .connect,
            onConnect: {},
            onChooseSelection: {}
        )
        ScreenTimeConnectionStatusCard(
            presentation: .needsAttention,
            onConnect: {},
            onChooseSelection: {}
        )
    }
    .padding()
    .background(AppColors.paper)
}

#Preview("Apple Health access help · accessibility") {
    HealthConnectionAccessHelpSheet()
        .environment(\.dynamicTypeSize, .accessibility5)
}
