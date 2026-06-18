
#import "PPBottomBar.h"

//
//  PPPaymentTabBar.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/11/2025.
//

#import "Styling.h"
#import "PPCommerceFeedbackManager.h"
#import "CartManager.h"

 
#pragma mark - BBCartBottomBar

static BOOL PPBBCartUsesLegacyIPadBelowIOS18(void);

static CGFloat PPBBCartBadgeCartButtonSize(void) {
    return 44.0;
}

static UIColor *PPBBCartColor(UIColor *color, UIColor *fallback) {
    return color ?: fallback ?: UIColor.systemBackgroundColor;
}

static BOOL PPBBCartUsesLegacyIPadBelowIOS18(void) {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && !PPIOS18();
}

static UIColor *PPBBCartAdaptiveColor(UIColor *darkColor, UIColor *lightColor) {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
                ? PPBBCartColor(darkColor, UIColor.secondarySystemBackgroundColor)
                : PPBBCartColor(lightColor, UIColor.secondarySystemBackgroundColor);
        }];
    }
    return PPBBCartColor(lightColor, darkColor);
}

static UIColor *PPBBCartControlFillColor(void) {
    if (PPBBCartUsesLegacyIPadBelowIOS18()) {
        return PPBBCartAdaptiveColor([UIColor colorWithWhite:1.0 alpha:0.070],
                                     [UIColor colorWithWhite:1.0 alpha:0.30]);
    }
    UIColor *base = PPBBCartColor(AppForgroundColr, UIColor.secondarySystemBackgroundColor);
    return [base colorWithAlphaComponent:PPIOS26() ? 0.18 : 0.26];
}

static CGFloat PPBBCartSurfaceBottomInset(void) {
    return 0.0;
}

static CGFloat PPBBCartSurfaceHorizontalInset(void) {
    return 0.0;
}

static CGFloat PPBBCartContentInset(void) {
    return PPBBCartUsesLegacyIPadBelowIOS18() ? 5.0 : 16;
}

static CGFloat PPBBCartRowSpacing(void) {
    return PPBBCartUsesLegacyIPadBelowIOS18() ? 4.0 : 12.0;
}

static CGFloat PPBBCartUtilityButtonSize(void) {
    return PPBBCartUsesLegacyIPadBelowIOS18() ? 40.0 : 44.0;
}

static CGFloat PPBBCartStepperButtonSize(void) {
    return PPBBCartUsesLegacyIPadBelowIOS18() ? 34.0 : 38.0;
}

static CGFloat PPBBCartQuantityWidth(void) {
    return PPBBCartUsesLegacyIPadBelowIOS18() ? 112.0 : 126.0;
}

static CGFloat PPBBCartControlHeight(void) {
    return PPBBCartUsesLegacyIPadBelowIOS18() ? 40.0 : 46.0;
}

static CGFloat PPBBCartTotalHeight(void) {
    return PPBBCartUsesLegacyIPadBelowIOS18() ? 40.0 : 46.0;
}

static CGFloat PPBBCartAddButtonHeight(void) {
    return PPBBCartUsesLegacyIPadBelowIOS18() ? 38.0 : 46.0;
}

static UIColor *PPBBCartSurfaceFillColor(void) {
    if (PPBBCartUsesLegacyIPadBelowIOS18()) {
        return PPBBCartAdaptiveColor([UIColor colorWithWhite:0.10 alpha:0.20],
                                     [UIColor colorWithWhite:1.0 alpha:0.24]);
    }
    UIColor *base = PPBBCartColor(AppBackgroundClr,
                                  UIColor.secondarySystemBackgroundColor);
    return [base colorWithAlphaComponent:PPIOS26() ? 0.08 : 0.18];
}

static UIColor *PPBBCartSurfaceTintColor(void) {
    if (PPBBCartUsesLegacyIPadBelowIOS18()) {
        return PPBBCartAdaptiveColor([UIColor colorWithWhite:1.0 alpha:0.035],
                                     [UIColor colorWithWhite:1.0 alpha:0.08]);
    }
    UIColor *base = PPBBCartColor(AppForgroundColr,
                                  UIColor.systemBackgroundColor);
    return [base colorWithAlphaComponent:PPIOS26() ? 0.16 : 0.10];
}

static UIColor *PPBBCartBadgeFillColor(void) {
    if (PPBBCartUsesLegacyIPadBelowIOS18()) {
        return PPBBCartAdaptiveColor([UIColor colorWithWhite:1.0 alpha:0.02],
                                     [UIColor colorWithWhite:1.0 alpha:0.32]);
    }
    UIColor *base = PPBBCartColor(AppForgroundColr, UIColor.secondarySystemBackgroundColor);
    return [base colorWithAlphaComponent:PPIOS26() ? 0.20 : 0.30];
}

static UIBlurEffectStyle PPBBCartUltraThinBlurStyle(void) {
    return UIBlurEffectStyleSystemUltraThinMaterial;
}

static UIImage *PPBBCartSymbol(NSString *name, CGFloat pointSize, UIImageSymbolWeight weight, UIColor *color) {
    UIImageSymbolConfiguration *size =
    [UIImageSymbolConfiguration configurationWithPointSize:pointSize
                                                    weight:weight
                                                     scale:UIImageSymbolScaleMedium];
    UIImage *image = [UIImage systemImageNamed:name withConfiguration:size];
    UIColor *resolved = color ?: UIColor.labelColor;
    return [[image imageWithTintColor:resolved] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

static NSArray<NSNumber *> *PPBBCartLottieRGBA(UIColor *color) {
    UIColor *resolved = color ?: UIColor.labelColor;
    CGFloat r = 0.0, g = 0.0, b = 0.0, a = 1.0;
    if (![resolved getRed:&r green:&g blue:&b alpha:&a]) {
        const CGFloat *components = CGColorGetComponents(resolved.CGColor);
        size_t count = CGColorGetNumberOfComponents(resolved.CGColor);
        if (components && count >= 3) {
            r = components[0];
            g = components[1];
            b = components[2];
            a = (count >= 4) ? components[3] : 1.0;
        } else if (components && count >= 2) {
            r = components[0];
            g = components[0];
            b = components[0];
            a = components[1];
        }
    }
    return @[@(r), @(g), @(b), @(a)];
}

static BOOL PPBBCartLottieColorArrayIsLight(NSArray *colorArray) {
    if (![colorArray isKindOfClass:NSArray.class] || colorArray.count < 3) {
        return NO;
    }
    CGFloat r = [colorArray[0] doubleValue];
    CGFloat g = [colorArray[1] doubleValue];
    CGFloat b = [colorArray[2] doubleValue];
    return ((r + g + b) / 3.0) > 0.86;
}

static void PPBBCartApplyLottieRGBA(NSMutableArray *colorArray, NSArray<NSNumber *> *rgba) {
    if (![colorArray isKindOfClass:NSMutableArray.class] || colorArray.count < 3) {
        return;
    }
    colorArray[0] = rgba[0];
    colorArray[1] = rgba[1];
    colorArray[2] = rgba[2];
}

static void PPBBCartRetintLottieColorObject(NSMutableDictionary *colorObject,
                                            NSArray<NSNumber *> *primaryRGBA,
                                            NSArray<NSNumber *> *highlightRGBA) {
    if (![colorObject isKindOfClass:NSMutableDictionary.class]) {
        return;
    }

    id k = colorObject[@"k"];
    if ([k isKindOfClass:NSMutableArray.class]) {
        NSMutableArray *array = (NSMutableArray *)k;
        if (array.count >= 3 && [array[0] isKindOfClass:NSNumber.class]) {
            PPBBCartApplyLottieRGBA(array, PPBBCartLottieColorArrayIsLight(array) ? highlightRGBA : primaryRGBA);
            return;
        }

        for (id frame in array) {
            if (![frame isKindOfClass:NSMutableDictionary.class]) {
                continue;
            }
            NSMutableDictionary *frameDict = (NSMutableDictionary *)frame;
            for (NSString *key in @[@"s", @"e", @"k"]) {
                id value = frameDict[key];
                if ([value isKindOfClass:NSMutableArray.class]) {
                    NSMutableArray *colorArray = (NSMutableArray *)value;
                    PPBBCartApplyLottieRGBA(colorArray, PPBBCartLottieColorArrayIsLight(colorArray) ? highlightRGBA : primaryRGBA);
                }
            }
        }
    }
}

static void PPBBCartRetintLottieNode(id node,
                                     NSArray<NSNumber *> *primaryRGBA,
                                     NSArray<NSNumber *> *highlightRGBA) {
    if ([node isKindOfClass:NSMutableDictionary.class]) {
        NSMutableDictionary *dict = (NSMutableDictionary *)node;
        NSString *type = [dict[@"ty"] isKindOfClass:NSString.class] ? dict[@"ty"] : nil;
        if (([type isEqualToString:@"fl"] || [type isEqualToString:@"st"]) &&
            [dict[@"c"] isKindOfClass:NSMutableDictionary.class]) {
            PPBBCartRetintLottieColorObject(dict[@"c"], primaryRGBA, highlightRGBA);
        }
        for (id value in dict.allValues) {
            PPBBCartRetintLottieNode(value, primaryRGBA, highlightRGBA);
        }
    } else if ([node isKindOfClass:NSMutableArray.class]) {
        for (id value in (NSMutableArray *)node) {
            PPBBCartRetintLottieNode(value, primaryRGBA, highlightRGBA);
        }
    }
}

static NSDictionary *PPBBCartRetintedLottieJSON(NSDictionary *jsonDict) {
    if (![jsonDict isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:nil];
    if (!data) {
        return jsonDict;
    }
    id mutableJSON = [NSJSONSerialization JSONObjectWithData:data
                                                     options:NSJSONReadingMutableContainers
                                                       error:nil];
    if (![mutableJSON isKindOfClass:NSMutableDictionary.class]) {
        return jsonDict;
    }

    UIColor *primary = PPBBCartColor(AppPrimaryClr, UIColor.systemOrangeColor);
    UIColor *highlight = UIColor.whiteColor;
    PPBBCartRetintLottieNode(mutableJSON, PPBBCartLottieRGBA(primary), PPBBCartLottieRGBA(highlight));
    return mutableJSON;
}

@interface BBCartBottomBar ()
{
    UIStackView *topRow;
    UIStackView *bottomRow;
}
@property (nonatomic, strong) UIView *separator;
@property (nonatomic, strong) UIVisualEffectView *blurBackground;
@property (nonatomic, strong) UIButton *BackgroundB;
@property (nonatomic, strong) UIView *surfaceTintView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIStackView *priceStack;
@property (nonatomic, strong) UIView *successHaloView;
@property (nonatomic, strong) CAGradientLayer *buttonSheenLayer;
@property (nonatomic, strong) UIVisualEffectView *totalGlassBackgroundView;
@property (nonatomic, strong) UIVisualEffectView *qtyGlassBackgroundView;
@property (nonatomic, copy) NSString *idleAddToCartTitle;
@property (nonatomic, strong) UIImage *idleAddToCartImage;
@property (nonatomic, assign) BOOL didPrepareEntranceAnimation;
@property (nonatomic, assign) BOOL didRunEntranceAnimation;
@property (nonatomic, assign) CGFloat entranceTargetAlpha;
@property (nonatomic, assign) CGAffineTransform entranceTargetTransform;
@property (nonatomic, assign, getter=isRestoringButton) BOOL restoringButton;
@property (nonatomic, assign) BOOL usesCompactCartButton;
@property (nonatomic, strong) LOTAnimationView *showCartAnimationView;
@property (nonatomic, assign) BOOL showCartAnimationLoaded;
@property (nonatomic, assign) BOOL pendingShowCartAnimationPlayback;
@property (nonatomic, assign) NSInteger showCartAnimationToken;
@property (nonatomic, strong) PPInsetLabel *showCartBadgeLabel;
@property (nonatomic, assign) NSInteger showCartBadgeCount;
@end
@implementation BBCartBottomBar

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self setupUI];
    }
    return self;
}

-(void)layoutSubviews
{
    [super layoutSubviews];

    self.clipsToBounds = NO;
    [self pp_setShadowColor:AppShadowClr];
    self.layer.shadowOpacity = PPIOS26() ? 0.08 : 0.07;
    self.layer.shadowRadius = 16.0;
    self.layer.shadowOffset = CGSizeMake(0.0, -6.0);
    CGRect shadowFrame = CGRectIsEmpty(self.BackgroundB.frame) ? self.bounds : self.BackgroundB.frame;
    self.layer.shadowPath =
    [UIBezierPath bezierPathWithRect:shadowFrame].CGPath;

    CGFloat surfaceRadius = 0.0;
    self.BackgroundB.layer.cornerRadius = surfaceRadius;
    self.blurBackground.layer.cornerRadius = surfaceRadius;
    self.surfaceTintView.layer.cornerRadius = surfaceRadius;
    self.BackgroundB.layer.borderWidth = 0.0;
    self.totalContainer.layer.cornerRadius = PPBBCartTotalHeight() * 0.5;
    self.qtyContainer.layer.cornerRadius = PPBBCartControlHeight() * 0.5;
    [self pp_applyRoundButtonGeometry:self.showCartButton];
    [self pp_applyRoundButtonGeometry:self.favButton];
    [self pp_applyRoundButtonGeometry:self.minusButton];
    [self pp_applyRoundButtonGeometry:self.plusButton];
    [self pp_layoutGlassBackgrounds];
    self.buttonSheenLayer.frame = self.addToCartButton.bounds;
    [self pp_bringShowCartBadgeToFront];
    [self pp_runEntranceIfNeeded];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    [self pp_runEntranceIfNeeded];
}

- (void)pp_prepareEntranceState
{
    if (self.didPrepareEntranceAnimation || self.didRunEntranceAnimation) {
        return;
    }

    self.didPrepareEntranceAnimation = YES;
    self.entranceTargetAlpha = self.alpha > 0.01 ? self.alpha : 1.0;
    self.entranceTargetTransform = CGAffineTransformIdentity;
    self.alpha = 0.0;
    self.transform = CGAffineTransformMakeTranslation(0.0, 14.0);
    self.BackgroundB.transform = CGAffineTransformMakeScale(0.985, 0.985);
    self.contentStack.alpha = 0.0;
    self.contentStack.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
}

