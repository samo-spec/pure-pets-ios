#import "PPSectionHeaderView.h"
#import <QuartzCore/QuartzCore.h>

static CGFloat PPSectionHeaderPixel(void) {
    return 1.0 / UIScreen.mainScreen.scale;
}

static const CGFloat PPSectionHeaderSurfaceRadius = 14.0;
static const CGFloat PPSectionHeaderOuterVerticalInset = 0.0;
static const CGFloat PPSectionHeaderContentLeading = 16.0;
static const CGFloat PPSectionHeaderContentTrailing = 0.0;
static const CGFloat PPSectionHeaderContentVerticalInset = 0.0;
static const CGFloat PPSectionHeaderAccentWidth = 8.0;
static const CGFloat PPSectionHeaderAccentHeight = 8.0;
static const CGFloat PPSectionHeaderActionMinHeight = 36.0;
static const CGFloat PPSectionHeaderActionMinWidth = 34.0;
static const CGFloat PPSectionHeaderActionMaxWidth = 184.0;
static NSString * const PPSectionHeaderLineSweepAnimationKey = @"pp.sectionHeader.line.sweep";
static NSString * const PPSectionHeaderLineBreathAnimationKey = @"pp.sectionHeader.line.breath";

@interface PPSectionHeaderView () <UIGestureRecognizerDelegate>

@property (nonatomic, strong, readwrite) UILabel *titleLabel;
@property (nonatomic, strong, readwrite) UILabel *subtitleLabel;
@property (nonatomic, strong, readwrite) UIButton *actionButton;

@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *materialWashView;
@property (nonatomic, strong) UIView *topSheenView;
@property (nonatomic, strong) UIView *tapHighlightView;
@property (nonatomic, strong) UIView *accentRailView;
@property (nonatomic, strong) UIView *lineView;
@property (nonatomic, strong) UIStackView *contentStackView;
@property (nonatomic, strong) UIStackView *textStackView;
@property (nonatomic, strong) CAGradientLayer *lineTrackLayer;
@property (nonatomic, strong) CAGradientLayer *lineAfterglowLayer;
@property (nonatomic, strong) CAGradientLayer *lineSweepLayer;

@property (nonatomic, strong) NSLayoutConstraint *accentRailWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *accentRailHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *actionButtonCircleWidthConstraint;

@property (nonatomic, assign) BOOL isExpanded;
@property (nonatomic, assign) BOOL actionButtonUsesCirclePresentation;
@property (nonatomic, assign) BOOL surfaceDecorationActive;
@property (nonatomic, assign) PPHomeSection currentSection;
@property (nonatomic, assign) CFTimeInterval lastActionTimestamp;
@property (nonatomic, assign) CGSize lineMotionLayoutSize;
@property (nonatomic, copy, nullable) NSString *actionAccessibilityTitle;

- (void)pp_installLineMotionLayerIfNeeded;
- (void)pp_updateLineMotionLayerAppearance;
- (void)pp_startLineMotionIfNeeded;
- (void)pp_stopLineMotion;
- (void)pp_applyActionButtonPresentationWithActionTitle:(nullable NSString *)actionTitle
                                               iconName:(nullable NSString *)iconName
                                                   menu:(nullable UIMenu *)menu
                                                section:(PPHomeSection)section
                                        subtitleVisible:(BOOL)subtitleVisible;

@end

@implementation PPSectionHeaderView

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self pp_buildUI];
    }
    return self;
}

#pragma mark - Build UI

- (void)pp_buildUI
{
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;
    self.layer.masksToBounds = NO;
    self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.preservesSuperviewLayoutMargins = YES;
    self.isAccessibilityElement = NO;

    [self pp_buildSurface];
    [self pp_buildLabels];
    [self pp_buildActionButton];
    [self pp_buildStacks];
    [self pp_installTapGesture];
    [self pp_refreshAppearance];
}

