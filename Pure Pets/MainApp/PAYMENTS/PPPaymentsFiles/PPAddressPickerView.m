//
//  PPAddressPickerView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 03/02/2026
//
 
#import "PPAddressPickerView.h"

typedef NS_ENUM(NSUInteger, PPAddressPickerState) {
    PPAddressPickerStateCollapsed,
    PPAddressPickerStateExpanded
};

@interface PPAddressPickerView ()

@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *addressLabel;
@property (nonatomic, strong) UIImageView *arrowView;
@property (nonatomic, strong) UILabel *hintLabel;

@property (nonatomic, strong) UIVisualEffectView *motionBlurView;

@property (nonatomic) PPAddressPickerState state;

@property (nonatomic, strong) NSLayoutConstraint *widthConstraintCircle;
@property (nonatomic, strong) NSLayoutConstraint *widthConstraintFull;
@property (nonatomic, strong) NSLayoutConstraint *trailingConstraint;
@property (nonatomic, assign) BOOL isCollapseDisabled;

@end

@implementation PPAddressPickerView

#pragma mark - Public

+ (instancetype)showInViewController:(UIViewController *)controller width:(float)width {
    PPAddressPickerView *view = [[PPAddressPickerView alloc] init];
    [controller.view addSubview:view];
    
    view.translatesAutoresizingMaskIntoConstraints = NO;
    
    
    NSLayoutConstraint *height =
    [view.heightAnchor constraintEqualToConstant:56.0];
    
    NSLayoutConstraint *trailing =
    [view.trailingAnchor constraintEqualToAnchor:controller.view.trailingAnchor constant:-16.0];
    
    [NSLayoutConstraint activateConstraints:@[
        trailing,
        [view.topAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.topAnchor constant:12.0],
        height,
        
    ]];
    
    view.widthConstraintCircle = [view.widthAnchor constraintEqualToConstant:56.0];
    view.widthConstraintFull = [view.widthAnchor constraintEqualToConstant:width];
    view.trailingConstraint = trailing;
    view.trailingConstraint.active = YES;
    view.widthConstraintCircle.active = YES;
    view.widthConstraintFull.active = NO;
    
    return view;
}

#pragma mark - Init

- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    self.isCollapseDisabled = NO;
    self.state = PPAddressPickerStateCollapsed;
    self.clipsToBounds = NO;
    
    [self buildUI];
    [self setupGesture];
    
    return self;
}

#pragma mark - UI

- (void)buildUI {
    UIBlurEffectStyle style = UIBlurEffectStyleSystemUltraThinMaterial;
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:style];
    
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.blurView.layer.cornerRadius = 28;
    self.blurView.layer.cornerCurve = kCACornerCurveContinuous;
    self.blurView.clipsToBounds = YES;
    
    // Soft glass-like shadow on the container layer
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.12;
    self.layer.shadowRadius = 16.0;
    self.layer.shadowOffset = CGSizeMake(0, 6);
    self.layer.masksToBounds = NO;
    
    [self addSubview:self.blurView];
    self.blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.blurView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.blurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.blurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.blurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor]
    ]];
    
    UIBlurEffect *motionBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    self.motionBlurView = [[UIVisualEffectView alloc] initWithEffect:motionBlur];
    self.motionBlurView.alpha = 0.0;
    self.motionBlurView.userInteractionEnabled = NO;
    [self addSubview:self.motionBlurView];
    self.motionBlurView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.motionBlurView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.motionBlurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.motionBlurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.motionBlurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor]
    ]];
    
    self.iconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"fast-delivery"]];
    self.iconView.contentMode = UIViewContentModeScaleToFill;
    self.iconView.tintColor = AppSecondaryTextClr;
    self.hintLabel = [[UILabel alloc] init];
    self.hintLabel.text = kLang(@"DeliverTo");
    self.hintLabel.font = [GM MidFontWithSize:13];
    self.hintLabel.textColor = UIColor.secondaryLabelColor;
    self.hintLabel.alpha = 1.0; // visible when collapsed
    
    self.addressLabel = [[UILabel alloc] init];
    self.addressLabel.font =[GM MidFontWithSize:15];
    self.addressLabel.textColor = UIColor.labelColor;
    self.addressLabel.alpha = 1.0;
    [self.addressLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.addressLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    
    self.arrowView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down"]];
    self.arrowView.tintColor = UIColor.secondaryLabelColor;
    self.arrowView.alpha = 1.0;
    
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.iconView,
        self.hintLabel,
        self.addressLabel,
        self.arrowView
    ]];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 8;
    stack.distribution = UIStackViewDistributionFill;
    [self.blurView.contentView addSubview:stack];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [stack.centerYAnchor constraintEqualToAnchor:self.blurView.contentView.centerYAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:self.blurView.contentView.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:self.blurView.contentView.trailingAnchor constant:-16]
    ]];
    
    [self.iconView.widthAnchor constraintEqualToConstant:28].active = YES;
    [self.iconView.heightAnchor constraintEqualToConstant:28].active = YES;
    
    [self.addressLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.addressLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    
    [self.hintLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.arrowView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    
    self.hintLabel.hidden = NO;
    self.addressLabel.hidden = NO;
    self.arrowView.hidden = NO;
}

#pragma mark - Gesture

- (void)setupGesture {
    UITapGestureRecognizer *tap =
    [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
    [self addGestureRecognizer:tap];
}

- (void)handleTap {
    if (self.state == PPAddressPickerStateCollapsed) {
        [self expand];
        return;
    }
    
    // Expanded state
    if (self.onPickAddress) {
        self.onPickAddress();
    }
    
    // Auto-collapse after tap
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self collapse];
    });
}

