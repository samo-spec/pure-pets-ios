# Pure Lens data-service contract

The active Pure Lens discovery flow does not call the legacy `/v1/lens/resolve`
endpoint. That endpoint may remain profile-bound for older consumers, but it is
not part of scanner eligibility or discovery orchestration.

## Animal detection

On-device detection locates a stable animal subject and supplies a provisional
hint. The selected-frame identity callable decides the animal identity before
production discovery.

It returns an ephemeral `DetectedAnimalContext` containing species, optional
confidence-gated breed, confidence, detection source, bounding box and track ID.
The context is not written to Firebase.

## Search by Image

The host reuses the existing `imageSearch` callable through
`PPImageSearchService`. It answers which visually relevant marketplace items
match one selected frame. The scanner must not upload live frames, and must not
invoke image search more than once for a confirmed scan.

Existing Firebase Auth, App Check, callable validation, visibility rules and
catalog authorization remain authoritative. If image search is unavailable,
Pure Lens continues with taxonomy discovery.

## Marketplace taxonomy

The host resolves detected species against live `MainKinds` and reads through
existing managers:

- `petAccessories`, type 1: Accessories
- `serviceOffers`: Services
- `petAccessories`, type 4: Medicine
- `petAccessories`, type 2: Products

No new collection, document shape, permission, or write path is introduced.
Blocked, deleted, disabled, incompatible, or non-market records are filtered
before presentation. Medicine remains catalog discovery and never diagnosis.

Hidden `MainKinds` never authorize a discovery session; Infra retains its legacy
compatibility for documents without an explicit visibility flag. Production selected-frame recognition obtains the authoritative
category from the identity callable after the user consents to the selected
frame, and before any marketplace request. An empty or failed taxonomy load is
not treated as permission to continue; an unsupported species and a taxonomy
availability failure are separate user-visible states.

## Universal animal identity and commerce authorization

Pure Lens animal identity is open-world: the server-assisted `lensAnimalIdentify`
callable may identify an animal even when Pure Pets has no matching marketplace
category. Business support is closed-world and is resolved independently against
the current live, user-visible `MainKindsCollection`. The recognition model never
decides whether Pure Pets supports an animal.

A positive commerce path requires a canonical `mainKindID`. The local support
resolver remains for metadata-only/legacy configurations, but a failed or timed
out production identity call never falls back to it. The legacy Boolean support
signal remains source-compatible but `true` alone never authorizes discovery. Generic
local labels such as `animal`, `bird`, `mammal`, `reptile`, `fish`, and
`small mammal` are insufficient support evidence.

Every taxonomy result and image-search item is revalidated against the same
canonical `mainKindID` before presentation. A conflicting image-search kind
from the callable's actual `detected.categoryId` invalidates that image-search
result set. Species text, breed relevance, and
visual similarity may rank only within the validated category and may never
expand its scope.

`lensAnimalIdentify` keeps its schema-version-1 status and support fields. An
`uncertain` single-subject response may add two or three distinct
`identification.candidates` with `commonName`, `canonicalSpecies`, optional
`scientificName`, and `confidence`. `identification.commonNameAr` and each
candidate's `commonNameAr` are optional Arabic display text only; canonical
matching and commerce never depend on those display names. Uncertain support
is always false with no `mainKindID`.

Both server and client suppress broad labels, contradictory identity names,
duplicate choices, choices below 0.35 confidence, and multiple-animal choices.
Fewer than two remaining candidates means there is no choice list; the recovery
action is Scan Again.

If the user chooses one of the candidates, the client resubmits the original
consented image to the same callable with `selectedCanonicalSpecies`. The server
reclassifies the image, accepts the choice only if that species is independently
identified again or remains among its fresh candidates, and resolves support
against live visible taxonomy. A different newly identified species cannot
replace the chosen animal or start commerce. The
choice itself never grants a category. “None of these” stays in a non-commerce
state and offers Scan Again; it sends no selected species. An exact identified
animal with no supported category is shown as unsupported with its identity.

`unsupported`, `uncertain`, `not_animal`, and `taxonomy_unavailable` are terminal
identity states for that scan generation and perform no marketplace or
image-search calls. Taxonomy load failure is not reported as unsupported.
Unsupported animals may still show their recognized identity, but never fake or
irrelevant commerce recommendations.

## Ranking

The host first enforces species compatibility. Within the compatible set, the
package ranks reliable breed matches before visual similarity, then preserves
the marketplace's canonical relevance order. Visual similarity cannot override
species incompatibility.

## Failure and privacy

Category calls are independent and may complete in any order. A failed category
does not cancel successful categories. Remote image processing requires explicit
versioned consent, and the representative frame is cleared with the scanning
session. No Pet Profile is synthesized as transport context.

The callable requires an authenticated, eligible existing `UsersCol` account
and retains App Check enforcement. Recognition uses two image-only prompts in
parallel with a 12-second timeout per awaited response. The prompts use the same
model, so their agreement is a consistency check, not independent accuracy
proof. This adds a second inference per scan; candidate confirmation repeats
both calls. Application timeouts do not cancel provider processing.

## Source packaging

`MyFrames/PureLensPackage` is tracked as ordinary package source at its existing
path. The former Git link had neither a submodule mapping nor a reachable local
commit. The conversion preserved all 54 authored package files and resources;
`.build` and `.swiftpm` remain ignored. Xcode continues to use the same local
package reference.
