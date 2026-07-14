#import "PPModerHomeCell.h"
#import "MainKindsModel.h"
#import "PPImageLoaderManager.h"

/// iPad shows these cells much larger, so the plate + kind artwork looked tiny at
/// the phone sizing. Scale them up on iPad only; phones stay unchanged.
static inline CGFloat PPModerHomeImageSizeScale(void)
{
    return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 2.0 : 1.4;
}

static inline UIColor *PPModerHomeDynamicColor(UIColor *lightColor, UIColor *darkColor)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
        }];
    }
    return lightColor;
}

static inline UIColor *PPModerHomeLightSurfaceColor(void)
{
    return [AppForgroundColr colorWithAlphaComponent:0.62] ?: [UIColor colorWithWhite:0.955 alpha:1.0];
}

static NSString * const PPModerHomeTapSheenAnimationKey = @"pp.moderHome.tapSheen";
static NSString * const PPModerHomeTapHaloAnimationKey = @"pp.moderHome.tapHalo";
static NSString * const PPModerHomeGlowCommitAnimationKey = @"pp.moderHome.glowCommit";

@interface PPModerHomeCell ()

@property (nonatomic, strong) UIButton *tapButton;
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *imagePlateView;
@property (nonatomic, strong) UIImageView *kindImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *selectionIndicatorView;
@property (nonatomic, strong) UIView *cornerPinView;
@property (nonatomic, strong) CAGradientLayer *surfaceGradientLayer;
@property (nonatomic, strong) CAGradientLayer *bottomGlowLayer;
@property (nonatomic, strong) CAGradientLayer *tapHaloLayer;
@property (nonatomic, strong) CAGradientLayer *tapSheenLayer;
@property (nonatomic, strong) NSLayoutConstraint *imagePlateWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *imagePlateHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *kindImageWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *kindImageHeightConstraint;
@property (nonatomic, strong, nullable) MainKindsModel *currentKind;
@property (nonatomic, assign) BOOL isAllOption;
@property (nonatomic, assign) BOOL isKindSelected;
@property (nonatomic, strong) UIColor *currentAccentColor;
@property (nonatomic, copy, nullable) NSString *currentImageURL;
@property (nonatomic, assign) BOOL didRunEntrance;
@property (nonatomic, assign) BOOL isPressing;

@end

@implementation PPModerHomeCell

+ (NSString *)reuseIdentifier
{
    return @"PPModerHomeCell";
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self pp_buildUI];
    }
    return self;
}

#pragma mark - UI

