//
//  ServiceViewerViewController.m
//  Pure Pets
//

#import "ServiceViewerViewController.h"
#import "ServiceModel.h"
#import "GM.h"
#import "PetAdManager.h"
#import "PPAlertHelper.h"
#import "PPCommerceFeedbackManager.h"
#import "PPHUD.h"
#import "AppClasses.h"
#import "UserModel.h"
#import "PPInfoPillsView.h"
#import "UserContactView.h"
#import "PPModernAvatarRenderer.h"
#import "MainKindsModel.h"
@import FirebaseFirestore;

static CGFloat const PPServiceViewerSideInset = 16.0;
static CGFloat const PPServiceViewerSectionSpacing = 14.0;
static CGFloat const PPServiceViewerHeroBottomInset = 20.0;
static CGFloat const PPServiceViewerSurfaceRadius = 26.0;
static CGFloat const PPServiceViewerTitleChromeRadius = 30.0;
static CGFloat const PPServiceViewerTitlePriceWidth = 126.0;

static NSString *PPServiceViewerLocalized(NSString *key, NSString *fallback) {
    NSString *value = key.length > 0 ? kLang(key) : nil;
    if (value.length == 0 || [value isEqualToString:key]) {
        return fallback ?: @"";
    }
    return value;
}

static UIColor *PPServiceViewerAccentColor(void) {
    return AppPrimaryClr ?: [UIColor colorWithRed:0.14 green:0.67 blue:0.68 alpha:1.0];
}

static UIColor *PPServiceViewerWarmAccentColor(void) {
    return [UIColor colorWithRed:0.96 green:0.76 blue:0.44 alpha:1.0];
}

@interface PPServiceViewerPremiumTitleView : UIView

- (void)configureWithTitle:(NSString *)title
                  location:(nullable NSString *)location
                     price:(nullable NSString *)price;

- (void)configureWithTitle:(NSString *)title
                  location:(nullable NSString *)location
                     price:(nullable NSString *)price
                  category:(nullable NSString *)category;

- (void)updateMetaPillsWithItems:(NSArray<PPInfoPill *> *)items;
- (void)enableBlurBackgroundWithStyle:(UIBlurEffectStyle)style;
- (void)prepareForEntrance;
- (void)animateEntranceIfNeeded;
- (void)animatePillsIn;

@end

@interface PPServiceViewerPremiumTitleView ()
@property (nonatomic, strong) UIView *chromeView;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *overlayView;
@property (nonatomic, strong) UIView *ambientOrbView;
@property (nonatomic, strong) UIView *categoryBadgeView;
@property (nonatomic, strong) UIImageView *categoryIconView;
@property (nonatomic, strong) UILabel *categoryLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIStackView *providerStackView;
@property (nonatomic, strong) UIImageView *providerIconView;
@property (nonatomic, strong) UILabel *providerLabel;
@property (nonatomic, strong) UIView *priceCardView;
@property (nonatomic, strong) CAGradientLayer *priceGradientLayer;
@property (nonatomic, strong) UILabel *priceCaptionLabel;
@property (nonatomic, strong) UILabel *priceLabel;
@property (nonatomic, strong) UIStackView *metaPillsStackView;
@property (nonatomic, strong) CAGradientLayer *backgroundGradientLayer;
@property (nonatomic, assign) BOOL didAnimateEntrance;
@property (nonatomic, assign) BOOL didStartAmbientMotion;
@end

@implementation PPServiceViewerPremiumTitleView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self pp_setupView];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self pp_setupView];
    }
    return self;
}

- (void)pp_setupView {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.layer.shadowOpacity = 0.22f;
    self.layer.shadowRadius = 28.0f;
    self.layer.shadowOffset = CGSizeMake(0.0, 16.0);
    [self pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:0.34]];

    self.chromeView = [[UIView alloc] init];
    self.chromeView.translatesAutoresizingMaskIntoConstraints = NO;
    self.chromeView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18];
    self.chromeView.layer.cornerRadius = PPServiceViewerTitleChromeRadius;
    self.chromeView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.chromeView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.chromeView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.18]];
    self.chromeView.layer.borderWidth = 1.0;
    [self addSubview:self.chromeView];

    self.blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    self.blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.chromeView addSubview:self.blurView];

    self.overlayView = [[UIView alloc] init];
    self.overlayView.translatesAutoresizingMaskIntoConstraints = NO;
    self.overlayView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    [self.chromeView addSubview:self.overlayView];

    self.backgroundGradientLayer = [CAGradientLayer layer];
    self.backgroundGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.backgroundGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    [self.overlayView.layer addSublayer:self.backgroundGradientLayer];

    self.ambientOrbView = [[UIView alloc] init];
    self.ambientOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    self.ambientOrbView.userInteractionEnabled = NO;
    self.ambientOrbView.backgroundColor = [PPServiceViewerWarmAccentColor() colorWithAlphaComponent:0.22];
    self.ambientOrbView.alpha = 0.85;
    self.ambientOrbView.layer.shadowRadius = 42.0;
    self.ambientOrbView.layer.shadowOpacity = 0.32;
    self.ambientOrbView.layer.shadowOffset = CGSizeZero;
    [self.ambientOrbView pp_setShadowColor:PPServiceViewerWarmAccentColor()];
    [self.chromeView addSubview:self.ambientOrbView];

    self.categoryBadgeView = [[UIView alloc] init];
    self.categoryBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    self.categoryBadgeView.backgroundColor = [PPServiceViewerAccentColor() colorWithAlphaComponent:0.18];
    self.categoryBadgeView.layer.cornerRadius = 14.0;
    self.categoryBadgeView.layer.borderWidth = 0.8;
    [self.categoryBadgeView pp_setBorderColor:[PPServiceViewerAccentColor() colorWithAlphaComponent:0.26]];
    if (@available(iOS 13.0, *)) {
        self.categoryBadgeView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.chromeView addSubview:self.categoryBadgeView];

    UIImageSymbolConfiguration *badgeSymbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:12.0 weight:UIImageSymbolWeightSemibold];
    self.categoryIconView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"sparkles" withConfiguration:badgeSymbolConfig] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    self.categoryIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.categoryIconView.tintColor = PPServiceViewerAccentColor();
    self.categoryIconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.categoryBadgeView addSubview:self.categoryIconView];

    self.categoryLabel = [[UILabel alloc] init];
    self.categoryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.categoryLabel.font = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    self.categoryLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.94];
    self.categoryLabel.numberOfLines = 1;
    self.categoryLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.categoryBadgeView addSubview:self.categoryLabel];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [GM boldFontWithSize:24.0] ?: [UIFont systemFontOfSize:24.0 weight:UIFontWeightBold];
    self.titleLabel.textColor = UIColor.whiteColor;
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.titleLabel.minimumScaleFactor = 0.82;
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.chromeView addSubview:self.titleLabel];

    self.providerIconView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"building.2.crop.circle.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    self.providerIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.providerIconView.tintColor = [UIColor colorWithWhite:1.0 alpha:0.82];
    self.providerIconView.contentMode = UIViewContentModeScaleAspectFit;

    self.providerLabel = [[UILabel alloc] init];
    self.providerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.providerLabel.font = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    self.providerLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.84];
    self.providerLabel.numberOfLines = 1;
    self.providerLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.providerLabel.textAlignment = Language.alignmentForCurrentLanguage;

    self.providerStackView = [[UIStackView alloc] initWithArrangedSubviews:@[self.providerIconView, self.providerLabel]];
    self.providerStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.providerStackView.axis = UILayoutConstraintAxisHorizontal;
    self.providerStackView.spacing = 8.0;
    self.providerStackView.alignment = UIStackViewAlignmentCenter;
    self.providerStackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.chromeView addSubview:self.providerStackView];

    self.priceCardView = [[UIView alloc] init];
    self.priceCardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.priceCardView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.16];
    self.priceCardView.layer.cornerRadius = 22.0;
    self.priceCardView.layer.borderWidth = 0.8;
    [self.priceCardView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.14]];
    if (@available(iOS 13.0, *)) {
        self.priceCardView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.chromeView addSubview:self.priceCardView];

    self.priceGradientLayer = [CAGradientLayer layer];
    self.priceGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.priceGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    [self.priceCardView.layer insertSublayer:self.priceGradientLayer atIndex:0];

    self.priceCaptionLabel = [[UILabel alloc] init];
    self.priceCaptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.priceCaptionLabel.font = [GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    self.priceCaptionLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.72];
    self.priceCaptionLabel.textAlignment = NSTextAlignmentCenter;
    self.priceCaptionLabel.text = PPServiceViewerLocalized(@"Price", @"Price");
    [self.priceCardView addSubview:self.priceCaptionLabel];

    self.priceLabel = [[UILabel alloc] init];
    self.priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.priceLabel.font = [GM boldFontWithSize:19.0] ?: [UIFont systemFontOfSize:19.0 weight:UIFontWeightBold];
    self.priceLabel.textColor = UIColor.whiteColor;
    self.priceLabel.numberOfLines = 2;
    self.priceLabel.adjustsFontForContentSizeCategory = YES;
    self.priceLabel.textAlignment = NSTextAlignmentCenter;
    [self.priceCardView addSubview:self.priceLabel];

    self.metaPillsStackView = [[UIStackView alloc] init];
    self.metaPillsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.metaPillsStackView.axis = UILayoutConstraintAxisHorizontal;
    self.metaPillsStackView.spacing = 8.0;
    self.metaPillsStackView.alignment = UIStackViewAlignmentCenter;
    self.metaPillsStackView.distribution = UIStackViewDistributionFillProportionally;
    self.metaPillsStackView.hidden = YES;
    self.metaPillsStackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.chromeView addSubview:self.metaPillsStackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.chromeView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.chromeView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.chromeView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.chromeView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [self.blurView.topAnchor constraintEqualToAnchor:self.chromeView.topAnchor],
        [self.blurView.leadingAnchor constraintEqualToAnchor:self.chromeView.leadingAnchor],
        [self.blurView.trailingAnchor constraintEqualToAnchor:self.chromeView.trailingAnchor],
        [self.blurView.bottomAnchor constraintEqualToAnchor:self.chromeView.bottomAnchor],

        [self.overlayView.topAnchor constraintEqualToAnchor:self.chromeView.topAnchor],
        [self.overlayView.leadingAnchor constraintEqualToAnchor:self.chromeView.leadingAnchor],
        [self.overlayView.trailingAnchor constraintEqualToAnchor:self.chromeView.trailingAnchor],
        [self.overlayView.bottomAnchor constraintEqualToAnchor:self.chromeView.bottomAnchor],

        [self.ambientOrbView.widthAnchor constraintEqualToConstant:132.0],
        [self.ambientOrbView.heightAnchor constraintEqualToConstant:132.0],
        [self.ambientOrbView.topAnchor constraintEqualToAnchor:self.chromeView.topAnchor constant:-38.0],
        [self.ambientOrbView.trailingAnchor constraintEqualToAnchor:self.chromeView.trailingAnchor constant:-18.0],

        [self.categoryBadgeView.topAnchor constraintEqualToAnchor:self.chromeView.topAnchor constant:16.0],
        [self.categoryBadgeView.leadingAnchor constraintEqualToAnchor:self.chromeView.leadingAnchor constant:16.0],
        [self.categoryBadgeView.heightAnchor constraintGreaterThanOrEqualToConstant:30.0],

        [self.categoryIconView.leadingAnchor constraintEqualToAnchor:self.categoryBadgeView.leadingAnchor constant:11.0],
        [self.categoryIconView.centerYAnchor constraintEqualToAnchor:self.categoryBadgeView.centerYAnchor],
        [self.categoryIconView.widthAnchor constraintEqualToConstant:13.0],
        [self.categoryIconView.heightAnchor constraintEqualToConstant:13.0],

        [self.categoryLabel.topAnchor constraintEqualToAnchor:self.categoryBadgeView.topAnchor constant:7.0],
        [self.categoryLabel.leadingAnchor constraintEqualToAnchor:self.categoryIconView.trailingAnchor constant:7.0],
        [self.categoryLabel.trailingAnchor constraintEqualToAnchor:self.categoryBadgeView.trailingAnchor constant:-12.0],
        [self.categoryLabel.bottomAnchor constraintEqualToAnchor:self.categoryBadgeView.bottomAnchor constant:-7.0],

        [self.priceCardView.topAnchor constraintEqualToAnchor:self.chromeView.topAnchor constant:16.0],
        [self.priceCardView.trailingAnchor constraintEqualToAnchor:self.chromeView.trailingAnchor constant:-16.0],
        [self.priceCardView.widthAnchor constraintEqualToConstant:PPServiceViewerTitlePriceWidth],
        [self.priceCardView.heightAnchor constraintGreaterThanOrEqualToConstant:88.0],

        [self.priceCaptionLabel.topAnchor constraintEqualToAnchor:self.priceCardView.topAnchor constant:14.0],
        [self.priceCaptionLabel.leadingAnchor constraintEqualToAnchor:self.priceCardView.leadingAnchor constant:10.0],
        [self.priceCaptionLabel.trailingAnchor constraintEqualToAnchor:self.priceCardView.trailingAnchor constant:-10.0],

        [self.priceLabel.topAnchor constraintEqualToAnchor:self.priceCaptionLabel.bottomAnchor constant:5.0],
        [self.priceLabel.leadingAnchor constraintEqualToAnchor:self.priceCardView.leadingAnchor constant:12.0],
        [self.priceLabel.trailingAnchor constraintEqualToAnchor:self.priceCardView.trailingAnchor constant:-12.0],
        [self.priceLabel.bottomAnchor constraintEqualToAnchor:self.priceCardView.bottomAnchor constant:-14.0],

        [self.titleLabel.topAnchor constraintEqualToAnchor:self.categoryBadgeView.bottomAnchor constant:12.0],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.chromeView.leadingAnchor constant:16.0],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.priceCardView.leadingAnchor constant:-14.0],

        [self.providerStackView.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:10.0],
        [self.providerStackView.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.providerStackView.trailingAnchor constraintLessThanOrEqualToAnchor:self.priceCardView.leadingAnchor constant:-12.0],

        [self.providerIconView.widthAnchor constraintEqualToConstant:16.0],
        [self.providerIconView.heightAnchor constraintEqualToConstant:16.0],

        [self.metaPillsStackView.topAnchor constraintEqualToAnchor:self.providerStackView.bottomAnchor constant:14.0],
        [self.metaPillsStackView.leadingAnchor constraintEqualToAnchor:self.chromeView.leadingAnchor constant:16.0],
        [self.metaPillsStackView.trailingAnchor constraintLessThanOrEqualToAnchor:self.chromeView.trailingAnchor constant:-16.0],
        [self.metaPillsStackView.bottomAnchor constraintEqualToAnchor:self.chromeView.bottomAnchor constant:-16.0],
        [self.metaPillsStackView.heightAnchor constraintGreaterThanOrEqualToConstant:30.0]
    ]];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.backgroundGradientLayer.frame = self.overlayView.bounds;
    self.backgroundGradientLayer.colors = @[
        (__bridge id)[[UIColor colorWithWhite:0.02 alpha:0.06] CGColor],
        (__bridge id)[[PPServiceViewerAccentColor() colorWithAlphaComponent:0.12] CGColor],
        (__bridge id)[[PPServiceViewerWarmAccentColor() colorWithAlphaComponent:0.18] CGColor],
        (__bridge id)[[UIColor colorWithWhite:1.0 alpha:0.08] CGColor]
    ];
    self.priceGradientLayer.frame = self.priceCardView.bounds;
    self.priceGradientLayer.colors = @[
        (__bridge id)[[PPServiceViewerAccentColor() colorWithAlphaComponent:0.96] CGColor],
        (__bridge id)[[PPServiceViewerWarmAccentColor() colorWithAlphaComponent:0.92] CGColor]
    ];
    self.priceGradientLayer.cornerRadius = self.priceCardView.layer.cornerRadius;
    self.ambientOrbView.layer.cornerRadius = CGRectGetWidth(self.ambientOrbView.bounds) / 2.0;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:PPServiceViewerTitleChromeRadius].CGPath;
}

