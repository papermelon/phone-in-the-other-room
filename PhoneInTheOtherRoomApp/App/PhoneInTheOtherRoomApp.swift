import SwiftUI

@main
struct PhoneInTheOtherRoomApp: App {
    @StateObject private var runViewModel = FocusRunViewModel()

    init() {
        PhoneNotificationService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(runViewModel)
                .preferredColorScheme(.dark)
        }
    }
}
