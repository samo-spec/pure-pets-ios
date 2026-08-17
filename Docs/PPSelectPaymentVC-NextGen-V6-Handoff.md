# PPSelectPaymentVC NextGen V6 Handoff

Last updated: 2026-08-16

## Current Status

- Target: `PPSelectPaymentVC`
- Platform: iOS 15+, code-only UIKit and Objective-C
- Mode: `redesign`
- Selected direction: Confidence Runway
- Current phase: handoff complete, runtime proof blocked
- Certification: `BLOCKED/UNVERIFIED`
- Backend and API changes: none
- Build authority: physical iPhone 13 Pro Max only, default DerivedData path, no simulator and no `xcodebuild`

## Frozen Scope

- Redesign the Select Payment surface and directly owned visual components, including the Address Picker Pill checkpoint (`PPAddressPickerView`).
- Re-architected `PPAddressPickerView` to the Verified Express Checkpoint concept: continuous squircle icon plate, active/prompt status dot indicator, two-tier Beiruti typography hierarchy, and a dedicated interactive trailing action pill ("تغيير" / "Change" or "اختيار" / "Select" chip with directional micro-chevron).
- Added Dynamic Type scaling via `UIFontMetrics`, accessible reflow for AX categories (88-104pt adaptive height), Reduce Motion spring dampening guards, High Contrast border handling, and solid background rendering under Reduce Transparency and dark mode.
- Preserved navigation, checkout scopes, payment method IDs, instrument IDs, selection ownership, totals, address validation, phone recovery, retry and idempotency, cart locking and clearing, analytics, Firebase listeners, API payloads, coordinator behavior, and order routing.
- Keep Cloud Functions, Firebase rules, schemas, callable contracts, payment gateways, persistence, and backend state untouched.
- Keep dormant add, edit, and delete capabilities at their existing reachability.
- Use Arabic RTL as the primary composition and English LTR as the secondary composition.

## Authority Map

- Screen and route owner: `Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPSelectPaymentVC.m`
- Selection and collection owner: `Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPSelectPaymentVC+Helper.m`
- Payment cell owner: `Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPPaymentMethodCell.m`
- Delivery checkpoint owner: `Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPAddressPickerView.m`
- Payment model authority: `Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PaymentMethod.m`
- Checkout transaction authority, read-only: `Pure Pets/MainApp/PAYMENTS/Checkout/PPCheckoutCoordinator.m`
- Totals authority, read-only: `PPCartCalculator`
- Persistent summary owner, read-only: `Pure Pets/DesignFiles/PP/PPNAV/PPPremuimChekoutView.swift`
- Brand authority: `Pure Pets/DesignFiles/PP/PPStyles/PurePets-DesignSystem.swift`
- Layout token authority: `Pure Pets/DesignFiles/PP/PPStyles/PPDesignTokens.h`
- Localization authority: `Pure Pets/ar.lproj/Localizable.strings` and `Pure Pets/en.lproj/Localizable.strings`

## Phase Log

### Phase 1: Intake And Limits

Status: complete

- Resolved the user target to `PPSelectPaymentVC`.
- Froze `redesign` mode and a frontend-only change boundary.
- Confirmed the required connected device is an iPhone 13 Pro Max.
- Confirmed the installed Pure Pets bundle is `com.PB.Pure-Bird`.
- Recorded that the device is locked and cannot currently launch the app for baseline capture.

### Phase 2: Source And Behavior Inspection

Status: complete

- Traced cart and explicit-item entry routes, custom back navigation, order-details adjacency, payment selection, remote availability flags, saved instruments, address refresh, QIB phone recovery, checkout coordinator results, and error recovery.
- Confirmed the screen owns presentation while `PPCheckoutCoordinator`, Firebase managers, and `PPCartCalculator` own transaction and data behavior.
- Found no checked-in baseline screenshot for this target.
- Identified visual-only seams in the hero, delivery checkpoint, method collection, method cells, section header, accessibility semantics, and motion.

### Phase 3: Parity, Brand, Direction, And Native UX

Status: complete

- Froze a source-backed behavior ledger with no authorized backend or API changes.
- Bound color roles to `ppPrimary`, `ppBackground`, `ppSurface`, `ppTextPrimary`, `ppTextSecondary`, and semantic success colors.
- Considered exactly three concepts: Confidence Runway, Method Stage, and Checkout Ledger.
- Selected Confidence Runway after an independent source review found no structural veto.
- Rejected Method Stage because it promoted an automatically selected default and destabilized list identity.
- Rejected Checkout Ledger because it crossed shared summary ownership and the persistent bottom-summary contract.
- Chose motion policy `reduce`: one bounded entrance, direct selection feedback, static controller-owned atmosphere, and preservation of the shared trust signal with its built-in Reduce Motion handling.

### Phase 4: Implementation

Status: complete

