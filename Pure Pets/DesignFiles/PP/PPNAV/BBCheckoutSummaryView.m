//
//  BBCheckoutSummaryView.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 11/01/2026.
//

#import "BBCheckoutSummaryView.h"
#import "PPChatsFunc.h"
#import "CartManager.h"
#import "PPCartCalculator.h"


@interface BBCheckoutSummaryView () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) UIView *animationContainerView;
@property (nonatomic, copy) void (^onRemovePreviewItem)(CartItem *item);
@property (nonatomic, strong) LOTAnimationView *animationView;
 
@property (nonatomic, strong) UIButton *cardView;
@property (nonatomic, strong) CAGradientLayer *cardGradientLayer;
@property (nonatomic, strong) CAGradientLayer *cardAuraLayer;
@property (nonatomic, strong) CAGradientLayer *cardEdgeLayer;
@property (nonatomic, strong) CALayer *cardBackgroundImageLayer;
@property (nonatomic, strong) UIStackView *pricingStack;
@property (nonatomic, strong) PPInsetLabel *itemsLabel;
@property (nonatomic, strong) PPInsetLabel *itemsValueLabel;
@property (nonatomic, assign) BOOL didRunCardEntranceAnimation;
@property (nonatomic, strong) PPInsetLabel *shippingLabel;
@property (nonatomic, strong) PPInsetLabel *shippingValueLabel;
 
@property (nonatomic, strong) UIView *separator;

@property (nonatomic, strong) UILabel *subtotalAttributedLabel;

@property (nonatomic, strong) UIButton *checkoutBTN;
@property (nonatomic, strong) CAGradientLayer *checkoutButtonGradientLayer;
@property (nonatomic, strong) UIActivityIndicatorView *checkoutFallbackIndicator;
@property (nonatomic, strong) UIImage *checkoutButtonImageForIdle;
@property (nonatomic, assign, getter=isCheckoutLoading) BOOL checkoutLoading;

@property (nonatomic, strong) UICollectionView *itemsPreviewCollection;
@property (nonatomic, strong) NSArray<CartItem *> *previewItems;
@property (nonatomic, assign) BOOL showsItemsPreview;
@property (nonatomic, strong) NSLayoutConstraint *itemsPreviewHeightConstraint;

@property (nonatomic, strong) UIStackView *itemsRow;
@property (nonatomic, strong) UIStackView *shippingRow;
@property (nonatomic, strong) NSLayoutConstraint *pricingStackBottomAnchor;

@property (nonatomic, strong) UIView *trustBannerView;
@property (nonatomic, strong) UILabel *trustBannerLabel;
@property (nonatomic, strong) CAGradientLayer *trustBannerAmbientLayer;
@property (nonatomic, strong) CAGradientLayer *trustBannerShimmerLayer;
@property (nonatomic, assign) BOOL wantsTrustBannerShimmer;
@property (nonatomic, assign) BOOL liveEffectsRunning;
@end

@implementation BBCheckoutSummaryView

static NSString *PPCheckoutDecimalSeparatorFromFormattedPrice(NSString *formattedPrice) {
    if (formattedPrice.length == 0) return @".";
    if ([formattedPrice rangeOfString:@"٫"].location != NSNotFound) return @"٫";
    if ([formattedPrice rangeOfString:@"."].location != NSNotFound) return @".";
    return [NSLocale currentLocale].decimalSeparator ?: @".";
}

static CGFloat PPCheckoutCardCornerRadius(void) {
    return 28.0;
}

static CGFloat PPCheckoutButtonCornerRadius(void) {
    return 22.0;
}

static BOOL PPCheckoutShouldAnimate(void) {
    return !UIAccessibilityIsReduceMotionEnabled();
}

static UIColor *PPCheckoutDynamicColor(UIColor *lightColor, UIColor *darkColor) {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
        }];
    }
    return lightColor;
}

static UIColor *PPCheckoutSoftSurfaceColor(void) {
    UIColor *light = [AppForgroundColr colorWithAlphaComponent:0.94] ?: [UIColor whiteColor];
    UIColor *dark = [[UIColor colorWithWhite:0.10 alpha:1.0] colorWithAlphaComponent:0.94];
    return PPCheckoutDynamicColor(light, dark);
}

static UIColor *PPCheckoutSoftStrokeColor(void) {
    return PPCheckoutDynamicColor([UIColor.labelColor colorWithAlphaComponent:0.08],
                                  [UIColor.whiteColor colorWithAlphaComponent:0.10]);
}

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.didRunCardEntranceAnimation = NO;
        self.wantsTrustBannerShimmer = NO;
        self.liveEffectsRunning = NO;
        [self buildUI];
        [self buildLayout];
        [self updateTotalsWithItems:0 shipping:0 showTitle:YES];
        self.previewItems = @[];
        self.showsItemsPreview = NO;
        // --- Cart observer for preview sync
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(pp_cartDidUpdate)
         name:kCartUpdatedNotification
         object:nil];
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(pp_accessibilityMotionDidChange)
         name:UIAccessibilityReduceMotionStatusDidChangeNotification
         object:nil];
    }
    return self;
}


// --- Cart observer handler for syncing preview items with cart ---
- (void)pp_cartDidUpdate
{
    NSArray<CartItem *> *items =
        [CartManager sharedManager].cartItems;

    self.previewItems = items ?: @[];

    PPCartSummary *summary = [PPCartCalculator currentSummary];
    [self updateTotalsWithItems:summary.subtotal shipping:summary.shippingFee showTitle:self.showDetails];

    BOOL shouldShowPreview =
        self.showsItemsPreview && self.previewItems.count > 0;

    self.itemsPreviewCollection.hidden = !shouldShowPreview;
    self.itemsPreviewCollection.alpha = shouldShowPreview ? 1.0 : 0.0;
    self.itemsPreviewCollection.transform = shouldShowPreview ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0.0, 10.0);
    self.itemsRow.hidden = shouldShowPreview;
    self.shippingRow.hidden = shouldShowPreview;
    self.itemsRow.alpha = shouldShowPreview ? 0.0 : 1.0;
    self.shippingRow.alpha = shouldShowPreview ? 0.0 : 1.0;
    self.itemsRow.transform = CGAffineTransformIdentity;
    self.shippingRow.transform = CGAffineTransformIdentity;

    [self.itemsPreviewCollection reloadData];
}

- (void)pp_accessibilityMotionDidChange
{
    if (PPCheckoutShouldAnimate()) {
        self.animationView.loopAnimation = YES;
        [self.animationView play];
        [self pp_startLivingEffectsIfNeeded];
        if (self.wantsTrustBannerShimmer) {
            [self pp_startTrustBannerShimmer];
        }
    } else {
        self.animationView.loopAnimation = NO;
        [self.animationView stop];
        [self pp_stopLivingEffects];
        [self pp_removeTrustBannerShimmerAnimation];
        self.cardView.transform = CGAffineTransformIdentity;
        self.checkoutBTN.transform = CGAffineTransformIdentity;
    }
}

// --- Remove observer on dealloc ---
- (void)dealloc
{
    [self pp_stopLivingEffects];
    [self pp_removeTrustBannerShimmerAnimation];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)skipCardEntranceAnimation
{
    self.didRunCardEntranceAnimation = YES;
    self.cardView.alpha = 1.0;
    self.cardView.transform = CGAffineTransformIdentity;
}

