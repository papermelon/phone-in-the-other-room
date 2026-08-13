import SwiftUI

struct OnboardingWelcomeStep: View {
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            onboardingTitle(
                eyebrow: AppCopy.OnboardingWelcome.eyebrow.value,
                title: AppCopy.OnboardingWelcome.title.value,
                detail: AppCopy.OnboardingWelcome.detail.value
            )

            OnboardingTimeline(draft: OnboardingDraft())

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

                Text("Ollie keeps watch while the phone rests somewhere else.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 320)
        }
    }
}

#Preview("Welcome") {
    OnboardingWelcomeStep()
        .padding()
        .background(AppColors.paper)
}

#Preview("Welcome · dark") {
    OnboardingWelcomeStep()
        .padding()
        .background(AppColors.paper)
        .environment(\.colorScheme, .dark)
}
