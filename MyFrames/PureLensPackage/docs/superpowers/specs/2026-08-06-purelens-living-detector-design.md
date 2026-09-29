# PureLens Living Detector 2.0 Design

> Archived pre-refactor design. It is not the active Pure Lens contract.

## Product intent

PureLens should communicate that it is continuously understanding the camera scene without becoming visually noisy. The detector is the dominant anchor. It must always exhibit a restrained living state, immediately surface a stable pet identity, and automatically continue into trusted resolution without requiring a Discover tap.

## Experience states

1. **Searching** — a slow orbital reticle, low-amplitude breathing halo, and concise guidance. No result text is invented.
2. **Stabilizing** — when a plausible pet appears, the ring accelerates slightly and displays deterministic progress while multi-frame evidence is collected.
3. **Detected** — the ring locks with a short spring transition. Breed is the primary line; species and category form the secondary line inside or directly below the reticle. The result remains visible while trusted remote resolution runs.
4. **Resolving** — local identity remains anchored; a subtle activity treatment communicates that PureLens is connecting the scene to account context.
5. **Uncertain / lost** — after tolerated missing frames, the lock gracefully returns to searching rather than flickering between labels.
6. **Interrupted / unavailable / error** — motion stops, the state is stated in text and symbol, and the existing recovery paths remain available.

## Recognition architecture

`PureLensCore` owns a platform-independent `LensDetectionStabilizer`. It normalizes raw labels into `LensPetRecognition` values containing `breed`, `species`, `category`, `confidence`, and `boundingBox`. A candidate must win multiple consecutive observations and exceed confidence thresholds before becoming locked. Short gaps are tolerated; competing candidates must independently stabilize before replacing an existing lock.

The SwiftUI target owns presentation only. `PureLensStore` feeds frames into the stabilizer, publishes `detectorState`, starts automatic resolution once per stable recognition, and deduplicates feedback. Existing remote policy validation, Pet Profile gating, authenticated context, write confirmation, and consent rules remain unchanged.

## Automatic resolution and privacy

A stable local recognition is revealed immediately. For metadata-only mode or prior consent, remote resolution starts automatically. For selected-frame mode without prior consent, PureLens automatically presents the existing one-frame consent disclosure; resolution starts only after explicit consent. Continuous video is never uploaded.

## Motion and feedback

The detector uses one motion system driven by `LensDetectorState`, not unrelated decorative animations. Searching uses a slow orbit and breath, stabilizing uses progress and modestly increased energy, and detected uses a short lock transition followed by a calm pulse. Reduce Motion disables rotation, scan travel, spring displacement, and repeating scale changes; state remains legible through opacity, line weight, text, and symbols.

A bundled, short, low-volume two-note tone is preloaded. A prepared soft impact is emitted only when a new stable recognition locks. The feedback controller applies recognition identity deduplication and cooldown so repeated frames never retrigger sound or haptics.

## Accessibility and localization

All identity content is available as a single VoiceOver element and announced once on stable lock. Dynamic Type may expand the recognition capsule without clipping. Color is never the sole state signal. English and Arabic strings are updated, layout uses leading/trailing alignment, and mixed Latin breed names remain readable in RTL.

## Performance

Detection stays on the existing serial frame queue. JPEG encoding is skipped in metadata-only mode and when no candidate is present. The UI observes a small, equatable detector state rather than raw frame history. Repeating animation count is capped and disabled while interrupted, backgrounded, or Reduce Motion is enabled.

## Verification

Core tests cover label normalization, stabilization thresholds, gap tolerance, replacement behavior, and feedback deduplication. Existing core tests remain green. Swift syntax is parsed in the available environment; full iOS type-checking and simulator validation require Xcode because AVFoundation, UIKit, Vision, and SwiftUI are unavailable on Linux.
