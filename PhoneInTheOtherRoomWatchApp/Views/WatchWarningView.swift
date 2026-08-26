import SwiftUI

/// Retained for older persisted runs that may still carry the former warning state.
/// New runs never use continuous proximity warnings.
struct WatchWarningView: View {
    var body: some View {
        WatchRunView()
    }
}
