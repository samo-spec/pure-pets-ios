//
//  PPNetworkRetryHelper.h
//  Pure Pets
//
//  Network retry utility with exponential backoff and offline pre-check.
//  M-10: Retry helper  |  M-11: Offline pre-check
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Block that performs an async operation and reports success/failure via its completion.
typedef void (^PPRetryOperationBlock)(void (^completion)(BOOL success));

/// Block called when the retry sequence finishes.
typedef void (^PPRetryCompletionBlock)(BOOL succeeded);

/**
 Lightweight retry utility with exponential backoff, designed for
 Firestore writes and other transient-failure-prone network operations.

 Backoff schedule (base = 1 s, multiplier = 2×):
   Attempt 1 → immediate
   Retry  1  → 1 s delay
   Retry  2  → 2 s delay
   Retry  3  → 4 s delay
 */
@interface PPNetworkRetryHelper : NSObject

/// Retry a block up to @c maxRetries times with exponential backoff.
/// @param block      The async operation. Call its inner completion with YES on success, NO to trigger a retry.
/// @param maxRetries Maximum number of retry attempts after the initial attempt (default 3).
/// @param completion Called on the main queue when the operation succeeds or all retries are exhausted.
+ (void)retryBlock:(PPRetryOperationBlock)block
        maxRetries:(NSInteger)maxRetries
        completion:(PPRetryCompletionBlock)completion;

/// Convenience that uses the default max-retry count (3).
+ (void)retryBlock:(PPRetryOperationBlock)block
        completion:(PPRetryCompletionBlock)completion;

#pragma mark - Reachability Pre-Check (M-11)

/// Synchronous check using the existing YYReachability infrastructure.
/// @return YES when the device has WiFi or cellular connectivity.
+ (BOOL)isNetworkAvailable;

@end

NS_ASSUME_NONNULL_END
