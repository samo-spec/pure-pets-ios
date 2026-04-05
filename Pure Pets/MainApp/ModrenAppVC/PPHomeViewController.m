

#import "MainBannerModel.h"
#import "PetAdoptCollectionViewCell.h"
#import "PPBannerCollectionCell.h"
#import "PPBannersCollection.h"
#import "PPBannersManager.h"
#import "PPBannerViewModel.h"
#import "PPCategoryCardCell.h"
#import "PPHomeFunc.h"
#import "PPHomeViewController.h"
#import "PPSPinnerView.h"
#import "PPSearchViewController.h"
#import "PPDataViewInput.h"
#import "PPDataViewVC.h"
#import "PPVetLocator.h"
#import "PPBrowseHistoryManager.h"
#import "PPImageLoaderManager.h"
#import "SearchCacheManager.h"
#import "PPHomeLayoutManager.h"
#import "AdoptPetsViewController.h"
#import "PPAdSharingHelper.h"
#import "AppClasses.h"
#import "CartManager.h"
#import "CountryModel.h"
#import "OrderDetailsViewController.h"
#import "OrderHistoryViewController.h"
#import "PPOrder.h"
#import "PPRolePermission.h"
#import "PPHomeHeroCell.h"
#import "PPHomeModels.h"
#import "PPHUD.h"
#import "PPCommerceFeedbackManager.h"
#import "LocationPickerViewController.h"
#import <AudioToolbox/AudioToolbox.h>
#import <CoreLocation/CoreLocation.h>
#import <FirebaseAuth/FirebaseAuth.h>
#import <FirebaseFirestore/FirebaseFirestore.h>
#import <SafariServices/SafariServices.h>
#import <TargetConditionals.h>
#import <math.h>
#import <float.h>
#import "PPHomeOrderStatusCell.h"



@implementation PPHomeProfileView (TapFeedback)

- (void)pp_highlightDown
{
    [UIView animateWithDuration:0.12 animations:^{
        self.transform = CGAffineTransformMakeScale(0.96, 0.96);
        self.alpha = 0.85;
    }];
}

- (void)pp_highlightUp
{
    [UIView animateWithDuration:0.18
                          delay:0
         usingSpringWithDamping:0.7
          initialSpringVelocity:0.4
                        options:0
                     animations:^{
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1.0;
    } completion:nil];
}

@end


@class PPCarouselItem;

@interface PPHomeHeaderConfig : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *actionTitle;
@property (nonatomic, copy) NSString *iconName;
@property (nonatomic, strong, nullable) UIMenu *menu;
@property (nonatomic, assign) BOOL hidden;
@property (nonatomic, assign) PPHomeSection section;
@end

@implementation PPHomeHeaderConfig
@end

@interface PPHomeSmartSearchTitleView : UIControl
@property (nonatomic, strong, readonly) UILabel *placeholderLabel;
@property (nonatomic, assign) BOOL showSmartPillBackground;
- (void)setQueryText:(NSString *)text animated:(BOOL)animated;
@end

@implementation PPHomeSmartSearchTitleView {
    UIView *_chromeView;
    UIVisualEffectView *_blurView;
    UIView *_leadingOrbView;
    UIImageView *_searchIconView;
    UIStackView *_textStackView;
    UIStackView *_signalRowView;
    UIView *_signalDotView;
    UILabel *_signalLabel;
    UILabel *_placeholderLabel;
    UIView *_trailingOrbView;
    UIImageView *_chevronView;
    UIView *_activityDotView;
    CAGradientLayer *_gradientLayer;
    CAGradientLayer *_ambientGlowLayer;
    CAGradientLayer *_liquidBorderLayer;
    CAShapeLayer *_liquidBorderMaskLayer;
    CAGradientLayer *_topHighlightLayer;
    CAGradientLayer *_bottomTintLayer;
    CAGradientLayer *_shineLayer;
    BOOL _ambientAnimationsConfigured;
}

@synthesize placeholderLabel = _placeholderLabel;

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(UIViewNoIntrinsicMetric, 44.0);
}

- (instancetype)initWithFrame:(CGRect)frame
{
    CGRect initialFrame = CGRectEqualToRect(frame, CGRectZero)
        ? CGRectMake(0.0, 0.0, 240.0, 46.0)
        : frame;
    self = [super initWithFrame:initialFrame];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.accessibilityTraits = UIAccessibilityTraitButton;
    self.accessibilityLabel =
        kLang(@"home_nav_search_accessibility") ?:
        (kLang(@"home_search_hint") ?: @"Open smart search");
    self.clipsToBounds = NO;
    _showSmartPillBackground = NO;

    self.layer.shadowColor = [UIColor colorWithWhite:0.02 alpha:1.0].CGColor;
    self.layer.shadowOpacity = 0.08f;
    self.layer.shadowRadius = 16.0f;
    self.layer.shadowOffset = CGSizeMake(0.0, 6.0);

    UIButton *chromeView = PPIOS26() ? [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleCapsule configType:PPButtonConfigrationGlass] : (UIButton *)[[UIView alloc] initWithFrame:self.bounds];
    chromeView.translatesAutoresizingMaskIntoConstraints = NO;
    chromeView.backgroundColor = UIColor.clearColor;
    chromeView.userInteractionEnabled = NO;
    chromeView.layer.cornerRadius = 23.0;
    chromeView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        chromeView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *config = chromeView.configuration;
        config.background.backgroundColor = [AppBackgroundClrLigter colorWithAlphaComponent:0.16];
        config.baseBackgroundColor = [AppBackgroundClrLigter colorWithAlphaComponent:0.16];
        chromeView.configuration = config;
    }


    [self addSubview:chromeView];
    _chromeView = chromeView;
    [chromeView.heightAnchor constraintEqualToConstant:46.0].active = YES;

    UIVisualEffectView *blurView =
        [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.userInteractionEnabled = NO;
    [chromeView addSubview:blurView];
    blurView.alpha = 0;
    _blurView = blurView;

    _gradientLayer = [CAGradientLayer layer];
    _gradientLayer.startPoint = CGPointMake(0.0, 0.0);
    _gradientLayer.endPoint = CGPointMake(1.0, 1.0);
    //_gradientLayer.opacity = 0;
    [chromeView.layer insertSublayer:_gradientLayer above:blurView.layer];

    _ambientGlowLayer = [CAGradientLayer layer];
    _ambientGlowLayer.startPoint = CGPointMake(0.0, 0.5);
    _ambientGlowLayer.endPoint = CGPointMake(1.0, 0.5);
    _ambientGlowLayer.opacity = 0.24f;
    [chromeView.layer addSublayer:_ambientGlowLayer];

    _topHighlightLayer = [CAGradientLayer layer];
    _topHighlightLayer.startPoint = CGPointMake(0.5, 0.0);
    _topHighlightLayer.endPoint = CGPointMake(0.5, 1.0);
    _topHighlightLayer.opacity = 0.92f;
    [chromeView.layer addSublayer:_topHighlightLayer];

    _bottomTintLayer = [CAGradientLayer layer];
    _bottomTintLayer.startPoint = CGPointMake(0.5, 0.0);
    _bottomTintLayer.endPoint = CGPointMake(0.5, 1.0);
    _bottomTintLayer.opacity = 0.0f;
    [chromeView.layer addSublayer:_bottomTintLayer];

    _liquidBorderLayer = [CAGradientLayer layer];
    _liquidBorderLayer.startPoint = CGPointMake(0.0, 0.3);
    _liquidBorderLayer.endPoint = CGPointMake(1.0, 0.7);
    _liquidBorderMaskLayer = [CAShapeLayer layer];
    _liquidBorderMaskLayer.fillColor = UIColor.clearColor.CGColor;
    _liquidBorderMaskLayer.lineWidth = 1.0f;
    _liquidBorderLayer.mask = _liquidBorderMaskLayer;
    [chromeView.layer addSublayer:_liquidBorderLayer];

    _shineLayer = [CAGradientLayer layer];
    _shineLayer.startPoint = CGPointMake(0.0, 0.5);
    _shineLayer.endPoint = CGPointMake(1.0, 0.5);
    _shineLayer.colors = @[
        (__bridge id)[UIColor.clearColor CGColor],
        (__bridge id)[[UIColor whiteColor] colorWithAlphaComponent:0.24].CGColor,
        (__bridge id)[UIColor.clearColor CGColor]
    ];
    _shineLayer.opacity = 1.0f;
    [chromeView.layer addSublayer:_shineLayer];

    chromeView.layer.borderWidth = 0.75f;
    chromeView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.10].CGColor;

    UIView *leadingOrbView = [UIView new];
    leadingOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    leadingOrbView.userInteractionEnabled = NO;
    leadingOrbView.layer.cornerRadius = 14.0;
    leadingOrbView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        leadingOrbView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [chromeView addSubview:leadingOrbView];
    _leadingOrbView = leadingOrbView;

    if(PPIOS26()) { _blurView.alpha = 0; }

    UIImageView *searchIconView =
        [[UIImageView alloc] initWithImage:[UIImage pp_symbolNamed:@"magnifyingglass"
                                                         pointSize:10
                                                            weight:UIImageSymbolWeightMedium
                                                             scale:UIImageSymbolScaleMedium
                                                           palette:@[AppPrimaryTextClr ?: UIColor.labelColor]
                                                      makeTemplate:YES]];
    searchIconView.translatesAutoresizingMaskIntoConstraints = NO;
    searchIconView.contentMode = UIViewContentModeScaleAspectFit;
    searchIconView.userInteractionEnabled = NO;
    [leadingOrbView addSubview:searchIconView];
    _searchIconView = searchIconView;

    UIStackView *textStackView = [[UIStackView alloc] init];
    textStackView.translatesAutoresizingMaskIntoConstraints = NO;
    textStackView.axis = UILayoutConstraintAxisVertical;
    textStackView.alignment = UIStackViewAlignmentFill;
    textStackView.distribution = UIStackViewDistributionFill;
    textStackView.spacing = 1.0;
    textStackView.userInteractionEnabled = NO;
    [chromeView addSubview:textStackView];
    _textStackView = textStackView;

    UIStackView *signalRowView = [[UIStackView alloc] init];
    signalRowView.translatesAutoresizingMaskIntoConstraints = NO;
    signalRowView.axis = UILayoutConstraintAxisHorizontal;
    signalRowView.alignment = UIStackViewAlignmentCenter;
    signalRowView.spacing = 4.0;
    signalRowView.userInteractionEnabled = NO;
    [textStackView addArrangedSubview:signalRowView];
    _signalRowView = signalRowView;

    UIView *signalDotView = [UIView new];
    signalDotView.translatesAutoresizingMaskIntoConstraints = NO;
    signalDotView.userInteractionEnabled = NO;
    signalDotView.layer.cornerRadius = 2.75;
    signalDotView.layer.masksToBounds = YES;
    [signalRowView addArrangedSubview:signalDotView];
    _signalDotView = signalDotView;

    UILabel *signalLabel = [UILabel new];
    signalLabel.translatesAutoresizingMaskIntoConstraints = NO;
    signalLabel.font = [GM MidFontWithSize:9.0] ?: [UIFont systemFontOfSize:8.0 weight:UIFontWeightSemibold];
    signalLabel.textAlignment = NSTextAlignmentNatural;
    signalLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    signalLabel.adjustsFontSizeToFitWidth = YES;
    signalLabel.minimumScaleFactor = 0.84;
    signalLabel.numberOfLines = 1;
    signalLabel.userInteractionEnabled = NO;
    signalLabel.text = kLang(@"home_nav_search_trending") ?: @"Trending";
    [signalRowView addArrangedSubview:signalLabel];
    _signalLabel = signalLabel;

    UILabel *placeholderLabel = [UILabel new];
    placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    placeholderLabel.font = [GM boldFontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold];
    placeholderLabel.textAlignment = NSTextAlignmentNatural;
    placeholderLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    placeholderLabel.adjustsFontSizeToFitWidth = YES;
    placeholderLabel.allowsDefaultTighteningForTruncation = YES;
    placeholderLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    placeholderLabel.minimumScaleFactor = 0.82;
    placeholderLabel.numberOfLines = 1;
    placeholderLabel.userInteractionEnabled = NO;
    placeholderLabel.text = kLang(@"home_search_placeholder_short") ?: @"Search in Pure Pets";
    [textStackView addArrangedSubview:placeholderLabel];
    _placeholderLabel = placeholderLabel;

    UIView *trailingOrbView = [UIView new];
    trailingOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    trailingOrbView.userInteractionEnabled = NO;
    trailingOrbView.layer.cornerRadius = 12.0;
    trailingOrbView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        trailingOrbView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [chromeView addSubview:trailingOrbView];
    _trailingOrbView = trailingOrbView;

    BOOL isRTL =
        [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:self.semanticContentAttribute] ==
        UIUserInterfaceLayoutDirectionRightToLeft;
    NSString *chevronSymbolName = isRTL ? @"chevron.forward" : @"chevron.backward";
    UIImageView *chevronView =
        [[UIImageView alloc] initWithImage:[UIImage pp_symbolNamed:chevronSymbolName
                                                         pointSize:11
                                                            weight:UIImageSymbolWeightBold
                                                             scale:UIImageSymbolScaleMedium
                                                           palette:@[AppPrimaryTextClr ?: UIColor.labelColor]
                                                      makeTemplate:YES]];
    chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    chevronView.contentMode = UIViewContentModeScaleAspectFit;
    chevronView.userInteractionEnabled = NO;
    //chevronView.
    chevronView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.0];
    [trailingOrbView addSubview:chevronView];
    _chevronView = chevronView;

    UIView *activityDotView = [UIView new];
    activityDotView.translatesAutoresizingMaskIntoConstraints = NO;
    activityDotView.userInteractionEnabled = NO;
    activityDotView.layer.cornerRadius = 3.0;
    activityDotView.layer.masksToBounds = YES;
    [chromeView addSubview:activityDotView];
    _activityDotView = activityDotView;

    [NSLayoutConstraint activateConstraints:@[
        [chromeView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [chromeView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [chromeView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [chromeView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [blurView.topAnchor constraintEqualToAnchor:chromeView.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:chromeView.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:chromeView.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:chromeView.bottomAnchor],

        [leadingOrbView.leadingAnchor constraintEqualToAnchor:chromeView.leadingAnchor constant:8.0],
        [leadingOrbView.centerYAnchor constraintEqualToAnchor:chromeView.centerYAnchor],
        [leadingOrbView.widthAnchor constraintEqualToConstant:22.0],
        [leadingOrbView.heightAnchor constraintEqualToConstant:22.0],

        [searchIconView.centerXAnchor constraintEqualToAnchor:leadingOrbView.centerXAnchor],
        [searchIconView.centerYAnchor constraintEqualToAnchor:leadingOrbView.centerYAnchor],
        [searchIconView.widthAnchor constraintEqualToConstant:18.0],
        [searchIconView.heightAnchor constraintEqualToConstant:18.0],

        [signalDotView.widthAnchor constraintEqualToConstant:5.5],
        [signalDotView.heightAnchor constraintEqualToConstant:5.5],

        [textStackView.leadingAnchor constraintEqualToAnchor:leadingOrbView.trailingAnchor constant:8.0],
        [textStackView.centerYAnchor constraintEqualToAnchor:chromeView.centerYAnchor],
        [textStackView.topAnchor constraintGreaterThanOrEqualToAnchor:chromeView.topAnchor constant:7.0],
        [textStackView.bottomAnchor constraintLessThanOrEqualToAnchor:chromeView.bottomAnchor constant:-7.0],
        [textStackView.trailingAnchor constraintEqualToAnchor:trailingOrbView.leadingAnchor constant:-8.0],

        [trailingOrbView.trailingAnchor constraintEqualToAnchor:chromeView.trailingAnchor constant:-8.0],
        [trailingOrbView.centerYAnchor constraintEqualToAnchor:chromeView.centerYAnchor],
        [trailingOrbView.widthAnchor constraintEqualToConstant:22.0],
        [trailingOrbView.heightAnchor constraintEqualToConstant:22.0],

        [chevronView.centerXAnchor constraintEqualToAnchor:trailingOrbView.centerXAnchor],
        [chevronView.centerYAnchor constraintEqualToAnchor:trailingOrbView.centerYAnchor],
        [chevronView.widthAnchor constraintEqualToConstant:16.0],
        [chevronView.heightAnchor constraintEqualToConstant:16.0],

        [activityDotView.widthAnchor constraintEqualToConstant:5.0],
        [activityDotView.heightAnchor constraintEqualToConstant:5.0],
        [activityDotView.centerYAnchor constraintEqualToAnchor:chromeView.centerYAnchor],
        [activityDotView.trailingAnchor constraintEqualToAnchor:chromeView.trailingAnchor constant:-11.0]
    ]];

    [_placeholderLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                       forAxis:UILayoutConstraintAxisHorizontal];
    [_signalLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                  forAxis:UILayoutConstraintAxisHorizontal];
    [_trailingOrbView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                      forAxis:UILayoutConstraintAxisHorizontal];

    [self pp_applyPalette];
    [self pp_updateInteractiveStateAnimated:NO];

    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if (!self.userInteractionEnabled || self.hidden || self.alpha < 0.01) {
        return nil;
    }

    CGRect hitFrame = CGRectInset(self.bounds, -6.0, -6.0);
    if (CGRectContainsPoint(hitFrame, point)) {
        return self;
    }

    return nil;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds);
    BOOL showsSignalRow = width >= 242.0;
    _signalRowView.hidden = !showsSignalRow;
    _activityDotView.hidden = showsSignalRow;
    _textStackView.spacing = showsSignalRow ? 0.5 : 0.0;
    _chromeView.layer.cornerRadius = CGRectGetHeight(self.bounds) * 0.5;
    _leadingOrbView.layer.cornerRadius = CGRectGetHeight(_leadingOrbView.bounds) * 0.5;
    _trailingOrbView.layer.cornerRadius = CGRectGetHeight(_trailingOrbView.bounds) * 0.5;
    _signalDotView.layer.cornerRadius = CGRectGetHeight(_signalDotView.bounds) * 0.5;
    _activityDotView.layer.cornerRadius = CGRectGetHeight(_activityDotView.bounds) * 0.5;
    CGRect chromeBounds = _chromeView.bounds;
    _gradientLayer.frame = chromeBounds;
    _ambientGlowLayer.frame = CGRectInset(chromeBounds, -42.0, -12.0);
    _topHighlightLayer.frame = chromeBounds;
    _bottomTintLayer.frame = chromeBounds;
    _liquidBorderLayer.frame = chromeBounds;
    _liquidBorderMaskLayer.frame = chromeBounds;
    CGFloat rimInset = 0.58f;
    CGFloat rimRadius = MAX(0.0, CGRectGetHeight(chromeBounds) * 0.5 - rimInset);
    UIBezierPath *rimPath =
        [UIBezierPath bezierPathWithRoundedRect:CGRectInset(chromeBounds, rimInset, rimInset)
                                   cornerRadius:rimRadius];
    _liquidBorderMaskLayer.path = rimPath.CGPath;
    _shineLayer.frame = CGRectInset(chromeBounds, -48.0, 0.0);
    self.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                   cornerRadius:CGRectGetHeight(self.bounds) * 0.5].CGPath;
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];

    if (!self.window) {
        [_shineLayer removeAnimationForKey:@"pp.home.smartSearch.shine"];
        [_ambientGlowLayer removeAnimationForKey:@"pp.home.smartSearch.ambient"];
        [_liquidBorderLayer removeAnimationForKey:@"pp.home.smartSearch.borderPulse"];
        [_activityDotView.layer removeAnimationForKey:@"pp.home.smartSearch.activityPulse"];
        _ambientAnimationsConfigured = NO;
        return;
    }

    if (_ambientAnimationsConfigured || UIAccessibilityIsReduceMotionEnabled() || CGRectGetWidth(self.bounds) <= 0.0) {
        return;
    }

    _ambientAnimationsConfigured = YES;

    CABasicAnimation *shine = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    shine.fromValue = @(-92.0);
    shine.toValue = @(CGRectGetWidth(self.bounds) + 92.0);
    shine.duration = 5.2;
    shine.repeatCount = HUGE_VALF;
    shine.timingFunction =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [_shineLayer addAnimation:shine forKey:@"pp.home.smartSearch.shine"];

    CABasicAnimation *pulseScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulseScale.fromValue = @(0.96);
    pulseScale.toValue = @(1.10);
    pulseScale.timingFunction =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

    CABasicAnimation *pulseOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    pulseOpacity.fromValue = @(0.68);
    pulseOpacity.toValue = @(0.92);
    pulseOpacity.timingFunction =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

    CAAnimationGroup *activityPulse = [CAAnimationGroup animation];
    activityPulse.duration = 1.8;
    activityPulse.repeatCount = HUGE_VALF;
    activityPulse.autoreverses = YES;
    activityPulse.animations = @[pulseScale, pulseOpacity];
    [_activityDotView.layer addAnimation:activityPulse forKey:@"pp.home.smartSearch.activityPulse"];
}

- (void)setQueryText:(NSString *)text animated:(BOOL)animated
{
    NSString *safeText = PPSafeString(text);
    if (safeText.length == 0) {
        safeText = kLang(@"home_search_placeholder_short") ?: @"Search in Pure Pets";
    }
    if ([_placeholderLabel.text isEqualToString:safeText]) {
        return;
    }

    self.accessibilityValue = safeText;

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        _placeholderLabel.text = safeText;
        return;
    }

    [UIView animateWithDuration:0.14
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self->_placeholderLabel.transform = CGAffineTransformMakeTranslation(0.0, -1.5);
        self->_placeholderLabel.alpha = 0.0;
        self->_signalRowView.alpha = 0.82;
    } completion:^(__unused BOOL finished) {
        self->_placeholderLabel.text = safeText;
        self->_placeholderLabel.transform = CGAffineTransformMakeTranslation(0.0, 1.5);

        [UIView animateWithDuration:0.22
                              delay:0.0
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.28
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            self->_placeholderLabel.transform = CGAffineTransformIdentity;
            self->_placeholderLabel.alpha = 1.0;
            self->_signalRowView.alpha = 1.0;
        } completion:nil];
    }];

    [UIView animateWithDuration:0.18
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self->_trailingOrbView.transform = CGAffineTransformMakeScale(1.03, 1.03);
        self->_activityDotView.transform = CGAffineTransformMakeScale(1.08, 1.08);
    } completion:^(__unused BOOL finished) {
        [UIView animateWithDuration:0.24 delay:0.0 usingSpringWithDamping:0.82 initialSpringVelocity:0.25 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self->_trailingOrbView.transform = CGAffineTransformIdentity;
            self->_activityDotView.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
        }];
    }];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self pp_applyPalette];
    }
}

- (void)tintColorDidChange
{
    [super tintColorDidChange];
    [self pp_forceTextColors];
}

- (void)pp_forceTextColors
{
    UIColor *textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    _searchIconView.tintColor = textColor;
    _signalLabel.textColor = textColor;
    _placeholderLabel.textColor = textColor;
    _chevronView.tintColor = textColor;
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    [self pp_updateInteractiveStateAnimated:YES];
}

- (void)pp_applyPalette
{
    UIColor *textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    UIColor *accentColor = [UIColor colorNamed:@"NewBg"] ?: [UIColor colorWithRed:0.98 green:0.70 blue:0.42 alpha:1.0];
    UIColor *surfaceColor = AppForgroundColr ?: [UIColor systemBackgroundColor];
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *glassWhite = [UIColor whiteColor];

    if (@available(iOS 13.0, *)) {
        UIBlurEffectStyle blurStyle =
            isDark ? UIBlurEffectStyleSystemUltraThinMaterialDark
                   : UIBlurEffectStyleSystemUltraThinMaterialLight;
        _blurView.effect = [UIBlurEffect effectWithStyle:blurStyle];
    }

    _gradientLayer.colors = @[
        (__bridge id)[surfaceColor colorWithAlphaComponent:isDark ? 0.34 : 0.12].CGColor,
        (__bridge id)[glassWhite colorWithAlphaComponent:isDark ? 0.04 : 0.15].CGColor,
        (__bridge id)[accentColor colorWithAlphaComponent:isDark ? 0.08 : 0.06].CGColor,
        (__bridge id)[surfaceColor colorWithAlphaComponent:isDark ? 0.22 : 0.08].CGColor
    ];
    _gradientLayer.locations = @[@0.0, @0.24, @0.68, @1.0];
    _gradientLayer.opacity = 1.0f;
    _ambientGlowLayer.colors = @[
        (__bridge id)[UIColor.clearColor CGColor],
        (__bridge id)[glassWhite colorWithAlphaComponent:isDark ? 0.05 : 0.09].CGColor,
        (__bridge id)[accentColor colorWithAlphaComponent:isDark ? 0.08 : 0.07].CGColor,
        (__bridge id)[UIColor.clearColor CGColor]
    ];
    _ambientGlowLayer.locations = @[@0.0, @0.26, @0.62, @1.0];
    _topHighlightLayer.colors = @[
        (__bridge id)[glassWhite colorWithAlphaComponent:isDark ? 0.14 : 0.30].CGColor,
        (__bridge id)[glassWhite colorWithAlphaComponent:isDark ? 0.04 : 0.08].CGColor,
        (__bridge id)[UIColor.clearColor CGColor]
    ];
    _topHighlightLayer.locations = @[@0.0, @0.28, @0.75];
    _topHighlightLayer.opacity = 0.62f;
    _bottomTintLayer.colors = @[
        (__bridge id)[UIColor.clearColor CGColor],
        (__bridge id)[accentColor colorWithAlphaComponent:isDark ? 0.07 : 0.05].CGColor,
        (__bridge id)[[UIColor colorWithWhite:(isDark ? 0.0 : 1.0)
                                       alpha:(isDark ? 0.10 : 0.01)] CGColor]
    ];
    _bottomTintLayer.locations = @[@0.0, @0.64, @1.0];
    _bottomTintLayer.opacity = 0.36f;
    _liquidBorderLayer.colors = @[
        (__bridge id)[glassWhite colorWithAlphaComponent:isDark ? 0.34 : 0.52].CGColor,
        (__bridge id)[glassWhite colorWithAlphaComponent:isDark ? 0.10 : 0.16].CGColor,
        (__bridge id)[accentColor colorWithAlphaComponent:isDark ? 0.12 : 0.10].CGColor,
        (__bridge id)[glassWhite colorWithAlphaComponent:isDark ? 0.22 : 0.38].CGColor
    ];
    _liquidBorderLayer.locations = @[@0.0, @0.22, @0.64, @1.0];
    _chromeView.layer.borderColor =
        [[glassWhite colorWithAlphaComponent:isDark ? 0.08 : 0.16] CGColor];

    _leadingOrbView.backgroundColor =
        [glassWhite colorWithAlphaComponent:isDark ? 0.08 : 0.15];
    _leadingOrbView.layer.borderWidth = 0.8f;
    _leadingOrbView.layer.borderColor =
        [[glassWhite colorWithAlphaComponent:isDark ? 0.10 : 0.16] CGColor];
    _searchIconView.tintColor = [textColor colorWithAlphaComponent:isDark ? 0.99 : 0.97];

    _signalDotView.backgroundColor = AppPrimaryClrShiner;
    _signalLabel.textColor = [textColor colorWithAlphaComponent:isDark ? 0.72 : 0.68];
    _placeholderLabel.textColor = [textColor colorWithAlphaComponent:isDark ? 0.99 : 0.98];

    _trailingOrbView.backgroundColor =
        [glassWhite colorWithAlphaComponent:isDark ? 0.08 : 0.14];
    _trailingOrbView.layer.borderWidth = 0.8f;
    _trailingOrbView.layer.borderColor =
        [[glassWhite colorWithAlphaComponent:isDark ? 0.10 : 0.16] CGColor];
    _chevronView.tintColor = [textColor colorWithAlphaComponent:isDark ? 0.94 : 0.86];
    _activityDotView.backgroundColor = accentColor;
    _shineLayer.opacity = isDark ? 0.08f : 0.10f;

    if (!_showSmartPillBackground) {
        [self pp_applySmartPillBackgroundVisibility];
    }
}

- (void)pp_updateInteractiveStateAnimated:(BOOL)animated
{
    void (^changes)(void) = ^{
        BOOL isPressed = self.highlighted;
        BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        self->_chromeView.transform = isPressed ? CGAffineTransformMakeScale(0.992, 0.992) : CGAffineTransformIdentity;
        self->_leadingOrbView.transform = isPressed ? CGAffineTransformMakeScale(0.97, 0.97) : CGAffineTransformIdentity;
        self->_trailingOrbView.transform = isPressed ? CGAffineTransformMakeScale(0.97, 0.97) : CGAffineTransformIdentity;
        self.layer.shadowOpacity = isDark ? 0.12f : 0.08f;
            
        self.layer.shadowRadius = isPressed ? 18.0f : 16.0f;
        self->_chromeView.alpha = self.enabled ? (isPressed ? 0.98 : 1.0) : 0.72;
    };

    if (!animated) {
        changes();
        return;
    }

    [UIView animateWithDuration:self.highlighted ? 0.12 : 0.24
                          delay:0.0
         usingSpringWithDamping:self.highlighted ? 1.0 : 0.82
          initialSpringVelocity:0.22
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:changes
                     completion:nil];
}

- (void)setShowSmartPillBackground:(BOOL)showSmartPillBackground
{
    if (_showSmartPillBackground == showSmartPillBackground) return;
    _showSmartPillBackground = showSmartPillBackground;
    [self pp_applySmartPillBackgroundVisibility];
}

- (void)pp_applySmartPillBackgroundVisibility
{
    BOOL show = _showSmartPillBackground;
    show = YES;
    _blurView.hidden          = show;
    _gradientLayer.hidden     = !show;
    _ambientGlowLayer.hidden  = show;
    _topHighlightLayer.hidden = show;
    _bottomTintLayer.hidden   = !show;
    _liquidBorderLayer.hidden = !show;
    _shineLayer.hidden        = !show;
    _chromeView.layer.borderWidth = show ? 0.75f : 0.0f;
    self.layer.shadowOpacity      = show ? 0.08f : 0.0f;
}

@end

@interface PPHomeLocationActionCard : UIControl
- (void)configureWithTitle:(NSString *)title
                  subtitle:(nullable NSString *)subtitle
                  iconName:(nullable NSString *)iconName
                 tintColor:(UIColor *)tintColor
               showsChevron:(BOOL)showsChevron;
@end

@implementation PPHomeLocationActionCard {
    UIVisualEffectView *_blurView;
    UIView *_tintOverlayView;
    UIView *_iconChipView;
    UIImageView *_iconView;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    UIImageView *_chevronView;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = UIColor.clearColor;
    self.layer.cornerRadius = 22.0;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = 0.06f;
    self.layer.shadowRadius = 14.0f;
    self.layer.shadowOffset = CGSizeMake(0.0, 9.0);
    self.clipsToBounds = NO;

    _blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]];
    _blurView.translatesAutoresizingMaskIntoConstraints = NO;
    _blurView.userInteractionEnabled = NO;
    _blurView.layer.cornerRadius = 22.0;
    _blurView.layer.cornerCurve = kCACornerCurveContinuous;
    _blurView.clipsToBounds = YES;
    [self addSubview:_blurView];

    _tintOverlayView = [[UIView alloc] init];
    _tintOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
    _tintOverlayView.userInteractionEnabled = NO;
    _tintOverlayView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.62] ?: [UIColor secondarySystemBackgroundColor];
    _tintOverlayView.layer.cornerRadius = 22.0;
    _tintOverlayView.layer.cornerCurve = kCACornerCurveContinuous;
    _tintOverlayView.layer.borderWidth = 0.8;
    _tintOverlayView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.08].CGColor;
    [self addSubview:_tintOverlayView];

    _iconChipView = [[UIView alloc] init];
    _iconChipView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconChipView.userInteractionEnabled = NO;
    _iconChipView.layer.cornerRadius = 18.0;
    _iconChipView.layer.cornerCurve = kCACornerCurveContinuous;
    [self addSubview:_iconChipView];

    _iconView = [[UIImageView alloc] init];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    [_iconChipView addSubview:_iconView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM boldFontWithSize:16] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    _titleLabel.numberOfLines = 1;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = [GM MidFontWithSize:12] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    _subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _subtitleLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.64] ?: UIColor.secondaryLabelColor;
    _subtitleLabel.numberOfLines = 2;
    _subtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [self addSubview:_subtitleLabel];

    UIImage *chevronImage =
        [UIImage pp_symbolNamed:(Language.isRTL ? @"chevron.left" : @"chevron.right")
                      pointSize:12
                         weight:UIImageSymbolWeightBold
                          scale:UIImageSymbolScaleSmall
                        palette:@[[AppPrimaryTextClr colorWithAlphaComponent:0.46] ?: UIColor.secondaryLabelColor]
                   makeTemplate:YES];
    _chevronView = [[UIImageView alloc] initWithImage:chevronImage];
    _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    _chevronView.contentMode = UIViewContentModeScaleAspectFit;
    [self addSubview:_chevronView];

    [NSLayoutConstraint activateConstraints:@[
        [_blurView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_blurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_blurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_blurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [_tintOverlayView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_tintOverlayView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_tintOverlayView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_tintOverlayView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [_iconChipView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14.0],
        [_iconChipView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_iconChipView.widthAnchor constraintEqualToConstant:36.0],
        [_iconChipView.heightAnchor constraintEqualToConstant:36.0],

        [_iconView.centerXAnchor constraintEqualToAnchor:_iconChipView.centerXAnchor],
        [_iconView.centerYAnchor constraintEqualToAnchor:_iconChipView.centerYAnchor],
        [_iconView.widthAnchor constraintEqualToConstant:18.0],
        [_iconView.heightAnchor constraintEqualToConstant:18.0],

        [_chevronView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16.0],
        [_chevronView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_chevronView.widthAnchor constraintEqualToConstant:12.0],
        [_chevronView.heightAnchor constraintEqualToConstant:12.0],

        [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconChipView.trailingAnchor constant:12.0],
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_chevronView.leadingAnchor constant:-10.0],
        [_titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:14.0],

        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_chevronView.leadingAnchor constant:-10.0],
        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:3.0],
        [_subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-14.0],
        [self.heightAnchor constraintGreaterThanOrEqualToConstant:70.0]
    ]];

    [self addTarget:self action:@selector(pp_touchDown) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(pp_touchUp) forControlEvents:UIControlEventTouchUpInside];
    [self addTarget:self action:@selector(pp_touchUp) forControlEvents:UIControlEventTouchUpOutside];
    [self addTarget:self action:@selector(pp_touchUp) forControlEvents:UIControlEventTouchCancel];

    return self;
}