- (void)pp_runEntranceIfNeeded
{
    if (self.didRunEntranceAnimation || !self.window || self.hidden || self.bounds.size.height <= 0.0) {
        return;
    }

    [self pp_prepareEntranceState];
    CGAffineTransform preparedTransform = CGAffineTransformMakeTranslation(0.0, 14.0);
    if (!CGAffineTransformEqualToTransform(self.transform, preparedTransform)) {
        self.entranceTargetTransform = self.transform;
        self.transform = preparedTransform;
    }
    if (self.alpha > 0.01) {
        self.entranceTargetAlpha = self.alpha;
        self.alpha = 0.0;
    }
    self.didRunEntranceAnimation = YES;
    CGFloat targetAlpha = self.entranceTargetAlpha > 0.01 ? self.entranceTargetAlpha : 1.0;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.alpha = targetAlpha;
        self.transform = self.entranceTargetTransform;
        self.BackgroundB.transform = CGAffineTransformIdentity;
        self.contentStack.alpha = 1.0;
        self.contentStack.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.34
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.alpha = targetAlpha;
        self.transform = self.entranceTargetTransform;
        self.BackgroundB.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.42
                          delay:0.05
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.42
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.contentStack.alpha = 1.0;
        self.contentStack.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if (![self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            return;
        }
    }
    [self pp_refreshChromeColors];
}

- (void)pp_refreshChromeColors
{
    BOOL legacyIPadBar = PPBBCartUsesLegacyIPadBelowIOS18();
    self.BackgroundB.backgroundColor = PPBBCartSurfaceFillColor();
    [self.BackgroundB pp_setBorderColor:UIColor.clearColor];
    self.BackgroundB.layer.borderWidth = 0.0;
    self.surfaceTintView.backgroundColor = legacyIPadBar
        ? [UIColor colorWithWhite:1.0 alpha:0.04]
        : PPBBCartSurfaceTintColor();
    self.separator.hidden = YES;
    self.separator.backgroundColor = UIColor.clearColor;

    self.totalContainer.backgroundColor = AppForgroundColr;
    [self.totalContainer pp_setBorderColor:UIColor.clearColor];
    self.totalContainer.layer.borderWidth = 0.0;
    
    
    self.qtyContainer.backgroundColor = AppForgroundColr;
    [self.qtyContainer pp_setBorderColor:UIColor.clearColor];
    self.qtyContainer.layer.borderWidth = 0.0;
    [self pp_applyCheckoutControlDepth:self.totalContainer emphasized:YES];
    [self pp_applyCheckoutControlDepth:self.qtyContainer emphasized:NO];
    [self pp_applyGlassBackgroundChrome];
    [self pp_styleUtilityButton:self.showCartButton];
    [self pp_styleUtilityButton:self.favButton];
    [self pp_updateShowCartBadgeStyle];

    self.countLabel.textColor = PPBBCartColor(AppPrimaryClr, UIColor.labelColor);
    self.amountLabel.textColor = PPBBCartColor(AppPrimaryTextClr, UIColor.labelColor);
    self.totalLabel.textColor = PPBBCartColor(AppSecondaryTextClr, UIColor.secondaryLabelColor);
    self.currencyLabel.textColor = PPBBCartColor(AppSecondaryTextClr, UIColor.secondaryLabelColor);
}

- (void)pp_applyRoundButtonGeometry:(UIButton *)button
{
    if (!button) {
        return;
    }
    CGFloat side = MIN(CGRectGetWidth(button.bounds), CGRectGetHeight(button.bounds));
    if (side <= 0.0) {
        side = PPBBCartUtilityButtonSize();
    }
    button.layer.cornerRadius = side * 0.5;
    button.layer.masksToBounds = YES;
    button.clipsToBounds = YES;
}

- (void)pp_applyCheckoutControlDepth:(UIView *)view emphasized:(BOOL)emphasized
{
    if (!view) {
        return;
    }
    [view pp_setShadowColor:AppShadowClr];
    view.layer.shadowOpacity = PPIOS26() ? (emphasized ? 0.12 : 0.08) : (emphasized ? 0.08 : 0.05);
    view.layer.shadowRadius = PPIOS26() ? (emphasized ? 13.0 : 9.0) : (emphasized ? 8.0 : 6.0);
    view.layer.shadowOffset = CGSizeMake(0.0, PPIOS26() ? 4.0 : 3.0);
}

- (UIVisualEffectView *)pp_makeUltraThinBlurView
{
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:PPBBCartUltraThinBlurStyle()];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.userInteractionEnabled = NO;
    blurView.clipsToBounds = YES;
    blurView.backgroundColor = UIColor.clearColor;
    return blurView;
}

- (void)pp_pinViewToEdges:(UIView *)view ofView:(UIView *)container
{
    if (!view || !container) {
        return;
    }
    [NSLayoutConstraint activateConstraints:@[
        [view.topAnchor constraintEqualToAnchor:container.topAnchor],
        [view.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [view.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [view.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];
}

- (void)pp_applyGlassBackgroundChrome
{
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:PPBBCartUltraThinBlurStyle()];
    self.blurBackground.effect = effect;
    self.totalGlassBackgroundView.effect = effect;
    self.qtyGlassBackgroundView.effect = effect;
    self.totalGlassBackgroundView.alpha = PPBBCartUsesLegacyIPadBelowIOS18() ? 0.78 : 0.86;
    self.qtyGlassBackgroundView.alpha = PPBBCartUsesLegacyIPadBelowIOS18() ? 0.74 : 0.82;
    [self pp_layoutGlassBackgrounds];
}

- (void)pp_layoutGlassBackgrounds
{
    CGFloat totalRadius = CGRectGetHeight(self.totalContainer.bounds) > 0.0
        ? CGRectGetHeight(self.totalContainer.bounds) * 0.5
        : PPBBCartTotalHeight() * 0.5;
    CGFloat qtyRadius = CGRectGetHeight(self.qtyContainer.bounds) > 0.0
        ? CGRectGetHeight(self.qtyContainer.bounds) * 0.5
        : PPBBCartControlHeight() * 0.5;

    self.totalContainer.layer.masksToBounds = NO;
    self.totalContainer.clipsToBounds = NO;
    self.qtyContainer.layer.masksToBounds = NO;
    self.qtyContainer.clipsToBounds = NO;
    self.totalGlassBackgroundView.layer.cornerRadius = totalRadius;
    self.qtyGlassBackgroundView.layer.cornerRadius = qtyRadius;
    if (@available(iOS 13.0, *)) {
        self.totalGlassBackgroundView.layer.cornerCurve = kCACornerCurveContinuous;
        self.qtyGlassBackgroundView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    [self.totalContainer bringSubviewToFront:self.priceStack];
    [self.qtyContainer bringSubviewToFront:self.qtyStack];

    if (!CGRectIsEmpty(self.totalContainer.bounds)) {
        self.totalContainer.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.totalContainer.bounds cornerRadius:totalRadius].CGPath;
    }
    if (!CGRectIsEmpty(self.qtyContainer.bounds)) {
        self.qtyContainer.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.qtyContainer.bounds cornerRadius:qtyRadius].CGPath;
    }
}


- (void)setupUI {
    self.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = GM.setSemantic;
    self.usesCompactCartButton = YES;
    BOOL legacyIPadBar = PPBBCartUsesLegacyIPadBelowIOS18();

    [self pp_buildSurface];

    _minusButton = [self circleButtonWithTitle:@"-"];
    _minusButton.accessibilityLabel = kLang(@"a11y_btn_decrease_qty");
    [_minusButton addTarget:self action:@selector(decreaseQuantity) forControlEvents:UIControlEventTouchUpInside];

    _plusButton = [self circleButtonWithTitle:@"+"];
    _plusButton.accessibilityLabel = kLang(@"a11y_btn_increase_qty");
    [_plusButton addTarget:self action:@selector(increaseQuantity) forControlEvents:UIControlEventTouchUpInside];

    _countLabel = [[UILabel alloc] init];
    _countLabel.text = @"1";
    _countLabel.font = [GM boldFontWithSize:(legacyIPadBar ? 16.0 : 17.0)] ?: [UIFont systemFontOfSize:(legacyIPadBar ? 16.0 : 17.0) weight:UIFontWeightSemibold];
    _countLabel.textAlignment = NSTextAlignmentCenter;
    _countLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _countLabel.textColor = PPBBCartColor(AppPrimaryClr, UIColor.labelColor);
    _countLabel.adjustsFontSizeToFitWidth = YES;
    _countLabel.adjustsFontForContentSizeCategory = YES;
    _countLabel.minimumScaleFactor = 0.72;
    _countLabel.isAccessibilityElement = YES;
    _countLabel.accessibilityLabel = kLang(@"a11y_cart_qty_stepper");
    [_countLabel.widthAnchor constraintGreaterThanOrEqualToConstant:(legacyIPadBar ? 24.0 : 28.0)].active = YES;

    _totalLabel = [[PPInsetLabel alloc] init];
    _totalLabel.text = kLang(@"OrderTotal");
    _totalLabel.font = [GM MidFontWithSize:(legacyIPadBar ? 13.5 : 15.0)] ?: [UIFont systemFontOfSize:(legacyIPadBar ? 13.5 : 15.0) weight:UIFontWeightMedium];
    _totalLabel.textColor = PPBBCartColor(AppSecondaryTextClr, UIColor.secondaryLabelColor);
    _totalLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _totalLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _totalLabel.adjustsFontForContentSizeCategory = YES;

    _amountLabel = [[PPInsetLabel alloc] init];
    _amountLabel.text = [self pp_priceStringFromAmount:_itemAmount];
    _amountLabel.font = [GM boldFontWithSize:(legacyIPadBar ? 25.0 : 28.0)] ?: [UIFont systemFontOfSize:(legacyIPadBar ? 25.0 : 28.0) weight:UIFontWeightBold];
    _amountLabel.textColor = PPBBCartColor(AppPrimaryTextClr, UIColor.labelColor);
    _amountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _amountLabel.adjustsFontSizeToFitWidth = YES;
    _amountLabel.adjustsFontForContentSizeCategory = YES;
    _amountLabel.minimumScaleFactor = 0.72;
    _amountLabel.numberOfLines = 1;

    _currencyLabel = [[PPInsetLabel alloc] init];
    _currencyLabel.text = kLang(@"Rials");
    _currencyLabel.font = [GM MidFontWithSize:(legacyIPadBar ? 12.5 : 14.0)] ?: [UIFont systemFontOfSize:(legacyIPadBar ? 12.5 : 14.0) weight:UIFontWeightMedium];
    _currencyLabel.textColor = PPBBCartColor(AppSecondaryTextClr, UIColor.secondaryLabelColor);
    _currencyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _currencyLabel.adjustsFontForContentSizeCategory = YES;

    _priceStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        _totalLabel,
        _amountLabel,
        _currencyLabel
    ]];
    _priceStack.axis = UILayoutConstraintAxisHorizontal;
    _priceStack.alignment = UIStackViewAlignmentFirstBaseline;
    _priceStack.spacing = PPSpaceXS;
    _priceStack.translatesAutoresizingMaskIntoConstraints = NO;
    _priceStack.semanticContentAttribute = GM.setSemantic;

    _totalContainer = [UIButton buttonWithType:UIButtonTypeCustom];
    _totalContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _totalContainer.userInteractionEnabled = YES;
    _totalContainer.isAccessibilityElement = YES;
    _totalContainer.accessibilityTraits = UIAccessibilityTraitStaticText;
    _totalContainer.backgroundColor = PPBBCartBadgeFillColor();
    PPApplyContinuousCorners(_totalContainer, 22.0);
    [_totalContainer pp_setBorderColor:UIColor.clearColor];
    _totalContainer.layer.borderWidth = 0.0;
    self.totalGlassBackgroundView = [self pp_makeUltraThinBlurView];
    [_totalContainer addSubview:self.totalGlassBackgroundView];
    [self pp_pinViewToEdges:self.totalGlassBackgroundView ofView:_totalContainer];
    [_totalContainer addSubview:_priceStack];

    _addToCartButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _addToCartButton.translatesAutoresizingMaskIntoConstraints = NO;
    _addToCartButton.clipsToBounds = YES;
    _addToCartButton.layer.masksToBounds = YES;
    _addToCartButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    _addToCartButton.titleLabel.minimumScaleFactor = 0.74;
    _addToCartButton.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _addToCartButton.accessibilityTraits = UIAccessibilityTraitButton;
    _addToCartButton.accessibilityLabel = kLang(@"a11y_btn_add_to_cart");
    _addToCartButton.accessibilityHint = kLang(@"a11y_btn_add_to_cart_hint");
    [_addToCartButton addTarget:self action:@selector(addToCartTapped)
               forControlEvents:UIControlEventTouchUpInside];
    self.idleAddToCartTitle = kLang(@"addToCart");
    self.idleAddToCartImage = PPBBCartSymbol(@"cart.badge.plus", 18.0, UIImageSymbolWeightSemibold, UIColor.whiteColor);
    
    self.usesCompactCartButton = NO;
    
    [self pp_setAddToCartTitle:self.idleAddToCartTitle
                    imageName:@"cart.badge.plus"
                    foreground:UIColor.whiteColor
                    background:PPBBCartColor(AppPrimaryClr, UIColor.systemBlueColor)];
    PPApplyButtonShadow(_addToCartButton);
    
    _showCartButton = [PPButtonHelper buttonWithSystemName:@"cart" target:self action:@selector(cartClick)];
    _showCartButton.translatesAutoresizingMaskIntoConstraints = NO;
   
    _showCartButton.accessibilityLabel = kLang(@"Cart");
    [self pp_styleUtilityButton:_showCartButton];
    
    CGFloat utilitySize = PPBBCartUtilityButtonSize();
    [_showCartButton.widthAnchor constraintEqualToConstant:utilitySize].active = YES;
    [_showCartButton.heightAnchor constraintEqualToConstant:utilitySize].active = YES;
    [self pp_setupShowCartLottieAnimation];

    _qtyStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        _minusButton, _countLabel, _plusButton
    ]];
    _qtyStack.axis = UILayoutConstraintAxisHorizontal;
    _qtyStack.spacing = PPSpaceXS;
    _qtyStack.alignment = UIStackViewAlignmentCenter;
    _qtyStack.distribution = UIStackViewDistributionEqualCentering;
    _qtyStack.translatesAutoresizingMaskIntoConstraints = NO;
    _qtyStack.semanticContentAttribute = GM.setSemantic;

    _qtyContainer = [UIButton buttonWithType:UIButtonTypeCustom];
    _qtyContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _qtyContainer.backgroundColor = PPBBCartControlFillColor();
    PPApplyContinuousCorners(_qtyContainer, 25.0);
    [_qtyContainer pp_setBorderColor:UIColor.clearColor];
    _qtyContainer.layer.borderWidth = 0.0;
    _qtyContainer.isAccessibilityElement = NO;
    self.qtyGlassBackgroundView = [self pp_makeUltraThinBlurView];
    [_qtyContainer addSubview:self.qtyGlassBackgroundView];
    [self pp_pinViewToEdges:self.qtyGlassBackgroundView ofView:_qtyContainer];
    [_qtyContainer addSubview:_qtyStack];

    self.favButton = [PPButtonHelper buttonWithSystemName:@"square.and.arrow.up" target:self action:@selector(sharaAccesee)];
    self.favButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.favButton.accessibilityLabel = kLang(@"Share");
    [self pp_styleUtilityButton:self.favButton];

    [_favButton.widthAnchor constraintEqualToConstant:utilitySize].active = YES;
    [_favButton.heightAnchor constraintEqualToConstant:utilitySize].active = YES;

    self.cartItemquantity = 1;
    [self pp_buildLayoutRows];
    [self pp_setupShowCartBadge];
    [self pp_refreshChromeColors];
    [self updateQuantityUI];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleCartUpdatedNotification:)
                                                 name:kCartUpdatedNotification
                                               object:nil];
    [self pp_refreshShowCartBadgeAnimated:NO];
    [self pp_updateTotalAccessibility];
    [self pp_prepareEntranceState];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(pp_restoreAddToCartButton) object:nil];
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
                                         from:self.parentContainerViewController
                                     animated:YES
                                   completion:nil];
}

