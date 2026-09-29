# PureLens Detector 3.0 local upgrade plan

> Superseded on 2026-08-07 by the independent Pure Lens discovery refactor.
> The active contracts are `EntryPointContract.md`, `BackendContract.md`, and
> `IntegrationChecklist.md`; this file remains only as pre-refactor history.

Date: 2026-08-07
Source of truth: `/Users/mohammedahmed/Downloads/Pure-Pets-Eyes-SwiftUI-Package-3.0.0`
Integration target: `Pure Pets IOS/MyFrames/PureLensPackage`

## Objective

Upgrade the checked-in PureLens implementation in place to the extracted Detector 3.0 package without adding a second package, replacing the real feature with a demo, weakening the Pet Profile gate, or inventing breed/model/backend behavior. The host remains responsible for authenticated context, Firebase App Check, typed action routing, consent terms, and backend ownership checks.

The package's public product names, iOS 16 package floor, `PureLens` module import, `PurePetsEyes` compatibility product, Objective-C factory/delegate surface, and resource bundle remain the compatibility boundary.

## Files to replace from the 3.0 source package

Replace the implementation contents in the existing local package for these files:

- `Sources/PureLensCore/LensClients.swift`
- `Sources/PureLensCore/LensModels.swift`
- `Sources/PureLensCore/LensDetectionStabilizer.swift`
- `Sources/PureLens/PureLensConfiguration.swift`
- `Sources/PureLens/PureLensStore.swift`
- `Sources/PureLens/Camera/PureLensCameraController.swift`
- `Sources/PureLens/Camera/PureLensCameraPreview.swift`
- `Sources/PureLens/Camera/PureLensCoreMLDetector.swift`
- `Sources/PureLens/Camera/VisionLensDetector.swift`
- `Sources/PureLens/Components/LensCameraScene.swift`
- `Sources/PureLens/Feedback/PureLensDetectionFeedback.swift`
- `Sources/PureLens/PureLensView.swift`

These files form one safety unit. Partial adoption is not acceptable because spatial association, bound-frame capture, resolver snapshots, barcode policy, and store readiness are cross-layer contracts.

Add the 3.0 release-gate test file:

- `Tests/PureLensCoreTests/LensDetectorReleaseGateTests.swift`

Merge the downloaded package documentation into the checked-in package documentation, preserving local project history where it does not conflict:

- update `README.md`, `CHANGELOG.md`, `VERIFICATION.md`, and `Documentation/BackendContract.md`;
- add `Documentation/BreedModelContract.md`;
- add `Documentation/DetectorAcceptance.md`;
- retain/update `Documentation/IntegrationChecklist.md`, `ObjectiveCBridge.md`, and `ContrastEvidence.md`.

The downloaded `Package.swift`, `PureLensCoreExports.swift`, `PureLensExports.swift`, `PurePetsEyes.swift`, unchanged UI components, and localization/privacy resources are already compatible; they will be compared and only changed if validation finds a real local mismatch.

## Files to merge, not blindly replace

1. `Sources/PureLens/PureLensModule.swift`
   - Adopt the 3.0 module implementation.
   - Preserve the local public compatibility method `purePetsCameraPreview(localeIdentifier:contextProvider:)`, which the downloaded 3.0 package removed. Removing an existing public feature is forbidden.

2. `Sources/PureLens/Integration/PureLensUIKit.swift`
   - The downloaded and local bridge surfaces are source-compatible and currently equivalent. Keep one implementation, then validate that the new `LensContext`, `LensResolutionSnapshot`, barcode policy, and `LensActionReceipt` contracts remain reachable through it.
   - Do not introduce a second coordinator/store. Keep the delegate weak and the host coordinator alive for the presented controller.

3. `Pure Pets/MainApp/ModrenAppVC/SwiftUIHome/Routing/HomeRouter.swift`
   - Keep the existing Firebase Auth/App Check and Pet Profile coordinator wiring.
   - Supply a current, saved Pet Profile context with locale, timezone, client version, verified identity confidence, and only non-expired proactive hints.
   - Replace hardcoded `false`/`nil` consent and disclosure values with a versioned, consent-aware host provider.
   - Implement every enabled typed action, including `createListingDraft`, and return localized `LensActionReceipt` metadata. Cart preparation must remain prepare-only, revalidate stock/price, use the detector-provided `actionID` as idempotency input, and never complete checkout.
   - Add consent-aware analytics forwarding without sending frame bytes, access tokens, raw errors, or sensitive identifiers.
   - Verify the endpoint and request schema against `Pure Pets Infra/`; do not infer compatibility from the package documentation alone.

4. Host privacy/localization surfaces
   - Keep `NSCameraUsageDescription` in all supported host localizations.
   - Add the actual selected-frame processor/retention disclosure in Arabic and English; consent must be invalidated when processor, purpose, or retention terms change.
   - Keep the package's default metadata-only and barcode-disabled behavior intact unless a product decision explicitly enables a consent-gated mode.

5. Xcode package graph
   - Keep the existing local package reference and workspace.
   - Remove only stale duplicate PureLens/PurePetsEyes product/build-file records after confirming which product the app target intentionally links. Do not remove unrelated features or the device-only QIBPayment link.

## Compatibility risks and mitigations

