import SwiftUI

// MARK: - Seamless Ready Header

/// The ready state of the living chat header. Uses atmospheric presence
/// indicators and seamless expansion instead of compartmentalized sections.
@available(iOS 17.0, *)
internal struct SpearReadyHeader<AvatarContent: View>: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.colorSchemeContrast) private var contrast

  let model: SpearChatHeaderModel
  let style: SpearChatHeaderStyle
  let copy: SpearChatHeaderCopy
  let actions: SpearChatHeaderActions
  let onExpansionChanged: (Bool) -> Void
  let contextThumbnail: (URL) -> AnyView
  let avatarContent: AvatarContent

  @State private var isExpanded = false

  var body: some View {
    VStack(spacing: 0) {
      topSection
      subordinateContent
    }
    .sensoryFeedback(.selection, trigger: isExpanded)
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

  // MARK: - Subordinate Conversation Content

  @ViewBuilder
  private var subordinateContent: some View {
    if hasSubordinateContent {
      VStack(spacing: SpearHeaderLayout.deckSpacing) {
        if let context = model.context {
          SpearContextRail(
            context: context,
            brandColor: style.brandColor,
            mainBackgroundColor: style.mainBackgroundColor,
            cornerRadius: min(style.cornerRadius, SpearHeaderLayout.deckCornerRadius),
            action: actions.context,
            thumbnail: contextThumbnail
          )
        }

        if showsIdentityExpansion {
          SpearIdentityExpansion(
            trust: model.trust,
            metrics: model.metrics,
            copy: copy,
            brandColor: style.brandColor,
            mainBackgroundColor: style.mainBackgroundColor,
            showsTrustDetail: model.context?.isSupport != true,
            profileAction: actions.profile,
            safetyAction: actions.safety
          )
          .transition(expansionTransition)
        }
      }
      .padding(.horizontal, style.horizontalPadding)
      .padding(.bottom, SpearHeaderLayout.deckSpacing)
    }
  }

  private var showsIdentityExpansion: Bool {
    isExpanded && canExpand
  }

  private var hasSubordinateContent: Bool {
    model.context != nil || showsIdentityExpansion
  }

  private var expansionTransition: AnyTransition {
    if reduceMotion { return .opacity }
    return .asymmetric(
      insertion: .opacity.combined(with: .scale(scale: 0.985, anchor: .top)),
      removal: .opacity.combined(with: .scale(scale: 0.99, anchor: .top))
    )
  }

  // MARK: - Regular Layout

  private var regularLayout: some View {
    HStack(spacing: SpearHeaderLayout.topRowSpacing) {
      backButton
      identityButton(compact: false)
      Spacer(minLength: 2)
      actionCapsule
    }
    .padding(.horizontal, style.horizontalPadding)
    .padding(.top, 8)
    .padding(.bottom, topSectionBottomPadding)
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
    .padding(.top, 8)
    .padding(.bottom, topSectionBottomPadding)
  }

  // MARK: - Action Cluster

  @ViewBuilder
  private var actionCapsule: some View {
    if hasTopActions {
      HStack(spacing: 0) {
        SpearHeaderCapsuleButton(
          systemName: callSystemName,
          accessibilityLabel: callAccessibilityLabel,
          accessibilityIdentifier: SpearChatHeaderAccessibilityID.call,
          action: actions.call.buttonAction,
          tint: actions.call.isActive ? .red : .primary,
          isActive: actions.call.isActive
        )

        if actions.call.isVisible && actions.more.availability.isVisible {
          Divider()
            .frame(height: 20)
            .opacity(contrast == .increased ? 0.72 : 0.42)
        }

        SpearHeaderCapsuleButton(
          systemName: "ellipsis",
          accessibilityLabel: copy.moreAccessibilityLabel,
          accessibilityIdentifier: SpearChatHeaderAccessibilityID.more,
          action: actions.more,
          tint: .primary,
          isActive: false
        )
      }
      .padding(2)
      .background {
        Capsule(style: .continuous)
          .fill(style.mainBackgroundColor)
          .overlay {
            Capsule(style: .continuous)
              .fill(Color.primary.opacity(colorScheme == .dark ? 0.070 : 0.040))
          }
      }
      .overlay {
        Capsule(style: .continuous)
          .strokeBorder(
            Color.primary.opacity(contrast == .increased ? 0.24 : 0.09),
            lineWidth: contrast == .increased ? 1.5 : 0.75
          )
      }
    }
  }

  // MARK: - Buttons

  private var backButton: some View {
    SpearHeaderIconActionButton(
      systemName: model.isModal ? "xmark" : "chevron.backward",
      accessibilityLabel: model.isModal
        ? copy.closeAccessibilityLabel
        : copy.backAccessibilityLabel,
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
      action: actions.call.buttonAction,
      tint: actions.call.isActive ? .red : .primary
    )
  }

  private var compactMoreButton: some View {
    SpearHeaderLabeledActionButton(
      title: copy.moreButtonTitle,
      systemName: "ellipsis.circle",
      accessibilityLabel: copy.moreAccessibilityLabel,
      accessibilityIdentifier: SpearChatHeaderAccessibilityID.more,
      action: actions.more
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

  private var canExpand: Bool {
    model.trust.detailText != nil
      || !model.metrics.isEmpty
      || actions.profile.availability.isVisible
      || actions.safety.availability.isVisible
  }

  private var hasTopActions: Bool {
    actions.call.isVisible || actions.more.availability.isVisible
  }

  private var topSectionBottomPadding: CGFloat {
    model.context == nil ? 9 : 5
  }

  // MARK: - Actions

  private func performBack() {
    actions.onBack()
  }

  private func toggleExpansion() {
    guard canExpand else { return }
    let nextValue = !isExpanded
    onExpansionChanged(nextValue)

    if reduceMotion {
      isExpanded = nextValue
    } else {
      withAnimation(nextValue ? SpearHeaderMotion.deck : SpearHeaderMotion.exit) {
        isExpanded = nextValue
      }
    }
  }
}
