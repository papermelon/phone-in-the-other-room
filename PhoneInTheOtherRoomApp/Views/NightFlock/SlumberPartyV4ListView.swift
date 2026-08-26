import SwiftUI

struct SlumberPartyV4Header: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("INVITE-ONLY · SEVEN NIGHTS")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            Text("Put phones away together")
                .font(AppTypography.title)
                .fixedSize(horizontal: false, vertical: true)
            Text("Create a group, invite your people, and see how everyone is putting their phone away.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SlumberPartyV4UnavailableCard: View {
    let title: String
    let detail: String
    var requestID: String? = nil

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Label(title, systemImage: "moon.stars.fill")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.ink)
                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let requestID, !requestID.isEmpty {
                    DisclosureGroup("Support details") {
                        Text(requestID)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                            .textSelection(.enabled)
                    }
                    .font(AppTypography.caption)
                }
            }
        }
    }
}

struct SlumberPartyV4ListView: View {
    @ObservedObject var viewModel: NightFlockViewModel
    @EnvironmentObject private var appViewModel: FocusRunViewModel
    @State private var groupName = ""
    @State private var invitationCode = ""
    @State private var previewedInvitationCode = ""
    @State private var shepherdNameDraft = ""
    @State private var shepherdNameFeedback: String?
    @State private var showsAccountDeletionConfirmation = false
    @FocusState private var groupNameFocused: Bool
    @FocusState private var invitationCodeFocused: Bool

    private var isAtPartyLimit: Bool {
        !viewModel.canCreateOrJoinAnotherParty
    }

    private var hasShepherdName: Bool {
        appViewModel.userProfile.hasEstablishedDisplayName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            listHeader
            if !hasShepherdName {
                ShepherdNameCard(
                    profile: appViewModel.userProfile,
                    draftName: $shepherdNameDraft,
                    feedback: $shepherdNameFeedback,
                    onSave: { appViewModel.saveShepherdDisplayName($0) }
                )
            }
            if case let .error(message) = viewModel.phase {
                SlumberPartyV4UnavailableCard(
                    title: "One Slumber Party update needs another try.",
                    detail: message,
                    requestID: viewModel.v4RequestID ?? viewModel.requestReference
                )
            }
            if let warmNotice = viewModel.warmNotice {
                NightFlockStatusCard(
                    symbol: "pawprint.fill",
                    title: "A note from Ollie",
                    detail: warmNotice
                )
            }
            if viewModel.slumberParties.isEmpty {
                SlumberPartyV4UnavailableCard(
                    title: "No Slumber Parties yet.",
                    detail: "Start one for people you know, or join with an invitation code."
                )
            } else {
                ForEach(viewModel.slumberParties) { party in
                    NavigationLink {
                        SlumberPartyV4PartyDetailView(viewModel: viewModel, summary: party)
                    } label: {
                        SlumberPartyV4PartyCard(summary: party)
                    }
                    .buttonStyle(.plain)
                }
            }
            createCard
            joinCard
            accountCard
        }
        .task {
            _ = await viewModel.refreshState(showLoading: false)
        }
        .confirmationDialog("Delete your online account?", isPresented: $showsAccountDeletionConfirmation) {
            Button("Delete online account", role: .destructive) {
                viewModel.deleteOnlineAccount()
            }
        } message: {
            Text("Your hosted groups will close and you will leave other groups. Your local Wind Down and Farm stay on this iPhone.")
        }
    }

    private var listHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("YOUR SLUMBER PARTIES")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("Up to \(NightFlockV4Rules.maximumConcurrentParties) groups can keep their own seven-night rounds.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button {
                Task { await viewModel.refreshState(showLoading: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.body.weight(.bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PixelChipButtonStyle(isSelected: false))
            .accessibilityLabel("Refresh Slumber Parties")
        }
    }

    private var createCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("CREATE A SLUMBER PARTY")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("Give your group a name.")
                    .font(AppTypography.headline)
                TextField("Group name", text: $groupName)
                    .font(AppTypography.body)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($groupNameFocused)
                    .frame(minHeight: 44)
                    .accessibilityHint("Only the group name is needed to create an invite-only Slumber Party.")
                if isAtPartyLimit {
                    Text("Your five Slumber Party places are full. Leave a group before starting or joining another.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button("Create group") {
                    viewModel.createSlumberParty(named: groupName)
                    groupNameFocused = false
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(PixelPrimaryButtonStyle())
                .disabled(
                    !hasShepherdName || isAtPartyLimit
                        || groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
    }

    private var joinCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("JOIN A SLUMBER PARTY")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("Use an invitation code from someone you know.")
                    .font(AppTypography.headline)
                TextField("Invitation code", text: $invitationCode)
                    .font(AppTypography.body)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($invitationCodeFocused)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Slumber Party invitation code")
                if isAtPartyLimit {
                    Text("Your five Slumber Party places are full. Leave a group before joining another.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button("Preview invitation") {
                    previewedInvitationCode = NightFlockInviteCode.normalize(invitationCode)
                    viewModel.previewSlumberPartyInvite(code: invitationCode)
                    invitationCodeFocused = false
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
                .disabled(
                    !hasShepherdName || isAtPartyLimit
                        || NightFlockInviteCode.normalize(invitationCode).isEmpty
                )
                if let preview = viewModel.v4InvitePreview,
                   previewedInvitationCode == NightFlockInviteCode.normalize(invitationCode) {
                    invitationPreview(preview)
                }
            }
        }
    }

    private func invitationPreview(_ preview: NightFlockV4InvitePreview) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(preview.name)
                .font(AppTypography.headline)
            Text("\(preview.memberCount) of \(preview.capacity) places are filled.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
            Button("Join this group") {
                viewModel.redeemSlumberPartyInvite(code: invitationCode)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(PixelPrimaryButtonStyle())
        }
        .padding(.top, AppSpacing.xs)
    }

    private var accountCard: some View {
        PixelCard {
            DisclosureGroup("Account and safety") {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Your Wind Down and Farm stay on this iPhone if you delete your online account.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Delete online account", role: .destructive) {
                        showsAccountDeletionConfirmation = true
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                }
                .padding(.top, AppSpacing.sm)
            }
            .font(AppTypography.body)
        }
    }
}