- Reorganized compact-width payment choices into full-width horizontal lanes.
- Preserved adaptive two-column presentation only for regular width when content size is not an accessibility category.
- Added semantic design tokens, Dynamic Type scaling, RTL-aware hero gradient direction, increased-contrast borders, solid Reduce Transparency-safe address treatment, and 44-point back control sizing.
- Added selected accessibility traits and stable screen-level identifiers.
- Added verified Apple logo fallback and generic NAPS system-symbol fallback without inventing a payment mark.
- Added missing localized display-name entries for Apple Pay and NAPS Debit.
- Reduced hero, summary, address, and selection motion without changing action timing or checkout feedback ownership.
- Added a compact hero mode for iPhone, compact-width split view, short-height layouts, and accessibility text sizes.
- Added an adaptive, noninteractive condensed summary mode for short-height and expanded-text layouts while preserving the total and checkout CTA.
- Guaranteed an 88-point scrollable payment-method viewport at priority 999 so the checkout CTA and method selection remain reachable together.
- Kept the existing shared trust-banner behavior and its built-in Reduce Motion handling.

### Phase 5: Independent Review

Status: complete

- Resolved the short-device and AX viewport finding with compact hero reflow, condensed summary presentation, and a protected method viewport.
- Resolved XXXL and AX5 source-level reflow risks with expanded cell tiers, compact section hierarchy, and hidden-view constraint replacement.
- Resolved redundant selected-state announcements by using the selected trait as the selected-state carrier.
- Resolved duplicate automation identifiers by keying each payment cell to instrument identity.
- Final independent source review reported no blocking source finding.
- Residual risk: compressed summary text may truncate on the shortest AX5 layout and requires physical-device pixel review.
- Confirmed no checkout, Firebase, API, persistence, payment-ID, payload, or routing behavior changed.

### Phase 6: Verification And Render Review

Status: `BLOCKED/UNVERIFIED`

- Passed `git diff --check`.
- Passed `plutil -lint` for English and Arabic localization files.
- Parsed all four changed Objective-C files with `clang-format` without syntax-structure errors.
- Confirmed zero diff in Checkout, Manager, `PaymentMethod.m`, `UserPaymentInstrument*`, and `PPOrderDetailsRouter.m` authorities.
- Confirmed the changed-file scope contains only the target UI, its directly owned visual components, localization, and this handoff.
- CodeRabbit CLI was unavailable, so independent source review used a separate read-only reviewer.
- Independent proof returned `certified: false`, `reviewUnlocked: false`, and overall `BLOCKED/UNVERIFIED`.
- Required native checks: build and launch on connected iPhone 13 Pro Max using repository-authorized Xcode workflow.
- Required visual set: Arabic RTL and English LTR, light and dark, compact and regular width, default and selected/loading or recovery states, and large Dynamic Type.
- Current blocker: two launch attempts were denied because the connected device is locked, so baseline and candidate screenshots cannot be captured.
- No `xcodebuild` or simulator build was run, in accordance with repository policy.

## Source Evidence Snapshot

Observed: 2026-08-16T17:23:11Z

```text
b05cf7f369f46f7d32761a0a39da9f7b26a95a213cdd2917c76512844c3079fc  Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPSelectPaymentVC.m
3ae84693acf620396a48b2f70949e7911fc4cbb3d723239e00f1508d383e0a34  Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPSelectPaymentVC+Helper.m
97af52affb7fc28bd62cd07767da4e15d5d9e8835c6aba2a24e2fec4f2f0e727  Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPPaymentMethodCell.m
ab5b27c75e5ce598cd3508f345c6956bacc99fe68cec8f6e5825a20dc927d3cc  Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPAddressPickerView.m
7f079eb019e3593e1e8264af64edb02a53bc8511d1fd0f3bc83a58ba1e0a1e5f  Pure Pets/en.lproj/Localizable.strings
52ef80c77a145f10c2b9ca46d78df02a122afedbe9bd1484a43029f8665be5e1  Pure Pets/ar.lproj/Localizable.strings
```

## Changed Files

- `Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPSelectPaymentVC.m`
- `Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPSelectPaymentVC+Helper.m`
- `Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPPaymentMethodCell.m`
- `Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPAddressPickerView.m`
- `Pure Pets/ar.lproj/Localizable.strings`
- `Pure Pets/en.lproj/Localizable.strings`
- `Docs/PPSelectPaymentVC-NextGen-V6-Handoff.md`

## Preserved Contracts

- Shared-cart and explicit-item checkout remain distinct.
- Explicit checkout does not lock, clear, or mutate the shared cart.
- Payment remains directly before order details in the navigation stack.
- Method availability remains controlled by current commerce configuration.
- Selection remains keyed by instrument ID and owned by `PPCurrentUser.SelectedInstrument`.
- Cash keeps Place Order behavior; online methods keep Pay Now behavior.
- Totals continue to come from `PPCartCalculator`.
- Checkout still refreshes and validates the selected address.
- QIB phone validation and recovery remain unchanged.
- Coordinator reuse, retry, cancellation, pending verification, and idempotency remain unchanged.
- Shared-cart clearing remains success-only.
- Analytics and commerce feedback timing remain unchanged.

## Next Action

Unlock the iPhone, perform the repository-authorized physical-device Xcode build and launch, then capture and independently review the required baseline and candidate evidence set.