-(void)layoutSubviews
{
    [super layoutSubviews];

    self.userInteractionEnabled = YES;
    self.cardView.userInteractionEnabled = YES;
    self.checkoutBTN.userInteractionEnabled = !self.isCheckoutLoading;

    [self.cardView bringSubviewToFront:self.pricingStack];

    self.cardAuraLayer.frame = CGRectInset(self.cardView.bounds, -18.0, -12.0);
    self.cardAuraLayer.cornerRadius = self.cardView.layer.cornerRadius + 18.0;
    self.cardGradientLayer.frame = self.cardView.bounds;
    self.cardGradientLayer.cornerRadius = self.cardView.layer.cornerRadius;
    self.cardEdgeLayer.frame = self.cardView.bounds;
    self.cardEdgeLayer.cornerRadius = self.cardView.layer.cornerRadius;
    self.cardBackgroundImageLayer.frame = self.cardView.bounds;
    self.cardBackgroundImageLayer.cornerRadius = self.cardView.layer.cornerRadius;
    self.cardView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.cardView.bounds
                                  cornerRadius:self.cardView.layer.cornerRadius].CGPath;
    self.checkoutButtonGradientLayer.frame = self.checkoutBTN.bounds;
    self.checkoutButtonGradientLayer.cornerRadius = self.checkoutBTN.layer.cornerRadius;
    self.checkoutBTN.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.checkoutBTN.bounds
                                  cornerRadius:self.checkoutBTN.layer.cornerRadius].CGPath;

    if (self.trustBannerShimmerLayer) {
        self.trustBannerShimmerLayer.frame = self.trustBannerView.bounds;
    }
    self.trustBannerAmbientLayer.frame = self.trustBannerView.bounds;
    self.trustBannerAmbientLayer.cornerRadius = self.trustBannerView.layer.cornerRadius;

    if (!self.didRunCardEntranceAnimation &&
        self.cardView.bounds.size.height > 0) {

        self.didRunCardEntranceAnimation = YES;

        [self pp_runCardEntranceAnimationIfNeeded];
    }
    [self bringSubviewToFront:self.animationContainerView];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];

    if (self.window) {
        [self pp_startLivingEffectsIfNeeded];
        if (self.wantsTrustBannerShimmer) {
            [self pp_startTrustBannerShimmer];
        }
    } else {
        [self pp_stopLivingEffects];
        [self pp_removeTrustBannerShimmerAnimation];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];

    if (@available(iOS 13.0, *)) {
        if (![self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            return;
        }
    }

    [self pp_refreshAdaptiveColors];
}

- (void)pp_refreshAdaptiveColors
{
    self.cardView.backgroundColor = PPCheckoutSoftSurfaceColor();
    [self.cardView pp_setBorderColor:PPCheckoutSoftStrokeColor()];
    [self.itemsRow pp_setBorderColor:PPCheckoutSoftStrokeColor()];
    [self.shippingRow pp_setBorderColor:PPCheckoutSoftStrokeColor()];
    self.itemsRow.backgroundColor = PPCheckoutDynamicColor([UIColor.labelColor colorWithAlphaComponent:0.035],
                                                           [UIColor.whiteColor colorWithAlphaComponent:0.045]);
    self.shippingRow.backgroundColor = self.itemsRow.backgroundColor;

    for (UICollectionViewCell *cell in self.itemsPreviewCollection.visibleCells) {
        cell.contentView.backgroundColor = PPCheckoutDynamicColor([UIColor.labelColor colorWithAlphaComponent:0.035],
                                                                  [UIColor.whiteColor colorWithAlphaComponent:0.045]);
        [cell.contentView pp_setBorderColor:PPCheckoutSoftStrokeColor()];
    }
}




#pragma mark - Trust Banner Animation

- (void)pp_startTrustBannerShimmer {
    self.wantsTrustBannerShimmer = YES;
    if (!self.trustBannerView) return;

    if (!self.trustBannerAmbientLayer) {
        CAGradientLayer *ambient = [CAGradientLayer layer];
        ambient.startPoint = CGPointMake(0.0, 0.0);
        ambient.endPoint = CGPointMake(1.0, 1.0);
        ambient.colors = @[
            (id)[[UIColor hx_colorWithHexStr:@"#FABB00" alpha:0.13] CGColor],
            (id)[[UIColor hx_colorWithHexStr:@"#FFFFFF" alpha:0.10] CGColor],
            (id)[[UIColor hx_colorWithHexStr:@"#FABB00" alpha:0.06] CGColor]
        ];
        ambient.locations = @[@0.0, @0.46, @1.0];
        ambient.cornerRadius = self.trustBannerView.layer.cornerRadius;
        ambient.masksToBounds = YES;
        [self.trustBannerView.layer insertSublayer:ambient atIndex:0];
        self.trustBannerAmbientLayer = ambient;
    }

    [self.trustBannerView setBackgroundColor:[UIColor hx_colorWithHexStr:@"#FABB00" alpha:0.055]];
    [Styling addLiquidGlassBorderToView:self.trustBannerView
                           cornerRadius:16
                                  color:[[UIColor colorWithHexString:@"#FABB00"] colorWithAlphaComponent:0.58]];

    if (!self.window || !PPCheckoutShouldAnimate()) return;

    if (!self.trustBannerShimmerLayer) {
        CAGradientLayer *g = [CAGradientLayer layer];
        g.frame = self.trustBannerView.bounds;
        g.startPoint = CGPointMake(0.0, 0.5);
        g.endPoint = CGPointMake(1.0, 0.5);

        // Gold shimmer (visible)
        UIColor *c0 = [UIColor colorWithRed:1.00 green:0.84 blue:0.00 alpha:0.00];
        UIColor *c1 = [UIColor colorWithRed:1.00 green:0.84 blue:0.00 alpha:0.34];
        UIColor *c2 = [UIColor colorWithRed:1.00 green:1.00 blue:1.00 alpha:0.00];

        g.colors = @[(id)c0.CGColor, (id)c1.CGColor, (id)c2.CGColor];
        g.locations = @[@0.0, @0.5, @1.0];
        g.cornerRadius = self.trustBannerView.layer.cornerRadius;
        g.masksToBounds = YES;

        if (self.trustBannerAmbientLayer) {
            [self.trustBannerView.layer insertSublayer:g above:self.trustBannerAmbientLayer];
        } else {
            [self.trustBannerView.layer insertSublayer:g atIndex:0];
        }
        self.trustBannerShimmerLayer = g;
    }

    // Shimmer sweep
    [self.trustBannerShimmerLayer removeAnimationForKey:@"pp_trust_banner_shimmer"];

    CABasicAnimation *shimmer = [CABasicAnimation animationWithKeyPath:@"locations"];
    shimmer.fromValue = @[@(-0.9), @(-0.45), @(0.0)];
    shimmer.toValue   = @[@(1.0),  @(1.45),  @(1.9)];
    shimmer.duration = 3.45;
    shimmer.repeatCount = HUGE_VALF;
    shimmer.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    shimmer.beginTime = CACurrentMediaTime() + 0.5;

    [self.trustBannerShimmerLayer addAnimation:shimmer forKey:@"pp_trust_banner_shimmer"];

    if (self.liveEffectsRunning && self.trustBannerAmbientLayer) {
        [self.trustBannerAmbientLayer removeAnimationForKey:@"pp_trust_ambient_breath"];
        CABasicAnimation *trust = [CABasicAnimation animationWithKeyPath:@"opacity"];
        trust.fromValue = @(0.82);
        trust.toValue = @(1.0);
        trust.duration = 4.6;
        trust.autoreverses = YES;
        trust.repeatCount = HUGE_VALF;
        trust.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.trustBannerAmbientLayer addAnimation:trust forKey:@"pp_trust_ambient_breath"];
    }
}

- (void)pp_stopTrustBannerShimmer {
    self.wantsTrustBannerShimmer = NO;
    [self pp_removeTrustBannerShimmerAnimation];
}

- (void)pp_removeTrustBannerShimmerAnimation {
    [self.trustBannerShimmerLayer removeAnimationForKey:@"pp_trust_banner_shimmer"];
    [self.trustBannerAmbientLayer removeAnimationForKey:@"pp_trust_ambient_breath"];
}

