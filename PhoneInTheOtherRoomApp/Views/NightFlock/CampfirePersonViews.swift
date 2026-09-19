import SwiftUI

struct CampfirePrivatePersonView: View {
    @ObservedObject var social: NightFlockViewModel
    let partyID: UUID
    let sourceID: UUID
    let memberID: UUID
    var onJoin: (NightFlockV4ActivityKind) -> Void
    @EnvironmentObject private var app: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                TimelineView(.periodic(from: .now, by: 15)) { context in
                    if social.v4ObservedPartyObservationState(for: partyID).permitsLivePresence,
                       let party = social.v4ObservedPartyDetail(for: partyID),
                       let member = party.memberships.first(where: { $0.memberID == memberID }) {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            SlumberPartySocialAvatarView(presentation: member.profile.presentation, avatarID: "shepherd", size: 88)
                            Text(member.profile.displayName).font(AppTypography.title)
                            Text("Shared with \(party.summary.name)").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                            if let buddy = party.pasture?.campfire?.buddies?.sessions.first(where: { $0.sourceID == sourceID && $0.memberID == memberID }),
                               party.pasture?.campfire?.agreement?.version == 2 {
                                CampfireBuddyCard(session: buddy, party: party, active: !buddy.ended && buddy.expiresAt > context.date,
                                    now: context.date, canJoin: !app.isRunning, isSending: social.pastureSending.contains(partyID),
                                    onJoin: { onJoin(buddy.kind) }, onAction: { action, outcome, note in
                                        social.sendCampfireAction(action, session: buddy, partyID: partyID, outcome: outcome, reflection: note)
                                    })
                            } else if let session = party.pasture?.campfire?.sessions.first(where: { $0.id == sourceID && $0.memberID == memberID }) {
                                Text(session.title).font(AppTypography.headline)
                                Text(session.isCurrent(at: context.date) ? "Planned until \(session.expiresAt.formatted(date: .omitted, time: .shortened))" : "Session ended")
                                    .font(AppTypography.body)
                                if session.isCurrent(at: context.date), !app.isRunning, memberID != party.myMemberID {
                                    Button("Start my own \(session.kind == .windDown ? "Wind Down" : "Phone Away")") { onJoin(session.kind) }
                                        .buttonStyle(PixelPrimaryButtonStyle())
                                }
                            } else { Text("This session is no longer available.").font(AppTypography.body) }
                            SharedPastureSaveFeedback(social: social, partyID: partyID)
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
                            Text(person.remaining.title).font(AppTypography.body)
                            if !person.isMe {
                                if !app.isRunning {
                                    Button("Start my own \(person.kind == .windDown ? "Wind Down" : "Phone Away")") { onJoin(person.kind) }
                                        .buttonStyle(PixelPrimaryButtonStyle())
                                }
                                Button(person.encouragedByMe ? "Encouragement sent" : "Send encouragement") {
                                    social.globalCampfireAction("encourage", participant: person)
                                }.buttonStyle(PixelChipButtonStyle(isSelected: person.encouragedByMe))
                                    .disabled(person.encouragedByMe || social.campfireDocument.commands.contains { $0.command == "encourage" && $0.targetID == person.id })
                                Button("Block this person", role: .destructive) { confirmsBlock = true }.frame(minHeight: 44)
                                Button("Report this profile") { confirmsReport = true }.frame(minHeight: 44)
                            }
                            if let message = social.campfireVisibilityMessage { Text(message).font(AppTypography.caption) }
                            Text("A shared session, not proof of sleep or task completion. Joining starts your own timer with the visibility you choose.")
                                .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                        }.padding(AppSpacing.md)
                    } else { Text("This session needs an update. Close this card and refresh the fire.").font(AppTypography.body).padding() }
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
