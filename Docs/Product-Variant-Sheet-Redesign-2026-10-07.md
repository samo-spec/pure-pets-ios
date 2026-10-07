# Product variant options sheet

Date: 2026-10-07

Follow-up requested by the user: both the outer representable and hosted sheet content now ignore the bottom container safe area, retaining keyboard avoidance. UIKit's sheet corner radius is now 42 points, matching the existing SwiftUI presentation modifier. Swift syntax parsing and the scoped whitespace check passed for this follow-up; no app build or device validation ran. The isolated typecheck and independent review below describe the earlier redesign revision.

Follow-up sheet SHA-256: `f5bd3ce2198fabf262ea737e2ceba2ee0e96b37954f10ee89a029d3f653c2629`.

Source implementation and focused static verification are finished. Native rendering, integrated build, interaction, accessibility, and performance proof remain **UNVERIFIED**. This is not release certification.

## Scope and owned files

Only the product variant options sheet in the supplied 06:00 screenshot was redesigned.

- `Pure Pets/MainApp/PetsAdsFiles/PetsAdvertiseImagesAndCells/PPUniversalVariantPicker.swift`
- `Pure Pets/ar.lproj/Localizable.strings`: five new `variant_sheet_*` keys
- `Pure Pets/en.lproj/Localizable.strings`: matching five keys
- This handoff

The universal-card route still presents `PPUniversalVariantPicker(accessory:)`. This task did not edit the card, Home, marketplace, product viewer, shared variant selector, store, bridge, cart manager, models, backend, or project configuration. Concurrent work in other files was preserved. A concurrent correction to the sheet's `Language.semanticAttributeForCurrentLanguage()` invocation was also preserved and checked against the real Objective-C declaration.

The app deployment target remains iOS 15. The existing variant sheet keeps its iOS 16 availability boundary.

## Design decision

The screenshot places the title/price above nested choice and selection-summary cards, followed by a separate cart surface and substantial unused space. Choices are small and horizontally constrained, and the configured product has no image inside the sheet.

Three structurally different directions were considered:

1. **Product fitting tray:** actual selected-product thumbnail/name, directly visible option axes, one price/quantity/action area, optional exact-combination disclosure.
2. **Sentence builder:** inline selectors embedded in prose. Rejected because backend-defined axes, Arabic grammar, long values, and automatic multi-axis adjustments make it fragile and harder to scan.
3. **Combination catalogue:** a list of exact products. Useful for recovery/direct selection but unnecessarily repetitive as the default for simple families.

Direction 1 was selected, retaining direction 3 as the existing combination/recovery path. An independent source and interaction assessment supported this decision; it was not rendered visual proof.

The implemented hierarchy contains a compact heading/close action, the confirmed product's actual image/name, labeled wrapping choices, contextual resolution/retry feedback, optional SKU details, and one cart action area. That area shows selected-product availability, calculated selection or cart-line total, quantity, and Add or existing-cart actions.

Existing Pure Pets semantic colors, Beiruti typography, and cached product imagery supply the identity. Decorative glass, gradients, entrance staging, selection pulses, and bouncing cart icons were removed. Press feedback is brief and user-triggered.

## Behavior and contract preservation

| Concern | Preserved owner and behavior |
| --- | --- |
| Entry/dismissal | Existing sheet route and representable teardown; dismissal is blocked during cart operations. |
| Selected identity | `PPAccessoryViewerStore.snapshot` supplies the exact selected product ID, image, title, price, and quantity. A pending family projection never replaces confirmed commercial data. |
| Option selection | `selectOptionValue` and `selectVariant` remain the only mutation entry points. Incompatible and out-of-stock values remain actionable; not-offered values do not become purchase paths. |
| Adding/increasing | Confirmed selection, current purchase data, a purchasable snapshot, cart eligibility, exact selected-product stock, and no pending mutation/switch are required. |
| Existing cart recovery | Decrease and remove remain available for stale or sold-out products when the store allows them. |
| Price | The existing bridge formatter uses `snapshot.accessory` and actual requested/current quantity. Family aggregate data never authorizes a cart line. |
| Recovery | Family retry, failed-selection retry/keep-current, stale-data retry, empty/unresolved combinations, stock notifications, and mutation errors retain actions. |
| Cancellation | Authentication/provider-switch cancellation remains separate from errors. Retained tasks finish already-dispatched cart operations through presentation changes. |
| Lifecycle | Load, pause, resume, scene phase, and `finishQuickAdd()` remain connected. |
| Feedback | Existing cart update notifications and legacy root-surface refresh are preserved. Quantity announcements use actual store values. |

Infra's product family/option definitions were checked read-only. Each selected `petAccessories` document remains independently sellable; `ProductFamilies` remains a projection. Three axes, 40 values per axis, and 40 variants remain the existing contract. No direct database calls, schema, permissions, App Check, rules, or backend behavior were added or changed.

## Sizing, localization, and accessibility

