import AVFAudio
import AudioToolbox
import UIKit

final class PingService {
    func pingPhone() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? audioSession.setActive(true)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        AudioServicesPlayAlertSoundWithCompletion(1057) {
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
