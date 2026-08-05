import Foundation

public struct MessageID: Hashable, Codable, Sendable, Identifiable, CustomStringConvertible {
  public let rawValue: UUID

  public init(_ rawValue: UUID = UUID()) {
    self.rawValue = rawValue
  }

  public var id: UUID { rawValue }
  public var description: String { rawValue.uuidString }
}

public struct NonEmptyText: Hashable, Codable, Sendable, CustomStringConvertible {
  public enum ValidationError: Error, Equatable {
    case empty
  }

  public let value: String

  public init(_ rawValue: String) throws {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw ValidationError.empty
    }
    value = trimmed
  }

  public var description: String { value }
}

public struct MessageSender: Hashable, Codable, Sendable, Identifiable {
  public let id: UUID
  public let displayName: String
  public let avatarURL: URL?
  public let initials: String

  public init(
    id: UUID = UUID(),
    displayName: String,
    avatarURL: URL? = nil,
    initials: String
  ) {
    self.id = id
    self.displayName = displayName
    self.avatarURL = avatarURL
    self.initials = initials
  }
}

public enum MessageSendFailure: Hashable, Codable, Sendable {
  case offline
  case rejected
  case attachmentExpired
  case unknown(code: String?)
}

public enum OutgoingDeliveryState: Hashable, Codable, Sendable {
  case queued
  case uploading(progress: Double)
  case sent
  case delivered
  case read(at: Date?)
  case failed(MessageSendFailure)

  public var normalizedProgress: Double? {
    guard case .uploading(let progress) = self else {
      return nil
    }
    return min(max(progress, 0), 1)
  }
}

public enum MessageDirection: Hashable, Codable, Sendable {
  case incoming(receivedAt: Date?)
  case outgoing(OutgoingDeliveryState)

  public var isOutgoing: Bool {
    if case .outgoing = self {
      return true
    }
    return false
  }
}

public struct MediaDimensions: Hashable, Codable, Sendable {
  public let width: Double
  public let height: Double

  public init(width: Double, height: Double) {
    self.width = max(width, 1)
    self.height = max(height, 1)
  }

  public var aspectRatio: Double { width / height }
}

public struct TextPayload: Hashable, Codable, Sendable {
  public let text: String
  public let isEdited: Bool

  public init(text: String, isEdited: Bool = false) {
    self.text = text
    self.isEdited = isEdited
  }
}

public struct VoicePayload: Hashable, Codable, Sendable {
  public let audioURL: URL?
  public let duration: TimeInterval
  public let waveform: [Double]
  public let transcript: String?

  public init(
    audioURL: URL? = nil,
    duration: TimeInterval,
    waveform: [Double],
    transcript: String? = nil
  ) {
    self.audioURL = audioURL
    self.duration = max(duration, 0)
    self.waveform = waveform.map { min(max($0, 0.08), 1) }
    self.transcript = transcript
  }
}

public struct ImagePayload: Hashable, Codable, Sendable {
  public let imageURL: URL?
  public let thumbnailURL: URL?
  public let dimensions: MediaDimensions
  public let accessibilityDescription: String

  public init(
    imageURL: URL? = nil,
    thumbnailURL: URL? = nil,
    dimensions: MediaDimensions,
    accessibilityDescription: String
  ) {
    self.imageURL = imageURL
    self.thumbnailURL = thumbnailURL
    self.dimensions = dimensions
    self.accessibilityDescription = accessibilityDescription
  }
}

public struct VideoPayload: Hashable, Codable, Sendable {
  public let videoURL: URL?
  public let thumbnailURL: URL?
  public let duration: TimeInterval
  public let dimensions: MediaDimensions
  public let accessibilityDescription: String

  public init(
    videoURL: URL? = nil,
    thumbnailURL: URL? = nil,
    duration: TimeInterval,
    dimensions: MediaDimensions,
    accessibilityDescription: String
  ) {
    self.videoURL = videoURL
    self.thumbnailURL = thumbnailURL
    self.duration = max(duration, 0)
    self.dimensions = dimensions
    self.accessibilityDescription = accessibilityDescription
  }
}

