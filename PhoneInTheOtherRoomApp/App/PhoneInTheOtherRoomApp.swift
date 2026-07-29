import SwiftUI

@main
struct PhoneInTheOtherRoomApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var runViewModel: FocusRunViewModel

    init() {
        PhoneNotificationService.shared.configure()
        let liveActivityService: FocusRunLiveActivityService
        do {
            let configuration = try SupabaseConfiguration.load()
            if configuration.liveActivityPushEnabled {
                let provider = ConfiguredSupabaseClientProvider(configuration: configuration)
                let authentication = SupabaseAuthenticationService(provider: provider)
                let sink = SupabaseLiveActivityRemoteSink(
                    provider: provider,
                    authentication: authentication
                )
                liveActivityService = FocusRunLiveActivityService(remoteSink: sink)
            } else {
                liveActivityService = FocusRunLiveActivityService()
            }
        } catch {
            SupabaseConfigurationDiagnostics.report(error)
            liveActivityService = FocusRunLiveActivityService()
        }
        let coordinator = FocusSessionCoordinator(liveActivity: liveActivityService)
        _runViewModel = StateObject(wrappedValue: FocusRunViewModel(coordinator: coordinator))
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(runViewModel)
                .preferredColorScheme(prefersNightPresentation ? .dark : nil)
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .background:
                        runViewModel.coordinator.applicationDidEnterBackground()
                    case .active:
                        runViewModel.coordinator.applicationDidBecomeActive()
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
        }
    }

    private var prefersNightPresentation: Bool {
        runViewModel.isRunning || runViewModel.canBeginNightWatchNow
    }
}
