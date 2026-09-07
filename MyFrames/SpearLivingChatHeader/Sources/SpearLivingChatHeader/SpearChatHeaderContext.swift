import SwiftUI

// MARK: - Conversation Context

/// One semantic row and one action. The entire row opens the host-owned
/// destination; a hidden action retains context without a disclosure affordance.
@available(iOS 15.0, *)
internal struct SpearContextRail: View {
  let context: SpearConversationContext
  let brandColor: Color
  let cornerRadius: CGFloat
  let action: SpearContextHeaderAction
  let thumbnail: (URL) -> AnyView

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Group {
      if let progress = context.orderProgress {
        contextControl
          .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
      } else {
        contextControl
      }
    }
    .animation(contextMotion, value: context.contentTransitionIdentity)
  }

  @ViewBuilder
  private var contextControl: some View {
    if action.availability.isVisible {
      Button {
        guard action.availability.isEnabled else { return }
        action.perform(context)
      } label: {
        contextLayout
      }
      .buttonStyle(SpearContextRowButtonStyle(color: brandColor, cornerRadius: cornerRadius))
      .hoverEffect(.highlight)
      .disabled(!action.availability.isEnabled)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(accessibilityLabel)
      .accessibilityIdentifier(SpearChatHeaderAccessibilityID.contextAction)
      .modifier(SpearDisabledReasonModifier(reason: action.availability.disabledReason))
    } else {
      contextLayout
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
  }

  @ViewBuilder
  private var contextLayout: some View {
    Group {
      if dynamicTypeSize.isAccessibilitySize {
        verticalLayout
      } else if #available(iOS 16.0, *) {
        ViewThatFits(in: .horizontal) {
          horizontalLayout.frame(minWidth: context.isSupport ? 240 : 280)
          verticalLayout
        }
      } else {
        verticalLayout
      }
    }
    .padding(.horizontal, 4)
    .padding(.vertical, 4)
    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    .contentShape(Rectangle())
  }

  private var horizontalLayout: some View {
    HStack(spacing: 8) {
      contextVisual
      contextText
      actionLabel
    }
  }

  private var verticalLayout: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 8) {
        contextVisual
        contextText
      }
      actionLabel
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
  }

  // MARK: - Identity and State

  @ViewBuilder
  private var contextVisual: some View {
    if context.isSupport {
      Image(systemName: context.symbolSystemName)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(brandColor)
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    } else {
      ZStack {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(Color.primary.opacity(0.045))
        Image(systemName: context.symbolSystemName)
          .font(.system(size: 18, weight: .medium))
          .foregroundStyle(brandColor)
        if let thumbnailURL = context.listingThumbnailURL {
          thumbnail(thumbnailURL)
        }
      }
      .frame(width: 44, height: 44)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .accessibilityHidden(true)
    }
  }

  private var contextText: some View {
    VStack(alignment: .leading, spacing: 2) {
      if context.isSupport {
        Text(context.detail.isEmpty ? context.title : context.detail)
          .font(Font.ppBeirutiMedium(size: 14, relativeTo: .subheadline))
          .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
      } else {
        Text(context.eyebrow)
          .font(Font.ppBeirutiRegular(size: 12, relativeTo: .caption))
          .foregroundStyle(.secondary)
        Text(context.title)
          .font(Font.ppBeirutiSemiBold(size: 15, relativeTo: .subheadline))
          .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
        if !context.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Text(context.detail)
            .font(Font.ppBeirutiRegular(size: 13, relativeTo: .caption))
            .foregroundStyle(.secondary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
        }
        if let progress = context.orderProgress {
          ProgressView(value: progress)
            .tint(brandColor)
            .padding(.top, 4)
        }
      }
    }
    .foregroundStyle(Color.primary)
    .multilineTextAlignment(.leading)
    .frame(maxWidth: .infinity, alignment: .leading)
    .fixedSize(horizontal: false, vertical: true)
  }

  @ViewBuilder
  private var actionLabel: some View {
    if action.availability.isVisible {
      HStack(spacing: 4) {
        Text(context.actionTitle)
          .font(Font.ppBeirutiSemiBold(size: 14, relativeTo: .subheadline))
          .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
        Image(systemName: "chevron.forward")
          .font(.system(size: 10, weight: .semibold))
      }
      .foregroundStyle(action.availability.isEnabled ? brandColor : Color.secondary)
      .multilineTextAlignment(.trailing)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var accessibilityLabel: String {
    let contextParts =
      context.isSupport
      ? [context.title, context.detail]
      : [context.eyebrow, context.title, context.detail]
    let actionParts = action.availability.isVisible ? [context.actionTitle] : []
    return (contextParts + actionParts)
      .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      .joined(separator: ", ")
  }

  private var contextMotion: Animation? {
    if reduceMotion { return nil }
    return SpearHeaderMotion.liveIndicator
  }
}

internal struct SpearContextRowButtonStyle: ButtonStyle {
  let color: Color
  let cornerRadius: CGFloat

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background(
        color.opacity(configuration.isPressed ? 0.07 : 0),
        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
      )
      .opacity(configuration.isPressed ? 0.82 : 1)
      .animation(
        reduceMotion ? nil : SpearHeaderMotion.press(isPressed: configuration.isPressed),
        value: configuration.isPressed
      )
  }
}
