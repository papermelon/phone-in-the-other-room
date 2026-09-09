import SwiftUI

/// Stable slots share one approved meadow; no physics or motion can move a person's target.
struct SlumberPartySharedFarmView: View {
    let party: NightFlockV4PartyDetail
    var showsSocialAvatar: Bool
    var selectedMemberID: UUID? = nil
    var onSelect: (UUID) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var members: [NightFlockV4Membership] { SlumberPartySharedFarmRules.members(in: party) }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("OUR FARM")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            Text("Familiar faces, shared moments")
                .font(AppTypography.headline)
            Text("Tap a friend to open their latest shared update and leave a quiet cheer.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm),
                                     count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: AppSpacing.lg) {
                ForEach(members) { member in
                    Button { onSelect(member.memberID) } label: {
                        VStack(spacing: AppSpacing.xxs) {
                            SlumberPartySocialAvatarView(presentation: member.profile.presentation,
                                avatarID: showsSocialAvatar ? member.profile.presentation.avatarID : "shepherd",
                                size: 112, showsBackdrop: false)
                            Text(member.profile.displayName + (member.memberID == party.myMemberID ? " · You" : ""))
                                .font(AppTypography.body.weight(.semibold))
                                .foregroundStyle(AppColors.ink)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, AppSpacing.xs)
                                .background(AppColors.paper.opacity(0.94), in: RoundedRectangle(cornerRadius: AppRadius.sm))
                        }
                        .frame(maxWidth: .infinity, minHeight: 156)
                        .contentShape(Rectangle())
                        .overlay {
                            if selectedMemberID == member.memberID {
                                RoundedRectangle(cornerRadius: AppRadius.md).stroke(AppColors.grass, lineWidth: 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityValue(selectedMemberID == member.memberID ? "Selected" : "")
                    .accessibilityLabel("\(member.profile.displayName), \(SlumberPartySocialAvatarView.title(for: showsSocialAvatar ? member.profile.presentation.avatarID : "shepherd"))")
                    .accessibilityHint("Opens their latest shared update and cheers")
                }
            }
            .padding(AppSpacing.md)
            .background {
                GeometryReader { proxy in
                    PixelAssetImage(name: AssetSlot.Farm.backgroundDay, contentMode: .fill)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .overlay(AppColors.paper.opacity(colorScheme == .dark ? 0.45 : 0))
                        .accessibilityHidden(true)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            DisclosureGroup("Members as a list") {
                ForEach(members) { member in
                    Button { onSelect(member.memberID) } label: {
                        HStack {
                            Text(member.profile.displayName).font(AppTypography.body)
                            Spacer(minLength: AppSpacing.sm)
                            Image(systemName: "chevron.right").accessibilityHidden(true)
                        }
                        .frame(minHeight: 48)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens their latest shared update and cheers")
                }
            }
            .font(AppTypography.body)
            .tint(AppColors.grass)
        }
    }
}

struct SlumberPartyMemberUpdatesView: View {
    @ObservedObject var viewModel: NightFlockViewModel
    let partyID: UUID
    let memberID: UUID
    var showsSocialAvatar: Bool
    var initialActivityID: UUID? = nil
    @Environment(\.dismiss) private var dismiss

    private var party: NightFlockV4PartyDetail? { viewModel.v4ObservedPartyDetail(for: partyID) }
    private var member: NightFlockV4Membership? { party?.memberships.first { $0.memberID == memberID } }

    private var isStale: Bool {
        if viewModel.partyRefreshFailures[partyID] != nil { return true }
        if case .current = viewModel.v4ObservedPartyObservationState(for: partyID) { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    if let party, let member {
                        SlumberPartySocialAvatarView(presentation: member.profile.presentation,
                            avatarID: showsSocialAvatar ? member.profile.presentation.avatarID : "shepherd", size: 112)
                            .frame(maxWidth: .infinity)
                        appearanceNote(member.profile.presentation)
                        if isStale {
                            Text("Showing the last update received. Connect and refresh to check for newer moments.")
                                .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                            Button("Refresh updates") { viewModel.selectSlumberParty(partyID) }
                                .buttonStyle(PixelChipButtonStyle(isSelected: false))
                        }
                        let updates = SlumberPartySharedFarmRules.updates(for: memberID, in: party)
                        if updates.isEmpty {
                            SlumberPartyV4UnavailableCard(title: "No shared update yet",
                                detail: "There isn’t an eligible update here for \(member.profile.displayName). Missing updates don’t tell us whether someone took part.")
                        } else {
                            let chosen = updates.first { $0.id == initialActivityID } ?? updates[0]
                            let earlier = updates.filter { $0.id != chosen.id }
                            Text(initialActivityID == nil ? "Latest shared update" : "Shared update")
                                .font(AppTypography.headline)
                            updateSection(updates: [chosen], party: party)
                            if updates.count > 1 {
                                DisclosureGroup("Earlier shared updates (\(updates.count - 1))") {
                                    updateSection(updates: earlier, party: party)
                                }.font(AppTypography.body)
                            }
                        }
                    } else {
                        SlumberPartyV4UnavailableCard(title: "This member is unavailable",
                            detail: "The party’s membership may have changed. Return to the group to refresh.")
                    }
                }
                .padding(AppSpacing.md)
            }
            .background(AppColors.paper.ignoresSafeArea())
            .navigationTitle(member?.profile.displayName ?? "Shared updates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    @ViewBuilder private func appearanceNote(_ appearance: CountingSheepPublicPresentation) -> some View {
        if !SocialAvatarRules.isKnownWireAvatar(appearance.avatarID) || !appearance.isAllowlisted()
            || (appearance.headShapeID.map { ShepherdHeadShape(rawValue: $0) == nil } ?? false) {
            Text("Some appearance details aren’t supported by this app. A familiar fallback is shown.")
                .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
        } else if appearance.headShapeID == nil && (!showsSocialAvatar || appearance.avatarID == "shepherd") {
            Text("Head shape hasn’t been shared. The default shape is shown.")
                .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
        }
    }

    private func updateSection(updates: [NightFlockV4SharedActivity], party: NightFlockV4PartyDetail) -> some View {
        let ids = Set(updates.map(\.activityID))
        let sharedIDs = Set((party.sharedActivities + party.memberUpdates).map(\.activityID))
        return SlumberPartyV4MembershipActivitiesSection(viewModel: viewModel, party: party,
            membershipActivities: updates.filter { sharedIDs.contains($0.activityID) },
            legacyRoundActivities: party.activities.filter { ids.contains($0.activityID) && !sharedIDs.contains($0.activityID) },
            compact: true)
    }
}

#Preview("Shared Farm · two identities") {
    SlumberPartySharedFarmView(party: SlumberPartySharedFarmFixtures.party, showsSocialAvatar: true, onSelect: { _ in })
        .padding().background(AppColors.paper)
}
#Preview("Shared Farm · large text") {
    ScrollView { SlumberPartySharedFarmView(party: SlumberPartySharedFarmFixtures.party, showsSocialAvatar: true, onSelect: { _ in }).padding() }
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Member update unavailable") {
    SlumberPartyMemberUpdatesView(viewModel: NightFlockViewModel(featureEnabled: false),
        partyID: UUID(), memberID: UUID(), showsSocialAvatar: false)
}