- (void)configureWithTitle:(NSString *)title
                  location:(nullable NSString *)location
                     price:(nullable NSString *)price {
    [self configureWithTitle:title location:location price:price category:nil];
}

- (void)configureWithTitle:(NSString *)title
                  location:(nullable NSString *)location
                     price:(nullable NSString *)price
                  category:(nullable NSString *)category {
    self.titleLabel.text = title.length > 0 ? title : PPServiceViewerLocalized(@"service_view_default_title", @"Service");
    self.providerLabel.text = location.length > 0 ? location : PPServiceViewerLocalized(@"service_view_owner", @"Provider");
    self.priceLabel.text = price.length > 0 ? price : PPServiceViewerLocalized(@"not available", @"Not available");
    self.categoryLabel.text = category.length > 0 ? category : PPServiceViewerLocalized(@"service_view_category", @"Category");
    self.categoryBadgeView.hidden = category.length == 0;
    self.accessibilityLabel = [@[self.titleLabel.text ?: @"", self.providerLabel.text ?: @"", self.priceLabel.text ?: @""] componentsJoinedByString:@", "];
}

- (void)updateMetaPillsWithItems:(NSArray<PPInfoPill *> *)items {
    for (UIView *view in self.metaPillsStackView.arrangedSubviews) {
        [self.metaPillsStackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    NSMutableArray<PPInfoPill *> *filteredItems = [NSMutableArray array];
    for (PPInfoPill *item in items) {
        if (item.text.length > 0 || item.iconName.length > 0) {
            [filteredItems addObject:item];
        }
    }

    self.metaPillsStackView.hidden = filteredItems.count == 0;
    for (PPInfoPill *item in filteredItems) {
        [self.metaPillsStackView addArrangedSubview:[self pp_metaBadgeForItem:item]];
    }

    if (self.didAnimateEntrance) {
        [self animatePillsIn];
    }
}

- (void)enableBlurBackgroundWithStyle:(UIBlurEffectStyle)style {
    self.blurView.effect = [UIBlurEffect effectWithStyle:style];
}

- (void)prepareForEntrance {
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    self.alpha = 0.0;
    self.transform = reduceMotion ? CGAffineTransformIdentity : CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 24.0), CGAffineTransformMakeScale(0.96, 0.96));

    NSArray<UIView *> *primaryViews = @[
        self.categoryBadgeView,
        self.titleLabel,
        self.providerStackView,
        self.priceCardView,
        self.metaPillsStackView,
        self.ambientOrbView
    ];
    [primaryViews enumerateObjectsUsingBlock:^(UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        view.alpha = 0.0;
        if (reduceMotion) {
            view.transform = CGAffineTransformIdentity;
            return;
        }

        switch (idx) {
            case 0:
                view.transform = CGAffineTransformMakeTranslation(-10.0, 6.0);
                break;
            case 1:
                view.transform = CGAffineTransformMakeTranslation(0.0, 14.0);
                break;
            case 2:
                view.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
                break;
            case 3:
                view.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(10.0, 12.0), CGAffineTransformMakeScale(0.92, 0.92));
                break;
            case 4:
                view.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
                break;
            default:
                view.transform = CGAffineTransformMakeScale(0.86, 0.86);
                break;
        }
    }];

    [self pp_prepareMetaBadgeViews];
}

- (void)animateEntranceIfNeeded {
    if (self.didAnimateEntrance) {
        return;
    }
    self.didAnimateEntrance = YES;

    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    NSTimeInterval cardDuration = reduceMotion ? 0.18 : 0.62;

    [UIView animateWithDuration:cardDuration
                          delay:0.0
         usingSpringWithDamping:reduceMotion ? 1.0 : 0.84
          initialSpringVelocity:reduceMotion ? 0.0 : 0.22
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.alpha = 1.0;
        self.transform = CGAffineTransformIdentity;
    } completion:nil];

    [self pp_animateView:self.ambientOrbView delay:0.04 duration:(reduceMotion ? 0.16 : 0.50) damping:0.90 velocity:0.12];
    [self pp_animateView:self.categoryBadgeView delay:0.10 duration:(reduceMotion ? 0.16 : 0.46) damping:0.84 velocity:0.22];
    [self pp_animateView:self.priceCardView delay:0.12 duration:(reduceMotion ? 0.16 : 0.56) damping:0.74 velocity:0.30];
    [self pp_animateView:self.titleLabel delay:0.16 duration:(reduceMotion ? 0.16 : 0.54) damping:0.86 velocity:0.18];
    [self pp_animateView:self.providerStackView delay:0.21 duration:(reduceMotion ? 0.16 : 0.46) damping:0.88 velocity:0.16];
    [self pp_animateView:self.metaPillsStackView delay:0.26 duration:(reduceMotion ? 0.16 : 0.44) damping:0.90 velocity:0.14];
    [self animatePillsIn];
    [self pp_beginAmbientMotionIfNeeded];
}

