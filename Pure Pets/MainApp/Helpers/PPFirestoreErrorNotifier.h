//
//  PPFirestoreErrorNotifier.h
//  Pure Pets
//
//  Centralized Firestore error surfacing utility.
//  Managers call +postError:context: to broadcast silent Firestore failures.
//  A single top-level observer (registered in AppDelegate) presents a
//  non-blocking auto-dismissing banner so the user is aware of transient issues
//  without being blocked by modal alerts.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Notification name broadcast when a Firestore operation fails silently.
/// userInfo keys: @"error" (NSError), @"context" (NSString).
FOUNDATION_EXPORT NSNotificationName const PPFirestoreErrorOccurredNotification;

#pragma mark - Context Keys

/// Predefined context strings for categorising error sources.
FOUNDATION_EXPORT NSString *const PPFirestoreContextCartPricingFetch;
FOUNDATION_EXPORT NSString *const PPFirestoreContextCartItemSync;
FOUNDATION_EXPORT NSString *const PPFirestoreContextCartBatchSync;
FOUNDATION_EXPORT NSString *const PPFirestoreContextCartListener;
FOUNDATION_EXPORT NSString *const PPFirestoreContextCartQuantityUpdate;
FOUNDATION_EXPORT NSString *const PPFirestoreContextCartDeleteQuery;
FOUNDATION_EXPORT NSString *const PPFirestoreContextCartDeleteItem;
FOUNDATION_EXPORT NSString *const PPFirestoreContextPaymentInstrumentListener;
FOUNDATION_EXPORT NSString *const PPFirestoreContextPaymentInstrumentFetch;
FOUNDATION_EXPORT NSString *const PPFirestoreContextPaymentInstrumentAdd;
FOUNDATION_EXPORT NSString *const PPFirestoreContextPaymentInstrumentSetDefault;
FOUNDATION_EXPORT NSString *const PPFirestoreContextPaymentInstrumentDefaultBatch;
FOUNDATION_EXPORT NSString *const PPFirestoreContextPaymentInstrumentDelete;
FOUNDATION_EXPORT NSString *const PPFirestoreContextAccessoryFetch;
FOUNDATION_EXPORT NSString *const PPFirestoreContextAccessorySimilar;
FOUNDATION_EXPORT NSString *const PPFirestoreContextAccessoryKindFetch;
FOUNDATION_EXPORT NSString *const PPFirestoreContextAccessorySearch;
FOUNDATION_EXPORT NSString *const PPFirestoreContextAccessoryOffers;

@interface PPFirestoreErrorNotifier : NSObject

/// Post an error notification from any thread. Dispatch to main is handled internally.
/// @param error   The Firestore NSError (must not be nil).
/// @param context A short string identifying the operation (use constants above).
+ (void)postError:(NSError *)error context:(NSString *)context;

/// Call once from AppDelegate to register the global observer that shows the banner.
+ (void)registerGlobalObserver;

/// Remove the global observer (optional — called on app termination).
+ (void)unregisterGlobalObserver;

@end

NS_ASSUME_NONNULL_END
