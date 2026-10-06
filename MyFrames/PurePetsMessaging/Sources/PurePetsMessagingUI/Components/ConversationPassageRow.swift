import SwiftUI

/// A passage on a shared page, rather than a container around every message.
/// Payloads, media actions and delivery truth remain owned by the messaging kit.
public struct ConversationPassageRow: View {
  private let message: ChatMessage
  private let startsPassage: Bool
  private let audioCoordinator: ConversationAudioCoordinator
  private let actions: SmartMessageCell.Actions
  private let animatesEntrance: Bool
  private let isHighlighted: Bool
  private let replyOffset: CGFloat
  private let maximumWidth: CGFloat
  private let contentLayoutDirection: LayoutDirection

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.scenePhase) private var scenePhase
  @State private var hasEntered = false

  public init(
    message: ChatMessage,
    startsPassage: Bool,
    audioCoordinator: ConversationAudioCoordinator,
    actions: SmartMessageCell.Actions,
    animatesEntrance: Bool,
    isHighlighted: Bool,
    replyOffset: CGFloat,
    maximumWidth: CGFloat,
    contentLayoutDirection: LayoutDirection
  ) {
    self.message = message
    self.startsPassage = startsPassage
    self.audioCoordinator = audioCoordinator
    self.actions = actions
    self.animatesEntrance = animatesEntrance
    self.isHighlighted = isHighlighted
    self.replyOffset = max(0, replyOffset)
    self.maximumWidth = max(120, maximumWidth)
    self.contentLayoutDirection = contentLayoutDirection
  }

  public var body: some View {
    HStack(alignment: .top, spacing: 0) {
      if outgoing { Spacer(minLength: laneInset) }
      passage
        .frame(maxWidth: maximumWidth, alignment: outgoing ? .trailing : .leading)
      if !outgoing { Spacer(minLength: laneInset) }
    }
    .frame(maxWidth: .infinity, alignment: outgoing ? .trailing : .leading)
    // Ownership lanes are physical. Each payload has its own reading direction.
    .environment(\.layoutDirection, .leftToRight)
    .opacity(entering ? 0 : 1)
    .offset(y: entering ? (outgoing ? 16 : 8) : 0)
    .scaleEffect(entering && outgoing ? 0.98 : 1, anchor: .bottom)
    .onAppear {
      guard !hasEntered else { return }
      withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.88)) {
        hasEntered = true
      }
    }
    .onChange(of: scenePhase) { phase in
      if phase != .active { hasEntered = true }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(author)
  }

  private var passage: some View {
    VStack(alignment: outgoing ? .trailing : .leading, spacing: 8) {
      if startsPassage {
        HStack(spacing: 6) {
          Rectangle()
            .fill(outgoing ? PurePetsMessagingTheme.signal : Color.secondary)
            .frame(width: outgoing ? 20 : 8, height: 2)
            .accessibilityHidden(true)
          Text(author)
            .font(.ppBeirutiSemiBold(size: 12, relativeTo: .caption))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .environment(\.layoutDirection, contentLayoutDirection)
      }

      if let reference = message.replyReference {
        ReplyReferenceView(reference: reference) { actions.onOpenReply(reference) }
          .environment(\.layoutDirection, contentLayoutDirection)
      }

      payloadContent
      .environment(\.layoutDirection, contentLayoutDirection)
      .fixedSize(horizontal: false, vertical: true)

      if showsMetadata {
        deliveryMetadata
        .environment(\.layoutDirection, contentLayoutDirection)
        .padding(.top, 2)
      }

      MessageReactionsView(reactions: message.reactions, onReactionTap: actions.onReactionTap)
        .environment(\.layoutDirection, contentLayoutDirection)
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 12)
    .background {
      Rectangle()
        .fill(PurePetsMessagingTheme.signal.opacity(isHighlighted ? 0.10 : 0))
        .accessibilityHidden(true)
    }
    .overlay(alignment: outgoing ? .trailing : .leading) {
      Rectangle()
        .fill(isHighlighted ? PurePetsMessagingTheme.signal : Color.secondary.opacity(0.20))
        .frame(width: isHighlighted ? 3 : 1)
        .padding(.vertical, 8)
        .accessibilityHidden(true)
    }
    .overlay(alignment: outgoing ? .trailing : .leading) {
      Image(systemName: outgoing ? "arrowshape.turn.up.left.fill" : "arrowshape.turn.up.right.fill")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(PurePetsMessagingTheme.signal)
        .opacity(min(Double(replyOffset / 56), 1))
        .offset(x: outgoing ? 24 : -24)
        .accessibilityHidden(true)
    }
    .offset(x: reduceMotion ? 0 : (outgoing ? -replyOffset : replyOffset))
    .contentShape(Rectangle())
    .anchorPreference(key: SmartMessageReplyRegionPreferenceKey.self, value: .bounds) {
      [message.id: $0]
    }
    .contextMenu { actionMenu }
    .accessibilityHint(localized("chat_message_actions_hint"))
    .modifier(PassageAccessibilityActions(
      canCopy: message.payload.canCopy, canDelete: actions.canDelete, actions: actions
    ))
    .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isHighlighted)
  }

  @ViewBuilder private var payloadContent: some View {
    if case .voice(let payload) = message.payload {
      VoiceMessageView(messageID: message.id, payload: payload, availableWidth: maximumWidth - 24, audioCoordinator: audioCoordinator)
    } else {
      MessagePayloadView(
        message: message,
        audioCoordinator: audioCoordinator,
        onOpenImage: actions.onOpenImage,
        onOpenVideo: actions.onOpenVideo,
        onUpdateApp: actions.onUpdateApp
      )
    }
  }

  @ViewBuilder private var deliveryMetadata: some View {
    if case .outgoing(.failed) = message.direction {
      Button(action: actions.onRetry) {
        Label(localized("chat_passage_retry"), systemImage: "exclamationmark.arrow.triangle.2.circlepath")
          .font(.ppBeirutiSemiBold(size: 13, relativeTo: .caption))
          .foregroundStyle(PurePetsMessagingTheme.danger)
          .frame(minHeight: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(PurePetsMessagingPressButtonStyle())
    } else {
      DeliveryStatusView(direction: message.direction, timestamp: message.sentAt, isEdited: isEdited, onRetry: actions.onRetry)
    }
  }

  @ViewBuilder private var actionMenu: some View {
    Button(action: actions.onReply) {
      Label(localized("reply"), systemImage: "arrowshape.turn.up.left")
    }
    if message.payload.canCopy {
      Button(action: actions.onCopy) {
        Label(localized("copy"), systemImage: "doc.on.doc")
      }
    }
    if actions.canDelete {
      Button(role: .destructive, action: actions.onDelete) {
        Label(localized("chat_unsend"), systemImage: "trash")
      }
    }
  }

  private var outgoing: Bool { message.direction.isOutgoing }
  private var laneInset: CGFloat { dynamicTypeSize.isAccessibilitySize ? 8 : 32 }
  private var author: String { outgoing ? localized("chat_passage_you") : message.sender.displayName }
  private var entering: Bool { animatesEntrance && !hasEntered && !reduceMotion && scenePhase == .active }
  private var isEdited: Bool {
    if case .text(let payload) = message.payload { return payload.isEdited }
    return false
  }
  private var showsMetadata: Bool {
    if message.groupPosition == .last || message.groupPosition == .isolated { return true }
    guard case .outgoing(let status) = message.direction else { return false }
    switch status {
    case .queued, .uploading, .failed: return true
    case .sent, .delivered, .read: return false
    }
  }
  private func localized(_ key: String) -> String { NSLocalizedString(key, comment: "") }
}

private struct PassageAccessibilityActions: ViewModifier {
  let canCopy: Bool
  let canDelete: Bool
  let actions: SmartMessageCell.Actions

  @ViewBuilder func body(content: Content) -> some View {
    let reply = content.accessibilityAction(named: Text(NSLocalizedString("reply", comment: "")), actions.onReply)
    if canCopy && canDelete {
      reply
        .accessibilityAction(named: Text(NSLocalizedString("copy", comment: "")), actions.onCopy)
        .accessibilityAction(named: Text(NSLocalizedString("chat_unsend", comment: "")), actions.onDelete)
    } else if canCopy {
      reply.accessibilityAction(named: Text(NSLocalizedString("copy", comment: "")), actions.onCopy)
    } else if canDelete {
      reply.accessibilityAction(named: Text(NSLocalizedString("chat_unsend", comment: "")), actions.onDelete)
    } else {
      reply
    }
  }
}
