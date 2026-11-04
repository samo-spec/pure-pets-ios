# Pure Pets consumer ordering — persistent handoff

Updated: 2026-11-04. Baseline consumer iOS HEAD: `928c942df15dcd80d8ee1fd4748db5bf1dc4591f`; working tree clean before this task.

## Mission and authority

Improve Cart → Checkout → Payment, delivery/billing review, saved addresses, address forms and optional location assistance in the existing consumer app. UIKit remains the screen/navigation owner. Existing Swift checkout-summary bridge remains reusable. NextGen entry rules plus V7 invention/craft guide the implementation. Infra source is read-only authority for schema, authorization, pricing, order lifecycle and QIB. No backend, Rules, deployments or production operations are part of this change.

One handoff is updated after each phase. Source/static, native build, installed app, rendered device, accessibility runtime and real payment evidence are separate.

## Phase 1 — Inspect: completed

Inspected the focused owner chain:

- `CartViewController`, `PPCartTableCell`, `CartManager`, `PPCartCalculator`, existing `PPContextAwareCheckoutView`.
- `PPSelectPaymentVC` + Helper, `PPAddressPickerView`, `PaymentMethod`, `PPPaymentManager`, `PPCheckoutCoordinator` and existing checkout regression scripts.
- `AddressFormVC`, `PPSelectAddressVC`, `LocationPickerViewController`, `PPAddressesManager`, `PPAddressModel`.
- Infra `functions/index.js` → `qibPayment.js/createPendingOrder`, `qibSessionPhase1.js`, and `firestore.rules/hasValidAddressFields`.

Preserved contracts: server-priced orders; exact sellable/cart identities; real saved address IDs; owner-scoped persistence; active payment settings; selected instrument identity; QIB integration; cancellation/readback; idempotency; cart locking; order routing; all existing form fields/capabilities.

## Phase 2 — Identify friction: completed

1. The cart cell mutates its shared `CartItem.quantity` before the manager checks inventory and captures rollback, defeating increase guards and rollback.
2. Repeated quantity writes have overlapping completion/rollback risks; failed changes can remain visible.
3. Cart summary hides the item/delivery breakdown, increasing price uncertainty.
4. Checkout resets the chosen address on every appearance, reloads multiple times, and can accept repeated confirm taps during asynchronous address refresh.
5. An empty address path shows a confirmation dialog before opening the form; load failure can look like an empty address book.
6. QIB preflight checks only the profile mobile even though the payment owner supports authenticated and address phone fallbacks.
7. Address screens request location on opening; denied location interrupts manual entry. The selector can return an unsaved synthetic current-location address that cannot pass server checkout.
8. Map confirmation reaches duplicate callbacks; reverse-geocode results can override newer choices and do not fill useful street/postal fields.
9. Address save mutates a shared model before persistence; a failed edit leaks into other screens.
10. Infra requires full name, address line, city/state IDs and postal code. Required fields cannot be removed by UI design. Billing/payment use existing account/contact and order totals; there is no separate billing-address contract to invent.

## Phase 3 — Reinvent: completed

Selected direction: one reviewable order with inline delivery/contact and item/delivery/total disclosure, existing payment choices and a contextual primary action. Saved selections survive navigation; missing data opens its actual editor. Address assistance is optional, uses verified geocoding, and always produces a saved model before checkout. Quantity controls send intent to the manager and expose pending/recovery truthfully.

Independent source-design reviewer `/root/ordering_review` selected `order_review` over `guided_steps` across the V7 sixteen-dimension review. Rejected the wizard because it adds compulsory navigation, hides the bill until late and expands restoration/focus/error states. The V7 portfolio returned `readyForImplementation: true`; synthesis rejected a multi-owner mechanism bundle, so implementation keeps each existing domain owner at its own seam, rather than introducing a shared replacement state owner. This is design/source guidance, not runtime or visual certification.

Mandatory safeguards: lock before asynchronous preflight; bind callbacks to UID and request generation; never silently substitute a deleted chosen address or disabled payment during confirmation; retain manager-owned cart mutation; return from editing to review without automatic purchase; do not invent billing-address fields.

## Phase 4 — Implement: completed

Implemented in existing owners (no new application architecture):

