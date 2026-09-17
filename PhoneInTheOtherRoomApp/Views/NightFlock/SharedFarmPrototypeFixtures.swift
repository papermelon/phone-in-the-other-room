import SwiftUI

/// Disposable data for the shared Farm prototype: previews and the isolated
/// `--shared-farm-prototype` launch route. Never a real account or Farm.
enum SharedFarmPrototypeFixtures {
    static let partyID = UUID(uuidString: "95000000-0000-4000-8000-000000000001")!
    static let me = UUID(uuidString: "95000000-0000-4000-8000-000000000002")!
    static let moss = UUID(uuidString: "95000000-0000-4000-8000-000000000003")!
    static let juniper = UUID(uuidString: "95000000-0000-4000-8000-000000000004")!
    static let rowan = UUID(uuidString: "95000000-0000-4000-8000-000000000005")!
    static let defaultsSuite = "com.ngawangchime.countingsheep.shared-farm-prototype"

    static var party: NightFlockV4PartyDetail {
        let now = Date()
        var clover = CountingSheepPublicPresentation.defaultValue
        clover.headShapeID = "round"
        clover.hairStyleID = "long"
        clover.shepherdOutfitID = "shepherd_moon_coat"
        clover.shepherdAccessoryID = "shepherd_moon_beanie"
        var mossLook = CountingSheepPublicPresentation.defaultValue
        mossLook.avatarID = "ollie"
        mossLook.ollieOrnamentID = "ollie_moss_bandana"
        var juniperLook = CountingSheepPublicPresentation.defaultValue
        juniperLook.avatarID = "sheep:pippin"
        var rowanLook = CountingSheepPublicPresentation.defaultValue
        rowanLook.headShapeID = "boxy"
        rowanLook.hairStyleID = "coils"
        rowanLook.skinToneID = ShepherdSkinTone.deep.rawValue
        rowanLook.shepherdOutfitID = "shepherd_field_overalls"

        let members: [NightFlockV4Membership] = [
            .init(memberID: me, profile: .init(displayName: "Clover", presentation: clover), role: .host, joinedAt: now.addingTimeInterval(-86_400 * 9)),
            .init(memberID: moss, profile: .init(displayName: "Moss", presentation: mossLook), role: .member, joinedAt: now.addingTimeInterval(-86_400 * 8)),
            .init(memberID: juniper, profile: .init(displayName: "Juniper", presentation: juniperLook), role: .member, joinedAt: now.addingTimeInterval(-86_400 * 6)),
            .init(memberID: rowan, profile: .init(displayName: "Rowan", presentation: rowanLook), role: .member, joinedAt: now.addingTimeInterval(-86_400 * 4))
        ]
        let updates: [NightFlockV4SharedActivity] = [
            .init(activityID: uuid(11), partyID: partyID, memberID: me, kind: .windDown, status: .completed, roundedMinutes: 30, occurredAt: now.addingTimeInterval(-86_400 - 3_600)),
            .init(activityID: uuid(12), partyID: partyID, memberID: moss, kind: .windDown, status: .completed, roundedMinutes: 45, occurredAt: now.addingTimeInterval(-86_400 - 1_800)),
            // A truthful zero: Juniper started Wind Down after bedtime and still completed it.
            .init(activityID: uuid(13), partyID: partyID, memberID: juniper, kind: .windDown, status: .completed, roundedMinutes: 0, occurredAt: now.addingTimeInterval(-86_400 * 2)),
            .init(activityID: uuid(14), partyID: partyID, memberID: rowan, kind: .phoneAway, status: .partlyCompleted, roundedMinutes: 15, occurredAt: now.addingTimeInterval(-86_400 * 3))
        ]
        var party = NightFlockV4PartyDetail(
            summary: .init(partyID: partyID, name: "Moonlit Neighbours", memberCount: members.count, myRole: .host,
                           currentRound: nil, revision: 3, sharingScope: .membership),
            myMemberID: me, memberships: members, sharedActivities: updates,
            sharedCheers: [.init(activityID: updates[0].id, cheer: .moonGlow, count: 1, sentByMe: false)]
        )
        party.updateCheerReceiptVersion = 1
        party.updateCheerReceipts = [.init(reactionID: uuid(21), activityID: updates[0].id, senderMemberID: moss, recipientMemberID: me,
                                           cheer: .moonGlow, acceptedAt: now.addingTimeInterval(-3_600), receivedByAppAt: now.addingTimeInterval(-3_500))]
        return party
    }

    static func members() -> [SharedFarmPrototypeStore.Member] {
        party.memberships.map { .init(memberID: $0.memberID, displayName: $0.profile.displayName) }
    }

