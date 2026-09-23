# Product viewer variants — redesign handoff

Date: 2026-09-23  
Repository: Pure Pets IOS  
Inspected HEAD: `3627af1ddacde8855dd3674d586ef0df06fef83f`  
Mode: in-place visual refinement after user feedback  
Delivery status: revised implementation and static checks complete; rendered quality and native acceptance UNVERIFIED.

## Scope and authority

The existing product viewer embeds SwiftUI in `PPAccessoryViewerHostingController`; this change uses that existing architecture. No UIKit migration, additional navigation owner, backend writes, dependency, project-file edit, deployment, or production mutation was introduced. Existing unrelated dirty work was preserved.

The traced path is `PPAccessoryViewerScreen` → variant section → `PPAccessoryViewerStore` → `PPAccessoryViewerLegacyBridge` → `PetAccessoryManager`. Infra `productVariantFamily.js` and `productOptionsDomain.js` define the family contract: at most three axes, forty values per axis and forty sellable variants. Each sellable variant remains an existing product identity. Family metadata is grouping/display data and is not sibling stock or pricing authority.

## Direction and source diagnosis

No baseline screenshot was supplied or captured. The first implemented composition was rejected by the user; its visual quality is not accepted. Diagnosis of the old composition is SOURCE evidence: separate horizontal rails, single-line color labels, gradient swatches, duplicated color/non-color rendering, and decorative stock badges. Pixel quality is UNVERIFIED.

Three directions were compared before implementation:

| Direction | Decision | Product reason |
| --- | --- | --- |
| Inline axis-specific choices with optional selection details | Selected and refined | Keeps the product and all axes together; compatible changes need one tap; bounded choices support expansion/search without repeated boxed rows or a permanent summary. |
| Sequential axis wizard | Rejected | Adds navigation and draft state to a viewer that already starts with a sellable product. |
| Modal comparison table | Rejected | Adds presentation and scanning cost, and requires a different layout at compact accessibility sizes. |

An independent read-only reviewer supported the inline direction structurally and identified selection/purchase races, stale callbacks, duplicate row identities and sparse-combination reachability. A second pass identified the after-cart quantity and Arabic stale-state copy corrections. The second complete independent review did not finish; no independent runtime or visual certification is claimed.

## In-place refinement after user feedback

The second pass preserves the selection owner and the first pass's safety fixes. It changes only the selector presentation and two localized disclosure labels:

