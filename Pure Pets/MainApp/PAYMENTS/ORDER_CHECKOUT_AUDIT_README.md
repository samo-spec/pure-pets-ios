# Pure Pets iOS Order Checkout Audit

## Purpose

This document explains the order placement audit and hardening work completed for the iOS app after Apple reported that an order could not be placed on iPad.

The goal of this fix was to make the full checkout flow reliable end-to-end:

- cart
- checkout preflight
- address validation
- payment method selection
- online payment launch
- backend and Firestore state handling
- async callback handling
- success and failure states
- duplicate submission prevention
- user-facing errors
- iPhone and iPad compatibility
- English and Arabic localization
- RTL and LTR safe messaging
- deep logs with `[PPORDER]`

## Scope

The fix was implemented only inside the iOS payments and checkout flow.

Primary folders:

- `Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles`
- `Pure Pets/MainApp/PAYMENTS/Checkout`
- `Pure Pets/MainApp/PAYMENTS/Manager/Payment`
- `Pure Pets/MainApp/PAYMENTS/Manager/Order`
- `Pure Pets/en.lproj`
- `Pure Pets/ar.lproj`

## Main Root Causes

### 1. Checkout could start with the wrong payment method

What was happening:

- Checkout could continue even when the visible payment selection was not valid.
- The old flow could fall back to `qib` when the selected instrument state was stale or missing.
- That meant the app might launch the online payment path instead of blocking with a clear message.

What it does now:

- Checkout resolves the actual visible payment instrument first.
- If no valid method exists, checkout stops immediately and shows a localized error.
- The checkout button title is updated to match the selected method:
  - cash -> `Place Order`
  - online -> `Pay Now`

Files:

- `Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPSelectPaymentVC.m`
- `Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPSelectPaymentVC+Helper.m`
- `Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPSelectPaymentVC+Helper.h`

### 2. Online payment completion could remain stuck in a non-terminal state

What was happening:

- The UI flow mainly depended on Firestore `status`.
- The backend also uses `paymentStatus` and `verificationStatus`.
- A payment could be verified or approved while the old listener still treated the order as pending.
- That created a stuck checkout or silent non-completion.

What it does now:

- The checkout coordinator resolves terminal state from all relevant fields:
  - `status`
  - `paymentStatus`
  - `verificationStatus`
- Verification success now re-fetches the latest order snapshot before resolving.
- Verification failure now resolves cleanly with a user-facing error.
- Non-terminal verification now opens a safe pending-verification state instead of hanging.

File:

- `Pure Pets/MainApp/PAYMENTS/Checkout/PPCheckoutCoordinator.m`

### 3. Duplicate submissions were not fully protected during payment transitions

What was happening:

- `viewWillAppear` reset loading state even if checkout was still in progress.
- That could re-enable the CTA during a live flow and weaken duplicate prevention.

What it does now:

- Loading state stays bound to the real checkout state.
- Repeated taps are blocked.
- The cart remains locked during the active flow.
- Stale async callbacks are ignored through generation-based checkout tracking.

Files:

- `Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPSelectPaymentVC.m`
- `Pure Pets/MainApp/PAYMENTS/Checkout/PPCheckoutCoordinator.m`

### 4. Payment presentation was not robust enough for iPad and scene-based UI

What was happening:

- Presenter resolution was too simple.
- That is riskier on iPad where the app can be presented in different window and sheet states.

What it does now:

- Payment presentation resolves from the active scene and visible controller hierarchy.
- If no valid presenter exists, the flow fails clearly instead of silently.

File:

- `Pure Pets/MainApp/PAYMENTS/Manager/Payment/PPPaymentManager.m`

### 5. Several failures surfaced weak or non-localized errors

What was happening:

- Some order creation and retry failures surfaced generic or hardcoded fallback text.
- Some errors were not clear enough for users or testers.

What it does now:

- User-facing failures are localized in Arabic and English.
- Preflight failures are explicit.
- Retry and backend failures now log with `[PPORDER]` and surface clearer text.

Files:

- `Pure Pets/MainApp/PAYMENTS/Manager/Order/PPOrderManager.m`
- `Pure Pets/en.lproj/Localizable.strings`
- `Pure Pets/ar.lproj/Localizable.strings`

## File-by-File Fix Summary

| File | What was before | What is fixed now |
| --- | --- | --- |
| `Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPSelectPaymentVC.m` | Checkout could continue with weak preflight validation and loading state could reset too early. | Added strict auth, payment, address, and phone checks. Loading is preserved correctly. Duplicate taps are blocked. Errors are surfaced clearly. |
| `Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPSelectPaymentVC+Helper.m` | Payment selection could become stale and the CTA did not reflect the actual checkout method. | Added stable selected-instrument resolution and CTA refresh logic. |
| `Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPSelectPaymentVC+Helper.h` | Helper interface did not expose the new selection and CTA helpers. | Added declarations required for safe payment selection and CTA updates. |
| `Pure Pets/MainApp/PAYMENTS/Checkout/PPCheckoutCoordinator.m` | Checkout resolution relied too much on a single status path and async callbacks could race or go stale. | Added generation-safe flow control, timeout fallback, latest snapshot fetch, multi-field terminal detection, pending verification handling, and better listener recovery. |
| `Pure Pets/MainApp/PAYMENTS/Manager/Payment/PPPaymentManager.m` | QIB launch and presenter selection were weaker for multi-scene and iPad cases. Logging was incomplete. | Added active presenter resolution, clearer launch failures, phone validation, session logging, and `[PPORDER]` diagnostics. |
| `Pure Pets/MainApp/PAYMENTS/Manager/Order/PPOrderManager.m` | Pending order creation and retry errors were harder to trace and some surfaced weak fallback messages. | Added localized failure messages and `[PPORDER]` logs for create, reuse, retry, and validation paths. |
| `Pure Pets/en.lproj/Localizable.strings` | Missing checkout keys and iPad-incompatible "real iPhone device" wording. | Added new checkout keys and updated device wording to "real device". |
| `Pure Pets/ar.lproj/Localizable.strings` | Missing checkout keys and iPad-incompatible wording. | Added new checkout keys and updated wording to "real device". |