- (void)animatePillsIn {
    [self pp_prepareMetaBadgeViews];
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    [self.metaPillsStackView.arrangedSubviews enumerateObjectsUsingBlock:^(UIView * _Nonnull badgeView, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        [UIView animateWithDuration:(reduceMotion ? 0.16 : 0.34)
                              delay:(reduceMotion ? 0.0 : (0.28 + (0.04 * idx)))
             usingSpringWithDamping:(reduceMotion ? 1.0 : 0.88)
              initialSpringVelocity:(reduceMotion ? 0.0 : 0.22)
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            badgeView.alpha = 1.0;
            badgeView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

- (UIView *)pp_metaBadgeForItem:(PPInfoPill *)item {
    UIColor *tintColor = [self pp_tintColorForMetaItem:item];

    UIView *badgeView = [[UIView alloc] init];
    badgeView.translatesAutoresizingMaskIntoConstraints = NO;
    badgeView.backgroundColor = [tintColor colorWithAlphaComponent:0.16];
    badgeView.layer.cornerRadius = 14.0;
    badgeView.layer.borderWidth = 0.8;
    [badgeView pp_setBorderColor:[tintColor colorWithAlphaComponent:0.24]];
    if (@available(iOS 13.0, *)) {
        badgeView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIImage *iconImage = nil;
    if (item.iconName.length > 0) {
        UIImageSymbolConfiguration *iconConfig = [UIImageSymbolConfiguration configurationWithPointSize:12.0 weight:UIImageSymbolWeightSemibold];
        iconImage = [UIImage systemImageNamed:item.iconName withConfiguration:iconConfig];
        if (!iconImage) {
            iconImage = [UIImage imageNamed:item.iconName];
        }
    }

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[iconImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = tintColor;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.hidden = iconImage == nil;

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [GM MidFontWithSize:12.5] ?: [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    label.textColor = UIColor.whiteColor;
    label.numberOfLines = 1;
    label.text = item.text ?: @"";
    label.textAlignment = Language.alignmentForCurrentLanguage;

    UIStackView *stackView = [[UIStackView alloc] initWithArrangedSubviews:iconImage ? @[iconView, label] : @[label]];
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    stackView.axis = UILayoutConstraintAxisHorizontal;
    stackView.spacing = 7.0;
    stackView.alignment = UIStackViewAlignmentCenter;
    stackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [badgeView addSubview:stackView];

    [NSLayoutConstraint activateConstraints:@[
        [iconView.widthAnchor constraintEqualToConstant:13.0],
        [iconView.heightAnchor constraintEqualToConstant:13.0],
        [stackView.topAnchor constraintEqualToAnchor:badgeView.topAnchor constant:7.0],
        [stackView.leadingAnchor constraintEqualToAnchor:badgeView.leadingAnchor constant:10.0],
        [stackView.trailingAnchor constraintEqualToAnchor:badgeView.trailingAnchor constant:-10.0],
        [stackView.bottomAnchor constraintEqualToAnchor:badgeView.bottomAnchor constant:-7.0]
    ]];

    return badgeView;
}

- (UIColor *)pp_tintColorForMetaItem:(PPInfoPill *)item {
    NSString *iconName = item.iconName ?: @"";
    if ([iconName isEqualToString:@"checkmark.seal.fill"]) {
        return [UIColor colorWithRed:0.36 green:0.82 blue:0.63 alpha:1.0];
    }
    if ([iconName isEqualToString:@"exclamationmark.triangle.fill"]) {
        return [UIColor colorWithRed:0.99 green:0.68 blue:0.32 alpha:1.0];
    }
    if ([iconName isEqualToString:@"pawprint.fill"]) {
        return [UIColor colorWithRed:0.56 green:0.80 blue:0.62 alpha:1.0];
    }
    if ([iconName isEqualToString:@"clock"]) {
        return PPServiceViewerWarmAccentColor();
    }
    return [UIColor colorWithWhite:1.0 alpha:0.82];
}

- (void)pp_prepareMetaBadgeViews {
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    for (UIView *badgeView in self.metaPillsStackView.arrangedSubviews) {
        badgeView.alpha = 0.0;
        badgeView.transform = reduceMotion ? CGAffineTransformIdentity : CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 8.0), CGAffineTransformMakeScale(0.97, 0.97));
    }
}

- (void)pp_animateView:(UIView *)view
                 delay:(NSTimeInterval)delay
              duration:(NSTimeInterval)duration
               damping:(CGFloat)damping
              velocity:(CGFloat)velocity {
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    [UIView animateWithDuration:duration
                          delay:delay
         usingSpringWithDamping:(reduceMotion ? 1.0 : damping)
          initialSpringVelocity:(reduceMotion ? 0.0 : velocity)
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        view.alpha = 1.0;
        view.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_beginAmbientMotionIfNeeded {
    if (self.didStartAmbientMotion || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    self.didStartAmbientMotion = YES;

    [UIView animateWithDuration:6.4
                          delay:0.0
                        options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.ambientOrbView.transform = CGAffineTransformMakeTranslation(-10.0, 12.0);
    } completion:nil];
}

@end

@interface ServiceViewerViewController () <UITextViewDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *topGlowView;
@property (nonatomic, strong) UIView *bottomGlowView;

@property (nonatomic, strong) UIView *heroContainerView;
@property (nonatomic, strong) UIImageView *heroImageView;
@property (nonatomic, strong) CAGradientLayer *heroGradientLayer;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) NSLayoutConstraint *heroHeightConstraint;
@property (nonatomic, strong) PPServiceViewerPremiumTitleView *titleView;

@property (nonatomic, strong) UIView *providerSectionView;
@property (nonatomic, strong) UILabel *providerTitleLabel;
@property (nonatomic, strong) UserContactView *providerContactView;
@property (nonatomic, strong) UILabel *providerMetaLabel;
@property (nonatomic, strong) UILabel *providerAboutTitleLabel;
@property (nonatomic, strong) UILabel *providerAboutLabel;

@property (nonatomic, strong) UIView *factsSectionView;
@property (nonatomic, strong) UILabel *factsTitleLabel;
@property (nonatomic, strong) UIStackView *factsStackView;

@property (nonatomic, strong) UIView *reviewsSectionView;
@property (nonatomic, strong) UILabel *reviewsTitleLabel;
@property (nonatomic, strong) UILabel *reviewsSummaryLabel;
@property (nonatomic, strong) UIView *reviewComposerView;
@property (nonatomic, strong) UILabel *reviewComposerTitleLabel;
@property (nonatomic, strong) UILabel *reviewComposerSubtitleLabel;
@property (nonatomic, strong) UIStackView *reviewStarsStackView;
@property (nonatomic, strong) UITextView *reviewTextView;
@property (nonatomic, strong) UIButton *submitReviewButton;
@property (nonatomic, strong) NSLayoutConstraint *reviewStarsTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *reviewTextTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *reviewTextMinHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *submitReviewTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *submitReviewHeightConstraint;
@property (nonatomic, strong) NSMutableArray<UIButton *> *reviewStarButtons;
@property (nonatomic, copy) NSString *reviewPlaceholderText;
@property (nonatomic, assign) NSInteger selectedReviewRating;
@property (nonatomic, assign) BOOL isSubmittingReview;
@property (nonatomic, assign) BOOL hasSubmittedProviderReview;
@property (nonatomic, assign) BOOL isCheckingProviderReviewStatus;
@property (nonatomic, assign) BOOL didCompleteLegacyProviderReviewScan;
@property (nonatomic, copy) NSString *lastReviewStatusUID;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *providerScopedReviews;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *legacyServiceScopedReviews;
@property (nonatomic, strong) UIStackView *reviewsStackView;

@property (nonatomic, strong) UIView *descriptionSectionView;
@property (nonatomic, strong) UILabel *descriptionTitleLabel;
@property (nonatomic, strong) UILabel *descriptionBodyLabel;

@property (nonatomic, strong) UIView *actionsSectionView;
@property (nonatomic, strong) UILabel *actionsTitleLabel;
@property (nonatomic, strong) UIStackView *actionsStackView;
@property (nonatomic, strong) UIButton *shareActionButton;
@property (nonatomic, strong) UIButton *PhoneActionButton;
@property (nonatomic, strong, nullable) UIButton *reportActionButton;
@property (nonatomic, strong, nullable) UIView *unavailableBannerView;

@property (nonatomic, strong) UserModel *ownerModel;
@property (nonatomic, assign) BOOL didTrackViewInteraction;
@property (nonatomic, assign) BOOL isResolvingOwner;
@property (nonatomic, assign) BOOL didAttemptOwnerLoad;
@property (nonatomic, assign) BOOL didAnimateEntrance;
@property (nonatomic, strong) id<FIRListenerRegistration> providerReviewsListener;
@property (nonatomic, strong) id<FIRListenerRegistration> reviewsListener;
@end

@implementation ServiceViewerViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.semanticContentAttribute = GM.setSemantic;
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.view.layer.cornerRadius = 28.0;
    self.view.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.view.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.modalInPresentation = NO;

    [self setupLayout];
    [self applyModelContent];
    [self loadOwnerIfNeeded];
    [self startReviewsListenerIfNeeded];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self pp_refreshCurrentUserReviewStatusIfNeeded];
    [self pp_updateReviewComposerState];

    if (!self.didTrackViewInteraction) {
        self.didTrackViewInteraction = YES;
        [self trackServiceInteraction:PPItemInteractionTypeView];
    }

    [self pp_beginEntranceAnimationsIfNeeded];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    self.heroGradientLayer.frame = self.heroContainerView.bounds;
    self.heroHeightConstraint.constant = [self pp_heroHeight];
    self.topGlowView.layer.cornerRadius = CGRectGetWidth(self.topGlowView.bounds) / 2.0;
    self.bottomGlowView.layer.cornerRadius = CGRectGetWidth(self.bottomGlowView.bounds) / 2.0;
}

- (void)dealloc {
    [self.providerReviewsListener remove];
    [self.reviewsListener remove];
}

#pragma mark - Layout

- (void)setupLayout {
    [self buildBackgroundDecor];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.backgroundColor = UIColor.clearColor;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.semanticContentAttribute = GM.setSemantic;
    if (@available(iOS 11.0, *)) {
        self.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.semanticContentAttribute = GM.setSemantic;

    [self.view addSubview:self.scrollView];
    [self.scrollView addSubview:self.contentView];

    UILayoutGuide *contentGuide = self.scrollView;
    UILayoutGuide *frameGuide = self.scrollView;
    if (@available(iOS 11.0, *)) {
        contentGuide = self.scrollView.contentLayoutGuide;
        frameGuide = self.scrollView.frameLayoutGuide;
    }

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.contentView.topAnchor constraintEqualToAnchor:contentGuide.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:contentGuide.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:contentGuide.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:contentGuide.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:frameGuide.widthAnchor]
    ]];

    [self buildHeroSection];
    [self buildProviderSection];
    [self buildFactsSection];
    [self buildReviewsSection];
    [self buildDescriptionSection];
    [self buildActionsSection];
    [self pp_prepareEntranceState];
}

- (void)buildBackgroundDecor {
    UIColor *accentColor = AppPrimaryClr ?: UIColor.systemBlueColor;

    self.topGlowView = [[UIView alloc] init];
    self.topGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.topGlowView.userInteractionEnabled = NO;
    self.topGlowView.backgroundColor = [accentColor colorWithAlphaComponent:0.18];
    [self.topGlowView pp_setShadowColor:accentColor];
    self.topGlowView.layer.shadowOpacity = 0.18f;
    self.topGlowView.layer.shadowRadius = 42.0f;
    self.topGlowView.layer.shadowOffset = CGSizeZero;

    self.bottomGlowView = [[UIView alloc] init];
    self.bottomGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomGlowView.userInteractionEnabled = NO;
    self.bottomGlowView.backgroundColor = [accentColor colorWithAlphaComponent:0.10];
    [self.bottomGlowView pp_setShadowColor:accentColor];
    self.bottomGlowView.layer.shadowOpacity = 0.12f;
    self.bottomGlowView.layer.shadowRadius = 36.0f;
    self.bottomGlowView.layer.shadowOffset = CGSizeZero;

    [self.view addSubview:self.topGlowView];
    [self.view addSubview:self.bottomGlowView];

    [NSLayoutConstraint activateConstraints:@[
        [self.topGlowView.widthAnchor constraintEqualToConstant:250.0],
        [self.topGlowView.heightAnchor constraintEqualToConstant:250.0],
        [self.topGlowView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-80.0],
        [self.topGlowView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-70.0],

        [self.bottomGlowView.widthAnchor constraintEqualToConstant:220.0],
        [self.bottomGlowView.heightAnchor constraintEqualToConstant:220.0],
        [self.bottomGlowView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:65.0],
        [self.bottomGlowView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:75.0]
    ]];
}

- (void)buildHeroSection {
    self.heroContainerView = [[UIView alloc] init];
    self.heroContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroContainerView.backgroundColor = AppForgroundColr ?: UIColor.systemBackgroundColor;
    self.heroContainerView.layer.cornerRadius = 0.0;
    self.heroContainerView.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    self.heroContainerView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.heroContainerView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    self.heroImageView = [[UIImageView alloc] init];
    self.heroImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.heroImageView.clipsToBounds = YES;
    self.heroImageView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.48];

    self.heroGradientLayer = [CAGradientLayer layer];
    UIColor *surfaceColor = AppForgroundColr ?: UIColor.systemBackgroundColor;
    UIColor *accentColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    self.heroGradientLayer.colors = @[
        (__bridge id)[UIColor colorWithWhite:0.04 alpha:0.06].CGColor,
        (__bridge id)[UIColor colorWithWhite:0.04 alpha:0.18].CGColor,
        (__bridge id)[accentColor colorWithAlphaComponent:0.20].CGColor,
        (__bridge id)[surfaceColor colorWithAlphaComponent:0.96].CGColor
    ];
    self.heroGradientLayer.locations = @[@0.0, @0.42, @0.74, @1.0];
    self.heroGradientLayer.startPoint = CGPointMake(0.5, 0.0);
    self.heroGradientLayer.endPoint = CGPointMake(0.5, 1.0);

    self.closeButton = [self pp_topChromeButtonWithSystemName:@"xmark" selector:@selector(closeTapped)];

    self.titleView = [[PPServiceViewerPremiumTitleView alloc] init];
    self.titleView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.titleView enableBlurBackgroundWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    
    

    [self.contentView addSubview:self.heroContainerView];
    [self.heroContainerView addSubview:self.heroImageView];
    [self.heroContainerView.layer addSublayer:self.heroGradientLayer];
    [self.heroContainerView addSubview:self.closeButton];
    [self.heroContainerView addSubview:self.titleView];

    self.heroHeightConstraint = [self.heroContainerView.heightAnchor constraintEqualToConstant:[self pp_heroHeight]];
    [NSLayoutConstraint activateConstraints:@[
        [self.heroContainerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.heroContainerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.heroContainerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        self.heroHeightConstraint,

        [self.heroImageView.topAnchor constraintEqualToAnchor:self.heroContainerView.topAnchor],
        [self.heroImageView.leadingAnchor constraintEqualToAnchor:self.heroContainerView.leadingAnchor],
        [self.heroImageView.trailingAnchor constraintEqualToAnchor:self.heroContainerView.trailingAnchor],
        [self.heroImageView.bottomAnchor constraintEqualToAnchor:self.heroContainerView.bottomAnchor],

        [self.closeButton.topAnchor constraintEqualToAnchor:self.heroContainerView.topAnchor constant:18.0],
        [self.closeButton.leadingAnchor constraintEqualToAnchor:self.heroContainerView.leadingAnchor constant:18.0],
        [self.closeButton.widthAnchor constraintEqualToConstant:40.0],
        [self.closeButton.heightAnchor constraintEqualToConstant:40.0],

        [self.titleView.leadingAnchor constraintEqualToAnchor:self.heroContainerView.leadingAnchor constant:PPServiceViewerSideInset],
        [self.titleView.trailingAnchor constraintEqualToAnchor:self.heroContainerView.trailingAnchor constant:-PPServiceViewerSideInset],
        [self.titleView.bottomAnchor constraintEqualToAnchor:self.heroContainerView.bottomAnchor constant:-PPServiceViewerHeroBottomInset]
    ]];
}

- (void)buildProviderSection {
    self.providerSectionView = [self pp_surfaceSectionView];
    [self.contentView addSubview:self.providerSectionView];

    self.providerTitleLabel = [self pp_sectionTitleLabelWithText:kLang(@"service_view_provider_title")];
    [self.providerSectionView addSubview:self.providerTitleLabel];

    self.providerContactView = [[UserContactView alloc] init];
    self.providerContactView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.providerSectionView addSubview:self.providerContactView];

    self.providerMetaLabel = [[UILabel alloc] init];
    self.providerMetaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.providerMetaLabel.font = [GM MidFontWithSize:14];
    self.providerMetaLabel.numberOfLines = 0;
    self.providerMetaLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.72];
    self.providerMetaLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.providerSectionView addSubview:self.providerMetaLabel];

    self.providerAboutTitleLabel = [[UILabel alloc] init];
    self.providerAboutTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.providerAboutTitleLabel.font = [GM boldFontWithSize:15];
    self.providerAboutTitleLabel.textColor = AppPrimaryTextClr;
    self.providerAboutTitleLabel.text = kLang(@"service_view_provider_about_title");
    self.providerAboutTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.providerSectionView addSubview:self.providerAboutTitleLabel];

    self.providerAboutLabel = [[UILabel alloc] init];
    self.providerAboutLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.providerAboutLabel.font = [GM MidFontWithSize:15];
    self.providerAboutLabel.numberOfLines = 0;
    self.providerAboutLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.86];
    self.providerAboutLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.providerSectionView addSubview:self.providerAboutLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.providerSectionView.topAnchor constraintEqualToAnchor:self.heroContainerView.bottomAnchor constant:18.0],
        [self.providerSectionView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPServiceViewerSideInset],
        [self.providerSectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPServiceViewerSideInset],

        [self.providerTitleLabel.topAnchor constraintEqualToAnchor:self.providerSectionView.topAnchor constant:20.0],
        [self.providerTitleLabel.leadingAnchor constraintEqualToAnchor:self.providerSectionView.leadingAnchor constant:20.0],
        [self.providerTitleLabel.trailingAnchor constraintEqualToAnchor:self.providerSectionView.trailingAnchor constant:-20.0],

        [self.providerContactView.topAnchor constraintEqualToAnchor:self.providerTitleLabel.bottomAnchor constant:14.0],
        [self.providerContactView.leadingAnchor constraintEqualToAnchor:self.providerSectionView.leadingAnchor constant:18.0],
        [self.providerContactView.trailingAnchor constraintEqualToAnchor:self.providerSectionView.trailingAnchor constant:-18.0],
        [self.providerContactView.heightAnchor constraintEqualToConstant:76.0],

        [self.providerMetaLabel.topAnchor constraintEqualToAnchor:self.providerContactView.bottomAnchor constant:14.0],
        [self.providerMetaLabel.leadingAnchor constraintEqualToAnchor:self.providerSectionView.leadingAnchor constant:20.0],
        [self.providerMetaLabel.trailingAnchor constraintEqualToAnchor:self.providerSectionView.trailingAnchor constant:-20.0],

        [self.providerAboutTitleLabel.topAnchor constraintEqualToAnchor:self.providerMetaLabel.bottomAnchor constant:16.0],
        [self.providerAboutTitleLabel.leadingAnchor constraintEqualToAnchor:self.providerSectionView.leadingAnchor constant:20.0],
        [self.providerAboutTitleLabel.trailingAnchor constraintEqualToAnchor:self.providerSectionView.trailingAnchor constant:-20.0],

        [self.providerAboutLabel.topAnchor constraintEqualToAnchor:self.providerAboutTitleLabel.bottomAnchor constant:8.0],
        [self.providerAboutLabel.leadingAnchor constraintEqualToAnchor:self.providerSectionView.leadingAnchor constant:20.0],
        [self.providerAboutLabel.trailingAnchor constraintEqualToAnchor:self.providerSectionView.trailingAnchor constant:-20.0],
        [self.providerAboutLabel.bottomAnchor constraintEqualToAnchor:self.providerSectionView.bottomAnchor constant:-20.0]
    ]];
}

- (void)buildFactsSection {
    self.factsSectionView = [self pp_surfaceSectionView];
    [self.contentView addSubview:self.factsSectionView];

    self.factsTitleLabel = [self pp_sectionTitleLabelWithText:kLang(@"service_view_quick_facts_title")];
    [self.factsSectionView addSubview:self.factsTitleLabel];

    self.factsStackView = [[UIStackView alloc] init];
    self.factsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.factsStackView.axis = UILayoutConstraintAxisVertical;
    self.factsStackView.spacing = 12.0;
    [self.factsSectionView addSubview:self.factsStackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.factsSectionView.topAnchor constraintEqualToAnchor:self.providerSectionView.bottomAnchor constant:PPServiceViewerSectionSpacing],
        [self.factsSectionView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPServiceViewerSideInset],
        [self.factsSectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPServiceViewerSideInset],

        [self.factsTitleLabel.topAnchor constraintEqualToAnchor:self.factsSectionView.topAnchor constant:20.0],
        [self.factsTitleLabel.leadingAnchor constraintEqualToAnchor:self.factsSectionView.leadingAnchor constant:20.0],
        [self.factsTitleLabel.trailingAnchor constraintEqualToAnchor:self.factsSectionView.trailingAnchor constant:-20.0],

        [self.factsStackView.topAnchor constraintEqualToAnchor:self.factsTitleLabel.bottomAnchor constant:14.0],
        [self.factsStackView.leadingAnchor constraintEqualToAnchor:self.factsSectionView.leadingAnchor constant:16.0],
        [self.factsStackView.trailingAnchor constraintEqualToAnchor:self.factsSectionView.trailingAnchor constant:-16.0],
        [self.factsStackView.bottomAnchor constraintEqualToAnchor:self.factsSectionView.bottomAnchor constant:-16.0]
    ]];
}

