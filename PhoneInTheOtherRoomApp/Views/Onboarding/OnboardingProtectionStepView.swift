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
                eyebrow: "APP LIMITS",
                title: "Protect the quiet you’re making.",
                detail: contextualProtectionDetail
            )

            OnboardingChoiceCard(
                title: "App limits",
                detail: "Choose social media or other distracting apps and categories to limit through the full Wind Down. Counting Sheep stays available.",
                icon: "iphone.slash",
                isSelected: draft.shieldingEnabled && draft.protectionChoice == .appShielding
            ) {
                draft.protectionChoice = .appShielding
                draft.shieldingEnabled = true
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

    private var contextualProtectionDetail: String {
        guard !draft.profileSkipped else {
            return "Choose the apps or categories you would like to pause while your phone rests. Counting Sheep stays available."
        }
        switch draft.profileRecommendation.kind {
        case .oneMoreThing:
            return "You mentioned that one more scroll can pull you back. Choose the apps you would like to pause while your phone rests."
        case .messagePull:
            return "You mentioned that messages can pull you back. Choose the apps you would like to pause while your phone rests."
        case .automaticReach:
            return "You mentioned that reaching can happen automatically. Choose the apps you would like to pause while your phone rests."
        default:
            return "Choose apps or categories in Apple’s picker to pause while your phone rests. Counting Sheep stays available."
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
                        Text("Try social media or another distracting app/category. You choose what stays limited; no app names leave this phone.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                    Button(
                        viewModel.hasSelectedShieldingApps ? "Change selected apps" : "Choose apps to limit",
                        action: onChooseApps
                    )
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    Text("Does this include the apps that pull you back most often?")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    HStack {
                        Button("Review", action: onChooseApps)
                            .buttonStyle(PixelChipButtonStyle(isSelected: false))
                        Button(draft.protectionSelectionSelfConfirmed ? "Yes" : "Yes, continue") {
                            draft.protectionSelectionSelfConfirmed = true
                        }
                        .disabled(!viewModel.hasSelectedShieldingApps)
                        .buttonStyle(PixelChipButtonStyle(isSelected: draft.protectionSelectionSelfConfirmed))
                    }
                    Text("This is your own check. Counting Sheep does not verify named apps.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                } else if case .denied = viewModel.screenTimeAuthorization {
                        Text("Screen Time access is off. Restore it, then choose at least one app or category to continue.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                } else if viewModel.screenTimeAuthorization == .unavailable {
                        Text("App protection is unavailable on this device. A new Wind Down cannot start until it is available.")
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
                }

                if viewModel.shieldingReadiness != .ready {
                    Text(viewModel.shieldingReadiness.detail)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    Text("Finish app protection setup to continue.")
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
