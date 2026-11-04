# Pure Pets Consumer iOS — Purchase Journey Upgrade Handoff

Updated: 2026-11-05
Scope: product cards, variant selection, cart switching copy, order detail commands and tracking presentation.
Repo: `samo-spec/pure-pets-ios`, local `main` at baseline `2588b116`.
Status: **Client improvements implemented and source-verified; NOT yet production/release certified.**

## Mission / non-negotiable constraints

Make shopping feel obvious at each step while retaining exact sellable-unit identity, authoritative backend pricing, physical live-pet inventory semantics, QIB/idempotency/cancellation state, provider ownership, UIKit navigation, Arabic RTL, English LTR and accessibility. Do not create new backend state owners or claim delivery time/medical suitability without verified authoritative data.

## Phase 0 — Inspection complete

Reviewed:
- `Pure Pets/MainApp/PetsAdsFiles/PetsAdvertiseImagesAndCells/PPUniversalCellSwiftUI.swift`
- `Pure Pets/MainApp/PetsAdsFiles/PetsAdvertiseImagesAndCells/PPUniversalVariantPicker.swift`
- `Pure Pets/MainApp/Accessories/AccessFiles/PPAccessoryViewerStore.swift`
- `Pure Pets/MainApp/PAYMENTS/Manager/Cart/CartManager.m`
- `Pure Pets/MainApp/PAYMENTS/Manager/Cart/PPSaveForLaterManager.m`
- `Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPSelectPaymentVC.m`
- `Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderDetailsMissionControlViews.swift`
- `Docs/ZERO_FRICTION_ORDERING_HANDOFF.md`
- Infra order lifecycle contract/read-only docs and related iOS regression scripts.

Key finding: previous checkout and address experience already received substantial improvements. A reported Cart → Payment hang has only source-level candidate fixes and remains unverified on-device. Saved-for-later is **not** a safe way to park an exact multi-item basket: its existing manager stores quantity 1 and omits full variant configuration. The proposed parked-basket feature is **deferred** pending a versioned server-authoritative, exact-line-identity contract.

## Phase 1 — Make product decisions explicit (IMPLEMENTED)

- Product-family cards now say `Choose options` (not `Add to cart`) when selecting an exact variant is still required; if a variant-family item is already in the cart, they say `Review options` (not a misleading purchase claim).
- Context menu uses `Choose options` and the same selector icon for a variant family.
- The existing variant sheet shows a clear selected/current-price message and explains that selecting another combination checks current price and availability. Archived combinations stay explicitly unavailable, and exact variant identity/cart ownership is unchanged.
- Two pairs of new English/Arabic variant action keys and two pairs of choice-state keys added to existing localization files.
- Product card presentation remains SwiftUI inside the existing UIKit navigation and manager contracts.

## Phase 2 — Help users understand orders (IMPLEMENTED)

- Order Mission Control now prioritizes `track` and `support` over cancel/return/refund commands. Server-provided eligibility and UI visibility still control executable actions; no new commands added.
- Removed a status-enum-derived fake completion **percentage** from the older fallback layout. It now shows the factual last update. The existing iOS 17 living status rail and timeline remain unchanged.

## Phase 3 — Prevent destructive-cart surprises (IMPLEMENTED AS COPY, FULL PARKING DEFERRED)

- Provider-switch confirmation now explicitly says it will replace the current basket.
- The destructive choice is labeled `Replace basket and add`; the safe choice is `Keep my basket`, with corresponding Arabic text.
- No silent backup or park is claimed; no cart sync, pricing, provider or stock mutation logic was altered.

## Phase 4 — Regression verification (SOURCE PASS; NATIVE BLOCKED)

New `scripts/purchase_decision_ux_regression_test.py`: **4/4 passing**.
Existing scoped regression suites: phase-8 variant static, cart manager **148/148**, checkout idempotency **58/58**, checkout state machine **158/158**, server-authoritative revalidation **36/36**, ordering journey **21/21**, order client **47/47**, fulfillment/delivery **87/87**, accessibility/RTL **51/51**, returns/refunds **33/33**, money/rounding **34/34**. All 12 scoped scripts passed as of this handoff.