- (void)buildReviewsSection {
    self.reviewsSectionView = [self pp_surfaceSectionView];
    [self.contentView addSubview:self.reviewsSectionView];

    self.reviewsTitleLabel = [self pp_sectionTitleLabelWithText:kLang(@"service_view_reviews_title")];
    [self.reviewsSectionView addSubview:self.reviewsTitleLabel];

    self.reviewsSummaryLabel = [[UILabel alloc] init];
    self.reviewsSummaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.reviewsSummaryLabel.font = [GM boldFontWithSize:16];
    self.reviewsSummaryLabel.numberOfLines = 0;
    self.reviewsSummaryLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    self.reviewsSummaryLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.reviewsSectionView addSubview:self.reviewsSummaryLabel];

    self.reviewComposerView = [self pp_reviewComposerView];
    [self.reviewsSectionView addSubview:self.reviewComposerView];

    self.reviewsStackView = [[UIStackView alloc] init];
    self.reviewsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.reviewsStackView.axis = UILayoutConstraintAxisVertical;
    self.reviewsStackView.spacing = 10.0;
    [self.reviewsSectionView addSubview:self.reviewsStackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.reviewsSectionView.topAnchor constraintEqualToAnchor:self.factsSectionView.bottomAnchor constant:PPServiceViewerSectionSpacing],
        [self.reviewsSectionView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPServiceViewerSideInset],
        [self.reviewsSectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPServiceViewerSideInset],

        [self.reviewsTitleLabel.topAnchor constraintEqualToAnchor:self.reviewsSectionView.topAnchor constant:20.0],
        [self.reviewsTitleLabel.leadingAnchor constraintEqualToAnchor:self.reviewsSectionView.leadingAnchor constant:20.0],
        [self.reviewsTitleLabel.trailingAnchor constraintEqualToAnchor:self.reviewsSectionView.trailingAnchor constant:-20.0],

        [self.reviewsSummaryLabel.topAnchor constraintEqualToAnchor:self.reviewsTitleLabel.bottomAnchor constant:10.0],
        [self.reviewsSummaryLabel.leadingAnchor constraintEqualToAnchor:self.reviewsSectionView.leadingAnchor constant:20.0],
        [self.reviewsSummaryLabel.trailingAnchor constraintEqualToAnchor:self.reviewsSectionView.trailingAnchor constant:-20.0],

        [self.reviewComposerView.topAnchor constraintEqualToAnchor:self.reviewsSummaryLabel.bottomAnchor constant:14.0],
        [self.reviewComposerView.leadingAnchor constraintEqualToAnchor:self.reviewsSectionView.leadingAnchor constant:16.0],
        [self.reviewComposerView.trailingAnchor constraintEqualToAnchor:self.reviewsSectionView.trailingAnchor constant:-16.0],

        [self.reviewsStackView.topAnchor constraintEqualToAnchor:self.reviewComposerView.bottomAnchor constant:14.0],
        [self.reviewsStackView.leadingAnchor constraintEqualToAnchor:self.reviewsSectionView.leadingAnchor constant:16.0],
        [self.reviewsStackView.trailingAnchor constraintEqualToAnchor:self.reviewsSectionView.trailingAnchor constant:-16.0],
        [self.reviewsStackView.bottomAnchor constraintEqualToAnchor:self.reviewsSectionView.bottomAnchor constant:-16.0]
    ]];
}

- (void)buildDescriptionSection {
    self.descriptionSectionView = [self pp_surfaceSectionView];
    [self.contentView addSubview:self.descriptionSectionView];

    self.descriptionTitleLabel = [self pp_sectionTitleLabelWithText:kLang(@"service_view_description_title")];
    [self.descriptionSectionView addSubview:self.descriptionTitleLabel];

    self.descriptionBodyLabel = [[UILabel alloc] init];
    self.descriptionBodyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.descriptionBodyLabel.font = [GM MidFontWithSize:15];
    self.descriptionBodyLabel.numberOfLines = 0;
    self.descriptionBodyLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.86];
    self.descriptionBodyLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.descriptionSectionView addSubview:self.descriptionBodyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.descriptionSectionView.topAnchor constraintEqualToAnchor:self.reviewsSectionView.bottomAnchor constant:PPServiceViewerSectionSpacing],
        [self.descriptionSectionView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPServiceViewerSideInset],
        [self.descriptionSectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPServiceViewerSideInset],

        [self.descriptionTitleLabel.topAnchor constraintEqualToAnchor:self.descriptionSectionView.topAnchor constant:20.0],
        [self.descriptionTitleLabel.leadingAnchor constraintEqualToAnchor:self.descriptionSectionView.leadingAnchor constant:20.0],
        [self.descriptionTitleLabel.trailingAnchor constraintEqualToAnchor:self.descriptionSectionView.trailingAnchor constant:-20.0],

        [self.descriptionBodyLabel.topAnchor constraintEqualToAnchor:self.descriptionTitleLabel.bottomAnchor constant:10.0],
        [self.descriptionBodyLabel.leadingAnchor constraintEqualToAnchor:self.descriptionSectionView.leadingAnchor constant:20.0],
        [self.descriptionBodyLabel.trailingAnchor constraintEqualToAnchor:self.descriptionSectionView.trailingAnchor constant:-20.0],
        [self.descriptionBodyLabel.bottomAnchor constraintEqualToAnchor:self.descriptionSectionView.bottomAnchor constant:-20.0]
    ]];
}

- (void)buildActionsSection {
    self.actionsSectionView = [self pp_surfaceSectionView];
    [self.contentView addSubview:self.actionsSectionView];

    self.actionsTitleLabel = [self pp_sectionTitleLabelWithText:kLang(@"service_view_actions_title")];
    [self.actionsSectionView addSubview:self.actionsTitleLabel];

    self.actionsStackView = [[UIStackView alloc] init];
    self.actionsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionsStackView.axis = UILayoutConstraintAxisHorizontal;
    self.actionsStackView.alignment = UIStackViewAlignmentFill;
    self.actionsStackView.distribution = UIStackViewDistributionFillEqually;
    self.actionsStackView.spacing = 12.0;
    [self.actionsSectionView addSubview:self.actionsStackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.actionsSectionView.topAnchor constraintEqualToAnchor:self.descriptionSectionView.bottomAnchor constant:PPServiceViewerSectionSpacing],
        [self.actionsSectionView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPServiceViewerSideInset],
        [self.actionsSectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPServiceViewerSideInset],
        [self.actionsSectionView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-28.0],

        [self.actionsTitleLabel.topAnchor constraintEqualToAnchor:self.actionsSectionView.topAnchor constant:20.0],
        [self.actionsTitleLabel.leadingAnchor constraintEqualToAnchor:self.actionsSectionView.leadingAnchor constant:20.0],
        [self.actionsTitleLabel.trailingAnchor constraintEqualToAnchor:self.actionsSectionView.trailingAnchor constant:-20.0],

        [self.actionsStackView.topAnchor constraintEqualToAnchor:self.actionsTitleLabel.bottomAnchor constant:14.0],
        [self.actionsStackView.leadingAnchor constraintEqualToAnchor:self.actionsSectionView.leadingAnchor constant:16.0],
        [self.actionsStackView.trailingAnchor constraintEqualToAnchor:self.actionsSectionView.trailingAnchor constant:-16.0],
        [self.actionsStackView.bottomAnchor constraintEqualToAnchor:self.actionsSectionView.bottomAnchor constant:-16.0]
    ]];

    [self pp_rebuildActions];
}

#pragma mark - Configure

- (void)applyModelContent {
    [GM setImageFromUrlString:self.service.imageURL imageView:self.heroImageView phImage:@"placeholder"];

    NSString *title = [self pp_serviceTitle];
    NSString *providerName = [self pp_providerDisplayName];
    NSString *priceText = [self pp_priceText];
    NSString *categoryText = [self pp_categoryText];

    [self.titleView configureWithTitle:title location:providerName price:priceText category:categoryText];
    [self.titleView updateMetaPillsWithItems:[self pp_summaryPills]];

    self.descriptionBodyLabel.text = self.service.desc.length > 0 ? self.service.desc : kLang(@"service_view_no_description");

    [self pp_updateProviderSection];
    [self pp_reloadFacts];
    [self pp_reloadReviews];
    [self pp_updateReviewComposerState];
    [self pp_updateActionAvailability];
    [self pp_updateUnavailableBanner];
}

- (void)pp_updateProviderSection {
    NSString *providerName = [self pp_providerDisplayName];
    UIImage *placeholderAvatar = [PPModernAvatarRenderer avatarImageForName:providerName size:44];

    if (self.ownerModel) {
        __weak typeof(self) weakSelf = self;
        [self.providerContactView configureWithUser:self.ownerModel
                                       chatCallback:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf chatTapped];
        } callCallback:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf callTapped];
        }];
    } else {
        self.providerContactView.nameLabel.text = providerName;
        self.providerContactView.avatarImageView.image = placeholderAvatar ?: PPSYSImage(@"person.crop.circle.fill");
        self.providerContactView.callButton.enabled = NO;
        self.providerContactView.chatButton.enabled = NO;
        self.providerContactView.callButton.alpha = self.isResolvingOwner ? 0.35 : 0.55;
        self.providerContactView.chatButton.alpha = self.isResolvingOwner ? 0.35 : 0.55;
    }

    self.providerMetaLabel.text = [self pp_providerMetaText];
    self.providerAboutLabel.text = [self pp_providerAboutText];
}

- (void)pp_reloadFacts {
    for (UIView *view in self.factsStackView.arrangedSubviews) {
        [self.factsStackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    UIColor *accentColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    UIColor *neutralAccent = [AppPrimaryTextClr colorWithAlphaComponent:0.68];
    NSString *providerCountryText = [self pp_providerCountryText];

    // Row 1: Category + Pet Kind
    UIView *rowOne = [self pp_factRowWithViews:@[
        [self pp_factTileWithIcon:@"sparkles"
                            title:kLang(@"service_view_category")
                            value:[self pp_categoryText]
                           accent:accentColor],
        [self pp_factTileWithIcon:@"pawprint.fill"
                            title:kLang(@"service_view_pet_kind")
                            value:[self pp_petKindText]
                           accent:[UIColor colorWithRed:0.32 green:0.66 blue:0.56 alpha:1.0]]
    ]];

    // Row 2: Availability Status + Service Type
    UIColor *availColor = self.service.isLive
        ? [UIColor colorWithRed:0.20 green:0.63 blue:0.39 alpha:1.0]
        : [UIColor colorWithRed:0.89 green:0.32 blue:0.36 alpha:1.0];
    UIView *rowTwo = [self pp_factRowWithViews:@[
        [self pp_factTileWithIcon:self.service.isLive ? @"checkmark.circle.fill" : @"exclamationmark.triangle.fill"
                            title:kLang(@"service_view_availability")
                            value:[self pp_availableDateText]
                           accent:availColor],
        [self pp_factTileWithIcon:@"tag.fill"
                            title:kLang(@"service_view_type")
                            value:[self pp_serviceTypeName]
                           accent:[UIColor colorWithRed:0.56 green:0.40 blue:0.80 alpha:1.0]]
    ]];

    // Row 3: Rating + Country
    UIView *rowThree = [self pp_factRowWithViews:@[
        [self pp_factTileWithIcon:@"star.fill"
                            title:kLang(@"service_view_rating")
                            value:[self pp_ratingText]
                           accent:[UIColor colorWithRed:0.95 green:0.63 blue:0.20 alpha:1.0]],
        [self pp_factTileWithIcon:@"globe"
                            title:kLang(@"Country")
                            value:providerCountryText
                           accent:[UIColor colorWithRed:0.34 green:0.55 blue:0.89 alpha:1.0]]
    ]];

    // Row 4: Posted date
    UIView *rowFour = [self pp_factRowWithViews:@[
        [self pp_factTileWithIcon:@"clock"
                            title:kLang(@"service_view_posted_date")
                            value:[self pp_postedDateText]
                           accent:neutralAccent ?: UIColor.secondaryLabelColor]
    ]];

    [self.factsStackView addArrangedSubview:rowOne];
    [self.factsStackView addArrangedSubview:rowTwo];
    [self.factsStackView addArrangedSubview:rowThree];
    [self.factsStackView addArrangedSubview:rowFour];
}

- (void)pp_reloadReviews {
    for (UIView *view in self.reviewsStackView.arrangedSubviews) {
        [self.reviewsStackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    self.reviewsSummaryLabel.text = [self.service localizedRatingSummaryText];
    [self pp_updateReviewComposerState];

    if (self.service.reviews.count == 0) {
        [self.reviewsStackView addArrangedSubview:[self pp_emptyReviewsView]];
        return;
    }

    NSUInteger maxVisibleReviews = MIN(self.service.reviews.count, 5);
    for (NSUInteger idx = 0; idx < maxVisibleReviews; idx++) {
        [self.reviewsStackView addArrangedSubview:[self pp_reviewViewForDictionary:self.service.reviews[idx]]];
    }
}

- (void)startReviewsListenerIfNeeded {
    [self pp_startProviderReviewsListenerIfNeeded];
    [self pp_startLegacyServiceReviewsListenerIfNeeded];
    [self pp_refreshCurrentUserReviewStatusIfNeeded];
}

- (void)pp_startProviderReviewsListenerIfNeeded {
    if (self.providerReviewsListener || self.service.serviceOwnerID.length == 0) {
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRCollectionReference *reviewsRef =
        [[[db collectionWithPath:@"UsersCol"] documentWithPath:self.service.serviceOwnerID]
         collectionWithPath:@"providerReviews"];

    FIRQuery *query = [[reviewsRef queryOrderedByField:@"updatedAt" descending:YES] queryLimitedTo:25];

    __weak typeof(self) weakSelf = self;
    self.providerReviewsListener = [query addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || error || !snapshot) {
                return;
            }

            NSMutableArray<NSDictionary<NSString *, id> *> *reviews = [NSMutableArray arrayWithCapacity:snapshot.documents.count];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                NSMutableDictionary *review = [doc.data mutableCopy] ?: [NSMutableDictionary dictionary];
                review[@"reviewID"] = doc.documentID;
                NSNumber *rating = [strongSelf pp_reviewNumberFromDictionary:review
                                                                        keys:@[@"rating", @"ratingValue", @"averageRating"]];
                if (rating.doubleValue > 0.0) {
                    [reviews addObject:review.copy];
                }
            }

            strongSelf.providerScopedReviews = reviews.copy;
            [strongSelf pp_refreshMergedReviews];
        });
    }];
}

- (void)pp_startLegacyServiceReviewsListenerIfNeeded {
    if (self.reviewsListener || self.service.serviceID.length == 0) {
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRCollectionReference *reviewsRef =
        [[[db collectionWithPath:@"serviceOffers"] documentWithPath:self.service.serviceID]
         collectionWithPath:@"reviews"];

    FIRQuery *query = [[reviewsRef queryOrderedByField:@"updatedAt" descending:YES] queryLimitedTo:25];

    __weak typeof(self) weakSelf = self;
    self.reviewsListener = [query addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || error || !snapshot) {
                return;
            }

            NSMutableArray<NSDictionary<NSString *, id> *> *reviews = [NSMutableArray arrayWithCapacity:snapshot.documents.count];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                NSMutableDictionary *review = [doc.data mutableCopy] ?: [NSMutableDictionary dictionary];
                review[@"reviewID"] = doc.documentID;
                NSNumber *rating = [strongSelf pp_reviewNumberFromDictionary:review
                                                                        keys:@[@"rating", @"ratingValue", @"averageRating"]];
                if (rating.doubleValue > 0.0) {
                    [reviews addObject:review.copy];
                }
            }

            strongSelf.legacyServiceScopedReviews = reviews.copy;
            [strongSelf pp_refreshMergedReviews];
        });
    }];
}

