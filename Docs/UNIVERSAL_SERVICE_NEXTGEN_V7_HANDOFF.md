# Universal service cell — NextGen V7

## Scope and evidence boundary

- Request: redesign only the consumer universal cell's service mode; preserve ads, products, medicine, food, pets, vets and every other mode.
- Baseline: `4e9872b626e2c622eb92ebcfb30c4bc1f7b1f355`, clean checkout. Original source and baseline manifest: `/tmp/pp-service-v7-86R3qG`.
- Entry: user explicitly selected `swiftymax-nextgen-category-defining-v7`, superseding the default V6 routing for this task.
- Existing architecture: `PPUniversalCell.m` registers `PPUniversalCardHostingCell`; `PPUniversalCardRenderer` dispatches `.services` to the existing SwiftUI `PPUniversalServiceCard`. No platform migration.
- User explicitly approved physical-iPhone build, install and validation on 2026-11-05. Only the connected iPhone 13 Pro Max and Xcode default DerivedData are in scope. No Simulator, deploy or production write is authorized. Native rendering, VoiceOver, motion and performance remain UNVERIFIED until individually evidenced.

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

## Phase 6 — Authorized device verification in progress

- Rechecked `00008110-00046D640EB8401E`: connected physical iPhone 13 Pro Max, iPhone14,3, iOS 27.0.1, developer mode enabled.
- Built workspace `Pure Pets.xcworkspace`, scheme `Pure Pets`, Debug, destination `platform=iOS,id=00008110-00046D640EB8401E`; no DerivedData override. **BUILD SUCCEEDED**, 2026-11-05 05:02 local time. Log: `/tmp/pp-service-v7-86R3qG/device-build.log`.
- Build includes current combined checkout at `df21e8b1` (concurrently committed outside this task). Exact compiled source SHA-256: `6d0a33d9768d1a1bb31f344bb76de212277809dae30d0f9057d441e18263c7d6`; service-section SHA-256: `f91ada9e9aec3cf539568dfab67ee9d7d46a7b5993030e5daa264af66af557d5`.
- Concurrent edits removed the service scroll fallback and changed Home sizing after the prior review; retained those edits. Prior source-review claims apply to the earlier recorded hash. Current native build passes; bounded-host runtime behavior still needs verification.
- No compile errors. Existing deprecation/concurrency warnings remain, plus the backward-compatible `UITraitCollection(traitsFrom:)` initializer used by the service placeholder.
- Device screenshot capture works. Initial capture shows the lock screen; iPhone Mirroring reports connection timeout. User asked to unlock once then relock for Mirroring.
- First candidate installed successfully (`install.json`). Launch failed with `com.apple.dt.CoreDeviceError 3`: remote connection invalidated (`com.apple.Mercury.error 1001`). This is a device-transport failure, not evidence of an app crash or successful launch.
- Current-source review found two medium regressions in concurrent sizing edits: no bounded overflow recovery, and unconditional two-line titles at accessibility sizes/focus. Fixed by a final vertical scroll candidate only when `!isMeasuring`, plus unlimited title lines for accessibility/focus. Retained compact standard-card geometry and external Home sizing.
- Reviewer confirmed both fixed with no new delta findings at `fbf220658692c986bd99034a2e6f4c7756c4d5886230b38017ab72e6739ad083`. Final physical-device rebuild and install in progress. No runtime acceptance claim yet.
- Handoff on user switch to Admin/Pro authentication: final rebuild failed in Xcode dependency scanning (`NSObject+YYAddForARC.m`, missing `Pure Pets_vers.o.scan` in default DerivedData). The earlier candidate built and installed; the final 10-line adaptation correction is source-parsed/reviewed but not successfully rebuilt/installed. Launch retry also timed out after 25 seconds. No app crash or service rendering verdict can be inferred from these toolchain/device-transport failures. Resume at final device rebuild after the current Admin/Pro task; preserve the same device/default-DerivedData constraints.
