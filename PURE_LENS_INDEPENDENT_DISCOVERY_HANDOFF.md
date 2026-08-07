# Pure Lens Independent Discovery Handoff

Date: 2026-08-08
Project: Pure Pets iOS
Status: implementation and independent source audit complete at static-validation level; physical-device acceptance remains unverified

## Objective

Pure Lens is now an independent animal discovery feature:

```text
Camera -> Stable Animal Recognition -> Temporary Animal Context
       -> One Representative Frame -> Shared Search by Image
       -> Progressive Accessories / Services / Medicine / Products sheet
```

The active Home and Account entry points do not require, select, create, fake,
or persist a PetProfile. Legacy `activePetID` fields remain only in compatibility
types and are not read by the active composition.

## Root Cause

Zero-profile use was previously blocked in four places:

1. `HomeRouter.openPureLens` redirected to Pet Profiles when no selected profile existed.
2. The package view/store gated camera and discovery on saved-pet context.
3. The legacy resolver transport expected `activePetID`.
4. The Infra `lensResolve` endpoint validates an owned profile because it serves the old profile-bound contract.

The active independent flow now bypasses that legacy resolver and composes existing
read-only marketplace/search services directly. Infra remains unchanged.

The apparent cat-only behavior came from relying on `VNRecognizeAnimalsRequest`,
which recognizes cats and dogs rather than the wider Pure Pets taxonomy. The supplied
12.64-second recording confirms only the old cat path (63 percent); it is not evidence
for other species.

## Implemented Architecture

- Added session-only `DetectedAnimalContext` with species, optional reliable breed,
  confidence, source, bounding box, and track identity.
- Added stable multi-frame and spatial confirmation; one frame cannot confirm.
- Added controlled inference on one serial frame queue with intentional sampling and
  stale-generation rejection.
- Added an exact-label `VNClassifyImageRequest` fallback for supported broad animal
  labels when native/custom object recognition is not reliable.
- Added animal umbrella confidence, species ambiguity, saliency confidence, and area
  gates. Collision labels such as `hotdog`, `birdhouse`, `fishbowl`, and
  `computer_mouse` cannot become detections.
- Added truth-based Vision/Core ML/fused detection-source attribution.
- Added one best-of-window representative frame. It enters shared image search once.
- Added progressive, independent category loading, visible partial-failure states,
  exact-pipeline retry when safe, and a separate item-open failure alert.
- Kept the camera behind one bottom discovery sheet; Scan Again clears session state
  and reuses the existing capture session.
- Added standalone Account entry communicating Camera -> Recognition -> Discovery.
- Added iOS 26 native glass and older-iOS Material behavior.
- Mapped all text styles to Beiruti Dynamic Type and all product colors to Pure Pets
  semantic theme tokens.

## MainKinds Safety

`MainKindsArrayManager` is now cache-first and concurrent-call safe:

- simultaneous cold callers share one request;
- every queued completion fires exactly once on the main thread;
- user-visible taxonomy is published centrally on the main thread;
- new integrations read an immutable queue-safe snapshot;
- later refreshes use notifications instead of repeating load completions.

After stable detection, Pure Lens pauses inference and validates the species against
the current visible MainKinds snapshot. Unsupported means analysis stays disabled and
no representative frame, consent prompt, image upload, or discovery request occurs.
A taxonomy load failure is a separate paused/retry state, not a false unsupported result.

Infra fixtures confirm Birds, Cats, Dogs, Camels, and Gazelles are canonical examples.
Apple's general classifier exposes camel but no gazelle label. Do not map deer to
gazelle or otherwise overstate identity; a validated custom model is required for
reliable gazelle recognition.

## Shared Search and Marketplace

`PPImageSearchService` now owns one reusable image-data transport. Existing Search
Controller UIImage behavior forwards through it unchanged. Pure Lens resolves species
against visible MainKinds, filters canonical `petAccessories` / `serviceOffers`
records, and routes taps through existing detail screens. The bridge's progressive
canonical-object cache is synchronized across callback queues.

No Firebase collection, rule, permission, write path, App Check setting, or Cloud
Function was changed. No deployment occurred.

## Primary Files

- `MyFrames/PureLensPackage/Sources/PureLens/PureLensStore.swift`
- `MyFrames/PureLensPackage/Sources/PureLens/Camera/VisionLensDetector.swift`
- `MyFrames/PureLensPackage/Sources/PureLens/Camera/PureLensCameraController.swift`
- `MyFrames/PureLensPackage/Sources/PureLensCore/LensModels.swift`
- `MyFrames/PureLensPackage/Sources/PureLensCore/LensDetectionStabilizer.swift`
- `MyFrames/PureLensPackage/Sources/PureLens/Components/LensResultSheet.swift`
- `MyFrames/PureLensPackage/Sources/PureLens/PureLensTheme.swift`
- `Pure Pets/MainApp/ModrenAppVC/SwiftUIHome/Routing/HomeRouter.swift`
- `Pure Pets/MainApp/ModrenAppVC/Search/PPImageSearchService.h/.m`
- `Pure Pets/DataClasses/BasicDataClassess/MainKindsArrayManager.h/.m`
- `Pure Pets/MainApp/UserFiles/PPUserMenuViewController.m`
- `Pure Pets/Pure Pets-Bridging-Header.h`
- `Pure Pets/ar.lproj/Localizable.strings`
- `Pure Pets/en.lproj/Localizable.strings`

## Static Evidence Completed

