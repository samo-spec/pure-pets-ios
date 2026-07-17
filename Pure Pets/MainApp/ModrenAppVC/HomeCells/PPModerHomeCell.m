#import "PPModerHomeCell.h"
#import "MainKindsModel.h"
#import "PPImageLoaderManager.h"

static inline UIColor *PPModerHomeDynamicColor(UIColor *lightColor, UIColor *darkColor)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
        }];
    }
    return lightColor;
}

static inline CGFloat PPModerHomePlateDimension(void)
{
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 96.0 : 72.0;
}

static inline CGFloat PPModerHomeArtworkDimension(BOOL isAll)
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return isAll ? 40.0 : 82.0;
    }
    return isAll ? 28.0 : 58.0;
}

static NSString * const PPModerHomeTapHaloAnimationKey = @"pp.moderHome.tapHalo";
static NSString * const PPModerHomeGlowCommitAnimationKey = @"pp.moderHome.glowCommit";

@interface PPModerHomeCell ()

@property (nonatomic, strong) UIButton *tapButton;
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *materialView;
@property (nonatomic, strong) UIView *imagePlateView;
@property (nonatomic, strong) UIImageView *kindImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *selectionIndicatorView;
@property (nonatomic, strong) CAGradientLayer *surfaceGradientLayer;
@property (nonatomic, strong) CAGradientLayer *accentWashLayer;
@property (nonatomic, strong) CAGradientLayer *bottomGlowLayer;
@property (nonatomic, strong) CAGradientLayer *tapHaloLayer;
@property (nonatomic, strong) CAShapeLayer *surfaceStrokeLayer;
@property (nonatomic, strong) NSLayoutConstraint *kindImageWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *kindImageHeightConstraint;
@property (nonatomic, strong, nullable) MainKindsModel *currentKind;
@property (nonatomic, assign) BOOL isAllOption;
@property (nonatomic, assign) BOOL isKindSelected;
@property (nonatomic, assign) BOOL usesRestoredSelectionAppearance;
@property (nonatomic, assign) BOOL isPressing;
@property (nonatomic, strong) UIColor *currentAccentColor;
@property (nonatomic, copy, nullable) NSString *currentImageURL;

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
    self.tapButton.accessibilityTraits = UIAccessibilityTraitButton;
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
    self.surfaceView.backgroundColor = UIColor.clearColor;
    self.surfaceView.layer.masksToBounds = NO;
    PPApplyContinuousCorners(self.surfaceView, PPCornerCard);
    [self.tapButton addSubview:self.surfaceView];

    self.materialView = [[UIView alloc] init];
    self.materialView.translatesAutoresizingMaskIntoConstraints = NO;
    self.materialView.userInteractionEnabled = NO;
    self.materialView.clipsToBounds = YES;
    PPApplyContinuousCorners(self.materialView, PPCornerCard);
    [self.surfaceView addSubview:self.materialView];

    self.surfaceGradientLayer = [CAGradientLayer layer];
    self.surfaceGradientLayer.startPoint = CGPointMake(0.15, 0.0);
    self.surfaceGradientLayer.endPoint = CGPointMake(0.85, 1.0);
    [self.materialView.layer insertSublayer:self.surfaceGradientLayer atIndex:0];

    self.accentWashLayer = [CAGradientLayer layer];
    self.accentWashLayer.startPoint = CGPointMake(0.5, 1.0);
    self.accentWashLayer.endPoint = CGPointMake(0.5, 0.0);
    self.accentWashLayer.locations = @[@0.0, @0.54, @1.0];
    [self.materialView.layer insertSublayer:self.accentWashLayer above:self.surfaceGradientLayer];

    self.bottomGlowLayer = [CAGradientLayer layer];
    self.bottomGlowLayer.name = @"PPMainKindsBottomGlowCircleLayer";
    self.bottomGlowLayer.startPoint = CGPointMake(0.5, 0.5);
    self.bottomGlowLayer.endPoint = CGPointMake(1.0, 1.0);
    self.bottomGlowLayer.locations = @[@0.0, @0.56, @1.0];
    self.bottomGlowLayer.opacity = 0.0;
    if (@available(iOS 12.0, *)) {
        self.bottomGlowLayer.type = kCAGradientLayerRadial;
    }
    [self.materialView.layer insertSublayer:self.bottomGlowLayer above:self.accentWashLayer];

    self.tapHaloLayer = [CAGradientLayer layer];
    self.tapHaloLayer.name = @"PPMainKindsTapHaloLayer";
    self.tapHaloLayer.startPoint = CGPointMake(0.5, 0.5);
    self.tapHaloLayer.endPoint = CGPointMake(1.0, 1.0);
    self.tapHaloLayer.locations = @[@0.0, @0.48, @1.0];
    self.tapHaloLayer.opacity = 0.0;
    if (@available(iOS 12.0, *)) {
        self.tapHaloLayer.type = kCAGradientLayerRadial;
    }
    [self.materialView.layer insertSublayer:self.tapHaloLayer above:self.bottomGlowLayer];

    self.surfaceStrokeLayer = [CAShapeLayer layer];
    self.surfaceStrokeLayer.fillColor = UIColor.clearColor.CGColor;
    self.surfaceStrokeLayer.lineJoin = kCALineJoinRound;
    self.surfaceStrokeLayer.contentsScale = UIScreen.mainScreen.scale;
    [self.surfaceView.layer addSublayer:self.surfaceStrokeLayer];

    self.imagePlateView = [[UIView alloc] init];
    self.imagePlateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.imagePlateView.userInteractionEnabled = NO;
    self.imagePlateView.clipsToBounds = YES;
    PPApplyContinuousCorners(self.imagePlateView, PPModerHomePlateDimension() * 0.5);
    [self.materialView addSubview:self.imagePlateView];

    self.kindImageView = [[UIImageView alloc] init];
    self.kindImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.kindImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.kindImageView.clipsToBounds = NO;
    self.kindImageView.isAccessibilityElement = NO;
    [self.imagePlateView addSubview:self.kindImageView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *baseTitleFont = [GM boldFontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    if (@available(iOS 11.0, *)) {
        self.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
                                scaledFontForFont:baseTitleFont
                                maximumPointSize:18.0];
    } else {
        self.titleLabel.font = baseTitleFont;
    }
    self.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.titleLabel.userInteractionEnabled = NO;
    self.titleLabel.isAccessibilityElement = NO;
    [self.materialView addSubview:self.titleLabel];

    self.selectionIndicatorView = [[UIView alloc] init];
    self.selectionIndicatorView.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionIndicatorView.userInteractionEnabled = NO;
    self.selectionIndicatorView.layer.cornerRadius = 1.5;
    self.selectionIndicatorView.layer.masksToBounds = YES;
    [self.materialView addSubview:self.selectionIndicatorView];

    CGFloat plateDimension = PPModerHomePlateDimension();
    self.kindImageWidthConstraint = [self.kindImageView.widthAnchor constraintEqualToConstant:PPModerHomeArtworkDimension(NO)];
    self.kindImageHeightConstraint = [self.kindImageView.heightAnchor constraintEqualToConstant:PPModerHomeArtworkDimension(NO)];
    NSLayoutConstraint *titleTopConstraint =
        [self.titleLabel.topAnchor constraintGreaterThanOrEqualToAnchor:self.imagePlateView.bottomAnchor
                                                               constant:PPSpaceXS];
    titleTopConstraint.priority = 999;

    [NSLayoutConstraint activateConstraints:@[
        [self.tapButton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.tapButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.tapButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.tapButton.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [self.surfaceView.topAnchor constraintEqualToAnchor:self.tapButton.topAnchor],
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.tapButton.leadingAnchor],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.tapButton.trailingAnchor],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.tapButton.bottomAnchor],

        [self.materialView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor],
        [self.materialView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor],
        [self.materialView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor],
        [self.materialView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor],

        [self.imagePlateView.topAnchor constraintEqualToAnchor:self.materialView.topAnchor constant:PPSpaceSM],
        [self.imagePlateView.centerXAnchor constraintEqualToAnchor:self.materialView.centerXAnchor],
        [self.imagePlateView.widthAnchor constraintEqualToConstant:plateDimension],
        [self.imagePlateView.heightAnchor constraintEqualToConstant:plateDimension],

        [self.kindImageView.centerXAnchor constraintEqualToAnchor:self.imagePlateView.centerXAnchor],
        [self.kindImageView.centerYAnchor constraintEqualToAnchor:self.imagePlateView.centerYAnchor],
        self.kindImageWidthConstraint,
        self.kindImageHeightConstraint,

        titleTopConstraint,
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.materialView.leadingAnchor constant:PPSpaceSM],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.materialView.trailingAnchor constant:-PPSpaceSM],
        [self.titleLabel.bottomAnchor constraintEqualToAnchor:self.materialView.bottomAnchor constant:-PPSpaceMD],

        [self.selectionIndicatorView.centerXAnchor constraintEqualToAnchor:self.materialView.centerXAnchor],
        [self.selectionIndicatorView.bottomAnchor constraintEqualToAnchor:self.materialView.bottomAnchor constant:-PPSpaceXS],
        [self.selectionIndicatorView.widthAnchor constraintEqualToConstant:28.0],
        [self.selectionIndicatorView.heightAnchor constraintEqualToConstant:3.0]
    ]];

    [self pp_applyPalette];
    [self pp_applySelection:NO animated:NO];
}

