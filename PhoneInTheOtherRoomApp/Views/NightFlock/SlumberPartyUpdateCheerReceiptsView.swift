import SwiftUI

struct SlumberPartyUpdateCheerReceiptsView: View {
    @ObservedObject var viewModel: NightFlockViewModel
    let party: NightFlockV4PartyDetail
    let activityID: UUID
    private var receipts: [SlumberPartyUpdateCheerReceipt] { SlumberPartySharedFarmRules.receipts(for: activityID, in: party) }

    var body: some View {
        if party.updateCheerReceiptVersion == 1 {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                ForEach(receipts) { receipt in
                    let sender = party.memberships.first { $0.memberID == receipt.senderMemberID }?.profile.displayName ?? "A member"
                    let title = receipt.cheer == .warmWave ? "Warm wave" : receipt.cheer == .moonGlow ? "Moon glow" : "Paw print"
                    Text("\(sender) · \(title)")
                        .font(AppTypography.caption.weight(.semibold))
                    Text(receipt.receivedByAppAt == nil ? "Accepted by Slumber Party" : "Received by the recipient’s app")
                        .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                }
                if receipts.contains(where: { $0.recipientMemberID == party.myMemberID && $0.receivedByAppAt == nil }) {
                    Button(receipts.contains(where: { viewModel.updateCheerAcknowledgements[$0.id] == .pending }) ? "Confirming app receipt…" : "Retry app confirmation") {
                        viewModel.acknowledgeUpdateCheers(partyID: party.summary.partyID, activityID: activityID)
                    }
                    .disabled(receipts.contains { viewModel.updateCheerAcknowledgements[$0.id] == .pending })
                    .frame(minHeight: 44)
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                }
            }
            .task(id: receipts.map(\.reactionID)) {
                viewModel.acknowledgeUpdateCheers(partyID: party.summary.partyID, activityID: activityID)
            }
        }
    }
}

#Preview("Named app receipt") {
    let party = SlumberPartySharedFarmFixtures.party
    SlumberPartyUpdateCheerReceiptsView(viewModel: NightFlockViewModel(featureEnabled: false),
        party: party, activityID: party.sharedActivities[0].id)
        .padding().background(AppColors.paper)
}
