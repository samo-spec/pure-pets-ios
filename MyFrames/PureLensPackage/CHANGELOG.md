## 3.1.0 - 2026-09-25

- Expanded Pure Lens to open-world animal identity while keeping marketplace support closed to live visible Pure Pets categories.
- Added conservative server taxonomy matching so wildlife and semantic relatives cannot inherit domestic/falcon commerce categories.
- Added a typed canonical commerce scope; marketplace and image-search discovery now require a positive `mainKindID` and re-filter every result to it.
- Added distinct unsupported, uncertain, not-animal, taxonomy-unavailable, and provider-failure states.
- Added identity-first unsupported UI with English/Arabic parity and accessible Scan Again recovery.
- Added bounded ambiguity metadata, stricter local-fallback specificity, and regression coverage for support leakage.

# Changelog

## 3.0.0 - 2026-08-07

- Removed Pet Profile eligibility, routing, persistence, and resolver coupling from the active scanner.
- Added an ephemeral, confidence-gated `DetectedAnimalContext` with species-only success.
- Added controlled multi-frame confirmation and one best representative-frame selection.
- Reused the host's existing Search by Image transport and canonical marketplace models.
- Added progressive Accessories, Services, Medicine, and Products discovery with partial-failure isolation.
- Added one over-camera discovery sheet, reusable-session Scan Again, and state-driven reticle behavior.
- Added native iOS 26 glass hierarchy with Material fallback, Arabic/English localization, and accessibility states.
- Added fail-closed validation against the current user-visible `MainKinds` snapshot before frame capture or discovery.
- Stabilized concurrent MainKinds loading with immutable snapshots, exact-once main-thread callbacks, cache-first delivery, and coalesced cold requests.
- Added an on-device general-classification fallback beyond Apple's cat/dog-only animal request, with explicit-label and saliency gates.
- Aligned the scanner with Pure Pets semantic colors and Beiruti Dynamic Type typography.

## 2.0.0 — 2026-08-06

- Renamed the canonical package product and customer-facing feature to **Pure Pets Eyes**.
- Added canonical SwiftUI, UIKit, and Objective-C entry names while keeping all 1.x symbols source-compatible.
- Embedded the anywhere-entry and saved Pet Profile contract into the public API and package documentation.
- Added the stable `pure_pets_eyes` identifier for remote configuration, analytics, and routing.
- Rebuilt the camera detector as an always-alive searching, stabilizing, detected, and resolving state machine.
- Added multi-frame confidence stabilization, dropout tolerance, and guarded replacement of an existing pet lock.
- Added automatic breed/species/category reveal beside the reticle and automatic resolution without a Discover tap, plus a clear paused recovery state after consent cancellation.
- Added a restrained bundled detection tone, prepared soft haptic, VoiceOver announcement, Reduce Motion, Reduce Transparency, and Differentiate Without Color behavior.
- Avoided JPEG materialization in metadata-only mode and added identity-aware keyframe throttling for selected-frame mode.
- Added deterministic tests for recognition parsing, stabilization, replacement, feedback deduplication, and frame-capture identity safety.

## 1.1.0 — 2026-08-02

- Added a fail-closed Pet Profile eligibility gate before camera permission, capture, AI processing, or backend resolution.
- Added host-owned Pet Profile routing for SwiftUI, UIKit, and Objective-C integrations.
- Added `PureLensFeatureButton`, a placement-independent SwiftUI entry point that can be styled and used on any screen.
- Added the anywhere-entry and Pet Profile contract with acceptance criteria.
- Added English and Arabic gate states for loading, required profile, retry, and recovery.
- Added client preflight validation and backend ownership requirements for `activePetID`.
- Added eligibility and missing-profile tests.

## 1.0.0 — 2026-08-02

- Initial Pure Lens SwiftUI package.
