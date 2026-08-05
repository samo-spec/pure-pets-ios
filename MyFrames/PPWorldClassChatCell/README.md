# PP World-Class Expandable Chat Cell

A production SwiftUI chat-inbox component for iOS 16+.

## Interaction contract

- Tap the conversation surface to open the messaging controller.
- Tap only the dedicated chevron control to expand or collapse inline reply.
- Quick replies, text entry, send, and retry never trigger navigation.
- The parent inbox owns navigation and which single conversation is expanded.

## What changed from the original file

- Stable backend `PPConversationID`; no generated row identity.
- Focused Swift package instead of one 1,286-line source file.
- Testable reply state machine with optimistic, sending, sent, failed, and retry transitions.
- Stable quick-reply IDs even when visible titles repeat.
- String Catalog-backed English and Arabic copy, plural unread counts, and localized accessibility states.
- `Date`-based locale-aware timestamps instead of preformatted timestamp strings.
- Product-safe error mapping; raw transport errors never reach the UI.
- Cached, request-coalesced, ImageIO-downsampled avatars.
- Opaque collapsed rows; material is reserved for the expanded state.
- All interactive controls have at least a 44×44-point target.
- Dynamic Type, RTL, VoiceOver, Voice Control identifiers, Reduce Motion, Reduce Transparency, Increased Contrast, and Differentiate Without Color support.
- Optimistic reply preview updates inside the cell immediately, while committed receipts flow back to the parent store.

## Add it to Xcode

1. Unzip the package.
2. In Xcode choose **File → Add Package Dependencies… → Add Local…**.
3. Select the `PPWorldClassChatCell` folder.
4. Add both products to your app target:
   - `PPChatCellCore`
   - `PPChatCellUI`
5. Import both modules where the inbox is implemented.

```swift
import PPChatCellCore
import PPChatCellUI
```

## Production integration

```swift
@State private var expandedConversationID: PPConversationID?

PPExpandableChatCell(
    thread: thread,
    isExpanded: Binding(
        get: { expandedConversationID == thread.id },
        set: { expandedConversationID = $0 ? thread.id : nil }
    ),
    onOpenChat: { conversationID in
        router.push(.conversation(conversationID))
    },
    onOptimisticReply: { message, conversationID in
        outbox.notePending(message, in: conversationID)
    },
    onReplyCommitted: { receipt in
        chatStore.apply(receipt)
    },
    onReplyFailed: { failure, conversationID in
        analytics.recordReplyFailure(failure, conversationID: conversationID)
    },
    sendQuickReply: { message, conversationID in
        try await messagingService.sendQuickReply(
            message,
            conversationID: conversationID
        )
    }
)
```

`sendQuickReply` must return a `PPQuickReplyReceipt` whose `conversationID` matches the requested conversation. Map service errors to `PPQuickReplyFailure` whenever possible.

## Backend model mapping

```swift
let thread = PPChatThreadSnapshot(
    id: PPConversationID(apiConversation.id),
    participantID: apiConversation.otherUser.id,
    displayName: apiConversation.otherUser.displayName,
    avatarURL: apiConversation.otherUser.avatarURL,
    presence: apiConversation.presence,
    lastActivity: .text(
        sender: apiConversation.lastMessage.senderName,
        text: apiConversation.lastMessage.text
    ),
    timestamp: apiConversation.lastMessage.sentAt,
    unreadCount: apiConversation.unreadCount,
    contextText: apiConversation.context,
    quickReplies: apiConversation.suggestions.map {
        PPQuickReply(id: $0.id, title: $0.title, message: $0.message)
    }
)
```

## UIKit inbox bridge

For an existing UIKit list on iOS 16+, host the SwiftUI component with `UIHostingConfiguration`. Keep expansion identity and navigation in the table/collection controller or its view model.

```swift
cell.contentConfiguration = UIHostingConfiguration {
    PPExpandableChatCell(
        thread: thread,
        isExpanded: expansionBinding,
        onOpenChat: { [weak self] conversationID in
            self?.openMessagingController(conversationID: conversationID)
        },
        sendQuickReply: sendAction
    )
}
.margins(.all, 0)
```

After expansion changes, use your normal diffable-data-source or row-height update path. Do not add another tap recognizer over the hosting view.

## Verification performed here

- `swift test`: 9 tests, 0 failures.
- Foundation/localization code compiled under Swift 6.2 on Linux.
- Every Swift source passed `swiftc -parse`.
- String Catalog JSON validated.
- Placeholder and unsafe-pattern scans completed.

The SwiftUI/UIKit branches cannot be fully type-checked without Apple SDKs. Run the Xcode release gates below before shipping.

## Xcode release gates

```bash
xcodebuild \
  -scheme YourAppScheme \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  clean test
```

Then verify on a physical device:

- VoiceOver and Voice Control
- Arabic with mixed English names, URLs, prices, and timestamps
- Accessibility text sizes through AX5
- Reduce Motion and Reduce Transparency
- Increase Contrast and Differentiate Without Color
- Offline, permission-denied, closed-conversation, rate-limit, and server errors
- Fast list scrolling with 200+ rows in Instruments
- Avatar cache hit rate, memory peak, and image decode cost

## Package contents

- `PPChatCellCore`: stable models and tested state machine
- `PPChatCellUI`: SwiftUI component, localization, avatar pipeline, demo, and previews
- `Tests`: portable unit tests
- `XcodeTests`: UI-test contract to copy into your app UI-test target
- `CODERABBIT_SETUP.md`: exact CodeRabbit CLI setup
- `MIGRATION_FROM_CHCELL.md`: mapping from the old Objective-C cell
