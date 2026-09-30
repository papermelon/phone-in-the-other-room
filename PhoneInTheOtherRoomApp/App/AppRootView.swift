import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var showQuietNoteEditor = false

    var body: some View {
        AccountAccessGate(model: viewModel.farmBackupViewModel) {
            switch viewModel.rootRoute {
            case .freshOnboarding:
                OnboardingFlowView(startsFresh: true, onComplete: {})
            case .resumeOnboarding:
                OnboardingFlowView(onComplete: {})
            case .home:
                HomeView()
            }
        }
        .animation(AppMotion.navigation, value: viewModel.rootRoute)
        .onOpenURL { url in
            if QuietNoteText.isEditorURL(url) { showQuietNoteEditor = true }
            else { openPartyLink(url) }
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL { openPartyLink(url) }
        }
        .sheet(isPresented: $showQuietNoteEditor) {
            NavigationStack {
                LockScreenQuietNoteGuideView()
                    .environmentObject(viewModel)
            }
        }
    }

    private func openPartyLink(_ url: URL) {
        guard let code = SlumberPartyLink.code(in: url) else { return }
        UserDefaults.standard.set(code, forKey: SlumberPartyLink.pendingCodeKey)
        viewModel.nightFlockViewModel.prefersJoinEntry = true
        NotificationCenter.default.post(name: .countingSheepShowNightFlock, object: "join")
    }
}

#Preview {
    AppRootView()
        .environmentObject(FocusRunViewModel())
}