    @MainActor
    static func store(seeded: Bool = true, defaults: UserDefaults? = nil) -> SharedFarmPrototypeStore {
        let suite = defaults ?? UserDefaults(suiteName: "\(defaultsSuite).\(UUID().uuidString)")!
        let store = SharedFarmPrototypeStore(partyID: partyID, myMemberID: me, members: members(), defaults: suite)
        guard seeded else { return store }
        let now = Date()
        store.seed(
            visits: [SharedFarmVisit(id: uuid(31), partyID: partyID, memberID: moss, sheepDefinitionID: "bramble", sheepDisplayName: "Bramble",
                                     sentAt: now.addingTimeInterval(-86_400 * 2))],
            greetings: [SharedFarmGreeting(id: uuid(41), partyID: partyID, senderMemberID: moss, recipientMemberID: me, cheer: .pawPrint,
                                           context: .update(activityID: uuid(11)), sentAt: now.addingTimeInterval(-3_000), delivery: .receivedByApp)]
        )
        return store
    }

    @MainActor
    static func viewModels(seeded: Bool = true) -> (app: FocusRunViewModel, social: NightFlockViewModel, store: SharedFarmPrototypeStore) {
        let defaults = UserDefaults(suiteName: "\(defaultsSuite).\(UUID().uuidString)")!
        let social = NightFlockViewModel(featureEnabled: true, previewPhase: .ready, previewAccountState: .linked, defaults: defaults)
        install(into: social)
        let app = FocusRunViewModel(persistence: PersistenceService(defaults: defaults), startsExternalServices: false,
                                    nightFlockViewModel: social, purposeCueDefaults: defaults)
        return (app, social, store(seeded: seeded, defaults: defaults))
    }

    @MainActor
    static func install(into social: NightFlockViewModel) {
        let party = party
        social.v4ListState = .init(parties: [party.summary], profileAvatarVersion: 1, sharedHabitsVersion: 1)
        social.v4ObservedPartyDetails[party.summary.partyID] = party
        social.v4ObservedPartyObservationStates[party.summary.partyID] = .current(lastReceivedAt: Date())
        social.v4ObservedPartyRefreshDates[party.summary.partyID] = Date()
        social.selectedV4Party = party
        social.sharedHabitsStates[party.summary.partyID] = sharedHabitsState()
    }

    /// Social avatars only show once the party's sharing agreement is
    /// accepted, so the fixture carries an accepted v1 agreement with sparse
    /// summaries: Moss shares sleep, Rowan shares nothing yet.
    private static func sharedHabitsState() -> NightFlockSharedHabitsStateResponse {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        let ending = NightFlockLocalDate(year: components.year ?? 2026, month: components.month ?? 9, day: components.day ?? 12)
        let periods: [NightFlockSharedHabitPeriodSummary] = [
            .init(memberID: moss, kind: .sleep, period: .lastNight, endingOn: ending, availableNights: 1, coveredNights: 1, averageMinutes: 431, method: "eligibleMean"),
            .init(memberID: moss, kind: .sleep, period: .last7Nights, endingOn: ending, availableNights: 7, coveredNights: 5, averageMinutes: 418, method: "eligibleMean"),
            .init(memberID: moss, kind: .windDown, period: .last7Nights, endingOn: ending, availableNights: 7, coveredNights: 4, averageMinutes: 38, method: "eligibleMean"),
            .init(memberID: juniper, kind: .windDown, period: .last7Nights, endingOn: ending, availableNights: 7, coveredNights: 2, averageMinutes: 12, method: "eligibleMean")
        ]
        return NightFlockSharedHabitsStateResponse(
            agreement: .init(agreementID: uuid(51), memberEpochID: uuid(52), acceptedAt: now.addingTimeInterval(-86_400 * 5),
                             timeZoneIdentifier: TimeZone.current.identifier, firstEligibleSleepNight: ending),
            records: [], nextCursor: nil, snapshotRevision: 1, periods: periods
        )
    }

    private static func uuid(_ suffix: Int) -> UUID {
        UUID(uuidString: String(format: "95000000-0000-4000-8000-%012d", suffix))!
    }
}

