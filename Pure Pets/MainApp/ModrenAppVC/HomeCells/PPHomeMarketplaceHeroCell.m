//
//  PPHomeMarketplaceHeroCell.m
//  Pure Pets
//

#import "PPHomeMarketplaceHeroCell.h"
#import "MainKindsModel.h"
#import "PetCareHelpers.h"
#import "PPBackgroundView.h"
#import "PPImageLoaderManager.h"
#import "PPMarketplaceHeroCardStyle.h"
#import "PPHomePresentationTokens.h"
#import "AppClasses.h"

#if __has_include(<Lottie/Lottie.h>)
#import <Lottie/Lottie.h>
#elif __has_include("Lottie.h")
#import "Lottie.h"
#elif __has_include(<lottie-ios_Oc/Lottie.h>)
#import <lottie-ios_Oc/Lottie.h>
#elif __has_include(<lottie_ios_Oc/Lottie.h>)
#import <lottie_ios_Oc/Lottie.h>
#endif

static NSString * const PPHomeMarketplaceHeroFloatMotionKey = @"pp.home.marketplaceHero.float";
static NSString * const PPHomeMarketplaceHeroHaloBreathKey = @"pp.home.marketplaceHero.haloBreath";
static NSString * const PPHomeMarketplaceHeroTapHaloAnimationKey = @"pp.marketplaceHero.tapHalo";
static NSString * const PPHomeMarketplaceHeroPlateBreathKey = @"pp.home.marketplaceHero.plateBreath";
static NSString * const PPHomeMarketplaceHeroPrimaryTileFloatKey = @"pp.home.marketplaceHero.primaryTileFloat";
static NSString * const PPHomeMarketplaceHeroSecondaryTileFloatKey = @"pp.home.marketplaceHero.secondaryTileFloat";
static CGFloat const PPHomeMarketplaceHeroAllArtworkSide = 52.0;
static CGFloat const PPHomeMarketplaceHeroCategoryArtworkSide = 66.0;

static UIColor *PPMarketHeroColor(uint32_t hex, CGFloat alpha)
{
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >>  8) & 0xFF) / 255.0
                            blue:((hex      ) & 0xFF) / 255.0
                           alpha:alpha];
}

static UIColor *PPMarketHeroAccentColor(void)
{
    return AppPrimaryClr ?: [GM appPrimaryColor] ?: PPMarketHeroColor(0xC93052, 1.0);
}

static UIColor *PPMarketHeroShineColor(void)
{
    return AppPrimaryClrShiner ?: [GM AppPrimaryColorShainer] ?: PPMarketHeroColor(0xF43F6A, 1.0);
}

static UIColor *PPMarketHeroDisplayAccentColor(UIColor *accentColor,
                                               UITraitCollection *traitCollection)
{
    UIColor *sourceAccent = accentColor ?: PPMarketHeroAccentColor();
    UIColor *resolvedAccent = PPMarketplaceHeroCardResolvedColor(sourceAccent, traitCollection);
    return resolvedAccent ?: sourceAccent;
}

static UIColor *PPMarketHeroCTAEndColor(UIColor *accentColor,
                                        UITraitCollection *traitCollection,
                                        BOOL useBrandFamily)
{
    UIColor *resolvedAccent = PPMarketplaceHeroCardResolvedColor(accentColor ?: PPMarketHeroAccentColor(),
                                                                 traitCollection);
    BOOL darkMode = PPMarketplaceHeroCardIsDark(traitCollection);

    if (useBrandFamily) {
        UIColor *shine = PPMarketplaceHeroCardResolvedColor(PPMarketHeroShineColor(),
                                                            traitCollection);
        return PPMarketplaceHeroCardBlend(resolvedAccent,
                                          shine ?: resolvedAccent,
                                          darkMode ? 0.10 : 0.16,
                                          traitCollection);
    }

    return PPMarketplaceHeroCardBlend(resolvedAccent,
                                      darkMode ? UIColor.whiteColor : UIColor.blackColor,
                                      darkMode ? 0.07 : 0.09,
                                      traitCollection);
}

static UIColor *PPMarketHeroLabelIconColor(void)
{
    if (@available(iOS 13.0, *)) {
        return UIColor.labelColor;
    }
    return PPMarketHeroColor(0x1D2420, 1.0);
}

static UIFont *PPMarketHeroScaledFont(UIFont *font, UIFontTextStyle textStyle)
{
    if (@available(iOS 11.0, *)) {
        return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:font];
    }
    return font;
}

static NSTextAlignment PPMarketHeroTextAlignment(void)
{
    return [Language alignmentForCurrentLanguage];
}

static UISemanticContentAttribute PPMarketHeroSemanticAttribute(void)
{
    return [Language semanticAttributeForCurrentLanguage];
}

static BOOL PPMarketHeroReduceMotion(void)
{
    return UIAccessibilityIsReduceMotionEnabled();
}

@interface PPHomeMarketplaceHeroCell ()

@property (nonatomic, strong) UIControl *surfaceControl;
@property (nonatomic, strong) LOTAnimationView *storefrontLottieView;
@property (nonatomic, strong) PPBackgroundView *heroGlassBackground;
@property (nonatomic, strong) UIStackView *contentStackView;
@property (nonatomic, strong) UIView *eyebrowPillView;
@property (nonatomic, strong) UIImageView *eyebrowIconView;
@property (nonatomic, strong) UILabel *eyebrowLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView *ctaView;
@property (nonatomic, strong) CAGradientLayer *ctaGradientLayer;
@property (nonatomic, strong) CAShapeLayer *ctaGradientMaskLayer;
@property (nonatomic, strong) UILabel *ctaLabel;
@property (nonatomic, strong) UIImageView *ctaIconView;
@property (nonatomic, strong) UIView *visualContainerView;
@property (nonatomic, strong) UIView *visualHaloView;
@property (nonatomic, strong) CAGradientLayer *visualHaloGradientLayer;
@property (nonatomic, strong) UIView *storefrontPlateView;
@property (nonatomic, strong) CAGradientLayer *storefrontGradientLayer;
@property (nonatomic, strong) UIImageView *storefrontIconView;
@property (nonatomic, strong) NSLayoutConstraint *storefrontIconWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *storefrontIconHeightConstraint;
@property (nonatomic, assign) BOOL storefrontLottieLoading;
@property (nonatomic, assign) NSInteger storefrontLottieRequestIdentifier;
@property (nonatomic, strong) UIView *primaryProductTileView;
@property (nonatomic, strong) UIImageView *primaryProductIconView;
@property (nonatomic, strong) UIView *secondaryProductTileView;
@property (nonatomic, strong) UIImageView *secondaryProductIconView;
@property (nonatomic, strong) NSLayoutConstraint *visualWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *visualHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *contentLeadingToVisualConstraint;
@property (nonatomic, strong) NSLayoutConstraint *contentLeadingToSurfaceConstraint;
@property (nonatomic, assign) BOOL visualHiddenForReadableText;
@property (nonatomic, strong, nullable) UIColor *contextAccentColor;
@property (nonatomic, copy) NSString *currentContextIdentifier;
@property (nonatomic, copy, nullable) NSString *currentArtworkImageURL;
@property (nonatomic, strong) CAGradientLayer *tapHaloLayer;
@property (nonatomic, assign) BOOL isPressing;

- (void)pp_applyArtworkSizingForAllContext:(BOOL)isAll
                                  animated:(BOOL)animated;

@end

@implementation PPHomeMarketplaceHeroCell