- (void)pp_setupShowCartLottieAnimation
{
    if (self.showCartAnimationView || !self.showCartButton) {
        return;
    }

    LOTAnimationView *animationView = [[LOTAnimationView alloc] init];
    animationView.translatesAutoresizingMaskIntoConstraints = NO;
    animationView.userInteractionEnabled = NO;
    animationView.contentMode = UIViewContentModeScaleAspectFit;
    animationView.backgroundColor = UIColor.clearColor;
    animationView.opaque = NO;
    animationView.loopAnimation = NO;
    animationView.hidden = YES;
    animationView.alpha = 0.0;
    [self.showCartButton addSubview:animationView];
    [NSLayoutConstraint activateConstraints:@[
        [animationView.centerXAnchor constraintEqualToAnchor:self.showCartButton.centerXAnchor],
        [animationView.centerYAnchor constraintEqualToAnchor:self.showCartButton.centerYAnchor],
        [animationView.widthAnchor constraintEqualToConstant:44.0],
        [animationView.heightAnchor constraintEqualToConstant:44.0]
    ]];
    self.showCartAnimationView = animationView;

    __weak typeof(self) weakSelf = self;
    [AppClasses fetchLottieJSONFromFirebasePath:@"LottieAnimations/Cart.json"
                                     completion:^(NSDictionary * _Nonnull jsonDict, NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            if (error || ![jsonDict isKindOfClass:NSDictionary.class]) {
                NSLog(@"BBCartBottomBar Lottie failed: %@", error.localizedDescription ?: @"Invalid JSON");
                self.pendingShowCartAnimationPlayback = NO;
                return;
            }

            NSDictionary *visibleJSON = PPBBCartRetintedLottieJSON(jsonDict) ?: jsonDict;
            LOTComposition *composition = [LOTComposition animationFromJSON:visibleJSON];
            if (!composition) {
                self.pendingShowCartAnimationPlayback = NO;
                return;
            }

            self.showCartAnimationLoaded = YES;
            [self.showCartAnimationView setSceneModel:composition];
            self.showCartAnimationView.animationSpeed = 1.15;
            self.showCartAnimationView.animationProgress = 0.0;

            if (self.pendingShowCartAnimationPlayback) {
                self.pendingShowCartAnimationPlayback = NO;
                [self pp_playShowCartLottieAnimation];
            }
        });
    }];
}

- (void)pp_flashShowCartButton
{
    [UIView animateWithDuration:0.12
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.showCartButton.transform = CGAffineTransformMakeScale(1.07, 1.07);
        self.showCartButton.alpha = 0.92;
    } completion:^(__unused BOOL finished) {
        [UIView animateWithDuration:0.24
                              delay:0.0
             usingSpringWithDamping:0.70
              initialSpringVelocity:0.36
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.showCartButton.transform = CGAffineTransformIdentity;
            self.showCartButton.alpha = 1.0;
        } completion:nil];
    }];
}

- (void)pp_playShowCartLottieAnimation
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (UIAccessibilityIsReduceMotionEnabled()) {
            [self pp_flashShowCartButton];
            return;
        }

        if (!self.showCartAnimationLoaded || !self.showCartAnimationView.sceneModel) {
            self.pendingShowCartAnimationPlayback = YES;
            [self pp_flashShowCartButton];
            return;
        }

        self.showCartAnimationToken += 1;
        NSInteger token = self.showCartAnimationToken;
        LOTAnimationView *animationView = self.showCartAnimationView;

        [animationView stop];
        animationView.loopAnimation = NO;
        animationView.animationProgress = 0.0;
        animationView.hidden = NO;
        animationView.alpha = 1.0;
        animationView.transform = CGAffineTransformMakeScale(0.92, 0.92);
        [self.showCartButton bringSubviewToFront:animationView];
        [self pp_bringShowCartBadgeToFront];
        self.showCartButton.imageView.alpha = 0.22;

        [UIView animateWithDuration:0.18
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            animationView.transform = CGAffineTransformIdentity;
            self.showCartButton.transform = CGAffineTransformMakeScale(1.045, 1.045);
        } completion:^(__unused BOOL finished) {
            [UIView animateWithDuration:0.26
                                  delay:0.0
                 usingSpringWithDamping:0.72
                  initialSpringVelocity:0.38
                                options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                self.showCartButton.transform = CGAffineTransformIdentity;
            } completion:nil];
        }];

        __weak typeof(self) weakSelf = self;
        [animationView playWithCompletion:^(BOOL finished) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self || self.showCartAnimationToken != token) {
                    return;
                }

                [UIView animateWithDuration:0.18
                                      delay:finished ? 0.04 : 0.0
                                    options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                                 animations:^{
                    self.showCartAnimationView.alpha = 0.0;
                    self.showCartAnimationView.transform = CGAffineTransformMakeScale(0.92, 0.92);
                    self.showCartButton.imageView.alpha = 1.0;
                    self.showCartButton.alpha = 1.0;
                } completion:^(__unused BOOL done) {
                    self.showCartAnimationView.hidden = YES;
                    self.showCartAnimationView.transform = CGAffineTransformIdentity;
                    self.showCartAnimationView.animationProgress = 0.0;
                    [self pp_bringShowCartBadgeToFront];
                }];
            });
        }];
    });
}

- (void)pp_setupShowCartBadge
{
    if (self.showCartBadgeLabel || !self.showCartButton) {
        return;
    }

    PPInsetLabel *badgeLabel = [[PPInsetLabel alloc] init];
    badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    badgeLabel.textAlignment = NSTextAlignmentCenter;
    badgeLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
    badgeLabel.textColor = UIColor.whiteColor;
    badgeLabel.textInsets = UIEdgeInsetsMake(1.0, 5.0, 1.0, 5.0);
    badgeLabel.adjustsFontSizeToFitWidth = YES;
    badgeLabel.minimumScaleFactor = 0.72;
    badgeLabel.hidden = YES;
    badgeLabel.alpha = 0.0;
    badgeLabel.userInteractionEnabled = NO;
    badgeLabel.layer.cornerRadius = 9.0;
    badgeLabel.layer.masksToBounds = YES;
    badgeLabel.layer.borderWidth = 1.0;
    [self addSubview:badgeLabel];
    [NSLayoutConstraint activateConstraints:@[
        [badgeLabel.bottomAnchor constraintEqualToAnchor:self.showCartButton.topAnchor constant:6.0],
        [badgeLabel.centerXAnchor constraintEqualToAnchor:self.showCartButton.trailingAnchor constant:-4.0],
        [badgeLabel.heightAnchor constraintEqualToConstant:18.0],
        [badgeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:18.0]
    ]];

    self.showCartBadgeLabel = badgeLabel;
    self.showCartButton.clipsToBounds = NO;
    [self pp_updateShowCartBadgeStyle];
    [self pp_bringShowCartBadgeToFront];
}

- (void)pp_updateShowCartBadgeStyle
{
    if (!self.showCartBadgeLabel) {
        return;
    }
    UIColor *badgeColor = PPBBCartColor(AppPrimaryClr, UIColor.systemRedColor);
    self.showCartBadgeLabel.backgroundColor = badgeColor;
    [self.showCartBadgeLabel pp_setBorderColor:[UIColor.whiteColor colorWithAlphaComponent:0.72]];
}

- (NSString *)pp_showCartBadgeTextForCount:(NSInteger)count
{
    if (count <= 0) {
        return nil;
    }
    return count > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)count];
}

- (void)pp_handleCartUpdatedNotification:(NSNotification *)notification
{
    (void)notification;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self pp_refreshShowCartBadgeAnimated:YES];
    });
}

- (void)pp_refreshShowCartBadgeAnimated:(BOOL)animated
{
    NSInteger totalCount = MAX([[CartManager sharedManager] totalItemsCount], 0);
    NSString *badgeText = [self pp_showCartBadgeTextForCount:totalCount];
    BOOL shouldShow = badgeText.length > 0;
    BOOL wasHidden = self.showCartBadgeLabel.hidden || self.showCartBadgeLabel.alpha <= 0.01;
    BOOL countChanged = (self.showCartBadgeCount != totalCount);
    self.showCartBadgeCount = totalCount;
    self.showCartBadgeLabel.text = badgeText;
    [self.showCartBadgeLabel invalidateIntrinsicContentSize];
    [self pp_bringShowCartBadgeToFront];

    self.showCartButton.accessibilityLabel = kLang(@"Cart");
    self.showCartButton.accessibilityValue = shouldShow ? badgeText : nil;

    if (!shouldShow) {
        if (!animated || wasHidden) {
            self.showCartBadgeLabel.hidden = YES;
            self.showCartBadgeLabel.alpha = 0.0;
            self.showCartBadgeLabel.transform = CGAffineTransformIdentity;
            return;
        }

        [UIView animateWithDuration:0.18
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            self.showCartBadgeLabel.alpha = 0.0;
            self.showCartBadgeLabel.transform = CGAffineTransformMakeScale(0.78, 0.78);
        } completion:^(__unused BOOL finished) {
            self.showCartBadgeLabel.hidden = YES;
            self.showCartBadgeLabel.transform = CGAffineTransformIdentity;
        }];
        return;
    }

    self.showCartBadgeLabel.hidden = NO;
    if (!animated) {
        self.showCartBadgeLabel.alpha = 1.0;
        self.showCartBadgeLabel.transform = CGAffineTransformIdentity;
        return;
    }

    if (wasHidden) {
        self.showCartBadgeLabel.alpha = 0.0;
        self.showCartBadgeLabel.transform = CGAffineTransformMakeScale(0.72, 0.72);
    } else if (countChanged) {
        self.showCartBadgeLabel.transform = CGAffineTransformMakeScale(1.16, 1.16);
    }

    [UIView animateWithDuration:0.30
                          delay:0.0
         usingSpringWithDamping:0.68
          initialSpringVelocity:0.44
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.showCartBadgeLabel.alpha = 1.0;
        self.showCartBadgeLabel.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_bringShowCartBadgeToFront
{
    if (self.showCartBadgeLabel.superview) {
        [self.showCartBadgeLabel.superview bringSubviewToFront:self.showCartBadgeLabel];
    }
}


-(void)sharaAccesee
{
    
}
//NSString *FavCollection = context == PPCellForAds ? @"favoritesAds" : context == PPCellForMarket? @"favoritesAccess" : context == PPCellForVets ? @"favoritesVets" : @"favoritesServices" ;
//[self setFavForCollection:FavCollection andID:vm.ModelID andButton:self.favButton];
-(void)setFavForCollection:(NSString *)collection andID:(NSString *)ID andButton:(FavoriteFixedSizeButton *)favButton
{//favoritesAds
    
    if(!UserManager.sharedManager.isUserLoggedIn) return;
    
    favButton.adID = ID;
    favButton.collection = collection;
    [favButton initValue];
}


#pragma mark - Button Factory

- (UIButton *)circleButtonWithTitle:(NSString *)title {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.accessibilityTraits = UIAccessibilityTraitButton;
    CGFloat buttonSize = PPBBCartStepperButtonSize();
    CGFloat symbolPointSize = PPBBCartUsesLegacyIPadBelowIOS18() ? 14.0 : 15.0;
    NSString *symbolName = [title isEqualToString:@"-"] ? @"minus" : ([title isEqualToString:@"+"] ? @"plus" : title);
    UIImage *symbolImage = PPBBCartSymbol(symbolName, symbolPointSize, UIImageSymbolWeightSemibold, PPBBCartColor(AppPrimaryClr, UIColor.labelColor));
    UIColor *fillColor = [PPBBCartColor(AppBackgroundClr, UIColor.systemBackgroundColor) colorWithAlphaComponent:PPIOS26() ? 0.16 : 0.28];

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.baseForegroundColor = PPBBCartColor(AppPrimaryClr, UIColor.labelColor);
        config.baseBackgroundColor = fillColor;
        config.background.backgroundColor = fillColor;
        config.background.cornerRadius = buttonSize * 0.5;
        config.background.strokeWidth = 0.0;
        config.background.strokeColor = UIColor.clearColor;
        config.image = symbolImage;
        config.contentInsets = NSDirectionalEdgeInsetsMake(0.0, 0.0, 0.0, 0.0);
        btn.configuration = config;
    } else {
        [btn setImage:symbolImage forState:UIControlStateNormal];
        [btn setTitleColor:PPBBCartColor(AppPrimaryClr, UIColor.labelColor) forState:UIControlStateNormal];
    }

    btn.backgroundColor = fillColor;
    PPApplyContinuousCorners(btn, buttonSize * 0.5);
    [btn pp_setBorderColor:UIColor.clearColor];
    btn.layer.borderWidth = 0.0;
    btn.layer.masksToBounds = YES;
    btn.clipsToBounds = YES;
    [btn.widthAnchor constraintEqualToConstant:buttonSize].active = YES;
    [btn.heightAnchor constraintEqualToConstant:buttonSize].active = YES;

    return btn;
}

