#if DEBUG
import SwiftUI

/// Isolated native layout fixture; readiness is presentation-only and never authorizes a start.
struct FirstStartSheetPreview: View {
    var readiness: ShieldingReadiness = .authorizationRequired
    var usesNFC = false
    var phoneAway = false
    @StateObject private var model = Self.makeModel()
    @State private var showsSheet = true

    var body: some View {
        Color.clear
            .sheet(isPresented: $showsSheet) {
                WindDownStartSheet(previewReadiness: readiness)
                    .environmentObject(model)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                if phoneAway { model.startNewOneTimeAdditionalQuietNow() }
                model.selectedGuardKind = usesNFC ? .nfcTag : .honorTimer
            }
    }

    private static func makeModel() -> FocusRunViewModel {
        let defaults = UserDefaults(suiteName: "FirstStartSheetPreview.\(UUID().uuidString)")!
        let persistence = PersistenceService(defaults: defaults)
        let coordinator = FocusSessionCoordinator(
            persistence: persistence,
            watch: .inactiveForDeterministicCapture(),
            notificationEffectsEnabled: false
        )
        return FocusRunViewModel(coordinator: coordinator, persistence: persistence, startsExternalServices: false)
    }

    static var launchReadiness: ShieldingReadiness {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--denied") { return .denied }
        if args.contains("--revoked") { return .revoked }
        if args.contains("--empty") { return .noSelection }
        if args.contains("--ready") { return .ready }
        if args.contains("--failure") { return .runtimeFailure }
        if args.contains("--unavailable") { return .unavailable }
        return .authorizationRequired
    }
}

#Preview("Allow Screen Time") { FirstStartSheetPreview() }
#Preview("Choose apps · large text") {
    FirstStartSheetPreview(readiness: .noSelection).environment(\.dynamicTypeSize, .accessibility3)
}
#Preview("Denied") { FirstStartSheetPreview(readiness: .denied) }
#Preview("Protection failed") { FirstStartSheetPreview(readiness: .runtimeFailure) }
#Preview("Ready · NFC · dark") {
    FirstStartSheetPreview(readiness: .ready, usesNFC: true).preferredColorScheme(.dark)
}
#Preview("Unavailable") { FirstStartSheetPreview(readiness: .unavailable) }
#Preview("Phone Away · large text") {
    FirstStartSheetPreview(readiness: .noSelection, phoneAway: true)
        .environment(\.dynamicTypeSize, .accessibility3)
}
#endif
