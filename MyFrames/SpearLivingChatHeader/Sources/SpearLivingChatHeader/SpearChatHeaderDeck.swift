import SwiftUI

// MARK: - Conversation Deck

/// A full-width typographic handoff below the participant crown.
@available(iOS 15.0, *)
internal struct SpearHeaderDeck<Content: View>: View {
  let mainBackgroundColor: Color
  let horizontalPadding: CGFloat
  let verticalPadding: CGFloat
  let content: Content

  @Environment(\.colorSchemeContrast) private var contrast

  init(
    mainBackgroundColor: Color,
    horizontalPadding: CGFloat = 0,
    verticalPadding: CGFloat = 2,
    @ViewBuilder content: () -> Content
  ) {
    self.mainBackgroundColor = mainBackgroundColor
    self.horizontalPadding = horizontalPadding
    self.verticalPadding = verticalPadding
    self.content = content()
  }

  var body: some View {
    content
      .padding(.horizontal, horizontalPadding)
      .padding(.vertical, verticalPadding)
      .background(mainBackgroundColor)
      .overlay(alignment: .top) {
        Color.primary.opacity(contrast == .increased ? 0.24 : 0.08)
          .frame(height: contrast == .increased ? 1.5 : 0.5)
          .accessibilityHidden(true)
      }
  }
}
