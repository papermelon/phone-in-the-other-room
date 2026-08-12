import SwiftUI

@main
struct PhoneInTheOtherRoomApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var runViewModel: FocusRunViewModel
#if DEBUG
    private let screenbookRequest: ScreenbookLaunchRequest?
#endif

    init() {
#if DEBUG
        let request = ScreenbookLaunchRequest.current
        screenbookRequest = request
        if let request {
            _runViewModel = StateObject(
                wrappedValue: ScreenbookFixtures.makeViewModel(for: request.kind)
            )
            return
        }
#endif
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
            rootView
                .environmentObject(runViewModel)
                .preferredColorScheme(preferredColorScheme)
                .onChange(of: scenePhase) { _, newPhase in
#if DEBUG
                    guard screenbookRequest == nil else { return }
#endif
                    switch newPhase {
                    case .background:
                        runViewModel.coordinator.applicationDidEnterBackground()
                    case .active:
                        runViewModel.coordinator.applicationDidBecomeActive()
                        runViewModel.reconcileAutomaticWindDownIfNeeded()
                        runViewModel.nightFlockViewModel.handleForeground()
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
        }
    }

    @ViewBuilder
    private var rootView: some View {
#if DEBUG
        if let screenbookRequest {
            ScreenbookRootView(request: screenbookRequest)
        } else {
            AppRootView()
        }
#else
        AppRootView()
#endif
    }

    private var preferredColorScheme: ColorScheme? {
        switch runViewModel.appearanceResolution {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
