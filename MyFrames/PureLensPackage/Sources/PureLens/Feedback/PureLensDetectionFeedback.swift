#if canImport(UIKit)
import AVFoundation
import PureLensCore
import UIKit

@MainActor
final class PureLensDetectionFeedback {
    private let soundEnabled: Bool
    private let hapticsEnabled: Bool
    private var audioPlayer: AVAudioPlayer?
    private var impactGenerator: UIImpactFeedbackGenerator?
    private var gate = LensRecognitionFeedbackGate()

    init(soundEnabled: Bool, hapticsEnabled: Bool) {
        self.soundEnabled = soundEnabled
        self.hapticsEnabled = hapticsEnabled
    }

    func prepare() {
        if soundEnabled, audioPlayer == nil,
           let url = Bundle.module.url(forResource: "purelens-detected", withExtension: "wav") {
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = 0.24
            audioPlayer?.prepareToPlay()
        }

        if hapticsEnabled, impactGenerator == nil {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.prepare()
            impactGenerator = generator
        }
    }

    func playDetection(
        for recognition: LensPetRecognition,
        cooldown: TimeInterval
    ) -> Bool {
        guard gate.shouldPlay(for: recognition, cooldown: cooldown) else {
            return false
        }

        prepare()
        if soundEnabled {
            audioPlayer?.currentTime = 0
            audioPlayer?.play()
        }
        if hapticsEnabled {
            impactGenerator?.impactOccurred(intensity: 0.62)
            impactGenerator?.prepare()
        }
        return true
    }

    func stop() {
        audioPlayer?.stop()
    }

    func reset() {
        stop()
        gate.reset()
    }
}


#endif