- (void)pp_buildUI
{
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.clipsToBounds = NO;
    self.layer.masksToBounds = NO;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    self.tapButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.tapButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.tapButton.adjustsImageWhenHighlighted = NO;
    self.tapButton.backgroundColor = UIColor.clearColor;
    self.tapButton.clipsToBounds = NO;
    self.tapButton.layer.masksToBounds = NO;
    [self.tapButton addTarget:self action:@selector(pp_handleTap) forControlEvents:UIControlEventTouchUpInside];
    [self.tapButton addTarget:self action:@selector(pp_handleTouchDown) forControlEvents:UIControlEventTouchDown];
    [self.tapButton addTarget:self action:@selector(pp_handleTouchDown) forControlEvents:UIControlEventTouchDragEnter];
    [self.tapButton addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchUpOutside];
    [self.tapButton addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchCancel];
    [self.tapButton addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchDragExit];
    [self.contentView addSubview:self.tapButton];

    self.surfaceView = [[UIView alloc] init];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.surfaceView.userInteractionEnabled = NO;
    self.surfaceView.layer.cornerRadius = PPNewCornerMin + 0;
    self.surfaceView.layer.masksToBounds = YES;
    self.surfaceView.layer.borderWidth = 1.0;
    if (@available(iOS 13.0, *)) {
        self.surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.tapButton addSubview:self.surfaceView];

    self.surfaceGradientLayer = [CAGradientLayer layer];
    self.surfaceGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.surfaceGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    self.surfaceGradientLayer.opacity = 0;
    [self.surfaceView.layer insertSublayer:self.surfaceGradientLayer atIndex:0];

    self.bottomGlowLayer = [CAGradientLayer layer];
    self.bottomGlowLayer.name = @"PPMainKindsBottomGlowCircleLayer";
    self.bottomGlowLayer.startPoint = CGPointMake(0.5, 0.5);
    self.bottomGlowLayer.endPoint = CGPointMake(1.0, 1.0);
    self.bottomGlowLayer.locations = @[@0.0, @0.56, @1.0];
    self.bottomGlowLayer.opacity = 0.0;
    if (@available(iOS 12.0, *)) {
        self.bottomGlowLayer.type = kCAGradientLayerRadial;
    }
    [self.surfaceView.layer insertSublayer:self.bottomGlowLayer above:self.surfaceGradientLayer];

    self.tapHaloLayer = [CAGradientLayer layer];
    self.tapHaloLayer.name = @"PPMainKindsTapHaloLayer";
    self.tapHaloLayer.startPoint = CGPointMake(0.5, 0.5);
    self.tapHaloLayer.endPoint = CGPointMake(1.0, 1.0);
    self.tapHaloLayer.locations = @[@0.0, @0.48, @1.0];
    self.tapHaloLayer.opacity = 0.0;
    if (@available(iOS 12.0, *)) {
        self.tapHaloLayer.type = kCAGradientLayerRadial;
    }
    [self.surfaceView.layer insertSublayer:self.tapHaloLayer above:self.bottomGlowLayer];

    self.tapSheenLayer = [CAGradientLayer layer];
    self.tapSheenLayer.name = @"PPMainKindsTapSheenLayer";
    self.tapSheenLayer.startPoint = CGPointMake(0.0, 0.5);
    self.tapSheenLayer.endPoint = CGPointMake(1.0, 0.5);
    self.tapSheenLayer.locations = @[@0.0, @0.46, @0.58, @1.0];
    self.tapSheenLayer.opacity = 0.0;
    [self.surfaceView.layer insertSublayer:self.tapSheenLayer above:self.tapHaloLayer];

    self.imagePlateView = [[UIView alloc] init];
    self.imagePlateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.imagePlateView.userInteractionEnabled = NO;
    self.imagePlateView.layer.cornerRadius = 26.0 * PPModerHomeImageSizeScale();
    self.imagePlateView.layer.masksToBounds = YES;
    self.imagePlateView.layer.borderWidth = 1.0;
    if (@available(iOS 13.0, *)) {
        self.imagePlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.surfaceView addSubview:self.imagePlateView];

    self.kindImageView = [[UIImageView alloc] init];
    self.kindImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.kindImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.kindImageView.clipsToBounds = NO;
    [self.imagePlateView addSubview:self.kindImageView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor = 0.92;
    self.titleLabel.userInteractionEnabled = NO;
    [self.surfaceView addSubview:self.titleLabel];

    self.selectionIndicatorView = [[UIView alloc] init];
    self.selectionIndicatorView.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionIndicatorView.userInteractionEnabled = NO;
    self.selectionIndicatorView.layer.cornerRadius = 1.75;
    self.selectionIndicatorView.layer.masksToBounds = YES;
    [self.surfaceView addSubview:self.selectionIndicatorView];

    self.cornerPinView = [[UIView alloc] init];
    self.cornerPinView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cornerPinView.userInteractionEnabled = NO;
    self.cornerPinView.layer.cornerRadius = 3.0;
    self.cornerPinView.layer.masksToBounds = YES;
    [self.surfaceView addSubview:self.cornerPinView];

    self.imagePlateWidthConstraint = [self.imagePlateView.widthAnchor constraintEqualToConstant:68.0];
    self.imagePlateHeightConstraint = [self.imagePlateView.heightAnchor constraintEqualToConstant:68.0];
    self.kindImageWidthConstraint = [self.kindImageView.widthAnchor constraintEqualToConstant:76.0];
    self.kindImageHeightConstraint = [self.kindImageView.heightAnchor constraintEqualToConstant:76.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.tapButton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.tapButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.tapButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.tapButton.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [self.surfaceView.topAnchor constraintEqualToAnchor:self.tapButton.topAnchor],
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.tapButton.leadingAnchor],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.tapButton.trailingAnchor],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.tapButton.bottomAnchor],

        [self.imagePlateView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:9.5],
        [self.imagePlateView.centerXAnchor constraintEqualToAnchor:self.surfaceView.centerXAnchor],
        self.imagePlateWidthConstraint,
        self.imagePlateHeightConstraint,

        [self.kindImageView.centerXAnchor constraintEqualToAnchor:self.imagePlateView.centerXAnchor],
        [self.kindImageView.centerYAnchor constraintEqualToAnchor:self.imagePlateView.centerYAnchor],
        self.kindImageWidthConstraint,
        self.kindImageHeightConstraint,

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:6.0],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-6.0],
       // [self.titleLabel.topAnchor constraintGreaterThanOrEqualToAnchor:self.imagePlateView.bottomAnchor constant:4.0],
        [self.titleLabel.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor constant:-14.0],

        [self.selectionIndicatorView.centerXAnchor constraintEqualToAnchor:self.surfaceView.centerXAnchor],
        [self.selectionIndicatorView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor constant:-5.0],
        [self.selectionIndicatorView.widthAnchor constraintEqualToConstant:30.0],
        [self.selectionIndicatorView.heightAnchor constraintEqualToConstant:3.0],

        [self.cornerPinView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:10.0],
        [self.cornerPinView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-10.0],
        [self.cornerPinView.widthAnchor constraintEqualToConstant:6.0],
        [self.cornerPinView.heightAnchor constraintEqualToConstant:6.0],
    ]];

    [self pp_setShadowColor:UIColor.blackColor];
    self.layer.shadowOpacity = 0.075;
    self.layer.shadowRadius = 15.0;
    self.layer.shadowOffset = CGSizeMake(0.0, 9.0);
    [self pp_applyBaseTheme];
}