- (void)pp_buildSurface {
    self.BackgroundB = [UIButton buttonWithType:UIButtonTypeCustom];
    self.BackgroundB.translatesAutoresizingMaskIntoConstraints = NO;
    self.BackgroundB.userInteractionEnabled = YES;
    self.BackgroundB.isAccessibilityElement = NO;
    self.BackgroundB.backgroundColor = PPBBCartSurfaceFillColor();
    self.BackgroundB.layer.cornerRadius = 0.0;
    [self.BackgroundB pp_setBorderColor:UIColor.clearColor];
    self.BackgroundB.layer.borderWidth = 0.0;
    self.BackgroundB.clipsToBounds = YES;
    [self addSubview:self.BackgroundB];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:PPBBCartUltraThinBlurStyle()];
    self.blurBackground = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.blurBackground.translatesAutoresizingMaskIntoConstraints = NO;
    self.blurBackground.userInteractionEnabled = NO;
    self.blurBackground.clipsToBounds = YES;
    self.blurBackground.layer.cornerRadius = 0.0;
    [self.BackgroundB addSubview:self.blurBackground];

    self.surfaceTintView = [[UIView alloc] init];
    self.surfaceTintView.translatesAutoresizingMaskIntoConstraints = NO;
    self.surfaceTintView.userInteractionEnabled = NO;
    self.surfaceTintView.backgroundColor = PPBBCartSurfaceTintColor();
    self.surfaceTintView.clipsToBounds = YES;
    self.surfaceTintView.layer.cornerRadius = 0.0;
    [self.BackgroundB addSubview:self.surfaceTintView];

    self.separator = [[UIView alloc] init];
    self.separator.translatesAutoresizingMaskIntoConstraints = NO;
    self.separator.hidden = YES;
    self.separator.backgroundColor = UIColor.clearColor;
    [self.BackgroundB addSubview:self.separator];

    CGFloat horizontalInset = PPBBCartSurfaceHorizontalInset();
    CGFloat bottomInset = PPBBCartSurfaceBottomInset();
    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray array];
    if (self.blurBackground) {
        [constraints addObjectsFromArray:@[
            [self.blurBackground.topAnchor constraintEqualToAnchor:self.BackgroundB.topAnchor],
            [self.blurBackground.leadingAnchor constraintEqualToAnchor:self.BackgroundB.leadingAnchor],
            [self.blurBackground.trailingAnchor constraintEqualToAnchor:self.BackgroundB.trailingAnchor],
            [self.blurBackground.bottomAnchor constraintEqualToAnchor:self.BackgroundB.bottomAnchor]
        ]];
    }

    [constraints addObjectsFromArray:@[
        [self.BackgroundB.topAnchor constraintEqualToAnchor:self.topAnchor constant:0.0],
        [self.BackgroundB.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:horizontalInset],
        [self.BackgroundB.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-horizontalInset],
        [self.BackgroundB.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-bottomInset],

        [self.surfaceTintView.topAnchor constraintEqualToAnchor:self.BackgroundB.topAnchor],
        [self.surfaceTintView.leadingAnchor constraintEqualToAnchor:self.BackgroundB.leadingAnchor],
        [self.surfaceTintView.trailingAnchor constraintEqualToAnchor:self.BackgroundB.trailingAnchor],
        [self.surfaceTintView.bottomAnchor constraintEqualToAnchor:self.BackgroundB.bottomAnchor],

        [self.separator.topAnchor constraintEqualToAnchor:self.BackgroundB.topAnchor],
        [self.separator.leadingAnchor constraintEqualToAnchor:self.BackgroundB.leadingAnchor constant:PPSpaceXL],
        [self.separator.trailingAnchor constraintEqualToAnchor:self.BackgroundB.trailingAnchor constant:-PPSpaceXL],
        [self.separator.heightAnchor constraintEqualToConstant:0.6]
    ]];

    [NSLayoutConstraint activateConstraints:constraints];
}

- (void)pp_buildLayoutRows {
    [self.contentStack removeFromSuperview];
    [self.addToCartButton removeFromSuperview];
    [self.favButton removeFromSuperview];
    [self.showCartButton removeFromSuperview];
    [self.totalContainer removeFromSuperview];
    [self.qtyContainer removeFromSuperview];
    BOOL legacyIPadBar = PPBBCartUsesLegacyIPadBelowIOS18();
    CGFloat contentInset = PPBBCartContentInset();
    CGFloat controlHeight = PPBBCartControlHeight();
    CGFloat rowSpacing = PPBBCartRowSpacing();
    CGFloat priceVerticalInset = legacyIPadBar ? 4.0 : 5.0;
    CGFloat stepperVerticalInset = 2.0;
    CGFloat stepperHorizontalInset = legacyIPadBar ? 5.0 : 6.0;
    
    [NSLayoutConstraint activateConstraints:@[
        [self.priceStack.topAnchor constraintEqualToAnchor:self.totalContainer.topAnchor constant:priceVerticalInset],
        [self.priceStack.bottomAnchor constraintEqualToAnchor:self.totalContainer.bottomAnchor constant:-priceVerticalInset],
        [self.priceStack.centerXAnchor constraintEqualToAnchor:self.totalContainer.centerXAnchor],
        [self.priceStack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.totalContainer.leadingAnchor constant:PPSpaceSM],
        [self.priceStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.totalContainer.trailingAnchor constant:-PPSpaceSM],

        [self.qtyStack.topAnchor constraintEqualToAnchor:self.qtyContainer.topAnchor constant:stepperVerticalInset],
        [self.qtyStack.bottomAnchor constraintEqualToAnchor:self.qtyContainer.bottomAnchor constant:-stepperVerticalInset],
        [self.qtyStack.leadingAnchor constraintEqualToAnchor:self.qtyContainer.leadingAnchor constant:stepperHorizontalInset],
        [self.qtyStack.trailingAnchor constraintEqualToAnchor:self.qtyContainer.trailingAnchor constant:-stepperHorizontalInset],

        [self.qtyContainer.widthAnchor constraintEqualToConstant:PPBBCartQuantityWidth()],
        [self.qtyContainer.heightAnchor constraintEqualToConstant:controlHeight],
        [self.totalContainer.heightAnchor constraintEqualToConstant:PPBBCartTotalHeight()]
    ]];

    topRow = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.totalContainer,
        self.qtyContainer
    ]];
    topRow.axis = UILayoutConstraintAxisHorizontal;
    topRow.spacing = rowSpacing;
    topRow.alignment = UIStackViewAlignmentCenter;
    topRow.distribution = UIStackViewDistributionFill;
    topRow.semanticContentAttribute = GM.setSemantic;
    topRow.translatesAutoresizingMaskIntoConstraints = NO;

    bottomRow = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.favButton,
        self.addToCartButton,
        self.showCartButton
    ]];
    bottomRow.axis = UILayoutConstraintAxisHorizontal;
    bottomRow.spacing = rowSpacing;
    bottomRow.alignment = UIStackViewAlignmentCenter;
    bottomRow.distribution = UIStackViewDistributionFill;
    bottomRow.semanticContentAttribute = GM.setSemantic;
    bottomRow.translatesAutoresizingMaskIntoConstraints = NO;

    [self.totalContainer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.totalContainer setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    
    [self.favButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.showCartButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    
    [self.addToCartButton setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.addToCartButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.qtyContainer setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.addToCartButton.heightAnchor constraintEqualToConstant:PPBBCartAddButtonHeight()].active = YES;
    self.contentStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        topRow,
        bottomRow
    ]];
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = rowSpacing;
    self.contentStack.alignment = UIStackViewAlignmentFill;
    self.contentStack.distribution = UIStackViewDistributionFill;
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.BackgroundB addSubview:self.contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.contentStack.topAnchor constraintEqualToAnchor:self.BackgroundB.topAnchor constant:contentInset],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.BackgroundB.leadingAnchor constant:PPSpaceMD],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.BackgroundB.trailingAnchor constant:-PPSpaceMD],
        [self.contentStack.bottomAnchor constraintLessThanOrEqualToAnchor:self.BackgroundB.bottomAnchor constant:-contentInset]
    ]];
}

- (void)pp_styleUtilityButton:(UIButton *)button {
    UIColor *fillColor = [PPBBCartColor(AppBackgroundClr, UIColor.systemBackgroundColor) colorWithAlphaComponent:PPIOS26() ? 0.18 : 0.30];
    button.backgroundColor = fillColor;
    button.tintColor = PPBBCartColor(AppPrimaryTextClr, UIColor.labelColor);
    PPApplyContinuousCorners(button, PPBBCartUtilityButtonSize() * 0.5);
    [button pp_setBorderColor:UIColor.clearColor];
    button.layer.borderWidth = 0.0;
    button.layer.cornerRadius = PPBBCartUtilityButtonSize() * 0.5;
    button.layer.masksToBounds = YES;
    button.clipsToBounds = YES;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *cfg = button.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
        cfg.baseForegroundColor = PPBBCartColor(AppPrimaryTextClr, UIColor.labelColor);
        cfg.baseBackgroundColor = fillColor;
        cfg.background.backgroundColor = fillColor;
        cfg.background.cornerRadius = PPBBCartUtilityButtonSize() * 0.5;
        cfg.background.strokeWidth = 0.0;
        cfg.background.strokeColor = UIColor.clearColor;
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(0.0, 0.0, 0.0, 0.0);
        button.configuration = cfg;
    }
}

- (NSString *)pp_priceStringFromAmount:(CGFloat)amount {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.minimumFractionDigits = 2;
    formatter.maximumFractionDigits = 2;
    formatter.locale = NSLocale.currentLocale;
    return [formatter stringFromNumber:@(amount)] ?: [NSString stringWithFormat:@"%.2f", amount];
}

- (void)pp_updateTotalAccessibility {
    NSString *amountText = self.amountLabel.text ?: @"";
    NSString *currencyText = self.currencyLabel.text ?: @"";
    self.totalContainer.accessibilityLabel = kLang(@"OrderTotal");
    self.totalContainer.accessibilityValue = [NSString stringWithFormat:@"%@ %@", amountText, currencyText];
}

- (void)pp_setAddToCartTitle:(NSString *)title
                   imageName:(NSString *)imageName
                  foreground:(UIColor *)foreground
                  background:(UIColor *)background {
    NSString *resolvedTitle = title.length ? title : kLang(@"addToCart");
    UIColor *resolvedForeground = PPBBCartColor(foreground, UIColor.whiteColor);
    UIColor *resolvedBackground = PPBBCartColor(background, UIColor.systemBlueColor);
    BOOL compact = self.usesCompactCartButton;
    BOOL legacyIPadBar = PPBBCartUsesLegacyIPadBelowIOS18();
    UIImage *image = PPBBCartSymbol(imageName ?: @"cart.badge.plus",
                                    compact ? 19.0 : 18.0,
                                    UIImageSymbolWeightSemibold,
                                    resolvedForeground);
    self.addToCartButton.accessibilityLabel = resolvedTitle;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config;
        if (compact && PPIOS26()) {
            if (@available(iOS 26.0, *)) {
                config = [UIButtonConfiguration prominentGlassButtonConfiguration];
            } else {
                config = [UIButtonConfiguration filledButtonConfiguration];
            }
        } else {
            config = [UIButtonConfiguration filledButtonConfiguration];
        }
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.buttonSize = legacyIPadBar ? UIButtonConfigurationSizeMedium : UIButtonConfigurationSizeLarge;
        config.baseForegroundColor = resolvedForeground;
        config.baseBackgroundColor = resolvedBackground;
        config.background.backgroundColor = [resolvedBackground colorWithAlphaComponent:(compact && PPIOS26()) ? 0.74 : 1.0];
        config.background.cornerRadius = (compact ? PPBBCartBadgeCartButtonSize() : PPBBCartAddButtonHeight()) * 0.5;
        config.background.strokeColor = UIColor.clearColor;
        config.background.strokeWidth = 0.0;
        config.title = compact ? nil : resolvedTitle;
        config.image = image;
        config.imagePlacement = NSDirectionalRectEdgeLeading;
        config.imagePadding = compact ? 0.0 : (legacyIPadBar ? 6.0 : PPSpaceSM);
        config.contentInsets = compact
        ? NSDirectionalEdgeInsetsMake(0.0, 0.0, 0.0, 0.0)
        : NSDirectionalEdgeInsetsMake(0.0, legacyIPadBar ? PPSpaceMD : PPSpaceBase, 0.0, legacyIPadBar ? PPSpaceMD : PPSpaceBase);
        config.titleTextAttributesTransformer =
        ^NSDictionary<NSAttributedStringKey, id> * (NSDictionary<NSAttributedStringKey, id> *attrs) {
            NSMutableDictionary *m = [attrs mutableCopy];
            m[NSFontAttributeName] = [GM boldFontWithSize:(legacyIPadBar ? 15.0 : 16.0)] ?: [UIFont systemFontOfSize:(legacyIPadBar ? 15.0 : 16.0) weight:UIFontWeightSemibold];
            m[NSForegroundColorAttributeName] = resolvedForeground;
            return m;
        };
        self.addToCartButton.configuration = config;
    } else {
        self.addToCartButton.backgroundColor = resolvedBackground;
        [self.addToCartButton setTitle:compact ? nil : resolvedTitle forState:UIControlStateNormal];
        [self.addToCartButton setTitleColor:resolvedForeground forState:UIControlStateNormal];
        [self.addToCartButton setImage:image forState:UIControlStateNormal];
        self.addToCartButton.titleLabel.font = [GM boldFontWithSize:(legacyIPadBar ? 15.0 : 16.0)] ?: [UIFont systemFontOfSize:(legacyIPadBar ? 15.0 : 16.0) weight:UIFontWeightSemibold];
        self.addToCartButton.contentEdgeInsets = compact
        ? UIEdgeInsetsZero
        : UIEdgeInsetsMake(0.0, legacyIPadBar ? PPSpaceMD : PPSpaceBase, 0.0, legacyIPadBar ? PPSpaceMD : PPSpaceBase);
        self.addToCartButton.layer.cornerRadius = (compact ? PPBBCartBadgeCartButtonSize() : PPBBCartAddButtonHeight()) * 0.5;
        if (@available(iOS 13.0, *)) {
            self.addToCartButton.layer.cornerCurve = kCACornerCurveContinuous;
        }
    }
}

