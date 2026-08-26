import SwiftUI

struct NightFlockSharedPastureView: View {
    @ObservedObject var viewModel: NightFlockViewModel
    let snapshot: NightFlockSnapshot

    private var entries: [NightFlockPastureEntry] {
        let positiveEntries = snapshot.days.flatMap(\.pasture).filter {
            $0.state == .morningQuietCompleted
        }
        return NightFlockPrivacyPresentation.pastureEntries(
            positiveEntries,
            memberCount: snapshot.members.count
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("SHARED CHEERS")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("Encouragement for the seven nights.")
                    .font(AppTypography.title)
                Text("Send a small fixed reaction to a shared update. No update shared is never shown as completion.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)

                if entries.isEmpty {
                    NightFlockStatusCard(
                        symbol: "sun.horizon.fill",
                        title: "No shared cheers yet.",
                        detail: "Shared goal updates will appear here when someone chooses to share one."
                    )
                } else {
                    ForEach(entries) { entry in
                        pastureEntry(entry)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(AppSpacing.md)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Shared Pasture")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func pastureEntry(_ entry: NightFlockPastureEntry) -> some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Label("A group member shared morning quiet", systemImage: "sun.max.fill")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.ink)
                Text("Send encouragement without sharing an exact time or duration.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                HStack(spacing: AppSpacing.xs) {
                    ForEach(NightFlockReactionKind.allCases) { reaction in
                        let summary = entry.reactions.first(where: { $0.kind == reaction })
                        Button {
                            viewModel.react(to: entry, with: reaction)
                        } label: {
                            Label("\(summary?.count ?? 0)", systemImage: reaction.symbolName)
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(PixelChipButtonStyle(isSelected: summary?.reactedByMe == true))
                        .accessibilityLabel("\(reaction.title), \(summary?.count ?? 0) reactions")
                    }
                }
            }
        }
    }
}

struct NightFlockResultCard: View {
    let snapshot: NightFlockSnapshot?

    var body: some View {
        PixelCard {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: "sun.horizon.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColors.amber)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("SLUMBER PARTY")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text("A shared goal update was posted.")
                        .font(AppTypography.headline)
                    Text("This is a supportive group record. Shared nights can bring a little wool, a small keepsake, or one Slumber Party sheep. Reactions do not.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}
