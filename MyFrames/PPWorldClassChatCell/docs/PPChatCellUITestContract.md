# UI test contract

The component exposes stable identifiers based on `PPConversationID`:

- `pp.chat.thread.<conversationID>`
- `pp.chat.open.<conversationID>`
- `pp.chat.expand.<conversationID>`
- `pp.chat.open.expanded.<conversationID>`
- `pp.chat.reply.input.<conversationID>`
- `pp.chat.reply.send.<conversationID>`
- `pp.chat.quickReply.<conversationID>.<quickReplyID>`
- Demo destination: `pp.chat.messaging.<conversationID>`

Required assertions:

1. Tapping `pp.chat.open.*` opens messaging without expanding.
2. Tapping `pp.chat.expand.*` expands without navigating.
3. Tapping the expand control again collapses.
4. Quick replies populate the composer without navigation.
5. Send is disabled for whitespace-only input.
6. Sending twice rapidly triggers one request.
7. Failure restores the draft and exposes retry.
8. VoiceOver focus order is summary → expand → open full chat → latest message → replies → composer → send.
