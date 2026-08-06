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
  let action: SpearContextHeaderAction
  let thumbnail: (URL) -> AnyView

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Group {
      if context.isSupport {
        supportLayout
      } else if dynamicTypeSize.isAccessibilitySize {
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
    .background {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(
          colorScheme == .dark
            ? Color.white.opacity(0.055)
            : Color.white.opacity(0.54)
        )
        .overlay {
          LinearGradient(
            colors: [
              Color.white.opacity(colorScheme == .dark ? 0.035 : 0.50),
              .clear,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
          .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(
          brandColor.opacity(contrast == .increased ? 0.30 : 0.12),
          lineWidth: contrast == .increased ? 1.5 : 0.75
        )
    }
    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.13 : 0.045), radius: 12, y: 5)
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

  private var supportLayout: some View {
    HStack(spacing: 10) {
      ZStack {
        Circle()
          .fill(brandColor.opacity(colorScheme == .dark ? 0.16 : 0.09))
        Image(systemName: context.symbolSystemName)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(brandColor)
      }
      .frame(width: 38, height: 38)
      .accessibilityHidden(true)

      Text(context.detail)
        .font(Font.ppBeirutiMedium(size: 13, relativeTo: .subheadline))
        .foregroundStyle(.secondary)
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
        .frame(maxWidth: .infinity, alignment: .leading)

      contextAction
    }
    .accessibilityElement(children: .contain)
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
        .lineLimit(1)

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
    return .smooth(duration: 0.28)
  }
}
