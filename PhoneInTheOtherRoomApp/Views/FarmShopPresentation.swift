import SwiftUI

struct WoolBalanceBadge: View {
    let value: Int

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "cloud.fill")
                .font(.headline.weight(.bold))
            Text("\(value)")
                .font(PixelTypography.mono(.headline))
            Text("WOOL")
                .font(pixelFont(.caption2))
        }
        .foregroundStyle(AppColors.bark)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColors.wool.opacity(0.72), in: RoundedRectangle(cornerRadius: AppRadius.md))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) wool available")
    }
}

extension FarmShopCategory {
    var shopTitle: String {
        switch self {
        case .barn: return "Barn"
        case .ollie: return "Ollie"
        case .shepherd: return "Shepherd"
        case .farm: return "Farm"
        case .collectibles: return "Keepsakes"
        }
    }

    var shopSymbol: String {
        switch self {
        case .barn: return "house.lodge.fill"
        case .ollie: return "pawprint.fill"
        case .shepherd: return "person.fill"
        case .farm: return "leaf.fill"
        case .collectibles: return "shippingbox.fill"
        }
    }

    var shopEyebrow: String {
        switch self {
        case .barn: return "ROOM TO GROW"
        case .ollie: return "FOR OLLIE"
        case .shepherd: return "YOUR WARDROBE"
        case .farm: return "AROUND THE FARM"
        case .collectibles: return "FARM KEEPSAKES"
        }
    }

    var shopDescription: String {
        switch self {
        case .barn: return "Open another pasture when your flock needs more room."
        case .ollie: return "Small farm treasures for the collie who brings everyone home."
        case .shepherd: return "Clothes and field gear for your place beside Ollie."
        case .farm: return "Add warm corners and familiar landmarks to the pasture."
        case .collectibles: return "Keep a few objects from the stories behind the flock."
        }
    }
}

#Preview("Wool badge · no wool") {
    WoolBalanceBadge(value: 0)
        .padding()
        .background(AppColors.paper)
}

#Preview("Wool badge · generous balance") {
    WoolBalanceBadge(value: 12_480)
        .padding()
        .background(AppColors.paper)
        .environment(\.dynamicTypeSize, .accessibility2)
}
