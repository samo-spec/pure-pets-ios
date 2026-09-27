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
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
    .background(
      Color(uiColor: .secondarySystemGroupedBackground).opacity(0.92),
      in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .stroke(
          LinearGradient(
            colors: [
              Color.white.opacity(0.38),
              Color.primary.opacity(0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 0.8
        )
    )
    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    .contentShape(Rectangle())
  }

  private var horizontalLayout: some View {
    HStack(spacing: 10) {
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

  // MARK: - Identity and State

  @ViewBuilder
  private var contextVisual: some View {
    if context.isSupport {
      ZStack(alignment: .bottomTrailing) {
        Circle()
          .fill(
            LinearGradient(
              colors: [
                brandColor,
                Color(red: 190 / 255.0, green: 24 / 255.0, blue: 60 / 255.0)
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
        Image(systemName: context.symbolSystemName)
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(.white)
          .shadow(color: Color.black.opacity(0.25), radius: 1, y: 1)

        Circle()
          .fill(SpearHeaderSemanticColor.live)
          .frame(width: 8, height: 8)
          .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 1.5))
          .offset(x: 2, y: 2)
      }
      .frame(width: 34, height: 34)
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
      .frame(width: 48, height: 48)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
      )
      .accessibilityHidden(true)
    }
  }

  private var contextText: some View {
    VStack(alignment: .leading, spacing: 3) {
      if context.isSupport {
        HStack(spacing: 5) {
          Text(context.title.isEmpty ? context.eyebrow : context.title)
            .font(Font.ppBeirutiBold(size: 15, relativeTo: .subheadline))
            .lineLimit(1)

          Text(Locale.current.languageCode == "ar" ? "نشط" : "Active")
            .font(Font.ppBeirutiBold(size: 10, relativeTo: .caption2))
            .foregroundStyle(SpearHeaderSemanticColor.live)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(SpearHeaderSemanticColor.live.opacity(0.12), in: Capsule())
        }

        if !context.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Text(context.detail)
            .font(Font.ppBeirutiRegular(size: 12, relativeTo: .caption))
            .foregroundStyle(Color.secondary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
        }
      } else {
        HStack(spacing: 4) {
          HStack(spacing: 3) {
            Image(systemName: context.symbolSystemName)
              .font(.system(size: 8, weight: .bold))
            Text(context.eyebrow)
              .font(Font.ppBeirutiBold(size: 10, relativeTo: .caption2))
          }
          .foregroundStyle(brandColor)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(brandColor.opacity(0.09), in: Capsule())

          if let badgeText = context.badgeText, !badgeText.isEmpty {
            Text(badgeText)
              .font(Font.ppBeirutiMedium(size: 10, relativeTo: .caption2))
              .foregroundStyle(Color.secondary)
              .padding(.horizontal, 5)
              .padding(.vertical, 2)
              .background(Color.primary.opacity(0.04), in: Capsule())
          }
        }

        Text(context.title)
          .font(Font.ppBeirutiBold(size: 15, relativeTo: .subheadline))
          .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)

        if !context.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Text(context.detail)
            .font(Font.ppBeirutiSemiBold(size: 13, relativeTo: .caption))
            .foregroundStyle(Color.secondary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
        }

        if let progress = context.orderProgress {
          ProgressView(value: progress)
            .tint(brandColor)
            .padding(.top, 2)
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
          .font(Font.ppBeirutiBold(size: 12, relativeTo: .caption))
          .lineLimit(1)
        Image(systemName: "chevron.forward")
          .font(.system(size: 8, weight: .bold))
      }
      .foregroundStyle(action.availability.isEnabled ? brandColor : Color.secondary)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(
        brandColor.opacity(action.availability.isEnabled ? 0.09 : 0.03),
        in: Capsule()
      )
      .overlay(
        Capsule()
          .strokeBorder(
            brandColor.opacity(action.availability.isEnabled ? 0.22 : 0.08),
            lineWidth: 0.75
          )
      )
      .multilineTextAlignment(.trailing)
      .fixedSize(horizontal: true, vertical: true)
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
      .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.985 : 1.0))
      .background(
        color.opacity(configuration.isPressed ? 0.06 : 0),
        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
      )
      .opacity(configuration.isPressed ? 0.85 : 1)
      .animation(
        reduceMotion ? nil : SpearHeaderMotion.press(isPressed: configuration.isPressed),
        value: configuration.isPressed
      )
  }
}
