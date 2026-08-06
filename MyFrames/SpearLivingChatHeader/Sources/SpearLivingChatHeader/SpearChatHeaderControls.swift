import SwiftUI
import UIKit

// MARK: - Capsule Action Button (new floating pill style)

internal struct SpearHeaderCapsuleButton: View {
  let systemName: String
  let accessibilityLabel: String
  let accessibilityIdentifier: String
  let action: SpearHeaderAction
  let tint: Color
  let isActive: Bool

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    if action.availability.isVisible {
      Button(action: action.perform) {
        Image(systemName: systemName)
          .font(.body.weight(.medium))
          .foregroundStyle(tint)
          .frame(width: 38, height: 38)
          .contentShape(Circle())
          .background { activeGlow }
      }
      .buttonStyle(SpearCapsuleItemStyle())
      .disabled(!action.availability.isEnabled)
      .opacity(action.availability.isEnabled ? 1 : 0.42)
      .accessibilityLabel(accessibilityLabel)
      .accessibilityIdentifier(accessibilityIdentifier)
      .modifier(SpearDisabledReasonModifier(reason: action.availability.disabledReason))
    }
  }

  @ViewBuilder
  private var activeGlow: some View {
    if isActive && !reduceMotion {
      Circle()
        .fill(tint.opacity(0.12))
        .phaseAnimator([false, true]) { view, phase in
          view.scaleEffect(phase ? 1.15 : 1.0)
        } animation: { _ in
          .easeInOut(duration: 1.2)
        }
    }
  }
}

// MARK: - Icon Action Button

internal struct SpearHeaderIconActionButton: View {
  let systemName: String
  let accessibilityLabel: String
  let accessibilityIdentifier: String
  let action: SpearHeaderAction
  var tint: Color = .primary

  var body: some View {
    if action.availability.isVisible {
      Button(action: action.perform) {
        Image(systemName: systemName)
          .font(.body.weight(.semibold))
          .foregroundStyle(tint)
          .frame(width: 44, height: 44)
          .contentShape(Circle())
      }
      .buttonStyle(SpearIconButtonStyle())
      .disabled(!action.availability.isEnabled)
      .opacity(action.availability.isEnabled ? 1 : 0.42)
      .accessibilityLabel(accessibilityLabel)
      .accessibilityIdentifier(accessibilityIdentifier)
      .modifier(SpearDisabledReasonModifier(reason: action.availability.disabledReason))
    }
  }
}

// MARK: - Labeled Action Button

internal struct SpearHeaderLabeledActionButton: View {
  let title: String
  let systemName: String
  let accessibilityLabel: String
  let accessibilityIdentifier: String
  let action: SpearHeaderAction
  var tint: Color = .primary

  var body: some View {
    if action.availability.isVisible {
      Button(action: action.perform) {
        Label(title, systemImage: systemName)
          .font(Font.ppBeirutiSemiBold(size: 14, relativeTo: .subheadline))
          .foregroundStyle(tint)
          .frame(maxWidth: .infinity)
          .frame(minHeight: 44)
      }
      .buttonStyle(SpearSecondaryButtonStyle())
      .disabled(!action.availability.isEnabled)
      .opacity(action.availability.isEnabled ? 1 : 0.42)
      .accessibilityLabel(accessibilityLabel)
      .accessibilityIdentifier(accessibilityIdentifier)
      .modifier(SpearDisabledReasonModifier(reason: action.availability.disabledReason))
    }
  }
}

// MARK: - Text Action Button

internal struct SpearTextActionButton: View {
  let title: String
  let accessibilityIdentifier: String
  let action: SpearHeaderAction

  var body: some View {
    if action.availability.isVisible {
      Button(title, action: action.perform)
        .buttonStyle(SpearSecondaryButtonStyle())
        .disabled(!action.availability.isEnabled)
        .opacity(action.availability.isEnabled ? 1 : 0.42)
        .accessibilityIdentifier(accessibilityIdentifier)
        .modifier(SpearDisabledReasonModifier(reason: action.availability.disabledReason))
    }
  }
}

