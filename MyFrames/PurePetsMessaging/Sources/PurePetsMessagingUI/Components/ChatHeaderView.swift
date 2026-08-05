import SwiftUI

public struct ChatHeaderView: View {
  private let presentation: ChatHeaderPresentation
  private let now: Date
  private let onBack: () -> Void
  private let onOpenDetails: () -> Void
  private let onOpenContext: () -> Void
  private let onOpenMore: () -> Void

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  public init(
    presentation: ChatHeaderPresentation,
    now: Date = .now,
    onBack: @escaping () -> Void,
    onOpenDetails: @escaping () -> Void,
    onOpenContext: @escaping () -> Void,
    onOpenMore: @escaping () -> Void
  ) {
    self.presentation = presentation
    self.now = now
    self.onBack = onBack
    self.onOpenDetails = onOpenDetails
    self.onOpenContext = onOpenContext
    self.onOpenMore = onOpenMore
  }

  public var body: some View {
    Group {
      if dynamicTypeSize.isAccessibilitySize {
        accessibilityLayout
      } else {
        compactLayout
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(.bar)
    .overlay(alignment: .bottom) {
      Divider()
    }
  }

  private var compactLayout: some View {
    HStack(spacing: 8) {
      backButton
      identityButton
      Spacer(minLength: 4)
      trailingAction
    }
  }

  private var accessibilityLayout: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        backButton
        identityButton
      }

      trailingAction
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
  }

  private var backButton: some View {
    Button(action: onBack) {
      Image(systemName: "chevron.backward")
        .font(.headline.weight(.semibold))
        .frame(width: 44, height: 44)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Back to conversations")
  }

  private var identityButton: some View {
    Button(action: onOpenDetails) {
      HStack(spacing: 10) {
        ParticipantAvatarView(
          sender: presentation.participant,
          presence: normalizedPresence
        )

        VStack(alignment: .leading, spacing: 2) {
          Text(presentation.participant.displayName)
            .font(Font.ppBeirutiSemiBold(size: 16, relativeTo: .headline))
            .foregroundStyle(.primary)
            .lineLimit(1)

          Text(statusText)
            .font(Font.ppBeirutiRegular(size: 14, relativeTo: .subheadline))
            .foregroundStyle(statusColor)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      "Conversation details for \(presentation.participant.displayName), \(statusText)"
    )
  }

  @ViewBuilder
  private var trailingAction: some View {
    switch presentation.context {
    case .activeOrder(let order):
      Button(action: onOpenContext) {
        Label(orderLabel(order), systemImage: "shippingbox")
          .lineLimit(1)
      }
      .buttonStyle(.bordered)
      .tint(PurePetsMessagingTheme.brand)
      .accessibilityLabel("Open order \(order.orderNumber), \(orderStatusLabel(order.status))")

    case .supportEscalation:
      Button(action: onOpenContext) {
        Label("Support", systemImage: "lifepreserver")
      }
      .buttonStyle(.bordered)
      .tint(PurePetsMessagingTheme.brand)

    case .none:
      Menu {
        Button("Conversation details", action: onOpenDetails)
        Button("Mute conversation", action: onOpenMore)
        Button("Report", role: .destructive, action: onOpenMore)
      } label: {
        Image(systemName: "ellipsis")
          .frame(width: 44, height: 44)
      }
      .accessibilityLabel("More conversation actions")
    }
  }

  private var normalizedPresence: ConversationPresence {
    presentation.presence.normalized(at: now)
  }

  private var statusText: String {
    switch normalizedPresence {
    case .typing:
      "Typing…"
    case .online:
      "Online"
    case .activeRecently(let date):
      "Active \(date.formatted(.relative(presentation: .named)))"
    case .offline:
      presentation.roleLabel ?? "Offline"
    case .unavailable:
      presentation.roleLabel ?? "Customer"
    }
  }

  private var statusColor: Color {
    switch normalizedPresence {
    case .typing, .online:
      PurePetsMessagingTheme.success
    default:
      .secondary
    }
  }

  private func orderLabel(_ order: ActiveOrderContext) -> String {
    "\(orderStatusLabel(order.status)) · #\(order.orderNumber)"
  }

  private func orderStatusLabel(_ status: ActiveOrderContext.Status) -> String {
    switch status {
    case .created: "Created"
    case .preparing: "Preparing"
    case .ready: "Ready"
    case .courierAssigned: "Courier assigned"
    case .onTheWay: "On the way"
    case .delivered: "Delivered"
    case .completed: "Completed"
    case .cancelled: "Cancelled"
    }
  }
}

private struct ParticipantAvatarView: View {
  let sender: MessageSender
  let presence: ConversationPresence

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      Circle()
        .fill(PurePetsMessagingTheme.brandSoft)
        .frame(width: 40, height: 40)
        .overlay {
          Text(sender.initials)
            .font(Font.ppBeirutiBold(size: 12, relativeTo: .caption))
            .foregroundStyle(PurePetsMessagingTheme.brand)
        }

      if isLive {
        Circle()
          .fill(PurePetsMessagingTheme.success)
          .frame(width: 12, height: 12)
          .overlay {
            Circle().stroke(.background, lineWidth: 2)
          }
          .accessibilityHidden(true)
      }
    }
    .accessibilityHidden(true)
  }

  private var isLive: Bool {
    switch presence {
    case .typing, .online:
      true
    default:
      false
    }
  }
}
