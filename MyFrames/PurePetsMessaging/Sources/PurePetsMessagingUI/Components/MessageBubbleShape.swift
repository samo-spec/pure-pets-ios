import SwiftUI

public struct MessageBubbleShape: Shape {
  public let isOutgoing: Bool
  public let groupPosition: MessageGroupPosition

  public init(isOutgoing: Bool, groupPosition: MessageGroupPosition) {
    self.isOutgoing = isOutgoing
    self.groupPosition = groupPosition
  }

  public func path(in rect: CGRect) -> Path {
    let exposed: CGFloat = 20
    let joined: CGFloat = 8
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

    var path = Path()
    let minX = rect.minX
    let minY = rect.minY
    let maxX = rect.maxX
    let maxY = rect.maxY

    // Start at top leading corner after radius
    path.move(to: CGPoint(x: minX + topLeading, y: minY))

    // Top edge to top trailing
    path.addLine(to: CGPoint(x: maxX - topTrailing, y: minY))
    if topTrailing > 0 {
      addContinuousCorner(
        to: &path,
        corner: CGPoint(x: maxX, y: minY),
        from: CGPoint(x: maxX - topTrailing, y: minY),
        target: CGPoint(x: maxX, y: minY + topTrailing),
        radius: topTrailing
      )
    }

    // Right edge to bottom trailing
    path.addLine(to: CGPoint(x: maxX, y: maxY - bottomTrailing))
    if bottomTrailing > 0 {
      addContinuousCorner(
        to: &path,
        corner: CGPoint(x: maxX, y: maxY),
        from: CGPoint(x: maxX, y: maxY - bottomTrailing),
        target: CGPoint(x: maxX - bottomTrailing, y: maxY),
        radius: bottomTrailing
      )
    }

    // Bottom edge to bottom leading
    path.addLine(to: CGPoint(x: minX + bottomLeading, y: maxY))
    if bottomLeading > 0 {
      addContinuousCorner(
        to: &path,
        corner: CGPoint(x: minX, y: maxY),
        from: CGPoint(x: minX + bottomLeading, y: maxY),
        target: CGPoint(x: minX, y: maxY - bottomLeading),
        radius: bottomLeading
      )
    }

    // Left edge to top leading
    path.addLine(to: CGPoint(x: minX, y: minY + topLeading))
    if topLeading > 0 {
      addContinuousCorner(
        to: &path,
        corner: CGPoint(x: minX, y: minY),
        from: CGPoint(x: minX, y: minY + topLeading),
        target: CGPoint(x: minX + topLeading, y: minY),
        radius: topLeading
      )
    }

    path.closeSubpath()
    return path
  }

  /// Adds a smooth super-ellipse (squircle) corner using cubic Bézier curves
  private func addContinuousCorner(
    to path: inout Path,
    corner: CGPoint,
    from: CGPoint,
    target: CGPoint,
    radius: CGFloat
  ) {
    let k: CGFloat = 0.552284749831
    let c1 = CGPoint(
      x: from.x + (corner.x - from.x) * k,
      y: from.y + (corner.y - from.y) * k
    )
    let c2 = CGPoint(
      x: target.x + (corner.x - target.x) * k,
      y: target.y + (corner.y - target.y) * k
    )
    path.addCurve(to: target, control1: c1, control2: c2)
  }
}
