import SwiftUI

struct SocialInboxButton: View {
    @ObservedObject var social: NightFlockViewModel
    var partyID: UUID? = nil
    var openParty: ((UUID) -> Void)? = nil
    @State private var showing = false
    var body: some View {
        Button { showing = true } label: {
            Label(partyID == nil ? (social.socialUnreadCount > 0 ? "Inbox · \(social.socialUnreadCount) new" : "Inbox") : "For you · Invitations & cheers", systemImage: "tray")
                .font(AppTypography.body).frame(minHeight: 44)
        }
        .buttonStyle(PixelChipButtonStyle(isSelected: social.socialUnreadCount > 0))
        .sheet(isPresented: $showing) {
            NavigationStack {
                SocialInboxView(social: social, partyID: partyID) { id in showing = false; openParty?(id) }
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showing = false } } }
            }
        }
    }
}

struct SocialInboxView: View {
    @ObservedObject var social: NightFlockViewModel
    var partyID: UUID? = nil
    var openParty: ((UUID) -> Void)? = nil
    @State private var filter = "All"
    @State private var selected: SocialInboxEvent?
    @State private var preferencesOpen = false
    @State private var routedInvitation: UUID?
    private var events: [SocialInboxEvent] {
        social.socialInboxEvents.filter { event in
            (partyID == nil || event.partyID == partyID) && event.kind != "invitation"
                && (filter == "All" || (filter == "Cheers" ? event.kind == "cheer" : event.kind == "joined"))
        }
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.md) {
                Picker("Inbox filter", selection: $filter) {
                    ForEach(["All", "Invitations", "Cheers"], id: \.self) { Text($0) }
                }.pickerStyle(.segmented)
                if filter != "Cheers" { SlumberPartyInvitationInbox(social: social, initialInvitationID: routedInvitation) }
                if social.socialInboxLoading && social.socialInboxEvents.isEmpty { SheepLoadingView("Opening your inbox…") }
                if let error = social.socialInboxError {
                    Text(error).font(AppTypography.body)
                    Button("Try again") { Task { await social.refreshSocialInbox() } }.frame(minHeight: 44)
                }
                if events.isEmpty && !social.socialInboxLoading && filter != "Invitations" {
                    PixelCard {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("A place for a little encouragement").font(AppTypography.headline)
                            Text("Cheers from your parties and the Global Campfire will appear here. You can return to them even with notifications off.")
                                .font(AppTypography.body).foregroundStyle(AppColors.secondaryText)
                        }
                    }
                }
                ForEach(SocialInboxGroup.grouped(events)) { group in
                    let event = group.presentation
                    Button { selected = event; Task { await social.markSocialEventsRead(group.events.map(\.id)) } } label: {
                        PixelCard {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                HStack(alignment: .top) {
                                    Text(event.title).font(AppTypography.headline)
                                    Spacer()
                                    if !event.isRead { Text("New").font(AppTypography.caption).foregroundStyle(AppColors.grass) }
                                }
                                Text([event.context, event.partyName ?? "Global Campfire"].joined(separator: " · "))
                                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                                Text("Received \(event.arrivedAt.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))")
                                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                            }.frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(.leading)
                        }
                    }.buttonStyle(.plain).accessibilityHint("Opens the original shared moment")
                }
                if social.socialInboxCursor != nil {
                    Button("Earlier messages") { Task { await social.refreshSocialInbox(nextPage: true) } }
                        .frame(minHeight: 44).disabled(social.socialInboxLoading)
                }
                Button("Notification choices") { preferencesOpen = true }.frame(minHeight: 44)
                Text("Available messages stay here for up to 30 days. Campfire sessions have a shorter history; withdrawn sharing disappears.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            }.padding(AppSpacing.md)
        }
        .background(AppColors.paper).navigationTitle(partyID == nil ? "Inbox" : "For you")
        .onChange(of: social.pastureOwner) { _, _ in selected = nil; routedInvitation = nil }
        .refreshable { await social.refreshSocialInbox() }
        .task {
            await social.refreshSocialInbox()
            if let event = await social.resolveSocialRoute() {
                if event.kind == "invitation" { routedInvitation = event.invitationID }
                else { selected = event }
            }
        }
        .sheet(item: $selected) { event in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        if let source = event.source {
                            if let detail = social.supportDetails[source] {
                                Text(event.title).font(AppTypography.title)
                                Text("For your \(detail.context)").font(AppTypography.headline)
                                Text(detail.occurredAt, format: .dateTime.day().month().year().hour().minute()).font(AppTypography.body)
                                Text("Received \(event.arrivedAt.formatted(date: .abbreviated, time: .shortened))").font(AppTypography.caption)
                                if let name = event.partyName { Text(name).font(AppTypography.body) }
                            } else if let error = social.supportErrors[source] {
                                Text(error).font(AppTypography.body)
                                Button("Check again") { Task { await social.loadSupportSource(source, eventID: event.id) } }.frame(minHeight: 44)
                            } else { SheepLoadingView("Opening the shared moment…") }
                        } else { Text(event.title).font(AppTypography.title) }
                        if let id = event.partyID, let openParty {
                            Button("Open party") { selected = nil; openParty(id) }.buttonStyle(PixelPrimaryButtonStyle())
                        }
                    }.padding(AppSpacing.md)
                }.background(AppColors.paper).navigationTitle("Encouragement")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { selected = nil } } }
                    .task { if let source = event.source { social.supportDetails[source] = nil; await social.loadSupportSource(source, eventID: event.id) } }
            }
        }
        .sheet(isPresented: $preferencesOpen) { SocialNotificationChoices(social: social) }
    }
}

