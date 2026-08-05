import SwiftUI

struct TextMessageView: View {
  let payload: TextPayload

  var body: some View {
    Text(payload.text)
      .font(Font.ppBeirutiRegular(size: 16, relativeTo: .body))
      .foregroundStyle(.primary)
      .textSelection(.enabled)
      .accessibilityTextContentType(.messaging)
  }
}