#pragma mark - Configure

- (void)configureWithMainKind:(nullable MainKindsModel *)kind
                        isAll:(BOOL)isAll
                     selected:(BOOL)selected
{
    [self configureWithMainKind:kind
                          isAll:isAll
                       selected:selected
    restoredSelectionAppearance:NO];
}

- (void)configureWithMainKind:(nullable MainKindsModel *)kind
                        isAll:(BOOL)isAll
                     selected:(BOOL)selected
  restoredSelectionAppearance:(BOOL)restoredSelectionAppearance
{
    NSString *nextCellID = isAll
        ? @"pp-main-kind-all"
        : [NSString stringWithFormat:@"%ld|%@|%@",
           (long)kind.ID,
           PPSafeString(kind.KindName),
           PPSafeString(kind.KindImageUrl)];
    BOOL sameBinding = [PPSafeString(self.boundCellID) isEqualToString:PPSafeString(nextCellID)];
    BOOL shouldAnimateSelection = sameBinding && self.window != nil && self.isKindSelected != selected;
    BOOL shouldRefreshImage = !sameBinding || self.kindImageView.image == nil;

    self.boundCellID = nextCellID;
    self.currentKind = kind;
    self.isAllOption = isAll;
    self.usesRestoredSelectionAppearance = selected && restoredSelectionAppearance;
    self.currentImageURL = PPSafeString(kind.KindImageUrl);
    self.currentAccentColor = [self pp_accentColorForKind:kind isAll:isAll];
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    NSString *title = isAll ? (kLang(@"all") ?: @"all") : PPSafeString(kind.KindName);
    self.titleLabel.text = title;
    self.tapButton.accessibilityLabel = title;
    self.tapButton.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);

    CGFloat artworkDimension = PPModerHomeArtworkDimension(isAll);
    self.kindImageWidthConstraint.constant = artworkDimension;
    self.kindImageHeightConstraint.constant = artworkDimension;

    if (shouldRefreshImage) {
        [self pp_configureImageForKind:kind isAll:isAll accent:self.currentAccentColor];
    } else if (isAll) {
        self.kindImageView.tintColor = self.currentAccentColor;
    }

    [self pp_applyPalette];
    [self pp_applySelection:selected animated:shouldAnimateSelection];
    [self setNeedsLayout];
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
                UIImageSymbolConfiguration *configuration =
                    [UIImageSymbolConfiguration configurationWithPointSize:24.0
                                                                    weight:UIImageSymbolWeightSemibold
                                                                     scale:UIImageSymbolScaleMedium];
                gridImage = [UIImage systemImageNamed:@"square.grid.2x2.fill" withConfiguration:configuration];
            }
        }
        self.kindImageView.image = [gridImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.kindImageView.tintColor = accent;
        return;
    }

    UIImage *placeholder = kind.KindImageFile;
    if (!placeholder && kind.KindImageNamed.length > 0) {
        placeholder = [UIImage imageNamed:kind.KindImageNamed];
    }
    if (!placeholder && kind.KindIconName.length > 0) {
        placeholder = [UIImage imageNamed:kind.KindIconName];
    }

    BOOL usesTemplatePlaceholder = NO;
    if (!placeholder && kind.KindIconName.length > 0) {
        if (@available(iOS 13.0, *)) {
            placeholder = [UIImage systemImageNamed:kind.KindIconName];
            usesTemplatePlaceholder = placeholder != nil;
        }
    }
    if (!placeholder) {
        if (@available(iOS 13.0, *)) {
            placeholder = [UIImage systemImageNamed:@"pawprint.fill"];
            usesTemplatePlaceholder = YES;
        }
    }

    self.kindImageView.tintColor = accent;
    self.kindImageView.image = usesTemplatePlaceholder
        ? [placeholder imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
        : [placeholder imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];

    if (self.currentImageURL.length > 0) {
        [[PPImageLoaderManager shared] setImageOnImageView:self.kindImageView
                                                       url:self.currentImageURL
                                               placeholder:self.kindImageView.image
                                           transitionStyle:PPImageTransitionStyleNone
                                                complation:nil];
    }
}