#pragma mark - Configure

- (void)configureWithMainKind:(nullable MainKindsModel *)kind
                        isAll:(BOOL)isAll
                     selected:(BOOL)selected
{
    NSString *nextCellID = isAll
        ? @"pp-main-kind-all"
        : [NSString stringWithFormat:@"%ld|%@|%@",
           (long)kind.ID,
           PPSafeString(kind.KindName),
           PPSafeString(kind.KindImageUrl)];
    BOOL isSameBoundCell = [PPSafeString(self.boundCellID) isEqualToString:PPSafeString(nextCellID)];
    BOOL shouldAnimateSelection = isSameBoundCell && self.window != nil && self.isKindSelected != selected;
    BOOL shouldRefreshImage =
        !isSameBoundCell ||
        self.kindImageView.image == nil;

    self.boundCellID = nextCellID;
    self.currentKind = kind;
    self.isAllOption = isAll;
    self.isKindSelected = selected;
    self.currentImageURL = PPSafeString(kind.KindImageUrl);
    self.currentAccentColor = isAll ? [AppPrimaryClr colorWithAlphaComponent:0.78] : [self pp_accentColorForKind:kind isAll:isAll];

    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    NSString *title = isAll ? (kLang(@"all") ?: @"all") : PPSafeString(kind.KindName);
    self.titleLabel.text = title;
    self.tapButton.accessibilityLabel = title;

    if (shouldRefreshImage) {
        [self pp_configureImageForKind:kind isAll:isAll accent:self.currentAccentColor];
    } else {
        self.kindImageView.tintColor = self.currentAccentColor;
    }
    [self pp_applyBaseTheme];
    [self pp_applySelection:selected animated:shouldAnimateSelection];
    [self pp_updateImageSizingForAll:isAll];

    [self setNeedsLayout];
    [self.contentView setNeedsLayout];
    [self layoutIfNeeded];
    [self pp_runEntranceIfNeeded];
}

