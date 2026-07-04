#import "PPModrenSegmrnted.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static const NSInteger PPModrenSegmrntedNoSelection = -1;
static const CGFloat PPModrenSegmrntedOuterInset = 3.0;
static const CGFloat PPModrenSegmrntedSegmentSpacing = 3.0;
static const CGFloat PPModrenSegmrntedUnderlineHeight = 4.0;
static const CGFloat PPModrenSegmrntedContainerCornerRadius = 24.0;
static const CGFloat PPModrenSegmrntedSelectionCornerRadius = 24.0;
static const NSTimeInterval PPModrenSegmrntedAnimationDuration = 0.36;

static inline UIColor *PPModrenSegmrntedDefaultContainerColor(void)
{
    return AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
}

static inline CGFloat PPModrenSegmrntedPillRadiusForHeight(CGFloat height, CGFloat fallback)
{
    if (!isfinite((double)height) || height <= 0.0) {
        return fallback;
    }
    return floor(height * 0.5);
}

@interface PPModrenSegmrntedItem ()

@property (nonatomic, copy, readwrite) NSString *title;
@property (nonatomic, copy, nullable, readwrite) NSString *iconName;
@property (nonatomic, copy, nullable, readwrite) NSString *selectedIconName;

@end

@implementation PPModrenSegmrntedItem

+ (instancetype)itemWithTitle:(NSString *)title
                     iconName:(nullable NSString *)iconName
             selectedIconName:(nullable NSString *)selectedIconName
{
    return [[self alloc] initWithTitle:title
                              iconName:iconName
                      selectedIconName:selectedIconName];
}

- (instancetype)initWithTitle:(NSString *)title
                     iconName:(nullable NSString *)iconName
             selectedIconName:(nullable NSString *)selectedIconName
{
    self = [super init];
    if (!self) {
        return nil;
    }

    _title = [title copy] ?: @"";
    _iconName = [iconName copy];
    _selectedIconName = [selectedIconName copy];
    return self;
}

@end

@interface _PPModrenSegmrntedSegmentView : UIControl

@property (nonatomic, strong) UIStackView *contentStackView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) NSLayoutConstraint *iconWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *iconHeightConstraint;
@property (nonatomic, strong) PPModrenSegmrntedItem *item;
@property (nonatomic, assign, getter=isSegmentSelected) BOOL segmentSelected;
@property (nonatomic, strong) UIColor *cachedNormalTextColor;
@property (nonatomic, strong) UIColor *cachedSelectedTextColor;
@property (nonatomic, strong) UIFont *cachedNormalFont;
@property (nonatomic, strong) UIFont *cachedSelectedFont;

- (void)configureWithItem:(PPModrenSegmrntedItem *)item;
- (void)applySelectionState:(BOOL)selected
                   animated:(BOOL)animated
            normalTextColor:(UIColor *)normalTextColor
          selectedTextColor:(UIColor *)selectedTextColor
                 normalFont:(UIFont *)normalFont
               selectedFont:(UIFont *)selectedFont;

@end

@implementation _PPModrenSegmrntedSegmentView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.exclusiveTouch = YES;

    self.iconView = [[UIImageView alloc] init];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.userInteractionEnabled = NO;

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor = 0.76;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.titleLabel.adjustsFontForContentSizeCategory = YES;

    self.contentStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.iconView,
        self.titleLabel
    ]];
    self.contentStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStackView.axis = UILayoutConstraintAxisVertical;
    self.contentStackView.alignment = UIStackViewAlignmentCenter;
    self.contentStackView.distribution = UIStackViewDistributionFill;
    self.contentStackView.spacing = 2.5;
    self.contentStackView.userInteractionEnabled = NO;
    self.contentStackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self addSubview:self.contentStackView];

    self.iconWidthConstraint = [self.iconView.widthAnchor constraintEqualToConstant:16.0];
    self.iconHeightConstraint = [self.iconView.heightAnchor constraintEqualToConstant:16.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.contentStackView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.leadingAnchor constant:6.0],
        [self.contentStackView.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-6.0],
        [self.contentStackView.topAnchor constraintGreaterThanOrEqualToAnchor:self.topAnchor constant:3.0],
        [self.contentStackView.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-3.0],
        [self.contentStackView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.contentStackView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        self.iconWidthConstraint,
        self.iconHeightConstraint
    ]];

    self.accessibilityTraits = UIAccessibilityTraitButton;
    return self;
}