- (UIImage *)pp_defaultCheckoutImage
{
    UIColor *foregroundColor = AppForgroundColr ?: [UIColor whiteColor];
    return [UIImage pp_symbolNamed:PPIsRL ? @"arrow.right" : @"arrow.left"
                         pointSize:18
                            weight:UIImageSymbolWeightSemibold
                             scale:UIImageSymbolScaleLarge
                           palette:@[foregroundColor, foregroundColor]
                      makeTemplate:NO];
}

- (void)pp_applyCheckoutButtonStyleWithTitle:(NSString *)title image:(UIImage *)image
{
    UIImage *resolvedImage = image ?: [self pp_defaultCheckoutImage];
    self.checkoutButtonImageForIdle = resolvedImage;

    self.checkoutBTN.layer.cornerRadius = PPCheckoutButtonCornerRadius();
    self.checkoutBTN.layer.masksToBounds = NO;
    UIColor *buttonBaseColor = AppPrimaryClr ?: [UIColor colorWithRed:0.92 green:0.13 blue:0.38 alpha:1.0];
    self.checkoutBTN.backgroundColor = [buttonBaseColor colorWithAlphaComponent:1.0];
    [self.checkoutBTN pp_setShadowColor:(AppPrimaryClr ?: UIColor.blackColor)];
    self.checkoutBTN.layer.shadowOpacity = 0.22f;
    self.checkoutBTN.layer.shadowRadius = 18.0f;
    self.checkoutBTN.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    if (@available(iOS 13.0, *)) {
        self.checkoutBTN.layer.cornerCurve = kCACornerCurveContinuous;
    }

    if (!self.checkoutButtonGradientLayer) {
        CAGradientLayer *gradient = [CAGradientLayer layer];
        gradient.startPoint = CGPointMake(0.0, 0.0);
        gradient.endPoint = CGPointMake(1.0, 1.0);
        gradient.masksToBounds = YES;
        [self.checkoutBTN.layer insertSublayer:gradient atIndex:0];
        self.checkoutButtonGradientLayer = gradient;
    }
    UIColor *ctaBaseColor = AppPrimaryClr ?: [UIColor colorWithRed:0.92 green:0.13 blue:0.38 alpha:1.0];
    UIColor *ctaDeepColor = AppPrimaryClrDarker ?: ctaBaseColor;
    self.checkoutButtonGradientLayer.colors = @[
        (id)[[UIColor whiteColor] colorWithAlphaComponent:0.28].CGColor,
        (id)[ctaBaseColor colorWithAlphaComponent:0.94].CGColor,
        (id)[ctaDeepColor colorWithAlphaComponent:0.98].CGColor
    ];
    self.checkoutButtonGradientLayer.locations = @[@0.0, @0.38, @1.0];

    if (@available(iOS 15.0, *)) {
        UIColor *foregroundColor = AppForgroundColr ?: [UIColor whiteColor];
        UIButtonConfiguration *config = self.checkoutBTN.configuration ?: [UIButtonConfiguration filledButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        config.background.cornerRadius = PPCheckoutButtonCornerRadius();
        config.background.backgroundColor = UIColor.clearColor;
        config.baseBackgroundColor = UIColor.clearColor;
        config.baseForegroundColor = foregroundColor;
        config.image = self.isCheckoutLoading ? nil : resolvedImage;
        config.imagePlacement = NSDirectionalRectEdgeTrailing;
        config.imagePadding = (self.isCheckoutLoading || resolvedImage == nil) ? 0.0 : 8.0;
        config.contentInsets = NSDirectionalEdgeInsetsMake(14, 18, 14, 18);
        config.preferredSymbolConfigurationForImage =
            [UIImageSymbolConfiguration configurationWithPointSize:16
                                                            weight:UIImageSymbolWeightSemibold];

        NSMutableAttributedString *attrTitle =
            [[NSMutableAttributedString alloc] initWithString:title ?: kLang(@"Checkout")
                                                   attributes:@{
            NSFontAttributeName: [GM boldFontWithSize:17],
            NSForegroundColorAttributeName: foregroundColor
        }];
        config.attributedTitle = attrTitle;

        if (@available(iOS 15.0, *)) {
            config.showsActivityIndicator = self.isCheckoutLoading;
        }

        self.checkoutBTN.configuration = config;
        self.checkoutBTN.tintColor = foregroundColor;
    } else {
        self.checkoutBTN.backgroundColor = [buttonBaseColor colorWithAlphaComponent:1.0];
        [self.checkoutBTN setTitle:title ?: kLang(@"Checkout") forState:UIControlStateNormal];
        [self.checkoutBTN setTitleColor:(AppForgroundColr ?: [UIColor whiteColor]) forState:UIControlStateNormal];
        [self.checkoutBTN setImage:self.isCheckoutLoading ? nil : resolvedImage forState:UIControlStateNormal];
        self.checkoutBTN.titleEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 8);
        self.checkoutBTN.contentEdgeInsets = UIEdgeInsetsMake(14, 18, 14, 18);
    }
}

- (void)pp_styleInfoRow:(UIStackView *)row
{
    row.backgroundColor = PPCheckoutDynamicColor([UIColor.labelColor colorWithAlphaComponent:0.035],
                                                 [UIColor.whiteColor colorWithAlphaComponent:0.045]);
    row.layer.cornerRadius = 20.0;
    row.layer.borderWidth = 1.0;
    [row pp_setBorderColor:PPCheckoutSoftStrokeColor()];
    if (@available(iOS 13.0, *)) {
        row.layer.cornerCurve = kCACornerCurveContinuous;
    }
}


#pragma mark - UI

