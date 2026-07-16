import Foundation

@MainActor
public final class NovaVoiceService: NSObject {
    public var onStateChange: ((NovaVoiceState) -> Void)?
    public var onPartialTranscript: ((String) -> Void)?
    public var onFinalTranscript: ((String) -> Void)?
    public var onAudioLevel: ((Float) -> Void)?
    public var onNovaResponse: ((String) -> Void)?
    public var onSpeechProgress: ((_ range: NSRange, _ fullText: String) -> Void)?
    public var onAuthorizationChange: ((NovaVoiceAuthorization) -> Void)?
    public var onRouteChange: ((NovaVoiceRouteInfo) -> Void)?
    public var onMetric: ((NovaVoiceMetric) -> Void)?
    public var onFailure: ((NovaVoiceFailure) -> Void)?

    public private(set) var state: NovaVoiceState = .idle {
        didSet {
            guard oldValue != state else { return }
            onStateChange?(state)
        }
    }

    public private(set) var authorization: NovaVoiceAuthorization {
        didSet {
            guard oldValue != authorization else { return }
            onAuthorizationChange?(authorization)
        }
    }

    public var configuration: NovaVoiceConfiguration
    public var conversationID: String?

    public var isContinuousConversationActive: Bool {
        continuousConversationRequested
    }

    private let sender: NovaVoiceMessageSending
    private let audioSessionController = NovaAudioSessionController()
    private let transcriber = NovaSpeechTranscriber()
    private let speaker = NovaSpeechSpeaker()

    private var responseTask: Task<Void, Never>?
    private var restartTask: Task<Void, Never>?
    private var activeTurnID = UUID()
    private var continuousConversationRequested = false
    private var shouldResumeAfterInterruption = false

    private var turnStartedAt: TimeInterval?
    private var listeningStartedAt: TimeInterval?
    private var finalizationStartedAt: TimeInterval?
    private var novaRequestStartedAt: TimeInterval?
    private var speechStartedAt: TimeInterval?
    private var permissionStartedAt: TimeInterval?

    public init(
        sender: NovaVoiceMessageSending,
        conversationID: String? = nil,
        configuration: NovaVoiceConfiguration = .arabicMarketplace
    ) {
        self.sender = sender
        self.conversationID = conversationID
        self.configuration = configuration
        self.authorization = NovaVoicePermissionManager.currentAuthorization()
        super.init()

        audioSessionController.delegate = self
        transcriber.delegate = self
        speaker.delegate = self
    }

    deinit {
        responseTask?.cancel()
        restartTask?.cancel()
    }

    @discardableResult
    public func requestAuthorization() async -> NovaVoiceAuthorization {
        permissionStartedAt = Self.now()
        state = .requestingPermission

        let result = await NovaVoicePermissionManager.requestAuthorization()
        authorization = result

        if let started = permissionStartedAt {
            emitMetric(.permissionRequest, startedAt: started)
        }
        permissionStartedAt = nil

        if result.isFullyAuthorized {
            state = .idle
        } else {
            fail(authorizationFailure(for: result))
        }

        return result
    }

    public func startListening(continuous: Bool? = nil) async {
        if let continuous {
            continuousConversationRequested = continuous
        } else if state == .idle {
            continuousConversationRequested = configuration.continuousConversationEnabled
        }

        invalidatePendingTurn()
        speaker.stop(notify: false)
        transcriber.cancel()
        restartTask?.cancel()
        restartTask = nil

        turnStartedAt = Self.now()
        listeningStartedAt = nil
        finalizationStartedAt = nil
        novaRequestStartedAt = nil
        speechStartedAt = nil

        let current = NovaVoicePermissionManager.currentAuthorization()
        authorization = current
        let authorized = current.isFullyAuthorized
            ? current
            : await requestAuthorization()

        guard authorized.isFullyAuthorized else { return }
        state = .preparing

        do {
            try audioSessionController.configureForListening(configuration)
            try transcriber.start(configuration: configuration)
            listeningStartedAt = Self.now()
            state = .listening(partialTranscript: "")
        } catch let failure as NovaVoiceFailure {
            fail(failure)
        } catch {
            fail(
                NovaVoiceFailure(
                    code: .audioSessionFailure,
                    message: "Nova could not start voice mode.",
                    underlyingDescription: error.localizedDescription
                )
            )
        }
    }

