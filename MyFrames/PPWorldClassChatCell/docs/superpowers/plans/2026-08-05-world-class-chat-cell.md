# World-Class Expandable Chat Cell Implementation Plan

> **For agentic workers:** Execute inline with test-first development and verify each release gate before claiming completion.

**Goal:** Upgrade the expandable Pure Pets chat inbox cell into a production-ready iOS 16+ component with stable identity, safe gesture ownership, localized copy, cached avatars, optimistic replies, accessibility coverage, and testable state transitions.

**Architecture:** Keep platform-independent conversation models and reply state in `PPChatCellCore`, verified by Swift Package tests on Linux. Keep SwiftUI/UIKit-specific rendering, localization, avatar loading, haptics, previews, and demo navigation in focused iOS files. The parent inbox owns navigation and expanded-row identity; the cell owns only ephemeral composer state.

**Tech Stack:** Swift 5.9+, SwiftUI, UIKit, ImageIO, URLSession, XCTest, String Catalogs; minimum iOS 16.

## Global Constraints

- Tap the conversation surface to open the messaging controller.
- Tap only the dedicated circular control to expand or collapse inline reply.
- Inline controls must never trigger navigation.
- Every interactive target must be at least 44×44 points.
- Conversation identity must come from a stable backend conversation ID.
- Collapsed cells use an opaque surface; material is reserved for the expanded state.
- User-visible errors must be product-safe and localized.
- The component must support Dynamic Type, VoiceOver, Voice Control, RTL, Reduce Motion, Reduce Transparency, Increase Contrast, and Differentiate Without Color.
- Remote avatars must be cached, request-coalesced, cancellable, and downsampled.
- The parent receives optimistic and committed reply events.

---

### Task 1: Testable core model and reply state

**Files:**
- Create: `Package.swift`
- Create: `Tests/PPChatCellCoreTests/PPChatCellCoreTests.swift`
- Create: `Sources/PPChatCellCore/PPChatCellCore.swift`

**Produces:** Stable `PPConversationID`, `PPQuickReply`, `PPChatThreadSnapshot`, `PPQuickReplyStateMachine`, `PPQuickReplyReceipt`, and `PPQuickReplyFailure`.

- [ ] Write tests for stable identity, duplicate reply titles, unread clamping, whitespace rejection, optimistic sending, success, and retry restoration.
- [ ] Run `swift test` and confirm the tests fail because the production types do not exist.
- [ ] Implement the smallest core needed to pass.
- [ ] Run `swift test` and confirm all tests pass.

### Task 2: Localization and timestamp formatting

**Files:**
- Create: `Sources/PPChatCellUI/PPChatCellCopy.swift`
- Create: `Sources/PPChatCellUI/Resources/PPChatCell.xcstrings`

**Produces:** String-catalog-backed copy including pluralized unread counts, accessibility states, and product-safe error messages; locale-aware timestamp formatter.

- [ ] Add all English and Arabic catalog entries.
- [ ] Eliminate hardcoded accessibility state strings.
- [ ] Format timestamps from `Date`, not preformatted model strings.

### Task 3: Cached avatar pipeline

**Files:**
- Create: `Sources/PPChatCellUI/PPAvatarImagePipeline.swift`

**Produces:** A shared, injected pipeline with memory cache, in-flight request coalescing, cancellation, and ImageIO thumbnail downsampling.

- [ ] Implement deterministic cache keys including pixel size and display scale.
- [ ] Coalesce duplicate in-flight requests.
- [ ] Cancel view-owned tasks on reuse/disappearance.
- [ ] Provide initials, loading, and failure fallbacks.

### Task 4: SwiftUI component

**Files:**
- Create: `Sources/PPChatCellUI/PPExpandableChatCell.swift`
- Create: `Sources/PPChatCellUI/PPChatCellSubcomponents.swift`
- Create: `Sources/PPChatCellUI/PPChatCellTokens.swift`

**Produces:** Focused SwiftUI component with explicit navigation/expansion gesture ownership, 44-point controls, opaque collapsed surface, expanded material, optimistic reply preview, and accessibility-safe states.

- [ ] Implement summary, avatar, preview, unread badge, expansion control, context, quick replies, composer, send status, and materials.
- [ ] Keep brand color limited to unread priority, focus, send, verification, and confirmation.
- [ ] Add Reduce Motion/Transparency, Differentiate Without Color, and Increased Contrast adaptations.

### Task 5: Integration, previews, and UI contract tests

**Files:**
- Create: `Sources/PPChatCellUI/PPChatInboxDemo.swift`
- Create: `Sources/PPChatCellUI/PPExpandableChatCell+Previews.swift`
- Create: `docs/PPChatCellUITestContract.md`

**Produces:** Parent-owned `NavigationStack`, single-expanded-row behavior, optimistic/committed callbacks, English/Arabic/dark/accessibility previews, and executable UI-test scenarios for Xcode.

- [ ] Demonstrate navigation by stable conversation ID.
- [ ] Demonstrate one expanded row at a time.
- [ ] Add UI-test identifiers and documented tap-ownership assertions.

### Task 6: Verification and delivery

**Files:**
- Create: `README.md`
- Create: `CODERABBIT_SETUP.md`

- [ ] Run `swift test`.
- [ ] Run `swiftc -parse` on every Swift file where possible.
- [ ] Scan for placeholder strings and sub-44-point interactive controls.
- [ ] Package the complete folder as a ZIP.
- [ ] Document Xcode/device/Instruments release gates that remain environment-dependent.