- (void)configureWithItem:(PPModrenSegmrntedItem *)item
{
    self.item = item;
    self.titleLabel.text = item.title;

    BOOL hasIcon = item.iconName.length > 0 || item.selectedIconName.length > 0;
    self.iconView.hidden = !hasIcon;
    self.iconWidthConstraint.constant = hasIcon ? 16.0 : 0.0;
    self.iconHeightConstraint.constant = hasIcon ? 16.0 : 0.0;
    self.contentStackView.axis = hasIcon ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    self.contentStackView.spacing = hasIcon ? 2.5 : 0.0;

    [self pp_applyCurrentStateAnimated:NO];
}

- (UIImage *)segmentImageForSelectionState:(BOOL)selected tintColor:(UIColor *)tintColor
{
    NSString *iconName = selected && self.item.selectedIconName.length > 0
        ? self.item.selectedIconName
        : self.item.iconName;
    if (iconName.length == 0) {
        return nil;
    }

    return [UIImage pp_symbolNamed:iconName
                         pointSize:selected ? 16.0 : 15.5
                            weight:selected ? UIImageSymbolWeightSemibold : UIImageSymbolWeightMedium
                             scale:UIImageSymbolScaleMedium
                           palette:@[tintColor]
                      makeTemplate:YES];
}

- (void)applySelectionState:(BOOL)selected
                   animated:(BOOL)animated
            normalTextColor:(UIColor *)normalTextColor
          selectedTextColor:(UIColor *)selectedTextColor
                 normalFont:(UIFont *)normalFont
               selectedFont:(UIFont *)selectedFont
{
    self.segmentSelected = selected;
    self.cachedNormalTextColor = normalTextColor ?: UIColor.secondaryLabelColor;
    self.cachedSelectedTextColor = selectedTextColor ?: UIColor.labelColor;
    self.cachedNormalFont = normalFont ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    self.cachedSelectedFont = selectedFont ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    [self pp_applyCurrentStateAnimated:animated];
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    [self pp_applyCurrentStateAnimated:YES];
}

- (void)setEnabled:(BOOL)enabled
{
    [super setEnabled:enabled];
    [self pp_applyCurrentStateAnimated:NO];
}

- (void)pp_applyCurrentStateAnimated:(BOOL)animated
{
    UIColor *normalTextColor = self.cachedNormalTextColor ?: UIColor.secondaryLabelColor;
    UIColor *selectedTextColor = self.cachedSelectedTextColor ?: UIColor.labelColor;
    UIFont *normalFont = self.cachedNormalFont ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    UIFont *selectedFont = self.cachedSelectedFont ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];

    BOOL selected = self.isSegmentSelected;
    BOOL highlighted = self.isHighlighted;
    BOOL enabled = self.isEnabled;

    UIColor *targetTextColor = selected ? selectedTextColor : normalTextColor;
    UIFont *targetFont = selected ? selectedFont : normalFont;
    UIImage *targetImage = [self segmentImageForSelectionState:selected tintColor:targetTextColor];

    CGFloat targetAlpha = enabled ? (selected ? 1.0 : 0.70) : 0.34;
    if (highlighted) {
        targetAlpha = enabled ? (selected ? 0.90 : 0.78) : targetAlpha;
    }

    CGFloat scale = highlighted ? 0.975 : 1.0;
    CGAffineTransform transform = CGAffineTransformMakeScale(scale, scale);

    void (^updates)(void) = ^{
        self.titleLabel.textColor = targetTextColor;
        self.titleLabel.font = targetFont;
        self.titleLabel.alpha = targetAlpha;
        self.iconView.image = targetImage;
        self.iconView.tintColor = targetTextColor;
        self.iconView.alpha = targetAlpha;
        self.contentStackView.transform = transform;
    };

    BOOL shouldAnimate = animated && !UIAccessibilityIsReduceMotionEnabled();
    if (shouldAnimate) {
        [UIView animateWithDuration:0.18
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                         animations:updates
                         completion:nil];
    } else {
        updates();
    }

    UIAccessibilityTraits traits = UIAccessibilityTraitButton;
    if (selected) {
        traits |= UIAccessibilityTraitSelected;
    }
    self.accessibilityTraits = traits;
    self.accessibilityLabel = self.item.title;
}

