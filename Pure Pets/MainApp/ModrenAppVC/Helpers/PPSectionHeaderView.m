#import "PPSectionHeaderView.h"
#import <QuartzCore/QuartzCore.h>

static CGFloat PPSectionHeaderPixel(void) {
    return 1.0 / UIScreen.mainScreen.scale;
}

static const CGFloat PPSectionHeaderSurfaceRadius = 22.0;
static const CGFloat PPSectionHeaderOuterVerticalInset = 3.0;
static const CGFloat PPSectionHeaderContentLeading = 28.0;
static const CGFloat PPSectionHeaderContentTrailing = 14.0;
static const CGFloat PPSectionHeaderContentVerticalInset = 10.0;
static const CGFloat PPSectionHeaderAccentWidth = 3.5;
static const CGFloat PPSectionHeaderAccentHeight = 30.0;
static const CGFloat PPSectionHeaderActionMinHeight = 40.0;
static const CGFloat PPSectionHeaderActionMinWidth = 44.0;
static const CGFloat PPSectionHeaderActionMaxWidth = 164.0;

@interface PPSectionHeaderView () <UIGestureRecognizerDelegate>

@property (nonatomic, strong, readwrite) UILabel *titleLabel;
@property (nonatomic, strong, readwrite) UILabel *subtitleLabel;
@property (nonatomic, strong, readwrite) UIButton *actionButton;

@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *materialWashView;
@property (nonatomic, strong) UIView *topSheenView;
@property (nonatomic, strong) UIView *tapHighlightView;
@property (nonatomic, strong) UIView *accentRailView;
@property (nonatomic, strong) UIStackView *contentStackView;
@property (nonatomic, strong) UIStackView *textStackView;

@property (nonatomic, strong) NSLayoutConstraint *accentRailWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *accentRailHeightConstraint;

@property (nonatomic, assign) BOOL isExpanded;
@property (nonatomic, assign) BOOL surfaceDecorationActive;
@property (nonatomic, assign) PPHomeSection currentSection;
@property (nonatomic, assign) CFTimeInterval lastActionTimestamp;

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
    self.surfaceView.layer.borderWidth = PPSectionHeaderPixel();
    self.surfaceView.backgroundColor = [self pp_surfaceFillColor];
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
        [self.surfaceView.topAnchor constraintEqualToAnchor:self.topAnchor constant:PPSectionHeaderOuterVerticalInset],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-PPSectionHeaderOuterVerticalInset],

        [self.materialWashView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor],
        [self.materialWashView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor],
        [self.materialWashView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor],
        [self.materialWashView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor],

        [self.topSheenView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:18.0],
        [self.topSheenView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-18.0],
        [self.topSheenView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor],
        [self.topSheenView.heightAnchor constraintEqualToConstant:PPSectionHeaderPixel()],

        [self.tapHighlightView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor],
        [self.tapHighlightView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor],
        [self.tapHighlightView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor],
        [self.tapHighlightView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor],

        [self.accentRailView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:17.0],
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
    self.titleLabel.numberOfLines = 2;
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
    self.subtitleLabel.numberOfLines = 2;
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
    self.actionButton.layer.cornerRadius = 12.0;
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

    [NSLayoutConstraint activateConstraints:@[
        [self.actionButton.heightAnchor constraintGreaterThanOrEqualToConstant:PPSectionHeaderActionMinHeight],
        [self.actionButton.widthAnchor constraintGreaterThanOrEqualToConstant:PPSectionHeaderActionMinWidth],
        [self.actionButton.widthAnchor constraintLessThanOrEqualToConstant:PPSectionHeaderActionMaxWidth],
    ]];
}

- (void)pp_buildStacks
{
    self.textStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.titleLabel,
        self.subtitleLabel,
    ]];
    self.textStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textStackView.axis = UILayoutConstraintAxisVertical;
    self.textStackView.alignment = UIStackViewAlignmentFill;
    self.textStackView.distribution = UIStackViewDistributionFill;
    self.textStackView.spacing = 3.0;
    self.textStackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.textStackView setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    self.contentStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.textStackView,
        self.actionButton,
    ]];
    self.contentStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStackView.axis = UILayoutConstraintAxisHorizontal;
    self.contentStackView.alignment = UIStackViewAlignmentCenter;
    self.contentStackView.distribution = UIStackViewDistributionFill;
    self.contentStackView.spacing = 14.0;
    self.contentStackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.surfaceView addSubview:self.contentStackView];

    NSLayoutConstraint *contentTopConstraint =
        [self.contentStackView.topAnchor constraintGreaterThanOrEqualToAnchor:self.surfaceView.topAnchor constant:PPSectionHeaderContentVerticalInset];
    NSLayoutConstraint *contentBottomConstraint =
        [self.contentStackView.bottomAnchor constraintLessThanOrEqualToAnchor:self.surfaceView.bottomAnchor constant:-PPSectionHeaderContentVerticalInset];
    contentTopConstraint.priority = UILayoutPriorityDefaultHigh;
    contentBottomConstraint.priority = UILayoutPriorityDefaultHigh;

    [NSLayoutConstraint activateConstraints:@[
        [self.contentStackView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:PPSectionHeaderContentLeading],
        [self.contentStackView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-PPSectionHeaderContentTrailing],
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
    background.strokeWidth = PPSectionHeaderPixel();
    background.strokeColor = [[self pp_accentColor] colorWithAlphaComponent:[self pp_isDarkMode] ? 0.24 : 0.10];
    background.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:[self pp_isDarkMode] ? 0.14 : 0.075];
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

    __weak typeof(self) weakSelf = self;
    cfg.titleTextAttributesTransformer =
    ^NSDictionary<NSAttributedStringKey,id> *(NSDictionary<NSAttributedStringKey,id> *attrs) {
        __strong typeof(weakSelf) self = weakSelf;
        NSMutableDictionary *values = attrs.mutableCopy ?: [NSMutableDictionary dictionary];
        values[NSFontAttributeName] = self ? [self pp_actionFont] : [UIFont systemFontOfSize:12.5 weight:UIFontWeightSemibold];
        values[NSForegroundColorAttributeName] = self ? [self pp_accentColor] : UIColor.systemTealColor;
        return values;
    };

    return cfg;
}