public struct StickerPayload: Hashable, Codable, Sendable {
  public let assetURL: URL?
  public let fallbackEmoji: String
  public let accessibilityDescription: NonEmptyText
  public let isAnimated: Bool

  public init(
    assetURL: URL? = nil,
    fallbackEmoji: String,
    accessibilityDescription: NonEmptyText,
    isAnimated: Bool = false
  ) {
    self.assetURL = assetURL
    self.fallbackEmoji = fallbackEmoji
    self.accessibilityDescription = accessibilityDescription
    self.isAnimated = isAnimated
  }
}

public enum MessageDeletionActor: Hashable, Codable, Sendable {
  case sender
  case recipient
  case moderator
  case system
}

public struct DeletedPayload: Hashable, Codable, Sendable {
  public let deletedBy: MessageDeletionActor

  public init(deletedBy: MessageDeletionActor) {
    self.deletedBy = deletedBy
  }
}

public struct UnsupportedPayload: Hashable, Codable, Sendable {
  public let typeIdentifier: String
  public let schemaVersion: Int?

  public init(typeIdentifier: String, schemaVersion: Int? = nil) {
    self.typeIdentifier = typeIdentifier
    self.schemaVersion = schemaVersion
  }
}

public enum MessagePayload: Hashable, Codable, Sendable {
  case text(TextPayload)
  case voice(VoicePayload)
  case image(ImagePayload)
  case video(VideoPayload)
  case sticker(StickerPayload)
  case deleted(DeletedPayload)
  case unsupported(UnsupportedPayload)

  public var usesTransparentChrome: Bool {
    if case .sticker = self {
      return true
    }
    return false
  }

  public var canCopy: Bool {
    if case .text = self {
      return true
    }
    return false
  }

  public var canForward: Bool {
    switch self {
    case .deleted, .unsupported:
      false
    default:
      true
    }
  }
}

public enum ReplyPreview: Hashable, Codable, Sendable {
  case text(String)
  case voice
  case image
  case video
  case sticker(description: String)
  case deleted
  case unsupported
}

public struct ReplyReference: Hashable, Codable, Sendable {
  public let messageID: MessageID
  public let senderDisplayName: String
  public let preview: ReplyPreview

  public init(
    messageID: MessageID,
    senderDisplayName: String,
    preview: ReplyPreview
  ) {
    self.messageID = messageID
    self.senderDisplayName = senderDisplayName
    self.preview = preview
  }
}

public struct MessageReaction: Hashable, Codable, Sendable, Identifiable {
  public let emoji: String
  public let count: Int
  public let reactedByCurrentUser: Bool

  public init(emoji: String, count: Int, reactedByCurrentUser: Bool = false) {
    self.emoji = emoji
    self.count = max(count, 1)
    self.reactedByCurrentUser = reactedByCurrentUser
  }

  public var id: String { emoji }
}

public enum MessageGroupPosition: Hashable, Codable, Sendable {
  case isolated
  case first
  case middle
  case last
}

public struct ChatMessage: Hashable, Codable, Sendable, Identifiable {
  public let id: MessageID
  public let sender: MessageSender
  public let direction: MessageDirection
  public let payload: MessagePayload
  public let replyReference: ReplyReference?
  public let reactions: [MessageReaction]
  public let sentAt: Date
  public let groupPosition: MessageGroupPosition

  public init(
    id: MessageID = MessageID(),
    sender: MessageSender,
    direction: MessageDirection,
    payload: MessagePayload,
    replyReference: ReplyReference? = nil,
    reactions: [MessageReaction] = [],
    sentAt: Date,
    groupPosition: MessageGroupPosition = .isolated
  ) {
    self.id = id
    self.sender = sender
    self.direction = direction
    self.payload = payload
    self.replyReference = replyReference
    self.reactions = reactions
    self.sentAt = sentAt
    self.groupPosition = groupPosition
  }
}
