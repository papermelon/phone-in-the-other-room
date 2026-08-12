import AuthenticationServices
import SwiftUI

struct NightFlockHubView: View {
    @ObservedObject var viewModel: NightFlockViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                NightFlockHeader()
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
        .onAppear(perform: viewModel.entryAppeared)
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.featureEnabled {
            EmptyView()
        } else if viewModel.accountState != .linked {
            accountEntry
        } else {
            switch viewModel.phase {
            case .loading:
                NightFlockStatusCard(
                    symbol: "moon.stars.fill",
                    title: "Opening the pasture…",
                    detail: "Ollie is checking the gate."
                )
                .redacted(reason: .placeholder)
            case .offline:
                NightFlockStatusCard(
                    symbol: "wifi.slash",
                    title: "The pasture is resting offline.",
                    detail: "Wind Down still works. Shared notes will try again later."
                )
            case .expiredInvite:
                NightFlockStatusCard(
                    symbol: "clock.badge.xmark",
                    title: "That invite has gone quiet.",
                    detail: "Ask a flock member for a fresh code."
                )
                createOrJoin
            case .fullFlock:
                NightFlockStatusCard(
                    symbol: "person.3.fill",
                    title: "That pasture is full.",
                    detail: "Slumber Parties have room for up to eight people."
                )
                createOrJoin
            case .blocked:
                NightFlockStatusCard(
                    symbol: "hand.raised.fill",
                    title: "That shared gate is closed.",
                    detail: "No Slumber Party details are visible from this account."
                )
            case .error(let message):
                NightFlockStatusCard(
                    symbol: "exclamationmark.bubble.fill",
                    title: "The pasture could not open.",
                    detail: message
                )
                createOrJoin
            case .ready, .idle:
                if let snapshot = viewModel.snapshot {
                    NightFlockDashboard(viewModel: viewModel, snapshot: snapshot)
                } else {
                    createOrJoin
                }
            case .hidden:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var accountEntry: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            switch viewModel.accountState {
            case .linking:
                NightFlockStatusCard(
                    symbol: "person.crop.circle.badge.clock",
                    title: "Linking your Apple account…",
                    detail: "Keep this screen open for a moment. Your existing Counting Sheep data stays with this account."
                )
                ProgressView()
                    .tint(AppColors.grass)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Linking Apple account")
            case .unavailable:
                NightFlockStatusCard(
                    symbol: "wifi.slash",
                    title: "The account gate could not open.",
                    detail: accountErrorMessage ?? "Check your connection and try again. Wind Down still works normally."
                )
                retryButton
            case .anonymous:
                NightFlockStatusCard(
                    symbol: "person.crop.circle.badge.checkmark",
                    title: "A linked account keeps this pasture private.",
                    detail: "Link with Apple only when you are ready to create or join. Your local Wind Down stays local."
                )
                if let accountErrorMessage {
                    NightFlockStatusCard(
                        symbol: "exclamationmark.bubble.fill",
                        title: "Apple sign-in did not link this account.",
                        detail: accountErrorMessage
                    )
                }
                SignInWithAppleButton(.continue) { request in
                    viewModel.prepareAppleSignInRequest(request)
                } onCompletion: { result in
                    viewModel.completeAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .accessibilityHint("Links the existing anonymous online account without replacing it")
            case .linked:
                EmptyView()
            }
        }
    }

    private var accountErrorMessage: String? {
        guard case .error(let message) = viewModel.phase else { return nil }
        return message
    }

    private var retryButton: some View {
        Button(action: viewModel.retryAccountConnection) {
            Label("Try the account gate again", systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PixelChipButtonStyle(isSelected: false))
    }

    private var createOrJoin: some View {
        NightFlockCreateJoinView(viewModel: viewModel)
    }
}

private struct NightFlockHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("INVITE-ONLY · SEVEN NIGHTS")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            Text("Slumber Party")
                .font(AppTypography.display(27))
            Text("Share only the good news: a tucked-away phone and a completed quiet morning.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct NightFlockCreateJoinView: View {
    @ObservedObject var viewModel: NightFlockViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("OPEN A PASTURE")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text("Choose a flock sign.")
                        .font(AppTypography.headline)
                    ForEach(NightFlockIdentity.allCases) { identity in
                        Button {
                            viewModel.selectedIdentity = identity
                        } label: {
                            HStack {
                                Label(identity.title, systemImage: identity.symbolName)
                                Spacer()
                                if viewModel.selectedIdentity == identity {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                            }
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(
                            viewModel.selectedIdentity == identity ? AppColors.grass : AppColors.ink
                        )
                    }
                    Button("Create Slumber Party", action: viewModel.createFlock)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(PixelPrimaryButtonStyle())
                }
            }

            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("JOIN BY CODE")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    TextField("Short invite code", text: $viewModel.joinCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Slumber Party invite code")
                    Text("Joining shares only positive check-ins for this challenge. Private nights never appear.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                    Button("Join Slumber Party", action: viewModel.joinFlock)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                }
            }
        }
    }
}

struct NightFlockStatusCard: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        PixelCard {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: symbol)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColors.grass)
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title)
                        .font(AppTypography.headline)
                    Text(detail)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}
