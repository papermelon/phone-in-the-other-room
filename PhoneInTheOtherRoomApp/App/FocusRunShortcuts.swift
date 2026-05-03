import AppIntents
import Foundation

struct PrepareFocusRunIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Focus Run"
    static var description = IntentDescription("Prepares Phone in the Other Room with a Focus Run duration. Add Apple's Focus action and Open App action in Shortcuts to complete the flow.")

    @Parameter(title: "Minutes", default: 25)
    var minutes: Int

    @Parameter(title: "Seconds", default: 0)
    var seconds: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        FocusRunShortcutStore.savePendingDuration(minutes: minutes, seconds: seconds)
        let label = durationLabel(minutes: minutes, seconds: seconds)
        return .result(dialog: "Prepared a \(label) Focus Run. Turn on Focus in this Shortcut, then open Phone in the Other Room.")
    }

    private func durationLabel(minutes: Int, seconds: Int) -> String {
        let clampedMinutes = min(max(minutes, 0), 180)
        let clampedSeconds = min(max(seconds, 0), 59)
        let totalSeconds = max(1, (clampedMinutes * 60) + clampedSeconds)
        let displayMinutes = totalSeconds / 60
        let displaySeconds = totalSeconds % 60
        if displaySeconds == 0 { return "\(displayMinutes)-minute" }
        if displayMinutes == 0 { return "\(displaySeconds)-second" }
        return "\(displayMinutes)-minute \(displaySeconds)-second"
    }
}

struct PhoneInTheOtherRoomShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor { .lime }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PrepareFocusRunIntent(),
            phrases: [
                "Start a Focus Run in \(.applicationName)",
                "Prepare a Focus Run in \(.applicationName)",
                "Send Ollie out in \(.applicationName)"
            ],
            shortTitle: "Start Focus Run",
            systemImageName: "figure.run"
        )
    }
}