#pragma mark - State

- (void)setAddressText:(NSString *)addressText {
    _addressText = addressText;
    self.addressLabel.text = addressText ?: @"Select address";
}



- (void)expand {
    if (self.state == PPAddressPickerStateExpanded) return;
    self.state = PPAddressPickerStateExpanded;

    UIView *container = self.superview;
    if (!container) return;

    CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width;
    CGFloat expandedWidth = screenWidth - 32.0; // 16pt margins on each side

    self.widthConstraintCircle.active = NO;
    self.widthConstraintFull.constant = expandedWidth;
    self.widthConstraintFull.active = YES;
    
    self.blurView.layer.cornerRadius = 18.0;
    self.layer.shadowRadius = 20.0;
    self.layer.shadowOpacity = 0.16;
    [Styling addLiquidGlassBorderToView:self cornerRadius:18];
    self.hintLabel.hidden = NO;
    self.addressLabel.hidden = NO;
    self.arrowView.hidden = NO;

    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [haptic impactOccurred];

    self.motionBlurView.alpha = 0.0;
    [UIView animateWithDuration:0.35
                          delay:0
         usingSpringWithDamping:0.85
          initialSpringVelocity:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        [container layoutIfNeeded];
        self.motionBlurView.alpha = 1.0;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.2 animations:^{
            self.motionBlurView.alpha = 0.0;
        }];
    }];
}


- (void)expandAndLock {
    self.isCollapseDisabled = YES;
    [self expand];
}



- (void)collapse {
    
 
    if ( self.isCollapseDisabled == YES) return;
    
    if (self.state == PPAddressPickerStateCollapsed) return;
    self.state = PPAddressPickerStateCollapsed;

    self.hintLabel.hidden = YES;
    self.addressLabel.hidden = YES;
    self.arrowView.hidden = YES;

    self.widthConstraintCircle.active =  YES;
    self.widthConstraintFull.active =NO;
    self.blurView.layer.cornerRadius = 28.0;
    self.layer.shadowRadius = 14.0;
    self.layer.shadowOpacity = 0.12;
    [Styling addLiquidGlassBorderToView:self cornerRadius:28];
    [UIView animateWithDuration:0.25 animations:^{
        [self.superview layoutIfNeeded];
    }];
}

- (void)attachToScrollView:(UIScrollView *)scrollView {
    [scrollView.panGestureRecognizer addTarget:self action:@selector(handleScroll:)];
}

- (void)handleScroll:(UIPanGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan && self.state == PPAddressPickerStateExpanded) {
        [self collapse];
    }
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];

    // L-03: Pre-compute shadow path so Core Animation avoids expensive
    // per-frame offscreen rendering on the glass container shadow.
    if (!CGRectIsEmpty(self.bounds)) {
        self.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                      cornerRadius:self.blurView.layer.cornerRadius].CGPath;
    }
}

@end