#pragma mark - Appearance

- (UIColor *)pp_accentColorForKind:(MainKindsModel *)kind isAll:(BOOL)isAll
{
    if (isAll || !kind) {
        return AppPrimaryClr ?: [GM appPrimaryColor] ?: [UIColor systemPinkColor];
    }
    return kind.kindColor ?: PPModerHomeDynamicColor(
        [UIColor colorWithRed:0.38 green:0.42 blue:0.48 alpha:1.0],
        [UIColor colorWithRed:0.72 green:0.75 blue:0.80 alpha:1.0]
    );
}

- (void)pp_applyPalette
{
    UIColor *surfaceTop = PPModerHomeDynamicColor(
        [UIColor colorWithWhite:1.0 alpha:0.92],
        [UIColor colorWithRed:0.13 green:0.14 blue:0.16 alpha:0.96]
    );
    UIColor *surfaceBottom = PPModerHomeDynamicColor(
        [UIColor colorWithWhite:0.985 alpha:0.78],
        [UIColor colorWithRed:0.08 green:0.09 blue:0.11 alpha:0.94]
    );
    UIColor *plateColor = PPModerHomeDynamicColor(
        [UIColor colorWithWhite:1.0 alpha:0.84],
        [UIColor colorWithWhite:1.0 alpha:0.075]
    );

    self.materialView.backgroundColor = PPModerHomeDynamicColor(
        [AppForgroundColr colorWithAlphaComponent:0.38] ?: [UIColor colorWithWhite:1.0 alpha:0.72],
        [UIColor colorWithRed:0.08 green:0.09 blue:0.11 alpha:0.92]
    );
    self.surfaceGradientLayer.colors = @[
        (__bridge id)surfaceTop.CGColor,
        (__bridge id)surfaceBottom.CGColor
    ];
    [self pp_applyBottomGlowPalette];
    self.imagePlateView.backgroundColor = plateColor;
    self.titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    [self pp_updateAccentWashColors];
}

