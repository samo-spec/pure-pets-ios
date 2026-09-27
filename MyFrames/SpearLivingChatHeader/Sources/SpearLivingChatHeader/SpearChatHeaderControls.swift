import SwiftUI
import UIKit

// MARK: - Toolbar Action

internal struct SpearHeaderToolbarButton: View {
  let systemName: String
  let accessibilityLabel: String
  let accessibilityIdentifier: String
  let action: SpearHeaderAction
  let tint: Color
  let isActive: Bool

  @Environment(\.colorSchemeContrast) private var contrast

  var body: some View {
    if action.availability.isVisible {
      Button(action: action.perform) {
        ZStack {
          Circle()
            .fill(
              isActive
                ? tint.opacity(0.15)
                : Color(uiColor: .secondarySystemGroupedBackground).opacity(0.94)
            )
          Circle()
            .strokeBorder(
              LinearGradient(
                colors: [
                  Color.white.opacity(contrast == .increased ? 0.50 : 0.25),
                  Color.primary.opacity(contrast == .increased ? 0.25 : 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              lineWidth: contrast == .increased ? 1.5 : 0.75
            )
          Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
        }
        .frame(width: 38, height: 38)
        .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1.5)
        .frame(width: 44, height: 44)
        .contentShape(Circle())
      }
      .buttonStyle(SpearCapsuleItemStyle())
      .hoverEffect(.highlight)
      .disabled(!action.availability.isEnabled)
      .opacity(action.availability.isEnabled ? 1 : 0.56)
      .accessibilityLabel(accessibilityLabel)
      .accessibilityIdentifier(accessibilityIdentifier)
      .modifier(SpearDisabledReasonModifier(reason: action.availability.disabledReason))
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

  @Environment(\.colorSchemeContrast) private var contrast

  var body: some View {
    if action.availability.isVisible {
      Button(action: action.perform) {
        ZStack {
          Circle()
            .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.94))
          Circle()
            .strokeBorder(
              LinearGradient(
                colors: [
                  Color.white.opacity(contrast == .increased ? 0.50 : 0.25),
                  Color.primary.opacity(contrast == .increased ? 0.25 : 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              lineWidth: contrast == .increased ? 1.5 : 0.75
            )
          Image(systemName: systemName)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(tint)
        }
        .frame(width: 38, height: 38)
        .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1.5)
        .frame(width: 44, height: 44)
        .contentShape(Circle())
      }
      .buttonStyle(SpearIconButtonStyle())
      .hoverEffect(.highlight)
      .disabled(!action.availability.isEnabled)
      .opacity(action.availability.isEnabled ? 1 : 0.56)
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
      .hoverEffect(.highlight)
      .disabled(!action.availability.isEnabled)
      .opacity(action.availability.isEnabled ? 1 : 0.56)
      .accessibilityLabel(accessibilityLabel)
      .accessibilityIdentifier(accessibilityIdentifier)
      .modifier(SpearDisabledReasonModifier(reason: action.availability.disabledReason))
    }
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

/// Toolbar control: tactile spring response with specular surface.
internal struct SpearCapsuleItemStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.93 : 1)
      .opacity(configuration.isPressed ? 0.76 : 1)
      .animation(
        reduceMotion ? nil : SpearHeaderMotion.press(isPressed: configuration.isPressed),
        value: configuration.isPressed)
  }
}

/// Icon button: back, standalone actions with tactile spring response.
internal struct SpearIconButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.93 : 1)
      .opacity(configuration.isPressed ? 0.76 : 1)
      .animation(
        reduceMotion ? nil : SpearHeaderMotion.press(isPressed: configuration.isPressed),
        value: configuration.isPressed)
  }
}

/// Identity tap: subtle press for the profile/trust area
internal struct SpearIdentityButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(.vertical, 4)
      .padding(.horizontal, 4)
      .background(
        Color.primary.opacity(0.04)
          .opacity(configuration.isPressed ? 1 : 0),
        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
      )
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
      .opacity(configuration.isPressed ? 0.88 : 1)
      .animation(
        reduceMotion ? nil : SpearHeaderMotion.press(isPressed: configuration.isPressed),
        value: configuration.isPressed)
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
        Color.primary.opacity(0.04),
        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(Color.primary.opacity(0.04))
          .opacity(configuration.isPressed ? 1 : 0)
      }
      .overlay {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .strokeBorder(
            Color.primary.opacity(contrast == .increased ? 0.22 : 0.07),
            lineWidth: contrast == .increased ? 1.5 : 0.5
          )
      }
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
      .opacity(configuration.isPressed ? 0.84 : 1)
      .animation(
        reduceMotion ? nil : SpearHeaderMotion.press(isPressed: configuration.isPressed),
        value: configuration.isPressed)
  }
}
