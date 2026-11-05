# Universal service cell — NextGen V7

## Scope and evidence boundary

- Request: redesign only the consumer universal cell's service mode; preserve ads, products, medicine, food, pets, vets and every other mode.
- Baseline: `4e9872b626e2c622eb92ebcfb30c4bc1f7b1f355`, clean checkout. Original source and baseline manifest: `/tmp/pp-service-v7-86R3qG`.
- Entry: user explicitly selected `swiftymax-nextgen-category-defining-v7`, superseding the default V6 routing for this task.
- Existing architecture: `PPUniversalCell.m` registers `PPUniversalCardHostingCell`; `PPUniversalCardRenderer` dispatches `.services` to the existing SwiftUI `PPUniversalServiceCard`. No platform migration.
- Build/run permission has not been granted for this task. Native rendering, VoiceOver, motion, performance and device behavior remain UNVERIFIED. No Simulator, app build, install, deploy or production write is authorized by this handoff.

## Phase 1 — Inspection completed

- Inspected the service projection, renderer, action/store boundaries, shared image pipeline, UIKit fitting helper, Search/My Services sizing, Home wrapper and Marketplace layouts.
- Screenshot friction: tiny artwork, oversize/truncated title, large empty middle, review text squeezed beside two 44pt actions, and compact fallback removing the open-service cue.
- Service facts stay in `PPUniversalServiceNote`: locale-formatted price, `ServiceModel.isLive`, bounded rating and real review count. Store/delegate remain navigation and action owners.
- Reuse guards, favorites/auth, context actions, owner editing/visibility/deletion, provider chat and video must survive unchanged.
- Hosts: intrinsic Marketplace cards; bounded Home, focus and legacy UIKit cells; Search measures service content. iOS 15 compatibility paths remain intact.

## Phase 2 — Invention / selection completed

- V7 strategy and invention-round tools ran. Two source-feasible alternatives: service window (photo → identity → terms → reputation → open cue) and textual comparison ledger.
- Independent reviewer `service_v7_review` assessed both concepts across all sixteen V7 dimensions and selected the service window. The ledger lost recognizable service imagery and overemphasized price. The selected composition uses full-width reviews, sibling utility controls and a deliberate image-failure fallback, with no added business data or navigation step.
- V7 portfolio evaluation, synthesis and implementation planning each returned `readyForImplementation: true`. These are advisory planning results, not runtime certification. Source-bound brand validation passed. Records are in `/tmp/pp-service-v7-86R3qG/`.
- Adaptation: logical leading/trailing, unlimited title wrapping, localized currency, 44pt utility targets; compact media and readable scrolling for constrained hosts.
- Motion: retain the existing bounded press/entrance ownership and Reduce Motion behavior; add no continuous effects.

## Phase 3 — Implementation completed

- Changed only the service presentation section of `PPUniversalCellSwiftUI.swift`.
- Replaced tiny thumbnails and the separated review/action footer with an inset service photo, category/title, price/availability, a full-width reputation line and a consistent localized open cue.
- Removed the expanding vertical spacer and title/category/review truncation. Bounded hosts try reduced artwork height before a vertical scroll fallback; intrinsic hosts size to content.
- Favorite/menu are sibling controls outside the main Button, on a solid capsule with 44pt targets and an Increased Contrast border.
- Added a service-only semantic image placeholder. It keeps SF Symbols at their intended proportions even when the shared image view uses aspect fill. The existing loader, image references, cancellation and cache remain authoritative.
- Placeholder cache has count/cost limits, native display scale and keys/signatures bound to dimensions, direction, theme and contrast. Measurement starts no image/favorite reads.
- Kept current entrance/press motion, background/disappear cleanup and Reduce Motion ownership.
- No new localization keys were necessary; all product copy uses the existing Arabic/English system. Provider-authored titles/categories are preserved as content.

## Phase 4 — Source verification completed

- `xcrun swiftc -frontend -parse` passed for the edited file; this is syntax parsing, not an app build or typecheck.
- Scoped `git diff --check` passed.
- Existing `scripts/universal_cell_variant_info_static_test.py` passed all of its reported checks.
- Arabic and English `Localizable.strings` passed `plutil -lint`; service localization lookup checks passed.
- Byte comparison passed for all source before the service section and from the service-motion section onward, including every non-service renderer, the store, bridge and shared image loader.
- `PPUniversalServiceNote`, favorite/owner/chat/reuse handlers, and menu actions remained byte-identical, except removal of the menu button's duplicate decorative background.
- No schema, Firebase rules, permission, authentication, pricing, order, QIB, persistence, or backend changes.

## Phase 5 — Refinement / independent source review completed

- Reviewer found one medium source issue: placeholder identity omitted size/direction, which could retain a stale fallback after resizing or language change. Corrected by including normalized dimensions and RTL in the image signature.
- Added display scale to the signature/cache and renderer for sharp Retina fallback artwork; account for pixel scale in cache cost. Increased Contrast now uses primary text color for the utility border.
- Final independent review: no remaining concrete critical/high/medium source findings at SHA-256 `6a16431644e0969022df2f8f52931c8665016bac444c0c9a8c8c0dc4b7198976`.
- Concurrent Search-controller edits appeared during verification. They were not authored, reverted, or included in this task's review.

## Remaining acceptance work — native gates UNVERIFIED

1. With explicit build/run authorization, recheck the connected iPhone 13 Pro Max and use Xcode default DerivedData; no Simulator or `xcodebuild test`.
2. Capture actual service cards in Arabic RTL and English LTR, light/dark, narrow/wide hosts, long content and AX sizes. Verify intrinsic sizing, bounded scroll fallback, content reading order and 44pt utility hit targets.
3. Exercise detail navigation, rapid taps, favorites, owner controls, provider chat, video, missing/failed/local/remote imagery and reused records. Check that utility taps do not open the service.
4. Verify VoiceOver, Reduce Motion/live changes and device frame pacing. No candidate screenshots or native runtime evidence have been captured; do not certify visual quality from source checks.
