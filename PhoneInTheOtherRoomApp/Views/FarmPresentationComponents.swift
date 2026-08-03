import SwiftUI

/// Shipping extraction of the useful Debug Farm presentation: the landscape,
/// featured sheep treatment, and restrained pagination affordance remain, while
/// economy/capacity data is deliberately absent.
struct ShippingFarmHeroScene: View {
    let sheep: SheepDefinition?
    let flockCount: Int

    private let artworkAspectRatio: CGFloat = 1784.0 / 882.0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                PixelAssetImage(name: AssetSlot.Farm.backgroundDay, contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()

                LinearGradient(
                    colors: [.clear, AppColors.bark.opacity(0.58)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack {
                    HStack(alignment: .top) {
                        arrivalBadge
                        Spacer(minLength: 0)
                    }
                    Spacer()
                }
                .padding(AppSpacing.sm)

                if let sheep {
                    ShippingFarmSheepFigure(sheep: sheep, size: min(142, size.width * 0.38))
                        .offset(x: -size.width * 0.07, y: size.height * 0.13)
                } else {
                    PixelAssetImage(name: AssetSlot.Dog.proud)
                        .frame(width: min(112, size.width * 0.30), height: min(112, size.width * 0.30))
                        .offset(x: -size.width * 0.06, y: size.height * 0.13)
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
        }
        .aspectRatio(artworkAspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .stroke(AppColors.stroke.opacity(0.24), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var arrivalBadge: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(sheep?.name ?? "Ollie's pasture")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(sheep == nil ? "A QUIET PLACE" : "A QUIET ARRIVAL")
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
