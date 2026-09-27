import SwiftUI

// MARK: - Identity Expansion

/// Inline identity utility rail. It deliberately avoids nesting another card
/// under the navigation header: trust, metrics, and actions remain part of the
/// same conversation hierarchy.
@available(iOS 15.0, *)
internal struct SpearIdentityExpansion: View {
  let trust: SpearTrustState
  let metrics: [SpearIdentityMetric]
  let copy: SpearChatHeaderCopy
  let brandColor: Color
  let showsTrustDetail: Bool
  let profileAction: SpearHeaderAction
  let safetyAction: SpearHeaderAction

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    contentStack
      .padding(.vertical, 4)
  }

  private var contentStack: some View {
    VStack(spacing: 12) {
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
      if trust.isVerified {
        HStack(spacing: 8) {
          Image(systemName: symbol)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(brandColor)

          Text(detail)
            .font(Font.ppBeirutiSemiBold(size: 13, relativeTo: .caption))
            .foregroundStyle(.primary)

          Spacer(minLength: 4)

          HStack(spacing: 4) {
            Image(systemName: "lock.shield.fill")
              .font(.system(size: 10))
            Text(Locale.current.languageCode == "ar" ? "قناة آمنة" : "Secure Channel")
              .font(Font.ppBeirutiMedium(size: 11, relativeTo: .caption2))
          }
          .foregroundStyle(SpearHeaderSemanticColor.live)
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(SpearHeaderSemanticColor.live.opacity(0.12), in: Capsule())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
          Color(uiColor: .secondarySystemGroupedBackground).opacity(0.88),
          in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .accessibilityHidden(true)
      } else {
        Label(detail, systemImage: symbol)
          .font(Font.ppBeirutiMedium(size: 12, relativeTo: .caption))
          .foregroundStyle(trust.isRestricted ? SpearHeaderSemanticColor.warning : Color.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityHidden(true)
      }
    }
  }

  // MARK: - Metrics

  @ViewBuilder
  private var metricsLayout: some View {
    if dynamicTypeSize.isAccessibilitySize {
      verticalMetrics
    } else {
      if #available(iOS 16.0, *) {
        ViewThatFits(in: .horizontal) {
          horizontalMetrics.frame(minWidth: 300)
          verticalMetrics
        }
      } else {
        horizontalMetrics
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
        if #available(iOS 16.0, *) {
          ViewThatFits(in: .horizontal) {
            horizontalActions.frame(minWidth: 270)
            verticalActions
          }
        } else {
          horizontalActions
        }
      }
    }
  }

  private var horizontalActions: some View {
    HStack(spacing: 8) {
      profileButton
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
        HStack(spacing: 8) {
          Image(systemName: systemName)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
          Text(title)
            .font(Font.ppBeirutiSemiBold(size: 15, relativeTo: .subheadline))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
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
  @Environment(\.colorSchemeContrast) private var contrast

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(configuration.isPressed ? brandColor : Color.primary)
      .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .background(
        configuration.isPressed
          ? brandColor.opacity(0.10)
          : Color(uiColor: .secondarySystemGroupedBackground).opacity(0.92),
        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .strokeBorder(
            LinearGradient(
              colors: [
                Color.white.opacity(contrast == .increased ? 0.40 : 0.20),
                Color.primary.opacity(contrast == .increased ? 0.24 : 0.06)
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: contrast == .increased ? 1.5 : 0.75
          )
      }
      .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1.5)
      .opacity(configuration.isPressed ? 0.84 : 1)
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
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
      if #available(iOS 16.0, *) {
        Text(metric.value)
          .font(Font.ppBeirutiBold(size: 14, relativeTo: .subheadline))
          .foregroundStyle(.primary)
          .contentTransition(.numericText())
      } else {
        Text(metric.value)
          .font(Font.ppBeirutiBold(size: 14, relativeTo: .subheadline))
          .foregroundStyle(.primary)
      }

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