- (void)pp_configureImageForKind:(MainKindsModel *)kind
                           isAll:(BOOL)isAll
                          accent:(UIColor *)accent
{
    [[PPImageLoaderManager shared] cancelImageLoadForImageView:self.kindImageView];

    if (isAll) {
        UIImage *gridImage = [UIImage imageNamed:@"square-layout"];
        if (!gridImage) {
            if (@available(iOS 13.0, *)) {
                gridImage = [UIImage systemImageNamed:@"square.grid.2x2.fill"];
            }
        }
        self.kindImageView.image = [gridImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.kindImageView.tintColor = accent ?: (AppPrimaryClr ?: UIColor.labelColor);
        return;
    }

    UIImage *placeholder = kind.KindImageFile;
    if (!placeholder && kind.KindImageNamed.length > 0) {
        placeholder = [UIImage imageNamed:kind.KindImageNamed];
    }
    if (!placeholder && kind.KindIconName.length > 0) {
        placeholder = [UIImage imageNamed:kind.KindIconName];
    }
    if (!placeholder && kind.KindIconName.length > 0) {
        if (@available(iOS 13.0, *)) {
            placeholder = [UIImage systemImageNamed:kind.KindIconName];
        }
    }
    if (!placeholder) {
        if (@available(iOS 13.0, *)) {
            placeholder = [UIImage systemImageNamed:@"pawprint.fill"];
        }
    }

    self.kindImageView.tintColor = accent;
    self.kindImageView.image = [placeholder imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] ?: placeholder;

    if (self.currentImageURL.length > 0) {
        [[PPImageLoaderManager shared] setImageOnImageView:self.kindImageView
                                                       url:self.currentImageURL
                                               placeholder:self.kindImageView.image
                                           transitionStyle:PPImageTransitionStyleNone
                                                complation:nil];
    }
}

#pragma mark - Theme

- (void)pp_applyBaseTheme
{
    UIColor *surfaceTop = PPModerHomeDynamicColor(PPModerHomeLightSurfaceColor(),
                                                  [UIColor colorWithRed:0.10 green:0.11 blue:0.13 alpha:1.0]);
    UIColor *surfaceBottom = PPModerHomeDynamicColor(PPModerHomeLightSurfaceColor(),
                                                     [UIColor colorWithRed:0.07 green:0.08 blue:0.10 alpha:1.0]);
    UIColor *borderColor = PPModerHomeDynamicColor([AppForgroundColr colorWithAlphaComponent:0.95],
                                                   [AppForgroundColr colorWithAlphaComponent:0.08]);
    UIColor *plateColor = PPModerHomeDynamicColor([AppBackgroundClrLigter colorWithAlphaComponent:0.06],
                                                  [[UIColor whiteColor] colorWithAlphaComponent:0.63]);
    UIColor *plateBorder = PPModerHomeDynamicColor([[UIColor blackColor] colorWithAlphaComponent:0.045],
                                                   [[UIColor whiteColor] colorWithAlphaComponent:0.07]);
    UIColor *titleColor = AppPrimaryTextClr ?: UIColor.labelColor;
    UIColor *subtleText = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;

    self.surfaceGradientLayer.colors = @[
        (__bridge id)surfaceTop.CGColor,
        (__bridge id)surfaceBottom.CGColor
    ];
    self.surfaceView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.62];
    [self.surfaceView pp_setBorderColor:borderColor];

    [self pp_applyBottomGlowPalette];

    self.imagePlateView.backgroundColor = plateColor;
    [self.imagePlateView pp_setBorderColor:plateBorder];
    self.titleLabel.textColor = titleColor;
    self.cornerPinView.backgroundColor = [subtleText colorWithAlphaComponent:0.20];
}

- (UIColor *)pp_accentColorForKind:(MainKindsModel *)kind isAll:(BOOL)isAll
{
    if (isAll || !kind) {
        return AppPrimaryClr ?: [GM appPrimaryColor] ?: PPModerHomeDynamicColor([UIColor colorWithRed:0.788 green:0.188 blue:0.322 alpha:1.0],
                                                                                [UIColor colorWithRed:1.000 green:0.608 blue:0.702 alpha:1.0]);
    }

    UIColor *modelColor = kind.kindColor;
    if (modelColor) {
        return modelColor;
    }
    return PPModerHomeDynamicColor([UIColor colorWithRed:0.38 green:0.42 blue:0.48 alpha:1.0],
                                   [UIColor colorWithRed:0.72 green:0.75 blue:0.80 alpha:1.0]);
}

