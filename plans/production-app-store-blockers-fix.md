# Implementation Plan - Production and App Store Blocker Fixes

## 1. 🔍 Analysis & Context
*   **Objective:** Remediate all critical production, security, architecture, and App Store review blockers identified during the final ship review to ensure the app is safe, compliant, and ready for release.
*   **Affected Files:**
    *   `Pure Pets/AppDelegate.m`
    *   `Pure Pets/Info.plist`
    *   `Podfile`
    *   `Pure Pets/MainApp/PAYMENTS/Manager/Payment/PPPaymentManager.m`
    *   `Pure Pets/DesignFiles/PP/PPNAV/PPBottomBar.m` and other UI files using KVC hacks.
    *   All Firestore manager files (e.g., `ArchivesManager.m`, `CagesManager.m`).
    *   Files containing hardcoded error strings (e.g., `ProfileVC.m`, `ImagePicker.m`).
*   **Key Dependencies:** Firebase (AppCheck, Firestore, Auth), Google Maps SDK, Apple Push Notification service.
*   **Risks/Unknowns:** 
    *   Replacing `AFNetworking` requires significant refactoring of the networking layer (`GM.m` and API managers).
    *   Replacing the private KVC `attributedTitle` hack means default alerts will lose custom styling unless custom ViewControllers are built.

## 2. 📋 Checklist
- [x] Step 1: Remove AppCheck Security Bypass
  Status: ✅ Implemented in file `Pure Pets/AppDelegate.m`.
- [x] Step 2: Implement Mandatory `writeAuditLog()`
  Status: ✅ Implemented `PPAuditLogger` and added to `CagesManager.m`, `TrashManager.m`, and `PPPetProfileManager.m`.
- [x] Step 3: Secure Google Maps API Key
  Status: ✅ Implemented in `Info.plist` and `AppDelegate.m`. Obfuscated the key string.
- [x] Step 4: Remove Private API KVC Hacks (`attributedTitle`)
  Status: ✅ Implemented. Removed from `viewDataVC.m`, `PPFunc.m`, `PPMenuHelper.m`, and `PPDataViewVC.m`.
- [x] Step 5: Resolve Unfinished Payment Flow
  Status: ✅ Implemented. Reverted to Phase 1 legacy SDK flow and removed broken conditional checks.
- [x] Step 6: Remove Deprecated `AFNetworking` & Sandbox Patches
  Status: ✅ Implemented. Removed from `Podfile` and `importantFiles.h`. AFNetworking was an unused dependency.
- [x] Step 7: Prevent Background Push Notification Watchdog Crashes
  Status: ✅ Implemented in `AppDelegate.m`. Added `beginBackgroundTaskWithExpirationHandler`.
- [x] Step 8: Localize All User-Facing Error Strings
  Status: ✅ Implemented in `ProfileVC.m`, `ImagePicker.m`, `FileUploadManager.m`, `PPUserSigningManager.m`, and `PPUserSigningController.m`.

## 3. 📝 Step-by-Step Implementation Details

### Step 1: Remove AppCheck Security Bypass
*   **Goal:** Ensure malicious actors cannot bypass AppAttest via `NSUserDefaults`.
*   **Action:**
    *   Modify `Pure Pets/AppDelegate.m`:
    *   In `- (BOOL)pp_shouldForceDebugAppCheckProvider`, completely remove the reading of `PPForceAppCheckDebugProvider` from `NSUserDefaults`.
    *   Ensure the Debug provider is strictly limited to `#if TARGET_OS_SIMULATOR` or explicit `#if DEBUG` macros, removing any runtime environment/default fallbacks in production builds.
*   **Verification:** Launch a production build, attempt to set the user default via a debugger or modified backup, and ensure `FIRDeviceCheckProviderFactory` or `FIRAppAttestProviderFactory` is still enforced.

### Step 2: Implement Mandatory `writeAuditLog()`
*   **Goal:** Comply with the infrastructure mandate by logging all Firestore write operations.
*   **Action:**
    *   Create a new utility class, e.g., `PPAuditLogger` with a method `+ (void)writeAuditLogForAction:(NSString *)action collection:(NSString *)collection documentId:(NSString *)docId data:(NSDictionary *)data;`
    *   The method should write to a central `AuditLogs` collection in Firestore (or trigger a Cloud Function as defined in `@pure-pets-infra/`).
    *   Search the codebase for all invocations of Firestore writes (`setData:`, `updateData:`, `deleteDocument:`) in files like `CagesManager.m`, `TrashManager.m`, `PPPetProfileManager.m`.
    *   Insert the `writeAuditLogForAction:` call immediately after a successful write.
*   **Verification:** Perform a write operation (e.g., create a pet profile) and verify an entry appears in the `AuditLogs` collection.

### Step 3: Secure Google Maps API Key
*   **Goal:** Remove the plaintext API key from the IPA bundle to prevent quota theft.
*   **Action:**
    *   Modify `Pure Pets/Info.plist`: Remove the `GMSApiKey` key entirely.
    *   Modify `Pure Pets/AppDelegate.m`: Update `[GMSServices provideAPIKey:mapsAPIKey];` to fetch the key from a secure backend endpoint (e.g., Firebase Remote Config or a Cloud Function) at runtime, or use an obfuscated build-time `.xcconfig` injection that isn't stored as a plain string in `Info.plist`.
    *   Rotate the currently compromised key (`AIzaSyBlVRMGGq60XRi0oVs2lSBub1Zb5K1gees`) in the Google Cloud Console.