- (void)configureWithTitle:(NSString *)title
                  subtitle:(nullable NSString *)subtitle
                  iconName:(nullable NSString *)iconName
                 tintColor:(UIColor *)tintColor
               showsChevron:(BOOL)showsChevron
{
    UIColor *resolvedTint = tintColor ?: (AppPrimaryClr ?: UIColor.systemPinkColor);
    _titleLabel.text = PPSafeString(title);
    _subtitleLabel.text = PPSafeString(subtitle);
    _subtitleLabel.hidden = (PPSafeString(subtitle).length == 0);
    _chevronView.hidden = !showsChevron;
    _iconChipView.backgroundColor = [resolvedTint colorWithAlphaComponent:0.14];
    _iconChipView.layer.borderWidth = 1.0;
    _iconChipView.layer.borderColor = [resolvedTint colorWithAlphaComponent:0.08].CGColor;
    _iconView.tintColor = resolvedTint;
    _iconView.image =
        [UIImage pp_symbolNamed:PPSafeString(iconName)
                      pointSize:17
                         weight:UIImageSymbolWeightSemibold
                          scale:UIImageSymbolScaleMedium
                        palette:@[resolvedTint]
                   makeTemplate:YES];
}

- (void)pp_touchDown
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    [UIView animateWithDuration:0.12
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.transform = CGAffineTransformMakeScale(0.98, 0.98);
        self.alpha = 0.97;
    } completion:nil];
}

- (void)pp_touchUp
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1.0;
        return;
    }

    [UIView animateWithDuration:0.24
                          delay:0.0
         usingSpringWithDamping:0.80
          initialSpringVelocity:0.30
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1.0;
    } completion:nil];
}

@end

@interface PPHomeLocationSheetViewController : UIViewController

@property (nonatomic, copy) NSString *sheetTitleText;
@property (nonatomic, copy) NSString *sheetSubtitleText;
@property (nonatomic, copy) NSString *currentLocationTitle;
@property (nonatomic, copy) NSString *currentLocationSubtitle;
@property (nonatomic, assign) BOOL showsUseCurrentLocationAction;
@property (nonatomic, assign) BOOL showsOpenSettingsAction;
@property (nonatomic, copy) NSArray<NSDictionary *> *recentLocations;
@property (nonatomic, copy, nullable) dispatch_block_t onUseCurrentLocation;
@property (nonatomic, copy, nullable) dispatch_block_t onChangeArea;
@property (nonatomic, copy, nullable) dispatch_block_t onOpenSettings;
@property (nonatomic, copy, nullable) void (^onSelectRecentLocation)(NSDictionary *locationRecord);

@end

@implementation PPHomeLocationSheetViewController {
    UIScrollView *_scrollView;
    UIStackView *_contentStack;
    UIStackView *_recentStack;
    PPHomeLocationActionCard *_currentCard;
    PPHomeLocationActionCard *_useCurrentCard;
    PPHomeLocationActionCard *_changeAreaCard;
    PPHomeLocationActionCard *_settingsCard;
    UILabel *_recentTitleLabel;
    UIView *_heroSurfaceView;
    BOOL _didAnimateEntrance;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self pp_buildUI];
    [self pp_applySheetConfigurationIfNeeded];
    [self pp_reloadContent];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (_didAnimateEntrance || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    _didAnimateEntrance = YES;
    NSArray<UIView *> *arrangedViews = _contentStack.arrangedSubviews ?: @[];
    [_recentStack.arrangedSubviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)idx;
        (void)stop;
    }];

    NSInteger index = 0;
    for (UIView *view in arrangedViews) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 14.0);
        [UIView animateWithDuration:0.34
                              delay:0.03 * index
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.18
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
        index += 1;
    }
}

- (void)pp_buildUI
{
    UIView *backdropView = [[UIView alloc] init];
    backdropView.translatesAutoresizingMaskIntoConstraints = NO;
    backdropView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    backdropView.layer.cornerRadius = PPIOS26() ? 34.0 : 28.0;
    backdropView.layer.cornerCurve = kCACornerCurveContinuous;
    backdropView.clipsToBounds = YES;
    [self.view addSubview:backdropView];

    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.backgroundColor = UIColor.clearColor;
    [backdropView addSubview:_scrollView];

    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    contentView.backgroundColor = UIColor.clearColor;
    [_scrollView addSubview:contentView];

    _contentStack = [[UIStackView alloc] init];
    _contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    _contentStack.axis = UILayoutConstraintAxisVertical;
    _contentStack.spacing = 14.0;
    _contentStack.alignment = UIStackViewAlignmentFill;
    [_scrollView addSubview:_contentStack];

    _heroSurfaceView = [[UIView alloc] init];
    _heroSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _heroSurfaceView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.94] ?: [UIColor secondarySystemBackgroundColor];
    _heroSurfaceView.layer.cornerRadius = 26.0;
    _heroSurfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    _heroSurfaceView.layer.borderWidth = 0.8;
    _heroSurfaceView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.08].CGColor;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:24] ?: [UIFont systemFontOfSize:24.0 weight:UIFontWeightBold];
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.numberOfLines = 2;
    titleLabel.tag = 601;
    [_heroSurfaceView addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:14] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.62] ?: UIColor.secondaryLabelColor;
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.tag = 602;
    [_heroSurfaceView addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:_heroSurfaceView.topAnchor constant:18.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:_heroSurfaceView.leadingAnchor constant:18.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:_heroSurfaceView.trailingAnchor constant:-18.0],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:_heroSurfaceView.bottomAnchor constant:-18.0]
    ]];

    _currentCard = [[PPHomeLocationActionCard alloc] init];
    _useCurrentCard = [[PPHomeLocationActionCard alloc] init];
    _changeAreaCard = [[PPHomeLocationActionCard alloc] init];
    _settingsCard = [[PPHomeLocationActionCard alloc] init];
    [_useCurrentCard addTarget:self action:@selector(pp_handleUseCurrentLocation) forControlEvents:UIControlEventTouchUpInside];
    [_changeAreaCard addTarget:self action:@selector(pp_handleChangeArea) forControlEvents:UIControlEventTouchUpInside];
    [_settingsCard addTarget:self action:@selector(pp_handleOpenSettings) forControlEvents:UIControlEventTouchUpInside];

    _recentTitleLabel = [[UILabel alloc] init];
    _recentTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _recentTitleLabel.font = [GM boldFontWithSize:14] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    _recentTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _recentTitleLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.74] ?: UIColor.secondaryLabelColor;

    _recentStack = [[UIStackView alloc] init];
    _recentStack.translatesAutoresizingMaskIntoConstraints = NO;
    _recentStack.axis = UILayoutConstraintAxisVertical;
    _recentStack.spacing = 10.0;
    _recentStack.alignment = UIStackViewAlignmentFill;

    [_contentStack addArrangedSubview:_heroSurfaceView];
    [_contentStack addArrangedSubview:_currentCard];
    [_contentStack addArrangedSubview:_useCurrentCard];
    [_contentStack addArrangedSubview:_changeAreaCard];
    [_contentStack addArrangedSubview:_settingsCard];
    [_contentStack addArrangedSubview:_recentTitleLabel];
    [_contentStack addArrangedSubview:_recentStack];

    [NSLayoutConstraint activateConstraints:@[
        [backdropView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [backdropView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [backdropView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [backdropView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [_scrollView.topAnchor constraintEqualToAnchor:backdropView.topAnchor],
        [_scrollView.leadingAnchor constraintEqualToAnchor:backdropView.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:backdropView.trailingAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:backdropView.bottomAnchor],

        [contentView.topAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.bottomAnchor],
        [contentView.widthAnchor constraintEqualToAnchor:_scrollView.frameLayoutGuide.widthAnchor],

        [_contentStack.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:20.0],
        [_contentStack.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16.0],
        [_contentStack.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-16.0],
        [_contentStack.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-24.0]
    ]];
}

- (void)pp_applySheetConfigurationIfNeeded
{
    self.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = self.sheetPresentationController;
        if (!sheet) {
            return;
        }
        sheet.detents = @[
            UISheetPresentationControllerDetent.mediumDetent,
            UISheetPresentationControllerDetent.largeDetent
        ];
        sheet.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
        sheet.prefersGrabberVisible = YES;
        sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
        sheet.preferredCornerRadius = PPIOS26() ? 34.0 : 28.0;
        if (@available(iOS 16.0, *)) {
            sheet.prefersEdgeAttachedInCompactHeight = YES;
            sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = YES;
        }
    }
}

- (void)pp_reloadContent
{
    UILabel *titleLabel = [_heroSurfaceView viewWithTag:601];
    UILabel *subtitleLabel = [_heroSurfaceView viewWithTag:602];
    titleLabel.text = PPSafeString(self.sheetTitleText);
    subtitleLabel.text = PPSafeString(self.sheetSubtitleText);

    [_currentCard configureWithTitle:(self.currentLocationTitle.length > 0 ? self.currentLocationTitle : (kLang(@"Select your location") ?: @"Select your location"))
                            subtitle:PPSafeString(self.currentLocationSubtitle)
                            iconName:@"location.fill"
                           tintColor:(AppPrimaryClr ?: UIColor.systemPinkColor)
                         showsChevron:NO];

    [_useCurrentCard configureWithTitle:(kLang(@"home_location_sheet_use_current") ?: @"Use current location")
                               subtitle:(kLang(@"home_location_sheet_use_current_subtitle") ?: @"Refresh nearby pets and services using GPS")
                               iconName:@"location.north.fill"
                              tintColor:UIColor.systemBlueColor
                            showsChevron:YES];

    [_changeAreaCard configureWithTitle:(kLang(@"home_location_sheet_change_area") ?: @"Change area")
                               subtitle:(kLang(@"home_location_sheet_change_area_subtitle") ?: @"Pick another city or neighborhood")
                               iconName:@"map.fill"
                              tintColor:UIColor.systemOrangeColor
                            showsChevron:YES];

    [_settingsCard configureWithTitle:(kLang(@"Open Settings") ?: @"Open Settings")
                             subtitle:(kLang(@"home_location_sheet_open_settings_subtitle") ?: @"Allow location access to keep nearby results accurate")
                             iconName:@"gearshape.fill"
                            tintColor:UIColor.systemIndigoColor
                          showsChevron:YES];
    _useCurrentCard.hidden = !self.showsUseCurrentLocationAction;
    _settingsCard.hidden = !self.showsOpenSettingsAction;

    _recentTitleLabel.text = kLang(@"home_location_sheet_recent_title") ?: @"Recent locations";
    _recentTitleLabel.hidden = (self.recentLocations.count == 0);

    for (UIView *subview in _recentStack.arrangedSubviews.copy) {
        [_recentStack removeArrangedSubview:subview];
        [subview removeFromSuperview];
    }

    NSInteger index = 0;
    for (NSDictionary *record in self.recentLocations ?: @[]) {
        PPHomeLocationActionCard *card = [[PPHomeLocationActionCard alloc] init];
        card.tag = index;
        NSString *title = PPSafeString(record[@"title"]);
        NSString *subtitle = PPSafeString(record[@"subtitle"]);
        if (subtitle.length == 0) {
            subtitle = kLang(@"home_location_sheet_recent_subtitle") ?: @"Tap to reuse this location";
        }
        [card configureWithTitle:title
                        subtitle:subtitle
                        iconName:@"clock.arrow.circlepath"
                       tintColor:UIColor.systemTealColor
                     showsChevron:YES];
        [card addTarget:self action:@selector(pp_handleRecentLocationTap:) forControlEvents:UIControlEventTouchUpInside];
        [_recentStack addArrangedSubview:card];
        index += 1;
    }
    _recentStack.hidden = (self.recentLocations.count == 0);
}

- (void)pp_handleUseCurrentLocation
{
    [self pp_dismissThenRun:self.onUseCurrentLocation];
}

- (void)pp_handleChangeArea
{
    [self pp_dismissThenRun:self.onChangeArea];
}

- (void)pp_handleOpenSettings
{
    [self pp_dismissThenRun:self.onOpenSettings];
}

- (void)pp_handleRecentLocationTap:(PPHomeLocationActionCard *)sender
{
    NSInteger index = sender.tag;
    if (index < 0 || index >= (NSInteger)self.recentLocations.count) {
        return;
    }

    NSDictionary *record = self.recentLocations[(NSUInteger)index];
    void (^selectBlock)(void) = ^{
        if (self.onSelectRecentLocation) {
            self.onSelectRecentLocation(record);
        }
    };
    [self pp_dismissThenRun:selectBlock];
}

- (void)pp_dismissThenRun:(dispatch_block_t)block
{
    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:block];
    } else if (block) {
        block();
    }
}

@end

static NSString * const PPNearbySelectedLatitudeKey = @"pp.home.nearby.latitude";
static NSString * const PPNearbySelectedLongitudeKey = @"pp.home.nearby.longitude";
static NSString * const PPNearbySelectedAreaNameKey = @"pp.home.nearby.areaName";
static NSString * const PPNearbyRecentLocationsKey = @"pp.home.nearby.recentLocations";
static NSString * const PPHomeTopCarouselBannerGroupID = @"HOME_MAIN_TOP_CAROUSEL";
static NSString * const PPHomeCompletedLastOrderSeenOrderIDKeyPrefix = @"pp.home.completedLastOrder.seen.orderID";
static NSString * const PPHomeCompletedLastOrderSeenSessionIDKeyPrefix = @"pp.home.completedLastOrder.seen.sessionID";
static NSString * const PPHomeTerminalOrderSeenOrderIDKeyPrefix = @"pp.home.terminalOrder.seen.orderID";
static NSString * const PPHomeTerminalOrderSeenSessionIDKeyPrefix = @"pp.home.terminalOrder.seen.sessionID";
static NSTimeInterval const PPNearbyMinimumRefreshInterval = 20.0;
static NSTimeInterval const PPHomeOtherOrdersRecentLookbackInterval = 24.0 * 60.0 * 60.0;
static NSTimeInterval const PPHomeCompletedLastOrderVisibilityInterval = 48.0 * 60.0 * 60.0;
static double const PPNearbyDefaultRadiusKm = 8.0;
static double const PPNearbyExpandedRadiusKm = 15.0;
static NSInteger const PPCurrentOrdersVisibleLimit = 4;
static NSInteger const PPBuyAgainVisibleLimit = 10;
static NSInteger const PPNearbyRecentLocationsLimit = 4;
static CLLocationCoordinate2D const PPNearbyDebugSimulatorCoordinate = {25.285447, 51.531040};

static NSString *PPHomeCurrentAppSessionIdentifier(void)
{
    static NSString *sessionIdentifier = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sessionIdentifier = NSUUID.UUID.UUIDString ?: @"";
    });
    return sessionIdentifier;
}

typedef NS_ENUM(NSInteger, PPNearbyLocationState) {
    PPNearbyLocationStateUnset = 0,
    PPNearbyLocationStateLoading,
    PPNearbyLocationStateReady,
    PPNearbyLocationStateDenied
};


@interface PPHomeViewController ()<UICollectionViewDelegate, UICollectionViewDataSourcePrefetching, BannerTapsCollectionDelegate,PPUniversalCellDelegate, CLLocationManagerDelegate>
 @property (nonatomic, assign) BOOL warmUpCache;
@property (nonatomic, assign) BOOL chatsListenerStarted;
@property (nonatomic, copy, nullable) NSString *unreadListenerUserID;
@property (nonatomic, assign) BOOL adsLoaded;
@property (nonatomic, assign) BOOL accessoriesLoaded;
@property (nonatomic, assign) BOOL nearbyLoaded;
@property (nonatomic, assign) BOOL nearbyLoading;
@property (nonatomic, assign) BOOL hideServiceSection;
@property (nonatomic, strong, nullable) MainKindsModel *selectedCategory;
@property (nonatomic, strong) PPHomeLayoutManager *layoutManager;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UICollectionViewDiffableDataSource<NSNumber *, PPHomeItem *> *dataSource;
@property (nonatomic, assign) BOOL didSelectInitialNearby;
@property (nonatomic, strong) NSArray<PetAd *> *ads;
@property (nonatomic, strong) NSArray<ServiceModel *> *services;
@property (nonatomic, strong) NSArray<MainKindsModel *> *mainKinds;
@property (nonatomic, strong) NSArray<PPCategoryItem *> *categories;
@property (nonatomic, strong) NSArray<PetAccessory *> *accessories;
@property (nonatomic, strong) NSArray<PetAccessory *> *buyAgainAccessories;
@property (nonatomic, strong) NSArray<PetAd *> *nearbyAds;
@property (nonatomic, strong) NSArray<PPOrder *> *currentOrders;
@property (nonatomic, strong) NSArray<PPOrder *> *recentOrders;
@property (nonatomic, strong) NSArray<PPCarouselItem *> *carouselItems;
@property (nonatomic, strong) NSArray<PPHomePromoCarouselCard *> *promoCarouselCards;
@property (nonatomic, strong) CLLocationManager *homeLocationManager;
@property (nonatomic, strong) CLGeocoder *homeGeocoder;
@property (nonatomic, assign) CLLocationCoordinate2D selectedNearbyCoordinate;
@property (nonatomic, assign) BOOL hasSelectedNearbyCoordinate;
@property (nonatomic, copy) NSString *selectedNearbyAreaName;
@property (nonatomic, assign) PPNearbyLocationState nearbyLocationState;
@property (nonatomic, assign) BOOL hasRequestedLocationAuthorization;
@property (nonatomic, assign) NSInteger nearbyRequestToken;
@property (nonatomic, strong) NSDate *lastNearbyRefreshAt;
@property (nonatomic, assign) CLLocationCoordinate2D lastNearbyRefreshCoordinate;
@property (nonatomic, assign) BOOL hasLastNearbyRefreshCoordinate;
@property (nonatomic, assign) double nearbyRadiusKm;
@property (nonatomic, strong) NSTimer *nearbyRefreshTimer;
@property (nonatomic, assign) BOOL isUsingManualNearbySelection;
@property (nonatomic, strong) UIView *pp_backgroundCanvasView;
@property (nonatomic, strong) CAGradientLayer *pp_backgroundGradientLayer;
@property (nonatomic, strong) CAGradientLayer *pp_backgroundTopGlowLayer;
@property (nonatomic, strong) CAGradientLayer *pp_backgroundAccentGlowLayer;
@property (nonatomic, strong) CAGradientLayer *pp_backgroundBottomGlowLayer;
@property (nonatomic, strong) CAGradientLayer *pp_backgroundShineLayer;
@property (nonatomic, assign) BOOL pp_backgroundAnimationsConfigured;
@property (nonatomic, assign) BOOL currentOrdersLoading;
@property (nonatomic, assign) BOOL currentOrdersLoaded;
@property (nonatomic, assign) BOOL isCurrentOrdersExpanded;
@property (nonatomic, assign) NSInteger currentOrdersRequestToken;
@property (nonatomic, assign) NSInteger buyAgainRequestToken;
@property (nonatomic, strong, nullable) NSDate *lastCurrentOrdersRefreshAt;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> currentOrdersQueryListener;
@property (nonatomic, copy) NSString *currentOrdersListenerUserID;
@property (nonatomic, assign) BOOL isHomeScreenVisible;
@property (nonatomic, copy, nullable) NSString *lastObservedHomeOrderID;
@property (nonatomic, copy, nullable) NSString *lastObservedHomeOrderStatusKey;
- (void)handleSeeAllForSection:(PPHomeSection)section;
- (NSString *)heroGreetingText;
- (NSString *)heroBaseGreetingText;
- (NSString *)heroDisplayNameText;
- (NSString *)heroCountryText;
- (nullable NSString *)heroLocationActionTitle;
- (void)refreshHeroSectionAppearance;
- (void)refreshNearbyAdsForce:(BOOL)force reason:(NSString *)reason;
- (void)openHomeLocationPicker;
- (void)presentHomeLocationOptions;
- (void)openLocationSettings;
- (void)configureLocationStateMachine;
- (void)switchHomeLocationBackToAutomatic;
- (void)presentHomeLocationSheet;
- (BOOL)pp_canUseSimulatedNearbyLocation;
- (void)pp_applySimulatedNearbyLocationAndRefreshWithReason:(NSString *)reason;
- (NSArray<PPHomeQuickActionModel *> *)pp_homeQuickActions;
- (void)handleQuickActionSelection:(PPHomeQuickActionModel *)quickAction;
- (void)pp_openAddNewAdComposer;
- (void)pp_openAdoptFlow;
- (NSArray<NSDictionary *> *)pp_recentNearbyLocationRecords;
- (void)pp_recordRecentNearbyLocationCoordinate:(CLLocationCoordinate2D)coordinate
                                          title:(NSString *)title
                                         source:(NSString *)source;
- (void)pp_applyNearbyLocationRecord:(NSDictionary *)record;
- (NSDictionary<NSString *, NSString *> *)pp_suggestionReasonForModel:(id)model
                                                      latestEvent:(NSDictionary *)latestEvent
                                             orderedAccessoryIDs:(NSSet<NSString *> *)orderedAccessoryIDs;
- (NSString *)pp_browseReasonTextForEvent:(NSDictionary *)event;
- (void)pp_emitSelectionHaptic;
- (void)pp_emitSoftImpactHaptic;
- (void)pp_animateHomeCell:(UICollectionViewCell *)cell highlighted:(BOOL)highlighted;
- (void)pp_scheduleInitialMainKindsLayoutRefresh;
- (void)refreshCurrentOrdersForce:(BOOL)force;
- (NSString *)pp_currentOrdersUserID;
- (void)pp_stopCurrentOrdersListener;
- (void)pp_startCurrentOrdersListenerForUserID:(NSString *)userID requestToken:(NSInteger)requestToken;
- (void)pp_applyCurrentOrdersSnapshot:(FIRQuerySnapshot *)snapshot requestToken:(NSInteger)requestToken;
- (BOOL)pp_homeStatusKey:(NSString *)statusKey matchesAnyKeywords:(NSArray<NSString *> *)keywords;
- (BOOL)pp_isFailureHomeOrderStatusKey:(NSString *)statusKey;
- (BOOL)pp_isActiveHomeOrder:(PPOrder *)order;
- (NSString *)pp_homeOrderStatusKey:(PPOrder *)order;
- (NSString *)pp_homeOrderStatusTitle:(PPOrder *)order;
- (NSString *)pp_homeOrderStatusHint:(PPOrder *)order;
- (UIColor *)pp_homeOrderStatusColor:(PPOrder *)order;
- (NSString *)pp_homeOrderStatusIconName:(PPOrder *)order;
- (double)pp_homeOrderProgress:(PPOrder *)order;
- (NSInteger)pp_homeOrderItemCount:(PPOrder *)order;
- (NSString *)pp_homeOrderAmountText:(PPOrder *)order;
- (NSString *)pp_homeOrderMetaText:(PPOrder *)order;
- (NSString *)pp_homeOrderFooterText:(PPOrder *)order;
- (NSString *)pp_homeOrderKickerTitle:(PPOrder *)order;
- (NSString *)pp_homeOrderImageURLFromItemData:(NSDictionary *)data;
- (NSArray<NSString *> *)pp_homeOrderPreviewImageURLs:(PPOrder *)order limit:(NSInteger)limit;
- (BOOL)pp_hasOtherRecentHomeOrdersWithinInterval:(NSTimeInterval)interval excludingOrder:(PPOrder *)order;
- (BOOL)pp_shouldHideCompletedLastHomeOrder:(PPOrder *)order;
- (NSString *)pp_completedLastHomeOrderSeenOrderIDDefaultsKey;
- (NSString *)pp_completedLastHomeOrderSeenSessionDefaultsKey;
- (void)pp_setCurrentOrdersExpanded:(BOOL)expanded animated:(BOOL)animated;
- (void)pp_scrollCurrentOrdersSectionIntoViewAnimated:(BOOL)animated;
- (NSString *)pp_homeRelativeDateString:(NSDate *)date;
- (NSString *)pp_homeShortDateString:(NSDate *)date;
- (nullable PPOrder *)pp_featuredHomeOrder;
- (NSArray<PPHomeItem *> *)pp_homeCurrentOrderItems;
- (NSArray<PPHomeItem *> *)pp_homeBuyAgainItems;
- (NSString *)pp_homeOrderItemIdentifier:(id)rawItem;
- (NSArray<NSString *> *)pp_buyAgainAccessoryIDsFromOrders:(NSArray<PPOrder *> *)orders
                                                     limit:(NSInteger)limit;
- (NSArray<PetAccessory *> *)pp_orderedBuyAgainAccessoriesFromResolvedByID:(NSDictionary<NSString *, PetAccessory *> *)resolvedByID
                                                                 orderedIDs:(NSArray<NSString *> *)orderedIDs
                                                                      limit:(NSInteger)limit;
- (void)pp_refreshBuyAgainSection;
- (void)pp_centerNearbySectionIfPossible;
- (void)pp_openOrderDetailsForOrder:(PPOrder *)order;

- (void)refreshNavigationRightItemsForCartCount:(NSUInteger)count;
@property (nonatomic, assign) BOOL isMainKindsExpanded;
@property (nonatomic, assign) BOOL didAutoScrollSuggestions;
@property (nonatomic, assign) BOOL didFillSuggestionsOnce;
@property (nonatomic, strong) UIView *profileCard;
@property (nonatomic, strong, nullable) UIBarButtonItem *homeProfileItem;
@property (nonatomic, strong, nullable) UIBarButtonItem *homeCartItem;
@property (nonatomic, strong, nullable) UIButton *homeCartButton;
@property (nonatomic, strong, nullable) PPInsetLabel *homeCartBadgeLabel;
@property (nonatomic, strong, nullable) NSLayoutConstraint *homeCartBadgeMinWidthConstraint;
@property (nonatomic, strong, nullable) UIBarButtonItem *homeOptionsItem;
@property (nonatomic, strong, nullable) PPHomeSmartSearchTitleView *homeSmartSearchView;
@property (nonatomic, strong, nullable) NSTimer *homeSmartSearchTimer;
@property (nonatomic, copy) NSArray<NSString *> *homeSmartSearchPlaceholders;
@property (nonatomic, assign) NSInteger homeSmartSearchPlaceholderIndex;
@property (nonatomic, assign) BOOL didRegisterTimeChangeObserver;
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *blurHashCache;
@property (nonatomic, strong) dispatch_queue_t blurHashQueue;
@property (nonatomic, copy) NSString *lastHeroRenderSignature;
@property (nonatomic, assign) BOOL heroRefreshScheduled;
- (void)pp_prefetchImagesAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (void)pp_prefetchTopImagesWithLimit:(NSInteger)limit;
- (void)pp_asyncBlurHashImageForHash:(NSString *)hash
                                size:(CGSize)size
                          completion:(void (^)(UIImage * _Nullable image))completion;
- (void)handleUserProfileSyncNotification:(NSNotification *)notification;
- (void)pp_handlePromoCardTap:(PPHomePromoCarouselCard *)card interaction:(NSString *)interaction;
- (void)pp_handleCarouselTapAction:(PPBannerOnTapAction)action
                             value:(NSString *)value
                       defaultKind:(NSInteger)fallbackMainKindID
                           context:(NSString *)context;
- (nullable MainBannerModel *)pp_homeTopCarouselBannerGroup;
- (NSArray<PPHomePromoCarouselCard *> *)pp_homePromoFallbackCards;
- (NSArray<PPHomePromoCarouselCard *> *)pp_promoCardsFromLegacyBannerGroup:(MainBannerModel *)group;
- (void)pp_layoutBackgroundLayers;
- (void)pp_startBackgroundAnimationsIfNeeded;
- (void)pp_stopBackgroundAnimations;
- (CGFloat)pp_preferredNavigationSearchWidth;
- (UIView *)pp_navigationSmartSearchTitleView;
- (void)pp_openSmartSearch;
- (NSArray<NSString *> *)pp_resolvedHomeSmartSearchPlaceholders;
- (NSString *)pp_currentHomeSmartSearchPlaceholder;
- (void)pp_updateHomeSmartSearchPlaceholderAnimated:(BOOL)animated;
- (void)pp_startHomeSmartSearchTimerIfNeeded;
- (void)pp_stopHomeSmartSearchTimer;
- (void)pp_advanceHomeSmartSearchPlaceholder;

@end


@implementation PPHomeViewController


// Scroll Suggestions section to item index 2 after data is loaded
- (void)autoScrollIndextoIndex:(NSInteger)targetItem inSection:(PPHomeSection)section
{
    NSInteger sectionIndex = [self sectionIndexForType:section];
    if (sectionIndex == NSNotFound) return;


    if ([self.collectionView numberOfItemsInSection:sectionIndex] <= targetItem) {
        return;
    }

    NSIndexPath *indexPath =
        [NSIndexPath indexPathForItem:targetItem inSection:sectionIndex];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self.collectionView scrollToItemAtIndexPath:indexPath
                                    atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                            animated:YES];
    });
}

- (void)pp_centerNearbySectionIfPossible
{
    NSInteger sectionIndex = [self sectionIndexForType:PPHomeSectionAdsNearBy];
    if (sectionIndex == NSNotFound || !self.collectionView) {
        return;
    }

    NSInteger itemCount = [self.collectionView numberOfItemsInSection:sectionIndex];
    if (itemCount <= 1) {
        return;
    }

    NSInteger targetItem = MIN(1, itemCount - 1);
    NSIndexPath *centerIndexPath = [NSIndexPath indexPathForItem:targetItem inSection:sectionIndex];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.collectionView layoutIfNeeded];
        if ([self.collectionView numberOfItemsInSection:sectionIndex] <= targetItem) {
            return;
        }
        [self.collectionView scrollToItemAtIndexPath:centerIndexPath
                                    atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                            animated:NO];
    });
}

#pragma mark - Life Cycle
- (void)didTapOn_BannerViewModel:(PPBannerViewModel *)pannerViewModel
{
    if (!pannerViewModel) return;
    [self pp_handleCarouselTapAction:pannerViewModel.onTapAction
                               value:PPSafeString(pannerViewModel.onTapValue)
                         defaultKind:0
                             context:@"legacy-banner-card"];
}

- (void)pp_handlePromoCardTap:(PPHomePromoCarouselCard *)card
                  interaction:(NSString *)interaction
{
    if (!card) return;

    if ([interaction isEqualToString:@"primary"]) {
        [self pp_handleCarouselTapAction:card.primaryButtonTapAction
                                   value:PPSafeString(card.primaryButtonTapValue)
                             defaultKind:0
                                 context:@"promo-primary-button"];
        return;
    }

    if ([interaction isEqualToString:@"secondary"]) {
        [self pp_handleCarouselTapAction:card.secondaryButtonTapAction
                                   value:PPSafeString(card.secondaryButtonTapValue)
                             defaultKind:0
                                 context:@"promo-secondary-button"];
        return;
    }

    [self pp_handleCarouselTapAction:card.cardTapAction
                               value:PPSafeString(card.cardTapValue)
                         defaultKind:0
                             context:@"promo-card"];
}