private struct SocialNotificationChoices: View {
    @ObservedObject var social: NightFlockViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var choices = SocialNotificationPreferences()
    @State private var saving = false
    var body: some View {
        NavigationStack {
            Form {
                Toggle("Party invitations", isOn: $choices.invitations)
                Toggle("Cheers", isOn: $choices.cheers)
                if choices.cheers { Toggle("Include Global Campfire cheers", isOn: $choices.globalCheers) }
                Text("Push alerts are optional. Messages still appear in your inbox. Cheers are grouped, and your quiet hours apply.")
                if !social.campfirePushStatus.isEmpty { Text(social.campfirePushStatus) }
                if let error = social.socialInboxError { Text(error) }
                Button(saving ? "Saving…" : "Save choices") {
                    saving = true
                    Task { await social.setSocialPreferences(choices); saving = false }
                }.disabled(saving)
            }.navigationTitle("Notifications")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .onAppear { choices = social.socialPreferences }
        }
    }
}

struct SupportMessageControl: View {
    @ObservedObject var social: NightFlockViewModel
    let source: SocialSource
    @State private var choosing = false
    @State private var selectedMessage: String?
    @State private var removing = false
    private var detail: SocialSourceDetail? { social.supportDetails[source] }
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if let pending = social.pendingSupport(source) {
                Text("\(SupportMessage.title(for: pending.messageID)) · \(social.supportSending.contains(source) ? "Sending…" : "Waiting to send")")
                    .font(AppTypography.body)
                if !social.supportSending.contains(source) {
                    Button("Retry") { social.replaySupportMessages() }.frame(minHeight: 44)
                }
            } else if let detail, detail.removed {
                Text("Cheer removed").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            } else if let message = detail?.sentMessageID {
                Label("\(SupportMessage.title(for: message)) · Sent", systemImage: "checkmark").font(AppTypography.body)
                Button("Remove cheer") { removing = true }.font(AppTypography.caption).frame(minHeight: 44)
            } else if let first = detail?.messages.first {
                Button(SupportMessage.title(for: first)) { social.sendSupport(first, source: source) }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                Button("Choose a cheer") { choosing = true }.frame(minHeight: 44)
            } else if detail == nil && social.supportErrors[source] == nil {
                ProgressView().accessibilityLabel("Loading cheers")
            }
            if let error = social.supportErrors[source] {
                Text(error).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                if detail == nil && social.pendingSupport(source) == nil {
                    Button("Refresh cheers") { Task { await social.loadSupportSource(source) } }.frame(minHeight: 44)
                }
            }
        }
        .task(id: source) { await social.loadSupportSource(source) }
        .confirmationDialog("Remove this cheer? It may already have been received.", isPresented: $removing, titleVisibility: .visible) {
            Button("Remove cheer", role: .destructive) {
                if let message = detail?.sentMessageID { social.sendSupport(message, source: source, remove: true) }
            }
        }
        .sheet(isPresented: $choosing) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("A little encouragement for \(detail?.name ?? "this Shepherd")").font(AppTypography.title)
                        Text(detail?.context ?? "Shared moment").font(AppTypography.body).foregroundStyle(AppColors.secondaryText)
                        ForEach(detail?.messages ?? [], id: \.self) { id in
                            Button { selectedMessage = id } label: {
                                HStack {
                                    Label(SupportMessage.title(for: id), systemImage: SupportMessage(rawValue: id)?.symbol ?? "heart")
                                    Spacer()
                                    if selectedMessage == id { Image(systemName: "checkmark").accessibilityHidden(true) }
                                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            }.buttonStyle(PixelChipButtonStyle(isSelected: selectedMessage == id))
                                .accessibilityAddTraits(selectedMessage == id ? .isSelected : [])
                        }
                        if let selectedMessage {
                            Button("Send “\(SupportMessage.title(for: selectedMessage))”") {
                                social.sendSupport(selectedMessage, source: source); choosing = false
                            }.buttonStyle(PixelPrimaryButtonStyle())
                        }
                    }.padding(AppSpacing.md)
                }.background(AppColors.paper).navigationTitle("Choose a cheer")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { choosing = false } } }
            }
            .onAppear { selectedMessage = detail?.messages.first }
        }
    }
}

#Preview("Inbox · empty · large text") {
    NavigationStack { SocialInboxView(social: NightFlockViewModel(featureEnabled: false, previewPhase: .ready)) }
        .environment(\.dynamicTypeSize, .accessibility2)
}
#Preview("Cheers · unavailable") {
    let model = NightFlockViewModel(featureEnabled: false, previewPhase: .ready)
    let source = SocialSource(kind: "activity", id: UUID())
    model.supportErrors[source] = "This shared moment is no longer available."
    return SupportMessageControl(social: model, source: source).padding().background(AppColors.paper)
}
