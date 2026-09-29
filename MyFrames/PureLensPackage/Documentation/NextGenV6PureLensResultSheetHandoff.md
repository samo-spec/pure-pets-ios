# Pure Lens Result Sheet - NextGen V6 Handoff

## Target

- Mode: redesign
- Surface: `Sources/PureLens/Components/LensResultSheet.swift`
- Selected direction: quiet recognition brief with a contextual Nova action rail
- Platform: SwiftUI package, iOS 16 minimum
- Language intent: Arabic-first RTL and English LTR

## Delivered

- Detection remains the first visual anchor and now reads as one recognition brief.
- Recognition uses the existing Pure Lens theme tokens, Beiruti typography, contrast handling, and Dynamic Type behavior.
- The recognition surface has a restrained success rail instead of additional decorative treatment.
- Nova is presented as a focused contextual handoff, not a competing result category.
- The handoff rail shows the detected animal context, keeps the editable-question action explicit, and preserves the privacy disclosure.
- Nova button press feedback continues to respect Reduce Motion.
- Existing category loading, partial failure, retry, empty, item-opening, Scan Again, sheet detents, and canonical routing behavior remain unchanged.

## Handoff Contract

- `PureLensStore.openGuidance()` creates `LensGuidanceHandoff` from the current `DetectedAnimalContext`.
- The handoff contains only `species`, optional `breed`, and localized `displayName`; camera frame data, geometry, confidence, and track identity stay inside Pure Lens.
- `HomeRouter` forwards the handoff to `PPNovaAmbientAssistantChatBridge.open(from:initialDraft:)`.
- Nova receives an editable localized draft. The draft is not sent until the user chooses Send.
- Existing Nova draft-discard protection remains active when the user attempts to close before sending.

## Preserved Sources

- `Sources/PureLensCore/LensModels.swift`
- `Sources/PureLens/PureLensStore.swift`
- `Sources/PureLens/Integration/PureLensUIKit.swift`
- `Pure Pets/MainApp/ModrenAppVC/SwiftUIHome/Routing/HomeRouter.swift`
- `Pure Pets/MainApp/GEMENI/PPNovaAmbientAssistantChatBridge.h`
- `Pure Pets/MainApp/GEMENI/PPNovaAmbientAssistantChatBridge.m`
- `Pure Pets/MainApp/GEMENI/PPNovaChatViewController.h`
- `Pure Pets/MainApp/GEMENI/PPNovaChatViewController.m`

## Verification

- `swift test`: PASS, 98 tests, 0 failures.
- Pure Lens package compilation: PASS as part of `swift test`.
- Focused Pure Lens diff whitespace check: PASS.
- Physical-device rendering, VoiceOver, RTL/LTR screenshots, motion interruption, and performance evidence: UNVERIFIED.
- NextGen V6 independent proof and target-bound visual review: BLOCKED/UNVERIFIED until the connected-device capture path is available.
- Repository note: `MyFrames/PureLensPackage` is recorded by the iOS superproject as a gitlink without a `.gitmodules` mapping, so its working-tree edits are not reported by the outer `git status`.

## Source Evidence

- `Sources/PureLens/Components/LensResultSheet.swift`: SHA-256 `4806eebde5ee43c1b2b8d9396c13e1326b057c07338e068f1ad515d80c8af1b8`
- `Sources/PureLens/PureLensStore.swift`: SHA-256 `9b55c0fc4f7cd77298c41309ba4350eeb3ee4bc4926d15faadf1f370fe36f353`
- `Sources/PureLensCore/LensModels.swift`: SHA-256 `4cdffe20cd41676a5df42a29915d6ab2b902ed4736da08a8d87cfc4eb4b55598`

## Remaining Gate

Capture the result sheet on the required physical iPhone in Arabic RTL and English LTR, light and dark appearances, compact and regular widths, and at least recognition/loading/partial-failure states. Confirm the Nova handoff opens the existing chat with an editable draft and that no frame or camera metadata crosses the handoff boundary.
