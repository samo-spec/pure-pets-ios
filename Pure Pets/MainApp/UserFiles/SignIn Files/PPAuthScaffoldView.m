//
//  PPAuthScaffoldView.m
//  Pure Pets
//

#import "PPAuthScaffoldView.h"
#import "Language.h"

@interface PPAuthScaffoldView ()
@property (nonatomic, strong, readwrite) UIView *topAccentView;
@property (nonatomic, strong, readwrite) UIView *bottomAccentView;
@property (nonatomic, assign) BOOL didStartAmbientMotion;
@end

@implementation PPAuthScaffoldView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.075 green:0.070 blue:0.078 alpha:1.0];
            }
            return PPBackgroundColorForIOS26([AppForgroundColr colorWithAlphaComponent:0.94] ?: UIColor.systemBackgroundColor);
        }];
        self.userInteractionEnabled = NO;

        _topAccentView = [[UIView alloc] initWithFrame:CGRectZero];
        _topAccentView.alpha = 0.34;
        _topAccentView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.16];
        [_topAccentView pp_setShadowColor:[AppPrimaryClr colorWithAlphaComponent:0.50]];
        _topAccentView.layer.shadowOpacity = 0.22;
        _topAccentView.layer.shadowRadius = 58.0;
        _topAccentView.layer.shadowOffset = CGSizeZero;
        [self addSubview:_topAccentView];

        _bottomAccentView = [[UIView alloc] initWithFrame:CGRectZero];
        _bottomAccentView.alpha = 0.28;
        _bottomAccentView.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.09];
        [_bottomAccentView pp_setShadowColor:[[UIColor systemBlueColor] colorWithAlphaComponent:0.28]];
        _bottomAccentView.layer.shadowOpacity = 0.18;
        _bottomAccentView.layer.shadowRadius = 64.0;
        _bottomAccentView.layer.shadowOffset = CGSizeZero;
        [self addSubview:_bottomAccentView];
    }
    return self;
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window) {
        [self pp_startAmbientMotionIfNeeded];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    CGFloat topSize = MIN(340.0, MAX(220.0, width * 0.72));
    CGFloat bottomSize = MIN(310.0, MAX(190.0, width * 0.62));
    self.topAccentView.frame = CGRectMake(width - topSize * 0.48, -topSize * 0.28, topSize, topSize);
    self.bottomAccentView.frame = CGRectMake(-bottomSize * 0.50, MAX(height * 0.58, 320.0), bottomSize, bottomSize);
    self.topAccentView.layer.cornerRadius = topSize * 0.5;
    self.bottomAccentView.layer.cornerRadius = bottomSize * 0.5;
}

- (void)pp_startAmbientMotionIfNeeded {
    if (self.didStartAmbientMotion ||
        UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    self.didStartAmbientMotion = YES;

    [self pp_floatAccent:self.topAccentView
             translation:CGPointMake(-18.0, 22.0)
                   scale:1.06
             targetAlpha:0.44
                duration:8.4];
    [self pp_floatAccent:self.bottomAccentView
             translation:CGPointMake(22.0, -16.0)
                   scale:1.08
             targetAlpha:0.36
                duration:9.8];
}

- (void)pp_floatAccent:(UIView *)view
           translation:(CGPoint)translation
                 scale:(CGFloat)scale
           targetAlpha:(CGFloat)targetAlpha
              duration:(NSTimeInterval)duration {
    if (!view) return;
    [UIView animateWithDuration:duration
                          delay:0.0
                        options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        view.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(translation.x, translation.y),
                                                 CGAffineTransformMakeScale(scale, scale));
        view.alpha = targetAlpha;
    } completion:nil];
}

+ (NSArray<NSString *> *)defaultStepTitles {
    return @[
        kLang(@"auth_step_mobile_number"),
        kLang(@"auth_step_verification_code"),
        kLang(@"auth_step_complete_profile")
    ];
}

