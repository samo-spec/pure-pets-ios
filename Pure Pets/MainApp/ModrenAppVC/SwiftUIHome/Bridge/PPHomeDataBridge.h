#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "EnumValues.h"

NS_ASSUME_NONNULL_BEGIN

@class PetAccessory;
@class PetAd;
@class PPUniversalCellViewModel;
@class ServiceModel;

typedef NS_ENUM(NSInteger, PPHomeBridgeSource) {
    PPHomeBridgeSourceMainKinds = 0,
    PPHomeBridgeSourcePromotions,
    PPHomeBridgeSourceAccessories,
    PPHomeBridgeSourceFood,
    PPHomeBridgeSourceAdvertisements,
    PPHomeBridgeSourceNearbyAdvertisements,
    PPHomeBridgeSourceServices,
    PPHomeBridgeSourcePetProfiles,
    PPHomeBridgeSourcePetReminders,
    PPHomeBridgeSourceOrders,
    PPHomeBridgeSourceHomeConfig,
    PPHomeBridgeSourceLocation,
};

typedef NS_ENUM(NSInteger, PPHomeBridgeLocationState) {
    PPHomeBridgeLocationStateNotDetermined = 0,
    PPHomeBridgeLocationStateLoading,
    PPHomeBridgeLocationStateReady,
    PPHomeBridgeLocationStateDenied,
    PPHomeBridgeLocationStateRestricted,
    PPHomeBridgeLocationStateFailed,
};

/// Narrow adapter between the production Objective-C services and Swift Home.
///
/// This object owns only service/listener adaptation. It has no visible UI and
/// does not derive presentation hierarchy. `HomeStore` remains the single
/// authoritative state owner.
@interface PPHomeDataBridge : NSObject <CLLocationManagerDelegate>

@property (nonatomic, copy, nullable) void (^mainKindsDidChange)(NSArray<NSObject *> *mainKinds);
@property (nonatomic, copy, nullable) void (^promotionsDidChange)(NSArray<NSObject *> *promotions);
@property (nonatomic, copy, nullable) void (^accessoriesDidChange)(NSArray<PetAccessory *> *accessories);
@property (nonatomic, copy, nullable) void (^foodDidChange)(NSArray<PetAccessory *> *food);
@property (nonatomic, copy, nullable) void (^advertisementsDidChange)(NSArray<PetAd *> *advertisements);
@property (nonatomic, copy, nullable) void (^nearbyAdvertisementsDidChange)(NSArray<PetAd *> *advertisements,
                                                                              BOOL showingRecentFallback);
@property (nonatomic, copy, nullable) void (^servicesDidChange)(NSArray<ServiceModel *> *services);
@property (nonatomic, copy, nullable) void (^petProfilesDidChange)(NSArray<NSObject *> *profiles);
@property (nonatomic, copy, nullable) void (^petRemindersDidChange)(NSArray<NSObject *> *reminders);
@property (nonatomic, copy, nullable) void (^ordersDidChange)(NSArray<NSObject *> *recentOrders);
@property (nonatomic, copy, nullable) void (^homeConfigDidChange)(NSArray<NSDictionary *> *sections,
                                                                    NSString *titleViewMode,
                                                                    BOOL premiumCareVisible,
                                                                    BOOL novaFloatingVisible,
                                                                    BOOL backgroundGlowsFaded,
                                                                    BOOL fromCache);
@property (nonatomic, copy, nullable) void (^locationDidChange)(PPHomeBridgeLocationState state,
                                                                  NSString *areaName,
                                                                  CLLocationCoordinate2D coordinate,
                                                                  BOOL hasCoordinate,
                                                                  BOOL manualSelection);
@property (nonatomic, copy, nullable) void (^sourceDidFail)(PPHomeBridgeSource source,
                                                              NSError *error);

