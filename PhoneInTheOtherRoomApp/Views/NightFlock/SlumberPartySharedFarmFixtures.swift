import SwiftUI

/// Disposable data for ordinary previews and the isolated native capture entry.
enum SlumberPartySharedFarmFixtures {
    static let partyID = UUID(uuidString: "91000000-0000-4000-8000-000000000001")!
    static let me = UUID(uuidString: "91000000-0000-4000-8000-000000000002")!
    static let friend = UUID(uuidString: "91000000-0000-4000-8000-000000000003")!
    static let now = Date(timeIntervalSince1970: 1788912000)
    static var party: NightFlockV4PartyDetail {
        var clover = CountingSheepPublicPresentation.defaultValue
        clover.headShapeID = "round"
        clover.hairStyleID = "long"
        clover.shepherdOutfitID = "shepherd_moon_coat"
        clover.shepherdAccessoryID = "shepherd_moon_beanie"
        var moss = CountingSheepPublicPresentation.defaultValue
        moss.avatarID = "shepherd"
        moss.skinToneID = "deep"
        moss.hairStyleID = "curls"
        moss.shepherdOutfitID = "shepherd_field_overalls"
        moss.ollieOrnamentID = "ollie_moss_bandana"
        let members: [NightFlockV4Membership] = [
            .init(memberID: me, profile: .init(displayName: "Clover", presentation: clover), role: .host, joinedAt: now.addingTimeInterval(-86400 * 3)),
            .init(memberID: friend, profile: .init(displayName: "Moss", presentation: moss), role: .member, joinedAt: now.addingTimeInterval(-86400 * 2))
        ]
        let updates = members.enumerated().map { index, member in
            NightFlockV4SharedActivity(activityID: UUID(uuidString: "92000000-0000-4000-8000-00000000000\(index + 1)")!,
                partyID: partyID, memberID: member.memberID, kind: .windDown, status: .completed,
                roundedMinutes: index == 0 ? 30 : 45, occurredAt: now.addingTimeInterval(-3600))
        }
        var party = NightFlockV4PartyDetail(summary: .init(partyID: partyID, name: "Moonlit Neighbours", memberCount: 2,
            myRole: .host, currentRound: nil, revision: 1, sharingScope: .membership), myMemberID: me,
            memberships: members, sharedActivities: updates,
            sharedCheers: [.init(activityID: updates[0].id, cheer: .moonGlow, count: 1, sentByMe: false)])
        party.updateCheerReceiptVersion = 1
        party.updateCheerReceipts = [.init(reactionID: UUID(uuidString: "93000000-0000-4000-8000-000000000001")!,
            activityID: updates[0].id, senderMemberID: friend, recipientMemberID: me,
            cheer: .moonGlow, acceptedAt: now, receivedByAppAt: now)]
        return party
    }
}

#if DEBUG
struct SlumberPartySharedFarmNativeFixture: View {
    @StateObject private var model: NightFlockViewModel
    @StateObject private var appModel: FocusRunViewModel
    private let party: NightFlockV4PartyDetail
    private let mode: String

