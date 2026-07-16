import AVFoundation
import Foundation
import Speech

@MainActor
protocol NovaSpeechTranscriberDelegate: AnyObject {
    func transcriber(_ transcriber: NovaSpeechTranscriber, didUpdatePartial transcript: String)
    func transcriber(_ transcriber: NovaSpeechTranscriber, didFinalize transcript: String)
    func transcriber(_ transcriber: NovaSpeechTranscriber, didUpdateAudioLevel level: Float)
    func transcriber(_ transcriber: NovaSpeechTranscriber, didFail failure: NovaVoiceFailure)
}

@MainActor
final class NovaSpeechTranscriber: NSObject, SFSpeechRecognizerDelegate {
    weak var delegate: NovaSpeechTranscriberDelegate?

    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?
    private var maximumDurationTimer: Timer?
    private var finalizationFallbackTimer: Timer?

    private var configuration = NovaVoiceConfiguration()
    private var latestTranscript = ""
    private var lastReportedTranscript = ""
    private var smoothedAudioLevel: Float = 0
    private var isCapturing = false
    private var isFinalizing = false
    private var didDeliverFinal = false
    private var audioBufferCounter = 0

    func start(configuration: NovaVoiceConfiguration) throws {
        cancel()
        self.configuration = configuration

        let locale = Self.resolveLocale(configuration.recognitionLocaleIdentifier)
        guard let recognizer = SFSpeechRecognizer(locale: locale),
              recognizer.isAvailable else {
            throw NovaVoiceFailure(
                code: .recognizerUnavailable,
                message: "Speech recognition is temporarily unavailable."
            )
        }

        self.recognizer = recognizer
        recognizer.delegate = self

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = configuration.taskHint
        request.contextualStrings = configuration.contextualStrings
        if #available(iOS 16.0, *) {
            request.addsPunctuation = configuration.addsPunctuation
        }

        switch configuration.onDeviceRecognitionPolicy {
        case .automatic:
            request.requiresOnDeviceRecognition = false
        case .prefer:
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        case .require:
            guard recognizer.supportsOnDeviceRecognition else {
                throw NovaVoiceFailure(
                    code: .recognizerUnavailable,
                    message: "On-device recognition is required but unavailable for this language."
                )
            }
            request.requiresOnDeviceRecognition = true
        }