@end

@interface PPModrenSegmrnted ()

@property (nonatomic, strong) UIView *containerFillView;
@property (nonatomic, strong) UIButton *containerBlurView;
@property (nonatomic, strong) UIView *containerTintOverlay;
@property (nonatomic, strong) UIView *selectionOutlineView;
@property (nonatomic, strong) UIView *selectionUnderlineView;
@property (nonatomic, strong) UIStackView *segmentsStackView;
@property (nonatomic, copy) NSArray<_PPModrenSegmrntedSegmentView *> *segmentViews;
@property (nonatomic, strong) CAGradientLayer *selectionSurfaceLayer;
@property (nonatomic, strong) CAGradientLayer *selectionUnderlineLayer;
@property (nonatomic, strong) NSLayoutConstraint *selectionOutlineLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *selectionOutlineWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *selectionUnderlineLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *selectionUnderlineWidthConstraint;

@end

@implementation PPModrenSegmrnted

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    [self pp_commonInit];
    return self;
}

- (instancetype)initWithItems:(NSArray<PPModrenSegmrntedItem *> *)items
{
    self = [super initWithFrame:CGRectZero];
    if (!self) {
        return nil;
    }

    [self pp_commonInit];
    self.items = items;
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self) {
        return nil;
    }

    [self pp_commonInit];
    return self;
}

