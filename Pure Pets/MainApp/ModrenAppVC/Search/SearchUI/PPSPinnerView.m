//
//  PPSPinnerView.m
//

#import "PPSPinnerView.h"

@interface PPSPinnerView ()

@property (nonatomic) PPSPinnerState state;

@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *containerView;

@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIImageView *stateIcon;

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;

@end

@implementation PPSPinnerView


+ (instancetype)spinnerInView:(UIView *)view {
    PPSPinnerView *spinner = [[self alloc] initWithFrame:view.bounds];
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:spinner];

    [NSLayoutConstraint activateConstraints:@[
        [spinner.topAnchor constraintEqualToAnchor:view.topAnchor],
        [spinner.bottomAnchor constraintEqualToAnchor:view.bottomAnchor],
        [spinner.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [spinner.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
    ]];

    return spinner;
}



#pragma mark - Init

+ (instancetype)spinner {
    return [[self alloc] initWithFrame:CGRectZero];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    [self buildUI];
    return self;
}

#pragma mark - UI

- (void)buildUI {

    self.backgroundColor = UIColor.clearColor;

    // Blur (2026 style)
    UIBlurEffectStyle style =
    self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
    ? UIBlurEffectStyleSystemChromeMaterialDark
    : UIBlurEffectStyleSystemChromeMaterialLight;

    self.blurView =
    [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:style]];
    self.blurView.translatesAutoresizingMaskIntoConstraints = NO;
    self.blurView.layer.cornerRadius = PPCornerHero;
    self.blurView.clipsToBounds = YES;
    self.blurView.layer.borderWidth = 0.5;
    [self.blurView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.08]];

    self.containerView = self.blurView.contentView;

    // Spinner
    self.spinner =
    [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.spinner.hidesWhenStopped = YES;

    // State icon
    self.stateIcon = [UIImageView new];
    self.stateIcon.translatesAutoresizingMaskIntoConstraints = NO;
    self.stateIcon.contentMode = UIViewContentModeScaleAspectFit;
    self.stateIcon.hidden = YES;

    // Title — use GM custom font for brand consistency
    self.titleLabel = [UILabel new];
    self.titleLabel.font = [GM boldFontWithSize:PPFontHeadline];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    // Subtitle
    self.subtitleLabel = [UILabel new];
    self.subtitleLabel.font = [GM MidFontWithSize:PPFontSubheadline];
    self.subtitleLabel.textColor = UIColor.secondaryLabelColor;
    self.subtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.subtitleLabel.numberOfLines = 3;
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    [self addSubview:self.blurView];
    [self.containerView addSubview:self.spinner];
    [self.containerView addSubview:self.stateIcon];
    [self.containerView addSubview:self.titleLabel];
    [self.containerView addSubview:self.subtitleLabel];

    [self setupConstraints];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        [self.blurView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.blurView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.blurView.widthAnchor constraintGreaterThanOrEqualToConstant:220],
        [self.blurView.heightAnchor constraintGreaterThanOrEqualToConstant:160], // ✅ REQUIRED
    ]];

    
    
    
    [NSLayoutConstraint activateConstraints:@[
    
        [self.spinner.topAnchor constraintEqualToAnchor:self.containerView.topAnchor constant:PPSpaceXL],
        [self.spinner.centerXAnchor constraintEqualToAnchor:self.containerView.centerXAnchor],

        [self.stateIcon.centerXAnchor constraintEqualToAnchor:self.spinner.centerXAnchor],
        [self.stateIcon.centerYAnchor constraintEqualToAnchor:self.spinner.centerYAnchor],
        [self.stateIcon.widthAnchor constraintEqualToConstant:44.0],
        [self.stateIcon.heightAnchor constraintEqualToConstant:44.0],

        [self.titleLabel.topAnchor constraintEqualToAnchor:self.spinner.bottomAnchor constant:PPSpaceBase],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor constant:PPSpaceLG],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor constant:-PPSpaceLG],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:PPSpaceSM],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],
        [self.subtitleLabel.bottomAnchor constraintEqualToAnchor:self.containerView.bottomAnchor constant:-PPSpaceXL]
    ]];
}

#pragma mark - States

- (void)showLoadingWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
    self.state = PPSPinnerStateLoading;
    self.titleLabel.text = title;
    self.subtitleLabel.text = subtitle;

    self.stateIcon.hidden = YES;
    [self.spinner startAnimating];

    [self animateIn];
}

- (void)showSuccessWithTitle:(NSString *)title subtitle:(NSString *)subtitle autoDismiss:(BOOL)autoDismiss {
    [self showState:PPSPinnerStateSuccess
              title:title
           subtitle:subtitle
               icon:@"checkmark.circle.fill"
         tintColor:UIColor.systemGreenColor
        autoDismiss:autoDismiss];
}

- (void)showErrorWithTitle:(NSString *)title subtitle:(NSString *)subtitle autoDismiss:(BOOL)autoDismiss {
    [self showState:PPSPinnerStateError
              title:title
           subtitle:subtitle
               icon:@"xmark.octagon.fill"
         tintColor:UIColor.systemRedColor
        autoDismiss:autoDismiss];
}

- (void)showWarningWithTitle:(NSString *)title subtitle:(NSString *)subtitle autoDismiss:(BOOL)autoDismiss {
    [self showState:PPSPinnerStateWarning
              title:title
           subtitle:subtitle
               icon:@"exclamationmark.triangle.fill"
         tintColor:UIColor.systemOrangeColor
        autoDismiss:autoDismiss];
}

- (void)showState:(PPSPinnerState)state
            title:(NSString *)title
         subtitle:(NSString *)subtitle
             icon:(NSString *)symbol
       tintColor:(UIColor *)tint
      autoDismiss:(BOOL)autoDismiss {

    self.state = state;
    self.titleLabel.text = title;
    self.subtitleLabel.text = subtitle;

    [self.spinner stopAnimating];

    UIImageSymbolConfiguration *cfg =
    [UIImageSymbolConfiguration configurationWithPointSize:38 weight:UIImageSymbolWeightSemibold];

    self.stateIcon.image =
    [[UIImage systemImageNamed:symbol withConfiguration:cfg]
     imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    self.stateIcon.tintColor = tint;
    self.stateIcon.hidden = NO;

    [self animateIn];

    if (autoDismiss) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.4 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self dismissAnimated:YES];
        });
    }
}

#pragma mark - Animations

- (void)animateIn {
    self.alpha = 0;
    self.blurView.transform = CGAffineTransformMakeScale(0.92, 0.92);
    [UIView animateWithDuration:0.35
                          delay:0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.5
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.alpha = 1;
        self.blurView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)dismissAnimated:(BOOL)animated {
    void (^block)(void) = ^{
        self.alpha = 0;
        self.blurView.transform = CGAffineTransformMakeScale(0.92, 0.92);
    };

    void (^finish)(BOOL) = ^(BOOL finished) {
        [self removeFromSuperview];
    };

    animated
    ? [UIView animateWithDuration:0.25
                            delay:0
           usingSpringWithDamping:0.9
            initialSpringVelocity:0.0
                          options:UIViewAnimationOptionCurveEaseIn
                       animations:block
                       completion:finish]
    : finish(YES);
}

#pragma mark - Trait

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self buildUI];
}

@end