- (void)pp_animateViewTap:(UIView *)view completion:(void (^ _Nullable)(void))completion {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        CGFloat originalAlpha = view.alpha;
        [UIView animateWithDuration:0.08
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            view.alpha = originalAlpha * 0.88;
        } completion:^(__unused BOOL finished) {
            [UIView animateWithDuration:0.10
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                view.alpha = originalAlpha;
            } completion:^(__unused BOOL done) {
                if (completion) completion();
            }];
        }];
        return;
    }

    [UIView animateWithDuration:PPAnimDurationFast
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        view.transform = CGAffineTransformMakeScale(0.965, 0.965);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.34
                              delay:0.0
             usingSpringWithDamping:0.72
              initialSpringVelocity:0.45
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            view.transform = CGAffineTransformIdentity;
        } completion:^(__unused BOOL done) {
            if (completion) completion();
        }];
    }];
}

- (void)pp_runConfirmedSheen {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    [self.buttonSheenLayer removeFromSuperlayer];
    self.buttonSheenLayer = [CAGradientLayer layer];
    self.buttonSheenLayer.colors = @[
        (__bridge id)[UIColor.whiteColor colorWithAlphaComponent:0.0].CGColor,
        (__bridge id)[UIColor.whiteColor colorWithAlphaComponent:0.30].CGColor,
        (__bridge id)[UIColor.whiteColor colorWithAlphaComponent:0.0].CGColor
    ];
    self.buttonSheenLayer.locations = @[@0.0, @0.48, @1.0];
    self.buttonSheenLayer.startPoint = CGPointMake(0.0, 0.5);
    self.buttonSheenLayer.endPoint = CGPointMake(1.0, 0.5);
    self.buttonSheenLayer.frame = self.addToCartButton.bounds;
    self.buttonSheenLayer.transform = CATransform3DMakeTranslation(-CGRectGetWidth(self.addToCartButton.bounds), 0.0, 0.0);
    [self.addToCartButton.layer addSublayer:self.buttonSheenLayer];

    CABasicAnimation *sweep = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    sweep.fromValue = @(-CGRectGetWidth(self.addToCartButton.bounds));
    sweep.toValue = @(CGRectGetWidth(self.addToCartButton.bounds));
    sweep.duration = 0.72;
    sweep.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.buttonSheenLayer addAnimation:sweep forKey:@"pp_add_to_cart_sheen"];
}

- (void)pp_runSuccessHalo {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    [self.successHaloView removeFromSuperview];
    self.successHaloView = [[UIView alloc] initWithFrame:self.addToCartButton.frame];
    self.successHaloView.translatesAutoresizingMaskIntoConstraints = NO;
    self.successHaloView.userInteractionEnabled = NO;
    self.successHaloView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.16];
    PPApplyContinuousCorners(self.successHaloView, PPButtonHeightLG * 0.5);

    UIView *hostView = self.addToCartButton.superview ?: self.BackgroundB;
    if (self.addToCartButton.superview == hostView) {
        [hostView insertSubview:self.successHaloView belowSubview:self.addToCartButton];
    } else {
        [hostView addSubview:self.successHaloView];
    }

    [NSLayoutConstraint activateConstraints:@[
        [self.successHaloView.topAnchor constraintEqualToAnchor:self.addToCartButton.topAnchor],
        [self.successHaloView.bottomAnchor constraintEqualToAnchor:self.addToCartButton.bottomAnchor],
        [self.successHaloView.leadingAnchor constraintEqualToAnchor:self.addToCartButton.leadingAnchor],
        [self.successHaloView.trailingAnchor constraintEqualToAnchor:self.addToCartButton.trailingAnchor]
    ]];

    self.successHaloView.alpha = 0.0;
    self.successHaloView.transform = CGAffineTransformMakeScale(0.92, 0.92);
    [UIView animateWithDuration:0.54
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.successHaloView.alpha = 1.0;
        self.successHaloView.transform = CGAffineTransformMakeScale(1.045, 1.08);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.28
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
            self.successHaloView.alpha = 0.0;
        } completion:^(__unused BOOL done) {
            [self.successHaloView removeFromSuperview];
            self.successHaloView = nil;
        }];
    }];
}

- (void)pp_restoreAddToCartButton {
    self.restoringButton = YES;
    [self pp_setAddToCartTitle:self.idleAddToCartTitle
                     imageName:@"cart.badge.plus"
                    foreground:UIColor.whiteColor
                    background:PPBBCartColor(AppPrimaryClr, UIColor.systemBlueColor)];
    [UIView transitionWithView:self.addToCartButton
                      duration:0.22
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        self.addToCartButton.alpha = 1.0;
    } completion:^(__unused BOOL finished) {
        self.addToCartButton.userInteractionEnabled = YES;
        self.restoringButton = NO;
    }];
}


#pragma mark - Actions

- (void)increaseQuantity {
    self.cartItemquantity++;
    [self pp_animateViewTap:self.qtyContainer completion:nil];
    [self updateQuantityUI];
}

- (void)decreaseQuantity {
    if (self.cartItemquantity > 1) self.cartItemquantity--;
    [self pp_animateViewTap:self.qtyContainer completion:nil];
    [self updateQuantityUI];
}

- (void)addToCartTapped {
    self.addToCartButton.userInteractionEnabled = NO;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(pp_restoreAddToCartButton) object:nil];

    [self pp_animateViewTap:self.addToCartButton completion:^{
        self.addToCartButton.userInteractionEnabled = YES;
        if (self.onAddToCart) {
            self.onAddToCart(MAX(self.cartItemquantity, 1));
        } else {
            [self performAddToCartSuccessAnimation];
        }
    }];
}

#pragma mark - Update UI

- (void)updateQuantityUI {
    NSInteger safeQuantity = MAX(self.cartItemquantity, 1);
    _cartItemquantity = safeQuantity;
    NSString *nextText = [NSString stringWithFormat:@"%ld", (long)safeQuantity];

    if (![self.countLabel.text isEqualToString:nextText]) {
        [UIView transitionWithView:self.countLabel
                          duration:0.18
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            self.countLabel.text = nextText;
        } completion:nil];
    } else {
        self.countLabel.text = nextText;
    }

    self.minusButton.enabled = safeQuantity > 1;
    self.minusButton.alpha = safeQuantity > 1 ? 1.0 : 0.36;
    self.countLabel.accessibilityValue = nextText;

    if (self.onQuantityChanged) self.onQuantityChanged(self.cartItemquantity);
}

- (void)setInitItemAmount:(CGFloat)amount {
    _itemAmount = amount;
    [self setTotalAmount:amount * MAX(self.cartItemquantity, 1)];

}


- (void)setTotalAmount:(CGFloat)totalAmount {
    _totalAmount = totalAmount;
    NSString *price = [self pp_priceStringFromAmount:totalAmount];
    [UIView transitionWithView:self.amountLabel
                      duration:0.18
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        self.amountLabel.text = price;
    } completion:nil];
    [self pp_updateTotalAccessibility];

}

- (void)setItemAmount:(CGFloat)itemAmount {
    _itemAmount = itemAmount;
}

- (void)performAddToCartSuccessAnimation {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(pp_restoreAddToCartButton) object:nil];
        self.addToCartButton.userInteractionEnabled = NO;

        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentSuccess];
        [self pp_setAddToCartTitle:kLang(@"AddedToCart")
                         imageName:@"checkmark.circle.fill"
                        foreground:UIColor.whiteColor
                        background:PPBBCartColor(AppSuccessClr, PPBBCartColor(AppPrimaryClr, UIColor.systemGreenColor))];
        [self pp_refreshShowCartBadgeAnimated:YES];
        [self pp_playShowCartLottieAnimation];
        [self pp_runSuccessHalo];
        [self pp_runConfirmedSheen];

        if (UIAccessibilityIsReduceMotionEnabled()) {
            self.addToCartButton.transform = CGAffineTransformIdentity;
            self.qtyContainer.transform = CGAffineTransformIdentity;
            self.totalContainer.transform = CGAffineTransformIdentity;
            [UIView transitionWithView:self.addToCartButton
                              duration:0.16
                               options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction
                            animations:nil
                            completion:nil];
        } else {
            self.addToCartButton.transform = CGAffineTransformMakeScale(0.97, 0.97);
            self.qtyContainer.transform = CGAffineTransformMakeScale(0.985, 0.985);

            [UIView animateWithDuration:0.44
                                  delay:0.0
                 usingSpringWithDamping:0.70
                  initialSpringVelocity:0.60
                                options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                self.addToCartButton.transform = CGAffineTransformIdentity;
                self.qtyContainer.transform = CGAffineTransformIdentity;
                self.totalContainer.transform = CGAffineTransformMakeScale(1.012, 1.012);
            } completion:^(__unused BOOL finished) {
                [UIView animateWithDuration:0.18
                                      delay:0.0
                                    options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                                 animations:^{
                    self.totalContainer.transform = CGAffineTransformIdentity;
                } completion:nil];
            }];
        }

        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, kLang(@"ItemAddedToCart"));
        [self performSelector:@selector(pp_restoreAddToCartButton) withObject:nil afterDelay:1.05];
    });
}

- (void)performAddToCartFailureAnimation {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(pp_restoreAddToCartButton) object:nil];
        [self.buttonSheenLayer removeFromSuperlayer];
        self.addToCartButton.userInteractionEnabled = YES;

        if (!UIAccessibilityIsReduceMotionEnabled()) {
            CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
            shake.values = @[@0, @(-8), @(7), @(-5), @(3), @0];
            shake.duration = 0.34;
            shake.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            [self.addToCartButton.layer addAnimation:shake forKey:@"pp_add_to_cart_failure"];
        }

        [UIView animateWithDuration:0.20
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.addToCartButton.alpha = 0.88;
        } completion:^(__unused BOOL finished) {
            [UIView animateWithDuration:0.20 animations:^{
                self.addToCartButton.alpha = 1.0;
            }];
        }];
    });

}

@end























/* **********************************************************************************************************************************************************************************************************/


#pragma mark - PPNewBottomBar

@interface PPNewBottomBar ()<UITabBarDelegate>

@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong) UIView *VIEWFORHOLE;
@property (nonatomic, strong) UIButton *emptyCard;
@property (nonatomic, strong) UIButton *lastSeletedbutton;
@property (nonatomic, strong) NSArray<UITabBarItem *> *items;
@property (nonatomic, strong) UITabBarItem *cart;
@end

@implementation PPNewBottomBar

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
       
    }
    return self;
}


- (UIButton *)createCategoriesBackground
{
    UIButton *bgButton;
    if (@available(iOS 26.0, *)) {
        // 🧊 iOS 26+ system glass button
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.background.backgroundColor = UIColor.clearColor;
        cfg.baseBackgroundColor = UIColor.clearColor;
        cfg.background.cornerRadius = 0;

        
        bgButton = [UIButton  buttonWithType:UIButtonTypeSystem];
        bgButton.configuration = cfg;
      } else {
         
 
        // 🌫️ Fallback for iOS <26
        bgButton = [UIButton buttonWithType:UIButtonTypeSystem];
        bgButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        bgButton.layer.cornerRadius = 16;
        bgButton.layer.masksToBounds = YES;
        [bgButton pp_setShadowColor:AppShadowClr];
        bgButton.layer.shadowOpacity = 0.15;
        bgButton.layer.shadowRadius = 8;
        bgButton.layer.shadowOffset = CGSizeMake(0, 4);
    }

    bgButton.translatesAutoresizingMaskIntoConstraints = NO;
    return bgButton;
}

