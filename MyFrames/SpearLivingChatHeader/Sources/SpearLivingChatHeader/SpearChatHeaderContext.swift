import SwiftUI
import UIKit

@available(iOS 17.0, *)
internal struct SpearContextRail: View {
  let context: SpearConversationContext
  let brandColor: Color
  let cornerRadius: CGFloat
  let action: SpearContextHeaderAction

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    .padding(10)
    .background(
      Color(uiColor: .secondarySystemBackground),
      in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .strokeBorder(
          Color.primary.opacity(contrast == .increased ? 0.24 : 0.08),
          lineWidth: contrast == .increased ? 1.5 : 1
        )
    }
  }

  private var horizontalLayout: some View {
    HStack(spacing: 10) {
      contextSymbol
      contextText
      contextAction
    }
  }

  private var verticalLayout: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        contextSymbol
        contextText
      }

      contextAction
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
  }

  @ViewBuilder
  private var contextSymbol: some View {
    let symbol = Image(systemName: context.symbolSystemName)
      .font(.body.weight(.semibold))
      .foregroundStyle(brandColor)
      .frame(width: 44, height: 44)
      .background(
        brandColor.opacity(0.1),
        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
      )
      .accessibilityHidden(true)

    if reduceMotion {
      symbol
    } else {
      symbol.symbolEffect(.bounce, value: context.id)
    }
  }

  private var contextText: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(context.eyebrow)
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)

      Text(context.title)
        .font(.subheadline.weight(.semibold))

      Text(context.detail)
        .font(.caption)
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
