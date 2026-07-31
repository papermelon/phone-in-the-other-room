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
                "Start Wind Down in \(.applicationName)",
                "Put my phone to bed with \(.applicationName)",
                "Start Wind Down with Ollie in \(.applicationName)"
            ],
            shortTitle: "Wind Down",
            systemImageName: "moon.stars.fill"
        )
    }
}