+ (NSString *)reuseIdentifier
{
    return @"PPHomeMarketplaceHeroCell";
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    [self pp_buildInterface];
    [self configureDefaultContent];
    [self refreshThemeAppearance];
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.storefrontLottieRequestIdentifier += 1;
    self.storefrontLottieLoading = NO;
    [self.storefrontLottieView stop];
    [self pp_stopAmbientMotion];
    [[PPImageLoaderManager shared] cancelImageLoadForImageView:self.storefrontIconView];
    self.currentArtworkImageURL = nil;
    self.onTap = nil;
    self.alpha = 1.0;
    self.transform = CGAffineTransformIdentity;
    self.contentView.alpha = 1.0;
    self.contentView.transform = CGAffineTransformIdentity;
    self.surfaceControl.alpha = 1.0;
    self.surfaceControl.transform = CGAffineTransformIdentity;
    [self.tapHaloLayer removeAnimationForKey:PPHomeMarketplaceHeroTapHaloAnimationKey];
    self.tapHaloLayer.opacity = 0.0;
    self.isPressing = NO;
    [self configureDefaultContent];
}

- (BOOL)accessibilityActivate
{
    [self pp_handleTap];
    return YES;
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
        [self pp_startAmbientMotionIfNeeded];
        if ([PPSafeString(self.currentContextIdentifier) isEqualToString:@"all"] &&
            self.storefrontLottieView.sceneModel &&
            !self.storefrontLottieView.hidden) {
            [self.storefrontLottieView play];
        }
    } else {
        [self pp_stopAmbientMotion];
        [self.storefrontLottieView stop];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    [self pp_updateAdaptiveLayout];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    CGRect ctaBounds = self.ctaView.bounds;
    BOOL ctaBoundsValid = !CGRectIsEmpty(ctaBounds) &&
                          isfinite((double)CGRectGetWidth(ctaBounds)) &&
                          isfinite((double)CGRectGetHeight(ctaBounds));
    CGFloat ctaRadius = PPHomeControlCornerRadius;
    self.ctaGradientLayer.frame = ctaBoundsValid ? ctaBounds : CGRectZero;
    self.ctaGradientLayer.cornerRadius = ctaRadius;
    if (ctaBoundsValid) {
        CGRect ctaMaskBounds = self.ctaGradientLayer.bounds;
        UIBezierPath *ctaPath = [UIBezierPath bezierPathWithRoundedRect:ctaMaskBounds
                                                            cornerRadius:ctaRadius];
        self.ctaView.layer.cornerRadius = ctaRadius;
        self.ctaView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:ctaBounds
                                                                   cornerRadius:ctaRadius].CGPath;
        self.ctaGradientMaskLayer.frame = ctaMaskBounds;
        self.ctaGradientMaskLayer.path = ctaPath.CGPath;
    } else {
        self.ctaView.layer.shadowPath = nil;
        self.ctaGradientMaskLayer.frame = CGRectZero;
        self.ctaGradientMaskLayer.path = nil;
    }
    CGRect haloBounds = self.visualHaloView.bounds;
    self.visualHaloGradientLayer.frame = (!CGRectIsEmpty(haloBounds) &&
                                          isfinite((double)CGRectGetWidth(haloBounds)) &&
                                          isfinite((double)CGRectGetHeight(haloBounds))) ? haloBounds : CGRectZero;
    CGFloat haloWidth = CGRectGetWidth(haloBounds);
    self.visualHaloGradientLayer.cornerRadius = (isfinite((double)haloWidth) && haloWidth > 0.0) ? haloWidth * 0.5 : 0.0;
    CGRect plateBounds = self.storefrontPlateView.bounds;
    self.storefrontGradientLayer.frame = (!CGRectIsEmpty(plateBounds) &&
                                          isfinite((double)CGRectGetWidth(plateBounds)) &&
                                          isfinite((double)CGRectGetHeight(plateBounds))) ? plateBounds : CGRectZero;
    CGFloat plateRadius = self.storefrontPlateView.layer.cornerRadius;
    self.storefrontGradientLayer.cornerRadius = isfinite((double)plateRadius) ? MAX(0.0, plateRadius) : 0.0;

    CGRect surfaceBounds = self.surfaceControl.bounds;
    self.tapHaloLayer.frame = (!CGRectIsEmpty(surfaceBounds) &&
                               isfinite((double)CGRectGetWidth(surfaceBounds)) &&
                               isfinite((double)CGRectGetHeight(surfaceBounds))) ? surfaceBounds : CGRectZero;
    CGFloat tapHaloDiameter = CGRectGetWidth(surfaceBounds);
    self.tapHaloLayer.cornerRadius = (isfinite((double)tapHaloDiameter) && tapHaloDiameter > 0.0) ? tapHaloDiameter * 0.5 : 0.0;
    [CATransaction commit];

    CGRect surfaceFrame = self.surfaceControl.frame;
    CGFloat surfaceRadius = self.surfaceControl.layer.cornerRadius;
    surfaceRadius = isfinite((double)surfaceRadius) ? MAX(0.0, surfaceRadius) : 0.0;
    if (!CGRectIsEmpty(surfaceFrame) &&
        isfinite((double)CGRectGetMinX(surfaceFrame)) &&
        isfinite((double)CGRectGetMinY(surfaceFrame)) &&
        isfinite((double)CGRectGetWidth(surfaceFrame)) &&
        isfinite((double)CGRectGetHeight(surfaceFrame))) {
        self.contentView.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:surfaceFrame
                                       cornerRadius:surfaceRadius].CGPath;
    } else {
        self.contentView.layer.shadowPath = nil;
    }

    [self pp_startAmbientMotionIfNeeded];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    BOOL contentSizeChanged =
        ![previousTraitCollection.preferredContentSizeCategory isEqualToString:self.traitCollection.preferredContentSizeCategory];
    [self refreshThemeAppearance];
    [self.heroGlassBackground reapplyPalette];
    if (contentSizeChanged) {
        [self pp_updateAdaptiveLayout];
    }
}

- (void)configureDefaultContent
{
    [self configureWithMainKind:nil animated:NO];
}