- (void)pp_buildSurface
{
    self.surfaceView = [[UIView alloc] init];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.surfaceView.userInteractionEnabled = YES;
    self.surfaceView.clipsToBounds = NO;
    self.surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    self.surfaceView.layer.cornerRadius = PPSectionHeaderSurfaceRadius;
    self.surfaceView.layer.borderWidth = 0;//PPSectionHeaderPixel();
    //self.surfaceView.backgroundColor = [self pp_surfaceFillColor];
    self.surfaceView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.surfaceView.layer.shadowOpacity = 0.05;
    self.surfaceView.layer.shadowRadius = 16.0;
    self.surfaceView.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    [self addSubview:self.surfaceView];

    self.materialWashView = [[UIView alloc] init];
    self.materialWashView.translatesAutoresizingMaskIntoConstraints = NO;
    self.materialWashView.userInteractionEnabled = NO;
    self.materialWashView.clipsToBounds = YES;
    self.materialWashView.layer.cornerCurve = kCACornerCurveContinuous;
    self.materialWashView.layer.cornerRadius = PPSectionHeaderSurfaceRadius;
    [self.surfaceView addSubview:self.materialWashView];

    self.topSheenView = [[UIView alloc] init];
    self.topSheenView.translatesAutoresizingMaskIntoConstraints = NO;
    self.topSheenView.userInteractionEnabled = NO;
    [self.surfaceView addSubview:self.topSheenView];

    self.tapHighlightView = [[UIView alloc] init];
    self.tapHighlightView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tapHighlightView.userInteractionEnabled = NO;
    self.tapHighlightView.alpha = 0.0;
    self.tapHighlightView.clipsToBounds = YES;
    self.tapHighlightView.layer.cornerCurve = kCACornerCurveContinuous;
    self.tapHighlightView.layer.cornerRadius = PPSectionHeaderSurfaceRadius;
    [self.surfaceView addSubview:self.tapHighlightView];

    self.accentRailView = [[UIView alloc] init];
    self.accentRailView.translatesAutoresizingMaskIntoConstraints = NO;
    self.accentRailView.userInteractionEnabled = NO;
    self.accentRailView.layer.cornerRadius = PPSectionHeaderAccentWidth * 0.5;
    self.accentRailView.layer.cornerCurve = kCACornerCurveContinuous;
    [self.surfaceView addSubview:self.accentRailView];

    self.accentRailWidthConstraint =
        [self.accentRailView.widthAnchor constraintEqualToConstant:PPSectionHeaderAccentWidth];
    self.accentRailHeightConstraint =
        [self.accentRailView.heightAnchor constraintEqualToConstant:PPSectionHeaderAccentHeight];

    [NSLayoutConstraint activateConstraints:@[
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:0.0],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-0.0],
        [self.surfaceView.topAnchor constraintEqualToAnchor:self.topAnchor constant:0],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-0.0],

        [self.materialWashView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor],
        [self.materialWashView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor],
        [self.materialWashView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor],
        [self.materialWashView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor],

        [self.topSheenView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:0.0],
        [self.topSheenView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-0.0],
        [self.topSheenView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor],
        [self.topSheenView.heightAnchor constraintEqualToConstant:PPSectionHeaderPixel()],

        [self.tapHighlightView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor],
        [self.tapHighlightView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor],
        [self.tapHighlightView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor],
        [self.tapHighlightView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor],

        [self.accentRailView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:10.0],
        [self.accentRailView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        self.accentRailWidthConstraint,
        self.accentRailHeightConstraint,
    ]];
}

- (void)pp_buildLabels
{
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [self pp_titleFont];
    self.titleLabel.textColor = [self pp_titleColor];
    self.titleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.titleLabel.adjustsFontSizeToFitWidth = NO;
    self.titleLabel.allowsDefaultTighteningForTruncation = YES;
    self.titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [self.titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh
                                                     forAxis:UILayoutConstraintAxisVertical];

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = [self pp_subtitleFont];
    self.subtitleLabel.textColor = [self pp_subtitleColor];
    self.subtitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.subtitleLabel.numberOfLines = 1;
    self.subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.subtitleLabel.adjustsFontForContentSizeCategory = YES;
    self.subtitleLabel.hidden = YES;
    [self.subtitleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh
                                                        forAxis:UILayoutConstraintAxisVertical];

    [self.titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.subtitleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
}

- (void)pp_buildActionButton
{
    self.actionButton = [UIButton buttonWithConfiguration:[self pp_baseActionButtonConfiguration]
                                            primaryAction:nil];
    self.actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionButton.hidden = YES;
    self.actionButton.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.actionButton.layer.cornerRadius = 8.0;
    self.actionButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.actionButton.clipsToBounds = YES;
    self.actionButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.actionButton.titleLabel.minimumScaleFactor = 0.88;
    self.actionButton.accessibilityTraits = UIAccessibilityTraitButton;
    [self.actionButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.actionButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.actionButton addTarget:self
                          action:@selector(pp_actionTapped)
                forControlEvents:UIControlEventTouchUpInside];

    NSLayoutConstraint *actionHeight = [self.actionButton.heightAnchor constraintGreaterThanOrEqualToConstant:PPSectionHeaderActionMinHeight];
    actionHeight.priority = UILayoutPriorityDefaultHigh;
    self.actionButtonCircleWidthConstraint =
        [self.actionButton.widthAnchor constraintEqualToConstant:PPSectionHeaderActionMinHeight];
    self.actionButtonCircleWidthConstraint.active = NO;
    [NSLayoutConstraint activateConstraints:@[
        actionHeight,
        [self.actionButton.widthAnchor constraintGreaterThanOrEqualToConstant:PPSectionHeaderActionMinWidth],
        [self.actionButton.widthAnchor constraintLessThanOrEqualToConstant:PPSectionHeaderActionMaxWidth],
    ]];
}

- (void)pp_buildStacks
{
    self.lineView = [[UIView alloc] init];
    self.lineView.translatesAutoresizingMaskIntoConstraints = NO;
    self.lineView.layer.cornerRadius = 0.5;
    self.lineView.clipsToBounds = YES;
    self.lineView.backgroundColor = UIColor.clearColor;
    [self.lineView setContentHuggingPriority:100 forAxis:UILayoutConstraintAxisHorizontal];
    [self.lineView setContentCompressionResistancePriority:100 forAxis:UILayoutConstraintAxisHorizontal];
    [self.lineView.heightAnchor constraintEqualToConstant:0.0].active = YES;
    [self pp_installLineMotionLayerIfNeeded];
    self.lineView.alpha = 0;
    self.textStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.titleLabel,
        self.lineView,
        self.actionButton
    ]];
    self.textStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textStackView.axis = UILayoutConstraintAxisHorizontal;
    self.textStackView.alignment = UIStackViewAlignmentCenter;
    self.textStackView.distribution = UIStackViewDistributionFill;
    self.textStackView.spacing = 12.0;
    self.textStackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    if (@available(iOS 11.0, *)) {
        [self.textStackView setCustomSpacing:16.0 afterView:self.titleLabel];
        [self.textStackView setCustomSpacing:16.0 afterView:self.lineView];
    }


    self.contentStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.textStackView,
        self.subtitleLabel
    ]];
    self.contentStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStackView.axis = UILayoutConstraintAxisVertical;
    self.contentStackView.alignment = UIStackViewAlignmentFill;
    self.contentStackView.distribution = UIStackViewDistributionFill;
    self.contentStackView.spacing = -4.0;
    self.contentStackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    [self.contentStackView setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [self.contentStackView setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];

    [self.surfaceView addSubview:self.contentStackView];

    NSLayoutConstraint *contentTopConstraint =
        [self.contentStackView.topAnchor constraintGreaterThanOrEqualToAnchor:self.surfaceView.topAnchor constant:PPSectionHeaderContentVerticalInset];
    NSLayoutConstraint *contentBottomConstraint =
        [self.contentStackView.bottomAnchor constraintLessThanOrEqualToAnchor:self.surfaceView.bottomAnchor constant:-PPSectionHeaderContentVerticalInset];
    contentTopConstraint.priority = UILayoutPriorityDefaultHigh;
    contentBottomConstraint.priority = UILayoutPriorityDefaultHigh;

    [NSLayoutConstraint activateConstraints:@[
        [self.contentStackView.leadingAnchor constraintEqualToAnchor:self.accentRailView.trailingAnchor constant:8.0],
        [self.contentStackView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-0.0],
        [self.contentStackView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        contentTopConstraint,
        contentBottomConstraint,
    ]];
}

- (void)pp_installTapGesture
{
    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_actionTapped)];
    tap.delegate = self;
    tap.cancelsTouchesInView = NO;
    [self addGestureRecognizer:tap];
}

