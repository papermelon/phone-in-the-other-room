import SwiftUI

struct SheepSearchExplainerView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("OLLIE’S SEARCH")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.grass)
                        Text(SheepSearchExplainerPresentation.rulesTitle)
                            .font(AppTypography.headline)
                        Text(SheepSearchExplainerPresentation.rulesDetail)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                ForEach(SheepSearchExplainerPresentation.sources) { source in
                    PixelCard {
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text(source.title)
                                .font(AppTypography.headline)
                            Text(source.detail)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("How Ollie’s searches work")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Ollie’s search rules") {
    NavigationStack { SheepSearchExplainerView() }
}