- (void)pp_handleCarouselTapAction:(PPBannerOnTapAction)action
                             value:(NSString *)value
                       defaultKind:(NSInteger)fallbackMainKindID
                           context:(NSString *)context
{
    NSString *safeValue = PPSafeString(value);
    NSLog(@"[Home][CarouselTap] context=%@ action=%ld value=%@",
          context ?: @"(nil)", (long)action, safeValue);

    switch (action) {
        case PPBannerOnTapViewAccessory:
        case PPBannerOnTapViewAd: {
            NSInteger mainKindID = safeValue.integerValue;
            if (mainKindID <= 0) {
                mainKindID = fallbackMainKindID;
            }
            MainKindsModel *kind = (mainKindID > 0) ? [self resolveMainKindWithID:mainKindID] : nil;
            PPDeepLinkTarget target = (action == PPBannerOnTapViewAccessory)
                ? PPDeepLinkTargetAccessories
                : PPDeepLinkTargetAds;
            PPInputSource source = (action == PPBannerOnTapViewAccessory)
                ? PPInputSourceHomeAccessoriesSection
                : PPInputSourceHomeNearBySection;
            [self handleDeepLinkWithTarget:target mainKind:kind source:source];
            break;
        }

        case PPBannerOnTapOpenUrl: {
            NSString *urlString = safeValue;
            if (urlString.length == 0) return;
            if (![urlString containsString:@"://"]) {
                urlString = [NSString stringWithFormat:@"https://%@", urlString];
            }
            NSURL *url = [NSURL URLWithString:urlString];
            if (!url) return;

            if (@available(iOS 9.0, *)) {
                SFSafariViewController *safari = [[SFSafariViewController alloc] initWithURL:url];
                [PPFunc presentSheetFrom:self sheetVC:safari detentStyle:PPSheetDetentStyle80];
            } else {
                [[UIApplication sharedApplication] openURL:url];
            }
            break;
        }

        case PPBannerOnTapCallPhoneNumber:
            [AppClasses callPhoneNumber:safeValue fromViewController:self];
            break;

        case PPBannerOnTapWhatsApp:
            [AppClasses startWhatsAppWith:safeValue fromViewController:self];
            break;

        default:
            break;
    }
}

- (NSArray<PPHomePromoCarouselCard *> *)pp_homePromoFallbackCards
{
    PPHomePromoCarouselCard *card = [PPHomePromoCarouselCard new];
    card.cardID = @"home-promo-fallback-service";
    card.visible = YES;
    card.sortOrder = 0;
    NSString *badgeTitle = kLang(@"Popular") ?: @"Popular";
    NSString *title = kLang(@"Hire a Service Man") ?: @"Hire a Service Man";
    NSString *subtitle = kLang(@"Need help with setup, repairs & installation?") ?: @"Need help with setup, repairs & installation?";
    NSString *bookNow = kLang(@"Book Now") ?: @"Book Now";
    card.badgeTextEn = badgeTitle;
    card.badgeTextAr = badgeTitle;
    card.titleTextEn = title;
    card.titleTextAr = title;
    card.subtitleTextEn = subtitle;
    card.subtitleTextAr = subtitle;
    card.primaryButtonTitleEn = bookNow;
    card.primaryButtonTitleAr = bookNow;
    card.hidePrimaryButton = NO;
    card.hideSecondaryButton = YES;
    card.startColorHex = @"#F5A63A";
    card.endColorHex = @"#EF8628";
    card.accentColorHex = @"#FFC86D";
    card.cardTapAction = PPBannerOnTapViewAccessory;
    card.cardTapValue = @"";
    card.primaryButtonTapAction = PPBannerOnTapViewAccessory;
    card.primaryButtonTapValue = @"";
    card.autoScrollInterval = 4.8;
    return @[card];
}

- (NSArray<PPHomePromoCarouselCard *> *)pp_promoCardsFromLegacyBannerGroup:(MainBannerModel *)group
{
    if (!group || group.childBanners.count == 0) return @[];

    NSMutableArray<PPHomePromoCarouselCard *> *cards = [NSMutableArray arrayWithCapacity:group.childBanners.count];
    NSInteger idx = 0;
    for (PPBannerViewModel *vm in group.childBanners) {
        if (![vm isKindOfClass:PPBannerViewModel.class]) continue;

        PPHomePromoCarouselCard *card = [PPHomePromoCarouselCard new];
        card.cardID = PPSafeString(vm.bannerID).length > 0 ? PPSafeString(vm.bannerID) : [NSString stringWithFormat:@"legacy-banner-%ld", (long)idx];
        card.visible = YES;
        card.sortOrder = idx;

        NSString *titleEn = PPSafeString(vm.titleTextEn);
        NSString *titleAr = PPSafeString(vm.titleTextAr);
        NSString *descEn = PPSafeString(vm.descTextEn);
        NSString *descAr = PPSafeString(vm.descTextAr);

        card.titleTextEn = titleEn.length > 0 ? titleEn : [vm localizedTitleText];
        card.titleTextAr = titleAr;
        card.subtitleTextEn = descEn.length > 0 ? descEn : [vm localizedDescText];
        card.subtitleTextAr = descAr;

        NSString *badge = PPSafeString(vm.postDateText);
        if (badge.length == 0) badge = @"Popular";
        card.badgeTextEn = badge;
        card.badgeTextAr = badge;

        switch (vm.onTapAction) {
            case PPBannerOnTapViewAccessory:
                card.primaryButtonTitleEn = kLang(@"Shop Now") ?: @"Shop Now";
                card.primaryButtonTitleAr = card.primaryButtonTitleEn;
                break;
            case PPBannerOnTapViewAd:
                card.primaryButtonTitleEn = kLang(@"View Ads") ?: @"View Ads";
                card.primaryButtonTitleAr = card.primaryButtonTitleEn;
                break;
            case PPBannerOnTapCallPhoneNumber:
                card.primaryButtonTitleEn = kLang(@"Call") ?: @"Call";
                card.primaryButtonTitleAr = card.primaryButtonTitleEn;
                break;
            case PPBannerOnTapWhatsApp:
                card.primaryButtonTitleEn = kLang(@"WhatsApp") ?: @"WhatsApp";
                card.primaryButtonTitleAr = card.primaryButtonTitleEn;
                break;
            case PPBannerOnTapOpenUrl:
            default:
                card.primaryButtonTitleEn = kLang(@"Open") ?: @"Open";
                card.primaryButtonTitleAr = card.primaryButtonTitleEn;
                break;
        }

        card.hidePrimaryButton = NO;
        card.hideSecondaryButton = YES;
        card.cardTapAction = vm.onTapAction;
        card.cardTapValue = PPSafeString(vm.onTapValue);
        card.primaryButtonTapAction = vm.onTapAction;
        card.primaryButtonTapValue = PPSafeString(vm.onTapValue);
        card.characterImageURL = vm.sampleImageURL;
        card.backgroundImageURL = vm.backgroundImageURL;
        card.autoScrollInterval = 5.0;

        // Subtle color variance while keeping the same warm style
        switch (idx % 4) {
            case 1:
                card.startColorHex = @"#F39B3C";
                card.endColorHex = @"#E9792C";
                card.accentColorHex = @"#FFD893";
                break;
            case 2:
                card.startColorHex = @"#F2A84A";
                card.endColorHex = @"#D96F27";
                card.accentColorHex = @"#FFC773";
                break;
            case 3:
                card.startColorHex = @"#EF9740";
                card.endColorHex = @"#D86721";
                card.accentColorHex = @"#FFD28B";
                break;
            default:
                card.startColorHex = @"#F5A63A";
                card.endColorHex = @"#EF8628";
                card.accentColorHex = @"#FFC86D";
                break;
        }

        [cards addObject:card];
        idx += 1;
    }

    return cards.copy;
}
- (void)applyBaseSnapshot
{
    NSDiffableDataSourceSnapshot *snapshot =
        [[NSDiffableDataSourceSnapshot alloc] init];

    // ✅ Sections ALWAYS visible
    NSMutableArray<NSNumber *> *sections = [@[
        @(PPHomeSectionHero),
        @(PPHomeSectionQuickActions),
    ] mutableCopy];
    if (!self.hideServiceSection) {
        [sections addObject:@(PPHomeSectionServices)];
    }
    [sections addObjectsFromArray:@[
        @(PPHomeSectionCurrentOrders),
        @(PPHomeSectionCarousel),
        @(PPHomeSectionMainKinds),
        @(PPHomeSectionSuggestions),
        @(PPHomeSectionAccessories),
        @(PPHomeSectionAdsNearBy),
        @(PPHomeSectionAdopt),
    ]];
    [snapshot appendSectionsWithIdentifiers:sections];

    // ✅ Hero (always present)
    PPHomeItem *heroItem = [PPHomeItem new];
    heroItem.type = PPHomeItemTypeHero;
    heroItem.payload = [NSNull null];
    [snapshot appendItemsWithIdentifiers:@[heroItem]
               intoSectionWithIdentifier:@(PPHomeSectionHero)];

    NSMutableArray<PPHomeItem *> *quickActions = [NSMutableArray array];
    for (PPHomeQuickActionModel *quickAction in [self pp_homeQuickActions]) {
        PPHomeItem *item = [PPHomeItem new];
        item.type = PPHomeItemTypeQuickActions;
        item.payload = quickAction;
        [quickActions addObject:item];
    }
    [snapshot appendItemsWithIdentifiers:quickActions
               intoSectionWithIdentifier:@(PPHomeSectionQuickActions)];

    // ✅ Services (right after hero)
    if (!self.hideServiceSection) {
        NSMutableArray *services = [NSMutableArray array];
        for (PPHomeServiceItem *service in [PPHomeServiceItem defaultHomeServices]) {
            PPHomeItem *item = [PPHomeItem new];
            item.payload = service;
            [services addObject:item];
        }
        [snapshot appendItemsWithIdentifiers:services
                   intoSectionWithIdentifier:@(PPHomeSectionServices)];
    }

    // ✅ Current Orders (after services)
    NSArray<PPHomeItem *> *currentOrderItems = [self pp_homeCurrentOrderItems];
    [snapshot appendItemsWithIdentifiers:currentOrderItems
               intoSectionWithIdentifier:@(PPHomeSectionCurrentOrders)];

    // ✅ Carousel placeholder (always present)
    PPHomeItem *carouselPlaceholder = [PPHomeItem new];
    carouselPlaceholder.payload = [NSNull null];

    [snapshot appendItemsWithIdentifiers:@[carouselPlaceholder]
               intoSectionWithIdentifier:@(PPHomeSectionCarousel)];

    // ✅ MainKinds (static)
    NSMutableArray *kinds = [NSMutableArray array];
    for (MainKindsModel *k in self.mainKinds) {
        PPHomeItem *item = [PPHomeItem new];
        item.payload = k;
        [kinds addObject:item];
    }
    [snapshot appendItemsWithIdentifiers:kinds
               intoSectionWithIdentifier:@(PPHomeSectionMainKinds)];

    // 🟡 Empty dynamic sections (NO skeletons)
    // ✅ Suggestions placeholder (height anchor)



    [snapshot appendItemsWithIdentifiers:@[]
               intoSectionWithIdentifier:@(PPHomeSectionAccessories)];
    [snapshot appendItemsWithIdentifiers:@[]
               intoSectionWithIdentifier:@(PPHomeSectionAdsNearBy)];

    // ✅ Adopt (static)
    PPHomeItem *adoptItem =
        [[PPHomeItem alloc] initWithType:PPHomeItemTypeAdopt payload:@"adopt"];
    [snapshot appendItemsWithIdentifiers:@[adoptItem]
               intoSectionWithIdentifier:@(PPHomeSectionAdopt)];

    NSArray<PPHomeItem *> *buyAgainItems = [self pp_homeBuyAgainItems];
    if (buyAgainItems.count > 0) {
        [snapshot appendSectionsWithIdentifiers:@[@(PPHomeSectionBuyAgain)]];
        [snapshot appendItemsWithIdentifiers:buyAgainItems
                   intoSectionWithIdentifier:@(PPHomeSectionBuyAgain)];
    }

    [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
}

- (void)pp_scheduleInitialMainKindsLayoutRefresh
{
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.collectionView) {
            return;
        }

        if ([self sectionIndexForType:PPHomeSectionMainKinds] == NSNotFound) {
            return;
        }

        [self.collectionView.collectionViewLayout invalidateLayout];
        [self.collectionView setNeedsLayout];
        [self.collectionView layoutIfNeeded];
    });
}

- (void)reloadSection:(PPHomeSection)section
{
    NSNumber *sectionIdentifier = @(section);
    CGPoint preservedOffset = CGPointZero;
    BOOL preserveOffset = (section == PPHomeSectionSuggestions);

    if (preserveOffset) {
        preservedOffset = self.collectionView.contentOffset;
    }


    NSDiffableDataSourceSnapshot *snapshot =
        self.dataSource.snapshot;

    NSArray<NSNumber *> *sectionIdentifiers = snapshot.sectionIdentifiers;
    BOOL sectionExists = [sectionIdentifiers containsObject:sectionIdentifier];

    NSArray *items = sectionExists
        ? [snapshot itemIdentifiersInSectionWithIdentifier:sectionIdentifier]
        : @[];

    NSMutableArray *newItems = [NSMutableArray array];

    switch (section) {
        case PPHomeSectionCurrentOrders:
            [newItems addObjectsFromArray:[self pp_homeCurrentOrderItems]];
            break;

        case PPHomeSectionBuyAgain:
            [newItems addObjectsFromArray:[self pp_homeBuyAgainItems]];
            break;

        case PPHomeSectionAccessories:
            for (PetAccessory *a in self.accessories) {
                PPHomeItem *item = [PPHomeItem new];
                PPUniversalCellViewModel *vm =
                    [[PPUniversalCellViewModel alloc] initWithModel:a
                                                            context:PPCellForMarket];
                vm.ModelObject = a;
                item.universalViewModel = vm;
                [newItems addObject:item];
            }
            break;

        case PPHomeSectionAdsNearBy:
            if (self.nearbyLoading && self.nearbyAds.count == 0) {
                NSInteger skeletonCount = 3;
                for (NSInteger i = 0; i < skeletonCount; i++) {
                    PPHomeItem *item = [PPHomeItem new];
                    item.universalViewModel = [[PPUniversalCellViewModel alloc] initSkeleton];
                    [newItems addObject:item];
                }
            } else if (self.nearbyAds.count == 0) {
                PPHomeItem *emptyItem = [PPHomeItem new];
                emptyItem.payload = @"nearby-empty-state";
                [newItems addObject:emptyItem];
            } else {
                for (PetAd *ad in self.nearbyAds) {
                    PPHomeItem *item = [PPHomeItem new];
                    PPUniversalCellViewModel *vm =
                        [[PPUniversalCellViewModel alloc] initWithModel:ad
                                                                context:PPCellForHomeAds];
                    vm.ModelObject = ad;
                    item.universalViewModel = vm;
                    [newItems addObject:item];
                }
            }
            break;

        case PPHomeSectionSuggestions: {
            NSMutableSet<NSString *> *seenSuggestionIDs = [NSMutableSet set];
            NSDictionary *latestEvent =
                [[PPBrowseHistoryManager shared] latestEvent];
            NSArray<NSString *> *orderedAccessoryIDs =
                [self pp_buyAgainAccessoryIDsFromOrders:self.recentOrders
                                                  limit:MAX(PPBuyAgainVisibleLimit * 2, PPBuyAgainVisibleLimit)];

            for (PetAd *ad in self.nearbyAds) {
                NSString *adID = PPSafeString(ad.adID);
                NSString *key = [NSString stringWithFormat:@"ad:%@", adID];
                if (adID.length == 0 || [seenSuggestionIDs containsObject:key]) {
                    continue;
                }
                [seenSuggestionIDs addObject:key];

                PPHomeItem *item = [PPHomeItem new];
                PPUniversalCellViewModel *vm =
                    [[PPUniversalCellViewModel alloc] initWithModel:ad
                                                            context:PPCellForHomeAds];
                vm.ModelObject = ad;
                NSDictionary<NSString *, NSString *> *reason =
                    [self pp_suggestionReasonForModel:ad
                                          latestEvent:latestEvent
                                    orderedAccessoryIDs:orderedAccessoryIDs];
                vm.contextualReasonText = PPSafeString(reason[@"text"]);
                vm.contextualReasonIconName = PPSafeString(reason[@"icon"]);
                item.universalViewModel = vm;
                [newItems addObject:item];
            }

            for (PetAccessory *acc in self.accessories) {
                NSString *accessoryID = PPSafeString(acc.accessoryID);
                NSString *key = [NSString stringWithFormat:@"acc:%@", accessoryID];
                if (accessoryID.length == 0 || [seenSuggestionIDs containsObject:key]) {
                    continue;
                }
                [seenSuggestionIDs addObject:key];

                PPHomeItem *item = [PPHomeItem new];
                PPUniversalCellViewModel *vm =
                    [[PPUniversalCellViewModel alloc] initWithModel:acc
                                                            context:PPCellForMarket];
                vm.ModelObject = acc;
                NSDictionary<NSString *, NSString *> *reason =
                    [self pp_suggestionReasonForModel:acc
                                          latestEvent:latestEvent
                                    orderedAccessoryIDs:orderedAccessoryIDs];
                vm.contextualReasonText = PPSafeString(reason[@"text"]);
                vm.contextualReasonIconName = PPSafeString(reason[@"icon"]);
                item.universalViewModel = vm;
                [newItems addObject:item];
            }
            break;
        }

        default:
            break;
    }

    if (section == PPHomeSectionCurrentOrders &&
        sectionExists &&
        items.count == newItems.count &&
        items.count == 1 &&
        [items.firstObject isKindOfClass:PPHomeItem.class] &&
        [newItems.firstObject isKindOfClass:PPHomeItem.class]) {
        PPHomeItem *existingItem = (PPHomeItem *)items.firstObject;
        PPHomeItem *replacementItem = (PPHomeItem *)newItems.firstObject;
        existingItem.type = replacementItem.type;
        existingItem.payload = replacementItem.payload;
        existingItem.universalViewModel = replacementItem.universalViewModel;
        [snapshot reloadItemsWithIdentifiers:@[existingItem]];
        [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
        [self invalidateHeaderForSection:section];
        return;
    }

    if (items.count > 0) {
        [snapshot deleteItemsWithIdentifiers:items];
    }

    if (section == PPHomeSectionBuyAgain) {
        if (!sectionExists && newItems.count > 0) {
            [snapshot appendSectionsWithIdentifiers:@[sectionIdentifier]];
            sectionExists = YES;
        } else if (sectionExists && newItems.count == 0) {
            [snapshot deleteSectionsWithIdentifiers:@[sectionIdentifier]];
            [self.dataSource applySnapshot:snapshot animatingDifferences:YES];
            return;
        } else if (!sectionExists) {
            return;
        }
    } else if (!sectionExists) {
        return;
    }

    [snapshot appendItemsWithIdentifiers:newItems
               intoSectionWithIdentifier:sectionIdentifier];

    BOOL animate = YES;

    if (section == PPHomeSectionSuggestions ||
        section == PPHomeSectionAdsNearBy ||
        section == PPHomeSectionCurrentOrders) {
        // 🔒 Prevent visual flicker on frequently refreshed sections.
        animate = NO;
        if (section == PPHomeSectionSuggestions) {
            self.didFillSuggestionsOnce = YES;
        }
    }

    [self.dataSource applySnapshot:snapshot animatingDifferences:animate];

    if (section == PPHomeSectionCurrentOrders || section == PPHomeSectionBuyAgain) {
        [self invalidateHeaderForSection:section];
    }

    // 🔒 Restore scroll position (Suggestions only)
    if (preserveOffset) {
        self.collectionView.contentOffset = preservedOffset;
    }

    // 🎯 Center last section starting from index 1 (if available)
    if (section == PPHomeSectionAdsNearBy) {
        [self pp_centerNearbySectionIfPossible];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    //[PetAccessoryManager.sharedManager pp_oneTimeSetAllAccessoriesPriceToFixedValuesWithCompletion:^(NSError * _Nullable error, NSInteger updatedCount) {

    //}];
   // [PetAdManager.sharedManager migrateImageMetaToImageItemsOnce];
    //[CartManager.sharedManager clearCart];
    self.isMainKindsExpanded = NO; // collapsed = horizontal
    self.hideServiceSection = YES;
    self.warmUpCache = NO;
    self.chatsListenerStarted = NO;
    self.view.backgroundColor = AppBackgroundClr;

    //[self pp_installBackgroundGradient];

    self.mainKinds = PPMainKindsArray;
    self.selectedCategory = nil; // nil == "All"
    self.blurHashCache = [NSCache new];
    self.blurHashCache.countLimit = 250;
    self.blurHashQueue =
    dispatch_queue_create("com.purepets.home.blurhash.decode", DISPATCH_QUEUE_CONCURRENT);
    self.selectedNearbyCoordinate = kCLLocationCoordinate2DInvalid;
    self.lastNearbyRefreshCoordinate = kCLLocationCoordinate2DInvalid;
    self.nearbyLocationState = PPNearbyLocationStateUnset;
    self.hasSelectedNearbyCoordinate = NO;
    self.hasLastNearbyRefreshCoordinate = NO;
    self.nearbyLoading = YES;
    self.nearbyRadiusKm = PPNearbyDefaultRadiusKm;
    self.currentOrders = @[];
    self.recentOrders = @[];
    self.buyAgainAccessories = @[];
    self.isCurrentOrdersExpanded = NO;
    self.currentOrdersRequestToken = 0;
    self.buyAgainRequestToken = 0;
    self.lastCurrentOrdersRefreshAt = nil;
    self.currentOrdersLoading = ([self pp_currentOrdersUserID].length > 0);
    self.currentOrdersLoaded = !self.currentOrdersLoading;
    self.homeGeocoder = [[CLGeocoder alloc] init];
    self.promoCarouselCards = PPHomePromoCarouselManager.sharedManager.cards ?: @[];
    [self configureLocationStateMachine];



    [self setupCollectionView];
    [self configureDataSource];
    [self applyBaseSnapshot];   // 🔥 NEW
    [self pp_scheduleInitialMainKindsLayoutRefresh];
    [self refreshHeroSectionAppearance];

    __weak typeof(self) weakSelf = self;
    [[PPHomePromoCarouselManager sharedManager] startListeningWithCompletion:^(NSArray<PPHomePromoCarouselCard *> * _Nullable cards, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (error) {
            NSLog(@"[HomePromoCarousel] listener error: %@", error.localizedDescription);
            return;
        }
        self.promoCarouselCards = cards ?: @[];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self fillCarouselBanner];
        });
    }];

    [self loadData];

    // 🔥 Fill top banner once banners are ready
    dispatch_async(dispatch_get_main_queue(), ^{
        [self fillCarouselBanner];
    });


    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleBrowseHistoryUpdate)
               name:@"PPBrowseHistoryDidUpdate"
             object:nil];


    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(updateCartQuantityBadge)
               name:kCartUpdatedNotification //@"PPCartDidChangeNotification"
             object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleAppWillEnterForeground)
               name:UIApplicationWillEnterForegroundNotification
             object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleAdUploadCompletedNotification:)
               name:PPAdDidFinishUploadNotification
             object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleUserProfileSyncNotification:)
               name:PPUserManagerDidSyncCurrentUserNotification
             object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleUserProfileSyncNotification:)
               name:PPUserManagerDidSignOutNotification
             object:nil];


}


- (void)handleBrowseHistoryUpdate
{
    // Update layout so header is re-requested
    [self invalidateHeaderForSection:PPHomeSectionSuggestions];
}

- (void)pp_refreshNavigationMenusForCurrentUser {
    if (@available(iOS 14.0, *)) {
        // Profile button now holds both user + app actions
        UIBarButtonItem *profileItem = self.homeProfileItem
            ?: self.navigationItem.leftBarButtonItems.firstObject
            ?: self.navigationItem.leftBarButtonItem;
        UIView *customView = profileItem.customView;
        if ([customView isKindOfClass:UIButton.class]) {
            UIButton *profileButton = (UIButton *)customView;
            UIMenu *userMenu = [PPActionButton userActionsArrayfor:self];
            UIMenu *appMenu  = [PPActionButton appActionsArrayfor:self];
            profileButton.menu = [UIMenu menuWithTitle:@""
                                                 image:nil
                                            identifier:nil
                                               options:UIMenuOptionsDisplayInline
                                              children:@[userMenu, appMenu]];
        }
    }
}

- (void)handleUserProfileSyncNotification:(NSNotification *)notification
{
    (void)notification;
    [self pp_refreshNavigationMenusForCurrentUser];
    [self refreshHeroSectionAppearance];
    [self refreshCurrentOrdersForce:YES];
}

- (NSString *)pp_currentOrdersUserID
{
    NSString *userID = @"";
    id value = UserManager.sharedManager.currentUser.ID;
    if ([value isKindOfClass:NSString.class]) {
        userID = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    if (userID.length == 0) {
        userID = [FIRAuth auth].currentUser.uid ?: @"";
    }
    return userID;
}

- (BOOL)pp_homeStatusKey:(NSString *)statusKey matchesAnyKeywords:(NSArray<NSString *> *)keywords
{
    NSString *normalizedStatus = [PPOrder normalizedStatusFromRawValue:statusKey];
    if (normalizedStatus.length == 0 || keywords.count == 0) {
        return NO;
    }

    NSString *wrappedStatus = [NSString stringWithFormat:@"_%@_", normalizedStatus];
    for (NSString *keyword in keywords) {
        NSString *normalizedKeyword = [PPOrder normalizedStatusFromRawValue:keyword];
        if (normalizedKeyword.length == 0) {
            continue;
        }
        NSString *wrappedKeyword = [NSString stringWithFormat:@"_%@_", normalizedKeyword];
        if ([wrappedStatus containsString:wrappedKeyword]) {
            return YES;
        }
    }

    return NO;
}

- (BOOL)pp_isFailureHomeOrderStatusKey:(NSString *)statusKey
{
    return [self pp_homeStatusKey:statusKey
                 matchesAnyKeywords:@[@"failed", @"rejected", @"cancelled", @"canceled", @"expired", @"voided", @"error"]];
}

- (NSString *)pp_homeOrderStatusKey:(PPOrder *)order
{
    NSString *statusKey = [PPOrder normalizedStatusFromRawValue:order.rawStatus];
    if (statusKey.length > 0) {
        return statusKey;
    }

    switch (order.status) {
        case PPOrderStatusPaid:
            return @"paid";
        case PPOrderStatusFailed:
            return @"failed";
        case PPOrderStatusPending:
        default:
            return @"pending";
    }
}

- (BOOL)pp_isActiveHomeOrder:(PPOrder *)order
{
    if (![order isKindOfClass:PPOrder.class]) {
        return NO;
    }

    NSString *statusKey = [self pp_homeOrderStatusKey:order];
    if ([self pp_isFailureHomeOrderStatusKey:statusKey]) {
        return NO;
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"delivered", @"completed", @"fulfilled"]]) {
        return NO;
    }

    return [self pp_homeStatusKey:statusKey
                 matchesAnyKeywords:@[@"pending",
                                      @"pending_collection",
                                      @"paid",
                                      @"success",
                                      @"processing",
                                      @"preparing",
                                      @"packed",
                                      @"confirmed",
                                      @"shipped",
                                      @"shipping",
                                      @"out_for_delivery",
                                      @"in_transit"]];
}

- (NSString *)pp_homeOrderStatusTitle:(PPOrder *)order
{
    NSString *statusKey = [self pp_homeOrderStatusKey:order];
    if ([self pp_isFailureHomeOrderStatusKey:statusKey]) {
        if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"cancelled", @"canceled"]]) {
            return kLang(@"Canceled");
        }
        return kLang(@"Failed");
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"delivered", @"completed", @"fulfilled"]]) {
        return kLang(@"Delivered");
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"shipped", @"shipping", @"out_for_delivery", @"in_transit"]]) {
        return kLang(@"Shipped");
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"processing", @"preparing", @"packed", @"confirmed"]]) {
        return kLang(@"Processing");
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"paid", @"success"]]) {
        return kLang(@"Paid");
    }
    return kLang(@"Pending");
}

- (NSString *)pp_homeOrderStatusHint:(PPOrder *)order
{
    NSString *statusKey = [self pp_homeOrderStatusKey:order];
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"shipped", @"shipping", @"out_for_delivery", @"in_transit"]]) {
        return kLang(@"Home_CurrentOrdersShippedHint") ?: (kLang(@"order_action_track_hint") ?: @"");
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"processing", @"preparing", @"packed", @"confirmed"]]) {
        return kLang(@"Home_CurrentOrdersProcessingHint") ?: (kLang(@"order_action_track_hint") ?: @"");
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"paid", @"success"]]) {
        return kLang(@"Home_CurrentOrdersPaidHint") ?: (kLang(@"order_action_track_hint") ?: @"");
    }
    return kLang(@"Home_CurrentOrdersPendingHint") ?: (kLang(@"order_action_track_hint") ?: @"");
}

- (UIColor *)pp_homeOrderStatusColor:(PPOrder *)order
{
    NSString *statusKey = [self pp_homeOrderStatusKey:order];
    if ([self pp_isFailureHomeOrderStatusKey:statusKey]) {
        return UIColor.systemRedColor;
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"delivered", @"completed", @"fulfilled"]]) {
        return UIColor.systemGreenColor;
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"shipped", @"shipping", @"out_for_delivery", @"in_transit"]]) {
        return UIColor.systemBlueColor;
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"processing", @"preparing", @"packed", @"confirmed"]]) {
        return UIColor.systemOrangeColor;
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"paid", @"success"]]) {
        return [GM appPrimaryColor];
    }
    return UIColor.systemOrangeColor;
}

- (NSString *)pp_homeOrderStatusIconName:(PPOrder *)order
{
    NSString *statusKey = [self pp_homeOrderStatusKey:order];
    if ([self pp_isFailureHomeOrderStatusKey:statusKey]) {
        return @"xmark.circle.fill";
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"delivered", @"completed", @"fulfilled"]]) {
        return @"checkmark.seal.fill";
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"shipped", @"shipping", @"out_for_delivery", @"in_transit"]]) {
        return @"shippedtruck";
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"processing", @"preparing", @"packed", @"confirmed"]]) {
        return @"shippingbox.circle.fill";
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"paid", @"success"]]) {
        return @"creditcard.fill";
    }
    return @"clock.fill";
}

- (double)pp_homeOrderProgress:(PPOrder *)order
{
    NSString *statusKey = [self pp_homeOrderStatusKey:order];
    if ([self pp_isFailureHomeOrderStatusKey:statusKey]) {
        return 1.0;
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"delivered", @"completed", @"fulfilled"]]) {
        return 1.0;
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"shipped", @"shipping", @"out_for_delivery", @"in_transit"]]) {
        return 0.86;
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"processing", @"preparing", @"packed", @"confirmed"]]) {
        return [order isCashOnDelivery] ? 0.56 : 0.68;
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"paid", @"success"]]) {
        return 0.38;
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"pending_collection"]]) {
        return 0.24;
    }
    return 0.16;
}

- (NSInteger)pp_homeOrderItemCount:(PPOrder *)order
{
    NSInteger totalCount = 0;
    for (id rawItem in order.items ?: @[]) {
        if ([rawItem isKindOfClass:NSDictionary.class]) {
            NSDictionary *item = (NSDictionary *)rawItem;
            id rawQty = item[@"qty"] ?: item[@"quantity"];
            NSInteger quantity = [rawQty respondsToSelector:@selector(integerValue)] ? [rawQty integerValue] : 1;
            totalCount += MAX(quantity, 1);
        } else {
            totalCount += 1;
        }
    }
    return MAX(totalCount, 0);
}

- (NSString *)pp_homeOrderAmountText:(PPOrder *)order
{
    double total = order.totalAmount;
    if (total <= 0.0) {
        total = order.amount;
    }
    if (total <= 0.0 && order.shippingFee > 0.0) {
        total = order.shippingFee;
    }
    if (total <= 0.0) {
        return @"";
    }

    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.currencyCode = order.currency.length > 0 ? order.currency : @"QAR";
    formatter.maximumFractionDigits = 2;
    formatter.minimumFractionDigits = 0;
    formatter.locale = Language.isRTL
        ? [NSLocale localeWithLocaleIdentifier:@"ar"]
        : [NSLocale localeWithLocaleIdentifier:@"en"];

    NSString *formattedAmount = [formatter stringFromNumber:@(total)];
    if (formattedAmount.length > 0) {
        return formattedAmount;
    }

    return [NSString stringWithFormat:@"%@ %.2f",
            order.currency.length > 0 ? order.currency : @"QAR",
            total];
}

- (NSString *)pp_homeOrderMetaText:(PPOrder *)order
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    NSInteger itemCount = [self pp_homeOrderItemCount:order];
    if (itemCount > 0) {
        NSString *itemsFormat = kLang(@"Home_CurrentOrdersItemsFormat") ?: @"%ld items";
        [parts addObject:[NSString stringWithFormat:itemsFormat, (long)itemCount]];
    }

    NSString *amountText = [self pp_homeOrderAmountText:order];
    if (amountText.length > 0) {
        [parts addObject:amountText];
    }

    return [parts componentsJoinedByString:@" | "];
}

- (NSString *)pp_homeRelativeDateString:(NSDate *)date
{
    if (![date isKindOfClass:NSDate.class]) {
        return @"";
    }

    if (@available(iOS 13.0, *)) {
        NSRelativeDateTimeFormatter *formatter = [[NSRelativeDateTimeFormatter alloc] init];
        formatter.unitsStyle = NSRelativeDateTimeFormatterUnitsStyleShort;
        formatter.locale = Language.isRTL
            ? [NSLocale localeWithLocaleIdentifier:@"ar"]
            : [NSLocale localeWithLocaleIdentifier:@"en"];
        return [formatter localizedStringForDate:date relativeToDate:[NSDate date]] ?: @"";
    }

    return [self pp_homeShortDateString:date];
}

