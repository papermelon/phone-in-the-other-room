#if DEBUG
import SwiftUI

/// Local visual inspection uses disposable Farm storage and no live services.
struct ShopWardrobeNativeQA: View {
    @StateObject private var model: FocusRunViewModel
    private let mode: String
    private let itemID: String

    init() {
        let args = ProcessInfo.processInfo.arguments
        mode = args.first { $0.hasPrefix("--shop-mode=") }?.replacingOccurrences(of: "--shop-mode=", with: "") ?? "ollie"
        itemID = args.first { $0.hasPrefix("--shop-item=") }?.replacingOccurrences(of: "--shop-item=", with: "") ?? "ollie_moss_bandana"
        let defaults = UserDefaults(suiteName: "ShopWardrobeNativeQA.\(UUID())")!
        let persistence = PersistenceService(defaults: defaults,
            farmSaveDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("ShopWardrobe-\(UUID())"))
        var state = FarmPreviewData.fullState
        state.woolBalance = 5
        if mode != "pasture", mode != "shelf" { state.ownedShopItemIDs = ["ollie_moss_bandana"] }
        state.equipment.ollieAccessoryItemID = "ollie_moss_bandana"
        persistence.farmState = state
        _model = StateObject(wrappedValue: FocusRunViewModel(persistence: persistence,
            startsExternalServices: false, purposeCueDefaults: defaults))
    }

    var body: some View {
        NavigationStack {
            if mode == "detail", let item = FarmShopCatalog.item(for: itemID) {
                FarmShopItemDetailView(item: item, progress: .newFarm)
            } else if mode == "home" {
                HomeWelcomeHero(accessoryItemID: itemID, scrollViewportSize: CGSize(width: 390, height: 800))
            } else if mode == "pasture" {
                FarmPastureView(state: model.farmState, protectedNightCount: 18, layoutSeed: 42, onSelectSheep: { _ in })
                    .frame(height: 330).padding(AppSpacing.md)
            } else if mode == "shelf" {
                ScrollView { FarmKeepsakeDisplay(state: model.farmState).padding(AppSpacing.md) }
            } else if mode == "journey" {
                NightJourneyView(run: FocusRun(plannedDurationSeconds: 3600, startedAt: Date().addingTimeInterval(-300),
                    state: .running, nightWatchPlan: NightWatchPreferences.defaults.makePlan()), reduceMotion: true,
                    accessoryItemID: itemID).padding(AppSpacing.md)
            } else {
                FarmShopView(initialCategory: FarmShopCategory(rawValue: mode) ?? .ollie)
            }
        }
        .environmentObject(model)
        .environment(\.dynamicTypeSize, ProcessInfo.processInfo.arguments.contains("--shop-large-type") ? .accessibility3 : .large)
        .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--shop-light") ? .light : .dark)
        .task { if ProcessInfo.processInfo.arguments.contains("--shop-capture-art") { capture() } }
    }

    @MainActor private func capture() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("shop-art-review")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for garment in OllieGarment.allCases {
                let frames = [NightJourneyAssets.ollieHomeIdleFrames[0]] + NightJourneyAssets.ollieRunFrames
                    + (2...11).map { String(format: "dog/dog_ollie_motion_pose_%02d", $0) }
                let content = VStack(spacing: 12) {
                    Text(FarmShopCatalog.item(for: garment.rawValue)!.title).font(AppTypography.title)
                    Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                        ForEach(0..<6, id: \.self) { row in
                            GridRow {
                                ForEach(0..<3, id: \.self) { column in
                                    let index = row * 3 + column
                                    if index < frames.count {
                                        VStack {
                                            OllieDressedSprite(assetName: frames[index], accessoryItemID: garment.rawValue)
                                                .frame(width: 180, height: 180)
                                            Text(frames[index].replacingOccurrences(of: "dog/dog_", with: "")).font(AppTypography.caption)
                                        }.frame(width: 200)
                                    }
                                }
                            }
                        }
                    }
                }.padding(20).background(AppColors.paper).environment(\.colorScheme, .light)
                try save(content, name: garment.rawValue, directory: directory)
            }
            for category in [FarmShopCategory.farm, .collectibles, .barn] {
                let items = FarmShopCatalog.items(in: category)
                let content = VStack {
                    Text(category.title).font(AppTypography.title)
                    Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                        ForEach(0..<((items.count + 1) / 2), id: \.self) { row in
                            GridRow {
                                ForEach(0..<2, id: \.self) { column in
                                    let index = row * 2 + column
                                    if index < items.count {
                                        VStack {
                                            FarmShopItemImage(item: items[index], size: 190)
                                            Text(items[index].title).font(AppTypography.headline)
                                        }.frame(width: 240)
                                    }
                                }
                            }
                        }
                    }
                }.padding(20).background(AppColors.paper).environment(\.colorScheme, .light)
                try save(content, name: category.rawValue, directory: directory)
            }
        } catch { print("Shop art capture failed: \(error)") }
    }

    @MainActor private func save<V: View>(_ content: V, name: String, directory: URL) throws {
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let data = renderer.uiImage?.pngData() else { return }
        try data.write(to: directory.appendingPathComponent(name + ".png"))
    }
}
#endif
