import SwiftUI

// MARK: - Ready Conversation Header

/// Identity anchors one reading column. Context stays mounted while utilities
/// disclose in that column, preserving both the route and transcript anchors.
@available(iOS 15.0, *)
internal struct SpearReadyHeader<AvatarContent: View>: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
    .spearSensoryFeedback(trigger: isExpanded)
    .onChange(of: canExpand) { available in
      if !available && isExpanded {
        setExpansion(false)
      }
    }
  }

  // MARK: - Top Section

  @ViewBuilder
  private var topSection: some View {
    if dynamicTypeSize.isAccessibilitySize {
      accessibilityLayout
    } else {
      if #available(iOS 16.0, *) {
        ViewThatFits(in: .horizontal) {
          regularLayout.frame(minWidth: regularMinimumWidth)
          compactLayout
        }
      } else {
        compactLayout
      }
    }
  }

  // MARK: - Subordinate Conversation Content

  @ViewBuilder
  private var subordinateContent: some View {
    if hasSubordinateContent {
      SpearHeaderDeck(mainBackgroundColor: style.mainBackgroundColor) {
        if dynamicTypeSize.isAccessibilitySize {
          // Context and utilities share a single scroll owner at AX sizes.
          ScrollView(.vertical) {
            subordinateLayout
          }
          .frame(maxHeight: SpearHeaderLayout.accessibilityExpansionMaximumHeight)
        } else {
          subordinateLayout
        }
      }
      .padding(
        .leading,
        dynamicTypeSize.isAccessibilitySize ? 0 : SpearHeaderLayout.conversationLeadingInset
      )
      .padding(.horizontal, style.horizontalPadding)
      .padding(.bottom, SpearHeaderLayout.deckSpacing)
    }
  }

  private var subordinateLayout: some View {
    VStack(spacing: SpearHeaderLayout.deckSpacing) {
      if let context = model.context {
        SpearContextRail(
          context: context,
          brandColor: style.brandColor,
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
          showsTrustDetail: showsTrustDetail,
          profileAction: actions.profile,
          safetyAction: actions.safety
        )
        .transition(expansionTransition)
      }
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
    return .opacity.combined(with: .offset(y: -4))
  }

  // MARK: - Regular Layout

  private var regularLayout: some View {
    HStack(spacing: SpearHeaderLayout.topRowSpacing) {
      backButton
      identityButton
      toolbarActions
    }
    .padding(.horizontal, style.horizontalPadding)
    .padding(.vertical, 8)
  }

  // MARK: - Compact Layout

  private var compactLayout: some View {
    VStack(spacing: 4) {
      HStack(spacing: SpearHeaderLayout.topRowSpacing) {
        backButton
        identityButton
      }

      if actions.call.isVisible || actions.more.availability.isVisible {
        HStack(spacing: 8) {
          compactCallButton
          compactMoreButton
        }
        .padding(.leading, SpearHeaderLayout.conversationLeadingInset)
      }
    }
    .padding(.horizontal, style.horizontalPadding)
    .padding(.vertical, 8)
  }

  private var accessibilityLayout: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        backButton
        Spacer(minLength: 8)
        toolbarActions
      }
      identityButton
    }
    .padding(.horizontal, style.horizontalPadding)
    .padding(.vertical, 8)
  }

  // MARK: - Toolbar

  @ViewBuilder
  private var toolbarActions: some View {
    if actions.call.isVisible || actions.more.availability.isVisible {
      HStack(spacing: 4) {
        SpearHeaderToolbarButton(
          systemName: callSystemName,
          accessibilityLabel: callAccessibilityLabel,
          accessibilityIdentifier: SpearChatHeaderAccessibilityID.call,
          action: actions.call.buttonAction,
          tint: actions.call.isActive ? .red : .primary,
          isActive: actions.call.isActive
        )

        SpearHeaderToolbarButton(
          systemName: "ellipsis",
          accessibilityLabel: copy.moreAccessibilityLabel,
          accessibilityIdentifier: SpearChatHeaderAccessibilityID.more,
          action: actions.more,
          tint: .primary,
          isActive: false
        )
      }
      .fixedSize(horizontal: true, vertical: false)
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
      action: .enabled(actions.onBack)
    )
    .fixedSize()
  }

  private var identityButton: some View {
    SpearIdentityButton(
      model: model,
      avatarContent: avatarContent,
      brandColor: style.brandColor,
      copy: copy,
      call: actions.call,
      motionMode: SpearMotionMode(presence: model.presence, call: actions.call),
      isExpanded: isExpanded,
      canExpand: canExpand,
      action: toggleExpansion
    )
    .frame(maxWidth: .infinity, alignment: .leading)
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
    (showsTrustDetail && model.trust.detailText != nil)
      || !model.metrics.isEmpty
      || actions.profile.availability.isVisible
      || actions.safety.availability.isVisible
  }

  private var showsTrustDetail: Bool {
    model.context?.isSupport != true || model.trust.isRestricted
  }

  private var regularMinimumWidth: CGFloat {
    actions.call.isVisible && actions.more.availability.isVisible ? 376 : 320
  }

  // MARK: - Actions

  private func toggleExpansion() {
    guard canExpand else { return }
    setExpansion(!isExpanded)
  }

  private func setExpansion(_ nextValue: Bool) {
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

extension View {
  @ViewBuilder
  fileprivate func spearSensoryFeedback(trigger: Bool) -> some View {
    if #available(iOS 17.0, *) {
      self.sensoryFeedback(.selection, trigger: trigger)
    } else {
      self
    }
  }
}
