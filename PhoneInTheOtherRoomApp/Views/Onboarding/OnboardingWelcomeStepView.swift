import SwiftUI

struct OnboardingWelcomeStep: View {
    let page: OnboardingWelcomePage

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            onboardingTitle(
                eyebrow: page == .countingSheep ? AppCopy.OnboardingWelcome.eyebrow.value : page.eyebrow,
                title: page == .countingSheep ? AppCopy.OnboardingWelcome.title.value : page.title,
                detail: page == .countingSheep ? AppCopy.OnboardingWelcome.detail.value : page.detail
            )

            if page == .windDown || page == .countingSheep {
                OnboardingTimeline(draft: OnboardingDraft())
            }

            VStack(spacing: AppSpacing.sm) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    AppColors.grass.opacity(0.58),
                                    AppColors.activeWindDownBackground
                                ],
                                center: .center,
                                startRadius: 12,
                                endRadius: 150
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                                .stroke(AppColors.grassLight.opacity(0.32), lineWidth: 1)
                        }

                    Ellipse()
                        .fill(AppColors.grass.opacity(0.28))
                        .frame(width: 132, height: 22)
                        .padding(.bottom, AppSpacing.sm)

                    HomeOllieIdleView(presentation: .onboardingHero)
                        .shadow(
                            color: AppShadows.cardColor.opacity(0.9),
                            radius: AppShadows.cardRadius,
                            y: AppShadows.cardY
                        )
                        .padding(.bottom, AppSpacing.xs)
                }
                .frame(width: 236, height: 206)
                .accessibilityHidden(true)

                Text(caption)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 320)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(page.eyebrow). \(page.title). \(page.detail)")
    }

    private var caption: String {
        switch page {
        case .countingSheep:
            return "Ollie keeps watch while the phone rests somewhere else."
        case .windDown:
            return "Quiet before bed, overnight rest, then quiet after waking."
        case .phoneAway:
            return "A shorter stretch, with optional app limits if you want them."
        case .ollie:
            return "Follow through, and Ollie looks after the flock."
        }
    }
}

#Preview("Welcome · Counting Sheep") {
    OnboardingWelcomeStep(page: .countingSheep)
        .padding()
        .background(AppColors.paper)
}

#Preview("Welcome · Wind Down") {
    OnboardingWelcomeStep(page: .windDown)
        .padding()
        .background(AppColors.paper)
}

#Preview("Welcome · Phone Away · dark") {
    OnboardingWelcomeStep(page: .phoneAway)
        .padding()
        .background(AppColors.paper)
        .preferredColorScheme(.dark)
}

#Preview("Welcome · Ollie · large type") {
    OnboardingWelcomeStep(page: .ollie)
        .padding()
        .background(AppColors.paper)
        .environment(\.dynamicTypeSize, .accessibility3)
}
