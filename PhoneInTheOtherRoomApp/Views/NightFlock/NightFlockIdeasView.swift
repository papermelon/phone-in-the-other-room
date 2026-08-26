import SwiftUI

struct NightFlockIdeasView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Ideas and sources").font(AppTypography.display(27))
                Text("These are general Wind Down ideas from Counting Sheep’s source library. Try what suits you; none of them are a checklist.")
                    .font(AppTypography.body).foregroundStyle(AppColors.secondaryText)
                ForEach(WindDownGuidanceTopic.allCases) { topic in
                    let items = WindDownGuidanceLibrary.items(for: topic)
                    if !items.isEmpty {
                        PixelCard {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Text(topic.title).font(AppTypography.headline)
                                ForEach(items) { item in
                                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                        Text(item.title).font(AppTypography.body.weight(.semibold))
                                        Text(item.body).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                                        Text("Sources: \(item.sourceIDs.joined(separator: ", "))")
                                            .font(pixelFont(.caption2)).foregroundStyle(AppColors.muted)
                                    }
                                    .padding(.vertical, AppSpacing.xxs)
                                }
                            }
                        }
                    }
                }
            }
            .padding(AppSpacing.md)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Ideas and sources")
        .navigationBarTitleDisplayMode(.inline)
    }
}
