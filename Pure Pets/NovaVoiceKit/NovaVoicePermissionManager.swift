import AVFoundation
import Foundation
import Speech

@MainActor
public enum NovaVoicePermissionManager {
    public static func currentAuthorization() -> NovaVoiceAuthorization {
        NovaVoiceAuthorization(
            microphone: microphoneStatus(),
            speechRecognition: speechStatus()
        )
    }

    public static func requestAuthorization() async -> NovaVoiceAuthorization {
        let speech = await requestSpeechAuthorization()
        guard speech == .authorized else {
            return NovaVoiceAuthorization(
                microphone: microphoneStatus(),
                speechRecognition: speech
            )
        }

        let microphone = await requestMicrophoneAuthorization()
        return NovaVoiceAuthorization(
            microphone: microphone,
            speechRecognition: speech
        )
    }

    private static func speechStatus() -> NovaVoiceAuthorization.Status {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .restricted: return .restricted
        case .authorized: return .authorized
        @unknown default: return .restricted
        }
    }

    private static func microphoneStatus() -> NovaVoiceAuthorization.Status {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .undetermined: return .notDetermined
            case .denied: return .denied
            case .granted: return .authorized
            @unknown default: return .restricted
            }
        }

        switch AVAudioSession.sharedInstance().recordPermission {
        case .undetermined: return .notDetermined
        case .denied: return .denied
        case .granted: return .authorized
        @unknown default: return .restricted
        }
    }

    private static func requestSpeechAuthorization() async -> NovaVoiceAuthorization.Status {
        let current = speechStatus()
        guard current == .notDetermined else { return current }

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                let mapped: NovaVoiceAuthorization.Status
                switch status {
                case .notDetermined: mapped = .notDetermined
                case .denied: mapped = .denied
                case .restricted: mapped = .restricted
                case .authorized: mapped = .authorized
                @unknown default: mapped = .restricted
                }
                continuation.resume(returning: mapped)
            }
        }
    }

    private static func requestMicrophoneAuthorization() async -> NovaVoiceAuthorization.Status {
        let current = microphoneStatus()
        guard current == .notDetermined else { return current }

        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
        } else {
            granted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
        }

        return granted ? .authorized : .denied
    }
}