    public func stopListeningAndSubmit() {
        guard case let .listening(partial) = state else { return }
        finalizationStartedAt = Self.now()
        state = .finalizing(transcript: partial)
        transcriber.finish()
    }

    public func interruptAndListen() async {
        invalidatePendingTurn()
        speaker.stop(notify: false)
        transcriber.cancel()
        await startListening(continuous: continuousConversationRequested)
    }

    public func stopSpeaking() {
        speaker.stop(notify: true)
        restartTask?.cancel()
        restartTask = nil
        state = .idle
        audioSessionController.deactivate()
    }

    public func cancelCurrentTurn() {
        continuousConversationRequested = false
        invalidatePendingTurn()
        transcriber.cancel()
        speaker.stop(notify: false)
        restartTask?.cancel()
        restartTask = nil
        state = .idle
        audioSessionController.deactivate()
    }

    public func setContinuousConversationEnabled(_ enabled: Bool) {
        continuousConversationRequested = enabled
        if !enabled {
            restartTask?.cancel()
            restartTask = nil
        }
    }

    /// Speak a response produced by the existing typed Nova pipeline.
    public func speakNovaResponse(_ response: String) {
        let clean = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        invalidatePendingTurn()
        transcriber.cancel()
        speak(clean)
    }

    /// Send an existing transcript through Nova's configured sender.
    public func submitTranscript(_ transcript: String) {
        let clean = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            fail(
                NovaVoiceFailure(
                    code: .emptyTranscript,
                    message: "No speech was detected. Please try again."
                )
            )
            return
        }
        handleFinalTranscript(clean)
    }

    private func handleFinalTranscript(_ transcript: String) {
        if let started = listeningStartedAt {
            emitMetric(.listeningDuration, startedAt: started)
        }
        listeningStartedAt = nil

        if let started = finalizationStartedAt {
            emitMetric(.finalizationLatency, startedAt: started)
        }
        finalizationStartedAt = nil

        onFinalTranscript?(transcript)
        state = .waitingForNova(transcript: transcript)

        let turnID = UUID()
        activeTurnID = turnID
        novaRequestStartedAt = Self.now()

        responseTask?.cancel()
        responseTask = Task { [weak self] in
            guard let self else { return }

            do {
                let response = try await self.sender.sendVoiceTranscript(
                    transcript,
                    conversationID: self.conversationID
                )

                try Task.checkCancellation()
                guard self.activeTurnID == turnID else { return }

                if let started = self.novaRequestStartedAt {
                    self.emitMetric(.novaResponseLatency, startedAt: started)
                }
                self.novaRequestStartedAt = nil

                let clean = response.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !clean.isEmpty else {
                    self.fail(
                        NovaVoiceFailure(
                            code: .emptyNovaResponse,
                            message: "Nova returned an empty response."
                        )
                    )
                    return
                }

                self.onNovaResponse?(clean)
                self.speak(clean)

            } catch is CancellationError {
                // Expected when the user interrupts or starts a newer turn.
            } catch {
                guard self.activeTurnID == turnID else { return }
                self.fail(
                    NovaVoiceFailure(
                        code: .novaRequestFailure,
                        message: "Nova could not complete the voice turn.",
                        underlyingDescription: error.localizedDescription
                    )
                )
            }
        }
    }

    private func speak(_ response: String) {
        do {
            try audioSessionController.configureForSpeaking(configuration)
            state = .speaking(response: response)
            speechStartedAt = Self.now()
            speaker.speak(response, configuration: configuration)
        } catch {
            fail(
                NovaVoiceFailure(
                    code: .audioSessionFailure,
                    message: "Nova could not play the voice response.",
                    underlyingDescription: error.localizedDescription
                )
            )
        }
    }

    private func scheduleContinuousRestartIfNeeded() {
        guard continuousConversationRequested else {
            state = .idle
            audioSessionController.deactivate()
            completeTurnMetrics()
            return
        }

        completeTurnMetrics()
        restartTask?.cancel()

        let delay = configuration.automaticRestartDelay
        restartTask = Task { [weak self] in
            guard let self else { return }
            if delay > 0 {
                try? await Task.sleep(
                    nanoseconds: UInt64(delay * 1_000_000_000)
                )
            }
            guard !Task.isCancelled else { return }
            await self.startListening(continuous: true)
        }
    }

    private func invalidatePendingTurn() {
        activeTurnID = UUID()
        responseTask?.cancel()
        responseTask = nil
    }

    private func fail(_ failure: NovaVoiceFailure) {
        invalidatePendingTurn()
        transcriber.cancel()
        speaker.stop(notify: false)
        restartTask?.cancel()
        restartTask = nil
        state = .failed(failure)
        onFailure?(failure)
        audioSessionController.deactivate()
    }

    private func authorizationFailure(
        for authorization: NovaVoiceAuthorization
    ) -> NovaVoiceFailure {
        if authorization.microphone != .authorized {
            return NovaVoiceFailure(
                code: .microphonePermissionDenied,
                message: "Microphone permission is required for Nova voice conversation."
            )
        }

        return NovaVoiceFailure(
            code: .speechPermissionDenied,
            message: "Speech-recognition permission is required for Nova voice conversation."
        )
    }

    private func completeTurnMetrics() {
        if let started = speechStartedAt {
            emitMetric(.speechDuration, startedAt: started)
        }
        speechStartedAt = nil

        if let started = turnStartedAt {
            emitMetric(.completeTurnDuration, startedAt: started)
        }
        turnStartedAt = nil
    }

    private func emitMetric(
        _ name: NovaVoiceMetric.Name,
        startedAt: TimeInterval,
        metadata: [String: String] = [:]
    ) {
        onMetric?(
            NovaVoiceMetric(
                name: name,
                milliseconds: max(0, (Self.now() - startedAt) * 1_000),
                metadata: metadata
            )
        )
    }

    private static func now() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }
}

