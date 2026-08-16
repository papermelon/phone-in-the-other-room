import SwiftUI

#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
import FamilyControls
#endif

struct OnboardingProtectionStep: View {
    @Binding var draft: OnboardingDraft
    @ObservedObject var viewModel: FocusRunViewModel
    let onChooseApps: () -> Void
    let showsNFCChoice: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            onboardingTitle(
                eyebrow: "OPTIONAL PROTECTION",
                title: "Give the quiet a little help.",
                detail: FirstRunGuideCopy.screenTimePermission + " " + FirstRunGuideCopy.permissionCanDecline
            )

            OnboardingChoiceCard(
                title: "App limits",
                detail: "Choose 1–3 apps or categories to limit through your full Wind Down.",
                icon: "iphone.slash",
                isSelected: draft.shieldingEnabled && draft.protectionChoice == .appShielding
            ) {
                draft.protectionChoice = .appShielding
                draft.shieldingEnabled = true
            }

            OnboardingChoiceCard(
                title: "No app limits for now",
                detail: "Keep the phone-away ritual without shielding. You can add apps later in Settings.",
                icon: "moon.stars.fill",
                isSelected: !draft.shieldingEnabled
            ) {
                draft.protectionChoice = .appShielding
                draft.shieldingEnabled = false
            }

            if showsNFCChoice {
                OnboardingChoiceCard(
                    title: OnboardingProtectionChoice.nfcAndAppShielding.title,
                    detail: "Your saved Wind Down tag stays available. Manage this advanced choice in Settings.",
                    icon: "dot.radiowaves.left.and.right",
                    isSelected: draft.shieldingEnabled && draft.protectionChoice == .nfcAndAppShielding
                ) {
                    draft.protectionChoice = .nfcAndAppShielding
                    draft.shieldingEnabled = true
                }

                if draft.protectionChoice == .nfcAndAppShielding {
                    nfcCard
                }
            }

            if draft.shieldingEnabled {
                shieldingCard
            }
        }
    }

    private var nfcCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Label("Wind Down tag", systemImage: "dot.radiowaves.left.and.right")
                    .font(AppTypography.headline)
                if viewModel.hasRegisteredNFCTag {
                    Label("Tag ready", systemImage: "checkmark.circle.fill")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                } else {
                    Text("Pair or replace the tag in Settings before using NFC.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    Button("Pair Wind Down tag") {
                        viewModel.provisionNFCTag()
                    }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                }
                if !viewModel.nfcStatus.isEmpty {
                    Text(viewModel.nfcStatus)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
    }

    private var shieldingCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Label("Choose apps to limit", systemImage: "shield.lefthalf.filled")
                    .font(AppTypography.headline)

                if viewModel.screenTimeAuthorization == .approved {
                    if viewModel.hasSelectedShieldingApps {
                    Text("Selected apps: \(viewModel.bedtimeActivitySelection.phoneOtherSelectionSummary)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.grass)
                    } else {
                        Text("Choose 1–3 apps or categories to limit.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                    Button(
                        viewModel.hasSelectedShieldingApps ? "Change selected apps" : "Choose apps to limit",
                        action: onChooseApps
                    )
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                } else if case .denied = viewModel.screenTimeAuthorization {
                    Text("Screen Time access is off. Save Wind Down now; choose apps to limit later in Settings if you want app limits.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                } else if viewModel.screenTimeAuthorization == .unavailable {
                    Text("App limits are unavailable on this device. Wind Down still works on its own.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                } else {
                    Text(FirstRunGuideCopy.screenTimePermission)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Allow Screen Time access") {
                        viewModel.connectScreenTime()
                    }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    Text(FirstRunGuideCopy.permissionCanDecline)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }

                if viewModel.shieldingReadiness != .ready {
                    Text(viewModel.shieldingReadiness.detail)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    Text("Finish this choice, or choose no app limits, to continue.")
                        .font(AppTypography.caption.weight(.bold))
                        .foregroundStyle(AppColors.grass)
                }
            }
        }
    }
}

#Preview("Shielding unavailable") {
    let viewModel = FocusRunViewModel()
    viewModel.screenTimeAuthorization = .unavailable
    return OnboardingProtectionStep(
        draft: .constant(OnboardingDraft()),
        viewModel: viewModel,
        onChooseApps: {},
        showsNFCChoice: false
    )
    .padding()
    .background(AppColors.paper)
}

#Preview("Shielding denied") {
    let viewModel = FocusRunViewModel()
    viewModel.screenTimeAuthorization = .denied("Preview")
    return OnboardingProtectionStep(
        draft: .constant(OnboardingDraft()),
        viewModel: viewModel,
        onChooseApps: {},
        showsNFCChoice: false
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Shielding connected · empty selection") {
    let viewModel = FocusRunViewModel()
    viewModel.screenTimeAuthorization = .approved
    return OnboardingProtectionStep(
        draft: .constant(OnboardingDraft()),
        viewModel: viewModel,
        onChooseApps: {},
        showsNFCChoice: false
    )
    .padding()
    .preferredColorScheme(.light)
}
