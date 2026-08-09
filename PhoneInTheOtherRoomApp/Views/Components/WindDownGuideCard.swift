import SwiftUI

struct WindDownGuideCard: View {
    let item: WindDownGuidanceItem
    var compact = false

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: compact ? AppSpacing.xs : AppSpacing.sm) {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(AppColors.grass)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(compact ? "ONE GENTLE IDEA" : "A GENTLE IDEA")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.grass)
                        Text(item.title)
                            .font(compact ? AppTypography.headline : AppTypography.title)
                    }
                    Spacer(minLength: 0)
                }
                Text(item.body)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Optional. No score, task, or streak attached.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }
}

struct WindDownGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("WIND DOWN GUIDE")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text("Small ideas for a kinder relationship with screens and sleep.")
                        .font(AppTypography.display(30))
                    Text("These are gentle experiments, not a treatment plan. Keep what feels useful and leave the rest.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.muted)
                }

                ForEach(WindDownGuidanceTopic.allCases) { topic in
                    let topicItems = WindDownGuidanceLibrary.items(for: topic)
                    if !topicItems.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text(topic.title)
                                .font(AppTypography.headline)
                            ForEach(topicItems) { item in
                                guideItem(item)
                            }
                        }
                    }
                }

                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("A note about sleep support")
                            .font(AppTypography.headline)
                        Text("Counting Sheep is not a sleep clinic or an insomnia treatment. If sleep difficulties keep affecting your days, a healthcare professional or CBT-I provider can help you find the right support.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Wind Down guide")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func guideItem(_ item: WindDownGuidanceItem) -> some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(item.title)
                    .font(AppTypography.headline)
                Text(item.body)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)
                Text(sourceLabel(for: item))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

    private func sourceLabel(for item: WindDownGuidanceItem) -> String {
        let labels = item.sourceIDs.compactMap { sourceTitle(for: $0) }
        return labels.isEmpty ? "Counting Sheep guidance" : "Sources: " + labels.joined(separator: " · ")
    }

    private func sourceTitle(for id: String) -> String? {
        switch id {
        case "nhlbi-healthy-sleep": return "NHLBI healthy sleep habits"
        case "nhlbi-sleep-wake-cycle": return "NHLBI sleep/wake cycle"
        case "nhlbi-circadian-treatment": return "NHLBI circadian guidance"
        case "va-stimulus-control": return "VA stimulus-control guidance"
        case "counting-sheep-principles": return "Counting Sheep product principles"
        case "counting-sheep-booklet": return "Counting Sheep wellness booklet"
        default: return nil
        }
    }
}

struct WindDownHowItWorksView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                OllieRitualView(state: .ready, size: 112)
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("HOW WIND DOWN WORKS")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text("One small ritual around sleep.")
                        .font(AppTypography.display(30))
                    Text("Counting Sheep helps you make the phone-away choice, fill the quiet with something offline, and keep the first part of morning phone-free.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.muted)
                }
                OnboardingTimeline(draft: OnboardingDraft())
                howCard(
                    icon: "iphone.slash",
                    title: "Protect",
                    detail: "Apps to rest can be limited from Wind Down start through morning quiet. Counting Sheep stays available."
                )
                howCard(
                    icon: "book.closed.fill",
                    title: "Replace",
                    detail: "Choose one gentle evening cue and one morning cue. They are invitations, never tasks."
                )
                howCard(
                    icon: "sparkles",
                    title: "Learn",
                    detail: "A small, optional guide offers sourced ideas about screens, light, timing, and settling. It never becomes a feed or a score."
                )
                Text("Change your schedule, apps, Wind Down tag, and reminders in Your Wind Down.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("How Wind Down works")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func howCard(icon: String, title: String, detail: String) -> some View {
        PixelCard {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.title2.weight(.black))
                    .foregroundStyle(AppColors.grass)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(title).font(AppTypography.headline)
                    Text(detail)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
        }
    }
}

#Preview("Guide card") {
    WindDownGuideCard(item: WindDownGuidanceLibrary.items[0])
        .padding()
        .background(AppColors.paper)
}

#Preview("Guide") {
    NavigationStack {
        WindDownGuideView()
    }
}
