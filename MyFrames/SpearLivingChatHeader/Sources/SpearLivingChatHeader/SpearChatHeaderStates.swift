import SwiftUI

@available(iOS 17.0, *)
internal struct SpearHeaderLoadingRow: View {
  let copy: SpearChatHeaderCopy
  let actions: SpearChatHeaderActions

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    HStack(spacing: 10) {
      SpearHeaderIconActionButton(
        systemName: "chevron.backward",
        accessibilityLabel: copy.backAccessibilityLabel,
        accessibilityIdentifier: SpearChatHeaderAccessibilityID.back,
        action: .enabled(actions.onBack)
      )

      skeletonContent
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(copy.loadingAccessibilityLabel)

      activeCallButton
    }
    .padding(.horizontal, 12)
    .padding(.top, 10)
    .padding(.bottom, 8)
  }

  @ViewBuilder
  private var skeletonContent: some View {
    let content = HStack(spacing: 11) {
      Circle()
        .fill(.quaternary)
        .frame(width: 52, height: 52)

      VStack(alignment: .leading, spacing: 7) {
        Capsule()
          .fill(.quaternary)
          .frame(maxWidth: 150)
          .frame(height: 13)

        Capsule()
          .fill(.quaternary)
          .frame(maxWidth: 104)
          .frame(height: 9)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if actions.call.isVisible && !actions.call.isActive {
        Circle()
          .fill(.quaternary)
          .frame(width: 36, height: 36)
      }

      if actions.more.availability.isVisible {
        Circle()
          .fill(.quaternary)
          .frame(width: 36, height: 36)
      }
    }

    if reduceMotion {
      content.opacity(0.58)
    } else {
      content.phaseAnimator([0.42, 0.72]) { view, opacity in
        view.opacity(opacity)
      } animation: { _ in
        .easeInOut(duration: 0.95)
      }
    }
  }

  @ViewBuilder
  private var activeCallButton: some View {
    if actions.call.isActive {
      SpearHeaderIconActionButton(
        systemName: "phone.down.fill",
        accessibilityLabel: copy.endCallAccessibilityLabel,
        accessibilityIdentifier: SpearChatHeaderAccessibilityID.call,
        action: actions.call.buttonAction,
        tint: .red
      )
    }
  }
}

@available(iOS 17.0, *)
internal struct SpearHeaderUnavailableRow: View {
  let title: String
  let retryTitle: String?
  let copy: SpearChatHeaderCopy
  let brandColor: Color
  let actions: SpearChatHeaderActions

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    Group {
      if dynamicTypeSize.isAccessibilitySize {
        compactLayout
      } else {
        ViewThatFits(in: .horizontal) {
          regularLayout.frame(minWidth: 340)
          compactLayout
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.top, 10)
    .padding(.bottom, 8)
  }

  private var regularLayout: some View {
    HStack(spacing: 10) {
      backButton
      unavailableIdentity
      retryButton
      activeCallIconButton
    }
  }

  private var compactLayout: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 10) {
        backButton
        unavailableIdentity
      }

      if retryIsVisible || actions.call.isActive {
        HStack(spacing: 8) {
          retryButton
          activeCallLabeledButton
        }
        .padding(.leading, 54)
      }
    }
  }

  private var backButton: some View {
    SpearHeaderIconActionButton(
      systemName: "chevron.backward",
      accessibilityLabel: copy.backAccessibilityLabel,
      accessibilityIdentifier: SpearChatHeaderAccessibilityID.back,
      action: .enabled(actions.onBack)
    )
  }

  private var unavailableIdentity: some View {
    HStack(spacing: 10) {
      Image(systemName: "person.crop.circle.badge.exclamationmark")
        .font(.title2)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text(title)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityElement(children: .combine)
  }

  private var retryIsVisible: Bool {
    retryTitle != nil && actions.retry.availability.isVisible
  }

  @ViewBuilder
  private var retryButton: some View {
    if let retryTitle, actions.retry.availability.isVisible {
      Button(retryTitle, action: actions.retry.perform)
        .buttonStyle(SpearBrandButtonStyle(color: brandColor))
        .disabled(!actions.retry.availability.isEnabled)
        .opacity(actions.retry.availability.isEnabled ? 1 : 0.48)
        .accessibilityIdentifier(SpearChatHeaderAccessibilityID.retry)
        .modifier(
          SpearDisabledReasonModifier(reason: actions.retry.availability.disabledReason)
        )
    }
  }

  @ViewBuilder
  private var activeCallIconButton: some View {
    if actions.call.isActive {
      SpearHeaderIconActionButton(
        systemName: "phone.down.fill",
        accessibilityLabel: copy.endCallAccessibilityLabel,
        accessibilityIdentifier: SpearChatHeaderAccessibilityID.call,
        action: actions.call.buttonAction,
        tint: .red
      )
    }
  }

  @ViewBuilder
  private var activeCallLabeledButton: some View {
    if actions.call.isActive {
      SpearHeaderLabeledActionButton(
        title: copy.endCallAccessibilityLabel,
        systemName: "phone.down.fill",
        accessibilityLabel: copy.endCallAccessibilityLabel,
        accessibilityIdentifier: SpearChatHeaderAccessibilityID.call,
        action: actions.call.buttonAction,
        tint: .red
      )
    }
  }
}
