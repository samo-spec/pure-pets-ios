import SwiftUI

@available(iOS 17.0, *)
internal struct SpearIdentityExpansion: View {
  let trust: SpearTrustState
  let metrics: [SpearIdentityMetric]
  let copy: SpearChatHeaderCopy
  let profileAction: SpearHeaderAction
  let safetyAction: SpearHeaderAction

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(spacing: 12) {
      trustDetail

      if !metrics.isEmpty {
        metricsLayout
      }

      actionsLayout
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 12)
    .transition(
      reduceMotion
        ? .opacity
        : .opacity.combined(with: .move(edge: .top))
    )
  }

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
        SpearMetricView(metric: metric)

        if index < metrics.count - 1 {
          Divider().frame(height: 34)
        }
      }
    }
    .padding(.vertical, 2)
  }

  private var verticalMetrics: some View {
    VStack(spacing: 8) {
      ForEach(metrics) { metric in
        SpearMetricRow(metric: metric)
      }
    }
  }

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

internal struct SpearMetricView: View {
  let metric: SpearIdentityMetric

  var body: some View {
    VStack(spacing: 2) {
      Text(metric.value)
        .font(.subheadline.weight(.semibold))
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
