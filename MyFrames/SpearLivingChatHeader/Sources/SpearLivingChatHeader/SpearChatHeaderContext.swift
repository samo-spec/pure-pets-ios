import SwiftUI

// MARK: - Conversation Context

/// A full-width handoff from who is in the conversation to what it concerns.
/// The host still owns the destination and receives the unmodified context.
@available(iOS 15.0, *)
internal struct SpearContextRail: View {
  let context: SpearConversationContext
  let brandColor: Color
  let cornerRadius: CGFloat
  let action: SpearContextHeaderAction
  let thumbnail: (URL) -> AnyView

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.colorSchemeContrast) private var contrast

  var body: some View {
    Group {
      if let progress = context.orderProgress {
        contextControl
          .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
      } else {
        contextControl
      }
    }
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
          horizontalLayout.frame(minWidth: 310)
          verticalLayout
        }
      } else {
        verticalLayout
      }
    }
    .padding(.leading, 12)
    .padding(.trailing, 2)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
    .overlay(alignment: .leading) {
      Rectangle()
        .fill(brandColor.opacity(contrast == .increased ? 1 : 0.74))
        .frame(width: contrast == .increased ? 3 : 2)
        .accessibilityHidden(true)
    }
    .contentShape(Rectangle())
  }

  private var horizontalLayout: some View {
    HStack(alignment: .center, spacing: 10) {
      contextVisual
      contextText
      actionLabel
    }
  }

  private var verticalLayout: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 10) {
        contextVisual
        contextText
      }
      actionLabel
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
  }

  // MARK: - Waypoint Identity

  private var contextVisual: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .fill(brandColor.opacity(0.09))

      Image(systemName: context.symbolSystemName)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(brandColor)

      if let thumbnailURL = context.listingThumbnailURL {
        thumbnail(thumbnailURL)
      }
    }
    .frame(width: 40, height: 40)
    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .strokeBorder(Color.primary.opacity(contrast == .increased ? 0.30 : 0.08), lineWidth: 1)
    }
    .accessibilityHidden(true)
  }

  private var contextText: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 5) {
        Text(context.eyebrow)
          .font(Font.ppBeirutiSemiBold(size: 11, relativeTo: .caption2))
          .foregroundStyle(brandColor)

        if let badge = context.badgeText, !badge.isEmpty {
          Text("·")
            .foregroundStyle(.secondary)
          Text(badge)
            .foregroundStyle(.secondary)
        }
      }
      .font(Font.ppBeirutiRegular(size: 11, relativeTo: .caption2))
      .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)

      Text(context.title.isEmpty ? context.eyebrow : context.title)
        .font(Font.ppBeirutiBold(size: 16, relativeTo: .subheadline))
        .foregroundStyle(.primary)
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
        .layoutPriority(1)

      if !context.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Text(context.detail)
          .font(Font.ppBeirutiRegular(size: 12, relativeTo: .caption))
          .foregroundStyle(.secondary)
          .lineLimit(context.isSupport || dynamicTypeSize.isAccessibilitySize ? nil : 1)
      }

      if let progress = context.orderProgress {
        ProgressView(value: progress)
          .tint(brandColor)
          .padding(.top, 3)
      }
    }
    .multilineTextAlignment(.leading)
    .frame(maxWidth: .infinity, alignment: .leading)
    .fixedSize(horizontal: false, vertical: true)
  }

  @ViewBuilder
  private var actionLabel: some View {
    if action.availability.isVisible {
      HStack(spacing: 4) {
        Text(context.actionTitle)
          .font(Font.ppBeirutiSemiBold(size: 12, relativeTo: .caption))
          .lineLimit(1)
        Image(systemName: "chevron.forward")
          .font(.system(size: 9, weight: .semibold))
          .accessibilityHidden(true)
      }
      .foregroundStyle(action.availability.isEnabled ? brandColor : Color.secondary)
      .fixedSize(horizontal: true, vertical: true)
    }
  }

  private var accessibilityLabel: String {
    let candidates = [
      context.eyebrow, context.title, context.badgeText, context.detail,
      action.availability.isVisible ? context.actionTitle : nil,
    ]
    var seen = Set<String>()
    return candidates.compactMap { candidate in
      guard let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
        !value.isEmpty,
        seen.insert(value).inserted
      else { return nil }
      return value
    }
    .joined(separator: ", ")
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
        in: RoundedRectangle(cornerRadius: min(cornerRadius, 8), style: .continuous)
      )
      .opacity(configuration.isPressed ? 0.88 : 1)
      .animation(pressAnimation(isPressed: configuration.isPressed), value: configuration.isPressed)
  }

  private func pressAnimation(isPressed: Bool) -> Animation? {
    if reduceMotion { return nil }
    return SpearHeaderMotion.press(isPressed: isPressed)
  }
}