        recognitionRequest = request
        resetRunState()

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw NovaVoiceFailure(
                code: .audioEngineFailure,
                message: "The microphone audio format is unavailable."
            )
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(
            onBus: 0,
            bufferSize: 1_024,
            format: format
        ) { [weak self, weak request] buffer, _ in
            request?.append(buffer)
            self?.calculateAudioLevel(from: buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognitionResult(result, error: error)
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            recognitionTask?.cancel()
            recognitionTask = nil
            recognitionRequest = nil
            throw NovaVoiceFailure(
                code: .audioEngineFailure,
                message: "Nova could not start the microphone.",
                underlyingDescription: error.localizedDescription
            )
        }

        isCapturing = true
        maximumDurationTimer = Timer.scheduledTimer(
            withTimeInterval: configuration.maximumUtteranceDuration,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in self?.finish() }
        }
    }

    func finish() {
        guard isCapturing || !latestTranscript.isEmpty else {
            deliverEmptyTranscriptFailure()
            return
        }
        guard !isFinalizing else { return }

        isFinalizing = true
        stopCapture()
        recognitionRequest?.endAudio()

        finalizationFallbackTimer?.invalidate()
        finalizationFallbackTimer = Timer.scheduledTimer(
            withTimeInterval: configuration.finalizationGraceInterval,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in self?.deliverLatestTranscriptIfNeeded() }
        }
    }

    func cancel() {
        silenceTimer?.invalidate()
        maximumDurationTimer?.invalidate()
        finalizationFallbackTimer?.invalidate()
        silenceTimer = nil
        maximumDurationTimer = nil
        finalizationFallbackTimer = nil

        stopCapture()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        recognizer = nil
        resetRunState()
    }

    private static func resolveLocale(_ identifier: String) -> Locale {
        let preferred = Locale(identifier: identifier)
        if SFSpeechRecognizer.supportedLocales().contains(preferred) {
            return preferred
        }
        if identifier.hasPrefix("ar") {
            if let fallback = SFSpeechRecognizer.supportedLocales().first(where: { $0.identifier.hasPrefix("ar-") }) {
                return fallback
            }
            return Locale(identifier: "ar-SA")
        }
        let en = Locale(identifier: "en-US")
        if SFSpeechRecognizer.supportedLocales().contains(en) {
            return en
        }
        return SFSpeechRecognizer.supportedLocales().first ?? preferred
    }

    private func resetRunState() {
        latestTranscript = ""
        lastReportedTranscript = ""
        smoothedAudioLevel = 0
        isCapturing = false
        isFinalizing = false
        didDeliverFinal = false
        audioBufferCounter = 0
    }

    private func stopCapture() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        isCapturing = false
        silenceTimer?.invalidate()
        maximumDurationTimer?.invalidate()
        silenceTimer = nil
        maximumDurationTimer = nil
    }

    private func handleRecognitionResult(
        _ result: SFSpeechRecognitionResult?,
        error: Error?
    ) {
        if let result {
            let transcript = result.bestTranscription.formattedString
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !transcript.isEmpty {
                latestTranscript = transcript
                if transcript != lastReportedTranscript {
                    lastReportedTranscript = transcript
                    delegate?.transcriber(self, didUpdatePartial: transcript)
                    scheduleSilenceTimer()
                }
            }

            if result.isFinal {
                deliverLatestTranscriptIfNeeded()
                return
            }
        }

        if let error, !didDeliverFinal {
            if isFinalizing, !latestTranscript.isEmpty {
                deliverLatestTranscriptIfNeeded()
                return
            }

            stopCapture()
            delegate?.transcriber(
                self,
                didFail: NovaVoiceFailure(
                    code: .recognitionFailure,
                    message: "Nova could not understand the voice input.",
                    underlyingDescription: error.localizedDescription
                )
            )
        }
    }

    private func scheduleSilenceTimer() {
        guard !latestTranscript.isEmpty else { return }
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(
            withTimeInterval: configuration.silenceAutoSubmitInterval,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in self?.finish() }
        }
    }

    private func deliverLatestTranscriptIfNeeded() {
        guard !didDeliverFinal else { return }
        didDeliverFinal = true
        finalizationFallbackTimer?.invalidate()
        stopCapture()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        recognizer = nil

        let final = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard final.count >= configuration.minimumNonEmptyTranscriptLength else {
            deliverEmptyTranscriptFailure()
            return
        }

        delegate?.transcriber(self, didFinalize: final)
    }

    private func deliverEmptyTranscriptFailure() {
        guard !didDeliverFinal else { return }
        didDeliverFinal = true
        stopCapture()
        delegate?.transcriber(
            self,
            didFail: NovaVoiceFailure(
                code: .emptyTranscript,
                message: "No speech was detected. Please try again."
            )
        )
    }

    nonisolated private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard
            let channelData = buffer.floatChannelData?.pointee,
            buffer.frameLength > 0
        else { return }

        let count = Int(buffer.frameLength)
        var sum: Float = 0
        for index in 0..<count {
            let value = channelData[index]
            sum += value * value
        }

        let rms = sqrt(sum / Float(count))
        let decibels = 20 * log10(max(rms, 0.000_01))
        let normalized = min(max((decibels + 60) / 60, 0), 1)

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.audioBufferCounter += 1
            guard self.audioBufferCounter % 3 == 0 else { return }

            let smoothing = self.configuration.audioLevelSmoothing
            self.smoothedAudioLevel =
                smoothing * self.smoothedAudioLevel
                + (1 - smoothing) * normalized

            self.delegate?.transcriber(
                self,
                didUpdateAudioLevel: self.smoothedAudioLevel
            )
        }
    }

    func speechRecognizer(
        _ speechRecognizer: SFSpeechRecognizer,
        availabilityDidChange available: Bool
    ) {
        guard !available, isCapturing else { return }
        delegate?.transcriber(
            self,
            didFail: NovaVoiceFailure(
                code: .recognizerUnavailable,
                message: "Speech recognition became unavailable."
            )
        )
    }
}
