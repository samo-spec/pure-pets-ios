import SwiftUI
import UIKit

// MARK: - Context Rail (Seamless Integration)

/// Context rail that continues the identity header instead of introducing a
/// second card. The media/symbol is the visual anchor; metadata and the action
/// share one reading line beneath a quiet separator.
@available(iOS 17.0, *)
internal struct SpearContextRail: View {
  let context: SpearConversationContext
  let brandColor: Color
  let mainBackgroundColor: Color
  let cornerRadius: CGFloat
  let action: SpearContextHeaderAction
  let thumbnail: (URL) -> AnyView

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Group {
      if context.isSupport {
        // Support status belongs to the conversation's live header, not a
        // second competing card. This keeps its state legible while giving
        // the transcript back its vertical room.
        supportRail
      } else {
        SpearHeaderDeck(
          brandColor: brandColor,
          mainBackgroundColor: mainBackgroundColor,
          cornerRadius: cornerRadius,
          horizontalPadding: 10,
          verticalPadding: 9
        ) {
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
      }
    }
    .animation(contextMotion, value: context.contentTransitionIdentity)
  }

  // MARK: - Layouts

  private var horizontalLayout: some View {
    HStack(spacing: 11) {
      contextVisual
      contextText
      contextAction
    }
  }

  private var supportRail: some View {
    Group {
      if dynamicTypeSize.isAccessibilitySize {
        supportAccessibilityLayout
      } else {
        supportLayout
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background {
      if reduceTransparency {
        mainBackgroundColor
      } else {
        LinearGradient(
          colors: [
            brandColor.opacity(colorScheme == .dark ? 0.075 : 0.045),
            .clear,
          ],
          startPoint: .leading,
          endPoint: .trailing
        )
      }
    }
    .overlay(alignment: .bottom) {
      LinearGradient(
        colors: [
          .clear,
          Color.primary.opacity(contrast == .increased ? 0.24 : 0.08),
          .clear,
        ],
        startPoint: .leading,
        endPoint: .trailing
      )
      .frame(height: contrast == .increased ? 1.5 : 0.75)
    }
    .overlay(alignment: .leading) {
      Capsule(style: .continuous)
        .fill(brandColor.opacity(contrast == .increased ? 0.92 : 0.70))
        .frame(width: contrast == .increased ? 3.5 : 2.5, height: 28)
        .accessibilityHidden(true)
    }
  }

  private var supportLayout: some View {
    HStack(spacing: 9) {
      supportVisual

      Text(context.detail)
        .font(Font.ppBeirutiMedium(size: 13, relativeTo: .subheadline))
        .foregroundStyle(.secondary)
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)

      contextAction
    }
    .frame(minHeight: 36)
    .accessibilityElement(children: .contain)
  }

  private var supportAccessibilityLayout: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        supportVisual

        Text(context.detail)
          .font(Font.ppBeirutiMedium(size: 13, relativeTo: .subheadline))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      contextAction
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .accessibilityElement(children: .contain)
  }

  private var supportVisual: some View {
    ZStack {
      Circle()
        .fill(brandColor.opacity(colorScheme == .dark ? 0.16 : 0.09))
      Image(systemName: context.symbolSystemName)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(brandColor)
    }
    .frame(width: 30, height: 30)
    .accessibilityHidden(true)
  }

  private var verticalLayout: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        contextVisual
        contextText
      }

      contextAction
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
  }

  // MARK: - Symbol

  @ViewBuilder
  private var contextVisual: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(brandColor.opacity(colorScheme == .dark ? 0.13 : 0.07))

      Image(systemName: context.symbolSystemName)
        .font(.body.weight(.semibold))
        .foregroundStyle(brandColor)

      if let thumbnailURL = context.listingThumbnailURL {
        thumbnail(thumbnailURL)
      }
    }
    .frame(width: 46, height: 46)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(
          brandColor.opacity(contrast == .increased ? 0.30 : 0.12),
          lineWidth: contrast == .increased ? 1.5 : 0.7
        )
    }
    .accessibilityHidden(true)
  }

  // MARK: - Text

  private var contextText: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(context.eyebrow)
        .font(Font.ppBeirutiMedium(size: 12, relativeTo: .caption))
        .foregroundStyle(.secondary)

      Text(context.title)
        .font(Font.ppBeirutiSemiBold(size: 14, relativeTo: .subheadline))
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)

      if !context.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Text(context.detail)
          .font(Font.ppBeirutiRegular(size: 12, relativeTo: .caption))
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }

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

  private var contextMotion: Animation? {
    if reduceMotion { return nil }
    return SpearHeaderMotion.liveIndicator
  }
}