- (void)pp_refreshMergedReviews {
    NSMutableArray<NSDictionary<NSString *, id> *> *mergedReviews = [NSMutableArray array];
    NSMutableSet<NSString *> *seenReviewerIDs = [NSMutableSet set];

    for (NSArray<NSDictionary<NSString *, id> *> *source in @[
        self.providerScopedReviews ?: @[],
        self.legacyServiceScopedReviews ?: @[]
    ]) {
        for (NSDictionary<NSString *, id> *review in source) {
            NSNumber *rating = [self pp_reviewNumberFromDictionary:review
                                                              keys:@[@"rating", @"ratingValue", @"averageRating"]];
            if (rating.doubleValue <= 0.0) {
                continue;
            }

            NSString *reviewerID = [self pp_reviewIdentifierForDictionary:review];
            if (reviewerID.length > 0) {
                if ([seenReviewerIDs containsObject:reviewerID]) {
                    continue;
                }
                [seenReviewerIDs addObject:reviewerID];
            }

            [mergedReviews addObject:review];
        }
    }

    [mergedReviews sortUsingComparator:^NSComparisonResult(NSDictionary<NSString *,id> * _Nonnull left,
                                                           NSDictionary<NSString *,id> * _Nonnull right) {
        NSDate *leftDate = [self pp_reviewSortDateForDictionary:left];
        NSDate *rightDate = [self pp_reviewSortDateForDictionary:right];
        if (!leftDate && !rightDate) return NSOrderedSame;
        if (!leftDate) return NSOrderedDescending;
        if (!rightDate) return NSOrderedAscending;
        return [rightDate compare:leftDate];
    }];

    double ratingTotal = 0.0;
    NSInteger ratingCount = 0;
    for (NSDictionary<NSString *, id> *review in mergedReviews) {
        NSNumber *rating = [self pp_reviewNumberFromDictionary:review
                                                          keys:@[@"rating", @"ratingValue", @"averageRating"]];
        if (rating.doubleValue > 0.0) {
            ratingTotal += rating.doubleValue;
            ratingCount += 1;
        }
    }

    self.service.reviews = mergedReviews.copy;
    self.service.reviewCount = ratingCount;
    self.service.ratingValue = ratingCount > 0 ? @(ratingTotal / (double)ratingCount) : nil;

    NSString *currentReviewerUID = [self pp_currentReviewerUID];
    if (currentReviewerUID.length > 0 && [self pp_reviewsArray:mergedReviews containsReviewerUID:currentReviewerUID]) {
        self.hasSubmittedProviderReview = YES;
        self.didCompleteLegacyProviderReviewScan = YES;
        self.isCheckingProviderReviewStatus = NO;
    }

    [self.titleView updateMetaPillsWithItems:[self pp_summaryPills]];
    [self pp_reloadFacts];
    [self pp_reloadReviews];
    [self pp_refreshCurrentUserReviewStatusIfNeeded];
}

- (void)pp_refreshCurrentUserReviewStatusIfNeeded {
    NSString *reviewerUID = [self pp_currentReviewerUID];
    if (reviewerUID.length == 0) {
        self.lastReviewStatusUID = @"";
        self.hasSubmittedProviderReview = NO;
        self.isCheckingProviderReviewStatus = NO;
        self.didCompleteLegacyProviderReviewScan = NO;
        [self pp_updateReviewComposerState];
        return;
    }

    if (![self.lastReviewStatusUID isEqualToString:reviewerUID]) {
        self.lastReviewStatusUID = reviewerUID;
        self.hasSubmittedProviderReview = NO;
        self.isCheckingProviderReviewStatus = NO;
        self.didCompleteLegacyProviderReviewScan = NO;
    }

    if ([self pp_reviewsArray:self.providerScopedReviews containsReviewerUID:reviewerUID] ||
        [self pp_reviewsArray:self.legacyServiceScopedReviews containsReviewerUID:reviewerUID]) {
        self.hasSubmittedProviderReview = YES;
        self.didCompleteLegacyProviderReviewScan = YES;
        self.isCheckingProviderReviewStatus = NO;
        [self pp_updateReviewComposerState];
        return;
    }

    if (self.service.serviceOwnerID.length == 0 ||
        [self pp_isOwnedByCurrentUser] ||
        self.didCompleteLegacyProviderReviewScan ||
        self.isCheckingProviderReviewStatus) {
        [self pp_updateReviewComposerState];
        return;
    }

    self.isCheckingProviderReviewStatus = YES;
    [self pp_updateReviewComposerState];

    __weak typeof(self) weakSelf = self;
    [self pp_scanLegacyProviderReviewsForReviewerUID:reviewerUID completion:^(BOOL found, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || ![strongSelf.lastReviewStatusUID isEqualToString:reviewerUID]) {
                return;
            }

            strongSelf.isCheckingProviderReviewStatus = NO;
            strongSelf.didCompleteLegacyProviderReviewScan = YES;
            if (found) {
                strongSelf.hasSubmittedProviderReview = YES;
            }

            [strongSelf pp_updateReviewComposerState];
        });
    }];
}

- (void)pp_scanLegacyProviderReviewsForReviewerUID:(NSString *)reviewerUID
                                        completion:(void (^)(BOOL found, NSError * _Nullable error))completion {
    if (reviewerUID.length == 0 || self.service.serviceOwnerID.length == 0) {
        if (completion) {
            completion(NO, nil);
        }
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRQuery *servicesQuery =
        [[db collectionWithPath:@"serviceOffers"] queryWhereField:@"serviceOwnerID" isEqualTo:self.service.serviceOwnerID];

    [servicesQuery getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error || !snapshot) {
            if (completion) {
                completion(NO, error);
            }
            return;
        }

        NSArray<FIRDocumentSnapshot *> *documents = snapshot.documents ?: @[];
        if (documents.count == 0) {
            if (completion) {
                completion(NO, nil);
            }
            return;
        }

        __block NSUInteger index = 0;
        __weak typeof(self) weakSelf = self;
        __block void (^checkNextReview)(void) = nil;
        checkNextReview = ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                if (completion) {
                    completion(NO, nil);
                }
                return;
            }

            if (index >= documents.count) {
                if (completion) {
                    completion(NO, nil);
                }
                return;
            }

            FIRDocumentSnapshot *serviceDoc = documents[index++];
            NSString *serviceID = serviceDoc.documentID ?: @"";
            if (serviceID.length == 0) {
                checkNextReview();
                return;
            }

            if ([serviceID isEqualToString:strongSelf.service.serviceID]) {
                if ([strongSelf pp_reviewsArray:strongSelf.legacyServiceScopedReviews containsReviewerUID:reviewerUID]) {
                    if (completion) {
                        completion(YES, nil);
                    }
                    return;
                }
                checkNextReview();
                return;
            }

            FIRDocumentReference *legacyReviewRef =
                [[[[db collectionWithPath:@"serviceOffers"] documentWithPath:serviceID]
                  collectionWithPath:@"reviews"] documentWithPath:reviewerUID];

            [legacyReviewRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable reviewSnapshot, NSError * _Nullable reviewError) {
                if (reviewError) {
                    if (completion) {
                        completion(NO, reviewError);
                    }
                    return;
                }

                if (reviewSnapshot.exists) {
                    if (completion) {
                        completion(YES, nil);
                    }
                    return;
                }

                checkNextReview();
            }];
        };

        checkNextReview();
    }];
}

- (NSString *)pp_currentReviewerUID {
    UserModel *currentUser = [UserManager sharedManager].currentUser;
    NSString *authUID = PPCurrentFIRAuthUser.uid ?: @"";
    if (authUID.length > 0) {
        return authUID;
    }
    return [currentUser.ID isKindOfClass:NSString.class] ? currentUser.ID : @"";
}

- (BOOL)pp_reviewsArray:(NSArray<NSDictionary<NSString *, id> *> *)reviews containsReviewerUID:(NSString *)reviewerUID {
    if (reviewerUID.length == 0) {
        return NO;
    }

    for (NSDictionary<NSString *, id> *review in reviews) {
        if ([[self pp_reviewIdentifierForDictionary:review] isEqualToString:reviewerUID]) {
            return YES;
        }
    }

    return NO;
}

- (NSString *)pp_reviewIdentifierForDictionary:(NSDictionary<NSString *, id> *)review {
    NSString *identifier = [self pp_reviewStringFromDictionary:review keys:@[@"userID", @"reviewID", @"uid", @"reviewerID"]];
    return identifier.length > 0 ? identifier : @"";
}

- (NSDate *)pp_reviewSortDateForDictionary:(NSDictionary<NSString *, id> *)review {
    return [self pp_reviewDateFromValue:review[@"updatedAt"] ?: review[@"createdAt"] ?: review[@"date"] ?: review[@"timestamp"]];
}

