import AuthenticationServices
import SwiftUI

struct FarmBackupView: View {
    var account: NightFlockViewModel? = nil
    @ObservedObject var model: FarmBackupViewModel
    @State private var confirmsSignOut = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Profile").font(AppTypography.title)
                profileIdentity
                AccountConnectionContent(model: model)
                if model.signedIn {
                    PixelCard {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("YOUR DETAILS").font(pixelFont(.caption)).foregroundStyle(AppColors.grass)
                            NavigationLink { ShepherdCustomizationView() } label: {
                                AccountRowLabel(title: "Name and appearance", symbol: "person.crop.circle")
                            }.buttonStyle(.plain)
                            Divider().overlay(AppColors.stroke)
                            NavigationLink {
                                AccountCredentialsView(farm: model, model: model.credentials)
                                    .task { model.credentials.showMethods() }
                            } label: {
                                AccountRowLabel(title: "Sign-in and username", symbol: "key",
                                    detail: model.credentialProfile?.signInMethodsTitle ?? "View connected methods")
                            }.buttonStyle(.plain)
                        }
                    }
                    Button("Sign out") { confirmsSignOut = true }
                        .buttonStyle(AccountTextButtonStyle()).disabled(model.busy || model.appleSignInInProgress)
                    if let account {
                        DisclosureGroup("Account management") {
                            NavigationLink { FarmAccountControlsView(account: account, backup: model) } label: {
                                AccountRowLabel(title: "Delete account", symbol: "trash",
                                    detail: "Permanently remove your account and online Farm", destructive: true)
                            }.buttonStyle(.plain)
                        }
                        .font(AppTypography.caption).tint(AppColors.secondaryText)
                    }
                }
                if !model.needsSyncAgreement { FarmSyncDisclosure() }
            }
            .foregroundStyle(AppColors.ink).padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .task { if model.available { model.refresh() } }
        .confirmationDialog("Sign out?", isPresented: $confirmsSignOut, titleVisibility: .visible) {
            Button("Sign out", action: model.signOut)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(model.hasUnsyncedChanges
                ? "Your latest changes haven’t synced. They’ll be kept privately on this phone for your next sign-in."
                : "Your Farm will close on this phone. Sign in again to continue it.")
        }
    }
    private var profileIdentity: some View {
        HStack(spacing: AppSpacing.md) {
            SlumberPartySocialAvatarView(
                presentation: model.persistence.userProfile.presentation,
                avatarID: SocialAvatarRules.shepherdID, size: 64
            )
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(model.persistence.userProfile.displayName.isEmpty ? "Your Shepherd" : model.persistence.userProfile.displayName)
                    .font(AppTypography.headline)
                if let username = model.credentialProfile?.username {
                    Text("@\(username)").font(AppTypography.body).foregroundStyle(AppColors.secondaryText)
                }
                Text(model.signedIn
                     ? model.credentialProfile?.signInMethodsTitle ?? "Signed in"
                     : "Guest · saved on this phone")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
    }

}

