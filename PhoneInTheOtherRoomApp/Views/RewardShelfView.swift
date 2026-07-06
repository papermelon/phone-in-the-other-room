import SwiftUI

struct RewardShelfView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    var body: some View {
        ScrollView {
            if viewModel.coordinator.rewards.isEmpty {
                emptyShelf
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    ForEach(viewModel.coordinator.rewards) { reward in
                        PixelCard {
                            HStack(spacing: 12) {
                                Image(assetName(for: reward.type))
                                    .resizable()
                                    .interpolation(.none)
                                    .scaledToFit()
                                    .frame(width: 48, height: 48)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(reward.title)
                                        .font(pixelFont(.caption))
                                    Text(reward.rarity.rawValue.capitalized)
                                        .font(PixelTypography.title(.caption2))
                                        .foregroundStyle(reward.isDemoReward ? AppColors.amber : AppColors.grass)
                                    Text(reward.earnedAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(PixelTypography.title(.caption2))
                                        .foregroundStyle(AppColors.muted)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Reward Shelf")
    }

    private var emptyShelf: some View {
        PixelCard {
            VStack(spacing: 12) {
                Image(systemName: "archivebox")
                    .font(.system(size: 44, weight: .black))
                    .foregroundStyle(AppColors.muted)
                Text("Ollie has not brought anything back yet.")
                    .font(PixelTypography.title(.subheadline))
                    .multilineTextAlignment(.center)
                Text("Complete a Focus Run to start your collection.")
                    .font(PixelTypography.title(.caption))
                    .foregroundStyle(AppColors.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
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