- (void)pp_applySelection:(BOOL)selected animated:(BOOL)animated
{
    self.isKindSelected = selected;
    UIColor *accent = self.currentAccentColor ?: [self pp_accentColorForKind:self.currentKind isAll:self.isAllOption];
    UIColor *selectedBorder = self.isAllOption ? [accent colorWithAlphaComponent:0.42] : [accent colorWithAlphaComponent:0.62];
    UIColor *regularBorder = PPModerHomeDynamicColor([[UIColor whiteColor] colorWithAlphaComponent:0.65],
                                                     [[UIColor whiteColor] colorWithAlphaComponent:0.08]);
    UIColor *plateColor = PPModerHomeDynamicColor([[UIColor whiteColor] colorWithAlphaComponent:0.68],
                                                  [[UIColor whiteColor] colorWithAlphaComponent:0.055]);
    CGFloat glowOpacity = [self pp_restingGlowOpacityForSelected:selected];

    void (^changes)(void) = ^{
        self.selectionIndicatorView.alpha = selected ? 1.0 : 0.0;
        self.cornerPinView.alpha = selected ? 1.0 : 0.36;
        self.selectionIndicatorView.backgroundColor = accent;
        self.cornerPinView.backgroundColor = [accent colorWithAlphaComponent:selected ? 0.78 : 0.26];
        self.titleLabel.textColor = selected ? accent : (AppPrimaryTextClr ?: UIColor.labelColor);
        [self.surfaceView pp_setBorderColor:selected ? selectedBorder : regularBorder];
        self.imagePlateView.backgroundColor = plateColor;
        self.layer.shadowOpacity = selected ? 0.12 : 0.075;
        self.layer.shadowRadius = selected ? 19.0 : 15.0;
        self.layer.shadowOffset = selected ? CGSizeMake(0.0, 11.0) : CGSizeMake(0.0, 9.0);
        self.bottomGlowLayer.opacity = self.isPressing ? [self pp_pressedGlowOpacityForSelected:selected] : glowOpacity;
        self.tapButton.transform = self.isPressing ? [self pp_pressedTapTransform] : [self pp_restingTapTransform];
    };

    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.24
                              delay:0.0
             usingSpringWithDamping:0.88
              initialSpringVelocity:0.48
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

- (void)pp_updateImageSizingForAll:(BOOL)isAll
{
    CGFloat scale = PPModerHomeImageSizeScale(); // 2x on iPad, 1x elsewhere
    self.imagePlateWidthConstraint.constant = (isAll ? 54.0 : 54.0) * scale;
    self.imagePlateHeightConstraint.constant = (isAll ? 54.0 : 54.0) * scale;
    self.kindImageWidthConstraint.constant = (isAll ? 24.0 : 46.0) * scale;
    self.kindImageHeightConstraint.constant = (isAll ? 24.0 : 46.0) * scale;
}

#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];

    // Force Auto Layout to resolve surfaceView bounds before reading them
    [self.tapButton layoutIfNeeded];
    [self.surfaceView layoutIfNeeded];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    CGRect surfaceBounds = self.surfaceView.bounds;
    if (CGRectIsEmpty(surfaceBounds)) {
        [CATransaction commit];
        return;
    }
    self.surfaceGradientLayer.frame = surfaceBounds;
    CGFloat glowDiameter = MIN(116.0, MAX(86.0, CGRectGetHeight(surfaceBounds) * 0.90));
    CGFloat glowX = Language.isRTL
        ? CGRectGetWidth(surfaceBounds) - glowDiameter + 24.0
        : -24.0;
    CGFloat glowY = CGRectGetHeight(surfaceBounds) - glowDiameter + 40.0;
    self.bottomGlowLayer.frame = CGRectIntegral(CGRectMake(glowX,
                                                            glowY,
                                                            glowDiameter,
                                                            glowDiameter));
    float corners = glowDiameter * 0.5;
    self.bottomGlowLayer.cornerRadius = corners;
    CGFloat haloDiameter = MAX(CGRectGetWidth(surfaceBounds), CGRectGetHeight(surfaceBounds)) * 1.36;
    CGFloat haloX = (CGRectGetWidth(surfaceBounds) - haloDiameter) * 0.5;
    CGFloat haloY = CGRectGetHeight(surfaceBounds) - (haloDiameter * 0.74);
    self.tapHaloLayer.frame = CGRectIntegral(CGRectMake(haloX, haloY, haloDiameter, haloDiameter));
    self.tapHaloLayer.cornerRadius = haloDiameter * 0.5;

    CGFloat sheenWidth = MAX(48.0, CGRectGetWidth(surfaceBounds) * 0.46);
    CGFloat sheenHeight = MAX(96.0, CGRectGetHeight(surfaceBounds) * 1.52);
    self.tapSheenLayer.anchorPoint = CGPointMake(0.5, 0.5);
    self.tapSheenLayer.bounds = CGRectIntegral(CGRectMake(0.0, 0.0, sheenWidth, sheenHeight));
    self.tapSheenLayer.position = CGPointMake(-sheenWidth * 0.58, CGRectGetMidY(surfaceBounds));
    CGFloat sheenRotation = Language.isRTL ? 0.6981317008 : -0.6981317008;
    self.tapSheenLayer.transform = CATransform3DMakeRotation(sheenRotation, 0.0, 0.0, 1.0);

    [self pp_applyBottomGlowPalette];
    self.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                    cornerRadius:corners].CGPath;
    [CATransaction commit];
}

