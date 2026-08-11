import SwiftUI

struct FarmPastureView: View {
    let state: FarmState
    let protectedNightCount: Int
    let layoutSeed: UInt64
    let onSelectSheep: (FlockSheep) -> Void

    private var pastureCount: Int { max(1, state.activeCapacity / 12) }

    var body: some View {
        TabView {
            ForEach(0..<pastureCount, id: \.self) { pasture in
                pasturePage(pasture)
                    .padding(.horizontal, 1)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: pastureCount > 1 ? .always : .never))
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .stroke(AppColors.stroke.opacity(0.28), lineWidth: 1)
        }
        .accessibilityLabel("Farm pasture, \(state.activeSheep.count) active sheep across \(pastureCount) pastures")
    }

    private func pasturePage(_ pasture: Int) -> some View {
        let pageSheep = Array(state.activeSheep.dropFirst(pasture * 12).prefix(12))
        let slots = slotAssignments(for: pageSheep)
        return GeometryReader { proxy in
            ZStack {
                PixelAssetImage(name: AssetSlot.Farm.backgroundDay, contentMode: .fill)
                    .accessibilityHidden(true)
                LinearGradient(
                    colors: [.clear, AppColors.grass.opacity(0.16), AppColors.bark.opacity(0.34)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                if pasture == 0 {
                    decorations(in: proxy.size)
                }

                ForEach(pageSheep) { sheep in
                    Button { onSelectSheep(sheep) } label: {
                        FarmSheepSprite(
                            sheep: sheep,
                            protectedNightCount: protectedNightCount,
                            size: spriteSize(for: slots[sheep.id] ?? 0),
                            showsStatusBadge: false
                        )
                    }
                    .buttonStyle(.plain)
                    .position(
                        position(
                            for: slots[sheep.id] ?? 0,
                            sheepID: sheep.id,
                            pasture: pasture,
                            in: proxy.size
                        )
                    )
                    .zIndex(Double((slots[sheep.id] ?? 0) / 4))
                    .accessibilityHint("Opens \(sheep.displayName) in The Barn")
                }

                OllieFarmAvatar(
                    accessoryItemID: state.equipment.ollieAccessoryItemID,
                    size: 72
                )
                .position(x: proxy.size.width * 0.10, y: proxy.size.height * 0.82)

                ShepherdAvatarView(profile: state.shepherd, size: 72)
                    .position(x: proxy.size.width * 0.94, y: proxy.size.height * 0.76)

                if pageSheep.isEmpty {
                    VStack(spacing: AppSpacing.xs) {
                        Text(pasture == 0 ? "The pasture is quiet." : "This pasture is open.")
                            .font(AppTypography.headline)
                        Text(pasture == 0
                            ? "A completed Wind Down gives Ollie a trail to follow."
                            : "New arrivals can settle here when they come home.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.paper.opacity(0.88), in: RoundedRectangle(cornerRadius: AppRadius.md))
                    .position(x: proxy.size.width * 0.52, y: proxy.size.height * 0.42)
                }

                Text("PASTURE \(pasture + 1)")
                    .font(pixelFont(.caption2))
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .foregroundStyle(AppColors.bark)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, AppSpacing.xxs)
                    .background(AppColors.paper.opacity(0.84), in: Capsule())
                    .padding(.leading, AppSpacing.lg)
                    .padding(.top, AppSpacing.sm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    @ViewBuilder
    private func decorations(in size: CGSize) -> some View {
        ForEach(state.equipment.farmDecorationItemIDs.sorted(), id: \.self) { itemID in
            if let item = FarmShopCatalog.item(for: itemID),
               let anchor = FarmShopCatalog.decorationAnchor(for: itemID),
               anchor.isBounded {
                FarmShopItemImage(item: item, size: CGFloat(anchor.size))
                    .position(
                        x: size.width * CGFloat(anchor.normalizedCenterX),
                        y: size.height * CGFloat(anchor.normalizedGroundY) - CGFloat(anchor.size) / 2
                    )
                    .accessibilityHidden(true)
            }
        }
    }

    private func position(
        for index: Int,
        sheepID: UUID,
        pasture: Int,
        in size: CGSize
    ) -> CGPoint {
        let positions: [(CGFloat, CGFloat)] = [
            (0.25, 0.62), (0.41, 0.62), (0.57, 0.62), (0.73, 0.62),
            (0.30, 0.75), (0.46, 0.75), (0.62, 0.75), (0.78, 0.75),
            (0.25, 0.88), (0.41, 0.88), (0.57, 0.88), (0.73, 0.88)
        ]
        let value = positions[min(index, positions.count - 1)]
        let random = stableHash(for: sheepID)
            ^ layoutSeed
            ^ (UInt64(pasture + 1) &* 11_400_714_819_323_198_485)
        let xJitter = (CGFloat((random >> 11) % 1_001) / 1_000 - 0.5) * 0.026
        let yJitter = (CGFloat((random >> 29) % 1_001) / 1_000 - 0.5) * 0.014
        return CGPoint(
            x: size.width * (value.0 + xJitter),
            y: size.height * (value.1 + yJitter)
        )
    }

    private func spriteSize(for index: Int) -> CGFloat {
        switch index / 4 {
        case 0: return 38
        case 1: return 46
        default: return 52
        }
    }

    private func slotAssignments(for sheep: [FlockSheep]) -> [UUID: Int] {
        var assignments: [UUID: Int] = [:]
        var used = Set<Int>()
        for entry in sheep.sorted(by: {
            if $0.arrivedAt == $1.arrivedAt { return $0.id.uuidString < $1.id.uuidString }
            return $0.arrivedAt < $1.arrivedAt
        }) {
            let preferred = Int((stableHash(for: entry.id) ^ layoutSeed) % 12)
            let slot = (0..<12)
                .map { (preferred + $0) % 12 }
                .first { !used.contains($0) } ?? preferred
            assignments[entry.id] = slot
            used.insert(slot)
        }
        return assignments
    }

    private func stableHash(for id: UUID) -> UInt64 {
        id.uuidString.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { partial, byte in
            (partial ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }
}