- (void)pp_commonInit
{
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.exclusiveTouch = YES;
    self.isAccessibilityElement = NO;
    self.shouldGroupAccessibilityChildren = NO;
    [self pp_setShadowColor:[UIColor colorWithWhite:0.02 alpha:1.0]];
    self.layer.shadowOpacity = 0.0f;
    self.layer.shadowRadius = 14.0f;
    self.layer.shadowOffset = CGSizeMake(0.0, 8.0);

    _containerBackgroundColor = PPModrenSegmrntedDefaultContainerColor();
    _selectedSegmentColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    _normalTextColor = UIColor.secondaryLabelColor;
    _selectedTextColor = AppPrimaryTextClr ?: UIColor.labelColor;
    _normalFont = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    _selectedFont = [GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    _selectedIndex = PPModrenSegmrntedNoSelection;

    [self pp_buildChrome];
    [self pp_updateChromeColors];
}

- (void)pp_buildChrome
{
    self.containerFillView = [[UIView alloc] init];
    self.containerFillView.translatesAutoresizingMaskIntoConstraints = NO;
    self.containerFillView.userInteractionEnabled = NO;
    self.containerFillView.backgroundColor = UIColor.clearColor;
    self.containerFillView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.containerFillView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self addSubview:self.containerFillView];

    //UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialLight];
    //self.containerBlurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    self.containerBlurView = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleCapsule configType:PPButtonConfigrationGlass];
    
    UIButtonConfiguration *config = self.containerBlurView.configuration;
    config.baseBackgroundColor = UIColor.clearColor;
    config.background.backgroundColor = UIColor.clearColor;
    config.background.strokeColor = UIColor.clearColor;
    config.background.strokeWidth = 0.0;
    config.background.cornerRadius = PPModrenSegmrntedContainerCornerRadius;
    self.containerBlurView.configuration = config;
    self.containerBlurView.translatesAutoresizingMaskIntoConstraints = NO;
    self.containerBlurView.userInteractionEnabled = NO;
    self.containerBlurView.clipsToBounds = YES;
    self.containerBlurView.layer.masksToBounds = YES;
    self.containerBlurView.layer.borderWidth = 0.0;
    self.containerBlurView.layer.borderColor = UIColor.clearColor.CGColor;
    [self.containerFillView addSubview:self.containerBlurView];

    self.containerTintOverlay = [[UIView alloc] init];
    self.containerTintOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    self.containerTintOverlay.userInteractionEnabled = NO;
    self.containerTintOverlay.backgroundColor = UIColor.clearColor;
    self.containerTintOverlay.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.containerTintOverlay.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.containerFillView addSubview:self.containerTintOverlay];

    self.selectionOutlineView = [[UIView alloc] init];
    self.selectionOutlineView.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionOutlineView.userInteractionEnabled = NO;
    self.selectionOutlineView.alpha = 0.0;
    self.selectionOutlineView.backgroundColor = UIColor.clearColor;
    self.selectionOutlineView.layer.borderWidth = 1.05;
    self.selectionOutlineView.layer.shadowOpacity = 0.08;
    self.selectionOutlineView.layer.shadowRadius = 12.0;
    self.selectionOutlineView.layer.shadowOffset = CGSizeMake(0.0, 4.0);
    if (@available(iOS 13.0, *)) {
        self.selectionOutlineView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.selectionSurfaceLayer = [CAGradientLayer layer];
    self.selectionSurfaceLayer.startPoint = CGPointMake(0.18, 0.0);
    self.selectionSurfaceLayer.endPoint = CGPointMake(0.86, 1.0);
    self.selectionSurfaceLayer.locations = @[@0.0, @0.62, @1.0];
    [self.selectionOutlineView.layer insertSublayer:self.selectionSurfaceLayer atIndex:0];
    [self addSubview:self.selectionOutlineView];

    self.selectionUnderlineView = [[UIView alloc] init];
    self.selectionUnderlineView.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionUnderlineView.userInteractionEnabled = NO;
    self.selectionUnderlineView.alpha = 0.0;
    self.selectionUnderlineView.backgroundColor = UIColor.clearColor;
    self.selectionUnderlineView.layer.cornerRadius = PPModrenSegmrntedUnderlineHeight * 0.5;
    self.selectionUnderlineView.layer.shadowOpacity = 0.14;
    self.selectionUnderlineView.layer.shadowRadius = 5.0;
    self.selectionUnderlineView.layer.shadowOffset = CGSizeMake(0.0, 2.0);
    if (@available(iOS 13.0, *)) {
        self.selectionUnderlineView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.selectionUnderlineLayer = [CAGradientLayer layer];
    self.selectionUnderlineLayer.startPoint = CGPointMake(0.0, 0.5);
    self.selectionUnderlineLayer.endPoint = CGPointMake(1.0, 0.5);
    self.selectionUnderlineLayer.locations = @[@0.0, @0.48, @1.0];
    [self.selectionUnderlineView.layer insertSublayer:self.selectionUnderlineLayer atIndex:0];
    [self addSubview:self.selectionUnderlineView];

    self.segmentsStackView = [[UIStackView alloc] init];
    self.segmentsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.segmentsStackView.axis = UILayoutConstraintAxisHorizontal;
    self.segmentsStackView.alignment = UIStackViewAlignmentFill;
    self.segmentsStackView.distribution = UIStackViewDistributionFillEqually;
    self.segmentsStackView.spacing = PPModrenSegmrntedSegmentSpacing;
    self.segmentsStackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self addSubview:self.segmentsStackView];

    self.selectionOutlineLeadingConstraint =
        [self.selectionOutlineView.leftAnchor constraintEqualToAnchor:self.leftAnchor constant:PPModrenSegmrntedOuterInset];
    self.selectionOutlineWidthConstraint =
        [self.selectionOutlineView.widthAnchor constraintEqualToConstant:0.0];
    self.selectionUnderlineLeadingConstraint =
        [self.selectionUnderlineView.leftAnchor constraintEqualToAnchor:self.leftAnchor constant:PPModrenSegmrntedOuterInset];
    self.selectionUnderlineWidthConstraint =
        [self.selectionUnderlineView.widthAnchor constraintEqualToConstant:0.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.containerFillView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.containerFillView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.containerFillView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.containerFillView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [self.containerBlurView.topAnchor constraintEqualToAnchor:self.containerFillView.topAnchor],
        [self.containerBlurView.leadingAnchor constraintEqualToAnchor:self.containerFillView.leadingAnchor],
        [self.containerBlurView.trailingAnchor constraintEqualToAnchor:self.containerFillView.trailingAnchor],
        [self.containerBlurView.bottomAnchor constraintEqualToAnchor:self.containerFillView.bottomAnchor],

        [self.containerTintOverlay.topAnchor constraintEqualToAnchor:self.containerFillView.topAnchor],
        [self.containerTintOverlay.leadingAnchor constraintEqualToAnchor:self.containerFillView.leadingAnchor],
        [self.containerTintOverlay.trailingAnchor constraintEqualToAnchor:self.containerFillView.trailingAnchor],
        [self.containerTintOverlay.bottomAnchor constraintEqualToAnchor:self.containerFillView.bottomAnchor],

        [self.selectionOutlineView.topAnchor constraintEqualToAnchor:self.topAnchor constant:PPModrenSegmrntedOuterInset],
        [self.selectionOutlineView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-PPModrenSegmrntedOuterInset],
        self.selectionOutlineLeadingConstraint,
        self.selectionOutlineWidthConstraint,

        [self.selectionUnderlineView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-6.0],
        [self.selectionUnderlineView.heightAnchor constraintEqualToConstant:PPModrenSegmrntedUnderlineHeight],
        self.selectionUnderlineLeadingConstraint,
        self.selectionUnderlineWidthConstraint,

        [self.segmentsStackView.topAnchor constraintEqualToAnchor:self.topAnchor constant:PPModrenSegmrntedOuterInset],
        [self.segmentsStackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:PPModrenSegmrntedOuterInset],
        [self.segmentsStackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-PPModrenSegmrntedOuterInset],
        [self.segmentsStackView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-PPModrenSegmrntedOuterInset]
    ]];
}

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(UIViewNoIntrinsicMetric, 44.0);
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat controlRadius = PPModrenSegmrntedPillRadiusForHeight(CGRectGetHeight(self.bounds),
                                                                  PPModrenSegmrntedContainerCornerRadius);
    CGFloat selectionRadius = PPModrenSegmrntedPillRadiusForHeight(CGRectGetHeight(self.selectionOutlineView.bounds),
                                                                    PPModrenSegmrntedSelectionCornerRadius);
    self.layer.cornerRadius = controlRadius;
    self.containerFillView.layer.cornerRadius = controlRadius;
    self.containerBlurView.layer.cornerRadius = controlRadius;
    self.containerTintOverlay.layer.cornerRadius = controlRadius;
    UIButtonConfiguration *containerConfiguration = self.containerBlurView.configuration;
    if (containerConfiguration.background.cornerRadius != controlRadius) {
        containerConfiguration.background.cornerRadius = controlRadius;
        self.containerBlurView.configuration = containerConfiguration;
    }
    self.layer.shadowPath = CGRectIsEmpty(self.bounds)
        ? nil
        : [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                     cornerRadius:controlRadius].CGPath;

    self.selectionOutlineView.layer.cornerRadius = selectionRadius;
    self.selectionUnderlineView.layer.cornerRadius = PPModrenSegmrntedUnderlineHeight * 0.5;


    self.selectionSurfaceLayer.frame = self.selectionOutlineView.bounds;
    self.selectionSurfaceLayer.cornerRadius = selectionRadius;


    self.selectionUnderlineLayer.frame = self.selectionUnderlineView.bounds;
    self.selectionUnderlineLayer.cornerRadius = 2.0;

    self.selectionOutlineView.layer.shadowPath = CGRectIsEmpty(self.selectionOutlineView.bounds)
        ? nil
        : [UIBezierPath bezierPathWithRoundedRect:self.selectionOutlineView.bounds
                                     cornerRadius:selectionRadius].CGPath;
    self.selectionUnderlineView.layer.shadowPath = CGRectIsEmpty(self.selectionUnderlineView.bounds)
        ? nil
        : [UIBezierPath bezierPathWithRoundedRect:self.selectionUnderlineView.bounds
                                     cornerRadius:PPModrenSegmrntedUnderlineHeight * 0.5].CGPath;

    [self pp_updateSelectionIndicatorMetrics];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self pp_updateChromeColors];
        [self pp_refreshAppearanceAnimated:NO];
    }
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    [self pp_updateSelectionIndicatorMetrics];
}

