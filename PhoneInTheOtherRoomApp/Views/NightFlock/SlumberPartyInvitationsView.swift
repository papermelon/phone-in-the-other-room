import SwiftUI

struct SlumberPartyInvitationInbox: View {
    @ObservedObject var social: NightFlockViewModel
    @State private var reviewing: SlumberPartyInvitation?

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Text("INVITATIONS").font(pixelFont(.caption)).foregroundStyle(AppColors.grass)
                    Spacer()
                    Button { Task { await social.updatePartyConnections(.init(action: "state")) } } label: {
                        Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
                    }.accessibilityLabel("Refresh invitations").disabled(social.partyConnectionsBusy)
                }
                if social.partyConnectionsBusy { SheepLoadingView("Checking invitations…") }
                if let error = social.partyConnectionsError {
                    Text(error).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                } else if let connections = social.partyConnections,
                          !connections.invitations.contains(where: \.isIncoming) {
                    Text("Invitations from people you know will appear here.")
                        .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                }
                ForEach(social.partyConnections?.invitations.filter(\.isIncoming) ?? []) { invitation in
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(invitation.partyName).font(AppTypography.headline)
                        Text("From \(invitation.senderName)").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                        Button("Review invitation") { reviewing = invitation }
                            .buttonStyle(PixelPrimaryButtonStyle()).disabled(social.partyConnectionsBusy)
                    }
                }
                if let connections = social.partyConnections {
                    DisclosureGroup("Your handle and user ID") {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            if let handle = connections.handle { Text("@\(handle)").font(AppTypography.body) }
                            Text(connections.userID.uuidString.lowercased()).font(AppTypography.caption).textSelection(.enabled)
                            Text("Someone who knows your exact handle or user ID can invite you. Joining always needs your agreement.")
                                .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                            ShareLink(item: connections.handle.map { "@\($0)" } ?? connections.userID.uuidString.lowercased()) {
                                Label("Share my ID", systemImage: "square.and.arrow.up").frame(minHeight: 44)
                            }
                        }.padding(.top, AppSpacing.xs)
                    }.font(AppTypography.caption).tint(AppColors.grass)
                }
            }
        }
        .task { await social.updatePartyConnections(.init(action: "state")) }
        .sheet(item: $reviewing) { invitation in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text(invitation.partyName).font(AppTypography.title)
                        Text("\(invitation.senderName) invited you to wind down together.").font(AppTypography.body)
                        SlumberPartySharedHabitsConsentDisclosure(partyName: invitation.partyName,
                            includesSharedNightPlans: social.supportsSharedNightPlans, actionLead: "Joining shares",
                            includesSharedHabits: social.supportsSharedHabits,
                            includesChosenCharacter: social.v4ListState?.supportsProfileAvatar == true)
                        Text("Joining accepts this party’s terms of agreement.").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                        if social.v4Acquisition.isBusy { SheepLoadingView("Joining the party…") }
                        if let error = social.partyConnectionsError { Text(error).font(AppTypography.caption) }
                        if case .error(let message) = social.phase { Text(message).font(AppTypography.caption) }
                        Button("Join & agree") { social.acceptPartyInvitation(invitation) }
                            .buttonStyle(PixelPrimaryButtonStyle())
                            .disabled(social.v4Acquisition.isBusy || social.partyConnectionsBusy || !social.canCreateOrJoinAnotherParty)
                        if !social.canCreateOrJoinAnotherParty {
                            Text("You’re already in five parties. Leave one before joining another.").font(AppTypography.caption)
                        }
                        Button("Decline invitation") {
                            Task {
                                if await social.updatePartyConnections(.init(action: "decline", invitationID: invitation.id)) != nil { reviewing = nil }
                            }
                        }.buttonStyle(PixelChipButtonStyle(isSelected: false))
                            .disabled(social.v4Acquisition.isBusy || social.partyConnectionsBusy)
                    }.padding(AppSpacing.md)
                }.background(AppColors.paper).navigationTitle("Party invitation").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { reviewing = nil } } }
            }
        }
        .onChange(of: social.v4Acquisition.acceptedPartyID) { _, id in if id != nil { reviewing = nil } }
    }
}

struct SlumberPartyInvitePeopleView: View {
    @ObservedObject var social: NightFlockViewModel
    let partyID: UUID
    @State private var query = ""
    @State private var searchedQuery: String?
    @State private var person: SlumberPartyPerson?
    @FocusState private var searchFocused: Bool