- (void)pp_rebuildActions {
    for (UIView *view in self.actionsStackView.arrangedSubviews) {
        [self.actionsStackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    self.shareActionButton = [self pp_actionTileButtonWithSymbol:@"square.and.arrow.up"
                                                           title:kLang(@"Share")
                                                            tint:AppPrimaryClr ?: UIColor.systemBlueColor
                                                         selector:@selector(shareTapped)];
    self.PhoneActionButton = [self pp_actionTileButtonWithSymbol:@"doc.on.doc"
                                                               title:kLang(@"service_view_copy_number")
                                                                tint:[UIColor colorWithRed:0.20 green:0.62 blue:0.58 alpha:1.0]
                                                             selector:@selector(copyNumberTapped)];

    [self.actionsStackView addArrangedSubview:self.shareActionButton];
    [self.actionsStackView addArrangedSubview:self.PhoneActionButton];

    if (![self pp_isOwnedByCurrentUser]) {
        self.reportActionButton = [self pp_actionTileButtonWithSymbol:@"flag.fill"
                                                                title:kLang(@"report_alert_title")
                                                                 tint:[UIColor systemRedColor]
                                                              selector:@selector(reportAdBTN)];
        [self.actionsStackView addArrangedSubview:self.reportActionButton];
    } else {
        self.reportActionButton = nil;
    }

    [self pp_updateActionAvailability];
}

#pragma mark - Content Helpers

- (NSArray<PPInfoPill *> *)pp_summaryPills {
    NSString *importantText = [self pp_heroImportantInfoText];
    if (importantText.length == 0) {
        return @[];
    }

    NSString *iconName = self.service.isLive ? @"checkmark.seal.fill" : @"exclamationmark.triangle.fill";
    return @[[PPInfoPill itemWithIcon:iconName text:importantText]];
}

- (NSString *)pp_heroImportantInfoText {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    NSString *availabilityText = [self.service localizedAvailabilityStatus];
    if (availabilityText.length > 0) {
        [parts addObject:availabilityText];
    }

    NSString *typeName = [self pp_serviceTypeName];
    if (typeName.length > 0 && ![typeName isEqualToString:kLang(@"Not specified")]) {
        [parts addObject:typeName];
    }

    NSString *petKindText = [self pp_petKindText];
    if (petKindText.length > 0 && ![petKindText isEqualToString:kLang(@"Not specified")]) {
        [parts addObject:petKindText];
    }

    if (parts.count == 0) {
        return kLang(@"service_view_important_info_default");
    }

    return [parts componentsJoinedByString:@" • "];
}

- (NSString *)pp_serviceTitle {
    return self.service.title.length > 0 ? self.service.title : kLang(@"service_view_default_title");
}

- (NSString *)pp_categoryText {
    return self.service.category.length > 0 ? self.service.category : kLang(@"not available");
}

- (NSString *)pp_petKindText {
    if (self.service.petMainKindID > 0) {
        MainKindsModel *kind = [MainKindsModel mainKindModelForID:self.service.petMainKindID];
        if (kind.KindName.length > 0) {
            return kind.KindName;
        }
    }
    return kLang(@"Not specified");
}

- (NSString *)pp_availableDateText {
    // Prefer explicit availability status from the upgraded model
    return [self.service localizedAvailabilityStatus];
}

- (NSString *)pp_serviceTypeName {
    NSString *name = [self.service localizedTypeName];
    return name.length > 0 ? name : kLang(@"Not specified");
}

- (NSString *)pp_ratingText {
    if ([self.service hasDisplayableRating]) {
        return [NSString stringWithFormat:@"%.1f (%ld)",
                self.service.ratingValue.doubleValue,
                (long)self.service.reviewCount];
    }
    return kLang(@"service_view_no_reviews");
}

- (NSString *)pp_postedDateText {
    NSDate *postedDate = self.service.createdAt ?: self.service.timestamp ?: self.service.availableDate;
    if ([postedDate isKindOfClass:[NSDate class]]) {
        return [GM formattedDate:postedDate];
    }
    return kLang(@"Not specified");
}

- (NSString *)pp_providerDisplayName {
    NSString *providerName = @"";
    if ([self.ownerModel respondsToSelector:@selector(PPBestDisplayName)]) {
        providerName = [self.ownerModel PPBestDisplayName];
    }
    if (providerName.length == 0) {
        providerName = self.ownerModel.UserName ?: @"";
    }
    if (providerName.length == 0 && self.service.serviceOwnerID.length > 0) {
        return self.didAttemptOwnerLoad ? kLang(@"service_view_owner") : kLang(@"service_view_owner_pending");
    }
    if (providerName.length == 0) {
        return kLang(@"service_view_owner");
    }
    return providerName;
}

- (NSString *)pp_providerMetaText {
    if (!self.ownerModel) {
        if (self.service.serviceOwnerID.length == 0 || self.didAttemptOwnerLoad) {
            return kLang(@"service_view_provider_unavailable");
        }
        return kLang(@"service_view_provider_loading");
    }

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    [parts addObject:(self.ownerModel.isVerified
                      ? kLang(@"service_view_provider_verified")
                      : kLang(@"service_view_provider_unverified"))];

    NSDate *memberDate = self.ownerModel.loginDate ?: self.ownerModel.updatedAt;
    if ([memberDate isKindOfClass:[NSDate class]]) {
        NSString *memberSinceText = [NSString stringWithFormat:@"%@ %@",
                                     kLang(@"service_view_member_since"),
                                     [GM formattedDate:memberDate]];
        [parts addObject:memberSinceText];
    }

    if (self.ownerModel.MobileNo.length > 0) {
        [parts addObject:kLang(@"service_view_contact_ready")];
    } else {
        [parts addObject:kLang(@"service_view_contact_limited")];
    }

    NSString *countryText = [self pp_providerCountryText];
    if (countryText.length > 0 && ![countryText isEqualToString:kLang(@"Not specified")]) {
        [parts addObject:countryText];
    }

    return [parts componentsJoinedByString:@" • "];
}

- (NSString *)pp_providerAboutText {
    if (self.ownerModel.UserAbout.length > 0) {
        return self.ownerModel.UserAbout;
    }
    if (!self.ownerModel) {
        if (self.service.serviceOwnerID.length == 0 || self.didAttemptOwnerLoad) {
            return kLang(@"service_view_provider_contact_pending");
        }
        return kLang(@"service_view_contact_loading");
    }
    return kLang(@"service_view_provider_about_empty");
}

- (NSString *)pp_providerCountryText {
    if (!self.ownerModel || self.ownerModel.CountryID <= 0) {
        return kLang(@"Not specified");
    }

    NSString *countryName = [CitiesManager.shared countryNameForID:self.ownerModel.CountryID];
    return countryName.length > 0 ? countryName : kLang(@"Not specified");
}

- (NSString *)pp_priceText {
    NSString *currencyCode = self.service.currency.length > 0 ? self.service.currency : kLang(@"Rials");
    NSString *formattedPrice = [GM formatPrice:@(self.service.price) currencyCode:currencyCode];
    if (formattedPrice.length > 0) {
        return formattedPrice;
    }
    return [NSString stringWithFormat:@"%.2f %@", self.service.price, currencyCode];
}

- (BOOL)pp_isOwnedByCurrentUser {
    NSString *currentUID = [self trackingUserID];
    if (currentUID.length == 0 || self.service.serviceOwnerID.length == 0) {
        return NO;
    }
    return [currentUID isEqualToString:self.service.serviceOwnerID];
}

- (void)pp_updateActionAvailability {
    BOOL canCopyNumber = self.ownerModel.MobileNo.length > 0;
    self.PhoneActionButton.enabled = canCopyNumber;
    self.PhoneActionButton.alpha = canCopyNumber ? 1.0 : 0.58;
}

- (void)pp_updateUnavailableBanner {
    BOOL showBanner = !self.service.isLive;

    if (!showBanner) {
        [self.unavailableBannerView removeFromSuperview];
        self.unavailableBannerView = nil;
        return;
    }

    if (self.unavailableBannerView) return;

    UIView *banner = [[UIView alloc] init];
    banner.translatesAutoresizingMaskIntoConstraints = NO;
    banner.backgroundColor = [[UIColor colorWithRed:0.89 green:0.32 blue:0.36 alpha:1.0] colorWithAlphaComponent:0.92];
    banner.layer.cornerRadius = 14.0;
    if (@available(iOS 13.0, *)) {
        banner.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIImageView *warnIcon = [[UIImageView alloc] init];
    warnIcon.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *cfg =
        [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold];
    warnIcon.image = [[UIImage systemImageNamed:@"exclamationmark.triangle.fill"]
                       imageByApplyingSymbolConfiguration:cfg];
    warnIcon.tintColor = UIColor.whiteColor;
    warnIcon.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *bannerLabel = [[UILabel alloc] init];
    bannerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    bannerLabel.font = [GM boldFontWithSize:14];
    bannerLabel.textColor = UIColor.whiteColor;
    bannerLabel.text = kLang(@"service_view_unavailable_banner");
    bannerLabel.numberOfLines = 1;
    bannerLabel.textAlignment = Language.alignmentForCurrentLanguage;

    [banner addSubview:warnIcon];
    [banner addSubview:bannerLabel];
    [self.heroContainerView addSubview:banner];

    [NSLayoutConstraint activateConstraints:@[
        [banner.topAnchor constraintEqualToAnchor:self.heroContainerView.topAnchor constant:18.0],
        [banner.trailingAnchor constraintEqualToAnchor:self.heroContainerView.trailingAnchor constant:-18.0],
        [banner.heightAnchor constraintEqualToConstant:36.0],

        [warnIcon.leadingAnchor constraintEqualToAnchor:banner.leadingAnchor constant:10.0],
        [warnIcon.centerYAnchor constraintEqualToAnchor:banner.centerYAnchor],
        [warnIcon.widthAnchor constraintEqualToConstant:16.0],
        [warnIcon.heightAnchor constraintEqualToConstant:16.0],

        [bannerLabel.leadingAnchor constraintEqualToAnchor:warnIcon.trailingAnchor constant:6.0],
        [bannerLabel.trailingAnchor constraintEqualToAnchor:banner.trailingAnchor constant:-12.0],
        [bannerLabel.centerYAnchor constraintEqualToAnchor:banner.centerYAnchor]
    ]];

    self.unavailableBannerView = banner;
}

#pragma mark - Motion

- (void)pp_prepareEntranceState {
    [self.titleView prepareForEntrance];

    NSArray<UIView *> *animatedSections = @[
        self.providerSectionView,
        self.factsSectionView,
        self.reviewsSectionView,
        self.descriptionSectionView,
        self.actionsSectionView
    ];

    for (UIView *view in animatedSections) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 18.0);
    }
}

- (void)pp_beginEntranceAnimationsIfNeeded {
    if (self.didAnimateEntrance) {
        return;
    }
    self.didAnimateEntrance = YES;

    [self.titleView animateEntranceIfNeeded];

    NSArray<UIView *> *animatedSections = @[
        self.providerSectionView,
        self.factsSectionView,
        self.reviewsSectionView,
        self.descriptionSectionView,
        self.actionsSectionView
    ];

    [animatedSections enumerateObjectsUsingBlock:^(UIView * _Nonnull sectionView, NSUInteger idx, BOOL * _Nonnull stop) {
        [UIView animateWithDuration:0.46
                              delay:0.08 + (0.06 * idx)
             usingSpringWithDamping:0.88
              initialSpringVelocity:0.18
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            sectionView.alpha = 1.0;
            sectionView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

#pragma mark - Actions

- (void)closeTapped {
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];

    if (self.presentingViewController ||
        (self.navigationController.presentingViewController &&
         self.navigationController.viewControllers.firstObject == self)) {
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }

    [self.navigationController popViewControllerAnimated:YES];
}

- (void)shareTapped {
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [lines addObject:[NSString stringWithFormat:@"%@: %@",
                      kLang(@"service_view_share_title"),
                      [self pp_serviceTitle]]];
    [lines addObject:[NSString stringWithFormat:@"%@: %@",
                      kLang(@"service_view_category"),
                      [self pp_categoryText]]];

    NSString *typeName = [self.service localizedTypeName];
    if (typeName.length > 0) {
        [lines addObject:[NSString stringWithFormat:@"%@: %@",
                          kLang(@"service_view_type"),
                          typeName]];
    }

    [lines addObject:[NSString stringWithFormat:@"%@: %@",
                      kLang(@"service_view_owner"),
                      [self pp_providerDisplayName]]];
    [lines addObject:[NSString stringWithFormat:@"%@: %@",
                      kLang(@"Price"),
                      [self pp_priceText]]];

    NSString *availStatus = [self.service localizedAvailabilityStatus];
    if (availStatus.length > 0) {
        [lines addObject:[NSString stringWithFormat:@"%@: %@",
                          kLang(@"service_view_availability"),
                          availStatus]];
    }

    if (self.service.desc.length > 0) {
        [lines addObject:self.service.desc];
    }

    UIActivityViewController *activityVC =
        [[UIActivityViewController alloc] initWithActivityItems:@[[lines componentsJoinedByString:@"\n"]]
                                          applicationActivities:nil];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = self.shareActionButton ?: self.view;
        activityVC.popoverPresentationController.sourceRect = self.shareActionButton
            ? self.shareActionButton.bounds
            : CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1.0, 1.0);
        activityVC.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }

    [self presentViewController:activityVC animated:YES completion:nil];
    [self trackServiceInteraction:PPItemInteractionTypeShare];
}

- (void)copyNumberTapped {
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];

    if (![self ensureSignedInForContactAction]) {
        return;
    }

    [self loadOwnerIfNeeded];
    if (!self.ownerModel) {
        [PPAlertHelper showInfoIn:self
                            title:kLang(@"service_view_provider_title")
                         subtitle:[self pp_contactUnavailableMessage]];
        return;
    }

    if (self.ownerModel.MobileNo.length == 0) {
        [PPAlertHelper showInfoIn:self
                            title:kLang(@"No Number")
                         subtitle:kLang(@"service_view_copy_number_missing")];
        return;
    }

    UIPasteboard.generalPasteboard.string = self.ownerModel.MobileNo;
    [PPAlertHelper showSuccessIn:self
                           title:kLang(@"service_view_copy_number")
                        subtitle:kLang(@"service_view_copy_number_success")];
}

- (void)callTapped {
    if (![self ensureSignedInForContactAction]) {
        return;
    }

    [self loadOwnerIfNeeded];
    if (!self.ownerModel) {
        [PPAlertHelper showInfoIn:self
                            title:kLang(@"service_view_provider_title")
                         subtitle:[self pp_contactUnavailableMessage]];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }

    if (self.ownerModel.MobileNo.length == 0) {
        [PPAlertHelper showInfoIn:self
                            title:kLang(@"No Number")
                         subtitle:kLang(@"service_view_copy_number_missing")];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }

    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
    [AppClasses callPhoneNumber:self.ownerModel.MobileNo fromViewController:self];
    [self trackServiceInteraction:PPItemInteractionTypeCall];
}

- (void)chatTapped {
    if (![self ensureSignedInForContactAction]) {
        return;
    }

    [self loadOwnerIfNeeded];
    if (!self.ownerModel) {
        [PPAlertHelper showInfoIn:self
                            title:kLang(@"service_view_provider_title")
                         subtitle:[self pp_contactUnavailableMessage]];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }

    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
    [GM chatWith:self.ownerModel FromController:self];
    [self trackServiceInteraction:PPItemInteractionTypeChat];
}

#pragma mark - Reviews

- (void)reviewStarTapped:(UIButton *)sender {
    self.selectedReviewRating = MAX(1, MIN(sender.tag, 5));
    [self pp_updateReviewStars];
    [self pp_updateReviewComposerState];
}

- (void)submitReviewTapped {
    if (![UserManager sharedManager].isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    if ([self pp_isOwnedByCurrentUser]) {
        [PPHUD showInfo:kLang(@"service_rate_sheet_owner_block")];
        return;
    }

    if (self.service.serviceID.length == 0 || self.service.serviceOwnerID.length == 0) {
        [PPHUD showError:kLang(@"service_rate_sheet_failed")
                subtitle:kLang(@"service_view_provider_contact_pending")];
        return;
    }

    UserManager *userManager = [UserManager sharedManager];
    UserModel *currentUser = userManager.currentUser;
    NSString *uid = [self pp_currentReviewerUID];
    if (uid.length == 0) {
        [UserManager showPromptOnTopController];
        return;
    }

    if (self.isCheckingProviderReviewStatus) {
        return;
    }

    if (self.hasSubmittedProviderReview) {
        [PPHUD showInfo:kLang(@"service_review_existing_title")
               subtitle:kLang(@"service_review_existing_subtitle")];
        return;
    }

    if (currentUser.isBlocked || [userManager isCurrentUserBlocked]) {
        [PPHUD showError:kLang(@"error") subtitle:kLang(@"service_review_blocked_account")];
        return;
    }

    if (self.selectedReviewRating <= 0) {
        [PPHUD showInfo:kLang(@"service_review_select_rating")];
        return;
    }

    NSString *comment = [self pp_currentReviewComment];
    if (comment.length > 600) {
        comment = [comment substringToIndex:600];
    }

    NSString *displayName = @"";
    if ([currentUser respondsToSelector:@selector(PPBestDisplayName)]) {
        displayName = currentUser.PPBestDisplayName ?: @"";
    }
    if (displayName.length == 0) {
        displayName = currentUser.UserName ?: @"";
    }
    if (displayName.length == 0) {
        displayName = kLang(@"service_view_review_anonymous");
    }

    self.isSubmittingReview = YES;
    [self pp_updateReviewComposerState];
    [PPHUD showLoading:kLang(@"service_rate_sheet_submitting")];

    FIRDocumentReference *reviewRef =
        [[[[[FIRFirestore firestore] collectionWithPath:@"UsersCol"]
           documentWithPath:self.service.serviceOwnerID]
          collectionWithPath:@"providerReviews"]
         documentWithPath:uid];

    __weak typeof(self) weakSelf = self;
    [reviewRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                strongSelf.isSubmittingReview = NO;
                [strongSelf pp_updateReviewComposerState];
                [PPHUD showError:kLang(@"service_rate_sheet_failed") subtitle:error.localizedDescription];
            });
            return;
        }

        if (snapshot.exists) {
            dispatch_async(dispatch_get_main_queue(), ^{
                strongSelf.isSubmittingReview = NO;
                strongSelf.hasSubmittedProviderReview = YES;
                strongSelf.didCompleteLegacyProviderReviewScan = YES;
                [strongSelf pp_updateReviewComposerState];
                [PPHUD showInfo:kLang(@"service_review_existing_title")
                       subtitle:kLang(@"service_review_existing_subtitle")];
            });
            return;
        }

        NSMutableDictionary *payload = [@{
            @"reviewID": uid,
            @"serviceID": strongSelf.service.serviceID ?: @"",
            @"serviceOwnerID": strongSelf.service.serviceOwnerID ?: @"",
            @"userID": uid,
            @"reviewerName": displayName ?: @"",
            @"rating": @(strongSelf.selectedReviewRating),
            @"comment": comment ?: @"",
            @"platform": @"ios",
            @"createdAt": [FIRFieldValue fieldValueForServerTimestamp],
            @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
        } mutableCopy];
        NSMutableDictionary *localReview = [@{
            @"reviewID": uid,
            @"serviceID": strongSelf.service.serviceID ?: @"",
            @"serviceOwnerID": strongSelf.service.serviceOwnerID ?: @"",
            @"userID": uid,
            @"reviewerName": displayName ?: @"",
            @"rating": @(strongSelf.selectedReviewRating),
            @"comment": comment ?: @"",
            @"platform": @"ios",
            @"createdAt": [NSDate date],
            @"updatedAt": [NSDate date]
        } mutableCopy];

        [reviewRef setData:payload completion:^(NSError * _Nullable writeError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                strongSelf.isSubmittingReview = NO;
                if (writeError) {
                    [strongSelf pp_updateReviewComposerState];
                    [PPHUD showError:kLang(@"service_rate_sheet_failed") subtitle:writeError.localizedDescription];
                    return;
                }

                if (strongSelf.reviewTextView.text.length > 0 &&
                    ![strongSelf.reviewTextView.text isEqualToString:strongSelf.reviewPlaceholderText]) {
                    strongSelf.reviewTextView.text = strongSelf.reviewPlaceholderText;
                    strongSelf.reviewTextView.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.46];
                }
                strongSelf.selectedReviewRating = 0;
                strongSelf.hasSubmittedProviderReview = YES;
                strongSelf.didCompleteLegacyProviderReviewScan = YES;
                [strongSelf pp_updateReviewStars];

                NSMutableArray<NSDictionary<NSString *, id> *> *providerReviews =
                    [strongSelf.providerScopedReviews mutableCopy] ?: [NSMutableArray array];
                NSIndexSet *existingIndexes =
                    [providerReviews indexesOfObjectsPassingTest:^BOOL(NSDictionary<NSString *,id> * _Nonnull review,
                                                                       NSUInteger idx,
                                                                       BOOL * _Nonnull stop) {
                        return [[strongSelf pp_reviewIdentifierForDictionary:review] isEqualToString:uid];
                    }];
                if (existingIndexes.count > 0) {
                    [providerReviews removeObjectsAtIndexes:existingIndexes];
                }
                [providerReviews insertObject:localReview.copy atIndex:0];
                strongSelf.providerScopedReviews = providerReviews.copy;
                [strongSelf pp_refreshMergedReviews];

                [PPHUD showSuccess:kLang(@"service_rate_sheet_success")
                            subtitle:kLang(@"service_review_success_subtitle")];
            });
        }];
    }];
}

