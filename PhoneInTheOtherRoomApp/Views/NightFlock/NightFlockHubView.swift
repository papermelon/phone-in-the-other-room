import AuthenticationServices
import SwiftUI

struct NightFlockHubView: View {
    @ObservedObject var viewModel: NightFlockViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SlumberPartyV4Header()
                content
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Slumber Party")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear {
            viewModel.entryAppeared()
            Task { _ = await viewModel.refreshState(showLoading: false) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.featureEnabled {
            SlumberPartyV4UnavailableCard(
                title: "Slumber Party is taking a quiet pause.",
                detail: "This version of Counting Sheep does not have the invite-only Slumber Party service turned on. Your Wind Down stays right here with you."
            )
        } else if viewModel.pendingAuthenticationRecovery != .none || viewModel.accountState != .linked {
            NightFlockAccountEntry(viewModel: viewModel)
        } else if viewModel.usesSlumberPartyV4 {
            SlumberPartyV4ListView(viewModel: viewModel)
        } else {
            legacySafeState
        }
    }

    @ViewBuilder
    private var legacySafeState: some View {
        switch viewModel.phase {
        case .loading:
            NightFlockStatusCard(
                symbol: "moon.stars.fill",
                title: "Opening Slumber Party…",
                detail: "Ollie is checking whether this service is ready."
            )
            .redacted(reason: .placeholder)
        case .offline:
            NightFlockStatusCard(
                symbol: "wifi.slash",
                title: "Slumber Party is resting offline.",
                detail: "Wind Down still works. Try again whenever you have a connection."
            )
            Button("Refresh") {
                Task { _ = await viewModel.refreshState(showLoading: true) }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(PixelChipButtonStyle(isSelected: false))
        case .error(let message):
            SlumberPartyV4UnavailableCard(
                title: "Slumber Party could not open yet.",
                detail: message,
                requestID: viewModel.v4RequestID ?? viewModel.requestReference
            )
            Button("Try again") {
                Task { _ = await viewModel.refreshState(showLoading: true) }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(PixelChipButtonStyle(isSelected: false))
        case .hidden, .idle, .ready, .expiredInvite, .fullFlock, .blocked:
            SlumberPartyV4UnavailableCard(
                title: "Slumber Party needs an update.",
                detail: "This invite-only service is not available from this version yet. Your local Farm and Wind Down are unaffected."
            )
        }
    }
}

private struct NightFlockAccountEntry: View {
    @ObservedObject var viewModel: NightFlockViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if viewModel.pendingAuthenticationRecovery == .reauthenticateApple {
                recoveryEntry(
                    title: "Reconnect your Apple account",
                    detail: "Ollie will only reopen this Slumber Party when it is the same Apple-linked account. Your local Wind Down and queued updates stay safe here.",
                    action: .signIn
                )
            } else if viewModel.pendingAuthenticationRecovery == .linkCurrentAnonymousApple {
                recoveryEntry(
                    title: "Link this existing account",
                    detail: "This Slumber Party needs Apple sign-in. It will link only the anonymous account already on this iPhone, without replacing it.",
                    action: .continue
                )
            } else if viewModel.pendingAuthenticationRecovery == .failClosed {
                NightFlockStatusCard(symbol: "lock.fill", title: "Slumber Party stayed closed for safety.", detail: "Counting Sheep could not prove this is the original account. Your local Wind Down and shared updates were kept safe here.")
            } else {
                switch viewModel.accountState {
                case .linking:
                    NightFlockStatusCard(symbol: "person.crop.circle.badge.clock", title: "Linking your Apple account…", detail: "Your local Wind Down stays on this iPhone.")
                    ProgressView().tint(AppColors.grass).frame(maxWidth: .infinity)
                case .unavailable:
                    NightFlockStatusCard(symbol: "wifi.slash", title: "The account gate could not open.", detail: "Check your connection and try again. Wind Down still works normally.")
                    Button("Try again", action: viewModel.retryAccountConnection)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                case .anonymous:
                    NightFlockStatusCard(symbol: "person.crop.circle.badge.checkmark", title: "Link an Apple account when you are ready.", detail: "It keeps this invite-only group tied to the right person. Your local Wind Down stays local.")
                    SignInWithAppleButton(.continue) { request in
                        viewModel.prepareAppleSignInRequest(request)
                    } onCompletion: { result in
                        viewModel.completeAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .accessibilityHint("Links this existing Counting Sheep account without replacing it")
                case .linked:
                    EmptyView()
                }
            }
        }
    }

    private func recoveryEntry(
        title: String,
        detail: String,
        action: SignInWithAppleButton.Label
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            NightFlockStatusCard(symbol: "person.crop.circle.badge.arrow.clockwise", title: title, detail: detail)
            SignInWithAppleButton(action) { request in
                viewModel.prepareAppleSignInRequest(request)
            } onCompletion: { result in
                viewModel.completeAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        }
    }
}

struct NightFlockStatusCard: View {
    let symbol: String
    let title: String
    let detail: String
    let requestReference: String?

    init(symbol: String, title: String, detail: String, requestReference: String? = nil) {
        self.symbol = symbol
        self.title = title
        self.detail = detail
        self.requestReference = requestReference
    }

    var body: some View {
        PixelCard {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: symbol)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColors.grass)
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title).font(AppTypography.headline)
                    Text(detail).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                    if let requestReference {
                        DisclosureGroup("Support details") {
                            Text(requestReference)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.secondaryText)
                                .textSelection(.enabled)
                        }
                        .font(AppTypography.caption)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}
