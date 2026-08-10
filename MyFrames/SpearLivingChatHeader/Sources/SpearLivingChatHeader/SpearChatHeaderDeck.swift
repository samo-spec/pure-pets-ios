import SwiftUI

// MARK: - Conversation Deck

/// A bounded semantic surface beneath the fixed identity row. Context and
/// identity utilities use the same treatment while retaining independent state.
@available(iOS 17.0, *)
internal struct SpearHeaderDeck<Content: View>: View {
  let brandColor: Color
  let mainBackgroundColor: Color
  let cornerRadius: CGFloat
  let horizontalPadding: CGFloat
  let verticalPadding: CGFloat
  let content: Content

  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.colorSchemeContrast) private var contrast

  init(
    brandColor: Color,
    mainBackgroundColor: Color,
    cornerRadius: CGFloat,
    horizontalPadding: CGFloat = 12,
    verticalPadding: CGFloat = 9,
    @ViewBuilder content: () -> Content
  ) {
    self.brandColor = brandColor
    self.mainBackgroundColor = mainBackgroundColor
    self.cornerRadius = cornerRadius
    self.horizontalPadding = horizontalPadding
    self.verticalPadding = verticalPadding
    self.content = content()
  }

  var body: some View {
    content
      .padding(.horizontal, horizontalPadding)
      .padding(.vertical, verticalPadding)
      .background {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(mainBackgroundColor)
          .overlay {
            if !reduceTransparency {
              LinearGradient(
                colors: [
                  brandColor.opacity(colorScheme == .dark ? 0.055 : 0.035),
                  Color.primary.opacity(colorScheme == .dark ? 0.035 : 0.018),
                  .clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
              .clipShape(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
              )
            }
          }
      }
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .strokeBorder(
            Color.primary.opacity(contrast == .increased ? 0.28 : 0.09),
            lineWidth: contrast == .increased ? 1.5 : 0.75
          )
      }
      .overlay(alignment: .leading) {
        Capsule(style: .continuous)
          .fill(brandColor.opacity(contrast == .increased ? 0.92 : 0.68))
          .frame(width: contrast == .increased ? 3.5 : 2.5)
          .padding(.vertical, 11)
          .padding(.leading, 2)
          .accessibilityHidden(true)
      }
  }
}
