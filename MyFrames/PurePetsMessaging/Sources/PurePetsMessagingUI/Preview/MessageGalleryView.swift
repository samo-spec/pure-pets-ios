import SwiftUI

public struct MessageGalleryView: View {
  @State private var isArabic: Bool = false
  @State private var audioCoordinator = ConversationAudioCoordinator()
  @State private var selectedReactionMessageID: MessageID?

  private let customHeader: ChatHeaderPresentation?
  private let customMessages: [ChatMessage]?

  public init(
    header: ChatHeaderPresentation? = nil,
    messages: [ChatMessage]? = nil
  ) {
    self.customHeader = header
    self.customMessages = messages
  }

  private var activeHeader: ChatHeaderPresentation {
    if let customHeader { return customHeader }
    return isArabic ? MessageFixtures.arabicHeader : MessageFixtures.header
  }

  private var activeMessages: [ChatMessage] {
    if let customMessages { return customMessages }
    return isArabic ? MessageFixtures.arabicAll : MessageFixtures.all
  }

  public var body: some View {
    VStack(spacing: 0) {
      ChatHeaderView(
        presentation: activeHeader,
        onBack: {},
        onOpenDetails: {},
        onOpenContext: {},
        onOpenMore: {}
      )

      // Workbench Mode Switcher Bar
      HStack(spacing: 8) {
        Button {
          withAnimation(PurePetsMessagingMotion.quick) {
            isArabic.toggle()
          }
        } label: {
          HStack(spacing: 5) {
            Image(systemName: "globe")
              .font(.system(size: 11, weight: .bold))
            Text(isArabic ? "English (LTR)" : "العربية (RTL)")
              .font(Font.ppBeirutiBold(size: 12, relativeTo: .caption))
          }
          .foregroundStyle(PurePetsMessagingTheme.brand)
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(PurePetsMessagingTheme.brandSoft, in: Capsule())
        }
        .buttonStyle(PurePetsMessagingPressButtonStyle())

        Spacer()

        Text("\(activeMessages.count) رسائل")
          .font(Font.ppBeirutiRegular(size: 11.5, relativeTo: .caption2))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 6)
      .background(PurePetsMessagingTheme.surfaceRaised)
      .overlay(alignment: .bottom) {
        Divider().background(PurePetsMessagingTheme.surfaceStroke)
      }

      ScrollView {
        LazyVStack(spacing: 12) {
          ForEach(activeMessages) { message in
            SmartMessageCell(
              message: message,
              audioCoordinator: audioCoordinator,
              actions: SmartMessageCell.Actions(
                onReactionTap: { _ in
                  withAnimation(PurePetsMessagingMotion.springBouncy) {
                    selectedReactionMessageID = selectedReactionMessageID == message.id ? nil : message.id
                  }
                },
                onSelectQuickReaction: { emoji in
                  withAnimation(PurePetsMessagingMotion.springBouncy) {
                    selectedReactionMessageID = nil
                  }
                }
              )
            )
            .id(message.id)
            .overlay(alignment: .top) {
              if selectedReactionMessageID == message.id {
                MessageQuickReactionBar(
                  onSelectEmoji: { _ in
                    withAnimation(PurePetsMessagingMotion.springBouncy) {
                      selectedReactionMessageID = nil
                    }
                  },
                  onDismiss: {
                    withAnimation(PurePetsMessagingMotion.springBouncy) {
                      selectedReactionMessageID = nil
                    }
                  }
                )
                .offset(y: -44)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .zIndex(10)
              }
            }
          }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
      }
      .background(PurePetsMessagingTheme.conversationBackground)
    }
    .environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)
    .environment(\.locale, Locale(identifier: isArabic ? "ar" : "en"))
  }
}

#Preview("All payloads") {
  MessageGalleryView()
}

#Preview("Arabic RTL") {
  MessageGalleryView(
    header: MessageFixtures.arabicHeader,
    messages: MessageFixtures.arabicAll
  )
  .environment(\.layoutDirection, .rightToLeft)
  .environment(\.locale, Locale(identifier: "ar"))
}

#Preview("Accessibility XL") {
  MessageGalleryView()
    .environment(\.dynamicTypeSize, .accessibility3)
}
