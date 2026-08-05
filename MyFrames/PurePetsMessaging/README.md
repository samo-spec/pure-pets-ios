# PurePetsMessaging

A production-oriented SwiftUI message system for Pure Pets.

## Included payloads

- Text
- Voice recording
- Image
- Video
- Sticker with no visible container
- Deleted message
- Unsupported/future message

Reply is metadata, not a payload type, so every payload can reply to every other payload.

## Architecture

```text
ChatMessage (typed value model)
└── SmartMessageCell (stable interaction shell)
    ├── ReplyReferenceView
    ├── MessagePayloadView (small dispatcher)
    │   ├── TextMessageView
    │   ├── VoiceMessageView
    │   ├── ImageMessageView
    │   ├── VideoMessageView
    │   ├── StickerMessageView
    │   ├── DeletedMessageView
    │   └── UnsupportedMessageView
    ├── DeliveryStatusView
    └── MessageReactionsView
```

The sticker renderer has no bubble, border, background, shadow, caption, or padding. The shell still owns alignment, reply context, status, actions, and accessibility.

## Minimum platform

- iOS 17
- Swift 6 language mode supported by the package manifest

## Integration

Add the package to Xcode, then:

```swift
import PurePetsMessagingUI

@State private var audioCoordinator = ConversationAudioCoordinator()

SmartMessageCell(
    message: message,
    audioCoordinator: audioCoordinator,
    actions: .init(
        onReply: { /* open composer reply */ },
        onRetry: { /* retry send */ },
        onOpenImage: { payload in /* image viewer */ },
        onOpenVideo: { payload in /* video coordinator */ }
    )
)
```

Use `MessageGalleryView` to inspect every payload and the included RTL, accessibility-size, and Reduce Motion previews.

## Media boundaries

`ConversationAudioCoordinator` owns voice playback and stops playback when its message disappears. Video playback is intentionally launched through `onOpenVideo`; the reusable cell never owns a video player.

`RemoteMediaImage` uses `AsyncImage` as a dependency-free reference implementation. Replace it with the app's authenticated thumbnail repository when integrating with production storage. Keep URL validation, byte limits, cache policy, and decoding outside the cell.

## Verification included

Core tests cover:

- Incoming/outgoing state separation
- Upload progress normalization
- Required sticker accessibility descriptions
- Containerless sticker chrome policy
- Forwarding restrictions
- Presence expiry normalization
