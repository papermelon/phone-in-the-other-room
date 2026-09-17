import SwiftUI

struct NightFlockIdeasView: View {
    var body: some View {
        WindDownGuideView()
    }
}

#Preview("Legacy ideas route") {
    NavigationStack {
        NightFlockIdeasView()
            .environmentObject(FocusRunViewModel(startsExternalServices: false))
    }
}