- Cart cells submit quantity intent; CartManager validates ceilings, serializes/coalesces each line's writes, preserves the newest intent, and rolls back to the last confirmed quantity on terminal failure. Visible rows refresh without structural reloads; pending writes disable destructive actions. Undo now uses the manager and is offered after deletion acknowledgement.
- The shared UIKit checkout summary keeps item/delivery charges visible outside item disclosure and adapts the action layout to larger text and totals.
- Checkout is a single order review with a stable saved-address selection, contextual primary action, inline load/error/retry state and editable payment contact. Preflight locks before refreshing, binds callbacks to UID/generation, and requires another review if the exact address, payment, contact, cart or total changes.
- Saved payment defaults wait for the actual saved methods; explicit selections are not silently replaced. Phone fallback uses the payment owner's existing normalization (profile, auth, address). Saving a contact returns to review without submitting an order.
- Addresses show street details, support direct editing and selection after persistence, and use adaptive controls/rows. Current location opens the real address form; no synthetic unsaved address enters checkout.
- Address form location is opt-in, bounded, and nonblocking on denial. Geocoding fills only empty unchanged fields, matches real geography, and rejects stale callbacks/samples. Map selection stays available without granting location. Detached stable-ID save drafts prevent failed edits from leaking and duplicate retry IDs.
- Added 31 Arabic/English string pairs and changed the checkout heading to order review. Dynamic Type, directional layout, accessibility labels/announcements and Reduce Motion are handled in changed surfaces.

All existing server-required address fields, payment choices, saved instruments, cart/saved-for-later actions and order recovery routes are preserved. Protected tooling/skill files were read only. Implementation still requires source regression/review gates below; no native outcome is inferred from source.

## Phase 5 — Test: completed (first pass)

First pass: idempotency 58/58, state machine 158/158, authority 36/36, variant/source contracts 10/10, cancellation/support 54/54, money/rounding 34/34 passed. Cart 143/146: three assertions expected the replaced rollback/undo implementation; retained safety requirements are being updated to the serialized queue and acknowledged-delete contracts. Both localization files linted; Swift frontend parsing and diff whitespace passed. Objective-C parser tool initially crashed with incompatible grammar/runtime versions; this is not native compile evidence. Tests are requested. Native app builds are not explicitly authorized by the request; workspace policy allows only an explicitly authorized connected iPhone 13 Pro Max workflow with default DerivedData, never Simulator or `xcodebuild test`.

## Phase 6 — Refine: completed (source and static checks)

Source refinement completed. Fixed superseded address reads, exact visible-address/contact changes during preflight, cancellation-control refresh, bounded initial/explicit address loading, delayed contact saves, editor retain/callback hazards, location timeout recovery, international/Arabic phone paste, and manager-owned undo after deletion acknowledgement. Payment edit/default/delete actions honor checkout locks. Cart listeners and quantity callbacks are scoped to the active authenticated user/session. No new source-review defect remains open; native acceptance is a separate unverified gate.

Final focused verification on 2026-11-04:

| Command (from consumer repo) | Result | Evidence level |
|---|---:|---|
| `python3 scripts/cart_manager_regression_test.py` | 148/148 | Python model + source contracts |
| `python3 scripts/checkout_idempotency_regression_test.py` | 58/58 | Python model + source contracts |
| `python3 scripts/checkout_state_machine_regression_test.py` | 158/158 | Python model + source contracts |
| `python3 scripts/server_authoritative_revalidation_regression_test.py` | 36/36 | Source/model contract checks |
| `python3 scripts/phase9_cart_checkout_static_test.py` | 10/10 | Source contracts |
| `python3 scripts/cancellation_support_contract_regression_test.py` | 54/54 | Source/model contract checks |
| `python3 scripts/money_type_rounding_regression_test.py` | 34/34 | Source/model contract checks |
| `python3 scripts/ordering_journey_regression_test.py` | 17/17 | New journey source-contract guards |
| `plutil -lint` on both `Localizable.strings` files | PASS | Resource syntax |
| New localized key uniqueness and format parity | 31 pairs PASS | Source/resources |
| `xcrun swiftc -frontend -parse` on shared checkout summary | PASS | Swift syntax only |
| Objective-C grammar parse of 15 changed `.m`/`.h` files | PASS | Syntax only after normalizing `NS_ENUM`, nullability and availability macros; zero parse errors in baseline and working copies |
| `git diff --check` | PASS | Whitespace/patch hygiene |

Total: 515 passing source/model checks. They do not execute UIKit, Firebase SDK callbacks or QIB. The temporary Objective-C parser uses tree-sitter 0.23.2 and tree-sitter-objc 3.0.2 under `/tmp/pp-ordering-syntax-tools`; no dependency or build configuration was added to the app. The initial parser runtime mismatch and raw macro errors were resolved for this syntax check; they were not app-build failures.