- (NSString *)pp_homeShortDateString:(NSDate *)date
{
    if (![date isKindOfClass:NSDate.class]) {
        return @"";
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterNoStyle;
    formatter.locale = Language.isRTL
        ? [NSLocale localeWithLocaleIdentifier:@"ar"]
        : [NSLocale localeWithLocaleIdentifier:@"en"];
    return [formatter stringFromDate:date] ?: @"";
}

- (NSString *)pp_homeOrderFooterText:(PPOrder *)order
{
    NSDate *estimatedDate = order.estimatedDeliveryAt;
    if ([estimatedDate isKindOfClass:NSDate.class]) {
        NSString *dateText = [self pp_homeShortDateString:estimatedDate];
        if (dateText.length > 0) {
            return [NSString stringWithFormat:@"%@ %@",
                    kLang(@"Home_CurrentOrdersExpectedPrefix") ?: @"Expected",
                    dateText];
        }
    }

    NSDate *updatedDate = order.statusUpdatedAt ?: order.updatedAt ?: order.createdAt;
    NSString *relativeDate = [self pp_homeRelativeDateString:updatedDate];
    if (relativeDate.length > 0) {
        return [NSString stringWithFormat:@"%@ %@",
                kLang(@"Home_CurrentOrdersUpdatedPrefix") ?: @"Updated",
                relativeDate];
    }

    return kLang(@"order_action_track_hint") ?: @"";
}

- (NSString *)pp_homeOrderKickerTitle:(PPOrder *)order
{
    if ([self pp_isActiveHomeOrder:order]) {
        return kLang(@"Home_CurrentOrdersTitle") ?: @"Active order";
    }

    return kLang(@"Home_LastOrderTitle") ?: @"Last order";
}

- (NSString *)pp_homeOrderImageURLFromItemData:(NSDictionary *)data
{
    if (![data isKindOfClass:NSDictionary.class]) {
        return @"";
    }

    NSArray<NSString *> *valueKeys = @[@"image", @"imageURL", @"imageUrl", @"photo", @"icon"];
    for (NSString *key in valueKeys) {
        NSString *value = PPSafeString(data[key]);
        value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (value.length > 0) {
            return value;
        }
    }

    NSArray<NSString *> *arrayKeys = @[@"imageURLsArray", @"imageURLs", @"images"];
    for (NSString *key in arrayKeys) {
        id rawValue = data[key];
        if (![rawValue isKindOfClass:NSArray.class]) {
            continue;
        }

        for (id item in (NSArray *)rawValue) {
            NSString *value = PPSafeString(item);
            value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (value.length > 0) {
                return value;
            }
        }
    }

    return @"";
}

- (NSArray<NSString *> *)pp_homeOrderPreviewImageURLs:(PPOrder *)order limit:(NSInteger)limit
{
    if (![order isKindOfClass:PPOrder.class] || limit == 0) {
        return @[];
    }

    NSMutableDictionary<NSString *, PetAccessory *> *resolvedByID = [NSMutableDictionary dictionary];
    for (PetAccessory *accessory in self.accessories ?: @[]) {
        if (![accessory isKindOfClass:PetAccessory.class]) {
            continue;
        }

        NSString *accessoryID = PPSafeString(accessory.accessoryID);
        accessoryID = [accessoryID stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (accessoryID.length == 0) {
            continue;
        }

        resolvedByID[accessoryID] = accessory;
    }

    NSInteger cappedLimit = MAX(limit, 0);
    NSMutableOrderedSet<NSString *> *orderedURLs = [NSMutableOrderedSet orderedSet];
    for (id rawItem in order.items ?: @[]) {
        NSString *imageURL = @"";
        if ([rawItem isKindOfClass:NSDictionary.class]) {
            NSDictionary *itemData = (NSDictionary *)rawItem;
            imageURL = [self pp_homeOrderImageURLFromItemData:itemData];

            if (imageURL.length == 0) {
                NSDictionary *nestedItemData =
                    [itemData[@"product"] isKindOfClass:NSDictionary.class] ? itemData[@"product"] :
                    ([itemData[@"item"] isKindOfClass:NSDictionary.class] ? itemData[@"item"] : nil);
                if (nestedItemData) {
                    imageURL = [self pp_homeOrderImageURLFromItemData:nestedItemData];
                }
            }
        }

        if (imageURL.length == 0) {
            NSString *itemID = [self pp_homeOrderItemIdentifier:rawItem];
            PetAccessory *accessory = resolvedByID[itemID];
            if ([accessory isKindOfClass:PetAccessory.class] &&
                [accessory.imageURLsArray isKindOfClass:NSArray.class] &&
                accessory.imageURLsArray.count > 0) {
                imageURL = PPSafeString(accessory.imageURLsArray.firstObject);
            }
        }

        imageURL = [imageURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (imageURL.length == 0 || [orderedURLs containsObject:imageURL]) {
            continue;
        }

        [orderedURLs addObject:imageURL];
        if (cappedLimit > 0 && orderedURLs.count >= cappedLimit) {
            break;
        }
    }

    return orderedURLs.array;
}

- (BOOL)pp_hasOtherRecentHomeOrdersWithinInterval:(NSTimeInterval)interval excludingOrder:(PPOrder *)order
{
    NSString *excludedOrderID = [order isKindOfClass:PPOrder.class] ? PPSafeString(order.orderId) : @"";
    NSDate *now = [NSDate date];

    for (PPOrder *candidate in self.recentOrders ?: @[]) {
        if (![candidate isKindOfClass:PPOrder.class]) {
            continue;
        }

        NSString *candidateOrderID = PPSafeString(candidate.orderId);
        if (excludedOrderID.length > 0 && [candidateOrderID isEqualToString:excludedOrderID]) {
            continue;
        }

        NSDate *activityDate = candidate.statusUpdatedAt ?: candidate.updatedAt ?: candidate.createdAt;
        if (![activityDate isKindOfClass:NSDate.class]) {
            continue;
        }

        NSTimeInterval elapsed = [now timeIntervalSinceDate:activityDate];
        if (elapsed <= interval) {
            return YES;
        }
    }

    return NO;
}

- (NSString *)pp_completedLastHomeOrderSeenOrderIDDefaultsKey
{
    NSString *userID = [self pp_currentOrdersUserID];
    if (userID.length == 0) {
        return PPHomeCompletedLastOrderSeenOrderIDKeyPrefix;
    }
    return [NSString stringWithFormat:@"%@.%@", PPHomeCompletedLastOrderSeenOrderIDKeyPrefix, userID];
}

- (NSString *)pp_completedLastHomeOrderSeenSessionDefaultsKey
{
    NSString *userID = [self pp_currentOrdersUserID];
    if (userID.length == 0) {
        return PPHomeCompletedLastOrderSeenSessionIDKeyPrefix;
    }
    return [NSString stringWithFormat:@"%@.%@", PPHomeCompletedLastOrderSeenSessionIDKeyPrefix, userID];
}

- (BOOL)pp_shouldHideCompletedLastHomeOrder:(PPOrder *)order
{
    if (![order isKindOfClass:PPOrder.class]) {
        return YES;
    }

    NSString *statusKey = [self pp_homeOrderStatusKey:order];
    if (![self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"delivered", @"completed", @"fulfilled"]]) {
        return NO;
    }

    NSDate *completedDate = order.statusUpdatedAt ?: order.updatedAt ?: order.createdAt;
    if (![completedDate isKindOfClass:NSDate.class]) {
        return NO;
    }

    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:completedDate];
    if (elapsed > PPHomeCompletedLastOrderVisibilityInterval) {
        return YES;
    }

    BOOL hasOtherRecentOrders =
        [self pp_hasOtherRecentHomeOrdersWithinInterval:PPHomeOtherOrdersRecentLookbackInterval
                                         excludingOrder:order];
    if (hasOtherRecentOrders) {
        return NO;
    }

    NSString *orderID = PPSafeString(order.orderId);
    if (orderID.length == 0) {
        return NO;
    }

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *storedOrderID = [defaults stringForKey:[self pp_completedLastHomeOrderSeenOrderIDDefaultsKey]] ?: @"";
    NSString *storedSessionID = [defaults stringForKey:[self pp_completedLastHomeOrderSeenSessionDefaultsKey]] ?: @"";
    NSString *currentSessionID = PPHomeCurrentAppSessionIdentifier();

    BOOL wasShownInPreviousLaunch =
        [storedOrderID isEqualToString:orderID] &&
        storedSessionID.length > 0 &&
        ![storedSessionID isEqualToString:currentSessionID];
    if (wasShownInPreviousLaunch) {
        return YES;
    }

    [defaults setObject:orderID forKey:[self pp_completedLastHomeOrderSeenOrderIDDefaultsKey]];
    [defaults setObject:currentSessionID forKey:[self pp_completedLastHomeOrderSeenSessionDefaultsKey]];
    return NO;
}

- (BOOL)pp_isTerminalHomeOrderStatusKey:(NSString *)statusKey
{
    return [self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"success", @"paid"]]
        || [self pp_isFailureHomeOrderStatusKey:statusKey];
}

- (NSString *)pp_terminalHomeOrderSeenOrderIDDefaultsKey
{
    NSString *userID = [self pp_currentOrdersUserID];
    if (userID.length == 0) {
        return PPHomeTerminalOrderSeenOrderIDKeyPrefix;
    }
    return [NSString stringWithFormat:@"%@.%@", PPHomeTerminalOrderSeenOrderIDKeyPrefix, userID];
}

- (NSString *)pp_terminalHomeOrderSeenSessionDefaultsKey
{
    NSString *userID = [self pp_currentOrdersUserID];
    if (userID.length == 0) {
        return PPHomeTerminalOrderSeenSessionIDKeyPrefix;
    }
    return [NSString stringWithFormat:@"%@.%@", PPHomeTerminalOrderSeenSessionIDKeyPrefix, userID];
}

- (BOOL)pp_shouldHideTerminalHomeOrder:(PPOrder *)order
{
    if (![order isKindOfClass:PPOrder.class]) {
        return NO;
    }

    NSString *statusKey = [self pp_homeOrderStatusKey:order];
    if (![self pp_isTerminalHomeOrderStatusKey:statusKey]) {
        return NO;
    }

    NSString *orderID = PPSafeString(order.orderId);
    if (orderID.length == 0) {
        return NO;
    }

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *storedOrderID = [defaults stringForKey:[self pp_terminalHomeOrderSeenOrderIDDefaultsKey]] ?: @"";
    NSString *storedSessionID = [defaults stringForKey:[self pp_terminalHomeOrderSeenSessionDefaultsKey]] ?: @"";
    NSString *currentSessionID = PPHomeCurrentAppSessionIdentifier();

    BOOL wasShownInPreviousLaunch =
        [storedOrderID isEqualToString:orderID] &&
        storedSessionID.length > 0 &&
        ![storedSessionID isEqualToString:currentSessionID];
    if (wasShownInPreviousLaunch) {
        return YES;
    }

    [defaults setObject:orderID forKey:[self pp_terminalHomeOrderSeenOrderIDDefaultsKey]];
    [defaults setObject:currentSessionID forKey:[self pp_terminalHomeOrderSeenSessionDefaultsKey]];
    return NO;
}

- (nullable PPOrder *)pp_featuredHomeOrder
{
    id activeOrder = self.currentOrders.firstObject;
    if ([activeOrder isKindOfClass:PPOrder.class]) {
        PPOrder *order = (PPOrder *)activeOrder;

        if ([self pp_shouldHideTerminalHomeOrder:order]) {
            return nil;
        }

        if ([self pp_isActiveHomeOrder:order]) {
            return order;
        }

        NSDate *createdDate = order.createdAt ?: order.updatedAt;
        if ([createdDate isKindOfClass:NSDate.class]) {
            NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:createdDate];
            if (elapsed <= PPHomeCompletedLastOrderVisibilityInterval) {
                return order;
            }
        }
    }

    return nil;
}

- (NSArray<PPHomeItem *> *)pp_homeCurrentOrderItems
{
    NSMutableArray<PPHomeItem *> *items = [NSMutableArray array];
    PPOrder *featuredOrder = [self pp_featuredHomeOrder];

    if (self.currentOrdersLoading && !featuredOrder) {
        PPHomeItem *placeholderItem =
            [[PPHomeItem alloc] initWithType:PPHomeItemTypeCurrentOrder payload:[NSNull null]];
        [items addObject:placeholderItem];
        return items.copy;
    }

    if (featuredOrder) {
        PPHomeItem *item =
            [[PPHomeItem alloc] initWithType:PPHomeItemTypeCurrentOrder payload:featuredOrder];
        [items addObject:item];
    }

    return items.copy;
}

- (NSArray<PPHomeItem *> *)pp_homeBuyAgainItems
{
    NSMutableArray<PPHomeItem *> *items = [NSMutableArray array];

    for (PetAccessory *accessory in self.buyAgainAccessories ?: @[]) {
        if (![accessory isKindOfClass:PetAccessory.class]) {
            continue;
        }

        PPUniversalCellViewModel *vm =
            [[PPUniversalCellViewModel alloc] initWithModel:accessory
                                                    context:PPCellForMarket];
        vm.ModelObject = accessory;

        PPHomeItem *item =
            [[PPHomeItem alloc] initWithType:PPHomeItemTypeBuyAgain
                               universalModel:vm];
        [items addObject:item];
    }

    return items.copy;
}

- (NSString *)pp_homeOrderItemIdentifier:(id)rawItem
{
    if ([rawItem isKindOfClass:NSString.class]) {
        return [(NSString *)rawItem stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }

    if (![rawItem isKindOfClass:NSDictionary.class]) {
        return @"";
    }

    NSDictionary *item = (NSDictionary *)rawItem;
    NSArray<NSString *> *candidateKeys = @[@"id", @"itemID", @"productId", @"productID"];
    for (NSString *key in candidateKeys) {
        NSString *value = [item[key] isKindOfClass:NSString.class] ? item[key] : @"";
        value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (value.length > 0) {
            return value;
        }
    }

    return @"";
}

- (NSArray<NSString *> *)pp_buyAgainAccessoryIDsFromOrders:(NSArray<PPOrder *> *)orders
                                                     limit:(NSInteger)limit
{
    NSMutableOrderedSet<NSString *> *orderedIDs = [NSMutableOrderedSet orderedSet];

    for (PPOrder *order in orders ?: @[]) {
        if (![order isKindOfClass:PPOrder.class]) {
            continue;
        }

        NSString *statusKey = [self pp_homeOrderStatusKey:order];
        if ([self pp_isFailureHomeOrderStatusKey:statusKey]) {
            continue;
        }

        for (id rawItem in order.items ?: @[]) {
            NSString *itemID = [self pp_homeOrderItemIdentifier:rawItem];
            if (itemID.length == 0) {
                continue;
            }

            [orderedIDs addObject:itemID];
            if (limit > 0 && orderedIDs.count >= limit) {
                return orderedIDs.array;
            }
        }
    }

    return orderedIDs.array;
}

- (NSArray<PetAccessory *> *)pp_orderedBuyAgainAccessoriesFromResolvedByID:(NSDictionary<NSString *, PetAccessory *> *)resolvedByID
                                                                 orderedIDs:(NSArray<NSString *> *)orderedIDs
                                                                      limit:(NSInteger)limit
{
    NSMutableArray<PetAccessory *> *orderedAccessories = [NSMutableArray array];
    NSMutableSet<NSString *> *seenAccessoryIDs = [NSMutableSet set];

    for (NSString *itemID in orderedIDs ?: @[]) {
        PetAccessory *accessory = resolvedByID[itemID];
        if (![accessory isKindOfClass:PetAccessory.class]) {
            continue;
        }

        NSString *accessoryID = PPSafeString(accessory.accessoryID);
        if (accessoryID.length == 0 || [seenAccessoryIDs containsObject:accessoryID]) {
            continue;
        }

        if (accessory.quantity <= 0) {
            continue;
        }

        [seenAccessoryIDs addObject:accessoryID];
        [orderedAccessories addObject:accessory];

        if (limit > 0 && orderedAccessories.count >= limit) {
            break;
        }
    }

    return orderedAccessories.copy;
}

- (void)pp_refreshBuyAgainSection
{
    NSArray<NSString *> *orderedIDs =
        [self pp_buyAgainAccessoryIDsFromOrders:self.recentOrders
                                          limit:MAX(PPBuyAgainVisibleLimit * 2, PPBuyAgainVisibleLimit)];

    self.buyAgainRequestToken += 1;
    NSInteger requestToken = self.buyAgainRequestToken;

    if (orderedIDs.count == 0) {
        self.buyAgainAccessories = @[];
        if (self.dataSource) {
            [self reloadSection:PPHomeSectionBuyAgain];
        }
        return;
    }

    NSMutableDictionary<NSString *, PetAccessory *> *resolvedByID = [NSMutableDictionary dictionary];
    for (PetAccessory *accessory in self.accessories ?: @[]) {
        if (![accessory isKindOfClass:PetAccessory.class]) {
            continue;
        }

        NSString *accessoryID = PPSafeString(accessory.accessoryID);
        if (accessoryID.length == 0) {
            continue;
        }
        resolvedByID[accessoryID] = accessory;
    }

    NSMutableArray<NSString *> *missingIDs = [NSMutableArray array];
    for (NSString *itemID in orderedIDs) {
        if (itemID.length == 0 || resolvedByID[itemID] != nil) {
            continue;
        }
        [missingIDs addObject:itemID];
    }

    void (^applyResolvedAccessories)(NSDictionary<NSString *, PetAccessory *> *) =
    ^(NSDictionary<NSString *, PetAccessory *> *resolved) {
        NSArray<PetAccessory *> *orderedAccessories =
            [self pp_orderedBuyAgainAccessoriesFromResolvedByID:resolved
                                                      orderedIDs:orderedIDs
                                                           limit:PPBuyAgainVisibleLimit];
        self.buyAgainAccessories = orderedAccessories;
        if (self.dataSource) {
            [self reloadSection:PPHomeSectionBuyAgain];
        }
    };

    if (missingIDs.count == 0) {
        applyResolvedAccessories(resolvedByID.copy);
        return;
    }

    __weak typeof(self) weakSelf = self;
    [PetAccessoryManager fetchAccessoriesWithIDs:missingIDs
                                      completion:^(NSArray<PetAccessory *> *accessories) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (requestToken != self.buyAgainRequestToken) {
            return;
        }

        NSMutableDictionary<NSString *, PetAccessory *> *mergedByID = resolvedByID.mutableCopy;
        for (PetAccessory *accessory in accessories ?: @[]) {
            if (![accessory isKindOfClass:PetAccessory.class]) {
                continue;
            }

            NSString *accessoryID = PPSafeString(accessory.accessoryID);
            if (accessoryID.length == 0) {
                continue;
            }
            mergedByID[accessoryID] = accessory;
        }

        applyResolvedAccessories(mergedByID.copy);
    }];
}

- (void)pp_openOrderDetailsForOrder:(PPOrder *)order
{
    if (![order isKindOfClass:PPOrder.class]) {
        return;
    }

    OrderDetailsViewController *detailsVC =
        [[OrderDetailsViewController alloc] initWithOrder:order];
    detailsVC.order = order;
    [PPHomeHelper pushViewControllerSafely:detailsVC from:self animated:YES];
}

- (void)refreshCurrentOrdersForce:(BOOL)force
{
    NSString *userID = [self pp_currentOrdersUserID];
    if (userID.length == 0) {
        self.currentOrdersRequestToken += 1;
        [self pp_stopCurrentOrdersListener];
        self.currentOrders = @[];
        self.recentOrders = @[];
        self.buyAgainAccessories = @[];
        self.currentOrdersLoading = NO;
        self.currentOrdersLoaded = YES;
        self.lastCurrentOrdersRefreshAt = nil;
        if (self.dataSource) {
            [self reloadSection:PPHomeSectionCurrentOrders];
            [self reloadSection:PPHomeSectionBuyAgain];
        }
        return;
    }

    BOOL listenerMatchesCurrentUser =
        self.currentOrdersQueryListener != nil &&
        [self.currentOrdersListenerUserID isEqualToString:userID];
    if (listenerMatchesCurrentUser && !force) {
        return;
    }

    self.currentOrdersRequestToken += 1;
    NSInteger requestToken = self.currentOrdersRequestToken;
    [self pp_stopCurrentOrdersListener];
    self.currentOrdersListenerUserID = userID;
    self.currentOrdersLoading = YES;
    self.currentOrdersLoaded = NO;

    if (self.currentOrders.count == 0 && self.dataSource) {
        [self reloadSection:PPHomeSectionCurrentOrders];
    }

    [self pp_startCurrentOrdersListenerForUserID:userID requestToken:requestToken];
}

- (void)pp_stopCurrentOrdersListener
{
    [self.currentOrdersQueryListener remove];
    self.currentOrdersQueryListener = nil;
    self.currentOrdersListenerUserID = @"";
}

- (void)pp_startCurrentOrdersListenerForUserID:(NSString *)userID requestToken:(NSInteger)requestToken
{
    if (userID.length == 0) {
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRQuery *query = [[db collectionWithPath:@"Orders"] queryWhereField:@"userId" isEqualTo:userID];
    query = [query queryOrderedByField:@"createdAt" descending:YES];
    query = [query queryLimitedTo:12];

    __weak typeof(self) weakSelf = self;
    self.currentOrdersQueryListener =
    [query addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            if (requestToken != self.currentOrdersRequestToken) {
                return;
            }

            if (error) {
                self.currentOrdersLoading = NO;
                self.currentOrdersLoaded = YES;
                NSLog(@"[Home][CurrentOrders] fetch failed: %@", error.localizedDescription ?: @"Unknown error");
                [self reloadSection:PPHomeSectionCurrentOrders];
                [self pp_refreshBuyAgainSection];
                return;
            }

            [self pp_applyCurrentOrdersSnapshot:snapshot requestToken:requestToken];
        });
    }];
}

- (void)pp_applyCurrentOrdersSnapshot:(FIRQuerySnapshot *)snapshot requestToken:(NSInteger)requestToken
{
    if (requestToken != self.currentOrdersRequestToken) {
        return;
    }

    self.currentOrdersLoading = NO;
    self.currentOrdersLoaded = YES;
    self.lastCurrentOrdersRefreshAt = [NSDate date];

    NSMutableArray<PPOrder *> *recentOrders = [NSMutableArray array];
    NSMutableArray<PPOrder *> *resolvedOrders = [NSMutableArray array];
    for (FIRDocumentSnapshot *document in snapshot.documents ?: @[]) {
        PPOrder *order = [PPOrder orderFromSnapshot:document];
        if (![order isKindOfClass:PPOrder.class]) {
            continue;
        }
        [recentOrders addObject:order];
        if (![self pp_isActiveHomeOrder:order]) {
            continue;
        }
        if (resolvedOrders.count >= PPCurrentOrdersVisibleLimit) {
            continue;
        }
        [resolvedOrders addObject:order];
    }

    self.recentOrders = recentOrders.copy;
    self.currentOrders = resolvedOrders.copy;

    PPOrder *featuredOrder = [self pp_featuredHomeOrder];
    NSString *nextObservedOrderID = [featuredOrder isKindOfClass:PPOrder.class]
        ? PPSafeString(featuredOrder.orderId)
        : @"";
    NSString *nextObservedStatusKey = [featuredOrder isKindOfClass:PPOrder.class]
        ? [self pp_homeOrderStatusKey:featuredOrder]
        : @"";
    NSString *previousOrderID = PPSafeString(self.lastObservedHomeOrderID);
    NSString *previousStatusKey = PPSafeString(self.lastObservedHomeOrderStatusKey);

    BOOL shouldPlayStatusFeedback = self.isHomeScreenVisible &&
                                    previousOrderID.length > 0 &&
                                    nextObservedOrderID.length > 0 &&
                                    [previousOrderID isEqualToString:nextObservedOrderID] &&
                                    previousStatusKey.length > 0 &&
                                    nextObservedStatusKey.length > 0 &&
                                    ![previousStatusKey isEqualToString:nextObservedStatusKey];
    if (shouldPlayStatusFeedback) {
        AudioServicesPlaySystemSound(1110);
    }

    self.lastObservedHomeOrderID = nextObservedOrderID;
    self.lastObservedHomeOrderStatusKey = nextObservedStatusKey;
    [self reloadSection:PPHomeSectionCurrentOrders];
    [self pp_refreshBuyAgainSection];
    // Refresh hero peek strip to reflect order changes
    [self refreshHeroSectionAppearance];
}

- (void)persistNearbyLocationIfNeeded
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (self.hasSelectedNearbyCoordinate &&
        CLLocationCoordinate2DIsValid(self.selectedNearbyCoordinate) &&
        isfinite(self.selectedNearbyCoordinate.latitude) &&
        isfinite(self.selectedNearbyCoordinate.longitude)) {
        [defaults setDouble:self.selectedNearbyCoordinate.latitude forKey:PPNearbySelectedLatitudeKey];
        [defaults setDouble:self.selectedNearbyCoordinate.longitude forKey:PPNearbySelectedLongitudeKey];
        [defaults setObject:self.selectedNearbyAreaName ?: @"" forKey:PPNearbySelectedAreaNameKey];
    } else {
        [defaults removeObjectForKey:PPNearbySelectedLatitudeKey];
        [defaults removeObjectForKey:PPNearbySelectedLongitudeKey];
        [defaults removeObjectForKey:PPNearbySelectedAreaNameKey];
    }
}

- (void)startNearbyRefreshTimerIfNeeded
{
    if (self.nearbyRefreshTimer) return;

    __weak typeof(self) weakSelf = self;
    self.nearbyRefreshTimer =
    [NSTimer scheduledTimerWithTimeInterval:90.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self refreshNearbyAdsForce:NO reason:@"periodic"];
    }];
}

- (void)stopNearbyRefreshTimer
{
    [self.nearbyRefreshTimer invalidate];
    self.nearbyRefreshTimer = nil;
}

- (void)configureLocationStateMachine
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([defaults objectForKey:PPNearbySelectedLatitudeKey] &&
        [defaults objectForKey:PPNearbySelectedLongitudeKey]) {
        CLLocationCoordinate2D persisted =
            CLLocationCoordinate2DMake([defaults doubleForKey:PPNearbySelectedLatitudeKey],
                                       [defaults doubleForKey:PPNearbySelectedLongitudeKey]);
        if (CLLocationCoordinate2DIsValid(persisted) &&
            !(fabs(persisted.latitude) < DBL_EPSILON && fabs(persisted.longitude) < DBL_EPSILON)) {
            self.selectedNearbyCoordinate = persisted;
            self.hasSelectedNearbyCoordinate = YES;
            self.selectedNearbyAreaName = [defaults stringForKey:PPNearbySelectedAreaNameKey] ?: @"";
            self.nearbyLocationState = PPNearbyLocationStateReady;
        }
    }

    self.homeLocationManager = [[CLLocationManager alloc] init];
    self.homeLocationManager.delegate = self;
    self.homeLocationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    self.homeLocationManager.distanceFilter = 75.0;

    CLAuthorizationStatus status;
    if (@available(iOS 14.0, *)) {
        status = self.homeLocationManager.authorizationStatus;
    } else {
        status = [CLLocationManager authorizationStatus];
    }
    [self updateLocationStateForAuthorizationStatus:status];
}

- (BOOL)pp_canUseSimulatedNearbyLocation
{
#if DEBUG
#if TARGET_OS_SIMULATOR
    return YES;
#else
    return NO;
#endif
#else
    return NO;
#endif
}

- (void)pp_applySimulatedNearbyLocationAndRefreshWithReason:(NSString *)reason
{
    if (![self pp_canUseSimulatedNearbyLocation]) {
        return;
    }

    CLLocationCoordinate2D coordinate = self.selectedNearbyCoordinate;
    if (!CLLocationCoordinate2DIsValid(coordinate) ||
        (fabs(coordinate.latitude) < DBL_EPSILON && fabs(coordinate.longitude) < DBL_EPSILON)) {
        coordinate = PPNearbyDebugSimulatorCoordinate;
    }
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        return;
    }

    NSString *areaName = PPSafeString(self.selectedNearbyAreaName);
    if (areaName.length == 0) {
        CountryModel *country = CitiesManager.shared.CurrentCountry;
        CityModel *defaultCity = [CitiesManager.shared defaultCityForCountry:country];
        if (defaultCity.name.length > 0) {
            areaName = defaultCity.name;
        } else {
            areaName = kLang(@"Select your location") ?: @"Select your location";
        }
    }

    self.selectedNearbyCoordinate = coordinate;
    self.hasSelectedNearbyCoordinate = YES;
    self.selectedNearbyAreaName = areaName;
    self.nearbyLocationState = PPNearbyLocationStateReady;
    self.nearbyRadiusKm = PPNearbyDefaultRadiusKm;
    [self pp_recordRecentNearbyLocationCoordinate:coordinate
                                            title:areaName
                                           source:@"simulator"];
    [self persistNearbyLocationIfNeeded];
    [self refreshHeroSectionAppearance];
    [self refreshNearbyAdsForce:YES reason:(reason.length > 0 ? reason : @"simulator-location")];
}

- (void)updateLocationStateForAuthorizationStatus:(CLAuthorizationStatus)status
{
    // ⚠️ Do NOT call +locationServicesEnabled on main thread repeatedly.
    // Rely on authorization status changes instead.
    // If services are globally disabled, the status will be Denied/Restricted.

    if (status == kCLAuthorizationStatusDenied ||
        status == kCLAuthorizationStatusRestricted) {

        if (!self.hasSelectedNearbyCoordinate && [self pp_canUseSimulatedNearbyLocation]) {
            [self pp_applySimulatedNearbyLocationAndRefreshWithReason:@"simulator-denied"];
            return;
        }

        self.nearbyLocationState = self.hasSelectedNearbyCoordinate
            ? PPNearbyLocationStateReady
            : PPNearbyLocationStateDenied;

        [self refreshHeroSectionAppearance];
        return;
    }

    switch (status) {
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            self.nearbyLocationState = (self.hasSelectedNearbyCoordinate || self.isUsingManualNearbySelection)
                ? PPNearbyLocationStateReady
                : PPNearbyLocationStateLoading;
            if (!self.isUsingManualNearbySelection) {
                [self requestCurrentLocationIfNeeded];
            }
            break;

        case kCLAuthorizationStatusDenied:
        case kCLAuthorizationStatusRestricted:
            self.nearbyLocationState = self.hasSelectedNearbyCoordinate
                ? PPNearbyLocationStateReady
                : PPNearbyLocationStateDenied;
            break;

        case kCLAuthorizationStatusNotDetermined:
            self.nearbyLocationState = self.hasSelectedNearbyCoordinate
                ? PPNearbyLocationStateReady
                : PPNearbyLocationStateLoading;
            if (!self.hasRequestedLocationAuthorization) {
                self.hasRequestedLocationAuthorization = YES;
                [self.homeLocationManager requestWhenInUseAuthorization];
            }
            break;
    }

    [self refreshHeroSectionAppearance];
    [self startNearbyRefreshTimerIfNeeded];
    BOOL shouldForceRefresh = (self.nearbyAds.count == 0);
    [self refreshNearbyAdsForce:shouldForceRefresh
                         reason:@"viewDidAppear"];
}

- (void)requestCurrentLocationIfNeeded
{
    if (!self.homeLocationManager) return;
    if (self.isUsingManualNearbySelection) return;
    [self.homeLocationManager requestLocation];
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager API_AVAILABLE(ios(14.0))
{
    [self updateLocationStateForAuthorizationStatus:manager.authorizationStatus];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    [self updateLocationStateForAuthorizationStatus:status];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    if (self.isUsingManualNearbySelection) {
        return;
    }

    CLLocation *latest = locations.lastObject;
    if (!latest) return;

    CLLocationCoordinate2D coordinate = latest.coordinate;
    if (!CLLocationCoordinate2DIsValid(coordinate)) return;
    if (fabs(coordinate.latitude) < DBL_EPSILON && fabs(coordinate.longitude) < DBL_EPSILON) return;

    if (!self.hasSelectedNearbyCoordinate) {
        self.selectedNearbyCoordinate = coordinate;
        self.hasSelectedNearbyCoordinate = YES;
    }

    [self.homeGeocoder cancelGeocode];
    __weak typeof(self) weakSelf = self;
    CLLocation *location = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
    [self.homeGeocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        NSString *area = self.selectedNearbyAreaName;
        CLPlacemark *placemark = placemarks.firstObject;
        if (!error && placemark) {
            NSString *locality = placemark.locality ?: placemark.subLocality;
            NSString *admin = placemark.administrativeArea;
            if (locality.length > 0 && admin.length > 0 && ![locality isEqualToString:admin]) {
                area = [NSString stringWithFormat:@"%@, %@", locality, admin];
            } else if (locality.length > 0) {
                area = locality;
            } else if (admin.length > 0) {
                area = admin;
            }
        }

        if (area.length == 0) {
            area = kLang(@"Select your location");
        }

        self.selectedNearbyCoordinate = coordinate;
        self.selectedNearbyAreaName = area;
        self.hasSelectedNearbyCoordinate = YES;
        self.nearbyLocationState = PPNearbyLocationStateReady;
        [self pp_recordRecentNearbyLocationCoordinate:coordinate
                                                title:area
                                               source:@"gps"];
        [self persistNearbyLocationIfNeeded];
        [self refreshHeroSectionAppearance];
        [self refreshNearbyAdsForce:YES reason:@"location-updated"];
    }];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"[HomeNearby] location failed: %@", error.localizedDescription);
    if (!self.hasSelectedNearbyCoordinate) {
        if ([self pp_canUseSimulatedNearbyLocation]) {
            [self pp_applySimulatedNearbyLocationAndRefreshWithReason:@"simulator-fail"];
            return;
        }
        self.nearbyLocationState = PPNearbyLocationStateDenied;
        [self refreshHeroSectionAppearance];
    }
}

