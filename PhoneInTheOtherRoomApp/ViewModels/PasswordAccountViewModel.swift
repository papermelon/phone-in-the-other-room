import Foundation

@MainActor
final class PasswordAccountViewModel: ObservableObject {
    enum Stage: String { case signIn, register, verify, recover, recoveryCode, newPassword, claimUsername, methods, emailChange, verifyEmailChange }
    private enum PendingSignupPhase: String { case verification, claimUsername }

    @Published var stage: Stage = .signIn
    @Published var identifier = ""
    @Published var email = ""
    @Published var username = ""
    @Published var password = ""
    @Published var code = ""
    @Published var notice: String?
    @Published var showsPassword = false
    @Published var verificationEmail = ""
    @Published private(set) var emailChangeCurrentEmail = ""

    private unowned let farm: FarmBackupViewModel
    private let defaults: UserDefaults
    private let pendingKey = "ollie.account.pendingVerification"
    private let pendingEmailChangeKey = "ollie.account.pendingEmailChange"

    init(farm: FarmBackupViewModel, defaults: UserDefaults = .standard) {
        self.farm = farm
        self.defaults = defaults
        if let pending = pendingSignup() {
            email = pending.email
            username = pending.username
            verificationEmail = pending.email
            stage = pending.phase == .claimUsername ? .claimUsername : .verify
        } else if let pending = pendingEmailChange() {
            email = pending.targetEmail
            emailChangeCurrentEmail = pending.currentEmail
            verificationEmail = pending.nextAddress
            stage = .verifyEmailChange
        }
    }

    func submit() {
        guard !farm.busy else { return }
        let password = self.password
        let code = self.code.trimmingCharacters(in: .whitespacesAndNewlines)
        self.password = ""
        notice = nil
        farm.perform { [self] in
            do {
                guard let account = farm.account, farm.canRestore?() == true else { throw AccountCredentialError.unavailable }
                switch stage {
                case .signIn:
                    guard await farm.prepareAccount?() != false else { throw AccountCredentialError.unavailable }
                    try await account.signInWithPassword(identifier: identifier, password: password)
                    try await farm.completeAccountConnection(acceptSync: true)
                    try await resumePendingUsernameClaimIfAuthenticated(account)
                    if stage == .signIn { stage = .methods }
                case .register:
                    guard password.count >= 12 else { notice = "Use at least 12 characters, including uppercase and lowercase letters and a number."; return }
                    guard await farm.prepareAccount?() != false else { throw AccountCredentialError.unavailable }
                    let verified = try await account.registerPassword(email: email, password: password, username: username)
                    savePendingSignup(email: email, username: username, phase: verified ? .claimUsername : .verification)
                    verificationEmail = email
                    stage = verified ? .claimUsername : .verify
                    if verified { try await finishRegistration(account) }
                    else { notice = "Enter the code from your confirmation email." }
                case .verify:
                    try await account.verifyEmailCode(email: email, code: code)
                    savePendingSignup(email: email, username: username, phase: .claimUsername)
                    stage = .claimUsername
                    try await finishRegistration(account)
                case .claimUsername:
                    try await finishRegistration(account)
                case .recover:
                    try await account.sendPasswordRecovery(email: email)
                    stage = .recoveryCode
                    notice = "If this email has an account, a recovery code is on its way."
                case .recoveryCode:
                    guard await farm.prepareAccount?() != false else { throw AccountCredentialError.unavailable }
                    try await account.verifyEmailCode(email: email, code: code, recovery: true)
                    stage = .newPassword
                    self.code = ""
                case .newPassword:
                    guard password.count >= 12 else { notice = "Use at least 12 characters, including uppercase and lowercase letters and a number."; return }
                    try await account.changePassword(password, nonce: code.isEmpty ? nil : code)
                    try await farm.completeAccountConnection(acceptSync: true)
                    notice = "Password updated."
                    stage = .methods
                case .emailChange:
                    let profile = try await account.credentialProfile()
                    let currentEmail = profile.email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          currentEmail.isEmpty || !sameEmail(currentEmail, email) else { throw AccountCredentialError.verifyEmail }
                    emailChangeCurrentEmail = currentEmail
                    verificationEmail = currentEmail.isEmpty ? email : currentEmail
                    savePendingEmailChange(currentEmail: currentEmail, targetEmail: email, confirmed: [])
                    try await account.changeRecoveryEmail(email)
                    stage = .verifyEmailChange
                    notice = currentEmail.isEmpty
                        ? "Enter the code sent to \(email)."
                        : "Enter the code for \(currentEmail), then the code for \(email)."
                case .verifyEmailChange:
                    try await verifyPendingEmailChange(account, code: code)
                case .methods: break
                }
            } catch {
                switch stage {
                case .claimUsername:
                    if error as? AccountCredentialError == .differentAccount {
                        notice = "Sign in to the account that started this registration before choosing its username."
                    } else {
                        notice = "That username could not be claimed. Try another name, or try again."
                    }
                case .verify, .recoveryCode, .verifyEmailChange:
                    notice = "That code could not be verified. Check it or request a new one."
                case .newPassword:
                    notice = "The password could not be updated. Request a security code and try again."
                default:
                    notice = (error as? AccountCredentialError)?.localizedDescription
                        ?? "This account action couldn’t finish. Check your details and connection, then try again."
                }
            }
        }
    }