- **Public API risk:** 3.0 adds fields and types to otherwise compatible models. Preserve the local `purePetsCameraPreview` method and compile all host call sites before changing project graph records.
- **Swift/Xcode risk:** the package declares Swift 5.10/iOS 16 while the app targets iOS 17 and uses Swift 5. Validate on the installed Xcode/iOS SDK; Linux parsing cannot prove AVFoundation, Vision, Core ML, or UIKit type checking.
- **Camera risk:** 3.0 changes BGRA/photo capture to bi-planar YUV video, reuses Vision/Core ML requests, carries interface orientation, and adds interruption/media-service recovery. Test portrait, upside-down portrait, landscape, interruptions, and resume on a physical device.
- **Model risk:** no production breed model is bundled. Without a validated object detector, the UI must show honest species/category output and must not fabricate a breed. A classifier-only or malformed model must degrade safely.
- **Backend risk:** the package contract describes `POST /v1/lens/resolve` and `stabilizedRecognition`; the existing host uses a Cloud Functions URL. Verify the deployed Firebase function, auth/App Check, schema, ownership, rate limits, deletion/retention, and typed response before enabling remote rollout.
- **Privacy risk:** selected-frame consent is temporal, not merely a Boolean. Raw barcode payloads are disabled by default and, if enabled, require explicit consent plus a fresh post-consent event. No pre-consent frame may be released.
- **Multi-pet risk:** ambiguous same-species crossings must freeze the last trustworthy reticle, suppress safe detection/capture/resolution, and require a new track to stabilize. Never fall back to the globally strongest label.
- **Host action risk:** incomplete route mappings, ignored action IDs, generic vet routing, or missing receipts can cause wrong navigation or non-idempotent writes. Treat each action as a typed contract and fail closed when required payloads are missing.
- **Performance risk:** 3.0's architecture is designed for lower cost but requires Instruments evidence for CPU/GPU, memory, energy, thermal state, frame latency, and dropped frames during a 10-minute session.
- **Existing work risk:** inspect repository status and preserve unrelated user changes. Make one logical edit per target file and never reset, clean, or overwrite unrelated project work.

## Migration sequence

1. Record repository status for the iOS project and verify the current package reference/product linkage.
2. Copy/merge the 3.0 source package files into the existing local package path, preserving the package identity and the local compatibility API.
3. Add the 3.0 release-gate tests and documentation contracts.
4. Reconcile `HomeRouter` with the package's new snapshot, context, action, consent, and analytics contracts using the existing host APIs and Infra as authority.
5. Reconcile host privacy strings and consent persistence/versioning. Keep raw frames and barcode payloads out of logs.
6. Validate package-level behavior: parse checks, localization key parity, privacy-manifest parsing, SwiftPM tests with warnings treated as errors, and all 3.0 deterministic invariants.
7. Validate app-level linkage with the workspace and scheme. Do not use simulator builds; use a connected-device build because the project contains a device-only payment framework.
8. Install and launch the built app on the connected iPhone. Exercise the real Home entry, Pet Profile gate, camera authorization, detection/reveal, consent, resolver, action, interruption/recovery, Arabic RTL, VoiceOver, Dynamic Type, Reduce Motion, and failure paths.
9. Use Instruments on the physical device for a 10-minute camera session and record observed memory stability, frame cadence, dropped frames, CPU/GPU, energy, and thermal state. If the tool/device/backend/model gate is unavailable, report it as unverified rather than claiming completion.
10. Perform a final acceptance review. Score only verified criteria; keep the remote feature flag closed for any unresolved backend, model, privacy-retention, accessibility, or device gate.

## Validation strategy

### Deterministic package tests

Required cases include:

- generic Dog → compatible breed enrichment;
- stable breed never downgraded by generic Dog frames;
- two same-species dogs remain separate;
- crossing ambiguity suspends safe resolution and recovers with a new track;
- wrong-pet, distant, spatially incompatible, future, and stale frame rejection;
- effective confidence equals bounded observation confidence × label confidence;
- confidence fluctuation, dropout tolerance, guarded replacement, and ambiguity recovery;
- immutable resolver snapshot, exact stabilized recognition propagation, and target-only metadata;
- barcode omission/redaction, explicit raw-payload consent, and post-consent race protection;
- malformed/unsupported model labels degrade safely;
- timestamp rollback, analysis throttling, detector failure throttling, and readiness gating.

### Host and UI checks

- no saved pet never requests camera access or calls the resolver;
- saved-pet and cancelled/incomplete Pet Profile flows remain fail-closed;
- detection states are living and meaningful: searching, stabilizing, detected, and resolving;
- result reveal is automatic and Discover remains optional;
- all interactive elements have VoiceOver labels/hints and 44-point targets;
- Arabic RTL/English LTR, Dynamic Type, Dark Mode, high contrast, Reduce Motion, Reduce Transparency, and Differentiate Without Color are verified;
- action routing is typed, localized, idempotent, and explicit about checkout confirmation.

### Device/performance checks

- connected iPhone build/install/launch succeeds;
- camera orientation, permission denial, interruption, media-service reset, background/resume, and thermal recovery work;
- Instruments captures the 10-minute session and results are recorded;
- no warnings, crashes, stale resolver results, duplicate feedback, or repeated sounds are observed.

## Go/no-go rule

The 3.0 package's downloaded reports are treated as input, not as local verification. A 95+ score may be assigned only to areas with executed evidence. A literal end-to-end 100 is not claimed until Xcode/device, production model, backend, privacy retention, accessibility, and Instruments gates pass. Any unresolved correctness, privacy, cross-pet, resolver-binding, crash, or warning issue blocks completion and must be fixed or reported as a remaining risk.