- (void)pp_updateAccentWashColors
{
    UIColor *accent = self.currentAccentColor ?: [self pp_accentColorForKind:self.currentKind isAll:self.isAllOption];
    CGFloat leadingAlpha = self.isKindSelected ? 0.26 : 0.050;
    CGFloat middleAlpha = self.isKindSelected ? 0.105 : 0.012;
    self.accentWashLayer.colors = @[
        (__bridge id)[accent colorWithAlphaComponent:leadingAlpha].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:middleAlpha].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:0.0].CGColor
    ];
}

- (void)pp_applyBottomGlowPalette
{
    UIColor *accent = self.currentAccentColor ?: [self pp_accentColorForKind:self.currentKind isAll:self.isAllOption];
    if (!accent) {
        self.bottomGlowLayer.colors = nil;
        self.tapHaloLayer.colors = nil;
        return;
    }

    BOOL isAll = self.isAllOption;
    self.bottomGlowLayer.colors = @[
        (__bridge id)[accent colorWithAlphaComponent:isAll ? 0.18 : 0.28].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:isAll ? 0.13 : 0.19].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:0.0].CGColor
    ];
    [self pp_applyMotionLayerPaletteWithAccent:accent];
}

- (void)pp_applyMotionLayerPaletteWithAccent:(UIColor *)accent
{
    if (!accent) {
        self.tapHaloLayer.colors = nil;
        return;
    }

    self.tapHaloLayer.colors = @[
        (__bridge id)[accent colorWithAlphaComponent:0.30].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:0.10].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:0.0].CGColor
    ];
}

