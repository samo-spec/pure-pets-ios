import Foundation

// MARK: - Stable identity

public struct PPConversationID: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }

    public var description: String { rawValue }
}

// MARK: - Conversation data

public enum PPChatPresence: Hashable, Sendable {
    case online
    case away
    case offline(lastSeen: Date?)
}

public enum PPChatLastActivity: Hashable, Sendable {
    case text(sender: String?, text: String)
    case typing
    case photo(sender: String?)
    case video(sender: String?)
    case voice(sender: String?, duration: TimeInterval?)
    case deleted
    case none

    public var sender: String? {
        switch self {
        case let .text(sender, _), let .photo(sender), let .video(sender), let .voice(sender, _):
            return sender
        case .typing, .deleted, .none:
            return nil
        }
    }

    public var textValue: String? {
        guard case let .text(_, text) = self else { return nil }
        return text
    }
}

public struct PPQuickReply: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let message: String

    public init(id: String, title: String, message: String) {
        let normalizedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = normalizedID.isEmpty
            ? Self.deterministicFallbackID(title: title, message: message)
            : normalizedID
        self.title = title
        self.message = message
    }

    private static func deterministicFallbackID(title: String, message: String) -> String {
        let raw = "fallback|\(title)|\(message)"
        return raw.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? raw
    }
}

public struct PPChatThreadSnapshot: Identifiable, Hashable, Sendable {
    public let id: PPConversationID
    public let participantID: String
    public var displayName: String
    public var avatarURL: URL?
    public var initials: String
    public var isVerified: Bool
    public var presence: PPChatPresence
    public var lastActivity: PPChatLastActivity
    public var timestamp: Date
    public private(set) var unreadCount: Int
    public var contextText: String?
    public var quickReplies: [PPQuickReply]

    public init(
        id: PPConversationID,
        participantID: String,
        displayName: String,
        avatarURL: URL? = nil,
        initials: String? = nil,
        isVerified: Bool = false,
        presence: PPChatPresence,
        lastActivity: PPChatLastActivity,
        timestamp: Date,
        unreadCount: Int = 0,
        contextText: String? = nil,
        quickReplies: [PPQuickReply] = []
    ) {
        self.id = id
        self.participantID = participantID
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.initials = initials ?? Self.makeInitials(from: displayName)
        self.isVerified = isVerified
        self.presence = presence
        self.lastActivity = lastActivity
        self.timestamp = timestamp
        self.unreadCount = max(0, unreadCount)
        self.contextText = contextText
        self.quickReplies = quickReplies
    }

    public mutating func setUnreadCount(_ count: Int) {
        unreadCount = max(0, count)
    }

    private static func makeInitials(from name: String) -> String {
        let characters = name
            .split(whereSeparator: \ .isWhitespace)
            .prefix(2)
            .compactMap(\.first)
        let value = String(characters)
        return value.isEmpty ? "?" : value.uppercased()
    }
}

// MARK: - Quick-reply state machine

public enum PPQuickReplyFailure: Error, Hashable, Sendable {
    case offline
    case permissionDenied
    case conversationClosed
    case rateLimited
    case server
    case unknown
}

public struct PPQuickReplyReceipt: Hashable, Sendable {
    public let messageID: String
    public let conversationID: PPConversationID
    public let message: String
    public let sentAt: Date

    public init(
        messageID: String,
        conversationID: PPConversationID,
        message: String,
        sentAt: Date
    ) {
        self.messageID = messageID
        self.conversationID = conversationID
        self.message = message
        self.sentAt = sentAt
    }
}

public enum PPQuickReplyPhase: Equatable, Sendable {
    case idle
    case sending(message: String)
    case sent(receipt: PPQuickReplyReceipt)
    case failed(message: String, failure: PPQuickReplyFailure)

    public var isSending: Bool {
        if case .sending = self { return true }
        return false
    }
}

public struct PPQuickReplyStateMachine: Equatable, Sendable {
    public var draft: String
    public private(set) var phase: PPQuickReplyPhase
    public private(set) var optimisticMessage: String?

    public init(
        draft: String = "",
        phase: PPQuickReplyPhase = .idle,
        optimisticMessage: String? = nil
    ) {
        self.draft = draft
        self.phase = phase
        self.optimisticMessage = optimisticMessage
    }

    @discardableResult
    public mutating func beginSend() -> String? {
        guard !phase.isSending else { return nil }

        let message = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return nil }

        draft = message
        optimisticMessage = message
        phase = .sending(message: message)
        return message
    }

    public mutating func succeed(with receipt: PPQuickReplyReceipt) {
        draft = ""
        optimisticMessage = receipt.message
        phase = .sent(receipt: receipt)
    }

    public mutating func fail(_ failure: PPQuickReplyFailure) {
        guard case let .sending(message) = phase else { return }
        draft = message
        optimisticMessage = nil
        phase = .failed(message: message, failure: failure)
    }

    public mutating func resetFeedback() {
        switch phase {
        case .sent, .failed:
            phase = .idle
        case .idle, .sending:
            break
        }
    }

    public mutating func selectQuickReply(_ reply: PPQuickReply) {
        guard !phase.isSending else { return }
        draft = reply.message
        switch phase {
        case .sent, .failed:
            phase = .idle
        case .idle, .sending:
            break
        }
    }
}
