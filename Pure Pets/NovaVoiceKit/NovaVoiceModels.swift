import Foundation

public struct NovaVoiceAuthorization: Equatable {
    public enum Status: String, Equatable {
        case notDetermined
        case denied
        case restricted
        case authorized
    }

    public let microphone: Status
    public let speechRecognition: Status

    public var isFullyAuthorized: Bool {
        microphone == .authorized && speechRecognition == .authorized
    }

    public init(microphone: Status, speechRecognition: Status) {
        self.microphone = microphone
        self.speechRecognition = speechRecognition
    }
}

public enum NovaVoiceState: Equatable {
    case idle
    case requestingPermission
    case preparing
    case listening(partialTranscript: String)
    case finalizing(transcript: String)
    case waitingForNova(transcript: String)
    case speaking(response: String)
    case interrupted
    case failed(NovaVoiceFailure)

    public var name: String {
        switch self {
        case .idle: return "idle"
        case .requestingPermission: return "requestingPermission"
        case .preparing: return "preparing"
        case .listening: return "listening"
        case .finalizing: return "finalizing"
        case .waitingForNova: return "waitingForNova"
        case .speaking: return "speaking"
        case .interrupted: return "interrupted"
        case .failed: return "failed"
        }
    }
}

public struct NovaVoiceFailure: Error, Equatable, LocalizedError {
    public enum Code: String, Equatable {
        case microphonePermissionDenied
        case speechPermissionDenied
        case recognizerUnavailable
        case localeUnsupported
        case audioSessionFailure
        case audioEngineFailure
        case recognitionFailure
        case emptyTranscript
        case novaRequestFailure
        case emptyNovaResponse
        case interrupted
        case cancelled
    }

    public let code: Code
    public let message: String
    public let underlyingDescription: String?

    public init(code: Code, message: String, underlyingDescription: String? = nil) {
        self.code = code
        self.message = message
        self.underlyingDescription = underlyingDescription
    }

    public var errorDescription: String? {
        if let underlyingDescription, !underlyingDescription.isEmpty {
            return "\(message) (\(underlyingDescription))"
        }
        return message
    }
}

public struct NovaVoiceMetric: Equatable {
    public enum Name: String {
        case permissionRequest
        case listeningDuration
        case finalizationLatency
        case novaResponseLatency
        case speechDuration
        case completeTurnDuration
    }

    public let name: Name
    public let milliseconds: Double
    public let metadata: [String: String]

    public init(
        name: Name,
        milliseconds: Double,
        metadata: [String: String] = [:]
    ) {
        self.name = name
        self.milliseconds = milliseconds
        self.metadata = metadata
    }
}

public struct NovaVoiceRouteInfo: Equatable {
    public let inputNames: [String]
    public let outputNames: [String]
}
