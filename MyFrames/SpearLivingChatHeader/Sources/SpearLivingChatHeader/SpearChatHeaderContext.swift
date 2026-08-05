import SwiftUI
import UIKit

// MARK: - Context Rail (Seamless Integration)

/// Context rail that uses subtle brand tinting and refined card treatment
/// to integrate with the dissolving gradient atmosphere.
@available(iOS 17.0, *)
internal struct SpearContextRail: View {
  let context: SpearConversationContext
  let brandColor: Color
  let cornerRadius: CGFloat
  let action: SpearContextHeaderAction

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Group {
      if dynamicTypeSize.isAccessibilitySize {
        verticalLayout
      } else {
        ViewThatFits(in: .horizontal) {
          horizontalLayout
            .frame(minWidth: 340)
          verticalLayout
        }
      }
    }
    .padding(12)
    .background(railBackground)
  }

  // MARK: - Background

  @ViewBuilder
  private var railBackground: some View {
    if reduceTransparency {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(Color(uiColor: .secondarySystemBackground))
        .overlay {
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
              Color.primary.opacity(contrast == .increased ? 0.2 : 0.08),
              lineWidth: contrast == .increased ? 1.5 : 1
            )
        }
    } else {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(
          LinearGradient(
            colors: [
              brandColor.opacity(colorScheme == .dark ? 0.06 : 0.04),
              Color(uiColor: .secondarySystemBackground).opacity(0.8),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .overlay {
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
              brandColor.opacity(contrast == .increased ? 0.2 : 0.08),
              lineWidth: contrast == .increased ? 1.5 : 0.5
            )
        }
    }
  }

  // MARK: - Layouts

  private var horizontalLayout: some View {
    HStack(spacing: 12) {
      contextSymbol
      contextText
      contextAction
    }
  }

  private var verticalLayout: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        contextSymbol
        contextText
      }

      contextAction
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
  }

  // MARK: - Symbol

  @ViewBuilder
  private var contextSymbol: some View {
    let symbol = Image(systemName: context.symbolSystemName)
      .font(.body.weight(.semibold))
      .foregroundStyle(brandColor)
      .frame(width: 40, height: 40)
      .background(
        brandColor.opacity(colorScheme == .dark ? 0.14 : 0.08),
        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
      )
      .accessibilityHidden(true)

    if reduceMotion {
      symbol
    } else {
      symbol.symbolEffect(.bounce, value: context.id)
    }
  }

  // MARK: - Text

  private var contextText: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(context.eyebrow)
        .font(Font.ppBeirutiMedium(size: 12, relativeTo: .caption))
        .foregroundStyle(.secondary)

      Text(context.title)
        .font(Font.ppBeirutiSemiBold(size: 14, relativeTo: .subheadline))

      Text(context.detail)
        .font(Font.ppBeirutiRegular(size: 12, relativeTo: .caption))
        .foregroundStyle(.secondary)

      if let progress = context.orderProgress {
        ProgressView(value: progress)
          .tint(brandColor)
          .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .fixedSize(horizontal: false, vertical: true)
    .accessibilityElement(children: .combine)
  }

  // MARK: - Action

  @ViewBuilder
  private var contextAction: some View {
    SpearContextActionButton(
      title: context.actionTitle,
      brandColor: brandColor,
      context: context,
      action: action
    )
  }
}