- (void)pp_applyBottomGlowPalette
{
    UIColor *accent = self.currentAccentColor ?: [self pp_accentColorForKind:self.currentKind isAll:self.isAllOption];
    if (!accent) {
        self.bottomGlowLayer.colors = nil;
        self.tapHaloLayer.colors = nil;
        self.tapSheenLayer.colors = nil;
        return;
    }

    BOOL isAll = self.isAllOption;
    self.bottomGlowLayer.colors = @[
        (__bridge id)[accent colorWithAlphaComponent:isAll ? 0.30 : 0.38].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:isAll ? 0.13 : 0.19].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:0.0].CGColor
    ];
    [self pp_applyMotionLayerPaletteWithAccent:accent];
}

- (void)pp_applyMotionLayerPaletteWithAccent:(UIColor *)accent
{
    if (!accent) {
        self.tapHaloLayer.colors = nil;
        self.tapSheenLayer.colors = nil;
        return;
    }

    UIColor *white = UIColor.whiteColor;
    self.tapHaloLayer.colors = @[
        (__bridge id)[accent colorWithAlphaComponent:0.30].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:0.10].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:0.0].CGColor
    ];
    self.tapSheenLayer.colors = @[
        (__bridge id)[white colorWithAlphaComponent:0.0].CGColor,
        (__bridge id)[white colorWithAlphaComponent:0.34].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:0.18].CGColor,
        (__bridge id)[white colorWithAlphaComponent:0.0].CGColor
    ];
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    [super applyLayoutAttributes:layoutAttributes];
    [self setNeedsLayout];
    [self.contentView setNeedsLayout];
}

#pragma mark - Motion

- (CGFloat)pp_restingGlowOpacityForSelected:(BOOL)selected
{
    if (selected) {
        return self.isAllOption ? 0.50 : 0.82;
    }
    return self.isAllOption ? 0.18 : 0.52;
}

- (CGFloat)pp_pressedGlowOpacityForSelected:(BOOL)selected
{
    return MIN(1.0, [self pp_restingGlowOpacityForSelected:selected] + (selected ? 0.10 : 0.16));
}

- (CGAffineTransform)pp_restingTapTransform
{
    return self.isKindSelected ? CGAffineTransformMakeScale(1.015, 1.015) : CGAffineTransformIdentity;
}

- (CGAffineTransform)pp_pressedTapTransform
{
    CGFloat scale = self.isKindSelected ? 0.992 : 0.974;
    return CGAffineTransformMakeScale(scale, scale);
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
        [self pp_runEntranceIfNeeded];
    }
}

