import SwiftUI

/// Shipping extraction of the useful Debug Farm presentation: the landscape,
/// featured sheep treatment, and restrained pagination affordance remain, while
/// economy/capacity data is deliberately absent.
struct ShippingFarmHeroScene: View {
    let sheep: SheepDefinition?
    let flockCount: Int

    var body: some View {
        ZStack {
            PixelAssetImage(name: AssetSlot.Farm.backgroundDay, contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            LinearGradient(
                colors: [.clear, AppColors.bark.opacity(0.58)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack {
                HStack(alignment: .top) {
                    fieldNoteBadge
                    Spacer()
                }
                Spacer()
            }
            .padding(AppSpacing.sm)

            if let sheep {
                ShippingFarmSheepFigure(sheep: sheep, size: 142)
                    .offset(x: -24, y: 26)
            } else {
                PixelAssetImage(name: AssetSlot.Dog.proud)
                    .frame(width: 112, height: 112)
                    .offset(x: -20, y: 28)
                    .accessibilityLabel("Ollie watching the pasture")
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("\(flockCount) settled")
                        .font(pixelFont(.caption2))
                        .foregroundStyle(AppColors.ink)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)
                        .background(AppColors.panel.opacity(0.94), in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                }
                .padding(.trailing, AppSpacing.md)
                .padding(.bottom, AppSpacing.md)
            }
        }
        .frame(height: 204)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .stroke(AppColors.stroke.opacity(0.24), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var fieldNoteBadge: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(sheep?.name ?? "Ollie's pasture")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(sheep == nil ? "FIELD NOTES" : "A QUIET ARRIVAL")
                .font(pixelFont(.caption2))
                .foregroundStyle(AppColors.grass)
        }
        .padding(AppSpacing.sm)
        .frame(width: 142, alignment: .leading)
        .background(AppColors.panel.opacity(0.92), in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .stroke(AppColors.stroke.opacity(0.35), lineWidth: 1)
        }
    }
}

private struct ShippingFarmSheepFigure: View {
    let sheep: SheepDefinition
    let size: CGFloat

    var body: some View {
        PixelAssetImage(name: sheep.assetName)
            .frame(width: size, height: size)
            .accessibilityLabel(sheep.name)
    }
}
