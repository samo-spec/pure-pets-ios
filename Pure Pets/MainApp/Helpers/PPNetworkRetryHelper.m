//
//  PPNetworkRetryHelper.m
//  Pure Pets
//
//  M-10: Exponential-backoff retry helper
//  M-11: Offline pre-check via YYReachability
//

#import "PPNetworkRetryHelper.h"
#import "YYReachability.h"

/// Default maximum number of retries after the initial attempt.
static NSInteger const kPPRetryDefaultMaxRetries = 3;

/// Base delay in seconds before the first retry. Subsequent delays double.
static NSTimeInterval const kPPRetryBaseDelay = 1.0;

/// Multiplier applied to the delay on every successive retry.
static const double kPPRetryMultiplier = 2.0;

@implementation PPNetworkRetryHelper

#pragma mark - Public API

+ (void)retryBlock:(PPRetryOperationBlock)block
        maxRetries:(NSInteger)maxRetries
        completion:(PPRetryCompletionBlock)completion
{
    NSParameterAssert(block);
    if (!block) {
        if (completion) { completion(NO); }
        return;
    }

    maxRetries = MAX(maxRetries, 0);
    [self pp_executeBlock:block
                  attempt:0
               maxRetries:maxRetries
               completion:completion];
}

+ (void)retryBlock:(PPRetryOperationBlock)block
        completion:(PPRetryCompletionBlock)completion
{
    [self retryBlock:block maxRetries:kPPRetryDefaultMaxRetries completion:completion];
}

#pragma mark - Reachability (M-11)

+ (BOOL)isNetworkAvailable
{
    // YYReachability synchronously queries SCNetworkReachability flags — safe on any thread.
    YYReachability *reachability = [YYReachability reachability];
    return reachability.isReachable;
}

#pragma mark - Internal

+ (void)pp_executeBlock:(PPRetryOperationBlock)block
                attempt:(NSInteger)attempt
             maxRetries:(NSInteger)maxRetries
             completion:(PPRetryCompletionBlock)completion
{
    block(^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                if (completion) { completion(YES); }
                return;
            }

            if (attempt >= maxRetries) {
                // All retries exhausted.
                if (completion) { completion(NO); }
                return;
            }

            // Exponential backoff: delay = base × multiplier^attempt
            NSTimeInterval delay = kPPRetryBaseDelay * pow(kPPRetryMultiplier, (double)attempt);

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [self pp_executeBlock:block
                              attempt:attempt + 1
                           maxRetries:maxRetries
                           completion:completion];
            });
        });
    });
}

@end
