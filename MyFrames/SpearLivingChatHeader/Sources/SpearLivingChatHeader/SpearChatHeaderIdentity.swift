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
        .background(Color(uiColor: .secondarySystemBackground))

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

@available(iOS 15.0, *)
internal struct SpearIdentityButton<AvatarContent: View>: View {
  let model: SpearChatHeaderModel
  let avatarContent: AvatarContent
  let brandColor: Color
  let copy: SpearChatHeaderCopy
  let call: SpearCallControl
  let motionMode: SpearMotionMode
  let isExpanded: Bool
  let canExpand: Bool
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
    HStack(alignment: dynamicTypeSize.isAccessibilitySize ? .top : .center, spacing: 12) {
      SpearAvatarFrame(
        trust: model.trust,
        presence: model.presence,
        call: call,
        motionMode: motionMode,
        brandColor: brandColor,
        content: avatarContent
      )

      VStack(alignment: .leading, spacing: 2) {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text(model.name)
            .font(Font.ppBeirutiBold(size: 20, relativeTo: .headline))
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)

          if let badge = model.trust.badgeSystemName {
            Image(systemName: badge)
              .font(.caption.weight(.semibold))
              .foregroundStyle(trustTint)
              .symbolRenderingMode(.hierarchical)
              .frame(minWidth: 18, minHeight: 18)
              .accessibilityHidden(true)
          }

          if canExpand {
            Image(systemName: "chevron.down")
              .font(.system(size: 10, weight: .bold))
              .foregroundStyle(isExpanded ? brandColor : Color.secondary)
              .rotationEffect(.degrees(isExpanded ? 180 : 0))
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
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(minHeight: 44)
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