Native build, install, launch, rendered Arabic/English layouts, maximum Dynamic Type, VoiceOver/focus, keyboard/compact-screen interaction, Reduce Motion, live permission/geocoding/offline recovery, real price/availability changes and real QIB cancellation/retry remain **UNVERIFIED**. No app build/test command, Simulator, deployment, production mutation, commit or push was performed.

## Current verification and next step

Source implementation, focused static testing, and source refinement are complete. Release acceptance remains open until an explicitly authorized physical-device workflow runs on the connected iPhone 13 Pro Max using Xcode default DerivedData. Do not substitute Simulator, `xcodebuild test`, Catalyst/Mac destinations, or a custom DerivedData path.

Device scenarios to exercise in that next authorized pass:

1. New account: empty address book → manual or optional current-location form → save → review → explicit order confirmation.
2. Returning account: valid default address/payment/contact → review total → one confirmation; no purchase on returning from an editor.
3. Rapid quantity taps, inventory ceiling, failed/queued write, removal/undo, saved-for-later, sign-out while a callback is pending.
4. Location denied/restricted, coarse/stale sample, geocode failure, map pin selection, Arabic/international phone paste, typed text preserved when geocoding completes.
5. Address removed/edited or payment disabled during confirmation; stale refresh and offline contact/address saving recovery.
6. QIB success, failure, pending verification, cancellation and retry using existing server-authoritative lifecycle/idempotency.
7. English/Arabic, compact width, large text, VoiceOver, Reduce Motion and supported dark appearance.

## Exact changed paths

- `Docs/ZERO_FRICTION_ORDERING_HANDOFF.md`
- `Pure Pets/DesignFiles/PP/PPNAV/PPContextAwareCheckoutView.swift`
- `Pure Pets/DesignFiles/PP/PPSelectOptionViewController/PPSelectAddressVC.m`
- `Pure Pets/MainApp/Helpers/LocationPickerViewController.m`
- `Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/CartViewController.m`
- `Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/PPCartTableCell.h`
- `Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/PPCartTableCell.m`
- `Pure Pets/MainApp/PAYMENTS/Manager/Cart/CartManager.h`
- `Pure Pets/MainApp/PAYMENTS/Manager/Cart/CartManager.m`
- `Pure Pets/MainApp/PAYMENTS/Manager/Payment/PPPaymentManager.h`
- `Pure Pets/MainApp/PAYMENTS/Manager/Payment/PPPaymentManager.m`
- `Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPSelectPaymentVC+Helper.h`
- `Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPSelectPaymentVC+Helper.m`
- `Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPSelectPaymentVC.m`
- `Pure Pets/MainApp/UserFiles/Adressess/AddressFormVC.h`
- `Pure Pets/MainApp/UserFiles/Adressess/AddressFormVC.m`
- `Pure Pets/MainApp/UserFiles/Adressess/PPAddressModel.m`
- `Pure Pets/ar.lproj/Localizable.strings`
- `Pure Pets/en.lproj/Localizable.strings`
- `scripts/cart_manager_regression_test.py`
- `scripts/ordering_journey_regression_test.py`

## Screenshot-driven saved-address redesign — source implementation complete

Scope: foreground saved-address sheet in the user-provided image. Prior ordering changes remain intact. UIKit table/controller, exact saved address IDs, one-tap selection, authenticated ownership checks, search, edit/save/delete callbacks and optional current-location form route remain the owners. No model/schema/backend or payment changes are required.

Inspection and friction diagnosis completed: `PPOptionCell.pp_applyVisualStyle` restores an opaque rectangular `contentView`/card while the picker supplies a second rounded `UIBackgroundConfiguration` and native accessories. The screenshot shows these competing backgrounds split the row. `PPAddressModel.displayName` already includes both street lines and default decoration; the picker repeats both. The sheet is excessively transparent, has no explicit close affordance, and gives two long equal-weight footer actions.

Direction review completed: three concepts considered — (A) street-first destination list with an explicit Edit action and stable add/location footer; (B) selected-address hero with collapsed alternatives; (C) system list with embedded action rows and swipe editing. Independent reviewer `/root/address_sheet_review` selected A across the sixteen-dimension source/design review. B adds a disclosure step; C hides editing and can place location below a long address list. A preserves one-tap selection and discoverable editing with the fewest hidden steps. Brand: existing PP semantic color/spacing/type tokens, GM font family, system symbols; no logo or new palette.

