import SwiftUI

struct AssetPlaceholderView: View {
    var assetName: String
    var label: String
    var systemImage: String = "photo"
    var tint: Color = AppColors.grass
    var aspectRatio: CGFloat = 1

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.22), AppColors.surfaceMuted],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.ink.opacity(0.24), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))

            VStack(spacing: AppSpacing.xs) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(tint)
                Text(label)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
                Text(assetName)
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(AppColors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            .padding(AppSpacing.sm)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .accessibilityLabel("\(label), placeholder for \(assetName)")
    }
}

// Mock-data-backed sprite/card components below are DEBUG-only with the gated
// MVP screens (ADR-0003). Release code uses PixelAssetImage + real models instead.
#if DEBUG

struct DogSpriteView: View {
    var state: MockDogState = MVPMockData.dog
    var mood: OllieMood? = nil
    var size: CGFloat = 132
    var showAssetName = true

    private var displayedMood: OllieMood { mood ?? state.mood }

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            ZStack {
                Ellipse()
                    .fill(AppColors.grass.opacity(0.22))
                    .frame(width: size * 0.86, height: size * 0.28)
                    .offset(y: size * 0.38)

                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(AppColors.bark)
                    .frame(width: size * 0.52, height: size * 0.68)
                    .offset(y: size * 0.10)

                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(.white)
                    .frame(width: size * 0.28, height: size * 0.62)
                    .offset(y: size * 0.10)

                Triangle()
                    .fill(AppColors.bark.opacity(0.88))
                    .frame(width: size * 0.20, height: size * 0.28)
                    .rotationEffect(.degrees(-20))
                    .offset(x: -size * 0.28, y: -size * 0.25)

                Triangle()
                    .fill(AppColors.bark.opacity(0.88))
                    .frame(width: size * 0.20, height: size * 0.28)
                    .rotationEffect(.degrees(20))
                    .offset(x: size * 0.28, y: -size * 0.25)

                eye(x: -size * 0.11)
                eye(x: size * 0.11)

                Capsule()
                    .fill(AppColors.ink)
                    .frame(width: size * 0.13, height: size * 0.08)
                    .offset(y: size * 0.10)

                moodMark
            }
            .frame(width: size, height: size)

            if showAssetName {
                Text(state.assetName)
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(AppColors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
        }
    }

    private func eye(x: CGFloat) -> some View {
        Circle()
            .fill(AppColors.ink)
            .frame(width: size * 0.07, height: size * 0.07)
            .offset(x: x, y: -size * 0.05)
    }

    @ViewBuilder
    private var moodMark: some View {
        switch displayedMood {
        case .excited, .happy, .proud:
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.18, weight: .black))
                .foregroundStyle(AppColors.amber)
                .offset(x: size * 0.34, y: -size * 0.34)
        case .sleepy:
            Text("Z")
                .font(.system(size: size * 0.18, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.lavender)
                .offset(x: size * 0.35, y: -size * 0.36)
        case .alert, .sad:
            Text("!")
                .font(.system(size: size * 0.22, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.warning)
                .offset(x: size * 0.35, y: -size * 0.36)
        default:
            EmptyView()
        }
    }
}

struct SheepSpriteView: View {
    var sheep: MockSheep
    var size: CGFloat = 74

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(sheep.isUnlocked ? sheep.rarity.color.opacity(0.35) : AppColors.surfaceMuted)
                    .frame(width: size, height: size)
                sheepBody
                    .opacity(sheep.isUnlocked ? 1 : 0.35)
                if !sheep.isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.headline.weight(.black))
                        .foregroundStyle(AppColors.secondaryText)
                        .offset(x: size * 0.28, y: -size * 0.28)
                }
            }
            Text(sheep.assetName)
                .font(AppTypography.monoCaption)
                .foregroundStyle(AppColors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
    }

    private var sheepBody: some View {
        ZStack {
            Image(systemName: "cloud.fill")
                .font(.system(size: size * 0.50, weight: .black))
                .foregroundStyle(sheep.rarity == .legendary ? AppColors.amber : .white)
            Circle()
                .fill(sheep.rarity == .uncommon ? AppColors.ink : Color(red: 0.25, green: 0.22, blue: 0.18))
                .frame(width: size * 0.22, height: size * 0.22)
                .offset(x: size * 0.18, y: size * 0.02)
            HStack(spacing: size * 0.16) {
                Capsule().fill(AppColors.ink).frame(width: size * 0.07, height: size * 0.20)
                Capsule().fill(AppColors.ink).frame(width: size * 0.07, height: size * 0.20)
            }
            .offset(y: size * 0.30)
        }
    }
}

