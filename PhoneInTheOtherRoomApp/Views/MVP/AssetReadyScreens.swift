import SwiftUI

// Entire MVP mock-screen layer is DEBUG-only until the reintroduction gates in
// docs/DECISIONS/ADR-0003-gated-features.md are met. Do not wire these into release paths.
#if DEBUG

struct FarmOverviewScreen: View {
    var progress: UserProgress
    @State private var selectedSheepSlot = 0

    private var ownedSheepCount: Int { min(60, max(0, progress.sheepBalance)) }
    private var sheepSlots: [FarmSheepDisplay] {
        FarmSheepDisplay.mockCapacitySlots.enumerated().map { index, sheep in
            index < ownedSheepCount ? sheep : .empty(slot: sheep.slot)
        }
    }

    private var selectedSheep: FarmSheepDisplay {
        sheepSlots.first { $0.slot == selectedSheepSlot && !$0.isEmpty }
            ?? sheepSlots.first { !$0.isEmpty }
            ?? .empty(slot: 0)
    }

    var body: some View {
        GeometryReader { proxy in
            let sidePadding: CGFloat = 12
            let contentWidth = max(0, proxy.size.width - (sidePadding * 2))

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 14) {
                    FarmTopResourceBar(selectedSheep: selectedSheep, sheepCount: ownedSheepCount)
                    FarmHeroScene(sheep: selectedSheep)
                    SheepCapacityPanel(sheep: sheepSlots, selectedSlot: $selectedSheepSlot, ownedCount: ownedSheepCount)
                    farmMissions
                    farmUpgrades
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(.horizontal, sidePadding)
                .padding(.top, 12)
                .padding(.bottom, 22)
            }
        }
        .background(AppColors.paper.ignoresSafeArea())
    }

    private var farmMissions: some View {
        VStack(alignment: .leading, spacing: 8) {
            FarmSectionHeader(title: "Missions")
            FarmMissionPreviewRow(icon: "stopwatch.fill", assetName: AssetSlot.Missions.awayIcon, title: "Stay Away for 2 Hours", detail: "Stay away from your phone for 2 hours in a day", progress: 0.50, count: "1 / 2", reward: "+3")
            FarmMissionPreviewRow(icon: "calendar", assetName: AssetSlot.Missions.dailyIcon, title: "Daily Consistency", detail: "Complete 3 focus sessions today", progress: 0.66, count: "2 / 3", reward: "+5")
            FarmMissionPreviewRow(icon: "star.fill", assetName: AssetSlot.Missions.achievementIcon, title: "Weekend Warrior", detail: "Stay away for 6 hours on the weekend", progress: 0.66, count: "4 / 6", reward: "+8")
        }
    }

    private var farmUpgrades: some View {
        VStack(alignment: .leading, spacing: 8) {
            FarmSectionHeader(title: "Farm Upgrades")
            FarmUpgradePreviewRow(icon: "barn.fill", assetName: AssetSlot.Farm.barn, title: "Bigger Kennel", detail: "Increase max sheep capacity\n28 -> 60 sheep", trailing: .owned)
            FarmUpgradePreviewRow(icon: "rectangle.grid.1x2.fill", assetName: AssetSlot.Farm.fence, title: "Stronger Fence", detail: "Increase daily sheep limit\n+20 minutes", trailing: .cost("300"))
        }
    }
}

private struct FarmTopResourceBar: View {
    var selectedSheep: FarmSheepDisplay
    var sheepCount: Int

    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                Image(systemName: "envelope")
                    .font(.system(size: 24, weight: .black))
                    .frame(width: 42, height: 36)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppColors.stroke, lineWidth: 2))
                Text("0")
                    .font(pixelFont(.caption2))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(AppColors.grass, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppColors.stroke, lineWidth: 1.5))
            }

            Spacer(minLength: 8)

            HStack(spacing: 7) {
                FarmSheepFigure(style: selectedSheep.style, size: 40)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(sheepCount)")
                            .foregroundStyle(AppColors.ink)
                        Text("/ 60")
                            .foregroundStyle(AppColors.ink)
                    }
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    Text("Sheep")
                        .font(pixelFont(.caption2))
                }
            }

            Spacer(minLength: 8)

            NavigationLink(destination: SettingsPlaceholderScreen()) {
                Image(systemName: "gearshape")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(AppColors.ink)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.top, 2)
        .frame(maxWidth: .infinity)
    }
}

private struct FarmHeroScene: View {
    var sheep: FarmSheepDisplay

    var body: some View {
        ZStack {
            PixelAssetImage(name: AssetSlot.Farm.backgroundDay, contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            VStack {
                HStack(alignment: .top) {
                    featuredBadge
                    Spacer()
                }
                Spacer()
            }
            .padding(.leading, 12)
            .padding(.top, 12)

            FarmSheepFigure(style: sheep.style, size: 156)
                .offset(x: -24, y: 28)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    viewSheepButton
                }
                .padding(.trailing, 28)
                .padding(.bottom, 18)
            }

            VStack {
                Spacer()
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(index == 1 ? AppColors.grass : AppColors.panel)
                            .overlay(Circle().stroke(AppColors.stroke.opacity(0.45), lineWidth: 1))
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .frame(height: 204)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(AppColors.stroke.opacity(0.18), lineWidth: 1))
    }

