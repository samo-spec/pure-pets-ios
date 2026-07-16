import AVFoundation
import Foundation
import Speech

public struct NovaVoiceConfiguration {
    public enum OnDeviceRecognitionPolicy: Equatable {
        case automatic
        case prefer
        case require
    }

    public enum OutputRoutePreference: Equatable {
        case systemDefault
        case speaker
    }

    public var recognitionLocaleIdentifier: String
    public var synthesisLanguageIdentifier: String
    public var synthesisVoiceIdentifier: String?
    public var onDeviceRecognitionPolicy: OnDeviceRecognitionPolicy
    public var addsPunctuation: Bool
    public var contextualStrings: [String]
    public var taskHint: SFSpeechRecognitionTaskHint
    public var silenceAutoSubmitInterval: TimeInterval
    public var maximumUtteranceDuration: TimeInterval
    public var finalizationGraceInterval: TimeInterval
    public var automaticRestartDelay: TimeInterval
    public var continuousConversationEnabled: Bool
    public var automaticallyResumeAfterInterruption: Bool
    public var outputRoutePreference: OutputRoutePreference
    public var allowsBluetoothHFP: Bool
    public var prefersEchoCancelledInput: Bool
    public var preferredIOBufferDuration: TimeInterval
    public var speechRate: Float
    public var speechPitchMultiplier: Float
    public var speechVolume: Float
    public var maximumSpeechChunkCharacters: Int
    public var stripsMarkdownBeforeSpeaking: Bool
    public var audioLevelSmoothing: Float
    public var minimumNonEmptyTranscriptLength: Int

    public init(
        recognitionLocaleIdentifier: String = "ar-QA",
        synthesisLanguageIdentifier: String = "ar-QA",
        synthesisVoiceIdentifier: String? = nil,
        onDeviceRecognitionPolicy: OnDeviceRecognitionPolicy = .prefer,
        addsPunctuation: Bool = true,
        contextualStrings: [String] = ["Nova", "نوفا", "Pure Pets", "بيور بيتس"],
        taskHint: SFSpeechRecognitionTaskHint = .dictation,
        silenceAutoSubmitInterval: TimeInterval = 1.15,
        maximumUtteranceDuration: TimeInterval = 45,
        finalizationGraceInterval: TimeInterval = 0.65,
        automaticRestartDelay: TimeInterval = 0.35,
        continuousConversationEnabled: Bool = false,
        automaticallyResumeAfterInterruption: Bool = true,
        outputRoutePreference: OutputRoutePreference = .speaker,
        allowsBluetoothHFP: Bool = true,
        prefersEchoCancelledInput: Bool = true,
        preferredIOBufferDuration: TimeInterval = 0.01,
        speechRate: Float = AVSpeechUtteranceDefaultSpeechRate * 0.92,
        speechPitchMultiplier: Float = 1.0,
        speechVolume: Float = 1.0,
        maximumSpeechChunkCharacters: Int = 280,
        stripsMarkdownBeforeSpeaking: Bool = true,
        audioLevelSmoothing: Float = 0.78,
        minimumNonEmptyTranscriptLength: Int = 1
    ) {
        self.recognitionLocaleIdentifier = recognitionLocaleIdentifier
        self.synthesisLanguageIdentifier = synthesisLanguageIdentifier
        self.synthesisVoiceIdentifier = synthesisVoiceIdentifier
        self.onDeviceRecognitionPolicy = onDeviceRecognitionPolicy
        self.addsPunctuation = addsPunctuation
        self.contextualStrings = contextualStrings
        self.taskHint = taskHint
        self.silenceAutoSubmitInterval = max(0.45, silenceAutoSubmitInterval)
        self.maximumUtteranceDuration = max(3, maximumUtteranceDuration)
        self.finalizationGraceInterval = max(0.15, finalizationGraceInterval)
        self.automaticRestartDelay = max(0, automaticRestartDelay)
        self.continuousConversationEnabled = continuousConversationEnabled
        self.automaticallyResumeAfterInterruption = automaticallyResumeAfterInterruption
        self.outputRoutePreference = outputRoutePreference
        self.allowsBluetoothHFP = allowsBluetoothHFP
        self.prefersEchoCancelledInput = prefersEchoCancelledInput
        self.preferredIOBufferDuration = max(0.005, preferredIOBufferDuration)
        self.speechRate = speechRate
        self.speechPitchMultiplier = min(max(speechPitchMultiplier, 0.5), 2.0)
        self.speechVolume = min(max(speechVolume, 0), 1)
        self.maximumSpeechChunkCharacters = max(80, maximumSpeechChunkCharacters)
        self.stripsMarkdownBeforeSpeaking = stripsMarkdownBeforeSpeaking
        self.audioLevelSmoothing = min(max(audioLevelSmoothing, 0), 0.98)
        self.minimumNonEmptyTranscriptLength = max(1, minimumNonEmptyTranscriptLength)
    }

    public static var arabicMarketplace: NovaVoiceConfiguration {
        NovaVoiceConfiguration(
            contextualStrings: [
                "Nova", "نوفا", "Pure Pets", "بيور بيتس",
                "marketplace", "السوق", "متجر", "منتج"
            ]
        )
    }

    public static var englishMarketplace: NovaVoiceConfiguration {
        NovaVoiceConfiguration(
            recognitionLocaleIdentifier: "en-US",
            synthesisLanguageIdentifier: "en-US",
            contextualStrings: ["Nova", "Pure Pets", "marketplace"]
        )
    }
}