Accessibility script had four stale source-pattern assertions. Current production code already uses `UILabel` loop with Dynamic Type scaling, `UIAccessibilityTraitStaticText` for noninteractive product titles, 52x44 payment icon container, `chevron.forward` plus semantic RTL alignment. Updated assertions to verify these actual patterns; no production accessibility behavior was weakened, and the suite passed 51/51.

Other source checks: `plutil -lint` passed for both localization files; `xcrun swiftc -frontend -parse` passed for the three changed Swift UI files; `git diff --check` passed. These are **not** a full Swift typecheck, Objective-C link, native app build or device interaction test.

Physical device: connected iPhone 13 Pro Max `00008110-00046D640EB8401E`.
Native dependency-resolve attempt via read-only `xcodebuild -list` was **blocked**: FirebaseAnalytics, GoogleAppMeasurement and FirebaseFirestoreInternal binary downloads failed with 'network connection was lost'. The transient change to `Package.resolved` from that attempt was restored. No simulator or production Firebase write was run.

## Phase 5 — Outstanding release / production certification gates

- Restore required Google/Firebase Swift Package binary downloads through the authorized dependency source or connectivity.
- Perform an explicitly authorized build/install/launch on the connected physical iPhone 13 Pro Max with Xcode default DerivedData. Do not use Simulator, Mac Catalyst, alternate DerivedData or `xcodebuild test` generic commands.
- Verify Cart → Payment cold/warm entries and obtain an actual main-thread stack if the previously reported hang persists. No fixed-hang claim without native evidence.
- Inspect Arabic and English rendered screens, iPhone compact and iPad layout as applicable, VoiceOver, Dynamic Type accessibility sizes, dark appearance and Reduce Motion.
- On staging/safe test data, exercise exact variant selection, out of stock, provider switch Keep/Replace, review price/address change, offline checkout, QIB pending/verify/retry/cancel, delivery status, partial fulfillment and returns. No live purchases during acceptance checks.
- Capture before/after usability evidence (tasks completed, wrong variants, cart abandonment, recovery success). No 'world-class' certification until measured.

## Deferred scoped epics (not implemented; require evidence/contracts)

1. **Pet Fit Intelligence** needs verified pet-profile attributes and trustworthy product suitability facts; avoid veterinary guarantees.
2. **Intent-first product search** needs an evaluated search/metadata pipeline; do not pretend keywords semantically prove pet suitability.
3. **Living Purchase Promise** should use only real shipping fees, server-confirmed price and an optional verifiable delivery ETA. No invented ETA.
4. **Park My Basket** requires a server-authorized, idempotent, user-scoped draft preserving all lines, variants, quantities, provider metadata, conflict behavior and recovery.
5. **After-care / one-tap Buy Again** must preserve exact historical sellable-unit identities, check current stock/prices and respect live-pet special rules.
6. **Checkout Rescue** is partially present in existing `ZERO_FRICTION_ORDERING_HANDOFF.md`; additional expansions should start from actual device and analytics friction, not duplicate implementation.

## Local file scope / noninterference

Changed product source:
- `Pure Pets/MainApp/PetsAdsFiles/PetsAdvertiseImagesAndCells/PPUniversalCellSwiftUI.swift`
- `Pure Pets/MainApp/PetsAdsFiles/PetsAdvertiseImagesAndCells/PPUniversalVariantPicker.swift`
- `Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderDetailsMissionControlViews.swift`
- `Pure Pets/ar.lproj/Localizable.strings`
- `Pure Pets/en.lproj/Localizable.strings`
- `scripts/accessibility_rtl_lifecycle_regression_test.py`
- `scripts/purchase_decision_ux_regression_test.py` (new)
- This handoff (new).

Pre-existing dirty files before this task were `CLAUDE.md` and untracked `.cursorrules`, `AGENTS.md`, `GEMINI.md`, `project-brain.json`; left untouched. No commit/push/deploy was performed.

## Continuation rule

Update this file after every new phase. Before claiming completion, collect full build/device evidence; if dependencies/network still block, report **source verified / native blocked**, not production ready.
