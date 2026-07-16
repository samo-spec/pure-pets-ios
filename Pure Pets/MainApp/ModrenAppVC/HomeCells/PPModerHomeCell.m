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
@property (nonatomic, strong) CAShapeLayer *surfaceStrokeLayer;
@property (nonatomic, strong) NSLayoutConstraint *kindImageWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *kindImageHeightConstraint;
@property (nonatomic, strong, nullable) MainKindsModel *currentKind;
@property (nonatomic, assign) BOOL isAllOption;
@property (nonatomic, assign) BOOL isKindSelected;
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
    self.imagePlateView.backgroundColor = plateColor;
    self.titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    [self pp_updateAccentWashColors];
}

- (void)pp_updateAccentWashColors
{
    UIColor *accent = self.currentAccentColor ?: [self pp_accentColorForKind:self.currentKind isAll:self.isAllOption];
    CGFloat leadingAlpha = self.isKindSelected ? 0.17 : 0.065;
    CGFloat middleAlpha = self.isKindSelected ? 0.065 : 0.018;
    self.accentWashLayer.colors = @[
        (__bridge id)[accent colorWithAlphaComponent:leadingAlpha].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:middleAlpha].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:0.0].CGColor
    ];
}

- (void)pp_applySelection:(BOOL)selected animated:(BOOL)animated
{
    self.isKindSelected = selected;
    UIColor *accent = self.currentAccentColor ?: [self pp_accentColorForKind:self.currentKind isAll:self.isAllOption];
    UIColor *regularStroke = PPModerHomeDynamicColor(
        [UIColor.blackColor colorWithAlphaComponent:0.055],
        [UIColor.whiteColor colorWithAlphaComponent:0.11]
    );
    UIColor *selectedStroke = [accent colorWithAlphaComponent:self.isAllOption ? 0.58 : 0.48];

    void (^updates)(void) = ^{
        self.titleLabel.textColor = selected ? accent : (AppPrimaryTextClr ?: UIColor.labelColor);
        self.selectionIndicatorView.backgroundColor = accent;
        self.selectionIndicatorView.alpha = selected ? 1.0 : 0.0;
        self.surfaceStrokeLayer.strokeColor = (selected ? selectedStroke : regularStroke).CGColor;
        self.surfaceStrokeLayer.lineWidth = selected ? 1.25 : (1.0 / UIScreen.mainScreen.scale);
        self.surfaceView.layer.shadowOpacity = selected ? 0.075 : 0.035;
        self.surfaceView.layer.shadowRadius = selected ? 16.0 : 12.0;
        self.surfaceView.layer.shadowOffset = CGSizeMake(0.0, selected ? 8.0 : 6.0);
        self.tapButton.transform = self.isPressing ? CGAffineTransformMakeScale(0.97, 0.97) : CGAffineTransformIdentity;
        self.imagePlateView.transform = self.isPressing ? CGAffineTransformMakeScale(0.96, 0.96) : CGAffineTransformIdentity;
        self.accentWashLayer.opacity = 1.0;
    };

    [self pp_updateAccentWashColors];
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

- (void)pp_handleTouchDown
{
    [self pp_setPressed:YES animated:YES];
}

- (void)pp_handleTouchUp
{
    [self pp_setPressed:NO animated:YES];
}

- (void)pp_setPressed:(BOOL)pressed animated:(BOOL)animated
{
    self.isPressing = pressed;
    CGAffineTransform cardTransform = pressed ? CGAffineTransformMakeScale(0.97, 0.97) : CGAffineTransformIdentity;
    CGAffineTransform imageTransform = pressed ? CGAffineTransformMakeScale(0.96, 0.96) : CGAffineTransformIdentity;
    CGFloat washOpacity = pressed ? 0.78 : 1.0;

    void (^updates)(void) = ^{
        self.tapButton.transform = cardTransform;
        self.imagePlateView.transform = imageTransform;
        self.accentWashLayer.opacity = washOpacity;
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        updates();
        return;
    }

    [UIView animateWithDuration:pressed ? 0.09 : 0.20
                          delay:0.0
         usingSpringWithDamping:pressed ? 1.0 : 0.86
          initialSpringVelocity:pressed ? 0.0 : 0.28
                        options:UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationOptionBeginFromCurrentState
                     animations:updates
                     completion:nil];
}

- (void)pp_handleTap
{
    [self pp_setPressed:NO animated:YES];
    if (@available(iOS 10.0, *)) {
        UISelectionFeedbackGenerator *feedback = [[UISelectionFeedbackGenerator alloc] init];
        [feedback selectionChanged];
    }

    void (^selection)(MainKindsModel *_Nullable, BOOL) = [self.onSelect copy];
    if (selection) {
        selection(self.currentKind, self.isAllOption);
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
    self.isPressing = NO;
    self.titleLabel.text = nil;
    self.kindImageView.image = nil;
    self.tapButton.accessibilityLabel = nil;
    self.tapButton.accessibilityTraits = UIAccessibilityTraitButton;
    self.tapButton.transform = CGAffineTransformIdentity;
    self.imagePlateView.transform = CGAffineTransformIdentity;
    self.selectionIndicatorView.alpha = 0.0;
    self.accentWashLayer.opacity = 1.0;
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