    private var featuredBadge: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sheep.name)
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(sheep.rarity)
                .font(pixelFont(.caption2))
                .foregroundStyle(AppColors.grass)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(AppColors.grass, lineWidth: 1.5))
        }
        .padding(10)
        .frame(width: 118, alignment: .leading)
        .background(AppColors.panel.opacity(0.92), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppColors.stroke.opacity(0.35), lineWidth: 1))
    }

    private var viewSheepButton: some View {
        NavigationLink(destination: FarmSheepDetailScreen(sheep: sheep)) {
            HStack(spacing: 8) {
                Text("View Sheep")
                    .font(pixelFont(.caption2))
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(AppColors.grass)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minWidth: 102)
            .background(AppColors.panel.opacity(0.94), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppColors.stroke.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct SheepCapacityPanel: View {
    var sheep: [FarmSheepDisplay]
    @Binding var selectedSlot: Int
    var ownedCount: Int

    @State private var currentPage: Int

    private static let slotsPerPage = 15
    private static let pageCount = 4
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    init(sheep: [FarmSheepDisplay], selectedSlot: Binding<Int>, ownedCount: Int) {
        self.sheep = sheep
        self._selectedSlot = selectedSlot
        self.ownedCount = ownedCount
        self._currentPage = State(initialValue: min(Self.pageCount - 1, max(0, selectedSlot.wrappedValue / Self.slotsPerPage)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your Sheep")
                    .font(.system(size: 26, weight: .black, design: .monospaced))
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(ownedCount)")
                            .foregroundStyle(AppColors.grass)
                        Text("/ 60")
                            .foregroundStyle(AppColors.ink)
                    }
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    HStack(spacing: 5) {
                        Text("Sheep Capacity")
                            .font(pixelFont(.caption2))
                        Image(systemName: "info.circle")
                            .foregroundStyle(AppColors.grass)
                    }
                }
            }

            TabView(selection: $currentPage) {
                ForEach(0..<Self.pageCount, id: \.self) { page in
                    SheepSlotPage(
                        slots: slots(for: page),
                        columns: columns,
                        selectedSlot: selectedSlot,
                        onSelect: selectSheep
                    )
                    .tag(page)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 260)
            .background(AppColors.surfaceMuted.opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppColors.stroke.opacity(0.28), lineWidth: 1))

            HStack {
                Button {
                    movePage(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2.weight(.black))
                        .foregroundStyle(currentPage == 0 ? AppColors.stroke.opacity(0.22) : AppColors.ink)
                        .frame(width: 48, height: 42)
                }
                .buttonStyle(.plain)
                .disabled(currentPage == 0)

                Spacer()
                HStack(spacing: 12) {
                    ForEach(0..<Self.pageCount, id: \.self) { index in
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                currentPage = index
                            }
                        } label: {
                            Circle()
                                .fill(index == currentPage ? AppColors.grass : .clear)
                                .overlay(Circle().stroke(index == currentPage ? AppColors.grass : AppColors.stroke.opacity(0.30), lineWidth: 1.4))
                                .frame(width: 12, height: 12)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Show sheep card \(index + 1) of \(Self.pageCount)")
                    }
                }
                Spacer()

                Button {
                    movePage(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2.weight(.black))
                        .foregroundStyle(currentPage == Self.pageCount - 1 ? AppColors.stroke.opacity(0.22) : AppColors.ink)
                        .frame(width: 48, height: 42)
                }
                .buttonStyle(.plain)
                .disabled(currentPage == Self.pageCount - 1)
            }
            .padding(.horizontal, 56)

            NavigationLink(destination: SheepCollectionScreen()) {
                HStack(spacing: 12) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(AppColors.grass)
                    Text("Tap on a sheep to view stats, history and perks.")
                        .font(pixelFont(.caption2))
                        .foregroundStyle(AppColors.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.black))
                        .foregroundStyle(AppColors.grass)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(AppColors.panel, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(AppColors.stroke.opacity(0.30), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(AppColors.panel.opacity(0.86), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppColors.stroke.opacity(0.35), lineWidth: 1))
        .onChange(of: selectedSlot) { _, newValue in
            let selectedPage = page(for: newValue)
            guard selectedPage != currentPage else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                currentPage = selectedPage
            }
        }
    }

    private func slots(for page: Int) -> [FarmSheepDisplay] {
        let start = page * Self.slotsPerPage
        return (start..<(start + Self.slotsPerPage)).map { slot in
            sheep.first { $0.slot == slot } ?? .empty(slot: slot)
        }
    }

    private func selectSheep(_ item: FarmSheepDisplay) {
        guard !item.isEmpty else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            selectedSlot = item.slot
            currentPage = page(for: item.slot)
        }
    }

    private func movePage(by delta: Int) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            currentPage = min(Self.pageCount - 1, max(0, currentPage + delta))
        }
    }

    private func page(for slot: Int) -> Int {
        min(Self.pageCount - 1, max(0, slot / Self.slotsPerPage))
    }
}

private struct SheepSlotPage: View {
    var slots: [FarmSheepDisplay]
    var columns: [GridItem]
    var selectedSlot: Int
    var onSelect: (FarmSheepDisplay) -> Void

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(slots) { item in
                SheepGridSlot(item: item, isSelected: selectedSlot == item.slot) {
                    onSelect(item)
                }
            }
        }
        .padding(14)
    }
}

private struct FarmStatPill: View {
    var title: String
    var value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(pixelFont(.caption2))
                .foregroundStyle(AppColors.grass)
            Text(title)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(AppColors.secondaryText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(AppColors.panel.opacity(0.82), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(AppColors.stroke.opacity(0.16), lineWidth: 1))
    }
}

private struct FarmSectionHeader: View {
    var title: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            Text("View All")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
    }
}

