import SwiftUI

struct LockScreenQuietNoteGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("A little note below the clock")
                        .font(AppTypography.display(30))
                    Text("Keep one gentle line nearby when you reach for your phone.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.muted)
                }

                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Add Quiet Note")
                            .font(AppTypography.headline)
                        guideStep("1", "Touch and hold your Lock Screen, then choose Customize.")
                        guideStep("2", "Select the Lock Screen and tap the widget area below the clock.")
                        guideStep("3", "Choose Counting Sheep, then add Quiet Note.")
                        guideStep("4", "Tap the new widget to enter your note, then finish customization.")
                    }
                }

                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Keep it short")
                            .font(AppTypography.headline)
                        Text("Short lines work best in the small Lock Screen space. Anything you enter may be visible while your phone is locked, so keep private details inside Counting Sheep.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }

                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Two quiet surfaces")
                            .font(AppTypography.headline)
                        Text("The Quiet Note stays in place. During Wind Down, the separate Live Activity can show your current phase and timer.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Lock Screen note")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func guideStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Text(number)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.grass)
                .frame(width: 24, alignment: .leading)
            Text(text)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.secondaryText)
        }
    }
}

#Preview {
    NavigationStack {
        LockScreenQuietNoteGuideView()
    }
}
