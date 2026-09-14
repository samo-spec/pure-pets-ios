# MainKindsCellV2 — Living Threshold
Updated: 2026-09-13

Status: integrated in the default Home category presentation. Source checks and independent code review pass. Native build, linkage, rendering, accessibility behavior, animation performance, and physical-device interaction remain UNVERIFIED.

## Product idea
- The Home hero already owns the large selected-animal portrait. Repeating the same animals in a row of cards weakened the first impression and duplicated meaning.
- The default selector is now a continuous living threshold: open typography, one quiet organic seam, and one moving trace that changes character by species.
- Source-backed category families produce orbit, feather, wing, whisker, paw, fish, or hoof traces. Unknown server categories receive the conservative paw trace.
- The selected trace, stronger type, and point marker communicate scope without depending on color. Category accent remains identity, not a tile fill.
- “Show all” still reveals the existing portrait grid. Nothing was destroyed to obtain the stronger default composition.

## Integration
- HomeCategoryRail mounts HomeMainKindsLivingThresholdV2 in its compact state.
- HomeStore remains the only owner of committed selection, persistence, routing, reloads, and the selection haptic.
- Taps retain the original callback. When five or fewer items fit at 64pt minimum width, the upper seam can be scrubbed; the preview is local and commits exactly once on touch-up.
- Compact widths, more categories, and accessibility Dynamic Type use a horizontally scrolling button rail centered on the committed selection.
- The existing MainKindsCellV2 UIKit renderer remains the expanded-grid renderer.
- PPMainKindsCell.swift and its original adapter remain present and unchanged.

## Motion and interaction
- A matched-geometry trace travels between species with one interruptible spring; its shape and semantic accent transform together.
- Touch compression is bounded and preserves native Button behavior.
- Reduce Motion removes interpolation and scrub lift while retaining every state signal.
- Resignation, backgrounding, disappearance, vertical-gesture rejection, and no-op callbacks clear transient scrub state.
- Simultaneous gesture composition preserves taps across the full button, including the trace area, while the scrub flag prevents a second route on touch-up.

## Accessibility and adaptation
| Concern | Implementation |
| --- | --- |
| VoiceOver | Native Buttons, localized labels and hints, stable identifiers, and committed .isSelected traits. Decorative seam/traces are hidden. |
| Dynamic Type | Beiruti text scales semantically; AX sizes receive two lines, wider scrolling targets, and up to 156pt selector height. |
| Touch | Minimum direct-scrub item width is 64pt; all button surfaces exceed the 44pt minimum target. |
| RTL/LTR | Logical SwiftUI layout plus explicit visual-to-logical scrub mapping; no animal artwork is mirrored. |
| Contrast | Selected meaning is not color-only; Increased Contrast promotes trace and seam ink to ppTextPrimary. |
| Adaptivity | Direct scrub is enabled only when every item fits; otherwise the selector preserves all categories through scrolling. |
| Images | The compact selector has no image requests. The retained expanded grid keeps the existing guarded loader, reuse cancellation, and fallbacks. |

## Verification evidence
- Swift frontend parse of HomeComponents.swift and MainKindsCellV2.swift: exit 0. This is syntax validation, not full typechecking or an app build.
- English and Arabic Localizable.strings plutil validation: OK; each new key appears once per locale.
- git diff --check: exit 0.
- Fresh preservation diff for PPMainKindsCell.swift and HomeStore.swift: empty.
- CodeRabbit first pass raised one minor hit-testing issue. It was corrected; the final scoped review completed with 0 issues.
- No simulator, generic xcodebuild, install, deploy, commit, or push was performed.

Current source SHA-256:
- HomeComponents: ee742531adebbf41e5152ed3b7cdadf6da617ebf42a653f2acc7ef5bac5b7239
- UIKit V2: 4e61197bc18e169d4bb8affa1473de65d3d6b5b304062d8c1d1abf7ee263fbaa
- Original PPMainKindsCell: 71d859f7398ab78c62bbd1a5f9a377b976668833f44fb6374ac65003ab1e22d5
- HomeStore: 4f3af9200ce893bb2c873a227d6252d00d368b0c118a080b18bb9290358910fb
- English localization: 8cb6d5bf4aee95797082d849297c56a126e7529a09d398f202fbac3a36de8e7b
- Arabic localization: 88a4e95eb99722e952e28fb7e0e8819ff200589de5e17e4fa4bda3d719a3276c

## Required native gate
The Project Brain requires explicit approval for the physical iPhone 13 Pro Max build workflow using default DerivedData; a simulator is not an accepted substitute. After approval, build/install and capture the real Home in Arabic and English, then exercise tap and scrub routing, All/category persistence, interruption, light/dark appearance, maximum Dynamic Type, VoiceOver, Increased Contrast, and Reduce Motion. Only that gate can establish native visual and motion quality.

Rollback is narrow: HomeCategoryRail can return to its retained compact UIKit V2 renderer without changing state, routing, or the expanded grid.