- (void)pp_applySelection:(BOOL)selected animated:(BOOL)animated
{
    self.isKindSelected = selected;
    UIColor *accent = self.currentAccentColor ?: [self pp_accentColorForKind:self.currentKind isAll:self.isAllOption];
    UIColor *regularStroke = [UIColor.whiteColor colorWithAlphaComponent:0.11];
    UIColor *selectedStroke = [accent colorWithAlphaComponent:self.isAllOption ? 0.58 : 0.48];
    BOOL borderlessRestoredSelection = selected && self.usesRestoredSelectionAppearance;
    CGFloat glowOpacity = [self pp_restingGlowOpacityForSelected:selected];

    void (^updates)(void) = ^{
        self.titleLabel.textColor = selected ? AppSecondaryTextClr : (AppPrimaryTextClr ?: UIColor.labelColor);
        self.selectionIndicatorView.backgroundColor = accent;
        self.selectionIndicatorView.alpha = selected ? 1.0 : 0.0;
        self.surfaceStrokeLayer.strokeColor = (borderlessRestoredSelection
                                               ? UIColor.clearColor
                                               : (selected ? selectedStroke : regularStroke)).CGColor;
        self.surfaceStrokeLayer.lineWidth = borderlessRestoredSelection
            ? 0.0
            : (selected ? 1.25 : (1.0 / UIScreen.mainScreen.scale));
        self.surfaceView.layer.shadowOpacity = selected ? 0.075 : 0.035;
        self.surfaceView.layer.shadowRadius = selected ? 16.0 : 12.0;
        self.surfaceView.layer.shadowOffset = CGSizeMake(0.0, selected ? 8.0 : 6.0);
        self.bottomGlowLayer.opacity = self.isPressing ? [self pp_pressedGlowOpacityForSelected:selected] : glowOpacity;
        self.tapButton.transform = self.isPressing ? [self pp_pressedTapTransform] : [self pp_restingTapTransform];
        self.accentWashLayer.opacity = 1.0;
    };

    [self pp_updateAccentWashColors];
    [self pp_applyBottomGlowPalette];
    self.surfaceView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.tapButton.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);

    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.24
                              delay:0.0
             usingSpringWithDamping:0.90
              initialSpringVelocity:0.20
                            options:UIViewAnimationOptionAllowUserInteraction |
                                    UIViewAnimationOptionBeginFromCurrentState
                         animations:updates
                         completion:nil];
    } else {
        updates();
    }
}