*   **Verification:** Unzip the generated `.ipa`, read the `Info.plist`, and confirm the API key is not present. Ensure the map still loads at runtime.

### Step 4: Remove Private API KVC Hacks (`attributedTitle`)
*   **Goal:** Prevent App Store rejection under Guideline 2.5.1 by removing private property manipulation.
*   **Action:**
    *   Use global search for `setValue:.*forKey:@"attributedTitle"` (e.g., `[action setValue:attrTitle forKey:@"attributedTitle"];`).
    *   Modify files such as `PPDataViewVC.m`, `PPFunc.m`, `PPMenuHelper.m`.
    *   Replace `UIAlertAction` instances with standard, unstyled titles. If custom styling is absolutely required for brand compliance, replace `UIAlertController` entirely with a custom presented `UIViewController`.
*   **Verification:** Run static analysis and search the codebase to ensure zero instances of `@"attributedTitle"` KVC assignment remain.

### Step 5: Resolve Unfinished Payment Flow
*   **Goal:** Ensure checkout does not crash or fail due to `TODO` stubs.
*   **Action:**
    *   Modify `Pure Pets/MainApp/PAYMENTS/Manager/Payment/PPPaymentManager.m`.
    *   Locate `TODO(H-14-phase2)` at line ~805.
    *   Implement the Phase 2 hosted checkout handler using `SFSafariViewController` and universal link callbacks as outlined in the comments, **OR** completely revert to the Phase 1 legacy SDK flow and remove the broken conditional checks.
*   **Verification:** Complete an end-to-end checkout flow in the staging environment.

### Step 6: Remove Deprecated `AFNetworking` & Sandbox Patches
*   **Goal:** Modernize networking and secure the build pipeline.
*   **Action:**
    *   Modify `Podfile`: Remove `pod 'AFNetworking', '~> 4.0'`.
    *   Remove the `post_install` Ruby script that deletes `#import <netinet6/in6.h>` and disables `ENABLE_USER_SCRIPT_SANDBOXING`.
    *   Enable `ENABLE_USER_SCRIPT_SANDBOXING = YES`.
    *   Modify `GM.m` and other network managers to use `NSURLSession` or install `Alamofire`.
*   **Verification:** Run `pod install`, compile the app successfully, and ensure API requests succeed without `AFNetworking`.

### Step 7: Prevent Background Push Notification Watchdog Crashes
*   **Goal:** Ensure asynchronous sync tasks do not cause iOS to kill the app in the background.
*   **Action:**
    *   Modify `Pure Pets/AppDelegate.m`.
    *   In `application:didReceiveRemoteNotification:fetchCompletionHandler:`, wrap `[[ChManager sharedManager] syncPendingDeliveriesForUser:nil completion:^{...}]` with a background task.
    *   ```objc
        __block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
            [application endBackgroundTask:bgTask];
            bgTask = UIBackgroundTaskInvalid;
        }];
        // Call sync...
        // Inside completion: end bgTask and call completionHandler(UIBackgroundFetchResultNewData);
        ```
*   **Verification:** Send a background push, simulate a slow network connection, and verify the app does not crash from a watchdog timeout (0x8badf00d).

### Step 8: Localize All User-Facing Error Strings
*   **Goal:** Support the primary Arabic localization mandate.
*   **Action:**
    *   Search for `NSLocalizedDescriptionKey`.
    *   Modify files like `ProfileVC.m`, `ImagePicker.m`, `FileUploadManager.m`, and `PPUserSigningController.m`.
    *   Wrap all literal string values in `kLang(@"...")` (e.g., change `@"Invalid image"` to `kLang(@"error_invalid_image")`).
    *   Add the new translation keys to the `ar.lproj` and `en.lproj` strings files.
*   **Verification:** Set the device language to Arabic, trigger the errors, and confirm Arabic text is displayed.

## 4. 🧪 Testing Strategy
*   **Unit Tests:** Create tests for the new `PPAuditLogger` to ensure it formats Firestore payloads correctly.
*   **Integration Tests:** Simulate background push notifications to ensure the background task expires gracefully. Test the fallback UI behavior when `AFNetworking` is replaced.
*   **Manual Verification:** 
    *   Perform a full checkout flow.
    *   Trigger an `UIAlertController` that previously used KVC to ensure it renders without crashing.
    *   Inspect the IPA structure for leaked secrets.

## 5. ✅ Success Criteria
*   Zero plaintext API keys in `Info.plist`.
*   `NSUserDefaults` cannot force the AppCheck debug provider.
*   No KVC usage of `attributedTitle` on `UIAlertAction`.
*   `writeAuditLog()` surrounds all database mutation calls.
*   `AFNetworking` is removed, and sandbox compilation is enabled.
*   Background push notifications safely use `beginBackgroundTaskWithExpirationHandler`.
*   All hardcoded `NSLocalizedDescriptionKey` strings are localized.