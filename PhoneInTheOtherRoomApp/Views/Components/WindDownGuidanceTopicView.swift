import SwiftUI

struct WindDownGuidanceTopicView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    let topic: WindDownGuidanceTopic
    var onboardingDraft: Binding<OnboardingDraft>? = nil

    private var items: [WindDownGuidanceItem] {
        WindDownGuidanceLibrary.items(for: topic)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("IDEAS")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(topic.title)
                        .font(AppTypography.display(30))
                    Text(topic.detail)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                }

                if items.isEmpty {
                    PixelCard {
                        Text("There are no ideas here yet.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                } else {
                    VStack(spacing: AppSpacing.xs) {
                        ForEach(items) { item in
                            NavigationLink {
                                WindDownGuidanceDetailView(
                                    item: item,
                                    onboardingDraft: onboardingDraft
                                )
                                .environmentObject(viewModel)
                            } label: {
                                ideaRow(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(AppSpacing.md)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func ideaRow(_ item: WindDownGuidanceItem) -> some View {
        PixelCard {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(item.title)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.ink)
                    Text(item.suggestion)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: AppSpacing.sm)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.grass)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows this idea")
    }
}

#Preview("Topic ideas") {
    NavigationStack {
        WindDownGuidanceTopicView(topic: .lightAndTiming)
            .environmentObject(FocusRunViewModel(startsExternalServices: false))
    }
}

#Preview("Topic ideas · accessibility") {
    NavigationStack {
        WindDownGuidanceTopicView(topic: .screenBoundary)
            .environmentObject(FocusRunViewModel(startsExternalServices: false))
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}