- (void)pp_updateReviewStars {
    UIColor *selectedColor = [UIColor colorWithRed:0.95 green:0.63 blue:0.20 alpha:1.0];
    UIColor *idleColor = [selectedColor colorWithAlphaComponent:0.42];

    for (UIButton *button in self.reviewStarButtons) {
        BOOL selected = button.tag <= self.selectedReviewRating;
        button.tintColor = selected ? selectedColor : idleColor;
        button.backgroundColor = selected
            ? [selectedColor colorWithAlphaComponent:0.15]
            : [UIColor colorWithWhite:1.0 alpha:0.52];
        [button pp_setBorderColor:[selectedColor colorWithAlphaComponent:(selected ? 0.28 : 0.14)]];
        button.transform = selected ? CGAffineTransformMakeScale(1.02, 1.02) : CGAffineTransformIdentity;
    }
}

- (void)pp_updateReviewComposerState {
    BOOL loggedIn = [UserManager sharedManager].isUserLoggedIn;
    BOOL isOwner = [self pp_isOwnedByCurrentUser];
    BOOL hasExistingReview = loggedIn && self.hasSubmittedProviderReview;
    BOOL isCheckingProviderReview = loggedIn && !isOwner && !hasExistingReview && self.isCheckingProviderReviewStatus;
    BOOL canTapButton = !isOwner && !hasExistingReview && !self.isSubmittingReview && !isCheckingProviderReview;
    BOOL canSubmit = loggedIn && canTapButton && self.selectedReviewRating > 0;

    self.reviewComposerTitleLabel.text = hasExistingReview
        ? kLang(@"service_review_existing_title")
        : kLang(@"service_review_composer_title");
    self.reviewComposerSubtitleLabel.text = hasExistingReview
        ? kLang(@"service_review_existing_subtitle")
        : kLang(@"service_review_composer_subtitle");
    self.reviewStarsStackView.hidden = hasExistingReview;
    self.reviewTextView.hidden = hasExistingReview;
    self.submitReviewButton.hidden = hasExistingReview;
    self.reviewStarsTopConstraint.constant = hasExistingReview ? 0.0 : 14.0;
    self.reviewTextTopConstraint.constant = hasExistingReview ? 0.0 : 12.0;
    self.reviewTextMinHeightConstraint.constant = hasExistingReview ? 0.0 : 82.0;
    self.submitReviewTopConstraint.constant = hasExistingReview ? 0.0 : 12.0;
    self.submitReviewHeightConstraint.constant = hasExistingReview ? 0.0 : 44.0;

    self.reviewTextView.editable = loggedIn && !isOwner && !hasExistingReview && !self.isSubmittingReview && !isCheckingProviderReview;
    self.reviewStarsStackView.userInteractionEnabled = loggedIn && !isOwner && !hasExistingReview && !self.isSubmittingReview && !isCheckingProviderReview;
    self.submitReviewButton.enabled = canTapButton;
    self.submitReviewButton.alpha = canSubmit ? 1.0 : (canTapButton ? 0.74 : 0.56);

    if (self.isSubmittingReview) {
        [self.submitReviewButton setTitle:kLang(@"service_rate_sheet_submitting") forState:UIControlStateNormal];
    } else if (hasExistingReview) {
        [self.submitReviewButton setTitle:kLang(@"service_review_existing_title") forState:UIControlStateNormal];
    } else if (isOwner) {
        [self.submitReviewButton setTitle:kLang(@"service_rate_sheet_owner_block") forState:UIControlStateNormal];
    } else if (!loggedIn) {
        [self.submitReviewButton setTitle:kLang(@"service_review_sign_in_action") forState:UIControlStateNormal];
    } else {
        [self.submitReviewButton setTitle:kLang(@"service_review_submit") forState:UIControlStateNormal];
    }
}

- (NSString *)pp_currentReviewComment {
    NSString *text = self.reviewTextView.text ?: @"";
    if ([text isEqualToString:self.reviewPlaceholderText]) {
        return @"";
    }
    return [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
}

#pragma mark - UITextViewDelegate

- (void)textViewDidBeginEditing:(UITextView *)textView {
    if (textView != self.reviewTextView) {
        return;
    }

    if ([textView.text isEqualToString:self.reviewPlaceholderText]) {
        textView.text = @"";
        textView.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    }
}

- (void)textViewDidEndEditing:(UITextView *)textView {
    if (textView != self.reviewTextView) {
        return;
    }

    NSString *trimmed = [textView.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) {
        textView.text = self.reviewPlaceholderText;
        textView.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.46];
    }
}

#pragma mark - Owner

- (void)loadOwnerIfNeeded {
    if (self.ownerModel || self.isResolvingOwner || self.service.serviceOwnerID.length == 0) {
        return;
    }

    self.isResolvingOwner = YES;
    self.didAttemptOwnerLoad = NO;
    __weak typeof(self) weakSelf = self;
    [UsrMgr getOtherUserModelFromFirestoreWithUID:self.service.serviceOwnerID completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }

            strongSelf.isResolvingOwner = NO;
            strongSelf.didAttemptOwnerLoad = YES;
            if (error || !user) {
                [strongSelf applyModelContent];
                return;
            }

            strongSelf.ownerModel = user;
            [strongSelf applyModelContent];
        });
    }];
}

- (BOOL)ensureSignedInForContactAction {
    if (UserManager.sharedManager.isUserLoggedIn) {
        return YES;
    }

    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
    [UserManager showPromptOnTopController];
    return NO;
}

- (NSString *)pp_contactUnavailableMessage {
    if (self.service.serviceOwnerID.length == 0 || self.didAttemptOwnerLoad) {
        return kLang(@"service_view_provider_contact_pending");
    }
    return kLang(@"service_view_contact_loading");
}

#pragma mark - Tracking

- (NSString *)trackingUserID {
    NSString *userID = [UserManager sharedManager].currentUser.ID;
    if (userID.length > 0) {
        return userID;
    }
    if (PPCurrentFIRAuthUser.uid.length > 0) {
        return PPCurrentFIRAuthUser.uid;
    }
    return nil;
}

- (void)trackServiceInteraction:(PPItemInteractionType)interaction {
    if (self.service.serviceID.length == 0) {
        return;
    }

    [PetAdManager trackInteraction:interaction
                         forItemID:self.service.serviceID
                        collection:@"serviceOffers"
                            userID:[self trackingUserID]
                        completion:nil];
}

#pragma mark - UI Helpers

- (CGFloat)pp_heroHeight {
    CGFloat width = CGRectGetWidth(self.view.bounds);
    if (width <= 0.0) {
        width = UIScreen.mainScreen.bounds.size.width;
    }
    return MIN(MAX(width * 0.90, 330.0), 430.0);
}

- (UIView *)pp_surfaceSectionView {
    UIView *surface = [[UIView alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.backgroundColor = PPBackgroundColorForIOS26([AppForgroundColr colorWithAlphaComponent:0.96]);
    surface.layer.cornerRadius = PPServiceViewerSurfaceRadius;
    surface.layer.borderWidth = 1.0;
    [surface pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:0.06]];
    [surface pp_setShadowColor:UIColor.blackColor];
    surface.layer.shadowOpacity = 0.08f;
    surface.layer.shadowRadius = 18.0f;
    surface.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    if (@available(iOS 13.0, *)) {
        surface.layer.cornerCurve = kCACornerCurveContinuous;
    }
    return surface;
}

- (UILabel *)pp_sectionTitleLabelWithText:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [GM boldFontWithSize:20];
    label.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.text = text;
    return label;
}

- (UILabel *)pp_badgeLabelWithBackgroundColor:(UIColor *)backgroundColor textColor:(UIColor *)textColor {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [GM boldFontWithSize:13];
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = textColor;
    label.backgroundColor = backgroundColor;
    label.layer.cornerRadius = 16.0;
    label.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        label.layer.cornerCurve = kCACornerCurveContinuous;
    }
    return label;
}

- (UIButton *)pp_topChromeButtonWithSystemName:(NSString *)systemName selector:(SEL)selector {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    UIImage *icon = [[UIImage systemImageNamed:systemName] imageByApplyingSymbolConfiguration:configuration];
    [button setImage:icon forState:UIControlStateNormal];
    button.tintColor = AppPrimaryTextClr ?: UIColor.labelColor;
    button.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.86];
    button.layer.cornerRadius = 20.0;
    button.layer.borderWidth = 1.0;
    [button pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:0.14]];
    [button pp_setShadowColor:UIColor.blackColor];
    button.layer.shadowOpacity = 0.08f;
    button.layer.shadowRadius = 14.0f;
    button.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIView *)pp_factRowWithViews:(NSArray<UIView *> *)views {
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:views];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentFill;
    row.distribution = UIStackViewDistributionFillEqually;
    row.spacing = 12.0;
    return row;
}

- (UIView *)pp_factTileWithIcon:(NSString *)iconName
                          title:(NSString *)title
                          value:(NSString *)value
                         accent:(UIColor *)accentColor {
    UIView *tile = [[UIView alloc] init];
    tile.translatesAutoresizingMaskIntoConstraints = NO;
    tile.backgroundColor = [accentColor colorWithAlphaComponent:0.10];
    tile.layer.cornerRadius = 22.0;
    tile.layer.borderWidth = 1.0;
    [tile pp_setBorderColor:[accentColor colorWithAlphaComponent:0.18]];
    if (@available(iOS 13.0, *)) {
        tile.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIView *iconShell = [[UIView alloc] init];
    iconShell.translatesAutoresizingMaskIntoConstraints = NO;
    iconShell.backgroundColor = [accentColor colorWithAlphaComponent:0.16];
    iconShell.layer.cornerRadius = 15.0;
    if (@available(iOS 13.0, *)) {
        iconShell.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
    iconView.image = [[UIImage systemImageNamed:iconName] imageByApplyingSymbolConfiguration:configuration];
    iconView.tintColor = accentColor;
    iconView.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM MidFontWithSize:12];
    titleLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.64];
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.text = title;
    titleLabel.numberOfLines = 1;

    UILabel *valueLabel = [[UILabel alloc] init];
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.font = [GM boldFontWithSize:15];
    valueLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    valueLabel.textAlignment = Language.alignmentForCurrentLanguage;
    valueLabel.numberOfLines = 2;
    valueLabel.text = value;

    [tile addSubview:iconShell];
    [iconShell addSubview:iconView];
    [tile addSubview:titleLabel];
    [tile addSubview:valueLabel];

    [NSLayoutConstraint activateConstraints:@[
        [tile.heightAnchor constraintGreaterThanOrEqualToConstant:110.0],

        [iconShell.topAnchor constraintEqualToAnchor:tile.topAnchor constant:14.0],
        [iconShell.leadingAnchor constraintEqualToAnchor:tile.leadingAnchor constant:14.0],
        [iconShell.widthAnchor constraintEqualToConstant:30.0],
        [iconShell.heightAnchor constraintEqualToConstant:30.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:15.0],
        [iconView.heightAnchor constraintEqualToConstant:15.0],

        [titleLabel.topAnchor constraintEqualToAnchor:iconShell.bottomAnchor constant:12.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:tile.leadingAnchor constant:14.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:tile.trailingAnchor constant:-14.0],

        [valueLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:5.0],
        [valueLabel.leadingAnchor constraintEqualToAnchor:tile.leadingAnchor constant:14.0],
        [valueLabel.trailingAnchor constraintEqualToAnchor:tile.trailingAnchor constant:-14.0],
        [valueLabel.bottomAnchor constraintLessThanOrEqualToAnchor:tile.bottomAnchor constant:-14.0]
    ]];

    return tile;
}

- (UIView *)pp_emptyReviewsView {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [GM MidFontWithSize:15];
    label.numberOfLines = 0;
    label.text = kLang(@"service_view_no_reviews");
    label.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.68];
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.backgroundColor = [AppPrimaryTextClr ?: UIColor.labelColor colorWithAlphaComponent:0.04];
    label.layer.cornerRadius = 18.0;
    label.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        label.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [NSLayoutConstraint activateConstraints:@[
        [label.heightAnchor constraintGreaterThanOrEqualToConstant:54.0]
    ]];
    return label;
}

