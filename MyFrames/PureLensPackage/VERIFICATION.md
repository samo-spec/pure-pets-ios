# Pure Lens verification record

## 2026-09-29 — exact identity and uncertainty choices

Scope: Infra recognition and taxonomy matching, consumer iOS result flow and
host bridge. Android has no Pure Lens identity client and was not changed.

### Verified

- Infra `test:lens-animal-identity` and `test:lens-resolve` pass. Regressions cover
  wildlife/category collisions, contradictory names, plural broad labels,
  uncertainty candidates, selected-species mismatch, malformed provider output,
  Arabic names, account-state rejection, and no taxonomy access for uncertainty.
- `test:app-check` passes locally for all 10 callable presets. Its temporary
  localhost listener required sandbox permission; no production request occurred.
- Astra independently reviewed the backend and iOS fixes. All reported high and
  medium source findings were addressed; its focused re-review found no new high
  or medium regression in those repaired points.
- Touched Swift files pass syntax parsing. English/Arabic localization and the
  privacy manifest pass plist lint; all 166 Lens keys match with no duplicates.
- Scoped whitespace checks and the Project Brain integrity check pass.
- The package's broken Git link was replaced with its authored files at the same
  path. Existing resources and source were preserved; build/cache files remain
  excluded, and Xcode's local package reference is unchanged.

### Unverified release gates

- Native compilation, Swift test execution, physical iPhone interaction, actual
  VoiceOver order, and Arabic/English AX5 rendering were not run. The workspace
  requires explicit build permission and its approved physical-device workflow.
- Real-image accuracy is unverified. Two prompts use the same existing model;
  agreement is a consistency check and cannot prove perfect classification.
- No backend deploy or production mutation occurred. The running app/backend
  will not receive these changes until the corresponding releases are approved.

### Required device scenarios

1. Lion/tiger must not open Cats; falcon species must not silently become Birds.
2. A known unsupported animal keeps its recognized name and shows no catalog.
3. Two/three exact choices plus None are reachable; a rejected or changed choice
   cannot open commerce. Scan Again/dismissal invalidates late callbacks.
4. Model failure, catalog failure, denied consent, and missing frame stay distinct
   non-commerce states. The selected frame is cleared when the scan ends.
5. Check long Arabic/English choices at AX5, VoiceOver, Reduce Motion, and compact
   layout. The complete prompt scrolls within available height.

The inference change makes two parallel model requests per scan, and another
two after a choice. Each awaited response has a 12-second timeout, which does
not cancel upstream provider work.

## Historical record — 2026-08-07

The evidence below predates the September changes and is not current proof.

Date: 2026-08-07
Scope: independent animal discovery refactor in the Pure Pets iOS workspace

## Root-cause evidence

- The previous live detector used `VNRecognizeAnimalsRequest`, whose native responsibility is cat-and-dog recognition. That is why the experience appeared cat-centric and could not represent the app's broader animal taxonomy.
- The supplied recording `4D6E4380-4ED2-4CC3-9B84-0504DB5A341D.MP4` is a 12.64-second, 1284 x 2778 HEVC capture. It shows the previous runtime confirming a cat at 63 percent and opening the progressive discovery sheet. It proves that cat path only; it does not prove reliable non-cat recognition.
- Running Apple's general Vision classifier against the representative cat frame returned the mutually consistent labels `animal`, `cat`, `feline`, and `adult_cat` at about 0.843 confidence. This supports the new guarded classifier fallback, but is not a device-camera release test.
- The old zero-profile failure existed in the host router, package UI/store policy, legacy resolver transport, and profile-owned backend contract. The active standalone flow no longer calls that profile-owned resolver.

## Current static verification

- Every Swift source and test file in `Sources` and `Tests` passes `swiftc -frontend -parse` with the installed Apple toolchain.
- `PureLensCore` passes a standalone Apple-toolchain type-check, and all current Pure Lens UI/camera sources pass an iPhoneOS frontend type-check against that module with the generated resource accessor.
- `MainKindsArrayManager.m`, `PPImageSearchService.m`, and `PPUserMenuViewController.m` pass focused Objective-C syntax checks against the existing iPhoneOS index response and project prefix header.
- English and Arabic package localization plists, English and Arabic host localization plists, `PrivacyInfo.xcprivacy`, and the host `Info.plist` pass `plutil -lint`.
- `git diff --check` passes.
- The SwiftyMax strict audit reports no actionable broad animations: every reported multiline animation is explicitly scoped to a value.
- Pure Lens text styles resolve through Beiruti Regular, Medium, or Bold with Dynamic Type metrics and a system fallback. Remaining direct system-font calls size SF Symbols only.
- Pure Lens colors are mapped to the host's semantic Pure Pets assets and injected through `PureLensTheme`.
- MainKinds loading is cache-first, coalesces simultaneous cold loads, publishes visible taxonomy on the main thread, and exposes an immutable queue-safe snapshot for new consumers.
- Unsupported detected species pause analysis before representative-frame capture or image upload. A taxonomy load error is distinct from an authoritative unsupported result.
- Animal confirmation is temporal, and only one representative frame enters the shared Search by Image transport.
- The classifier taxonomy uses exact allowlisted labels and rejects collision labels including `hotdog`, `birdhouse`, `fishbowl`, and `computer_mouse`.

## Test evidence boundary

- Before the latest MainKinds, classifier-species, and documentation delta, 96 SwiftPM tests passed with 0 failures.
- The latest delta has static parse/type-check coverage only. No test build was run because workspace policy requires explicit user permission.
- No Xcode build, install, simulator run, or physical-device run was performed. Workspace policy forbids simulator and terminal `xcodebuild`; physical-device validation must use the Xcode Run UI.
- No Firebase resource was changed or deployed.

## Required physical-device release gate

1. Use a user with zero PetProfiles and verify open, stable detection, taxonomy validation, progressive results, detail routing, and Scan Again without creating or selecting a profile.
2. Test real dog, bird, rabbit, fish, reptile, small-mammal, horse, camel, sheep, goat, and cow subjects or controlled fixtures. Confirm non-animal scenes never lock.
3. Verify that an animal absent from live `MainKindsCollection` produces the paused unsupported state with no image-search request.
4. Exercise Search by Image failure and each taxonomy category failure independently; remaining sections must continue loading.
5. Exercise camera denial, interruption, background/foreground, repeated open-scan-close cycles, and thermal behavior on a supported physical iPhone.
6. Inspect Arabic RTL and English LTR in light/dark mode, Dynamic Type through accessibility sizes, VoiceOver, Reduce Motion, and Reduce Transparency.
7. Verify iOS 26 native Liquid Glass and the older-iOS Material fallback on their actual OS versions.

The primary zero-PetProfile acceptance test and broad-species accuracy remain `UNVERIFIED` until this physical-device gate is completed.