struct AccountConnectionContent: View {
    @ObservedObject var model: FarmBackupViewModel
    var requiresAuthentication = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var confirmsLocalFarm = false
    @State private var confirmsRemoteFarm = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if model.signedIn && !requiresAuthentication {
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Label(status, systemImage: "icloud").font(AppTypography.headline)
                        if let date = model.sync?.confirmedAt {
                            Text("Last saved \(date.formatted(date: .abbreviated, time: .shortened))")
                                .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                        }
                        if model.busy { ProgressView() }
                        if model.needsSyncAgreement {
                            Text("Save your Farm to your account and keep it up to date across phones.").font(AppTypography.body)
                            if let notice = model.syncConnectionNotice {
                                Text(notice).font(AppTypography.body)
                            } else if model.generationNeedsReview || model.accountPresentation == .failed {
                                Text(model.message).font(AppTypography.body)
                            }
                            FarmSyncDisclosure()
                            Button(model.busy ? "Connecting…" : "Enable automatic sync", action: model.acceptAutomaticSync)
                                .buttonStyle(AccountPrimaryButtonStyle()).disabled(model.busy)
                        } else if case .remoteFarm(let preview) = model.accountPresentation {
                            Text("Your account has \(preview.activeSheepCount) sheep and \(preview.woolBalance) wool. Choose which Farm to continue.")
                                .font(AppTypography.body)
                            Button("Use account Farm") { confirmsRemoteFarm = true }
                                .buttonStyle(AccountPrimaryButtonStyle()).disabled(model.busy)
                            Button("Use this phone’s Farm") { confirmsLocalFarm = true }
                                .buttonStyle(AccountSecondaryButtonStyle()).disabled(model.busy)
                        } else if model.accountPresentation == .failed || model.accountPresentation == .remoteFarmUnavailable {
                            Text(model.message).font(AppTypography.body)
                            Button("Try again", action: model.refresh).buttonStyle(AccountSecondaryButtonStyle()).disabled(model.busy)
                        }
                    }
                }
            } else {
                Text("Sign in to continue your Farm across phones. Your account keeps it in sync automatically.")
                    .font(AppTypography.body)
                if model.available {
                    SignInWithAppleButton(.signIn, onRequest: model.prepareApple, onCompletion: model.completeApple)
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .frame(height: 50).disabled(model.busy || model.appleSignInInProgress)
                    NavigationLink("Sign in with username or email") {
                        AccountCredentialsView(farm: model, model: model.credentials)
                            .onAppear { if requiresAuthentication { model.credentials.stage = .signIn } }
                    }.buttonStyle(AccountSecondaryButtonStyle()).disabled(model.busy || model.appleSignInInProgress)
                } else { Text("Account sign-in is unavailable in this build.").font(AppTypography.body) }
                if model.busy { ProgressView("Connecting…") }
                if model.accountPresentation == .failed && model.appleSignInFailure == nil { Text(model.message).font(AppTypography.body) }
            }
            if let failure = model.appleSignInFailure {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(failure.message).font(AppTypography.body)
                    DisclosureGroup("Support details") {
                        Text(failure.supportDetail).font(AppTypography.caption).textSelection(.enabled)
                    }.font(AppTypography.caption)
                }
            }
        }
        .confirmationDialog("Use the account Farm?", isPresented: $confirmsRemoteFarm, titleVisibility: .visible) {
            Button("Use account Farm", action: model.chooseAccountFarm)
        } message: { Text("This phone’s changes will remain in recovery. Progress won’t be combined.") }
        .confirmationDialog("Use this phone’s Farm?", isPresented: $confirmsLocalFarm, titleVisibility: .visible) {
            Button("Use this phone’s Farm", action: model.chooseLocalFarm)
        } message: { Text("The account will continue from this Farm. The previous account copy stays in revision history.") }
    }

    private var status: String {
        if model.busy { return "Syncing…" }
        if model.needsSyncAgreement { return "Connect your Farm" }
        if model.accountPresentation == .failed { return "Waiting to sync" }
        if case .remoteFarm = model.accountPresentation { return "Choose your Farm" }
        if model.hasUnsyncedChanges { return "Changes waiting to sync" }
        if case .backupConfirmed = model.accountPresentation { return "Saved" }
        return "Connecting your Farm"
    }
}

struct FarmBackupStatusView: View {
    @ObservedObject var model: FarmBackupViewModel
    let account: NightFlockViewModel
    var body: some View {
        NavigationLink { FarmBackupView(account: account, model: model) } label: {
            Image(systemName: "person.crop.circle")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.secondaryText)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            .accessibilityLabel("Profile")
            .accessibilityHint("Your name, sign-in methods and Farm sync")
        }.buttonStyle(.plain)
    }
}

#Preview("Account · unavailable") {
    FarmBackupView(model: FarmBackupViewModel(persistence: .shared, account: nil, service: nil))
}

#Preview("Profile · Apple connected") {
    let model = FarmBackupViewModel(persistence: .shared, account: nil, service: nil)
    NavigationStack { FarmBackupView(model: model) }
        .onAppear {
            model.signedIn = true
            model.accountPresentation = .backupConfirmed(nil)
            model.credentialProfile = .init(id: UUID(), username: "shepherd", hasApple: true, hasEmail: false)
        }
}

#Preview("Profile · sync confirmation · large text") {
    let model = FarmBackupViewModel(persistence: .shared, account: nil, service: nil)
    NavigationStack { FarmBackupView(model: model) }
        .onAppear {
            model.signedIn = true
            model.needsSyncAgreement = true
            model.credentialProfile = .init(id: UUID(), hasApple: true, hasEmail: false)
        }
        .environment(\.dynamicTypeSize, .accessibility3)
}
