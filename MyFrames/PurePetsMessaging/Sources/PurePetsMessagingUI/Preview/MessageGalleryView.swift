import SwiftUI

public struct MessageGalleryView: View {
  private let header: ChatHeaderPresentation
  private let messages: [ChatMessage]

  @State private var audioCoordinator = ConversationAudioCoordinator()

  public init(
    header: ChatHeaderPresentation = MessageFixtures.header,
    messages: [ChatMessage] = MessageFixtures.all
  ) {
    self.header = header
    self.messages = messages
  }

  public var body: some View {
    VStack(spacing: 0) {
      ChatHeaderView(
        presentation: header,
        onBack: {},
        onOpenDetails: {},
        onOpenContext: {},
        onOpenMore: {}
      )

      ScrollView {
        LazyVStack(spacing: 10) {
          ForEach(messages) { message in
            SmartMessageCell(
              message: message,
              audioCoordinator: audioCoordinator
            )
            .id(message.id)
          }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
      }
      .background(PurePetsMessagingTheme.conversationBackground)
    }
  }
}

#Preview("All payloads") {
  MessageGalleryView()
}

#Preview("Arabic RTL") {
  MessageGalleryView()
    .environment(\.layoutDirection, .rightToLeft)
    .environment(\.locale, Locale(identifier: "ar"))
}

#Preview("Accessibility XL") {
  MessageGalleryView()
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Reduce Motion") {
  MessageGalleryView()
    // .environment(\.accessibilityReduceMotion, true) // Read-only in this SwiftUI version
}