- Color choices are compact, labeled samples with a selected ring and checkmark. Missing color data remains a text choice rather than an invented swatch.
- Size, weight, volume, material, flavor and other values use content-sized controls that wrap to the available width. A fixed indicator slot and stable font prevent selection from changing a control's width.
- Each axis has a restrained name and the confirmed value. The explanatory introduction and always-visible selection receipt were removed.
- SKU, quantity after cart and the complete selection are available under Selection details. Loading, failure, unavailable and stale-availability feedback remain visible without opening details.
- Complete combinations and accessibility-size choices use simple full-width rows instead of large bordered tiles. Search, sparse-family reachability, selected identity and disabled behavior remain intact.
- The custom wrapping Layout delegates RTL mirroring to SwiftUI; it does not manually mirror coordinates. This follows [Apple's LayoutDirection contract](https://developer.apple.com/documentation/swiftui/layoutdirection). Long headings and disclosure actions fall back to vertical arrangements.

This is a source implementation refinement, not a claimed visual acceptance pass. The iPhone 13 Pro Max was reachable over the network, but the read-only screenshot request failed because its screenshot service was unavailable (`Could not start screenshotr service: Invalid service`). No build, installation, device configuration change or simulated replacement screenshot was used.

## Implemented behavior

- One shared option renderer covers color, size, weight, volume, material, flavor and other backend-defined axes. Swatches preserve actual color, while visible/spoken labels preserve names and units.
- Wrapping choices show six values initially and always retain the selected choice. More choices expand in place; search appears for longer axes and matches Arabic, English, canonical labels and units.
- Complete combinations are explicitly reachable, including sparse families such as red/small and blue/large. Rows use sellable `productId`, so different sizes sharing a color cannot collide.
- Product identity, price, images, quantity, selected options and cart target commit together after the requested product loads. A pending request leaves the confirmed product intact.
- Pending selection has progress, a keep-current action, retryable local failure and stale-completion rejection. Leaving the viewer invalidates the pending request. Family, favorite and live-listener callbacks are guarded against obsolete requests/products.
- Purchase/mutation entry points reject a pending switch, and variant changes reject cart processing and both checkout phases. The existing commerce holder remains mounted but disabled during selection reads.
- Missing option axes are not fabricated from the first value. Archived choices cannot become purchasable through the new selector gate. Unresolved families expose the combinations route.
- Optional selection details retain the SKU and report remaining quantity after the current cart. No sibling stock/price is invented from the family projection.

## Preserved contracts

The existing product fetch, cart manager, direct checkout, authentication, permissions, App Check, Firebase rules, collection names and authoritative server validation remain in place. Per-product favorite/cart state and quantity reset still follow the selected product. The gallery, seller, suggestions, host and root navigation were not redesigned. New symbols are internal presentation/state helpers; no public API or backend schema changed.

## Native UX and localization

Existing PP semantic colors, PPSpace/PPCorner tokens and Beiruti Dynamic Type typography remain authoritative. There is no new logo or generated media dependency. Selection uses a checkmark and text semantics as well as restrained brand outlines. Compact choices and utility actions have at least 44pt touch targets; combination and accessibility rows have at least 52pt height. Labels wrap, and accessibility sizes reflow to one column. Search uses native TextField focus/submit, with explicit clear and collapse actions. Source uses logical leading/trailing alignment, inherited app layout direction and Unicode isolates for mixed-script values and SKU. Arabic and English keys have matching format arguments.

Motion decision: reduce. Keep the existing interruptible press style at a smaller displacement, with its live Reduce Motion fallback; use system progress rather than decorative loops or animated choice geometry. Native focus, keyboard avoidance, VoiceOver, Switch Control, contrast, text shaping, safe-area fit and frame pacing require device validation.

## Verification

| Check | Result | Boundary |
| --- | --- | --- |
| Swift frontend syntax parse, all three changed Swift files | PASS | Syntax only; no type-check, link or build proof. |
| Existing phase8 variant-detail static contract check | PASS | Typed models, bridge, selector integration, purchase gate presence, localization, no direct Firestore writes. |
| Arabic and English localization lint | PASS | Resource syntax. |
| All 130 referenced viewer localization keys and format arguments | PASS | Both locales present; format signatures match. |
| Scoped whitespace/diff check | PASS | Only in-scope files checked. |
| NextGen brand-brief validator | PASS | Structural token binding only. |
| NextGen source hint audit | Reviewed | One onChange deprecation hint retained for this iOS 16-gated surface; newer closure overloads would raise availability. |
| Physical device and screenshot | Partially observed | iPhone 13 Pro Max reachable over network; screenshot service unavailable. No build/install/run performed. |
| Real baseline/candidate captures and visual comparison | UNVERIFIED | No target captures; initial visual direction rejected by user. |
| Arabic RTL / English LTR runtime; AX5 / VoiceOver / keyboard / light-dark / Reduce Motion | UNVERIFIED | Source review does not close device gates. |
| Native compile/link, real async recovery, cart/payment regression and performance | UNVERIFIED | No authorized build or native test run. |

B&A Sketch returned reauthentication required. Product Design brief/context and NextGen native/brand/parity/motion/visual/proof guidance were used. Creative Production was inspected; this component needs no generated imagery or campaign asset. No claim of using every unrelated installed plugin is made.

## Remaining acceptance and continuation

The repository execution policy requires an approved physical-device workflow. Continue on the connected iPhone 13 Pro Max using default DerivedData after explicit build authorization. No simulator, Mac/Catalyst target or xcodebuild test was run.

Exercise both Arabic and English: color-only legacy data; size-only; color + size; weight/material/flavor with units; forty values; sparse combinations; long labels; AX5; light/dark and increased contrast; VoiceOver selected/pending/failure announcements; search/clear/collapse and keyboard avoidance. Verify loading, no family, malformed/empty definitions, offline failure, retry, keep-current, late canceled completion, listener reorder, archived/missing product, quantity already in cart, purchase during pending read, switch during cart write/payment, dismissal and foreground return. Capture actual baseline/candidate states and re-audit pixels. Until these gates pass, final quality is BLOCKED/UNVERIFIED.

Rollback seam: the selector section, the narrowly coupled Store/Models changes, the appended localization keys and updated existing static check. Do not revert unrelated work or reset the repository.

## Refinement verification scope

The Store, Models and existing static-contract script hashes are unchanged by the second pass. Arabic and English strings parse, all 130 referenced viewer localization keys exist with matching format signatures, and the three changed Swift files pass syntax parsing. The existing static contract check and scoped diff check pass. These checks do not establish native type checking, visual quality or runtime correctness.

| Experience | Source review | Runtime |
| --- | --- | --- |
| English / LTR | Logical placement, readable labels, units/SKU isolation and native controls reviewed | UNVERIFIED |
| Arabic / RTL | App direction inheritance, automatic custom-Layout mirroring, leading/trailing alignment, expanded text and localized disclosures reviewed | UNVERIFIED |
| Accessibility and motion | Single-column accessibility layout, selected traits, labels/hints, 44pt targets and existing Reduce Motion-aware press style retained | UNVERIFIED |

## Source hashes at handoff

- `Pure Pets/MainApp/Accessories/AccessFiles/PPAccessoryViewerComponents.swift`: `c0bd165054eba32a277e4d9b596e1ca3f2f54bcdc5f6196421fecb0f20ee898a`
- `Pure Pets/MainApp/Accessories/AccessFiles/PPAccessoryViewerStore.swift`: `41411bdfde726bf09c9957c9a013544c15603c48c271223a5ec88399802e927e`
- `Pure Pets/MainApp/Accessories/AccessFiles/PPAccessoryViewerModels.swift`: `f8d2b19fd2ebdfd62c0260de64593afb7f4f34db38602ffecb67219f7556fa6c`
- `Pure Pets/ar.lproj/Localizable.strings`: `517a64df7fcf3841b8316390484d8dc37ebbc4c4af9a89d8cb258f14837a35d6`
- `Pure Pets/en.lproj/Localizable.strings`: `c4385edf65eeb8a282b56291c331ad2bee86f986ddc4340936c494d5d4cec1e0`
- `scripts/phase8_variant_detail_static_test.py`: `a843d85001a4baaadc2e62630f9c59e5e9bc26315e1b678eec49ffbdc01a0337`
