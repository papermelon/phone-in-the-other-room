import SwiftUI

struct CompletionView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    private var minutes: Int { viewModel.activeRun?.creditedQuietMinutes ?? 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PixelCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 14) {
                            OllieRitualView(state: .completed)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("A PROTECTED NIGHT")
                                    .font(pixelFont(.caption))
                                    .foregroundStyle(AppColors.grass)
                                Text("You woke up before your phone did.")
                                    .font(pixelFont(.title2))
                                Text("You kept \(minutes) minutes phone-free around sleep.")
                                    .font(pixelFont(.body))
                                    .foregroundStyle(AppColors.secondaryText)
                            }
                        }
                    }
                }

                if let plan = viewModel.activeRun?.nightWatchPlan {
                    PixelCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("LAST NIGHT'S QUIET TIME")
                                .font(pixelFont(.caption))
                                .foregroundStyle(AppColors.grass)
                            quietTimeRow(
                                icon: "moon.zzz.fill",
                                title: "Wind-down",
                                value: "\(viewModel.activeRun?.creditedWindDownMinutes ?? 0) min",
                                detail: plan.eveningActivity.shortTitle
                            )
                            quietTimeRow(
                                icon: "sun.max.fill",
                                title: "After waking",
                                value: "\(viewModel.activeRun?.creditedMorningQuietMinutes ?? 0) min",
                                detail: plan.morningActivity.shortTitle
                            )
                        }
                    }
                }

                NightWatchReceiptCard(
                    run: viewModel.activeRun,
                    sleepSummary: viewModel.lastNightSleep,
                    sleepAuthorization: viewModel.sleepAuthorization,
                    screenTimeAuthorization: viewModel.screenTimeAuthorization
                )

                if let reward = viewModel.coordinator.latestReward {
                    PixelCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 14) {
                                PixelAssetImage(name: artworkName(for: reward.type))
                                    .frame(width: 68, height: 68)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(reward.family.title.uppercased())
                                        .font(pixelFont(.caption))
                                        .foregroundStyle(AppColors.grass)
                                    Text(reward.title)
                                        .font(pixelFont(.title3))
                                    Text(reward.description)
                                        .font(pixelFont(.body))
                                        .foregroundStyle(AppColors.secondaryText)
                                }
                            }

                            if let context = reward.context {
                                Divider()
                                Label(context.bookendSummary, systemImage: "moon.stars.fill")
                                    .font(pixelFont(.caption))
                                    .foregroundStyle(AppColors.secondaryText)
                            }
                        }
                    }
                }

                PixelCard {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("WHAT THE QUIET HELD")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.grass)
                        Text(viewModel.offlinePurpose.completionPhrase)
                            .font(pixelFont(.body))
                        if let reflection = viewModel.coordinator.latestReward?.gentleReflection {
                            Text(reflection)
                                .font(pixelFont(.caption))
                                .foregroundStyle(AppColors.secondaryText)
                        }
                        Text("A quiet record, not a sleep score.")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }

                NavigationLink {
                    RewardShelfView()
                        .environmentObject(viewModel)
                } label: {
                    Label("See Ollie's keepsake shelf", systemImage: "shippingbox.fill")
                }
                .buttonStyle(PixelChipButtonStyle(isSelected: false))

                NavigationLink("See your nights") {
                    FocusStatsView()
                        .environmentObject(viewModel)
                }
                .buttonStyle(PixelChipButtonStyle(isSelected: false))

                Button("Done for now") { viewModel.resetSetup() }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(PixelPrimaryButtonStyle())
            }
            .padding(16)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .onAppear(perform: viewModel.refreshSleepSummary)
    }

    private func quietTimeRow(icon: String, title: String, value: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.grass)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(pixelFont(.body))
                Text(detail)
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.secondaryText)
            }
            Spacer()
            Text(value)
                .font(pixelFont(.caption))
        }
    }

    private func artworkName(for type: RewardType) -> String {
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
