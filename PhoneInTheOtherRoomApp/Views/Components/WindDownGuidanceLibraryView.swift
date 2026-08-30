import SwiftUI

/// The shared destination for Home, setup, onboarding, Settings, and the
/// legacy Slumber Party entry point. Its public type stays stable so existing
/// routes do not need to know about the library's internal screens.
struct WindDownGuideView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    var onboardingDraft: Binding<OnboardingDraft>? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header

                VStack(spacing: AppSpacing.xs) {
                    ForEach(WindDownGuidanceTopic.allCases) { topic in
                        NavigationLink {
                            WindDownGuidanceTopicView(
                                topic: topic,
                                onboardingDraft: onboardingDraft
                            )
                            .environmentObject(viewModel)
                        } label: {
                            topicRow(topic)
                        }
                        .buttonStyle(.plain)
                    }
                }

                NavigationLink {
                    WindDownGuidanceSourcesView(onboardingDraft: onboardingDraft)
                        .environmentObject(viewModel)
                } label: {
                    Label("Browse all sources", systemImage: "books.vertical.fill")
                        .font(AppTypography.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(PixelChipButtonStyle(isSelected: false))

                Text("Counting Sheep is not a sleep clinic or a treatment plan. If sleep difficulties keep affecting your days, a healthcare professional or CBT-I provider can help you find the right support.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppSpacing.md)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Ideas & sources")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("IDEAS & SOURCES")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            Text("Small ideas for a kinder relationship with screens and sleep.")
                .font(AppTypography.display(30))
            Text("Try what suits you. These are invitations, not a checklist.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.secondaryText)
        }
    }

    private func topicRow(_ topic: WindDownGuidanceTopic) -> some View {
        PixelCard {
            HStack(alignment: .center, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(topic.title)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.ink)
                    Text(topic.detail)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: AppSpacing.sm)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.grass)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows ideas about \(topic.title.lowercased())")
    }
}

#Preview("Ideas and sources") {
    NavigationStack {
        WindDownGuideView()
            .environmentObject(FocusRunViewModel(startsExternalServices: false))
    }
}
