import SwiftUI

// MARK: - Seamless Ready Header

/// The ready state of the living chat header. Uses atmospheric presence
/// indicators and seamless expansion instead of compartmentalized sections.
@available(iOS 17.0, *)
internal struct SpearReadyHeader<AvatarContent: View>: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.colorScheme) private var colorScheme

  let model: SpearChatHeaderModel
  let style: SpearChatHeaderStyle
  let copy: SpearChatHeaderCopy
  let actions: SpearChatHeaderActions
  let avatarContent: AvatarContent

  @State private var isExpanded = false
  @State private var actionFeedback = 0

  var body: some View {
    VStack(spacing: 0) {
      topSection

      if isExpanded && canExpand {
        SpearIdentityExpansion(
          trust: model.trust,
          metrics: model.metrics,
          copy: copy,
          brandColor: style.brandColor,
          profileAction: actionWithFeedback(actions.profile),
          safetyAction: actionWithFeedback(actions.safety)
        )
      }

      if let context = model.context {
        SpearContextRail(
          context: context,
          brandColor: style.brandColor,
          cornerRadius: style.cornerRadius,
          action: contextActionWithFeedback
        )
        .padding(.horizontal, style.horizontalPadding)
        .padding(.bottom, 10)
        .transition(
          reduceMotion
            ? .opacity
            : .asymmetric(
              insertion: .opacity.combined(with: .scale(scale: 0.97, anchor: .top)),
              removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
            )
        )
        .animation(
          reduceMotion ? nil : .smooth(duration: 0.32),
          value: context.id
        )
      }
    }
    .sensoryFeedback(.selection, trigger: isExpanded)
    .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: actionFeedback)
  }

  // MARK: - Top Section

  @ViewBuilder
  private var topSection: some View {
    if dynamicTypeSize.isAccessibilitySize {
      compactLayout
    } else {
      ViewThatFits(in: .horizontal) {
        regularLayout.frame(minWidth: 350)
        compactLayout
      }
    }
  }

  // MARK: - Regular Layout (floating capsule actions)

  private var regularLayout: some View {
    HStack(spacing: 10) {
      backButton
      identityButton(compact: false)
      Spacer(minLength: 4)
      actionCapsule
    }
    .padding(.horizontal, style.horizontalPadding)
    .padding(.top, 10)
    .padding(.bottom, 10)
  }

  // MARK: - Compact Layout

  private var compactLayout: some View {
    VStack(spacing: 8) {
      HStack(spacing: 10) {
        backButton
        identityButton(compact: true)
      }

      if actions.call.isVisible || actions.more.availability.isVisible {
        HStack(spacing: 8) {
          compactCallButton
          compactMoreButton
        }
        .padding(.leading, 52)
      }
    }
    .padding(.horizontal, style.horizontalPadding)
    .padding(.top, 10)
    .padding(.bottom, 10)
  }

  // MARK: - Action Capsule (floating pill with grouped actions)

  private var actionCapsule: some View {
    HStack(spacing: 2) {
      SpearHeaderCapsuleButton(
        systemName: callSystemName,
        accessibilityLabel: callAccessibilityLabel,
        accessibilityIdentifier: SpearChatHeaderAccessibilityID.call,
        action: callActionWithFeedback,
        tint: actions.call.isActive ? .red : .primary,
        isActive: actions.call.isActive
      )

      SpearHeaderCapsuleButton(
        systemName: "ellipsis",
        accessibilityLabel: copy.moreAccessibilityLabel,
        accessibilityIdentifier: SpearChatHeaderAccessibilityID.more,
        action: actionWithFeedback(actions.more),
        tint: .primary,
        isActive: false
      )
    }
    .padding(4)
    .background {
      Capsule(style: .continuous)
        .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
    }
  }

  // MARK: - Buttons

  private var backButton: some View {
    SpearHeaderIconActionButton(
      systemName: model.isModal ? "xmark" : "chevron.backward",
      accessibilityLabel: copy.backAccessibilityLabel,
      accessibilityIdentifier: SpearChatHeaderAccessibilityID.back,
      action: .enabled(performBack)
    )
  }

  private func identityButton(compact: Bool) -> some View {
    SpearIdentityButton(
      model: model,
      avatarContent: avatarContent,
      brandColor: style.brandColor,
      copy: copy,
      call: actions.call,
      motionMode: SpearMotionMode(presence: model.presence, call: actions.call),
      isExpanded: isExpanded,
      canExpand: canExpand,
      compact: compact,
      action: toggleExpansion
    )
    .layoutPriority(1)
  }

  private var compactCallButton: some View {
    SpearHeaderLabeledActionButton(
      title: actions.call.isActive
        ? copy.endCallAccessibilityLabel
        : copy.callButtonTitle,
      systemName: callSystemName,
      accessibilityLabel: callAccessibilityLabel,
      accessibilityIdentifier: SpearChatHeaderAccessibilityID.call,
      action: callActionWithFeedback,
      tint: actions.call.isActive ? .red : .primary
    )
  }

  private var compactMoreButton: some View {
    SpearHeaderLabeledActionButton(
      title: copy.moreButtonTitle,
      systemName: "ellipsis.circle",
      accessibilityLabel: copy.moreAccessibilityLabel,
      accessibilityIdentifier: SpearChatHeaderAccessibilityID.more,
      action: actionWithFeedback(actions.more)
    )
  }

  // MARK: - Computed Properties

  private var callSystemName: String {
    actions.call.isActive ? "phone.down.fill" : "phone.fill"
  }

  private var callAccessibilityLabel: String {
    actions.call.isActive
      ? copy.endCallAccessibilityLabel
      : copy.startCallAccessibilityLabel
  }

  private var callActionWithFeedback: SpearHeaderAction {
    actionWithFeedback(actions.call.buttonAction)
  }

  private var canExpand: Bool {
    model.trust.detailText != nil
      || !model.metrics.isEmpty
      || actions.profile.availability.isVisible
      || actions.safety.availability.isVisible
  }

  private var contextActionWithFeedback: SpearContextHeaderAction {
    SpearContextHeaderAction(
      availability: actions.context.availability
    ) { context in
      guard actions.context.availability.isEnabled else { return }
      actionFeedback += 1
      actions.context.perform(context)
    }
  }

  // MARK: - Actions

  private func actionWithFeedback(_ action: SpearHeaderAction) -> SpearHeaderAction {
    SpearHeaderAction(availability: action.availability) {
      guard action.availability.isEnabled else { return }
      actionFeedback += 1
      action.perform()
    }
  }

  private func performBack() {
    actionFeedback += 1
    actions.onBack()
  }

  private func toggleExpansion() {
    guard canExpand else { return }

    if reduceMotion {
      isExpanded.toggle()
    } else {
      withAnimation(.smooth(duration: 0.38, extraBounce: 0.02)) {
        isExpanded.toggle()
      }
    }
  }
}