#pragma mark - Appearance

- (UIButtonConfiguration *)pp_baseActionButtonConfiguration
{
    UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
    cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    cfg.contentInsets = NSDirectionalEdgeInsetsMake(8.0, 14.0, 8.0, 14.0);
    cfg.imagePadding = 6.0;
    cfg.imagePlacement = NSDirectionalRectEdgeTrailing;
    cfg.baseForegroundColor = [self pp_accentColor];

    UIBackgroundConfiguration *background = [UIBackgroundConfiguration clearConfiguration];
    background.cornerRadius = PPSectionHeaderActionMinHeight * 0.5;
    background.strokeWidth = 0.08;//PPSectionHeaderPixel();
    background.strokeColor = [[self pp_accentColor] colorWithAlphaComponent:[self pp_isDarkMode] ? 0.24 : 0.10];
    background.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:[self pp_isDarkMode] ? 0.14 : 0.095];
    cfg.background = background;

    UIImageSymbolConfiguration *symbolConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:12.5
                                                        weight:UIImageSymbolWeightSemibold
                                                         scale:UIImageSymbolScaleMedium];
    UIImage *chevron = [UIImage systemImageNamed:@"chevron.down" withConfiguration:symbolConfig];
    if (@available(iOS 15.0, *)) {
        chevron = [chevron imageByApplyingSymbolConfiguration:
                   [UIImageSymbolConfiguration configurationWithPaletteColors:@[[self pp_accentColor]]]];
    }
    cfg.image = chevron;

    return cfg;
}

- (UIButtonConfiguration *)pp_actionButtonConfigurationForSubtitleVisible:(BOOL)subtitleVisible
{
    UIButtonConfiguration *cfg = [self pp_baseActionButtonConfiguration];
    cfg.imagePlacement = NSDirectionalRectEdgeTrailing;
    cfg.imagePadding = subtitleVisible ? 0.0 : 6.0;
    cfg.contentInsets = subtitleVisible
        ? NSDirectionalEdgeInsetsMake(8.0, 8.0, 8.0, 8.0)
        : NSDirectionalEdgeInsetsMake(8.0, 14.0, 8.0, 14.0);

    UIBackgroundConfiguration *background = cfg.background ?: [UIBackgroundConfiguration clearConfiguration];
    background.cornerRadius = PPSectionHeaderActionMinHeight * 0.5;
    background.strokeWidth = 0.0;
    cfg.background = background;
    return cfg;
}

- (void)pp_refreshAppearance
{
    BOOL decorationActive = self.surfaceDecorationActive;
    BOOL darkMode = [self pp_isDarkMode];
    UIColor *accentColor = [self pp_accentColor];

    self.surfaceView.backgroundColor = UIColor.clearColor;
    self.surfaceView.layer.borderColor = UIColor.clearColor.CGColor;
    self.surfaceView.layer.shadowColor = UIColor.clearColor.CGColor;
    self.surfaceView.layer.shadowOpacity = 0.0;
    self.surfaceView.layer.shadowRadius = 0.0;
    self.surfaceView.layer.shadowOffset = CGSizeZero;

    self.materialWashView.backgroundColor = UIColor.clearColor;
    self.topSheenView.backgroundColor = UIColor.clearColor;
    self.tapHighlightView.backgroundColor = [accentColor colorWithAlphaComponent:(darkMode ? 0.16 : 0.01)];

    self.accentRailView.backgroundColor = [accentColor colorWithAlphaComponent:0.28];
    self.accentRailView.alpha = decorationActive ? 1.0 : 0.68;
    self.lineView.backgroundColor = UIColor.clearColor;
    [self pp_updateLineMotionLayerAppearance];
    self.titleLabel.textColor = [self pp_titleColor];
    self.subtitleLabel.textColor = [self pp_subtitleColor];

    UIButtonConfiguration *cfg = self.actionButton.configuration ?: [self pp_baseActionButtonConfiguration];
    UIBackgroundConfiguration *background = cfg.background ?: [UIBackgroundConfiguration clearConfiguration];
    background.cornerRadius = self.actionButtonUsesCirclePresentation ? PPSectionHeaderActionMinHeight * 0.5 : ((PPSectionHeaderActionMinHeight * 0.5) - 4);
    background.strokeWidth = 0.0;//PPSectionHeaderPixel();
    background.strokeColor = [accentColor colorWithAlphaComponent:self.actionButtonUsesCirclePresentation ? (darkMode ? 0.26 : 0.08) : (darkMode ? 0.24 : 0.28)];
    background.backgroundColor = [accentColor colorWithAlphaComponent:self.actionButtonUsesCirclePresentation ? (darkMode ? 0.16 : 0.065) : (darkMode ? 0.22 : 0.025)];
    cfg.background = background;
    cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    cfg.baseForegroundColor = [accentColor colorWithAlphaComponent:0.82];
    cfg.baseForegroundColor = [AppPrimaryClr colorWithAlphaComponent:0.22];
    self.actionButton.configuration = cfg;
    self.actionButton.layer.cornerRadius = PPSectionHeaderActionMinHeight * 0.5;
    self.actionButton.layer.cornerCurve = kCACornerCurveContinuous;
}