    func resend() {
        farm.perform { [self] in
            guard let account = farm.account else { throw AccountCredentialError.unavailable }
            do {
                if stage == .recoveryCode {
                    try await account.sendPasswordRecovery(email: email)
                } else if stage == .newPassword {
                    try await account.sendPasswordChangeCode()
                } else if stage == .verifyEmailChange, let pending = pendingEmailChange() {
                    savePendingEmailChange(currentEmail: pending.currentEmail, targetEmail: pending.targetEmail, confirmed: [])
                    verificationEmail = pending.currentEmail.isEmpty ? pending.targetEmail : pending.currentEmail
                    try await account.changeRecoveryEmail(pending.targetEmail)
                } else {
                    try await account.resendVerification(email: email)
                }
                notice = "Check your email for the code."
            } catch { notice = "The email couldn’t be sent yet. Please try again shortly." }
        }
    }

    func showMethods() {
        stage = .methods
        password = ""
        code = ""
        farm.perform { [self] in
            farm.credentialProfile = try await farm.account?.credentialProfile()
        }
    }

    /// Explicit account removal must not let an unfinished credential flow for
    /// that person appear under the next account. Ordinary app relaunch keeps
    /// these records so a verified signup can safely resume its username claim.
    func clearForSignOut() {
        defaults.removeObject(forKey: pendingKey)
        defaults.removeObject(forKey: pendingEmailChangeKey)
        stage = .signIn
        identifier = ""
        email = ""
        username = ""
        password = ""
        code = ""
        verificationEmail = ""
        emailChangeCurrentEmail = ""
        notice = nil
    }

    private func finishRegistration(_ account: NightFlockAccountService) async throws {
        guard let pending = pendingSignup() else {
            // Existing Apple or email accounts may add a username later. This
            // path has no signup record, so bind the claim to the active
            // credential profile instead of treating it as a resumed signup.
            let profile = try await account.credentialProfile()
            try await account.claimUsername(username)
            farm.credentialProfile = try await account.credentialProfile()
            stage = .methods
            notice = "Username added."
            _ = profile
            return
        }
        guard pending.phase == .claimUsername else {
            stage = .verify
            verificationEmail = pending.email
            return
        }
        let profile = try await account.credentialProfile()
        guard sameEmail(profile.email, pending.email) else { throw AccountCredentialError.differentAccount }
        // Keep an edited retry name durable before making the claim. A
        // collision must never resurrect the previously rejected name.
        savePendingSignup(email: pending.email, username: username, phase: .claimUsername)
        try await account.claimUsername(username)
        try await farm.completeAccountConnection(acceptSync: true)
        defaults.removeObject(forKey: pendingKey)
        stage = .methods
    }

