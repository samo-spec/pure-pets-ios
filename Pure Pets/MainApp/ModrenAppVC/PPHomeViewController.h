#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>

#import "EnumValues.h"

NS_ASSUME_NONNULL_BEGIN

@protocol PPUniversalCellDelegate;
@class MainKindsModel;
@class PetAccessory;
@class PPDataViewVC;
@class PPHomePromoCarouselCard;
@class PPOrder;
@class PPPetProfile;
@class PPUniversalCellViewModel;

/// Objective-C runtime compatibility shell for the SwiftUI Pure Pets Pulse Home.
///
/// Existing callers, reflection, deep links, and universal-card delegate
/// selectors rely on this exact class identity. Visible layout and Home state
/// are owned exclusively by `PPHomeHostingController` / `HomeStore`.
@interface PPHomeViewController : UIViewController <PPUniversalCellDelegate>

/// Existing public deep-link factory contract.
- (PPDataViewVC *)buildDataViewVCForTarget:(PPDeepLinkTarget)target
                                  mainKind:(nullable MainKindsModel *)mainKind
                                    source:(PPInputSource)source;

/// Retained for Objective-C source/binary compatibility. SwiftUI resolves its
/// own adaptive category rail while preserving the caller-provided value.
@property (nonatomic, assign) PPMainKindsLayoutMode mainKindsLayoutMode;

/// Optional category to select when Home is created by a deep-link caller.
@property (nonatomic, assign) NSInteger initialSelectedMainKindID;

#pragma mark - Swift Home route forwarding

- (void)pp_homeOpenSearch;
- (void)pp_homeOpenCart;
- (void)pp_homeOpenObject:(id)object
    NS_SWIFT_NAME(pp_homeOpenObject(_:));
- (void)pp_homeOpenMainKind:(NSObject *)mainKind
    NS_SWIFT_NAME(pp_homeOpenMainKind(_:));
- (void)pp_homeOpenDeepLinkTarget:(PPDeepLinkTarget)target
                         mainKind:(nullable NSObject *)mainKind
                           source:(PPInputSource)source
    NS_SWIFT_NAME(pp_homeOpenDeepLinkTarget(_:mainKind:source:));
- (void)pp_homeOpenPetProfiles;
- (void)pp_homeOpenPetEditor:(nullable NSObject *)pet
    NS_SWIFT_NAME(pp_homeOpenPetEditor(_:));
- (void)pp_homeOpenOrder:(NSObject *)order
    NS_SWIFT_NAME(pp_homeOpenOrder(_:));
- (void)pp_homeOpenOrderHistory;
- (void)pp_homeOpenCareSection:(NSInteger)section
                      mainKind:(nullable NSObject *)mainKind
    NS_SWIFT_NAME(pp_homeOpenCareSection(_:mainKind:));
- (void)pp_homeOpenAdoption;
- (void)pp_homeOpenProviderCategoryIdentifier:(NSString *)identifier
                                     titleKey:(nullable NSString *)titleKey
                                  subtitleKey:(nullable NSString *)subtitleKey
    NS_SWIFT_NAME(pp_homeOpenProviderCategoryIdentifier(_:titleKey:subtitleKey:));
- (void)pp_homeOpenPromoCard:(NSObject *)card
                  interaction:(NSString *)interaction
    NS_SWIFT_NAME(pp_homeOpenPromoCard(_:interaction:));
- (void)pp_homePresentLocationOptions;
- (void)pp_homeOpenLocationPicker;
- (void)pp_homeOpenLocationSettings;
- (void)pp_homeOpenNova;
- (void)pp_homeRefresh;
- (CGFloat)pp_homeBottomContentClearance;

/// Called by root tab reselection. Scrolls to the top and refreshes through the
/// Swift store's duplicate-request guard.
- (void)pp_homeHandleReselection;

@end

NS_ASSUME_NONNULL_END