- (void)pp_runEntranceIfNeeded
{
    if (self.didRunEntrance || !self.window) {
        return;
    }
    self.didRunEntrance = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.alpha = 1.0;
        self.contentView.transform = CGAffineTransformIdentity;
        return;
    }

    self.alpha = 0.0;
    self.contentView.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    [UIView animateWithDuration:0.34
                          delay:0.02
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.alpha = 1.0;
        self.contentView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_applyPressed:(BOOL)pressed animated:(BOOL)animated
{
    self.isPressing = pressed;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        if (!pressed) {
            self.tapButton.transform = [self pp_restingTapTransform];
            self.imagePlateView.transform = CGAffineTransformIdentity;
            self.kindImageView.transform = CGAffineTransformIdentity;
            self.titleLabel.transform = CGAffineTransformIdentity;
            self.selectionIndicatorView.transform = CGAffineTransformIdentity;
            self.tapHaloLayer.opacity = 0.0;
            self.bottomGlowLayer.opacity = [self pp_restingGlowOpacityForSelected:self.isKindSelected];
        }
        return;
    }

    NSTimeInterval duration = pressed ? 0.11 : (animated ? 0.24 : 0.0);
    CGFloat damping = pressed ? 1.0 : 0.82;
    CGFloat velocity = pressed ? 0.0 : 0.42;
    void (^changes)(void) = ^{
        self.tapButton.transform = pressed ? [self pp_pressedTapTransform] : [self pp_restingTapTransform];
        self.imagePlateView.transform = pressed ? CGAffineTransformMakeScale(0.925, 0.925) : CGAffineTransformIdentity;
        self.kindImageView.transform = pressed ? CGAffineTransformMakeScale(0.965, 0.965) : CGAffineTransformIdentity;
        self.titleLabel.transform = pressed ? CGAffineTransformMakeTranslation(0.0, 0.45) : CGAffineTransformIdentity;
        self.selectionIndicatorView.transform = pressed ? CGAffineTransformMakeScale(0.82, 1.0) : CGAffineTransformIdentity;
        self.cornerPinView.alpha = pressed ? MIN(1.0, (self.isKindSelected ? 1.0 : 0.36) + 0.18) : (self.isKindSelected ? 1.0 : 0.36);
        self.bottomGlowLayer.opacity = pressed ? [self pp_pressedGlowOpacityForSelected:self.isKindSelected] : [self pp_restingGlowOpacityForSelected:self.isKindSelected];
        self.tapHaloLayer.opacity = pressed ? 0.28 : 0.0;
    };

    if (!animated || duration <= 0.0) {
        changes();
        return;
    }

    [UIView animateWithDuration:duration
                          delay:0.0
         usingSpringWithDamping:damping
          initialSpringVelocity:velocity
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:changes
                     completion:nil];
}

- (void)pp_performTapCommitMotion
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    [self pp_performTapSheenMotion];
    [self pp_performHaloBurstMotion];

    CGFloat restingGlow = [self pp_restingGlowOpacityForSelected:self.isKindSelected];
    CABasicAnimation *glowAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    glowAnimation.fromValue = @(MIN(1.0, restingGlow + 0.18));
    glowAnimation.toValue = @(restingGlow);
    glowAnimation.duration = 0.36;
    glowAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    self.bottomGlowLayer.opacity = restingGlow;
    [self.bottomGlowLayer addAnimation:glowAnimation forKey:PPModerHomeGlowCommitAnimationKey];

    [UIView animateKeyframesWithDuration:0.42
                                   delay:0.0
                                 options:UIViewKeyframeAnimationOptionAllowUserInteraction | UIViewKeyframeAnimationOptionBeginFromCurrentState | UIViewKeyframeAnimationOptionCalculationModeCubic
                              animations:^{
        [UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:0.32 animations:^{
            CGFloat liftScale = self.isKindSelected ? 1.026 : 1.018;
            self.tapButton.transform = CGAffineTransformMakeScale(liftScale, liftScale);
            self.imagePlateView.transform = CGAffineTransformMakeScale(1.055, 1.055);
            self.kindImageView.transform = CGAffineTransformMakeScale(1.028, 1.028);
            self.selectionIndicatorView.transform = CGAffineTransformMakeScale(1.18, 1.0);
        }];
        [UIView addKeyframeWithRelativeStartTime:0.32 relativeDuration:0.68 animations:^{
            self.tapButton.transform = [self pp_restingTapTransform];
            self.imagePlateView.transform = CGAffineTransformIdentity;
            self.kindImageView.transform = CGAffineTransformIdentity;
            self.titleLabel.transform = CGAffineTransformIdentity;
            self.selectionIndicatorView.transform = CGAffineTransformIdentity;
            self.tapHaloLayer.opacity = 0.0;
        }];
    } completion:nil];
}

- (void)pp_performTapSheenMotion
{
    CGRect bounds = self.surfaceView.bounds;
    if (CGRectIsEmpty(bounds)) {
        return;
    }

    [self.tapSheenLayer removeAnimationForKey:PPModerHomeTapSheenAnimationKey];
    self.tapSheenLayer.opacity = 0.0;

    CGFloat travelPadding = MAX(CGRectGetWidth(self.tapSheenLayer.bounds) * 0.9, 54.0);
    CGFloat fromX = Language.isRTL ? CGRectGetWidth(bounds) + travelPadding : -travelPadding;
    CGFloat toX = Language.isRTL ? -travelPadding : CGRectGetWidth(bounds) + travelPadding;

    CABasicAnimation *positionAnimation = [CABasicAnimation animationWithKeyPath:@"position.x"];
    positionAnimation.fromValue = @(fromX);
    positionAnimation.toValue = @(toX);

    CAKeyframeAnimation *opacityAnimation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    opacityAnimation.values = @[@0.0, @0.78, @0.0];
    opacityAnimation.keyTimes = @[@0.0, @0.42, @1.0];

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[positionAnimation, opacityAnimation];
    group.duration = 0.48;
    group.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.18 :0.74 :0.24 :1.0];
    group.removedOnCompletion = YES;
    [self.tapSheenLayer addAnimation:group forKey:PPModerHomeTapSheenAnimationKey];
}