- (UIView *)pp_reviewComposerView {
    UIView *view = [[UIView alloc] init];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    UIColor *accentColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    view.backgroundColor = [accentColor colorWithAlphaComponent:0.08];
    view.layer.cornerRadius = 22.0;
    view.layer.borderWidth = 1.0;
    [view pp_setBorderColor:[accentColor colorWithAlphaComponent:0.14]];
    [view pp_setShadowColor:UIColor.blackColor];
    view.layer.shadowOpacity = 0.04f;
    view.layer.shadowRadius = 14.0f;
    view.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    if (@available(iOS 13.0, *)) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }

    self.reviewComposerTitleLabel = [[UILabel alloc] init];
    self.reviewComposerTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.reviewComposerTitleLabel.font = [GM boldFontWithSize:16];
    self.reviewComposerTitleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    self.reviewComposerTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.reviewComposerTitleLabel.text = kLang(@"service_review_composer_title");

    self.reviewComposerSubtitleLabel = [[UILabel alloc] init];
    self.reviewComposerSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.reviewComposerSubtitleLabel.font = [GM MidFontWithSize:13];
    self.reviewComposerSubtitleLabel.numberOfLines = 0;
    self.reviewComposerSubtitleLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.66];
    self.reviewComposerSubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.reviewComposerSubtitleLabel.text = kLang(@"service_review_composer_subtitle");

    self.reviewStarsStackView = [[UIStackView alloc] init];
    self.reviewStarsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.reviewStarsStackView.axis = UILayoutConstraintAxisHorizontal;
    self.reviewStarsStackView.alignment = UIStackViewAlignmentCenter;
    self.reviewStarsStackView.distribution = UIStackViewDistributionFillEqually;
    self.reviewStarsStackView.spacing = 6.0;
    self.reviewStarsStackView.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    self.reviewStarButtons = [NSMutableArray arrayWithCapacity:5];

    for (NSInteger idx = 1; idx <= 5; idx++) {
        UIButton *starButton = [UIButton buttonWithType:UIButtonTypeSystem];
        starButton.translatesAutoresizingMaskIntoConstraints = NO;
        starButton.tag = idx;
        starButton.tintColor = [[UIColor colorWithRed:0.95 green:0.63 blue:0.20 alpha:1.0] colorWithAlphaComponent:0.42];
        starButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.52];
        starButton.layer.cornerRadius = 17.0;
        starButton.layer.borderWidth = 1.0;
        [starButton pp_setBorderColor:[[UIColor colorWithRed:0.95 green:0.63 blue:0.20 alpha:1.0] colorWithAlphaComponent:0.14]];
        if (@available(iOS 13.0, *)) {
            starButton.layer.cornerCurve = kCACornerCurveContinuous;
        }
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
        [starButton setPreferredSymbolConfiguration:cfg forImageInState:UIControlStateNormal];
        [starButton setImage:[UIImage systemImageNamed:@"star.fill"] forState:UIControlStateNormal];
        [starButton addTarget:self action:@selector(reviewStarTapped:) forControlEvents:UIControlEventTouchUpInside];
        [NSLayoutConstraint activateConstraints:@[
            [starButton.heightAnchor constraintEqualToConstant:34.0]
        ]];
        [self.reviewStarsStackView addArrangedSubview:starButton];
        [self.reviewStarButtons addObject:starButton];
    }

    self.reviewPlaceholderText = kLang(@"service_review_placeholder");
    self.reviewTextView = [[UITextView alloc] init];
    self.reviewTextView.translatesAutoresizingMaskIntoConstraints = NO;
    self.reviewTextView.delegate = self;
    self.reviewTextView.font = [GM MidFontWithSize:14];
    self.reviewTextView.textAlignment = Language.alignmentForCurrentLanguage;
    self.reviewTextView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.58];
    self.reviewTextView.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.46];
    self.reviewTextView.text = self.reviewPlaceholderText;
    self.reviewTextView.textContainerInset = UIEdgeInsetsMake(10.0, 12.0, 10.0, 12.0);
    self.reviewTextView.layer.cornerRadius = 16.0;
    self.reviewTextView.layer.borderWidth = 1.0;
    [self.reviewTextView pp_setBorderColor:[AppPrimaryTextClr ?: UIColor.labelColor colorWithAlphaComponent:0.08]];
    if (@available(iOS 13.0, *)) {
        self.reviewTextView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    self.submitReviewButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.submitReviewButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.submitReviewButton.titleLabel.font = [GM boldFontWithSize:14];
    self.submitReviewButton.layer.cornerRadius = 18.0;
    self.submitReviewButton.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.submitReviewButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.submitReviewButton setTitle:kLang(@"service_review_submit") forState:UIControlStateNormal];
    [self.submitReviewButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.submitReviewButton.backgroundColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    [self.submitReviewButton addTarget:self action:@selector(submitReviewTapped) forControlEvents:UIControlEventTouchUpInside];

    [view addSubview:self.reviewComposerTitleLabel];
    [view addSubview:self.reviewComposerSubtitleLabel];
    [view addSubview:self.reviewStarsStackView];
    [view addSubview:self.reviewTextView];
    [view addSubview:self.submitReviewButton];

    self.reviewStarsTopConstraint =
        [self.reviewStarsStackView.topAnchor constraintEqualToAnchor:self.reviewComposerSubtitleLabel.bottomAnchor constant:14.0];
    self.reviewTextTopConstraint =
        [self.reviewTextView.topAnchor constraintEqualToAnchor:self.reviewStarsStackView.bottomAnchor constant:12.0];
    self.reviewTextMinHeightConstraint =
        [self.reviewTextView.heightAnchor constraintGreaterThanOrEqualToConstant:82.0];
    self.submitReviewTopConstraint =
        [self.submitReviewButton.topAnchor constraintEqualToAnchor:self.reviewTextView.bottomAnchor constant:12.0];
    self.submitReviewHeightConstraint =
        [self.submitReviewButton.heightAnchor constraintEqualToConstant:44.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.reviewComposerTitleLabel.topAnchor constraintEqualToAnchor:view.topAnchor constant:16.0],
        [self.reviewComposerTitleLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:16.0],
        [self.reviewComposerTitleLabel.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-16.0],

        [self.reviewComposerSubtitleLabel.topAnchor constraintEqualToAnchor:self.reviewComposerTitleLabel.bottomAnchor constant:5.0],
        [self.reviewComposerSubtitleLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:16.0],
        [self.reviewComposerSubtitleLabel.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-16.0],

        self.reviewStarsTopConstraint,
        [self.reviewStarsStackView.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:16.0],
        [self.reviewStarsStackView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-16.0],

        self.reviewTextTopConstraint,
        [self.reviewTextView.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:16.0],
        [self.reviewTextView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-16.0],
        self.reviewTextMinHeightConstraint,

        self.submitReviewTopConstraint,
        [self.submitReviewButton.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:16.0],
        [self.submitReviewButton.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-16.0],
        self.submitReviewHeightConstraint,
        [self.submitReviewButton.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-16.0]
    ]];

    [self pp_updateReviewStars];
    return view;
}

- (UIView *)pp_reviewViewForDictionary:(NSDictionary<NSString *, id> *)review {
    UIView *view = [[UIView alloc] init];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.backgroundColor = [AppPrimaryTextClr ?: UIColor.labelColor colorWithAlphaComponent:0.035];
    view.layer.cornerRadius = 18.0;
    view.layer.borderWidth = 1.0;
    [view pp_setBorderColor:[AppPrimaryTextClr ?: UIColor.labelColor colorWithAlphaComponent:0.06]];
    if (@available(iOS 13.0, *)) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.font = [GM boldFontWithSize:14];
    nameLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    nameLabel.textAlignment = Language.alignmentForCurrentLanguage;
    nameLabel.text = [self pp_reviewStringFromDictionary:review keys:@[@"reviewerName", @"userName", @"name", @"displayName"]] ?: kLang(@"service_view_review_anonymous");

    UILabel *ratingLabel = [[UILabel alloc] init];
    ratingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    ratingLabel.font = [GM boldFontWithSize:13];
    ratingLabel.textColor = [UIColor colorWithRed:0.72 green:0.46 blue:0.08 alpha:1.0];
    ratingLabel.textAlignment = Language.alignmentForCurrentLanguage;
    NSNumber *rating = [self pp_reviewNumberFromDictionary:review keys:@[@"rating", @"ratingValue", @"averageRating"]];
    ratingLabel.text = rating.doubleValue > 0.0 ? [NSString stringWithFormat:@"★ %.1f", rating.doubleValue] : @"";

    UILabel *commentLabel = [[UILabel alloc] init];
    commentLabel.translatesAutoresizingMaskIntoConstraints = NO;
    commentLabel.font = [GM MidFontWithSize:14];
    commentLabel.numberOfLines = 0;
    commentLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.78];
    commentLabel.textAlignment = Language.alignmentForCurrentLanguage;
    commentLabel.text = [self pp_reviewStringFromDictionary:review keys:@[@"comment", @"text", @"review", @"commentText"]] ?: kLang(@"service_view_review_comment_empty");

    UILabel *dateLabel = [[UILabel alloc] init];
    dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    dateLabel.font = [GM MidFontWithSize:12];
    dateLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.52];
    dateLabel.textAlignment = Language.alignmentForCurrentLanguage;
    NSDate *date = [self pp_reviewDateFromValue:review[@"createdAt"] ?: review[@"date"] ?: review[@"timestamp"]];
    dateLabel.text = date ? [GM formattedDate:date] : @"";

    [view addSubview:nameLabel];
    [view addSubview:ratingLabel];
    [view addSubview:commentLabel];
    [view addSubview:dateLabel];

    [NSLayoutConstraint activateConstraints:@[
        [nameLabel.topAnchor constraintEqualToAnchor:view.topAnchor constant:14.0],
        [nameLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:14.0],
        [nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:ratingLabel.leadingAnchor constant:-10.0],

        [ratingLabel.topAnchor constraintEqualToAnchor:view.topAnchor constant:14.0],
        [ratingLabel.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-14.0],

        [commentLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:8.0],
        [commentLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:14.0],
        [commentLabel.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-14.0],

        [dateLabel.topAnchor constraintEqualToAnchor:commentLabel.bottomAnchor constant:8.0],
        [dateLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:14.0],
        [dateLabel.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-14.0],
        [dateLabel.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-14.0]
    ]];

    return view;
}

- (nullable NSString *)pp_reviewStringFromDictionary:(NSDictionary<NSString *, id> *)dict keys:(NSArray<NSString *> *)keys {
    for (NSString *key in keys) {
        id value = dict[key];
        if ([value isKindOfClass:NSString.class] && [(NSString *)value length] > 0) {
            return value;
        }
    }
    return nil;
}

- (nullable NSNumber *)pp_reviewNumberFromDictionary:(NSDictionary<NSString *, id> *)dict keys:(NSArray<NSString *> *)keys {
    for (NSString *key in keys) {
        id value = dict[key];
        if ([value isKindOfClass:NSNumber.class]) {
            return value;
        }
        if ([value isKindOfClass:NSString.class] && [(NSString *)value length] > 0) {
            return @([(NSString *)value doubleValue]);
        }
    }
    return nil;
}

- (nullable NSDate *)pp_reviewDateFromValue:(id)value {
    if (!value || [value isKindOfClass:NSNull.class]) return nil;
    if ([value isKindOfClass:NSDate.class]) return value;
    if ([value respondsToSelector:@selector(dateValue)]) return [value dateValue];
    return nil;
}

- (UIButton *)pp_actionTileButtonWithSymbol:(NSString *)symbol
                                      title:(NSString *)title
                                       tint:(UIColor *)tintColor
                                    selector:(SEL)selector {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [tintColor colorWithAlphaComponent:0.12];
    button.layer.cornerRadius = 24.0;
    button.layer.borderWidth = 1.0;
    [button pp_setBorderColor:[tintColor colorWithAlphaComponent:0.18]];
    [button pp_setShadowColor:UIColor.blackColor];
    button.layer.shadowOpacity = 0.04f;
    button.layer.shadowRadius = 10.0f;
    button.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIView *iconShell = [[UIView alloc] init];
    iconShell.translatesAutoresizingMaskIntoConstraints = NO;
    iconShell.userInteractionEnabled = NO;
    iconShell.backgroundColor = [tintColor colorWithAlphaComponent:0.18];
    iconShell.layer.cornerRadius = 18.0;
    if (@available(iOS 13.0, *)) {
        iconShell.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.userInteractionEnabled = NO;
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    iconView.image = [[UIImage systemImageNamed:symbol] imageByApplyingSymbolConfiguration:configuration];
    iconView.tintColor = tintColor;
    iconView.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.userInteractionEnabled = NO;
    titleLabel.text = title;
    titleLabel.font = [GM boldFontWithSize:13];
    titleLabel.numberOfLines = 2;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[iconShell, titleLabel]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.userInteractionEnabled = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10.0;
    stack.alignment = UIStackViewAlignmentCenter;

    [button addSubview:stack];
    [iconShell addSubview:iconView];

    [NSLayoutConstraint activateConstraints:@[
        [button.heightAnchor constraintEqualToConstant:104.0],

        [iconShell.widthAnchor constraintEqualToConstant:36.0],
        [iconShell.heightAnchor constraintEqualToConstant:36.0],
        [iconView.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:16.0],
        [iconView.heightAnchor constraintEqualToConstant:16.0],

        [stack.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:button.leadingAnchor constant:8.0],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:button.trailingAnchor constant:-8.0]
    ]];

    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    return button;
}

#pragma mark - Reporting

- (void)reportAdBTN {
    if (![UserManager sharedManager].isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    if ([self pp_isOwnedByCurrentUser]) {
        return;
    }

    UIAlertController *sheet = [UIAlertController
        alertControllerWithTitle:kLang(@"report_alert_title")
                         message:kLang(@"report_alert_message")
                  preferredStyle:UIAlertControllerStyleActionSheet];

    NSDictionary *reasons = @{
        @"spam": kLang(@"report_reason_spam"),
        @"inappropriate_content": kLang(@"report_reason_inappropriate"),
        @"scam_fraud": kLang(@"report_reason_fraud"),
        @"wrong_category": kLang(@"report_reason_wrong_category"),
        @"other": kLang(@"report_reason_other")
    };

    for (NSString *code in @[@"inappropriate_content", @"scam_fraud", @"wrong_category", @"spam", @"other"]) {
        [sheet addAction:[UIAlertAction actionWithTitle:reasons[code]
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction * _Nonnull action) {
            [self submitServiceReportWithReasonCode:code];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = self.reportActionButton ?: self.view;
        sheet.popoverPresentationController.sourceRect = self.reportActionButton
            ? self.reportActionButton.bounds
            : CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1.0, 1.0);
        sheet.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)submitServiceReportWithReasonCode:(NSString *)reasonCode {
    NSString *uid = [self trackingUserID];
    if (uid.length == 0 || self.service.serviceID.length == 0) {
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *contentRef = [[db collectionWithPath:@"serviceOffers"]
                                        documentWithPath:self.service.serviceID];

    [contentRef updateData:@{
        @"reportedBy": [FIRFieldValue fieldValueForArrayUnion:@[uid]],
        @"reportCount": [FIRFieldValue fieldValueForIntegerIncrement:1],
        @"lastReportedAt": [FIRFieldValue fieldValueForServerTimestamp]
    } completion:nil];

    NSString *reportID = [NSString stringWithFormat:@"%@_%@", self.service.serviceID, uid];
    FIRDocumentReference *reportRef = [[db collectionWithPath:@"reports"] documentWithPath:reportID];

    NSDictionary *reportData = @{
        @"reportId": reportID,
        @"contentId": self.service.serviceID,
        @"contentType": @"serviceOffer",
        @"collection": @"serviceOffers",
        @"reason": reasonCode,
        @"reporterUid": uid,
        @"reportedOwnerUid": self.service.serviceOwnerID ?: @"",
        @"status": @"pending",
        @"platform": @"ios",
        @"createdAt": [FIRFieldValue fieldValueForServerTimestamp],
        @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
    };

    [reportRef setData:reportData merge:YES completion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [PPAlertHelper showInfoIn:self
                                    title:kLang(@"error")
                                 subtitle:kLang(@"report_submit_failed_message")];
            } else {
                [PPAlertHelper showSuccessIn:self
                                       title:kLang(@"report_submit_title")
                                    subtitle:kLang(@"report_submit_message")];
            }
        });
    }];
}

@end