- All package Swift Sources and Tests pass `swiftc -frontend -parse`.
- `PureLensCore` passes standalone frontend type-check.
- All current Pure Lens UI/camera sources pass an iPhoneOS frontend type-check.
- `HomeRouter.swift` passes Swift parse.
- `MainKindsArrayManager.m`, `PPImageSearchService.m`, and
  `PPUserMenuViewController.m` pass focused iPhoneOS Objective-C syntax checks.
- Package Arabic/English localization parity: 119 unique keys each, no missing key
  and no duplicate key.
- Host Arabic/English strings, package strings, PrivacyInfo, and Info.plist pass plist lint.
- SwiftyMax strict audit across all 25 package source files has no configured findings.
- `git diff --check` passes.
- Before the latest delta, 96 package tests passed. No test suite, Xcode build,
  `xcodebuild`, simulator, or device run was performed in the resumed task.
- The earlier frontend type-check and focused Objective-C syntax evidence above was not
  rerun during the resumed no-Xcode pass; the current package Sources and Tests were
  reparsed after the latest delta.

## Required Next Validation

1. In Xcode Run UI on a physical iPhone, use a user with zero PetProfiles.
2. Verify open -> detect -> progressive sheet -> details -> Scan Again without any
   profile being created or selected.
3. Exercise dog, bird, rabbit, fish, reptile, small mammal, horse, camel, sheep, goat,
   and cow fixtures; verify non-animal scenes never confirm.
4. Hide/remove a detected category from live MainKinds and verify the paused unsupported
   state sends no image-search request.
5. Exercise camera denial/interruption/background/foreground and repeated open/close.
6. Fail image search and each marketplace category separately.
7. Inspect Arabic RTL, English LTR, Dynamic Type, VoiceOver, Reduce Motion,
   Reduce Transparency, dark mode, iOS 26 glass, and older-iOS Material.
8. Profile a sustained physical-device camera session for frame time, energy, thermal,
   memory, and retained sessions.

The primary zero-PetProfile test, broad-species accuracy, live MainKinds behavior,
rendered UI, and lifecycle performance are `UNVERIFIED` until these device gates pass.

## Repository Warning

`MyFrames/PureLensPackage` is recorded by the parent repository as git mode `160000`,
but this checkout has no nested `.git` metadata and no matching `.gitmodules` entry.
The package edits exist on disk and are used by the local project, but the parent Git
cannot report or stage their file-level diff. Restore the intended package repository
metadata before preparing a commit; do not replace or discard the current directory.

Read-only history inspection found that parent commit `d76315d6` introduced the gitlink
directly at nested commit `6d18c7c9cc76e5979821e75c1a95184d73aef3b5`. No `.gitmodules`
history, local `submodule.*` config, `.git/modules/MyFrames/PureLensPackage` metadata,
or local object for that nested commit exists. Restoration therefore requires the
intended package remote or a known-good clone; initializing or replacing this directory
from a guessed remote would risk losing the current package sources.

=== CHECKPOINT START ===
Checkpoint Name: Independent Pure Lens static implementation
Status: completed
What was finished:
- Zero-PetProfile architecture, broad guarded detection, MainKinds fail-closed gate,
  shared image search, progressive results, standalone Account entry, app theme/font use.
Files created/updated:
- See Primary Files above and package verification/documentation files.
Routes / models / APIs added:
- `PPPureLensHostPresenter`, `PPPureLensDiscoveryBridge`, `DetectedAnimalContext`,
  `LensDiscoveryClient.isAnimalSupported`, and `visibleMainKindsSnapshot`.
Known remaining work:
- Physical-device acceptance and package git metadata restoration.
How to continue next:
- Open `Pure Pets.xcworkspace`, run on connected hardware, and execute Required Next Validation.
=== CHECKPOINT END ===

=== CHECKPOINT START ===
Checkpoint Name: Independent Pure Lens source-audit closure
Status: completed
What was finished:
- Traced Home and Account entry ownership through `PPPureLensHostPresenter`, the
  server-driven MainKinds gate, shared image search, marketplace reads, and existing
  detail routing.
- Repaired the missing UI consumer for recorded discovery failures.
- Added category-level retry for failed taxonomy/image pipelines when the current
  detection and retained representative frame make retry safe.
- Added a localized item-open failure alert and AX-size-safe retry layout.
- Replaced the `contains(where:)` key-path predicate with an explicit typed closure
  after the project compiler rejected that shorthand in `hasDiscoveryFailures`.
- Normalized value-scoped Reduce Motion animations so strict static audit recognizes
  their explicit state boundaries.
Files created/updated:
- `MyFrames/PureLensPackage/Sources/PureLens/PureLensStore.swift`
- `MyFrames/PureLensPackage/Sources/PureLens/Components/LensResultSheet.swift`
- `MyFrames/PureLensPackage/Sources/PureLens/Components/LensBottomPrompt.swift`
- `MyFrames/PureLensPackage/Sources/PureLens/Components/LensCameraScene.swift`
- Package Arabic and English `Localizable.strings`
- `PURE_LENS_INDEPENDENT_DISCOVERY_HANDOFF.md`
Routes / models / APIs added:
- No Firebase, navigation, model, collection, permission, or write API was added.
- Added internal `retryDiscovery(_:)`, `canRetryDiscovery(_:)`, and item-open error state.
Known remaining work:
- Physical-device acceptance in Required Next Validation.
- Restore package Git metadata from the intended remote or a known-good clone.
- Package tests and build/device validation were intentionally not run in this task.
How to continue next:
- First recover the package repository identity without replacing its current source
  directory; then use `Pure Pets.xcworkspace` on connected physical hardware when
  explicit runtime validation is authorized.
=== CHECKPOINT END ===