    init() {
        let args = ProcessInfo.processInfo.arguments
        mode = args.first(where: { $0.hasPrefix("--farm-state=") })?.replacingOccurrences(of: "--farm-state=", with: "") ?? "farm"
        var party = SlumberPartySharedFarmFixtures.party
        if mode == "empty" || mode == "empty-party" { party.sharedActivities = [] }
        if mode == "old-server" { party.updateCheerReceiptVersion = nil; party.updateCheerReceipts = []; party.memberships[0].profile.presentation.headShapeID = nil }
        if mode == "unsupported" { party.memberships[0].profile.presentation.headShapeID = "future"; party.updateCheerReceiptVersion = nil }
        if mode == "large-party" || mode == "four-party" || mode == "ollie-study" {
            for index in 2..<(mode == "four-party" ? 4 : 8) {
                var member = party.memberships[index % 2]
                member.memberID = UUID(uuidString: String(format: "91000000-0000-4000-8000-%012d", index + 20))!
                member.profile.displayName = ["Juniper", "Fern", "Rowan", "Willow", "Hazel", "River"][index - 2]
                member.joinedAt = member.joinedAt.addingTimeInterval(Double(index))
                if index == 7 { member.profile.presentation.avatarID = "sheep:juniper" }
                party.memberships.append(member)
            }
            party.summary.memberCount = party.memberships.count
        }
        if mode != "old-server", mode != "old-party", mode != "unsupported" {
            let epoch = UUID(uuidString: "97000000-0000-4000-8000-000000000001")!
            let members = SlumberPartySharedFarmRules.members(in: party)
            var entities = members.enumerated().map { index, member in
                let point = SharedMeadowLayout.seededPosition(for: .member(member.memberID), memberIndex: index, memberCount: members.count, seed: 0)
                return SharedPastureEntity(id: "member-" + member.memberID.uuidString, kind: "shepherd", referenceID: member.memberID, revision: 0, x: point.x, y: point.y)
            }
            let visits = members.enumerated().map { index, member in
                SharedPastureVisit(id: UUID(uuidString: String(format: "98000000-0000-4000-8000-%012d", index+1))!,
                    memberID: member.memberID, sheepDefinitionID: index % 2 == 0 ? "bramble" : "mabel",
                    sheepDisplayName: index % 2 == 0 ? "Bramble" : "Mabel", sentAt: Date())
            }
            entities += visits.enumerated().map { index, visit in
                let point = SharedMeadowLayout.seededPosition(for: .visitor(visit.id), memberIndex: index, memberCount: members.count, seed: 0)
                return SharedPastureEntity(id: "visitor-" + visit.id.uuidString, kind: "sheep", referenceID: visit.id, revision: 0, x: point.x, y: point.y)
            }
            if mode == "lantern-complete" {
                entities.append(.init(id: "lantern-" + party.summary.partyID.uuidString, kind: "lantern", referenceID: party.summary.partyID, revision: 0, x: 0.32, y: 0.60))
            }
            party.pasture = SharedPastureState(memberEpochID: epoch, entities: entities, visits: visits,
                lantern: .init(contributions: mode == "lantern-complete" ? 12 : 5, requiredContributions: 12,
                               completedAt: mode == "lantern-complete" ? Date() : nil))
        }
        if mode == "empty-party" {
            party.pasture?.visits = []
            party.pasture?.entities.removeAll { $0.kind == "sheep" }
            party.pasture?.lantern.contributions = 0
        }
        if mode == "active-party" || mode == "live-home" {
            party.sharedLiveStatuses = [.init(statusID: UUID(), partyID: party.summary.partyID,
                memberID: SlumberPartySharedFarmFixtures.friend, status: .windDownStarting, revision: 1,
                observedAt: Date().addingTimeInterval(-60), expiresAt: Date().addingTimeInterval(900))]
        }
        if mode != "old-server" {
            let clock = Date()
            let campfireExpired = mode == "campfire-expired"
            party.pasture?.campfire = .init(agreement: .init(id: UUID(), version: 1, revision: 1, enabled: true, acceptedAt: clock.addingTimeInterval(-3600)),
                sessions: mode == "empty-party" ? [] : party.memberships.enumerated().map { index, member in
                    CampfireSession(id: UUID(), memberID: member.memberID, kind: index == 0 ? .windDown : .phoneAway,
                        activity: index == 0 ? nil : .reading, startedAt: clock.addingTimeInterval(-300), observedAt: clock.addingTimeInterval(-300),
                        expiresAt: campfireExpired ? clock.addingTimeInterval(-1) : clock.addingTimeInterval(1800), ended: false, revision: 1)
                })
        }
        self.party = party
        let defaults = UserDefaults(suiteName: "SlumberPartyNativeFixture.\(UUID())")!
        let model = NightFlockViewModel(featureEnabled: true, previewPhase: .ready, previewAccountState: .linked, defaults: defaults)
        model.v4ListState = .init(parties: [party.summary], profileAvatarVersion: 1, sharedHabitsVersion: 1)
        model.sharedHabitsStates[party.summary.partyID] = .init(agreement: .init(agreementID: UUID(), memberEpochID: UUID(),
            acceptedAt: SlumberPartySharedFarmFixtures.now, timeZoneIdentifier: "UTC", firstEligibleSleepNight: nil),
            records: [], nextCursor: nil, snapshotRevision: 1, periods: [])
        model.v4ObservedPartyDetails[party.summary.partyID] = party
        model.v4ObservedPartyObservationStates[party.summary.partyID] = .current(lastReceivedAt: Date())
        if mode == "refreshing" { model.v4ObservedPartyObservationStates[party.summary.partyID] = .refreshing(lastReceivedAt: Date()) }
        if mode == "stale" || mode == "stale-party" { model.v4ObservedPartyObservationStates[party.summary.partyID] = .stale(lastReceivedAt: Date().addingTimeInterval(-86400)) }
        if mode == "pending" || mode == "failed", let update = party.sharedActivities.last {
            model.v4CheerSendStates[.init(partyID: party.summary.partyID, target: .membershipActivity(update.id), cheer: .warmWave)] = mode == "failed" ? .failed : .pending
        }
        _model = StateObject(wrappedValue: model)
        let persistence = PersistenceService(defaults: defaults)
        persistence.orientationState = CountingSheepOrientationState(
            status: .completed, seenContextualTips: Set(CountingSheepContextualTip.allCases))
        var farm = FarmState.empty
        farm.sheep = ["mabel", "bramble", "juniper"].enumerated().map { index, id in
            FlockSheep(id: UUID(), definitionID: id, displayName: id.capitalized, arrivedAt: Date(), protectedNightNumber: index, rarity: .common)
        }
        persistence.farmState = farm
        let app = FocusRunViewModel(persistence: persistence,
            startsExternalServices: false, nightFlockViewModel: model, purposeCueDefaults: defaults)
        if mode == "active-party" || mode == "live-home" {
            let start = Date().addingTimeInterval(-300)
            let plan = NightWatchPlan(intendedBedtime: start.addingTimeInterval(1800), wakeTime: start.addingTimeInterval(8*3600),
                protectedUntil: start.addingTimeInterval(8*3600), windDownMinutes: 30, morningQuietMinutes: 0,
                eveningActivity: .read, morningActivity: .openCurtains)
            app.coordinator.run = FocusRun(plannedDurationSeconds: 8*3600, startedAt: start, state: .running,
                guardKind: .honorTimer, nightWatchPlan: plan, appShieldingRequested: false, liveActivityRequested: false)
        }
        _appModel = StateObject(wrappedValue: app)
    }
    var body: some View {
        Group {
            if mode == "refreshing" || mode == "stale" || mode == "recipient" || mode == "friend" || mode == "empty" || mode == "unsupported" || mode == "pending" || mode == "failed" || mode == "old-server" {
                SlumberPartyMemberUpdatesView(viewModel: model, partyID: party.summary.partyID,
                    memberID: ["friend", "pending", "failed", "old-server"].contains(mode) ? SlumberPartySharedFarmFixtures.friend : SlumberPartySharedFarmFixtures.me,
                    showsSocialAvatar: true)
            } else if mode == "campfire-settings" {
                CampfireSharingSheet(social: model, partyID: party.summary.partyID)
            } else if ProcessInfo.processInfo.arguments.contains("--campfire-direct") {
                NavigationStack { SlumberPartyV4PartyDetailView(viewModel: model, summary: party.summary) }
                    .environmentObject(appModel)
            } else if mode == "ollie-study" {
                ScrollView {
                    SlumberPartyPastureView(party: party, visits: party.pasture?.visits ?? [], arrangement: party.pasture?.arrangement,
                        canArrange: true, studyCompanionOwner: party.myMemberID, onSelect: { _ in }).padding(AppSpacing.md)
                }.background(AppColors.paper.ignoresSafeArea())
            } else {
                HomeView(initialTab: mode == "personal" ? .farm : .home, farmVisitSeed: 47,
                         dashboardWatch: appModel.coordinator.watch, allowsLaunchRouting: false)
                    .environmentObject(appModel)
                    .task {
                        guard mode != "personal", mode != "live-home" else { return }
                        try? await Task.sleep(for: .seconds(3))
                        NotificationCenter.default.post(name: .countingSheepShowNightFlock, object: party.summary.partyID)
                    }
            }
        }
        .dynamicTypeSize(ProcessInfo.processInfo.arguments.contains("--farm-accessibility") ? .accessibility3 : .large)
    }
}
#endif
