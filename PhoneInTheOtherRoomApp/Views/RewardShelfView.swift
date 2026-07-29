import SwiftUI

struct RewardShelfView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    var body: some View {
        RewardShelfContent(rewards: viewModel.coordinator.rewards)
            .navigationTitle("Ollie's Keepsakes")
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RewardShelfContent: View {
    let rewards: [RewardItem]

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                shelfIntroduction

                if rewards.isEmpty {
                    emptyShelf
                } else {
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(rewards) { reward in
                            keepsakeCard(for: reward)
                        }
                    }
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.background.ignoresSafeArea())
    }

    private var shelfIntroduction: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(rewards.isEmpty ? "A QUIET SHELF" : "\(rewards.count) KEEPSAKES")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("Every keepsake marks a finished Night Watch or a kind fresh start.")
                    .font(pixelFont(.body))
                Text("Three keepsake families take turns. Milestones count all protected nights. A gap takes nothing away.")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

    private var emptyShelf: some View {
        PixelCard {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "archivebox")
                    .font(.system(size: 44, weight: .black))
                    .foregroundStyle(AppColors.muted)
                Text("Ollie has not brought anything back yet.")
                    .font(pixelFont(.body))
                    .multilineTextAlignment(.center)
                Text("The shelf is waiting for its first quiet-night keepsake.")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.lg)
        }
    }

    private func keepsakeCard(for reward: RewardItem) -> some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    PixelAssetImage(name: assetName(for: reward.type))
                        .frame(width: 64, height: 64)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(reward.family.title.uppercased())
                            .font(pixelFont(.caption))
                            .foregroundStyle(reward.isDemoReward ? AppColors.amber : AppColors.grass)
                        Text(reward.title)
                            .font(pixelFont(.body))
                        Text(reward.earnedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.muted)
                    }

                    Spacer(minLength: 0)
                }

                Text(reward.description)
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.secondaryText)

                if let context = reward.context {
                    Divider()
                    Label(context.bookendSummary, systemImage: "moon.stars.fill")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.secondaryText)

                    if let activitySummary = context.activitySummary {
                        Label(activitySummary, systemImage: "leaf.fill")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.secondaryText)
                    }

                    if context.protectedNightNumber > 0 {
                        Text("Protected night \(context.protectedNightNumber)")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.muted)
                    }
                } else {
                    Text("\(reward.runDurationMinutes) recorded minutes")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.muted)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func assetName(for type: RewardType) -> String {
        switch type {
        case .ollieMail: return "RewardOllieMail"
        case .letter: return "RewardLetter"
        case .ribbon: return "RewardRibbon"
        case .trophy: return "RewardTrophy"
        case .tennisBall: return "RewardTennisBall"
        case .stick: return "RewardStick"
        case .postcard: return "RewardPostcard"
        case .sheepBadge: return "RewardSheepBadge"
        case .fieldMap: return "RewardFieldMap"
        case .muddyPaw: return "RewardMuddyPaw"
        }
    }
}

#Preview("Keepsake shelf") {
    NavigationStack {
        RewardShelfContent(
            rewards: [
                RewardItem(
                    id: UUID(),
                    type: .tennisBall,
                    rarity: .common,
                    title: "Tiny Tennis Ball",
                    description: "A bright ball from the quiet side of the pasture.",
                    earnedAt: Date(),
                    runDurationMinutes: 60,
                    isDemoReward: false,
                    context: RewardContext(
                        windDownMinutes: 30,
                        morningQuietMinutes: 30,
                        eveningActivity: .read,
                        morningActivity: .openCurtains,
                        protectedNightNumber: 2
                    )
                ),
                RewardItem(
                    id: UUID(),
                    type: .ribbon,
                    rarity: .uncommon,
                    title: "First Protected Night",
                    description: "A ribbon for keeping both edges of the night quiet.",
                    earnedAt: Date().addingTimeInterval(-86_400),
                    runDurationMinutes: 45,
                    isDemoReward: false,
                    context: RewardContext(
                        windDownMinutes: 15,
                        morningQuietMinutes: 30,
                        eveningActivity: .journal,
                        morningActivity: .breakfast,
                        protectedNightNumber: 1
                    )
                )
            ]
        )
        .navigationTitle("Ollie's Keepsakes")
    }
}

#Preview("Empty keepsake shelf") {
    NavigationStack {
        RewardShelfContent(rewards: [])
            .navigationTitle("Ollie's Keepsakes")
    }
}
