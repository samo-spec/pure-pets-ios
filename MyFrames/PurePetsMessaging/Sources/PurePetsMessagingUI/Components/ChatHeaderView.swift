import SwiftUI
import UIKit

public struct ChatHeaderView: View {
  private let presentation: ChatHeaderPresentation
  private let now: Date
  private let onBack: () -> Void
  private let onOpenDetails: () -> Void
  private let onOpenContext: () -> Void
  private let onOpenMore: () -> Void

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.layoutDirection) private var layoutDirection

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
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
    .background(
      Rectangle()
        .fill(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
          Divider()
            .background(PurePetsMessagingTheme.surfaceStroke)
        }
    )
  }

  private var compactLayout: some View {
    HStack(spacing: 10) {
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
    Button {
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      onBack()
    } label: {
      ZStack {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(PurePetsMessagingTheme.surfaceRaised)
          .frame(width: 38, height: 38)
          .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1.5)
          .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .strokeBorder(PurePetsMessagingTheme.surfaceStroke, lineWidth: 0.65)
          }

        Image(systemName: "chevron.backward")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(PurePetsMessagingTheme.brand)
      }
    }
    .buttonStyle(PurePetsMessagingPressButtonStyle())
    .accessibilityLabel(localized("chat_header_back"))
  }

  private var identityButton: some View {
    Button {
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      onOpenDetails()
    } label: {
      HStack(spacing: 10) {
        LivingParticipantAvatarView(
          sender: presentation.participant,
          presence: normalizedPresence
        )

        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 4) {
            Text(presentation.participant.displayName)
              .font(Font.ppBeirutiBold(size: 16, relativeTo: .headline))
              .foregroundStyle(.primary)
              .lineLimit(1)

            Image(systemName: "checkmark.seal.fill")
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(PurePetsMessagingTheme.brand)
          }

          HStack(spacing: 5) {
            if isOnlineOrTyping {
              Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            }

            Text(statusText)
              .font(Font.ppBeirutiRegular(size: 12.5, relativeTo: .subheadline))
              .foregroundStyle(statusColor)
              .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(PurePetsMessagingPressButtonStyle())
    .accessibilityLabel(
      "\(presentation.participant.displayName), \(statusText)"
    )
  }

  @ViewBuilder
  private var trailingAction: some View {
    switch presentation.context {
    case .activeOrder(let order):
      Button {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onOpenContext()
      } label: {
        HStack(spacing: 5) {
          Image(systemName: "shippingbox.fill")
            .font(.system(size: 11, weight: .semibold))
          Text(orderLabel(order))
            .font(Font.ppBeirutiBold(size: 11.5, relativeTo: .caption))
            .lineLimit(1)
        }
        .foregroundStyle(PurePetsMessagingTheme.brand)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(PurePetsMessagingTheme.brandSoft, in: Capsule())
        .overlay {
          Capsule().strokeBorder(PurePetsMessagingTheme.brand.opacity(0.20), lineWidth: 0.75)
        }
      }
      .buttonStyle(PurePetsMessagingPressButtonStyle())
      .accessibilityLabel("Order \(order.orderNumber), \(orderStatusLabel(order.status))")

    case .supportEscalation:
      Button {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onOpenContext()
      } label: {
        HStack(spacing: 5) {
          Image(systemName: "lifepreserver.fill")
            .font(.system(size: 11, weight: .semibold))
          Text(localized("chat_header_support"))
            .font(Font.ppBeirutiBold(size: 11.5, relativeTo: .caption))
        }
        .foregroundStyle(PurePetsMessagingTheme.brand)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(PurePetsMessagingTheme.brandSoft, in: Capsule())
      }
      .buttonStyle(PurePetsMessagingPressButtonStyle())

    case .none:
      Menu {
        Button {
          onOpenDetails()
        } label: {
          Label(localized("chat_header_details"), systemImage: "info.circle")
        }

        Button {
          onOpenMore()
        } label: {
          Label(localized("chat_header_mute"), systemImage: "bell.slash")
        }

        Button(role: .destructive) {
          onOpenMore()
        } label: {
          Label(localized("chat_header_report"), systemImage: "exclamationmark.bubble")
        }
      } label: {
        ZStack {
          Circle()
            .fill(PurePetsMessagingTheme.surfaceRaised)
            .frame(width: 38, height: 38)
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1.5)
            .overlay {
              Circle().strokeBorder(PurePetsMessagingTheme.surfaceStroke, lineWidth: 0.65)
            }

          Image(systemName: "ellipsis")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.secondary)
        }
      }
      .accessibilityLabel(localized("chat_header_actions"))
    }
  }

  private var normalizedPresence: ConversationPresence {
    presentation.presence.normalized(at: now)
  }

  private var isOnlineOrTyping: Bool {
    switch normalizedPresence {
    case .typing, .online: true
    default: false
    }
  }

  private var statusText: String {
    switch normalizedPresence {
    case .typing:
      localized("chat_status_typing")
    case .online:
      localized("chat_status_online")
    case .activeRecently(let date):
      String(format: localized("chat_status_active_recently_format"), date.formatted(.relative(presentation: .named)))
    case .offline:
      presentation.roleLabel ?? localized("chat_status_offline")
    case .unavailable:
      presentation.roleLabel ?? localized("chat_status_unavailable")
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
    case .created: localized("chat_order_created")
    case .preparing: localized("chat_order_preparing")
    case .ready: localized("chat_order_ready")
    case .courierAssigned: localized("chat_order_courier_assigned")
    case .onTheWay: localized("chat_order_on_the_way")
    case .delivered: localized("chat_order_delivered")
    case .completed: localized("chat_order_completed")
    case .cancelled: localized("chat_order_cancelled")
    }
  }

  private func localized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
  }
}

// MARK: - Living Participant Avatar with Breathing Presence Halo

private struct LivingParticipantAvatarView: View {
  let sender: MessageSender
  let presence: ConversationPresence

  @State private var isBreathing = false

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      Circle()
        .fill(PurePetsMessagingTheme.avatarGradient)
        .frame(width: 42, height: 42)
        .overlay {
          Circle().strokeBorder(PurePetsMessagingTheme.surfaceRaised.opacity(0.85), lineWidth: 1)
        }
        .overlay {
          Text(sender.initials)
            .font(Font.ppBeirutiBold(size: 13, relativeTo: .caption))
            .foregroundStyle(PurePetsMessagingTheme.avatarForeground)
        }

      if isLive {
        ZStack {
          // Breathing Halo Ring
          Circle()
            .fill(PurePetsMessagingTheme.success.opacity(isBreathing ? 0.35 : 0.10))
            .frame(width: 18, height: 18)
            .scaleEffect(isBreathing ? 1.4 : 1.0)

          Circle()
            .fill(PurePetsMessagingTheme.success)
            .frame(width: 11, height: 11)
            .overlay {
              Circle().stroke(PurePetsMessagingTheme.surfaceRaised, lineWidth: 2)
            }
        }
        .offset(x: 2, y: 2)
        .accessibilityHidden(true)
        .onAppear {
          withAnimation(
            Animation.easeInOut(duration: 1.4).repeatForever(autoreverses: true)
          ) {
            isBreathing = true
          }
        }
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
