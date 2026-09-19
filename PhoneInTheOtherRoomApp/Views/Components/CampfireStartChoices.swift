import SwiftUI

struct CampfireStartChoices: View {
    @ObservedObject var viewModel: FocusRunViewModel
    private var social: NightFlockViewModel { viewModel.nightFlockViewModel }
    private var hasBuddies: Bool {
        social.selectedCampfirePartyIDs.contains { social.campfireAgreement(partyID: $0)?.version == 2 }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            CampfireVisibilityButton(social: social)
            if social.campfireVisibility != .off {
                if viewModel.pendingNightWatchIsAdditionalQuiet {
                    Picker("Campfire activity", selection: $viewModel.nextCampfireActivity) {
                        ForEach(CampfireActivity.allCases) { Text($0.title).tag($0) }
                    }
                }
                if hasBuddies {
                    TextField("Intention for your party", text: $viewModel.nextCampfireIntention,
                              prompt: Text("e.g. read one chapter"), axis: .vertical)
                        .textFieldStyle(.roundedBorder).lineLimit(1...3)
                        .onChange(of: viewModel.nextCampfireIntention) { _, value in
                            if value.unicodeScalars.count > 80 { viewModel.nextCampfireIntention = CampfireBuddiesRules.publicText(value) }
                        }
                    Toggle("Invite my parties when I start", isOn: $viewModel.nextCampfireAnnouncesStart)
                    Toggle("Ask for a check-in buddy", isOn: $viewModel.nextCampfireAsksForBuddy)
                    Text("This intention and buddy request go only to your selected parties. Global participants never receive this text.")
                        .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                }
            }
        }.font(AppTypography.body).tint(AppColors.grass)
            .task(id: social.slumberParties.map(\.partyID)) {
                _ = social.restoreCampfireVisibility()
                for party in social.slumberParties { social.refreshV4PartyObservation(party.partyID, refreshListAfterward: false) }
            }
    }
}
