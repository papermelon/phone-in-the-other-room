import Foundation

/// Continue from the displayed rest pose rather than switching a sleeping dog straight to running.
enum PastureFetchWakeUp {
    static func frames(from assetName: String?) -> [OllieCompanionSpriteFrame] {
        guard let assetName, assetName.hasPrefix("dog/dog_ollie_motion_pose_"),
              let pose = Int(assetName.suffix(2)), (5...11).contains(pose),
              let rise = OllieCompanionSpriteManifest.production.sequence(for: .rise) else { return [] }
        if pose >= 10 { return rise.frames.filter { $0.poseIdentifier >= pose } }
        return [.init(assetName: assetName, duration: 0.16, poseIdentifier: pose)] + rise.frames
    }
}