- (void)buildUI {
    self.backgroundColor = UIColor.clearColor;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.userInteractionEnabled = YES;
    self.semanticContentAttribute = GM.setSemantic;
     
    
    // --- Animation View ---
    self.animationView = [[LOTAnimationView alloc] init];
    self.animationView.loopAnimation = PPCheckoutShouldAnimate();
    self.animationView.animationSpeed = 0.6;
    self.animationView.contentMode = UIViewContentModeScaleAspectFit;

        [AppClasses fetchLottieJSONFromFirebasePath:[NSString stringWithFormat:@"LottieAnimations/shield.json"]
                                         completion:^(NSDictionary * _Nonnull jsonDict, NSError * _Nonnull error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    NSLog(@"❌ Failed to fetch Lottie JSON: %@", error.localizedDescription);
                    return;
                }
                LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
                if (composition) {
                    [self.animationView setSceneModel:composition];
                    if (PPCheckoutShouldAnimate()) {
                        [self.animationView play];
                    } else {
                        [self.animationView stop];
                    }
                }
            });
        }];
    _animationView.layer.cornerRadius = 18.0;
    _animationView.backgroundColor = [AppPrimaryClrDarker colorWithAlphaComponent:0.00];
 
    self.animationContainerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.animationContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.animationContainerView.userInteractionEnabled = NO;
    self.animationContainerView.backgroundColor = UIColor.clearColor;

    [self addSubview:self.animationContainerView];

    self.animationView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.animationContainerView addSubview:self.animationView];
    
        
     
    self.cardView =
    [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleLarge configType:PPButtonConfigrationGlass];
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cardView.layer.cornerRadius = PPCheckoutCardCornerRadius();
    self.cardView.userInteractionEnabled = YES;
    self.cardView.backgroundColor = PPCheckoutSoftSurfaceColor();
    self.cardView.layer.masksToBounds = NO;
    self.cardView.layer.borderWidth = 1.0;
    [self.cardView pp_setBorderColor:PPCheckoutSoftStrokeColor()];
    [self.cardView pp_setShadowColor:(AppShadowClr ?: UIColor.blackColor)];
    self.cardView.layer.shadowOpacity = 0.16f;
    self.cardView.layer.shadowRadius = 30.0f;
    self.cardView.layer.shadowOffset = CGSizeMake(0.0, 18.0);
    if (@available(iOS 13.0, *)) {
        self.cardView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    
    UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
    cfg.cornerStyle = UIButtonConfigurationCornerStyleFixed;
    cfg.background.cornerRadius = PPCheckoutCardCornerRadius();
    cfg.background.backgroundColor = UIColor.clearColor;
    cfg.baseBackgroundColor = UIColor.clearColor;
    cfg.contentInsets = NSDirectionalEdgeInsetsMake(0, 0, 0, 0);
    self.cardView.configuration = cfg;
 
    [self addSubview:self.cardView];

    UIColor *primaryColor = AppPrimaryClr ?: [UIColor colorWithRed:0.92 green:0.13 blue:0.38 alpha:1.0];
    UIColor *deepPrimaryColor = AppPrimaryClrDarker ?: primaryColor;

    self.cardAuraLayer = [CAGradientLayer layer];
    self.cardAuraLayer.startPoint = CGPointMake(0.0, 0.0);
    self.cardAuraLayer.endPoint = CGPointMake(1.0, 1.0);
    self.cardAuraLayer.colors = @[
        (id)[primaryColor colorWithAlphaComponent:0.18].CGColor,
        (id)[[UIColor whiteColor] colorWithAlphaComponent:0.08].CGColor,
        (id)[deepPrimaryColor colorWithAlphaComponent:0.10].CGColor
    ];
    self.cardAuraLayer.locations = @[@0.0, @0.44, @1.0];
    self.cardAuraLayer.opacity = 0.0;
    [self.layer insertSublayer:self.cardAuraLayer atIndex:0];

    self.cardGradientLayer = [CAGradientLayer layer];
    self.cardGradientLayer.colors = @[
        (__bridge id)[[UIColor whiteColor] colorWithAlphaComponent:0.32].CGColor,
        (__bridge id)[primaryColor colorWithAlphaComponent:0.065].CGColor,
        (__bridge id)[UIColor.clearColor CGColor]
    ];
    self.cardGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.cardGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    self.cardGradientLayer.locations = @[@0.0, @0.42, @1.0];
    [self.cardView.layer insertSublayer:self.cardGradientLayer atIndex:0];

    self.cardEdgeLayer = [CAGradientLayer layer];
    self.cardEdgeLayer.startPoint = CGPointMake(0.0, 0.0);
    self.cardEdgeLayer.endPoint = CGPointMake(1.0, 0.0);
    self.cardEdgeLayer.colors = @[
        (id)[primaryColor colorWithAlphaComponent:0.00].CGColor,
        (id)[primaryColor colorWithAlphaComponent:0.22].CGColor,
        (id)[primaryColor colorWithAlphaComponent:0.00].CGColor
    ];
    self.cardEdgeLayer.locations = @[@0.0, @0.5, @1.0];
    self.cardEdgeLayer.opacity = 0.0;
    [self.cardView.layer insertSublayer:self.cardEdgeLayer above:self.cardGradientLayer];

    self.layer.cornerRadius = PPCheckoutCardCornerRadius();
    self.clipsToBounds = NO;
    
    
    // Items Preview Collection
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumLineSpacing = 12.0;
    layout.sectionInset = UIEdgeInsetsMake(2, 1, 2, 1);
    layout.itemSize = CGSizeMake(88, 108);

    self.itemsPreviewCollection =
    [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.itemsPreviewCollection.translatesAutoresizingMaskIntoConstraints = NO;
    self.itemsPreviewCollection.backgroundColor = UIColor.clearColor;
    self.itemsPreviewCollection.showsHorizontalScrollIndicator = NO;
    self.itemsPreviewCollection.dataSource = self;
    self.itemsPreviewCollection.delegate = self;
    self.itemsPreviewCollection.hidden = NO;
    self.itemsPreviewCollection.clipsToBounds = NO;
    self.itemsPreviewCollection.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);

    [self.itemsPreviewCollection registerClass:[UICollectionViewCell class]
                    forCellWithReuseIdentifier:@"CheckoutPreviewCell"];

    [self.cardView addSubview:self.itemsPreviewCollection];
    
    // Labels and Values
    UIFont *labelFont =  [GM MidFontWithSize:13];
    UIColor *labelColor = [UIColor.labelColor colorWithAlphaComponent:0.58];
    UIColor *valueColor = [UIColor.labelColor colorWithAlphaComponent:0.92];
    
    self.itemsLabel = [[PPInsetLabel alloc] init];
    self.itemsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.itemsLabel.font = labelFont;
    self.itemsLabel.textColor = labelColor;
    self.itemsLabel.text = kLang(@"Selected Items" );
    self.itemsLabel.textInsets = UIEdgeInsetsMake(1, 6, 1, 6);

    self.itemsValueLabel = [[PPInsetLabel alloc] init];
    self.itemsValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.itemsValueLabel.font = [GM boldFontWithSize:14];
    self.itemsValueLabel.textColor = valueColor;
    self.itemsValueLabel.adjustsFontSizeToFitWidth = YES;
    self.itemsValueLabel.minimumScaleFactor = 0.72;

    
    self.shippingLabel = [[PPInsetLabel alloc] init];
    self.shippingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.shippingLabel.font = labelFont;
    self.shippingLabel.textColor = labelColor;
    self.shippingLabel.text = kLang(@"Shipping Fee");
    self.shippingLabel.textInsets = UIEdgeInsetsMake(1, 6, 1, 6);

    self.shippingValueLabel = [[PPInsetLabel alloc] init];
    self.shippingValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.shippingValueLabel.font = [GM boldFontWithSize:14];
    self.shippingValueLabel.textColor = valueColor;
    self.shippingValueLabel.textAlignment = NSTextAlignmentNatural;
    self.shippingValueLabel.adjustsFontSizeToFitWidth = YES;
    self.shippingValueLabel.minimumScaleFactor = 0.72;
     // Separator
    self.separator = [[UIView alloc] init];
    self.separator.translatesAutoresizingMaskIntoConstraints = NO;
    self.separator.backgroundColor = [UIColor.labelColor colorWithAlphaComponent:0.08];
    
    // Subtotal
    self.subtotalAttributedLabel = [[UILabel alloc] init];
    self.subtotalAttributedLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtotalAttributedLabel.numberOfLines = 0;
    self.subtotalAttributedLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.subtotalAttributedLabel.semanticContentAttribute =GM.setSemantic;
    
    [self.subtotalAttributedLabel setContentHuggingPriority:UILayoutPriorityDefaultLow
                                                    forAxis:UILayoutConstraintAxisHorizontal];

    [self.subtotalAttributedLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                                 forAxis:UILayoutConstraintAxisHorizontal];

    [self.subtotalAttributedLabel setContentHuggingPriority:UILayoutPriorityRequired
                                                    forAxis:UILayoutConstraintAxisVertical];

    [self.subtotalAttributedLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                                 forAxis:UILayoutConstraintAxisVertical];
    
     

    self.shippingValueLabel.textAlignment = NSTextAlignmentNatural;
    self.shippingLabel.textAlignment = NSTextAlignmentNatural;

    // Pricing Stack
    self.pricingStack = [[UIStackView alloc] init];
    self.pricingStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.pricingStack.axis = UILayoutConstraintAxisVertical;
    self.pricingStack.spacing = 13.0;
    [self.cardView addSubview:self.pricingStack];
    
    
    self.pricingStackBottomAnchor = [self.pricingStack.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:-18];
   //shoppingCart
   
    // Checkout Button
    self.checkoutBTN = [UIButton buttonWithType:UIButtonTypeSystem];
    self.checkoutBTN.translatesAutoresizingMaskIntoConstraints = NO;
    self.checkoutBTN.layer.cornerRadius = PPCheckoutButtonCornerRadius();
    self.checkoutBTN.titleLabel.font = [GM boldFontWithSize:17];
    self.checkoutBTN.accessibilityLabel = NSLocalizedString(@"a11y_btn_checkout", @"Checkout");
    self.checkoutBTN.accessibilityHint  = NSLocalizedString(@"a11y_btn_checkout_hint", @"Double-tap to proceed to checkout");
    [self.checkoutBTN addTarget:self action:@selector(didTapCheckout) forControlEvents:UIControlEventTouchUpInside];
    [self.checkoutBTN addTarget:self action:@selector(pp_checkoutButtonTouchDown:)
               forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
    [self.checkoutBTN addTarget:self action:@selector(pp_checkoutButtonTouchUp:)
               forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
    [self pp_applyCheckoutButtonStyleWithTitle:kLang(@"Checkout") image:nil];
    [self.checkoutBTN setContentHuggingPriority:UILayoutPriorityRequired
                                        forAxis:UILayoutConstraintAxisHorizontal];

    [self.checkoutBTN setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                     forAxis:UILayoutConstraintAxisHorizontal];

    self.checkoutFallbackIndicator =
    [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.checkoutFallbackIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.checkoutFallbackIndicator.hidesWhenStopped = YES;
    self.checkoutFallbackIndicator.color = AppForgroundColr;
    [self.checkoutBTN addSubview:self.checkoutFallbackIndicator];
    [NSLayoutConstraint activateConstraints:@[
        [self.checkoutFallbackIndicator.centerXAnchor constraintEqualToAnchor:self.checkoutBTN.centerXAnchor],
        [self.checkoutFallbackIndicator.centerYAnchor constraintEqualToAnchor:self.checkoutBTN.centerYAnchor]
    ]];
    // Rows: items, shipping, separator, subtotal
    
    self.itemsRow =
    [self horizontalRowWithLabel:self.itemsLabel value:self.itemsValueLabel];

    self.shippingRow =
    [self horizontalRowWithLabel:self.shippingLabel value:self.shippingValueLabel];
    
    
    
    // Trust banner (between table and summary)
    self.trustBannerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.trustBannerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.trustBannerView.layer.cornerRadius =18.0;
    self.trustBannerView.layer.masksToBounds = YES;
    self.trustBannerView.layer.borderWidth = 1.0;
    [self.trustBannerView pp_setBorderColor:[UIColor colorWithRed:1.00 green:0.84 blue:0.00 alpha:0.16]];
    [self.trustBannerView setBackgroundColor:[UIColor hx_colorWithHexStr:@"#FABB00" alpha:0.055]];
    if (@available(iOS 13.0, *)) {
        self.trustBannerView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.trustBannerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.trustBannerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.trustBannerLabel.numberOfLines = 1;
    self.trustBannerLabel.font = [GM MidFontWithSize:12];
    self.trustBannerLabel.textColor = [UIColor.labelColor colorWithAlphaComponent:0.66];
    self.trustBannerLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.trustBannerLabel.text =  kLang(@"Securecheckout");
    [self.trustBannerView addSubview:self.trustBannerLabel];

    [self.trustBannerView.heightAnchor constraintEqualToConstant:38.0].active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [self.trustBannerLabel.leadingAnchor constraintEqualToAnchor:self.trustBannerView.leadingAnchor constant:14.0],
        [self.trustBannerLabel.trailingAnchor constraintEqualToAnchor:self.trustBannerView.trailingAnchor constant:-52.0],
        [self.trustBannerLabel.topAnchor constraintEqualToAnchor:self.trustBannerView.topAnchor constant:0.0],
        [self.trustBannerLabel.bottomAnchor constraintEqualToAnchor:self.trustBannerView.bottomAnchor constant:0.0]
    ]];
    
    UIView *subtotalSpacer = [[UIView alloc] initWithFrame:CGRectZero];
    subtotalSpacer.translatesAutoresizingMaskIntoConstraints = NO;

    // Subtotal row: button on the left, subtotal on the right
    UIStackView *subtotalRow =
    [[UIStackView alloc] initWithArrangedSubviews:@[ self.subtotalAttributedLabel, subtotalSpacer,self.checkoutBTN]];
    subtotalRow.axis = UILayoutConstraintAxisHorizontal;
    subtotalRow.alignment = UIStackViewAlignmentCenter;
    subtotalRow.distribution = UIStackViewDistributionFill;
    subtotalRow.spacing = 16.0;

    [subtotalSpacer setContentHuggingPriority:UILayoutPriorityDefaultLow
                                     forAxis:UILayoutConstraintAxisHorizontal];
    [subtotalSpacer setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                   forAxis:UILayoutConstraintAxisHorizontal];

    // Keep button fixed; let subtotal take remaining space
    [self.checkoutBTN setContentHuggingPriority:UILayoutPriorityRequired
                                        forAxis:UILayoutConstraintAxisHorizontal];
    [self.checkoutBTN setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                     forAxis:UILayoutConstraintAxisHorizontal];

    [self.subtotalAttributedLabel setContentHuggingPriority:UILayoutPriorityDefaultLow
                                                    forAxis:UILayoutConstraintAxisHorizontal];
    [self.subtotalAttributedLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                                 forAxis:UILayoutConstraintAxisHorizontal];
    
    
    self.itemsPreviewCollection.alpha = 0.0;
    self.itemsPreviewCollection.hidden = YES;
    self.itemsPreviewHeightConstraint =
        [self.itemsPreviewCollection.heightAnchor constraintEqualToConstant:110.0];
    self.itemsPreviewHeightConstraint.active = YES;
    
    [self.pricingStack addArrangedSubview:subtotalRow];
    [self.pricingStack addArrangedSubview:self.separator];
    [self.pricingStack addArrangedSubview:self.itemsRow];
    [self.pricingStack addArrangedSubview:self.shippingRow];
    [self.pricingStack addArrangedSubview:self.itemsPreviewCollection];
    [self.pricingStack addArrangedSubview:self.trustBannerView];
    
    
    if(Language.isRTL)
    {
        self.itemsLabel.textAlignment = NSTextAlignmentRight;
        self.itemsValueLabel.textAlignment = NSTextAlignmentLeft;
        
        self.shippingLabel.textAlignment = NSTextAlignmentRight;
        self.shippingValueLabel.textAlignment = NSTextAlignmentLeft;
        
    }
    else
    {
        self.itemsLabel.textAlignment = NSTextAlignmentLeft;
        self.itemsValueLabel.textAlignment = NSTextAlignmentRight;
        
        self.shippingLabel.textAlignment = NSTextAlignmentLeft;
        self.shippingValueLabel.textAlignment = NSTextAlignmentRight;
    }

}
//kLang(@"Checkout")
-(void)setCheckoutBTNTitle:(NSString *)title image:(UIImage *)image
{
    [self pp_applyCheckoutButtonStyleWithTitle:title ?: kLang(@"Checkout") image:image];
}

- (void)setCheckoutLoading:(BOOL)loading
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setCheckoutLoading:loading];
        });
        return;
    }

    if (_checkoutLoading == loading) return;
    _checkoutLoading = loading;

    self.checkoutBTN.enabled = !loading;
    self.checkoutBTN.userInteractionEnabled = !loading;
    CGFloat targetAlpha = loading ? 0.88 : 1.0;
    if (PPCheckoutShouldAnimate()) {
        [UIView animateWithDuration:0.18
                              delay:0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.checkoutBTN.alpha = targetAlpha;
            self.checkoutBTN.transform = CGAffineTransformIdentity;
        } completion:nil];
    } else {
        self.checkoutBTN.alpha = targetAlpha;
        self.checkoutBTN.transform = CGAffineTransformIdentity;
    }

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = self.checkoutBTN.configuration;
        if (!config) {
            config = [UIButtonConfiguration filledButtonConfiguration];
        }
        config.showsActivityIndicator = loading;
        config.image = loading ? nil : self.checkoutButtonImageForIdle;
        config.imagePadding = (loading || self.checkoutButtonImageForIdle == nil) ? 0.0 : 6.0;
        self.checkoutBTN.configuration = config;
    } else {
        if (loading) {
            [self.checkoutFallbackIndicator startAnimating];
        } else {
            [self.checkoutFallbackIndicator stopAnimating];
        }
    }
}

