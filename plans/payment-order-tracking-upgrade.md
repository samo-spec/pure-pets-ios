# Implementation Plan - Payment, Order, and Tracking System Upgrade

## 1. 🔍 Analysis & Context
*   **Objective:** Upgrade the Pure Pets payment and order tracking flows to production-grade quality by enforcing strict driver ownership, migrating QIB online payments to a secure Phase 2 (URL-based) architecture, and implementing robust retry, idempotency, and UI synchronization logic.
*   **Affected Files:**
    *   `Pure Pets Pro/PurePetsPro/DeliverySection/PPDeliveryManager.m`
    *   `Pure Pets Pro/PurePetsPro/DeliverySection/PPDeliveryManager.h`
    *   `Pure Pets Infra/functions/qibPayment.js`
    *   `Pure Pets/MainApp/PAYMENTS/Manager/Payment/PPPaymentManager.m`
    *   `Pure Pets/MainApp/PAYMENTS/Checkout/PPCheckoutCoordinator.m`
    *   `Pure Pets/MainApp/PAYMENTS/Manager/Order/PPOrderManager.m`
    *   `Pure Pets Infra/functions/index.js`
*   **Key Dependencies:**
    *   Firebase Cloud Functions (Node.js)
    *   Firestore
    *   iOS Objective-C (Pure Pets Customer and Pro Apps)
    *   QIB Payment Gateway
*   **Risks/Unknowns:**
    *   Migrating from returning `secretKey` to `paymentUrl` (Phase 2) requires changes to how the iOS SDK initiates the payment UI. This is a high-risk change impacting checkout conversion.
    *   Removing `adminTransitionOrderStatus` from the Pro app might break existing driver workflows if `deliveryTransitionOrderStatus` rules are too strict or misconfigured.
    *   Introducing idempotency keys requires robust local state management on iOS to prevent order duplication on network drops.

## 2. 📋 Checklist
- [ ] Step 1: Enforce Strict Delivery Endpoint Routing (Pro App)
- [ ] Step 2: Implement QIB Phase 2 Server-Side Tokenization (Infra)
- [ ] Step 3: Update iOS Customer App for QIB Phase 2
- [ ] Step 4: Harden Idempotency & Retry Logic (iOS)
- [ ] Step 5: Implement Automated Reconciliation Cron Jobs (Infra)

## 3. 📝 Step-by-Step Implementation Details

### Step 1: Enforce Strict Delivery Endpoint Routing (Pro App)
*   **Goal:** Prevent privilege escalation by ensuring the Pro driver app only uses the constrained `deliveryTransitionOrderStatus` endpoint.
*   **Action:**
    *   Modify `Pure Pets Pro/PurePetsPro/DeliverySection/PPDeliveryManager.m`: Remove the generic `- (void)performAction:...` method that calls `adminTransitionOrderStatus`.
    *   Update all action methods (e.g., `markOrderShipped:`, `collectCashPayment:`) to route through `- (void)performDeliveryAction:...`.
    *   Modify `Pure Pets Pro/PurePetsPro/DeliverySection/PPDeliveryManager.h` to reflect the removal of the admin callable.
*   **Verification:** Ensure the Pro app compiles. Attempting to trigger a delivery action while logged in as a non-delivery user should return a `permission-denied` error from the Cloud Function.

### Step 2: Implement QIB Phase 2 Server-Side Tokenization (Infra)
*   **Goal:** Secure the QIB `secretKey` by preventing it from being transmitted to the client.
*   **Action:**
    *   Modify `Pure Pets Infra/functions/qibPayment.js`: Refactor `createQibSession`. Instead of returning `{ sessionId, gatewayId, secretKey, mode, currency, paymentAttemptId }`, construct the payment URL server-side (using the QIB API specs) and return `{ sessionId, paymentUrl, mode, paymentAttemptId }`.
*   **Verification:** Deploy the function locally or to a staging environment. Call `createQibSession` via Postman or Firebase emulator UI and verify `secretKey` is absent and `paymentUrl` is present.

### Step 3: Update iOS Customer App for QIB Phase 2
*   **Goal:** Adapt the iOS payment flow to use the new server-generated `paymentUrl`.
*   **Action:**
    *   Modify `Pure Pets/MainApp/PAYMENTS/Manager/Payment/PPPaymentManager.m`: Update the completion handler for `createQibSession` to expect `paymentUrl`. Remove logic that initializes the QIB mobile SDK with the `secretKey`. Instead, present a web view (e.g., `SFSafariViewController` or `WKWebView`) loading the `paymentUrl`.
    *   Implement URL interception/callbacks in the web view to detect payment completion/failure and trigger the existing `verifyQibPayment` flow.
*   **Verification:** Run the iOS app. Complete a checkout flow using the new web-based QIB UI and ensure it successfully verifies and updates Firestore.

### Step 4: Harden Idempotency & Retry Logic (iOS)
*   **Goal:** Prevent duplicate orders on network failures and gracefully handle retry rejections.
*   **Action:**
    *   Modify `Pure Pets/MainApp/PAYMENTS/Manager/Order/PPOrderManager.m`: Generate a deterministic UUID (`idempotencyKey`) when initiating `createPendingOrder`. Pass this key in the payload. Ensure the key persists locally if the request times out, so retries use the same key.
    *   Modify `Pure Pets/MainApp/PAYMENTS/Checkout/PPCheckoutCoordinator.m`: Enhance error handling around `prepareOrderForRetry`. If it fails with `failed-precondition` (e.g., order is already paid), parse the error, dismiss the retry UI, and gracefully navigate the user to the success screen or order details.
*   **Verification:** Simulate a network drop during checkout. Verify that a retry creates/updates the same order ID in Firestore instead of creating a duplicate.

### Step 5: Implement Automated Reconciliation Cron Jobs (Infra)
*   **Goal:** Clean up stale data and release reserved inventory for abandoned orders.
*   **Action:**
    *   Modify `Pure Pets Infra/functions/index.js` (or create a new scheduled function file): Implement a Cloud Scheduler function (`onSchedule("every 30 minutes")`).
    *   Query `qibSessions` where `expiresAt < now()` and `status == 'created'`. Mark them as `expired`.
    *   Query `Orders` where `status == 'pending'` and `createdAt` is older than 24 hours. Mark them as `failed` (or `cancelled`) and trigger inventory restock logic.
*   **Verification:** Manually trigger the scheduled function in the GCP console or emulator and verify stale records are updated correctly.

## 4. 🧪 Testing Strategy
*   **Unit Tests:**
    *   Backend: Add tests in `Pure Pets Infra/functions/scripts/` to verify `createQibSession` no longer exposes the secret.
*   **Integration Tests:**
    *   Test the full QIB Phase 2 flow via the iOS UI.
    *   Test the driver delivery flow (Accept -> Pick Up -> Transit -> Deliver -> Collect Cash) using a test driver account.
*   **Manual Verification:**
    *   Force close the iOS app during payment verification and verify the retry flow handles the recovery gracefully without duplicating the charge.
    *   Attempt to use the Pro app to collect cash on an order assigned to a *different* driver to verify the ownership lock.

## 5. ✅ Success Criteria
*   The QIB `secretKey` never leaves the Cloud Functions environment.
*   The Pro app strictly uses `deliveryTransitionOrderStatus` and cannot bypass assignment locks.
*   Network drops during order creation do not result in duplicate `Orders` documents.
*   Abandoned pending orders are automatically cleaned up after 24 hours.