UIKit now owns one custom content detent and the large detent. Header, scrolling content, and action heights are measured separately. The resolver uses the actual container's maximum detent height. Content changes invalidate sizing without resetting the user's expanded detent.

The controller walks `activePresentationController` to reach the actual presented host. This avoids creating a synthetic sheet controller for the unpresented representable child, a concrete issue caught and fixed in independent review.

Arabic RTL and English LTR use the app language and locale. The wrapping layout relies on SwiftUI's semantic mirroring; backend option order is preserved. Mixed-script names/SKU values use existing directional isolation, and number/price formatting uses existing locale-aware helpers.

At accessibility text sizes, choices become full-width rows and commerce actions move into the scroll flow. Compact-height and keyboard-search states also use inline actions. Long text wraps and essential targets remain at least 44 points. Quantity controls and selected/pending choices have explicit accessibility semantics. Mutation errors are announced, while existing store-owned selection announcements are not duplicated.

Reduce Motion disables press scaling and detent animation. Solid semantic surfaces do not depend on transparency. Increased Contrast uses a stronger semantic outline for unselected choices and quantity controls.

Visible choice labels use `summaryName`, avoiding duplicated units such as `250g (g)`. Source token calculations found accent text on selected rose below the normal-text contrast floor, so option text uses primary ink; accent marks selection via the border and checkmark. These calculations do not establish rendered contrast.

## Validation evidence

Redesign sheet SHA-256 before the safe-area follow-up:

`5654b18cc9eb398bf909ec9e4fea06aa0fdcca5104a40c0bc74f590287b298c1`

| Check | Result and limit |
| --- | --- |
| Swift syntax parse | PASS. |
| Isolated SwiftUI/UIKit type check | PASS against the installed iPhoneOS SDK, arm64 iOS 16 target, Swift 5 mode. The real sheet is checked with stand-in app declarations. No object emission, linking, or integrated app build. |
| Arabic/English localization lint | PASS. |
| Copy/key validation | PASS: all 40 referenced keys exist in both locales with matching placeholders. Five new keys are unique in each locale; existing values match the captured baseline. |
| Scoped diff whitespace check | PASS. |
| Independent source review | Two P2 findings fixed: actual sheet ownership and duplicate unit labels. Subsequent review found no remaining concrete critical/high/medium source defect in the reviewed scope. |
| NextGen brand validation | PASS for source-bound tokens and Arabic-first copy. No logo introduced. |
| Lexical UI audit | Remaining hint is the one-parameter `onChange` signature, retained for iOS 16 compatibility. New closure signatures require iOS 17. This is a lexical hint, not a runtime defect. |
| Native visual preflight | BLOCKED/UNVERIFIED: no candidate device captures, runtime accessibility checks, motion capture, or performance measurement. |

API use was checked against the installed SDK and [Apple's sheet presentation documentation](https://developer.apple.com/documentation/uikit/uisheetpresentationcontroller). Custom-layout mirroring follows [Apple's layout direction contract](https://developer.apple.com/documentation/swiftui/layoutsubviews/layoutdirection).

Temporary baseline: `/tmp/pure-pets-variant-sheet-20261007-baseline/`.

Temporary typecheck declarations/log: `/tmp/pure-pets-variant-sheet-20261007-validation/`.

No protected tooling/skill files were modified. No app build, simulator run, device installation, deployment, push, or production mutation was performed. The explicit user build restriction remains in effect.

## Remaining native acceptance gates

After explicit build authorization, use the approved physical iPhone 13 Pro Max workflow and default Xcode DerivedData:

1. Build the integrated app and open the sheet through its actual card route.
2. Inspect Arabic/English, light/dark, normal/AX5, long names, mixed-unit names, and Increased Contrast.
3. Verify content/large detents, interactive drag, scroll, keyboard search, safe areas, rotation, and content fit.
4. Exercise one/multiple axes, actual color swatches, unresolved/archived/unavailable variants, and large searchable families.
5. Verify pending selection, cancel/retry, stale stock, cart clamps, stock alerts, add/decrease/remove, auth/provider interruptions, and background/foreground behavior.
6. Check VoiceOver, Reduce Motion, actual rendered contrast, and performance.

=== CHECKPOINT START ===
Checkpoint Name: Product variant options sheet - source handoff
Status: completed
What was finished:
- Sheet-only redesign, product preview, wrapping option controls, and consolidated cart actions.
- Single sizing owner, accessibility adaptations, bilingual copy, and recovery parity.
- Focused source/type checks and independent review.
Files created/updated:
- PPUniversalVariantPicker.swift
- Arabic and English Localizable.strings
- This handoff
Routes / models / APIs added:
- None.
Known remaining work:
- Integrated build and native visual/interaction/accessibility/performance checks are UNVERIFIED.
How to continue next:
- Preserve current and concurrent work; run the physical-device acceptance gates after explicit build authorization.
=== CHECKPOINT END ===
