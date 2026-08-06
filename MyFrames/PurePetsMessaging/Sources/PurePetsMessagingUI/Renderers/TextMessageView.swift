import SwiftUI

struct TextMessageView: View {
  let payload: TextPayload
  @Environment(\.layoutDirection) private var fallbackLayoutDirection

  var body: some View {
    Text(payload.text)
      .font(Font.ppBeirutiRegular(size: 16, relativeTo: .body))
      .foregroundStyle(.primary)
      .multilineTextAlignment(.leading)
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
