import AuthenticationServices
import SwiftUI

struct NightFlockHubView: View {
    @ObservedObject var viewModel: NightFlockViewModel
    @State private var showOrientation = false

    var body: some View {
        ScrollViewReader { proxy in
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
            .onAppear {
                viewModel.entryAppeared()
                showOrientation = viewModel.orientationState.shouldShowIntro
                if viewModel.prefersJoinEntry {
                    DispatchQueue.main.async {
                        proxy.scrollTo("slumber-party-join", anchor: .center)
                    }
                }
            }
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Slumber Party")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(isPresented: $showOrientation) {
            NightFlockOrientationView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.featureEnabled {
            EmptyView()
        } else if viewModel.pendingAuthenticationRecovery != .none || viewModel.accountState != .linked {
            NightFlockAccountEntry(viewModel: viewModel)
        } else {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if let warmNotice = viewModel.warmNotice {
                    NightFlockStatusCard(symbol: "pawprint.fill", title: "A warm welcome back", detail: warmNotice, requestReference: viewModel.requestReference)
                }
                switch viewModel.phase {
                case .loading:
                    NightFlockStatusCard(symbol: "moon.stars.fill", title: "Opening Slumber Party…", detail: "Ollie is checking the gate.")
                        .redacted(reason: .placeholder)
                case .offline:
                    NightFlockStatusCard(symbol: "wifi.slash", title: "Slumber Party is resting offline.", detail: "Wind Down still works. Shared updates will try again later.", requestReference: viewModel.requestReference)
                    Button("Refresh lobby", action: viewModel.retryNightFlockRequest)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                case .expiredInvite:
                    NightFlockStatusCard(symbol: "clock.badge.xmark", title: "That invitation has gone quiet.", detail: "Ask your host for a fresh code.", requestReference: viewModel.requestReference)
                    NightFlockCreateJoinView(viewModel: viewModel)
                case .fullFlock:
                    NightFlockStatusCard(symbol: "person.3.fill", title: "This Slumber Party is full.", detail: "A party has room for 2–8 people.", requestReference: viewModel.requestReference)
                    NightFlockCreateJoinView(viewModel: viewModel)
                case .blocked:
                    NightFlockStatusCard(symbol: "hand.raised.fill", title: "That shared gate is closed.", detail: "No Slumber Party details are visible from this account.", requestReference: viewModel.requestReference)
                case .error(let message):
                    NightFlockStatusCard(symbol: "exclamationmark.bubble.fill", title: "Slumber Party could not open.", detail: message, requestReference: viewModel.requestReference)
                    if viewModel.canRetryNightFlockRequest {
                        Button("Retry", action: viewModel.retryNightFlockRequest)
                            .frame(maxWidth: .infinity)
                            .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    }
                    NightFlockCreateJoinView(viewModel: viewModel)
                case .ready, .idle:
                    if let snapshot = viewModel.snapshot, snapshot.challenge.sharedGoal != nil {
                        NightFlockDashboard(viewModel: viewModel, snapshot: snapshot)
                    } else {
                        NightFlockCreateJoinView(viewModel: viewModel)
                    }
                case .hidden:
                    EmptyView()
                }
            }
        }
    }
}

private struct NightFlockHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("2–8 PEOPLE · 7 NIGHTS")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            Text("Wind down together")
                .font(AppTypography.display(27))
            Text("Choose one bedtime goal as a group. Keep your own routine, share the parts that help, and encourage one another along the way.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
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
                NightFlockStatusCard(symbol: "lock.fill", title: "Slumber Party stayed closed for safety.", detail: "Counting Sheep could not prove this is the original account. Your local Wind Down and shared updates were kept safe here.", requestReference: viewModel.requestReference)
            } else {
            switch viewModel.accountState {
            case .linking:
                NightFlockStatusCard(symbol: "person.crop.circle.badge.clock", title: "Linking your Apple account…", detail: "Your local Wind Down stays on this iPhone.")
                ProgressView().tint(AppColors.grass).frame(maxWidth: .infinity)
            case .unavailable:
                NightFlockStatusCard(symbol: "wifi.slash", title: "The account gate could not open.", detail: "Check your connection and try again. Wind Down still works normally.")
                Button("Try again", action: viewModel.retryAccountConnection)
                    .frame(maxWidth: .infinity)
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
            NightFlockStatusCard(symbol: "person.crop.circle.badge.arrow.clockwise", title: title, detail: detail, requestReference: viewModel.requestReference)
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

private struct NightFlockCreateJoinView: View {
    @ObservedObject var viewModel: NightFlockViewModel
    @FocusState private var joinFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("CHOOSE ONE GOAL")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text("What will your group practise for seven nights?")
                        .font(AppTypography.headline)
                    ForEach(NightFlockGoalKind.allCases) { kind in
                        Button {
                            viewModel.commitmentDraft.goal = NightFlockSharedGoal(
                                kind: kind,
                                targetMinutes: kind.defaultTargetMinutes,
                                appDisplayName: kind == .shieldInstagram ? "Instagram" : nil
                            )
                        } label: {
                            HStack(alignment: .top, spacing: AppSpacing.sm) {
                                Image(systemName: kind == viewModel.commitmentDraft.goal.kind ? "checkmark.circle.fill" : "circle")
                                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                    Text(kind.title).font(AppTypography.body.weight(.semibold))
                                    Text(kind.detail).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(kind == viewModel.commitmentDraft.goal.kind ? AppColors.grass : AppColors.ink)
                    }
                    if viewModel.commitmentDraft.goal.kind == .quietMinutes {
                        Stepper(
                            String(viewModel.commitmentDraft.goal.targetMinutes ?? 30) + " quiet minutes",
                            value: Binding(
                                get: { viewModel.commitmentDraft.goal.targetMinutes ?? 30 },
                                set: { viewModel.commitmentDraft.goal.targetMinutes = min(max($0, 5), 180) }
                            ),
                            in: 5...180,
                            step: 5
                        )
                    }
                    Text("Choose a pasture identity")
                        .font(AppTypography.caption.weight(.semibold))
                    Picker("Pasture identity", selection: Binding(
                        get: { viewModel.commitmentDraft.identity },
                        set: { viewModel.commitmentDraft.identity = $0 }
                    )) {
                        ForEach(NightFlockIdentity.allCases) { identity in
                            Text(identity.title).tag(identity)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("Everyone accepts the same goal. Bedtimes and routines can still be different.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                    Text(NightFlockSharingConsentCopy.joinDisclosure)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Create lobby", action: viewModel.createSharedParty)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(PixelPrimaryButtonStyle())
                }
            }

            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("JOIN A LOBBY")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    TextField("Party code", text: $viewModel.joinCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .focused($joinFieldFocused)
                        .accessibilityLabel("Slumber Party code")
                    Button("Preview invitation", action: viewModel.previewSharedInvite)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    if let preview = viewModel.invitePreview {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(preview.goal.title).font(AppTypography.body.weight(.semibold))
                            Text(String(preview.memberCount) + " people are in this lobby. The code can be reused until the host starts or the lobby fills.")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.secondaryText)
                            Text(NightFlockSharingConsentCopy.joinDisclosure)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("Join this lobby", action: viewModel.redeemSharedInvite)
                                .frame(maxWidth: .infinity)
                                .buttonStyle(PixelPrimaryButtonStyle())
                        }
                        .padding(.top, AppSpacing.xs)
                    }
                }
            }
            .id("slumber-party-join")
            .onAppear {
                if viewModel.prefersJoinEntry {
                    joinFieldFocused = true
                }
            }
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
                        Text(requestReference)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                            .textSelection(.enabled)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}
