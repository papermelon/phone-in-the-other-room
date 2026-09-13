import AppIntents

struct PrepareNightWatchIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Wind Down"
    static var description = IntentDescription("Opens Counting Sheep so you can tuck your phone in for the night.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Ollie is ready for Wind Down. Put your phone to bed when you are ready.")
    }
}

struct PhoneInTheOtherRoomShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor { .lime }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PrepareNightWatchIntent(),
            phrases: [
                "Put my phone away with \(.applicationName)",
                "Put my phone to bed with \(.applicationName)",
                "Put my phone away with Ollie in \(.applicationName)"
            ],
            shortTitle: "Put phone away",
            systemImageName: "moon.stars.fill"
        )
    }
}
