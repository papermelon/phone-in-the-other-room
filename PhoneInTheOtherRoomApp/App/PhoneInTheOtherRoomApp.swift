import SwiftUI

@main
struct PhoneInTheOtherRoomApp: App {
    var body: some Scene {
        WindowGroup {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--slumber-farm-fixture") {
                SlumberPartySharedFarmNativeFixture()
            } else if ProcessInfo.processInfo.arguments.contains("--shepherd-art-study") {
                if ProcessInfo.processInfo.arguments.contains("--shepherd-production-preview") {
                    NavigationStack { ShepherdProductionPreview() }
                } else {
                    ShepherdArtStudyView()
                }
            } else {
                PhoneInTheOtherRoomRuntimeView()
            }
#else
            PhoneInTheOtherRoomRuntimeView()
#endif
        }
    }
}

/// Delay production dependencies until the normal application surface is actually requested.
private struct PhoneInTheOtherRoomRuntimeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var runViewModel = Self.makeRunViewModel()
#if DEBUG
    private let screenbookRequest = ScreenbookLaunchRequest.current
#endif

    /// StateObject evaluates this factory once, rather than on every view-value recreation.
    private static func makeRunViewModel() -> FocusRunViewModel {
#if DEBUG
        if let request = ScreenbookLaunchRequest.current {
            return ScreenbookFixtures.makeViewModel(for: request.kind)
        }
        if WatchPhysicalQAFixture.isRequested {
            return WatchPhysicalQAFixture.makeViewModel()
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
        return FocusRunViewModel(coordinator: coordinator)
    }

    var body: some View {
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