// MARK: - Context Action Button

internal struct SpearContextActionButton: View {
  let title: String
  let brandColor: Color
  let context: SpearConversationContext
  let action: SpearContextHeaderAction

  var body: some View {
    if action.availability.isVisible {
      Button {
        action.perform(context)
      } label: {
        HStack(spacing: 6) {
          Text(title)
            .lineLimit(1)
          Image(systemName: "chevron.forward")
            .font(.caption.weight(.bold))
            .accessibilityHidden(true)
        }
      }
      .buttonStyle(SpearContextButtonStyle(color: brandColor))
      .disabled(!action.availability.isEnabled)
      .opacity(action.availability.isEnabled ? 1 : 0.42)
      .accessibilityLabel("\(title), \(context.title)")
      .accessibilityIdentifier(SpearChatHeaderAccessibilityID.contextAction)
      .modifier(SpearDisabledReasonModifier(reason: action.availability.disabledReason))
    }
  }
}

internal struct SpearContextButtonStyle: ButtonStyle {
  let color: Color

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorSchemeContrast) private var contrast

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(Font.ppBeirutiSemiBold(size: 14, relativeTo: .subheadline))
      .foregroundStyle(color)
      .padding(.horizontal, 8)
      .frame(minWidth: 44, minHeight: 44)
      .contentShape(Rectangle())
      .background(
        configuration.isPressed
          ? color.opacity(contrast == .increased ? 0.15 : 0.08)
          : .clear,
        in: Capsule(style: .continuous)
      )
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
      .animation(reduceMotion ? nil : .snappy(duration: 0.17), value: configuration.isPressed)
  }
}

// MARK: - Disabled Reason Modifier

internal struct SpearDisabledReasonModifier: ViewModifier {
  let reason: String?

  @ViewBuilder
  func body(content: Content) -> some View {
    if let reason, !reason.isEmpty {
      content.accessibilityHint(reason)
    } else {
      content
    }
  }
}

// MARK: - Button Styles

/// Capsule item: lives inside the floating action pill
internal struct SpearCapsuleItemStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.88 : 1)
      .opacity(configuration.isPressed ? 0.65 : 1)
      .animation(reduceMotion ? nil : .snappy(duration: 0.16, extraBounce: 0.12), value: configuration.isPressed)
  }
}

/// Icon button: back, standalone actions
internal struct SpearIconButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.colorScheme) private var colorScheme

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background(
        Color.primary.opacity(
          configuration.isPressed
            ? (contrast == .increased ? 0.18 : 0.11)
            : (contrast == .increased ? 0.10 : 0.055)
        ),
        in: Circle()
      )
      .overlay {
        Circle()
          .strokeBorder(
            Color.primary.opacity(contrast == .increased ? 0.22 : 0.07),
            lineWidth: contrast == .increased ? 1.5 : 0.5
          )
      }
      .shadow(
        color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.05),
        radius: 9,
        y: 4
      )
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
      .animation(reduceMotion ? nil : .snappy(duration: 0.18, extraBounce: 0.08), value: configuration.isPressed)
  }
}

/// Identity tap: subtle press for the profile/trust area
internal struct SpearIdentityButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(.horizontal, 4)
      .padding(.vertical, 3)
      .background(
        configuration.isPressed ? Color.primary.opacity(0.05) : .clear,
        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
      )
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.99 : 1)
      .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: configuration.isPressed)
  }
}

/// Secondary button: call/more in compact layout, profile/safety in expansion
internal struct SpearSecondaryButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorSchemeContrast) private var contrast

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(Font.ppBeirutiSemiBold(size: 14, relativeTo: .subheadline))
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .frame(minHeight: 44)
      .background(
        Color.primary.opacity(configuration.isPressed ? 0.08 : 0.04),
        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .strokeBorder(
            Color.primary.opacity(contrast == .increased ? 0.22 : 0.07),
            lineWidth: contrast == .increased ? 1.5 : 0.5
          )
      }
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
      .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: configuration.isPressed)
  }
}
