import SwiftUI

/// One chronological index; each row opens the original update and its receipts.
struct SlumberPartyGroupStreamView: View {
    let party: NightFlockV4PartyDetail
    var onOpen: (UUID, UUID) -> Void
    private var updates: [NightFlockV4SharedActivity] {
        SlumberPartySharedFarmRules.groupUpdates(in: party)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("SHARED MOMENTS").font(pixelFont(.caption)).foregroundStyle(AppColors.grass)
            if updates.isEmpty {
                Text("The first shared moment is still to come.").font(AppTypography.body)
            } else {
                ForEach(updates.prefix(4)) { row($0) }
                if updates.count > 4 {
                    DisclosureGroup("Earlier moments") { ForEach(updates.dropFirst(4)) { row($0) } }
                        .font(AppTypography.body).tint(AppColors.grass)
                }
            }
        }
    }
    private func row(_ update: NightFlockV4SharedActivity) -> some View {
        Button { onOpen(update.memberID, update.id) } label: {
            HStack(spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(party.memberships.first { $0.memberID == update.memberID }?.profile.displayName ?? "A member")
                        .font(AppTypography.headline)
                    Text(NightFlockV4Presentation.activityPresentation(for: update).cardSummary)
                        .font(AppTypography.caption)
                    Text(update.occurredAt, format: .dateTime.day().month().hour().minute())
                        .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right").accessibilityHidden(true)
            }.frame(minHeight: 56)
        }.buttonStyle(.plain).accessibilityHint("Opens this update and its responses")
    }
}

#Preview("Group stream") { SlumberPartyGroupStreamView(party: SlumberPartySharedFarmFixtures.party, onOpen: { _, _ in }).padding() }
