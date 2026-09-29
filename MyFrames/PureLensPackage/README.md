# Pure Lens

Pure Lens is the independent visual animal-discovery feature for Pure Pets.
It detects an animal on-device, creates an ephemeral scanning-session context,
submits one representative frame to the app's shared Search by Image service,
and progressively combines compatible marketplace results.

No Pet Profile is required, selected, created, or persisted. A Pet Profile may
launch Pure Lens or provide an optional known hint, but it never controls camera
eligibility, detection, discovery, or result presentation.

## Active flow

```text
Open camera
  -> detect animal on-device
  -> confirm one spatial track across multiple frames
  -> validate species against user-visible MainKinds
  -> create DetectedAnimalContext
  -> present discovery sheet
  -> select one best representative frame
  -> run shared Search by Image once
  -> load compatible taxonomy categories progressively
  -> open canonical marketplace details
```

The discovery categories are Accessories, Services, Medicine, and Products.
Species-only recognition is a valid success. Breed is included only when its
confidence reaches the configured reliability floor.

## Package layout

```text
Sources/PureLensCore   Detection, context, discovery models, ranking and clients
Sources/PureLens       Camera, orchestration, SwiftUI presentation and UIKit bridge
Tests                  Deterministic contract, detector and client tests
Documentation          Entry-point, bridge and integration contracts
```

## Composition

The host supplies two read clients and one canonical routing client:

```swift
let module = PureLensModule.production(
    discovery: LensDiscoveryClient(
        isAnimalSupported: { animal in
            try await taxonomy.containsVisibleSpecies(animal.species)
        },
        searchByImage: { frame, animal in
            try await sharedImageSearch.search(frame: frame, animal: animal)
        },
        searchMarketplace: { category, animal in
            try await marketplace.search(category: category, animal: animal)
        }
    ),
    actionHandler: { item in
        try await canonicalRouter.open(item)
    }
)
```

`searchByImage` is invoked at most once per confirmed scan and only after the
user's remote-processing consent. Taxonomy searches begin immediately and fail
independently, so one unavailable dependency never suppresses other categories.
An animal missing from the live user-visible MainKinds snapshot stops detection
before context creation, frame capture, consent, upload, or marketplace search.

## Runtime guarantees

- Camera permission is requested without consulting Pet Profile state.
- Only one capture session and one active inference path are owned per scanner.
- Stable detection is temporal and spatial; a single frame cannot confirm.
- Apple's native cat/dog object request is supplemented by the on-device general
  image classifier for explicit bird, rabbit, fish, reptile, small-mammal, horse,
  camel, sheep, goat, and cow species labels.
- Classifier labels use an exact allowlist; incidental strings such as `hotdog`,
  `birdhouse`, and `fishbowl` cannot become animal detections.
- Stale inference and discovery results are rejected by session generation.
- Detection pauses after confirmation until Scan Again.
- Unsupported MainKinds results and taxonomy-read failures remain paused and
  explicitly confirm that no frame was shared.
- Scan Again clears the ephemeral context, frame and results, then reuses the
  existing capture session when it is safe.
- Backgrounding stops capture; foregrounding resumes only when appropriate.
- The scanner has localized denied, restricted, unavailable and interrupted states.
- Medicine is catalog discovery by compatible animal kind, never diagnosis.

## Pure Pets host integration

The consumer app composes the package through `PPPureLensHostPresenter`.
`PPPureLensDiscoveryBridge` resolves detected species against server-driven
user-visible `MainKinds`, reuses `PPImageSearchService`, loads `petAccessories` and
`serviceOffers` through existing managers, and routes results through
`PPOverlayCoordinator`.

The host supplies Pure Pets semantic color tokens and Beiruti Dynamic Type
typography. The package retains system fallbacks for reuse outside the app.

The existing Search Controller continues to call `PPImageSearchService`; its
image preparation now forwards into the same reusable data-search entry point.

## Platform behavior

- iOS 26 and newer use native Liquid Glass where the SDK exposes it.
- Earlier supported releases use system Material hierarchy.
- Arabic and English resources are bundled with semantic RTL/LTR layout.
- VoiceOver, Dynamic Type, Reduce Motion, Differentiate Without Color, camera
  permission recovery, partial failures, and empty results are first-class states.

See [EntryPointContract.md](Documentation/EntryPointContract.md),
[ObjectiveCBridge.md](Documentation/ObjectiveCBridge.md), and
[IntegrationChecklist.md](Documentation/IntegrationChecklist.md).
