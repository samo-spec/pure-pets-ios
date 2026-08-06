# Pure Pets Ad Share Package Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an iOS 17+ Swift Package that shares a branded advertisement JPEG, localized caption, canonical URL, and rich share-sheet metadata through one SwiftUI button.

**Architecture:** One public module contains Foundation-only contracts plus conditionally compiled SwiftUI/UIKit implementation. The host supplies validated public data and an image source; the package prepares all expensive work before presenting `UIActivityViewController` and exposes completion analytics without private content.

**Tech Stack:** Swift 5.9, Swift Package Manager, SwiftUI, UIKit, LinkPresentation, ImageIO, UniformTypeIdentifiers, XCTest.

## Global Constraints

- Minimum platform: iOS 17.
- No third-party dependencies.
- Do not use private WhatsApp APIs or hard-coded WhatsApp activity identifiers.
- Do not include private seller data, internal IDs, moderation fields, or Firebase paths.
- Canonical URL must appear exactly once in the caption.
- Render image before presenting the share controller.
- Default visible controls must support Dynamic Type, RTL, Reduce Motion, and 44-point minimum interaction targets.

---

### Task 1: Package and core contracts

**Files:**
- Create: `Package.swift`
- Create: `Sources/PurePetsAdShareKit/PPAdSharePayload.swift`
- Create: `Sources/PurePetsAdShareKit/PPAdShareError.swift`
- Test: `Tests/PurePetsAdShareKitTests/PPAdSharePayloadTests.swift`

**Interfaces:**
- Produces `PPAdSharePayload`, `PPAdShareAttribute`, and `PPAdShareError`.

- [ ] Write validation tests for blank IDs, invalid URLs, trimming, and attribute deduplication.
- [ ] Run `swift test` and confirm the tests fail because the types do not exist.
- [ ] Implement immutable validated models and errors.
- [ ] Run `swift test` and confirm Task 1 passes.

### Task 2: Localized caption formatting

**Files:**
- Create: `Sources/PurePetsAdShareKit/PPAdShareCopy.swift`
- Create: `Sources/PurePetsAdShareKit/PPAdShareMessageFormatter.swift`
- Test: `Tests/PurePetsAdShareKitTests/PPAdShareMessageFormatterTests.swift`

**Interfaces:**
- Consumes `PPAdSharePayload`.
- Produces `PPAdShareCopy` and `PPAdShareMessageFormatter.message(for:)`.

- [ ] Write deterministic English and Arabic formatting tests.
- [ ] Verify the canonical URL appears exactly once and optional values disappear cleanly.
- [ ] Implement localized copy presets and caption formatting.
- [ ] Run all tests.

### Task 3: File naming and temporary storage

**Files:**
- Create: `Sources/PurePetsAdShareKit/PPAdShareFileStore.swift`
- Test: `Tests/PurePetsAdShareKitTests/PPAdShareFileStoreTests.swift`

**Interfaces:**
- Produces safe deterministic JPEG paths and cleanup methods.

- [ ] Write filename normalization and path-containment tests.
- [ ] Implement the temporary share directory and atomic writes.
- [ ] Run all tests.

### Task 4: iOS card rendering and image loading

**Files:**
- Create: `Sources/PurePetsAdShareKit/PPAdShareConfiguration.swift`
- Create: `Sources/PurePetsAdShareKit/PPAdShareImageSource.swift`
- Create: `Sources/PurePetsAdShareKit/PPAdShareImageLoader.swift`
- Create: `Sources/PurePetsAdShareKit/PPAdShareCard.swift`
- Create: `Sources/PurePetsAdShareKit/PPAdShareCardRenderer.swift`

**Interfaces:**
- Produces `PPAdShareConfiguration`, `PPAdShareImageSource`, and a renderer returning a JPEG file URL.

- [ ] Implement validated visual configuration and image-source cases.
- [ ] Implement bounded remote loading with ImageIO downsampling.
- [ ] Implement the fixed-size branded export card.
- [ ] Implement `ImageRenderer` JPEG export using the Foundation file store.
- [ ] Parse all Swift sources.

### Task 5: Share controller and metadata

**Files:**
- Create: `Sources/PurePetsAdShareKit/PPAdShareAnalytics.swift`
- Create: `Sources/PurePetsAdShareKit/PPAdShareItemSource.swift`
- Create: `Sources/PurePetsAdShareKit/PPAdShareCoordinator.swift`
- Create: `Sources/PurePetsAdShareKit/PPShareSheet.swift`

**Interfaces:**
- Produces prepared sessions, activity-controller creation, completion analytics, and SwiftUI presentation.

- [ ] Implement privacy-safe analytics types and protocol.
- [ ] Implement rich `LPLinkMetadata` from existing payload data.
- [ ] Build the activity controller from the JPEG and caption source.
- [ ] Add iPad popover-safe representable presentation.
- [ ] Parse all Swift sources.

### Task 6: High-level SwiftUI button and preview

**Files:**
- Create: `Sources/PurePetsAdShareKit/PPFancyShareLabel.swift`
- Create: `Sources/PurePetsAdShareKit/PPAdShareButton.swift`
- Create: `Sources/PurePetsAdShareKit/PPAdSharePreview.swift`
- Create: `Examples/AdDetailsIntegration.swift`

**Interfaces:**
- Produces a default premium button and a generic custom-label initializer.

- [ ] Implement explicit idle, preparing, presented, and failure states.
- [ ] Add Reduce Motion, Dynamic Type, RTL, accessibility labels, and retry behavior.
- [ ] Add preview fixtures and a complete host-app integration example.
- [ ] Parse all Swift sources.

### Task 7: Documentation and release verification

**Files:**
- Create: `README.md`
- Create: `INTEGRATION.md`
- Create: `RELEASE_QA.md`
- Create: `Scripts/verify.sh`

**Interfaces:**
- Produces installation, backend-link, security, and verification guidance.

- [ ] Document local-package and remote-package integration.
- [ ] Document Open Graph and Universal Link requirements.
- [ ] Add a Linux-compatible core gate and a macOS Xcode gate.
- [ ] Run all available verification commands.
- [ ] Create the final ZIP and checksum.
