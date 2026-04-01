//
//  PPRecordingLockPillView 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 27/01/2026.
//


#import "PPRecordingLockPillView.h"

@interface PPRecordingLockPillView ()
@property (nonatomic, strong) UIButton *containerView;
@property (nonatomic, strong) UIImageView *arrowView;
@property (nonatomic, strong) UIImageView *lockView;
@property (nonatomic, strong) NSLayoutConstraint *widthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heightConstraint;
@property (nonatomic, strong) UIStackView *stackView;
@end

@implementation PPRecordingLockPillView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setup];
        [self setState:PPRecordingLockPillStateHidden animated:NO];
    }
    return self;
}

- (void)setup {
    self.translatesAutoresizingMaskIntoConstraints = NO;
     self.clipsToBounds = NO;

    
    self.containerView = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleCapsule configType:PPButtonConfigrationGlass];

     self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.containerView];

    [NSLayoutConstraint activateConstraints:@[
        [self.containerView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.containerView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.containerView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.containerView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
    ]];

    UIImageSymbolConfiguration *cfg =
        [UIImageSymbolConfiguration configurationWithPointSize:18
                                                        weight:UIImageSymbolWeightSemibold];

    self.lockView = [[UIImageView alloc]
        initWithImage:[UIImage systemImageNamed:@"lock.fill"
                               withConfiguration:cfg]];
    self.lockView.tintColor = UIColor.secondaryLabelColor;
    self.lockView.translatesAutoresizingMaskIntoConstraints = NO;

    self.arrowView = [[UIImageView alloc]
        initWithImage:[UIImage systemImageNamed:@"chevron.up"
                               withConfiguration:cfg]];
    self.arrowView.tintColor = UIColor.secondaryLabelColor;
    self.arrowView.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *stack = [[UIStackView alloc]
        initWithArrangedSubviews:@[ self.lockView, self.arrowView ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 20;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.distribution = UIStackViewDistributionFill;
    [self.containerView addSubview:stack];
    self.stackView = stack;

    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:self.containerView.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:self.containerView.centerYAnchor],
    ]];

    self.widthConstraint  = [self.widthAnchor constraintEqualToConstant:48];
    self.heightConstraint = [self.heightAnchor constraintEqualToConstant:102];

    [self.widthConstraint setActive:YES];
    [self.heightConstraint setActive:YES];
    
 }

#pragma mark - State

- (void)setState:(PPRecordingLockPillState)state animated:(BOOL)animated {
    _state = state;

    switch (state) {

        case PPRecordingLockPillStateHidden:
            self.alpha = 0;
            [self.arrowView.layer removeAllAnimations];
            break;

        case PPRecordingLockPillStateIdle:
            self.heightConstraint.constant = 92;
            self.containerView.layer.cornerRadius = 46;
            self.alpha = 1;
            self.lockView.tintColor = UIColor.secondaryLabelColor;
            self.arrowView.hidden = NO;
            self.stackView.spacing = 10;
            [self startArrowAnimation];
            break;

        case PPRecordingLockPillStateLocked: {

            [self.arrowView.layer removeAllAnimations];
            self.arrowView.alpha = 0;

            self.arrowView.hidden = YES;
            self.stackView.spacing = 0;

            self.lockView.tintColor = UIColor.systemGreenColor;

            void (^changes)(void) = ^{
                // Morph pill into circle
                self.heightConstraint.constant = 48;
                self.containerView.layer.cornerRadius = 24;

                // Ensure lock is perfectly centered
                [self layoutIfNeeded];
            };

            if (animated) {
                [UIView animateWithDuration:0.22
                                      delay:0
                     usingSpringWithDamping:0.85
                      initialSpringVelocity:0.4
                                    options:UIViewAnimationOptionCurveEaseOut
                                 animations:changes
                                 completion:^(BOOL finished) {
                    self.lockView.transform =
                        CGAffineTransformMakeScale(1.12, 1.12);
                    [UIView animateWithDuration:0.12 animations:^{
                        self.lockView.transform = CGAffineTransformIdentity;
                    }];
                }];

                if (@available(iOS 10.0, *)) {
                    UIImpactFeedbackGenerator *h =
                        [[UIImpactFeedbackGenerator alloc]
                         initWithStyle:UIImpactFeedbackStyleMedium];
                    [h impactOccurred];
                }
            } else {
                changes();
            }
            break;
        }
    }
}

#pragma mark - Arrow Animation

- (void)startArrowAnimation {
    self.arrowView.alpha = 1;

    CABasicAnimation *floatAnim =
        [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    floatAnim.fromValue = @6;
    floatAnim.toValue   = @-6;
    floatAnim.duration  = 0.9;
    floatAnim.autoreverses = YES;
    floatAnim.repeatCount = HUGE_VALF;
    floatAnim.timingFunction =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

    [self.arrowView.layer addAnimation:floatAnim forKey:@"float"];
}

@end