- (NSInteger)numberOfSegments
{
    return self.items.count;
}

- (void)setItems:(NSArray<PPModrenSegmrntedItem *> *)items
{
    _items = [items copy] ?: @[];

    if (_items.count == 0) {
        _selectedIndex = PPModrenSegmrntedNoSelection;
    } else if (_selectedIndex >= (NSInteger)_items.count) {
        _selectedIndex = _items.count - 1;
    }

    [self pp_rebuildSegments];
}

- (void)setSelectedIndex:(NSInteger)selectedIndex
{
    [self setSelectedIndex:selectedIndex animated:NO];
}

- (void)setSelectedIndex:(NSInteger)selectedIndex animated:(BOOL)animated
{
    NSInteger resolvedIndex = PPModrenSegmrntedNoSelection;
    if (self.items.count > 0 && selectedIndex >= 0) {
        resolvedIndex = MAX(0, MIN(selectedIndex, (NSInteger)self.items.count - 1));
    }

    _selectedIndex = resolvedIndex;
    [self pp_refreshAppearanceAnimated:animated];
}

- (void)setEnabled:(BOOL)enabled
{
    [super setEnabled:enabled];
    [self pp_refreshAppearanceAnimated:NO];
}

- (void)setContainerBackgroundColor:(UIColor *)containerBackgroundColor
{
    _containerBackgroundColor = containerBackgroundColor ?: PPModrenSegmrntedDefaultContainerColor();
    [self pp_updateChromeColors];
}