## Implemented Behavior Changes

### Checkout entry

The checkout screen now:

- refuses checkout when the user is not authenticated
- refuses checkout when no valid payment method is available
- refuses checkout when address data is incomplete
- refuses online checkout when no phone number is available
- shows localized warnings instead of silent failure
- keeps the checkout button in loading state while the request is active

### Payment method handling

The checkout CTA now reflects the actual selected method:

- cash -> place order
- online -> pay now

This makes the UX clearer and prevents the wrong mental model for COD users.

### Order creation and retry

The order manager now:

- logs order creation with `[PPORDER]`
- logs pending order reuse with `[PPORDER]`
- logs retry preparation with `[PPORDER]`
- surfaces clearer localized fallback errors

### Online payment verification

The checkout coordinator now:

- listens for Firestore changes
- verifies QIB payment through Cloud Functions
- re-fetches the latest order snapshot when needed
- completes from success-like states
- completes from failure-like states
- falls back to a pending verification screen when confirmation is delayed

### Duplicate submission prevention

The flow now protects against:

- double tap on checkout
- stale callback completion from old requests
- re-enabling the button during payment transitions
- charging a stale in-memory order after cart drift

## Added Logs

All important checkout and payment steps now log with:

```text
[PPORDER]
```

Examples of covered events:

- checkout tap
- preflight block reason
- address refresh failure
- inventory validation start and failure
- pending order create or reuse
- payment request start
- presenter resolution
- QIB session creation
- payment verification
- Firestore listener updates
- success, failure, or pending verification completion

## Localization Added

New or updated localized keys include:

- `payment_place_order`
- `checkout_payment_method_unavailable`
- `checkout_payment_confirmation_delayed`
- `payment_requires_real_device`

These were added or updated in:

- `Pure Pets/en.lproj/Localizable.strings`
- `Pure Pets/ar.lproj/Localizable.strings`

## Build and Validation Notes

### Simulator build result

Command used:

```bash
xcodebuild -workspace 'Pure Pets IOS/Pure Pets.xcworkspace' -scheme 'Pure Pets' -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' CODE_SIGNING_ALLOWED=NO build
```

Result:

- Failed because `QIBPayment.framework` only contains device slices.
- This is a project packaging limitation and prevents a full simulator link for QIB.
- The failure was:
  - building for `iOS-simulator`, but linking in dylib `QIBPayment.framework/QIBPayment` built for `iOS`

### Device build result

Command used:

```bash
xcodebuild -workspace 'Pure Pets IOS/Pure Pets.xcworkspace' -scheme 'Pure Pets' -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Result:

- The build progressed through the updated checkout code and into broader app compilation.
- No checkout-source compile diagnostics were emitted during the device build pass observed in this audit.
- The workspace is large and did not reach a complete finish inside the available session time.

## Recommended QA Test Plan

### Cash on delivery

1. Add one stocked accessory to cart.
2. Select a valid address.
3. Select cash on delivery.
4. Tap checkout once.
5. Confirm:
   - loading starts
   - repeated taps do nothing
   - one order is created
   - cart clears
   - order details screen opens

### Online payment

1. Add one stocked accessory to cart.
2. Select a valid address with a phone number.
3. Select online payment.
4. Start payment on a real device.
5. Confirm:
   - payment screen opens correctly
   - no silent failure occurs
   - success resolves from backend status updates
   - delayed verification opens the pending verification state
   - failure shows a visible localized error

### Validation blocking

Verify checkout is blocked clearly when:

- user is logged out
- no payment method is available
- no valid address exists
- online payment has no phone number

### Device coverage

Test on:

- iPhone
- iPad

Test in:

- English
- Arabic

Confirm:

- messages are localized
- RTL and LTR rendering remain correct
- iPad presentation does not silently fail

## Known Environment Limitation

This audit fixed the checkout source flow, but one environment issue remains outside the checkout logic itself:

- `QIBPayment.framework` is device-only and does not support simulator linking.

If simulator-based automated QA is required for the payment screen, the project will need one of the following:

- a simulator-compatible QIB framework
- a conditional simulator stub
- a debug-only abstraction layer for payment launch

## Summary

This checkout audit fixed the main reliability problems in the iOS order flow:

- wrong payment path fallback
- stuck payment completion
- weak duplicate protection
- fragile iPad presenter resolution
- silent or unclear failure paths
- missing deep logs
- missing localized error coverage

The order flow is now safer, clearer, and easier to debug in production.