- (UIColor *)pp_accentColor
{
    return AppPrimaryClr ?: UIColor.systemTealColor;
}

- (UIColor *)pp_titleColor
{
    return AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
}

- (UIColor *)pp_subtitleColor
{
    return AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
}

- (UIColor *)pp_surfaceFillColor
{
    return UIColor.clearColor;
}

- (UIColor *)pp_surfaceBorderColor
{
    return UIColor.clearColor;
}

- (UIFont *)pp_titleFont
{
    UIFont *font = [GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightBold];
    return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline] scaledFontForFont:font];
}

- (UIFont *)pp_subtitleFont
{
    UIFont *font = [GM MidFontWithSize:12.5] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:font];
}

- (UIFont *)pp_actionFont
{
    UIFont *font = [GM MidFontWithSize:11.5] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1] scaledFontForFont:font];
}

- (BOOL)pp_isDarkMode
{
    return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
}

#pragma mark - Line Motion

- (void)pp_installLineMotionLayerIfNeeded
{
    if (self.lineTrackLayer && self.lineAfterglowLayer && self.lineSweepLayer) {
        return;
    }

    self.lineView.layer.masksToBounds = YES;

    if (!self.lineTrackLayer) {
        CAGradientLayer *trackLayer = [CAGradientLayer layer];
        trackLayer.startPoint = CGPointMake(0.0, 0.5);
        trackLayer.endPoint = CGPointMake(1.0, 0.5);
        trackLayer.locations = @[@0.0, @0.18, @0.5, @0.82, @1.0];
        trackLayer.opacity = 1.0;
        self.lineTrackLayer = trackLayer;
        [self.lineView.layer addSublayer:trackLayer];
    }

    if (!self.lineAfterglowLayer) {
        CAGradientLayer *afterglowLayer = [CAGradientLayer layer];
        afterglowLayer.startPoint = CGPointMake(0.0, 0.5);
        afterglowLayer.endPoint = CGPointMake(1.0, 0.5);
        afterglowLayer.locations = @[@0.0, @0.38, @0.5, @0.62, @1.0];
        afterglowLayer.opacity = 0.22;
        self.lineAfterglowLayer = afterglowLayer;
        [self.lineView.layer addSublayer:afterglowLayer];
    }

    if (!self.lineSweepLayer) {
        CAGradientLayer *sweepLayer = [CAGradientLayer layer];
        sweepLayer.startPoint = CGPointMake(0.0, 0.5);
        sweepLayer.endPoint = CGPointMake(1.0, 0.5);
        sweepLayer.locations = @[@0.0, @0.28, @0.48, @0.64, @1.0];
        sweepLayer.opacity = 0.0;
        self.lineSweepLayer = sweepLayer;
        [self.lineView.layer addSublayer:sweepLayer];
    }

    [self pp_updateLineMotionLayerAppearance];
}

