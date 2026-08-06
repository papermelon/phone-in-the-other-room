import AppIntents
import SwiftUI
import WidgetKit

struct QuietNoteConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Quiet Note"
    static let description = IntentDescription("Keep one gentle cue below the clock.")

    @Parameter(
        title: "Note",
        default: "Put your phone to bed. Wake up before it does."
    )
    var note: String
}

struct QuietNoteEntry: TimelineEntry {
    let date: Date
    let text: String
}

struct QuietNoteProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> QuietNoteEntry {
        QuietNoteEntry(date: Date(), text: QuietNoteText.defaultText)
    }

    func snapshot(
        for configuration: QuietNoteConfigurationIntent,
        in context: Context
    ) async -> QuietNoteEntry {
        QuietNoteEntry(
            date: Date(),
            text: QuietNoteText.normalized(configuration.note)
        )
    }

    func timeline(
        for configuration: QuietNoteConfigurationIntent,
        in context: Context
    ) async -> Timeline<QuietNoteEntry> {
        let entry = QuietNoteEntry(
            date: Date(),
            text: QuietNoteText.normalized(configuration.note)
        )
        return Timeline(entries: [entry], policy: .never)
    }
}

struct QuietNoteWidget: Widget {
    private static let kind = "com.ngawangchime.countingsheep.quiet-note"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: QuietNoteConfigurationIntent.self,
            provider: QuietNoteProvider()
        ) { entry in
            QuietNoteWidgetView(entry: entry)
        }
        .configurationDisplayName("Quiet Note")
        .description("Keep one gentle cue below the clock.")
        .supportedFamilies([.accessoryRectangular])
    }
}

private struct QuietNoteWidgetView: View {
    let entry: QuietNoteEntry

    var body: some View {
        Text(entry.text)
            .font(.caption.weight(.semibold))
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .privacySensitive()
            .accessibilityLabel("Quiet Note")
            .accessibilityValue(entry.text)
            .containerBackground(for: .widget) {}
    }
}

#Preview("Default note", as: .accessoryRectangular) {
    QuietNoteWidget()
} timeline: {
    QuietNoteEntry(date: Date(), text: QuietNoteText.defaultText)
}

#Preview("Custom note", as: .accessoryRectangular) {
    QuietNoteWidget()
} timeline: {
    QuietNoteEntry(date: Date(), text: "The book is where the phone used to be.")
}
