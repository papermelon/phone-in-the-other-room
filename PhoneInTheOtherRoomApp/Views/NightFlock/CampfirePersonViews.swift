import SwiftUI

struct CampfirePrivatePersonView: View {
    @ObservedObject var social: NightFlockViewModel
    let partyID: UUID
    let sourceID: UUID
    let memberID: UUID
    var onJoin: (NightFlockV4ActivityKind) -> Void
    @EnvironmentObject private var app: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showsProfile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                SlumberPartyV4PresentationClock(party: social.v4ObservedPartyDetail(for: partyID)) { date in
                    if social.v4ObservedPartyObservationState(for: partyID).permitsLivePresence,
                       let party = social.v4ObservedPartyDetail(for: partyID),
                       let member = party.memberships.first(where: { $0.memberID == memberID }) {
                        let current = CampfireRules.currentSessions(party.pasture?.campfire,
                            members: Set(party.memberships.map(\.memberID)), isFresh: true, at: date)
                            .first { $0.id == sourceID && $0.memberID == memberID }
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            CampfireShepherdView(presentation: member.profile.presentation, pose: current?.pose(at: date) ?? .awake, size: 88)
                                .accessibilityLabel(current?.pose(at: date).accessibilityDescription ?? "Shepherd")
                            Text(member.profile.displayName).font(AppTypography.title)
                            Text("Shared with \(party.summary.name)").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                            if let buddy = party.pasture?.campfire?.buddies?.sessions.first(where: { $0.sourceID == sourceID && $0.memberID == memberID }),
                               party.pasture?.campfire?.agreement?.version == 2 {
                                CampfireBuddyCard(session: buddy, party: party, active: current != nil,
                                    now: date, canJoin: !app.isRunning, isSending: social.pastureSending.contains(partyID), showsMemberName: false,
                                    onJoin: { onJoin(buddy.kind) }, onAction: { action, outcome, note in
                                        social.sendCampfireAction(action, session: buddy, partyID: partyID, outcome: outcome, reflection: note)
                                    })
                            } else if let session = party.pasture?.campfire?.sessions.first(where: { $0.id == sourceID && $0.memberID == memberID }) {
                                Text(session.title).font(AppTypography.headline)
                                Text(current != nil ? "Planned until \(session.expiresAt.formatted(date: .omitted, time: .shortened))" : "Session ended")
                                    .font(AppTypography.body)
                                if current != nil, !app.isRunning, memberID != party.myMemberID {
                                    Button("Start my own \(session.kind == .windDown ? "Wind Down" : "Phone Away")") { onJoin(session.kind) }
                                        .buttonStyle(PixelPrimaryButtonStyle())
                                }
                            } else { Text("This session is no longer available.").font(AppTypography.body) }
                            SharedPastureSaveFeedback(social: social, partyID: partyID)
                            DisclosureGroup(isExpanded: $showsProfile) {
                                if showsProfile { CampfireProfileView(social: social, memberID: memberID) }
                            } label: { Text("Profile & Farm").font(AppTypography.headline).frame(minHeight: 44) }
                        }.padding(AppSpacing.md)
                    } else { Text("Refresh the party to see this session’s current details.").font(AppTypography.body).padding() }
                }
            }.background(AppColors.paper.ignoresSafeArea()).navigationTitle("At the Campfire").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.tint(AppColors.grass)
    }
}

struct CampfirePublicPersonView: View {
    @ObservedObject var social: NightFlockViewModel
    let participantID: UUID
    var onJoin: (NightFlockV4ActivityKind) -> Void
    @EnvironmentObject private var app: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showsProfile = false
    @State private var confirmsBlock = false
    @State private var confirmsReport = false
    private var person: GlobalCampfireParticipant? { social.globalCampfireState?.participants.first { $0.id == participantID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                TimelineView(.periodic(from: .now, by: 15)) { context in
                    if let state = social.globalCampfireState, state.isSupported,
                       CampfireVisibilityRules.isFresh(observedAt: state.observedAt, now: context.date), let person {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            SlumberPartySocialAvatarView(presentation: person.appearance.presentation, avatarID: "shepherd", size: 88)
                            Text(person.name).font(AppTypography.title)
                            Text("Global Campfire").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                            Text(person.title).font(AppTypography.headline)
                            if let plan = CampfirePlanText.normalized(person.thought) {
                                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                    Text("Shared plan").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                                    Text(plan).font(AppTypography.body).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            if let start = person.startedAt, let end = person.expiresAt {
                                Text("\(OllieFormat.dateAndTime(start)) – \(OllieFormat.dateAndTime(end))")
                                    .font(AppTypography.body)
                            } else { Text(person.remaining.title).font(AppTypography.body) }
                            if !person.isMe {
                                if !app.isRunning {
                                    Button("Start my own \(person.kind == .windDown ? "Wind Down" : "Phone Away")") { onJoin(person.kind) }
                                        .buttonStyle(PixelPrimaryButtonStyle())
                                }
                                let pending = social.campfireDocument.commands.contains { $0.command == "encourage" && $0.targetID == person.id }
                                Button(person.encouragedByMe ? "Encouragement sent" : pending ? "Waiting to send" : "Send encouragement") {
                                    social.globalCampfireAction("encourage", participant: person)
                                }.buttonStyle(PixelChipButtonStyle(isSelected: person.encouragedByMe))
                                    .disabled(person.encouragedByMe || pending)
                                if pending && social.campfireVisibilityMessage != nil {
                                    Button("Try sending again") { social.drainGlobalCampfireCommands(retry: true) }.frame(minHeight: 44)
                                }
                            }
                            if let message = social.campfireVisibilityMessage { Text(message).font(AppTypography.caption) }
                            if person.hasProfile == true {
                                DisclosureGroup(isExpanded: $showsProfile) {
                                    if showsProfile { CampfireProfileView(social: social, participantID: person.id) }
                                } label: { Text("Profile & Farm").font(AppTypography.headline).frame(minHeight: 44) }
                            }
                            if !person.isMe {
                                Menu {
                                    Button("Block this person", role: .destructive) { confirmsBlock = true }
                                    Button("Report this profile") { confirmsReport = true }
                                } label: { Label("Safety options", systemImage: "ellipsis").font(AppTypography.body).frame(minHeight: 44) }
                            }
                        }.padding(AppSpacing.md)
                    } else { Text("This session needs an update. Close this card and refresh the campfire.").font(AppTypography.body).padding() }
                }
            }.background(AppColors.paper.ignoresSafeArea()).navigationTitle("At the Campfire").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .confirmationDialog("Block this person?", isPresented: $confirmsBlock) {
                    Button("Block", role: .destructive) {
                        if let person { social.globalCampfireAction("block", participant: person); dismiss() }
                    }
                } message: { Text("They’ll be hidden on this phone now. Mutual visibility is removed when the block syncs.") }
                .confirmationDialog("Report this profile?", isPresented: $confirmsReport) {
                    Button("Send safety report") {
                        if let person { social.globalCampfireAction("report", participant: person, reason: "profile"); dismiss() }
                    }
                } message: { Text("Send this public profile to Counting Sheep for review. Reporting doesn’t block the person.") }
        }.tint(AppColors.grass)
    }
}
