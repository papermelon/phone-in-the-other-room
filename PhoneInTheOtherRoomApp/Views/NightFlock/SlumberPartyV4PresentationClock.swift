import SwiftUI

/// Known presentation boundaries never perform transport work. Re-entering the
/// foreground evaluates the current instant rather than a suspended timeline tick.
struct SlumberPartyV4PresentationClock<Content: View>: View {
    let party: NightFlockV4PartyDetail?
    @ViewBuilder var content: (Date) -> Content
    @Environment(\.scenePhase) private var scenePhase
    @State private var resumedAt = Date()

    var body: some View {
        TimelineView(.explicit(invalidationDates)) { context in
            content(max(context.date, Date()))
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { resumedAt = Date() }
        }
    }

    private var invalidationDates: [Date] {
        let now = max(Date(), resumedAt)
        return NightFlockV4Presentation.timelineDates(in: party, at: now)
    }
}
