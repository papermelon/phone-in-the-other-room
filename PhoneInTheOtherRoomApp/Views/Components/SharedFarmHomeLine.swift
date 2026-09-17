import SwiftUI

/// Idle Home's one-line reason to look at the shared Farm: the newest thing a
/// friend actually did there. Silent when nothing new has arrived.
struct SharedFarmHomeLine: View {
    @ObservedObject var store: SharedFarmPrototypeStore

    var body: some View {
        if let line {
            HStack(alignment: .top, spacing: AppSpacing.xs) {
                Image(systemName: line.symbol)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.grass)
                    .accessibilityHidden(true)
                Text(line.text)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var line: (symbol: String, text: String)? {
        let now = Date()
        if let greeting = store.greetingsReceived.first {
            let contextTitle: String?
            switch greeting.context {
            case .update: contextTitle = "your shared update"
            case .visit: contextTitle = "your visiting sheep"
            case .meadow: contextTitle = nil
            }
            return (SharedFarmSocialCopy.cheerSymbol(greeting.cheer),
                    SharedFarmSocialCopy.recipientLine(cheer: greeting.cheer, senderName: store.displayName(for: greeting.senderMemberID),
                                                       contextTitle: contextTitle))
        }
        if let visit = store.currentVisits.first(where: { $0.memberID != store.myMemberID }) {
            return ("pawprint", SharedFarmSocialCopy.visitLine(sheepName: visit.sheepDisplayName, ownerName: store.displayName(for: visit.memberID),
                                                               isMe: false, nightsRemaining: visit.nightsRemaining(at: now)))
        }
        return nil
    }
}

#Preview("Home line") {
    VStack(alignment: .leading, spacing: AppSpacing.sm) {
        SharedFarmHomeLine(store: SharedFarmPrototypeFixtures.store())
        SharedFarmHomeLine(store: SharedFarmPrototypeFixtures.store(seeded: false))
    }
    .padding().background(AppColors.paper)
}