struct SlumberPartyV4PartyCard: View {
    let summary: NightFlockV4PartySummary

    var body: some View {
        PixelCard {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: "person.3.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppColors.lavender)
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(summary.name)
                        .font(AppTypography.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(roleTitle(summary.myRole)) · \(memberCountTitle(summary.memberCount))")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                    Text(roundTitle(summary.currentRound))
                        .font(AppTypography.caption.weight(.semibold))
                        .foregroundStyle(AppColors.ink)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.muted)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
        }
        .accessibilityHint("Opens this Slumber Party")
    }

    private func roleTitle(_ role: NightFlockV4Role) -> String {
        role == .host ? "You’re the host" : "Member"
    }

    private func memberCountTitle(_ count: Int) -> String {
        count == 1 ? "1 person" : "\(count) people"
    }

    private func roundTitle(_ round: NightFlockV4Round?) -> String {
        guard let round else { return "Ready for the next seven nights" }
        switch round.status {
        case .pending: return "Round \(round.number) is ready to begin"
        case .active:
            let day = NightFlockV4RoundRules.day(at: Date(), round: round) ?? 7
            return "Round \(round.number) · Day \(day) of 7"
        case .completed: return "Round \(round.number) is complete"
        }
    }
}

#Preview("Slumber Party v4 list card · accessibility · iPhone 12", traits: .fixedLayout(width: 390, height: 844)) {
    SlumberPartyV4PartyCard(
        summary: NightFlockV4PartySummary(
            partyID: UUID(),
            name: "Moonlit Neighbours",
            memberCount: 4,
            myRole: .host,
            currentRound: nil,
            revision: 1
        )
    )
    .padding()
    .background(AppColors.paper)
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Slumber Party v4 list card · dark") {
    SlumberPartyV4PartyCard(
        summary: NightFlockV4PartySummary(
            partyID: UUID(),
            name: "A Very Long Name For Our Little Nighttime Group",
            memberCount: 5,
            myRole: .member,
            currentRound: nil,
            revision: 1
        )
    )
    .padding()
    .background(AppColors.paper)
    .preferredColorScheme(.dark)
}