- (void)configureWithMainKind:(MainKindsModel *)mainKind
                     animated:(BOOL)animated
{
    BOOL isAll = (mainKind == nil || mainKind.ID == -1);
    NSString *contextID = isAll ? @"all" : [NSString stringWithFormat:@"%ld", (long)mainKind.ID];
    BOOL contentChanged = ![PPSafeString(self.currentContextIdentifier) isEqualToString:contextID];
    self.currentContextIdentifier = contextID;
    self.contextAccentColor = isAll ? PPMarketHeroAccentColor() : ([mainKind kindColor] ?: PPMarketHeroAccentColor());

    NSString *kindName = PPSafeString(mainKind.KindName);
    if (kindName.length == 0) {
        kindName = PPSafeString(mainKind.KindNameAr);
    }
    if (kindName.length == 0) {
        kindName = PPSafeString(mainKind.KindNameEn);
    }

    void (^applyContent)(void) = ^{
        [self pp_applyArtworkSizingForAllContext:isAll animated:animated && contentChanged];
        if (isAll) {
            [[PPImageLoaderManager shared] cancelImageLoadForImageView:self.storefrontIconView];
            self.currentArtworkImageURL = nil;
            self.eyebrowLabel.text = kLang(@"home_marketplace_hero_all_eyebrow") ?: kLang(@"home_marketplace_hero_eyebrow_proof") ?: @"";
            self.titleLabel.text = kLang(@"home_marketplace_hero_all_title") ?: kLang(@"home_marketplace_hero_title") ?: @"";
            self.subtitleLabel.text = kLang(@"home_marketplace_hero_all_subtitle") ?: kLang(@"home_marketplace_hero_subtitle") ?: @"";
            self.ctaLabel.text = kLang(@"home_marketplace_hero_all_cta") ?: kLang(@"home_marketplace_hero_cta") ?: @"";
            self.accessibilityLabel = kLang(@"home_marketplace_hero_all_accessibility_label") ?: kLang(@"home_marketplace_hero_accessibility_label") ?: @"";
            self.storefrontIconView.image = [self pp_storefrontFallbackArtwork];
            self.storefrontIconView.alpha = 1.0;
            self.storefrontIconView.hidden = NO;
            self.storefrontLottieView.hidden = (self.storefrontLottieView.sceneModel == nil);
            [self pp_loadShopLottieAnimation];
            self.primaryProductIconView.image = [UIImage pp_symbolNamed:@"bag.fill"
                                                               pointSize:15.0
                                                                  weight:UIImageSymbolWeightBold
                                                                   scale:UIImageSymbolScaleMedium
                                                                 palette:@[self.contextAccentColor ?: PPMarketHeroAccentColor()]
                                                            makeTemplate:YES];
            self.secondaryProductIconView.image = [UIImage pp_symbolNamed:@"shippingbox.fill"
                                                                 pointSize:15.0
                                                                    weight:UIImageSymbolWeightBold
                                                                     scale:UIImageSymbolScaleMedium
                                                                   palette:@[self.contextAccentColor ?: PPMarketHeroAccentColor()]
                                                              makeTemplate:YES];
        } else {
            self.storefrontLottieRequestIdentifier += 1;
            self.storefrontLottieLoading = NO;
            self.storefrontLottieView.hidden = YES;
            [self.storefrontLottieView stop];
            self.storefrontIconView.alpha = 1.0;
            self.storefrontIconView.hidden = NO;
            NSString *eyebrowFormat = kLang(@"home_marketplace_hero_category_eyebrow_format") ?: @"";
            NSString *titleFormat = kLang(@"home_marketplace_hero_category_title_format") ?: @"";
            NSString *subtitleFormat = kLang(@"home_marketplace_hero_category_subtitle_format") ?: @"";
            NSString *ctaFormat = kLang(@"home_marketplace_hero_category_cta_format") ?: @"";
            NSString *accessibilityFormat = kLang(@"home_marketplace_hero_category_accessibility_label_format") ?: @"";

            self.eyebrowLabel.text = eyebrowFormat.length ? [NSString stringWithFormat:eyebrowFormat, kindName] : kindName;
            self.titleLabel.text = titleFormat.length ? [NSString stringWithFormat:titleFormat, kindName] : kindName;
            self.subtitleLabel.text = subtitleFormat.length ? [NSString stringWithFormat:subtitleFormat, kindName] : kindName;
            self.ctaLabel.text = ctaFormat.length ? [NSString stringWithFormat:ctaFormat, kindName] : (kLang(@"home_marketplace_hero_cta") ?: @"");
            self.accessibilityLabel = accessibilityFormat.length ? [NSString stringWithFormat:accessibilityFormat, kindName] : self.titleLabel.text;
            [self pp_configureArtworkForMainKind:mainKind];
            self.primaryProductIconView.image = [UIImage pp_symbolNamed:@"checkmark.seal.fill"
                                                               pointSize:15.0
                                                                  weight:UIImageSymbolWeightBold
                                                                   scale:UIImageSymbolScaleMedium
                                                                 palette:@[self.contextAccentColor ?: PPMarketHeroAccentColor()]
                                                            makeTemplate:YES];
            self.secondaryProductIconView.image = [UIImage pp_symbolNamed:@"sparkles"
                                                                 pointSize:15.0
                                                                    weight:UIImageSymbolWeightBold
                                                                     scale:UIImageSymbolScaleMedium
                                                                   palette:@[self.contextAccentColor ?: PPMarketHeroAccentColor()]
                                                              makeTemplate:YES];
        }
        self.accessibilityHint = kLang(@"home_marketplace_hero_accessibility_hint") ?: @"";
    };

    BOOL shouldAnimate = animated && contentChanged && !PPMarketHeroReduceMotion();

    if (shouldAnimate) {
        [UIView transitionWithView:self.surfaceControl
                          duration:0.28
                           options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                        animations:applyContent
                        completion:nil];
    } else {
        applyContent();
    }

    self.semanticContentAttribute = PPMarketHeroSemanticAttribute();
    self.contentView.semanticContentAttribute = PPMarketHeroSemanticAttribute();
    self.surfaceControl.semanticContentAttribute = PPMarketHeroSemanticAttribute();
    self.contentStackView.semanticContentAttribute = PPMarketHeroSemanticAttribute();
    self.eyebrowPillView.semanticContentAttribute = PPMarketHeroSemanticAttribute();
    self.eyebrowIconView.semanticContentAttribute = PPMarketHeroSemanticAttribute();
    self.eyebrowLabel.semanticContentAttribute = PPMarketHeroSemanticAttribute();
    self.ctaView.semanticContentAttribute = PPMarketHeroSemanticAttribute();
    self.ctaIconView.image = [UIImage pp_symbolNamed:(Language.isRTL ? @"arrow.left" : @"arrow.right")
                                           pointSize:13.0
                                              weight:UIImageSymbolWeightBold
                                               scale:UIImageSymbolScaleMedium
                                             palette:@[UIColor.whiteColor]
                                        makeTemplate:YES];
    self.eyebrowLabel.textAlignment = PPMarketHeroTextAlignment();
    self.titleLabel.textAlignment = PPMarketHeroTextAlignment();
    self.subtitleLabel.textAlignment = PPMarketHeroTextAlignment();
    self.ctaLabel.textAlignment = PPMarketHeroTextAlignment();

    if (shouldAnimate) {
        [self pp_animateThemeTransition];
    } else {
        [self refreshThemeAppearance];
    }
}

