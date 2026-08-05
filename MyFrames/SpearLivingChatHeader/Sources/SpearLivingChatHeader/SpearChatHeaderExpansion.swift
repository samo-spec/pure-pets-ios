import SwiftUI

// MARK: - Identity Expansion (Frosted Sheet Style)

/// Expansion panel that unfolds as a warm frosted material sheet,
/// extending the gradient atmosphere of the header.
@available(iOS 17.0, *)
internal struct SpearIdentityExpansion: View {
  let trust: SpearTrustState
  let metrics: [SpearIdentityMetric]
  let copy: SpearChatHeaderCopy
  let brandColor: Color
  let profileAction: SpearHeaderAction
  let safetyAction: SpearHeaderAction

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.colorSchemeContrast) private var contrast

  var body: some View {
    VStack(spacing: 12) {
      trustDetail

      if !metrics.isEmpty {
        metricsLayout
      }

      actionsLayout
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .background(expansionBackground)
    .padding(.horizontal, 12)
    .padding(.bottom, 8)
    .transition(
      reduceMotion
        ? .opacity
        : .asymmetric(
          insertion: .opacity
            .combined(with: .scale(scale: 0.96, anchor: .top))
            .combined(with: .offset(y: -6)),
          removal: .opacity
            .combined(with: .scale(scale: 0.98, anchor: .top))
        )
    )
  }

  // MARK: - Frosted Background

  @ViewBuilder
  private var expansionBackground: some View {
    if reduceTransparency {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(Color(uiColor: .secondarySystemGroupedBackground))
        .overlay {
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.primary.opacity(contrast == .increased ? 0.2 : 0.08), lineWidth: 1)
        }
    } else {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay {
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(brandColor.opacity(colorScheme == .dark ? 0.04 : 0.02))
        }
        .overlay {
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(
              Color.primary.opacity(contrast == .increased ? 0.18 : 0.06),
              lineWidth: contrast == .increased ? 1.5 : 0.5
            )
        }
    }
  }

  // MARK: - Trust Detail

  @ViewBuilder
  private var trustDetail: some View {
    if let detail = trust.detailText,
      let symbol = trust.detailSystemName
    {
      Label(detail, systemImage: symbol)
        .font(.caption.weight(.medium))
        .foregroundStyle(trust.isRestricted ? Color.orange : Color.secondary)
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
    SpearTextActionButton(
      title: copy.profileButtonTitle,
      accessibilityIdentifier: SpearChatHeaderAccessibilityID.profile,
      action: profileAction
    )
  }

  @ViewBuilder
  private var safetyButton: some View {
    SpearTextActionButton(
      title: copy.safetyButtonTitle,
      accessibilityIdentifier: SpearChatHeaderAccessibilityID.safety,
      action: safetyAction
    )
  }
}

// MARK: - Metric View (Horizontal)

internal struct SpearMetricView: View {
  let metric: SpearIdentityMetric
  let brandColor: Color

  var body: some View {
    VStack(spacing: 3) {
      Text(metric.value)
        .font(.subheadline.weight(.bold))
        .foregroundStyle(.primary)
        .contentTransition(.numericText())

      Text(metric.label)
        .font(.caption2)
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
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Spacer(minLength: 12)

      Text(metric.value)
        .font(.subheadline.weight(.semibold))
        .multilineTextAlignment(.trailing)
    }
    .frame(minHeight: 44)
    .accessibilityElement(children: .combine)
  }
}