- (void)pp_updateLineMotionLayerAppearance
{
    [self pp_installLineMotionLayerIfNeeded];

    UIColor *accentColor = [self pp_accentColor] ?: UIColor.systemTealColor;
    BOOL darkMode = [self pp_isDarkMode];
    CGRect bounds = self.lineView.bounds;
    CGFloat width = MAX(CGRectGetWidth(bounds), 0.0);
    CGFloat height = 0.75;;
    CGFloat sweepWidth = MAX(72.0, MIN(width * 0.54, 172.0));

    self.lineView.layer.cornerRadius = height * 0.5;
    self.lineTrackLayer.cornerRadius = height * 0.5;
    self.lineAfterglowLayer.cornerRadius = height * 0.5;
    self.lineSweepLayer.cornerRadius = height * 0.5;
    self.lineTrackLayer.masksToBounds = YES;
    self.lineAfterglowLayer.masksToBounds = YES;
    self.lineSweepLayer.masksToBounds = YES;

    self.lineTrackLayer.frame = bounds;
    self.lineAfterglowLayer.frame = bounds;
    self.lineSweepLayer.frame = CGRectMake(-sweepWidth, 0.0, sweepWidth, height);

    self.lineTrackLayer.colors = @[
        (__bridge id)[accentColor colorWithAlphaComponent:0.00].CGColor,
        (__bridge id)[accentColor colorWithAlphaComponent:(darkMode ? 0.16 : 0.08)].CGColor,
        (__bridge id)[accentColor colorWithAlphaComponent:(darkMode ? 0.32 : 0.18)].CGColor,
        (__bridge id)[accentColor colorWithAlphaComponent:(darkMode ? 0.16 : 0.08)].CGColor,
        (__bridge id)[accentColor colorWithAlphaComponent:0.00].CGColor
    ];
    self.lineAfterglowLayer.colors = @[
        (__bridge id)[accentColor colorWithAlphaComponent:0.00].CGColor,
        (__bridge id)[accentColor colorWithAlphaComponent:(darkMode ? 0.08 : 0.05)].CGColor,
        (__bridge id)[accentColor colorWithAlphaComponent:(darkMode ? 0.42 : 0.24)].CGColor,
        (__bridge id)[accentColor colorWithAlphaComponent:(darkMode ? 0.08 : 0.05)].CGColor,
        (__bridge id)[accentColor colorWithAlphaComponent:0.00].CGColor
    ];
    self.lineSweepLayer.colors = @[
        (__bridge id)[accentColor colorWithAlphaComponent:0.00].CGColor,
        (__bridge id)[accentColor colorWithAlphaComponent:(darkMode ? 0.18 : 0.10)].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:(darkMode ? 0.82 : 0.64)].CGColor,
        (__bridge id)[accentColor colorWithAlphaComponent:(darkMode ? 0.72 : 0.52)].CGColor,
        (__bridge id)[accentColor colorWithAlphaComponent:0.00].CGColor
    ];
}

- (void)pp_startLineMotionIfNeeded
{
    return;
    [self pp_installLineMotionLayerIfNeeded];
    [self pp_updateLineMotionLayerAppearance];

    CGFloat width = CGRectGetWidth(self.lineView.bounds);
    CGFloat sweepWidth = CGRectGetWidth(self.lineSweepLayer.bounds);
    if (width <= 2.0 || sweepWidth <= 2.0) {
        self.lineSweepLayer.opacity = 0.0;
        return;
    }

    if (!self.window || UIAccessibilityIsReduceMotionEnabled()) {
        [self pp_stopLineMotion];
        self.lineTrackLayer.opacity = 0.92;
        self.lineAfterglowLayer.opacity = 0.18;
        self.lineSweepLayer.opacity = 0.0;
        return;
    }

    BOOL hasSweepAnimation =
        [self.lineSweepLayer animationForKey:PPSectionHeaderLineSweepAnimationKey] != nil;
    BOOL hasBreathAnimation =
        [self.lineAfterglowLayer animationForKey:PPSectionHeaderLineBreathAnimationKey] != nil;
    if (hasSweepAnimation && hasBreathAnimation) {
        return;
    }

    self.lineTrackLayer.opacity = 1.0;
    self.lineAfterglowLayer.opacity = 0.28;
    self.lineSweepLayer.opacity = 1.0;

    if (!hasSweepAnimation) {
        CFTimeInterval sweepDuration = 4.8;
        CABasicAnimation *translation = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
        translation.fromValue = @0.0;
        translation.toValue = @(width + sweepWidth);
        translation.duration = sweepDuration;
        translation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

        CAKeyframeAnimation *sweepOpacity = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
        sweepOpacity.values = @[@0.0, @0.92, @0.86, @0.0];
        sweepOpacity.keyTimes = @[@0.0, @0.18, @0.76, @1.0];
        sweepOpacity.duration = sweepDuration;
        sweepOpacity.timingFunctions = @[
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn]
        ];

        CAAnimationGroup *sweepGroup = [CAAnimationGroup animation];
        sweepGroup.animations = @[translation, sweepOpacity];
        sweepGroup.duration = sweepDuration;
        sweepGroup.repeatCount = HUGE_VALF;
        sweepGroup.removedOnCompletion = NO;
        sweepGroup.fillMode = kCAFillModeBoth;
        [self.lineSweepLayer addAnimation:sweepGroup forKey:PPSectionHeaderLineSweepAnimationKey];
    }

    if (!hasBreathAnimation) {
        CABasicAnimation *breath = [CABasicAnimation animationWithKeyPath:@"opacity"];
        breath.fromValue = @0.16;
        breath.toValue = @0.42;
        breath.duration = 3.8;
        breath.autoreverses = YES;
        breath.repeatCount = HUGE_VALF;
        breath.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        breath.removedOnCompletion = NO;
        [self.lineAfterglowLayer addAnimation:breath forKey:PPSectionHeaderLineBreathAnimationKey];
    }
}

- (void)pp_stopLineMotion
{
    [self.lineAfterglowLayer removeAnimationForKey:PPSectionHeaderLineBreathAnimationKey];
    [self.lineSweepLayer removeAnimationForKey:PPSectionHeaderLineSweepAnimationKey];
    self.lineAfterglowLayer.opacity = 0.22;
    self.lineSweepLayer.opacity = 0.0;
}

