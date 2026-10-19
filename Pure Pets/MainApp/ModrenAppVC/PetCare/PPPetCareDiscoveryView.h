#import <UIKit/UIKit.h>
#import "PPPetCareViewController.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPPetCareDiscoveryState) {
    PPPetCareDiscoveryStateResults,
    PPPetCareDiscoveryStateLoading,
    PPPetCareDiscoveryStateEmpty,
    PPPetCareDiscoveryStateNoMatches,
    PPPetCareDiscoveryStateError,
    PPPetCareDiscoveryStateRetainedError
};

@class LOTAnimationView;

/// Presentation only. The existing controller owns queries, filters and navigation.
@interface PPPetCareDiscoveryView : UIView
@property (nonatomic, strong, readonly) UITextField *searchField;
@property (nonatomic, strong, readonly) UIButton *medicineButton;
@property (nonatomic, strong, readonly) UIButton *vetsButton;
@property (nonatomic, strong, readonly) UIButton *clinicsButton;
@property (nonatomic, strong, readonly) UIButton *kindButton;
@property (nonatomic, strong, readonly) UIButton *filterButton;
@property (nonatomic, strong, readonly) UIButton *primaryButton;
@property (nonatomic, strong, readonly) UIButton *alternateButton;
@property (nonatomic, strong, readonly) UIButton *refreshButton;
@property (nonatomic, strong, readonly) UIImageView *careMark;
@property (nonatomic, strong, readonly, nullable) LOTAnimationView *careLottieView;
@property (nonatomic, strong, readonly) UIView *careContainer;
- (void)resumeCareAnimationIfNeeded;
- (void)configureForSection:(PPPetCareInitialSection)section
                  kindName:(nullable NSString *)kindName
                filterName:(nullable NSString *)filterName
                     count:(NSUInteger)count
                     state:(PPPetCareDiscoveryState)state
                   loading:(BOOL)loading
                  animated:(BOOL)animated;
/// Compatibility entry point for the original two-section discovery surface.
- (void)configureForVeterinarians:(BOOL)veterinarians
                        kindName:(nullable NSString *)kindName
                      filterName:(nullable NSString *)filterName
                           count:(NSUInteger)count
                           state:(PPPetCareDiscoveryState)state
                         loading:(BOOL)loading
                        animated:(BOOL)animated;
- (CGFloat)fittingHeightForWidth:(CGFloat)width;
@end

NS_ASSUME_NONNULL_END
