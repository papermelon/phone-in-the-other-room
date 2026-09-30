import SwiftUI

struct CampfireBuddyCard: View {
    let session: CampfireBuddySession
    let party: NightFlockV4PartyDetail
    var active: Bool
    var now: Date = Date()
    var canJoin = true
    var isSending = false
    var showsMemberName = true
    var onJoin: () -> Void = {}
    var onAction: (String, CampfireOutcome?, String?) -> Void = { _, _, _ in }
    var support: AnyView? = nil
    @State private var reflection = ""
    @State private var selectedOutcome: CampfireOutcome?
    @State private var skippedCheckIn = false
    private var me: UUID? { party.myMemberID }
    private func name(_ id: UUID) -> String { party.memberships.first { $0.memberID == id }?.profile.displayName ?? "A party member" }
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label(showsMemberName ? "\(name(session.memberID)) · \(session.kind == .windDown ? "Wind Down" : "Phone Away")" : (session.kind == .windDown ? "Wind Down" : "Phone Away"), systemImage: active ? "flame" : "leaf")
                .font(AppTypography.headline)
            if let plan = CampfirePlanText.normalized(session.publicIntention) {
                Text("Shared plan").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                Text(plan).font(AppTypography.body).fixedSize(horizontal: false, vertical: true)
            }
            Text(active ? "Planned until \(session.expiresAt.formatted(date: .omitted, time: .shortened))" : "Session ended")
                .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            if let buddy = session.buddyMemberID {
                Text("\(name(buddy)) will check in afterwards").font(AppTypography.caption)
            } else if session.asksForBuddy && active {
                Text("A check-in buddy is welcome").font(AppTypography.caption)
            }
            if !session.encouragementMemberIDs.isEmpty {
                Text("Encouragement from \(session.encouragementMemberIDs.map(name).joined(separator: ", "))")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            }
            if let outcome = session.sharedOutcome {
                Text(session.windDownOutcome == nil ? "Shared check-in: \(outcome.title)" : "Winding down: \(outcome.title)").font(AppTypography.body)
                if let note = session.reflection, !note.isEmpty { Text(note).font(AppTypography.body) }
            } else if session.memberID == me && session.mayReflect(at: now) {
                checkInForm
            } else if !active {
                Text(session.kind == .windDown && now < session.checkInAfter ? "Check-in waits until morning quiet ends" : "No check-in shared")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            }
            if session.memberID != me {
                if active && canJoin {
                    Button(action: onJoin) { Text("Start my own \(session.kind == .windDown ? "Wind Down" : "Phone Away")").frame(maxWidth: .infinity) }
                        .buttonStyle(PixelPrimaryButtonStyle())
                }
                if CampfireBuddiesRules.canAccept(session, me: me, active: active) {
                    Button("I’ll check in afterwards") { onAction("accept", nil, nil) }
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                }
                if let support { support }
                else if let me, !session.encouragementMemberIDs.contains(me) {
                    Button("Send encouragement") { onAction("encourage", nil, nil) }
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                }
                if session.buddyMemberID == me && now >= session.checkInAfter && session.sharedOutcome == nil && !session.checkInRequested {
                    Button("Ask how it went") { onAction("checkIn", nil, nil) }
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.panel, in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .disabled(isSending)
    }

    @ViewBuilder private var checkInForm: some View {
        if session.kind == .windDown && party.pasture?.campfire?.buddies?.supportsWindDownEase != true {
            Text("Wind Down check-ins aren’t available for this party yet.")
                .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
        } else if skippedCheckIn {
            Button("Share a check-in") { skippedCheckIn = false }
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
        } else {
            if session.checkInRequested {
                Text("Your buddy asked how it went").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            }
            Text(session.kind == .windDown ? "How easy was it to wind down?" : "How did your plan go?")
                .font(AppTypography.body)
            ForEach(CampfireOutcome.choices(for: session.kind)) { result in
                Button { selectedOutcome = result } label: {
                    Label(result.title, systemImage: selectedOutcome == result ? "checkmark.circle.fill" : "circle")
                        .font(AppTypography.body).frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                }
                .buttonStyle(PixelChipButtonStyle(isSelected: selectedOutcome == result))
                .accessibilityAddTraits(selectedOutcome == result ? .isSelected : [])
            }
            Text("Anything you’d like to share? · Optional").font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText).fixedSize(horizontal: false, vertical: true)
            TextField("Add a note", text: $reflection,
                      prompt: Text("Add a note").foregroundColor(AppColors.secondaryText), axis: .vertical)
                .font(AppTypography.body).textFieldStyle(.roundedBorder)
                .accessibilityLabel("Optional note shared with \(party.summary.name)")
                .onChange(of: reflection) { _, value in
                    if value.unicodeScalars.count > 160 { reflection = CampfireBuddiesRules.publicText(value, limit: 160) }
                }
            Text("Shared with \(party.summary.name)").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            if session.kind == .phoneAway {
                Text("A finished timer doesn’t mark the task done.").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            }
            Button {
                guard let selectedOutcome else { return }
                onAction("reflect", selectedOutcome, reflection)
            } label: {
                Text("Share check-in").font(AppTypography.body).frame(maxWidth: .infinity)
            }
            .buttonStyle(PixelPrimaryButtonStyle()).disabled(selectedOutcome == nil)
            .accessibilityHint(selectedOutcome.map { "Share \($0.title) and your optional note with \(party.summary.name)" } ?? "Choose an answer first")
            Button("Skip for now") { skippedCheckIn = true }
                .font(AppTypography.body).foregroundStyle(AppColors.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }
}

struct CampfireFollowThrough: View {
    @ObservedObject var social: NightFlockViewModel
    let party: NightFlockV4PartyDetail
    var now: Date = Date()
    var sourceID: UUID? = nil
    private var sessions: [CampfireBuddySession] {
        CampfireBuddiesRules.visible(party.pasture?.campfire?.buddies, members: Set(party.memberships.map(\.memberID)), now: now)
            .filter { ($0.ended || $0.expiresAt <= now) && (sourceID == nil || $0.sourceID == sourceID) }
    }
    var body: some View {
        if !sessions.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Campfire check-ins").font(AppTypography.headline)
                ForEach(sessions.prefix(8)) { session in
                    CampfireBuddyCard(session: session, party: party, active: false, now: now, canJoin: false,
                        isSending: social.pastureSending.contains(party.summary.partyID), onAction: { action, outcome, note in
                            social.sendCampfireAction(action, session: session, partyID: party.summary.partyID, outcome: outcome, reflection: note)
                        }, support: social.supportsSocialInbox ? AnyView(SupportMessageControl(social: social,
                            source: .init(kind: "campfire", id: session.sourceID, partyID: party.summary.partyID, memberID: session.memberID))) : nil)
                }
                SharedPastureSaveFeedback(social: social, partyID: party.summary.partyID)
            }
        }
    }
}

