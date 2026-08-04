import SwiftUI

struct PPPromoCardBackground: View {
  let startColor: Color
  let endColor: Color
  let accentColor: Color

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          startColor.opacity(0.20),
          PPPromoTheme.elevatedSurface,
          endColor.opacity(0.14),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      Circle()
        .fill(startColor.opacity(0.13))
        .frame(width: 190, height: 190)
        .blur(radius: 2)
        .offset(x: -150, y: 120)

      Circle()
        .fill(endColor.opacity(0.12))
        .frame(width: 160, height: 160)
        .offset(x: 155, y: -120)

      RoundedRectangle(cornerRadius: 54, style: .continuous)
        .stroke(accentColor.opacity(0.26), lineWidth: 5)
        .frame(width: 155, height: 155)
        .rotationEffect(.degrees(8))
        .offset(x: 94, y: -2)

      Path { path in
        path.move(to: CGPoint(x: 0, y: 250))
        path.addCurve(
          to: CGPoint(x: 420, y: 220),
          control1: CGPoint(x: 110, y: 182),
          control2: CGPoint(x: 260, y: 304)
        )
      }
      .stroke(startColor.opacity(0.11), lineWidth: 22)
    }
    .clipped()
    .accessibilityHidden(true)
  }
}
