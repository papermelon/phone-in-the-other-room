import SwiftUI

struct AutomaticWindDownCard: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Toggle("Start Wind Down automatically", isOn: Binding(
                    get: { viewModel.nightWatchPreferences.automaticStartEnabled },
                    set: viewModel.setAutomaticStartEnabled
                ))
                .font(AppTypography.headline)
                Text("Use your repeating plan for automatic starts and scheduled app limits.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                Text(viewModel.automaticWindDownStatusPresentation.title)
                    .font(AppTypography.body.weight(.semibold))
                Text(viewModel.automaticWindDownStatusPresentation.detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if viewModel.automaticWindDownStatusPresentation.needsRepair {
                    NavigationLink {
                        ScreenTimeProtectionRepairView(repairsAutomaticStart: true)
                    } label: {
                        Text("Review protection repair")
                    }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                }
            }
        }
    }
}

#Preview("Automatic Wind Down") {
    NavigationStack { AutomaticWindDownCard().padding() }
        .environmentObject(FocusRunViewModel(startsExternalServices: false))
}
