import SwiftUI

struct CampfireVisibilityButton: View {
    @ObservedObject var social: NightFlockViewModel
    var run: FocusRun? = nil
    var compact = false
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var showsChoice = false
    private var shareableRun: FocusRun? {
        guard let run, let end = CampfireRules.end(for: run), end > Date(),
              run.state != .completed, run.state != .endedEarly else { return nil }
        return run
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            let choice = Button { showsChoice = true } label: {
                Group {
                    if textSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Visibility").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                            Text(social.campfireVisibility.title).font(AppTypography.body)
                        }
                    } else {
                        HStack(spacing: AppSpacing.sm) {
                            Text("Visibility").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                            Text(social.campfireVisibility.title).font(compact ? AppTypography.caption : AppTypography.body)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.down").accessibilityHidden(true)
                        }
                    }
                }.fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, AppSpacing.sm)
            }.accessibilityValue(social.campfireVisibilityStatus(for: run))
            if compact {
                choice.buttonStyle(.plain).foregroundStyle(AppColors.grass)
            } else {
                choice.buttonStyle(PixelChipButtonStyle(isSelected: false))
            }
            if !compact || social.campfireVisibilityMessage != nil {
                Text(run == nil && social.campfireVisibilityMessage == nil ? "Applies to your next session" : social.campfireVisibilityStatus(for: run)).font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText).fixedSize(horizontal: false, vertical: true)
            }
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
    private var publicName: String { social.v4Profile?.displayName ?? "" }
    private var appearance: PublicCampfireAppearance {
        PublicCampfireAppearance(PersistenceService.shared.userProfile.presentation)
            .forServer(supportsWardrobe: social.globalCampfireState?.appearanceVersion == 1)
    }

    init(social: NightFlockViewModel, run: FocusRun? = nil) {
        self.social = social; self.run = run
        _choice = State(initialValue: social.campfireVisibility)
        _selected = State(initialValue: Set(social.selectedCampfirePartyIDs))
    }

    private var canSave: Bool {
        social.accountState == .linked && (choice != .party || !selected.isEmpty)
            && (choice != .global || (social.globalCampfireState?.supportsProfiles == true && !publicName.isEmpty))
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
                                    Text(option == .global && social.globalCampfireFailure == .unavailable ? "Global · unavailable" : option.title).font(AppTypography.headline)
                                }
                                Text(detail(option)).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                            }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        }.buttonStyle(.plain).disabled(option == .global && social.globalCampfireFailure == .unavailable && choice != .global).accessibilityAddTraits(choice == option ? .isSelected : [])
                    }
                    if choice != .off { parties }
                    if choice == .global { publicChoice }
                    if choice == .party && !selected.isEmpty { privateDisclosure }
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
                    Text("Remembered for new sessions. Browsing a campfire never changes your visibility. Turning visibility Off keeps your timer and Farm progress running.")
                        .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                    if run != nil {
                        Text("Your live session appears from now. If removal can’t sync, it may remain visible until its planned end.")
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
        case .off: return "You won’t appear at the Campfire. You can still look around."
        case .party: return "Only the Slumber Parties you choose below."
        case .global: return "Anyone at the Global Campfire, plus your selected parties."
        }
    }

    private var parties: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Your Slumber Parties").font(AppTypography.headline)
            if social.slumberParties.isEmpty {
                if let failure = social.listRefreshFailure {
                    Text(failure.title).font(AppTypography.caption)
                    Button("Reload your parties", action: social.retryNightFlockRequest).frame(minHeight: 44)
                } else {
                    Text("You haven’t joined a Slumber Party. Global Campfire doesn’t need one.").font(AppTypography.caption)
                }
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
            if social.globalCampfireState?.supportsProfiles == true {
                Text("Your Campfire profile").font(AppTypography.headline)
                HStack(spacing: AppSpacing.sm) {
                    SlumberPartySocialAvatarView(presentation: appearance.presentation, avatarID: "shepherd", size: 64)
                    Text(publicName.isEmpty ? "Your character name is loading…" : publicName).font(AppTypography.body)
                }
                Text("Global shares your character name and look, activities, tasks, Wind Down routines, current session and exact times, intention, recorded history, party names, Farm inventory and Farm appearance. Everyone at the Global Campfire and your selected parties can open your profile.")
                    .font(AppTypography.body)
                Text("Save Global to share these details, including your existing recorded history. Your profile is available while your session is shared. Off removes it when the change syncs.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            } else {
                Text(social.globalCampfireLoading ? "Checking Global Campfire…" : social.globalCampfireFailure?.title ?? (social.globalCampfireState?.isSupported == true ? "Campfire profiles are being updated. You can still browse." : "Global Campfire isn’t available right now.")).font(AppTypography.body)
                if let issue = social.globalCampfireFailure { Text(issue.detail).font(AppTypography.caption) }
                Button(social.globalCampfireFailure == .unavailable ? "Check availability" : "Check again") { social.refreshGlobalCampfire() }.frame(minHeight: 44)
            }
        }
    }

    private var privateDisclosure: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Shared with your selected parties").font(AppTypography.headline)
            Text("Your Shepherd, Wind Down or Phone Away, start and planned end, and optional activity. Where Campfire Buddies is available, it also shares a separately written intention, encouragement and optional check-in for up to seven days. Private tasks aren’t copied.")
                .font(AppTypography.body)
            if selected.contains(where: { social.v4ObservedPartyDetail(for: $0)?.pasture?.campfire?.supportsIntendedBedtime == true }) {
                Text("Your selected parties also receive your planned bedtime for a shared Wind Down. Your Shepherd settles into a sleeping bag then and stays by the campfire until the session ends or its planned wake time. Phone Away keeps its chosen activity at the campfire.")
                    .font(AppTypography.body)
            }
            Text("Saving this choice accepts Campfire sharing with the selected parties. Start invitations follow each member’s notification choices. Wind Down check-ins wait until morning quiet ends. Off removes live Campfire sharing; other agreed group records stay as they are.")
                .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
        }
    }
}

#Preview("Campfire visibility · signed out") {
    CampfireVisibilitySheet(social: NightFlockViewModel(featureEnabled: false)).dynamicTypeSize(.accessibility3)
}
