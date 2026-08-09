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
                detail: "App shielding limits the apps you choose from Wind Down start through your morning quiet window. Counting Sheep stays available, and you can use the emergency exit if you need your phone back."
            )

            OnboardingChoiceCard(
                title: "Apps to rest",
                detail: "Choose 1–3 apps or categories to rest from Wind Down start through your morning quiet window.",
                icon: "iphone.slash",
                isSelected: draft.protectionChoice == .appShielding
            ) {
                draft.protectionChoice = .appShielding
                draft.shieldingEnabled = true
            }

            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Label("Start small", systemImage: "hand.tap.fill")
                        .font(AppTypography.headline)
                    Text("Pick the 1–3 apps you reach for around bedtime or waking. You can change them later in Settings.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }

            if showsNFCChoice {
                OnboardingChoiceCard(
                    title: OnboardingProtectionChoice.nfcAndAppShielding.title,
                    detail: "Your saved Wind Down tag stays available. Manage this advanced choice in Settings.",
                    icon: "dot.radiowaves.left.and.right",
                    isSelected: draft.protectionChoice == .nfcAndAppShielding
                ) {
                    draft.protectionChoice = .nfcAndAppShielding
                    draft.shieldingEnabled = true
                }

                if draft.protectionChoice == .nfcAndAppShielding {
                    nfcCard
                }
            }

            shieldingCard
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
                    Label("Choose apps to rest", systemImage: "shield.lefthalf.filled")
                    .font(AppTypography.headline)

                if viewModel.screenTimeAuthorization == .approved {
                    if viewModel.hasSelectedShieldingApps {
                    Text("Selected apps: \(viewModel.bedtimeActivitySelection.phoneOtherSelectionSummary)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.grass)
                    } else {
                        Text("Choose 1–3 apps or categories to rest.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                    Button(
                        viewModel.hasSelectedShieldingApps ? "Change apps to rest" : "Choose apps to rest",
                        action: onChooseApps
                    )
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                } else if case .denied = viewModel.screenTimeAuthorization {
                    Text("Screen Time access is off. Save Wind Down now; add apps to rest later in Settings if you want them.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                } else if viewModel.screenTimeAuthorization == .unavailable {
                    Text("Apps to rest are unavailable on this device. Wind Down still works on its own.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                } else {
                    Button("Allow Screen Time access") {
                        viewModel.connectScreenTime()
                    }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    Text("After permission, choose 1–3 apps or categories to rest. Counting Sheep never shields itself.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }

                if draft.shieldingEnabled {
                    Button("Continue without shielding") {
                        draft.shieldingEnabled = false
                    }
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.grass)
                } else {
                    Text("Wind Down without apps to rest for now. You can add them later in Settings.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                }

                if viewModel.shieldingReadiness != .ready {
                    Text(viewModel.shieldingReadiness.detail)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
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
