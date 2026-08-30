import SwiftUI
import UIKit

/// Administrative and identity choices live away from the active party feed.
/// The screen exposes only controls already supported by the current party
/// contract; it does not imply new leader powers or sharing behavior.
struct SlumberPartyV4GroupDetailsView: View {
    @ObservedObject var viewModel: NightFlockViewModel
    private let initialParty: NightFlockV4PartyDetail
    @EnvironmentObject private var appViewModel: FocusRunViewModel
    @State private var newName = ""
    @State private var copiedCodeNotice: String?
    @State private var showsLeaveConfirmation = false
    @State private var showsDeleteConfirmation = false
    @State private var showsSharedHistoryDeletionConfirmation = false
    @Environment(\.dismiss) private var dismiss

    init(viewModel: NightFlockViewModel, party: NightFlockV4PartyDetail) {
        self.viewModel = viewModel
        initialParty = party
    }

    private var party: NightFlockV4PartyDetail {
        viewModel.v4ObservedPartyDetail(for: initialParty.summary.partyID) ?? initialParty
    }

    private var actionIsInFlight: Bool {
        viewModel.isRefreshingV4Party(party.summary.partyID) || viewModel.phase == .loading
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("GROUP DETAILS")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(party.summary.name)
                        .font(AppTypography.display(30))
                    Text("\(party.memberships.count) \(party.memberships.count == 1 ? "person" : "people") in this invited group.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                }

                statusNotice
                identitySection
                peopleSection
                invitationSection
                managementSection
                if party.summary.myRole != .host, viewModel.supportsSharedHabits {
                    sharedHabitsPrivacySection
                }
            }
            .padding(AppSpacing.md)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Group details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { newName = party.summary.name }
        .onChange(of: party.summary.name) { _, name in
            newName = name
        }
        .onChange(of: viewModel.v4ListState?.parties) { _, parties in
            guard let parties,
                  !parties.contains(where: { $0.partyID == initialParty.summary.partyID })
            else { return }
            dismiss()
        }
        .confirmationDialog("Leave this Slumber Party?", isPresented: $showsLeaveConfirmation) {
            Button("Leave group", role: .destructive) {
                guard !actionIsInFlight else { return }
                viewModel.leaveSlumberParty(party.summary.partyID)
            }
        } message: {
            Text("Your local Wind Down and Farm will stay on this iPhone.")
        }
        .confirmationDialog("Leave and remove your shared history?", isPresented: $showsSharedHistoryDeletionConfirmation) {
            Button("Leave and remove my history", role: .destructive) {
                guard !actionIsInFlight, viewModel.supportsSharedHabits else { return }
                viewModel.withdrawSharedHabitsAndLeave(party.summary.partyID)
            }
        } message: {
            Text("Your device stops sharing and hides this party immediately. Removing your retained summaries waits for the group service; local Wind Down and Farm data remain on this iPhone.")
        }
        .confirmationDialog("Dissolve this Slumber Party and leave?", isPresented: $showsDeleteConfirmation) {
            Button("Dissolve party and leave", role: .destructive) {
                guard !actionIsInFlight else { return }
                viewModel.deleteSlumberParty(party.summary.partyID)
            }
        } message: {
            Text("This removes the group archive for its members and leaves it. Your local Wind Down and Farm will stay on this iPhone.")
        }
    }

    @ViewBuilder
    private var statusNotice: some View {
        if actionIsInFlight {
            Text("Updating group details…")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
        }
        if case let .error(message) = viewModel.phase {
            SlumberPartyV4UnavailableCard(
                title: "One group update needs another try.",
                detail: message,
                requestID: viewModel.v4RequestID ?? viewModel.requestReference
            )
        }
    }

    private var identitySection: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("YOUR GROUP IDENTITY")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                HStack(spacing: AppSpacing.sm) {
                    SlumberPartySocialAvatarView(
                        presentation: appViewModel.userProfile.presentation,
                        avatarID: appViewModel.selectedSocialAvatarID,
                        size: 60
                    )
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(SlumberPartySocialAvatarView.title(for: appViewModel.selectedSocialAvatarID))
                            .font(AppTypography.headline)
                        Text("One identity across your Slumber Parties.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    Spacer(minLength: AppSpacing.xs)
                }
                identityAvailabilityNote
                NavigationLink {
                    SlumberPartySocialAvatarPicker(
                        presentation: appViewModel.userProfile.presentation,
                        initialAvatarID: appViewModel.selectedSocialAvatarID
                    )
                } label: {
                    Label("Choose group identity", systemImage: "person.crop.circle")
                        .font(AppTypography.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
            }
        }
    }