    init(social: NightFlockViewModel, partyID: UUID, initialPerson: SlumberPartyPerson? = nil) {
        self.social = social
        self.partyID = partyID
        _person = State(initialValue: initialPerson)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Bring someone to your party").font(AppTypography.title)
                Text("Search their exact handle or user ID. They’ll review the party’s agreement before joining.")
                    .font(AppTypography.body).foregroundStyle(AppColors.secondaryText)
                TextField("@handle or user ID", text: $query)
                    .textFieldStyle(PixelTextFieldStyle()).font(AppTypography.body)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search)
                    .focused($searchFocused).onSubmit(search)
                    .accessibilityLabel("Search by exact handle or user ID")
                Button("Search", action: search).buttonStyle(PixelChipButtonStyle(isSelected: false))
                    .disabled(social.partyConnectionsBusy || SlumberPartyInvitationSearch.normalized(query) == nil)
                if social.partyConnectionsBusy { SheepLoadingView("Checking your invitations…") }
                if let error = social.partyConnectionsError {
                    Text(error).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                }
                if let person {
                    PixelCard {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text(person.name).font(AppTypography.headline)
                            if let handle = person.handle { Text("@\(handle)").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText) }
                            if person.isMember {
                                Label("Already in your party", systemImage: "checkmark.circle.fill").font(AppTypography.body)
                            } else if person.isInvited {
                                Label("Invited · waiting for their reply", systemImage: "envelope.badge").font(AppTypography.body)
                            } else {
                                Button("Send invitation") {
                                    Task {
                                        if await social.updatePartyConnections(.init(action: "invite", partyID: partyID, userID: person.userID)) != nil {
                                            self.person?.isInvited = true
                                        }
                                    }
                                }.buttonStyle(PixelPrimaryButtonStyle()).disabled(social.partyConnectionsBusy)
                            }
                        }
                    }
                } else if searchedQuery != nil && !social.partyConnectionsBusy && social.partyConnectionsError == nil {
                    Text("No matching Shepherd. Check the full handle or user ID with your friend.")
                        .font(AppTypography.body).foregroundStyle(AppColors.secondaryText)
                }
                let pending = social.partyConnections?.invitations.filter { $0.partyID == partyID && !$0.isIncoming } ?? []
                if !pending.isEmpty {
                    Text("WAITING FOR A REPLY").font(pixelFont(.caption)).foregroundStyle(AppColors.grass)
                    ForEach(pending) { invitation in
                        PixelCard {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text(invitation.recipientName).font(AppTypography.headline)
                                Text("Invited · expires \(invitation.expiresAt, style: .date)").font(AppTypography.caption)
                                if invitation.canRevoke {
                                    Button("Cancel invitation") {
                                        Task {
                                            if await social.updatePartyConnections(.init(action: "revoke", invitationID: invitation.id)) != nil,
                                               person?.userID == invitation.recipientID { person?.isInvited = false }
                                        }
                                    }.buttonStyle(PixelChipButtonStyle(isSelected: false)).disabled(social.partyConnectionsBusy)
                                }
                            }
                        }
                    }
                }
                Button("Refresh invitations") { Task { await social.updatePartyConnections(.init(action: "state", partyID: partyID)) } }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false)).disabled(social.partyConnectionsBusy)
            }.padding(AppSpacing.md)
        }.background(AppColors.paper).navigationTitle("Invite people").navigationBarTitleDisplayMode(.inline)
            .task { await social.updatePartyConnections(.init(action: "state", partyID: partyID)) }
            .onChange(of: query) { _, _ in person = nil; searchedQuery = nil }
    }

    private func search() {
        guard let normalized = SlumberPartyInvitationSearch.normalized(query), !social.partyConnectionsBusy else { return }
        searchFocused = false
        person = nil
        searchedQuery = normalized
        Task {
            let result = await social.updatePartyConnections(.init(action: "search", partyID: partyID, query: normalized))
            guard SlumberPartyInvitationSearch.normalized(query) == normalized else { return }
            person = result?.person
        }
    }
}

#Preview("Invitations · empty") {
    SlumberPartyInvitationInbox(social: NightFlockViewModel(featureEnabled: false, previewPhase: .ready))
        .padding().background(AppColors.paper)
}
#Preview("Invite people · large text") {
    NavigationStack {
        SlumberPartyInvitePeopleView(social: NightFlockViewModel(featureEnabled: false, previewPhase: .ready), partyID: UUID())
    }.environment(\.dynamicTypeSize, .accessibility3)
}
