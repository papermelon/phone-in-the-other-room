import SwiftUI

struct RitualReflectionInvitation: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    var body: some View {
        if !viewModel.personalisationLoadFailed,
           viewModel.personalisation.invitationAvailable(now: viewModel.nowProvider(), isActive: viewModel.personalisationIsActive) {
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Is your routine helping?").font(AppTypography.headline)
                    NavigationLink("Reflect for a moment") { RitualPersonalisationView() }.frame(minHeight: 44)
                    Button("Not this week") { viewModel.dismissPersonalisationInvitation() }.frame(minHeight: 44)
                }
            }
        }
    }
}
