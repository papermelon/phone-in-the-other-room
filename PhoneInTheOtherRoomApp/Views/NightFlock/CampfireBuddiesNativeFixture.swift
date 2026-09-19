#if DEBUG
import SwiftUI

/// Disposable rendering fixture using release components and isolated local state.
struct CampfireBuddiesNativeFixture: View {
    @StateObject private var social: NightFlockViewModel
    @StateObject private var app: FocusRunViewModel
    private let party: NightFlockV4PartyDetail
    private let mode: String
    init(mode: String? = nil) {
        let mode = mode ?? ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--buddy-view=") })?.replacingOccurrences(of: "--buddy-view=", with: "") ?? "live"
        self.mode = mode
        var party = SlumberPartySharedFarmFixtures.party
        let now = Date(), agreementID = UUID()
        let live = Array(party.memberships.prefix(2).reversed()).enumerated().map { index, member in
            CampfireSession(id: UUID(), memberID: member.memberID, kind: index == 0 ? .phoneAway : .windDown,
                activity: index == 0 ? .reading : nil, startedAt: now.addingTimeInterval(-120), observedAt: now,
                expiresAt: now.addingTimeInterval(1800), ended: false, revision: 1)
        }
        var buddies = live.map { session in
            CampfireBuddySession(sourceID: session.id, memberID: session.memberID,
                publicIntention: session.kind == .phoneAway ? "Read one chapter" : "Shower, then read before bed", asksForBuddy: true,
                encouragementMemberIDs: [], checkInRequested: false, startedAt: session.startedAt,
                expiresAt: session.expiresAt, checkInAfter: session.expiresAt, ended: false, kind: session.kind)
        }
        if mode == "return" {
            buddies[0].memberID = party.myMemberID!
            buddies[0].ended = true
            buddies[0].checkInAfter = now.addingTimeInterval(-30)
            buddies[0].buddyMemberID = SlumberPartySharedFarmFixtures.friend
        }
        party.pasture = .init(memberEpochID: UUID(), entities: [], visits: [],
            lantern: .init(contributions: 5, requiredContributions: 12),
            campfire: .init(agreement: .init(id: agreementID, version: 2, revision: 1, enabled: true, acceptedAt: now.addingTimeInterval(-3600)),
                sessions: mode == "empty" ? [] : live,
                buddies: .init(version: 1, startAlerts: false, sessions: mode == "empty" ? [] : buddies)))
        if mode == "setup" { party.pasture?.campfire?.agreement = nil }
        self.party = party
        let defaults = UserDefaults(suiteName: "CampfireBuddiesFixture.\(UUID())")!
        defaults.set(UUID().uuidString, forKey: NightFlockAccountService.expectedLinkedUserIDKey)
        let social = NightFlockViewModel(featureEnabled: true, previewPhase: .ready, previewAccountState: .linked, defaults: defaults)
        social.v4ListState = .init(parties: [party.summary], profileAvatarVersion: 1, sharedHabitsVersion: 1)
        social.v4ObservedPartyDetails[party.summary.partyID] = party
        social.v4ObservedPartyObservationStates[party.summary.partyID] = .current(lastReceivedAt: now)
        _social = StateObject(wrappedValue: social)
        let app = FocusRunViewModel(persistence: PersistenceService(defaults: defaults),
            startsExternalServices: false, nightFlockViewModel: social, purposeCueDefaults: defaults)
        social.sharedFarmAccount = nil
        _ = social.restoreCampfireVisibility()
        if mode.hasPrefix("unified") || mode == "visibility" || mode == "public-card" {
            social.globalCampfireState = .init(version: 1, available: mode != "unified-unavailable", observedAt: now,
                participants: (0..<8).map { index in
                    .init(id: UUID(), profileID: UUID(), name: PublicCampfireName.choices[index], appearance: .init(),
                        kind: index.isMultiple(of: 2) ? .windDown : .phoneAway, activity: index.isMultiple(of: 2) ? nil : .reading,
                        remaining: index.isMultiple(of: 2) ? .severalHours : .short, encouragedByMe: index == 1, isMe: false)
                }, approximateCount: 10)
            if mode == "unified-stale" { social.globalCampfireState?.observedAt = now.addingTimeInterval(-120) }
            if mode == "unified-failed" { social.globalCampfireState = nil; social.globalCampfireFailure = "Refresh to try again." }
            if mode == "unified-empty" { social.globalCampfireState?.participants = []; social.globalCampfireState?.approximateCount = 0 }
            if mode == "unified-no-party" { social.v4ListState = .init(parties: [], profileAvatarVersion: 1, sharedHabitsVersion: 1) }
        }
        app.nextCampfireIntention = "Read one chapter"
        app.nextCampfireAsksForBuddy = true
        _app = StateObject(wrappedValue: app)
    }
    var body: some View {
        Group {
            if mode == "visibility" { CampfireVisibilitySheet(social: social).environmentObject(app) }
            else if mode == "public-card", let person = social.globalCampfireState?.participants.first {
                CampfirePublicPersonView(social: social, participantID: person.id, onJoin: { _ in }).environmentObject(app)
            }
            else if mode.hasPrefix("unified") {
                NavigationStack {
                    ScrollViewReader { proxy in
                        ScrollView {
                            CampfirePanel(social: social, partyID: mode == "unified-party" ? party.summary.partyID : nil, onStart: { _ in }).padding(AppSpacing.md)
                            Color.clear.frame(height: 1).id("fixture-bottom")
                        }.background(AppColors.paper)
                            .onAppear {
                                if ProcessInfo.processInfo.arguments.contains("--buddy-bottom") {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { proxy.scrollTo("fixture-bottom", anchor: .bottom) }
                                }
                            }
                    }
                }.environmentObject(app)
            }
            else if mode == "settings" { CampfireSharingSheet(social: social, partyID: party.summary.partyID) }
            else {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            if mode == "returnbar" {
                                Text("Your Phone Away keeps running while you visit the campfire.").font(AppTypography.body)
                                let start = Date(), end = start.addingTimeInterval(1800)
                                ActiveWindDownReturnBar(run: FocusRun(plannedDurationSeconds: 1800, startedAt: start,
                                    nightWatchPlan: .additionalQuiet(start: start, end: end, cueText: "")), action: {})
                            }
                            else if mode == "setup" {
                                if let notice = social.campfireParticipationNotice(partyID: party.summary.partyID, run: nil) {
                                    CampfireParticipationNotice(message: notice, onReview: {})
                                }
                                CampfireStartChoices(viewModel: app)
                            }
                            else if mode == "start" { CampfireStartChoices(viewModel: app) }
                            else if mode == "card" || mode == "return", let buddy = party.pasture?.campfire?.buddies?.sessions.first {
                                CampfireBuddyCard(session: buddy, party: party, active: mode == "card")
                            } else {
                                SlumberPartyPastureView(party: party, statusIsFresh: mode != "stale", onSelect: { _ in }, buddyCard: { session in
                                    if let buddy = party.pasture?.campfire?.buddies?.sessions.first(where: { $0.sourceID == session.id }) {
                                        return AnyView(CampfireBuddyCard(session: buddy, party: party, active: true))
                                    }
                                    return AnyView(EmptyView())
                                })
                            }
                        }.padding(AppSpacing.md)
                    }.background(AppColors.paper).navigationTitle(mode == "start" ? "Before you start" : "Campfire Buddies")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }.preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--buddy-light") ? .light : .dark)
            .dynamicTypeSize(ProcessInfo.processInfo.arguments.contains("--buddy-max-text") ? .accessibility5 : ProcessInfo.processInfo.arguments.contains("--buddy-large-text") ? .accessibility3 : .large)
    }
}
#Preview("Campfire Buddies · live") { CampfireBuddiesNativeFixture() }
#Preview("Campfire Buddies · no sessions") { CampfireBuddiesNativeFixture(mode: "empty") }
#Preview("Campfire Buddies · stale") { CampfireBuddiesNativeFixture(mode: "stale") }
#Preview("Campfire Buddies · return") { CampfireBuddiesNativeFixture(mode: "return") }
#Preview("Campfire Buddies · start") { CampfireBuddiesNativeFixture(mode: "start") }
#Preview("Campfire Buddies · sharing setup") { CampfireBuddiesNativeFixture(mode: "setup") }
#Preview("Unified Campfire · mixed private sessions") { CampfireBuddiesNativeFixture(mode: "unified-party") }
#Preview("Unified Campfire · eight public participants") { CampfireBuddiesNativeFixture(mode: "unified") }
#Preview("Unified Campfire · no Slumber Party") { CampfireBuddiesNativeFixture(mode: "unified-no-party") }
#Preview("Unified Campfire · unavailable") { CampfireBuddiesNativeFixture(mode: "unified-unavailable") }
#Preview("Unified Campfire · empty") { CampfireBuddiesNativeFixture(mode: "unified-empty") }
#Preview("Unified Campfire · visibility") { CampfireBuddiesNativeFixture(mode: "visibility") }
#endif
