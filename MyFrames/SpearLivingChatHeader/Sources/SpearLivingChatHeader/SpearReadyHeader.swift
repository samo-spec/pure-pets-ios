import SwiftUI

@available(iOS 17.0, *)
internal struct SpearReadyHeader<AvatarContent: View>: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
            : .opacity.combined(with: .move(edge: .top))
        )
        .animation(
          reduceMotion ? nil : .smooth(duration: 0.28),
          value: context.id
        )
      }
    }
    .sensoryFeedback(.selection, trigger: isExpanded)
    .sensoryFeedback(.impact, trigger: actionFeedback)
  }

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

  private var regularLayout: some View {
    HStack(spacing: 8) {
      backButton
      identityButton(compact: false)
      regularActionCluster
    }
    .padding(.horizontal, style.horizontalPadding)
    .padding(.top, 10)
    .padding(.bottom, 8)
  }

  private var compactLayout: some View {
    VStack(spacing: 8) {
      HStack(spacing: 8) {
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
    .padding(.bottom, 8)
  }

  private var backButton: some View {
    SpearHeaderIconActionButton(
      systemName: "chevron.backward",
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

  private var regularActionCluster: some View {
    HStack(spacing: 8) {
      SpearHeaderIconActionButton(
        systemName: callSystemName,
        accessibilityLabel: callAccessibilityLabel,
        accessibilityIdentifier: SpearChatHeaderAccessibilityID.call,
        action: callActionWithFeedback,
        tint: actions.call.isActive ? .red : .primary
      )

      SpearHeaderIconActionButton(
        systemName: "ellipsis",
        accessibilityLabel: copy.moreAccessibilityLabel,
        accessibilityIdentifier: SpearChatHeaderAccessibilityID.more,
        action: actionWithFeedback(actions.more)
      )
    }
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
      withAnimation(.snappy(duration: 0.34, extraBounce: 0.04)) {
        isExpanded.toggle()
      }
    }
  }
}
