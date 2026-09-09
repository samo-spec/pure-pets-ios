# Home MainKinds animal gallery — revised implementation

Updated: 2026-09-09

Source baseline: `60cb055733c31c6054e6ffa20af185bf53eac515`

Status: The revised implementation, source checks, and independent source review are finished. The candidate has **not** been built, installed, or rendered. Physical-device visual, accessibility, interaction, motion, and performance verification remain **UNVERIFIED**. Explicit build authorization is still required by the supplied AGENTS.md instructions.

## Actual baseline and revision

The user supplied two real Arabic/light Home screenshots on 2026-09-08 at 20:20:17 and 20:20:29, showing Birds and All selected. These exposed weaknesses in the previous implementation: repeated tall arches dominated the artwork, names appeared disconnected from the portraits, the tick read as a generic checkbox, and the All grid glyph did not belong to the animal imagery.

The caption gap also had a concrete layout cause: a one-line name was vertically centered inside a reserved two-line UILabel frame. The revision measures the actual caption and positions that frame four points after the portrait canvas.

This document supersedes the earlier arch/check design and its source hashes. Historical source or device evidence does not verify this candidate.

## Chosen direction

Three structurally different options were assessed against the supplied screenshots:

| Direction | Assessment |
| --- | --- |
| Unframed animal gallery; one low selected surface joins portrait and caption | Selected after independent critique. Keeps animal recognition dominant, integrates state with the content, retains fixed tap targets, and fits the expanded grid. |
| Connected editorial index with a shared rail and reversed selected label | Rejected. Risks becoming ordinary picture tabs and introduces another rail-wide drawing owner through scrolling/grid changes. |
| A wide featured selected animal among compact passive portraits | Rejected. Changes subsequent target positions and the next-item peek; duplicates the large hero and complicates scroll/activation behavior. |

The selected design uses the existing category artwork directly on Home. Passive animals have no enclosing surface, outline, shadow, or badge. Only the selected animal has a low, solid category-colored surface extending behind its lower portrait and caption. It has a 6-point corner radius, contrasting text, and no tick. Beiruti captions increase from a 15-point to an 18-point base and remain uncapped under Dynamic Type.

All becomes an ensemble of up to three already supplied category images. The existing All glyph remains until at least two images are available. Empty, partial, and failed image loading do not fabricate additional animals or leave All blank.

## Live ownership and changed files

The flow remains `HomeView → HomeCategoryRail → HomeMainKindCellRepresentable → PPMainKindsCell`. `HomeStore.selectCategory` owns the selected scope, persistence, haptics, and the original category/All navigation.

- `Pure Pets/MainApp/ModrenAppVC/HomeCells/PPMainKindsCell.swift`: gallery presentation, selected surface, actual caption measurement, All ensemble, and safe visible-image application.
- `Pure Pets/MainApp/ModrenAppVC/SwiftUIHome/Views/HomeComponents.swift`: shared gallery sizing within HomeCategoryRail, separate grid measurement at actual column width, and tighter bottom spacing.
- This handoff.

Objective-C class identity, both configure selectors, public hooks, original NSObject/All callback semantics, category ordering/IDs, scroll anchoring, Show All/Show Less, and the UIKit bridge remain intact. HomeStore, HomeRouter, HomeModelAdapter, PPHomeDataBridge, HomeView, and HomeViewState are unchanged.

Firebase, permissions, collections, backend contracts, model fields, localization entries, the hero, and other Home sections are outside this patch. Existing localization and PP colors/spacing/fonts remain authoritative.

## Layout and native behavior

- Ordinary rail widths remain 102 / 112.2 / 119 points. Selection never expands or reorders items.
- Actual medium/bold caption measurements determine the required row height. Measurement is performed once per rail/grid body update, rather than once for every child.
- The label occupies its measured height and begins four points after the portrait canvas. Two-line text is supported, increasing to three from XXXL upward. Full labels remain available to accessibility.
- Accessibility sizes widen the rail and retain the two-/one-column grid adaptation. Grid height is calculated from the grid's column width, independently of rail width.
- Artwork stays aspect-fit, unmasked, and unreflected. Existing optical profiles remain shared with Home; oversized canvases align to the portrait baseline so they cannot cover the caption.
- One native button exposes the existing ID, label, selected/disabled traits, and Large Content Viewer data. An unavailable callback disables it.
- The selected foreground is chosen by measured contrast against its actual fill. The surface is opaque and uses the existing contrast-safe category palette for light/dark and Increased Contrast.

## Image and motion ownership

The shared image loader applies an image before invoking the client completion. Generation checks solely inside that completion could therefore be too late to prevent a stale visible write. The cell now retains detached request UIImageViews; only a completion matching generation, binding, and URL can copy its image into the visible artwork. Reuse/rebind cancels and clears primary/ensemble requests. The same loader and cache remain in use, with no new URLs or fetch subsystem.

Touch feedback remains a finite 90 ms portrait compression followed by a 180 ms release. The existing callback fires after release, subject to its original debounce, generation, binding, and window checks. Rejected rapid taps release pressure; reuse, rebind, disappearance, backgrounding, and callback removal cancel pending activation.

Selection text and its ink update together at full contrast. Only the selected surface settles upward by three points over 180 ms (120 ms for the retained restoration hook). It is laid out with bounds/center so an interrupted transform does not corrupt its frame. Reduce Motion applies the same state without spatial animation and invokes the original activation callback immediately.

## Current verification

- Swift frontend parsing passed for both changed Swift files. Parsing does not prove type correctness, linkage, signing, or runtime behavior.
- Scoped whitespace/diff checks passed.
- Thirty transient source-preservation/ownership checks passed against the baseline, including selectors, model/palette adaptation, callback ordering, scroll ownership, image request isolation, and unchanged downstream owners.
- 480 arithmetic geometry/selected-text coverage cases passed for rail/grid widths and hypothetical text scales. These are geometry stress checks, not native Dynamic Type or glyph-rendering proof.
- Independent screenshot-based concept assessment selected the gallery direction. Independent read-only review of the resulting two-file diff found no remaining concrete source-level regression.
- The bounded UI analyzer emitted a `reduce-motion-missing` lexical hint at animator declarations. Manual review confirms the property, explicit guards in all animation entry paths, and live-setting cancellation; the analyzer does not follow those indirections. No zero-findings or runtime-accessibility claim is made.
- Visual preflight has real user-supplied baseline evidence but no authorized candidate render. No quality score, Apple endorsement, or release certification is claimed.
- The approved iPhone 13 Pro Max was found paired and available. Read-only lock-state inspection returned `passcodeRequired: false` and `unlockedSinceBoot: true`. No build or app launch was performed.

Source hashes at handoff:

~~~text
566d1d674b16f14c2700119cde357dabc785623dacb40bda52b2a693cd0360aa  PPMainKindsCell.swift
d104d485389514501f3264193b5e61ff89169e898e425b4dfbdfb843d407c5ae  HomeComponents.swift
~~~

## Continue from here

After explicit authorization, build/install using the approved physical iPhone 13 Pro Max workflow and Xcode's default DerivedData. Inspect the real candidate against the two supplied baseline states. Check the unframed animal balance, selected surface integration, All ensemble overlap, and caption spacing with actual category artwork.

Verify Arabic/English, light/dark, standard/maximum accessibility text, Increased Contrast, and Reduce Motion. Exercise All/category navigation, Show All/Show Less, fast taps across cells, scroll-versus-tap cancellation, image failures/reuse, and backgrounding. Capture actual motion and performance evidence separately from still screenshots. Resume this verification phase; the implementation and source-review phase need not be restarted.
