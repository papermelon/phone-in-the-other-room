import SwiftUI

struct SlumberPartyV4Header: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("PRIVATE · INVITE-ONLY")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            Text("Give your phones some time away — together.")
                .font(AppTypography.title)
                .fixedSize(horizontal: false, vertical: true)
            Text("A private group for family, a partner, or close friends. Share small moments together; seven-night rounds organize progress and rewards.")
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
    private enum AcquisitionEntry: Hashable {
        case create
        case join
    }

    @ObservedObject var viewModel: NightFlockViewModel
    @EnvironmentObject private var appViewModel: FocusRunViewModel
    @State private var groupName = ""
    @State private var invitationCode = ""
    @State private var previewedInvitationCode = ""
    @State private var shepherdNameDraft = ""
    @State private var shepherdNameFeedback: String?
    @State private var showsAccountDeletionConfirmation = false
    @State private var formerPartyAwaitingHistoryDeletion: NightFlockRetainedSharedHabitParty?
    @State private var acquisitionEntry: AcquisitionEntry?
    @FocusState private var groupNameFocused: Bool
    @FocusState private var invitationCodeFocused: Bool

    init(viewModel: NightFlockViewModel, initialAcquisition: String? = nil) {
        self.viewModel = viewModel
        switch initialAcquisition {
        case "create":
            _acquisitionEntry = State(initialValue: .create)
        case "join":
            _acquisitionEntry = State(initialValue: .join)
        default:
            _acquisitionEntry = State(initialValue: nil)
        }
    }

    private var isAtPartyLimit: Bool {
        !viewModel.canCreateOrJoinAnotherParty
    }

    private var hasShepherdName: Bool {
        appViewModel.userProfile.hasEstablishedDisplayName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            SlumberPartyV4Header()
            if let notice = viewModel.sharedHabitsPrivacyNotice {
                SlumberPartyV4UnavailableCard(
                    title: "A privacy change is still pending.",
                    detail: notice,
                    requestID: viewModel.v4RequestID ?? viewModel.requestReference
                )
                Button("Retry privacy change") { viewModel.retrySharedHabitsPrivacyAction() }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
            }
            if !viewModel.slumberParties.isEmpty {
                listHeader
                Text("Your invited groups stay together between each set of 7 nights.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
                emptyState
            } else {
                ForEach(viewModel.slumberParties) { party in
                    NavigationLink {
                        SlumberPartyV4PartyDetailView(viewModel: viewModel, summary: party)
                    } label: {
                        SlumberPartyV4PartyCard(summary: party)
                    }
                    .buttonStyle(.plain)
                }
                acquisitionDisclosure
            }
            accountCard
        }
        .task {
            _ = await viewModel.refreshState(showLoading: false)
        }
        .onAppear {
            consumePreferredEntry()
            viewModel.refreshSharedHabitsFormerParties()
        }
        .confirmationDialog("Remove retained shared history?", isPresented: Binding(
            get: { formerPartyAwaitingHistoryDeletion != nil },
            set: { if !$0 { formerPartyAwaitingHistoryDeletion = nil } }
        )) {
            Button("Remove my retained history", role: .destructive) {
                guard viewModel.supportsSharedHabits,
                      let formerPartyAwaitingHistoryDeletion
                else { return }
                viewModel.deleteRetainedSharedHabitsHistory(partyID: formerPartyAwaitingHistoryDeletion.partyID)
                self.formerPartyAwaitingHistoryDeletion = nil
            }
        } message: {
            Text("This asks the group service to delete your retained shared-habits contributions. It does not restore access to the party or change your local Wind Down and Farm.")
        }
        .confirmationDialog("Delete your online account?", isPresented: $showsAccountDeletionConfirmation) {
            Button("Delete online account", role: .destructive) {
                viewModel.deleteOnlineAccount()
            }
        } message: {
            Text("Your hosted groups will close and you will leave other groups. Your local Wind Down and Farm stay on this iPhone.")
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Start with people you trust.")
                        .font(AppTypography.headline)
                    Text("Each person uses their own Wind Down or Phone Away. Shared moments appear only inside the party.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button("Start a party") {
                acquisitionEntry = .create
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(PixelPrimaryButtonStyle())
            Button("Join with a code") {
                acquisitionEntry = .join
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(PixelChipButtonStyle(isSelected: false))
            if acquisitionEntry == .create {
                createCard
            } else if acquisitionEntry == .join {
                joinCard
            }
        }
    }

    private var acquisitionDisclosure: some View {
        PixelCard {
            DisclosureGroup("Start or join another", isExpanded: Binding(
                get: { acquisitionEntry != nil },
                set: { expanded in
                    if !expanded { acquisitionEntry = nil }
                    else if acquisitionEntry == nil { acquisitionEntry = .create }
                }
            )) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Picker("Party action", selection: Binding(
                        get: { acquisitionEntry ?? .create },
                        set: { acquisitionEntry = $0 }
                    )) {
                        Text("Start a party").tag(AcquisitionEntry.create)
                        Text("Join with a code").tag(AcquisitionEntry.join)
                    }
                    .pickerStyle(.segmented)
                    if acquisitionEntry == .create {
                        createCard
                    } else {
                        joinCard
                    }
                }
                .padding(.top, AppSpacing.sm)
            }
            .font(AppTypography.body)
        }
    }

    private func consumePreferredEntry() {
        guard viewModel.prefersJoinEntry else { return }
        acquisitionEntry = .join
        viewModel.prefersJoinEntry = false
    }

    private var listHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("YOUR SLUMBER PARTIES")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("Up to \(NightFlockV4Rules.maximumConcurrentParties) groups can keep their own seven-night windows.")
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
                Text("START A PARTY")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("Name your group.")
                    .font(AppTypography.headline)
                TextField("Party name", text: $groupName)
                    .font(AppTypography.body)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($groupNameFocused)
                    .frame(minHeight: 44)
                    .accessibilityHint("Only the group name is needed to create an invite-only Slumber Party.")
                if viewModel.supportsSharedHabits {
                    SlumberPartySharedHabitsConsentDisclosure(
                        partyName: groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "this new Slumber Party"
                            : groupName.trimmingCharacters(in: .whitespacesAndNewlines),
                        includesSharedNightPlans: viewModel.supportsSharedNightPlans
                    )
                }
                if isAtPartyLimit {
                    Text("You’re already in five Slumber Parties. Leave one before starting or joining another.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button(viewModel.supportsSharedHabits ? "Create & agree" : "Create party") {
                    viewModel.createSlumberParty(named: groupName)
                    groupNameFocused = false
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(PixelPrimaryButtonStyle())
                .disabled(!hasShepherdName || isAtPartyLimit || groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                Text("JOIN WITH A CODE")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("Use a code from someone you know.")
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
                    Text("You’re already in five Slumber Parties. Leave one before starting or joining another.")
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
            Text(viewModel.supportsSharedNightPlans
                ? "Joining shares rounded Wind Down and Phone Away updates, your curated Farm look, and—after the v2 agreement—your bounded next-seven-night plan. Your recurrence rule and selected apps stay private."
                : "Joining lets this group see shared Wind Down and Phone Away updates, rounded minutes, and your curated Farm look. Your schedule and selected apps stay private.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if viewModel.supportsSharedHabits {
                SlumberPartySharedHabitsConsentDisclosure(
                    partyName: preview.name,
                    includesSharedNightPlans: viewModel.supportsSharedNightPlans
                )
            }
            Button("Join this party") {
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
                    if viewModel.supportsSharedHabits,
                       !viewModel.retainedSharedHabitParties.isEmpty {
                        Text("Former party shared history")
                            .font(AppTypography.caption.weight(.semibold))
                        Text("You can ask to remove your retained shared-habits contributions without rejoining a party.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(viewModel.retainedSharedHabitParties) { formerParty in
                            Button("Remove history from \(formerParty.partyName)", role: .destructive) {
                                formerPartyAwaitingHistoryDeletion = formerParty
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .buttonStyle(PixelChipButtonStyle(isSelected: false))
                        }
                    }
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
        let presentation = NightFlockV4PartyCardPresentation.make(from: summary)
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
                    Text("\(presentation.roleTitle) · \(presentation.memberCountTitle)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                    Text(presentation.stateTitle)
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