- (void)setupView {
    
   
    
    // Avoid duplicate setup
    if (self.emptyCard && self.actionButton) return;

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = UIColor.clearColor;
    CGFloat pad = 12.0;

    // Empty card (background glass)
    self.emptyCard = [self createCategoriesBackground];
    self.emptyCard.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.emptyCard];

    _lastSeletedbutton = [UIButton new];

    [NSLayoutConstraint activateConstraints:@[
        [self.emptyCard.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:0],
        [self.emptyCard.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-0],
        [self.emptyCard.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.emptyCard.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];
    self.emptyCard.alpha = 0;
    self.emptyCard.backgroundColor = UIColor.clearColor;
    //self.emptyCard.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    //self.emptyCard.layer.shadowOpacity = 0.36;
    //self.emptyCard.layer.shadowOffset = CGSizeMake(0, 2);
    //self.emptyCard.layer.shadowRadius = 6.0;
    //self.emptyCard.layer.cornerRadius = PPCorners + 16;

   
    [self addSubview:_emptyCard];
 

    // Floating action button (trailing anchor)
    _actionButton = [self pp_BarButtonWithSystemName:@"plus" klangKey:nil withSide:54 isCenterBtn:YES];
    _actionButton.accessibilityIdentifier = @"plus";
    if (@available(iOS 18.0, *)) {
        [_actionButton.imageView addSymbolEffect: [NSSymbolWiggleEffect effect]];
    } else {
        // Fallback on earlier versions
    }
    _actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    _actionButton.tag = PPBarTagNewAd;
    [_actionButton addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_actionButton];
    
    
    _searchButton = [self pp_BarButtonWithSystemName:@"magnifyingglass" klangKey:nil withSide:54 isCenterBtn:YES];
    _searchButton.translatesAutoresizingMaskIntoConstraints = NO;
    _searchButton.tag = PPBarTagSearch;
    [_searchButton addTarget:self action:@selector(searchTapped:) forControlEvents:UIControlEventTouchUpInside];
    _searchButton.hidden = NO;
    [self addSubview:_searchButton];
    _searchButton.hidden = YES;
    // Layout: action button anchored to trailing, container fills from leading to before button
    CGFloat horizontalMargin = 16.0;
    CGFloat trailingMargin = -16.0;

    
    [NSLayoutConstraint activateConstraints:@[
        [_actionButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-horizontalMargin],
        [_searchButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:trailingMargin],
    ]];

    // Style action button
    _actionButton.layer.cornerRadius = (_blurBarViewHeight - 14) / 2.0;
    _actionButton.clipsToBounds = YES;
   
    [self layoutIfNeeded];
    if(PPIOS26()) {
        [self addTabbbar];
    } else {
        // iOS <26: create UIStackView for tab buttons (configureWithItems: adds buttons here)
        _stackView = [[UIStackView alloc] init];
        _stackView.axis = UILayoutConstraintAxisHorizontal;
        _stackView.distribution = UIStackViewDistributionFillEqually;
        _stackView.alignment = UIStackViewAlignmentCenter;
        _stackView.spacing = 4;
        _stackView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_stackView];

        [NSLayoutConstraint activateConstraints:@[
            [_stackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:0],
            [_stackView.trailingAnchor constraintEqualToAnchor:_actionButton.leadingAnchor constant:-8],
            [_stackView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_stackView.heightAnchor constraintEqualToAnchor:self.heightAnchor],
        ]];
    }
    
    
 
}



- (void)configureTabBarItems:(NSArray<NSDictionary *> *)items {
    
    [self setupView];
    
    // 1. Clear old buttons

    NSMutableArray *tabbaritemsArr = [NSMutableArray array];

    // 2. Create each button
    for (NSInteger i = 0; i < items.count; i++) {
        NSDictionary *info = items[i];
        NSString *iconName = info[@"icon"];
        PPBarTag tag = [info[@"tag"] integerValue];
        
        NSString *iconNameFill = [NSString stringWithFormat:@"%@.fill",info[@"icon"]];
        NSString *title    = _hideTitles ? nil : info[@"title"];

        UIColor *clr = [AppPrimaryClr colorWithAlphaComponent:1.0];
        UIImage *img = [UIImage systemImageNamed:iconName] ? [UIImage pp_symbolNamed:iconName pointSize:19 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleMedium palette:@[AppButtonMixColorClr,AppButtonMixColorClr] makeTemplate:YES] : [UIImage imageNamed:iconName];
        
        UIImage *imgFill = [UIImage systemImageNamed:iconNameFill] ? [UIImage pp_symbolNamed:iconNameFill pointSize:20 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleMedium palette:@[clr,clr] makeTemplate:YES] : [UIImage imageNamed:iconNameFill];

        UITabBarItem *itm;

        //if(_hideTitles == NO)
        //    itm = [[UITabBarItem alloc] initWithTitle:title image:img  selectedImage:imgFill ];
        //else
           //itm = [[UITabBarItem alloc] initWithTitle:nil image:[self bar_symbolNamed:iconName]  selectedImage:imgFill ];
        itm = [[UITabBarItem alloc] initWithTitle:title image:img  selectedImage:imgFill ];
        itm.tag = tag;
        
        
        [tabbaritemsArr addObject:itm];
        if(tag == PPBarTagCart)
            self.cart = itm;
        
    }
    _items = tabbaritemsArr;
    self.tabBar.itemPositioning = UITabBarItemPositioningFill;
    self.tabBar.itemSpacing = 0.0;
    self.tabBar.items = _items;
    
    // FIX: Force layout so titles do not disappear
    [self.tabBar setNeedsLayout];
    [self.tabBar layoutIfNeeded];
    
   //
   // self.tabBar.itemPositioning = UITabBarItemPositioningCentered;
       // self.tabBar.itemWidth = 110.0;    // العرض المطلوب لكل أيقونة/عنصر
       // self.tabBar.itemSpacing = 16.0;  // المسافة بين العناصر
    
     
    _lastSelectedBarItem = tabbaritemsArr.firstObject;
    //[self.tabBar setSelectedItem:tabbaritemsArr.firstObject];
}


-(void)addTabbbar
{
    // 1️⃣ Create tab bar
    self.tabBar = [[UITabBar alloc] init];
    self.tabBar.delegate = self;

    // 2️⃣ Create tab bar items
    self.cart = [[UITabBarItem alloc] initWithTitle:kLang(@"Cart") image:[self bar_symbolNamed:@"cart"] tag:0];
    [self configureAppearance];

    self.tabBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabBarState = TabBarStateExpanded;
    
    
    [self addSubview:self.tabBar];
    self.tabBar.translatesAutoresizingMaskIntoConstraints = NO;
    // ensure tabBar fills the same background area (in case it was added earlier)
    [NSLayoutConstraint activateConstraints:@[
        [_searchButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:0],
        [_actionButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:0],
        
        [self.tabBar.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:0],
        [self.tabBar.trailingAnchor constraintEqualToAnchor:_actionButton.leadingAnchor constant:-8],
        [self.tabBar.centerYAnchor constraintEqualToAnchor:self.actionButton.centerYAnchor constant:10],
    ]];
     
    
    
}


// Floating background (emulates iOS 26 look)
- (void)pp_configureFloatingBackgroundForAppearance:(UITabBarAppearance *)appearance {
    if (@available(iOS 26.0, *)) {
        [appearance configureWithTransparentBackground];
    } else if (@available(iOS 13.0, *)) {
        //UITabBarAppearance *appearance = [UITabBarAppearance new];
        [appearance configureWithTransparentBackground];
        

    } else {
        appearance.backgroundImage = [UIImage new];
        appearance.shadowImage = [UIImage new];
    }
}


- (void)configureAppearance {
    // WHY: Make selected title invisible while keeping normal visible.
    if (@available(iOS 13.0, *)) {
        UITabBarAppearance *appearance = [UITabBarAppearance new];
        [self pp_configureFloatingBackgroundForAppearance:appearance];

        NSDictionary<NSAttributedStringKey, id> *clearSelectedTitle =
        @{ NSForegroundColorAttributeName: [AppPrimaryClr colorWithAlphaComponent:1.0] ,
           NSFontAttributeName: [GM boldFontWithSize:10.5]};

        appearance.stackedLayoutAppearance.selected.titleTextAttributes = clearSelectedTitle;
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = clearSelectedTitle;
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = clearSelectedTitle;

        NSDictionary<NSAttributedStringKey, id> *normalTitle =
        @{ NSForegroundColorAttributeName: AppButtonMixColorClr ,
           NSFontAttributeName: [GM MidFontWithSize:10.5]};
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalTitle;
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = normalTitle;
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = normalTitle;
        appearance.stackedLayoutAppearance.normal.titlePositionAdjustment = UIOffsetMake(0.0, -1.0);
        appearance.stackedLayoutAppearance.selected.titlePositionAdjustment = UIOffsetMake(0.0, -1.0);
        appearance.inlineLayoutAppearance.normal.titlePositionAdjustment = UIOffsetMake(0.0, -1.0);
        appearance.inlineLayoutAppearance.selected.titlePositionAdjustment = UIOffsetMake(0.0, -1.0);
        appearance.compactInlineLayoutAppearance.normal.titlePositionAdjustment = UIOffsetMake(0.0, -1.0);
        appearance.compactInlineLayoutAppearance.selected.titlePositionAdjustment = UIOffsetMake(0.0, -1.0);
        
    

        self.tabBar.standardAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            self.tabBar.scrollEdgeAppearance = appearance;
        }
         
    } else {
        NSDictionary<NSAttributedStringKey, id> *clearSelectedTitle =
            @{ NSForegroundColorAttributeName: UIColor.clearColor };
        [[UITabBarItem appearance] setTitleTextAttributes:clearSelectedTitle forState:UIControlStateSelected];
    }
}

- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {
    NSLog(@"Selected tab: %@ (tag:%ld)", item.title, (long)item.tag);
    
   
    if(item.tag == PPBarTagCart)
    {
        if (self.onTabBarTapped) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.onTabBarTapped(item.tag, item);
            });
        }
        [self.tabBar setSelectedItem:_lastSelectedBarItem];
        return;
    } else  _lastSelectedBarItem = item;

        if (self.onTabBarTapped) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.onTabBarTapped(item.tag, item);
            });
        }
    
}

#pragma mark - Tab -> ViewController factory

- (UIViewController *)viewControllerForTabTag:(PPBarTag)tag {
    switch (tag) {
        case PPBarTagHome: {
             NewAppVC *vc = [[NewAppVC alloc] init];
            // configure vc if needed
            return vc;
        }
        case PPBarTagCart: {
            CartViewController *vc = [[CartViewController alloc] init];
            // If Cart should be a different VC, change class here
            return vc;
        }
        case PPBarTagChats: {
            UserChatsViewController *vc = [[UserChatsViewController alloc] init];
            return vc;
        }
        case PPBarTagOrdersHistory: {
            OrderHistoryViewController *vc = [[OrderHistoryViewController alloc] init];
            return vc;
        }
        default:
            return nil;
    }
}

- (void)deselectTabberItems
{

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
        self.tabBar.selectedItem = nil;
            });
}
// PPTabBarController.m

- (void)selectItemWithTag:(PPBarTag)tag animated:(BOOL)animated {
    NSArray<UITabBarItem *> *items = self.tabBar.items;
    NSUInteger index = NSNotFound;

    // Find tab by tag
    for (NSUInteger i = 0; i < items.count; i++) {
        if (items[i].tag == tag) {
            index = i;
            break;
        }
    }

    if (index == NSNotFound) {
        NSLog(@"Tab not found for tag %ld", (long)tag);
        return;
    }

    if (animated) {
        [UIView transitionWithView:self.tabBar
                          duration:0.25
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
          //  self.selectedIndex = index;
            self.tabBar.selectedItem = items[tag];
            
        } completion:nil];
    } else {
      //  self.selectedIndex = index;
    }
}


/*
 -(void)layoutSubviews
 {
     
     [super layoutSubviews];
     
     
     CGRect selfFrame = CGRectMake(0,
                                   -50,
                                   self.hx_w,
                                   self.hx_h + GM.bottomPadding + 50);
     self.backgroundColor = UIColor.clearColor;
     
     [PPFunc removeOldGradientsFromView:self];
     
     {
    
     PPGradientDirection direction =
     (_barBackStyle == BarBackStyleGardLTR)
     ? PPGradientDirectionRightToLeft
     : (_barBackStyle == BarBackStyleGardRTL)
     ? PPGradientDirectionLeftToRight
     : (_barBackStyle == BarBackStyleFadeTopToBottom)
     ? PPGradientDirectionTopToBottom
     : PPGradientDirectionBottomToTop;
   
         PPGradientDirection direction ;
     CAGradientLayer *mainGradient =
         [UIView gradientLayerWithFadeForColor:[AppShadowClr colorWithAlphaComponent:0.6]
                                 direction:direction
                                     frame:selfFrame];
     mainGradient.cornerRadius = PPCorners + 10;
     
     // 🔹 5. Add gradient based on style
     if (_barBackStyle == BarBackStyleFade || _barBackStyle == BarBackStyleLongFade) {
         
         mainGradient = [UIView halfGradientLayerWithFadeForColor:[AppForgroundColr colorWithAlphaComponent:0.1]
                                                        direction:PPGradientDirectionBottomToTop
                                                            frame:selfFrame];
         mainGradient.cornerRadius = PPCorners + 10;
         mainGradient.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
         [self.layer insertSublayer:mainGradient atIndex:0];
         
         
     }
     else if (_barBackStyle == BarBackStyleFadeTopToBottom) {
         mainGradient = [UIView gradientLayerWithFadeForColor:AppForgroundColr
                                                    direction:PPGradientDirectionTopToBottom
                                                        frame:selfFrame];
         mainGradient.cornerRadius = PPCorners + 10;
          [self.layer insertSublayer:mainGradient atIndex:0];
     }
     else if (_barBackStyle == BarBackStyleGardRTL) {
         mainGradient = [UIView gradientLayerWithFadeForColor:AppForgroundColr
                                                    direction:PPGradientDirectionRightToLeft
                                                        frame:selfFrame];
         mainGradient.cornerRadius = PPCorners + 10;
          [self.layer insertSublayer:mainGradient atIndex:0];
     }
     
     //CAGradientLayer *cardGradient =
     //   [UIView gradientLayerWithFadeForColor:AppBackgroundClr
     //           direction:PPGradientDirectionTopToBottom
     //        frame:emptyFrame];
     //cardGradient.cornerRadius = PPCorners + 15;
     //[self.emptyCard.layer insertSublayer:cardGradient atIndex:0];
     
     // 🔹 7. Semantic direction (RTL/LTR)
     self.semanticContentAttribute = GM.setSemantic;
 }
     //[_tabBar.heightAnchor constraintEqualToConstant:86].active = YES;
    // [_tabBar.widthAnchor constraintEqualToAnchor:self.widthAnchor constant:-60].active = YES;
     //[_tabBar.leadingAnchor constraintEqualToAnchor:_actionButton.trailingAnchor constant:-10].active = YES;
    // [_tabBar.centerYAnchor constraintEqualToAnchor:_actionButton.centerYAnchor constant:10].active = YES;
    
     //[_tabBar.bottomAnchor constraintEqualToAnchor:_actionButton.bottomAnchor constant:8].active = YES;

     [self.tabBar setTintColor:AppPrimaryClr];
     [self.tabBar setUnselectedItemTintColor:UIColor.grayColor];

     [self.tabBar setNeedsLayout];
     [self.tabBar layoutIfNeeded];
     [self.emptyCard bringSubviewToFront:_tabBar];

    
 }
 */