private struct FarmMissionPreviewRow: View {
    var icon: String
    var assetName: String? = nil
    var title: String
    var detail: String
    var progress: Double
    var count: String
    var reward: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppColors.grass)
                    if let assetName {
                        PixelAssetImage(name: assetName)
                            .padding(7)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(icon == "star.fill" ? AppColors.coin : AppColors.ink)
                    }
                }
                .frame(width: 58, height: 58)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.stroke.opacity(0.16), lineWidth: 1))

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(pixelFont(.subheadline))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(detail)
                        .font(pixelFont(.caption2))
                        .lineSpacing(3)
                        .lineLimit(2)
                        .minimumScaleFactor(0.80)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 2) {
                    FarmSheepFigure(style: .common, size: 30)
                    Text(reward)
                        .font(pixelFont(.caption2))
                }
                .frame(width: 50, height: 64)
                .background(AppColors.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.stroke.opacity(0.15), lineWidth: 1))
            }

            HStack(spacing: 12) {
                ProgressBar(progress: progress, tint: AppColors.grass)
                Text(count)
                    .font(pixelFont(.caption))
                    .lineLimit(1)
                    .frame(width: 46, alignment: .trailing)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.panel.opacity(0.92), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(AppColors.stroke.opacity(0.28), lineWidth: 1))
    }
}

private struct FarmUpgradePreviewRow: View {
    enum Trailing {
        case owned
        case cost(String)
    }

    var icon: String
    var assetName: String? = nil
    var title: String
    var detail: String
    var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppColors.grass)
                if let assetName {
                    PixelAssetImage(name: assetName)
                        .padding(6)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(icon == "barn.fill" ? AppColors.clay : AppColors.ink)
                }
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(pixelFont(.subheadline))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
                Text(detail)
                    .font(pixelFont(.caption2))
                    .lineSpacing(3)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            switch trailing {
            case .owned:
                Image(systemName: "checkmark")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(AppColors.grass)
                    .frame(width: 44)
            case .cost(let cost):
                HStack(spacing: 5) {
                    FarmSheepFigure(style: .common, size: 26)
                    Text(cost)
                        .font(.system(size: 17, weight: .black, design: .monospaced))
                        .foregroundStyle(AppColors.grass)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(.horizontal, 8)
                .frame(width: 76, height: 48)
                .background(AppColors.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.stroke.opacity(0.14), lineWidth: 1))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.panel.opacity(0.92), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(AppColors.stroke.opacity(0.28), lineWidth: 1))
    }
}

private struct FarmSheepDisplay: Identifiable {
    var id: Int { slot }
    var slot: Int
    var name: String
    var style: FarmSheepStyle
    var rarity: String
    var stage: String
    var level: Int
    var perk: String
    var bonus: String
    var woolBonus: String
    var focusRuns: Int
    var origin: String

    var isEmpty: Bool { style == .empty }

