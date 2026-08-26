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
                            Text("Up to 30 recent eligible nights as a date-free baseline, then future nights: planned and completed phone-free minutes, start method, shielding status, sleep duration and available stages, optional restfulness, and app version.")
                                .font(AppTypography.body)
                        }
                    }

                    PixelCard {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("What stays private")
                                .font(AppTypography.headline)
                            Text("Exact dates and times, raw Apple Health samples, selected apps, NFC tag identity, Health source names, and your own written reflections.")
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
