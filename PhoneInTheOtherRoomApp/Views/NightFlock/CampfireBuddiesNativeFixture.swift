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
        social.v4ListState = .init(parties: [party.summary], profile: .init(displayName: "Tommy"), profileAvatarVersion: 1, sharedHabitsVersion: 1)
        social.v4ObservedPartyDetails[party.summary.partyID] = party
        social.v4ObservedPartyObservationStates[party.summary.partyID] = .current(lastReceivedAt: now)
        _social = StateObject(wrappedValue: social)
        let app = FocusRunViewModel(persistence: PersistenceService(defaults: defaults),
            startsExternalServices: false, nightFlockViewModel: social, purposeCueDefaults: defaults)
        social.sharedFarmAccount = nil
        _ = social.restoreCampfireVisibility()
        if mode.hasPrefix("unified") || mode == "visibility" || mode.hasPrefix("public-card") {
            social.globalCampfireState = .init(version: 1, available: mode != "unified-unavailable", observedAt: now,
                participants: (0..<8).map { index in
                    .init(id: UUID(), profileID: UUID(), name: ["Tommy", "Jim", "Alex", "Sam", "Riley", "Casey", "Morgan", "Jo"][index], appearance: .init(),
                        kind: index.isMultiple(of: 2) ? .windDown : .phoneAway, activity: index.isMultiple(of: 2) ? nil : .reading,
                        remaining: index.isMultiple(of: 2) ? .severalHours : .short, encouragedByMe: index == 1, isMe: false,
                        thought: index.isMultiple(of: 2) ? "Read before bed" : "One more chapter", hasProfile: true)
                }, approximateCount: 10, profileVersion: 2, channels: [.init(id: 1, count: 8), .init(id: 2, count: 0)], channelID: 1)
            if mode == "unified-plans" || mode == "public-card-long" {
                let plans: [String?] = ["Read a chapter", "Shower, then read before bed", String(repeating: "Make time for a chapter and a cup of tea. ", count: 8),
                    " \n ", "读完一章，然后准备休息", "أقرأ فصلاً قبل النوم", "A little café time ☕️", nil]
                for index in 0..<8 { social.globalCampfireState?.participants[index].thought = plans[index] }
                if mode == "public-card-long" { social.globalCampfireState?.participants[0].thought = plans[2] }
            }
            if let countArgument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--buddy-count=") }),
               let count = Int(countArgument.replacingOccurrences(of: "--buddy-count=", with: "")) {
                social.globalCampfireState?.participants = Array((social.globalCampfireState?.participants ?? []).prefix(max(0, min(8, count))))
            }
            if mode == "unified-loading" || mode == "unified-retrying" {
                social.globalCampfireState = nil
                social.globalCampfireLoading = true
                if mode == "unified-retrying" { social.globalCampfireFailure = .connection }
            }
            if mode == "public-card-pending", let person = social.globalCampfireState?.participants.first {
                social.campfireDocument.commands = [.init(command: "encourage", targetID: person.id)]
                social.campfireVisibilityMessage = "Your Campfire change is waiting to sync."
            }
            if mode == "public-card-sent" { social.globalCampfireState?.participants[0].encouragedByMe = true }
            if mode == "unified-refreshing" { social.globalCampfireLoading = true }
            if mode == "unified-party-refreshing" {
                social.v4ObservedPartyObservationStates[party.summary.partyID] = .refreshing(lastReceivedAt: now)
            }
            if mode == "unified-unavailable" { social.globalCampfireFailure = .unavailable }
            if mode == "unified-stale" { social.globalCampfireState?.observedAt = now.addingTimeInterval(-120) }
            if mode == "unified-failed" { social.globalCampfireState = nil; social.globalCampfireFailure = .connection }
            if mode == "unified-empty" { social.globalCampfireState?.participants = []; social.globalCampfireState?.approximateCount = 0 }
            if mode == "unified-no-party" { social.v4ListState = .init(parties: [], profileAvatarVersion: 1, sharedHabitsVersion: 1) }
        }
        if mode == "visibility" {
            social.campfireDocument.selection = .init(visibility: .global, partyIDs: [party.summary.partyID], effectiveAt: now)
        }
        social.v4Profile = .init(displayName: "Tommy")
        app.nextCampfireIntention = "Read one chapter"
        app.nextCampfireAsksForBuddy = true
        if mode == "unified-local" {
            let end = now.addingTimeInterval(1800)
            let run = FocusRun(plannedDurationSeconds: 1800, startedAt: now, state: .running,
                nightWatchPlan: .additionalQuiet(start: now, end: end, cueText: ""))
            app.coordinator.run = run
            social.globalCampfireState?.participants = []
        }
        _app = StateObject(wrappedValue: app)
    }
    var body: some View {
        Group {
            if mode.hasPrefix("bedtime") { CampfireBedtimeNativeFixture(mode: mode) }
            else if mode == "profile" {
                ScrollView {
                    CampfireProfileContents(snapshot: .init(session: ["Phone Away · Active", "Started 20 Sep, 10:00 AM", "Planned end 20 Sep, 10:30 AM", "Times in Asia/Singapore"],
                        tasks: ["Read one chapter"], routines: ["Wind Down · 22:30–07:00", "Evening · Read"], intention: "Make room for a quiet evening",
                        history: ["Wind Down · 19 Sep, 10:30 PM – 20 Sep, 7:00 AM · Completed"], partyNames: ["Family"],
                        inventory: ["shepherd_moss_coat"], sheep: [], appearance: .init(), decorations: [:], collectibles: [:],
                        ollieAccessory: "none", barnCapacityLevel: 0)).padding(AppSpacing.md)
                }.background(AppColors.paper).environmentObject(app)
            }
            else if mode == "private-card", let person = party.pasture?.campfire?.sessions.first {
                CampfirePrivatePersonView(social: social, partyID: party.summary.partyID, sourceID: person.id,
                    memberID: person.memberID, onJoin: { _ in }).environmentObject(app)
            }
            else if mode == "visibility" { CampfireVisibilitySheet(social: social).environmentObject(app) }
            else if mode.hasPrefix("public-card"), let person = social.globalCampfireState?.participants.first {
                CampfirePublicPersonView(social: social, participantID: person.id, onJoin: { _ in }).environmentObject(app)
            }
            else if mode.hasPrefix("unified") {
                NavigationStack {
                    CampfirePanel(social: social, partyID: mode.hasPrefix("unified-party") ? party.summary.partyID : nil, onStart: { _ in })
                        .background(AppColors.paper)
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
#Preview("Campfire · varied plans") { CampfireBuddiesNativeFixture(mode: "unified-plans") }
#Preview("Campfire · full shared plan") { CampfireBuddiesNativeFixture(mode: "public-card-long") }
#Preview("Unified Campfire · loading") { CampfireBuddiesNativeFixture(mode: "unified-loading") }
#Preview("Unified Campfire · refreshing") { CampfireBuddiesNativeFixture(mode: "unified-refreshing") }
#Preview("Unified Campfire · retrying") { CampfireBuddiesNativeFixture(mode: "unified-retrying") }
#Preview("Unified Campfire · empty") { CampfireBuddiesNativeFixture(mode: "unified-empty") }
#Preview("Unified Campfire · visibility") { CampfireBuddiesNativeFixture(mode: "visibility") }
#endif
