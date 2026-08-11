import SwiftUI

#Preview("Farm Shop · catalogue") {
    NavigationStack {
        FarmShopView()
    }
    .environmentObject(FocusRunViewModel())
}

#Preview("Farm Shop · large type") {
    NavigationStack {
        FarmShopView(initialCategory: .farm)
    }
    .environmentObject(FocusRunViewModel())
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Farm equipment · dark · small device") {
    ScrollView {
        FarmEquipmentPreviewContent()
            .padding(AppSpacing.md)
    }
    .background(AppColors.paper.ignoresSafeArea())
    .environment(\.colorScheme, .dark)
    .environment(\.dynamicTypeSize, .accessibility2)
    .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
}

#Preview("Farm equipment · light") {
    ScrollView {
        FarmEquipmentPreviewContent()
            .padding(AppSpacing.md)
    }
    .background(AppColors.paper.ignoresSafeArea())
    .environment(\.colorScheme, .light)
}

private struct FarmEquipmentPreviewContent: View {
    private let state = FarmPreviewData.fullState

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("EQUIPPED FARM ART")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76))], spacing: AppSpacing.sm) {
                ForEach(["ollie_moss_bandana", "ollie_moon_kerchief", "ollie_brass_bell"], id: \.self) { itemID in
                    VStack(spacing: AppSpacing.xxs) {
                        OllieFarmAvatar(accessoryItemID: itemID, size: 78)
                        Text(FarmShopCatalog.item(for: itemID)?.title ?? itemID)
                            .font(.caption2.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92))], spacing: AppSpacing.sm) {
                ForEach(ShepherdHairStyle.allCases) { hairStyle in
                    ShepherdAvatarView(
                        profile: ShepherdProfile(
                            skinTone: .warm,
                            hairStyle: hairStyle,
                            outfitItemID: "shepherd_moss_coat",
                            accessoryItemID: "shepherd_wool_hat"
                        ),
                        size: 96
                    )
                    .accessibilityLabel("Wool Field Hat, \(hairStyle.title) hair")
                }
            }

            FarmKeepsakeDisplay(state: state)
            FarmPastureView(
                state: state,
                protectedNightCount: 18,
                layoutSeed: 42,
                onSelectSheep: { _ in }
            )
        }
    }
}