- (void)configureWithItems:(NSArray<NSDictionary *> *)items {
    
    [self setupView];
    
    // 1. Clear old buttons
    for (UIView *v in _stackView.arrangedSubviews) [v removeFromSuperview];

    NSMutableArray *btns = [NSMutableArray array];

    // 2. Create each button
    for (NSInteger i = 0; i < items.count; i++) {
        NSDictionary *info = items[i];
        NSString *iconName = info[@"icon"];
        NSString *title    = _hideTitles ? nil : info[@"title"];

    
        UIImage *img = [UIImage systemImageNamed:iconName] ? [UIImage pp_symbolNamed:iconName pointSize:20 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleMedium palette:@[AppPrimaryClrShiner,AppPrimaryClr] makeTemplate:YES] : [UIImage imageNamed:iconName];

        // --- Button configuration ---
        UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
        cfg.image = img;
        cfg.imagePlacement = _hideTitles ? NSDirectionalRectEdgeAll : NSDirectionalRectEdgeTop;
        cfg.imagePadding = 2;
        cfg.background.backgroundColor = UIColor.clearColor;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(3, 1, 3, 1);
        cfg.titleLineBreakMode = NSLineBreakByClipping;

        if(_hideTitles == NO)
        {
            NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
            paragraph.alignment = NSTextAlignmentCenter;
            paragraph.lineBreakMode = NSLineBreakByClipping;
            // Title styling (separate text color)
            NSAttributedString *attrTitle =
            [[NSAttributedString alloc] initWithString:title
                                            attributes:@{
                NSFontAttributeName: [GM MidFontWithSize:10.5],
                NSForegroundColorAttributeName: AppPrimaryTextClr,
                NSParagraphStyleAttributeName: paragraph
            }];
            cfg.attributedTitle = attrTitle;
        }
     
        
        // --- Create button ---
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        btn.configuration = cfg;
        btn.accessibilityIdentifier = iconName; // <– add this line
        btn.titleLabel.numberOfLines = 1;
        btn.titleLabel.adjustsFontSizeToFitWidth = YES;
        btn.titleLabel.minimumScaleFactor = 0.62;
        btn.titleLabel.lineBreakMode = NSLineBreakByClipping;
        btn.titleLabel.textAlignment = NSTextAlignmentCenter;
        btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;

        // Tint color fallback (for iOS < 15)
        [btn.titleLabel setTextColor:AppPrimaryTextClr];
        [btn setTintColor:AppPrimaryTextClr];
        UIImage *fillicon = [UIImage systemImageNamed:iconName] ? [UIImage pp_symbolNamed:iconName pointSize:20 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleMedium palette:@[AppPrimaryClrShiner,AppPrimaryClr] makeTemplate:YES] : [UIImage imageNamed:iconName];
      
        [btn setImage:fillicon forState:UIControlStateSelected];
        [btn setImage:fillicon forState:UIControlStateHighlighted];
        
        [btn setImage:img forState:UIControlStateNormal];
        btn.tag = i;
        [btn addTarget:self
                 action:@selector(tabTapped:)
         
       forControlEvents:UIControlEventTouchUpInside];
        
        if([iconName isEqualToString:@"cart"])
        {
            self.cartButton = btn;
        }
        [btns addObject:btn];
        [_stackView addArrangedSubview:btn];
        
    }

    self.tabButtons = btns;
    //[self addBlurToView:_container style:UIBlurEffectStyleSystemUltraThinMaterial cornerRadius:_blurBarViewHeight/2];
    [self setNeedsLayout];
}


- (void)searchTapped:(UIButton *)sender {
     
    NSLog(@"[NEW BOTTOM BAR] searchTapped: %ld", (long)sender.tag);

    if(PPIOS26())
    {
            if (self.onTabBarTapped)  self.onTabBarTapped(PPBarTagSearch,(UIBarItem *)sender);
    }
    else
    {
        // 🔹 Animate tap + callback
        [self performButtonTapAnimation:sender animCompletion:^(BOOL finished) {
            if (self.onTabBarTapped)  self.onTabBarTapped(PPBarTagSearch, (UIBarItem *)sender);
        }];
        // 🔹 Highlight tapped button
        sender.selected = YES;
    }
    
}


- (void)tabTapped:(UIButton *)sender {
    NSLog(@"[NEW BOTTOM BAR] tabTapped: %ld", (long)sender.tag);

    if([AppMgr.topViewController isKindOfClass: MainController.class])
    {
        NewCardForm *vc = [NewCardForm new];
        vc.FromVC =  @"main";
       
        [AppMgr.topViewController.navigationController pushViewController:vc animated:YES];
        return;
    }
    if(PPIOS26())
    {
            if (self.onTabBarTapped)  self.onTabBarTapped(PPBarTagNewAd, (UIBarItem *)sender);
    }
    else
    {
        [self performButtonTapAnimation:sender animCompletion:^(BOOL finished) {
            if (self.onTabBarTapped) self.onTabBarTapped(PPBarTagNewAd, (UIBarItem *)sender);
        }];
        
        // 🔹 Highlight tapped button
        sender.selected = YES;
        [sender setTintColor:AppPrimaryClr];
    }
      
    
 

    
}
 
 

- (void)showTitles:(BOOL)show {
    for (UITabBarItem *item in self.tabBar.items) {
        if (show) {
            [item setTitlePositionAdjustment:UIOffsetMake(0, 0)];
            item.imageInsets = UIEdgeInsetsZero;
        } else {
            [item setTitlePositionAdjustment:UIOffsetMake(0, 10)];
            item.imageInsets = UIEdgeInsetsMake(6, 0, -6, 0);
        }
    }
}




















































































































































- (void)performButtonTapAnimation:(UIButton *)button animCompletion:(void (^ __nullable)(BOOL finished))animCompletion {
    AudioServicesPlaySystemSound(1104); // "Tock" – Apple system tap sound

    UIImpactFeedbackGenerator *feedback =
    [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
    [feedback impactOccurred];

    [UIView animateWithDuration:0.12
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        button.transform = CGAffineTransformMakeScale(0.90, 0.90);
        button.alpha = 0.9;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.20
                              delay:0
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
            button.transform = CGAffineTransformIdentity;
            button.alpha = 1.0;
        } completion:^(BOOL finished) {
            animCompletion(finished);
        }];
    }];
}

// ✅ Remove badge
- (void)removeBadgeAtIndex:(NSInteger)index {
    UILabel *badge = [self badgeLabels][@(index)];
    if (badge) {
        [badge removeFromSuperview];
        [[self badgeLabels] removeObjectForKey:@(index)];
    }
}

// ✅ Get the button safely
- (UIButton *)getButtonAtIndex:(NSInteger)index {
    if (index < 0 || index >= self.tabButtons.count) return nil;
    return self.tabButtons[index];
}


-(void)setTabBarHidden:(BOOL)tabBarHidden
{
    if(tabBarHidden)
    {
        //[self setTabBarState:TabBarStateHidden animated:YES];
         //[self.tabBar setItems:@[self.cart] animated:YES];
    }
    else
    {
        //[self.tabBar setItems:_items animated:YES];
       // [self setTabBarState:TabBarStateExpanded animated:YES];
    }
    
}


- (void)applyFadeMaskToView:(UIView *)view
                  direction:(PPGradientDirection)direction
                  fadeStart:(CGFloat)start
                    fadeEnd:(CGFloat)end {
    // Remove any existing mask
    view.layer.mask = nil;
    
    // Create a gradient layer that will serve as the mask
    CAGradientLayer *maskLayer = [CAGradientLayer layer];
    maskLayer.frame = view.bounds;
    
    // White = visible, Black = transparent
    maskLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor
    ];
    
    // Define start/end based on direction
    switch (direction) {
        case PPGradientDirectionTopToBottom:
            maskLayer.startPoint = CGPointMake(0.5, start);
            maskLayer.endPoint   = CGPointMake(0.5, end);
            break;
        case PPGradientDirectionBottomToTop:
            maskLayer.startPoint = CGPointMake(0.5, 1.0 - start);
            maskLayer.endPoint   = CGPointMake(0.5, 1.0 - end);
            break;
        case PPGradientDirectionLeftToRight:
            maskLayer.startPoint = CGPointMake(start, 0.5);
            maskLayer.endPoint   = CGPointMake(end, 0.5);
            break;
        case PPGradientDirectionRightToLeft:
            maskLayer.startPoint = CGPointMake(1.0 - start, 0.5);
            maskLayer.endPoint   = CGPointMake(1.0 - end, 0.5);
            break;
    }
    
    // Apply mask
    view.layer.mask = maskLayer;
    
    // Keep mask updated during layout
    view.layer.masksToBounds = YES;
    view.layer.needsDisplayOnBoundsChange = YES;
}


#pragma mark - Toggle Action Button Visibility

- (void)setActionButtonHidden:(BOOL)hidden {
    if (_actionButton.hidden == hidden) return; // no change

    [UIView transitionWithView:_actionButton
                      duration:0.25
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        self.actionButton.hidden = hidden;
                    } completion:nil];

    // Remove old leading constraint for container
    for (NSLayoutConstraint *constraint in self.constraints) {
        if ((constraint.firstItem == _emptyCard && constraint.firstAttribute == NSLayoutAttributeLeading) ||
            (constraint.secondItem == _emptyCard && constraint.secondAttribute == NSLayoutAttributeLeading)) {
            [constraint setActive:NO];
        }
    }

    // Create new constraint depending on hidden state
    NSLayoutConstraint *newLeading;
    NSLayoutConstraint *newTabBarLeading;
    if (hidden) {
        // Expand to full width
        newLeading = [_emptyCard.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14];
        newTabBarLeading = [_tabBar.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14];
    } else {
        // Normal mode (next to button)
        newLeading = [_emptyCard.leadingAnchor constraintEqualToAnchor:_actionButton.trailingAnchor constant:14];
        newTabBarLeading = [_tabBar.leadingAnchor constraintEqualToAnchor:_actionButton.trailingAnchor constant:14];
    }

    newLeading.active = YES;
    newTabBarLeading.active = YES;
    // Animate layout change smoothly
    [UIView animateWithDuration:0.3
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         [self layoutIfNeeded];
                     } completion:nil];
}
- (UIButton *)pp_BarButtonWithSystemName:(NSString *)imageName
                                klangKey:(NSString *)klangKey
                                withSide:(CGFloat)btnSize
                             isCenterBtn:(BOOL)isCenterBtn
{
    // Create config
    UIButtonConfiguration *cfg;
    UIButton *btn = [[UIButton alloc]init];
    
    //UIImage *icon;
    //NSMutableAttributedString *attributedTitle;
        // --- Center (main action) button ---
    if (@available(iOS 26.0, *)) {
        cfg = [UIButtonConfiguration glassButtonConfiguration];
        UIImage *img = [UIImage systemImageNamed:imageName] ? [UIImage pp_symbolNamed:imageName pointSize:18 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleLarge palette:@[[AppPrimaryClr colorWithAlphaComponent:1.2],[AppPrimaryClr colorWithAlphaComponent:1.2]] makeTemplate:YES] : [UIImage imageNamed:imageName];
            cfg.baseForegroundColor = AppPrimaryClr ?: UIColor.systemBlueColor;
          
            cfg.image = img;
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
            btn.configuration = cfg;
            btn.tintColor = AppPrimaryClr ?: UIColor.systemBlueColor;
            btn.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
            [btn.widthAnchor constraintEqualToConstant:btnSize].active = YES;
            [btn.heightAnchor constraintEqualToConstant:btnSize].active = YES;
            return btn;
        }
        else
        {
            cfg = [UIButtonConfiguration filledButtonConfiguration];
            UIImage *img;
            UIColor *iconColor = ([imageName isEqualToString:@"plus"]
                                  ? (AppPrimaryClr ?: UIColor.systemBlueColor)
                                  : AppForgroundColr);
            if([imageName isEqualToString:@"plus"])
                img = [UIImage systemImageNamed:imageName] ? [UIImage pp_symbolNamed:imageName pointSize:18 weight:UIImageSymbolWeightMedium scale:UIImageSymbolScaleMedium palette:@[iconColor, iconColor] makeTemplate:YES] : [UIImage imageNamed:imageName];
            else
                img = [UIImage systemImageNamed:imageName] ? [UIImage pp_symbolNamed:imageName pointSize:18 weight:UIImageSymbolWeightMedium scale:UIImageSymbolScaleMedium palette:@[iconColor, iconColor] makeTemplate:YES] : [UIImage imageNamed:imageName];
                
            cfg.baseForegroundColor=iconColor;
            cfg.baseBackgroundColor=[AppPrimaryClr colorWithAlphaComponent:0.8];
            cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;

            cfg.image = img;
            UIButton *btn = [UIButton  buttonWithConfiguration:cfg primaryAction:nil];
            //btn.configuration = cfg;
            btn.tintColor = iconColor;
            btn.translatesAutoresizingMaskIntoConstraints = NO;
            btn.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

            // --- Size behavior ---
            if (isCenterBtn) {
                [btn.widthAnchor constraintEqualToConstant:btnSize].active = YES;
                [btn.heightAnchor constraintEqualToConstant:btnSize].active = YES;
            }
        
            btn.layer.cornerRadius = btnSize / 2;
            btn.clipsToBounds= YES;
            [btn setImage:img forState:UIControlStateNormal];
            [btn setTintColor:AppForgroundColr];
            [btn.imageView setTintColor:AppForgroundColr];
            return btn;
        }
        

    
    
  

    return btn;
}