+ (UIStackView *)headerStackWithTitle:(NSString *)title
                              subtitle:(NSString *)subtitle
                               eyebrow:(NSString *)eyebrow {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8.0;
    stack.alignment = UIStackViewAlignmentFill;
    stack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    if (eyebrow.length > 0) {
        UILabel *eyebrowLabel = [[UILabel alloc] init];
        eyebrowLabel.text = eyebrow;
        eyebrowLabel.font = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
        eyebrowLabel.textColor = [AppPrimaryClr colorWithAlphaComponent:0.92];
        eyebrowLabel.textAlignment = [Language alignmentForCurrentLanguage];
        [stack addArrangedSubview:eyebrowLabel];
    }

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title ?: @"";
    titleLabel.font = [GM boldFontWithSize:28.0] ?: [UIFont systemFontOfSize:28.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    titleLabel.numberOfLines = 0;
    [stack addArrangedSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.text = subtitle ?: @"";
    subtitleLabel.font = [GM MidFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    subtitleLabel.textColor = UIColor.secondaryLabelColor;
    subtitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    subtitleLabel.numberOfLines = 0;
    [stack addArrangedSubview:subtitleLabel];

    return stack;
}

+ (void)applyPremiumCardStyleToView:(UIView *)view {
    view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:0.15 alpha:0.94];
        }
        return [UIColor colorWithWhite:1.0 alpha:0.96];
    }];
    view.layer.cornerRadius = 26.0;
    view.layer.masksToBounds = NO;
    view.layer.borderWidth = 1.0;
    [view pp_setBorderColor:[UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.08]
            : [UIColor colorWithWhite:0.0 alpha:0.05];
    }]];
    [view pp_setShadowColor:UIColor.blackColor];
    view.layer.shadowOpacity = 0.07;
    view.layer.shadowRadius = 22.0;
    view.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    if (@available(iOS 13.0, *)) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
}

+ (void)applyPrimaryButtonStyleToButton:(UIButton *)button enabled:(BOOL)enabled loading:(BOOL)loading {
    button.layer.cornerRadius = 22.0;
    button.layer.masksToBounds = NO;
    button.clipsToBounds = NO;
    button.enabled = enabled && !loading;
    button.alpha = 1.0;
    UIColor *backgroundColor = enabled && !loading
        ? (AppPrimaryClr ?: UIColor.systemPinkColor)
        : [(AppPrimaryClr ?: UIColor.systemPinkColor) colorWithAlphaComponent:0.18];
    UIColor *titleColor = enabled && !loading
        ? UIColor.whiteColor
        : [(AppPrimaryClr ?: UIColor.systemPinkColor) colorWithAlphaComponent:0.72];
    button.backgroundColor = backgroundColor;
    [button setTitleColor:titleColor forState:UIControlStateNormal];
    [button setTitleColor:titleColor forState:UIControlStateDisabled];
    button.titleLabel.font = [GM boldFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    [button pp_setShadowColor:UIColor.blackColor];
    button.layer.shadowOpacity = enabled && !loading ? 0.12 : 0.0;
    button.layer.shadowRadius = enabled && !loading ? 16.0 : 0.0;
    button.layer.shadowOffset = CGSizeMake(0.0, enabled && !loading ? 8.0 : 0.0);
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = button.configuration ?: [UIButtonConfiguration filledButtonConfiguration];
        config.background.backgroundColor = backgroundColor;
        config.background.cornerRadius = 22.0;
        config.baseForegroundColor = titleColor;
        config.showsActivityIndicator = loading;
        config.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;
        NSString *title = config.title ?: button.currentTitle ?: @"";
        if (title.length > 0) {
            config.attributedTitle = [[NSAttributedString alloc] initWithString:title
                                                                     attributes:@{
                NSFontAttributeName: [GM boldFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold],
                NSForegroundColorAttributeName: titleColor
            }];
        }
        button.configuration = config;
    }
}

+ (void)applySecondaryButtonStyleToButton:(UIButton *)button {
    button.backgroundColor = UIColor.clearColor;
    button.layer.cornerRadius = 18.0;
    button.titleLabel.font = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    [button setTitleColor:AppPrimaryClr ?: UIColor.systemPinkColor forState:UIControlStateNormal];
    button.contentEdgeInsets = UIEdgeInsetsMake(8.0, 12.0, 8.0, 12.0);
}

+ (void)applyInputStyleToView:(UIView *)view {
    view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:1.0 alpha:0.07];
        }
        return [UIColor colorWithWhite:0.97 alpha:1.0];
    }];
    view.layer.cornerRadius = 20.0;
    view.layer.masksToBounds = YES;
    view.layer.borderWidth = 1.0;
    [view pp_setBorderColor:[UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.08]
            : [UIColor colorWithWhite:0.0 alpha:0.06];
    }]];
}

+ (void)addPressMotionToControl:(UIControl *)control {
    [control addTarget:self action:@selector(pp_authPressDown:) forControlEvents:UIControlEventTouchDown];
    [control addTarget:self action:@selector(pp_authPressUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
}

+ (void)pp_authPressDown:(UIControl *)control {
    [UIView animateWithDuration:0.12 delay:0.0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        control.transform = CGAffineTransformMakeScale(0.985, 0.985);
    } completion:nil];
}

+ (void)pp_authPressUp:(UIControl *)control {
    [UIView animateWithDuration:0.24 delay:0.0 usingSpringWithDamping:0.88 initialSpringVelocity:0.12 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        control.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end
