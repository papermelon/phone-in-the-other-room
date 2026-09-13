import SwiftUI

/// A durable entry to the original update, with no replaying toast or attention claim.
struct SlumberPartyReceivedCheersSection: View {
    let party: NightFlockV4PartyDetail
    var onOpen: (UUID, UUID) -> Void

    var body: some View {
        let updates = SlumberPartySharedFarmRules.cheeredUpdatesForMe(in: party)
        if party.updateCheerReceiptVersion == 1, !updates.isEmpty, let me = party.myMemberID {
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("CHEERS FOR YOUR UPDATES")
                        .font(pixelFont(.caption)).foregroundStyle(AppColors.grass)
                    ForEach(updates.prefix(3)) { update in row(update, me: me) }
                    if updates.count > 3 {
                        DisclosureGroup("More cheered updates (\(updates.count - 3))") {
                            ForEach(updates.dropFirst(3)) { update in row(update, me: me) }
                        }.font(AppTypography.body)
                    }
                }
            }
        }
    }

    private func row(_ update: NightFlockV4SharedActivity, me: UUID) -> some View {
        let receipts = SlumberPartySharedFarmRules.receipts(for: update.id, in: party)
        let names = Set(receipts.compactMap { receipt in
            party.memberships.first { $0.memberID == receipt.senderMemberID }?.profile.displayName
        }).sorted().joined(separator: ", ")
        return Button { onOpen(me, update.id) } label: {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("From \(names)").font(AppTypography.body.weight(.semibold))
                Text(NightFlockV4Presentation.activityPresentation(for: update).cardSummary)
                    .font(AppTypography.caption)
                Text(update.occurredAt, format: .dateTime.day().month().year())
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this original shared update and its named cheers")
    }
}

#Preview("Durable recipient feedback") {
    SlumberPartyReceivedCheersSection(party: SlumberPartySharedFarmFixtures.party, onOpen: { _, _ in })
        .padding().background(AppColors.paper)
}