    static let mockCapacitySlots: [FarmSheepDisplay] = {
        let owned: [FarmSheepDisplay] = [
            .init(slot: 0, name: "Daisy", style: .common, rarity: "Common", stage: "Adult", level: 1, perk: "Reliable grazer.", bonus: "Small wool bonus.", woolBonus: "+4%", focusRuns: 3, origin: "First Focus Run"),
            .init(slot: 1, name: "Pip", style: .common, rarity: "Common", stage: "Adult", level: 1, perk: "Calm and steady.", bonus: "Good daily wool.", woolBonus: "+4%", focusRuns: 3, origin: "Daily Focus"),
            .init(slot: 2, name: "Moss", style: .common, rarity: "Common", stage: "Adult", level: 1, perk: "Enjoys short sessions.", bonus: "Quick-run wool.", woolBonus: "+5%", focusRuns: 4, origin: "Short Focus"),
            .init(slot: 3, name: "Clover", style: .common, rarity: "Common", stage: "Adult", level: 1, perk: "Easy keeper.", bonus: "Stable wool yield.", woolBonus: "+3%", focusRuns: 2, origin: "Any Session"),
            .init(slot: 4, name: "Bean", style: .common, rarity: "Common", stage: "Adult", level: 1, perk: "Likes morning pasture.", bonus: "Morning focus wool.", woolBonus: "+5%", focusRuns: 4, origin: "Morning Focus"),
            .init(slot: 5, name: "Bramble", style: .common, rarity: "Common", stage: "Adult", level: 1, perk: "Stays near the fence.", bonus: "No-peek helper.", woolBonus: "+4%", focusRuns: 3, origin: "No Peek"),
            .init(slot: 6, name: "Sunny", style: .common, rarity: "Common", stage: "Adult", level: 1, perk: "Bright little sheep.", bonus: "Daily streak wool.", woolBonus: "+5%", focusRuns: 5, origin: "Streak Starter"),
            .init(slot: 7, name: "Nettle", style: .common, rarity: "Common", stage: "Adult", level: 1, perk: "Patient grazer.", bonus: "Partial-run wool.", woolBonus: "+3%", focusRuns: 2, origin: "Partial Session"),
            .init(slot: 8, name: "Pebble", style: .common, rarity: "Common", stage: "Adult", level: 1, perk: "Small but useful.", bonus: "Basic wool bonus.", woolBonus: "+3%", focusRuns: 2, origin: "Any Session"),
            .init(slot: 9, name: "Sprout", style: .common, rarity: "Common", stage: "Adult", level: 1, perk: "Fast pasture friend.", bonus: "Short-run wool.", woolBonus: "+4%", focusRuns: 3, origin: "Quick Run"),
            .init(slot: 10, name: "Oat", style: .common, rarity: "Common", stage: "Adult", level: 1, perk: "Steady in the pasture.", bonus: "Basic wool bonus.", woolBonus: "+3%", focusRuns: 2, origin: "Any Session"),
            .init(slot: 11, name: "Wisp", style: .common, rarity: "Common", stage: "Adult", level: 1, perk: "Gentle flock friend.", bonus: "Daily wool bonus.", woolBonus: "+4%", focusRuns: 3, origin: "Daily Focus"),
            .init(slot: 12, name: "Mallow", style: .common, rarity: "Common", stage: "Adult", level: 1, perk: "Likes quiet fields.", bonus: "Focus sprint wool.", woolBonus: "+5%", focusRuns: 4, origin: "Focus Sprint"),
            .init(slot: 13, name: "Fennel", style: .common, rarity: "Common", stage: "Adult", level: 1, perk: "Easygoing grazer.", bonus: "Small wool bonus.", woolBonus: "+4%", focusRuns: 3, origin: "Any Session"),
            .init(slot: 14, name: "Biscuit", style: .common, rarity: "Common", stage: "Adult", level: 1, perk: "Stays with the flock.", bonus: "Streak wool bonus.", woolBonus: "+5%", focusRuns: 5, origin: "Streak Starter"),
            .init(slot: 15, name: "Thistle", style: .common, rarity: "Common", stage: "Adult", level: 1, perk: "Careful and calm.", bonus: "Partial-run wool.", woolBonus: "+3%", focusRuns: 2, origin: "Partial Session"),
            .init(slot: 16, name: "Juniper", style: .common, rarity: "Common", stage: "Adult", level: 1, perk: "Enjoys long grass.", bonus: "Daily wool bonus.", woolBonus: "+4%", focusRuns: 3, origin: "Daily Focus"),
            .init(slot: 17, name: "Hazel", style: .common, rarity: "Common", stage: "Adult", level: 1, perk: "Reliable field mate.", bonus: "Short-run wool.", woolBonus: "+4%", focusRuns: 3, origin: "Quick Run"),
            .init(slot: 18, name: "Tansy", style: .common, rarity: "Common", stage: "Adult", level: 1, perk: "Quiet helper.", bonus: "No-peek helper.", woolBonus: "+4%", focusRuns: 3, origin: "No Peek"),
            .init(slot: 19, name: "Fig", style: .common, rarity: "Common", stage: "Adult", level: 1, perk: "Bright little grazer.", bonus: "Morning focus wool.", woolBonus: "+5%", focusRuns: 4, origin: "Morning Focus"),
            .init(slot: 20, name: "Bluebell", style: .common, rarity: "Common", stage: "Adult", level: 1, perk: "Patient and soft.", bonus: "Basic wool bonus.", woolBonus: "+3%", focusRuns: 2, origin: "Any Session"),
            .init(slot: 21, name: "Poppy", style: .common, rarity: "Common", stage: "Adult", level: 1, perk: "Likes quick resets.", bonus: "Quick-run wool.", woolBonus: "+5%", focusRuns: 4, origin: "Short Focus"),
            .init(slot: 22, name: "Fern", style: .common, rarity: "Common", stage: "Adult", level: 1, perk: "Keeps close to the barn.", bonus: "Stable wool yield.", woolBonus: "+3%", focusRuns: 2, origin: "Any Session"),
            .init(slot: 23, name: "Luna", style: .common, rarity: "Common", stage: "Adult", level: 1, perk: "Calm during evening runs.", bonus: "Evening wool bonus.", woolBonus: "+6%", focusRuns: 5, origin: "Evening Focus"),
            .init(slot: 24, name: "Midnight", style: .black, rarity: "Uncommon", stage: "Adult", level: 2, perk: "Quiet and focused.", bonus: "No-peek bonus.", woolBonus: "+9%", focusRuns: 8, origin: "No Peek Mission"),
            .init(slot: 25, name: "Shaggy", style: .shaggy, rarity: "Uncommon", stage: "Adult", level: 2, perk: "Thick winter coat.", bonus: "Extra wool on long runs.", woolBonus: "+10%", focusRuns: 9, origin: "Weekly Chest"),
            .init(slot: 26, name: "Ramsay", style: .merino, rarity: "Rare", stage: "Adult", level: 2, perk: "Brave pasture leader.", bonus: "Long-run wool bonus.", woolBonus: "+12%", focusRuns: 10, origin: "Long Run"),
            .init(slot: 27, name: "Merino", style: .merino, rarity: "Rare", stage: "Adult", level: 2, perk: "Gentle and hearty.", bonus: "Provides extra wool bonus.", woolBonus: "+14%", focusRuns: 12, origin: "Deep Focus")
        ]

        var slots = owned
        slots.append(contentsOf: (owned.count..<60).map { FarmSheepDisplay.empty(slot: $0) })
        return slots
    }()

    static func empty(slot: Int) -> FarmSheepDisplay {
        FarmSheepDisplay(
            slot: slot,
            name: "Empty Slot",
            style: .empty,
            rarity: "Locked",
            stage: "Empty",
            level: 0,
            perk: "Open pasture slot.",
            bonus: "Earn more sheep through focus sessions.",
            woolBonus: "-",
            focusRuns: 0,
            origin: "Locked"
        )
    }
}

private enum FarmSheepStyle {
    case common
    case black
    case shaggy
    case merino
    case empty
}

private struct SheepGridSlot: View {
    var item: FarmSheepDisplay
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if item.style == .empty {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppColors.stroke.opacity(0.42), style: StrokeStyle(lineWidth: 1.5, dash: [7, 6]))
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(AppColors.ink)
                } else {
                    FarmSheepFigure(style: item.style, size: 64)
                }
            }
            .frame(height: 72)
            .frame(maxWidth: .infinity)
            .background {
                if isSelected && !item.isEmpty {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppColors.grass.opacity(0.16))
                }
            }
            .overlay {
                if isSelected && !item.isEmpty {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppColors.grass, lineWidth: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.isEmpty ? "Empty sheep slot" : "Select \(item.name), \(item.rarity), level \(item.level)")
    }
}

private struct FarmSheepFigure: View {
    var style: FarmSheepStyle
    var size: CGFloat

