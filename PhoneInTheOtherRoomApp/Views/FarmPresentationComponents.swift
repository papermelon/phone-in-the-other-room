import SwiftUI

/// The pasture scene is decorative context for the real-data Farm. Flock count,
/// arrivals, and trail evidence stay in separate, scalable SwiftUI content.
struct ShippingFarmHeroScene: View {
    let sheep: SheepDefinition?

    private let artworkAspectRatio: CGFloat = 1784.0 / 882.0

    var body: some View {
        ZStack {
            PixelAssetImage(name: AssetSlot.Farm.backgroundDay, contentMode: .fill)
                .accessibilityHidden(true)

            LinearGradient(
                colors: [.clear, AppColors.bark.opacity(0.42)],
                startPoint: .top,
                endPoint: .bottom
            )

            if let sheep {
                PixelAssetImage(name: sheep.assetName)
                    .frame(width: 132, height: 132)
                    .offset(x: -52, y: 34)
                    .accessibilityLabel(sheep.name)
            } else {
                PixelAssetImage(name: AssetSlot.Dog.proud)
                    .frame(width: 112, height: 112)
                    .offset(x: -42, y: 34)
                    .accessibilityLabel("Ollie watching the pasture")
            }
        }
        .aspectRatio(artworkAspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .stroke(AppColors.stroke.opacity(0.24), lineWidth: 1)
        }
    }
}

struct FarmArrivalCard: View {
    let sheep: SheepDefinition?
    let outcome: SheepSearchOutcome?

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(sheep == nil ? "A QUIET PASTURE" : "LATEST ARRIVAL")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)

                if let sheep {
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        PixelAssetImage(name: sheep.assetName)
                            .frame(width: 72, height: 72)
                            .accessibilityLabel(sheep.name)
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text(sheep.name)
                                .font(AppTypography.title)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(sheep.story)
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if let outcome {
                        let habitat = outcome.habitat?.title ?? sheep.habitat.title
                        let distance = String(format: "%.1f km", outcome.trailDistance)
                        Text("Home from " + habitat + " · " + distance + " trail")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text("The pasture is quiet for now.")
                        .font(AppTypography.title)
                    Text("No sheep have come home yet. Ollie’s search moves only after eligible completed protected nights.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
    }
}