struct MissionCard: View {
    var mission: MockMission

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: mission.icon)
                    .font(.title3.weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(AppColors.grass, in: RoundedRectangle(cornerRadius: AppRadius.md))
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(mission.title)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.ink)
                    Text(mission.detail)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
                Spacer()
                Text(mission.cadence)
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(AppColors.grass)
            }
            ProgressBar(progress: mission.progress, tint: mission.isClaimable ? AppColors.amber : AppColors.grass)
            HStack {
                Text(mission.progressLabel)
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(AppColors.secondaryText)
                Spacer()
                Label(mission.reward, systemImage: mission.isClaimable ? "gift.fill" : "lock.open")
                    .font(AppTypography.caption)
                    .foregroundStyle(mission.isClaimable ? AppColors.amber : AppColors.ink)
            }
        }
        .assetReadyCard()
    }
}

struct RewardCard: View {
    var reward: MockReward

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            AssetPlaceholderView(assetName: reward.assetName, label: reward.title, systemImage: reward.icon, tint: reward.rarity.color, aspectRatio: 1.25)
            Text(reward.title)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.ink)
            Text(reward.detail)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
            Text(reward.rarity.rawValue)
                .font(AppTypography.monoCaption)
                .foregroundStyle(AppColors.ink)
                .padding(.horizontal, AppSpacing.xs)
                .padding(.vertical, AppSpacing.xxs)
                .background(reward.rarity.color.opacity(0.45), in: RoundedRectangle(cornerRadius: AppRadius.sm))
        }
        .assetReadyCard()
    }
}

#endif

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 12
    var tint: Color = AppColors.grass
    var label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColors.surfaceMuted, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(label)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.ink)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 88, height: 88)
    }
}

struct ProgressBar: View {
    var progress: Double
    var tint: Color = AppColors.grass

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: AppRadius.xs)
                    .fill(AppColors.surfaceMuted)
                RoundedRectangle(cornerRadius: AppRadius.xs)
                    .fill(tint)
                    .frame(width: proxy.size.width * min(1, max(0, progress)))
            }
        }
        .frame(height: 12)
    }
}

#if DEBUG

struct FarmTileView: View {
    var unlock: MockFarmUnlock

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            AssetPlaceholderView(assetName: unlock.assetName, label: unlock.title, systemImage: unlock.icon, tint: unlock.isUnlocked ? AppColors.grass : AppColors.secondaryText, aspectRatio: 1.15)
            Text(unlock.title)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.ink)
            Text(unlock.detail)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
            Text(unlock.isUnlocked ? "Unlocked" : unlock.cost)
                .font(AppTypography.monoCaption)
                .foregroundStyle(unlock.isUnlocked ? AppColors.success : AppColors.clay)
        }
        .assetReadyCard()
    }
}

struct StatsCard: View {
    var statistic: MockScreenTimeStatistic

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: statistic.icon)
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(AppColors.grass, in: RoundedRectangle(cornerRadius: AppRadius.md))
                Spacer()
                Text(statistic.value)
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.ink)
                    .minimumScaleFactor(0.72)
            }
            Text(statistic.title)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.ink)
            Text(statistic.detail)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
            ProgressBar(progress: statistic.progress, tint: AppColors.amber)
        }
        .assetReadyCard()
    }
}

struct FocusSessionCard: View {
    var session: MockFocusSession

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            ProgressRing(progress: Double(session.completedMinutes) / Double(max(1, session.plannedMinutes)), label: "\(session.completedMinutes)m")
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(session.title)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.ink)
                Text("\(session.focusType) - \(session.dateLabel)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                Text(session.rewardSummary)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.grass)
                Text(session.outcome)
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(session.outcome == "Completed" ? AppColors.success : AppColors.warning)
            }
            Spacer()
        }
        .assetReadyCard()
    }
}

#endif

extension View {
    func assetReadyCard() -> some View {
        self
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(AppColors.ink.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: AppShadows.cardColor, radius: AppShadows.cardRadius, x: 0, y: AppShadows.cardY)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