#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect surfaceBounds = self.surfaceView.bounds;
    CGFloat cornerRadius = self.surfaceView.layer.cornerRadius;
    self.materialWashView.layer.cornerRadius = cornerRadius;
    self.tapHighlightView.layer.cornerRadius = cornerRadius;
    self.accentRailView.layer.cornerRadius = PPSectionHeaderAccentWidth * 0.5;
    CGSize previousLineSize = self.lineMotionLayoutSize;
    [self pp_updateLineMotionLayerAppearance];
    CGSize currentLineSize = self.lineView.bounds.size;
    BOOL lineSizeChanged =
        fabs(previousLineSize.width - currentLineSize.width) > 0.5 ||
        fabs(previousLineSize.height - currentLineSize.height) > 0.5;
    self.lineMotionLayoutSize = currentLineSize;
    if (self.window && !UIAccessibilityIsReduceMotionEnabled()) {
        if (lineSizeChanged &&
            [self.lineSweepLayer animationForKey:PPSectionHeaderLineSweepAnimationKey]) {
            [self pp_stopLineMotion];
        }
        [self pp_startLineMotionIfNeeded];
    }

    if (!CGRectIsEmpty(surfaceBounds) &&
        isfinite(CGRectGetWidth(surfaceBounds)) &&
        isfinite(CGRectGetHeight(surfaceBounds)) &&
        isfinite(cornerRadius)) {
        self.surfaceView.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:surfaceBounds
                                       cornerRadius:MAX(0.0, cornerRadius)].CGPath;
    } else {
        self.surfaceView.layer.shadowPath = nil;
    }
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
        [self pp_startLineMotionIfNeeded];
    } else {
        [self pp_stopLineMotion];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self pp_refreshAppearance];
    }
}

- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    UICollectionViewLayoutAttributes *attrs = [layoutAttributes copy];
    if (layoutAttributes.frame.size.height <= 45.0) {
        attrs.frame = layoutAttributes.frame;
        return attrs;
    }
    CGSize size = [self systemLayoutSizeFittingSize:CGSizeMake(attrs.size.width, UIViewNoIntrinsicMetric)
                      withHorizontalFittingPriority:UILayoutPriorityRequired
                            verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    CGRect frame = attrs.frame;
    CGFloat fittingHeight = isfinite(size.height) ? ceil(size.height) : 0.0;
    frame.size.height = MAX(fittingHeight, layoutAttributes.frame.size.height);
    attrs.frame = frame;
    return attrs;
}

#pragma mark - Public

- (void)hide
{
    self.actionButton.hidden = YES;
    [self pp_updateAccessibility];
}

- (void)setSurfaceDecorationActive:(BOOL)active animated:(BOOL)animated
{
    BOOL changed = (_surfaceDecorationActive != active);
    _surfaceDecorationActive = active;

    if (!animated || !changed || UIAccessibilityIsReduceMotionEnabled()) {
        [self pp_refreshAppearance];
        return;
    }

    [UIView animateWithDuration:0.24
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        [self pp_refreshAppearance];
        [self layoutIfNeeded];
    } completion:nil];
}

#pragma mark - Configuration

- (void)configureWithTitle:(nullable NSString *)title
               actionTitle:(nullable NSString *)actionTitle
                  iconName:(nullable NSString *)iconName
                      menu:(nullable UIMenu *)menu
             ppHomeSection:(PPHomeSection)ppHomeSection
{
    [self configureWithTitle:title
                    subtitle:nil
                 actionTitle:actionTitle
                    iconName:iconName
                        menu:menu
               ppHomeSection:ppHomeSection];
}