struct CampfireReturnCheckIns: View {
    @ObservedObject var social: NightFlockViewModel
    let sourceID: UUID
    var partyIDs: [UUID] = []
    var body: some View {
        ForEach(social.slumberParties.filter { partyIDs.contains($0.partyID) }, id: \.partyID) { summary in
            if let party = social.v4ObservedPartyDetail(for: summary.partyID) {
                Text(summary.name).font(AppTypography.headline)
                CampfireFollowThrough(social: social, party: party, sourceID: sourceID)
                if social.pastureSending.contains(summary.partyID) {
                    Text("Sharing your session end. Your campfire check-in will be available when it syncs.")
                        .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                }
            }
        }
    }
}

#if DEBUG
#Preview("Buddy card · intention") {
    let party = SlumberPartySharedFarmFixtures.party
    if let member = party.memberships.first {
        CampfireBuddyCard(session: .init(sourceID: UUID(), memberID: member.memberID, publicIntention: "Read one chapter",
            asksForBuddy: true, encouragementMemberIDs: [], checkInRequested: false, startedAt: Date(),
            expiresAt: Date().addingTimeInterval(1800), checkInAfter: Date().addingTimeInterval(1800), ended: false, kind: .phoneAway), party: party, active: true)
            .padding().background(AppColors.paper)
    }
}
#endif

struct CampfirePendingCheckInCard: View {
    @ObservedObject var social: NightFlockViewModel
    private var partyID: UUID? {
        social.slumberParties.first { summary in
            guard let party = social.v4ObservedPartyDetail(for: summary.partyID) else { return false }
            return CampfireBuddiesRules.visible(party.pasture?.campfire?.buddies,
                members: Set(party.memberships.map(\.memberID)), now: Date()).contains {
                    $0.memberID == party.myMemberID && $0.sharedOutcome == nil && $0.mayReflect(at: Date())
                        && ($0.kind != .windDown || party.pasture?.campfire?.buddies?.supportsWindDownEase == true)
                }
        }?.partyID
    }
    var body: some View {
        if let partyID {
            Button {
                NotificationCenter.default.post(name: .countingSheepShowNightFlock, object: partyID)
            } label: {
                Label("Share a campfire check-in", systemImage: "leaf")
                    .font(AppTypography.body).frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(PixelChipButtonStyle(isSelected: false))
        }
    }
}