- (void)setSelectedSegmentColor:(UIColor *)selectedSegmentColor
{
    _selectedSegmentColor = selectedSegmentColor ?: AppPrimaryClr ?: UIColor.systemBlueColor;
    [self pp_updateChromeColors];
    [self pp_refreshAppearanceAnimated:NO];
}

- (void)setNormalTextColor:(UIColor *)normalTextColor
{
    _normalTextColor = normalTextColor ?: UIColor.secondaryLabelColor;
    [self pp_refreshAppearanceAnimated:NO];
}

- (void)setSelectedTextColor:(UIColor *)selectedTextColor
{
    _selectedTextColor = selectedTextColor ?: AppPrimaryTextClr ?: UIColor.labelColor;
    [self pp_refreshAppearanceAnimated:NO];
}

- (void)setNormalFont:(UIFont *)normalFont
{
    _normalFont = normalFont ?: [GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    [self pp_refreshAppearanceAnimated:NO];
}

- (void)setSelectedFont:(UIFont *)selectedFont
{
    _selectedFont = selectedFont ?: [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    [self pp_refreshAppearanceAnimated:NO];
}

- (void)setHidesContainerChrome:(BOOL)hidesContainerChrome
{
    if (_hidesContainerChrome == hidesContainerChrome) {
        return;
    }
    _hidesContainerChrome = hidesContainerChrome;
    [self pp_updateChromeColors];
    [self setNeedsLayout];
}

- (UIColor *)pp_accentColor
{
    return self.selectedSegmentColor ?: AppPrimaryClr ?: UIColor.systemBlueColor;
}

- (BOOL)pp_isDarkMode
{
    return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
}

- (void)pp_updateChromeColors
{
    UIColor *accent = [self pp_accentColor];
    BOOL dark = [self pp_isDarkMode];
    UIColor *surfaceColor = self.containerBackgroundColor ?: AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
    UIColor *liquidBorderColor = AppPrimaryClrShiner ?: surfaceColor;

    self.containerFillView.backgroundColor = UIColor.clearColor;
    self.containerBlurView.alpha = self.hidesContainerChrome ? 0.0 : 1.0;
     
    if (self.hidesContainerChrome)
    {
        self.containerTintOverlay.backgroundColor = UIColor.clearColor;
        self.containerFillView.layer.borderWidth = 0.0f;
        [self.containerFillView pp_setBorderColor:UIColor.clearColor];
        [self pp_setShadowColor:UIColor.clearColor];
        self.layer.shadowOpacity = 0.0f;
        self.layer.shadowRadius = 0.0f;
        self.layer.shadowOffset = CGSizeZero;
    }
    else if(!PPIOS26())
    {
        self.containerTintOverlay.backgroundColor =
            [surfaceColor colorWithAlphaComponent:dark ? 0.28 : 0.14];
        self.containerFillView.layer.borderWidth = dark ? 0.0f : 0.92f;
        [self.containerFillView pp_setBorderColor:dark
         ? UIColor.clearColor
         : [liquidBorderColor colorWithAlphaComponent:0.58]];

        [self pp_setShadowColor:[UIColor colorWithWhite:0.02 alpha:1.0]];
        self.layer.shadowOpacity = dark ? 0.16f : 0.08f;
        self.layer.shadowRadius = 14.0f;
        self.layer.shadowOffset = CGSizeMake(0.0, 8.0);

    }
    else
    {
        self.containerFillView.layer.borderWidth = 0.0f;
        [self.containerFillView pp_setBorderColor:UIColor.clearColor];
    }
  
   
  
    self.selectionOutlineView.layer.borderColor =
        [accent colorWithAlphaComponent:dark ? 0.0 : 0.0].CGColor;
    self.selectionOutlineView.layer.shadowColor =
        (dark ? accent : UIColor.blackColor).CGColor;
    self.selectionOutlineView.layer.shadowOpacity = dark ? 0.11 : 0.07;
    self.selectionSurfaceLayer.colors = @[
        (id)[accent colorWithAlphaComponent:dark ? 0.18 : 0.075].CGColor,
        (id)[accent colorWithAlphaComponent:dark ? 0.09 : 0.034].CGColor,
        (id)[UIColor.whiteColor colorWithAlphaComponent:dark ? 0.018 : 0.20].CGColor
    ];

    self.selectionUnderlineView.layer.shadowColor = accent.CGColor;
    self.selectionUnderlineLayer.colors = @[
        (id)[accent colorWithAlphaComponent:0.42].CGColor,
        (id)[accent colorWithAlphaComponent:1.0].CGColor,
        (id)[accent colorWithAlphaComponent:0.42].CGColor
    ];
}

- (UIColor *)pp_effectiveSelectedTextColor
{
    UIColor *candidate = self.selectedTextColor ?: AppPrimaryTextClr ?: UIColor.labelColor;
    UIColor *resolvedColor = candidate;
    if (@available(iOS 13.0, *)) {
        resolvedColor = [candidate resolvedColorWithTraitCollection:self.traitCollection];
    }

    CGFloat red = 0.0;
    CGFloat green = 0.0;
    CGFloat blue = 0.0;
    CGFloat alpha = 0.0;

    if ([resolvedColor getRed:&red green:&green blue:&blue alpha:&alpha]) {
        CGFloat luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue);
        if (alpha > 0.70 && luminance > 0.82) {
            return AppPrimaryTextClr ?: UIColor.labelColor;
        }
    }

    CGFloat white = 0.0;
    if ([resolvedColor getWhite:&white alpha:&alpha] && alpha > 0.70 && white > 0.82) {
        return AppPrimaryTextClr ?: UIColor.labelColor;
    }

    return candidate;
}

- (UIFont *)pp_scaledFont:(UIFont *)font textStyle:(UIFontTextStyle)textStyle
{
    UIFont *resolvedFont = font ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:resolvedFont];
}