- (void)refreshThemeAppearance
{
    UIColor *rawAccent = self.contextAccentColor ?: PPPetCareAccentColor() ?: PPMarketHeroAccentColor();
    BOOL isAllContext = [PPSafeString(self.currentContextIdentifier) isEqualToString:@"all"];
    UIColor *primaryAccent = PPMarketHeroDisplayAccentColor(rawAccent,
                                                            self.traitCollection);
    BOOL darkMode = NO;
    if (@available(iOS 13.0, *)) {
        darkMode = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    UIColor *surfaceBase = PPMarketplaceHeroCardSurfaceBaseColor(self.traitCollection);
    UIColor *textPrimary = PPMarketplaceHeroCardPrimaryTextColor();
    UIColor *textSecondary = PPMarketplaceHeroCardSecondaryTextColor();
    UIColor *stroke = PPMarketplaceHeroCardStrokeColor(self.traitCollection);
    UIColor *eyebrowFill = [primaryAccent colorWithAlphaComponent:darkMode ? 0.22 : 0.17];
    UIColor *ctaEnd = PPMarketHeroCTAEndColor(primaryAccent,
                                             self.traitCollection,
                                             isAllContext);

    self.surfaceControl.backgroundColor = [UIColor clearColor];
    
    
    self.heroGlassBackground.accentColorOverride = isAllContext ? nil : primaryAccent;
    self.contentView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.contentView.layer.shadowOpacity = darkMode ? 0.06f : 0.035f;
    self.contentView.layer.shadowRadius = darkMode ? 10.0f : 8.0f;
    self.contentView.layer.shadowOffset = CGSizeMake(0.0, 4.0);

    self.eyebrowPillView.backgroundColor = eyebrowFill;
    self.eyebrowPillView.layer.borderColor = [primaryAccent colorWithAlphaComponent:darkMode ? 0.30 : 0.24].CGColor;
    self.eyebrowIconView.image = [UIImage pp_symbolNamed:@"storefront.fill"
                                               pointSize:10.5
                                                  weight:UIImageSymbolWeightSemibold
                                                   scale:UIImageSymbolScaleMedium
                                                 palette:@[primaryAccent]
                                            makeTemplate:YES];
    self.eyebrowIconView.tintColor = primaryAccent;
    self.eyebrowLabel.textColor = primaryAccent;

    self.titleLabel.textColor = textPrimary;
    self.subtitleLabel.textColor = textSecondary;
    self.ctaView.backgroundColor = UIColor.clearColor;
    self.ctaGradientLayer.colors = @[(id)primaryAccent.CGColor, (id)ctaEnd.CGColor];
    self.ctaGradientLayer.locations = @[@0.0, @1.0];
    self.ctaGradientLayer.startPoint = Language.isRTL ? CGPointMake(1.0, 0.5) : CGPointMake(0.0, 0.5);
    self.ctaGradientLayer.endPoint = Language.isRTL ? CGPointMake(0.0, 0.5) : CGPointMake(1.0, 0.5);
    self.ctaView.layer.borderWidth = 0.0;
    self.ctaView.layer.borderColor = UIColor.clearColor.CGColor;
    self.ctaView.layer.shadowColor = primaryAccent.CGColor;
    self.ctaView.layer.shadowOpacity = 0.0f;
    self.ctaLabel.textColor = UIColor.whiteColor;
    self.ctaIconView.tintColor = UIColor.whiteColor;

    self.visualHaloGradientLayer.colors = @[
        (id)[primaryAccent colorWithAlphaComponent:darkMode ? 0.10 : 0.06].CGColor,
        (id)[surfaceBase colorWithAlphaComponent:darkMode ? 0.04 : 0.02].CGColor,
        (id)[UIColor.clearColor CGColor]
    ];
    self.visualHaloGradientLayer.locations = @[@0.0, @0.45, @1.0];

    self.tapHaloLayer.colors = @[
        (id)[primaryAccent colorWithAlphaComponent:0.30].CGColor,
        (id)[primaryAccent colorWithAlphaComponent:0.10].CGColor,
        (id)[primaryAccent colorWithAlphaComponent:0.0].CGColor
    ];

    self.storefrontGradientLayer.colors = @[
        (id)[primaryAccent colorWithAlphaComponent:darkMode ? 0.42 : 0.34].CGColor,
        (id)[surfaceBase colorWithAlphaComponent:darkMode ? 0.90 : 0.78].CGColor
    ];
    self.storefrontGradientLayer.startPoint = CGPointMake(0.12, 0.0);
    self.storefrontGradientLayer.endPoint = CGPointMake(0.92, 1.0);
    self.storefrontPlateView.layer.borderColor = stroke.CGColor;
    self.storefrontIconView.tintColor = primaryAccent;

    [self pp_applyProductTile:self.primaryProductTileView
                         icon:self.primaryProductIconView
                       accent:primaryAccent
                         dark:darkMode];
    [self pp_applyProductTile:self.secondaryProductTileView
                         icon:self.secondaryProductIconView
                       accent:primaryAccent
                         dark:darkMode];
}

/// Crossfade-based theme transition: snapshot old CALayer colors,
/// apply new theme, then animate with a matched 280 ms ease-out spring.
- (void)pp_animateThemeTransition
{
    // Snapshot old CALayer color values before update
    NSArray *oldCTAColors = [self.ctaGradientLayer.colors copy];
    NSArray *oldHaloColors = [self.visualHaloGradientLayer.colors copy];
    NSArray *oldTapHaloColors = [self.tapHaloLayer.colors copy];
    NSArray *oldStorefrontColors = [self.storefrontGradientLayer.colors copy];
    CGColorRef oldStrokeColor = self.storefrontPlateView.layer.borderColor;
    CGColorRef oldEyebrowBorder = self.eyebrowPillView.layer.borderColor;

    // Apply the new theme state (sets final layer & view values)
    [self refreshThemeAppearance];

    // Animate CALayer color properties with a crossfade transition
    NSTimeInterval duration = 0.28;
    NSString *timingName = kCAMediaTimingFunctionEaseOut;
    CAMediaTimingFunction *timing = [CAMediaTimingFunction functionWithName:timingName];

    // CTA gradient
    if (oldCTAColors && self.ctaGradientLayer.colors) {
        CABasicAnimation *ctaAnim = [CABasicAnimation animationWithKeyPath:@"colors"];
        ctaAnim.fromValue = oldCTAColors;
        ctaAnim.duration = duration;
        ctaAnim.timingFunction = timing;
        [self.ctaGradientLayer addAnimation:ctaAnim forKey:@"pp_ctaColorTransition"];
    }
    // Visual halo gradient
    if (oldHaloColors && self.visualHaloGradientLayer.colors) {
        CABasicAnimation *haloAnim = [CABasicAnimation animationWithKeyPath:@"colors"];
        haloAnim.fromValue = oldHaloColors;
        haloAnim.duration = duration;
        haloAnim.timingFunction = timing;
        [self.visualHaloGradientLayer addAnimation:haloAnim forKey:@"pp_haloColorTransition"];
    }
    // Tap halo gradient
    if (oldTapHaloColors && self.tapHaloLayer.colors) {
        CABasicAnimation *tapAnim = [CABasicAnimation animationWithKeyPath:@"colors"];
        tapAnim.fromValue = oldTapHaloColors;
        tapAnim.duration = duration;
        tapAnim.timingFunction = timing;
        [self.tapHaloLayer addAnimation:tapAnim forKey:@"pp_tapHaloColorTransition"];
    }
    // Storefront gradient
    if (oldStorefrontColors && self.storefrontGradientLayer.colors) {
        CABasicAnimation *sfAnim = [CABasicAnimation animationWithKeyPath:@"colors"];
        sfAnim.fromValue = oldStorefrontColors;
        sfAnim.duration = duration;
        sfAnim.timingFunction = timing;
        [self.storefrontGradientLayer addAnimation:sfAnim forKey:@"pp_storefrontColorTransition"];
    }
    // Storefront plate border
    if (oldStrokeColor) {
        CABasicAnimation *borderAnim = [CABasicAnimation animationWithKeyPath:@"borderColor"];
        borderAnim.fromValue = (__bridge id)oldStrokeColor;
        borderAnim.duration = duration;
        borderAnim.timingFunction = timing;
        [self.storefrontPlateView.layer addAnimation:borderAnim forKey:@"pp_strokeTransition"];
    }
    // Eyebrow pill border
    if (oldEyebrowBorder) {
        CABasicAnimation *eyeAnim = [CABasicAnimation animationWithKeyPath:@"borderColor"];
        eyeAnim.fromValue = (__bridge id)oldEyebrowBorder;
        eyeAnim.duration = duration;
        eyeAnim.timingFunction = timing;
        [self.eyebrowPillView.layer addAnimation:eyeAnim forKey:@"pp_eyebrowBorderTransition"];
    }

    // Animate UIView tint / backgroundColor properties with a matching spring
    [UIView animateWithDuration:duration
                          delay:0
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        // Force layout to ensure tint propagation
        [self.eyebrowPillView layoutIfNeeded];
        [self.ctaView layoutIfNeeded];
        [self.storefrontPlateView layoutIfNeeded];
    }
                     completion:nil];
}

- (void)pp_loadShopLottieAnimation
{
    if (![PPSafeString(self.currentContextIdentifier) isEqualToString:@"all"]) {
        return;
    }

    if (self.storefrontLottieView.sceneModel) {
        [self pp_showStorefrontLottieIfReady];
        return;
    }

    if (self.storefrontLottieLoading) {
        return;
    }

    self.storefrontLottieLoading = YES;
    NSInteger requestIdentifier = ++self.storefrontLottieRequestIdentifier;

    __weak typeof(self) weakSelf = self;
    [AppClasses setAnimationNamed:@"petstore"
                           ToView:self.storefrontLottieView
                        withSpeed:0.1
                       completion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (requestIdentifier != strongSelf.storefrontLottieRequestIdentifier) {
                return;
            }
            strongSelf.storefrontLottieLoading = NO;
            if (success) {
                [strongSelf pp_showStorefrontLottieIfReady];
            } else {
                [strongSelf pp_showStorefrontFallbackArtwork];
            }
        });
    }];
}

- (UIImage *)pp_storefrontFallbackArtwork
{
    UIColor *accent = self.contextAccentColor ?: PPMarketHeroAccentColor();
    return [UIImage pp_symbolNamed:@"storefront.fill"
                         pointSize:46.0
                            weight:UIImageSymbolWeightSemibold
                             scale:UIImageSymbolScaleLarge
                           palette:@[accent]
                      makeTemplate:YES];
}

- (void)pp_showStorefrontLottieIfReady
{
    if (![PPSafeString(self.currentContextIdentifier) isEqualToString:@"all"] ||
        !self.storefrontLottieView.sceneModel) {
        return;
    }

    self.storefrontIconView.alpha = 1.0;
    self.storefrontLottieView.alpha = 0.98;
    self.storefrontLottieView.hidden = NO;
    self.storefrontIconView.hidden = YES;
    [self.storefrontLottieView play];
}

