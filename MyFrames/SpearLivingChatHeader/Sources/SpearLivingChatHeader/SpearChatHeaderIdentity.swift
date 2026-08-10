import SwiftUI
import UIKit

// MARK: - Default Avatar

public struct SpearDefaultAvatarContent: View {
  public let fallback: SpearAvatarFallback
  public let brandColor: Color

  public init(
    fallback: SpearAvatarFallback,
    brandColor: Color
  ) {
    self.fallback = fallback
    self.brandColor = brandColor
  }

  public var body: some View {
    switch fallback {
    case .initials(let value):
      Text(value)
        .font(Font.ppBeirutiBold(size: 14, relativeTo: .subheadline))
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
          LinearGradient(
            colors: [
              Color(uiColor: .secondarySystemBackground),
              Color(uiColor: .tertiarySystemBackground),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )

    case .systemImage(let name):
      Image(systemName: name)
        .font(.title3.weight(.semibold))
        .foregroundStyle(brandColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
          brandColor.opacity(0.08)
        )
    }
  }
}

// MARK: - Identity Button

@available(iOS 17.0, *)
internal struct SpearIdentityButton<AvatarContent: View>: View {
  let model: SpearChatHeaderModel
  let avatarContent: AvatarContent
  let brandColor: Color
  let copy: SpearChatHeaderCopy
  let call: SpearCallControl
  let motionMode: SpearMotionMode
  let isExpanded: Bool
  let canExpand: Bool
  let compact: Bool
  let action: () -> Void

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  @ViewBuilder
  var body: some View {
    if canExpand {
      Button(action: action) {
        identityContent
      }
      .buttonStyle(SpearIdentityButtonStyle())
      .hoverEffect(.highlight)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(accessibilityLabel)
      .accessibilityHint(
        isExpanded ? copy.collapseAccessibilityHint : copy.expandAccessibilityHint
      )
      .accessibilityValue(
        isExpanded ? copy.expandedAccessibilityValue : copy.collapsedAccessibilityValue
      )
      .accessibilityIdentifier(SpearChatHeaderAccessibilityID.identity)
    } else {
      identityContent
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(SpearChatHeaderAccessibilityID.identity)
    }
  }

  private var identityContent: some View {
    HStack(spacing: compact ? 10 : 12) {
      SpearAvatarFrame(
        trust: model.trust,
        presence: model.presence,
        call: call,
        motionMode: motionMode,
        brandColor: brandColor,
        content: avatarContent
      )

      VStack(alignment: .leading, spacing: 2) {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
          Text(model.name)
            .font(Font.ppBeirutiBold(size: 17, relativeTo: .headline))
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            .multilineTextAlignment(.leading)
            .layoutPriority(1)

          if let badge = model.trust.badgeSystemName {
            Image(systemName: badge)
              .font(.caption.weight(.semibold))
              .foregroundStyle(trustTint)
              .symbolRenderingMode(.hierarchical)
              .frame(minWidth: 18, minHeight: 18)
              .accessibilityHidden(true)
          }
        }

        SpearPresenceLine(
          presence: model.presence,
          call: call,
          copy: copy,
          motionMode: motionMode,
          brandColor: brandColor
        )
      }
      .frame(maxWidth: compact ? .infinity : nil, alignment: .leading)

      if canExpand {
        Image(systemName: "chevron.down")
          .font(.caption.weight(.semibold))
          .foregroundStyle(isExpanded ? brandColor : Color.secondary)
          .frame(width: 28, height: 44)
          .rotationEffect(.degrees(isExpanded ? 180 : 0))
          .accessibilityHidden(true)
      }
    }
    .contentShape(Rectangle())
  }

  private var accessibilityLabel: String {
    [
      "\(copy.conversationAccessibilityPrefix) \(model.name)",
      copy.trustAccessibilityText(for: model.trust),
      liveAccessibilityText,
    ]
    .compactMap { value in
      guard let value, !value.isEmpty else { return nil }
      return value
    }
    .joined(separator: ", ")
  }

  private var liveAccessibilityText: String {
    if let elapsedSeconds = call.elapsedSeconds {
      return copy.callText(elapsedSeconds: elapsedSeconds)
    }
    return copy.presenceText(for: model.presence)
  }

  private var trustTint: Color {
    model.trust.isRestricted ? SpearHeaderSemanticColor.warning : brandColor
  }
}