- (void)openHomeLocationPicker
{
    LocationPickerViewController *picker = [[LocationPickerViewController alloc] init];
    if (self.hasSelectedNearbyCoordinate && CLLocationCoordinate2DIsValid(self.selectedNearbyCoordinate)) {
        picker.initialCoordinate = self.selectedNearbyCoordinate;
    }
    __weak typeof(self) weakSelf = self;
    void (^applyPickedCoordinate)(CLLocationCoordinate2D, NSString *) =
    ^(CLLocationCoordinate2D coordinate, NSString *resolvedTitle) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (!CLLocationCoordinate2DIsValid(coordinate) ||
            (fabs(coordinate.latitude) < DBL_EPSILON && fabs(coordinate.longitude) < DBL_EPSILON)) {
            return;
        }

        NSString *resolvedAreaName = PPSafeString(resolvedTitle);
        if (resolvedAreaName.length == 0) {
            resolvedAreaName = kLang(@"Select your location") ?: @"Select your location";
        }
        self.isUsingManualNearbySelection = YES;
        self.selectedNearbyCoordinate = coordinate;
        self.hasSelectedNearbyCoordinate = YES;
        self.selectedNearbyAreaName = resolvedAreaName;
        self.nearbyLocationState = PPNearbyLocationStateReady;
        self.nearbyRadiusKm = PPNearbyDefaultRadiusKm;
        [self pp_recordRecentNearbyLocationCoordinate:coordinate
                                                title:resolvedAreaName
                                               source:@"manual"];
        [self persistNearbyLocationIfNeeded];
        [self refreshHeroSectionAppearance];
        [self refreshNearbyAdsForce:YES reason:@"manual-picker"];
    };
    picker.onLocationConfirmed = ^(GMSAddress *gmsAddress) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !gmsAddress) return;

        NSString *resolvedAreaName = [LocationPickerViewController titleFromAddress:gmsAddress] ?: @"";
        if (resolvedAreaName.length == 0 && gmsAddress.lines.count > 0) {
            resolvedAreaName = [gmsAddress.lines componentsJoinedByString:@", "] ?: @"";
        }
        if (resolvedAreaName.length == 0) {
            resolvedAreaName = gmsAddress.country ?: @"";
        }
        applyPickedCoordinate(gmsAddress.coordinate, resolvedAreaName);
    };
    picker.onCoordinateConfirmed = ^(CLLocationCoordinate2D coordinate, NSString *locationTitle) {
        applyPickedCoordinate(coordinate, locationTitle);
    };
    if (self.navigationController) {
        [self.navigationController pushViewController:picker animated:YES];
    } else {
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
        [self presentViewController:nav animated:YES completion:nil];
    }
}

- (void)presentHomeLocationOptions
{
    [self presentHomeLocationSheet];
}

- (void)presentHomeLocationSheet
{
    if ([self.presentedViewController isKindOfClass:PPHomeLocationSheetViewController.class]) {
        return;
    }

    PPHomeLocationSheetViewController *sheet = [[PPHomeLocationSheetViewController alloc] init];
    sheet.sheetTitleText = kLang(@"home_location_sheet_title") ?: @"Choose your smart location";
    sheet.sheetSubtitleText = kLang(@"home_location_sheet_subtitle") ?: @"Switch between your live GPS position and recent areas quickly, while keeping nearby discovery smooth.";
    sheet.currentLocationTitle = [self heroCountryText];

    NSString *currentSubtitleKey = @"home_location_sheet_current_subtitle_unset";
    if (self.nearbyLocationState == PPNearbyLocationStateDenied) {
        currentSubtitleKey = @"home_location_sheet_current_subtitle_denied";
    } else if (self.isUsingManualNearbySelection) {
        currentSubtitleKey = @"home_location_sheet_current_subtitle_manual";
    } else if (self.nearbyLocationState == PPNearbyLocationStateReady) {
        currentSubtitleKey = @"home_location_sheet_current_subtitle_auto";
    }
    sheet.currentLocationSubtitle = kLang(currentSubtitleKey) ?: @"";
    sheet.showsUseCurrentLocationAction = (self.nearbyLocationState != PPNearbyLocationStateDenied);
    sheet.showsOpenSettingsAction = (self.nearbyLocationState == PPNearbyLocationStateDenied);
    sheet.recentLocations = [self pp_recentNearbyLocationRecords];

    __weak typeof(self) weakSelf = self;
    sheet.onUseCurrentLocation = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self switchHomeLocationBackToAutomatic];
    };
    sheet.onChangeArea = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self openHomeLocationPicker];
    };
    sheet.onOpenSettings = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self openLocationSettings];
    };
    sheet.onSelectRecentLocation = ^(NSDictionary *locationRecord) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self pp_applyNearbyLocationRecord:locationRecord];
    };

    [self pp_emitSoftImpactHaptic];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)switchHomeLocationBackToAutomatic
{
    self.isUsingManualNearbySelection = NO;
    [self pp_emitSelectionHaptic];
    if (!self.homeLocationManager) {
        [self refreshHeroSectionAppearance];
        return;
    }

    CLAuthorizationStatus status;
    if (@available(iOS 14.0, *)) {
        status = self.homeLocationManager.authorizationStatus;
    } else {
        status = [CLLocationManager authorizationStatus];
    }
    [self updateLocationStateForAuthorizationStatus:status];
}

- (void)openLocationSettings
{
    NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if ([[UIApplication sharedApplication] canOpenURL:settingsURL]) {
        [[UIApplication sharedApplication] openURL:settingsURL options:@{} completionHandler:nil];
    }
}

- (void)handleAppWillEnterForeground
{
    if (self.homeLocationManager && !self.isUsingManualNearbySelection) {
        CLAuthorizationStatus status;
        if (@available(iOS 14.0, *)) {
            status = self.homeLocationManager.authorizationStatus;
        } else {
            status = [CLLocationManager authorizationStatus];
        }
        [self updateLocationStateForAuthorizationStatus:status];
    }
    [self refreshCurrentOrdersForce:YES];
    [self refreshNearbyAdsForce:YES reason:@"foreground"];
}

- (void)handleAdUploadCompletedNotification:(NSNotification *)notification
{
    [self refreshNearbyAdsForce:YES reason:@"ad-upload"];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.isHomeScreenVisible = YES;
    [self pp_startBackgroundAnimationsIfNeeded];
    [self pp_centerNearbySectionIfPossible];
    //[PPHUD showLoading];
    if(!self.warmUpCache)
    {
        NSLog(@"Starting cache warm-up...");
        [[SearchCacheManager shared] warmUpCacheIfNeeded:^{
            NSLog(@"Cache Warm Up Complete ****** *******...");
        }];
        NSLog(@"Cache warm-up initiated");;
        self.warmUpCache = YES;
    }

    NSString *currentUserID = UserManager.sharedManager.currentUser.ID;
    if (currentUserID.length > 0) {
        if (!self.chatsListenerStarted ||
            ![self.unreadListenerUserID isEqualToString:currentUserID]) {
            self.chatsListenerStarted = YES;
            self.unreadListenerUserID = currentUserID;
            [[ChManager sharedManager] startGlobalUnreadListenerForUser:currentUserID];
        }
    } else {
        self.chatsListenerStarted = NO;
        self.unreadListenerUserID = nil;
    }
    [self.view bringSubviewToFront:self.profileCard];


    [self refreshHeroSectionAppearance];
    if (self.homeLocationManager) {
        CLAuthorizationStatus status;
        if (@available(iOS 14.0, *)) {
            status = self.homeLocationManager.authorizationStatus;
        } else {
            status = [CLLocationManager authorizationStatus];
        }
        [self updateLocationStateForAuthorizationStatus:status];
    }

    if (!self.didRegisterTimeChangeObserver) {
        self.didRegisterTimeChangeObserver = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleTimeChange)
                                                     name:UIApplicationSignificantTimeChangeNotification
                                                   object:nil];
    }

}

- (void)handleTimeChange
{
    // Time crossed hour / day / DST → refresh hero
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshHeroSectionAppearance];
    });
}



#pragma mark - Categories Selection

- (BOOL)isSelected:(PPHomeItem *)item
{
    // "All" option
    if ([item.payload isKindOfClass:NSString.class]) {
        return self.selectedCategory == nil;
    }

    if (![item.payload isKindOfClass:MainKindsModel.class]) {
        return NO;
    }

    MainKindsModel *kind = (MainKindsModel *)item.payload;

    if (!self.selectedCategory) {
        return NO;
    }

    return kind.ID == self.selectedCategory.ID;
}


- (PPHomeHeaderConfig *)headerConfigForSection:(PPHomeSection)section
{
    PPHomeHeaderConfig *cfg = [PPHomeHeaderConfig new];

    cfg.section = section;
    cfg.hidden = YES; // default SAFE
    NSString *arrowImage = Language.isRTL ?  @"arrow.left" :  @"arrow.right";

    switch (section) {
        case PPHomeSectionSuggestions: {
            cfg.hidden = NO;
            cfg.title = kLang(@"SuggestedForYou");
            //cfg.actionTitle = kLang(@"ShowLess");
            cfg.iconName = arrowImage;
             cfg.subtitle = kLang(@"RecommendedForYouHint");

            NSDictionary *event =
                [[PPBrowseHistoryManager shared] latestEvent];

            if (event) {
                NSInteger kindID = [event[@"kind"] integerValue];
                PPBrowseItemType type = [event[@"type"] integerValue];

                MainKindsModel *kind = [self resolveMainKindWithID:kindID];
                if (kind) {
                    NSString *typeKey =
                        type == PPBrowseItemTypeAd
                        ? kLang(@"BrowseType_Ads")
                        : type == PPBrowseItemTypeAccessory
                            ? kLang(@"BrowseType_Accessories")
                            : kLang(@"BrowseType_Services");

                    cfg.subtitle =
                        [NSString stringWithFormat:
                         kLang(@"BecauseYouViewedFormat"),
                         typeKey,kind.KindName
                         ];
                }
            }

            break;
        }

        case PPHomeSectionCurrentOrders: {
            cfg.hidden = !self.isCurrentOrdersExpanded ||
                         !(self.currentOrdersLoading || [self pp_featuredHomeOrder] != nil);
            cfg.title = kLang(@"Home_LastOrderTitle");
            cfg.subtitle = kLang(@"Home_LastOrderSubtitle");
            cfg.actionTitle = kLang(@"OrderHistory");
            cfg.iconName = arrowImage;
            break;
        }

        case PPHomeSectionMainKinds:
        {
            cfg.hidden = NO;
            cfg.title = kLang(@"MainCategories");
            cfg.actionTitle = self.isMainKindsExpanded
                ? kLang(@"ShowLess")
                : kLang(@"ShowAll");

            cfg.iconName = self.isMainKindsExpanded
                ? @"chevron.up"
                : @"chevron.down";

            cfg.menu = nil; // IMPORTANT – header tap controls layout
            break;
        }

        case PPHomeSectionAccessories: {
            cfg.hidden = NO;
            cfg.title = kLang(@"Accessories");
           // cfg.actionTitle = kLang(@"ShowAll");
            cfg.iconName = @"list.bullet";

            cfg.menu =
                [PPActionButton generateActionsForMainKind:MKM.MainKindsArray
                                                 tintColor:AppPrimaryTextClr
                                                   handler:^(MainKindsModel *category) {
                [self handleDeepLinkWithTarget:PPDeepLinkTargetAccessories
                                      mainKind:category
                                        source:PPInputSourceHomeAccessoriesSection];
            }];
            break;
        }

        case PPHomeSectionAdsNearBy: {
            cfg.hidden = NO;
            cfg.title = kLang(@"Home_NearbyAds");
           // cfg.actionTitle = kLang(@"ShowAll");
            cfg.iconName = arrowImage;
            break;
        }

        case PPHomeSectionBuyAgain: {
            cfg.hidden = self.buyAgainAccessories.count == 0;
            cfg.title = kLang(@"Home_BuyAgainTitle");
            cfg.subtitle = kLang(@"Home_BuyAgainSubtitle");
            cfg.actionTitle = kLang(@"ShowAll");
            cfg.iconName = arrowImage;
            break;
        }

        default:
            break;
    }

    return cfg;
}

#pragma mark - CollectionView


- (void)setupCollectionView {
    if (self.collectionView) {
        return;
    }

    self.layoutManager =
        [[PPHomeLayoutManager alloc] initWithMainKindsExpanded:self.isMainKindsExpanded];
    self.layoutManager.isCurrentOrdersExpanded = self.isCurrentOrdersExpanded;


    UICollectionViewCompositionalLayout *layout =
        [self.layoutManager buildLayout];

    self.collectionView =
        [[UICollectionView alloc] initWithFrame:CGRectZero
                           collectionViewLayout:layout];

    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.delegate = self;
    self.collectionView.prefetchingEnabled = YES;
    self.collectionView.prefetchDataSource = self;


    //self.collectionView.contentInset = UIEdgeInsetsMake(0, 6, 6, 6);
    self.collectionView.scrollIndicatorInsets = self.collectionView.contentInset;
    self.collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;


    [self.view addSubview:self.collectionView];

    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor
            constraintEqualToAnchor:self.view.topAnchor],
         [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
         [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
         [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:0]
    ]];

    [self.collectionView registerClass:PPHomeHeroCell.class
            forCellWithReuseIdentifier:PPHomeHeroCell.reuseIdentifier];
    [self.collectionView registerClass:PPHomeOrderStatusCell.class
            forCellWithReuseIdentifier:PPHomeOrderStatusCell.reuseIdentifier];
    [self.collectionView registerClass:PPCategoryCardCell.class forCellWithReuseIdentifier:PPCategoryCardCell.reuseIdentifier];
    [self.collectionView registerClass:PPUniversalCell.class forCellWithReuseIdentifier:PPUniversalCell.reuseIdentifier];
    [self.collectionView registerClass:PPHomeCell.class forCellWithReuseIdentifier:@"PPHomeCell"];
    [self.collectionView registerClass:PPHomeActionCell.class forCellWithReuseIdentifier:@"PPHomeActionCell"];

    [self.collectionView registerClass:PPCarouselContainerCell.class forCellWithReuseIdentifier:@"PPCarouselContainerCell"];
    [self.collectionView registerClass:PPHomeServicesCell.class forCellWithReuseIdentifier:PPHomeServicesCell.reuseIdentifier];
    [self.collectionView registerClass:PPBannerCollectionCell.class forCellWithReuseIdentifier:PPBannerCollectionCell.reuseIdentifier];
    [self.collectionView registerClass:PetAdoptCollectionViewCell.class forCellWithReuseIdentifier:@"PetAdoptCollectionViewCell"];

    [self.collectionView registerClass:PPSectionHeaderView.class
            forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                   withReuseIdentifier:@"PPSectionHeaderView"];

    [self.collectionView registerClass:PPCollectionSectionHeader.class
            forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                   withReuseIdentifier:@"PPCollectionSectionHeader"];

    [self.collectionView registerClass:PPCategoryCardCell.class
            forCellWithReuseIdentifier:PPCategoryCardCell.reuseIdentifier];
}


- (void)reloadCarouselBanner
{
    NSDiffableDataSourceSnapshot *snapshot = self.dataSource.snapshot;

    NSArray *items =
        [snapshot itemIdentifiersInSectionWithIdentifier:@(PPHomeSectionCarousel)];
    if (items.count == 0) return;

    [snapshot reloadItemsWithIdentifiers:items];

    [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
}



#pragma mark - DataSource
- (void)configureDataSource {
    __weak typeof(self) weakSelf = self;

    self.dataSource =
        [[UICollectionViewDiffableDataSource alloc]
         initWithCollectionView:self.collectionView
                   cellProvider:^UICollectionViewCell *_Nullable
             (UICollectionView *collectionView, NSIndexPath *indexPath, PPHomeItem *item) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return [collectionView dequeueReusableCellWithReuseIdentifier:PPUniversalCell.reuseIdentifier
                                                             forIndexPath:indexPath];
        }
        PPHomeSection section = [strongSelf sectionTypeForIndexPath:indexPath];

        if (section == PPHomeSectionHero) {
            PPHomeHeroCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:PPHomeHeroCell.reuseIdentifier
                                                          forIndexPath:indexPath];
            [strongSelf pp_configureHeroCell:cell];
            return cell;
        }

        if (section == PPHomeSectionQuickActions) {
            PPHomeActionCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:PPHomeActionCell.reuseIdentifier
                                                          forIndexPath:indexPath];
            PPHomeQuickActionModel *quickAction =
                [item.payload isKindOfClass:PPHomeQuickActionModel.class]
                ? (PPHomeQuickActionModel *)item.payload
                : nil;
            if (quickAction) {
                [cell configureWithQuickAction:quickAction];
            } else {
                [cell configureWithTitle:@"" systemIcon:@"sparkles"];
            }

            __weak typeof(strongSelf) weakHome = strongSelf;
            cell.onTap = ^{
                __strong typeof(weakHome) self = weakHome;
                if (!self || !quickAction) {
                    return;
                }
                [self handleQuickActionSelection:quickAction];
            };
            return cell;
        }

        if (section == PPHomeSectionCurrentOrders) {
            PPHomeOrderStatusCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:PPHomeOrderStatusCell.reuseIdentifier
                                                          forIndexPath:indexPath];
            BOOL expanded = strongSelf.isCurrentOrdersExpanded;

            if (item.payload == [NSNull null] || ![item.payload isKindOfClass:PPOrder.class]) {
                [cell configurePlaceholderExpanded:expanded];
                return cell;
            }

            PPOrder *order = (PPOrder *)item.payload;
            [cell configureWithOrderReference:[order displayOrderReference]
                             orderKickerTitle:[strongSelf pp_homeOrderKickerTitle:order]
                              previewImageURLs:[strongSelf pp_homeOrderPreviewImageURLs:order limit:3]
                                         meta:[strongSelf pp_homeOrderMetaText:order]
                                  statusTitle:[strongSelf pp_homeOrderStatusTitle:order]
                                   statusHint:[strongSelf pp_homeOrderStatusHint:order]
                                     progress:[strongSelf pp_homeOrderProgress:order]
                                   footerText:[strongSelf pp_homeOrderFooterText:order]
                                  statusColor:[strongSelf pp_homeOrderStatusColor:order]
                               statusIconName:[strongSelf pp_homeOrderStatusIconName:order]
                                  actionTitle:(kLang(@"order_action_track") ?: @"Track order")
                                     expanded:expanded];

            __weak typeof(strongSelf) weakHome = strongSelf;
            cell.onTrackTap = ^{
                __strong typeof(weakHome) self = weakHome;
                if (!self) return;
                [self pp_openOrderDetailsForOrder:order];
            };
            cell.onHistoryTap = ^{
                __strong typeof(weakHome) self = weakHome;
                if (!self) return;
                [self handleSeeAllForSection:PPHomeSectionCurrentOrders];
            };
            cell.onCollapseTap = ^{
                __strong typeof(weakHome) self = weakHome;
                if (!self) return;
                BOOL shouldExpand = !self.isCurrentOrdersExpanded;
                [self pp_setCurrentOrdersExpanded:shouldExpand animated:YES];
                if (shouldExpand) {
                    [self pp_scrollCurrentOrdersSectionIntoViewAnimated:YES];
                }
            };
            return cell;
        }

        if (section == PPHomeSectionCarousel) {

            PPBannerCollectionCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:@"PPBannerCollectionCell"
                                                          forIndexPath:indexPath];

            if (item.payload == [NSNull null]) {
                // 🔥 Soft placeholder — NO skeleton, NO shimmer
                [cell configurePlaceholder];


                return cell;
            }

            if ([item.payload isKindOfClass:NSArray.class]) {
                NSArray *promoCards = (NSArray *)item.payload;
                BOOL hasPromoCardObjects =
                    promoCards.count > 0 &&
                    [promoCards.firstObject isKindOfClass:PPHomePromoCarouselCard.class];

                if (hasPromoCardObjects) {
                    __weak typeof(strongSelf) weakHome = strongSelf;
                    [cell configureWithPromoCards:(NSArray<PPHomePromoCarouselCard *> *)promoCards
                                        onCardTap:^(PPHomePromoCarouselCard *card) {
                        __strong typeof(weakHome) self = weakHome;
                        if (!self) return;
                        [self pp_handlePromoCardTap:card interaction:@"card"];
                    }
                                     onPrimaryTap:^(PPHomePromoCarouselCard *card) {
                        __strong typeof(weakHome) self = weakHome;
                        if (!self) return;
                        [self pp_handlePromoCardTap:card interaction:@"primary"];
                    }
                                   onSecondaryTap:^(PPHomePromoCarouselCard *card) {
                        __strong typeof(weakHome) self = weakHome;
                        if (!self) return;
                        [self pp_handlePromoCardTap:card interaction:@"secondary"];
                    }];
                    return cell;
                }
            }

            MainBannerModel *homeTop = [strongSelf pp_homeTopCarouselBannerGroup];

            if (!homeTop || homeTop.childBanners.count == 0) {
                [cell configurePlaceholder];
                return cell;
            }

            [cell configureWithBanners:homeTop.childBanners
                                 group:homeTop
                              delegate:strongSelf];

            return cell;
        }

        /*
        if (indexPath.section == PPHomeSectionCategoriesOptions) {
            PPCategoryCardCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:
                    PPCategoryCardCell.reuseIdentifier
                                                            forIndexPath:indexPath];
            BOOL isAll = [item.payload isKindOfClass:NSString.class];
            MainKindsModel *kind = isAll ? nil : (MainKindsModel *)item.payload;

            // selection state
            BOOL selected = NO;
            if (isAll) {
                selected = (self.selectedCategory == nil);
            } else if (self.selectedCategory) {
                selected = (kind.ID == self.selectedCategory.ID);
            }

            [cell configureWithMainKind:kind
                                    isAll:isAll
                                selected:selected];

            // Wire up selection for category options
            __weak typeof(self) weakSelf = self;
            cell.onSelect = ^(MainKindsModel *kind, BOOL isAll) {
                if (isAll) {
                    [weakSelf didSelectCategory:nil];   // "All"
                } else {
                    [weakSelf didSelectCategory:kind];
                }
            };

            return cell;
        }
        if (indexPath.section == PPHomeSectionCategoriesItems) {
            PPUniversalCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:
                    PPUniversalCell.reuseIdentifier
                                                            forIndexPath:indexPath];

            PPUniversalCellViewModel *vm = item.universalViewModel;
            vm.indexPath = indexPath;

            [cell applyViewModel:vm
                            context:PPCellForVets
                        layoutMode:PPCellLayoutModeSquare
                    discountMode:PPDiscountStylePlain
                        imageLoader:^(UIImageView *iv, NSString *url, UIImage *ph, UIView *card) {
                [GM pp_setImageURL:url imageView:iv placeholder:@"placeholder"];
            }];

            return cell;
        }
        */

        if (section == PPHomeSectionServices) {
            PPHomeServicesCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:PPHomeServicesCell.reuseIdentifier
                                                                                 forIndexPath:indexPath];

            if (item.payload == [NSNull null]) {
                [cell configureSkeleton];
                return cell;
            }

            PPHomeServiceItem *service = (PPHomeServiceItem *)item.payload;
            [cell configureWithService:service];

            __weak typeof(cell) weakCell = cell;
             cell.onTap = ^{
                __strong typeof(weakCell) cell = weakCell;
                NSIndexPath *path = [collectionView indexPathForCell:cell];

                if (path) {
                    NSLog(@"onTap");
                    [strongSelf collectionView:collectionView
                        didSelectItemAtIndexPath:path];
                }
            };
            cell.onTapMenu = ^(PPHomeServiceItem *_Nonnull service, MainKindsModel *_Nonnull mainKindModel) {
                NSLog(@"onTapMenu %ld", mainKindModel.ID);
                PPDeepLinkTarget targt = service.type == PPHomeServiceTypeGrooming ? PPDeepLinkTargetGrooming : service.type == PPHomeServiceTypeTraining ? PPDeepLinkTargetTraning : PPDeepLinkTargetFood;
                [weakSelf handleDeepLinkWithTarget:targt
                                          mainKind:mainKindModel
                                            source:PPInputSourceHomeServicesSection];
            };

            return cell;
        }


            if (section == PPHomeSectionAdopt) {
            PetAdoptCollectionViewCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:@"PetAdoptCollectionViewCell"
                                                          forIndexPath:indexPath];

            [cell configureWithTitle:kLang(@"Adopt a Pet")
                            subtitle:kLang(@"Find your new best friend")
                           seedImage:[UIImage imageNamed:@"icn_cat"]];

            __weak typeof(cell) weakCell = cell;
            cell.onTap = ^{
                __strong typeof(weakCell) tappedCell = weakCell;
                NSIndexPath *path = [collectionView indexPathForCell:tappedCell];
                if (path) {
                    [strongSelf collectionView:collectionView didSelectItemAtIndexPath:path];
                }
            };

            return cell;
        }

                if (section == PPHomeSectionSuggestions) {

                if (item.payload == [NSNull null]) {
                    PPUniversalCell *cell =
                            [collectionView dequeueReusableCellWithReuseIdentifier:PPUniversalCell.reuseIdentifier
                                                                      forIndexPath:indexPath];
                        return cell; // height-only placeholder
                    }

            // ✅ REAL CONTENT
            PPUniversalCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:
                    PPUniversalCell.reuseIdentifier
                                                        forIndexPath:indexPath];
            cell.delegate = strongSelf;

            PPUniversalCellViewModel *vm = item.universalViewModel;
            if (!vm || !vm.ModelObject) {
                return cell;
            }

            vm.indexPath = indexPath;

            [cell applyViewModel:vm
                         context:vm.modelContext
                      layoutMode:PPCellLayoutModeSquare
                    discountMode:PPDiscountStyleBadge
                     imageLoader:^(UIImageView *iv,
                                   NSString *url,
                                   UIImage *placeholder,
                                   UIView *card) {
                (void)placeholder;
                (void)card;

                UIImage *fallback =
                vm.placeholder ?: [UIImage imageNamed:@"placeholder"];
                iv.image = fallback;

                NSString *currentHash = vm.blurHash;
                __weak UIImageView *weakIV = iv;

                if (currentHash.length > 0) {
                    [strongSelf pp_asyncBlurHashImageForHash:currentHash
                                                         size:CGSizeMake(40, 40)
                                                   completion:^(UIImage * _Nullable blurImage) {
                        if (!blurImage || !weakIV) {
                            return;
                        }
                        if (![currentHash isEqualToString:vm.blurHash]) {
                            return;
                        }
                        [UIView performWithoutAnimation:^{
                            if (weakIV.image == fallback) {
                                weakIV.image = blurImage;
                            }
                        }];
                    }];
                }

                [[PPImageLoaderManager shared]
                    setImageOnImageView:iv
                                     url:url
                              placeholder:fallback
                          transitionStyle:PPImageTransitionStyleNone
                               complation:nil];
            }];

            return cell;
        }


                if (section == PPHomeSectionMainKinds) {

                PPHomeCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:@"PPHomeCell"
                                                          forIndexPath:indexPath];

                // ⛔️ HARD GUARD – skeleton or invalid payload
                if (![item.payload isKindOfClass:MainKindsModel.class]) {
                    // skeleton cell
                        [cell configureWithMainKind:nil
                                              isAll:YES
                                          selected:(strongSelf.selectedCategory == nil)];
                        return cell;
                    }

                MainKindsModel *kind = (MainKindsModel *)item.payload;
                BOOL isAll = (kind.ID == -1);


                // selection state
                    BOOL selected = NO;
                    if (isAll) {
                        selected = (strongSelf.selectedCategory == nil);
                    } else if (strongSelf.selectedCategory) {
                        selected = (kind.ID == strongSelf.selectedCategory.ID);
                    }

                if (selected) {
                    NSLog(@"[Home][MainKinds][Cell] ✅ SELECTED → %@", kind.KindName);
                }

                [cell configureWithMainKind:kind
                                        isAll:isAll
                                    selected:selected];

                __weak typeof(strongSelf) weakStrongSelf = strongSelf;
                cell.onSelect = ^(MainKindsModel *kind, BOOL isAll) {
                    __strong typeof(weakStrongSelf) strongSelf = weakStrongSelf;
                    if (!strongSelf) return;

                    // ✅ ONLY update selection state here
                    strongSelf.selectedCategory = isAll ? nil : kind;

                    if (isAll) {
                        NSLog(@"[Home][MainKinds][Action] ALL selected → deep link");
                        [strongSelf handleDeepLinkWithTarget:PPDeepLinkTargetAllCategories
                                                     mainKind:nil
                                                       source:PPInputSourceHomeMainKindsSection];
                    } else {
                        NSLog(@"[Home][MainKinds][Action] Kind selected → %@",
                              kind.KindName);
                        [strongSelf handleMainKindSelection:(MainKindsModel *)item.payload];
                    }




                     // 🔁 Refresh main kinds visuals only
                     NSDiffableDataSourceSnapshot *snapshot = strongSelf.dataSource.snapshot;
                     NSArray *items =
                         [snapshot itemIdentifiersInSectionWithIdentifier:@(PPHomeSectionMainKinds)];
                     [snapshot reloadItemsWithIdentifiers:items];

                     [strongSelf.dataSource applySnapshot:snapshot animatingDifferences:YES];


                };


                return cell;
            }

        if (section == PPHomeSectionAdsNearBy &&
            [item.payload isKindOfClass:NSString.class]) {
            PPHomeActionCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:PPHomeActionCell.reuseIdentifier
                                                          forIndexPath:indexPath];
            NSString *token = (NSString *)item.payload;
            if ([token isEqualToString:@"nearby-empty-state"]) {
                [cell configureWithTitle:kLang(@"No nearby ads available")
                              systemIcon:@"location.slash.fill"];
                __weak typeof(strongSelf) weakSelfAction = strongSelf;
                cell.onTap = ^{
                    __strong typeof(weakSelfAction) self = weakSelfAction;
                    if (!self) return;
                    self.nearbyRadiusKm = MIN(PPNearbyExpandedRadiusKm, self.nearbyRadiusKm + 3.0);
                    [self refreshNearbyAdsForce:YES reason:@"expand-radius"];
                };
            } else {
                [cell configureWithTitle:kLang(@"Loading...")
                              systemIcon:@"hourglass"];
                cell.onTap = nil;
            }
            return cell;
        }


            PPUniversalCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:PPUniversalCell.reuseIdentifier forIndexPath:indexPath];
                cell.delegate = strongSelf;
            cell.delegate = self;
        if (item.universalViewModel) {


            PPUniversalCellViewModel *vm = item.universalViewModel;
            vm.indexPath = indexPath;
            [cell applyViewModel:vm
                         context:vm.modelContext
                      layoutMode:PPCellLayoutModeSquare
                    discountMode:PPDiscountStyleBadge
                     imageLoader:^(UIImageView *iv,
                                   NSString *url,
                                   UIImage *placeholder,
                                   UIView *card) {
                (void)placeholder;
                (void)card;

                UIImage *fallback =
                vm.placeholder ?: [UIImage imageNamed:@"placeholder"];
                iv.image = fallback;

                NSString *currentHash = vm.blurHash;
                __weak UIImageView *weakIV = iv;

                if (currentHash.length > 0) {
                    [strongSelf pp_asyncBlurHashImageForHash:currentHash
                                                         size:CGSizeMake(40, 40)
                                                   completion:^(UIImage * _Nullable blurImage) {
                        if (!blurImage || !weakIV) {
                            return;
                        }
                        if (![currentHash isEqualToString:vm.blurHash]) {
                            return;
                        }
                        [UIView performWithoutAnimation:^{
                            if (weakIV.image == fallback) {
                                weakIV.image = blurImage;
                            }
                        }];
                    }];
                }

                [[PPImageLoaderManager shared]
                 setImageOnImageView:iv
                                  url:url
                           placeholder:fallback
                       transitionStyle:PPImageTransitionStyleNone
                            complation:nil];
            }];


        }

        return cell;
    }];

    // =========================
    // Supplementary Views
    // =========================


    self.dataSource.supplementaryViewProvider =
    ^UICollectionReusableView * _Nullable(UICollectionView *collectionView,
                                          NSString *kind,
                                          NSIndexPath *indexPath)
    {
        if (![kind isEqualToString:UICollectionElementKindSectionHeader]) {
            return nil;
        }

        NSArray *sectionIDs = weakSelf.dataSource.snapshot.sectionIdentifiers;
        if (indexPath.section >= (NSInteger)sectionIDs.count) return nil;
        NSNumber *sectionID = sectionIDs[indexPath.section];
        PPHomeSection section = (PPHomeSection)sectionID.integerValue;

        PPHomeHeaderConfig *cfg =
            [weakSelf headerConfigForSection:section];

        PPSectionHeaderView *header =
        [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                           withReuseIdentifier:@"PPSectionHeaderView"
                                                  forIndexPath:indexPath];


        if (cfg.hidden) {
            header.hidden = YES;
            return header;
        }

        header.hidden = NO;

        [header configureWithTitle:cfg.title
                          subtitle:cfg.subtitle
                       actionTitle:cfg.actionTitle
                          iconName:cfg.iconName
                              menu:cfg.section == PPHomeSectionMainKinds ? nil : cfg.menu
                     ppHomeSection:cfg.section];

        header.onTap = ^{
            [weakSelf handleSeeAllForSection:cfg.section];
        };

        return header;
    };



    /*self.dataSource.supplementaryViewProvider =
    ^UICollectionReusableView * _Nullable(UICollectionView *collectionView,
                                          NSString *kind,
                                          NSIndexPath *indexPath)
    {

        NSNumber *sectionID = weakSelf.dataSource.snapshot.sectionIdentifiers[indexPath.section];
        PPHomeSection section = (PPHomeSection)sectionID.integerValue;

        if (section == PPHomeSectionMainKinds)
        {
            PPCollectionSectionHeader *header =
                [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                                   withReuseIdentifier:@"PPCollectionSectionHeader"
                                                          forIndexPath:indexPath];

            [header configureWithTitle:@"إدارة الإنتاج"
                              subtitle:@"آخر العناصر المضافة"
                           actionTitle:@"عرض الكل"
                                action:^{
                                    [weakSelf handleSeeAllForSection:PPHomeSectionMainKinds];
                                }];

            return header;
        }

        PPSectionHeaderView *header =
        [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                           withReuseIdentifier:@"PPSectionHeaderView"
                                                  forIndexPath:indexPath];

        PPHomeHeaderConfig *cfg =
        [weakSelf headerConfigForSection:section];

        if (cfg.hidden) {
            header.hidden = YES;
            return header;
        }

        header.hidden = NO;

        if (cfg.subtitle.length > 0) {
            [header configureWithTitle:cfg.title
                              subtitle:cfg.subtitle
                           actionTitle:cfg.actionTitle
                              iconName:cfg.iconName
                                  menu:cfg.section == PPHomeSectionMainKinds ? nil : cfg.menu
                         ppHomeSection:cfg.section];
        } else {
            [header configureWithTitle:cfg.title
                           actionTitle:cfg.actionTitle
                              iconName:cfg.iconName
                                  menu:cfg.section == PPHomeSectionMainKinds ? nil : cfg.menu
                         ppHomeSection:cfg.section];
        }

        header.onTap = ^{
            if (cfg.section == PPHomeSectionMainKinds) {
                [weakSelf handleSeeAllForSection:cfg.section];
                //[weakSelf handleMainKindsHeaderTap];
            } else {
                [weakSelf handleSeeAllForSection:cfg.section];
            }
        };

        return header;
    };*/

}