    var body: some View {
        PixelAssetImage(name: assetName)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var assetName: String {
        switch style {
        case .common: return AssetSlot.Sheep.common
        case .black: return AssetSlot.Sheep.black
        case .shaggy: return AssetSlot.Sheep.cream
        case .merino: return AssetSlot.Sheep.golden
        case .empty: return AssetSlot.Sheep.common
        }
    }
}

private struct LegacyFarmSheepFigure: View {
    var style: FarmSheepStyle
    var size: CGFloat

    var body: some View {
        EmptyView()
        .frame(width: size, height: size)
    }

    private var bodyCloud: some View {
        ZStack {
            let fill = bodyColor
            ForEach(0..<9, id: \.self) { index in
                Circle()
                    .fill(fill)
                    .overlay(Circle().stroke(outlineColor.opacity(0.55), lineWidth: 0.7))
                    .frame(width: size * 0.24, height: size * 0.24)
                    .offset(x: cloudOffset(index).x, y: cloudOffset(index).y)
            }
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .fill(fill)
                .overlay(RoundedRectangle(cornerRadius: size * 0.16).stroke(outlineColor.opacity(0.45), lineWidth: 0.8))
                .frame(width: size * 0.58, height: size * 0.38)
        }
        .offset(x: -size * 0.04)
    }

    private var head: some View {
        Circle()
            .fill(headColor)
            .overlay(Circle().stroke(AppColors.stroke.opacity(0.55), lineWidth: 0.8))
            .frame(width: size * 0.25, height: size * 0.25)
            .offset(x: size * 0.26, y: -size * 0.02)
            .overlay(alignment: .center) {
                Circle()
                    .fill(AppColors.ink)
                    .frame(width: size * 0.025, height: size * 0.025)
                    .offset(x: size * 0.30, y: -size * 0.05)
            }
    }

    private var legs: some View {
        HStack(spacing: size * 0.20) {
            Capsule().fill(legColor).frame(width: size * 0.06, height: size * 0.24)
            Capsule().fill(legColor).frame(width: size * 0.06, height: size * 0.24)
        }
        .offset(x: -size * 0.05, y: size * 0.25)
    }

    private func horn(x: CGFloat) -> some View {
        Circle()
            .trim(from: 0.08, to: 0.76)
            .stroke(Color(red: 0.50, green: 0.32, blue: 0.14), lineWidth: max(2, size * 0.04))
            .frame(width: size * 0.22, height: size * 0.22)
            .rotationEffect(.degrees(x < 0 ? -45 : 135))
            .offset(x: x, y: -size * 0.22)
    }

    private var bodyColor: Color {
        switch style {
        case .common: return .white
        case .black: return Color(red: 0.10, green: 0.10, blue: 0.10)
        case .shaggy: return Color(red: 0.70, green: 0.56, blue: 0.36)
        case .merino: return Color(red: 0.98, green: 0.78, blue: 0.46)
        case .empty: return .clear
        }
    }

    private var headColor: Color {
        switch style {
        case .common: return Color(red: 0.12, green: 0.12, blue: 0.11)
        case .black: return Color(red: 0.06, green: 0.06, blue: 0.06)
        case .shaggy: return Color(red: 0.70, green: 0.48, blue: 0.24)
        case .merino: return Color(red: 0.94, green: 0.70, blue: 0.38)
        case .empty: return .clear
        }
    }

    private var legColor: Color {
        style == .merino || style == .shaggy ? Color(red: 0.39, green: 0.22, blue: 0.12) : headColor
    }

    private var outlineColor: Color {
        style == .black ? Color.white.opacity(0.25) : AppColors.stroke
    }

    private func cloudOffset(_ index: Int) -> CGPoint {
        let offsets: [CGPoint] = [
            .init(x: -0.26, y: -0.14), .init(x: -0.12, y: -0.20), .init(x: 0.04, y: -0.18),
            .init(x: 0.18, y: -0.10), .init(x: -0.28, y: 0.05), .init(x: -0.08, y: 0.08),
            .init(x: 0.12, y: 0.07), .init(x: 0.24, y: 0.08), .init(x: 0.00, y: -0.02)
        ]
        let point = offsets[index]
        return CGPoint(x: point.x * size, y: point.y * size)
    }
}

private struct FarmLandscapeBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [AppColors.sky, Color(red: 0.75, green: 0.91, blue: 0.99), AppColors.grassLight], startPoint: .top, endPoint: .bottom)

            cloud(x: -130, y: -86)
            cloud(x: 20, y: -84)
            cloud(x: 154, y: -76)

            Circle()
                .fill(AppColors.grass.opacity(0.72))
                .frame(width: 300, height: 140)
                .offset(x: -116, y: 12)
            Circle()
                .fill(Color(red: 0.22, green: 0.50, blue: 0.27).opacity(0.72))
                .frame(width: 310, height: 150)
                .offset(x: 128, y: 16)

            Rectangle()
                .fill(AppColors.grass)
                .frame(height: 100)
                .offset(y: 74)

            Path { path in
                path.move(to: CGPoint(x: 260, y: 110))
                path.addQuadCurve(to: CGPoint(x: 380, y: 260), control: CGPoint(x: 306, y: 170))
                path.addLine(to: CGPoint(x: 250, y: 260))
                path.addQuadCurve(to: CGPoint(x: 238, y: 115), control: CGPoint(x: 246, y: 172))
                path.closeSubpath()
            }
            .fill(Color(red: 0.78, green: 0.66, blue: 0.45))

            Image(systemName: "leaf.fill")
                .font(.system(size: 54, weight: .black))
                .foregroundStyle(AppColors.grass.opacity(0.8))
                .offset(x: -150, y: 80)
        }
    }

    private func cloud(x: CGFloat, y: CGFloat) -> some View {
        HStack(spacing: -7) {
            Circle().frame(width: 20, height: 20)
            Circle().frame(width: 30, height: 30)
            Circle().frame(width: 22, height: 22)
        }
        .foregroundStyle(.white)
        .offset(x: x, y: y)
    }
}

