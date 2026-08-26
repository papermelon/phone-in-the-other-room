import SwiftUI

struct OnboardingWelcomeStep: View {
    let page: OnboardingWelcomePage
    var starterSheep: FlockSheep?
    var protectedNightCount = 0

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasPlayedReaction = false
    @State private var sheepOffset: CGFloat = 8
    @State private var sheepScale: CGFloat = 1
    @State private var sheepTilt: Double = 0
    @State private var dogOffset: CGFloat = 0
    @State private var dogScale: CGFloat = 1
    @State private var dogTilt: Double = 0
    @State private var showsBaa = false

    private var visiblePage: OnboardingWelcomePage { page.normalizedForCurrentFlow }

    var body: some View {
        Group {
            switch visiblePage {
            case .countingSheep:
                phoneRestingStory
            case .ollie:
                farmStory
            case .windDown, .phoneAway:
                EmptyView()
            }
        }
        .accessibilityElement(children: .contain)
        .task(id: visiblePage) { await playWelcomeReactionIfNeeded() }
    }

    private var phoneRestingStory: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            onboardingTitle(
                eyebrow: AppCopy.OnboardingWelcome.eyebrow.value,
                title: AppCopy.OnboardingWelcome.title.value,
                detail: AppCopy.OnboardingWelcome.detail.value
            )

            Image(AssetSlot.Onboarding.phoneRestStory)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .background(AppColors.surfaceMuted)
                .aspectRatio(1.5, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                storyRow(icon: "moon.zzz.fill", title: "Wind down without the scroll")
                storyRow(icon: "door.left.hand.open", title: "Keep your phone out of reach overnight")
                storyRow(icon: "sunrise.fill", title: "Start your morning before your feed does")
            }
        }
    }

    private var farmStory: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    Image(AssetSlot.Farm.backgroundDay)
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)

                    HStack(alignment: .bottom, spacing: AppSpacing.sm) {
                        PixelAssetImage(
                            name: NightJourneyAssets.ollieHomeIdleFrames.first
                                ?? "dog/dog_classic_home_idle_frame_01"
                        )
                            .frame(
                                width: dynamicTypeSize.isAccessibilitySize ? 92 : 124,
                                height: dynamicTypeSize.isAccessibilitySize ? 92 : 124
                            )
                            .scaleEffect(dogScale, anchor: .bottom)
                            .rotationEffect(.degrees(dogTilt), anchor: .bottom)
                            .offset(y: dogOffset)

                        starterSheepSprite
                            .scaleEffect(x: sheepScale, y: 2 - sheepScale, anchor: .bottom)
                            .rotationEffect(.degrees(sheepTilt), anchor: .bottom)
                            .offset(y: sheepOffset)
                            .overlay(alignment: .topTrailing) {
                                if showsBaa {
                                    Text("baa")
                                        .font(AppTypography.caption.weight(.semibold))
                                        .foregroundStyle(AppColors.ink)
                                        .padding(.horizontal, AppSpacing.xs)
                                        .padding(.vertical, AppSpacing.xxs)
                                        .background(AppColors.paper.opacity(0.94), in: Capsule())
                                        .offset(x: 10, y: -10)
                                        .transition(.opacity)
                                }
                            }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .frame(width: proxy.size.width, alignment: .center)
                    .padding(.bottom, AppSpacing.xs)
                }
            }
            .frame(height: dynamicTypeSize.isAccessibilitySize ? 176 : 220)
            .background(AppColors.grassLight.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "Ollie the Collie sits beside Mabel, the starter sheep, in front of the Farm barn."
            )

            onboardingTitle(
                eyebrow: visiblePage.eyebrow,
                title: visiblePage.title
            )

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                storyBeat(
                    number: 1,
                    icon: "shield.lefthalf.filled",
                    text: Text("Ollie helps guard your screen time when it might get in the way of rest."),
                    accessibilityText: "Ollie helps guard your screen time when it might get in the way of rest."
                )
                storyBeat(
                    number: 2,
                    icon: "pawprint.fill",
                    text: Text("Each night you complete a ")
                        + Text("Wind Down").bold()
                        + Text(", he’ll search for lost sheep to bring back to your Farm."),
                    accessibilityText: "Each night you complete a Wind Down, he’ll search for lost sheep to bring back to your Farm."
                )
                storyBeat(
                    number: 3,
                    icon: "timer",
                    text: Text("Need some space from your phone during the day? ")
                        + Text("Phone Away").bold()
                        + Text(" is there for that, too."),
                    accessibilityText: "Need some space from your phone during the day? Phone Away is there for that, too."
                )
            }
        }
    }

    @ViewBuilder
    private var starterSheepSprite: some View {
        let size: CGFloat = dynamicTypeSize.isAccessibilitySize ? 73 : 95
        if let starterSheep, starterSheep.definitionID == WelcomeRewardCatalog.starterSheepID {
            FarmSheepSprite(
                sheep: starterSheep,
                protectedNightCount: protectedNightCount,
                size: size,
                showsStatusBadge: false
            )
        } else {
            PixelAssetImage(
                name: WelcomeRewardCatalog.starterDefinition?.assetName
                    ?? "sheep/sheep_mabel_wool_ready"
            )
            .frame(width: size, height: size)
        }
    }

    @MainActor
    private func playWelcomeReactionIfNeeded() async {
        guard visiblePage == .ollie, !hasPlayedReaction else { return }
        hasPlayedReaction = true
        guard !reduceMotion else {
            sheepOffset = 0
            return
        }

        withAnimation(.easeOut(duration: 0.5)) {
            sheepOffset = 0
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.16)) {
            sheepScale = 1.07
            sheepTilt = -5
            showsBaa = true
        }
        try? await Task.sleep(nanoseconds: 180_000_000)
        withAnimation(.easeOut(duration: 0.16)) {
            sheepScale = 1
            sheepTilt = 0
            dogOffset = -3
            dogScale = 0.98
            dogTilt = 3
        }
        try? await Task.sleep(nanoseconds: 280_000_000)
        withAnimation(.easeInOut(duration: 0.16)) {
            dogOffset = 0
            dogScale = 1
            dogTilt = 0
            showsBaa = false
        }
    }

    private func storyRow(icon: String, title: String) -> some View {
        Label {
            Text(title)
                .font(AppTypography.body)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(AppColors.grass)
                .frame(width: 28)
        }
        .frame(minHeight: 44)
    }

    private func storyBeat(
        number: Int,
        icon: String,
        text: Text,
        accessibilityText: String
    ) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            ZStack {
                Circle().fill(AppColors.grass.opacity(0.12))
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.grass)
            }
            .frame(width: 34, height: 34)
            .accessibilityHidden(true)

            text
                .font(AppTypography.body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 44)
        .accessibilityLabel("Story point \(number). \(accessibilityText)")
    }
}

#Preview("Welcome · phone resting place") {
    ScrollView {
        OnboardingWelcomeStep(page: .countingSheep)
            .padding()
    }
    .background(AppColors.paper)
}

#Preview("Welcome · Ollie and the Farm") {
    ScrollView {
        OnboardingWelcomeStep(page: .ollie)
            .padding()
    }
    .background(AppColors.paper)
}

#Preview("Welcome · large type") {
    ScrollView {
        OnboardingWelcomeStep(page: .countingSheep)
            .padding()
    }
    .background(AppColors.paper)
    .environment(\.dynamicTypeSize, .accessibility3)
}
