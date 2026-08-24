import SwiftUI

struct FirstRunContinueCard: View {
    var title = FirstRunGuideCopy.continueCardTitle
    var detail = FirstRunGuideCopy.continueCardDetail
    let onResume: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(title)
                    .font(AppTypography.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppSpacing.sm) {
                        Button(FirstRunGuideCopy.continueCardResume, action: onResume)
                            .buttonStyle(PixelChipButtonStyle(isSelected: true))
                            .frame(minWidth: 124, minHeight: 44)
                        Button(FirstRunGuideCopy.continueCardDismiss, action: onDismiss)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                            .frame(minHeight: 44)
                    }
                    VStack(spacing: AppSpacing.xs) {
                        Button(FirstRunGuideCopy.continueCardResume, action: onResume)
                            .buttonStyle(PixelChipButtonStyle(isSelected: true))
                            .frame(maxWidth: .infinity, minHeight: 48)
                        Button(FirstRunGuideCopy.continueCardDismiss, action: onDismiss)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
        .accessibilityAction(.default, onResume)
    }
}

struct CountingSheepPracticeOfferSheet: View {
    let onStartPractice: () -> Void
    let onSkip: () -> Void
    let onMaybeLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Label("A SHORT PRACTICE", systemImage: "timer")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(FirstRunGuideCopy.practiceOfferTitle)
                    .font(AppTypography.title)
                    .fixedSize(horizontal: false, vertical: true)
                Text(FirstRunGuideCopy.message(for: .practiceOffer))
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onStartPractice) {
                Label(FirstRunGuideCopy.practiceStart, systemImage: "timer")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PixelPrimaryButtonStyle())

            Button(FirstRunGuideCopy.skipForNow, action: onSkip)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.ink)
                .frame(maxWidth: .infinity, minHeight: 44)

            Button(FirstRunGuideCopy.doThisLater, action: onMaybeLater)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.muted)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .foregroundStyle(AppColors.ink)
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppColors.paper.ignoresSafeArea())
        .accessibilityElement(children: .contain)
    }
}

struct FirstRunPracticeRewardCard: View {
    var grantedNewSheep: Bool = true
    let onSeeFarm: () -> Void
    let onSkip: () -> Void

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(FirstRunGuideCopy.practiceGiftEyebrow)
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text(FirstRunGuideCopy.practiceGiftTitle(grantedNewSheep: grantedNewSheep))
                    .font(AppTypography.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(
                    grantedNewSheep
                        ? FirstRunGuideCopy.message(for: .practiceReward)
                        : "The five-minute introduction is in Nights. It is not a protected night."
                )
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button(
                    grantedNewSheep ? FirstRunGuideCopy.practiceGiftSeeFarm : "See the Farm",
                    action: onSeeFarm
                )
                    .buttonStyle(PixelChipButtonStyle(isSelected: true))
                    .frame(minHeight: 44)
                Button(FirstRunGuideCopy.skipForNow, action: onSkip)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                    .frame(minHeight: 44)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(FirstRunGuideCopy.practiceGiftTitle(grantedNewSheep: grantedNewSheep))
    }
}

struct FirstRunFarmTourOfferCard: View {
    let onShow: () -> Void
    let onExplore: () -> Void

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("AROUND THE FARM")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("Want the four-tip Farm tour?")
                    .font(AppTypography.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Meet the flock, The Barn, the wardrobe, and Ollie’s Search.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppSpacing.sm) {
                        Button("Show me", action: onShow)
                            .buttonStyle(PixelChipButtonStyle(isSelected: true))
                        Button("Explore on my own", action: onExplore)
                            .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    }
                    VStack(spacing: AppSpacing.xs) {
                        Button("Show me", action: onShow)
                            .buttonStyle(PixelPrimaryButtonStyle())
                        Button("Explore on my own", action: onExplore)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct FirstRunHomeChapterHandoffCard: View {
    let onExplore: () -> Void
    let onPractice: () -> Void

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("HOME BASICS COMPLETE")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("That’s the four basics. Have a look around.")
                    .font(AppTypography.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text("The Farm tour will wait until you choose to explore it.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppSpacing.sm) {
                        Button("Explore", action: onExplore)
                            .buttonStyle(PixelChipButtonStyle(isSelected: true))
                        Button("Try a 5-minute practice", action: onPractice)
                            .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    }
                    VStack(spacing: AppSpacing.xs) {
                        Button("Explore", action: onExplore)
                            .buttonStyle(PixelPrimaryButtonStyle())
                        Button("Try a 5-minute practice", action: onPractice)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct FirstRunSlumberPartyIntroCard: View {
    let isAvailable: Bool
    let onCreate: () -> Void
    let onJoin: () -> Void
    let onLater: () -> Void

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(FirstRunGuideCopy.title(for: .slumberParty))
                    .font(AppTypography.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(
                    isAvailable
                        ? FirstRunGuideCopy.message(for: .slumberParty)
                        : FirstRunGuideCopy.slumberPartyUnavailable
                )
                .font(AppTypography.body)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

                if isAvailable {
                    Button(FirstRunGuideCopy.slumberPartyCreate, action: onCreate)
                        .buttonStyle(PixelChipButtonStyle(isSelected: true))
                        .frame(minHeight: 44)
                    Button(FirstRunGuideCopy.slumberPartyJoin, action: onJoin)
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                        .frame(minHeight: 44)
                }
                Button(
                    isAvailable ? FirstRunGuideCopy.slumberPartyLater : "Continue",
                    action: onLater
                )
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
                .frame(minHeight: 44)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct OrientationRecordPrompt: View {
    let onSeeNights: () -> Void

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Label("YOUR PRACTICE RECORD", systemImage: "book.closed.fill")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("Five minutes of quiet, recorded plainly.")
                    .font(AppTypography.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text("It appears in Nights. Completing it can bring a welcome gift sheep home, without counting as a Wind Down.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button("See it in Nights", action: onSeeNights)
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    .frame(minHeight: 44, alignment: .leading)
            }
        }
    }
}

#Preview("Continue card") {
    FirstRunContinueCard(onResume: {}, onDismiss: {})
        .padding()
        .background(AppColors.paper)
}

#Preview("Practice offer") {
    CountingSheepPracticeOfferSheet(onStartPractice: {}, onSkip: {}, onMaybeLater: {})
}

#Preview("Practice reward") {
    FirstRunPracticeRewardCard(onSeeFarm: {}, onSkip: {})
        .padding()
        .background(AppColors.paper)
}

#Preview("Practice reward · already granted") {
    FirstRunPracticeRewardCard(grantedNewSheep: false, onSeeFarm: {}, onSkip: {})
        .padding()
        .background(AppColors.paper)
}

#Preview("Farm tour offer · compact") {
    FirstRunFarmTourOfferCard(onShow: {}, onExplore: {})
        .padding()
        .background(AppColors.paper)
        .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Slumber Party intro") {
    FirstRunSlumberPartyIntroCard(isAvailable: true, onCreate: {}, onJoin: {}, onLater: {})
        .padding()
        .background(AppColors.paper)
}

#Preview("Slumber Party unavailable · dark") {
    FirstRunSlumberPartyIntroCard(isAvailable: false, onCreate: {}, onJoin: {}, onLater: {})
        .padding()
        .background(AppColors.paper)
        .preferredColorScheme(.dark)
}