private struct FarmFenceView: View {
    var body: some View {
        HStack(spacing: 14) {
            ForEach(0..<7, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.45, green: 0.27, blue: 0.11))
                    .frame(width: 9, height: 62)
            }
        }
        .overlay(alignment: .center) {
            VStack(spacing: 14) {
                Rectangle().fill(Color(red: 0.47, green: 0.29, blue: 0.12)).frame(height: 8)
                Rectangle().fill(Color(red: 0.47, green: 0.29, blue: 0.12)).frame(height: 8)
            }
            .frame(width: 360)
        }
    }
}

private struct BarnView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.clay)
                .frame(width: 118, height: 96)
                .overlay(Rectangle().stroke(AppColors.stroke, lineWidth: 2))
            Triangle()
                .fill(Color(red: 0.48, green: 0.28, blue: 0.10))
                .frame(width: 144, height: 72)
                .offset(y: -64)
                .overlay(Triangle().stroke(AppColors.stroke, lineWidth: 2).offset(y: -64))
            Rectangle()
                .fill(AppColors.ink)
                .frame(width: 48, height: 58)
            HStack {
                BarnDoor()
                Spacer()
                BarnDoor()
            }
            .frame(width: 104)
            .padding(.bottom, 10)
            WindowShape()
                .frame(width: 34, height: 34)
                .offset(y: -58)
            Image(systemName: "flag")
                .font(.title3.weight(.black))
                .offset(x: 16, y: -118)
        }
    }
}

private struct BarnDoor: View {
    var body: some View {
        Rectangle()
            .fill(Color(red: 0.75, green: 0.23, blue: 0.12))
            .frame(width: 28, height: 42)
            .overlay(Rectangle().stroke(.white, lineWidth: 2))
    }
}

private struct WindowShape: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.panel)
            .overlay(Rectangle().stroke(AppColors.stroke, lineWidth: 2))
            .overlay {
                VStack(spacing: 0) {
                    Rectangle().fill(AppColors.stroke).frame(height: 2)
                    Spacer()
                }
            }
            .overlay {
                HStack(spacing: 0) {
                    Rectangle().fill(AppColors.stroke).frame(width: 2)
                    Spacer()
                }
            }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct FarmSheepDetailScreen: View {
    var sheep: FarmSheepDisplay

    var body: some View {
        AssetReadyScroll(title: sheep.name) {
            VStack(spacing: 14) {
                FarmSheepFigure(style: sheep.style, size: 180)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(colors: [AppColors.sky.opacity(0.55), AppColors.grassLight.opacity(0.45)], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                HStack(spacing: 10) {
                    FarmDetailStat(title: "Rarity", value: sheep.rarity)
                    FarmDetailStat(title: "Level", value: "\(sheep.level)")
                    FarmDetailStat(title: "Wool", value: sheep.woolBonus)
                }

                InfoCard(title: "Perk", value: "\(sheep.perk) \(sheep.bonus)", icon: "leaf.fill")
                InfoCard(title: "History", value: "Found from \(sheep.origin). Helped with \(sheep.focusRuns) Focus Runs.", icon: "clock.arrow.circlepath")
                InfoCard(title: "Asset Slot", value: assetName(for: sheep.style), icon: "photo")
            }
        }
    }

    private func assetName(for style: FarmSheepStyle) -> String {
        switch style {
        case .common: return "sheep_common_white"
        case .black: return "sheep_black"
        case .shaggy: return "sheep_shaggy"
        case .merino: return "sheep_merino"
        case .empty: return "sheep_locked_slot"
        }
    }
}

private struct FarmDetailStat: View {
    var title: String
    var value: String

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(pixelFont(.caption2))
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppColors.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.stroke.opacity(0.16), lineWidth: 1))
    }
}

