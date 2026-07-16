import Foundation
import Speech

@objc public protocol NovaVoiceObjCMessageSending: AnyObject {
    func novaVoiceSendTranscript(
        _ transcript: String,
        conversationID: String?,
        completion: @escaping (_ response: String?, _ error: NSError?) -> Void
    )
}

@objc public protocol NovaVoiceObjCBridgeDelegate: AnyObject {
    @objc optional func novaVoiceBridge(
        _ bridge: NovaVoiceObjCBridge,
        didChangeState state: String
    )
    @objc optional func novaVoiceBridge(
        _ bridge: NovaVoiceObjCBridge,
        didUpdatePartialTranscript transcript: String
    )
    @objc optional func novaVoiceBridge(
        _ bridge: NovaVoiceObjCBridge,
        didFinalizeTranscript transcript: String
    )
    @objc optional func novaVoiceBridge(
        _ bridge: NovaVoiceObjCBridge,
        didUpdateAudioLevel level: Float
    )
    @objc optional func novaVoiceBridge(
        _ bridge: NovaVoiceObjCBridge,
        didReceiveNovaResponse response: String
    )
    @objc optional func novaVoiceBridge(
        _ bridge: NovaVoiceObjCBridge,
        didFailWithCode code: String,
        message: String
    )
}

@MainActor
@objcMembers
public final class NovaVoiceObjCBridge: NSObject {
    public weak var delegate: NovaVoiceObjCBridgeDelegate?

    public var conversationID: String? {
        get { service.conversationID }
        set { service.conversationID = newValue }
    }

    public var continuousConversationEnabled: Bool = false {
        didSet {
            service.setContinuousConversationEnabled(
                continuousConversationEnabled
            )
        }
    }

    public var recognitionLocaleIdentifier: String {
        get { service.configuration.recognitionLocaleIdentifier }
        set { service.configuration.recognitionLocaleIdentifier = newValue }
    }

    public var synthesisLanguageIdentifier: String {
        get { service.configuration.synthesisLanguageIdentifier }
        set { service.configuration.synthesisLanguageIdentifier = newValue }
    }

    public var silenceAutoSubmitInterval: TimeInterval {
        get { service.configuration.silenceAutoSubmitInterval }
        set { service.configuration.silenceAutoSubmitInterval = newValue }
    }

    public var stateName: String {
        service.state.name
    }

    private let service: NovaVoiceService
    private weak var sender: NovaVoiceObjCMessageSending?

    public init(
        sender: NovaVoiceObjCMessageSending,
        conversationID: String? = nil
    ) {
        self.sender = sender

        let adapter = NovaVoiceMessageSenderClosure { [weak sender] transcript, conversationID in
            guard let sender else {
                throw NovaVoiceFailure(
                    code: .novaRequestFailure,
                    message: "The Nova Objective-C sender was released."
                )
            }

            return try await withCheckedThrowingContinuation { continuation in
                sender.novaVoiceSendTranscript(
                    transcript,
                    conversationID: conversationID
                ) { response, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let response {
                        continuation.resume(returning: response)
                    } else {
                        continuation.resume(
                            throwing: NovaVoiceFailure(
                                code: .emptyNovaResponse,
                                message: "Nova returned no response."
                            )
                        )
                    }
                }
            }
        }

        service = NovaVoiceService(
            sender: adapter,
            conversationID: conversationID,
            configuration: .arabicMarketplace
        )

        super.init()
        bindCallbacks()
    }

    public func requestAuthorization(
        completion: @escaping (Bool, String?) -> Void
    ) {
        Task {
            let auth = await service.requestAuthorization()
            completion(
                auth.isFullyAuthorized,
                auth.isFullyAuthorized
                    ? nil
                    : "Microphone and speech-recognition permissions are required."
            )
        }
    }

    public func startListening() {
        Task {
            await service.startListening(
                continuous: continuousConversationEnabled
            )
        }
    }

    public func stopListeningAndSubmit() {
        service.stopListeningAndSubmit()
    }

    public func interruptAndListen() {
        Task { await service.interruptAndListen() }
    }

    public func cancelCurrentTurn() {
        service.cancelCurrentTurn()
    }

    public func stopSpeaking() {
        service.stopSpeaking()
    }

    public func speakNovaResponse(_ response: String) {
        service.speakNovaResponse(response)
    }

    public func submitTranscript(_ transcript: String) {
        service.submitTranscript(transcript)
    }

    public func transcribeAudioURL(
        _ url: URL,
        completion: @escaping (String?, Error?) -> Void
    ) {
        let locale = Locale(identifier: recognitionLocaleIdentifier)
        let recognizer = SFSpeechRecognizer(locale: locale)
        guard let recognizer, recognizer.isAvailable else {
            completion(nil, NSError(
                domain: "NovaVoice",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Speech recognizer unavailable for \(locale.identifier)"]
            ))
            return
        }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        recognizer.recognitionTask(with: request) { result, error in
            if let error {
                completion(nil, error)
                return
            }
            guard let transcript = result?.bestTranscription.formattedString, !transcript.isEmpty else {
                completion(nil, NSError(
                    domain: "NovaVoice",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "No speech detected"]
                ))
                return
            }
            completion(transcript, nil)
        }
    }

    private func bindCallbacks() {
        service.onStateChange = { [weak self] state in
            guard let self else { return }
            self.delegate?.novaVoiceBridge?(self, didChangeState: state.name)
        }

        service.onPartialTranscript = { [weak self] transcript in
            guard let self else { return }
            self.delegate?.novaVoiceBridge?(
                self,
                didUpdatePartialTranscript: transcript
            )
        }

        service.onFinalTranscript = { [weak self] transcript in
            guard let self else { return }
            self.delegate?.novaVoiceBridge?(
                self,
                didFinalizeTranscript: transcript
            )
        }

        service.onAudioLevel = { [weak self] level in
            guard let self else { return }
            self.delegate?.novaVoiceBridge?(self, didUpdateAudioLevel: level)
        }

        service.onNovaResponse = { [weak self] response in
            guard let self else { return }
            self.delegate?.novaVoiceBridge?(
                self,
                didReceiveNovaResponse: response
            )
        }

        service.onFailure = { [weak self] failure in
            guard let self else { return }
            self.delegate?.novaVoiceBridge?(
                self,
                didFailWithCode: failure.code.rawValue,
                message: failure.localizedDescription
            )
        }
    }
}
