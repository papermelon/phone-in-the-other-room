#if DEBUG
import SwiftUI

/// Local harness for the three study surfaces. It owns fixture selection and
/// the intent log; it never touches production routing, view models or stores.
struct SocialExperienceStudyRoot: View {
    enum Surface: String, CaseIterable, Identifiable {
        case home, party, campfire
        var id: String { rawValue }
        var title: String {
            switch self {
            case .home: return "Home cards"
            case .party: return "Slumber Party"
            case .campfire: return "Campfire"
            }
        }
    }

    @State private var fixture: SocialStudyFixture
    @State private var surface: Surface
    @State private var person: StudyPersonSelection?
    @State private var showsInventory = false
    @StateObject private var log = SocialStudyActionLog()
    var showsChrome = true
    /// Sheets don't inherit a `dynamicTypeSize` override from the presenter,
    /// so the harness reapplies it to presented cards for large-text captures.
    var typeOverride: DynamicTypeSize?
    var scrollsToBottom = false

    init(fixture: SocialStudyFixture = .twoSessions, surface: Surface = .party, personID: UUID? = nil, showsChrome: Bool = true,
         typeOverride: DynamicTypeSize? = nil, scrollsToBottom: Bool = false) {
        _fixture = State(initialValue: fixture)
        _surface = State(initialValue: surface)
        _person = State(initialValue: personID.map(StudyPersonSelection.init))
        self.showsChrome = showsChrome
        self.typeOverride = typeOverride
        self.scrollsToBottom = scrollsToBottom
    }

    private var scenario: SocialStudyScenario { fixture.scenario }

    var body: some View {
        NavigationStack {
            Group {
                switch surface {
                case .home: homeSketch
                case .party: SlumberPartyHomeStudyView(scenario: scenario, send: log.record, onOpenPerson: { person = .init(id: $0) }, scrollsToBottom: scrollsToBottom)
                case .campfire: CampfireStudyView(scenario: scenario, send: log.record, onOpenPerson: { person = .init(id: $0) }, scrollsToBottom: scrollsToBottom)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if showsChrome {
                    VStack(spacing: AppSpacing.xs) {
                        StudyActionToast(log: log)
                        PixelSegmentedPicker(title: "Surface", selection: $surface) { $0.title }.padding(.horizontal, AppSpacing.md)
                    }
                    .padding(.vertical, AppSpacing.xs).background(AppColors.paper.opacity(0.96))
                }
            }
            .toolbar {
                if showsChrome {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Picker("Fixture", selection: $fixture) { ForEach(SocialStudyFixture.allCases) { Text($0.title).tag($0) } }
                            Divider()
                            Button("Interaction inventory") { showsInventory = true }
                        } label: { Label("Fixture", systemImage: "slider.horizontal.3") }
                    }
                }
            }
        }
        .sheet(item: $person) { selection in
            SocialPersonCardStudyView(scenario: scenario, personID: selection.id, send: log.record)
                .dynamicTypeSize(typeOverride.map { $0...$0 } ?? DynamicTypeSize.xSmall...DynamicTypeSize.accessibility5)
        }
        .sheet(isPresented: $showsInventory) { StudyInteractionInventory() }
    }

    /// Where the two entries sit on Home, so labels agree with their destinations.
    private var homeSketch: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Home entry-card sketch").font(AppTypography.headline)
                Text(scenario.summary).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText).fixedSize(horizontal: false, vertical: true)
                SlumberPartyHomeEntryCardStudy(scenario: scenario) { surface = .party }
                CampfireHomeEntryCardStudy(scenario: scenario) { surface = .campfire }
                StudyTruthLine(text: "Both cards sit below the personal Wind Down start on Home. Slumber Party opens the private group; Campfire opens public discovery. Neither card claims presence from stale data.")
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Home").navigationBarTitleDisplayMode(.inline)
    }
}

/// Sheet item wrapper so the harness doesn't add a retroactive conformance to UUID.
struct StudyPersonSelection: Identifiable, Equatable {
    let id: UUID
}

/// Every semantic action with its integration note, readable inside the app.
struct StudyInteractionInventory: View {
    @Environment(\.dismiss) private var dismiss
    private let sample = UUID()
    private var actions: [(String, SocialStudyAction)] {
        [("Start a session with an audience", .startSession(.windDown, .myParties)), ("Review audience", .reviewAudience),
         ("Accept public agreement", .acceptPublicAgreement), ("Join with my own timer", .joinWithOwnSession(sample, .windDown)),
         ("Back to running session", .backToRunningSession), ("Send fixed encouragement", .encourage(sample)),
         ("Offer to check in (party buddy)", .offerCheckIn(sample)), ("Ask how it went", .askHowItWent(sample)),
         ("Acknowledge a shared result", .acknowledgeResult(sample)), ("Share my check-in", .shareCheckIn(sample, .didIt)),
         ("Open Members", .openMembers), ("Open Shared meadow", .openMeadow), ("Open Our next improvement", .openImprovement),
         ("Open a person", .openPerson(sample)), ("Send a sheep", .sendSheep(sample)), ("Bring a sheep home", .recallSheep(sample)),
         ("Request connection", .requestConnection(sample)), ("Respond to connection", .respondToConnection(sample, accept: true)),
         ("Invite connection to a party", .inviteToParty(sample)), ("Block", .block(sample)), ("Report", .report(sample)),
         ("Retry / refresh", .retry), ("Change gathering", .changeGathering("Reading")),
         ("Suggest a shared evening plan", .suggestEveningPlan), ("Choose a next-round adjustment", .adjustNextRound("earlier"))]
    }

