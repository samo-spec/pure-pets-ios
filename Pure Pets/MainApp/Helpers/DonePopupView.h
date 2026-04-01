//
//  DonePopupView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 10/07/2025.
//


#import <UIKit/UIKit.h>

@interface DonePopupView : UIView

@property (nonatomic, strong) LOTAnimationView *checkAnimationView;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIButton *doneButton;
@property (nonatomic, assign) BOOL showAsBottomSheet;
- (instancetype)initWithMessage:(NSString *)message;
- (void)showInView:(UIView *)parentView;
- (instancetype)initWithMessage:(NSString *)message showAsBottomSheet:(BOOL)bottomSheet onView:(UIView *)view;
@end
