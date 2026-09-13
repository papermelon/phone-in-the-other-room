import SwiftUI

struct OllieWardrobePreview: View {
    let itemID: String
    @State private var pose = Pose.sitting
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Pose: String, CaseIterable, Identifiable {
        case sitting = "Sitting", running = "Running", resting = "Resting"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            TimelineView(.animation(minimumInterval: 0.15, paused: reduceMotion || pose != .running)) { time in
                let frame = reduceMotion ? 0 : Int(time.date.timeIntervalSinceReferenceDate / 0.15) % 6
                OllieDressedSprite(assetName: asset(frame: frame), accessoryItemID: itemID)
                    .frame(width: 210, height: 210)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Preview: Ollie wearing \(FarmShopCatalog.item(for: itemID)?.title ?? "an accessory"), \(pose.rawValue.lowercased())")
            Picker("Preview pose", selection: $pose) {
                ForEach(Pose.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppSpacing.sm)
            Text("One look for Home, Farm and every chase.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, AppSpacing.sm)
    }

    private func asset(frame: Int) -> String {
        switch pose {
        case .sitting: return NightJourneyAssets.ollieHomeIdleFrames[0]
        case .running: return NightJourneyAssets.ollieRunFrames[frame]
        case .resting: return "dog/dog_ollie_motion_pose_09"
        }
    }
}

#Preview("Scarf") {
    OllieWardrobePreview(itemID: "ollie_sunrise_scarf")
        .background(AppColors.paper)
}
