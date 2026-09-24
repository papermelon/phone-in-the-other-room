import SwiftUI

/// The navigation shell is destroyed on logout so an old pushed Farm or profile
/// cannot remain visible underneath the next account.
struct AccountAccessGate<Content: View>: View {
    @ObservedObject var model: FarmBackupViewModel
    @ViewBuilder var content: () -> Content

    var body: some View {
        Group {
            if model.accessBlocked {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppSpacing.lg) {
                            Text("Welcome back").font(AppTypography.title)
                            if model.isFinishingSignOut {
                                Text("Your Farm is closed. Finish signing out before using another account or playing as a guest.")
                                    .font(AppTypography.body)
                                Button("Finish signing out", action: model.refresh)
                                    .buttonStyle(AccountPrimaryButtonStyle()).disabled(model.busy)
                                if model.busy { SheepLoadingView() }
                                if model.accountPresentation == .failed { Text(model.message).font(AppTypography.body) }
                            } else {
                                AccountConnectionContent(model: model)
                                Button("Continue as guest", action: model.continueAsGuest)
                                    .buttonStyle(AccountTextButtonStyle()).disabled(model.busy || model.appleSignInInProgress)
                                FarmSyncDisclosure()
                            }
                        }.padding(AppSpacing.md).foregroundStyle(AppColors.ink)
                    }.background(AppColors.paper.ignoresSafeArea())
                }
            } else { content() }
        }
        .task { if model.available && model.accessBlocked { model.refresh() } }
    }
}

#Preview("Signed out") {
    let model = FarmBackupViewModel(persistence: .shared, account: nil, service: nil)
    AccountAccessGate(model: model) { Text("Farm") }
}
