import SwiftUI

struct OnboardingRecommendationStep: View {
    @Binding var draft: OnboardingDraft
    let answers: WindDownProfileAnswer
    let recommendation: WindDownProfileRecommendation
    var showsSourcesLink = true

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            profileReveal
            answerSummary
            compactTip
        }
    }

    private var profileReveal: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("YOUR STARTING POINT")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

            patternArt
            resultCopy
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.sm)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .accessibilityElement(children: .combine)
    }

    private var answerSummary: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("WHAT WE NOTICED")
                .font(pixelFont(.caption2))
                .foregroundStyle(AppColors.grass)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            ForEach(Array(recommendation.noticed.enumerated()), id: \.offset) { _, observation in
                answerRow(icon: "checkmark.circle", text: observation)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.md))
    }

    private var compactTip: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Label("A gentle place to begin", systemImage: "leaf.fill")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.grass)
            Text(recommendation.suggestedStrategy)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if showsSourcesLink {
                NavigationLink {
                    WindDownGuideView(onboardingDraft: $draft)
                } label: {
                    Text(FirstRunGuideCopy.aboutIdeasAndSources)
                        .font(AppTypography.caption)
                        .frame(minHeight: 44, alignment: .leading)
                }
                .accessibilityHint("Opens the local source library")
            }
        }
        .padding(.horizontal, AppSpacing.xs)
    }

    private var patternTitle: String {
        guard let secondary = recommendation.secondaryKind else { return recommendation.kind.title }
        return "\(recommendation.kind.title) + \(secondary.title)"
    }

    private var patternArt: some View {
        Image(recommendation.kind.onboardingIllustrationAssetName)
            .resizable()
            .aspectRatio(2, contentMode: .fit)
            .frame(maxWidth: 300)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .accessibilityHidden(true)
    }

    private var resultCopy: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(patternTitle)
                .font(AppTypography.title)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(recommendation.summary)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.secondaryText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func answerRow(icon: String, text: String) -> some View {
        Label {
            Text(text)
                .font(AppTypography.body)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(AppColors.grass)
                .frame(width: 26)
        }
    }

}

struct OnboardingShepherdGiftStep: View {
    @Binding var draft: OnboardingDraft

    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsAppearanceChoices = false

    private var claimedItemID: String? { viewModel.claimedWelcomeGiftItemID }
    private var reservedItemID: String? { viewModel.existingWelcomeGiftItemID }
    private var selectedItemID: String? {
        claimedItemID ?? reservedItemID ?? draft.selectedWelcomeGiftItemID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            onboardingTitle(
                eyebrow: "YOUR SHEPHERD",
                title: "A little something for starting.",
                detail: claimedItemID == nil
                    ? "Ollie picked out a few things for your first night. Choose one for your Shepherd."
                    : "Ollie’s pick is waiting in your wardrobe. You can change your Shepherd’s look whenever you like."
            )

            VStack(spacing: AppSpacing.sm) {
                ShepherdAvatarView(
                    profile: WelcomeRewardEngine.previewShepherd(
                        viewModel.farmState.shepherd,
                        wearing: claimedItemID == nil ? selectedItemID : nil
                    ),
                    size: dynamicTypeSize.isAccessibilitySize ? 140 : 178
                )
                Text("Your Shepherd")
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(AppColors.grass)
                Button(showsAppearanceChoices ? "Do this later" : "Make them yours") {
                    showsAppearanceChoices.toggle()
                }
                .font(AppTypography.caption.weight(.semibold))
                .frame(minHeight: 44)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity)
            .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.lg))

            if showsAppearanceChoices {
                ShepherdAppearanceControls(
                    profile: viewModel.farmState.shepherd,
                    onSkinTone: viewModel.setShepherdSkinTone,
                    onHeadShape: viewModel.setShepherdHeadShape,
                    onHairStyle: viewModel.setShepherdHairStyle,
                    compact: true
                )
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(claimedItemID == nil ? "Choose one welcome gift" : "Your welcome gift")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.grass)

                ForEach(giftItems) { item in
                    giftRow(item)
                }
            }
        }
        .onAppear {
            if let reservedItemID { draft.selectedWelcomeGiftItemID = reservedItemID }
        }
    }

    private var giftItems: [FarmShopItem] {
        WelcomeRewardCatalog.finishedShepherdWearableIDs.compactMap(FarmShopCatalog.item(for:))
    }

    private func giftRow(_ item: FarmShopItem) -> some View {
        let selected = selectedItemID == item.id
        let locked = reservedItemID != nil && !selected
        return Button {
            guard reservedItemID == nil else { return }
            draft.selectedWelcomeGiftItemID = item.id
        } label: {
            HStack(alignment: .center, spacing: AppSpacing.sm) {
                FarmShopItemImage(item: item, size: 56)
                    .frame(width: 60, height: 60)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(item.title)
                        .font(AppTypography.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(flavour(for: item))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: AppSpacing.xs)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? AppColors.grass : AppColors.muted)
            }
            .padding(AppSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(
                selected ? AppColors.grassLight.opacity(0.22) : AppColors.surface,
                in: RoundedRectangle(cornerRadius: AppRadius.md)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(selected ? AppColors.grass : AppColors.stroke.opacity(0.22), lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .opacity(locked ? 0.55 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(locked ? "A welcome gift has already been chosen" : "Previews this gift on your Shepherd")
    }

    private func flavour(for item: FarmShopItem) -> String {
        switch item.id {
        case "shepherd_wool_hat":
            return "A sunny little hat for slow beginnings and bright mornings."
        case "shepherd_moss_coat":
            return "Deep pockets for small plans, quiet walks, and winding-down time."
        case "shepherd_moon_coat":
            return "For nights that don’t always run by the clock. A steady cue can still have a place."
        default:
            return item.detail
        }
    }
}

#Preview("Starting point") {
    OnboardingRecommendationStep(
        draft: .constant(OnboardingDraft()),
        answers: .defaults,
        recommendation: WindDownProfileMapper.recommendation(for: .defaults)
    )
    .padding()
    .background(AppColors.paper)
}

#Preview("Welcome gift · narrow") {
    ScrollView {
        OnboardingShepherdGiftStep(draft: .constant(OnboardingDraft(step: .gift)))
            .padding()
    }
    .frame(width: 320)
    .background(AppColors.paper)
    .environmentObject(FocusRunViewModel())
}

#Preview("Welcome gift · narrow · large type") {
    ScrollView {
        OnboardingShepherdGiftStep(draft: .constant(OnboardingDraft(step: .gift)))
            .padding()
    }
    .frame(width: 320)
    .background(AppColors.paper)
    .environmentObject(FocusRunViewModel())
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Starting point · large type") {
    let answers = WindDownProfileAnswer(
        bedtimeHour: 23,
        bedtimeMinute: 0,
        wakeHour: 7,
        wakeMinute: 0,
        phoneUsePattern: .beforeBed,
        awayFriction: .habitReach,
        eveningActivities: [.read],
        morningActivities: [.openCurtains],
        desiredWindDownMinutes: 30,
        automaticReaching: .often,
        morningChecking: .immediately
    )
    ScrollView {
        OnboardingRecommendationStep(
            draft: .constant(OnboardingDraft()),
            answers: answers,
            recommendation: WindDownProfileMapper.recommendation(for: answers)
        )
        .padding()
    }
    .background(AppColors.paper)
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
}
