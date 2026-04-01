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
- (void)attachToScrollView:(UIScrollView *)scrollView;;
/// Default address text (optional)
@property (nonatomic, copy, nullable) NSString *addressText;

/// Called when user taps expanded picker
@property (nonatomic, copy, nullable) void (^onPickAddress)(void);

/// Collapse programmatically
- (void)collapse;

/// Expand programmatically
- (void)expand;
- (void)expandAndLock;;
@end

NS_ASSUME_NONNULL_END