- (void)playRestoredSelectionAnimation
{
    if (!self.window || !self.isKindSelected || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    [self.layer removeAnimationForKey:@"pp.home.kind.restored.scale"];
    [self.surfaceStrokeLayer removeAnimationForKey:@"pp.home.kind.restored.stroke"];
    [self.accentWashLayer removeAnimationForKey:@"pp.home.kind.restored.wash"];

    if (!self.usesRestoredSelectionAppearance) {
        CABasicAnimation *strokeAnimation = [CABasicAnimation animationWithKeyPath:@"lineWidth"];
        strokeAnimation.fromValue = @(0.45);
        strokeAnimation.toValue = @(self.surfaceStrokeLayer.lineWidth);
        strokeAnimation.duration = 0.34;
        strokeAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        [self.surfaceStrokeLayer addAnimation:strokeAnimation forKey:@"pp.home.kind.restored.stroke"];
    }

    CABasicAnimation *washAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    washAnimation.fromValue = @(0.38);
    washAnimation.toValue = @(1.0);
    washAnimation.duration = 0.38;
    washAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    [self.accentWashLayer addAnimation:washAnimation forKey:@"pp.home.kind.restored.wash"];

    self.selectionIndicatorView.transform = CGAffineTransformMakeScale(0.72, 1.0);
    self.surfaceView.transform = CGAffineTransformMakeScale(0.992, 0.992);
    [UIView animateWithDuration:0.38
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.22
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.selectionIndicatorView.transform = CGAffineTransformIdentity;
        self.surfaceView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGRect bounds = self.surfaceView.bounds;
    if (CGRectIsEmpty(bounds)) {
        return;
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.surfaceGradientLayer.frame = self.materialView.bounds;
    self.accentWashLayer.frame = self.materialView.bounds;
    CGRect materialBounds = self.materialView.bounds;
    CGFloat glowDiameter = MIN(116.0, MAX(86.0, CGRectGetHeight(materialBounds) * 0.90));
    CGFloat glowX = Language.isRTL
        ? CGRectGetWidth(materialBounds) - glowDiameter + 24.0
        : -24.0;
    CGFloat glowY = CGRectGetHeight(materialBounds) - glowDiameter + 40.0;
    self.bottomGlowLayer.frame = CGRectIntegral(CGRectMake(glowX,
                                                           glowY,
                                                           glowDiameter,
                                                           glowDiameter));
    self.bottomGlowLayer.cornerRadius = glowDiameter * 0.5;

    CGFloat haloDiameter = MAX(CGRectGetWidth(materialBounds), CGRectGetHeight(materialBounds)) * 1.66;
    CGFloat haloX = (CGRectGetWidth(materialBounds) - haloDiameter) * 0.5;
    CGFloat haloY = CGRectGetHeight(materialBounds) - (haloDiameter * 0.74);
    self.tapHaloLayer.frame = CGRectIntegral(CGRectMake(haloX, haloY, haloDiameter, haloDiameter));
    self.tapHaloLayer.cornerRadius = haloDiameter * 0.5;

    CGFloat inset = MAX(0.5, self.surfaceStrokeLayer.lineWidth * 0.5);
    CGRect strokeBounds = CGRectInset(bounds, inset, inset);
    CGFloat strokeRadius = MAX(0.0, PPCornerCard - inset);
    self.surfaceStrokeLayer.frame = bounds;
    self.surfaceStrokeLayer.path = [UIBezierPath bezierPathWithRoundedRect:strokeBounds
                                                             cornerRadius:strokeRadius].CGPath;
    self.surfaceView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:bounds
                                                                  cornerRadius:PPCornerCard].CGPath;
    [CATransaction commit];
}

#pragma mark - Interaction

- (CGFloat)pp_restingGlowOpacityForSelected:(BOOL)selected
{
    if (selected) {
        return self.isAllOption ? 0.68 : 0.82;
    }
    return self.isAllOption ? 0.14 : 0.26;
}

- (CGFloat)pp_pressedGlowOpacityForSelected:(BOOL)selected
{
    return MIN(1.0, [self pp_restingGlowOpacityForSelected:selected] + (selected ? 0.20 : 0.04));
}

- (CGAffineTransform)pp_restingTapTransform
{
    return self.isKindSelected ? CGAffineTransformMakeScale(1.015, 1.015) : CGAffineTransformIdentity;
}

- (CGAffineTransform)pp_pressedTapTransform
{
    CGFloat scale = self.isKindSelected ? 0.978 : 0.958;
    return CGAffineTransformMakeScale(scale, scale);
}

- (void)pp_handleTouchDown
{
    [self pp_applyPressed:YES animated:YES];
}

- (void)pp_handleTouchUp
{
    [self pp_applyPressed:NO animated:YES];
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
    void (^updates)(void) = ^{
        self.tapButton.transform = pressed ? [self pp_pressedTapTransform] : [self pp_restingTapTransform];
        self.imagePlateView.transform = pressed ? CGAffineTransformMakeScale(0.90, 0.90) : CGAffineTransformIdentity;
        self.kindImageView.transform = pressed ? CGAffineTransformMakeScale(0.95, 0.95) : CGAffineTransformIdentity;
        self.titleLabel.transform = pressed ? CGAffineTransformMakeTranslation(0.0, 0.45) : CGAffineTransformIdentity;
        self.selectionIndicatorView.transform = pressed ? CGAffineTransformMakeScale(0.82, 1.0) : CGAffineTransformIdentity;
        self.bottomGlowLayer.opacity = pressed ? [self pp_pressedGlowOpacityForSelected:self.isKindSelected] : [self pp_restingGlowOpacityForSelected:self.isKindSelected];
        self.tapHaloLayer.opacity = pressed ? 0.28 : 0.0;
    };

    if (!animated || duration <= 0.0) {
        updates();
        return;
    }

    [UIView animateWithDuration:duration
                          delay:0.0
         usingSpringWithDamping:damping
          initialSpringVelocity:velocity
                        options:UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationOptionBeginFromCurrentState
                     animations:updates
                     completion:nil];
}

- (void)pp_performTapCommitMotion
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

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
                                 options:UIViewKeyframeAnimationOptionAllowUserInteraction |
                                         UIViewKeyframeAnimationOptionBeginFromCurrentState |
                                         UIViewKeyframeAnimationOptionCalculationModeCubic
                              animations:^{
        [UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:0.32 animations:^{
            CGFloat liftScale = self.isKindSelected ? 1.038 : 1.028;
            self.tapButton.transform = CGAffineTransformMakeScale(liftScale, liftScale);
            self.imagePlateView.transform = CGAffineTransformMakeScale(1.082, 1.082);
            self.kindImageView.transform = CGAffineTransformMakeScale(1.044, 1.044);
            self.selectionIndicatorView.transform = CGAffineTransformMakeScale(1.38, 1.0);
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
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(routeDelay * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
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
    self.usesRestoredSelectionAppearance = NO;
    self.isPressing = NO;
    self.titleLabel.text = nil;
    self.kindImageView.image = nil;
    self.tapButton.accessibilityLabel = nil;
    self.tapButton.accessibilityTraits = UIAccessibilityTraitButton;
    [self pp_resetTransientMotion];
    self.surfaceView.transform = CGAffineTransformIdentity;
    self.selectionIndicatorView.alpha = 0.0;
    self.accentWashLayer.opacity = 1.0;
    self.bottomGlowLayer.opacity = 0.0;
    self.bottomGlowLayer.frame = CGRectZero;
    self.tapHaloLayer.frame = CGRectZero;
    [self.surfaceStrokeLayer removeAnimationForKey:@"pp.home.kind.restored.stroke"];
    [self.accentWashLayer removeAnimationForKey:@"pp.home.kind.restored.wash"];
    [self pp_applyPalette];
    [self pp_applySelection:NO animated:NO];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applyPalette];
            [self pp_applySelection:self.isKindSelected animated:NO];
            [self setNeedsLayout];
        }
    }
}

@end