Visual baseline is the supplied JPG. Candidate native rendering, AX/RTL pixels and motion remain UNVERIFIED; there is no authorized native build in this turn. The source implementation is delivered under the user instruction; static checks cannot certify its rendered result.

### Redesign implementation: completed

- A private UIKit address cell owns one continuous rounded surface. The screenshot's shared-cell opaque rectangle, second background configuration and competing native accessories are removed from this sheet. Shared `PPOptionCell` remains unchanged.
- Street, additional address details, actual geographic names and recipient each appear once; default status appears once. Direction isolates preserve mixed Arabic/Latin address parts. The old XLForm display value is retained for legacy compatibility; an explicit saved address ID takes precedence over a stale legacy string.
- Separate minimum-size selection and Edit controls expose separate VoiceOver actions. Selected state uses a checkmark, border and selected accessibility trait. All text wraps and scales; color changes resolve the row border for its actual traits.
- Opaque semantic backgrounds, a compact header and a close action replace the transparent composition. A content-aware detent expands for larger accessibility text. The bottom action stack is pinned to the table viewport, reserves its measured height and follows a docked keyboard.
- Add new address is the primary footer action; current location opens the existing optional-assisted address form. Removed the picker’s unreachable duplicate location engine; permission, sampling and geocoding remain with the real address form.
- Refresh exposes loading/failure/retry while retaining the existing rows, with UID/generation checks and a bounded wait. Saved selections still complete once through the original ownership guard and exact address object. Save/delete/push/sheet/search callbacks remain intact.
- Added nine Arabic/English `address_picker_*` translations and included them in the existing localization contract guard. No new source file, project membership, public API, Firebase contract, pricing or QIB behavior was introduced.

Current follow-up files: `PPSelectAddressVC.m`, both `Localizable.strings`, `scripts/ordering_journey_regression_test.py`, and this handoff. Pre-redesign copies are preserved under `/tmp/pp-address-sheet-baseline/` for review. All other earlier ordering changes are preserved.

### Redesign testing: completed (source/static)

Final focused checks on 2026-11-04:

- `python3 scripts/ordering_journey_regression_test.py`: **18/18 PASS**. Includes the prior ordering guards, all nine new localized picker keys, and a new confirmed-delete/failed-refresh source-contract guard.
- `plutil -lint` on Arabic and English `Localizable.strings`: **PASS**. New keys have one entry per language and matching format arguments.
- Objective-C grammar parsing of the picker before and after the redesign: **PASS**, no grammar errors. Repeated against the final refined source: **PASS**. This is syntax evidence, not a native compile.
- `git diff --check`: **PASS**.
- Exact comparison confirms the public header and seven key method bodies remain unchanged: effective-ID resolution, legacy display value, ownership/idempotent selection completion, add/current-location routes, completion after editor dismissal, and search dismissal. The editor presentation adds keyboard cleanup; the deletion callback now immediately reflects an acknowledged deletion locally.
- Installed UIKit headers were inspected for the relevant configuration/viewport APIs. No app dependency, project membership, protected tooling, or skill file was changed.

The earlier 515-check ordering verification above is the previous full pass. This follow-up reran the focused journey suite and affected source/resource checks; it does not imply every earlier suite was rerun.

### Redesign refinement: completed (source review)

Independent read-only reviewer `/root/address_sheet_review` reported no remaining actionable source defects after two corrections:

1. Search → Add/Edit/location → close could leave a stale keyboard overlap. The picker now resigns search and clears the overlap before presenting the form, processes hide events even while an editor is presented, and resets absent-keyboard state on return.
2. A confirmed server deletion could leave a selectable row when the subsequent read failed. The delegate now checks the picker UID and removes only the acknowledged deleted ID from local options before refreshing, retaining the selected-model clearing. Failed refresh preserves this acknowledged local result.

Review also confirmed a complete self-sizing row constraint chain, distinct selection/Edit accessibility controls, one default announcement, isolated mixed-script text, saved-model identity precedence, legacy display-value compatibility, preserved UID/owner/completion guards, and the existing saved-address/location routes. These are source findings, not device acceptance.