- (void)pp_rebuildSegments
{
    for (UIView *view in self.segmentsStackView.arrangedSubviews) {
        [self.segmentsStackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    NSMutableArray<_PPModrenSegmrntedSegmentView *> *segmentViews =
        [NSMutableArray arrayWithCapacity:self.items.count];

    [self.items enumerateObjectsUsingBlock:^(PPModrenSegmrntedItem * _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
        _PPModrenSegmrntedSegmentView *segmentView = [[_PPModrenSegmrntedSegmentView alloc] init];
        segmentView.tag = (NSInteger)idx;
        segmentView.enabled = self.enabled;
        [segmentView configureWithItem:item];
        [segmentView addTarget:self
                        action:@selector(pp_segmentTapped:)
              forControlEvents:UIControlEventTouchUpInside];
        [self.segmentsStackView addArrangedSubview:segmentView];
        [segmentViews addObject:segmentView];
    }];

    self.segmentViews = [segmentViews copy];
    [self pp_refreshAppearanceAnimated:NO];
}

- (void)pp_refreshAppearanceAnimated:(BOOL)animated
{
    BOOL hasSelection = self.selectedIndex >= 0 && self.selectedIndex < (NSInteger)self.segmentViews.count;
    UIColor *selectedTextColor = [self pp_effectiveSelectedTextColor];
    UIFont *normalFont = [self pp_scaledFont:self.normalFont textStyle:UIFontTextStyleCaption1];
    UIFont *selectedFont = [self pp_scaledFont:self.selectedFont textStyle:UIFontTextStyleCaption1];

    [self.segmentViews enumerateObjectsUsingBlock:^(_PPModrenSegmrntedSegmentView * _Nonnull segmentView, NSUInteger idx, BOOL * _Nonnull stop) {
        segmentView.enabled = self.enabled;
        [segmentView applySelectionState:(hasSelection && idx == (NSUInteger)self.selectedIndex)
                                animated:animated
                         normalTextColor:self.normalTextColor
                       selectedTextColor:selectedTextColor
                              normalFont:normalFont
                            selectedFont:selectedFont];
    }];

    [self pp_updateSelectionIndicatorMetrics];

    NSString *selectedTitle = hasSelection ? self.items[self.selectedIndex].title : nil;
    self.accessibilityValue = selectedTitle;

    void (^layoutChanges)(void) = ^{
        CGFloat alpha = (hasSelection && self.enabled) ? 1.0 : 0.0;
        self.selectionOutlineView.alpha = alpha;
        self.selectionUnderlineView.alpha = alpha;
        self.selectionOutlineView.transform = hasSelection ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.94, 0.94);
        self.selectionUnderlineView.transform = hasSelection ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.72, 1.0);
        [self layoutIfNeeded];
    };

    BOOL shouldAnimate = animated && self.window != nil && !UIAccessibilityIsReduceMotionEnabled();
    if (shouldAnimate) {
        [UIView animateWithDuration:PPModrenSegmrntedAnimationDuration
                              delay:0.0
             usingSpringWithDamping:0.78
              initialSpringVelocity:0.24
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                         animations:layoutChanges
                         completion:nil];
    } else {
        layoutChanges();
    }
}