    var body: some View {
        NavigationStack {
            List(actions, id: \.0) { title, action in
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    HStack {
                        Text(title).font(AppTypography.body.weight(.semibold))
                        Spacer()
                        Text(action.isProposal ? "PROPOSAL" : "EXISTING").font(pixelFont(.caption2))
                            .foregroundStyle(action.isProposal ? AppColors.lavender : AppColors.grass)
                    }
                    switch action.integration {
                    case let .existing(note), let .proposal(note):
                        Text(note).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                    }
                }
            }
            .navigationTitle("Interaction inventory").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

/// Launch-argument entry for native screenshots on a Simulator:
/// `--social-study --social-study-state=<fixture> --social-study-surface=<home|party|campfire|person|public-person>`
/// with optional `--social-study-large` and `--social-study-bottom`. Not wired into release navigation.
struct SocialExperienceStudyNativeFixture: View {
    private let fixture: SocialStudyFixture
    private let surface: SocialExperienceStudyRoot.Surface
    private let personID: UUID?
    private let large: Bool
    private let bottom: Bool

    init() {
        let args = ProcessInfo.processInfo.arguments
        func value(_ key: String) -> String? { args.first { $0.hasPrefix(key + "=") }?.dropFirst(key.count + 1).description }
        fixture = SocialStudyFixture(rawValue: value("--social-study-state") ?? "") ?? .twoSessions
        let requested = value("--social-study-surface") ?? "party"
        let scenario = fixture.scenario
        switch requested {
        case "person":
            surface = .party
            personID = scenario.group.sessions.first { $0.personID != scenario.group.myID }?.personID ?? scenario.group.members.dropFirst().first?.id
        case "public-person":
            surface = .campfire
            personID = scenario.campfire.participants.first?.id
        default:
            surface = SocialExperienceStudyRoot.Surface(rawValue: requested) ?? .party
            personID = nil
        }
        large = args.contains("--social-study-large")
        bottom = args.contains("--social-study-bottom")
    }

    var body: some View {
        SocialExperienceStudyRoot(fixture: fixture, surface: surface, personID: personID, showsChrome: false,
                                  typeOverride: large ? .accessibility5 : nil, scrollsToBottom: bottom)
            .dynamicTypeSize(large ? .accessibility5 : .large)
    }
}

// MARK: - Previews

#Preview("Party · two sessions") { SocialExperienceStudyRoot(fixture: .twoSessions, surface: .party) }
#Preview("Party · quiet") { SocialExperienceStudyRoot(fixture: .quiet, surface: .party) }
#Preview("Party · eight people · dark") { SocialExperienceStudyRoot(fixture: .eightPeople, surface: .party).preferredColorScheme(.dark) }
#Preview("Party · return check-in") { SocialExperienceStudyRoot(fixture: .returnCheckIn, surface: .party) }
#Preview("Party · failed · AX5") { SocialExperienceStudyRoot(fixture: .failed, surface: .party).dynamicTypeSize(.accessibility5) }
#Preview("Campfire · eight people") { SocialExperienceStudyRoot(fixture: .eightPeople, surface: .campfire) }
#Preview("Campfire · sharing off · dark") { SocialExperienceStudyRoot(fixture: .sharingOff, surface: .campfire).preferredColorScheme(.dark) }
#Preview("Campfire · quiet") { SocialExperienceStudyRoot(fixture: .quiet, surface: .campfire) }
#Preview("Campfire · stale") { SocialExperienceStudyRoot(fixture: .stale, surface: .campfire) }
#Preview("Campfire · loading · AX5") { SocialExperienceStudyRoot(fixture: .loading, surface: .campfire).dynamicTypeSize(.accessibility5) }
#Preview("Person · party buddy") {
    SocialExperienceStudyRoot(fixture: .twoSessions, surface: .party, personID: SocialStudyFixtures.papa)
}
#Preview("Person · public · connected") {
    SocialExperienceStudyRoot(fixture: .returnCheckIn, surface: .campfire, personID: SocialStudyFixtures.publicIDs[1])
}
#Preview("Home cards · stale") { SocialExperienceStudyRoot(fixture: .stale, surface: .home) }
#endif
