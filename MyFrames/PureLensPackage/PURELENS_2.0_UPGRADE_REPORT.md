# Pure Pets Eyes 2.0 — Living Detector Upgrade Report

> Archived historical report. Version 3.0 replaced the orbit/scan-line presentation,
> profile-gated resolver flow, and automatic insight action with state-driven
> independent animal discovery. Do not use this document as the active contract.

Date: 2026-08-06
Branch: `feature/purelens-living-detector-2.0`
Scope: PureLens/Pure Pets Eyes Swift package only

## Delivered experience

Pure Pets Eyes now behaves as a continuous detector rather than a camera screen waiting for a button press.

1. **Searching** — the detector has a slow orbital movement, breathing halo, and scan line.
2. **Stabilizing** — a candidate must remain consistent across configurable consecutive frames.
3. **Detected** — the stable breed, species, and category appear next to the reticle immediately.
4. **Resolving** — trusted resolution starts automatically; there is no Discover tap in the normal path.
5. **Consent paused** — selected-frame consent still remains explicit. Cancelling the disclosure pauses analysis and exposes one deliberate recovery action instead of reopening the alert repeatedly.
6. **Interrupted or lost** — motion and state reset cleanly without retaining a stale selected frame.

## Recognition architecture

The new platform-independent `LensDetectionStabilizer` owns recognition normalization and lock behavior. It:

- parses Apple Vision animal labels into species-level results;
- parses structured custom-model labels such as `pet|dog|Golden Retriever`;
- recognizes common direct dog/cat breed labels;
- prefers a valid breed-level result over a more confident generic species result;
- requires consecutive stable frames before lock;
- tolerates brief missing frames;
- requires a competing identity to stabilize before replacing an existing lock;
- smooths confidence and bounding-box movement;
- exposes one equatable `LensDetectorState` to SwiftUI.

## Feedback

- Bundled 0.44-second, 44.1 kHz, 16-bit mono detection tone.
- Preloaded `AVAudioPlayer` at restrained volume.
- Prepared `.soft` UIKit impact with controlled intensity.
- Identity and cooldown gate prevents repeated frames from replaying feedback.
- Existing success/error/action feedback remains separate from detection feedback.

## Privacy and performance

- Continuous video is never uploaded.
- Automatic resolution does not bypass selected-frame consent.
- Metadata-only mode does not materialize JPEG frames.
- Selected-frame mode captures only recognized candidates above the configured confidence threshold.
- Repeated captures are throttled, while a changed pet identity forces a fresh keyframe.
- The selected frame is cleared on backgrounding, camera interruption, and Pet Profile loss.
- Camera analysis remains on the existing serial frame queue; only small state updates reach `@MainActor`.

## Accessibility and bidirectionality

- Reduce Motion removes orbital, scan, spring, and breathing movement while preserving state information.
- Reduce Transparency replaces material with an opaque camera surface.
- Differentiate Without Color changes line weight, dash pattern, and symbols.
- Stable detections produce one localized VoiceOver announcement only while VoiceOver is active.
- Recognition copy is localized in English and Arabic.
- Layout uses SwiftUI environment locale and layout direction, supporting LTR and RTL.
- The recognition capsule uses scalable text, bounded lines, and a unified accessibility label.

## Public configuration added

```swift
var automaticallyResolvesDetections: Bool
var minimumDetectionConfidence: Double
var stableDetectionFrameCount: Int
var replacementStableFrameCount: Int
var lostDetectionFrameTolerance: Int
var detectionSoundEnabled: Bool
var detectionFeedbackCooldown: TimeInterval
```

Production defaults are documented in `README.md`.

## New analytics events

- `pure_lens_pet_detected`
- `pure_lens_auto_resolve_started`
- `pure_lens_remote_processing_declined`

Existing Discover analytics remain only for the optional manual fallback mode.

## Verification evidence

- 31 Swift source/test files parsed with zero syntax failures.
- 29 platform-independent XCTest cases passed with zero failures.
- 81 English keys and 81 Arabic keys; identical sets and no duplicates.
- Package manifest parsed successfully with iOS 16 minimum deployment.
- Privacy manifest parsed successfully.
- Detection WAV format validated.
- `git diff --check` clean.
- Full iOS build is not claimed because this Linux workspace has no Xcode or iOS SDK; `AVFoundation` is unavailable by design.
- CodeRabbit could not be installed because this workspace could not resolve `cli.coderabbit.ai`; no CodeRabbit result is claimed.

## Host integration

The upgraded package can replace the current `MyFrames/PureLensPackage` working tree. The package keeps both products:

- `PurePetsEyes` — canonical 2.0 product;
- `PureLens` — compatibility product for current imports.

After replacement, update the host repository's submodule pointer or commit the local package contents, then run the Xcode/device release gates listed in `VERIFICATION.md`.
