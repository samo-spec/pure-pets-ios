# Migration from `ChCell.h/.m`

## Keep

- Existing chat service and messaging controller.
- Existing backend conversation identifier.
- Existing presence source, unread count, avatar URL, and last-message payload.

## Replace

- Replace row-owned navigation with `onOpenChat(PPConversationID)`.
- Replace generated row IDs with the backend conversation ID.
- Replace preformatted dates with `Date`.
- Replace `[String]` quick replies with `[PPQuickReply]` using stable IDs.
- Replace direct remote image assignment with `PPAvatarImagePipeline`.
- Replace raw service error display with `PPQuickReplyFailure`.

## Required parent state

```swift
@State private var expandedConversationID: PPConversationID?
```

Only one row should compare equal to this ID at a time. Set it to `nil` when the selected row collapses.

## Gesture ownership

Do not add a row-level `onTapGesture` around `PPExpandableChatCell`. The component already exposes two independent semantic buttons:

1. Conversation surface → messaging controller.
2. Circular chevron → inline composer.

Adding an outer gesture will reintroduce accidental navigation from quick replies and the composer.
