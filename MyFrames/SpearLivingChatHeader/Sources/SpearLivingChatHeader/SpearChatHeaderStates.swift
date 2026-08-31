import SwiftUI

// MARK: - Loading State (Seamless Skeleton)

@available(iOS 15.0, *)
internal struct SpearHeaderLoadingRow: View {
  let copy: SpearChatHeaderCopy
  let actions: SpearChatHeaderActions

  var body: some View {
    HStack(spacing: 12) {
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
    .padding(.bottom, 10)
  }

  @ViewBuilder
  private var skeletonContent: some View {
    let content = HStack(spacing: 12) {
      // Avatar skeleton with warm tint
      Circle()
        .fill(.quaternary)
        .frame(width: 48, height: 48)
        .overlay {
          Circle()
            .strokeBorder(Color.primary.opacity(0.04), lineWidth: 1)
        }

      VStack(alignment: .leading, spacing: 8) {
        Capsule()
          .fill(.quaternary)
          .frame(maxWidth: 140)
          .frame(height: 12)

        Capsule()
          .fill(.quaternary)
          .frame(maxWidth: 90)
          .frame(height: 8)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      // Preserve the ready row's action footprint to avoid a loading-to-ready
      // width jump. Active calls remain real controls outside the skeleton.
      if !actions.call.isActive && hasLoadingActionFootprint {
        HStack(spacing: 0) {
          if actions.call.isVisible {
            loadingActionPlaceholder
          }
          if actions.more.availability.isVisible {
            loadingActionPlaceholder
          }
        }
        .padding(2)
        .background(Color.primary.opacity(0.02), in: Capsule(style: .continuous))
      }
    }

    content.opacity(0.58)
  }

  private var hasLoadingActionFootprint: Bool {
    actions.call.isVisible || actions.more.availability.isVisible
  }

  private var loadingActionPlaceholder: some View {
    Circle()
      .fill(.quaternary)
      .frame(width: 28, height: 28)
      .frame(width: 44, height: 44)
      .accessibilityHidden(true)
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

// MARK: - Unavailable State

@available(iOS 15.0, *)
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
        if #available(iOS 16.0, *) {
          ViewThatFits(in: .horizontal) {
            regularLayout.frame(minWidth: 340)
            compactLayout
          }
        } else {
          regularLayout
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.top, 10)
    .padding(.bottom, 10)
  }

  private var regularLayout: some View {
    HStack(spacing: 12) {
      backButton
      unavailableIdentity
      retryButton
      activeCallIconButton
    }
  }

  private var compactLayout: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 12) {
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
        .font(Font.ppBeirutiMedium(size: 15, relativeTo: .subheadline))
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
        .opacity(actions.retry.availability.isEnabled ? 1 : 0.42)
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
