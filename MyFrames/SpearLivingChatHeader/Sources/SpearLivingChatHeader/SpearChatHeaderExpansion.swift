import SwiftUI

// MARK: - Identity Expansion

/// Inline identity utility rail. It deliberately avoids nesting another card
/// under the navigation header: trust, metrics, and actions remain part of the
/// same conversation hierarchy.
@available(iOS 17.0, *)
internal struct SpearIdentityExpansion: View {
  let trust: SpearTrustState
  let metrics: [SpearIdentityMetric]
  let copy: SpearChatHeaderCopy
  let brandColor: Color
  let mainBackgroundColor: Color
  let showsTrustDetail: Bool
  let profileAction: SpearHeaderAction
  let safetyAction: SpearHeaderAction

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    SpearHeaderDeck(
      brandColor: trust.isRestricted ? SpearHeaderSemanticColor.warning : brandColor,
      mainBackgroundColor: mainBackgroundColor,
      cornerRadius: SpearHeaderLayout.deckCornerRadius
    ) {
      expansionContent
    }
  }

  @ViewBuilder
  private var expansionContent: some View {
    if dynamicTypeSize.isAccessibilitySize {
      ScrollView(.vertical) {
        contentStack
          .frame(maxWidth: .infinity)
      }
      .frame(maxHeight: SpearHeaderLayout.accessibilityExpansionMaximumHeight)
      .scrollIndicators(.visible)
      .scrollBounceBehavior(.basedOnSize)
    } else {
      contentStack
    }
  }

  private var contentStack: some View {
    VStack(spacing: 9) {
      if showsTrustDetail {
        trustDetail
      }

      if !metrics.isEmpty {
        metricsLayout
      }

      actionsLayout
    }
  }

  // MARK: - Trust Detail

  @ViewBuilder
  private var trustDetail: some View {
    if let detail = trust.detailText,
      let symbol = trust.detailSystemName
    {
      Label(detail, systemImage: symbol)
        .font(Font.ppBeirutiMedium(size: 12, relativeTo: .caption))
        .foregroundStyle(trust.isRestricted ? SpearHeaderSemanticColor.warning : Color.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }
  }

  // MARK: - Metrics

  @ViewBuilder
  private var metricsLayout: some View {
    if dynamicTypeSize.isAccessibilitySize {
      verticalMetrics
    } else {
      ViewThatFits(in: .horizontal) {
        horizontalMetrics.frame(minWidth: 300)
        verticalMetrics
      }
    }
  }

  private var horizontalMetrics: some View {
    HStack(spacing: 0) {
      ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
        SpearMetricView(metric: metric, brandColor: brandColor)

        if index < metrics.count - 1 {
          Divider()
            .frame(height: 30)
            .opacity(0.5)
        }
      }
    }
    .padding(.vertical, 4)
  }

  private var verticalMetrics: some View {
    VStack(spacing: 8) {
      ForEach(metrics) { metric in
        SpearMetricRow(metric: metric)
      }
    }
  }

  // MARK: - Actions

  @ViewBuilder
  private var actionsLayout: some View {
    let hasProfile = profileAction.availability.isVisible
    let hasSafety = safetyAction.availability.isVisible

    if hasProfile || hasSafety {
      if dynamicTypeSize.isAccessibilitySize {
        verticalActions
      } else {
        ViewThatFits(in: .horizontal) {
          horizontalActions.frame(minWidth: 270)
          verticalActions
        }
      }
    }
  }

  private var horizontalActions: some View {
    HStack(spacing: 0) {
      profileButton
      if profileAction.availability.isVisible && safetyAction.availability.isVisible {
        Divider()
          .frame(height: 24)
      }
      safetyButton
    }
  }

  private var verticalActions: some View {
    VStack(spacing: 8) {
      profileButton
      safetyButton
    }
  }

  @ViewBuilder
  private var profileButton: some View {
    utilityButton(
      title: copy.profileButtonTitle,
      systemName: "person.crop.circle",
      accessibilityIdentifier: SpearChatHeaderAccessibilityID.profile,
      action: profileAction
    )
  }

  @ViewBuilder
  private var safetyButton: some View {
    utilityButton(
      title: copy.safetyButtonTitle,
      systemName: "shield.lefthalf.filled",
      accessibilityIdentifier: SpearChatHeaderAccessibilityID.safety,
      action: safetyAction
    )
  }

  @ViewBuilder
  private func utilityButton(
    title: String,
    systemName: String,
    accessibilityIdentifier: String,
    action: SpearHeaderAction
  ) -> some View {
    if action.availability.isVisible {
      Button {
        guard action.availability.isEnabled else { return }
        action.perform()
      } label: {
        Label(title, systemImage: systemName)
          .font(Font.ppBeirutiSemiBold(size: 14, relativeTo: .subheadline))
          .frame(maxWidth: .infinity)
          .frame(minHeight: 44)
      }
      .buttonStyle(SpearIdentityUtilityButtonStyle(brandColor: brandColor))
      .hoverEffect(.highlight)
      .disabled(!action.availability.isEnabled)
      .opacity(action.availability.isEnabled ? 1 : 0.56)
      .accessibilityIdentifier(accessibilityIdentifier)
      .modifier(
        SpearDisabledReasonModifier(
          reason: action.availability.disabledReason
        )
      )
    }
  }
}

private struct SpearIdentityUtilityButtonStyle: ButtonStyle {
  let brandColor: Color

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(configuration.isPressed ? brandColor : Color.primary)
      .contentShape(Rectangle())
      .background(
        configuration.isPressed ? brandColor.opacity(0.07) : .clear,
        in: Capsule(style: .continuous)
      )
      .opacity(configuration.isPressed ? 0.82 : 1)
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
      .animation(
        reduceMotion ? nil : SpearHeaderMotion.press(isPressed: configuration.isPressed),
        value: configuration.isPressed)
  }
}

// MARK: - Metric View (Horizontal)

internal struct SpearMetricView: View {
  let metric: SpearIdentityMetric
  let brandColor: Color

  var body: some View {
    VStack(spacing: 3) {
      Text(metric.value)
        .font(Font.ppBeirutiBold(size: 14, relativeTo: .subheadline))
        .foregroundStyle(.primary)
        .contentTransition(.numericText())

      Text(metric.label)
        .font(Font.ppBeirutiRegular(size: 11, relativeTo: .caption2))
        .foregroundStyle(.secondary)
        .lineLimit(2)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .combine)
  }
}

// MARK: - Metric Row (Vertical)

internal struct SpearMetricRow: View {
  let metric: SpearIdentityMetric

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Text(metric.label)
        .font(Font.ppBeirutiRegular(size: 14, relativeTo: .subheadline))
        .foregroundStyle(.secondary)

      Spacer(minLength: 12)

      Text(metric.value)
        .font(Font.ppBeirutiSemiBold(size: 14, relativeTo: .subheadline))
        .multilineTextAlignment(.trailing)
    }
    .frame(minHeight: 44)
    .accessibilityElement(children: .combine)
  }
}
