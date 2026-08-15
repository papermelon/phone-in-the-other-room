#if SLUMBER_PARTY_QA
import SwiftUI

struct NightFlockQADiagnosticsView: View {
    @EnvironmentObject private var focusViewModel: FocusRunViewModel
    @ObservedObject var viewModel: NightFlockViewModel

    private var diagnostics: NightFlockDiagnostics {
        viewModel.diagnostics.resolvingSurface(activeWindDown: focusViewModel.isRunning)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("INTERNAL QA ONLY")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text("Slumber Party diagnostics")
                        .font(AppTypography.display(27))
                        .foregroundStyle(AppColors.ink)
                    Text("This screen reads local build state only. It does not create an account, start a request, or open a Slumber Party.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                }

                diagnosticCard("Feature flag", detail: flagDetail)
                diagnosticCard("Backend configuration", detail: configurationDetail)
                diagnosticCard("Wind Down surface", detail: surfaceDetail)
                diagnosticCard("Account link", detail: accountDetail)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("QA diagnostics")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func diagnosticCard(_ title: String, detail: String) -> some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.ink)
                Text(detail)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var flagDetail: String {
        switch diagnostics.featureFlag {
        case .enabled: return "Enabled by this QA build configuration."
        case .disabled: return "Disabled by this build configuration."
        case .invalid: return "Invalid or missing. The feature is fail-closed."
        }
    }

    private var configurationDetail: String {
        switch diagnostics.configuration {
        case .notEvaluated: return "Not evaluated because Slumber Party is disabled."
        case .valid: return "Required client configuration is valid."
        case .invalid(.invalidFeatureFlag): return "The feature-flag value is invalid."
        case .invalid(.missingURL): return "The client URL is unavailable."
        case .invalid(.malformedURL): return "The client URL is invalid."
        case .invalid(.missingPublishableKey): return "The publishable key is unavailable."
        case .invalid(.nonPublishableKey): return "The configured key is not a publishable key."
        case .invalid(.unavailable): return "Required client configuration could not be validated."
        }
    }

    private var surfaceDetail: String {
        switch diagnostics.surface {
        case .unavailable: return "Hidden because Slumber Party is not enabled and configured in this build."
        case .available: return "Available outside an active Wind Down."
        case .suppressedForActiveWindDown: return "Suppressed while Wind Down is active."
        }
    }

    private var accountDetail: String {
        switch diagnostics.accountState {
        case .anonymous: return "No Apple-linked account is active."
        case .linking: return "Apple account linking is in progress."
        case .linked: return "An Apple-linked account is active."
        case .unavailable: return "Account state is unavailable."
        }
    }
}

#Preview("Slumber Party QA diagnostics") {
    NavigationStack {
        NightFlockQADiagnosticsView(
            viewModel: NightFlockViewModel(
                featureEnabled: false,
                diagnostics: .initial(featureFlag: .enabled, configuration: .invalid(.missingURL))
            )
        )
        .environmentObject(FocusRunViewModel(startsExternalServices: false))
    }
}
#endif
