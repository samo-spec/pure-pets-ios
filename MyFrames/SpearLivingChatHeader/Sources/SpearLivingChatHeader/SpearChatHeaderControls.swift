import SwiftUI
import UIKit

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
      .opacity(action.availability.isEnabled ? 1 : 0.48)
      .accessibilityLabel(accessibilityLabel)
      .accessibilityIdentifier(accessibilityIdentifier)
      .modifier(SpearDisabledReasonModifier(reason: action.availability.disabledReason))
    }
  }
}

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
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(tint)
          .frame(maxWidth: .infinity)
          .frame(minHeight: 44)
      }
      .buttonStyle(SpearSecondaryButtonStyle())
      .disabled(!action.availability.isEnabled)
      .opacity(action.availability.isEnabled ? 1 : 0.48)
      .accessibilityLabel(accessibilityLabel)
      .accessibilityIdentifier(accessibilityIdentifier)
      .modifier(SpearDisabledReasonModifier(reason: action.availability.disabledReason))
    }
  }
}

internal struct SpearTextActionButton: View {
  let title: String
  let accessibilityIdentifier: String
  let action: SpearHeaderAction

  var body: some View {
    if action.availability.isVisible {
      Button(title, action: action.perform)
        .buttonStyle(SpearSecondaryButtonStyle())
        .disabled(!action.availability.isEnabled)
        .opacity(action.availability.isEnabled ? 1 : 0.48)
        .accessibilityIdentifier(accessibilityIdentifier)
        .modifier(SpearDisabledReasonModifier(reason: action.availability.disabledReason))
    }
  }
}

internal struct SpearContextActionButton: View {
  let title: String
  let brandColor: Color
  let context: SpearConversationContext
  let action: SpearContextHeaderAction

  var body: some View {
    if action.availability.isVisible {
      Button(title) {
        action.perform(context)
      }
      .buttonStyle(SpearBrandButtonStyle(color: brandColor))
      .disabled(!action.availability.isEnabled)
      .opacity(action.availability.isEnabled ? 1 : 0.48)
      .accessibilityIdentifier(SpearChatHeaderAccessibilityID.contextAction)
      .modifier(SpearDisabledReasonModifier(reason: action.availability.disabledReason))
    }
  }
}

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

internal struct SpearIconButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorSchemeContrast) private var contrast

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background(
        Color.primary.opacity(contrast == .increased ? 0.1 : 0.055),
        in: Circle()
      )
      .overlay {
        Circle()
          .strokeBorder(
            Color.primary.opacity(contrast == .increased ? 0.24 : 0.09),
            lineWidth: contrast == .increased ? 1.5 : 1
          )
      }
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.93 : 1)
      .opacity(configuration.isPressed ? 0.72 : 1)
      .animation(
        reduceMotion ? nil : .snappy(duration: 0.18, extraBounce: 0.08),
        value: configuration.isPressed
      )
  }
}

internal struct SpearIdentityButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(.horizontal, 4)
      .padding(.vertical, 3)
      .background(
        configuration.isPressed ? Color.primary.opacity(0.055) : .clear,
        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
      )
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.988 : 1)
      .animation(
        reduceMotion ? nil : .snappy(duration: 0.18),
        value: configuration.isPressed
      )
  }
}

internal struct SpearSecondaryButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorSchemeContrast) private var contrast

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .frame(minHeight: 44)
      .background(
        Color.primary.opacity(configuration.isPressed ? 0.09 : 0.045),
        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
          .strokeBorder(
            Color.primary.opacity(contrast == .increased ? 0.25 : 0.09),
            lineWidth: contrast == .increased ? 1.5 : 1
          )
      }
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.982 : 1)
      .animation(
        reduceMotion ? nil : .snappy(duration: 0.18),
        value: configuration.isPressed
      )
  }
}

internal struct SpearBrandButtonStyle: ButtonStyle {
  let color: Color

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(.white)
      .padding(.horizontal, 13)
      .padding(.vertical, 8)
      .frame(minHeight: 44)
      .background(
        color.opacity(configuration.isPressed ? 0.8 : 1),
        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
      )
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
      .animation(
        reduceMotion ? nil : .snappy(duration: 0.17, extraBounce: 0.06),
        value: configuration.isPressed
      )
  }
}
