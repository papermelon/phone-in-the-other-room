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
            Text("Pick an idea to read more. Keep what fits your evening or morning.")
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


struct RoutineIdeasView: View {
    let phase: WindDownRoutinePhase
    @Binding var steps: [WindDownRoutineStep]
    var onSave: () -> Void
    @State private var draft: [WindDownRoutineStep]
    @Environment(\.dismiss) private var dismiss

    init(phase: WindDownRoutinePhase, steps: Binding<[WindDownRoutineStep]>, onSave: @escaping () -> Void = {}) {
        self.phase = phase
        self._steps = steps
        self.onSave = onSave
        self._draft = State(initialValue: steps.wrappedValue)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Find something that fits")
                    .font(AppTypography.headline)
                Text("Explore a small idea, see why you might try it, and add it to your routine draft. Tap Save ideas here when you’re ready.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)
                ForEach(WindDownGuidanceLibrary.items.filter { $0.routinePhase == phase }) { item in
                    NavigationLink {
                        WindDownGuidanceDetailView(item: item, routineDraft: $draft)
                    } label: {
                        PixelCard {
                            HStack(spacing: AppSpacing.sm) {
                                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                    Text(item.title).font(AppTypography.headline)
                                    Text(item.suggestion).font(AppTypography.caption)
                                        .foregroundStyle(AppColors.secondaryText)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .foregroundStyle(AppColors.ink)
        .navigationTitle(phase == .evening ? "Evening ideas" : "Morning ideas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save ideas") {
                    steps = draft
                    onSave()
                    dismiss()
                }
            }
        }
    }
}

#Preview("Evening ideas in a routine draft") {
    NavigationStack {
        RoutineIdeasView(phase: .evening, steps: .constant([]))
            .environmentObject(FocusRunViewModel(startsExternalServices: false))
    }
}
