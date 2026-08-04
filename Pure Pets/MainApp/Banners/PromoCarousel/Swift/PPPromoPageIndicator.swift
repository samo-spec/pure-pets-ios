import SwiftUI

struct PPPromoPageIndicator: View {
  let count: Int
  @Binding var selection: Int

  @Namespace private var indicatorNamespace

  var body: some View {
    HStack(spacing: 10) {
      ForEach(0..<count, id: \.self) { index in
        Button {
          selection = index
        } label: {
          ZStack {
            Capsule()
              .fill(Color.secondary.opacity(0.20))
              .frame(width: index == selection ? 27 : 8, height: 8)

            if index == selection {
              Capsule()
                .fill(Color.secondary.opacity(0.78))
                .frame(width: 27, height: 8)
                .matchedGeometryEffect(id: "pp-promo-indicator", in: indicatorNamespace)
            }
          }
          .frame(minWidth: 12, minHeight: 44)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
          String(
            format: NSLocalizedString("pp_promo_page_format", comment: "Carousel page number"),
            index + 1,
            count
          )
        )
        .accessibilityAddTraits(index == selection ? .isSelected : [])
      }
    }
    .animation(PPPromoTheme.snapAnimation, value: selection)
  }
}