- (void)invalidateHeaderForSection:(PPHomeSection)section
{
    NSInteger sectionIndex = [self sectionIndexForType:section];
    if (sectionIndex == NSNotFound) return;

    UICollectionViewLayout *layout = self.collectionView.collectionViewLayout;

    if ([layout isKindOfClass:UICollectionViewCompositionalLayout.class]) {
        [layout invalidateLayout];
    }
}
#pragma mark - MainKinds Header Tap

- (void)handleMainKindsHeaderTap
{
    NSLog(@"[Home][MainKinds] Header tapped → open ALL categories (PPDataViewVC)");

    if (self.mainKinds.count == 0) {
        NSLog(@"[Home][MainKinds] ❌ No categories available");
        return;
    }

    // Build input object for PPDataViewVC
    PPDataViewInput *input = [PPDataViewInput inputWithMainKindsArr:self.mainKinds sourceTarget:PPDeepLinkTargetAllCategories source:PPInputSourceHomeMainKindsSection];
    PPDataViewVC *vc =  [[PPDataViewVC alloc] initWithInput:input];
    vc.pp_transitionStyle = PPTransitionStyleNone;
    input.title = kLang(@"MainCategories");
    if (![PPHomeHelper pushViewControllerSafely:vc from:self animated:YES]) {
        return;
    }
    //input.layout = PPDataLayoutGrid;                 // ✅ grid lives here
    //input.items = ;


}

#pragma mark - Data
- (void)loadData {
    __weak typeof(self) weakSelf = self;

    /*
     [[PetAdManager sharedManager]
      fetchLatestAdsWithLimit:8
                   completion:^(NSArray<PetAd *> *ads) {
         weakSelf.ads = ads ? : @[];
         weakSelf.adsLoaded = YES;
         [weakSelf tryApplySnapshot];
     }];
     */

    [[PetAccessoryManager sharedManager] fetchLatestAccessoriesWithLimit:50
                          completion:^(NSArray *accessories, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [PPHUD showError:kLang(@"SomethingWentWrong")];
            });
            return;
        }

        NSArray *source = accessories ?: @[];
        NSArray *sorted =
        [source sortedArrayUsingComparator:^NSComparisonResult(PetAccessory *a, PetAccessory *b) {

            BOOL aHasDiscount = (a.discountPercent > 0 || a.discountAmount > 0);
            BOOL bHasDiscount = (b.discountPercent > 0 || b.discountAmount > 0);

            if (aHasDiscount && !bHasDiscount) return NSOrderedAscending;
            if (!aHasDiscount && bHasDiscount) return NSOrderedDescending;

            NSDate *aDate = a.createdAt ?: [NSDate distantPast];
            NSDate *bDate = b.createdAt ?: [NSDate distantPast];
            NSComparisonResult dateOrder = [bDate compare:aDate];
            if (dateOrder != NSOrderedSame) return dateOrder;

            NSString *aID = PPSafeString(a.accessoryID);
            NSString *bID = PPSafeString(b.accessoryID);
            return [aID compare:bID options:NSCaseInsensitiveSearch];
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.accessories = sorted;
            self.accessoriesLoaded = YES;
            [self pp_refreshBuyAgainSection];
            [self reloadSection:PPHomeSectionCurrentOrders];
            [self reloadSection:PPHomeSectionAccessories];
            [self reloadSection:PPHomeSectionSuggestions];
            [self tryApplySnapshot];
            [self pp_prefetchTopImagesWithLimit:20];
        });

    }];

    [self refreshCurrentOrdersForce:YES];
    [self refreshNearbyAdsForce:YES reason:@"initial-load"];
}

- (void)refreshNearbyAdsForce:(BOOL)force reason:(NSString *)reason
{
    if (!self.hasSelectedNearbyCoordinate ||
        !CLLocationCoordinate2DIsValid(self.selectedNearbyCoordinate)) {
        self.nearbyAds = @[];
        self.nearbyLoading = NO;
        self.nearbyLoaded = YES;
        [self reloadSection:PPHomeSectionAdsNearBy];
        [self reloadSection:PPHomeSectionSuggestions];
        [self tryApplySnapshot];
        return;
    }

    NSDate *now = [NSDate date];
    if (!force && self.lastNearbyRefreshAt) {
        NSTimeInterval elapsed = [now timeIntervalSinceDate:self.lastNearbyRefreshAt];
        if (elapsed < PPNearbyMinimumRefreshInterval && self.hasLastNearbyRefreshCoordinate) {
            CLLocation *last =
                [[CLLocation alloc] initWithLatitude:self.lastNearbyRefreshCoordinate.latitude
                                           longitude:self.lastNearbyRefreshCoordinate.longitude];
            CLLocation *current =
                [[CLLocation alloc] initWithLatitude:self.selectedNearbyCoordinate.latitude
                                           longitude:self.selectedNearbyCoordinate.longitude];
            if ([current distanceFromLocation:last] < 150.0) {
                return;
            }
        }
    }

    self.nearbyRequestToken += 1;
    NSInteger requestToken = self.nearbyRequestToken;
    self.nearbyLoading = YES;
    if (self.nearbyAds.count == 0) {
        [self reloadSection:PPHomeSectionAdsNearBy];
    }

    __weak typeof(self) weakSelf = self;
    [[PetAdManager sharedManager]
        fetchNearbyAdsAtCoordinate:self.selectedNearbyCoordinate
                          radiusKm:self.nearbyRadiusKm
                             limit:30
                          category:0
                        completion:^(NSArray<PetAd *> *ads) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (requestToken != self.nearbyRequestToken) {
            return; // stale response guard
        }

        NSMutableDictionary<NSString *, PetAd *> *uniqueByID = [NSMutableDictionary dictionary];
        for (PetAd *ad in ads ?: @[]) {
            if (!ad.adID.length) continue;
            uniqueByID[ad.adID] = ad;
        }

        NSArray<PetAd *> *deduped =
            [uniqueByID.allValues sortedArrayUsingComparator:^NSComparisonResult(PetAd *a, PetAd *b) {
            NSDate *aDate = a.createdAt ?: a.postedDate ?: [NSDate distantPast];
            NSDate *bDate = b.createdAt ?: b.postedDate ?: [NSDate distantPast];
            NSComparisonResult dateOrder = [bDate compare:aDate];
            if (dateOrder != NSOrderedSame) return dateOrder;
            return [a.adID compare:b.adID options:NSCaseInsensitiveSearch];
        }];
        if (deduped.count == 0) {
            // 🔁 Fallback: show latest 5 ads when no nearby ads found
            [[PetAdManager sharedManager] fetchLatestAdsWithLimit:5
                                                       completion:^(NSArray<PetAd *> *latestAds) {
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;

                self.nearbyAds = latestAds ?: @[];
                self.nearbyLoaded = YES;
                self.nearbyLoading = NO;
                self.lastNearbyRefreshAt = [NSDate date];
                self.lastNearbyRefreshCoordinate = self.selectedNearbyCoordinate;
                self.hasLastNearbyRefreshCoordinate = YES;

                [self reloadSection:PPHomeSectionAdsNearBy];
                [self reloadSection:PPHomeSectionSuggestions];
                [self tryApplySnapshot];
                [self pp_prefetchTopImagesWithLimit:24];
            }];
            return;
        } else {
            self.nearbyAds = deduped;
        }
        self.nearbyLoaded = YES;
        self.nearbyLoading = NO;
        self.lastNearbyRefreshAt = [NSDate date];
        self.lastNearbyRefreshCoordinate = self.selectedNearbyCoordinate;
        self.hasLastNearbyRefreshCoordinate = YES;

        NSLog(@"[HomeNearby] refreshed reason=%@ radius=%.1fkm count=%lu",
              reason, self.nearbyRadiusKm, (unsigned long)self.nearbyAds.count);

        [self reloadSection:PPHomeSectionAdsNearBy];
        [self reloadSection:PPHomeSectionSuggestions];
        [self tryApplySnapshot];
        [self pp_prefetchTopImagesWithLimit:24];

        if (!self.didAutoScrollSuggestions && self.nearbyAds.count > 1) {
            self.didAutoScrollSuggestions = YES;
            [self autoScrollIndextoIndex:2 inSection:PPHomeSectionSuggestions];
        }
    }];
}

- (void)tryApplySnapshot {
    if (!self.accessoriesLoaded || !self.nearbyLoaded) {
        return;
    }

    // ✅ Data ready → dismiss HUD once
    if ([PPHUD isVisible]) {
        [PPHUD dismiss];
    }

}

- (NSString *)pp_currentHeroRenderSignature
{
    NSString *greeting = [self heroGreetingText] ?: @"";
    NSString *name = [self heroDisplayNameText] ?: @"";
    NSString *location = [self heroCountryText] ?: @"";
    NSString *actionTitle = [self heroLocationActionTitle] ?: @"";
    return [NSString stringWithFormat:@"%@|%@|%@|%ld|%@",
            greeting,
            name,
            location,
            (long)self.nearbyLocationState,
            actionTitle];
}

- (void)pp_configureHeroCell:(PPHomeHeroCell *)cell
{
    if (!cell) return;

    [cell configureWithGreeting:[self heroGreetingText]
                       userName:nil
                       location:[self heroCountryText]
                  locationState:(PPHomeHeroLocationState)self.nearbyLocationState
                    actionTitle:[self heroLocationActionTitle]];

    __weak typeof(self) weakSelf = self;
    cell.onLocationTap = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self presentHomeLocationSheet];
    };
    cell.onLocationActionTap = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self presentHomeLocationSheet];
    };

    [cell hideOrderPeek:NO];
    cell.onOrderPeekTap = nil;
}

- (void)refreshHeroSectionAppearance
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refreshHeroSectionAppearance];
        });
        return;
    }

    if (self.heroRefreshScheduled) {
        return;
    }
    self.heroRefreshScheduled = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        self.heroRefreshScheduled = NO;

        if (!self.isViewLoaded || !self.collectionView || !self.dataSource) {
            return;
        }

        NSString *renderSignature = [self pp_currentHeroRenderSignature];
        NSInteger sectionIndex = [self sectionIndexForType:PPHomeSectionHero];
        if (sectionIndex == NSNotFound) {
            return;
        }

        NSIndexPath *heroIndexPath = [NSIndexPath indexPathForItem:0 inSection:sectionIndex];
        PPHomeHeroCell *visibleHeroCell =
            (PPHomeHeroCell *)[self.collectionView cellForItemAtIndexPath:heroIndexPath];
        if (visibleHeroCell) {
            [self pp_configureHeroCell:visibleHeroCell];
            self.lastHeroRenderSignature = renderSignature;
            return;
        }

        if ([renderSignature isEqualToString:self.lastHeroRenderSignature]) {
            return;
        }

        NSDiffableDataSourceSnapshot *snapshot = self.dataSource.snapshot;
        NSArray *items = [snapshot itemIdentifiersInSectionWithIdentifier:@(PPHomeSectionHero)];
        if (items.count == 0) {
            return;
        }

        [snapshot reloadItemsWithIdentifiers:items];
        [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
        self.lastHeroRenderSignature = renderSignature;
    });
}

// MARK: - Carousel Data

#pragma mark - Carousel Data

- (void)reloadHomeCarousel {
    // Convert ads → carousel items
    if (self.ads.count == 0) {
        self.carouselItems = @[];
        return;
    }

    NSMutableArray<PPCarouselItem *> *items = [NSMutableArray array];


    for (PetAd *ad in self.ads) {

        NSString *imageURL = nil;
        UIImage *placeholder = [UIImage imageNamed:@"placeholder"];

        PetImageItem *firstItem = ad.imageItems.firstObject;
        if (firstItem) {
            imageURL = PPSafeString(firstItem.url);

            if (firstItem.blurHash.length > 0) {
                UIImage *cachedPlaceholder =
                [self.blurHashCache objectForKey:firstItem.blurHash];
                if (cachedPlaceholder) {
                    placeholder = cachedPlaceholder;
                } else {
                    [self pp_asyncBlurHashImageForHash:firstItem.blurHash
                                                  size:CGSizeMake(40, 40)
                                            completion:nil];
                }
            }
        }


        PPCarouselItem *item =
            [PPCarouselItem itemWithIdentifier:PPSafeString(ad.adID)
                                      imageURL:imageURL
                                         title:PPSafeString(ad.adTitle)
                                      subtitle:@""
                              placeholderImage:placeholder];

        [items addObject:item];
    }

    self.carouselItems = items.copy;

}


- (NSInteger)sectionIndexForType:(PPHomeSection)section
{
    NSArray *sections = self.dataSource.snapshot.sectionIdentifiers;

    return [sections indexOfObject:@(section)];
}

- (PPHomeSection)sectionTypeForIndexPath:(NSIndexPath *)indexPath
{
    NSArray<NSNumber *> *sections = self.dataSource.snapshot.sectionIdentifiers;
    if (indexPath.section < sections.count) {
        return (PPHomeSection)sections[indexPath.section].integerValue;
    }
    return (PPHomeSection)indexPath.section;
}

- (void)handleSeeAllForSection:(PPHomeSection)section {
    switch (section) {
        case PPHomeSectionMainKinds: {
            self.isMainKindsExpanded = !self.isMainKindsExpanded;
            self.layoutManager.isMainKindsExpanded = self.isMainKindsExpanded;

            UICollectionViewCompositionalLayout *newLayout =
            [self.layoutManager buildLayout];

            // Capture scroll position to prevent layout jump
            CGPoint savedOffset = self.collectionView.contentOffset;

            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            [self.collectionView setCollectionViewLayout:newLayout animated:NO];
            self.collectionView.contentOffset = savedOffset;
            [self.collectionView layoutIfNeeded];
            [CATransaction commit];

            // Force gradient/overlay re-layout on all visible MainKinds cells
            NSInteger sectionIdx = [self sectionIndexForType:PPHomeSectionMainKinds];
            if (sectionIdx != NSNotFound) {
                NSArray<UICollectionViewCell *> *cells =
                    [self.collectionView visibleCells];
                for (UICollectionViewCell *cell in cells) {
                    NSIndexPath *ip = [self.collectionView indexPathForCell:cell];
                    if (ip && ip.section == sectionIdx) {
                        [cell setNeedsLayout];
                        [cell layoutIfNeeded];
                        cell.alpha = 0.0;
                        cell.transform = CGAffineTransformMakeScale(0.92, 0.92);
                        [UIView animateWithDuration:0.3
                                              delay:0
                             usingSpringWithDamping:0.85
                              initialSpringVelocity:0.3
                                            options:UIViewAnimationOptionCurveEaseOut
                                         animations:^{
                            cell.alpha = 1.0;
                            cell.transform = CGAffineTransformIdentity;
                        } completion:nil];
                    }
                }
            }

            [self refreshMainKindsHeader];
            break;
        }

        case PPHomeSectionCurrentOrders: {
            OrderHistoryViewController *vc = [[OrderHistoryViewController alloc] init];
            [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
            break;
        }

        case PPHomeSectionAccessories:
            [self handleDeepLinkWithTarget:PPDeepLinkTargetAccessories
                                  mainKind:nil
                                    source:PPInputSourceHomeAccessoriesSection];
            break;

        case PPHomeSectionAdsNearBy:
            if (!self.hasSelectedNearbyCoordinate) {
                [self openHomeLocationPicker];
                break;
            }
            [self handleDeepLinkWithTarget:PPDeepLinkTargetNewByAds
                                  mainKind:nil
                                    source:PPInputSourceHomeNearBySection];
            break;

        case PPHomeSectionSuggestions:
            [self handleDeepLinkWithTarget:PPDeepLinkTargetAllCategories
                                  mainKind:nil
                                    source:PPInputSourceHomeMainKindsSection];
            break;

        case PPHomeSectionBuyAgain:
            [self handleDeepLinkWithTarget:PPDeepLinkTargetAccessories
                                  mainKind:nil
                                    source:PPInputSourceHomeAccessoriesSection];
            break;

        default:
            break;
    }
}

- (void)pp_setCurrentOrdersExpanded:(BOOL)expanded animated:(BOOL)animated
{
    if (self.isCurrentOrdersExpanded == expanded &&
        (!self.layoutManager || self.layoutManager.isCurrentOrdersExpanded == expanded)) {
        [self refreshHeroSectionAppearance];
        return;
    }

    self.isCurrentOrdersExpanded = expanded;

    if (!self.collectionView || !self.layoutManager) {
        [self refreshHeroSectionAppearance];
        return;
    }

    NSInteger sectionIndex = [self sectionIndexForType:PPHomeSectionCurrentOrders];
    NSIndexPath *currentOrderIndexPath = nil;
    if (sectionIndex != NSNotFound &&
        [self.collectionView numberOfItemsInSection:sectionIndex] > 0) {
        currentOrderIndexPath = [NSIndexPath indexPathForItem:0 inSection:sectionIndex];
    }

    PPHomeOrderStatusCell *visibleOrderCell =
        currentOrderIndexPath
        ? (PPHomeOrderStatusCell *)[self.collectionView cellForItemAtIndexPath:currentOrderIndexPath]
        : nil;
    if (![visibleOrderCell isKindOfClass:PPHomeOrderStatusCell.class]) {
        visibleOrderCell = nil;
    }

    self.layoutManager.isCurrentOrdersExpanded = expanded;
    CGPoint savedOffset = self.collectionView.contentOffset;
    UICollectionViewCompositionalLayout *newLayout = [self.layoutManager buildLayout];
    [self refreshHeroSectionAppearance];
    if (visibleOrderCell) {
        [visibleOrderCell setExpandedState:expanded animated:animated];
    }

    __weak typeof(self) weakSelf = self;
    [self.collectionView setCollectionViewLayout:newLayout
                                        animated:animated
                                      completion:^(__unused BOOL finished) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        self.collectionView.contentOffset = savedOffset;

        if (!currentOrderIndexPath) {
            return;
        }

        UICollectionViewCell *updatedCell =
            [self.collectionView cellForItemAtIndexPath:currentOrderIndexPath];
        if (![updatedCell isKindOfClass:PPHomeOrderStatusCell.class]) {
            return;
        }

        PPHomeOrderStatusCell *updatedOrderCell = (PPHomeOrderStatusCell *)updatedCell;
        if (updatedOrderCell != visibleOrderCell) {
            [updatedOrderCell setExpandedState:expanded animated:NO];
        }

        [updatedOrderCell refreshDecorativeLayersForCurrentBounds];
    }];
}

- (void)pp_scrollCurrentOrdersSectionIntoViewAnimated:(BOOL)animated
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSInteger sectionIndex = [self sectionIndexForType:PPHomeSectionCurrentOrders];
        if (sectionIndex == NSNotFound || [self.collectionView numberOfItemsInSection:sectionIndex] == 0) {
            return;
        }

        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:sectionIndex];
        UICollectionViewLayoutAttributes *attributes =
            [self.collectionView layoutAttributesForItemAtIndexPath:indexPath];
        if (attributes) {
            CGRect targetRect = CGRectInset(attributes.frame, 0.0, -18.0);
            [self.collectionView scrollRectToVisible:targetRect animated:animated];
            return;
        }

        [self.collectionView scrollToItemAtIndexPath:indexPath
                                    atScrollPosition:UICollectionViewScrollPositionTop
                                            animated:animated];
    });
}


- (void)refreshMainKindsHeader
{
    NSInteger sectionIndex = [self sectionIndexForType:PPHomeSectionMainKinds];
    if (sectionIndex == NSNotFound) return;

    NSIndexPath *indexPath =
        [NSIndexPath indexPathForItem:0 inSection:sectionIndex];

    UICollectionReusableView *view =
        [self.collectionView supplementaryViewForElementKind:UICollectionElementKindSectionHeader
                                                 atIndexPath:indexPath];

    if (![view isKindOfClass:PPSectionHeaderView.class]) {
        return;
    }

    PPSectionHeaderView *header = (PPSectionHeaderView *)view;

    NSString *iconName = self.isMainKindsExpanded
        ? @"chevron.up"
        : @"chevron.down";

    NSString *actionTitle = self.isMainKindsExpanded
        ? kLang(@"ShowLess")
        : kLang(@"ShowAll");

    [header configureWithTitle:kLang(@"MainCategories")
                      subtitle:nil
                   actionTitle:actionTitle
                      iconName:iconName
                          menu:nil
                 ppHomeSection:PPHomeSectionMainKinds];
}

#pragma mark - Prefetching

- (NSArray<NSString *> *)pp_imageURLsFromIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    if (indexPaths.count == 0 || !self.dataSource) {
        return @[];
    }

    NSMutableOrderedSet<NSString *> *urls = [NSMutableOrderedSet orderedSet];
    for (NSIndexPath *indexPath in indexPaths) {
        PPHomeItem *item = [self.dataSource itemIdentifierForIndexPath:indexPath];
        NSString *url = item.universalViewModel.imageURL;
        if (url.length > 0) {
            [urls addObject:url];
        }
    }

    return urls.array;
}

- (void)pp_prefetchImagesAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    NSArray<NSString *> *urls = [self pp_imageURLsFromIndexPaths:indexPaths];
    if (urls.count == 0) {
        return;
    }

    [[PPImageLoaderManager shared] prefetchURLs:urls];
}

- (void)pp_prefetchTopImagesWithLimit:(NSInteger)limit
{
    if (limit <= 0 || !self.dataSource) {
        return;
    }

    NSDiffableDataSourceSnapshot<NSNumber *, PPHomeItem *> *snapshot =
    self.dataSource.snapshot;
    NSArray<NSNumber *> *sections = snapshot.sectionIdentifiers;
    if (sections.count == 0) {
        return;
    }

    NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray array];
    NSInteger remaining = limit;

    for (NSInteger sectionIndex = 0;
         sectionIndex < (NSInteger)sections.count && remaining > 0;
         sectionIndex++) {
        NSArray<PPHomeItem *> *items =
        [snapshot itemIdentifiersInSectionWithIdentifier:sections[(NSUInteger)sectionIndex]];

        for (NSInteger itemIndex = 0;
             itemIndex < (NSInteger)items.count && remaining > 0;
             itemIndex++) {
            PPHomeItem *item = items[(NSUInteger)itemIndex];
            if (item.universalViewModel.imageURL.length == 0) {
                continue;
            }

            [indexPaths addObject:[NSIndexPath indexPathForItem:itemIndex
                                                       inSection:sectionIndex]];
            remaining--;
        }
    }

    [self pp_prefetchImagesAtIndexPaths:indexPaths];
}

- (void)collectionView:(UICollectionView *)collectionView
prefetchItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    (void)collectionView;
    [self pp_prefetchImagesAtIndexPaths:indexPaths];
}

- (void)collectionView:(UICollectionView *)collectionView
cancelPrefetchingForItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    (void)collectionView;
    if (indexPaths.count == 0) {
        return;
    }
    [[PPImageLoaderManager shared] cancelAllPrefetching];
}

- (void)pp_asyncBlurHashImageForHash:(NSString *)hash
                                size:(CGSize)size
                          completion:(void (^)(UIImage * _Nullable image))completion
{
    if (hash.length == 0) {
        if (completion) {
            completion(nil);
        }
        return;
    }

    UIImage *cached = [self.blurHashCache objectForKey:hash];
    if (cached) {
        if (completion) {
            completion(cached);
        }
        return;
    }

    dispatch_async(self.blurHashQueue, ^{
        UIImage *image = [PPBlurHashBridge imageFrom:hash
                                            syncSize:size
                                               punch:1.0];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (image) {
                [self.blurHashCache setObject:image forKey:hash];
            }
            if (completion) {
                completion(image);
            }
        });
    });
}


- (void)dealloc
{
    [[PPHomePromoCarouselManager sharedManager] stopListening];
    [self pp_stopCurrentOrdersListener];
    [self stopNearbyRefreshTimer];
    [self pp_stopHomeSmartSearchTimer];
    self.collectionView.prefetchDataSource = nil;
    [[PPImageLoaderManager shared] cancelAllPrefetching];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
- (NSArray<PPHomeItem *> *)identifiersForIndexPaths:(NSArray<NSIndexPath *> *)paths {
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:paths.count];

    for (NSIndexPath *path in paths) {
        PPHomeItem *item = [self.dataSource itemIdentifierForIndexPath:path];

        if (item) {
            [items addObject:item];
        }
    }

    return items;
}

- (void)openNearestVet {
    // push nearest vet map / list
    NSLog(@"PPHomeQuickActionNearestVet");
    PPVetLocator *vc = [PPVetLocator new];
    [PPFunc presentSheetFrom:self sheetVC:vc detentStyle:PPSheetDetentStyle70];
}

- (void)openAccessories {
    // push accessories listing
    NSLog(@"PPHomeQuickActionAccessories");
}

- (void)openFood {
    // push food listing
    NSLog(@"PPHomeQuickActionFood");
}

#pragma mark - UICollectionViewDelegate

// MARK: - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView
    didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    PPHomeSection section = [self sectionTypeForIndexPath:indexPath];
    if (section == PPHomeSectionHero) {
        [self presentHomeLocationSheet];
        return;
    }

    NSLog(@"[Home][Tap] section=%ld item=%ld",
             (long)indexPath.section,
             (long)indexPath.item);


    PPHomeItem *item =
        [self.dataSource itemIdentifierForIndexPath:indexPath];

    if (!item) {
        return;
    }

    switch (section) {
        case PPHomeSectionQuickActions:
            return;

        case PPHomeSectionServices: {
            [self pp_emitSelectionHaptic];
            NSLog(@"[Home][Tap][Services] tapped service=%@",
                  item.payload);
            PPHomeServiceItem *service =
                (PPHomeServiceItem *)item.payload;

            if (![service isKindOfClass:PPHomeServiceItem.class]) {
                return;
            }

            [self handleServiceSelection:service
                           fromIndexPath:indexPath];
            break;
        }

        case PPHomeSectionMainKinds: {
            [self pp_emitSelectionHaptic];
            if (![item.payload isKindOfClass:MainKindsModel.class]) {
                return;
            }

            MainKindsModel *kind = (MainKindsModel *)item.payload;
            BOOL isAll = (kind.ID == -1);

            NSLog(@"[Home][Tap][MainKinds] isAll=%@ payload=%@",
                  isAll ? @"YES" : @"NO",
                  item.payload);

            if (isAll) {
                // ✅ Route ALL to DataViewVC
                [self handleDeepLinkWithTarget:PPDeepLinkTargetAllCategories
                                      mainKind:nil
                                        source:PPInputSourceHomeMainKindsSection];
                return;
            }


            // ✅ Route specific kind
            [self handleMainKindSelection:kind];
            return;
            break;
        }

        case PPHomeSectionCurrentOrders: {
            [self pp_emitSelectionHaptic];
            if (![item.payload isKindOfClass:PPOrder.class]) {
                return;
            }
            [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
            [self pp_openOrderDetailsForOrder:(PPOrder *)item.payload];
            return;
        }

        case PPHomeSectionSuggestions: {
            [self pp_emitSelectionHaptic];
            PPUniversalCellViewModel *vm = item.universalViewModel;
            id model = vm.ModelObject;

            if (!model) return;

            // 🔥 Track browse history (important for "Because you viewed")
            if ([model isKindOfClass:PetAd.class]) {
                PetAd *ad = (PetAd *)model;

                [[PPBrowseHistoryManager shared]
                    trackItemWithType:PPBrowseItemTypeAd
                           mainKindID:ad.category];
            }
            else if ([model isKindOfClass:PetAccessory.class]) {
                PetAccessory *acc = (PetAccessory *)model;

                [[PPBrowseHistoryManager shared]
                    trackItemWithType:PPBrowseItemTypeAccessory
                           mainKindID:acc.petMainCategoryID];
            }

            // ✅ Open overlay (same UX as nearby / accessories)
            [self pp_openOverlayForObject:model];
            break;
        }

        case PPHomeSectionAccessories:
        case PPHomeSectionBuyAgain:
        case PPHomeSectionAdsNearBy: {
            [self pp_emitSelectionHaptic];
             PPUniversalCellViewModel *vm = item.universalViewModel;
            id model = vm.ModelObject;

            NSLog(@"[Home][Tap][ResolvedModel] %@",
                  NSStringFromClass([model class]));

            if (!model) return;

            [self pp_openOverlayForObject:model];
            break;
        }

        case PPHomeSectionAdopt: {
            [self pp_emitSelectionHaptic];
            NSLog(@"[Home][Tap][Adopt] Open BitsViewController");

            AdoptPetsViewController *vc = [[AdoptPetsViewController alloc] init];
            vc.pp_transitionStyle = PPTransitionStyleNone;

            PPNavigationController *nav =
                (PPNavigationController *)[PPHomeHelper currentNavigationControllerFor:self];
            if (!nav) return;

            [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
            break;
        }

        default:
            break;
    }
}

- (void)collectionView:(UICollectionView *)collectionView
didHighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    PPHomeSection section = [self sectionTypeForIndexPath:indexPath];
    if (section == PPHomeSectionHero ||
        section == PPHomeSectionCurrentOrders ||
        section == PPHomeSectionCarousel) {
        return;
    }

    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    [self pp_animateHomeCell:cell highlighted:YES];
}

- (void)collectionView:(UICollectionView *)collectionView
didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    [self pp_animateHomeCell:cell highlighted:NO];
}

#pragma mark - Overlay Routing (Home → OverlayCoordinator)

- (void)pp_openOverlayForObject:(id)object
{
    if ([object isKindOfClass:PetAd.class]) {
        PetAd *ad = object;
        [[PPBrowseHistoryManager shared]
            trackItemWithType:PPBrowseItemTypeAd
                   mainKindID:ad.category];
    }
    else if ([object isKindOfClass:PetAccessory.class]) {
        PetAccessory *acc = object;
        [[PPBrowseHistoryManager shared]
            trackItemWithType:PPBrowseItemTypeAccessory
                   mainKindID:acc.petMainCategoryID];
    }


    if (!object) return;
    UIViewController *sourceVC = self;
    [PPOverlayCoordinator pp_openDetailForObject:object
                                         fromVC:sourceVC
                                     routingNav:nil];
}