- (void)pp_runCardEntranceAnimationIfNeeded
{
    if (!PPCheckoutShouldAnimate()) {
        self.cardView.alpha = 1.0;
        self.cardView.transform = CGAffineTransformIdentity;
        return;
    }

    self.cardView.alpha = 0.0;
    self.cardView.transform =
        CGAffineTransformConcat(CGAffineTransformMakeTranslation(0, 24),
                                CGAffineTransformMakeScale(0.982, 0.982));

    [UIView animateWithDuration:0.58
                          delay:0.05
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.cardView.alpha = 1.0;
        self.cardView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_startLivingEffectsIfNeeded
{
    if (self.liveEffectsRunning || !self.window) return;

    if (!PPCheckoutShouldAnimate()) {
        self.cardAuraLayer.opacity = 0.22;
        self.cardEdgeLayer.opacity = 0.16;
        return;
    }

    self.liveEffectsRunning = YES;
    self.cardAuraLayer.opacity = 0.24;
    self.cardEdgeLayer.opacity = 0.18;

    [self.cardAuraLayer removeAnimationForKey:@"pp_checkout_aura_breath"];
    CABasicAnimation *aura = [CABasicAnimation animationWithKeyPath:@"opacity"];
    aura.fromValue = @(0.14);
    aura.toValue = @(0.34);
    aura.duration = 5.8;
    aura.autoreverses = YES;
    aura.repeatCount = HUGE_VALF;
    aura.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.cardAuraLayer addAnimation:aura forKey:@"pp_checkout_aura_breath"];

    [self.cardEdgeLayer removeAnimationForKey:@"pp_checkout_edge_sweep"];
    CABasicAnimation *edge = [CABasicAnimation animationWithKeyPath:@"locations"];
    edge.fromValue = @[@(-0.35), @(-0.1), @(0.18)];
    edge.toValue = @[@(0.82), @(1.08), @(1.35)];
    edge.duration = 6.4;
    edge.repeatCount = HUGE_VALF;
    edge.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.cardEdgeLayer addAnimation:edge forKey:@"pp_checkout_edge_sweep"];

    if (self.trustBannerAmbientLayer) {
        [self.trustBannerAmbientLayer removeAnimationForKey:@"pp_trust_ambient_breath"];
        CABasicAnimation *trust = [CABasicAnimation animationWithKeyPath:@"opacity"];
        trust.fromValue = @(0.82);
        trust.toValue = @(1.0);
        trust.duration = 4.6;
        trust.autoreverses = YES;
        trust.repeatCount = HUGE_VALF;
        trust.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.trustBannerAmbientLayer addAnimation:trust forKey:@"pp_trust_ambient_breath"];
    }
}