- (void)pp_showStorefrontFallbackArtwork
{
    if (![PPSafeString(self.currentContextIdentifier) isEqualToString:@"all"]) {
        return;
    }

    [self.storefrontLottieView stop];
    self.storefrontLottieView.hidden = YES;
    self.storefrontLottieView.alpha = 0.98;
    self.storefrontIconView.image = [self pp_storefrontFallbackArtwork];
    self.storefrontIconView.alpha = 1.0;
    self.storefrontIconView.hidden = NO;
}

- (void)pp_configureArtworkForMainKind:(MainKindsModel *)mainKind
{
    [[PPImageLoaderManager shared] cancelImageLoadForImageView:self.storefrontIconView];

    NSString *imageURL = PPSafeString(mainKind.KindImageUrl);
    self.currentArtworkImageURL = imageURL;

    UIImage *placeholder = [self pp_artworkImageForMainKind:mainKind];
    self.storefrontIconView.image = placeholder;
    self.storefrontIconView.tintColor = PPMarketHeroDisplayAccentColor(self.contextAccentColor ?: PPMarketHeroAccentColor(),
                                                                       self.traitCollection);

    if (imageURL.length == 0) {
        return;
    }

    [[PPImageLoaderManager shared] setImageOnImageView:self.storefrontIconView
                                                   url:imageURL
                                           placeholder:placeholder
                                       transitionStyle:PPImageTransitionStyleNone
                                            complation:nil];
}

- (UIImage *)pp_artworkImageForMainKind:(MainKindsModel *)mainKind
{
    UIImage *image = mainKind.KindImageFile;
    if (!image && mainKind.KindImageNamed.length > 0) {
        image = [UIImage imageNamed:mainKind.KindImageNamed];
    }
    if (!image && mainKind.KindIconName.length > 0) {
        image = [UIImage imageNamed:mainKind.KindIconName];
    }
    if (!image && mainKind.KindIconName.length > 0) {
        if (@available(iOS 13.0, *)) {
            image = [UIImage systemImageNamed:mainKind.KindIconName];
        }
    }
    if (!image) {
        if (@available(iOS 13.0, *)) {
            image = [UIImage systemImageNamed:@"pawprint.fill"];
        }
    }
    if (image) {
        return [image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] ?: image;
    }
    return [UIImage pp_symbolNamed:@"pawprint.fill"
                         pointSize:46.0
                            weight:UIImageSymbolWeightSemibold
                             scale:UIImageSymbolScaleLarge
                           palette:@[self.contextAccentColor ?: PPMarketHeroAccentColor()]
                      makeTemplate:YES];
}

#pragma mark - Build