- (void)pp_refreshAppearance
{
    BOOL decorationActive = self.surfaceDecorationActive;
    BOOL darkMode = [self pp_isDarkMode];
    UIColor *accentColor = [self pp_accentColor];

    self.surfaceView.backgroundColor = [self pp_surfaceFillColor];
    self.surfaceView.layer.borderColor = [self pp_surfaceBorderColor].CGColor;
    self.surfaceView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.surfaceView.layer.shadowOpacity = (decorationActive && !darkMode) ? 0.05 : 0.0;
    self.surfaceView.layer.shadowRadius = decorationActive ? 16.0 : 0.0;
    self.surfaceView.layer.shadowOffset = decorationActive ? CGSizeMake(0.0, 6.0) : CGSizeZero;

    UIColor *foregroundWash = AppForgroundColr ?: UIColor.whiteColor;
    self.materialWashView.backgroundColor =
        [foregroundWash colorWithAlphaComponent:decorationActive ? (darkMode ? 0.045 : 0.16) : (darkMode ? 0.025 : 0.09)];
    self.topSheenView.backgroundColor =
        [UIColor.whiteColor colorWithAlphaComponent:decorationActive ? (darkMode ? 0.08 : 0.55) : (darkMode ? 0.05 : 0.22)];
    self.tapHighlightView.backgroundColor = [accentColor colorWithAlphaComponent:darkMode ? 0.16 : 0.10];

    CGFloat accentAlpha = self.currentSection == PPHomeSectionMainKinds ? 0.82 : 0.58;
    self.accentRailView.backgroundColor = [accentColor colorWithAlphaComponent:accentAlpha];
    self.accentRailView.alpha = decorationActive ? 1.0 : 0.64;
    self.titleLabel.textColor = [self pp_titleColor];
    self.subtitleLabel.textColor = [self pp_subtitleColor];

    UIButtonConfiguration *cfg = self.actionButton.configuration ?: [self pp_baseActionButtonConfiguration];
    UIBackgroundConfiguration *background = cfg.background ?: [UIBackgroundConfiguration clearConfiguration];
    background.cornerRadius = PPSectionHeaderActionMinHeight * 0.5;
    background.strokeWidth = PPSectionHeaderPixel();
    background.strokeColor = [accentColor colorWithAlphaComponent:darkMode ? 0.24 : 0.10];
    background.backgroundColor = [accentColor colorWithAlphaComponent:darkMode ? 0.14 : 0.075];
    cfg.background = background;
    cfg.baseForegroundColor = accentColor;
    self.actionButton.configuration = cfg;
}

- (UIColor *)pp_accentColor
{
    return AppPrimaryClr ?: UIColor.systemTealColor;
}

- (UIColor *)pp_titleColor
{
    return AppPrimaryTextClr ?: UIColor.labelColor;
}

- (UIColor *)pp_subtitleColor
{
    return AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
}

- (UIColor *)pp_surfaceFillColor
{
    if ([self pp_isDarkMode]) {
        return [UIColor colorWithWhite:1.0 alpha:self.surfaceDecorationActive ? 0.055 : 0.04];
    }

    UIColor *foregroundSurface = AppForgroundColr ?: UIColor.whiteColor;
    return [foregroundSurface colorWithAlphaComponent:self.surfaceDecorationActive ? 0.32 : 0.24];
}

- (UIColor *)pp_surfaceBorderColor
{
    if ([self pp_isDarkMode]) {
        return [UIColor colorWithWhite:1.0 alpha:0.08];
    }
    UIColor *accent = AppForgroundColr ?: UIColor.separatorColor;
    return [accent colorWithAlphaComponent:self.surfaceDecorationActive ? 0.42 : 0.22];
}

