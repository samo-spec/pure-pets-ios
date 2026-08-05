import SwiftUI

struct TextMessageView: View {
  let payload: TextPayload

  var body: some View {
    Text(payload.text)
      .font(.body)
      .foregroundStyle(.primary)
      .textSelection(.enabled)
      .accessibilityTextContentType(.messaging)
  }
}
