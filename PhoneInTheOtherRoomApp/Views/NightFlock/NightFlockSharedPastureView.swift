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
                Text("SHARED PASTURE")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("Quiet mornings, gathered gently.")
                    .font(AppTypography.title)
                Text(snapshot.members.count <= 3
                    ? "A small flock's pasture stays qualitative. No count, absence, or private night is shown."
                    : "Only completed quiet mornings appear. No absence or private night is named.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)

                if entries.isEmpty {
                    NightFlockStatusCard(
                        symbol: "sun.horizon.fill",
                        title: "The morning pasture is quiet.",
                        detail: "Positive notes will settle here when they are shared."
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
                Label("A quiet morning reached the pasture", systemImage: "sun.max.fill")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.ink)
                Text("Shared without a name, rank, exact time, or duration.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                HStack(spacing: AppSpacing.xs) {
                    ForEach(NightFlockReactionKind.allCases) { reaction in
                        let summary = entry.reactions.first(where: { $0.kind == reaction })
                        Button {
                            viewModel.react(to: entry, with: reaction)
                        } label: {
                            if snapshot.members.count <= 3 {
                                Image(systemName: reaction.symbolName)
                                    .accessibilityLabel(reaction.title)
                            } else {
                                Label("\(summary?.count ?? 0)", systemImage: reaction.symbolName)
                                    .labelStyle(.titleAndIcon)
                            }
                        }
                        .buttonStyle(PixelChipButtonStyle(isSelected: summary?.reactedByMe == true))
                        .accessibilityLabel(snapshot.members.count <= 3
                            ? reaction.title
                            : "\(reaction.title), \(summary?.count ?? 0) reactions")
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
                    Text("A quiet morning reached the shared pasture.")
                        .font(AppTypography.headline)
                    Text("This group Trail Note is narrative only. It adds no wool, sheep, rank, or reward.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}
