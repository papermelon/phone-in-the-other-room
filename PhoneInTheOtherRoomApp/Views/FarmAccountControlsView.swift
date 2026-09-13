import SwiftUI

struct FarmAccountControlsView: View {
    @ObservedObject var account: NightFlockViewModel
    @ObservedObject var backup: FarmBackupViewModel
    @State private var confirmsDeletion = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Delete account").font(AppTypography.title)
                Text("This permanently deletes your account, its online Farm and account-owned Slumber Party data covered by deletion.")
                Text("Your account’s Farm and recovery copies will also be removed from this phone.")
                Button("Delete account", role: .destructive) { confirmsDeletion = true }
                    .buttonStyle(AccountTextButtonStyle(destructive: true))
                    .disabled(backup.busy || account.accountState != .linked || !account.permitsNightFlockNetwork)
                if let notice = account.warmNotice { Text(notice) }
                if case .error(let message) = account.phase { Text(message) }
            }.font(AppTypography.body).foregroundStyle(AppColors.ink).padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .task { await account.inspectAccountForFarm() }
        .confirmationDialog("Permanently delete your account?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) { account.deleteOnlineAccount() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This cannot be undone.") }
    }
}

#Preview("Account deletion · unavailable") {
    FarmAccountControlsView(account: NightFlockViewModel(featureEnabled: false),
        backup: FarmBackupViewModel(persistence: .shared, account: nil, service: nil))
}
