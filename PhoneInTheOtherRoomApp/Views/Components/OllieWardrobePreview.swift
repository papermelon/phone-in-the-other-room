import SwiftUI

struct OllieWardrobePreview: View {
    let itemID: String
    @State private var pose = Pose.sitting
    @State private var beganAt = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Pose: String, CaseIterable, Identifiable {
        case sitting = "Sitting", running = "Running", resting = "Resting"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            TimelineView(.animation(minimumInterval: 0.05, paused: reduceMotion)) { time in
                OllieDressedSprite(assetName: asset(elapsed: max(0, time.date.timeIntervalSince(beganAt))), accessoryItemID: itemID)
                    .frame(width: 210, height: 210)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Preview: Ollie wearing \(FarmShopCatalog.item(for: itemID)?.title ?? "an accessory"), \(pose.rawValue.lowercased())")
            Picker("Preview pose", selection: $pose) {
                ForEach(Pose.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppSpacing.sm)
            .onChange(of: pose) { _, _ in beganAt = Date() }
            Text("One look for Home, Farm and every chase.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, AppSpacing.sm)
    }

    private func asset(elapsed: TimeInterval) -> String {
        let neutral = NightJourneyAssets.ollieHomeIdleFrames[0]
        if reduceMotion {
            switch pose {
            case .sitting: return neutral
            case .running: return NightJourneyAssets.ollieRunFrames[0]
            case .resting: return "dog/dog_ollie_motion_pose_09"
            }
        }
        let manifest = OllieCompanionSpriteManifest.production
        let sequence: OllieCompanionSpriteSequence
        switch pose {
        case .sitting:
            sequence = .init(frames: [.init(assetName: neutral, duration: 1.5, poseIdentifier: 1)]
                + (manifest.sequence(for: .headTilt)?.frames ?? []))
        case .running:
            sequence = .init(frames: NightJourneyAssets.ollieRunFrames.enumerated().map {
                .init(assetName: $0.element, duration: 0.15, poseIdentifier: $0.offset)
            })
        case .resting:
            sequence = .init(frames: [.init(assetName: neutral, duration: 1, poseIdentifier: 1)]
                + [OllieCompanionAction.settleToRest, .resting, .rise].flatMap { manifest.sequence(for: $0)?.frames ?? [] })
        }
        guard sequence.duration > 0 else { return neutral }
        return sequence.frame(at: elapsed.truncatingRemainder(dividingBy: sequence.duration))?.assetName ?? neutral
    }
}

#Preview("Scarf") {
    OllieWardrobePreview(itemID: "ollie_sunrise_scarf")
        .background(AppColors.paper)
}
