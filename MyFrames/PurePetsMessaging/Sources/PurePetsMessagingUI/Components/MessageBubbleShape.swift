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

    var path = Path()
    let minX = rect.minX
    let minY = rect.minY
    let maxX = rect.maxX
    let maxY = rect.maxY

    path.move(to: CGPoint(x: minX + topLeading, y: minY))
    path.addLine(to: CGPoint(x: maxX - topTrailing, y: minY))
    if topTrailing > 0 {
      path.addArc(center: CGPoint(x: maxX - topTrailing, y: minY + topTrailing), radius: topTrailing, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
    }
    path.addLine(to: CGPoint(x: maxX, y: maxY - bottomTrailing))
    if bottomTrailing > 0 {
      path.addArc(center: CGPoint(x: maxX - bottomTrailing, y: maxY - bottomTrailing), radius: bottomTrailing, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
    }
    path.addLine(to: CGPoint(x: minX + bottomLeading, y: maxY))
    if bottomLeading > 0 {
      path.addArc(center: CGPoint(x: minX + bottomLeading, y: maxY - bottomLeading), radius: bottomLeading, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
    }
    path.addLine(to: CGPoint(x: minX, y: minY + topLeading))
    if topLeading > 0 {
      path.addArc(center: CGPoint(x: minX + topLeading, y: minY + topLeading), radius: topLeading, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
    }
    path.closeSubpath()
    return path
  }
}