- (void)pp_updateSelectionIndicatorMetrics
{
    BOOL hasSelection = self.selectedIndex >= 0 && self.selectedIndex < (NSInteger)self.segmentViews.count;
    if (!hasSelection || CGRectIsEmpty(self.bounds)) {
        CGFloat centerX = CGRectGetMidX(self.bounds);
        self.selectionOutlineLeadingConstraint.constant = centerX;
        self.selectionOutlineWidthConstraint.constant = 0.0;
        self.selectionUnderlineLeadingConstraint.constant = centerX;
        self.selectionUnderlineWidthConstraint.constant = 0.0;
        return;
    }

    [self.segmentsStackView layoutIfNeeded];

    _PPModrenSegmrntedSegmentView *selectedSegment = self.segmentViews[self.selectedIndex];
    CGRect selectedFrame = [self convertRect:selectedSegment.frame fromView:self.segmentsStackView];
    CGFloat outlineInset = 2.0;
    CGFloat outlineWidth = MAX(0.0, CGRectGetWidth(selectedFrame) - (outlineInset * 2.0));
    CGFloat outlineLeading = CGRectGetMinX(selectedFrame) + outlineInset;

    CGFloat desiredUnderlineWidth = CGRectGetWidth(selectedFrame) * 0.34;
    CGFloat underlineWidth = MIN(MAX(30.0, desiredUnderlineWidth), 64.0);
    CGFloat underlineLeading = CGRectGetMidX(selectedFrame) - (underlineWidth * 0.5);

    self.selectionOutlineLeadingConstraint.constant = outlineLeading;
    self.selectionOutlineWidthConstraint.constant = outlineWidth;
    self.selectionUnderlineLeadingConstraint.constant = underlineLeading;
    self.selectionUnderlineWidthConstraint.constant = underlineWidth;
}

- (void)pp_segmentTapped:(_PPModrenSegmrntedSegmentView *)sender
{
    if (!self.enabled) {
        return;
    }

    NSInteger tappedIndex = sender.tag;
    if (tappedIndex == self.selectedIndex) {
        return;
    }

    [PPFunc triggerLightHaptic];
    [self setSelectedIndex:tappedIndex animated:YES];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

@end
