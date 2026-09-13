import SwiftUI

struct ImpactSharingConsentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onShare: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Image(systemName: "hand.raised.fill")
                            .font(.title2)
                            .foregroundStyle(AppColors.grass)
                        Text("Help Counting Sheep learn what helps")
                            .font(AppTypography.display(28))
                        Text("Optional. Your detailed history stays on this iPhone.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.muted)
                    }

                    PixelCard {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("What is shared")
                                .font(AppTypography.headline)
                            Text("Up to 30 eligible nights before consent as a baseline, then future eligible nights. Records omit calendar dates and clock times but keep a night number relative to consent. They can include planned before-bed and after-waking quiet minutes, recorded Wind Down before-bed minutes, whether Wind Down ended normally or early, start method, shield-evidence category, sleep duration and available stages, your optional restfulness category, and app version.")
                                .font(AppTypography.body)
                        }
                    }

                    PixelCard {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("What stays private")
                                .font(AppTypography.headline)
                            Text("Calendar dates and clock times, raw Apple Health samples, selected apps, NFC tag identity, Health source names, your sleep-onset and bedtime-sleepiness answers, the complete morning note, and Quiet Note text.")
                                .font(AppTypography.body)
                        }
                    }

                    Button {
                        onShare()
                        dismiss()
                    } label: {
                        Text("Share optional impact data")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PixelPrimaryButtonStyle())

                    Button("Not now") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.muted)
                }
                .padding(AppSpacing.lg)
            }
            .background(AppColors.paper.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ImpactSharingConsentSheet(onShare: {})
}