- (void)pp_stopLivingEffects
{
    self.liveEffectsRunning = NO;
    [self.cardAuraLayer removeAnimationForKey:@"pp_checkout_aura_breath"];
    [self.cardEdgeLayer removeAnimationForKey:@"pp_checkout_edge_sweep"];
    [self.trustBannerAmbientLayer removeAnimationForKey:@"pp_trust_ambient_breath"];
}

- (void)pp_checkoutButtonTouchDown:(UIButton *)sender
{
    if (self.isCheckoutLoading || !PPCheckoutShouldAnimate()) return;

    [UIView animateWithDuration:0.10
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        sender.transform = CGAffineTransformMakeScale(0.972, 0.972);
        sender.layer.shadowOpacity = 0.15f;
        sender.layer.shadowRadius = 12.0f;
    } completion:nil];
}

- (void)pp_checkoutButtonTouchUp:(UIButton *)sender
{
    if (!PPCheckoutShouldAnimate()) {
        sender.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.22
                          delay:0
         usingSpringWithDamping:0.72
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        sender.transform = CGAffineTransformIdentity;
        sender.layer.shadowOpacity = self.isCheckoutLoading ? 0.12f : 0.22f;
        sender.layer.shadowRadius = 18.0f;
    } completion:nil];
}

- (UIStackView *)horizontalRowWithLabel:(UILabel *)label value:(UILabel *)value {
    return [self horizontalRowWithLabel:label value:value button:nil];
}

- (UIStackView *)horizontalRowWithLabel:(UILabel *)label value:(UILabel *)value button:(nullable UIButton *)button{
    UIView *spacer = [[UIView alloc] initWithFrame:CGRectZero];
    spacer.translatesAutoresizingMaskIntoConstraints = NO;

    NSMutableArray<UIView *> *arrangedSubviews = [NSMutableArray arrayWithObjects:label, spacer, value, nil];
    if (button) {
        [arrangedSubviews addObject:button];
    }

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:arrangedSubviews];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 10.0;
    row.alignment = UIStackViewAlignmentCenter;
    row.distribution = UIStackViewDistributionFill;
    row.semanticContentAttribute = GM.setSemantic;
    row.layoutMarginsRelativeArrangement = YES;
    row.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(12, 14, 12, 14);
    [self pp_styleInfoRow:row];

    [label setContentHuggingPriority:UILayoutPriorityDefaultHigh
                             forAxis:UILayoutConstraintAxisHorizontal];
    [label setContentCompressionResistancePriority:UILayoutPriorityRequired
                                           forAxis:UILayoutConstraintAxisHorizontal];

    [spacer setContentHuggingPriority:UILayoutPriorityDefaultLow
                              forAxis:UILayoutConstraintAxisHorizontal];
    [spacer setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                            forAxis:UILayoutConstraintAxisHorizontal];

    [value setContentHuggingPriority:UILayoutPriorityRequired
                              forAxis:UILayoutConstraintAxisHorizontal];
    [value setContentCompressionResistancePriority:UILayoutPriorityRequired
                                            forAxis:UILayoutConstraintAxisHorizontal];

    return row;
}

#pragma mark - Layout

- (void)buildLayout {
    CGFloat padding = 18.0;
  
    [NSLayoutConstraint activateConstraints:@[
        [self.checkoutBTN.heightAnchor constraintEqualToConstant:54.0],
        [self.cardView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
 
        [self.pricingStack.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:18.0],
        [self.pricingStack.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:padding],
        [self.pricingStack.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-padding],

        [self.separator.heightAnchor constraintEqualToConstant:1.0],
        self.pricingStackBottomAnchor,
     ]];

    self.animationView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.animationContainerView.heightAnchor constraintEqualToConstant:28.0].active = YES;
    [self.animationContainerView.widthAnchor constraintEqualToConstant:34.0].active = YES;
    [self.animationContainerView.centerYAnchor constraintEqualToAnchor:self.trustBannerView.centerYAnchor].active = YES;
    [self.animationContainerView.trailingAnchor constraintEqualToAnchor:self.trustBannerView.trailingAnchor constant:-8.0].active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [self.animationView.topAnchor constraintEqualToAnchor:self.animationContainerView.topAnchor],
        [self.animationView.bottomAnchor constraintEqualToAnchor:self.animationContainerView.bottomAnchor],
        [self.animationView.leadingAnchor constraintEqualToAnchor:self.animationContainerView.leadingAnchor],
        [self.animationView.trailingAnchor constraintEqualToAnchor:self.animationContainerView.trailingAnchor],
    ]];
    [self setNeedsLayout];
    [self layoutIfNeeded];
  
}

#pragma mark - API