- (void)pp_performHaloBurstMotion
{
    [self.tapHaloLayer removeAnimationForKey:PPModerHomeTapHaloAnimationKey];
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
    [self.tapHaloLayer addAnimation:group forKey:PPModerHomeTapHaloAnimationKey];
}

- (void)pp_emitTapHaptic
{
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        if (@available(iOS 13.0, *)) {
            [generator impactOccurredWithIntensity:0.62];
        } else {
            [generator impactOccurred];
        }
    }
}

- (void)pp_resetTransientMotion
{
    [self.tapSheenLayer removeAnimationForKey:PPModerHomeTapSheenAnimationKey];
    [self.tapHaloLayer removeAnimationForKey:PPModerHomeTapHaloAnimationKey];
    [self.bottomGlowLayer removeAnimationForKey:PPModerHomeGlowCommitAnimationKey];
    self.isPressing = NO;
    self.contentView.transform = CGAffineTransformIdentity;
    self.tapButton.transform = [self pp_restingTapTransform];
    self.imagePlateView.transform = CGAffineTransformIdentity;
    self.kindImageView.transform = CGAffineTransformIdentity;
    self.titleLabel.transform = CGAffineTransformIdentity;
    self.selectionIndicatorView.transform = CGAffineTransformIdentity;
    self.tapHaloLayer.opacity = 0.0;
    self.tapSheenLayer.opacity = 0.0;
}

- (void)pp_handleTouchDown
{
    [self pp_applyPressed:YES animated:YES];
}

- (void)pp_handleTouchUp
{
    [self pp_applyPressed:NO animated:YES];
}

- (void)pp_handleTap
{
    [self pp_applyPressed:NO animated:YES];
    [self pp_emitTapHaptic];
    [self pp_performTapCommitMotion];

    void (^selection)(MainKindsModel *_Nullable, BOOL) = [self.onSelect copy];
    if (!selection) {
        return;
    }

    MainKindsModel *kind = self.currentKind;
    BOOL isAll = self.isAllOption;
    NSTimeInterval routeDelay = UIAccessibilityIsReduceMotionEnabled() ? 0.0 : 0.055;
    if (routeDelay <= 0.0) {
        selection(kind, isAll);
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(routeDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            selection(kind, isAll);
        });
    }
}

#pragma mark - Reuse

- (void)prepareForReuse
{
    [super prepareForReuse];
    [[PPImageLoaderManager shared] cancelImageLoadForImageView:self.kindImageView];

    self.onSelect = nil;
    self.boundCellID = nil;
    self.currentKind = nil;
    self.currentImageURL = nil;
    self.currentAccentColor = nil;
    self.isAllOption = NO;
    self.isKindSelected = NO;
    self.didRunEntrance = NO;
    self.isPressing = NO;

    self.titleLabel.text = nil;
    self.tapButton.accessibilityLabel = nil;
    self.kindImageView.image = nil;
    self.kindImageView.tintColor = AppPrimaryTextClr ?: UIColor.labelColor;
    self.alpha = 1.0;
    [self pp_resetTransientMotion];
    self.selectionIndicatorView.alpha = 0.0;
    self.cornerPinView.alpha = 0.36;
    self.bottomGlowLayer.opacity = 0.0;
    self.bottomGlowLayer.frame = CGRectZero;
    self.tapHaloLayer.frame = CGRectZero;
    self.tapSheenLayer.frame = CGRectZero;
    [self pp_applyBaseTheme];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applyBaseTheme];
            [self pp_applySelection:self.isKindSelected animated:NO];
        }
    }
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    [self pp_applySelection:selected animated:YES];
}

@end