extension NovaVoiceService: NovaSpeechTranscriberDelegate {
    func transcriber(
        _ transcriber: NovaSpeechTranscriber,
        didUpdatePartial transcript: String
    ) {
        state = .listening(partialTranscript: transcript)
        onPartialTranscript?(transcript)
    }

    func transcriber(
        _ transcriber: NovaSpeechTranscriber,
        didFinalize transcript: String
    ) {
        handleFinalTranscript(transcript)
    }

    func transcriber(
        _ transcriber: NovaSpeechTranscriber,
        didUpdateAudioLevel level: Float
    ) {
        onAudioLevel?(level)
    }

    func transcriber(
        _ transcriber: NovaSpeechTranscriber,
        didFail failure: NovaVoiceFailure
    ) {
        fail(failure)
    }
}

extension NovaVoiceService: NovaSpeechSpeakerDelegate {
    func speakerDidStart(_ speaker: NovaSpeechSpeaker) {}

    func speakerDidFinish(_ speaker: NovaSpeechSpeaker) {
        scheduleContinuousRestartIfNeeded()
    }

    func speakerDidCancel(_ speaker: NovaSpeechSpeaker) {
        if case .speaking = state {
            state = .idle
            audioSessionController.deactivate()
        }
    }

    func speaker(
        _ speaker: NovaSpeechSpeaker,
        willSpeakCharacterRange range: NSRange,
        in fullText: String
    ) {
        onSpeechProgress?(range, fullText)
    }
}

extension NovaVoiceService: NovaAudioSessionControllerDelegate {
    func audioSessionControllerDidBeginInterruption(
        _ controller: NovaAudioSessionController
    ) {
        shouldResumeAfterInterruption =
            configuration.automaticallyResumeAfterInterruption
            && continuousConversationRequested

        invalidatePendingTurn()
        transcriber.cancel()
        speaker.stop(notify: false)
        restartTask?.cancel()
        restartTask = nil
        state = .interrupted
    }

    func audioSessionController(
        _ controller: NovaAudioSessionController,
        didEndInterruptionShouldResume shouldResume: Bool
    ) {
        guard shouldResume, shouldResumeAfterInterruption else {
            state = .idle
            return
        }

        shouldResumeAfterInterruption = false
        Task { [weak self] in
            await self?.startListening(continuous: true)
        }
    }

    func audioSessionController(
        _ controller: NovaAudioSessionController,
        didChangeRoute route: NovaVoiceRouteInfo
    ) {
        onRouteChange?(route)
    }

    func audioSessionControllerMediaServicesWereReset(
        _ controller: NovaAudioSessionController
    ) {
        let shouldRestart = continuousConversationRequested
        transcriber.cancel()
        speaker.stop(notify: false)
        state = .idle

        if shouldRestart {
            Task { [weak self] in
                await self?.startListening(continuous: true)
            }
        }
    }
}
