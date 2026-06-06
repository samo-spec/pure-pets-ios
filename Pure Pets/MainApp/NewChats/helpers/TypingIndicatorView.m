//
//  TypingIndicatorView 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 21/01/2026.
//


#import "TypingIndicatorView.h"
@interface TypingIndicatorView ()
@property (nonatomic, strong) UIButton *glassButton;
@property (nonatomic, strong) UIStackView *dotsStack;
@property (nonatomic, strong) NSMutableArray<UIView *> *dots;
@property (nonatomic, assign) BOOL isAnimating;
@end

@implementation TypingIndicatorView

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (self = [super initWithCoder:coder]) {
        [self commonInit];
    }
    return self;
}

#pragma mark - Setup

- (void)commonInit
{
    self.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Configure button appearance with availability checks
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration glassButtonConfiguration];
        self.configuration = config;
    } else if (@available(iOS 15.0, *)) {
        // Fallback to a plain configuration on iOS 15-25
        UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
        self.configuration = config;
    } else {
        // Legacy fallback for iOS versions prior to UIButtonConfiguration
        self.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.5];
        self.layer.cornerRadius = 8.0;
        self.clipsToBounds = YES;
        [self setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
    }
    
     
    self.hidden = YES;
    self.alpha = 0.0;

    self.dotsCount = 3;
    self.animationStyle = PTTypingAnimationStylePulse;

    // === iOS 26 Glass Button Container ===
    UIButtonConfiguration *cfg;
    if (@available(iOS 26.0, *)) {
        cfg = [UIButtonConfiguration glassButtonConfiguration];
    } else {
        cfg = [UIButtonConfiguration filledButtonConfiguration];
    }
    cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
  

    self.glassButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.glassButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.glassButton.configuration = cfg;
    self.glassButton.userInteractionEnabled = NO; // display-only
    [self.glassButton pp_setShadowColor:UIColor.blackColor];
    self.glassButton.layer.shadowOpacity = 0.12;
    self.glassButton.layer.shadowRadius = 14;
    self.glassButton.layer.shadowOffset = CGSizeMake(0, 8);

    [self addSubview:self.glassButton];

    // === Dots Stack ===
    self.dotsStack = [[UIStackView alloc] init];
    self.dotsStack.axis = UILayoutConstraintAxisHorizontal;
    self.dotsStack.spacing = 8;
    self.dotsStack.alignment = UIStackViewAlignmentCenter;
    self.dotsStack.translatesAutoresizingMaskIntoConstraints = NO;

    [self.glassButton addSubview:self.dotsStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.glassButton.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.glassButton.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.glassButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.glassButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],

        [self.dotsStack.centerXAnchor constraintEqualToAnchor:self.glassButton.centerXAnchor],
        [self.dotsStack.centerYAnchor constraintEqualToAnchor:self.glassButton.centerYAnchor],

        [self.heightAnchor constraintEqualToConstant:36],
        [self.widthAnchor constraintGreaterThanOrEqualToConstant:70],
    ]];

    [self rebuildDots];
}

#pragma mark - Dots

- (void)rebuildDots
{
    self.dots = [NSMutableArray array];
    [self.dotsStack.arrangedSubviews makeObjectsPerformSelector:@selector(removeFromSuperview)];

    for (NSInteger i = 0; i < self.dotsCount; i++) {
        UIView *dot = [[UIView alloc] init];
        dot.translatesAutoresizingMaskIntoConstraints = NO;
        dot.backgroundColor = UIColor.labelColor;
        dot.alpha = 0.35;
        dot.layer.cornerRadius = 3.5;

        [NSLayoutConstraint activateConstraints:@[
            [dot.widthAnchor constraintEqualToConstant:7],
            [dot.heightAnchor constraintEqualToConstant:7],
        ]];

        [self.dotsStack addArrangedSubview:dot];
        [self.dots addObject:dot];
    }
}

#pragma mark - Animation Control

- (void)startAnimating
{
    if (self.isAnimating) return;
    self.isAnimating = YES;

    self.hidden = NO;
    [UIView animateWithDuration:0.25 animations:^{
        self.alpha = 1.0;
    }];

    for (NSInteger i = 0; i < self.dots.count; i++) {
        [self animateDot:self.dots[i] delay:i * 0.15];
    }
}

- (void)stopAnimating
{
    self.isAnimating = NO;

    [UIView animateWithDuration:0.2 animations:^{
        self.alpha = 0.0;
    } completion:^(BOOL finished) {
        self.hidden = YES;
    }];

    for (UIView *dot in self.dots) {
        [dot.layer removeAllAnimations];
        dot.alpha = 0.35;
        dot.transform = CGAffineTransformIdentity;
    }
}

- (void)animateDot:(UIView *)dot delay:(CGFloat)delay
{
    if (!self.isAnimating) return;

    UIViewAnimationOptions opts =
        UIViewAnimationOptionAutoreverse |
        UIViewAnimationOptionRepeat |
        UIViewAnimationOptionAllowUserInteraction;

    switch (self.animationStyle) {

        case PTTypingAnimationStyleFade:
        {
            [UIView animateWithDuration:0.6 delay:delay options:opts animations:^{
                dot.alpha = 1.0;
            } completion:nil];
            break;
        }
           
        case PTTypingAnimationStyleSlide:
        {
            [UIView animateWithDuration:0.6 delay:delay options:opts animations:^{
                dot.transform = CGAffineTransformMakeTranslation(0, -4);
                dot.alpha = 1.0;
            } completion:nil];
            break;
        }
        
        case PTTypingAnimationStylePulse:
        default:
        {
            [UIView animateWithDuration:0.6 delay:delay options:opts animations:^{
                dot.transform = CGAffineTransformMakeScale(1.4, 1.4);
                dot.alpha = 1.0;
            } completion:nil];
            break;
        }
           
    }
}
- (CGSize)intrinsicContentSize {
    return CGSizeMake(UIViewNoIntrinsicMetric, 28);
}
@end