- (void)configureWithTitle:(nullable NSString *)title
                  subtitle:(nullable NSString *)subtitle
               actionTitle:(nullable NSString *)actionTitle
                  iconName:(nullable NSString *)iconName
                      menu:(nullable UIMenu *)menu
             ppHomeSection:(PPHomeSection)ppHomeSection
{
    self.currentSection = ppHomeSection;
    self.titleLabel.text = title;
    
    BOOL hasSubtitle = subtitle.length > 0;
    self.subtitleLabel.text = hasSubtitle ? subtitle : nil;
    self.subtitleLabel.hidden = !hasSubtitle;
    self.contentStackView.spacing = hasSubtitle ? 2.0 : 0.0;
    
    if (ppHomeSection != PPHomeSectionMainKinds) {
        self.isExpanded = NO;
        self.accentRailView.transform = CGAffineTransformIdentity;
    }
    
    [self pp_applySemanticDirection];

    self.actionButton.imageView.transform = CGAffineTransformIdentity;
    
    [self pp_applyActionButtonPresentationWithActionTitle:actionTitle
                                                 iconName:iconName
                                                     menu:menu
                                                  section:ppHomeSection
                                          subtitleVisible:hasSubtitle];
                                          
    [self pp_configureMenu:menu];
    
    [self pp_refreshAppearance];
    
    // Post-configuration layout updates: MUST happen after all configuration/appearance changes
    [self.actionButton invalidateIntrinsicContentSize];
    if (@available(iOS 15.0, *)) {
        [self.actionButton setNeedsUpdateConfiguration];
    }
    [self.actionButton setNeedsLayout];
    [self.actionButton layoutIfNeeded];

    [self.textStackView invalidateIntrinsicContentSize];
    [self.contentStackView invalidateIntrinsicContentSize];
    [self.textStackView setNeedsLayout];
    [self.contentStackView setNeedsLayout];
    [self.textStackView layoutIfNeeded];
    [self.contentStackView layoutIfNeeded];

    [self pp_startLineMotionIfNeeded];
    [self pp_updateAccessibility];

    if (ppHomeSection == PPHomeSectionMainKinds) {
        [self pp_setExpanded:self.isExpanded animated:NO];
    }

    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)pp_applyActionButtonPresentationWithActionTitle:(nullable NSString *)actionTitle
                                               iconName:(nullable NSString *)iconName
                                                   menu:(nullable UIMenu *)menu
                                                section:(PPHomeSection)section
                                        subtitleVisible:(BOOL)subtitleVisible
{
    BOOL showAction = YES;
    self.actionButton.hidden = !showAction;
    BOOL forceTitleAction =
        section == PPHomeSectionMainKinds ||
        section == PPHomeSectionAccessories;
    BOOL usesCirclePresentation = subtitleVisible && !forceTitleAction;
    self.actionButtonUsesCirclePresentation = usesCirclePresentation;
    self.actionButtonCircleWidthConstraint.active = usesCirclePresentation;

    NSString *resolvedActionTitle = actionTitle.length > 0
        ? actionTitle
        : (kLang(@"ShowAll") ?: @"Show All");
    NSString *resolvedIconName = iconName.length > 0 ? iconName : @"arrow.forward";
    if (section == PPHomeSectionMainKinds && !usesCirclePresentation && iconName.length == 0) {
        resolvedIconName = self.isExpanded ? @"chevron.up" : @"chevron.down";
    }
    if (usesCirclePresentation) {
        resolvedIconName = @"arrow.forward";
    }

    self.actionAccessibilityTitle = resolvedActionTitle;

    UIButtonConfiguration *cfg =
        [self pp_actionButtonConfigurationForSubtitleVisible:usesCirclePresentation];
    
    /*
     cfg = [self pp_applyIconNamed:resolvedIconName
                  toConfiguration:cfg
                       forSection:section
                   subtitleVisible:usesCirclePresentation];
     */
    cfg = [self pp_applyIconNamed:resolvedIconName
                 toConfiguration:cfg
                      forSection:section
                  subtitleVisible:usesCirclePresentation];
    
    if (usesCirclePresentation) {
        
        cfg.attributedTitle = nil;
        cfg.title = nil;
    } else {
        cfg.attributedTitle = nil;
        cfg.title = resolvedActionTitle;
        __weak typeof(self) weakSelf = self;
        cfg.titleTextAttributesTransformer =
            ^NSDictionary<NSAttributedStringKey,id> *(NSDictionary<NSAttributedStringKey,id> *attrs) {
            __strong typeof(weakSelf) self = weakSelf;
            NSMutableDictionary<NSAttributedStringKey,id> *values =
                attrs.mutableCopy ?: [NSMutableDictionary dictionary];
            values[NSFontAttributeName] = self ? [self pp_actionFont] : [UIFont systemFontOfSize:12.5 weight:UIFontWeightSemibold];
            values[NSForegroundColorAttributeName] = self ? [self pp_accentColor] : UIColor.systemPinkColor;
            return values;
        };
    }
    
    self.actionButton.configuration = cfg;

    [self.actionButton invalidateIntrinsicContentSize];
    if (@available(iOS 15.0, *)) {
        [self.actionButton setNeedsUpdateConfiguration];
    }
    [self.actionButton setNeedsLayout];
    [self.textStackView invalidateIntrinsicContentSize];
    [self.contentStackView invalidateIntrinsicContentSize];
    (void)menu;
}

- (UIButtonConfiguration *)pp_applyIconNamed:(nullable NSString *)iconName
                             toConfiguration:(UIButtonConfiguration *)configuration
                                  forSection:(PPHomeSection)section
                             subtitleVisible:(BOOL)subtitleVisible
{
    UIButtonConfiguration *cfg = configuration;
    UIImage *image = nil;
    CGFloat pointSize = subtitleVisible ? 13.5 : 12.5;

    if (iconName.length > 0) {
        image = [UIImage pp_symbolNamed:iconName
                              pointSize:pointSize
                                 weight:UIImageSymbolWeightSemibold
                                  scale:UIImageSymbolScaleMedium
                                palette:@[[self pp_accentColor]]
                           makeTemplate:YES];
    } else if (section == PPHomeSectionMainKinds) {
        UIImageSymbolConfiguration *symbolConfig =
            [UIImageSymbolConfiguration configurationWithPointSize:pointSize
                                                            weight:UIImageSymbolWeightSemibold
                                                             scale:UIImageSymbolScaleMedium];
        image = [UIImage systemImageNamed:@"chevron.down" withConfiguration:symbolConfig];
    }

    cfg.image = image;
    cfg.imagePadding = (image && !subtitleVisible) ? 6.0 : 0.0;
    cfg.imagePlacement = NSDirectionalRectEdgeTrailing;

    BOOL hasTitleText = (cfg.title.length > 0 || cfg.attributedTitle.string.length > 0);
    if (!hasTitleText && image) {
        cfg.contentInsets = subtitleVisible
            ? NSDirectionalEdgeInsetsMake(8.0, 8.0, 8.0, 8.0)
            : NSDirectionalEdgeInsetsMake(8.0, 10.0, 8.0, 10.0);
    }

    return cfg;
}

- (void)pp_configureMenu:(nullable UIMenu *)menu
{
    if (menu) {
        self.actionButton.menu = menu;
        self.actionButton.showsMenuAsPrimaryAction = YES;
        [PPMenuHelper presentMenuFromButton:self.actionButton
                                       Menu:menu
                                destructive:nil
                                    handler:^(NSInteger idx, NSString *t) { }];
    } else {
        self.actionButton.menu = nil;
        self.actionButton.showsMenuAsPrimaryAction = NO;
    }
}

