import AuthenticationServices
import SwiftUI

struct OnboardingAccountStep: View {
    enum Kind { case newUser, returning }

    let kind: Kind
    @ObservedObject var model: FarmBackupViewModel
    let farmState: FarmState
    let protectedNightCount: Int
    let onContinue: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            accountArtwork
            onboardingTitle(
                eyebrow: kind == .returning ? "WELCOME BACK" : "YOUR ACCOUNT",
                title: "Keep your Farm with you",
                detail: "Sign in and your Farm stays in sync across phones."
            )
            accountActions
            Button(continueTitle, action: onContinue)
                .disabled(model.busy || model.accessBlocked)
                .font(AppTypography.body.weight(.semibold))
                .foregroundStyle(AppColors.grass)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityHint(continueHint)
        }
        .foregroundStyle(AppColors.ink)
        .task { if model.available { model.refresh() } }
    }

    private var continueTitle: String { model.signedIn ? "Continue to setup" : "Continue as guest" }
    private var continueHint: String { "Continue this phone’s Wind Down setup." }

    private var accountActions: some View {
        AccountConnectionContent(model: model)
    }

    private var accountArtwork: some View {
        HStack(alignment: .bottom, spacing: AppSpacing.sm) {
            ShepherdAvatarView(profile: farmState.shepherd, size: dynamicTypeSize.isAccessibilitySize ? 86 : 112)
            PixelAssetImage(name: NightJourneyAssets.ollieHomeIdleFrames.first ?? "dog/dog_classic_home_idle_frame_01")
                .frame(width: dynamicTypeSize.isAccessibilitySize ? 78 : 98, height: dynamicTypeSize.isAccessibilitySize ? 78 : 98)
            if let sheep = farmState.activeSheep.first {
                FarmSheepSprite(sheep: sheep, protectedNightCount: protectedNightCount, size: dynamicTypeSize.isAccessibilitySize ? 64 : 82)
            } else {
                PixelAssetImage(name: WelcomeRewardCatalog.starterDefinition?.assetName ?? "sheep/sheep_mabel_wool_ready")
                    .frame(width: dynamicTypeSize.isAccessibilitySize ? 64 : 82, height: dynamicTypeSize.isAccessibilitySize ? 64 : 82)
            }
        }
        .frame(maxWidth: .infinity).padding(AppSpacing.sm)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your Shepherd, Ollie, and a sheep.")
    }
}

@MainActor
private func accountPreview(_ presentation: FarmBackupAccountPresentation) -> some View {
    let model = FarmBackupViewModel(persistence: .shared, account: nil, service: nil)
    model.accountPresentation = presentation
    model.signedIn = presentation != .signedOut && presentation != .unavailable
    return ScrollView {
        OnboardingAccountStep(kind: .newUser, model: model, farmState: .empty,
            protectedNightCount: 0, onContinue: {}).padding().background(AppColors.paper)
    }
}

#Preview("Account invitation · signed out") { accountPreview(.signedOut) }
#Preview("Account invitation · unavailable") { accountPreview(.unavailable) }
#Preview("Account invitation · existing Farm") { accountPreview(.remoteFarm(FarmBackupAccountPreview(revisionID: UUID(), savedAt: .now, activeSheepCount: 12, woolBalance: 240))) }
#Preview("Account invitation · retry") { accountPreview(.failed) }
#Preview("Account invitation · large text") { accountPreview(.noRemoteSave).environment(\.dynamicTypeSize, .accessibility3) }
