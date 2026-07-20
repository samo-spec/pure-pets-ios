import AVFoundation
import Foundation

@MainActor
protocol NovaSpeechSpeakerDelegate: AnyObject {
    func speakerDidStart(_ speaker: NovaSpeechSpeaker)
    func speakerDidFinish(_ speaker: NovaSpeechSpeaker)
    func speakerDidCancel(_ speaker: NovaSpeechSpeaker)
    func speaker(
        _ speaker: NovaSpeechSpeaker,
        willSpeakCharacterRange range: NSRange,
        in fullText: String
    )
}

@MainActor
final class NovaSpeechSpeaker: NSObject, AVSpeechSynthesizerDelegate {
    weak var delegate: NovaSpeechSpeakerDelegate?

    private let synthesizer = AVSpeechSynthesizer()
    private var chunks: [String] = []
    private var currentChunkIndex = 0
    private var currentText = ""
    private var fullText = ""
    private var fullTextOffset = 0
    private var configuration = NovaVoiceConfiguration()
    private var suppressCancelCallback = false

    override init() {
        super.init()
        synthesizer.delegate = self
        synthesizer.usesApplicationAudioSession = true
    }

    func speak(_ text: String, configuration: NovaVoiceConfiguration) {
        stop(notify: false)
        self.configuration = configuration

        let prepared = configuration.stripsMarkdownBeforeSpeaking
            ? NovaSpeechTextSanitizer.sanitize(text)
            : text.trimmingCharacters(in: .whitespacesAndNewlines)

        fullText = prepared
        chunks = NovaSpeechTextSanitizer.chunks(
            from: prepared,
            maximumCharacters: configuration.maximumSpeechChunkCharacters
        )
        currentChunkIndex = 0
        fullTextOffset = 0

        guard !chunks.isEmpty else {
            delegate?.speakerDidFinish(self)
            return
        }

        speakCurrentChunk()
    }

    func stop(notify: Bool = true) {
        let wasActive = synthesizer.isSpeaking || synthesizer.isPaused || !chunks.isEmpty
        suppressCancelCallback = !notify
        chunks.removeAll()
        currentChunkIndex = 0
        fullTextOffset = 0
        currentText = ""
        fullText = ""

        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        } else {
            suppressCancelCallback = false
            if notify, wasActive { delegate?.speakerDidCancel(self) }
        }
    }

    private func speakCurrentChunk() {
        guard currentChunkIndex < chunks.count else {
            chunks.removeAll()
            currentText = ""
            delegate?.speakerDidFinish(self)
            return
        }

        currentText = chunks[currentChunkIndex]
        let utterance = AVSpeechUtterance(string: currentText)

        if let identifier = configuration.synthesisVoiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(
                language: configuration.synthesisLanguageIdentifier
            )
        }

        utterance.rate = configuration.speechRate
        utterance.pitchMultiplier = configuration.speechPitchMultiplier
        utterance.volume = configuration.speechVolume
        utterance.preUtteranceDelay = currentChunkIndex == 0 ? 0 : 0.04
        synthesizer.speak(utterance)
    }

    // MARK: - AVSpeechSynthesizerDelegate (Non-isolated bridge)

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didStart utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.handleSpeechStart()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.handleSpeechWillSpeak(characterRange: characterRange)
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.handleSpeechFinish()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.handleSpeechCancel()
        }
    }

    // MARK: - MainActor Helpers

    private func handleSpeechStart() {
        if currentChunkIndex == 0 {
            delegate?.speakerDidStart(self)
        }
    }

    private func handleSpeechWillSpeak(characterRange: NSRange) {
        delegate?.speaker(
            self,
            willSpeakCharacterRange: NSRange(
                location: fullTextOffset + characterRange.location,
                length: characterRange.length
            ),
            in: fullText
        )
    }

    private func handleSpeechFinish() {
        fullTextOffset += (currentText as NSString).length + 1
        currentChunkIndex += 1
        speakCurrentChunk()
    }

    private func handleSpeechCancel() {
        let notify = !suppressCancelCallback
        suppressCancelCallback = false
        if notify { delegate?.speakerDidCancel(self) }
    }
}
