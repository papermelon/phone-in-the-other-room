import AuthenticationServices
import SwiftUI

struct NightFlockHubView: View {
    @ObservedObject var viewModel: NightFlockViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                if !viewModel.usesSlumberPartyV4 {
                    SlumberPartyV4Header()
                }
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
        .task { await viewModel.activateEntry() }
        .refreshable { await viewModel.activateEntry() }
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
        } else if !viewModel.permitsFarmOwnerScopedSocialEffects, let account = viewModel.sharedFarmAccount {
            NightFlockStatusCard(
                symbol: "person.crop.circle",
                title: "Finish connecting your Farm",
                detail: "Slumber Party is waiting for this account’s Farm to load. Review your account below to continue."
            )
            AccountConnectionContent(model: account)
                .task { if account.available { account.refresh() } }
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
            ProgressView("Loading your parties…")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
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
        case .idle:
            SlumberPartyV4UnavailableCard(
                title: "Your parties haven’t loaded yet.",
                detail: "Try opening Slumber Party again.",
                onRetry: viewModel.entryAppeared
            )
        case .hidden, .ready, .expiredInvite, .fullFlock, .blocked:
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
        if let model = viewModel.sharedFarmAccount {
            AccountConnectionContent(model: model, requiresAuthentication: true)
            FarmSyncDisclosure()
        } else {
            NightFlockStatusCard(symbol: "person.crop.circle", title: "Sign in from Settings",
                detail: "Open Account in Settings to connect your account.")
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
