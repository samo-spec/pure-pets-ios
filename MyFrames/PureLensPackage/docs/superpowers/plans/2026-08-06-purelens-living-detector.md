# PureLens Living Detector 2.0 Implementation Plan

> Archived pre-refactor plan. It is not the active Pure Lens contract.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Make PureLens continuously alive, stabilize and reveal breed/species/category automatically, and add deduplicated premium feedback without weakening privacy or accessibility.

**Architecture:** Add platform-independent recognition normalization and stabilization to `PureLensCore`; feed its equatable state from `PureLensStore`; render one state-driven detector composition in SwiftUI; keep remote resolution and consent in the existing workflow. Add a focused feedback controller and a bundled tone.

**Tech Stack:** Swift 5.10, Swift Package Manager, SwiftUI iOS 16+, Vision, Core ML, AVFoundation, UIKit haptics, XCTest.

## Global Constraints

- Minimum platform remains iOS 16.
- Preserve both `PurePetsEyes` and backward-compatible `PureLens` products and symbols.
- Do not bypass Pet Profile eligibility, authentication, policy validation, remote-processing consent, or action confirmation.
- Support English, Arabic, LTR, RTL, Dynamic Type, VoiceOver, Differentiate Without Color, and Reduce Motion.
- Keep all camera and detection work off the main thread; publish UI state on `@MainActor`.
- Preserve the uploaded package's existing uncommitted 2.0 naming and integration changes.

---

### Task 1: Recognition normalization and stabilization

**Files:**
- Create: `Sources/PureLensCore/LensDetectionStabilizer.swift`
- Test: `Tests/PureLensCoreTests/LensDetectionStabilizerTests.swift`

**Interfaces:**
- Produces: `LensPetRecognition`, `LensDetectorState`, `LensDetectionStabilizer.Configuration`, `mutating func ingest(_:) -> LensDetectorState`, and `mutating func reset()`.

- [x] Write failing tests for generic species labels, structured breed labels, stable lock, tolerated gaps, and candidate replacement.
- [x] Build the core test target and verify the new tests fail because the types do not exist.
- [x] Implement the minimum normalization and stabilization logic.
- [x] Rebuild and run the core test executable; verify all tests pass.

### Task 2: Automatic store orchestration

**Files:**
- Modify: `Sources/PureLens/PureLensStore.swift`
- Modify: `Sources/PureLens/PureLensConfiguration.swift`
- Modify: `Sources/PureLens/Camera/PureLensCameraController.swift`

**Interfaces:**
- Consumes: `LensDetectionStabilizer` from Task 1.
- Produces: published `detectorState`, `liveRecognition`, automatic one-shot resolution, and optional keyframe delivery.

- [x] Add configuration values for auto-resolution, stable-frame count, confidence threshold, lost-frame tolerance, sound enablement, and feedback cooldown.
- [x] Feed each frame through the stabilizer and publish only changed detector state.
- [x] Start automatic resolution once for each stable recognition; automatically request consent when required.
- [x] Reset recognition and cancellation state across backgrounding, profile loss, and camera interruption.
- [x] Avoid JPEG encoding in metadata-only mode and when selected-frame mode has no pet detection.

### Task 3: State-driven detector UI

**Files:**
- Replace focused internals in: `Sources/PureLens/Components/LensCameraScene.swift`
- Modify: `Sources/PureLens/Components/LensBottomPrompt.swift`
- Modify: `Sources/PureLens/PureLensView.swift`

**Interfaces:**
- Consumes: `store.detectorState`, `store.liveRecognition`, workflow state, accessibility environment values.
- Produces: always-alive searching, stabilizing progress, detected identity capsule, resolving treatment, and accessible announcements.

- [x] Build a single reticle composition whose motion parameters derive from detector state.
- [x] Show breed as the dominant line and species/category as the secondary line inside or adjacent to the ring.
- [x] Remove the Discover button from the normal eligible path; show a consent continuation only through the existing alert.
- [x] Keep retry and action confirmation in the result sheet.
- [x] Add Reduce Motion, Differentiate Without Color, Dynamic Type, VoiceOver labels, and RTL-safe alignment.

### Task 4: Premium feedback

**Files:**
- Create: `Sources/PureLens/Feedback/PureLensDetectionFeedback.swift`
- Create: `Sources/PureLens/Resources/purelens-detected.wav`
- Modify: `Sources/PureLens/PureLensStore.swift`

**Interfaces:**
- Produces: `prepare()` and `playDetection(for:cooldown:)` with identity deduplication.

- [x] Generate a short low-volume two-note WAV with fast attack and soft decay.
- [x] Preload `AVAudioPlayer` and prepare UIKit generators when the camera becomes eligible.
- [x] Play sound and haptic only on a new stable recognition and respect configuration switches.
- [x] Stop feedback playback when the feature closes or backgrounds.

### Task 5: Localization, documentation, and verification

**Files:**
- Modify: `Sources/PureLens/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/PureLens/Resources/ar.lproj/Localizable.strings`
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `VERIFICATION.md`

**Interfaces:**
- Produces: accurate auto-detection/privacy copy and integration guidance.

- [x] Add searching, stabilizing, detected, species, category, and accessibility announcement strings in English and Arabic.
- [x] Remove copy that says Discover must be tapped; document automatic resolution and consent behavior.
- [x] Parse every Swift file for syntax errors.
- [x] Build and run the platform-independent core tests.
- [x] Review the final diff for unrelated changes, accidental API breaks, animation excess, and missing state handling.
