import SwiftUI

struct SlumberPartyV4MemberCard: View {
    let member: NightFlockV4Membership
    let isYou: Bool
    let liveStatus: NightFlockV4LiveStatus?
    var onBlock: (() -> Void)? = nil
    var onReport: ((NightFlockReportReason) -> Void)? = nil
    var liveCheerCount: Int = 0
    var onLiveCheer: ((NightFlockV4Cheer) -> Void)? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(alignment: .top, spacing: AppSpacing.xs) {
                    memberHeader
                    Spacer(minLength: 0)
                    if !isYou, onBlock != nil || onReport != nil {
                        memberSafetyMenu
                    }
                }
                Text(liveStatus.map(liveStatusTitle) ?? "No live update right now")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                if liveCheerCount > 0 {
                    Text(liveCheerCount == 1 ? "1 quiet cheer" : "\(liveCheerCount) quiet cheers")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                }
                if !isYou, canSendLiveCheer, let onLiveCheer {
                    liveCheerMenu(onLiveCheer)
                }
                curatedProfileSnapshot(member.profile.presentation)
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var memberHeader: some View {
        if dynamicTypeSize > .large {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                memberName
                memberBadges
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                memberName
                memberBadges
            }
        }
    }

    private var memberName: some View {
        Text(member.profile.displayName.isEmpty ? "A group member" : member.profile.displayName)
            .font(AppTypography.headline)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var memberBadges: some View {
        HStack(spacing: AppSpacing.xs) {
            if isYou { memberBadge("You") }
            if member.role == .host { memberBadge("Host") }
        }
    }

    private var memberSafetyMenu: some View {
        Menu {
            if let onReport {
                Menu("Report member") {
                    ForEach(NightFlockReportReason.allCases) { reason in
                        Button(reason.title) {
                            onReport(reason)
                        }
                    }
                }
            }
            if let onBlock {
                Button("Block member", role: .destructive) {
                    onBlock()
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Safety options for \(member.profile.displayName)")
    }

    private var canSendLiveCheer: Bool {
        guard let liveStatus else { return false }
        return liveStatus.status == .windDownStarting || liveStatus.status == .phoneAwayActive
    }

    private func liveCheerMenu(_ onLiveCheer: @escaping (NightFlockV4Cheer) -> Void) -> some View {
        Menu {
            ForEach(NightFlockV4Cheer.allCases, id: \.self) { cheer in
                Button(liveCheerTitle(cheer)) {
                    onLiveCheer(cheer)
                }
            }
        } label: {
            Label("Send a quiet cheer", systemImage: "hand.wave")
                .font(AppTypography.caption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .accessibilityHint("Sends a silent note to this person’s Live Activity or Watch.")
    }

    private func liveCheerTitle(_ cheer: NightFlockV4Cheer) -> String {
        switch cheer {
        case .warmWave: "Warm wave"
        case .moonGlow: "Moon glow"
        case .pawPrint: "Paw print"
        }
    }

    @ViewBuilder
    private func curatedProfileSnapshot(_ presentation: CountingSheepPublicPresentation) -> some View {
        if let snapshot = safeSnapshot(for: presentation) {
            Group {
                if dynamicTypeSize > .large {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        snapshotArtwork(snapshot)
                        snapshotDescription(snapshot)
                    }
                } else {
                    HStack(alignment: .center, spacing: AppSpacing.sm) {
                        snapshotArtwork(snapshot)
                        snapshotDescription(snapshot)
                    }
                }
            }
            .padding(AppSpacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(snapshot.themeColor, in: RoundedRectangle(cornerRadius: AppRadius.md))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(snapshot.accessibilityLabel)
        } else {
            Text("A simple Farm look is waiting to travel safely.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
        }
    }

    private func snapshotArtwork(_ snapshot: CuratedProfileSnapshot) -> some View {
        HStack(spacing: AppSpacing.xs) {
            ShepherdAvatarView(profile: snapshot.shepherd, size: 54)
                .accessibilityHidden(true)
            OllieFarmAvatar(accessoryItemID: snapshot.ollieAccessoryID, size: 52)
                .accessibilityHidden(true)
            if let sheep = snapshot.featuredSheep {
                PixelAssetImage(name: sheep.assetName)
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)
            }
        }
    }

    private func snapshotDescription(_ snapshot: CuratedProfileSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(snapshot.featuredSheep.map { "Featured \($0.name)" } ?? "No featured sheep")
            Text(snapshot.themeTitle)
        }
        .font(AppTypography.caption)
        .foregroundStyle(AppColors.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func memberBadge(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.caption.weight(.semibold))
            .foregroundStyle(AppColors.grass)
    }

    private func liveStatusTitle(_ status: NightFlockV4LiveStatus) -> String {
        switch status.status {
        case .windDownStarting: return "Starting Wind Down"
        case .phoneAwayActive: return "Phone Away is underway"
        case .windDownCompleted: return "Wind Down completed"
        case .phoneAwayCompleted: return "Phone Away completed"
        }
    }

    private func safeSnapshot(
        for presentation: CountingSheepPublicPresentation
    ) -> CuratedProfileSnapshot? {
        guard presentation.isAllowlisted(),
              let skinTone = ShepherdSkinTone(rawValue: presentation.skinToneID),
              let hairStyle = ShepherdHairStyle(rawValue: presentation.hairStyleID)
        else { return nil }
        let outfitID = presentation.shepherdOutfitID == "none" ? nil : presentation.shepherdOutfitID
        let accessoryID = presentation.shepherdAccessoryID == "none" ? nil : presentation.shepherdAccessoryID
        let ollieAccessoryID = presentation.ollieOrnamentID == "none" ? nil : presentation.ollieOrnamentID
        let featuredSheep = presentation.featuredSheepDefinitionID == "none"
            ? nil
            : SheepCatalog.definition(for: presentation.featuredSheepDefinitionID)
        return CuratedProfileSnapshot(
            shepherd: ShepherdProfile(
                skinTone: skinTone,
                hairStyle: hairStyle,
                outfitItemID: outfitID,
                accessoryItemID: accessoryID
            ),
            ollieAccessoryID: ollieAccessoryID,
            featuredSheep: featuredSheep,
            pastureThemeID: presentation.pastureThemeID
        )
    }
}

private struct CuratedProfileSnapshot {
    let shepherd: ShepherdProfile
    let ollieAccessoryID: String?
    let featuredSheep: SheepDefinition?
    let pastureThemeID: String

    var themeColor: Color {
        switch pastureThemeID {
        case "pasture_moonlit": return AppColors.lavender.opacity(0.16)
        case "pasture_sunrise": return AppColors.amber.opacity(0.16)
        default: return AppColors.grass.opacity(0.13)
        }
    }

    var themeTitle: String {
        switch pastureThemeID {
        case "pasture_moonlit": return "Moonlit pasture"
        case "pasture_sunrise": return "Sunrise pasture"
        default: return "Meadow pasture"
        }
    }

    var accessibilityLabel: String {
        let sheep = featuredSheep.map { "Featured sheep \($0.name)." } ?? "No featured sheep."
        return "Curated Farm look. \(themeTitle). \(sheep)"
    }
}
