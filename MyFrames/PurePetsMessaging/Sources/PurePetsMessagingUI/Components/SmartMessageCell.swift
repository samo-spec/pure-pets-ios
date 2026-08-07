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
  @ScaledMetric(relativeTo: .body) private var incomingAvatarSize = 31
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
        Spacer(minLength: 52)
      } else {
        incomingAvatar
      }

      messageColumn

      if !message.direction.isOutgoing {
        Spacer(minLength: 52)
      }
    }
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
    let size = min(incomingAvatarSize, 39)
    if showsAvatar {
      ZStack {
        Circle()
          .fill(PurePetsMessagingTheme.avatarGradient)

        Circle()
          .strokeBorder(PurePetsMessagingTheme.surfaceRaised.opacity(0.78), lineWidth: 1)

        Text(message.sender.initials)
          .font(Font.ppBeirutiBold(size: 11.5, relativeTo: .caption2))
          .foregroundStyle(PurePetsMessagingTheme.avatarForeground)
      }
      .frame(width: size, height: size)
      .overlay {
        Circle()
          .stroke(PurePetsMessagingTheme.signal.opacity(0.14), lineWidth: 0.75)
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
    .frame(
      maxWidth: .infinity,
      alignment: message.direction.isOutgoing ? .trailing : .leading
    )
  }

  private var interactiveShell: some View {
    ZStack(alignment: replyIndicatorAlignment) {
      replyIndicator
      shell.offset(x: signedReplyOffset)
    }
    .environment(\.layoutDirection, .leftToRight)
  }

  private var shell: some View {
    VStack(
      alignment: message.direction.isOutgoing ? .trailing : .leading,
      spacing: 6
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
        bubbleSurface
      }
    }
    .overlay {
      bubbleOutline
    }
    .ppMessageTerminalElevation(
      showsTerminalElevation,
      isOutgoing: message.direction.isOutgoing
    )
    .scaleEffect(
      isHighlighted && !reduceMotion ? 1.012 : 1,
      anchor: message.direction.isOutgoing ? .trailing : .leading
    )
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
    .animation(reduceMotion ? nil : PurePetsMessagingMotion.standard, value: isHighlighted)
  }

  private var bubbleSurface: some View {
    MessageBubbleShape(
      isOutgoing: message.direction.isOutgoing,
      groupPosition: message.groupPosition
    )
    .fill(
      message.direction.isOutgoing
        ? AnyShapeStyle(PurePetsMessagingTheme.outgoingBubbleGradient)
        : AnyShapeStyle(PurePetsMessagingTheme.incomingBubbleGradient)
    )
    .environment(\.layoutDirection, .leftToRight)
  }

  @ViewBuilder
  private var bubbleOutline: some View {
    if !message.payload.usesTransparentChrome {
      MessageBubbleShape(
        isOutgoing: message.direction.isOutgoing,
        groupPosition: message.groupPosition
      )
      .stroke(
        isHighlighted
          ? PurePetsMessagingTheme.signal.opacity(0.90)
          : (message.direction.isOutgoing
              ? PurePetsMessagingTheme.outgoingBubbleStroke
              : PurePetsMessagingTheme.incomingBubbleStroke),
        lineWidth: isHighlighted ? 1.5 : 0.75
      )
      .environment(\.layoutDirection, .leftToRight)
    } else if isHighlighted {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(PurePetsMessagingTheme.signal.opacity(0.90), lineWidth: 1.5)
    }
  }

  @ViewBuilder
  private var messageBody: some View {
    if case .text(let payload) = message.payload, showsDeliveryMetadata {
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
    ZStack {
      Circle()
        .fill(PurePetsMessagingTheme.brandSoft)

      Circle()
        .stroke(PurePetsMessagingTheme.signal.opacity(0.20), lineWidth: 1)

      Circle()
        .trim(from: 0, to: max(0.035, replyProgress))
        .stroke(
          PurePetsMessagingTheme.signal,
          style: StrokeStyle(lineWidth: 2, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))

      Image(
        systemName: message.direction.isOutgoing
          ? "arrowshape.turn.up.left.fill"
          : "arrowshape.turn.up.right.fill"
      )
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(PurePetsMessagingTheme.signal)
    }
    .frame(width: 38, height: 38)
    .padding(.horizontal, 3)
    .opacity(replyProgress)
    .scaleEffect(0.94 + (replyProgress * 0.06))
    .offset(x: message.direction.isOutgoing ? 3 : -3)
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
      ? min(224, maximumBubbleWidth)
      : maximumBubbleWidth
  }

  private var minimumBubbleSurfaceWidth: CGFloat? {
    guard !message.payload.usesTransparentChrome else { return nil }
    if case .text = message.payload {
      return 58
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

  private var bubbleHorizontalPadding: CGFloat {
    switch message.payload {
    case .image, .video:
      return 5
    case .voice:
      return 9
    case .sticker:
      return 0
    default:
      return 13
    }
  }

  private var bubbleVerticalPadding: CGFloat {
    switch message.payload {
    case .image, .video:
      return 5
    case .voice:
      return 6
    case .sticker:
      return 0
    default:
      return 7
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

  private var showsTerminalElevation: Bool {
    guard !message.payload.usesTransparentChrome else { return false }
    return message.groupPosition == .isolated || message.groupPosition == .last
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
      width: message.direction.isOutgoing ? 10 : -10,
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
    withAnimation(PurePetsMessagingMotion.entrance) {
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

private extension View {
  @ViewBuilder
  func ppMessageTerminalElevation(
    _ isEnabled: Bool,
    isOutgoing: Bool
  ) -> some View {
    if isEnabled {
      shadow(
        color: PurePetsMessagingTheme.messageShadow,
        radius: isOutgoing ? 5 : 4,
        y: 2
      )
    } else {
      self
    }
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