@property (nonatomic, assign, readonly) PPHomeBridgeLocationState locationState;
@property (nonatomic, copy, readonly) NSString *selectedAreaName;
@property (nonatomic, assign, readonly) CLLocationCoordinate2D selectedCoordinate;
@property (nonatomic, assign, readonly) BOOL hasSelectedCoordinate;
@property (nonatomic, assign, readonly) BOOL usesManualLocation;

/// Starts exactly one listener set. Repeated calls are ignored.
- (void)start;

/// Performs deduplicated one-shot refreshes and restarts the order listener
/// only when the authenticated UID changed.
- (void)refresh;

/// Removes all listener registrations, notification observers, and location
/// work owned by this bridge.
- (void)stop;

/// Applies a genuine user-confirmed map coordinate and refreshes nearby data.
- (void)setManualLocationLatitude:(CLLocationDegrees)latitude
                        longitude:(CLLocationDegrees)longitude
                             title:(NSString *)title;

/// Returns to system location after a prior manual selection.
- (void)useAutomaticLocation;

/// Requests location authorization only from an explicit user action.
- (void)requestLocationAuthorization;

/// Existing model-to-universal-card mapping kept as a narrow compatibility
/// seam. The Swift `HomeModelAdapter` decides context and section ownership.
+ (PPUniversalCellViewModel *)viewModelForObject:(id)object
                                         context:(PPCellContext)context
    NS_SWIFT_NAME(viewModel(object:context:));

/// Resolves genuine historical order item IDs through the existing inventory
/// manager. This is used by the Swift store for Buy Again.
- (void)fetchAccessoriesWithIDs:(NSArray<NSString *> *)itemIDs
                     completion:(void (^)(NSArray<PetAccessory *> *accessories))completion
    NS_SWIFT_NAME(fetchAccessories(ids:completion:));

/// Shared order normalization helpers keep legacy and current order documents
/// aligned while Swift owns the resulting presentation state.
+ (nullable NSObject *)activeOrderFromOrders:(NSArray<NSObject *> *)orders
    NS_SWIFT_NAME(activeOrder(from:));
+ (NSArray<NSString *> *)buyAgainAccessoryIDsFromOrders:(NSArray<NSObject *> *)orders
                                                   limit:(NSInteger)limit
    NS_SWIFT_NAME(buyAgainAccessoryIDs(from:limit:));
+ (NSDictionary<NSString *, id> *)presentationForOrder:(NSObject *)order
    NS_SWIFT_NAME(orderPresentation(for:));

/// Presentation-only projections for Firebase-backed Objective-C models.
/// Keeping those concrete model headers out of the project-wide bridging
/// header avoids transitive Firebase module imports in every Swift compile.
+ (NSDictionary<NSString *, id> *)categoryPresentationForObject:(NSObject *)object
    NS_SWIFT_NAME(categoryPresentation(for:));
+ (NSDictionary<NSString *, id> *)petPresentationForObject:(NSObject *)object
    NS_SWIFT_NAME(petPresentation(for:));
+ (NSDictionary<NSString *, id> *)promotionPresentationForObject:(NSObject *)object
    NS_SWIFT_NAME(promotionPresentation(for:));
+ (NSDictionary<NSString *, id> *)reminderPresentationForObject:(NSObject *)object
    NS_SWIFT_NAME(reminderPresentation(for:));
+ (NSInteger)currentCartItemCount NS_SWIFT_NAME(currentCartItemCount());

@end

/// Home-scoped host for bundled or Firebase-backed hero Lottie assets.
///
/// The view owns loading and playback lifecycle so SwiftUI never needs to
/// import the legacy Lottie Objective-C API directly.
@interface PPHomeHeroAnimationView : UIView

- (instancetype)initWithAnimationName:(NSString *)animationName
                    loadsFromFirebase:(BOOL)loadsFromFirebase;

@property (nonatomic, assign, getter=isPlaybackEnabled) BOOL playbackEnabled;

@end

NS_ASSUME_NONNULL_END