- (UIFont *)pp_titleFont
{
    UIFont *font = [GM boldFontWithSize:19.0] ?: [UIFont systemFontOfSize:18.5 weight:UIFontWeightBold];
    return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline] scaledFontForFont:font];
}

- (UIFont *)pp_subtitleFont
{
    UIFont *font = [GM MidFontWithSize:12.5] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:font];
}

- (UIFont *)pp_actionFont
{
    UIFont *font = [GM MidFontWithSize:12.5] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1] scaledFontForFont:font];
}

- (BOOL)pp_isDarkMode
{
    return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
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
    [self pp_refreshAppearance];
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
    self.currentSection = ppHomeSection;
    self.titleLabel.text = title;
    self.subtitleLabel.text = nil;
    self.subtitleLabel.hidden = YES;
    if (ppHomeSection != PPHomeSectionMainKinds) {
        self.isExpanded = NO;
        self.accentRailView.transform = CGAffineTransformIdentity;
    }
    [self pp_applySemanticDirection];

    self.actionButton.configuration = [self pp_baseActionButtonConfiguration];
    self.actionButton.imageView.transform = CGAffineTransformIdentity;

    BOOL showAction = (ppHomeSection == PPHomeSectionMainKinds ||
                       actionTitle.length > 0 ||
                       menu != nil);
    self.actionButton.hidden = !showAction;

    UIButtonConfiguration *cfg = self.actionButton.configuration;
    cfg.title = actionTitle.length > 0 ? actionTitle : @"";
    cfg = [self pp_applyIconNamed:iconName
                 toConfiguration:cfg
                      forSection:ppHomeSection];
    self.actionButton.configuration = cfg;
    [self.contentStackView invalidateIntrinsicContentSize];

    [self pp_configureMenu:menu];
    [self pp_refreshAppearance];
    [self pp_updateAccessibility];

    if (ppHomeSection == PPHomeSectionMainKinds) {
        [self pp_setExpanded:self.isExpanded animated:NO];
    }

    [self setNeedsLayout];
}

- (void)configureWithTitle:(nullable NSString *)title
                  subtitle:(nullable NSString *)subtitle
               actionTitle:(nullable NSString *)actionTitle
                  iconName:(nullable NSString *)iconName
                      menu:(nullable UIMenu *)menu
             ppHomeSection:(PPHomeSection)ppHomeSection
{
    [self configureWithTitle:title
                 actionTitle:actionTitle
                    iconName:iconName
                        menu:menu
               ppHomeSection:ppHomeSection];

    BOOL hasSubtitle = subtitle.length > 0;
    self.subtitleLabel.text = hasSubtitle ? subtitle : nil;
    self.subtitleLabel.hidden = !hasSubtitle;
    self.textStackView.spacing = hasSubtitle ? 2.0 : 0.0;
    [self pp_updateAccessibility];
    [self setNeedsLayout];
}

- (UIButtonConfiguration *)pp_applyIconNamed:(nullable NSString *)iconName
                             toConfiguration:(UIButtonConfiguration *)configuration
                                  forSection:(PPHomeSection)section
{
    UIButtonConfiguration *cfg = configuration;
    UIImage *image = nil;

    if (iconName.length > 0) {
        image = [UIImage pp_symbolNamed:iconName
                              pointSize:12.5
                                 weight:UIImageSymbolWeightSemibold
                                  scale:UIImageSymbolScaleMedium
                                palette:@[[self pp_accentColor]]
                           makeTemplate:YES];
    } else if (section == PPHomeSectionMainKinds) {
        UIImageSymbolConfiguration *symbolConfig =
            [UIImageSymbolConfiguration configurationWithPointSize:12.5
                                                            weight:UIImageSymbolWeightSemibold
                                                             scale:UIImageSymbolScaleMedium];
        image = [UIImage systemImageNamed:@"chevron.down" withConfiguration:symbolConfig];
    }

    cfg.image = image;
    cfg.imagePadding = image ? 6.0 : 0.0;
    cfg.imagePlacement = section == PPHomeSectionMainKinds ? NSDirectionalRectEdgeTrailing : NSDirectionalRectEdgeLeading;

    if (cfg.title.length == 0 && image) {
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(8.0, 10.0, 8.0, 10.0);
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
    self.textStackView.spacing = 0.0;
    self.actionButton.hidden = YES;
    self.actionButton.menu = nil;
    self.actionButton.showsMenuAsPrimaryAction = NO;
    self.actionButton.configuration = [self pp_baseActionButtonConfiguration];
    self.actionButton.imageView.transform = CGAffineTransformIdentity;
    self.surfaceView.transform = CGAffineTransformIdentity;
    self.actionButton.transform = CGAffineTransformIdentity;
    self.accentRailView.transform = CGAffineTransformIdentity;
    self.tapHighlightView.alpha = 0.0;
    self.surfaceDecorationActive = NO;
    self.onTap = nil;
    self.onTapMenu = nil;
    self.lastActionTimestamp = 0;
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
    NSString *actionTitle = self.actionButton.configuration.title ?: @"";

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