- (UIVisualEffectView *)addBlurToView:(UIView *)view
                                 style:(UIBlurEffectStyle)style
                           cornerRadius:(CGFloat)cornerRadius
{
    
    
    if (@available(iOS 26.0, *)) return nil;
    // 1. Create the blur effect
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:style];

    // 2. Create the blur view
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;

    // 3. Create vibrancy effect for extra transparency
    UIVibrancyEffect *vibrancyEffect = [UIVibrancyEffect effectForBlurEffect:blurEffect];
    UIVisualEffectView *vibrancyView = [[UIVisualEffectView alloc] initWithEffect:vibrancyEffect];
    vibrancyView.translatesAutoresizingMaskIntoConstraints = NO;

    // Add vibrancy view to blur view's content
    [blurView.contentView addSubview:vibrancyView];

    // 4. Round the corners (optional)
    blurView.layer.cornerRadius = cornerRadius;
    blurView.layer.masksToBounds = YES;
   // blurView.alpha = 0.7;
    // 5. Insert into your view hierarchy
    [view insertSubview:blurView atIndex:0];

    // 6. Pin blur view to edges
    [NSLayoutConstraint activateConstraints:@[
        [blurView.topAnchor constraintEqualToAnchor:view.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:view.bottomAnchor]
    ]];

    // 7. Pin vibrancy view to blur view's content
    [NSLayoutConstraint activateConstraints:@[
        [vibrancyView.topAnchor constraintEqualToAnchor:blurView.contentView.topAnchor],
        [vibrancyView.leadingAnchor constraintEqualToAnchor:blurView.contentView.leadingAnchor],
        [vibrancyView.trailingAnchor constraintEqualToAnchor:blurView.contentView.trailingAnchor],
        [vibrancyView.bottomAnchor constraintEqualToAnchor:blurView.contentView.bottomAnchor]
    ]];

    return blurView;
  
}

- (UIView *)pp_createGlassBlurFadeViewWithHeight:(CGFloat)height {
    
    // Container view
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.clipsToBounds = YES;
    container.userInteractionEnabled = NO;

    // 🧊 1. Blur background (glass)
    UIVisualEffectView *blurView =
        [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:blurView];

    [NSLayoutConstraint activateConstraints:@[
        [blurView.topAnchor constraintEqualToAnchor:container.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];

    // 🌫 2. Add gradient fade (bottom → transparent)
    CAGradientLayer *fade = [CAGradientLayer layer];
    fade.colors = @[
        (__bridge id)[UIColor colorWithWhite:1 alpha:0.6].CGColor,
        (__bridge id)[UIColor colorWithWhite:1 alpha:0.15].CGColor,
        (__bridge id)[UIColor colorWithWhite:1 alpha:0.0].CGColor
    ];
    
    fade.locations = @[@0.0, @0.5, @1.0];
    fade.startPoint = CGPointMake(0.5, 1.0);
    fade.endPoint = CGPointMake(0.5, 0.0);
    fade.frame = CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, height);
    fade.name = @"BottomFadeLayer";
    [container.layer addSublayer:fade];

    // 🧷 Optional: subtle border line
    CALayer *line = [CALayer layer];
    line.backgroundColor = [UIColor colorWithWhite:0.9 alpha:0.4].CGColor;
    line.frame = CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, 0.5);
    [container.layer addSublayer:line];

    return container;
}


#pragma mark - Badge Support

// Store badges in a dictionary
- (NSMutableDictionary<NSNumber *, UILabel *> *)badgeLabels {
    static char kBadgeLabelsKey;
    NSMutableDictionary *badges = objc_getAssociatedObject(self, &kBadgeLabelsKey);
    if (!badges) {
        badges = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &kBadgeLabelsKey, badges, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return badges;
}

- (void)setBadge:(NSString *)value forTag:(PPBarTag)tag {
    for (UITabBarItem *it in self.tabBar.items) {
        if (it.tag == tag) {
            it.badgeValue = value;
            return;
        }
    }
}

// ✅ Add or update badge
- (void)setBadgeOnButtonAtIndex:(NSInteger)index
                          value:(NSString *)value
                backgroundColor:(UIColor *)bgColor
                    borderColor:(UIColor *)borderColor
{
    
    if(PPIOS26())
    {
        
        [self setBadge:value forTag:PPBarTagChats];
        return;
    }
    UIButton *button = [self getButtonAtIndex:index];
    if (!button) return;

    UILabel *badge = [self badgeLabels][@(index)];
    if (!badge) {
        badge = [[UILabel alloc] init];
        badge.translatesAutoresizingMaskIntoConstraints = NO;
        badge.textAlignment = NSTextAlignmentCenter;
        badge.font = [UIFont boldSystemFontOfSize:11];
        badge.textColor = UIColor.whiteColor;
        badge.backgroundColor = bgColor ?: UIColor.systemRedColor;
        badge.layer.cornerRadius = 9;
        badge.layer.masksToBounds = YES;
        [badge pp_setBorderColor:borderColor];
        badge.layer.borderWidth = borderColor ? 1.0 : 0.0;
        badge.adjustsFontSizeToFitWidth = YES;
        badge.minimumScaleFactor = 0.7;
        [button addSubview:badge];
        [self badgeLabels][@(index)] = badge;

        // 🧩 Constraints: top-right corner of button
        [NSLayoutConstraint activateConstraints:@[
            [badge.centerXAnchor constraintEqualToAnchor:button.trailingAnchor constant:-20],
            [badge.centerYAnchor constraintEqualToAnchor:button.topAnchor constant:6],
            [badge.heightAnchor constraintEqualToConstant:18],
            [badge.widthAnchor constraintGreaterThanOrEqualToConstant:18]
        ]];
    }

    badge.text = value;
    badge.backgroundColor = bgColor ?: badge.backgroundColor;
    [badge pp_setBorderColor:borderColor];
    badge.hidden = (value.length == 0);
}
- (UIImage *)bar_symbolNamed:(NSString *)name
{
    UIImage *img = [UIImage systemImageNamed:name];
    if (!img) return nil;

    // Build symbol configuration
    UIImageSymbolConfiguration *colorCfg =
    [UIImageSymbolConfiguration configurationWithHierarchicalColor:[AppPrimaryClr colorWithAlphaComponent:1.2]];

    UIImageSymbolConfiguration *sizeCfg =
    [UIImageSymbolConfiguration configurationWithPointSize:18.0
                                                    weight:UIImageSymbolWeightSemibold
                                                     scale:UIImageSymbolScaleMedium];

    // Merge color + size configs
    UIImageSymbolConfiguration *finalCfg =
        [colorCfg configurationByApplyingConfiguration:sizeCfg];

    UIImage *configured = [img imageByApplyingSymbolConfiguration:finalCfg];
    if (configured) return configured;

    // Fallback for non-symbol images
    UIImage *templ = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    return [self pp_resizedImage:templ toPointSize:18.0];
}


- (UIImage *)pp_symbolNamed:(NSString *)name
{
    UIImage *img = [UIImage imageNamed:name];
#if __IPHONE_13_0
    if (!img) { img = [UIImage systemImageNamed:name]; } // allow using a real SF symbol name too
#endif
    if (!img) { return nil; }
    
#if __IPHONE_13_0
    // Try to apply symbol configuration (has effect only for symbol images)
    UIImageSymbolConfiguration *cfg =
    [UIImageSymbolConfiguration configurationWithPointSize:22.0
                                                    weight:UIImageSymbolWeightSemibold
                                                     scale:UIImageSymbolScaleLarge];
    //NSArray *palette =@[AppSecondaryTextClr,AppSecondaryTextClr];
#if __IPHONE_15_0
   // if (palette.count > 0) {
   //     UIImageSymbolConfiguration *pal = [UIImageSymbolConfiguration configurationWithPaletteColors:palette];
   //     cfg = [cfg configurationByApplyingConfiguration:pal];
   // }
#endif
    
    UIImage *configured = [img imageByApplyingSymbolConfiguration:cfg];
    if (configured) {
        return configured;
    }
#endif
    
    // Not a symbol → make it a template so tint works, and optionally resize to approx. point size.
    UIImage *templ = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] ;
    return [self pp_resizedImage:templ toPointSize:18.0];
}

- (UIImage *)pp_resizedImage:(UIImage *)image toPointSize:(CGFloat)pointSize {
    if (!image) return nil;
    
    // Treat pointSize as target height; keep aspect
    CGFloat targetH = MAX(pointSize, 1.0);
    CGFloat aspect = image.size.width / MAX(image.size.height, 0.001);
    CGSize targetSize = CGSizeMake(targetH * aspect, targetH);
    
    UIGraphicsImageRenderer *renderer =
    [[UIGraphicsImageRenderer alloc] initWithSize:targetSize];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull ctx) {
        [image drawInRect:(CGRect){.origin=CGPointZero, .size=targetSize}];
    }];
}


@end














































@interface PPPaymentTabBar ()
@property (nonatomic, strong) NSArray<UIButton *> *tabButtons;
@property (nonatomic, assign, readwrite) PPPaymentTab selectedTab;
@end

@implementation PPPaymentTabBar

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.backgroundColor = UIColor.clearColor;
        self.layer.masksToBounds = NO;

        [self setupTabs];
        [self setSelectedTab:PPPaymentTabCard animated:NO];
    }
    return self;
}

#pragma mark - Setup

- (void)setupTabs {
    NSArray *titles = @[ @"Card", @"Ooredoo Money", @"PayPal" ];
    NSArray *icons  = @[ @"creditcard.fill", @"q.circle.fill", @"p.circle.fill" ];
    NSArray *colors = @[ UIColor.systemBlueColor, UIColor.systemRedColor, UIColor.systemIndigoColor ];

    NSMutableArray *buttons = [NSMutableArray array];

    for (NSInteger i = 0; i < titles.count; i++) {
        UIButton *btn = [self createGlassButtonWithTitle:titles[i]
                                                    icon:icons[i]
                                                   color:colors[i]];
        btn.tag = i;
        [btn addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [buttons addObject:btn];
    }

    self.tabButtons = buttons;
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:buttons];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 12;
    stack.alignment = UIStackViewAlignmentFill;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    [self addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:self.topAnchor constant:8],
        [stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-8],
        [stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12]
    ]];
}

- (UIButton *)createGlassButtonWithTitle:(NSString *)title
                                    icon:(NSString *)icon
                                   color:(UIColor *)tint {
    UIButton *button;

    if (@available(iOS 26.0, *)) {
        // 🧊 iOS 26 Modern glass button
        UIButtonConfiguration *cfg = [UIButtonConfiguration prominentGlassButtonConfiguration];
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.baseForegroundColor = tint;
        cfg.image = [UIImage systemImageNamed:icon];
        cfg.imagePadding = 6;
        cfg.imagePlacement = NSDirectionalRectEdgeTop;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(10, 14, 10, 14);

        NSMutableAttributedString *attrTitle = [[NSMutableAttributedString alloc] initWithString:title
                                                                                       attributes:@{
            NSFontAttributeName: [GM boldFontWithSize:16],
            NSForegroundColorAttributeName: UIColor.labelColor
        }];
        cfg.attributedTitle = attrTitle;

        button = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        button.configuration = cfg;
    } else {
        // 🌫️ Legacy fallback
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        button.layer.cornerRadius = 16;
        button.layer.masksToBounds = YES;

        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurView.translatesAutoresizingMaskIntoConstraints = NO;
        blurView.userInteractionEnabled = NO;
        [button insertSubview:blurView atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [blurView.topAnchor constraintEqualToAnchor:button.topAnchor],
            [blurView.bottomAnchor constraintEqualToAnchor:button.bottomAnchor],
            [blurView.leadingAnchor constraintEqualToAnchor:button.leadingAnchor],
            [blurView.trailingAnchor constraintEqualToAnchor:button.trailingAnchor]
        ]];

        [button setTitle:title forState:UIControlStateNormal];
        [button setImage:[UIImage systemImageNamed:icon] forState:UIControlStateNormal];
        [button setTintColor:tint];
        [button.titleLabel setFont:[UIFont boldSystemFontOfSize:15]];
    }

    return button;
}

#pragma mark - Actions

- (void)tabTapped:(UIButton *)sender {
    [self setSelectedTab:(PPPaymentTab)sender.tag animated:YES];
    if (self.onSelect) self.onSelect(self.selectedTab);
}

- (void)setSelectedTab:(PPPaymentTab)tab animated:(BOOL)animated {
    _selectedTab = tab;

    for (UIButton *btn in self.tabButtons) {
        BOOL isSelected = (btn.tag == tab);

        if (@available(iOS 26.0, *)) {
            UIButtonConfiguration *cfg = btn.configuration;
            cfg.baseBackgroundColor = isSelected
                ? [btn.configuration.baseForegroundColor colorWithAlphaComponent:0.15]
                : [UIColor clearColor];
            cfg.baseForegroundColor = btn.configuration.baseForegroundColor;
            btn.configuration = cfg;
        } else {
            btn.alpha = isSelected ? 1.0 : 0.6;
        }

        if (animated) {
            [UIView animateWithDuration:0.25 animations:^{
                btn.transform = isSelected ? CGAffineTransformMakeScale(1.05, 1.05)
                                           : CGAffineTransformIdentity;
            }];
        }
    }
}

@end
