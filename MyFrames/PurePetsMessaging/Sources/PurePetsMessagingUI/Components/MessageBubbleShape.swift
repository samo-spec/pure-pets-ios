import SwiftUI

struct MessageBubbleShape: Shape {
  let isOutgoing: Bool
  let groupPosition: MessageGroupPosition

  func path(in rect: CGRect) -> Path {
    let exposed: CGFloat = 19
    let joined: CGFloat = 8
    let terminal: CGFloat = 10
    let joinsPrevious = groupPosition == .middle || groupPosition == .last
    let joinsNext = groupPosition == .first || groupPosition == .middle

    var topLeading = exposed
    var bottomLeading = exposed
    var bottomTrailing = exposed
    var topTrailing = exposed

    if isOutgoing {
      topTrailing = joinsPrevious ? joined : exposed
      bottomTrailing = joinsNext ? joined : terminal
    } else {
      topLeading = joinsPrevious ? joined : exposed
      bottomLeading = joinsNext ? joined : terminal
    }

    let radii = RectangleCornerRadii(
      topLeading: topLeading,
      bottomLeading: bottomLeading,
      bottomTrailing: bottomTrailing,
      topTrailing: topTrailing
    )

    return UnevenRoundedRectangle(cornerRadii: radii, style: .continuous)
      .path(in: rect)
  }
}
