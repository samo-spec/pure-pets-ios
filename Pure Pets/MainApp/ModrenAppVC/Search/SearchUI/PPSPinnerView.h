//
//  PPSPinnerView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 06/01/2026.
//


//
//  PPSPinnerView.h
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPSPinnerState) {
    PPSPinnerStateLoading,
    PPSPinnerStateSuccess,
    PPSPinnerStateError,
    PPSPinnerStateWarning
};

@interface PPSPinnerView : UIView
+ (instancetype)spinnerInView:(UIView *)view;

@property (nonatomic, readonly) PPSPinnerState state;

/// Text
@property (nonatomic, copy, nullable) NSString *titleText;
@property (nonatomic, copy, nullable) NSString *subtitleText;

/// Factory
+ (instancetype)spinner;

/// Control
- (void)showLoadingWithTitle:(nullable NSString *)title
                    subtitle:(nullable NSString *)subtitle;

- (void)showSuccessWithTitle:(nullable NSString *)title
                    subtitle:(nullable NSString *)subtitle
                 autoDismiss:(BOOL)autoDismiss;

- (void)showErrorWithTitle:(nullable NSString *)title
                  subtitle:(nullable NSString *)subtitle
               autoDismiss:(BOOL)autoDismiss;

- (void)showWarningWithTitle:(nullable NSString *)title
                    subtitle:(nullable NSString *)subtitle
                 autoDismiss:(BOOL)autoDismiss;

- (void)dismissAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END




