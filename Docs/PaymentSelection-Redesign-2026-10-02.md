# Payment selection redesign — 2026-10-02

Implementation and source review completed. Native build, rendered comparison, accessibility interaction, and performance remain **UNVERIFIED**. No production certification is claimed.

## Scope and direction

Consumer iOS `PPSelectPaymentVC`, its collection helper, payment cells, delivery picker, and Arabic/English strings. UIKit/Objective-C remains the implementation. This report supersedes the presentation description in the historical August handoff, not its historical evidence.

The source baseline placed delivery above a separately scrolling method list and used an animated navigation illustration. That topology restricted space for long addresses and large text. No baseline screenshot was captured in this run; composition observations are source-based.

Three directions were considered:

1. **Single reading sequence (implemented):** scrollable introduction, delivery checkpoint, full-width payment choices, persistent existing checkout dock. It keeps context and selection in one reading order and accommodates content-driven heights.
2. **Paged payment deck:** rejected because paging would conceal available choices and introduce gesture dependence and selection discontinuity.
3. **Two-column review workspace:** rejected because it would fragment the compact-width and accessibility reading order. Regular-width content instead stays centered at a maximum 680 points.

Pure Pets semantic colors, existing Beiruti font helpers, PP spacing/corner tokens, existing payment marks, and system symbols remain the visual sources. No new logo, palette, dependency, route, or backend field was introduced. The NextGen brand brief passed structural validation; that is not visual certification.

## Implementation

- `PPSelectPaymentVC.m`: one scrollable collection header owns introduction and delivery; checkout dock remains visible and is anchored above the safe-area bottom. Removed decorative Lottie parsing/retint/loading/loop and glow machinery. Added retained-content loading/error/empty presentation and visible retry through the existing instrument listener. UI callbacks are main-thread and guarded by authenticated UID plus load generation.
- `PPSelectPaymentVC+Helper.h/.m`: supplementary header delegates to the controller; methods use one column and exact content-driven cell measurement. Existing selection/default/edit/delete behavior is retained.
- `PPPaymentMethodCell.h/.m`: stable checkmark and border selection, neutral payment-mark plate, wrapped labels, uncapped Dynamic Type, accessibility-size reflow, VoiceOver activation, and isolated masked-number runs. The same configured cell supplies sizing. Selection feedback is a short interruptible change and respects Reduce Motion.
- `PPAddressPickerView.h/.m`: additive inline mode preserves the existing public floating API. Inline address and Change/Select action size from content; accessibility sizes move the action beneath the address. Removed the decorative status dot, blur, shadow, and tap transform from inline presentation. Address or trait updates invalidate header layout. Existing address-picker callback remains the action owner.
- `ar.lproj/Localizable.strings` and `en.lproj/Localizable.strings`: six matching new checkout presentation/loading/retry keys per locale, with no duplicate new keys.

## Behavior ledger

Direct comparisons against the initial clean iOS HEAD confirmed unchanged method bodies for:

- `finishPayments`, `pp_startCheckoutWithPaymentMethodId:`, and checkout-result handling;
- address validation, latest-address refresh, picker routing, and preferred-address resolution;
- explicit-item/shared-cart item selection and calculator summary;
- QIB phone recovery and pending cancellation prompt;
- available instrument filtering, default selection, resolved selection, and checkout CTA wording;
- instrument default, edit, and delete callbacks.

Checkout coordinator, payment manager, payment models, instrument manager, and shared checkout dock source have no diff. Firebase rules, functions, permissions, schemas, App Check, authentication authority, and payment execution were not modified. Error presentation changes from a transient saved-method HUD to a persistent inline message with retry; built-in options remain available according to existing configuration.

## Localization and accessibility

Layout uses leading/trailing anchors and the existing `Language` semantics/alignment. Arabic and English copy are present. Mixed masked-number runs are isolated without forcing surrounding Arabic into LTR. Header/address/method labels wrap; payment rows are measured rather than assigned fixed category heights. Navigation text alone is capped for the existing fixed-height bar, with the full-size heading in scroll content. Back and retry controls meet a 44-point minimum; address and method cards expose button activation and method selection traits.

Source corrections from independent review: hidden status/retry constraints now yield at priority 999, and compact navigation typography is bounded. These choices still require real-device AX5/VoiceOver/RTL/LTR verification.

## Validation

| Gate | Result |
| --- | --- |
| Scoped `git diff --check` | PASS |
| Arabic/English `plutil -lint` | PASS |
| New localization key parity/duplicates | PASS: six keys each |
| Required presentation-key lookup in both locales | PASS; removed an obsolete missing fallback key in favor of the existing localized Select key |
| Four changed Objective-C implementations through clang-format | Structure parsed; not compilation/type checking |
| Existing cart/checkout static contract script | PASS |
| Checkout state-machine regression script | 158/158; Python model and source assertions |
| Checkout idempotency regression script | 58/58; Python model and source assertions |
| Independent source review | Findings corrected; final pass found no additional actionable defect |
| CodeRabbit initial review | Two minor findings: empty copy and font fallbacks; both corrected |
| CodeRabbit follow-up | Completed with zero findings across the nine changed source/localization files; final helper declaration cleanup and fallback-key correction were checked locally afterward |
| iOS compilation/device launch | UNVERIFIED; not executed under current build policy |
| Native screenshots, Arabic/English pixels, AX5, VoiceOver, motion/performance | UNVERIFIED |

The NextGen visual planner correctly left certification `BLOCKED/UNVERIFIED`: no new native capture or runtime evidence was produced. No simulator, custom DerivedData, deployment, or production mutation was used.

## Remaining release gate

Use the authorized connected iPhone 13 Pro Max workflow and default DerivedData when build execution is authorized. Inspect Arabic RTL and English LTR; light/dark and increased contrast; smallest supported width/rotation; default through AX5; long address and masked details; selected/loading/failure/empty/retry states; VoiceOver and Reduce Motion. Exercise cash and online handoff, cancellation, and return-to-screen behavior without equating a successful build to runtime proof.
