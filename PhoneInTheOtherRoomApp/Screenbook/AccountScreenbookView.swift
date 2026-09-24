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
            let arguments = ProcessInfo.processInfo.arguments
            let pending = arguments.contains("-screenbook-account-pending")
            model.credentials.stage = .signIn
            model.needsSyncAgreement = arguments.contains("-screenbook-account-migration")
            model.signedIn = !passwordForm
            model.accountPresentation = .backupConfirmed(ScreenbookFixtures.now(for: .configuredHome))
            let owner = UUID()
            model.credentialProfile = AccountCredentialProfile(id: owner, email: "shepherd@example.com",
                username: arguments.contains("-screenbook-account-no-handle") ? nil : "shepherd", hasApple: true, hasEmail: false)
            if pending {
                model.signedIn = false
                model.authenticatedAccountID = owner
                model.accountPresentation = .failed
                model.appleSignInFailure = .init(stage: .farm)
            }
        }
    }
}
#endif