- (void)pp_buildInterface
{
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.clipsToBounds = NO;
    self.clipsToBounds = NO;
    self.contentView.layer.masksToBounds = NO;
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;

    UIControl *surface = [[UIControl alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.backgroundColor = UIColor.clearColor;
    surface.clipsToBounds = YES;
    surface.layer.cornerRadius = PPHomeHeroCornerRadius;
    surface.isAccessibilityElement = NO;
    if (@available(iOS 13.0, *)) {
        surface.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [surface addTarget:self action:@selector(pp_touchDown) forControlEvents:UIControlEventTouchDown];
    [surface addTarget:self action:@selector(pp_touchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [surface addTarget:self action:@selector(pp_handleTap) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:surface];
    self.surfaceControl = surface;

    PPBackgroundView *glass = [PPBackgroundView new];
    glass.translatesAutoresizingMaskIntoConstraints = NO;
    glass.accentStyle = PPHeroGlassAccentStyleCornerGlow;
    glass.cornerGlowOpacityMultiplier = 0.89;
    glass.glowDirection = PPIsRL ? PPHeroGlowDirectionLeftDirect : PPHeroGlowDirectionRightDirection;
    glass.PPHeroApexUseShimmer = NO;
    glass.PPHeroApexUseUnderFingerMotion = NO;
    [surface insertSubview:glass atIndex:0];
    self.heroGlassBackground = glass;

    CAGradientLayer *halo = [CAGradientLayer layer];
    halo.name = @"PPHomeMarketplaceHeroTapHaloLayer";
    halo.startPoint = CGPointMake(0.5, 0.5);
    halo.endPoint = CGPointMake(1.0, 1.0);
    halo.locations = @[@0.0, @0.48, @1.0];
    halo.opacity = 0.0;
    if (@available(iOS 12.0, *)) {
        halo.type = kCAGradientLayerRadial;
    }
    [glass.layer addSublayer:halo];
    self.tapHaloLayer = halo;
    
    [self pp_buildContentStackInSurface:surface];
    [self pp_buildVisualClusterInSurface:surface];

    [NSLayoutConstraint activateConstraints:@[
        [surface.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [surface.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [surface.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [surface.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [glass.topAnchor constraintEqualToAnchor:surface.topAnchor],
        [glass.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor],
        [glass.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor],
        [glass.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor],

        [self.contentStackView.topAnchor constraintGreaterThanOrEqualToAnchor:surface.topAnchor constant:20.0],
        [self.contentStackView.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-20.0],
        [self.contentStackView.centerYAnchor constraintEqualToAnchor:surface.centerYAnchor],
        [self.contentStackView.bottomAnchor constraintLessThanOrEqualToAnchor:surface.bottomAnchor constant:-20.0],

        [self.visualContainerView.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:20.0],
        [self.visualContainerView.centerYAnchor constraintEqualToAnchor:surface.centerYAnchor],
    ]];

    self.visualWidthConstraint = [self.visualContainerView.widthAnchor constraintEqualToConstant:124.0];
    self.visualHeightConstraint = [self.visualContainerView.heightAnchor constraintEqualToConstant:146.0];
    self.contentLeadingToVisualConstraint =
        [self.contentStackView.leadingAnchor constraintEqualToAnchor:self.visualContainerView.trailingAnchor constant:18.0];
    self.contentLeadingToSurfaceConstraint =
        [self.contentStackView.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:20.0];
    self.contentLeadingToVisualConstraint.active = YES;
    self.visualWidthConstraint.active = YES;
    self.visualHeightConstraint.active = YES;
}

- (void)pp_buildContentStackInSurface:(UIView *)surface
{
    UIView *eyebrowPill = [[UIView alloc] init];
    eyebrowPill.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowPill.layer.cornerRadius = 13.0;
    eyebrowPill.layer.borderWidth = 1.0;
    if (@available(iOS 13.0, *)) {
        eyebrowPill.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.eyebrowPillView = eyebrowPill;

    UIImageView *eyebrowIcon =
        [[UIImageView alloc] initWithImage:[UIImage pp_symbolNamed:@"storefront.fill"
                                                         pointSize:10.5
                                                            weight:UIImageSymbolWeightSemibold
                                                             scale:UIImageSymbolScaleMedium
                                                           palette:@[PPMarketHeroAccentColor()]
                                                      makeTemplate:YES]];
    eyebrowIcon.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowIcon.contentMode = UIViewContentModeScaleAspectFit;
    eyebrowIcon.isAccessibilityElement = NO;
    [eyebrowPill addSubview:eyebrowIcon];
    self.eyebrowIconView = eyebrowIcon;

    UILabel *eyebrowLabel = [[UILabel alloc] init];
    eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowLabel.font = PPMarketHeroScaledFont([GM MidFontWithSize:10.5], UIFontTextStyleCaption1);
    eyebrowLabel.adjustsFontForContentSizeCategory = YES;
    eyebrowLabel.adjustsFontSizeToFitWidth = NO;
    eyebrowLabel.numberOfLines = 1;
    eyebrowLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [eyebrowPill addSubview:eyebrowLabel];
    self.eyebrowLabel = eyebrowLabel;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = PPMarketHeroScaledFont([GM boldFontWithSize:24.0], UIFontTextStyleTitle2);
    titleLabel.adjustsFontForContentSizeCategory = YES;
    titleLabel.numberOfLines = 2;
    titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    titleLabel.adjustsFontSizeToFitWidth = NO;
    self.titleLabel = titleLabel;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = PPMarketHeroScaledFont([GM MidFontWithSize:14.0], UIFontTextStyleSubheadline);
    subtitleLabel.adjustsFontForContentSizeCategory = YES;
    subtitleLabel.numberOfLines = 3;
    subtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    subtitleLabel.adjustsFontSizeToFitWidth = NO;
    self.subtitleLabel = subtitleLabel;

    UIView *cta = [[UIView alloc] init];
    cta.translatesAutoresizingMaskIntoConstraints = NO;
    cta.userInteractionEnabled = NO;
    CGFloat ctaRadius = PPHomeControlCornerRadius;
    cta.layer.cornerRadius = ctaRadius;
    cta.layer.borderWidth = 0.0;
    if (@available(iOS 13.0, *)) {
        cta.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.ctaView = cta;

    self.ctaGradientLayer = [CAGradientLayer layer];
    self.ctaGradientLayer.drawsAsynchronously = NO;
    self.ctaGradientLayer.cornerRadius = ctaRadius;
    self.ctaGradientMaskLayer = [CAShapeLayer layer];
    self.ctaGradientMaskLayer.fillColor = UIColor.blackColor.CGColor;
    self.ctaGradientLayer.mask = self.ctaGradientMaskLayer;
    [cta.layer insertSublayer:self.ctaGradientLayer atIndex:0];

    UIView *ctaContainer = [[UIView alloc] init];
    ctaContainer.translatesAutoresizingMaskIntoConstraints = NO;
    ctaContainer.userInteractionEnabled = NO;
    [cta addSubview:ctaContainer];

    UILabel *ctaLabel = [[UILabel alloc] init];
    ctaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    ctaLabel.font = PPMarketHeroScaledFont([GM boldFontWithSize:13.0], UIFontTextStyleCallout);
    ctaLabel.adjustsFontForContentSizeCategory = YES;
    ctaLabel.numberOfLines = 1;
    ctaLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [ctaContainer addSubview:ctaLabel];
    self.ctaLabel = ctaLabel;

    UIImageView *ctaIcon =
        [[UIImageView alloc] initWithImage:[UIImage pp_symbolNamed:(Language.isRTL ? @"arrow.left" : @"arrow.right")
                                                         pointSize:13.0
                                                            weight:UIImageSymbolWeightBold
                                                             scale:UIImageSymbolScaleMedium
                                                           palette:@[UIColor.whiteColor]
                                                      makeTemplate:YES]];
    ctaIcon.translatesAutoresizingMaskIntoConstraints = NO;
    ctaIcon.contentMode = UIViewContentModeScaleAspectFit;
    [ctaContainer addSubview:ctaIcon];
    self.ctaIconView = ctaIcon;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        eyebrowPill,
        titleLabel,
        subtitleLabel,
        cta
    ]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentLeading;
    stack.spacing = PPSpaceSM;
    stack.userInteractionEnabled = NO;
    [stack setCustomSpacing:PPSpaceMD afterView:eyebrowPill];
    [stack setCustomSpacing:PPSpaceSM afterView:titleLabel];
    [stack setCustomSpacing:PPSpaceMD afterView:subtitleLabel];
    [surface addSubview:stack];
    self.contentStackView = stack;

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [subtitleLabel.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [cta.widthAnchor constraintLessThanOrEqualToAnchor:stack.widthAnchor],
        [cta.widthAnchor constraintGreaterThanOrEqualToConstant:136.0],

        [eyebrowPill.heightAnchor constraintGreaterThanOrEqualToConstant:26.0],
        [eyebrowIcon.leadingAnchor constraintEqualToAnchor:eyebrowPill.leadingAnchor constant:10.0],
        [eyebrowIcon.centerYAnchor constraintEqualToAnchor:eyebrowPill.centerYAnchor],
        [eyebrowIcon.widthAnchor constraintEqualToConstant:13.0],
        [eyebrowIcon.heightAnchor constraintEqualToConstant:13.0],

        [eyebrowLabel.leadingAnchor constraintEqualToAnchor:eyebrowIcon.trailingAnchor constant:6.0],
        [eyebrowLabel.trailingAnchor constraintEqualToAnchor:eyebrowPill.trailingAnchor constant:-10.0],
        [eyebrowLabel.topAnchor constraintEqualToAnchor:eyebrowPill.topAnchor constant:5.0],
        [eyebrowLabel.bottomAnchor constraintEqualToAnchor:eyebrowPill.bottomAnchor constant:-5.0],

        [cta.heightAnchor constraintGreaterThanOrEqualToConstant:PPTouchTargetMin],
        [ctaContainer.centerXAnchor constraintEqualToAnchor:cta.centerXAnchor],
        [ctaContainer.centerYAnchor constraintEqualToAnchor:cta.centerYAnchor],
        [ctaContainer.topAnchor constraintEqualToAnchor:cta.topAnchor],
        [ctaContainer.bottomAnchor constraintEqualToAnchor:cta.bottomAnchor],
        [ctaContainer.leadingAnchor constraintGreaterThanOrEqualToAnchor:cta.leadingAnchor],
        [ctaContainer.trailingAnchor constraintLessThanOrEqualToAnchor:cta.trailingAnchor],

        [ctaLabel.leadingAnchor constraintEqualToAnchor:ctaContainer.leadingAnchor constant:PPSpaceMD-2],
        [ctaLabel.centerYAnchor constraintEqualToAnchor:ctaContainer.centerYAnchor],
        [ctaIcon.leadingAnchor constraintEqualToAnchor:ctaLabel.trailingAnchor constant:PPSpaceSM+4],
        [ctaIcon.trailingAnchor constraintEqualToAnchor:ctaContainer.trailingAnchor constant:-PPSpaceMD],
        [ctaIcon.centerYAnchor constraintEqualToAnchor:ctaContainer.centerYAnchor],
        [ctaIcon.widthAnchor constraintEqualToConstant:15.0],
        [ctaIcon.heightAnchor constraintEqualToConstant:15.0],
    ]];
}

- (void)pp_buildVisualClusterInSurface:(UIView *)surface
{
    UIView *visual = [[UIView alloc] init];
    visual.translatesAutoresizingMaskIntoConstraints = NO;
    visual.userInteractionEnabled = NO;
    visual.isAccessibilityElement = NO;
    visual.accessibilityElementsHidden = YES;
    [surface addSubview:visual];
    self.visualContainerView = visual;

    UIView *halo = [[UIView alloc] init];
    halo.translatesAutoresizingMaskIntoConstraints = NO;
    halo.userInteractionEnabled = NO;
    halo.layer.cornerRadius = 62.0;
    halo.clipsToBounds = YES;
    [visual addSubview:halo];
    self.visualHaloView = halo;

    self.visualHaloGradientLayer = [CAGradientLayer layer];
    if (@available(iOS 12.0, *)) {
        self.visualHaloGradientLayer.type = kCAGradientLayerRadial;
        self.visualHaloGradientLayer.startPoint = CGPointMake(0.5, 0.5);
        self.visualHaloGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    }
    [halo.layer insertSublayer:self.visualHaloGradientLayer atIndex:0];
    halo.layer.opacity = 0.42;
    UIView *plate = [[UIView alloc] init];
    plate.translatesAutoresizingMaskIntoConstraints = NO;
    plate.layer.cornerRadius = 32.0;
    plate.layer.borderWidth = 1.0;
    plate.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        plate.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [visual addSubview:plate];
    self.storefrontPlateView = plate;

    self.storefrontGradientLayer = [CAGradientLayer layer];
    [plate.layer insertSublayer:self.storefrontGradientLayer atIndex:0];

    UIImageView *storefrontIcon =
        [[UIImageView alloc] initWithImage:[UIImage pp_symbolNamed:@"storefront.fill"
                                                          pointSize:46.0
                                                             weight:UIImageSymbolWeightSemibold
                                                              scale:UIImageSymbolScaleLarge
                                                            palette:@[PPMarketHeroLabelIconColor()]
                                                       makeTemplate:YES]];
    storefrontIcon.translatesAutoresizingMaskIntoConstraints = NO;
    storefrontIcon.contentMode = UIViewContentModeScaleAspectFit;
    [plate addSubview:storefrontIcon];
    self.storefrontIconView = storefrontIcon;

    LOTAnimationView *storefrontLottie = [[LOTAnimationView alloc] init];
    storefrontLottie.translatesAutoresizingMaskIntoConstraints = NO;
    storefrontLottie.contentMode = UIViewContentModeScaleAspectFit;
    storefrontLottie.loopAnimation = YES;
    storefrontLottie.backgroundColor = UIColor.clearColor;
    storefrontLottie.hidden = YES;
    [plate addSubview:storefrontLottie];
    self.storefrontLottieView = storefrontLottie;

    self.primaryProductTileView = [self pp_makeProductTileWithSymbol:@"bag.fill"];
    self.primaryProductIconView = (UIImageView *)self.primaryProductTileView.subviews.firstObject;
    [visual addSubview:self.primaryProductTileView];

    self.secondaryProductTileView = [self pp_makeProductTileWithSymbol:@"shippingbox.fill"];
    self.secondaryProductIconView = (UIImageView *)self.secondaryProductTileView.subviews.firstObject;
    [visual addSubview:self.secondaryProductTileView];

    self.storefrontIconWidthConstraint = [storefrontIcon.widthAnchor constraintEqualToConstant:PPHomeMarketplaceHeroAllArtworkSide];
    self.storefrontIconHeightConstraint = [storefrontIcon.heightAnchor constraintEqualToConstant:PPHomeMarketplaceHeroAllArtworkSide];

    [NSLayoutConstraint activateConstraints:@[
        [halo.centerXAnchor constraintEqualToAnchor:visual.centerXAnchor],
        [halo.centerYAnchor constraintEqualToAnchor:visual.centerYAnchor],
        [halo.widthAnchor constraintEqualToConstant:118.0],
        [halo.heightAnchor constraintEqualToConstant:124.0],

        [plate.centerXAnchor constraintEqualToAnchor:visual.centerXAnchor],
        [plate.centerYAnchor constraintEqualToAnchor:visual.centerYAnchor constant:-2.0],
        [plate.widthAnchor constraintEqualToConstant:100.0],
        [plate.heightAnchor constraintEqualToConstant:100.0],

        [storefrontIcon.centerXAnchor constraintEqualToAnchor:plate.centerXAnchor],
        [storefrontIcon.centerYAnchor constraintEqualToAnchor:plate.centerYAnchor],
        self.storefrontIconWidthConstraint,
        self.storefrontIconHeightConstraint,

        [self.storefrontLottieView.centerXAnchor constraintEqualToAnchor:plate.centerXAnchor],
        [self.storefrontLottieView.centerYAnchor constraintEqualToAnchor:plate.centerYAnchor],
        [self.storefrontLottieView.widthAnchor constraintEqualToAnchor:storefrontIcon.widthAnchor multiplier:1.20],
        [self.storefrontLottieView.heightAnchor constraintEqualToAnchor:storefrontIcon.heightAnchor multiplier:1.20],

        [self.primaryProductTileView.widthAnchor constraintEqualToConstant:44.0],
        [self.primaryProductTileView.heightAnchor constraintEqualToConstant:44.0],
        [self.primaryProductTileView.trailingAnchor constraintEqualToAnchor:visual.trailingAnchor constant:0.0],
        [self.primaryProductTileView.topAnchor constraintEqualToAnchor:visual.topAnchor constant:12.0],

        [self.secondaryProductTileView.widthAnchor constraintEqualToConstant:38.0],
        [self.secondaryProductTileView.heightAnchor constraintEqualToConstant:38.0],
        [self.secondaryProductTileView.leadingAnchor constraintEqualToAnchor:visual.leadingAnchor constant:0.0],
        [self.secondaryProductTileView.bottomAnchor constraintEqualToAnchor:visual.bottomAnchor constant:-14.0],
    ]];
    
}

- (UIView *)pp_makeProductTileWithSymbol:(NSString *)symbolName
{
    UIView *tile = [[UIView alloc] init];
    tile.translatesAutoresizingMaskIntoConstraints = NO;
    tile.layer.cornerRadius = 15.0;
    tile.layer.borderWidth = 1.0;
    tile.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        tile.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIImageView *icon =
        [[UIImageView alloc] initWithImage:[UIImage pp_symbolNamed:symbolName
                                                         pointSize:15.0
                                                            weight:UIImageSymbolWeightBold
                                                             scale:UIImageSymbolScaleMedium
                                                           palette:@[PPMarketHeroAccentColor()]
                                                      makeTemplate:YES]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [tile addSubview:icon];

    [NSLayoutConstraint activateConstraints:@[
        [icon.centerXAnchor constraintEqualToAnchor:tile.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:tile.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:18.0],
        [icon.heightAnchor constraintEqualToConstant:18.0],
    ]];

    return tile;
}

#pragma mark - State

- (void)pp_applyArtworkSizingForAllContext:(BOOL)isAll
                                  animated:(BOOL)animated
{
    if (!self.storefrontIconWidthConstraint || !self.storefrontIconHeightConstraint) {
        return;
    }

    CGFloat targetSide = isAll ? PPHomeMarketplaceHeroAllArtworkSide : PPHomeMarketplaceHeroCategoryArtworkSide;
    if (fabs(self.storefrontIconWidthConstraint.constant - targetSide) < 0.5 &&
        fabs(self.storefrontIconHeightConstraint.constant - targetSide) < 0.5) {
        return;
    }

    void (^updates)(void) = ^{
        self.storefrontIconWidthConstraint.constant = targetSide;
        self.storefrontIconHeightConstraint.constant = targetSide;
        [self.storefrontPlateView layoutIfNeeded];
    };

    if (animated && !PPMarketHeroReduceMotion()) {
        [UIView animateWithDuration:0.22
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseOut
                         animations:updates
                         completion:nil];
    } else {
        updates();
    }
}

- (void)pp_applyProductTile:(UIView *)tile
                       icon:(UIImageView *)icon
                     accent:(UIColor *)accent
                     dark:(BOOL)dark
{
    UIColor *surfaceBase = dark ? [UIColor colorWithWhite:0.18 alpha:0.92] : [UIColor.whiteColor colorWithAlphaComponent:0.86];
    tile.backgroundColor = surfaceBase;
    tile.layer.borderColor = [UIColor.whiteColor colorWithAlphaComponent:dark ? 0.12 : 0.76].CGColor;
    tile.layer.shadowColor = PPMarketHeroColor(0x29312E, 1.0).CGColor;
    tile.layer.shadowOpacity = dark ? 0.18f : 0.075f;
    tile.layer.shadowRadius = 10.0f;
    tile.layer.shadowOffset = CGSizeMake(0.0, 5.0);
    icon.tintColor = accent ?: PPMarketHeroAccentColor();
}

- (void)pp_updateAdaptiveLayout
{
    CGFloat width = CGRectGetWidth(self.bounds);
    BOOL accessibilityCategory =
        UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
    BOOL hideVisual = accessibilityCategory || (width > 0.0 && width < 350.0);

    if (hideVisual == self.visualHiddenForReadableText) {
        return;
    }

    self.visualHiddenForReadableText = hideVisual;
    self.visualContainerView.hidden = hideVisual;
    self.contentLeadingToVisualConstraint.active = !hideVisual;
    self.contentLeadingToSurfaceConstraint.active = hideVisual;
    if (hideVisual) {
        [self pp_stopAmbientMotion];
    } else {
        [self pp_startAmbientMotionIfNeeded];
    }
}

- (void)pp_touchDown
{
    [self pp_applyPressed:YES];
}

- (void)pp_touchUp
{
    [self pp_applyPressed:NO];
}

- (void)pp_applyPressed:(BOOL)pressed
{
    self.isPressing = pressed;
    if (PPMarketHeroReduceMotion()) {
        if (!pressed) {
            self.surfaceControl.alpha = 1.0;
            self.surfaceControl.transform = CGAffineTransformIdentity;
            self.tapHaloLayer.opacity = 0.0;
        } else {
            self.surfaceControl.alpha = 0.94;
        }
        return;
    }

    NSTimeInterval duration = pressed ? 0.10 : 0.22;
    CGFloat damping = pressed ? 1.0 : 0.88;
    CGFloat velocity = pressed ? 0.0 : 0.12;
    void (^updates)(void) = ^{
        self.surfaceControl.transform = pressed ? CGAffineTransformMakeScale(0.985, 0.985) : CGAffineTransformIdentity;
        self.tapHaloLayer.opacity = pressed ? 0.28 : 0.0;
    };

    if (duration <= 0.0) {
        updates();
        return;
    }

    [UIView animateWithDuration:duration
                          delay:0.0
         usingSpringWithDamping:damping
          initialSpringVelocity:velocity
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:updates
                     completion:nil];
}

- (void)pp_handleTap
{
    [self pp_performTapCommitMotion];
    if (self.onTap) {
        self.onTap();
    }
}

- (void)pp_performTapCommitMotion
{
    if (PPMarketHeroReduceMotion() || !self.tapHaloLayer) {
        return;
    }

    [self pp_performHaloBurstMotion];

    [UIView animateKeyframesWithDuration:0.42
                                   delay:0.0
                                 options:UIViewKeyframeAnimationOptionAllowUserInteraction |
                                         UIViewKeyframeAnimationOptionBeginFromCurrentState |
                                         UIViewKeyframeAnimationOptionCalculationModeCubic
                              animations:^{
        [UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:0.32 animations:^{
            self.surfaceControl.transform = CGAffineTransformMakeScale(1.025, 1.025);
        }];
        [UIView addKeyframeWithRelativeStartTime:0.32 relativeDuration:0.68 animations:^{
            self.surfaceControl.transform = CGAffineTransformIdentity;
            self.tapHaloLayer.opacity = 0.0;
        }];
    } completion:nil];
}

- (void)pp_performHaloBurstMotion
{
    [self.tapHaloLayer removeAnimationForKey:PPHomeMarketplaceHeroTapHaloAnimationKey];
    self.tapHaloLayer.opacity = 0.0;

    CAKeyframeAnimation *opacityAnimation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    opacityAnimation.values = @[@0.0, @0.42, @0.0];
    opacityAnimation.keyTimes = @[@0.0, @0.22, @1.0];

    CABasicAnimation *scaleAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnimation.fromValue = @0.72;
    scaleAnimation.toValue = @1.18;

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[opacityAnimation, scaleAnimation];
    group.duration = 0.40;
    group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    group.removedOnCompletion = YES;
    [self.tapHaloLayer addAnimation:group forKey:PPHomeMarketplaceHeroTapHaloAnimationKey];
}

- (void)pp_startAmbientMotionIfNeeded
{
    if (PPMarketHeroReduceMotion()) {
        [self.heroGlassBackground stopAnimations];
        [self pp_stopAmbientMotion];
        return;
    }
    if (!self.window || CGRectIsEmpty(self.bounds)) {
        return;
    }
    [self.heroGlassBackground startAnimations];

    if (self.visualContainerView.hidden || CGRectIsEmpty(self.visualContainerView.bounds)) {
        return;
    }
    if (![self.visualContainerView.layer animationForKey:PPHomeMarketplaceHeroFloatMotionKey]) {
        CABasicAnimation *floatAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
        floatAnimation.fromValue = @0.0;
        floatAnimation.toValue = @(-4.0);
        floatAnimation.duration = 3.8;
        floatAnimation.autoreverses = YES;
        floatAnimation.repeatCount = HUGE_VALF;
        floatAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        floatAnimation.removedOnCompletion = YES;
        [self.visualContainerView.layer addAnimation:floatAnimation forKey:PPHomeMarketplaceHeroFloatMotionKey];
    }

    [self pp_applyBreathingGlowToView:self.visualHaloView
                                  key:PPHomeMarketplaceHeroHaloBreathKey
                            fromAlpha:0.42
                              toAlpha:0.62
                            fromScale:0.97
                              toScale:1.045
                             duration:3.8];
    [self pp_applyBreathingGlowToView:self.storefrontPlateView
                                  key:PPHomeMarketplaceHeroPlateBreathKey
                            fromAlpha:1.0
                              toAlpha:1.0
                            fromScale:0.992
                              toScale:1.018
                             duration:3.4];
    [self pp_applyFloatingMotionToView:self.primaryProductTileView
                                   key:PPHomeMarketplaceHeroPrimaryTileFloatKey
                                 fromY:0.0
                                   toY:-5.0
                              duration:3.15
                                 delay:0.18];
    [self pp_applyFloatingMotionToView:self.secondaryProductTileView
                                   key:PPHomeMarketplaceHeroSecondaryTileFloatKey
                                 fromY:0.0
                                   toY:4.0
                              duration:3.55
                                 delay:0.0];
}

- (void)pp_applyFloatingMotionToView:(UIView *)view
                                  key:(NSString *)key
                                fromY:(CGFloat)fromY
                                  toY:(CGFloat)toY
                             duration:(CFTimeInterval)duration
                                delay:(CFTimeInterval)delay
{
    if (!view || key.length == 0 || [view.layer animationForKey:key]) {
        return;
    }

    CABasicAnimation *floatAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    floatAnimation.fromValue = @(fromY);
    floatAnimation.toValue = @(toY);
    floatAnimation.duration = duration;
    floatAnimation.beginTime = CACurrentMediaTime() + delay;
    floatAnimation.autoreverses = YES;
    floatAnimation.repeatCount = HUGE_VALF;
    floatAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    floatAnimation.removedOnCompletion = YES;
    [view.layer addAnimation:floatAnimation forKey:key];
}

- (void)pp_applyBreathingGlowToView:(UIView *)view
                                key:(NSString *)key
                          fromAlpha:(CGFloat)fromAlpha
                            toAlpha:(CGFloat)toAlpha
                          fromScale:(CGFloat)fromScale
                            toScale:(CGFloat)toScale
                           duration:(CFTimeInterval)duration
{
    if (!view || [view.layer animationForKey:key]) {
        return;
    }

    CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityAnimation.fromValue = @(fromAlpha);
    opacityAnimation.toValue = @(toAlpha);

    CABasicAnimation *scaleAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnimation.fromValue = @(fromScale);
    scaleAnimation.toValue = @(toScale);

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[opacityAnimation, scaleAnimation];
    group.duration = duration;
    group.autoreverses = YES;
    group.repeatCount = HUGE_VALF;
    group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    group.removedOnCompletion = YES;
    [view.layer addAnimation:group forKey:key];
}

- (void)pp_stopAmbientMotion
{
    [self.visualContainerView.layer removeAnimationForKey:PPHomeMarketplaceHeroFloatMotionKey];
    [self.heroGlassBackground stopAnimations];
    [self.visualHaloView.layer removeAnimationForKey:PPHomeMarketplaceHeroHaloBreathKey];
    [self.storefrontPlateView.layer removeAnimationForKey:PPHomeMarketplaceHeroPlateBreathKey];
    [self.primaryProductTileView.layer removeAnimationForKey:PPHomeMarketplaceHeroPrimaryTileFloatKey];
    [self.secondaryProductTileView.layer removeAnimationForKey:PPHomeMarketplaceHeroSecondaryTileFloatKey];
    self.visualContainerView.transform = CGAffineTransformIdentity;
    self.visualHaloView.transform = CGAffineTransformIdentity;
    self.storefrontPlateView.transform = CGAffineTransformIdentity;
    self.primaryProductTileView.transform = CGAffineTransformIdentity;
    self.secondaryProductTileView.transform = CGAffineTransformIdentity;
}



@end
