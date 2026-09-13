import SwiftUI

struct OllieDetailView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    let onPlay: (FarmPasturePlayAction) -> Void

    var body: some View {
        OllieDetailContent(state: viewModel.farmState, onPlay: onPlay) { item in
            if viewModel.farmState.equipment.ollieAccessoryItemID == item.id {
                viewModel.takeOffOllieAccessory(item.id)
            } else {
                viewModel.wearOllieAccessory(item.id)
            }
        }
        .farmActionAlert(viewModel: viewModel)
    }
}

private struct OllieDetailContent: View {
    let state: FarmState
    let onPlay: (FarmPasturePlayAction) -> Void
    let onToggle: (FarmShopItem) -> Void
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var accessories: [FarmShopItem] {
        FarmShopCatalog.items(in: .ollie).filter { state.ownedShopItemIDs.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Your companion at the Farm.")
                    .font(AppTypography.body).foregroundStyle(AppColors.secondaryText)
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    sectionTitle("PLAY TOGETHER")
                    Button { onPlay(.fetch) } label: {
                        Label("Fetch with Ollie", systemImage: "tennisball")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(PixelChipButtonStyle(isSelected: false))
                    Button { onPlay(.gather) } label: {
                        Label("Gather the sheep", systemImage: "pawprint")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(PixelChipButtonStyle(isSelected: false))
                    Text("Play takes you back to the pasture.")
                        .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                }
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    sectionTitle("OLLIE’S ACCESSORIES")
                    if accessories.isEmpty {
                        Text("Ollie is ready just as he is. Any accessories you bring home will be here.")
                            .font(AppTypography.body).foregroundStyle(AppColors.secondaryText)
                    }
                    ForEach(accessories) { item in
                        let isWorn = state.equipment.ollieAccessoryItemID == item.id
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            HStack(spacing: AppSpacing.sm) {
                                FarmShopItemImage(item: item, size: 54).frame(width: 54, height: 54)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                    Text(item.title).font(AppTypography.headline)
                                    Text(isWorn ? "Equipped" : "Owned")
                                        .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                                }
                            }
                            Button(isWorn ? "Take off" : "Wear") { onToggle(item) }
                                .buttonStyle(PixelChipButtonStyle(isSelected: isWorn))
                                .frame(minHeight: 44)
                                .accessibilityLabel("\(isWorn ? "Take off" : "Wear") \(item.title)")
                        }
                        .padding(AppSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.md))
                    }
                    NavigationLink("Browse Ollie’s accessories in Shop") {
                        FarmShopView(initialCategory: .ollie)
                    }.buttonStyle(PixelChipButtonStyle(isSelected: false)).frame(minHeight: 44)
                }
            }
            .padding(AppSpacing.md)
            .padding(.bottom, AppSpacing.xl)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            OllieFarmAvatar(accessoryItemID: state.equipment.ollieAccessoryItemID,
                            size: verticalSizeClass == .compact ? 80 : 120, motionEnabled: false)
                .frame(maxWidth: .infinity).padding(.vertical, AppSpacing.xs)
                .background(AppColors.surface)
                .overlay(alignment: .bottom) { Divider() }
                .accessibilityLabel("Ollie’s current look")
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Ollie")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(pixelFont(.caption)).foregroundStyle(AppColors.grass)
    }
}

#Preview("Ollie · no accessories") {
    NavigationStack { OllieDetailContent(state: .empty, onPlay: { _ in }, onToggle: { _ in }) }
}

#Preview("Ollie · large text") {
    NavigationStack { OllieDetailContent(state: FarmPreviewData.fullState, onPlay: { _ in }, onToggle: { _ in }) }
        .dynamicTypeSize(.accessibility3)
}
