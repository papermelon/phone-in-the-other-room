import AVFAudio
import AudioToolbox
import UIKit

final class PingService {
    func pingPhone() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        AudioServicesPlayAlertSound(1057)
    }
}