    @ViewBuilder
    private var identityAvailabilityNote: some View {
        if let syncMessage = appViewModel.socialAvatarSyncMessage {
            Text(syncMessage)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        } else if !appViewModel.socialAvatarSharingAvailable {
            Text("Group service does not yet acknowledge identity changes. Your local choice is shown here; members keep the current shared identity.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("PEOPLE")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            ForEach(party.memberships) { member in
                PixelCard {
                    HStack(spacing: AppSpacing.sm) {
                        SlumberPartySocialAvatarView(
                            presentation: member.profile.presentation,
                            avatarID: member.profile.presentation.avatarID,
                            size: 52
                        )
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text(member.profile.displayName.isEmpty ? "A group member" : member.profile.displayName)
                                .font(AppTypography.body.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(member.memberID == party.myMemberID
                                ? "You\(member.role == .host ? " · Host" : "")"
                                : (member.role == .host ? "Host" : "Member"))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.secondaryText)
                        }
                        Spacer(minLength: AppSpacing.sm)
                    }
                    .frame(minHeight: 52, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var invitationSection: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("INVITATION")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                invitationContent
                if let copiedCodeNotice {
                    Text(copiedCodeNotice)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
        }
    }

    @ViewBuilder
    private var invitationContent: some View {
        if let code = viewModel.v4InviteCode, party.invitation?.status == .active {
            Text(displayInvitationCode(code))
                .font(AppTypography.headline.monospaced())
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .accessibilityLabel("Invitation code \(code)")
            invitationActions(code: code)
        } else if party.invitation?.status == .active {
            Text("An invitation is active for this group.")
                .font(AppTypography.body)
            Button("Show active code") {
                viewModel.retrieveSlumberPartyInvite(party.summary.partyID)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(PixelChipButtonStyle(isSelected: false))
            .disabled(actionIsInFlight)
        } else if party.summary.myRole == .host {
            Text("Invite people you know when you’re ready.")
                .font(AppTypography.body)
            Button("Create invitation") {
                viewModel.createSlumberPartyInvite(party.summary.partyID)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(PixelPrimaryButtonStyle())
            .disabled(actionIsInFlight)
        } else {
            Text("The host has not shared an active invitation right now.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
        }
    }

    private func invitationActions(code: String) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Button("Copy code") {
                UIPasteboard.general.string = code
                copiedCodeNotice = "Invitation code copied."
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(PixelChipButtonStyle(isSelected: false))
            ShareLink(item: code, subject: Text("Slumber Party invitation")) {
                Label("Share code", systemImage: "square.and.arrow.up")
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(PixelChipButtonStyle(isSelected: false))
            if party.summary.myRole == .host, let invitation = party.invitation {
                Button("Replace code") {
                viewModel.replaceSlumberPartyInvite(
                        party.summary.partyID,
                        expectedInviteID: invitation.inviteID
                    )
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
                .disabled(actionIsInFlight)
                Button("Revoke code") {
                    viewModel.revokeSlumberPartyInvite(
                        party.summary.partyID,
                        inviteID: invitation.inviteID
                    )
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
                .disabled(actionIsInFlight)
            }
        }
    }

    private var sharedHabitsPrivacySection: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("SHARED HABITS & PRIVACY")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("Leaving stops new sharing and access. Earlier agreed summaries stay with this party for its lifetime unless you remove your own retained history or the host dissolves the group.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Leave and remove my shared history", role: .destructive) {
                    showsSharedHistoryDeletionConfirmation = true
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
                .disabled(actionIsInFlight)
            }
        }
    }

    private var managementSection: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("GROUP MANAGEMENT")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                if party.summary.myRole == .host {
                    TextField("Party name", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .font(AppTypography.body)
                        .frame(minHeight: 44)
                    Button("Save party name") {
                        viewModel.renameSlumberParty(party.summary.partyID, name: newName)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    .disabled(actionIsInFlight)
                    Button("Dissolve party and leave", role: .destructive) {
                        showsDeleteConfirmation = true
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    .disabled(actionIsInFlight)
                } else {
                    Button("Leave party", role: .destructive) {
                        showsLeaveConfirmation = true
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    .disabled(actionIsInFlight)
                }
            }
        }
    }

    private func displayInvitationCode(_ code: String) -> String {
        code.enumerated().reduce(into: "") { formatted, item in
            if item.offset > 0, item.offset.isMultiple(of: 4) {
                formatted.append(" ")
            }
            formatted.append(item.element)
        }
    }
}

#Preview("Group details · legacy identity") {
    let party = SlumberPartyV4GroupDetailsPreviewData.party
    NavigationStack {
        SlumberPartyV4GroupDetailsView(
            viewModel: SlumberPartyV4GroupDetailsPreviewData.model(for: party),
            party: party
        )
        .environmentObject(FocusRunViewModel(startsExternalServices: false))
    }
}

#Preview("Group details · accessibility") {
    let party = SlumberPartyV4GroupDetailsPreviewData.party
    NavigationStack {
        SlumberPartyV4GroupDetailsView(
            viewModel: SlumberPartyV4GroupDetailsPreviewData.model(for: party),
            party: party
        )
        .environmentObject(FocusRunViewModel(startsExternalServices: false))
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

@MainActor
private enum SlumberPartyV4GroupDetailsPreviewData {
    static func model(for party: NightFlockV4PartyDetail) -> NightFlockViewModel {
        let model = NightFlockViewModel(
            featureEnabled: true,
            previewPhase: .ready,
            previewAccountState: .linked
        )
#if DEBUG
        model.installV4ObservedPartyPreview(party)
#endif
        return model
    }

    static var party: NightFlockV4PartyDetail {
        let partyID = UUID()
        let hostID = UUID()
        let memberID = UUID()
        let summary = NightFlockV4PartySummary(
            partyID: partyID,
            name: "Moonlit Neighbours",
            memberCount: 2,
            myRole: .host,
            currentRound: nil,
            revision: 1
        )
        return NightFlockV4PartyDetail(
            summary: summary,
            myMemberID: hostID,
            memberships: [
                NightFlockV4Membership(
                    memberID: hostID,
                    profile: CountingSheepUserProfile(displayName: "Clover"),
                    role: .host,
                    joinedAt: .now
                ),
                NightFlockV4Membership(
                    memberID: memberID,
                    profile: CountingSheepUserProfile(displayName: "Moss"),
                    role: .member,
                    joinedAt: .now
                )
            ]
        )
    }
}
