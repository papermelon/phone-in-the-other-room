import SwiftUI

struct SharedPastureSheepSheet: View {
    @ObservedObject var social: NightFlockViewModel
    let partyID: UUID
    @EnvironmentObject private var app: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss
    private var party: NightFlockV4PartyDetail? { social.v4ObservedPartyDetail(for: partyID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    if let party, let state = party.pasture, state.isSupported {
                        Text("Send one of your sheep to stay beside your Shepherd. Its name and look are shared with this party until you bring it home. Your flock keeps its progress.")
                            .font(AppTypography.body)
                        ForEach(state.visits) { visit in
                            HStack(spacing: AppSpacing.sm) {
                                PixelAssetImage(name: SheepCatalog.definition(for: visit.sheepDefinitionID)?.assetName ?? AssetSlot.Sheep.common)
                                    .frame(width: 52, height: 52).accessibilityHidden(true)
                                VStack(alignment: .leading) {
                                    Text(visit.sheepDisplayName).font(AppTypography.headline)
                                    Text("With \(party.memberships.first { $0.memberID == visit.memberID }?.profile.displayName ?? "their Shepherd")")
                                        .font(AppTypography.caption)
                                }
                                Spacer()
                                if visit.memberID == party.myMemberID {
                                    Button("Bring home") { social.recallSheep(visit.id, partyID: partyID) }
                                        .frame(minHeight: 44)
                                }
                            }
                        }
                        Text("YOUR FLOCK").font(pixelFont(.caption)).foregroundStyle(AppColors.grass)
                        ForEach(app.farmState.activeSheep) { sheep in
                            let visiting = social.visitingSheepIDs.contains(sheep.id)
                            Button { social.contributeSheep(sheep.id, partyID: partyID) } label: {
                                HStack {
                                    Text(sheep.displayName)
                                    Spacer()
                                    Text(visiting ? "Visiting" : "Send to visit")
                                }.font(AppTypography.body).frame(minHeight: 48)
                            }
                            .buttonStyle(PixelChipButtonStyle(isSelected: visiting))
                            .disabled(visiting || social.pastureSending.contains(partyID))
                        }
                        if app.farmState.activeSheep.isEmpty { Text("Your flock is waiting for its first arrival.").font(AppTypography.body) }
                        Text("Your sheep must be saved to your account before it can visit. Only one sheep per party; each sheep visits one party at a time.")
                            .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                        SharedPastureSaveFeedback(social: social, partyID: partyID)
                    } else {
                        Text("Sheep visits aren’t available for this party yet. You can still open everyone’s shared updates.")
                            .font(AppTypography.body)
                    }
                }.padding(AppSpacing.md)
            }
            .background(AppColors.paper.ignoresSafeArea()).navigationTitle("Sheep in the meadow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct SharedPastureLanternSheet: View {
    let lantern: SharedPastureLantern?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                PaperPastureLantern(isLit: lantern?.isComplete == true).frame(width: 96, height: 120).frame(maxWidth: .infinity)
                if let lantern {
                    Text(lantern.isComplete ? "A little more light" : "A lantern for our meadow").font(AppTypography.title)
                    Text("The campfire is free from day one. This lantern is an extra light everyone earns together.").font(AppTypography.body)
                    ProgressView(value: Double(min(lantern.contributions, lantern.requiredContributions)), total: Double(max(1, lantern.requiredContributions)))
                        .tint(AppColors.grass)
                    Text("\(min(lantern.contributions, lantern.requiredContributions)) of \(lantern.requiredContributions) contributions").font(AppTypography.body)
                    Text("Your first completed Wind Down or Phone Away that earns a round grant counts once per party-day. Everyone’s contributions stay across rounds. Early endings keep their usual Farm credit.")
                        .font(AppTypography.body)
                    if lantern.isComplete { Text("Everyone can arrange the lantern in the shared meadow.").font(AppTypography.caption) }
                } else {
                    Text("The earned lantern isn’t available for this party yet.").font(AppTypography.body)
                }
            }.padding(AppSpacing.md)
            }.background(AppColors.paper.ignoresSafeArea())
                .navigationTitle("Our lantern").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct SharedPastureSaveFeedback: View {
    @ObservedObject var social: NightFlockViewModel
    let partyID: UUID
    var body: some View {
        if let message = social.pastureMessages[partyID] {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(message).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                if message.contains("hasn’t") || message.contains("retry") {
                    Button("Retry saved change") { social.recoverPasture(partyID: partyID, retry: true) }
                        .buttonStyle(PixelChipButtonStyle(isSelected: false)).frame(minHeight: 44)
                }
            }
        }
    }
}

/// Separate interactive scenery; the background never promises a reward state.
struct PaperPastureLantern: View {
    var isLit: Bool
    var body: some View {
        ZStack {
            if isLit { Ellipse().fill(AppColors.grassLight.opacity(0.22)).frame(width: 70, height: 24).offset(y: 40) }
            RoundedRectangle(cornerRadius: 3).fill(AppColors.bark).frame(width: 7, height: 84).offset(x: -15, y: 6)
            RoundedRectangle(cornerRadius: 3).fill(AppColors.bark).frame(width: 37, height: 6).offset(y: -33)
            RoundedRectangle(cornerRadius: 5).fill(isLit ? AppColors.amber : AppColors.surfaceMuted)
                .frame(width: 25, height: 32).overlay(RoundedRectangle(cornerRadius: 5).stroke(AppColors.bark, lineWidth: 3)).offset(x: 10, y: -12)
        }.accessibilityLabel(isLit ? "Earned meadow lantern" : "Meadow lantern")
    }
}

#Preview("Lantern · in progress") { SharedPastureLanternSheet(lantern: .init(contributions: 5, requiredContributions: 12, completedAt: nil)) }
#Preview("Lantern · unsupported") { SharedPastureLanternSheet(lantern: nil) }
