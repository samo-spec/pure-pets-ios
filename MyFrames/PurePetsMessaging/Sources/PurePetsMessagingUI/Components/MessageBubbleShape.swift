import SwiftUI

struct MessageBubbleShape: Shape {
  let isOutgoing: Bool
  let groupPosition: MessageGroupPosition

  func path(in rect: CGRect) -> Path {
    let large: CGFloat = 20
    let small: CGFloat = groupPosition == .isolated || groupPosition == .last ? 6 : 14

    let radii = RectangleCornerRadii(
      topLeading: large,
      bottomLeading: isOutgoing ? large : small,
      bottomTrailing: isOutgoing ? small : large,
      topTrailing: large
    )

    return UnevenRoundedRectangle(cornerRadii: radii, style: .continuous)
      .path(in: rect)
  }
}