struct SheepCollectionScreen: View {
    var body: some View {
        AssetReadyScroll(title: "Sheep Collection") {
            ForEach(MockRarity.allCases) { rarity in
                let sheepForRarity = MVPMockData.sheep.filter { $0.rarity == rarity }
                if !sheepForRarity.isEmpty {
                    section(rarity.rawValue) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 142), spacing: AppSpacing.sm)], spacing: AppSpacing.sm) {
                            ForEach(sheepForRarity) { sheep in
                                NavigationLink(destination: SheepDetailScreen(sheep: sheep)) {
                                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                        SheepSpriteView(sheep: sheep, size: 78)
                                        Text(sheep.name)
                                            .font(AppTypography.headline)
                                            .foregroundStyle(AppColors.ink)
                                        Text(sheep.source)
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColors.secondaryText)
                                    }
                                    .assetReadyCard()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct SheepDetailScreen: View {
    var sheep: MockSheep

    var body: some View {
        AssetReadyScroll(title: sheep.name) {
            SheepSpriteView(sheep: sheep, size: 132)
                .frame(maxWidth: .infinity)
            InfoCard(title: "Asset Slot", value: sheep.assetName, icon: "photo")
            InfoCard(title: "Rarity", value: sheep.rarity.rawValue, icon: "sparkle")
            InfoCard(title: "Unlock Source", value: sheep.source, icon: "lock.open")
            InfoCard(title: "Current Placeholder", value: "SwiftUI cloud body, face, legs, rarity frame", icon: "square.dashed")
        }
    }
}

struct MissionsOverviewScreen: View {
    var body: some View {
        AssetReadyScroll(title: "Missions") {
            missionGroup("Daily Missions", cadence: "Daily")
            missionGroup("Weekly Missions", cadence: "Weekly")
            missionGroup("Achievements", cadence: "Achievement")
            missionGroup("Events", cadence: "Event")
            NavigationLink(destination: RewardClaimScreen()) {
                PlaceholderNavRow(title: "Claimable Rewards", detail: "Cards use the same slots as session and mission rewards.", icon: "gift.fill")
            }
        }
    }

    private func missionGroup(_ title: String, cadence: String) -> some View {
        section(title) {
            VStack(spacing: AppSpacing.sm) {
                ForEach(MVPMockData.missions.filter { $0.cadence == cadence }) { mission in
                    NavigationLink(destination: MissionDetailScreen(mission: mission)) {
                        MissionCard(mission: mission)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct MissionDetailScreen: View {
    var mission: MockMission

    var body: some View {
        AssetReadyScroll(title: mission.title) {
            MissionCard(mission: mission)
            InfoCard(title: "Required Asset", value: missionAssetName, icon: mission.icon)
            InfoCard(title: "Progress Data", value: mission.progressLabel, icon: "chart.bar.fill")
            InfoCard(title: "Reward", value: mission.reward, icon: "gift.fill")
        }
    }

    private var missionAssetName: String {
        switch mission.cadence {
        case "Weekly": return AssetSlot.Missions.weeklyIcon
        case "Achievement": return AssetSlot.Missions.achievementIcon
        default: return AssetSlot.Missions.dailyIcon
        }
    }
}

struct StatsOverviewScreen: View {
    private let columns = [GridItem(.adaptive(minimum: 154), spacing: AppSpacing.sm)]

    var body: some View {
        AssetReadyScroll(title: "Stats") {
            section("Today") {
                LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                    ForEach(MVPMockData.statistics) { statistic in
                        StatsCard(statistic: statistic)
                    }
                }
            }
            section("Session History") {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(MVPMockData.sessions) { session in
                        FocusSessionCard(session: session)
                    }
                }
            }
            section("Screen Time Setup") {
                Text("Real Screen Time reports remain in the existing stats implementation. These cards are the mock fallback for builds without FamilyControls or entitlement access.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .assetReadyCard()
            }
        }
    }
}

struct FriendsOverviewScreen: View {
    var body: some View {
        AssetReadyScroll(title: "Friends") {
            section("Friend Feed") {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(MVPMockData.friendFeed) { item in
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: item.icon)
                                .font(.headline.weight(.black))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(AppColors.lavender, in: RoundedRectangle(cornerRadius: AppRadius.md))
                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text(item.name)
                                    .font(AppTypography.headline)
                                Text(item.detail)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.secondaryText)
                            }
                            Spacer()
                            Text(item.reaction)
                                .font(AppTypography.monoCaption)
                                .foregroundStyle(AppColors.grass)
                        }
                        .assetReadyCard()
                    }
                }
            }
            section("MVP Placeholders") {
                PlaceholderNavRow(title: "My Herd", detail: "Members, shared goal, progress, streak, rewards", icon: "person.3.fill")
                PlaceholderNavRow(title: "Challenges", detail: "Active, create, join, detail, and result states", icon: "flag.fill")
                PlaceholderNavRow(title: "Add Friends", detail: "Invite code, link, contacts, and QR slots", icon: "person.badge.plus")
            }
        }
    }
}

struct ShopPlaceholderScreen: View {
    var body: some View {
        AssetReadyScroll(title: "Shop") {
            section("Shop") {
                PlaceholderNavRow(title: "Ollie Cosmetics", detail: "Collars, bandanas, hats, and badges will live here.", icon: "tag.fill")
                PlaceholderNavRow(title: "Farm Decor", detail: "Barn, fence, pasture, and seasonal decoration slots.", icon: "paintpalette.fill")
                PlaceholderNavRow(title: "Reward Preview", detail: "Uses farm currency and mission rewards later.", icon: "gift.fill")
            }
        }
    }
}

struct DoghouseScreen: View {
    var body: some View {
        AssetReadyScroll(title: "Doghouse") {
            section("Ollie Overview") {
                VStack(spacing: AppSpacing.md) {
                    DogSpriteView(state: MVPMockData.dog, size: 156)
                    InfoCard(title: "Mood", value: "Happy and ready to guard focus", icon: "heart.fill")
                    InfoCard(title: "Energy", value: "\(MVPMockData.dog.energy)%", icon: "bolt.fill")
                    InfoCard(title: "Bond Level", value: "Level \(MVPMockData.dog.bondLevel)", icon: "pawprint.fill")
                    InfoCard(title: "Current Outfit", value: MVPMockData.dog.outfit, icon: "tag.fill")
                }
            }
            section("Cosmetics") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: AppSpacing.sm)], spacing: AppSpacing.sm) {
                    RewardCard(reward: MockReward(title: "Default collar", assetName: "dog_collar_default", detail: "Equipped", rarity: .common, icon: "circle"))
                    RewardCard(reward: MockReward(title: "Focus bandana", assetName: "dog_bandana_focus_blue", detail: "Unlocked from Deep Work Sprint", rarity: .uncommon, icon: "tag.fill"))
                    RewardCard(reward: MockReward(title: "Straw hat", assetName: "dog_hat_straw", detail: "Future farm cosmetic", rarity: .rare, icon: "sun.max.fill"))
                    RewardCard(reward: MockReward(title: "Sheep Finder badge", assetName: "dog_badge_sheep_finder", detail: "Achievement overlay", rarity: .rare, icon: "seal.fill"))
                }
            }
            section("Care") {
                PlaceholderNavRow(title: "Feed Treat", detail: "Uses dog treat reward slots later.", icon: "heart.fill")
                PlaceholderNavRow(title: "Play", detail: "Toy, petting, and bond animation placeholders.", icon: "tennisball.fill")
                PlaceholderNavRow(title: "Rest", detail: "Sleeping Ollie and home bed asset slots.", icon: "bed.double.fill")
            }
        }
    }
}

