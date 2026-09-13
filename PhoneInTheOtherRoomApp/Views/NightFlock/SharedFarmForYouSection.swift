import SwiftUI

/// One "for you" card instead of separate cheer, greeting and visitor lists.
/// Durable cheer receipts (existing contract) and prototype greetings share a
/// row style; each row names the sender and what they responded to.
struct SharedFarmForYouSection: View {
    let party: NightFlockV4PartyDetail
    @ObservedObject var store: SharedFarmPrototypeStore
    var onOpenUpdate: (UUID, UUID) -> Void

    var body: some View {
        let rows = rows()
        if !rows.isEmpty {
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("FOR YOU")
                        .font(pixelFont(.caption)).foregroundStyle(AppColors.grass)
                    ForEach(rows) { row in
                        if let activityID = row.activityID, let me = party.myMemberID {
                            Button { onOpenUpdate(me, activityID) } label: { label(row) }
                                .buttonStyle(.plain)
                                .accessibilityHint("Opens the original shared update")
                        } else {
                            label(row)
                        }
                    }
                    Text("Nothing here is sent back automatically. Reply from a friend’s card if you want to.")
                        .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                }
            }
        }
    }

    private struct Row: Identifiable {
        let id: String
        let symbol: String
        let title: String
        let detail: String
        let activityID: UUID?
    }

    private func label(_ row: Row) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: row.symbol)
                .font(.body).foregroundStyle(AppColors.grass)
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(row.title).font(AppTypography.body.weight(.semibold))
                Text(row.detail).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func rows() -> [Row] {
        var rows: [Row] = []
        let now = Date()
        if party.myMemberID != nil, party.updateCheerReceiptVersion == 1 {
            for update in SlumberPartySharedFarmRules.cheeredUpdatesForMe(in: party).prefix(3) {
                let receipts = SlumberPartySharedFarmRules.receipts(for: update.id, in: party)
                let names = Set(receipts.compactMap { r in party.memberships.first { $0.memberID == r.senderMemberID }?.profile.displayName })
                    .sorted().joined(separator: ", ")
                let cheer = receipts.first?.cheer ?? .warmWave
                rows.append(Row(
                    id: "cheer:\(update.id)", symbol: SharedFarmSocialCopy.cheerSymbol(cheer),
                    title: "\(names) sent a \(SharedFarmSocialCopy.cheerTitle(cheer).lowercased()) for your update",
                    detail: NightFlockV4Presentation.activityPresentation(for: update).cardSummary, activityID: update.id))
            }
        }
        for greeting in store.greetingsReceived.prefix(3) {
            let sender = store.displayName(for: greeting.senderMemberID)
            let alreadyListed = rows.contains { row in
                if case .update(let id) = greeting.context { return row.id == "cheer:\(id)" }
                return false
            }
            guard !alreadyListed else { continue }
            let contextID: UUID?
            let contextTitle: String?
            switch greeting.context {
            case .update(let id):
                contextID = id
                contextTitle = party.sharedActivities.first { $0.id == id }.map {
                    "your \(NightFlockV4Presentation.activityPresentation(for: $0).modeTitle) \(SharedFarmSocialCopy.relativeNight($0.occurredAt, now: now))"
                } ?? "your shared update"
            case .visit(let visitID):
                contextID = nil
                contextTitle = store.visits.first { $0.id == visitID }.map { "your visiting \($0.sheepDisplayName)" } ?? "your visiting sheep"
            case .meadow:
                contextID = nil
                contextTitle = nil
            }
            rows.append(Row(id: "greeting:\(greeting.id)", symbol: SharedFarmSocialCopy.cheerSymbol(greeting.cheer),
                            title: SharedFarmSocialCopy.recipientLine(cheer: greeting.cheer, senderName: sender, contextTitle: contextTitle),
                            detail: SharedFarmSocialCopy.relativeNight(greeting.sentAt, now: now), activityID: contextID))
        }
        // Visiting sheep are already named under the meadow; repeating them here
        // was one of the duplications this prototype set out to remove.
        return rows
    }
}

#Preview("For you") {
    SharedFarmForYouSection(party: SharedFarmPrototypeFixtures.party, store: SharedFarmPrototypeFixtures.store(), onOpenUpdate: { _, _ in })
        .padding().background(AppColors.paper)
}