#if DEBUG
/// `--shared-farm-prototype` boots the ordinary four-tab shell on disposable
/// data with the prototype store injected. Optional flags:
/// `--prototype-fail-first-send`, `--prototype-accessibility`, `--prototype-unseeded`.
struct SharedFarmPrototypeFixture: View {
    @StateObject private var appModel: FocusRunViewModel
    @StateObject private var store: SharedFarmPrototypeStore
    @State private var showsSimulationBar = true

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let app = ScreenbookFixtures.makeViewModel(for: .configuredHome)
        SharedFarmPrototypeFixtures.install(into: app.nightFlockViewModel)
        let defaults = UserDefaults(suiteName: SharedFarmPrototypeFixtures.defaultsSuite)!
        defaults.removePersistentDomain(forName: SharedFarmPrototypeFixtures.defaultsSuite)
        let store = SharedFarmPrototypeFixtures.store(seeded: !arguments.contains("--prototype-unseeded"), defaults: defaults)
        store.failsNextSend = arguments.contains("--prototype-fail-first-send")
        _appModel = StateObject(wrappedValue: app)
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        Group {
            if arguments.contains("--prototype-home-section") {
                // Isolated capture of Home's Slumber Party card, which sits
                // below the fold on small phones and cannot be scrolled headlessly.
                ScrollView {
                    SlumberPartyHomeSection(viewModel: appModel.nightFlockViewModel, openParty: { _ in })
                        .padding(AppSpacing.md)
                }
                .background(AppColors.paper.ignoresSafeArea())
            } else if arguments.contains("--prototype-meadow-section") {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        SlumberPartySharedMeadowView(
                            party: SharedFarmPrototypeFixtures.party, showsSocialAvatar: true, store: store,
                            isWindDownActive: arguments.contains("--prototype-wind-down-active"),
                            onSelectMember: { _ in }, onGreetingCandidate: { _ in }, onSendVisit: {})
                        SharedFarmForYouSection(party: SharedFarmPrototypeFixtures.party, store: store, onOpenUpdate: { _, _ in })
                    }
                    .padding(AppSpacing.md)
                }
                .background(AppColors.paper.ignoresSafeArea())
            } else {
                HomeView(initialTab: initialTab, farmVisitSeed: 47, activeRunNow: nil,
                         dashboardWatch: appModel.coordinator.watch, allowsLaunchRouting: false)
            }
        }
            .environmentObject(appModel)
            .environment(\.sharedFarmPrototype, store)
            .environment(\.locale, Locale(identifier: "en_SG"))
            .dynamicTypeSize(arguments.contains("--prototype-accessibility") ? .accessibility3 : .large)
            .overlay(alignment: .topTrailing) { simulationBar }
            .task { await runScriptedRoute() }
    }

    private var arguments: [String] { ProcessInfo.processInfo.arguments }

    private var initialTab: MainAppTab {
        // The party route starts on Home: reselecting Farm resets its navigation path.
        arguments.contains("--prototype-open-farm") ? .farm : .home
    }

    /// Screenshot routes for headless Simulator runs, where no touch automation
    /// is available. Each step mirrors what a tap would do.
    private func runScriptedRoute() async {
        guard arguments.contains("--prototype-open-party") else {
            if arguments.contains("--prototype-friend-reply") {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                simulateReply()
            }
            return
        }
        // Long enough for the shell to settle on a busy machine; the Farm tab
        // must exist before its navigation destination can present.
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        NotificationCenter.default.post(name: .countingSheepShowNightFlock, object: SharedFarmPrototypeFixtures.partyID)
        try? await Task.sleep(nanoseconds: 4_000_000_000)
        if let name = arguments.first(where: { $0.hasPrefix("--prototype-open-card=") })?.split(separator: "=").last {
            let member: UUID? = switch name {
            case "moss": SharedFarmPrototypeFixtures.moss
            case "juniper": SharedFarmPrototypeFixtures.juniper
            case "rowan": SharedFarmPrototypeFixtures.rowan
            case "me": SharedFarmPrototypeFixtures.me
            default: nil
            }
            if let member {
                if arguments.contains("--prototype-sent-greeting") {
                    // Mirrors a confirmed send on Moss's latest update so delivery rows are visible.
                    store.sendGreeting(to: member, cheer: .pawPrint,
                                       context: .update(activityID: UUID(uuidString: "95000000-0000-4000-8000-000000000012")!))
                }
                NotificationCenter.default.post(name: .sharedFarmPrototypeOpenCard, object: member,
                                                userInfo: ["suggested": arguments.contains("--prototype-suggest-greeting")])
            }
        } else if arguments.contains("--prototype-open-visit-picker") {
            NotificationCenter.default.post(name: .sharedFarmPrototypeOpenVisitPicker, object: nil)
        }
        if arguments.contains("--prototype-friend-reply") {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            simulateReply()
        }
    }

    private func simulateReply() {
        store.simulateFriendActivity(from: SharedFarmPrototypeFixtures.moss, sheepDefinitionID: "bramble", sheepDisplayName: "Bramble",
                                     cheer: .warmWave, context: .meadow)
    }

    /// Stands in for the second phone. It is part of the fixture, not the product.
    @ViewBuilder private var simulationBar: some View {
        if showsSimulationBar, !arguments.contains("--prototype-hide-controls") {
            HStack(spacing: AppSpacing.xs) {
                Button("Moss replies") { simulateReply() }
                Button {
                    showsSimulationBar = false
                } label: {
                    Image(systemName: "xmark").accessibilityLabel("Hide prototype controls")
                }
            }
            .buttonStyle(.plain)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppColors.ink)
            .padding(.horizontal, AppSpacing.sm)
            .frame(minHeight: 32)
            .background(AppColors.paper.opacity(0.92), in: Capsule())
            .overlay(Capsule().stroke(AppColors.stroke, lineWidth: 1))
            .padding(.trailing, AppSpacing.sm)
            .padding(.top, AppSpacing.xxs)
        }
    }
}

extension Notification.Name {
    /// DEBUG-only scripted routes for the shared Farm prototype fixture.
    static let sharedFarmPrototypeOpenCard = Notification.Name("sharedFarmPrototype.openCard")
    static let sharedFarmPrototypeOpenVisitPicker = Notification.Name("sharedFarmPrototype.openVisitPicker")
}
#endif
