import AuthenticationServices
import SwiftUI

struct AccountCredentialsView: View {
    @ObservedObject var farm: FarmBackupViewModel
    @ObservedObject var model: PasswordAccountViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var enteredSignedOut = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text(title).font(AppTypography.title)
                if model.stage == .methods {
                    methods
                } else {
                    form
                }
                if let notice = model.notice {
                    Text(notice).font(AppTypography.body).accessibilityLabel(notice)
                }
                if farm.busy { ProgressView("Please wait…") }
            }
            .padding(AppSpacing.md)
            .foregroundStyle(AppColors.ink)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .onAppear { enteredSignedOut = !farm.signedIn }
        .onChange(of: farm.busy) { _, busy in
            if !busy && enteredSignedOut && farm.signedIn && model.stage == .methods { dismiss() }
        }
        .onDisappear { model.password = ""; model.code = "" }
    }

    private var title: String {
        switch model.stage {
        case .signIn: return "Sign in"
        case .register: return "Create account"
        case .verify, .verifyEmailChange: return "Verify your email"
        case .recover, .recoveryCode: return "Reset password"
        case .newPassword: return "Set password"
        case .claimUsername: return "Choose a username"
        case .methods: return "Sign-in and username"
        case .emailChange: return "Recovery email"
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            switch model.stage {
            case .signIn:
                input("Username or email", text: $model.identifier, type: .username)
                passwordField
            case .register:
                input("Email", text: $model.email, type: .emailAddress)
                input("Username", text: $model.username, type: .username)
                passwordField
                Text("3–24 letters, numbers or underscores. Start with a letter.").font(AppTypography.caption)
            case .verify, .recoveryCode:
                Text("Enter the code sent to \(model.email).").font(AppTypography.body)
                input("Email code", text: $model.code, type: .oneTimeCode)
            case .verifyEmailChange:
                Text("Confirm both email addresses to update your recovery email.").font(AppTypography.body)
                input("Email receiving this code", text: $model.verificationEmail, type: .emailAddress)
                input("Email code", text: $model.code, type: .oneTimeCode)
            case .recover, .emailChange:
                input("Email", text: $model.email, type: .emailAddress)
            case .newPassword:
                passwordField
                input("Security code, if requested", text: $model.code, type: .oneTimeCode)
            case .claimUsername:
                input("Username", text: $model.username, type: .username)
            case .methods: EmptyView()
            }
            if [.signIn, .register].contains(model.stage) {
                Text("Your account keeps your Farm in sync automatically.")
                    .font(AppTypography.body)
                FarmSyncDisclosure()
            }
            Button(actionTitle, action: model.submit)
                .buttonStyle(AccountPrimaryButtonStyle()).disabled(farm.busy || farm.appleSignInInProgress)
            if model.stage == .signIn {
                Button("Forgot password?") { model.stage = .recover }
                    .buttonStyle(AccountTextButtonStyle())
                Button("Create an account") { model.stage = .register }
                    .buttonStyle(AccountSecondaryButtonStyle())
            } else if [.verify, .recoveryCode, .newPassword, .verifyEmailChange].contains(model.stage) {
                Button("Send a new code", action: model.resend)
                    .buttonStyle(AccountSecondaryButtonStyle()).disabled(farm.busy || farm.appleSignInInProgress)
            }
            if !farm.signedIn && model.stage != .signIn {
                Button("Back to sign in") { model.stage = .signIn }
                    .buttonStyle(AccountTextButtonStyle()).disabled(farm.busy || farm.appleSignInInProgress)
            }
        }
    }

    private var actionTitle: String {
        switch model.stage {
        case .signIn: return "Sign in"
        case .register: return "Create account"
        case .verify, .recoveryCode, .verifyEmailChange: return "Verify code"
        case .recover: return "Send recovery code"
        case .newPassword: return "Save password"
        case .claimUsername: return "Use this username"
        case .emailChange: return "Verify new email"
        case .methods: return "Continue"
        }
    }

    private var methods: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if let profile = farm.credentialProfile {
                if let username = profile.username { Text("@\(username)").font(AppTypography.headline) }
                if let email = profile.email { Text(email).font(AppTypography.body) }
                if profile.hasApple { Label("Apple connected", systemImage: "checkmark.circle") }
                else {
                    SignInWithAppleButton(.continue, onRequest: { request in
                        farm.linkingApple = true
                        farm.prepareApple(request)
                    }, onCompletion: farm.completeApple)
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 50)
                }
                if profile.hasEmail {
                    Button("Set or change password") { model.stage = .newPassword }
                        .buttonStyle(AccountSecondaryButtonStyle())
                    Button("Change recovery email") { model.email = ""; model.stage = .emailChange }
                        .buttonStyle(AccountSecondaryButtonStyle())
                } else if let email = profile.email {
                    Button("Set password with \(email)") { model.email = email; model.stage = .newPassword }
                        .buttonStyle(AccountSecondaryButtonStyle())
                } else {
                    Button("Add recovery email to set a password") { model.email = ""; model.stage = .emailChange }
                        .buttonStyle(AccountSecondaryButtonStyle())
                }
                if !profile.usernameLookupSucceeded {
                    Text("Your username couldn’t be loaded.").font(AppTypography.caption)
                    Button("Check username", action: model.showMethods).buttonStyle(AccountTextButtonStyle())
                } else if profile.username == nil {
                    Button("Choose a username") { model.stage = .claimUsername }
                        .buttonStyle(AccountSecondaryButtonStyle())
                }
            } else {
                Button("Try again", action: model.showMethods).buttonStyle(AccountSecondaryButtonStyle())
            }
        }
        .disabled(farm.busy || farm.appleSignInInProgress)
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Password").font(AppTypography.body).foregroundStyle(AppColors.ink)
            Group {
                if model.showsPassword {
                    TextField("", text: $model.password,
                              prompt: Text("Password").foregroundStyle(AppColors.secondaryText))
                } else {
                    SecureField("", text: $model.password,
                                prompt: Text("Password").foregroundStyle(AppColors.secondaryText))
                }
            }
            .textContentType(model.stage == .signIn ? .password : .newPassword)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .font(AppTypography.body).foregroundStyle(AppColors.ink)
            .padding(AppSpacing.md).background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.sm))
            .accessibilityLabel("Password")
            Toggle("Show password", isOn: $model.showsPassword).font(AppTypography.caption)
        }
    }

    private func input(_ title: String, text: Binding<String>, type: UITextContentType) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title).font(AppTypography.body).foregroundStyle(AppColors.ink)
            TextField("", text: text, prompt: Text(title).foregroundStyle(AppColors.secondaryText)).textContentType(type)
            .keyboardType(type == .emailAddress ? .emailAddress : .default)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .font(AppTypography.body).padding(AppSpacing.md)
            .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.sm))
            .accessibilityLabel(title)
            .foregroundStyle(AppColors.ink)
        }
    }
}

struct FarmSyncDisclosure: View {
    var body: some View {
        DisclosureGroup("What syncs?") {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Sheep and their names, wool, cosmetics, Farm layout, searches and reward records—including Farm event dates and reward timing—are saved privately to your account with Supabase.")
                Text("Detailed Nights history, Health data, reflections, questionnaire answers, routines, app selections, tags and active timers stay on this device. Your Farm inventory isn’t shared with Slumber Party.")
                Text("Offline changes sync when a connection is available. Only confirmed saves can be recovered if you lose this phone.")
                Text("Data uses encryption in transit and provider encryption at rest, not end-to-end encryption. The current Farm stays until account deletion. Older copies are kept for 30 days and at least the latest ten revisions; unresolved conflicts remain until resolved or deleted.")
            }.font(AppTypography.caption).foregroundStyle(AppColors.secondaryText).padding(.top, AppSpacing.sm)
        }.font(AppTypography.body)
    }
}

#Preview("Password sign-in · dark") {
    let farm = FarmBackupViewModel(persistence: .shared, account: nil, service: nil)
    AccountCredentialsView(farm: farm, model: farm.credentials).preferredColorScheme(.dark)
}
