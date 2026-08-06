import Foundation
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
    public var canDelete: Bool
    public var canForward: Bool

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
      onUpdateApp: @escaping () -> Void = {},
      canDelete: Bool = false,
      canForward: Bool = true
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
      self.canDelete = canDelete
      self.canForward = canForward
    }
  }

  private let message: ChatMessage
  private let showsAvatar: Bool
  private let audioCoordinator: ConversationAudioCoordinator
  private let actions: Actions
  private let animatesEntrance: Bool
  private let isHighlighted: Bool
  private let replyOffset: CGFloat
  private let maximumBubbleWidth: CGFloat
  private let contentLayoutDirection: LayoutDirection

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme
  @ScaledMetric(relativeTo: .body) private var incomingAvatarSize = 30
  @State private var hasEntered = false

  public init(
    message: ChatMessage,
    showsAvatar: Bool = true,
    audioCoordinator: ConversationAudioCoordinator,
    actions: Actions = Actions(),
    animatesEntrance: Bool = false,
    isHighlighted: Bool = false,
    replyOffset: CGFloat = 0,
    maximumBubbleWidth: CGFloat = 310,
    contentLayoutDirection: LayoutDirection = .leftToRight
  ) {
    self.message = message
    self.showsAvatar = showsAvatar
    self.audioCoordinator = audioCoordinator
    self.actions = actions
    self.animatesEntrance = animatesEntrance
    self.isHighlighted = isHighlighted
    self.replyOffset = max(0, replyOffset)
    self.maximumBubbleWidth = max(190, maximumBubbleWidth)
    self.contentLayoutDirection = contentLayoutDirection
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
    // LazyVStack proposes the transcript width, but an HStack is otherwise
    // free to collapse around short content. Claiming the proposal here keeps
    // the physical sender lanes pinned to the screen edges in every locale.
    .frame(maxWidth: .infinity)
    .environment(\.layoutDirection, .leftToRight)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(message.sender.displayName)
    .opacity(entranceOpacity)
    .offset(x: entranceOffset.width, y: entranceOffset.height)
    .scaleEffect(
      entranceScale,
      anchor: message.direction.isOutgoing ? .bottomTrailing : .bottomLeading
    )
    .onAppear(perform: performEntranceIfNeeded)
  }

  @ViewBuilder
  private var incomingAvatar: some View {
    let size = min(incomingAvatarSize, 38)
    if showsAvatar {
      Circle()
        .fill(PurePetsMessagingTheme.avatarSurface)
        .frame(width: size, height: size)
        .overlay {
          Text(message.sender.initials)
            .font(Font.ppBeirutiBold(size: 11, relativeTo: .caption2))
            .foregroundStyle(PurePetsMessagingTheme.avatarForeground)
        }
        .accessibilityHidden(true)
    } else {
      Color.clear
        .frame(width: size, height: 1)
    }
  }

  private var messageColumn: some View {
    VStack(alignment: message.direction.isOutgoing ? .trailing : .leading, spacing: 4) {
      interactiveShell

      MessageReactionsView(
        reactions: message.reactions,
        onReactionTap: actions.onReactionTap
      )
      .environment(\.layoutDirection, contentLayoutDirection)
    }
    .environment(\.layoutDirection, .leftToRight)
    .frame(maxWidth: .infinity, alignment: message.direction.isOutgoing ? .trailing : .leading)
  }

  private var interactiveShell: some View {
    ZStack(alignment: replyIndicatorAlignment) {
      replyIndicator

      shell
        .offset(x: signedReplyOffset)
    }
    .environment(\.layoutDirection, .leftToRight)
  }

  private var shell: some View {
    VStack(
      alignment: message.direction.isOutgoing ? .trailing : .leading,
      spacing: 7
    ) {
      if let replyReference = message.replyReference {
        ReplyReferenceView(reference: replyReference) {
          actions.onOpenReply(replyReference)
        }
        .environment(\.layoutDirection, contentLayoutDirection)
      }

      messageBody
    }
    .padding(.horizontal, bubbleHorizontalPadding)
    .padding(.vertical, bubbleVerticalPadding)
    .frame(
      minWidth: minimumBubbleSurfaceWidth,
      alignment: message.direction.isOutgoing ? .trailing : .leading
    )
    .background {
      if !message.payload.usesTransparentChrome {
        ZStack {
          MessageBubbleShape(
            isOutgoing: message.direction.isOutgoing,
            groupPosition: message.groupPosition
          )
          .fill(
            message.direction.isOutgoing
              ? PurePetsMessagingTheme.outgoingBubbleSurface
              : PurePetsMessagingTheme.incomingSurface
          )

          MessageBubbleShape(
            isOutgoing: message.direction.isOutgoing,
            groupPosition: message.groupPosition
          )
          .fill(
            LinearGradient(
              colors: [bubbleSpecularHighlight, .clear],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
        }
        .environment(\.layoutDirection, .leftToRight)
      }
    }
    .overlay {
      if !message.payload.usesTransparentChrome {
        MessageBubbleShape(
          isOutgoing: message.direction.isOutgoing,
          groupPosition: message.groupPosition
        )
        .stroke(
          isHighlighted
            ? PurePetsMessagingTheme.signal.opacity(0.78)
            : (message.direction.isOutgoing
                ? PurePetsMessagingTheme.outgoingBubbleStroke
                : PurePetsMessagingTheme.incomingBubbleStroke),
          lineWidth: isHighlighted ? 1.5 : 0.7
        )
        .environment(\.layoutDirection, .leftToRight)
      } else if isHighlighted {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(PurePetsMessagingTheme.signal.opacity(0.78), lineWidth: 1.5)
      }
    }
    // Own interaction before adding the invisible width cap used for sender
    // alignment. Blank transcript space cannot open a menu or start a reply.
    .contentShape(Rectangle())
    .anchorPreference(
      key: SmartMessageReplyRegionPreferenceKey.self,
      value: .bounds
    ) { anchor in
      [message.id: anchor]
    }
    .contextMenu {
      actionMenu
    }
    .accessibilityHint(localized("chat_message_actions_hint"))
    .accessibilityAction(named: localized("reply")) {
      actions.onReply()
    }
    .accessibilityActions {
      if message.payload.canCopy {
        Button(localized("copy"), action: actions.onCopy)
      }
      if message.payload.canForward && actions.canForward {
        Button(localized("chat_forward"), action: actions.onForward)
      }
      if actions.canDelete {
        Button(localized("chat_unsend"), role: .destructive, action: actions.onDelete)
      }
    }
    .frame(
      maxWidth: maximumMessageWidth,
      alignment: message.direction.isOutgoing ? .trailing : .leading
    )
    .environment(
      \.colorScheme,
      message.direction.isOutgoing ? .dark : colorScheme
    )
    .environment(\.layoutDirection, .leftToRight)
    .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: isHighlighted)
  }

  @ViewBuilder
  private var messageBody: some View {
    if case .text(let payload) = message.payload, showsDeliveryMetadata {
      // Short text and its timestamp belong to one reading line. Long text
      // naturally falls back to the stacked composition instead of being
      // squeezed or truncated to preserve the compact bubble.
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
          TextMessageView(payload: payload)
            .fixedSize(horizontal: true, vertical: false)

          deliveryMetadata
            .fixedSize(horizontal: true, vertical: true)
        }
        .environment(\.layoutDirection, resolvedPayloadDirection)

        VStack(alignment: .leading, spacing: 5) {
          TextMessageView(payload: payload)

          deliveryMetadata
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .environment(\.layoutDirection, resolvedPayloadDirection)
      }
    } else {
      MessagePayloadView(
        message: message,
        audioCoordinator: audioCoordinator,
        onOpenImage: actions.onOpenImage,
        onOpenVideo: actions.onOpenVideo,
        onUpdateApp: actions.onUpdateApp
      )
      .environment(\.layoutDirection, contentLayoutDirection)

      if showsDeliveryMetadata {
        deliveryMetadata
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
    }
  }

  private var deliveryMetadata: some View {
    DeliveryStatusView(
      direction: message.direction,
      timestamp: message.sentAt,
      isEdited: isEdited,
      onRetry: actions.onRetry
    )
    .environment(\.layoutDirection, resolvedPayloadDirection)
  }

  private var replyIndicator: some View {
    Image(
      systemName: message.direction.isOutgoing
        ? "arrowshape.turn.up.left.fill"
        : "arrowshape.turn.up.right.fill"
    )
      .font(.system(size: 14, weight: .semibold))
      .foregroundStyle(PurePetsMessagingTheme.signal)
      .frame(width: 36, height: 36)
      .background(
        Circle()
          .fill(PurePetsMessagingTheme.brandSoft)
      )
      .overlay {
        Circle()
          .stroke(PurePetsMessagingTheme.signal.opacity(0.32), lineWidth: 0.7)
      }
      .padding(.horizontal, 7)
      .opacity(replyProgress)
      .scaleEffect(0.78 + (replyProgress * 0.22))
      .allowsHitTesting(false)
      .accessibilityHidden(true)
  }

  @ViewBuilder
  private var actionMenu: some View {
    Button {
      actions.onReply()
    } label: {
      Label(localized("reply"), systemImage: "arrowshape.turn.up.left")
    }

    if message.payload.canCopy {
      Button {
        actions.onCopy()
      } label: {
        Label(localized("copy"), systemImage: "doc.on.doc")
      }
    }

    if message.payload.canForward && actions.canForward {
      Button {
        actions.onForward()
      } label: {
        Label(localized("chat_forward"), systemImage: "arrowshape.turn.up.right")
      }
    }

    if actions.canDelete {
      Button(role: .destructive) {
        actions.onDelete()
      } label: {
        Label(localized("chat_unsend"), systemImage: "trash")
      }
    }
  }

  private var isEdited: Bool {
    if case .text(let payload) = message.payload {
      return payload.isEdited
    }
    return false
  }

  private var maximumMessageWidth: CGFloat {
    message.payload.usesTransparentChrome
      ? min(220, maximumBubbleWidth)
      : maximumBubbleWidth
  }

  private var minimumBubbleSurfaceWidth: CGFloat? {
    guard !message.payload.usesTransparentChrome else { return nil }
    if case .text = message.payload {
      return 56
    }
    return nil
  }

  private var resolvedPayloadDirection: LayoutDirection {
    guard case .text(let payload) = message.payload else {
      return contentLayoutDirection
    }
    return PurePetsMessageTextDirection.resolve(
      payload.text,
      fallback: contentLayoutDirection
    )
  }

  private var bubbleSpecularHighlight: Color {
    if message.direction.isOutgoing {
      return Color.white.opacity(colorScheme == .dark ? 0.055 : 0.085)
    }
    return Color.white.opacity(colorScheme == .dark ? 0.035 : 0.26)
  }

  private var bubbleHorizontalPadding: CGFloat {
    switch message.payload {
    case .image, .video:
      return 5
    case .voice:
      return 10
    case .sticker:
      return 0
    default:
      return 12
    }
  }

  private var bubbleVerticalPadding: CGFloat {
    switch message.payload {
    case .image, .video:
      return 5
    case .voice:
      return 8
    case .sticker:
      return 0
    default:
      return 9
    }
  }

  private var replyIndicatorAlignment: Alignment {
    message.direction.isOutgoing ? .trailing : .leading
  }

  private var signedReplyOffset: CGFloat {
    message.direction.isOutgoing ? -replyOffset : replyOffset
  }

  private var replyProgress: CGFloat {
    min(max(replyOffset / ReplyGestureMetrics.threshold, 0), 1)
  }

  private var showsDeliveryMetadata: Bool {
    switch message.groupPosition {
    case .isolated, .last:
      return true
    case .first, .middle:
      guard case .outgoing(let state) = message.direction else { return false }
      switch state {
      case .queued, .uploading, .failed:
        return true
      case .sent, .delivered, .read:
        return false
      }
    }
  }

  private var entranceOpacity: Double {
    animatesEntrance && !hasEntered && !reduceMotion ? 0 : 1
  }

  private var entranceOffset: CGSize {
    guard animatesEntrance, !hasEntered, !reduceMotion else { return .zero }
    return CGSize(
      width: message.direction.isOutgoing ? 8 : -8,
      height: 5
    )
  }

  private var entranceScale: CGFloat {
    animatesEntrance && !hasEntered && !reduceMotion ? 0.985 : 1
  }

  private func performEntranceIfNeeded() {
    guard animatesEntrance, !hasEntered else {
      hasEntered = true
      return
    }
    guard !reduceMotion else {
      hasEntered = true
      return
    }
    withAnimation(.timingCurve(0.2, 0, 0, 1, duration: 0.24)) {
      hasEntered = true
    }
  }

  private func localized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
  }

  private enum ReplyGestureMetrics {
    static let threshold: CGFloat = 56
  }
}

public struct SmartMessageReplyRegionPreferenceKey: PreferenceKey {
  public static var defaultValue: [MessageID: Anchor<CGRect>] { [:] }

  public static func reduce(
    value: inout [MessageID: Anchor<CGRect>],
    nextValue: () -> [MessageID: Anchor<CGRect>]
  ) {
    value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
  }
}