// Subtotal label now supports showTitle YES/NO, with vertical centering and alignment options
- (void)updateTotalsWithItems:(CGFloat)itemsTotal
                     shipping:(CGFloat)shippingFee
                    showTitle:(BOOL)showTitle
{
   
    
    _itemsTotal = itemsTotal;
    _shippingFee = shippingFee;
    _subtotal = itemsTotal + shippingFee;

    self.itemsValueLabel.text = [PPChatsFunc formattedCurrency:itemsTotal];
    self.shippingValueLabel.text = [PPChatsFunc formattedCurrency:shippingFee];

    NSString *title = kLang(@"Subtotal");
    NSString *price = [PPChatsFunc formattedCurrency:_subtotal];

    // Split integer / fraction (locale-safe)
    NSString *decimalSeparator = PPCheckoutDecimalSeparatorFromFormattedPrice(price);

    NSString *integerPart = price;
    NSString *fractionPart = nil;

    NSRange sepRange =
    [price rangeOfString:decimalSeparator options:NSBackwardsSearch];

    if (sepRange.location != NSNotFound) {
        integerPart = [price substringToIndex:sepRange.location];
        fractionPart = [price substringFromIndex:sepRange.location];
    }

    NSString *fullText = nil;
    showTitle=YES;
    if (showTitle) {
        fullText = fractionPart
        ? [NSString stringWithFormat:@"%@\n%@%@", title, integerPart, fractionPart]
        : [NSString stringWithFormat:@"%@\n%@", title, integerPart];
    } else {
        fullText = fractionPart
        ? [NSString stringWithFormat:@"%@%@", integerPart, fractionPart]
        : integerPart;
    }

    NSMutableAttributedString *attr =
    [[NSMutableAttributedString alloc] initWithString:fullText];

    NSRange titleRange = [fullText rangeOfString:title];
    if (titleRange.location != NSNotFound) {
        [attr addAttributes:@{
            NSFontAttributeName: [GM MidFontWithSize:11],
            NSForegroundColorAttributeName: [UIColor.labelColor colorWithAlphaComponent:0.52],
            NSKernAttributeName: @(0.4)
        } range:titleRange];
    }

    NSRange integerRange =
    [fullText rangeOfString:integerPart options:NSBackwardsSearch];

    [attr addAttributes:@{
        NSFontAttributeName: [GM boldFontWithSize:PPIsRL ? 34 : 30],
        NSForegroundColorAttributeName: [UIColor.labelColor colorWithAlphaComponent:0.96]
    } range:integerRange];

    if (fractionPart) {
        NSRange fractionRange =
        [fullText rangeOfString:fractionPart options:NSBackwardsSearch];

        if (fractionRange.location != NSNotFound) {
            UIColor *primaryColor = AppPrimaryClr ?: [UIColor colorWithRed:0.92 green:0.13 blue:0.38 alpha:1.0];
            [attr addAttributes:@{
                NSFontAttributeName: [GM boldFontWithSize:14],
                NSForegroundColorAttributeName: [primaryColor colorWithAlphaComponent:0.92],
                NSBaselineOffsetAttributeName: @(9)
            } range:fractionRange];
        }
    }

    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineSpacing = showTitle ? 3.0 : 0.0;
    style.alignment = Language.alignmentForCurrentLanguage;

    [attr addAttribute:NSParagraphStyleAttributeName
                 value:style
                 range:NSMakeRange(0, attr.length)];

    NSString *previousSubtotalText = self.subtotalAttributedLabel.attributedText.string;
    self.subtotalAttributedLabel.numberOfLines = showTitle ? 2 : 1;
    self.subtotalAttributedLabel.attributedText = attr;

    if (PPCheckoutShouldAnimate() &&
        previousSubtotalText.length > 0 &&
        ![previousSubtotalText isEqualToString:fullText]) {
        self.subtotalAttributedLabel.transform = CGAffineTransformMakeScale(0.985, 0.985);
        [UIView animateWithDuration:0.24
                              delay:0
             usingSpringWithDamping:0.78
              initialSpringVelocity:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.subtotalAttributedLabel.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

#pragma mark - Action

- (void)didTapCheckout {
    NSLog(@"Checkout tapped");
    if (!self.isCheckoutLoading && PPCheckoutShouldAnimate()) {
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *feedback =
                [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            [feedback prepare];
            [feedback impactOccurred];
        }
    }
    
    if (self.onTapCheckOut) {
        self.onTapCheckOut();
    }
    
    
}

 
- (void)setShowsItemsPreview:(BOOL)showsItemsPreview
{
    if (_showsItemsPreview == showsItemsPreview) return;
    _showsItemsPreview = showsItemsPreview;

    if (showsItemsPreview) {
        self.itemsPreviewCollection.hidden = NO;
        self.itemsPreviewCollection.alpha = 0.0;
        self.itemsPreviewCollection.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
        self.itemsRow.hidden = NO;
        self.shippingRow.hidden = NO;
    }

    self.pricingStackBottomAnchor.constant = -18.0;
    if (!PPCheckoutShouldAnimate()) {
        self.itemsPreviewCollection.alpha = showsItemsPreview ? 1.0 : 0.0;
        self.itemsPreviewCollection.transform = CGAffineTransformIdentity;
        self.itemsRow.alpha = showsItemsPreview ? 0.0 : 1.0;
        self.shippingRow.alpha = showsItemsPreview ? 0.0 : 1.0;
        self.itemsRow.transform = CGAffineTransformIdentity;
        self.shippingRow.transform = CGAffineTransformIdentity;
        self.itemsRow.hidden = showsItemsPreview;
        self.shippingRow.hidden = showsItemsPreview;
        self.itemsPreviewCollection.hidden = !showsItemsPreview;
        return;
    }

    [UIView animateWithDuration:0.38
                          delay:0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.itemsPreviewCollection.alpha = showsItemsPreview ? 1.0 : 0.0;
        self.itemsPreviewCollection.transform = showsItemsPreview ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0.0, 10.0);
        self.itemsRow.alpha = showsItemsPreview ? 0.0 : 1.0;
        self.itemsRow.transform = showsItemsPreview ? CGAffineTransformMakeTranslation(0.0, -6.0) : CGAffineTransformIdentity;
        self.shippingRow.alpha = showsItemsPreview ? 0.0 : 1.0;
        self.shippingRow.transform = showsItemsPreview ? CGAffineTransformMakeTranslation(0.0, -6.0) : CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        self.itemsRow.hidden = showsItemsPreview;
        self.shippingRow.hidden = showsItemsPreview;
        if (!showsItemsPreview) {
            self.itemsPreviewCollection.hidden = YES;
        }
    }];
}

- (void)updatePreviewItems:(NSArray<CartItem *> *)items
{
    self.previewItems = items ?: @[];
    BOOL shouldShowPreview = self.showsItemsPreview && self.previewItems.count > 0;
    self.itemsPreviewCollection.hidden = !shouldShowPreview;
    self.itemsPreviewCollection.alpha = shouldShowPreview ? 1.0 : 0.0;
    self.itemsPreviewCollection.transform = shouldShowPreview ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0.0, 10.0);
    self.itemsRow.hidden = shouldShowPreview;
    self.shippingRow.hidden = shouldShowPreview;
    self.itemsRow.alpha = shouldShowPreview ? 0.0 : 1.0;
    self.shippingRow.alpha = shouldShowPreview ? 0.0 : 1.0;
    self.itemsRow.transform = CGAffineTransformIdentity;
    self.shippingRow.transform = CGAffineTransformIdentity;
    [self.itemsPreviewCollection reloadData];
     
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
    return self.previewItems.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                          cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell =
    [collectionView dequeueReusableCellWithReuseIdentifier:@"CheckoutPreviewCell"
                                              forIndexPath:indexPath];

    CartItem *item = self.previewItems[indexPath.item];

    UIImageView *img = [cell.contentView viewWithTag:11];
    UILabel *price = [cell.contentView viewWithTag:12];

    if (!img) {
        img = [[UIImageView alloc] init];
        img.tag = 11;
        img.translatesAutoresizingMaskIntoConstraints = NO;
        img.contentMode = UIViewContentModeScaleAspectFill;
        img.clipsToBounds = YES;
        img.layer.cornerRadius = 16.0;
        img.backgroundColor = PPCheckoutDynamicColor([UIColor.labelColor colorWithAlphaComponent:0.05],
                                                     [UIColor.whiteColor colorWithAlphaComponent:0.07]);
        if (@available(iOS 13.0, *)) {
            img.layer.cornerCurve = kCACornerCurveContinuous;
        }
        cell.backgroundColor = UIColor.clearColor;
        cell.contentView.backgroundColor = PPCheckoutDynamicColor([UIColor.labelColor colorWithAlphaComponent:0.035],
                                                                  [UIColor.whiteColor colorWithAlphaComponent:0.045]);
        cell.contentView.layer.cornerRadius = 22.0;
        cell.contentView.layer.borderWidth = 1.0;
        [cell.contentView pp_setBorderColor:PPCheckoutSoftStrokeColor()];
        cell.contentView.layer.masksToBounds = YES;
        if (@available(iOS 13.0, *)) {
            cell.contentView.layer.cornerCurve = kCACornerCurveContinuous;
        }

        UIColor *previewPrimaryColor = AppPrimaryClr ?: [UIColor colorWithRed:0.92 green:0.13 blue:0.38 alpha:1.0];
        CAGradientLayer *previewGradient = [CAGradientLayer layer];
        previewGradient.name = @"pp_checkout_preview_gradient";
        previewGradient.startPoint = CGPointMake(0.0, 0.0);
        previewGradient.endPoint = CGPointMake(1.0, 1.0);
        previewGradient.colors = @[
            (id)[[UIColor whiteColor] colorWithAlphaComponent:0.18].CGColor,
            (id)[previewPrimaryColor colorWithAlphaComponent:0.045].CGColor,
            (id)[UIColor.clearColor CGColor]
        ];
        previewGradient.locations = @[@0.0, @0.48, @1.0];
        previewGradient.frame = cell.contentView.bounds;
        previewGradient.cornerRadius = 22.0;
        [cell.contentView.layer insertSublayer:previewGradient atIndex:0];

        [cell.contentView addSubview:img];

        price = [[UILabel alloc] init];
        price.tag = 12;
        price.translatesAutoresizingMaskIntoConstraints = NO;
        price.font = [GM boldFontWithSize:11.5];
        price.textAlignment = NSTextAlignmentCenter;
        price.textColor = [UIColor.labelColor colorWithAlphaComponent:0.72];
        price.adjustsFontSizeToFitWidth = YES;
        price.minimumScaleFactor = 0.7;
        price.numberOfLines = 1;
        [cell.contentView addSubview:price];

        UIButton *removeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        removeBtn.tag = 13;
        removeBtn.translatesAutoresizingMaskIntoConstraints = NO;
        removeBtn.backgroundColor = PPCheckoutDynamicColor([[UIColor whiteColor] colorWithAlphaComponent:0.92],
                                                           [[UIColor blackColor] colorWithAlphaComponent:0.36]);
        removeBtn.layer.cornerRadius = 12.0;
        removeBtn.clipsToBounds = YES;
        removeBtn.layer.borderWidth = 1.0;
        [removeBtn pp_setBorderColor:PPCheckoutSoftStrokeColor()];
        if (@available(iOS 13.0, *)) {
            removeBtn.layer.cornerCurve = kCACornerCurveContinuous;
        }

        [removeBtn setImage:[UIImage systemImageNamed:@"xmark"]
                   forState:UIControlStateNormal];
        removeBtn.tintColor = [UIColor.labelColor colorWithAlphaComponent:0.78];
        removeBtn.contentEdgeInsets = UIEdgeInsetsMake(3, 3, 3, 3);

        [removeBtn addTarget:self
                      action:@selector(didTapRemovePreviewItem:)
            forControlEvents:UIControlEventTouchUpInside];

        [cell.contentView addSubview:removeBtn];

        [NSLayoutConstraint activateConstraints:@[
            [img.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:10.0],
            [img.centerXAnchor constraintEqualToAnchor:cell.contentView.centerXAnchor],
            [img.widthAnchor constraintEqualToConstant:62.0],
            [img.heightAnchor constraintEqualToConstant:62.0],

            [price.topAnchor constraintEqualToAnchor:img.bottomAnchor constant:8.0],
            [price.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:6.0],
            [price.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-6.0],
            [price.bottomAnchor constraintLessThanOrEqualToAnchor:cell.contentView.bottomAnchor constant:-8.0],

            [removeBtn.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:6.0],
            [removeBtn.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-6.0],
            [removeBtn.widthAnchor constraintEqualToConstant:24.0],
            [removeBtn.heightAnchor constraintEqualToConstant:24.0],
        ]];
    }

    for (CALayer *layer in cell.contentView.layer.sublayers) {
        if ([layer.name isEqualToString:@"pp_checkout_preview_gradient"]) {
            layer.frame = cell.contentView.bounds;
            layer.cornerRadius = cell.contentView.layer.cornerRadius;
            break;
        }
    }

    // Tag the remove button with the current index (for every reuse)
    UIButton *removeBtn = [cell.contentView viewWithTag:13];
    removeBtn.accessibilityIdentifier =
        [NSString stringWithFormat:@"%ld", (long)indexPath.item];

    NSString *url = item.imageURL;
    img.image = nil;
    if (url.length > 0) {
        [img sd_setImageWithURL:[NSURL URLWithString:url]];
    }

    price.text = [PPChatsFunc formattedCurrency:item.price];

    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView
       willDisplayCell:(UICollectionViewCell *)cell
    forItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (!PPCheckoutShouldAnimate()) {
        cell.contentView.alpha = 1.0;
        cell.contentView.transform = CGAffineTransformIdentity;
        return;
    }

    cell.contentView.alpha = 0.0;
    cell.contentView.transform =
        CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 8.0),
                                CGAffineTransformMakeScale(0.965, 0.965));

    NSTimeInterval delay = MIN(indexPath.item, 6) * 0.035;
    [UIView animateWithDuration:0.34
                          delay:delay
         usingSpringWithDamping:0.84
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        cell.contentView.alpha = 1.0;
        cell.contentView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - Public API (optional)

// Optional: Setter for card background image
- (void)setCardBackgroundImage:(UIImage *)image
{
    if (!image) {
        [self.cardBackgroundImageLayer removeFromSuperlayer];
        self.cardBackgroundImageLayer = nil;
        return;
    }

    if (!self.cardBackgroundImageLayer) {
        CALayer *imageLayer = [CALayer layer];
        imageLayer.contentsGravity = kCAGravityResizeAspectFill;
        imageLayer.masksToBounds = YES;
        imageLayer.opacity = 0.16;
        imageLayer.contentsScale = UIScreen.mainScreen.scale;
        if (self.cardGradientLayer) {
            [self.cardView.layer insertSublayer:imageLayer below:self.cardGradientLayer];
        } else {
            [self.cardView.layer insertSublayer:imageLayer atIndex:0];
        }
        self.cardBackgroundImageLayer = imageLayer;
    }

    self.cardBackgroundImageLayer.contents = (__bridge id)image.CGImage;
    [self setNeedsLayout];
}

#pragma mark - Remove Preview Item Action

- (void)didTapRemovePreviewItem:(UIButton *)sender
{
    NSIndexPath *indexPath = nil;
    UIView *view = sender;
    while (view && ![view isKindOfClass:[UICollectionViewCell class]]) {
        view = view.superview;
    }
    if ([view isKindOfClass:[UICollectionViewCell class]]) {
        indexPath = [self.itemsPreviewCollection indexPathForCell:(UICollectionViewCell *)view];
    }
    if (!indexPath) {
        NSInteger index = sender.accessibilityIdentifier.integerValue;
        if (index >= 0 && index < self.previewItems.count) {
            indexPath = [NSIndexPath indexPathForItem:index inSection:0];
        }
    }
    if (!indexPath || indexPath.item < 0 || indexPath.item >= self.previewItems.count) return;

    CartItem *item = self.previewItems[indexPath.item];
    if (!item) return;

    [[CartManager sharedManager] removeItem:item];

    if (self.onRemovePreviewItem) {
        self.onRemovePreviewItem(item);
    }
}
@end