Remaining gate: **UNVERIFIED native build/render/interaction** under the existing physical iPhone 13 Pro Max/default DerivedData policy. Next authorized pass should exercise the supplied screenshot's two-address Arabic case, English, empty/search/no-results, long address text, AX5, VoiceOver, dark appearance, scrolling to the last row, search → editor → return, and confirmed deletion followed by failed refresh. No build, Simulator, device install/launch, deployment, production mutation, commit or push was performed for this redesign.

## Cart → payment hang — candidate fix implemented; native confirmation pending

Reported trigger: tapping Continue to payment from Cart. Preserved the 21-path dirty baseline and full staged/unstaged diffs at `/var/folders/n6/5p16xph116n5w19rfp1yvvxh0000gn/T/pp-checkout-hang-baseline-4s01pc55/`. Scope is the existing payment controller and shared checkout dock; payment authority and the saved-address redesign remain intact.

Inspection/attribution: `checkoutTapped` calls the existing `PPSelectPaymentVC` push route. Address, payment-instrument and pricing reads are asynchronous; the inspected entry path contains no semaphore or synchronous dispatch wait. Source inspection found a definite constraint conflict: `pp_reviewActionButtonWithTitle:` gives the retry/contact actions a required nonzero minimum height, then `pp_updateCheckoutReview` hides them as vertical stack children. It also found synchronous child/ancestor layout calls from dock visibility updates during controller construction, and adaptive-axis decisions based on the same label's wrapping-dependent intrinsic size. These are source defects/feedback risks on the entry path; the exact frozen device stack has not been obtained.

Live evidence boundary: the approved iPhone 13 Pro Max is connected. Read-only Xcode inspection initially showed an ended debug session; a later live session appeared, but ended before the pause attempt produced any thread frames. No app build or launch was initiated by the agent. The requested independent read-only agents all failed with a usage-limit error, so no independent findings are claimed for this follow-up. No native before/after timings or fixed-hang claim can be made yet.

Correction direction: allow hidden stack actions to collapse, defer nonanimated dock layout to UIKit, keep animated disclosure layout to one ancestor pass, and make the dock's axis decision independent of its current wrapping. Add narrow source regression guards and non-private navigation/view-construction signposts for a subsequent authorized device capture.

Implementation completed:

- `PPSelectPaymentVC.m`: retry/contact minimum heights now yield to the stack’s required hidden height; initial adaptive-summary configuration schedules layout rather than synchronously forcing it. Added `CheckoutPresentation` signposts for `CartToPaymentPresentation` and `PaymentViewConstruction`. They contain no address, phone, UID, payment details, or order data; the navigation interval ends on appearance, cancellation or deallocation.
- `PPContextAwareCheckoutView.swift`: ignores unresolved/invalid width, measures unwrapped total text independently of current label geometry, and changes constraints only when the axis actually changes. Nonanimated visibility updates mark layout dirty without forcing child/ancestor reentry. Onscreen disclosure animation still establishes its starting layout and performs one ancestor layout inside the animation.
- `scripts/ordering_journey_regression_test.py`: added three source regression guards for the hidden-action conflict, synchronous construction layout, and feedback-dependent axis decision. All three were observed failing before the patch and passing after it.

Verification completed (source/model only):

| Gate | Result |
|---|---:|
| Ordering journey regression | 21/21 PASS |
| Checkout idempotency regression | 58/58 PASS |
| Checkout state-machine regression | 158/158 PASS |
| Server-authoritative revalidation regression | 36/36 PASS |
| Swift frontend syntax parse of the shared dock | PASS |
| Objective-C grammar parse of payment controller | PASS |
| `git diff --check` | PASS |
| Eight payment/address/total/lifecycle method bodies compared with pre-fix snapshot | Unchanged |
| Remaining 17 prior dirty files and staged patch | Byte-for-byte unchanged |

Total: **273 passing source/model checks**, including three red-before/green-after regressions. The first shell wrapper for three suites used zsh's read-only `status` variable and failed after the scripts ran; it was corrected to `pp_check_exit`, and all three suite invocations then exited zero. This was a verification-wrapper error, not an app test failure.

Remaining acceptance gate: **UNVERIFIED** native compilation and the exact Cart → payment interaction, with no before/after timing or frozen-thread stack available. The candidate is ready for an explicitly authorized build/install/run on the connected iPhone 13 Pro Max with default DerivedData. Capture the two signpost intervals and, if the freeze persists, pause the active app for its main-thread stack before further changes. Exercise cold/warm entry, repeated navigation, empty/saved-address states, large totals, Arabic/English, Dynamic Type, and disclosure motion. No purchase or production write is part of that validation.
