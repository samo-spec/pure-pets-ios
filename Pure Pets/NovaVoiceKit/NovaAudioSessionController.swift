import AVFoundation
import Foundation

@MainActor
protocol NovaAudioSessionControllerDelegate: AnyObject {
    func audioSessionControllerDidBeginInterruption(_ controller: NovaAudioSessionController)
    func audioSessionController(
        _ controller: NovaAudioSessionController,
        didEndInterruptionShouldResume shouldResume: Bool
    )
    func audioSessionController(
        _ controller: NovaAudioSessionController,
        didChangeRoute route: NovaVoiceRouteInfo
    )
    func audioSessionControllerMediaServicesWereReset(_ controller: NovaAudioSessionController)
}

@MainActor
final class NovaAudioSessionController {
    weak var delegate: NovaAudioSessionControllerDelegate?

    private let session = AVAudioSession.sharedInstance()
    private var observers: [NSObjectProtocol] = []

    init() {
        installObservers()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func configureForListening(_ configuration: NovaVoiceConfiguration) throws {
        try configure(configuration)
        if configuration.prefersEchoCancelledInput {
            if #available(iOS 18.2, *) {
                try? session.setPrefersEchoCancelledInput(true)
            }
        }
    }

    func configureForSpeaking(_ configuration: NovaVoiceConfiguration) throws {
        try configure(configuration)
    }

    func deactivate() {
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
    }

    func currentRouteInfo() -> NovaVoiceRouteInfo {
        NovaVoiceRouteInfo(
            inputNames: session.currentRoute.inputs.map(\.portName),
            outputNames: session.currentRoute.outputs.map(\.portName)
        )
    }

    private func configure(_ configuration: NovaVoiceConfiguration) throws {
        var options: AVAudioSession.CategoryOptions = []
        if configuration.allowsBluetoothHFP {
            options.insert(.allowBluetoothHFP)
        }
        if configuration.outputRoutePreference == .speaker {
            options.insert(.defaultToSpeaker)
        }

        try session.setCategory(.playAndRecord, mode: .voiceChat, options: options)
        try? session.setPreferredIOBufferDuration(configuration.preferredIOBufferDuration)
        try session.setActive(true, options: [])

        if configuration.outputRoutePreference == .speaker,
           !currentRouteContainsPrivateOutput() {
            try? session.overrideOutputAudioPort(.speaker)
        }
    }

    private func currentRouteContainsPrivateOutput() -> Bool {
        let ports = session.currentRoute.outputs.map(\.portType)
        return ports.contains(.bluetoothHFP)
            || ports.contains(.bluetoothA2DP)
            || ports.contains(.bluetoothLE)
            || ports.contains(.headphones)
            || ports.contains(.headsetMic)
    }

    private func installObservers() {
        let center = NotificationCenter.default

        observers.append(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: session,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    self?.handleInterruption(notification)
                }
            }
        )

        observers.append(
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: session,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.delegate?.audioSessionController(
                        self,
                        didChangeRoute: self.currentRouteInfo()
                    )
                }
            }
        )

        observers.append(
            center.addObserver(
                forName: AVAudioSession.mediaServicesWereResetNotification,
                object: session,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.delegate?.audioSessionControllerMediaServicesWereReset(self)
                }
            }
        )
    }

    private func handleInterruption(_ notification: Notification) {
        guard
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: rawType)
        else {
            return
        }

        switch type {
        case .began:
            delegate?.audioSessionControllerDidBeginInterruption(self)

        case .ended:
            let rawOptions =
                notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            delegate?.audioSessionController(
                self,
                didEndInterruptionShouldResume: options.contains(.shouldResume)
            )

        @unknown default:
            break
        }
    }
}
