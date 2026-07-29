import AppIntents

struct PrepareNightWatchIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Quiet Time"
    static var description = IntentDescription("Opens Counting Sheep so you can tuck your phone in for the night.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Ollie is ready for quiet time. Put your phone to bed when you are ready.")
    }
}

struct PhoneInTheOtherRoomShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor { .lime }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PrepareNightWatchIntent(),
            phrases: [
                "Start Quiet Time in \(.applicationName)",
                "Put my phone to bed with \(.applicationName)",
                "Start quiet time with Ollie in \(.applicationName)"
            ],
            shortTitle: "Quiet Time",
            systemImageName: "moon.stars.fill"
        )
    }
}
