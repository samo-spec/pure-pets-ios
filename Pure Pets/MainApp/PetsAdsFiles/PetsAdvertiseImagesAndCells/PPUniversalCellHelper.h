#import <UIKit/UIKit.h>
#import "EnumValues.h"

NS_ASSUME_NONNULL_BEGIN

@class PPUniversalCellViewModel;

typedef NS_ENUM(NSInteger, PPUniversalAvailabilityTone) {
    PPUniversalAvailabilityToneNeutral = 0,
    PPUniversalAvailabilityToneAvailable,
    PPUniversalAvailabilityToneLimited,
    PPUniversalAvailabilityToneUnavailable,
    PPUniversalAvailabilityToneUsed
};

@interface PPCornerBlurView : UIView

@property (nonatomic, copy, nullable) void (^layoutSubviewsBlock)(void);
@property (nonatomic, strong, nullable) UIVisualEffectView *blurView;

- (void)applyBlurStyle:(UIBlurEffectStyle)style
             tintColor:(nullable UIColor *)tintColor;

@end

/// Keeps legacy app services and model-specific presentation rules out of SwiftUI.
/// The SwiftUI cell remains a renderer while this bridge preserves the existing
/// authentication, cart, favorite, and stock-notification contracts.
@interface PPUniversalCellSwiftUIBridge : NSObject

+ (NSString *)localizedStringForKey:(NSString *)key fallback:(NSString *)fallback;
+ (BOOL)isRightToLeft;
+ (BOOL)isUserLoggedIn;
+ (void)showLoginPrompt;

+ (BOOL)isAccessoryViewModel:(PPUniversalCellViewModel *)viewModel;
+ (BOOL)isAdvertisementViewModel:(PPUniversalCellViewModel *)viewModel;
+ (BOOL)isServiceLike:(PPUniversalCellViewModel *)viewModel;
+ (BOOL)isUsedAccessoryViewModel:(PPUniversalCellViewModel *)viewModel;
+ (BOOL)usesQuantityControlForViewModel:(PPUniversalCellViewModel *)viewModel;
+ (BOOL)prefersContainedImageForViewModel:(PPUniversalCellViewModel *)viewModel;
+ (BOOL)showsDiscountPresentationForViewModel:(PPUniversalCellViewModel *)viewModel;

+ (NSInteger)stockLimitForViewModel:(PPUniversalCellViewModel *)viewModel;
+ (NSInteger)cartQuantityForViewModel:(PPUniversalCellViewModel *)viewModel;
+ (NSString *)favoritesCollectionForContext:(PPCellContext)context;

+ (nullable NSString *)displaySubtitleForViewModel:(PPUniversalCellViewModel *)viewModel
                                           context:(PPCellContext)context
                                  horizontalLayout:(BOOL)horizontalLayout
                                  dataViewPresenter:(BOOL)dataViewPresenter
                                     showsSubtitle:(BOOL)showsSubtitle;
+ (nullable NSString *)availabilityTextForViewModel:(PPUniversalCellViewModel *)viewModel
                                            context:(PPCellContext)context
                                   horizontalLayout:(BOOL)horizontalLayout
                                   dataViewPresenter:(BOOL)dataViewPresenter;
+ (PPUniversalAvailabilityTone)availabilityToneForViewModel:(PPUniversalCellViewModel *)viewModel
                                                     context:(PPCellContext)context;
+ (nullable NSString *)metadataTextForViewModel:(PPUniversalCellViewModel *)viewModel;
+ (nullable NSString *)metadataSystemImageForViewModel:(PPUniversalCellViewModel *)viewModel;
+ (nullable NSString *)advertisementGenderValueForViewModel:(PPUniversalCellViewModel *)viewModel;

+ (BOOL)isSuggestionsSectionForViewModel:(PPUniversalCellViewModel *)viewModel
                                delegate:(nullable id)delegate;

+ (void)registerStockNotificationForViewModel:(PPUniversalCellViewModel *)viewModel
                                    completion:(void (^)(BOOL succeeded))completion;

@end

NS_ASSUME_NONNULL_END
