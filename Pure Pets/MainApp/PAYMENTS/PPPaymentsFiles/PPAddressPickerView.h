//
//  PPAddressPickerView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 03/02/2026.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPAddressPickerView : UIView

/// Show picker floating on top of any controller
+ (instancetype)showInViewController:(UIViewController *)controller width:(float)width;

/// Use as a self-sizing checkout section. Does not install floating constraints.
- (void)configureForInlineCheckout;

/// Attach pan gesture to dismiss/collapse on scroll
- (void)attachToScrollView:(UIScrollView *)scrollView;

/// Default address text (optional)
@property (nonatomic, copy, nullable) NSString *addressText;

/// The top-anchor constraint created by showInViewController:
/// Re-assign or deactivate to reposition the picker vertically.
@property (nonatomic, strong, nullable) NSLayoutConstraint *topConstraint;

/// Called when user taps expanded picker
@property (nonatomic, copy, nullable) void (^onPickAddress)(void);

/// Allows a containing self-sizing header to refresh after content or type changes.
@property (nonatomic, copy, nullable) void (^onLayoutHeightChange)(void);

/// Collapse programmatically
- (void)collapse;

/// Expand programmatically
- (void)expand;

/// Expand and lock expanded state (collapse disabled)
- (void)expandAndLock;

@end

NS_ASSUME_NONNULL_END
