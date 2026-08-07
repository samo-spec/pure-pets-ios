import SwiftUI

struct MessageBubbleShape: Shape {
  let isOutgoing: Bool
  let groupPosition: MessageGroupPosition

  func path(in rect: CGRect) -> Path {
    let exposed: CGFloat = 22
    let joined: CGFloat = 7
    let terminal: CGFloat = 6
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

    return UnevenRoundedRectangle(
      cornerRadii: RectangleCornerRadii(
        topLeading: topLeading,
        bottomLeading: bottomLeading,
        bottomTrailing: bottomTrailing,
        topTrailing: topTrailing
      ),
      style: .continuous
    )
    .path(in: rect)
  }
}
