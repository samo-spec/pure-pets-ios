import SwiftUI

struct TextMessageView: View {
  let payload: TextPayload

  @Environment(\.layoutDirection) private var fallbackLayoutDirection

  // Stable single-line height: a short one-line message (Arabic or Latin)
  // always fills the same vertical space, so bubbles no longer look cramped
  // or vary by script. Multi-line text naturally exceeds this and is
  // unaffected. Scales with Dynamic Type.
  @ScaledMetric(relativeTo: .body) private var singleLineMinHeight: CGFloat = 26

  var body: some View {
    Text(payload.text)
      .font(Font.ppBeirutiRegular(size: 16.5, relativeTo: .body))
      .foregroundStyle(.primary)
      .multilineTextAlignment(.leading)
      .lineSpacing(1)
      .frame(minHeight: singleLineMinHeight, alignment: .center)
      .environment(\.layoutDirection, resolvedLayoutDirection)
      .textSelection(.enabled)
      .accessibilityTextContentType(.messaging)
  }

  private var resolvedLayoutDirection: LayoutDirection {
    PurePetsMessageTextDirection.resolve(
      payload.text,
      fallback: fallbackLayoutDirection
    )
  }
}
