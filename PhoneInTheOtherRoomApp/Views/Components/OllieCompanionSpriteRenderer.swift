import SwiftUI
import UIKit

/// Legacy neutral overlays keep an equipped accessory visible when its exact
/// registered neutral overlay is not available yet.
func ollieNeutralAccessoryOverlayAssetName(for accessoryItemID: String?) -> String? {
    guard let item = accessoryItemID.flatMap(FarmShopCatalog.item),
          case .ollieAccessory(let assetName) = item.equippedRenderAsset,
          UIImage(named: assetName) != nil else {
        return nil
    }
    return assetName
}

/// Resolves only the active action for one equipped choice. A missing frame
/// holds the supplied neutral renderer for the whole action, preventing a
/// partial sequence from flashing between neutral and an unrelated pose.
struct OllieCompanionSpriteRenderer<Neutral: View>: View {
    let animationFrame: OllieCompanionAnimationFrame
    let accessoryItemID: String?
    let size: CGFloat
    @Binding var actionCapabilities: [OllieCompanionAction: Bool]
    @Binding var capabilityRevision: Int
    @ViewBuilder let neutral: (String?) -> Neutral

    @State private var checkedAccessoryItemID: String?
    @State private var hasCheckedAccessory = false
    @State private var neutralMotionOverlayName: String?

    init(
        animationFrame: OllieCompanionAnimationFrame,
        accessoryItemID: String?,
        size: CGFloat,
        actionCapabilities: Binding<[OllieCompanionAction: Bool]>,
        capabilityRevision: Binding<Int>,
        @ViewBuilder neutral: @escaping (String?) -> Neutral
    ) {
        self.animationFrame = animationFrame
        self.accessoryItemID = accessoryItemID
        self.size = size
        _actionCapabilities = actionCapabilities
        _capabilityRevision = capabilityRevision
        self.neutral = neutral
    }

    var body: some View {
        Group {
            if let spriteFrame = resolvedSpriteFrame {
                ZStack {
                    PixelAssetImage(name: spriteFrame.assetName)
                    if let overlayName = OllieCompanionSpriteManifest.production.overlayAssetName(
                        for: accessoryItemID,
                        frame: spriteFrame
                    ) {
                        PixelAssetImage(name: overlayName)
                    }
                }
            } else {
                neutral(currentNeutralMotionOverlayName)
            }
        }
        .frame(width: size, height: size)
        .transaction { $0.animation = nil }
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

    private var currentNeutralMotionOverlayName: String? {
        guard hasCheckedAccessory, checkedAccessoryItemID == accessoryItemID else { return nil }
        return neutralMotionOverlayName
    }

    private var capabilityKey: CapabilityKey {
        CapabilityKey(action: animationFrame.action, accessoryItemID: accessoryItemID)
    }

    private func refreshCapabilityIfNeeded() {
        if !hasCheckedAccessory || checkedAccessoryItemID != accessoryItemID {
            checkedAccessoryItemID = accessoryItemID
            hasCheckedAccessory = true
            actionCapabilities = [:]
            neutralMotionOverlayName = OllieCompanionSpriteManifest.production.neutralOverlayAssetName(
                for: accessoryItemID
            ).flatMap { UIImage(named: $0) == nil ? nil : $0 }
            capabilityRevision &+= 1
        }
        guard animationFrame.action != .neutral,
              actionCapabilities[animationFrame.action] == nil,
              let required = OllieCompanionSpriteManifest.production.requiredAssetNames(
                for: animationFrame.action,
                accessoryItemID: accessoryItemID
              ) else {
            return
        }

        let available = Set(required.filter { UIImage(named: $0) != nil })
        let canRender = OllieCompanionSpriteManifest.production.canRender(
            action: animationFrame.action,
            accessoryItemID: accessoryItemID,
            availableAssetNames: available
        )
        for action in OllieCompanionSpriteManifest.production.capabilityActions(for: animationFrame.action) {
            actionCapabilities[action] = canRender
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
        ) { _ in
            PixelAssetImage(name: NightJourneyAssets.ollieHomeIdleFrames[0])
        }
        .padding()
        .background(AppColors.paper)
    }
}

#Preview("Equipped ear tuck") {
    OllieCompanionSpriteRendererPreview()
}
