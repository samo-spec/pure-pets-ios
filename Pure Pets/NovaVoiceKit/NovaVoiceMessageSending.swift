import Foundation

/// Forward the transcript into the exact same Nova pipeline used by typed chat.
public protocol NovaVoiceMessageSending: AnyObject {
    func sendVoiceTranscript(
        _ transcript: String,
        conversationID: String?
    ) async throws -> String
}

public final class NovaVoiceMessageSenderClosure: NovaVoiceMessageSending {
    public typealias Handler = (
        _ transcript: String,
        _ conversationID: String?
    ) async throws -> String

    private let handler: Handler

    public init(handler: @escaping Handler) {
        self.handler = handler
    }

    public func sendVoiceTranscript(
        _ transcript: String,
        conversationID: String?
    ) async throws -> String {
        try await handler(transcript, conversationID)
    }
}