    private func resumePendingUsernameClaimIfAuthenticated(_ account: NightFlockAccountService) async throws {
        guard let pending = pendingSignup() else { return }
        guard pending.phase == .claimUsername else {
            email = pending.email
            username = pending.username
            verificationEmail = pending.email
            stage = .verify
            notice = "Enter the confirmation code for the account you created."
            return
        }
        let profile = try await account.credentialProfile()
        guard sameEmail(profile.email, pending.email) else { return }
        email = pending.email
        username = pending.username
        stage = .claimUsername
        try await finishRegistration(account)
    }

    private func verifyPendingEmailChange(_ account: NightFlockAccountService, code: String) async throws {
        guard var pending = pendingEmailChange(),
              (!pending.currentEmail.isEmpty && sameEmail(verificationEmail, pending.currentEmail))
                || sameEmail(verificationEmail, pending.targetEmail) else {
            throw AccountCredentialError.verifyEmail
        }
        try await account.verifyEmailCode(email: verificationEmail, code: code, emailChange: true)
        if !pending.confirmed.contains(where: { sameEmail($0, verificationEmail) }) {
            pending.confirmed.append(verificationEmail)
        }
        savePendingEmailChange(currentEmail: pending.currentEmail, targetEmail: pending.targetEmail, confirmed: pending.confirmed)

        let profile = try? await account.credentialProfile()
        if sameEmail(profile?.email, pending.targetEmail) {
            defaults.removeObject(forKey: pendingEmailChangeKey)
            email = pending.targetEmail
            verificationEmail = ""
            emailChangeCurrentEmail = ""
            farm.credentialProfile = profile
            stage = .methods
            notice = "Recovery email updated."
            return
        }

        let next = !pending.currentEmail.isEmpty && sameEmail(verificationEmail, pending.currentEmail)
            ? pending.targetEmail : pending.currentEmail
        guard !next.isEmpty else {
            verificationEmail = pending.targetEmail
            notice = "The email change is still waiting for the code sent to \(pending.targetEmail)."
            return
        }
        verificationEmail = next
        stage = .verifyEmailChange
        notice = "The email change is still waiting for the code sent to \(next)."
    }

    private func pendingSignup() -> (email: String, username: String, phase: PendingSignupPhase)? {
        guard let pending = defaults.dictionary(forKey: pendingKey),
              let email = pending["email"] as? String, let username = pending["username"] as? String else { return nil }
        let phase = PendingSignupPhase(rawValue: pending["phase"] as? String ?? "") ?? .verification
        return (email, username, phase)
    }

    private func savePendingSignup(email: String, username: String, phase: PendingSignupPhase) {
        defaults.set(["email": email, "username": username, "phase": phase.rawValue], forKey: pendingKey)
    }

    private func pendingEmailChange() -> (currentEmail: String, targetEmail: String, confirmed: [String], nextAddress: String)? {
        guard let pending = defaults.dictionary(forKey: pendingEmailChangeKey),
              let current = pending["currentEmail"] as? String, let target = pending["targetEmail"] as? String else { return nil }
        let confirmed = pending["confirmed"] as? [String] ?? []
        let next = current.isEmpty || confirmed.contains(where: { sameEmail($0, current) }) ? target : current
        return (current, target, confirmed, next)
    }

    private func savePendingEmailChange(currentEmail: String, targetEmail: String, confirmed: [String]) {
        defaults.set(["currentEmail": currentEmail, "targetEmail": targetEmail, "confirmed": confirmed],
                     forKey: pendingEmailChangeKey)
    }

    private func sameEmail(_ lhs: String?, _ rhs: String) -> Bool {
        guard let lhs else { return false }
        return lhs.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(rhs.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }
}
