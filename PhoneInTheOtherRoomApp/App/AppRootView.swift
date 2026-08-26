import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var showQuietNoteEditor = false

    var body: some View {
        Group {
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
            guard QuietNoteText.isEditorURL(url) else { return }
            showQuietNoteEditor = true
        }
        .sheet(isPresented: $showQuietNoteEditor) {
            NavigationStack {
                LockScreenQuietNoteGuideView()
                    .environmentObject(viewModel)
            }
        }
    }
}

#Preview {
    AppRootView()
        .environmentObject(FocusRunViewModel())
}
