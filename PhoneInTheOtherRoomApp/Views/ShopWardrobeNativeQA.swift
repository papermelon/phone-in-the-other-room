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
        if mode != "pasture", mode != "shelf", mode != "wardrobe" { state.ownedShopItemIDs = ["ollie_moss_bandana"] }
        state.equipment.ollieAccessoryItemID = "ollie_moss_bandana"
        if args.contains("--shop-fuller-coat") { state.equipment.ollieCoatID = "fuller" }
        if mode == "wardrobe" {
            state.ownedShopItemIDs = FarmShopCatalog.items(in: .shepherd).map(\.id)
            state.shepherd.outfitItemID = "shepherd_open_moss_coat"
            state.shepherd.shirtItemID = "shepherd_berry_shirt"
            state.shepherd.accessoryItemID = "shepherd_wool_hat"
        }
        persistence.farmState = state
        _model = StateObject(wrappedValue: FocusRunViewModel(persistence: persistence,
            startsExternalServices: false, purposeCueDefaults: defaults))
    }

    var body: some View {
        NavigationStack {
            if mode == "wardrobe" {
                ShepherdCustomizationView()
            } else if mode == "motion" {
                OllieWardrobePreview(itemID: itemID)
            } else if mode == "detail", let item = FarmShopCatalog.item(for: itemID) {
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
        .environment(\.ollieCoat, model.farmState.equipment.ollieCoat)
        .environment(\.dynamicTypeSize, ProcessInfo.processInfo.arguments.contains("--shop-large-type") ? .accessibility3 : .large)
        .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--shop-light") ? .light : .dark)
        .task { if ProcessInfo.processInfo.arguments.contains("--shop-capture-art") { capture() } }
    }

    @MainActor private func capture() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("shop-art-review")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if ProcessInfo.processInfo.arguments.contains("--shop-capture-shepherd-shirts") {
                let shirts = FarmShopCatalog.items(in: .shepherd).filter { $0.effect == .shepherdShirt }
                let combinations = HStack(alignment: .top, spacing: AppSpacing.md) {
                    ForEach(shirts) { shirt in
                        VStack {
                            ShepherdAvatarView(profile: ShepherdProfile(skinTone: .warm,
                                hairStyle: .long, outfitItemID: "shepherd_open_moss_coat",
                                accessoryItemID: "shepherd_wool_hat", shirtItemID: shirt.id), size: 180)
                            Text(shirt.title).font(AppTypography.caption)
                        }.frame(width: 190)
                    }
                }.padding(AppSpacing.lg).background(AppColors.paper).environment(\.colorScheme, .light)
                try save(combinations, name: "shepherd-shirts-with-coat-and-hat", directory: directory)
                return
            }
            if ProcessInfo.processInfo.arguments.contains("--shop-capture-shepherd") {
                let hats = FarmShopCatalog.items(in: .shepherd).filter { $0.effect == .shepherdAccessory }
                let clothes = FarmShopCatalog.items(in: .shepherd).filter { $0.effect == .shepherdOutfit }
                let combinations = VStack(spacing: AppSpacing.md) {
                    Text("Headwear + clothing · production renderer").font(AppTypography.title)
                    ForEach(hats) { hat in
                        HStack(spacing: AppSpacing.sm) {
                            ForEach(clothes) { outfit in
                                VStack {
                                    ShepherdAvatarView(profile: ShepherdProfile(skinTone: .warm,
                                        hairStyle: .long, outfitItemID: outfit.id,
                                        accessoryItemID: hat.id, shirtItemID: "shepherd_berry_shirt"), size: 140)
                                    Text(hat.title).font(AppTypography.caption)
                                    Text(outfit.title).font(AppTypography.caption)
                                }.frame(width: 180)
                            }
                        }
                    }
                }.padding(AppSpacing.lg).background(AppColors.paper).environment(\.colorScheme, .light)
                try save(combinations, name: "shepherd-combinations", directory: directory)
                return
            }
            let bandanaOnly = ProcessInfo.processInfo.arguments.contains("--shop-capture-bandana")
            for garment in bandanaOnly ? [.mossBandana] : OllieGarment.allCases {
                let frames = NightJourneyAssets.ollieHomeIdleFrames + NightJourneyAssets.ollieRunFrames
                    + (2...11).map { String(format: "dog/dog_ollie_motion_pose_%02d", $0) }
                    + ["dog/dog_classic_farm_idle"]
                let content = VStack(spacing: 12) {
                    Text(FarmShopCatalog.item(for: garment.rawValue)!.title).font(AppTypography.title)
                    Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                        ForEach(0..<((frames.count + 2) / 3), id: \.self) { row in
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
                if bandanaOnly {
                    for (index, frame) in frames.enumerated() {
                        let sprite = OllieDressedSprite(assetName: frame, accessoryItemID: garment.rawValue)
                            .frame(width: 512, height: 512).background(Color.black)
                        try save(sprite, name: String(format: "frame-%02d", index), directory: directory)
                    }
                    let layouts = HStack {
                        OllieDressedSprite(assetName: frames[4], accessoryItemID: garment.rawValue)
                            .frame(width: 256, height: 160)
                        OllieDressedSprite(assetName: frames[4], accessoryItemID: garment.rawValue)
                            .frame(width: 160, height: 256)
                        OllieDressedSprite(assetName: frames[4], accessoryItemID: "future_item")
                            .frame(width: 96, height: 96)
                    }.padding().background(Color.black)
                    try save(layouts, name: "layout-and-fallback", directory: directory)
                    let sizes = VStack(spacing: 20) {
                        ForEach([Color.black, AppColors.paper], id: \.self) { background in
                            HStack(alignment: .bottom, spacing: 20) {
                                OllieDressedSprite(assetName: frames[4], accessoryItemID: garment.rawValue)
                                    .frame(width: 210, height: 210)
                                OllieDressedSprite(assetName: frames[0], accessoryItemID: garment.rawValue)
                                    .frame(width: 72, height: 72)
                                OllieDressedSprite(assetName: frames[6], accessoryItemID: garment.rawValue)
                                    .frame(width: 72, height: 72)
                                OllieDressedSprite(assetName: frames[6], accessoryItemID: garment.rawValue)
                                    .frame(width: 72, height: 72).scaleEffect(x: -1, y: 1)
                            }.padding(20).background(background)
                        }
                    }.environment(\.colorScheme, .light)
                    try save(sizes, name: "home-farm-chase-sizes", directory: directory)
                }
            }
            if bandanaOnly { return }
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
        let renderer = ImageRenderer(content: content.environment(\.ollieCoat, model.farmState.equipment.ollieCoat))
        renderer.scale = 2
        guard let data = renderer.uiImage?.pngData() else { return }
        try data.write(to: directory.appendingPathComponent(name + ".png"))
    }
}
#endif