- (void)pp_applySemanticDirection
{
    UISemanticContentAttribute semantic = [Language semanticAttributeForCurrentLanguage];
    NSTextAlignment alignment = [Language alignmentForCurrentLanguage];

    self.semanticContentAttribute = semantic;
    self.surfaceView.semanticContentAttribute = semantic;
    self.contentStackView.semanticContentAttribute = semantic;
    self.textStackView.semanticContentAttribute = semantic;
    self.actionButton.semanticContentAttribute = semantic;
    self.titleLabel.textAlignment = alignment;
    self.subtitleLabel.textAlignment = alignment;
}

#pragma mark - Reuse

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.subtitleLabel.hidden = YES;
    self.contentStackView.spacing = 0.0;
    self.actionButton.hidden = YES;
    self.actionButton.menu = nil;
    self.actionButton.showsMenuAsPrimaryAction = NO;
    self.actionButton.configuration = [self pp_baseActionButtonConfiguration];
    self.actionButton.imageView.transform = CGAffineTransformIdentity;
    self.actionButtonUsesCirclePresentation = NO;
    self.actionButtonCircleWidthConstraint.active = NO;
    self.actionAccessibilityTitle = nil;
    self.surfaceView.transform = CGAffineTransformIdentity;
    self.actionButton.transform = CGAffineTransformIdentity;
    self.accentRailView.transform = CGAffineTransformIdentity;
    self.tapHighlightView.alpha = 0.0;
    self.surfaceDecorationActive = YES;
    self.onTap = nil;
    self.onTapMenu = nil;
    self.lastActionTimestamp = 0;
    [self pp_stopLineMotion];
    [self pp_refreshAppearance];
    [self pp_updateAccessibility];
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    [super applyLayoutAttributes:layoutAttributes];
    self.layer.zPosition = MAX((CGFloat)layoutAttributes.zIndex, 2.0);
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

#pragma mark - Actions

- (void)pp_actionTapped
{
    CFTimeInterval now = CACurrentMediaTime();
    if ((now - self.lastActionTimestamp) < 0.22) {
        return;
    }
    self.lastActionTimestamp = now;

    [self pp_animatePressFeedback];

    if (self.currentSection != PPHomeSectionMainKinds) {
        if (self.onTap) {
            self.onTap();
        }
        return;
    }

    [PPFunc triggerMediumHaptic];
    self.isExpanded = !self.isExpanded;
    [self pp_setExpanded:self.isExpanded animated:YES];

    if (self.onTap) {
        self.onTap();
    }
}

- (void)pp_animatePressFeedback
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.12
                              delay:0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.tapHighlightView.alpha = 1.0;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.18
                                  delay:0
                                options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                self.tapHighlightView.alpha = 0.0;
            } completion:nil];
        }];
        return;
    }

    [UIView animateWithDuration:0.08
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.tapHighlightView.alpha = 1.0;
        self.surfaceView.transform = CGAffineTransformMakeScale(0.988, 0.988);
        self.actionButton.transform = CGAffineTransformMakeScale(0.97, 0.97);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.22
                              delay:0
             usingSpringWithDamping:0.78
              initialSpringVelocity:0.35
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.tapHighlightView.alpha = 0.0;
            self.surfaceView.transform = CGAffineTransformIdentity;
            self.actionButton.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
       shouldReceiveTouch:(UITouch *)touch
{
    (void)gestureRecognizer;
    UIView *hitView = touch.view;
    while (hitView) {
        if (hitView == self.actionButton) {
            return NO;
        }
        hitView = hitView.superview;
    }
    return YES;
}

#pragma mark - Expand / Collapse

- (void)pp_setExpanded:(BOOL)expanded animated:(BOOL)animated
{
    _isExpanded = expanded;

    if (self.currentSection != PPHomeSectionMainKinds) {
        self.actionButton.imageView.transform = CGAffineTransformIdentity;
        self.accentRailView.transform = CGAffineTransformIdentity;
        return;
    }

    CGFloat angle = expanded ? M_PI : 0.0;
    void (^updates)(void) = ^{
        self.actionButton.imageView.transform = CGAffineTransformMakeRotation(angle);
        self.accentRailView.transform = expanded
            ? CGAffineTransformMakeScale(1.0, 1.14)
            : CGAffineTransformIdentity;
    };

    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.34
                              delay:0
             usingSpringWithDamping:0.76
              initialSpringVelocity:0.55
                            options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                         animations:updates
                         completion:nil];
    } else {
        updates();
    }
}

#pragma mark - Accessibility

- (void)pp_updateAccessibility
{
    NSString *title = self.titleLabel.text ?: @"";
    NSString *subtitle = self.subtitleLabel.hidden ? @"" : (self.subtitleLabel.text ?: @"");
    NSString *configuredActionTitle =
        self.actionButton.configuration.attributedTitle.string.length > 0
            ? self.actionButton.configuration.attributedTitle.string
            : (self.actionButton.configuration.title ?: @"");
    NSString *actionTitle =
        self.actionAccessibilityTitle.length > 0
            ? self.actionAccessibilityTitle
            : configuredActionTitle;

    self.titleLabel.accessibilityLabel = title;
    self.subtitleLabel.accessibilityLabel = subtitle;
    self.actionButton.accessibilityLabel = actionTitle.length > 0 ? actionTitle : title;
    self.actionButton.accessibilityHint = nil;

    if (self.currentSection == PPHomeSectionMainKinds) {
        self.actionButton.accessibilityTraits = UIAccessibilityTraitButton;
        self.actionButton.accessibilityValue = self.isExpanded ? kLang(@"ShowLess") : kLang(@"ShowAll");
    }
}

@end
