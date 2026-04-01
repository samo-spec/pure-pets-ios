# QIB Production Smoke Checklist

Run this checklist after each production deploy:

1. Confirm function revisions in `us-central1`:
   - `createQibSession`
   - `verifyQibPayment`
   - `prepareOrderForRetry`
   - `reconcileQibPendingVerifications`
2. Confirm runtime config:
   - `QIB_MODE=live`
   - `QIB_GATEWAY_ID_LIVE` and `QIB_SECRET_KEY_LIVE` are set
   - `QIB_ALLOW_LEGACY_CLIENT_BOOTSTRAP=true` (required for current mobile SDK contract)
   - `QIB_VERIFY_URL` is set and reachable
   - `QIB_ENFORCE_APP_CHECK=true` (or temporary controlled override)
3. Create a fresh pending order from app and start checkout.
4. Verify `createQibSession` log shows:
   - `mode: "live"`
   - `configSource: "live_pair"`
5. Complete one real payment and confirm:
   - `Orders/{orderId}.status == "paid"`
   - `Orders/{orderId}.transactionId` is present
   - `verificationStatus == "verified"`
6. Run one failed/cancelled attempt and confirm:
   - `status == "failed"` (or `verificationStatus == "pending"` for temporary provider outages)
   - `failureReason` is populated
7. Confirm no raw PAN/CVV fields in:
   - `UsersCol/{uid}/paymentInstruments/*`
8. Run compliance maintenance:
   - Trigger `runPaymentInstrumentScrub` once after deploy
   - Review logs for `auditPaymentInstrumentCompliance`