struct OnboardingPreviewScreen: View {
    var body: some View {
        AssetReadyScroll(title: "Onboarding") {
            OnboardingStep(title: "Welcome", detail: "Put your phone away. Help Ollie herd sheep.", assetName: "onboarding_welcome_ollie", icon: "pawprint.fill")
            OnboardingStep(title: "Pick Your Goal", detail: "Study, work, sleep better, reduce scrolling, or be more present.", assetName: "onboarding_goal_cards", icon: "target")
            OnboardingStep(title: "Meet Ollie", detail: "Introduce the Border Collie companion and default name.", assetName: AssetSlot.Dog.happy, icon: "dog.fill")
            OnboardingStep(title: "Daily Goal", detail: "15, 30, 60 minutes, or custom.", assetName: "onboarding_daily_goal", icon: "timer")
            OnboardingStep(title: "Permissions", detail: "Notifications, Watch, and Screen Time setup slots.", assetName: "onboarding_permissions", icon: "shield.fill")
            OnboardingStep(title: "First Mission", detail: "Complete your first 10-minute session.", assetName: AssetSlot.Missions.dailyIcon, icon: "flag.fill")
        }
    }
}

struct SettingsPlaceholderScreen: View {
    var body: some View {
        AssetReadyScroll(title: "Settings") {
            PlaceholderNavRow(title: "Profile", detail: "Name, avatar, and friend code", icon: "person.crop.circle")
            PlaceholderNavRow(title: "Daily Goal", detail: "Minutes per day and active days", icon: "target")
            PlaceholderNavRow(title: "Focus Presets", detail: "Study, work, sleep, reading", icon: "slider.horizontal.3")
            PlaceholderNavRow(title: "Notifications", detail: "Reminder times and streak alerts", icon: "bell.fill")
            PlaceholderNavRow(title: "Watch Setup", detail: "Pairing, status, and troubleshooting", icon: "applewatch")
            PlaceholderNavRow(title: "Screen Time Setup", detail: "Permission state and mock/real data mode", icon: "hourglass")
            PlaceholderNavRow(title: "Privacy", detail: "Control social sharing and data visibility", icon: "hand.raised.fill")
            NavigationLink(destination: OnboardingPreviewScreen()) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "sparkles")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(AppColors.lavender, in: RoundedRectangle(cornerRadius: AppRadius.md))
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("Onboarding Preview")
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.ink)
                        Text("MVP first-run flow screens")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.secondaryText)
                }
                .assetReadyCard()
            }
            .buttonStyle(.plain)
        }
    }
}

struct FarmUtilityScreen: View {
    enum Kind {
        case decorations
        case resources

        var title: String {
            switch self {
            case .decorations: return "Decorations"
            case .resources: return "Resources"
            }
        }
    }

    var kind: Kind

    var body: some View {
        AssetReadyScroll(title: kind.title) {
            switch kind {
            case .decorations:
                ForEach(MVPMockData.farmUnlocks) { unlock in
                    FarmTileView(unlock: unlock)
                }
                InfoCard(title: "Placement Mode", value: "Slot placement placeholder; drag/drop can replace this later.", icon: "hand.draw.fill")
            case .resources:
                ResourceRow(title: "Wool", value: "48", icon: "circle.hexagongrid.fill", assetName: "icon_reward_wool")
                ResourceRow(title: "Treats", value: "7", icon: "heart.fill", assetName: "icon_reward_treat")
                ResourceRow(title: "Bones", value: "3", icon: "dog.fill", assetName: "icon_reward_bone")
                ResourceRow(title: "Bells", value: "1", icon: "bell.fill", assetName: "icon_reward_bell")
                ResourceRow(title: "Special Tokens", value: "0", icon: "sparkle", assetName: "icon_reward_special_token")
            }
        }
    }
}

struct RewardClaimScreen: View {
    private let columns = [GridItem(.adaptive(minimum: 154), spacing: AppSpacing.sm)]

    var body: some View {
        AssetReadyScroll(title: "Reward Claim") {
            section("Claimable") {
                LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                    ForEach(MVPMockData.rewards) { reward in
                        RewardCard(reward: reward)
                    }
                }
            }
        }
    }
}

private struct AssetReadyScroll<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                content
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(title)
    }
}

private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: AppSpacing.sm) {
        Text(title)
            .font(AppTypography.title)
            .foregroundStyle(AppColors.ink)
        content()
    }
}

private struct PlaceholderNavRow: View {
    var title: String
    var detail: String
    var icon: String

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(AppColors.grass, in: RoundedRectangle(cornerRadius: AppRadius.md))
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.ink)
                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.secondaryText)
        }
        .assetReadyCard()
    }
}

private struct ResourceRow: View {
    var title: String
    var value: String
    var icon: String
    var assetName: String

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            AssetPlaceholderView(assetName: assetName, label: title, systemImage: icon, tint: AppColors.amber, aspectRatio: 1)
                .frame(width: 72)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppTypography.headline)
                Text("Current mock balance")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
            Spacer()
            Text(value)
                .font(AppTypography.display(26))
                .foregroundStyle(AppColors.ink)
        }
        .assetReadyCard()
    }
}

private struct InfoCard: View {
    var title: String
    var value: String
    var icon: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(AppColors.grass, in: RoundedRectangle(cornerRadius: AppRadius.md))
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                Text(value)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.ink)
            }
        }
        .assetReadyCard()
    }
}

private struct OnboardingStep: View {
    var title: String
    var detail: String
    var assetName: String
    var icon: String

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            AssetPlaceholderView(assetName: assetName, label: title, systemImage: icon, tint: AppColors.sky, aspectRatio: 1)
                .frame(width: 88)
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.ink)
                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
        .assetReadyCard()
    }
}

#endif