- (BOOL)isCategorySelected:(MainKindsModel *)kind
{
    if (!kind) {
        return self.selectedCategory == nil; // All
    }

    return self.selectedCategory &&
           kind.ID == self.selectedCategory.ID;
}
- (void)handleServiceSelection:(PPHomeServiceItem *)service
                 fromIndexPath:(NSIndexPath *)indexPath {
    switch (service.type) {
        case PPHomeServiceTypeVet:
            [self openNearestVet];
            break;

        case PPHomeServiceTypeGrooming:
            [self handleDeepLinkWithTarget:PPDeepLinkTargetGrooming
                                  mainKind:nil
                                    source:PPInputSourceHomeServicesSection];
            break;

        case PPHomeServiceTypeTraining:
            [self handleDeepLinkWithTarget:PPDeepLinkTargetTraning
                                  mainKind:nil
                                    source:PPInputSourceHomeServicesSection];
            break;

        case PPHomeServiceTypeFood:
            [self handleDeepLinkWithTarget:PPDeepLinkTargetFood
                                  mainKind:nil
                                    source:PPInputSourceHomeServicesSection];
            break;
    }
}

- (CGFloat)currentYOffsetForSection:(PPHomeSection)section {
    NSIndexPath *headerIndexPath = [NSIndexPath indexPathForItem:0 inSection:section];

    UICollectionViewLayoutAttributes *attrs =
        [self.collectionView layoutAttributesForSupplementaryElementOfKind:@"PPHomeSectionHeaderKind"
                                                               atIndexPath:headerIndexPath];

    if (!attrs) {
        return self.collectionView.contentOffset.y;
    }

    return attrs.frame.origin.y - self.collectionView.contentOffset.y;
}

#pragma mark - View Data Routing (PPDataViewVC)

// MainKinds now open unified PPDataViewVC
- (void)handleMainKindSelection:(MainKindsModel *)kind {
    if (!kind) {
        return;
    }

    // Build input object for PPDataViewVC
    PPDataViewInput *input = [PPDataViewInput inputWithMainKind:kind sourceTarget:PPDeepLinkTargetAds source:PPInputSourceHomeMainKindsSection];
    PPDataViewVC *vc =  [[PPDataViewVC alloc] initWithInput:input];
    vc.pp_transitionStyle = PPTransitionStyleNone;
    if (![PPHomeHelper pushViewControllerSafely:vc from:self animated:YES]) {
        return;
    }
}

- (void)handleDeepLinkWithTarget:(PPDeepLinkTarget)target
                        mainKind:(MainKindsModel *)mainKind
                          source:(PPInputSource)source
{
    NSLog(@"[MainKindsModel] handleDeepLinkWithTarget resolvedKind %@",
          mainKind ? mainKind.KindName : @"(nil)");
    UINavigationController *nav = [PPHomeHelper currentNavigationControllerFor:self];

    if (!nav) {
        NSLog(@"[DeepLink] ❌ No navigation controller available");
        return;
    }

    UIViewController *vc;

    switch (target) {
        case PPDeepLinkTargetAllCategories: {
            NSLog(@"[DeepLink] Building ALL MainKinds DataViewVC");

            PPDataViewInput *input =
                [PPDataViewInput inputWithMainKindsArr:self.mainKinds
                                          sourceTarget:PPDeepLinkTargetAllCategories
                                                source:source];

            PPDataViewVC *allVC =
                [[PPDataViewVC alloc] initWithInput:input];

            allVC.pp_transitionStyle = PPTransitionStyleNone;
            [PPHomeHelper pushViewControllerSafely:allVC from:self animated:YES];
            return;
        }
        case PPDeepLinkTargetAccessories:
        case PPDeepLinkTargetFood:
        case PPDeepLinkTargetServices:
        case PPDeepLinkTargetGrooming:
        case PPDeepLinkTargetTraning:
        case PPDeepLinkTargetNewByAds:
        case PPDeepLinkTargetAds:{
            vc = [self buildDataViewVCForTarget:target
                                       mainKind:mainKind
                                         source:source];

            if (!vc) {
                NSLog(@"[DeepLink] ❌ Failed to build destination VC"); return;
            }

            break;
        }

        default:{
            vc = [self buildDataViewVCForTarget:target mainKind:mainKind source:source];

            if (!vc) {
                NSLog(@"[DeepLink] ❌ Failed to build destination VC"); return;
            }
        }

        break;
    }
    // =========================
    // Navigate Safely
    // =========================

    [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
}

// Unified builder for PPDataViewVC for deep-link targets
- (PPDataViewVC *)buildDataViewVCForTarget:(PPDeepLinkTarget)target
                                  mainKind:(MainKindsModel *_Nullable)mainKind
                                    source:(PPInputSource)source
{
    PPDataViewInput *input;
    if (mainKind) {
        input = [PPDataViewInput inputWithMainKind:mainKind
                                      sourceTarget:target
                                            source:source];
    } else {
        input = [PPDataViewInput inputWithMainKind:nil
                                      sourceTarget:target
                                            source:source];
    }

    if (!input) {
        return nil;
    }

    // Create unified data viewer
    PPDataViewVC *vc =
        [[PPDataViewVC alloc] initWithInput:input];

    vc.pp_transitionStyle = PPTransitionStyleNone;
    return vc;
}

- (BOOL)deepLinkTargetRequiresMainKind:(PPDeepLinkTarget)target {
    switch (target) {
        case PPDeepLinkTargetAds:
        case PPDeepLinkTargetAccessories:
        case PPDeepLinkTargetFood:
        case PPDeepLinkTargetServices:
            return YES;    // Global listings

        default:
            return NO;
    }
}

- (MainKindsModel *)resolveMainKindWithID:(NSInteger)mainKindID {
    for (MainKindsModel *kind in self.mainKinds) {
        if (kind.ID == mainKindID) {
            return kind;
        }
    }

    return nil;
}

- (NSString *)heroBaseGreetingText
{
    return [PPHomeGreetingProvider baseGreetingForDate:NSDate.date];
}

- (NSString *)heroDisplayNameText
{
    if (!PPIsUserLoggedIn) {
        return @"";
    }

    id resolvedUser = PPCurrentUser ?: UserManager.sharedManager.currentUser;
    if (!resolvedUser) {
        return @"";
    }

    NSString *bestName = PPSafeString([resolvedUser valueForKey:@"PPBestDisplayName"]);
    if (bestName.length > 0) {
        return bestName;
    }

    NSString *username = PPSafeString([resolvedUser valueForKey:@"UserName"]);
    return username.length > 0 ? username : @"";
}

- (NSString *)heroCountryText
{
    switch (self.nearbyLocationState) {
        case PPNearbyLocationStateLoading:
            return kLang(@"Loading...") ?: @"Loading...";
        case PPNearbyLocationStateDenied:
            return kLang(@"Location permission denied") ?: @"Location permission denied";
        case PPNearbyLocationStateReady:
            if (self.selectedNearbyAreaName.length > 0) {
                return self.selectedNearbyAreaName;
            }
            return kLang(@"Select your location") ?: @"Select your location";
        case PPNearbyLocationStateUnset:
        default:
            return kLang(@"Select your location") ?: @"Select your location";
    }
}

- (NSString *)heroLocationActionTitle
{
    switch (self.nearbyLocationState) {
        case PPNearbyLocationStateDenied:
            return kLang(@"Open Settings") ?: @"Open Settings";
        case PPNearbyLocationStateReady:
            return kLang(@"Hero_ChangeArea") ?: @"Change area";
        case PPNearbyLocationStateUnset:
            return kLang(@"Hero_LocationCTA") ?: @"Choose area";
        case PPNearbyLocationStateLoading:
        default:
            return nil;
    }
}

- (NSString *)pp_sanitizedHeroLine:(NSString *)line
{
    NSString *safe = PPSafeString(line);
    safe = [safe stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    safe = [safe stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
    return [safe stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)heroGreetingText
{
    PPHomeGreetingModel *model =
        [PPHomeGreetingProvider modelForDate:NSDate.date
                                 displayName:[self heroDisplayNameText]];
    NSString *headline = [self pp_sanitizedHeroLine:model.headlineText];
    if (headline.length > 0) {
        return headline;
    }
    return [self pp_sanitizedHeroLine:[self heroBaseGreetingText]];
}

- (void)openAdoption {
    AdoptPetsViewController *vc = [[AdoptPetsViewController alloc] init];

    vc.pp_transitionStyle = PPTransitionStyleNone;
}

- (NSArray<PPHomeQuickActionModel *> *)pp_homeQuickActions
{
    return [PPHomeQuickActionModel defaultHomeQuickActions];
}

- (void)handleQuickActionSelection:(PPHomeQuickActionModel *)quickAction
{
    if (![quickAction isKindOfClass:PPHomeQuickActionModel.class]) {
        return;
    }

    [self pp_emitSoftImpactHaptic];

    switch (quickAction.type) {
        case PPHomeQuickActionTypeNearestVet:
            [self openNearestVet];
            break;
        case PPHomeQuickActionTypeSellPet:
        case PPHomeQuickActionTypeAddAd:
            [self pp_openAddNewAdComposer];
            break;
        case PPHomeQuickActionTypeAdopt:
            [self pp_openAdoptFlow];
            break;
        case PPHomeQuickActionTypeRequestService:
            [self handleDeepLinkWithTarget:PPDeepLinkTargetServices
                                  mainKind:nil
                                    source:PPInputSourceHomeServicesSection];
            break;
    }
}

- (void)pp_openAddNewAdComposer
{
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    if (UserManager.sharedManager.isCurrentUserBlocked) {
        [PPAlertHelper showErrorIn:self
                             title:(kLang(@"Account blocked") ?: @"Account blocked")
                          subtitle:(kLang(@"Your account is blocked. You can't add ads right now.") ?: @"Your account is blocked. You can't add ads right now.")];
        return;
    }

    UserModel *currentUser = UserManager.sharedManager.currentUser;
    BOOL canPostAds = [currentUser hasAnyPermissionInKeys:@[kPermPostAds, kPermAdminAll]];
    if (!canPostAds) {
        [PPAlertHelper showErrorIn:self
                             title:(kLang(@"Permission denied") ?: @"Permission denied")
                          subtitle:(kLang(@"You don't have permission to add ads.") ?: @"You don't have permission to add ads.")];
        return;
    }

    AddNewAd *vc = [AddNewAd new];
    vc.mode = AdEditorModeCreate;
    vc.FromVC = @"HomeVC";
    vc.pp_transitionStyle = PPTransitionStyleNone;
    [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
}

- (void)pp_openAdoptFlow
{
    AdoptPetsViewController *vc = [[AdoptPetsViewController alloc] init];
    vc.pp_transitionStyle = PPTransitionStyleNone;
    [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
}

- (NSArray<NSDictionary *> *)pp_recentNearbyLocationRecords
{
    id savedRecords =
        [[NSUserDefaults standardUserDefaults] objectForKey:PPNearbyRecentLocationsKey];
    if (![savedRecords isKindOfClass:NSArray.class]) {
        return @[];
    }

    NSMutableArray<NSDictionary *> *records = [NSMutableArray array];
    for (NSDictionary *record in (NSArray *)savedRecords) {
        if (![record isKindOfClass:NSDictionary.class]) {
            continue;
        }

        NSNumber *latitude = record[@"latitude"];
        NSNumber *longitude = record[@"longitude"];
        NSString *title = PPSafeString(record[@"title"]);
        CLLocationCoordinate2D coordinate =
            CLLocationCoordinate2DMake(latitude.doubleValue, longitude.doubleValue);
        if (!CLLocationCoordinate2DIsValid(coordinate) || title.length == 0) {
            continue;
        }
        [records addObject:record];
    }

    [records sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        NSNumber *time1 = obj1[@"timestamp"];
        NSNumber *time2 = obj2[@"timestamp"];
        return [time2 compare:time1];
    }];

    if (records.count > PPNearbyRecentLocationsLimit) {
        return [records subarrayWithRange:NSMakeRange(0, PPNearbyRecentLocationsLimit)];
    }
    return records.copy;
}

- (void)pp_recordRecentNearbyLocationCoordinate:(CLLocationCoordinate2D)coordinate
                                          title:(NSString *)title
                                         source:(NSString *)source
{
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        return;
    }

    NSString *safeTitle = PPSafeString(title);
    if (safeTitle.length == 0) {
        return;
    }

    NSMutableArray<NSDictionary *> *records =
        [[self pp_recentNearbyLocationRecords] mutableCopy] ?: [NSMutableArray array];
    NSMutableArray<NSDictionary *> *filtered = [NSMutableArray array];

    for (NSDictionary *record in records) {
        NSNumber *latitude = record[@"latitude"];
        NSNumber *longitude = record[@"longitude"];
        NSString *existingTitle = PPSafeString(record[@"title"]);
        BOOL sameTitle = [existingTitle isEqualToString:safeTitle];
        BOOL sameCoordinate =
            fabs(latitude.doubleValue - coordinate.latitude) < 0.0001 &&
            fabs(longitude.doubleValue - coordinate.longitude) < 0.0001;
        if (sameTitle || sameCoordinate) {
            continue;
        }
        [filtered addObject:record];
    }

    NSDictionary *newRecord = @{
        @"latitude" : @(coordinate.latitude),
        @"longitude" : @(coordinate.longitude),
        @"title" : safeTitle,
        @"source" : PPSafeString(source),
        @"timestamp" : @([[NSDate date] timeIntervalSince1970])
    };
    [filtered insertObject:newRecord atIndex:0];

    if (filtered.count > PPNearbyRecentLocationsLimit) {
        [filtered removeObjectsInRange:NSMakeRange(PPNearbyRecentLocationsLimit,
                                                   filtered.count - PPNearbyRecentLocationsLimit)];
    }

    [[NSUserDefaults standardUserDefaults] setObject:filtered.copy
                                              forKey:PPNearbyRecentLocationsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)pp_applyNearbyLocationRecord:(NSDictionary *)record
{
    if (![record isKindOfClass:NSDictionary.class]) {
        return;
    }

    NSNumber *latitude = record[@"latitude"];
    NSNumber *longitude = record[@"longitude"];
    NSString *title = PPSafeString(record[@"title"]);
    CLLocationCoordinate2D coordinate =
        CLLocationCoordinate2DMake(latitude.doubleValue, longitude.doubleValue);
    if (!CLLocationCoordinate2DIsValid(coordinate) || title.length == 0) {
        return;
    }

    self.isUsingManualNearbySelection = YES;
    self.selectedNearbyCoordinate = coordinate;
    self.hasSelectedNearbyCoordinate = YES;
    self.selectedNearbyAreaName = title;
    self.nearbyLocationState = PPNearbyLocationStateReady;
    self.nearbyRadiusKm = PPNearbyDefaultRadiusKm;
    [self pp_recordRecentNearbyLocationCoordinate:coordinate title:title source:@"recent"];
    [self persistNearbyLocationIfNeeded];
    [self refreshHeroSectionAppearance];
    [self refreshNearbyAdsForce:YES reason:@"recent-location"];
    [self pp_emitSelectionHaptic];
}

- (NSDictionary<NSString *, NSString *> *)pp_suggestionReasonForModel:(id)model
                                                          latestEvent:(NSDictionary *)latestEvent
                                                    orderedAccessoryIDs:(NSArray<NSString *> *)orderedAccessoryIDs
{
    if ([model isKindOfClass:PetAccessory.class]) {
        PetAccessory *accessory = (PetAccessory *)model;
        NSString *accessoryID = PPSafeString(accessory.accessoryID);
        if (accessoryID.length > 0 && [orderedAccessoryIDs containsObject:accessoryID]) {
            return @{
                @"text" : (kLang(@"home_suggestion_reason_previous_orders") ?: @"Based on your previous orders"),
                @"icon" : @"clock.arrow.circlepath"
            };
        }
    }

    NSString *browseReason = [self pp_browseReasonTextForEvent:latestEvent];
    NSInteger latestKindID = [latestEvent[@"kind"] integerValue];
    PPBrowseItemType latestType = [latestEvent[@"type"] integerValue];

    if (browseReason.length > 0) {
        if ([model isKindOfClass:PetAd.class]) {
            PetAd *ad = (PetAd *)model;
            if (latestType == PPBrowseItemTypeAd && ad.category == latestKindID) {
                return @{
                    @"text" : browseReason,
                    @"icon" : @"sparkles"
                };
            }
        } else if ([model isKindOfClass:PetAccessory.class]) {
            PetAccessory *accessory = (PetAccessory *)model;
            if (latestType == PPBrowseItemTypeAccessory &&
                accessory.petMainCategoryID == latestKindID) {
                return @{
                    @"text" : browseReason,
                    @"icon" : @"sparkles"
                };
            }
        }
    }

    if ([model isKindOfClass:PetAd.class]) {
        return @{
            @"text" : (kLang(@"home_suggestion_reason_nearby") ?: @"Near you"),
            @"icon" : @"location.fill"
        };
    }

    return nil;
}

- (NSString *)pp_browseReasonTextForEvent:(NSDictionary *)event
{
    if (![event isKindOfClass:NSDictionary.class]) {
        return @"";
    }

    NSInteger kindID = [event[@"kind"] integerValue];
    PPBrowseItemType type = [event[@"type"] integerValue];
    MainKindsModel *kind = [self resolveMainKindWithID:kindID];
    if (!kind) {
        return @"";
    }

    NSString *typeKey =
        type == PPBrowseItemTypeAd
        ? (kLang(@"BrowseType_Ads") ?: @"ads")
        : type == PPBrowseItemTypeAccessory
            ? (kLang(@"BrowseType_Accessories") ?: @"accessories")
            : (kLang(@"BrowseType_Services") ?: @"services");
    NSString *format = kLang(@"BecauseYouViewedFormat") ?: @"Because you viewed %@ %@";
    return [NSString stringWithFormat:format, typeKey, kind.KindName ?: @""];
}

- (void)pp_emitSelectionHaptic
{
    UISelectionFeedbackGenerator *generator = [[UISelectionFeedbackGenerator alloc] init];
    [generator selectionChanged];
}

- (void)pp_emitSoftImpactHaptic
{
    UIImpactFeedbackGenerator *generator =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
    [generator impactOccurred];
}

- (void)pp_animateHomeCell:(UICollectionViewCell *)cell highlighted:(BOOL)highlighted
{
    if (!cell) {
        return;
    }

    if (UIAccessibilityIsReduceMotionEnabled()) {
        cell.transform = CGAffineTransformIdentity;
        cell.alpha = 1.0;
        return;
    }

    [UIView animateWithDuration:(highlighted ? 0.12 : 0.20)
                          delay:0.0
         usingSpringWithDamping:(highlighted ? 1.0 : 0.78)
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        cell.transform = highlighted ? CGAffineTransformMakeScale(0.975, 0.975) : CGAffineTransformIdentity;
        cell.alpha = highlighted ? 0.96 : 1.0;
    } completion:nil];
}



- (void)setProfileCard
{
    UIImage *profileAvatar = [UIImage systemImageNamed:@"person.crop.circle.fill"];
    NSString *title = [UsrMgr profileNameAndTitleWithMode:ProfileGreetingShorteningModeShotNameOnly] ? : @"";
    NSString *subtitle = Language.isRTL ? CitiesManager.shared.CurrentCountry.arName : CitiesManager.shared.CurrentCountry.enName ? : @"";
    UIButton *profile = (UIButton *)[self pp_profileViewWithImage:profileAvatar
                                              title:title
                                           subtitle:subtitle
                                          userModel:PPCurrentUser
                                             target:self
                                             action:@selector(profileTapped:)];

    if (@available(iOS 26.0, *)) {
        profile.configuration = [UIButtonConfiguration glassButtonConfiguration];
    } else {
        profile.configuration = nil;
        profile.layer.cornerRadius = 22;
        profile.clipsToBounds = YES;
    }

    self.profileCard =
        [self pp_wrappedNavigationTitleView:profile];
    self.profileCard.translatesAutoresizingMaskIntoConstraints = NO;
   // [self.view addSubview:self.profileCard];
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self configureNavigationBar];
    [self updateCartQuantityBadge];
    if (self.accessoriesLoaded || self.nearbyLoaded) {
        [self reloadSection:PPHomeSectionSuggestions];
    }
    [self refreshCurrentOrdersForce:NO];
    [self refreshHeroSectionAppearance];

    PPNavigationController *nav = (PPNavigationController *)self.navigationController;
    if (nav) {
        UIGestureRecognizer *pop = nav.interactivePopGestureRecognizer;

        pop.delegate = nil;   // 🔥 reset UIKit state
        pop.enabled = YES;
        pop.delegate = self;
    }

    if (!self.didAutoScrollSuggestions) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.didAutoScrollSuggestions = YES;
        });
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.isHomeScreenVisible = NO;
    [self pp_stopBackgroundAnimations];
    self.lastObservedHomeOrderID = nil;
    self.lastObservedHomeOrderStatusKey = nil;
    [self pp_stopCurrentOrdersListener];
    [self stopNearbyRefreshTimer];
    [self pp_stopHomeSmartSearchTimer];
}

// Show bottom card with haptic feedback
- (void)showBottomCard:(UIView *)card
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self showBottomCard:card]; });
        return;
    }
    // Hardware haptic feedback
    UIImpactFeedbackGenerator *gen =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
    [gen prepare];
    [gen impactOccurred];

    card.hidden = NO;
    card.transform = CGAffineTransformMakeTranslation(0, 40);
    card.alpha = 0.0;

    [UIView animateWithDuration:0.45
                          delay:0
         usingSpringWithDamping:0.85
          initialSpringVelocity:0.6
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        card.transform = CGAffineTransformIdentity;
        card.alpha = 1.0;
    } completion:nil];
}


// Hide bottom card with haptic feedback
- (void)hideBottomCard:(UIView *)card
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self hideBottomCard:card]; });
        return;
    }
    // Hardware haptic feedback
    UIImpactFeedbackGenerator *gen =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [gen prepare];
    [gen impactOccurred];

    [UIView animateWithDuration:0.25
                          delay:0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        card.transform = CGAffineTransformMakeTranslation(0, 30);
        card.alpha = 0.0;
    } completion:^(BOOL finished) {
        card.hidden = YES;
        card.transform = CGAffineTransformIdentity;
    }];
}

- (void)cartClick
{
    NSLog(@"[Cart] Tap");

    if (!PPIsUserLoggedIn) { [UserManager showPromptOnTopController]; return; }

    CartViewController *vc = [[CartViewController alloc] init];
    vc.pp_transitionStyle = PPTransitionStyleFade;

    // Embed in nav
    PPNavigationController *nav =
        [[PPNavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;

    // ✅ PRESENT THE NAV — NOT vc
    [PPHomeHelper presentViewControllerSafely:nav
                                         from:self
                                     animated:YES
                                   completion:nil];
}

- (void)configureNavigationBar {
     self.navigationItem.title = nil;
    UIView *centerView= [self pp_navigationSmartSearchTitleView];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    UIBarButtonItem *profileItem = [self pp_buildProfileBarButtonItem];
    self.homeProfileItem = profileItem;
    self.homeCartItem = [self pp_buildCartBarButtonItem];

    self.navigationItem.leftBarButtonItems  = @[profileItem];
    [self refreshNavigationRightItemsForCartCount:[CartManager.sharedManager totalItemsCount]];
    [self pp_updateHomeSmartSearchPlaceholderAnimated:NO];
    [self pp_startHomeSmartSearchTimerIfNeeded];

    [self pp_navBarSetTitleViewCentered:centerView];
}

- (UIBarButtonItem *)pp_buildCartBarButtonItem
{
    static const CGFloat kSize = 36.0;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0, 0, kSize, kSize);
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.contentEdgeInsets = UIEdgeInsetsZero;
    button.adjustsImageWhenHighlighted = NO;
    button.clipsToBounds = NO;
    button.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.60] ?: [UIColor colorWithWhite:0.95 alpha:1.0];
    button.layer.cornerRadius = kSize * 0.5;
    button.layer.borderWidth = 0.8;
    button.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor;
    button.layer.shadowColor = UIColor.blackColor.CGColor;
    button.layer.shadowOpacity = 0.06;
    button.layer.shadowRadius = 10.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 4.0);
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    button.accessibilityLabel = kLang(@"Cart") ?: @"Cart";
    [button addTarget:self action:@selector(cartClick) forControlEvents:UIControlEventTouchUpInside];

    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:kSize],
        [button.heightAnchor constraintEqualToConstant:kSize]
    ]];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:
        [UIImage pp_symbolNamed:@"cart.fill"
                      pointSize:18
                         weight:UIImageSymbolWeightRegular
                          scale:UIImageSymbolScaleMedium
                        palette:@[AppPrimaryTextClr ?: UIColor.labelColor]
                   makeTemplate:YES]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.tintColor = AppPrimaryTextClr ?: UIColor.labelColor;
    [button addSubview:iconView];

    [NSLayoutConstraint activateConstraints:@[
        [iconView.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:18.0],
        [iconView.heightAnchor constraintEqualToConstant:18.0]
    ]];

    PPInsetLabel *badgeLabel = [[PPInsetLabel alloc] init];
    badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    badgeLabel.textInsets = UIEdgeInsetsMake(1.5, 5.0, 1.5, 5.0);
    badgeLabel.textAlignment = NSTextAlignmentCenter;
    badgeLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
    badgeLabel.textColor = UIColor.whiteColor;
    badgeLabel.backgroundColor = UIColor.systemRedColor;
    badgeLabel.adjustsFontSizeToFitWidth = YES;
    badgeLabel.minimumScaleFactor = 0.82;
    badgeLabel.layer.cornerRadius = 8.5;
    badgeLabel.layer.borderWidth = 1.0;
    badgeLabel.layer.borderColor = [[UIColor blueColor] colorWithAlphaComponent:0.92].CGColor;
    badgeLabel.layer.masksToBounds = YES;
    badgeLabel.hidden = NO;
    badgeLabel.alpha = 1.0;
    badgeLabel.userInteractionEnabled = NO;
    //badgeLabel.layer.zPosition = 20.0f;
    if (@available(iOS 13.0, *)) {
        badgeLabel.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [button addSubview:badgeLabel];
    [button bringSubviewToFront:badgeLabel];

    NSLayoutConstraint *badgeMinWidth =
        [badgeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:17.0];
    badgeMinWidth.active = YES;
    [NSLayoutConstraint activateConstraints:@[
        [badgeLabel.heightAnchor constraintEqualToConstant:17.0],
        [badgeLabel.topAnchor constraintEqualToAnchor:button.topAnchor constant:1.0],
        [badgeLabel.trailingAnchor constraintEqualToAnchor:button.trailingAnchor constant:-1.0]
    ]];

    self.homeCartButton = button;
    self.homeCartBadgeLabel = badgeLabel;
    self.homeCartBadgeMinWidthConstraint = badgeMinWidth;

    return [[UIBarButtonItem alloc] initWithCustomView:button];
}


- (void)pp_showCartBarButtonAnimated
{
    if ([self.navigationItem.rightBarButtonItems containsObject:self.homeCartItem]) {
        return; // already visible
    }

    [UIView transitionWithView:self.navigationController.navigationBar
                      duration:0.25
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        self.navigationItem.rightBarButtonItems = @[self.homeCartItem];
    } completion:nil];
}

- (void)pp_hideCartBarButtonAnimated
{
    if (![self.navigationItem.rightBarButtonItems containsObject:self.homeCartItem]) {
        return; // already hidden
    }

    [UIView transitionWithView:self.navigationController.navigationBar
                      duration:0.20
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        self.navigationItem.rightBarButtonItems = @[];
    } completion:nil];
}

- (UIBarButtonItem *)pp_buildProfileBarButtonItem
{
    static const CGFloat kSize = 36.0;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0, 0, kSize, kSize);
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.contentEdgeInsets = UIEdgeInsetsZero;
    button.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.72] ?: [UIColor colorWithWhite:1.0 alpha:0.90];
    button.clipsToBounds = NO;
    button.layer.cornerRadius = kSize * 0.5;
    button.layer.borderWidth = 0.8;
    button.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor;
    button.layer.shadowColor = UIColor.blackColor.CGColor;
    button.layer.shadowOpacity = 0.06;
    button.layer.shadowRadius = 10.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 4.0);
    button.adjustsImageWhenHighlighted = NO;
    button.accessibilityLabel = kLang(@"Profile") ?: @"Profile";
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }

    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:kSize],
        [button.heightAnchor constraintEqualToConstant:kSize]
    ]];

    UIImageView *avatar = [[UIImageView alloc] init];
    avatar.translatesAutoresizingMaskIntoConstraints = NO;
    avatar.contentMode = UIViewContentModeScaleAspectFill;
    avatar.clipsToBounds = YES;
    avatar.layer.cornerRadius = (kSize * 0.5) - 1.0;
    avatar.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    [button addSubview:avatar];
    [NSLayoutConstraint activateConstraints:@[
        [avatar.topAnchor constraintEqualToAnchor:button.topAnchor constant:1.0],
        [avatar.leadingAnchor constraintEqualToAnchor:button.leadingAnchor constant:1.0],
        [avatar.trailingAnchor constraintEqualToAnchor:button.trailingAnchor constant:-1.0],
        [avatar.bottomAnchor constraintEqualToAnchor:button.bottomAnchor constant:-1.0]
    ]];

    // Placeholder
    UIImage *placeholder = [UIImage imageNamed:@"man"];
    UIImage *fallback =
        [UIImage pp_symbolNamed:@"person.crop.circle.fill"
                      pointSize:22
                         weight:UIImageSymbolWeightSemibold
                          scale:UIImageSymbolScaleMedium
                        palette:@[AppPrimaryClr ?: UIColor.systemTealColor]
                   makeTemplate:YES];

    avatar.image = placeholder ?: fallback;
    avatar.tintColor = placeholder ? nil : (AppPrimaryClr ?: UIColor.systemTealColor);
    avatar.contentMode = placeholder ? UIViewContentModeScaleAspectFill : UIViewContentModeCenter;

    // Remote image
    NSString *url = PPSafeString(PPCurrentUser.UserImageUrl.absoluteString);
    if (url.length > 0) {
        [GM setImageFromUrlString:url
                        imageView:avatar
                          phImage:@"man"
                       completion:^(UIImage * _Nullable image,
                                    NSError * _Nullable error)
        {
            if (!image || error) {
                avatar.image = placeholder ?: fallback;
                avatar.tintColor = placeholder ? nil : (AppPrimaryClr ?: UIColor.systemTealColor);
                avatar.contentMode = placeholder ? UIViewContentModeScaleAspectFill
                                                 : UIViewContentModeCenter;
                return;
            }
            avatar.image = image;
            avatar.tintColor = nil;
            avatar.contentMode = UIViewContentModeScaleAspectFill;
        }];
    }

    if (@available(iOS 14.0, *)) {
        // Combine user actions + app actions into a single profile menu
        UIMenu *userMenu = [PPActionButton userActionsArrayfor:self];
        UIMenu *appMenu  = [PPActionButton appActionsArrayfor:self];
        button.menu = [UIMenu menuWithTitle:@""
                                      image:nil
                                 identifier:nil
                                    options:UIMenuOptionsDisplayInline
                                   children:@[userMenu, appMenu]];
        button.showsMenuAsPrimaryAction = YES;
    }

    return [[UIBarButtonItem alloc] initWithCustomView:button];
}


- (void)refreshNavigationRightItemsForCartCount:(NSUInteger)count
{
    (void)count;
    if (!self.homeCartItem) {
        self.homeCartItem = [self pp_buildCartBarButtonItem];
    }

    BOOL isAlreadyShowing = [self.navigationItem.rightBarButtonItems containsObject:self.homeCartItem];
    if (!isAlreadyShowing || self.navigationItem.rightBarButtonItems.count != 1) {
        self.navigationItem.rightBarButtonItems = @[self.homeCartItem];
    }

    [self.homeCartItem.customView setNeedsLayout];
    [self.homeCartItem.customView layoutIfNeeded];
    [self.navigationController.navigationBar setNeedsLayout];
    [self.navigationController.navigationBar layoutIfNeeded];
}

- (void)pp_applyHomeCartBadgeCount:(NSInteger)count
{
    if (!self.homeCartBadgeLabel || !self.homeCartButton) {
        return;
    }

    NSInteger safeCount = MAX(count, 0);
    BOOL shouldShowBadge = safeCount > 0;
    NSString *text = (safeCount > 99) ? @"99+" : [NSString stringWithFormat:@"%ld", (long)safeCount];
    BOOL valueChanged = ![self.homeCartBadgeLabel.text isEqualToString:text];
    BOOL wasHidden = self.homeCartBadgeLabel.hidden;

    self.homeCartBadgeLabel.text = text;
    CGFloat textWidth = ceil([text sizeWithAttributes:@{NSFontAttributeName : self.homeCartBadgeLabel.font}].width) + 8.0;
    self.homeCartBadgeMinWidthConstraint.constant = MAX(16.0, textWidth);
    self.homeCartBadgeLabel.hidden = !shouldShowBadge;
    self.homeCartBadgeLabel.alpha = shouldShowBadge ? 1.0 : 0.0;
    self.homeCartBadgeLabel.backgroundColor = UIColor.redColor;
    [self.homeCartButton setNeedsLayout];
    [self.homeCartButton layoutIfNeeded];

    if (shouldShowBadge && (wasHidden || valueChanged)) {
        self.homeCartBadgeLabel.transform = CGAffineTransformMakeScale(0.82, 0.82);
        [UIView animateWithDuration:0.22
                              delay:0.0
             usingSpringWithDamping:0.72
              initialSpringVelocity:0.15
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.homeCartBadgeLabel.transform = CGAffineTransformIdentity;
        } completion:nil];
    } else if (!shouldShowBadge) {
        self.homeCartBadgeLabel.transform = CGAffineTransformIdentity;
    }
}

