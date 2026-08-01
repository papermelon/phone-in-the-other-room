import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var didCompleteOnboarding = false

    var body: some View {
        Group {
            if shouldShowOnboarding {
                OnboardingFlowView {
                    didCompleteOnboarding = true
                }
            } else {
                HomeView()
            }
        }
        .animation(AppMotion.navigation, value: shouldShowOnboarding)
    }

    private var shouldShowOnboarding: Bool {
        guard viewModel.activeRun == nil else { return false }
        guard !didCompleteOnboarding else { return false }
        guard !viewModel.hasConfiguredNightWatch else { return false }
        return PersistenceService.shared.onboardingVersion < CountingSheepOnboarding.currentVersion
    }
}

#Preview {
    AppRootView()
        .environmentObject(FocusRunViewModel())
}
