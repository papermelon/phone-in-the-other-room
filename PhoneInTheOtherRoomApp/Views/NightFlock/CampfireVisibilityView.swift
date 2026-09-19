import SwiftUI

struct CampfireVisibilityButton: View {
    @ObservedObject var social: NightFlockViewModel
    var run: FocusRun? = nil
    @State private var showsChoice = false
    private var shareableRun: FocusRun? {
        guard let run, let end = CampfireRules.end(for: run), end > Date(),
              run.state != .completed, run.state != .endedEarly else { return nil }
        return run
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Button { showsChoice = true } label: {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("My visibility").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                    Text(social.campfireVisibility.title).font(AppTypography.body)
                }.fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, AppSpacing.sm)
            }.buttonStyle(PixelChipButtonStyle(isSelected: false))
            Text(run == nil && social.campfireVisibilityMessage == nil ? "Applies to your next session" : social.campfireVisibilityStatus(for: run)).font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText).fixedSize(horizontal: false, vertical: true)
            if !social.campfireDocument.commands.isEmpty {
                Button("Retry visibility change") { social.drainGlobalCampfireCommands(retry: true) }
                    .font(AppTypography.caption).frame(minHeight: 44)
            }
        }
        .tint(AppColors.grass)
        .sheet(isPresented: $showsChoice) { CampfireVisibilitySheet(social: social, run: shareableRun) }
        .task { _ = social.restoreCampfireVisibility() }
    }
}

struct CampfireVisibilitySheet: View {
    @ObservedObject var social: NightFlockViewModel
    var run: FocusRun?
    @Environment(\.dismiss) private var dismiss
    @State private var choice: CampfireVisibility
    @State private var selected: Set<UUID>
    @State private var publicName: String
    private var appearance: PublicCampfireAppearance { PublicCampfireAppearance(social.v4Profile?.presentation ?? .defaultValue) }

    init(social: NightFlockViewModel, run: FocusRun? = nil) {
        self.social = social; self.run = run
        _choice = State(initialValue: social.campfireVisibility)
        _selected = State(initialValue: Set(social.selectedCampfirePartyIDs))
        _publicName = State(initialValue: social.campfireDocument.publicName)
    }

    private var canSave: Bool {
        social.accountState == .linked && (choice != .party || !selected.isEmpty)
            && (choice != .global || social.globalCampfireState?.isSupported == true)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Text("Who can see your session?").font(AppTypography.headline)
                    ForEach(CampfireVisibility.allCases) { option in
                        Button { choice = option; if option == .party && selected.isEmpty, let first = social.slumberParties.first { selected.insert(first.partyID) } } label: {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                HStack(alignment: .top, spacing: AppSpacing.sm) {
                                    Image(systemName: choice == option ? "largecircle.fill.circle" : "circle")
                                        .font(AppTypography.headline).dynamicTypeSize(...DynamicTypeSize.xxxLarge).accessibilityHidden(true)
                                    Text(option.title).font(AppTypography.headline)
                                }
                                Text(detail(option)).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                            }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        }.buttonStyle(.plain).accessibilityAddTraits(choice == option ? .isSelected : [])
                    }
                    if choice != .off { parties }
                    if choice == .global { publicChoice }
                    if choice != .off && !selected.isEmpty { privateDisclosure }
                    if let message = social.campfireVisibilityMessage {
                        Text(message).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                    }
                    if social.accountState != .linked {
                        Text("Sign in from Settings to share a session. Your timer works with visibility Off.")
                            .font(AppTypography.body)
                    }
                    Button(run != nil && choice != .off ? "Share this session from now" : "Save visibility") {
                        if social.chooseCampfireVisibility(choice, partyIDs: Array(selected), run: run,
                            publicName: publicName, appearance: appearance) { dismiss() }
                    }.buttonStyle(PixelPrimaryButtonStyle()).disabled(!canSave)
                    Text("Remembered for new sessions. Browsing a fire never changes your visibility. Turning visibility Off keeps your timer and Farm progress running.")
                        .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                    if run != nil {
                        Text("Sharing starts from your choice now. Earlier private activity isn’t added. If removal can’t sync, your last shared session may remain until its planned end.")
                            .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                    }
                }.padding(AppSpacing.md)
            }.background(AppColors.paper.ignoresSafeArea())
                .navigationTitle("Campfire visibility").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .task {
                    _ = social.restoreCampfireVisibility()
                    social.refreshGlobalCampfire()
                    for party in social.slumberParties { social.refreshV4PartyObservation(party.partyID, refreshListAfterward: false) }
                }
        }.tint(AppColors.grass)
    }

    private func detail(_ option: CampfireVisibility) -> String {
        switch option {
        case .off: return "You won’t appear at either fire. You can still look around."
        case .party: return "Only the Slumber Parties you choose below."
        case .global: return "Anyone at the global fire, plus your selected parties. Private group details stay private."
        }
    }

    private var parties: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Your Slumber Parties").font(AppTypography.headline)
            if social.slumberParties.isEmpty {
                Text("You haven’t joined a Slumber Party. Global Campfire doesn’t need one.").font(AppTypography.caption)
            }
            ForEach(social.slumberParties, id: \.partyID) { party in
                Toggle(party.name, isOn: Binding(get: { selected.contains(party.partyID) }, set: { enabled in
                    if enabled { selected.insert(party.partyID) } else { selected.remove(party.partyID) }
                })).font(AppTypography.body)
            }
        }
    }

    private var publicChoice: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if social.globalCampfireState?.isSupported == true {
                Text("Your public card").font(AppTypography.headline)
                HStack(spacing: AppSpacing.sm) {
                    SlumberPartySocialAvatarView(presentation: appearance.presentation, avatarID: "shepherd", size: 64)
                    Picker("Public name", selection: $publicName) {
                        ForEach(PublicCampfireName.choices, id: \.self) { Text($0).tag($0) }
                    }.font(AppTypography.body)
                }
                Text("Global shares this chosen name and Shepherd, your session type, a preset activity and a rough time left. No exact times, private intentions, party names, history, Health or Farm inventory.")
                    .font(AppTypography.body)
                Text("These are app-reported sessions. They don’t prove sleep or where a phone is. Public presence ends with the session or when removal syncs. By saving Global, you accept this public sharing choice.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            } else {
                Text(social.globalCampfireLoading ? "Checking Global Campfire…" : "Global Campfire isn’t available right now.").font(AppTypography.body)
                Button("Check again") { social.refreshGlobalCampfire() }.frame(minHeight: 44)
            }
        }
    }

    private var privateDisclosure: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Shared with your selected parties").font(AppTypography.headline)
            Text("Your Shepherd, Wind Down or Phone Away, start and planned end, and optional activity. Where Campfire Buddies is available, it also shares a separately written intention, encouragement and optional check-in for up to seven days. Private tasks aren’t copied.")
                .font(AppTypography.body)
            Text("Saving this choice accepts Campfire sharing with the selected parties. Start invitations follow each member’s notification choices. Wind Down check-ins wait until morning quiet ends. Off removes live Campfire sharing; other agreed group records stay as they are.")
                .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
        }
    }
}

#Preview("Campfire visibility · signed out") {
    CampfireVisibilitySheet(social: NightFlockViewModel(featureEnabled: false)).dynamicTypeSize(.accessibility3)
}
