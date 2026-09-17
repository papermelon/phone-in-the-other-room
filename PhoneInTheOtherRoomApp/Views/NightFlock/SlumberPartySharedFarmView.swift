import SwiftUI

/// The release Farm and its accessible member list open the same update sheet.
struct SlumberPartySharedFarmView: View {
    let party: NightFlockV4PartyDetail
    var showsSocialAvatar: Bool
    var selectedMemberID: UUID? = nil
    var onSelect: (UUID) -> Void

    var body: some View {
        SlumberPartyPastureView(party: party, onSelect: onSelect)
    }
}

struct SlumberPartyMemberUpdatesView: View {
    @ObservedObject var viewModel: NightFlockViewModel
    let partyID: UUID
    let memberID: UUID
    var showsSocialAvatar: Bool
    var initialActivityID: UUID? = nil
    var memberContext: AnyView? = nil
    @Environment(\.dismiss) private var dismiss

    private var party: NightFlockV4PartyDetail? { viewModel.v4ObservedPartyDetail(for: partyID) }
    private var member: NightFlockV4Membership? { party?.memberships.first { $0.memberID == memberID } }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isStale: Bool {
        viewModel.partyRefreshFailures[partyID] != nil
            || viewModel.v4ObservedPartyObservationState(for: partyID).showsConnectionWarning
    }

    private var isRefreshing: Bool {
        if case .refreshing = viewModel.v4ObservedPartyObservationState(for: partyID) { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    if let party, let member {
                        if let memberContext { memberContext } else {
                        SlumberPartySocialAvatarView(presentation: member.profile.presentation,
                            avatarID: "shepherd", size: 112)
                            .frame(maxWidth: .infinity)
                            .overlay(alignment: .topTrailing) {
                                Group {
                                    if reduceMotion { Image(systemName: "arrow.clockwise") }
                                    else { ProgressView() }
                                }
                                .frame(width: 24, height: 24)
                                .opacity(isRefreshing ? 1 : 0)
                                .accessibilityLabel("Updating shared moments")
                                .accessibilityHidden(!isRefreshing)
                            }
                        }
                        appearanceNote(member.profile.presentation)
                        if isStale {
                            Text("Couldn’t check for newer moments. Your last received update is shown.")
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    @ViewBuilder private func appearanceNote(_ appearance: CountingSheepPublicPresentation) -> some View {
        if !SocialAvatarRules.isKnownWireAvatar(appearance.avatarID) || !appearance.isAllowlisted()
            || (appearance.headShapeID.map { ShepherdHeadShape(rawValue: $0) == nil } ?? false) {
            Text("Some appearance details aren’t supported by this app. A familiar fallback is shown.")
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
