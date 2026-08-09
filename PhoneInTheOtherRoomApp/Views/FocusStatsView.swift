import SwiftUI

/// The shipping Nights tab is intentionally one finite document. Its first
/// section answers what happened; optional context is progressively disclosed
/// below the recent ritual record.
struct FocusStatsView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    NightsHeader()
                    NightsRecordSection(
                        viewModel: viewModel,
                        focusedRecordID: viewModel.nightsRecordFocusID
                    )
                    NightsSevenDaySection(viewModel: viewModel)
                    NightsMonthLink(viewModel: viewModel)
                    NightsHealthContext(viewModel: viewModel)
                    NightsScreenTimeContext(viewModel: viewModel)
                }
                .padding(AppSpacing.md)
            }
            .background(AppColors.paper.ignoresSafeArea())
            .onAppear {
                viewModel.markOrientation(.nightsExplored)
                focusRecord(using: proxy)
            }
            .onChange(of: viewModel.nightsRecordFocusID) { _, _ in
                focusRecord(using: proxy)
            }
            .task {
                if viewModel.sleepAuthorization == .requested {
                    viewModel.refreshSleepSummary()
                }
            }
        }
    }

    private func focusRecord(using proxy: ScrollViewProxy) {
        guard let recordID = viewModel.nightsRecordFocusID else { return }
        Task { @MainActor in
            await Task.yield()
            withAnimation(AppMotion.navigation) {
                proxy.scrollTo(NightsRecordSection.anchor(for: recordID), anchor: .top)
            }
            viewModel.markOrientationPracticeRecordViewedIfPresent()
            viewModel.clearNightsRecordFocus()
        }
    }
}

struct NightsHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Nights")
                .font(AppTypography.display(34))
            Text("See what your phone-away ritual recorded around sleep.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.muted)
        }
    }
}

#Preview("Nights · empty · light") {
    NavigationStack {
        FocusStatsView()
            .environmentObject(FocusRunViewModel())
    }
    .preferredColorScheme(.light)
}

#Preview("Nights · optional context unavailable · dark") {
    let viewModel = FocusRunViewModel()
    viewModel.screenTimeAuthorization = .unavailable
    viewModel.sleepAuthorization = .unavailable
    return NavigationStack {
        FocusStatsView()
            .environmentObject(viewModel)
    }
    .preferredColorScheme(.dark)
}

#Preview("Nights · denied and large type") {
    let viewModel = FocusRunViewModel()
    viewModel.screenTimeAuthorization = .denied("Preview")
    viewModel.sleepAuthorization = .error("Preview")
    return NavigationStack {
        FocusStatsView()
            .environmentObject(viewModel)
    }
    .environment(\.dynamicTypeSize, .accessibility2)
    .preferredColorScheme(.light)
}