- (CGFloat)pp_preferredNavigationSearchWidth
{
    CGFloat screenWidth = CGRectGetWidth(UIScreen.mainScreen.bounds);
    return MIN(MAX(screenWidth - 112.0, 206.0), 320.0);
}

- (UIView *)pp_navigationSmartSearchTitleView
{
    CGFloat width = [self pp_preferredNavigationSearchWidth];
    if (!self.homeSmartSearchView) {
        self.homeSmartSearchView =
            [[PPHomeSmartSearchTitleView alloc] initWithFrame:CGRectMake(0.0, 0.0, width, 42.0)];
        [self.homeSmartSearchView addTarget:self
                                     action:@selector(pp_openSmartSearch)
                           forControlEvents:UIControlEventTouchUpInside];
    }

    CGRect frame = self.homeSmartSearchView.frame;
    frame.size.width = width;
    frame.size.height = 42.0;
    self.homeSmartSearchView.frame = frame;
    return self.homeSmartSearchView;
}

- (void)pp_openSmartSearch
{
    UINavigationController *nav = self.navigationController;
    PPSearchViewController *searchVC = nil;

    for (UIViewController *vc in nav.viewControllers.reverseObjectEnumerator) {
        if ([vc isKindOfClass:PPSearchViewController.class]) {
            searchVC = (PPSearchViewController *)vc;
            break;
        }
    }

    if (searchVC) {
        if (nav.topViewController != searchVC) {
            [nav popToViewController:searchVC animated:YES];
        }
    } else {
        searchVC = [PPSearchViewController new];
        [PPHomeHelper pushViewControllerSafely:searchVC from:self animated:YES];
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.28 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [searchVC focusSearchField];
    });
}

- (NSArray<NSString *> *)pp_resolvedHomeSmartSearchPlaceholders
{
    if (self.homeSmartSearchPlaceholders.count > 0) {
        return self.homeSmartSearchPlaceholders;
    }

    NSMutableArray<NSString *> *items = [NSMutableArray array];
    NSString *primaryPlaceholder = kLang(@"home_search_placeholder_short") ?: @"Search in Pure Pets";
    if (PPSafeString(primaryPlaceholder).length > 0) {
        [items addObject:primaryPlaceholder];
    }

    BOOL prefersExpandedExamples = [self pp_preferredNavigationSearchWidth] >= 232.0;
    NSArray<NSString *> *candidates = prefersExpandedExamples
        ? @[
            kLang(@"home_nav_search_example_cats") ?: @"Cats for sale",
            kLang(@"home_nav_search_example_vets") ?: @"Nearby vets",
            kLang(@"home_nav_search_example_food") ?: @"Dog food",
            kLang(@"home_nav_search_example_accessories") ?: @"Pet accessories"
        ]
        : @[
            kLang(@"home_nav_search_example_cats_compact") ?: @"Cats",
            kLang(@"home_nav_search_example_vets_compact") ?: @"Vet",
            kLang(@"home_nav_search_example_food_compact") ?: @"Food",
            kLang(@"home_nav_search_example_accessories_compact") ?: @"Gear"
        ];

    for (NSString *item in candidates) {
        NSString *safeItem = PPSafeString(item);
        if (safeItem.length > 0 && ![items containsObject:safeItem]) {
            [items addObject:safeItem];
        }
    }

    if (items.count == 0) {
        [items addObject:(kLang(@"home_search_placeholder_short") ?: @"Search in Pure Pets")];
    }

    self.homeSmartSearchPlaceholders = items.copy;
    self.homeSmartSearchPlaceholderIndex = 0;
    return self.homeSmartSearchPlaceholders;
}

- (NSString *)pp_currentHomeSmartSearchPlaceholder
{
    NSArray<NSString *> *placeholders = [self pp_resolvedHomeSmartSearchPlaceholders];
    if (placeholders.count == 0) {
        return kLang(@"home_search_placeholder_short") ?: @"Search in Pure Pets";
    }

    NSInteger safeIndex = MAX(0, MIN(self.homeSmartSearchPlaceholderIndex,
                                     (NSInteger)placeholders.count - 1));
    return placeholders[safeIndex];
}

- (void)pp_updateHomeSmartSearchPlaceholderAnimated:(BOOL)animated
{
    if (!self.homeSmartSearchView) {
        return;
    }

    [self.homeSmartSearchView setQueryText:[self pp_currentHomeSmartSearchPlaceholder]
                                  animated:animated];
}

- (void)pp_startHomeSmartSearchTimerIfNeeded
{
    [self pp_updateHomeSmartSearchPlaceholderAnimated:NO];

    NSArray<NSString *> *placeholders = [self pp_resolvedHomeSmartSearchPlaceholders];
    if (placeholders.count <= 1 || self.homeSmartSearchTimer) {
        return;
    }

    NSTimer *timer =
        [NSTimer timerWithTimeInterval:2.4
                                target:self
                              selector:@selector(pp_advanceHomeSmartSearchPlaceholder)
                              userInfo:nil
                               repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    self.homeSmartSearchTimer = timer;
}

- (void)pp_stopHomeSmartSearchTimer
{
    [self.homeSmartSearchTimer invalidate];
    self.homeSmartSearchTimer = nil;
}

- (void)pp_advanceHomeSmartSearchPlaceholder
{
    NSArray<NSString *> *placeholders = [self pp_resolvedHomeSmartSearchPlaceholders];
    if (placeholders.count == 0) {
        return;
    }

    self.homeSmartSearchPlaceholderIndex =
        (self.homeSmartSearchPlaceholderIndex + 1) % placeholders.count;
    [self pp_updateHomeSmartSearchPlaceholderAnimated:YES];
}

#pragma mark - Navigation Logo Title View

- (UIView *)pp_logoTitleView
{
    UIImage *logo = [UIImage imageNamed:@"newlogo"]; // 🔁 change name if needed
    if (!logo) return nil;

    UIImageView *logoView = [[UIImageView alloc] initWithImage:logo];
    logoView.translatesAutoresizingMaskIntoConstraints = NO;
    logoView.contentMode = UIViewContentModeScaleToFill;

    // Prevent compression / jumping
    [logoView setContentHuggingPriority:UILayoutPriorityRequired
                                forAxis:UILayoutConstraintAxisHorizontal];
    [logoView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                              forAxis:UILayoutConstraintAxisHorizontal];

    // Wrap using YOUR helper (important)
    UIView *wrapped = [self pp_wrappedNavigationTitleView:logoView];

    // Explicit size so UIKit never guesses
    CGFloat height =  46.0;

    [NSLayoutConstraint activateConstraints:@[
        [logoView.heightAnchor constraintEqualToConstant:height],
        [logoView.centerXAnchor constraintEqualToAnchor:wrapped.centerXAnchor],
        [logoView.centerYAnchor constraintEqualToAnchor:wrapped.centerYAnchor],
        [logoView.widthAnchor constraintEqualToConstant:height],

    ]];

    [NSLayoutConstraint activateConstraints:@[
        [wrapped.heightAnchor constraintEqualToConstant:height],
        [wrapped.widthAnchor constraintEqualToConstant:height],

    ]];

    return wrapped;
}

- (UIView *)pp_wrappedNavigationTitleView:(UIView *)content
{
    CGFloat navHeight = 36.0;

    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.hx_w - 32, navHeight)];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = UIColor.clearColor;

    content.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:content];

    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [content.topAnchor constraintEqualToAnchor:container.topAnchor],
        [content.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];

    return container;
}

#pragma mark - Top/Nav UI
- (void)profileTapped:(UIButton *)sender {
    // Menu is already presented via `showsMenuAsPrimaryAction`.
    // Keep this as a safe no-op fallback.
    (void)sender;
}

- (void)presentMenu:(UIMenu *)menu fromView:(UIView *)sourceView {
    (void)menu;
    (void)sourceView;
}

- (MainBannerModel *)pp_homeTopCarouselBannerGroup
{
    NSArray<MainBannerModel *> *candidates =
    [PPBannersManager.sharedManager.bannerGroups filteredArrayUsingPredicate:
     [NSPredicate predicateWithBlock:^BOOL (MainBannerModel *g, NSDictionary *_) {
        return (g.bannerViewHolder == PPBannerHolderMainView &&
                g.bannerViewPosition == PPBannerPositionTop &&
                g.bannerViewVisible);
    }]];

    if (candidates.count == 0) return nil;

    for (MainBannerModel *group in candidates) {
        if ([PPSafeString(group.bannerViewID) caseInsensitiveCompare:PPHomeTopCarouselBannerGroupID] == NSOrderedSame) {
            return group;
        }
    }

    NSArray<MainBannerModel *> *sorted =
    [candidates sortedArrayUsingComparator:^NSComparisonResult(MainBannerModel *a, MainBannerModel *b) {
        return [PPSafeString(a.bannerViewID) localizedCaseInsensitiveCompare:PPSafeString(b.bannerViewID)];
    }];
    return sorted.firstObject;
}



- (void)fillCarouselBanner
{
    NSDiffableDataSourceSnapshot *snapshot = self.dataSource.snapshot;

    NSArray *items =
        [snapshot itemIdentifiersInSectionWithIdentifier:@(PPHomeSectionCarousel)];
    if (items.count == 0) return;

    PPHomeItem *item = items.firstObject;

    NSArray<PPHomePromoCarouselCard *> *promoCards = self.promoCarouselCards;
    if (promoCards.count > 0) {
        item.payload = promoCards;
        [snapshot reloadItemsWithIdentifiers:@[item]];
        [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
        return;
    }

    MainBannerModel *homeTop = [self pp_homeTopCarouselBannerGroup];

    NSArray<PPHomePromoCarouselCard *> *legacyPromoCards = [self pp_promoCardsFromLegacyBannerGroup:homeTop];
    if (legacyPromoCards.count > 0) {
        item.payload = legacyPromoCards;
        [snapshot reloadItemsWithIdentifiers:@[item]];
        [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
        return;
    }

    if (!homeTop || homeTop.childBanners.count == 0) {
        NSArray<PPHomePromoCarouselCard *> *fallbackCards = [self pp_homePromoFallbackCards];
        if (fallbackCards.count > 0) {
            item.payload = fallbackCards;
            [snapshot reloadItemsWithIdentifiers:@[item]];
            [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
            return;
        }
        item.payload = [NSNull null];
        [snapshot reloadItemsWithIdentifiers:@[item]];
        [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
        return;
    }

    item.payload = homeTop;

    [snapshot reloadItemsWithIdentifiers:@[item]];
    [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
}


- (UIView *)pp_profileViewWithImage:(UIImage *_Nullable)image
                              title:(NSString *_Nullable)title
                           subtitle:(NSString *_Nullable)subtitle
                          userModel:(UserModel *_Nullable)usr
                             target:(id _Nullable)target
                             action:(SEL _Nullable)action
{
    static const CGFloat kAvatarSize = 36.0;
    static const CGFloat kMinHeight  = 46.0;

    // =====================================================
    // 1️⃣ Container (UIButton – nav-safe)
    // =====================================================
    PPHomeProfileView *container =
        [PPHomeProfileView buttonWithType:UIButtonTypeCustom];
    if (@available(iOS 26.0, *)) {
        container.configuration = [UIButtonConfiguration glassButtonConfiguration];
    } else {
        container.configuration = nil;
    }

    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.adjustsImageWhenHighlighted = NO;
    container.clipsToBounds = NO;

    container.semanticContentAttribute =
        Language.isRTL
        ? UISemanticContentAttributeForceRightToLeft
        : UISemanticContentAttributeForceLeftToRight;

    // Menu + tap safely coexist — combined user + app actions
    UIMenu *userMenu = [PPActionButton userActionsArrayfor:self];
    UIMenu *appMenu  = [PPActionButton appActionsArrayfor:self];
    container.menu = [UIMenu menuWithTitle:@""
                                     image:nil
                                identifier:nil
                                   options:UIMenuOptionsDisplayInline
                                  children:@[userMenu, appMenu]];
    container.showsMenuAsPrimaryAction = YES;

    if (target && action) {
        [container addTarget:target
                      action:action
            forControlEvents:UIControlEventTouchUpInside];
    }

    // Hard height for navigation bar stability
    [container.heightAnchor constraintGreaterThanOrEqualToConstant:kMinHeight].active = YES;

    // =====================================================
    // 2️⃣ Avatar
    // =====================================================
    UIImageView *avatar = [[UIImageView alloc] init];
    avatar.translatesAutoresizingMaskIntoConstraints = NO;
    avatar.contentMode = UIViewContentModeScaleAspectFill;
    avatar.layer.cornerRadius = kAvatarSize / 2.0;
    avatar.layer.masksToBounds = YES;
    avatar.tintColor = AppPrimaryTextClr;
    avatar.image = image ?: [UIImage systemImageNamed:@"person.crop.circle.fill"];

    [NSLayoutConstraint activateConstraints:@[
        [avatar.widthAnchor constraintEqualToConstant:kAvatarSize],
        [avatar.heightAnchor constraintEqualToConstant:kAvatarSize]
    ]];

    if (usr) {
        [GM setImageFromUrlString:PPSafeString(usr.UserImageUrl.absoluteString)
                        imageView:avatar
                          phImage:@"person.crop.circle.fill"];
    }

    // =====================================================
    // 3️⃣ Title
    // =====================================================
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:16];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.text = title ?: kLang(@"JoinUs");
    titleLabel.numberOfLines = 1;
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    // =====================================================
    // 4️⃣ Subtitle (icon + text, baseline safe)
    // =====================================================
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM fontWithSize:12];
    subtitleLabel.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    subtitleLabel.numberOfLines = 1;
    subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    if (subtitle.length > 0) {
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:11
                                                            weight:UIImageSymbolWeightRegular];

        NSTextAttachment *att = [[NSTextAttachment alloc] init];
        att.image = [UIImage systemImageNamed:@"location.fill"
                             withConfiguration:cfg];
        att.bounds = CGRectMake(0, -1.5, 12, 12);

        NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] init];
        [attr appendAttributedString:[NSAttributedString attributedStringWithAttachment:att]];
        [attr appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
        [attr appendAttributedString:[[NSAttributedString alloc] initWithString:subtitle]];

        subtitleLabel.attributedText = attr;
    }

    // =====================================================
    // 5️⃣ Text stack
    // =====================================================
    UIStackView *textStack =
        [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, subtitleLabel]];

    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 0;
    textStack.alignment = UIStackViewAlignmentLeading;

    [titleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                forAxis:UILayoutConstraintAxisHorizontal];
    [subtitleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                   forAxis:UILayoutConstraintAxisHorizontal];

    // =====================================================
    // 6️⃣ Horizontal layout
    // =====================================================
    UIStackView *contentStack =
        [[UIStackView alloc] initWithArrangedSubviews:@[avatar, textStack]];

    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    contentStack.axis = UILayoutConstraintAxisHorizontal;
    contentStack.spacing = 10;
    contentStack.alignment = UIStackViewAlignmentCenter;

    [container addSubview:contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [contentStack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:6],
        [contentStack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor  constant:-16],
        [contentStack.topAnchor constraintEqualToAnchor:container.topAnchor],
        [contentStack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];

    // =====================================================
    // 7️⃣ Touch feedback (safe)
    // =====================================================
    [container addTarget:container
                  action:@selector(pp_highlightDown)
        forControlEvents:UIControlEventTouchDown];

    [container addTarget:container
                  action:@selector(pp_highlightUp)
        forControlEvents:UIControlEventTouchUpInside |
                        UIControlEventTouchCancel |
                        UIControlEventTouchDragExit];

    return container;
}




#pragma mark - Swipe Back Gesture

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer ==
        self.navigationController.interactivePopGestureRecognizer) {

        // Disable on root VC only
        return self.navigationController.viewControllers.count > 1;
    }
    return YES;
}


-(void)PPUniversalCell_changeQuantity:(PPUniversalCellViewModel *)universalModel quantity:(NSInteger)quantity
{


    if (![universalModel.ModelObject isKindOfClass:[PetAccessory class]]) {
        NSLog(@"[Home][Cart] Ignored quantity change for non-accessory model");
        return;
    }
    PetAccessory *access = (PetAccessory *)universalModel.ModelObject;
    NSInteger maxStock = MAX(access.quantity, 0);
    NSInteger safeQuantity = MAX(0, quantity);

    if (maxStock <= 0 && safeQuantity > 0) {
        [PPHUD showError:kLang(@"Out of stock")];
        safeQuantity = 0;
    } else if (safeQuantity > maxStock) {
        safeQuantity = maxStock;
        [PPHUD showInfo:[NSString stringWithFormat:@"%@ %ld %@",
                         kLang(@"Only"),
                         (long)maxStock,
                         kLang(@"left in stock")]];
    }

    if (safeQuantity == 0) {
        [PPFunc triggerWarningHaptic];
        [[CartManager sharedManager] removeItemForAccessory:access];
    } else {
        CartManager *cart = [CartManager sharedManager];
        CartItem *existing = [cart getCartItemForItemID:access.accessoryID];
        CartItem *item = [[CartItem alloc] initWithAccessory:access quantity:safeQuantity];
        if (existing) {
            [cart updateQuantity:safeQuantity forItem:item completion:nil];
        } else {
            BOOL didAdd = [cart addItem:item];
            if (!didAdd) {
                [PPHUD showError:kLang(@"Out of stock")];
            }
        }
        
        [self updateCartQuantityBadge];

        if (safeQuantity == 1) {
            [PPFunc triggerLightHaptic];
        } else {
            [PPFunc triggerMediumHaptic];
        }
    }

    NSLog(@"[Quantity] Quantity %ld", (long)safeQuantity);

        // ✅ NOTIFY controllers to update badge
        [[NSNotificationCenter defaultCenter]
            postNotificationName:kCartUpdatedNotification
                          object:nil];

}




- (void)updateCartQuantityBadge
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateCartQuantityBadge];
        });
        return;
    }

    NSInteger count = [CartManager.sharedManager totalItemsCount];
    count = MAX(count, 0);
    [self refreshNavigationRightItemsForCartCount:count];
    [self pp_applyHomeCartBadgeCount:count];
    [self.homeCartItem.customView setNeedsLayout];
    [self.homeCartItem.customView layoutIfNeeded];
    [self.navigationController.navigationBar setNeedsLayout];
    [self.navigationController.navigationBar layoutIfNeeded];
    NSLog(@"[CartBadge] Updated count=%ld", (long)count);
}


-(void)PPUniversalCell_tapShare:(PPUniversalCellViewModel *)universalModel
{
    if (!PPIsUserLoggedIn) { [UserManager showPromptOnTopController]; return; }
    if (![universalModel.ModelObject isKindOfClass:[PetAd class]]) {
        NSLog(@"[Home][Share] Ignored share for unsupported model class");
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [PPAdSharingHelper sharePetAd:(PetAd *)universalModel.ModelObject fromViewController:self];
    });
}

-(void)PPUniversalCell_tapEdit:(PPUniversalCellViewModel *)universalModel
{

    NSLog(@"[AdsVC] PPUniversalCell_tapEdit");

    if(universalModel.cellSection == CellSectionAds && [universalModel.ModelObject isKindOfClass:[PetAd class]])
    {
        AddNewAd *vc = (AddNewAd *)[AddNewAd new];
        vc.mode = AdEditorModeEdit;
        vc.editingAd = (PetAd *)universalModel.ModelObject;                 // the existing PetAd you want to edit
        //vc.delegate = self;                // optional to get callbacks
         [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
    }
    else  if(universalModel.cellSection == CellSectionAccessories && [universalModel.ModelObject isKindOfClass:[PetAccessory class]])
    {
        // Edit
        AddNewAccessory *editVC = [AddNewAccessory new];
        editVC.editingAccessory = (PetAccessory *)universalModel.ModelObject;   ;   // prefill from this model
        editVC.onFinish = ^(PetAccessory *result, BOOL isEdit) {
            // refresh list, etc.
            [AppClasses reloadThisCollectionView:self.collectionView completion:^(BOOL finished) { }];

        };
        [PPHomeHelper pushViewControllerSafely:editVC from:self animated:YES];
    }
}

-(void)PPUniversalCell_tapDelete:(PPUniversalCellViewModel *)universalModel
{
    if (!PPIsUserLoggedIn) { [UserManager showPromptOnTopController]; return; }
    NSLog(@"[AdsVC] PPUniversalCell_tapDelete");
    if(universalModel.cellSection == CellSectionAds && [universalModel.ModelObject isKindOfClass:[PetAd class]])
    {
        [GM showDeleteConfirmationFrom:self
                                 title:kLang(@"Confirm Deletion")
                               message:kLang(@"Are you sure you want to delete this item?")
                            completion:^(BOOL confirmed) {
            if (confirmed) {
                // Perform delete action
                [PetAdManager.sharedManager deletePetAd:(PetAd *)universalModel.ModelObject completion:^(NSError * _Nonnull error) {
                    [AppClasses reloadThisCollectionView:self.collectionView completion:^(BOOL finished) { }];
                }];
            }
        }];
    }


}

#pragma mark - Background Gradient

- (void)pp_installBackgroundGradient
{
    if (self.pp_backgroundCanvasView) {
        return;
    }

    UIView *canvas = [[UIView alloc] init];
    canvas.translatesAutoresizingMaskIntoConstraints = NO;
    canvas.backgroundColor = UIColor.clearColor;
    canvas.userInteractionEnabled = NO;
    canvas.clipsToBounds = YES;
    [self.view insertSubview:canvas atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [canvas.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [canvas.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [canvas.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [canvas.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
    self.pp_backgroundCanvasView = canvas;

    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.startPoint = CGPointMake(0.08, 0.0);
    gradient.endPoint = CGPointMake(0.92, 1.0);
    gradient.locations = @[@0.0, @0.34, @0.72, @1.0];
    gradient.needsDisplayOnBoundsChange = YES;
    [canvas.layer addSublayer:gradient];
    self.pp_backgroundGradientLayer = gradient;

    CAGradientLayer *topGlow = [CAGradientLayer layer];
    topGlow.type = kCAGradientLayerRadial;
    topGlow.startPoint = CGPointMake(0.5, 0.5);
    topGlow.endPoint = CGPointMake(1.0, 1.0);
    topGlow.locations = @[@0.0, @0.30, @1.0];
    topGlow.needsDisplayOnBoundsChange = YES;
    [canvas.layer addSublayer:topGlow];
    self.pp_backgroundTopGlowLayer = topGlow;

    CAGradientLayer *accentGlow = [CAGradientLayer layer];
    accentGlow.type = kCAGradientLayerRadial;
    accentGlow.startPoint = CGPointMake(0.5, 0.5);
    accentGlow.endPoint = CGPointMake(1.0, 1.0);
    accentGlow.locations = @[@0.0, @0.36, @1.0];
    accentGlow.needsDisplayOnBoundsChange = YES;
    [canvas.layer addSublayer:accentGlow];
    self.pp_backgroundAccentGlowLayer = accentGlow;

    CAGradientLayer *bottomGlow = [CAGradientLayer layer];
    bottomGlow.type = kCAGradientLayerRadial;
    bottomGlow.startPoint = CGPointMake(0.5, 0.5);
    bottomGlow.endPoint = CGPointMake(1.0, 1.0);
    bottomGlow.locations = @[@0.0, @0.42, @1.0];
    bottomGlow.needsDisplayOnBoundsChange = YES;
    [canvas.layer addSublayer:bottomGlow];
    self.pp_backgroundBottomGlowLayer = bottomGlow;

    CAGradientLayer *shineLayer = [CAGradientLayer layer];
    shineLayer.startPoint = CGPointMake(0.0, 0.08);
    shineLayer.endPoint = CGPointMake(1.0, 0.92);
    shineLayer.locations = @[@0.0, @0.40, @0.64, @1.0];
    shineLayer.needsDisplayOnBoundsChange = YES;
    [canvas.layer addSublayer:shineLayer];
    self.pp_backgroundShineLayer = shineLayer;

    [self pp_layoutBackgroundLayers];
    [self pp_updateBackgroundGradientColors];
}

- (void)pp_updateBackgroundGradientColors
{
    if (!self.pp_backgroundGradientLayer) return;

    UIColor *base = [UIColor colorWithHexString:@"#ed1e67"] ;
    BOOL isDark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);

    UIColor *tintTop = nil;
    UIColor *tintUpperMid = nil;
    UIColor *tintLowerMid = nil;
    UIColor *topGlowStart = nil;
    UIColor *topGlowMid = nil;
    UIColor *accentGlowStart = nil;
    UIColor *accentGlowMid = nil;
    UIColor *bottomGlowStart = nil;
    UIColor *bottomGlowMid = nil;
    UIColor *shinePeak = nil;
    UIColor *shineTail = nil;

    if (isDark) {
        // Deep charcoal base with cool blue undertones
        tintTop = [UIColor colorWithRed:0.07 green:0.07 blue:0.11 alpha:1.0];
        tintUpperMid = [UIColor colorWithRed:0.06 green:0.08 blue:0.14 alpha:1.0];
        tintLowerMid = [UIColor colorWithRed:0.05 green:0.06 blue:0.12 alpha:1.0];
        // Warm coral/amber glow — top-left focal point
        topGlowStart = [UIColor colorWithRed:0.98 green:0.52 blue:0.32 alpha:0.30];
        topGlowMid = [UIColor colorWithRed:0.94 green:0.36 blue:0.42 alpha:0.12];
        // Electric teal/cyan accent — modern contrast
        accentGlowStart = [UIColor colorWithRed:0.18 green:0.82 blue:0.86 alpha:0.20];
        accentGlowMid = [UIColor colorWithRed:0.24 green:0.72 blue:0.90 alpha:0.08];
        // Soft indigo/violet — lower depth
        bottomGlowStart = [UIColor colorWithRed:0.44 green:0.32 blue:0.82 alpha:0.18];
        bottomGlowMid = [UIColor colorWithRed:0.38 green:0.28 blue:0.72 alpha:0.06];
        shinePeak = [UIColor colorWithWhite:1.0 alpha:0.08];
        shineTail = [UIColor colorWithWhite:1.0 alpha:0.02];
    } else {
        // Airy ivory base with lavender-mint undertones
        tintTop = [UIColor colorWithRed:0.98 green:0.97 blue:0.99 alpha:1.0];
        tintUpperMid = [UIColor colorWithRed:0.97 green:0.95 blue:0.98 alpha:1.0];
        tintLowerMid = [UIColor colorWithRed:0.95 green:0.97 blue:0.99 alpha:1.0];
        // Soft apricot/peach glow — organic warmth
        topGlowStart = [UIColor colorWithRed:1.0 green:0.82 blue:0.64 alpha:0.72];
        topGlowMid = [UIColor colorWithRed:0.98 green:0.68 blue:0.62 alpha:0.30];
        // Cool mint/teal accent — fresh contrast
        accentGlowStart = [UIColor colorWithRed:0.48 green:0.90 blue:0.88 alpha:0.38];
        accentGlowMid = [UIColor colorWithRed:0.56 green:0.86 blue:0.92 alpha:0.14];
        // Soft lilac/lavender — subtle depth
        bottomGlowStart = [UIColor colorWithRed:0.76 green:0.68 blue:0.96 alpha:0.30];
        bottomGlowMid = [UIColor colorWithRed:0.80 green:0.74 blue:0.94 alpha:0.12];
        shinePeak = [UIColor colorWithWhite:1.0 alpha:0.38];
        shineTail = [UIColor colorWithWhite:1.0 alpha:0.06];
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.pp_backgroundGradientLayer.colors = @[
        (id)tintTop.CGColor,
        (id)tintUpperMid.CGColor,
        (id)tintLowerMid.CGColor,
        (id)base.CGColor
    ];
    self.pp_backgroundTopGlowLayer.colors = @[
        (id)topGlowStart.CGColor,
        (id)topGlowMid.CGColor,
        (id)UIColor.clearColor.CGColor
    ];
    self.pp_backgroundAccentGlowLayer.colors = @[
        (id)accentGlowStart.CGColor,
        (id)accentGlowMid.CGColor,
        (id)UIColor.clearColor.CGColor
    ];
    self.pp_backgroundBottomGlowLayer.colors = @[
        (id)bottomGlowStart.CGColor,
        (id)bottomGlowMid.CGColor,
        (id)UIColor.clearColor.CGColor
    ];
    self.pp_backgroundShineLayer.colors = @[
        (id)UIColor.clearColor.CGColor,
        (id)shinePeak.CGColor,
        (id)shineTail.CGColor,
        (id)UIColor.clearColor.CGColor
    ];
    [CATransaction commit];
}

- (void)pp_layoutBackgroundLayers
{
    if (!self.pp_backgroundCanvasView) {
        return;
    }

    CGRect bounds = self.pp_backgroundCanvasView.bounds;
    if (CGRectIsEmpty(bounds)) {
        return;
    }

    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.pp_backgroundGradientLayer.frame = bounds;
    // Top-left warm glow — larger, pulled further off-screen for organic bleed
    self.pp_backgroundTopGlowLayer.frame =
        CGRectMake(-width * 0.28, -height * 0.22, width * 1.44, MAX(height * 0.78, width * 1.0));
    // Accent glow — shifted right-center for asymmetric balance
    self.pp_backgroundAccentGlowLayer.frame =
        CGRectMake(width * 0.42, height * 0.12, width * 0.72, width * 0.72);
    // Bottom glow — wider spread, lower on screen
    self.pp_backgroundBottomGlowLayer.frame =
        CGRectMake(-width * 0.18, height * 0.52, width * 1.08, height * 0.62);
    self.pp_backgroundShineLayer.frame = bounds;
    [CATransaction commit];
}

- (void)pp_startBackgroundAnimationsIfNeeded
{
    if (self.pp_backgroundAnimationsConfigured || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    CABasicAnimation *topOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    topOpacity.fromValue = @0.78;
    topOpacity.toValue = @1.0;
    topOpacity.duration = 8.0;
    topOpacity.autoreverses = YES;
    topOpacity.repeatCount = HUGE_VALF;
    topOpacity.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.pp_backgroundTopGlowLayer addAnimation:topOpacity forKey:@"pp.background.top.opacity"];

    CABasicAnimation *topScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    topScale.fromValue = @1.0;
    topScale.toValue = @1.08;
    topScale.duration = 14.0;
    topScale.autoreverses = YES;
    topScale.repeatCount = HUGE_VALF;
    topScale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.pp_backgroundTopGlowLayer addAnimation:topScale forKey:@"pp.background.top.scale"];

    CABasicAnimation *accentDrift = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    accentDrift.fromValue = @0.0;
    accentDrift.toValue = @(-24.0);
    accentDrift.duration = 16.0;
    accentDrift.autoreverses = YES;
    accentDrift.repeatCount = HUGE_VALF;
    accentDrift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.pp_backgroundAccentGlowLayer addAnimation:accentDrift forKey:@"pp.background.accent.drift"];

    CABasicAnimation *accentScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    accentScale.fromValue = @1.0;
    accentScale.toValue = @1.10;
    accentScale.duration = 18.0;
    accentScale.autoreverses = YES;
    accentScale.repeatCount = HUGE_VALF;
    accentScale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.pp_backgroundAccentGlowLayer addAnimation:accentScale forKey:@"pp.background.accent.scale"];

    CABasicAnimation *bottomDrift = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    bottomDrift.fromValue = @0.0;
    bottomDrift.toValue = @22.0;
    bottomDrift.duration = 15.0;
    bottomDrift.autoreverses = YES;
    bottomDrift.repeatCount = HUGE_VALF;
    bottomDrift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.pp_backgroundBottomGlowLayer addAnimation:bottomDrift forKey:@"pp.background.bottom.drift"];

    self.pp_backgroundAnimationsConfigured = YES;
}

- (void)pp_stopBackgroundAnimations
{
    [self.pp_backgroundTopGlowLayer removeAnimationForKey:@"pp.background.top.opacity"];
    [self.pp_backgroundTopGlowLayer removeAnimationForKey:@"pp.background.top.scale"];
    [self.pp_backgroundAccentGlowLayer removeAnimationForKey:@"pp.background.accent.drift"];
    [self.pp_backgroundAccentGlowLayer removeAnimationForKey:@"pp.background.accent.scale"];
    [self.pp_backgroundBottomGlowLayer removeAnimationForKey:@"pp.background.bottom.drift"];
    self.pp_backgroundAnimationsConfigured = NO;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    if (self.pp_backgroundCanvasView &&
        !CGRectEqualToRect(self.pp_backgroundCanvasView.bounds, CGRectZero)) {
        //[self pp_layoutBackgroundLayers];
    }

    if (self.homeSmartSearchView) {
        CGRect frame = self.homeSmartSearchView.frame;
        frame.size.width = [self pp_preferredNavigationSearchWidth];
        frame.size.height = 42.0;
        self.homeSmartSearchView.frame = frame;
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self pp_updateBackgroundGradientColors];
    }
}



@end
