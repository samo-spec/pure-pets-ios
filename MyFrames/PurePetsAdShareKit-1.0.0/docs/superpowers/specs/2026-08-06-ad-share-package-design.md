# Pure Pets Ad Share Package Design

## Goal

Create a reusable iOS 17+ Swift Package that shares a Pure Pets advertisement as a branded image attachment, a localized concise caption, and a canonical public URL through the system share sheet, including WhatsApp when installed.

## Product contract

The package must never fabricate listing data. It receives an immutable public share payload from the host app, renders only those approved fields, and treats the canonical URL as the source of truth. It must not use private WhatsApp APIs or hard-coded third-party activity identifiers.

## Architecture

The package exposes one module, `PurePetsAdShareKit`. Foundation-only models, validation, formatting, and filename logic compile on every Swift Package platform. SwiftUI, UIKit, LinkPresentation, ImageIO, and UniformTypeIdentifiers features are wrapped in `#if canImport(...)` so the core test suite runs outside Xcode while the complete feature compiles on iOS.

Primary units:

- `PPAdSharePayload`: immutable, validated public advertisement data.
- `PPAdShareMessageFormatter`: deterministic localized caption creation.
- `PPAdShareCard`: branded 1080×1350 SwiftUI export view.
- `PPAdShareImageLoader`: URLSession loading and ImageIO downsampling.
- `PPAdShareCardRenderer`: off-screen `ImageRenderer` JPEG export to a temporary file.
- `PPAdShareItemSource`: caption and rich `LPLinkMetadata` provider.
- `PPAdShareCoordinator`: preparation, share-controller creation, analytics, and cleanup.
- `PPAdShareButton`: high-level SwiftUI control with preparing, presentation, and error states.
- `PPFancyShareLabel`: default premium, accessible label.

## Data flow

1. Host maps its backend model to `PPAdSharePayload`.
2. User activates `PPAdShareButton`.
3. Coordinator resolves the listing image from a supplied `UIImage`, image data, or remote URL.
4. Renderer creates the branded JPEG before presenting the share sheet.
5. Formatter creates a localized caption containing the canonical URL exactly once.
6. `UIActivityViewController` receives the JPEG file URL and an item source containing the caption and rich metadata.
7. Completion analytics report the selected activity and completion status without advertisement content or personal data.
8. Temporary files are removed after completion or explicit cleanup.

## Error handling

Public failures use `PPAdShareError` with localized, user-presentable descriptions. Invalid payloads fail during construction. Image loading validates HTTP responses, MIME data, byte limits, and decodability. Rendering and temporary-file errors are distinct. The button presents an alert and remains retryable.

## Accessibility and motion

The default label supports Dynamic Type, a minimum 52-point target, VoiceOver labels and hints, Reduce Motion, Increase Contrast, and RTL layout. Exported cards use fixed typography because they are raster assets, while visible in-app controls remain semantic and scalable.

## Testing

Foundation tests cover validation, trimming, attribute caps, English and Arabic captions, canonical URL uniqueness, safe filenames, and privacy-sensitive omission. Apple-platform compilation and rendered behavior are verified by an included Xcode verification script and manual checklist.

## Non-goals

- Uploading advertisements or share cards to a backend.
- Tracking recipients or message content.
- Forcing WhatsApp as the only activity.
- Editing backend listing data.
- Guaranteeing how a third-party app combines image and caption items.
