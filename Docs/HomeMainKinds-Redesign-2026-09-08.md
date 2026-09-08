# Home MainKinds portrait redesign

Date: 2026-09-08

Source baseline: `c354d0ae95a0c2f636ab606dcb17d1e073bfed06`

Status: Implementation and source review completed. Native build, rendered device, accessibility interaction, motion capture, and performance proof remain **UNVERIFIED**. No build or deployment was authorized or run.

## Scope and design decision

The live chain is `HomeView` → `HomeCategoryRail` → `HomeMainKindCellRepresentable` → `PPMainKindsCell`. `HomeStore.selectCategory` continues to own selection, persistence, haptics, and the existing category/All route.

Three structures were considered before implementation:

| Direction | Assessment |
| --- | --- |
| Open animal portrait with an independent caption | Selected. Keeps recognition and the category name clear at the existing compact rail widths, gives selection one distinct mark, and scales into the existing expanded grid. |
| Asymmetric typographic field ticket | Rejected. Competing title/tag regions consume the narrow rail width and weaken animal recognition. |
| Horizontal portrait and label strip | Rejected. It requires substantially wider cells or compressed artwork in the phone rail. |

The implemented cell uses a softly arched background behind the existing aspect-fit animal artwork. The name sits outside that background. A check at the field's lower logical trailing edge, selected Beiruti weight, and the existing category color identify selection. Passive cells use neutral PP surfaces. The background shape does not mask the animal. Layered glass, pedestals, gradients, and halo/echo effects from the previous cell were removed.

## Files

- `Pure Pets/MainApp/ModrenAppVC/HomeCells/PPMainKindsCell.swift`: replaces the private presentation graph and feedback mechanics; preserves the public UIKit/Objective-C integration and model adaptation.
- `Pure Pets/MainApp/ModrenAppVC/SwiftUIHome/Views/HomeComponents.swift`: adjusts only `HomeCategoryRail` caption budgeting, accessibility rail widths/grid columns, and the bridge's explanatory comment.

Existing unrelated messaging and localization edits were preserved. No Firebase, permissions, collections, data models, navigation destinations, or localization entries were changed.

## Preserved behavior and states

- Existing category order, numeric IDs, stable scroll IDs, logical scroll anchoring, All action, and Show All/Show Less behavior remain in their original owners.
- Objective-C class identity, both configuration selectors, `onSelect`, `boundCellID`, restored-selection hooks, and the All-preview integration hook remain available. All retains the bundled `menugrid` glyph.
- The model adapter and palette contrast helpers are unchanged. Existing Arabic/English titles and the `Language` semantic-direction helper are reused.
- Artwork preserves the local image → asset → icon → fallback chain and the shared image loader. Loading/failure keeps the existing usable placeholder. Completion checks generation, binding identity, and URL before application; requests are cancelled on reuse/rebind. No image is horizontally reflected for RTL.
- One native button exposes the category label, stable accessibility ID, selected/disabled traits, and Large Content Viewer data. An unavailable callback disables the action. Empty category data retains the original All entry and Home's existing state ownership.
- Dynamic Type is uncapped. The rail reserves scaled caption height; captions use two lines, or three from XXXL upward. Accessibility sizes widen the rail cells and reduce expanded-grid columns to two or one, depending on available width and text size.
- Dark mode and Increased Contrast use existing resolved PP tokens and contrast helpers. The check foreground is chosen against its actual accent fill. The field is opaque, so Reduce Transparency has an equivalent static appearance.

## Motion and cancellation

| Event | Presentation | Behavior |
| --- | --- | --- |
| Touch down/drag enter | Portrait compresses to 0.974 and fades to 0.86 over 90 ms | Caption remains stationary; no additional haptic owner. |
| Accepted activation | Portrait returns to rest over 180 ms | Existing callback fires once after completion, subject to generation, binding, and window checks. |
| Cancel/drag exit/debounced release | Portrait returns to rest | A rejected rapid tap cannot leave the cell visually pressed. |
| Selection/restoration | Finite appearance feedback, 180/120 ms | No looping animation or separate navigation owner. |
| Reduce Motion | Static touch feedback and immediate activation | Same model, All semantics, and destination; live setting changes cancel motion. |
| Reuse/rebind/disappearance/background/dismantle | Animators stop and appearance resets | Pending activation is invalidated; clearing `onSelect` cancels its owned activation. |

## Verification evidence

- `xcrun swiftc -frontend -parse` passed for both changed Swift files. This proves parsing only, not type checking, linkage, signing, installation, or runtime behavior.
- Scoped `git diff --check` passed.
- Thirty transient source-preservation checks passed against the baseline, covering bridge selectors, model/palette adaptation, callback and scroll ownership, image fallbacks/guards, button semantics, and unchanged Home state/router/data-bridge/view sources.
- A 180-case arithmetic layout stress check passed for rail/grid widths and hypothetical text scale factors. Bundled Beiruti font metadata was inspected to compare the 18-point base line height with the rail's 22-point scaled reserve. These checks do not substitute for UIKit text rendering or a native Dynamic Type matrix.
- The NextGen brand validator accepted the source-backed PP token and asset brief. This is structural validation, not visual certification.
- The static UI audit emitted a `reduce-motion-missing` hint at animator declarations. Manual source review confirms the `reduceMotion` property, explicit guards in all three animation entry paths, and live-setting cancellation. The hint does not establish a missing guard; runtime behavior still requires device proof.
- Independent read-only review found no remaining concrete source regression after the rapid-tap release fix.
- Visual preflight remains **BLOCKED/UNVERIFIED**: no current Home baseline capture or authorized native render was available. No overall quality score or release certification is claimed.

Source hashes at handoff:

```text
fd124824dce735366f5fdcb0fc17cfcb703af6ca5ec7d224f8c3a2cbc0c3b3d3  PPMainKindsCell.swift
5e38bddc0eae555c69e3056404c8d278289ae8094daa2773d641f7a6797adcf3  HomeComponents.swift
```

## Remaining verification

When explicitly authorized, use the approved physical iPhone workflow and default Xcode DerivedData. Capture the live Home rail and expanded grid in Arabic/English, light/dark, standard/large accessibility text, Increased Contrast, and Reduce Motion. Verify All/category navigation, rapid taps across different cells, scroll-versus-tap cancellation, backgrounding, and visible image reuse. Confirm artwork balance and caption wrapping with real category content, then capture motion/performance evidence. Do not reuse historical device proof for this patch.
