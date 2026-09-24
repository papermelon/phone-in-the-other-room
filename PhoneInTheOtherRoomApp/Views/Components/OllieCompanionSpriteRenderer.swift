import SwiftUI
import UIKit

/// Resolves only the active action for one equipped choice. A missing frame
/// holds the supplied neutral renderer for the whole action, preventing a
/// partial sequence from flashing between neutral and an unrelated pose.
struct OllieCompanionSpriteRenderer<Neutral: View>: View {
    let animationFrame: OllieCompanionAnimationFrame
    let accessoryItemID: String?
    let size: CGFloat
    let onSpriteChanged: ((String?) -> Void)?
    @Binding var actionCapabilities: [OllieCompanionAction: Bool]
    @Binding var capabilityRevision: Int
    @ViewBuilder let neutral: () -> Neutral

    @State private var checkedAccessoryItemID: String?
    @State private var hasCheckedAccessory = false

    init(
        animationFrame: OllieCompanionAnimationFrame,
        accessoryItemID: String?,
        size: CGFloat,
        actionCapabilities: Binding<[OllieCompanionAction: Bool]>,
        capabilityRevision: Binding<Int>,
        onSpriteChanged: ((String?) -> Void)? = nil,
        @ViewBuilder neutral: @escaping () -> Neutral
    ) {
        self.animationFrame = animationFrame
        self.accessoryItemID = accessoryItemID
        self.size = size
        self.onSpriteChanged = onSpriteChanged
        _actionCapabilities = actionCapabilities
        _capabilityRevision = capabilityRevision
        self.neutral = neutral
    }

    var body: some View {
        Group {
            if let spriteFrame = resolvedSpriteFrame {
                OllieDressedSprite(assetName: spriteFrame.assetName, accessoryItemID: accessoryItemID)
            } else {
                neutral()
            }
        }
        .frame(width: size, height: size)
        .transaction { $0.animation = nil }
        .onChange(of: resolvedSpriteFrame?.assetName, initial: true) { _, assetName in
            onSpriteChanged?(assetName)
        }
        .task(id: capabilityKey) {
            refreshCapabilityIfNeeded()
        }
    }

    private var resolvedSpriteFrame: OllieCompanionSpriteFrame? {
        guard hasCheckedAccessory,
              checkedAccessoryItemID == accessoryItemID,
              actionCapabilities[animationFrame.action] == true else { return nil }
        return OllieCompanionSpriteManifest.production
            .sequence(for: animationFrame.action)?
            .frame(at: animationFrame.actionElapsed)
    }

    private var capabilityKey: CapabilityKey {
        CapabilityKey(action: animationFrame.action, accessoryItemID: accessoryItemID)
    }

    private func refreshCapabilityIfNeeded() {
        if !hasCheckedAccessory || checkedAccessoryItemID != accessoryItemID {
            checkedAccessoryItemID = accessoryItemID
            hasCheckedAccessory = true
            actionCapabilities = [:]
            capabilityRevision &+= 1
        }
        guard animationFrame.action != .neutral,
              actionCapabilities[animationFrame.action] == nil,
              let required = OllieCompanionSpriteManifest.production.requiredAssetNames(
                for: animationFrame.action,
                accessoryItemID: nil
              ) else {
            return
        }

        let available = Set(required.filter { UIImage(named: $0) != nil })
        let canRender = OllieCompanionSpriteManifest.production.canRender(
            action: animationFrame.action,
            accessoryItemID: nil,
            availableAssetNames: available
        )
        let fitted = OllieGarment(itemID: accessoryItemID) == nil
            || required.allSatisfy { OllieNeckwearPose.forAsset($0) != nil }
        for action in OllieCompanionSpriteManifest.production.capabilityActions(for: animationFrame.action) {
            actionCapabilities[action] = canRender && fitted
        }
        capabilityRevision &+= 1
    }

    private struct CapabilityKey: Hashable {
        let action: OllieCompanionAction
        let accessoryItemID: String?
    }
}

private struct OllieCompanionSpriteRendererPreview: View {
    @State private var actionCapabilities: [OllieCompanionAction: Bool] = [:]
    @State private var capabilityRevision = 0

    var body: some View {
        OllieCompanionSpriteRenderer(
            animationFrame: OllieCompanionAnimationFrame(
                action: .earTuck,
                cycleElapsed: 0,
                actionElapsed: 0.16,
                isAnimated: true
            ),
            accessoryItemID: "ollie_moss_bandana",
            size: 190,
            actionCapabilities: $actionCapabilities,
            capabilityRevision: $capabilityRevision
        ) {
            PixelAssetImage(name: NightJourneyAssets.ollieHomeIdleFrames[0])
        }
        .padding()
        .background(AppColors.paper)
    }
}

#Preview("Equipped ear tuck") {
    OllieCompanionSpriteRendererPreview()
}
