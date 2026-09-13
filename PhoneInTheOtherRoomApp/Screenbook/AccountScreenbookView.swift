#if DEBUG
import SwiftUI

struct AccountScreenbookView: View {
    @ObservedObject var model: FarmBackupViewModel
    let account: NightFlockViewModel
    private var passwordForm: Bool { ProcessInfo.processInfo.arguments.contains("-screenbook-account-password") }

    var body: some View {
        NavigationStack {
            if passwordForm {
                AccountCredentialsView(farm: model, model: model.credentials)
            } else {
                FarmBackupView(account: account, model: model)
            }
        }
        .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("-screenbook-account-dark") ? .dark : .light)
        .environment(\.dynamicTypeSize, ProcessInfo.processInfo.arguments.contains("-screenbook-account-accessibility") ? .accessibility3 : .large)
        .onAppear {
            guard !model.available else { return }
            model.credentials.stage = .signIn
            model.needsSyncAgreement = ProcessInfo.processInfo.arguments.contains("-screenbook-account-migration")
            model.signedIn = !passwordForm
            model.accountPresentation = .backupConfirmed(ScreenbookFixtures.now(for: .configuredHome))
            model.credentialProfile = AccountCredentialProfile(id: UUID(), email: "shepherd@example.com",
                username: "shepherd", hasApple: true, hasEmail: false)
        }
    }
}
#endif
