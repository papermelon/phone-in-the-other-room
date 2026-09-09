#if DEBUG
import SwiftUI

/// A local Debug harness. It never receives a run model, account, store, or backend client.
struct ShepherdArtStudyView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var appearance: ShepherdStudyAppearance
    @State private var direction: ShepherdStudyDirection = .threeQuarter
    @State private var motion: ShepherdStudyMotion = .still
    @State private var paperTexture = true
    @State private var startedAt = Date()
    @State private var manualFrame = 0
    @State private var isVisible = false
    @State private var exportResult: String?

    init(appearance: ShepherdStudyAppearance = .init()) {
        _appearance = State(initialValue: appearance)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    Text("Native movement study")
                        .font(pixelFont(.headline))
                    Text("Local preview · no Farm changes")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                    NavigationLink("Preview production customization") { ShepherdProductionPreview() }
                    stage
                    motionControls
                    appearanceControls
                    Button("Export master sheets") { exportMasters() }
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                        .frame(minHeight: 44)
                    if let exportResult {
                        Text(exportResult)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                            .textSelection(.enabled)
                    }
                }
                .padding(AppSpacing.md)
            }
            .background(AppColors.paper)
            .foregroundStyle(AppColors.ink)
            .navigationTitle("Shepherd art study")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { isVisible = true; startedAt = Date() }
        .onDisappear { isVisible = false }
        .onChange(of: reduceMotion) { _, _ in restart() }
        .onChange(of: scenePhase) { _, _ in restart() }
        .task {
            if ProcessInfo.processInfo.arguments.contains("--shepherd-art-export") { exportMasters() }
        }
    }

    private var allowsAnimation: Bool {
        ShepherdStudyMotionRules.canAnimate(motion, reduceMotion: reduceMotion,
                                           isActive: isVisible && scenePhase == .active)
    }

    private var stage: some View {
        PixelCard {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !allowsAnimation)) { timeline in
                let pose = currentPose(at: timeline.date)
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: AppSpacing.md))
                    : AnyLayout(HStackLayout(alignment: .bottom, spacing: AppSpacing.sm))
                layout {
                    VStack(spacing: AppSpacing.xs) {
                        ShepherdStudyCanvas(appearance: appearance, direction: direction, pose: pose, paperTexture: paperTexture)
                            .frame(width: 160, height: 200)
                        Text("Master").font(AppTypography.caption)
                    }
                    VStack(spacing: AppSpacing.xs) {
                        ShepherdStudyCanvas(appearance: appearance, direction: direction, pose: pose, paperTexture: paperTexture)
                            .frame(width: 72, height: 72)
                        Text("Farm · 72 pt").font(AppTypography.caption)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var motionControls: some View {
        VStack(spacing: AppSpacing.sm) {
            Picker("Motion", selection: Binding(get: { motion }, set: { motion = $0; restart() })) {
                ForEach(ShepherdStudyMotion.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("shepherd-study-motion")
            HStack(spacing: AppSpacing.sm) {
                Button("Turn") { direction = direction.next }
                Button("Step frame") {
                    motion = .still
                    manualFrame = manualFrame % 8 + 1
                }
            }
            .buttonStyle(PixelChipButtonStyle(isSelected: false))
            .frame(minHeight: 44)
            if reduceMotion {
                Text("Reduce Motion is on. Use Step frame to inspect individual poses.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
    }

    private var appearanceControls: some View {
        PixelCard {
            VStack(spacing: AppSpacing.sm) {
                Picker("Head shape", selection: $appearance.head) {
                    ForEach(ShepherdStudySilhouette.allCases) { Text($0.title).tag($0) }
                }
                Picker("Eyes", selection: $appearance.eyes) {
                    ForEach(ShepherdStudyEyes.allCases) { Text($0.title).tag($0) }
                }
                Picker("Hair", selection: $appearance.hair) {
                    ForEach(ShepherdStudyHair.allCases) { Text($0.title).tag($0) }
                }
                Picker("Clothes", selection: $appearance.outfit) {
                    ForEach(ShepherdStudyOutfit.allCases) { Text($0.title).tag($0) }
                }
                Picker("Skin tone", selection: $appearance.skin) {
                    ForEach(ShepherdSkinTone.allCases) { Text($0.title).tag($0) }
                }
                Picker("Facing", selection: $direction) {
                    ForEach(ShepherdStudyDirection.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Wool hat", isOn: $appearance.hat)
                Toggle("Face left", isOn: $appearance.faceLeft)
                Toggle("Paper texture", isOn: $paperTexture)
            }
            .pickerStyle(.menu)
            .font(AppTypography.body)
            .tint(AppColors.grass)
        }
    }

    private func currentPose(at date: Date) -> ShepherdStudyPose {
        if manualFrame > 0 && motion == .still {
            return ShepherdStudyMotionRules.pose(at: Double(manualFrame) / 8 * ShepherdStudyMotionRules.cycleDuration, motion: .walk)
        }
        return ShepherdStudyMotionRules.pose(at: date.timeIntervalSince(startedAt), motion: motion,
                                            reduceMotion: reduceMotion, isActive: isVisible && scenePhase == .active)
    }

    private func restart() { startedAt = Date(); manualFrame = 0 }

    private func exportMasters() {
        do { exportResult = "Exported: \(try ShepherdStudyMasterExporter.export().lastPathComponent)" }
        catch { exportResult = "Export failed: \(error.localizedDescription)" }
    }
}


/// Uses the actual production controls with disposable state, without touching a Farm.
struct ShepherdProductionPreview: View {
    @State private var profile = ShepherdProfile.defaultProfile
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                ShepherdAvatarView(profile: profile, size: 180)
                ShepherdAppearanceControls(
                    profile: profile,
                    onSkinTone: { profile.skinTone = $0 },
                    onHeadShape: { profile.headShape = $0 },
                    onHairStyle: { profile.hairStyle = $0 }
                )
                ForEach(FarmShopCatalog.items(in: .shepherd)) { item in
                    Button {
                        if item.effect == .shepherdOutfit {
                            profile.outfitItemID = profile.outfitItemID == item.id ? nil : item.id
                        } else {
                            profile.accessoryItemID = profile.accessoryItemID == item.id ? nil : item.id
                        }
                    } label: {
                        HStack {
                            FarmShopItemImage(item: item, size: 54)
                            Text(item.title).font(AppTypography.body)
                            Spacer()
                            if profile.outfitItemID == item.id || profile.accessoryItemID == item.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                }
            }.padding(AppSpacing.md)
        }
        .background(AppColors.paper)
        .navigationTitle("Production preview")
    }
}

#Preview("Production · large type") {
    NavigationStack { ShepherdProductionPreview() }
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
}

#Preview("B · native study") { ShepherdArtStudyView() }
#Preview("C · long hair and dress") { ShepherdArtStudyView(appearance: .round) }
#Preview("Large text and dark room") {
    ShepherdArtStudyView(appearance: .round)
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
}
#endif
