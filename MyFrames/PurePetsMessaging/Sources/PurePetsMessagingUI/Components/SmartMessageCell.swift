import SwiftUI

public struct SmartMessageCell: View {
  public struct Actions {
    public var onReply: () -> Void
    public var onCopy: () -> Void
    public var onForward: () -> Void
    public var onDelete: () -> Void
    public var onRetry: () -> Void
    public var onOpenReply: (ReplyReference) -> Void
    public var onOpenImage: (ImagePayload) -> Void
    public var onOpenVideo: (VideoPayload) -> Void
    public var onReactionTap: (MessageReaction) -> Void
    public var onUpdateApp: () -> Void

    public init(
      onReply: @escaping () -> Void = {},
      onCopy: @escaping () -> Void = {},
      onForward: @escaping () -> Void = {},
      onDelete: @escaping () -> Void = {},
      onRetry: @escaping () -> Void = {},
      onOpenReply: @escaping (ReplyReference) -> Void = { _ in },
      onOpenImage: @escaping (ImagePayload) -> Void = { _ in },
      onOpenVideo: @escaping (VideoPayload) -> Void = { _ in },
      onReactionTap: @escaping (MessageReaction) -> Void = { _ in },
      onUpdateApp: @escaping () -> Void = {}
    ) {
      self.onReply = onReply
      self.onCopy = onCopy
      self.onForward = onForward
      self.onDelete = onDelete
      self.onRetry = onRetry
      self.onOpenReply = onOpenReply
      self.onOpenImage = onOpenImage
      self.onOpenVideo = onOpenVideo
      self.onReactionTap = onReactionTap
      self.onUpdateApp = onUpdateApp
    }
  }

  private let message: ChatMessage
  private let showsAvatar: Bool
  private let audioCoordinator: ConversationAudioCoordinator
  private let actions: Actions

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  public init(
    message: ChatMessage,
    showsAvatar: Bool = true,
    audioCoordinator: ConversationAudioCoordinator,
    actions: Actions = Actions()
  ) {
    self.message = message
    self.showsAvatar = showsAvatar
    self.audioCoordinator = audioCoordinator
    self.actions = actions
  }

  public var body: some View {
    HStack(alignment: .bottom, spacing: 8) {
      if message.direction.isOutgoing {
        Spacer(minLength: 54)
      } else {
        incomingAvatar
      }

      messageColumn

      if !message.direction.isOutgoing {
        Spacer(minLength: 54)
      }
    }
    .animation(
      reduceMotion ? .easeOut(duration: 0.16) : .snappy(duration: 0.24), value: message.direction
    )
    .contextMenu {
      actionMenu
    }
    .accessibilityAction(named: "Reply") {
      actions.onReply()
    }
    .accessibilityActions {
      if message.payload.canCopy {
        Button("Copy", action: actions.onCopy)
      }
      if message.payload.canForward {
        Button("Forward", action: actions.onForward)
      }
      Button("Delete", role: .destructive, action: actions.onDelete)
    }
  }

  @ViewBuilder
  private var incomingAvatar: some View {
    if showsAvatar {
      Circle()
        .fill(PurePetsMessagingTheme.brandSoft)
        .frame(width: 30, height: 30)
        .overlay {
          Text(message.sender.initials)
            .font(.caption2.weight(.bold))
            .foregroundStyle(PurePetsMessagingTheme.brand)
        }
        .accessibilityHidden(true)
    } else {
      Color.clear
        .frame(width: 30, height: 1)
    }
  }

  private var messageColumn: some View {
    VStack(alignment: message.direction.isOutgoing ? .trailing : .leading, spacing: 4) {
      shell

      MessageReactionsView(
        reactions: message.reactions,
        onReactionTap: actions.onReactionTap
      )
    }
    .frame(maxWidth: .infinity, alignment: message.direction.isOutgoing ? .trailing : .leading)
  }

  private var shell: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let replyReference = message.replyReference {
        ReplyReferenceView(reference: replyReference) {
          actions.onOpenReply(replyReference)
        }
      }

      MessagePayloadView(
        message: message,
        audioCoordinator: audioCoordinator,
        onOpenImage: actions.onOpenImage,
        onOpenVideo: actions.onOpenVideo,
        onUpdateApp: actions.onUpdateApp
      )

      DeliveryStatusView(
        direction: message.direction,
        timestamp: message.sentAt,
        isEdited: isEdited,
        onRetry: actions.onRetry
      )
      .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding(message.payload.usesTransparentChrome ? 0 : 10)
    .background {
      if !message.payload.usesTransparentChrome {
        MessageBubbleShape(
          isOutgoing: message.direction.isOutgoing,
          groupPosition: message.groupPosition
        )
        .fill(
          message.direction.isOutgoing
            ? PurePetsMessagingTheme.brandSoft
            : PurePetsMessagingTheme.incomingSurface
        )
      }
    }
    .overlay {
      if !message.payload.usesTransparentChrome {
        MessageBubbleShape(
          isOutgoing: message.direction.isOutgoing,
          groupPosition: message.groupPosition
        )
        .stroke(.separator.opacity(0.35), lineWidth: 0.5)
      }
    }
    .frame(maxWidth: maximumMessageWidth, alignment: .leading)
  }

  @ViewBuilder
  private var actionMenu: some View {
    Button {
      actions.onReply()
    } label: {
      Label("Reply", systemImage: "arrowshape.turn.up.left")
    }

    if message.payload.canCopy {
      Button {
        actions.onCopy()
      } label: {
        Label("Copy", systemImage: "doc.on.doc")
      }
    }

    if message.payload.canForward {
      Button {
        actions.onForward()
      } label: {
        Label("Forward", systemImage: "arrowshape.turn.up.right")
      }
    }

    Button(role: .destructive) {
      actions.onDelete()
    } label: {
      Label("Delete", systemImage: "trash")
    }
  }

  private var isEdited: Bool {
    if case .text(let payload) = message.payload {
      return payload.isEdited
    }
    return false
  }

  private var maximumMessageWidth: CGFloat {
    message.payload.usesTransparentChrome ? 190 : 310
  }
}
