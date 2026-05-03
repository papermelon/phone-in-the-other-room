import SwiftUI

@main
struct PhoneInTheOtherRoomWatchApp: App {
    @StateObject private var viewModel = WatchRunViewModel()

    init() {
        WatchNotificationService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            WatchSetupView()
                .environmentObject(viewModel)
        }
    }
}
