#import "PPModrenSegmrnted.h"

static const NSInteger PPModrenSegmrntedNoSelection = -1;
static const CGFloat PPModrenSegmrntedRailInset = 4.0;
static const CGFloat PPModrenSegmrntedCornerRadius = 22.0;
static const NSTimeInterval PPModrenSegmrntedAnimationDuration = 0.34;

static inline UIColor *PPModrenSegmrntedDefaultContainerColor(void)
{
    return AppForgroundColr ?: [UIColor colorWithWhite:1.0 alpha:0.12];
}

static inline UIColor *PPModrenSegmrntedTrackStrokeColor(void)
{
    return [UIColor colorWithWhite:1.0 alpha:0.10];
}

static inline UIColor *PPModrenSegmrntedTrackSheenColor(void)
{
    return [UIColor colorWithWhite:1.0 alpha:0.12];
}

static inline UIColor *PPModrenSegmrntedIndicatorBorderColor(void)
{
    return [UIColor colorWithWhite:1.0 alpha:0.28];
}

static inline UIColor *PPModrenSegmrntedIndicatorShadowColor(void)
{
    return AppShadowClr ?: UIColor.blackColor;
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
    return [[self alloc] initWithTitle:title iconName:iconName selectedIconName:selectedIconName];
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

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.userInteractionEnabled = NO;
    self.iconView = iconView;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.numberOfLines = 1;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.72;
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.titleLabel = titleLabel;

    UIStackView *contentStackView = [[UIStackView alloc] initWithArrangedSubviews:@[iconView, titleLabel]];
    contentStackView.translatesAutoresizingMaskIntoConstraints = NO;
    contentStackView.axis = UILayoutConstraintAxisVertical;
    contentStackView.alignment = UIStackViewAlignmentCenter;
    contentStackView.distribution = UIStackViewDistributionFill;
    contentStackView.spacing = 1.5;
    contentStackView.userInteractionEnabled = NO;
    contentStackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.contentStackView = contentStackView;
    [self addSubview:contentStackView];

    self.iconWidthConstraint = [iconView.widthAnchor constraintEqualToConstant:16.0];
    self.iconHeightConstraint = [iconView.heightAnchor constraintEqualToConstant:16.0];

    [NSLayoutConstraint activateConstraints:@[
        [contentStackView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.leadingAnchor constant:6.0],
        [contentStackView.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-6.0],
        [contentStackView.topAnchor constraintGreaterThanOrEqualToAnchor:self.topAnchor constant:2.0],
        [contentStackView.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-2.0],
        [contentStackView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [contentStackView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
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
    self.contentStackView.spacing = hasIcon ? 1.5 : 0.0;

    [self pp_applyCurrentStateAnimated:NO];
}

- (UIImage *)segmentImageForSelectionState:(BOOL)selected tintColor:(UIColor *)tintColor
{
    NSString *iconName = selected && self.item.selectedIconName.length > 0 ? self.item.selectedIconName : self.item.iconName;
    if (iconName.length == 0) {
        return nil;
    }

    return [UIImage pp_symbolNamed:iconName
                         pointSize:selected ? 17.0 : 16.0
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
    self.cachedSelectedTextColor = selectedTextColor ?: UIColor.whiteColor;
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
    UIColor *selectedTextColor = self.cachedSelectedTextColor ?: UIColor.whiteColor;
    UIFont *normalFont = self.cachedNormalFont ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    UIFont *selectedFont = self.cachedSelectedFont ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];

    BOOL selected = self.segmentSelected;
    BOOL highlighted = self.highlighted;
    BOOL enabled = self.enabled;

    UIColor *targetTextColor = selected ? selectedTextColor : normalTextColor;
    UIFont *targetFont = selected ? selectedFont : normalFont;
    UIImage *targetImage = [self segmentImageForSelectionState:selected tintColor:targetTextColor];

    CGFloat restingAlpha = selected ? 1.0 : 0.76;
    CGFloat targetAlpha = enabled ? (highlighted ? 0.92 : restingAlpha) : 0.42;
    CGFloat iconAlpha = enabled ? (selected ? 1.0 : 0.84) : 0.42;
    CGFloat scale = highlighted ? (selected ? 0.985 : 0.965) : 1.0;
    CGAffineTransform targetTransform = CGAffineTransformMakeScale(scale, scale);

    void (^updates)(void) = ^{
        self.titleLabel.textColor = targetTextColor;
        self.titleLabel.font = targetFont;
        self.titleLabel.alpha = targetAlpha;
        self.iconView.image = targetImage;
        self.iconView.tintColor = targetTextColor;
        self.iconView.alpha = iconAlpha;
        self.contentStackView.transform = targetTransform;
    };

    BOOL shouldAnimate = animated && !UIAccessibilityIsReduceMotionEnabled();
    if (shouldAnimate) {
        [UIView animateWithDuration:0.18
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
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
@property (nonatomic, strong) UIView *selectionIndicatorView;
@property (nonatomic, strong) UIStackView *segmentsStackView;
@property (nonatomic, copy) NSArray<_PPModrenSegmrntedSegmentView *> *segmentViews;
@property (nonatomic, strong) NSLayoutConstraint *selectionIndicatorLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *selectionIndicatorWidthConstraint;
@property (nonatomic, strong) CAGradientLayer *containerSheenLayer;
@property (nonatomic, strong) CAGradientLayer *selectionGradientLayer;

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

    _containerBackgroundColor = PPModrenSegmrntedDefaultContainerColor();
    _selectedSegmentColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    _normalTextColor = UIColor.secondaryLabelColor;
    _selectedTextColor = UIColor.whiteColor;
    _normalFont = [GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    _selectedFont = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    _selectedIndex = PPModrenSegmrntedNoSelection;

    UIView *containerFillView = [[UIView alloc] init];
    containerFillView.translatesAutoresizingMaskIntoConstraints = NO;
    containerFillView.backgroundColor = _containerBackgroundColor;
    containerFillView.userInteractionEnabled = NO;
    containerFillView.layer.borderWidth = 0.0;
    containerFillView.layer.borderColor = PPModrenSegmrntedTrackStrokeColor().CGColor;
    containerFillView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        containerFillView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.containerFillView = containerFillView;
    [self addSubview:containerFillView];

    CAGradientLayer *containerSheenLayer = [CAGradientLayer layer];
    containerSheenLayer.startPoint = CGPointMake(0.5, 0.0);
    containerSheenLayer.endPoint = CGPointMake(0.5, 1.0);
    containerSheenLayer.locations = @[@0.0, @0.30, @1.0];
    containerSheenLayer.colors = @[
        (id)PPModrenSegmrntedTrackSheenColor().CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.03].CGColor,
        (id)UIColor.clearColor.CGColor
    ];
    [containerFillView.layer addSublayer:containerSheenLayer];
    self.containerSheenLayer = containerSheenLayer;

    UIView *selectionIndicatorView = [[UIView alloc] init];
    selectionIndicatorView.translatesAutoresizingMaskIntoConstraints = NO;
    selectionIndicatorView.userInteractionEnabled = NO;
    selectionIndicatorView.backgroundColor = _selectedSegmentColor;
    selectionIndicatorView.alpha = 0.0;
    selectionIndicatorView.layer.borderWidth = 0.5;
    selectionIndicatorView.layer.borderColor = PPModrenSegmrntedIndicatorBorderColor().CGColor;
    selectionIndicatorView.layer.shadowColor = PPModrenSegmrntedIndicatorShadowColor().CGColor;
    selectionIndicatorView.layer.shadowOpacity = 0.14;
    selectionIndicatorView.layer.shadowRadius = 12.0;
    selectionIndicatorView.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    if (@available(iOS 13.0, *)) {
        selectionIndicatorView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.selectionIndicatorView = selectionIndicatorView;
    [self addSubview:selectionIndicatorView];

    CAGradientLayer *selectionGradientLayer = [CAGradientLayer layer];
    selectionGradientLayer.startPoint = CGPointMake(0.15, 0.0);
    selectionGradientLayer.endPoint = CGPointMake(0.85, 1.0);
    selectionGradientLayer.locations = @[@0.0, @1.0];
    [selectionIndicatorView.layer insertSublayer:selectionGradientLayer atIndex:0];
    self.selectionGradientLayer = selectionGradientLayer;

    UIStackView *segmentsStackView = [[UIStackView alloc] init];
    segmentsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    segmentsStackView.axis = UILayoutConstraintAxisHorizontal;
    segmentsStackView.alignment = UIStackViewAlignmentFill;
    segmentsStackView.distribution = UIStackViewDistributionFillEqually;
    segmentsStackView.spacing = 0.0;
    segmentsStackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.segmentsStackView = segmentsStackView;
    [self addSubview:segmentsStackView];

    // Use physical left/right anchors here because segment frames are measured in
    // UIKit's left-based coordinate space. Semantic leading/trailing anchors mirror
    // in RTL and would place the active capsule under the wrong segment.
    self.selectionIndicatorLeadingConstraint = [selectionIndicatorView.leftAnchor constraintEqualToAnchor:self.leftAnchor constant:PPModrenSegmrntedRailInset];
    self.selectionIndicatorWidthConstraint = [selectionIndicatorView.widthAnchor constraintEqualToConstant:0.0];

    [NSLayoutConstraint activateConstraints:@[
        [containerFillView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [containerFillView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [containerFillView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [containerFillView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [selectionIndicatorView.topAnchor constraintEqualToAnchor:self.topAnchor constant:PPModrenSegmrntedRailInset],
        [selectionIndicatorView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-PPModrenSegmrntedRailInset],
        self.selectionIndicatorLeadingConstraint,
        self.selectionIndicatorWidthConstraint,

        [segmentsStackView.topAnchor constraintEqualToAnchor:self.topAnchor constant:PPModrenSegmrntedRailInset],
        [segmentsStackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:PPModrenSegmrntedRailInset],
        [segmentsStackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-PPModrenSegmrntedRailInset],
        [segmentsStackView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-PPModrenSegmrntedRailInset]
    ]];

    [self pp_updateSelectionIndicatorColors];
}

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(UIViewNoIntrinsicMetric, 44.0);
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat controlRadius = MIN(PPModrenSegmrntedCornerRadius, CGRectGetHeight(self.bounds) * 0.5);
    self.containerFillView.layer.cornerRadius = controlRadius;

    CGFloat indicatorHeight = MAX(0.0, CGRectGetHeight(self.bounds) - (PPModrenSegmrntedRailInset * 2.0));
    CGFloat indicatorRadius = MIN(MAX(16.0, indicatorHeight * 0.5), controlRadius - 2.0);
    self.selectionIndicatorView.layer.cornerRadius = indicatorRadius;

    self.containerSheenLayer.frame = self.containerFillView.bounds;
    self.containerSheenLayer.cornerRadius = controlRadius;
    self.selectionGradientLayer.frame = self.selectionIndicatorView.bounds;
    self.selectionGradientLayer.cornerRadius = indicatorRadius;
    self.selectionIndicatorView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.selectionIndicatorView.bounds cornerRadius:indicatorRadius].CGPath;

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
    } else if (_selectedIndex >= _items.count) {
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
        resolvedIndex = MAX(0, MIN(selectedIndex, self.items.count - 1));
    }

    _selectedIndex = resolvedIndex;
    [self pp_refreshAppearanceAnimated:animated];
}

- (void)setContainerBackgroundColor:(UIColor *)containerBackgroundColor
{
    _containerBackgroundColor = containerBackgroundColor ?: PPModrenSegmrntedDefaultContainerColor();
    self.containerFillView.backgroundColor = _containerBackgroundColor;
}

- (void)setSelectedSegmentColor:(UIColor *)selectedSegmentColor
{
    _selectedSegmentColor = selectedSegmentColor ?: AppPrimaryClr ?: UIColor.systemBlueColor;
    [self pp_updateSelectionIndicatorColors];
    [self pp_refreshAppearanceAnimated:NO];
}

- (void)setNormalTextColor:(UIColor *)normalTextColor
{
    _normalTextColor = normalTextColor ?: UIColor.secondaryLabelColor;
    [self pp_refreshAppearanceAnimated:NO];
}

- (void)setSelectedTextColor:(UIColor *)selectedTextColor
{
    _selectedTextColor = selectedTextColor ?: UIColor.whiteColor;
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

- (void)pp_updateSelectionIndicatorColors
{
    UIColor *baseColor = self.selectedSegmentColor ?: AppPrimaryClr ?: UIColor.systemBlueColor;
    self.selectionIndicatorView.backgroundColor = baseColor;
    self.selectionGradientLayer.colors = @[
        (id)[baseColor colorWithAlphaComponent:1.0].CGColor,
        (id)[baseColor colorWithAlphaComponent:0.88].CGColor
    ];
}

- (void)pp_rebuildSegments
{
    for (UIView *view in self.segmentsStackView.arrangedSubviews) {
        [self.segmentsStackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    NSMutableArray<_PPModrenSegmrntedSegmentView *> *segmentViews = [NSMutableArray arrayWithCapacity:self.items.count];
    [self.items enumerateObjectsUsingBlock:^(PPModrenSegmrntedItem * _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
        _PPModrenSegmrntedSegmentView *segmentView = [[_PPModrenSegmrntedSegmentView alloc] init];
        segmentView.tag = (NSInteger)idx;
        [segmentView configureWithItem:item];
        [segmentView addTarget:self action:@selector(pp_segmentTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.segmentsStackView addArrangedSubview:segmentView];
        [segmentViews addObject:segmentView];
    }];

    self.segmentViews = [segmentViews copy];
    [self pp_refreshAppearanceAnimated:NO];
}

- (void)pp_refreshAppearanceAnimated:(BOOL)animated
{
    BOOL hasSelection = self.selectedIndex >= 0 && self.selectedIndex < (NSInteger)self.segmentViews.count;

    [self.segmentViews enumerateObjectsUsingBlock:^(_PPModrenSegmrntedSegmentView * _Nonnull segmentView, NSUInteger idx, BOOL * _Nonnull stop) {
        [segmentView applySelectionState:(hasSelection && idx == (NSUInteger)self.selectedIndex)
                                animated:animated
                         normalTextColor:self.normalTextColor
                       selectedTextColor:self.selectedTextColor
                              normalFont:self.normalFont
                            selectedFont:self.selectedFont];
    }];

    [self pp_updateSelectionIndicatorMetrics];

    NSString *selectedTitle = hasSelection ? self.items[self.selectedIndex].title : nil;
    self.accessibilityValue = selectedTitle;

    void (^layoutChanges)(void) = ^{
        self.selectionIndicatorView.alpha = hasSelection ? 1.0 : 0.0;
        self.selectionIndicatorView.transform = hasSelection ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.88, 0.88);
        [self layoutIfNeeded];
    };

    BOOL shouldAnimate = animated && self.window != nil && !UIAccessibilityIsReduceMotionEnabled();
    if (shouldAnimate) {
        [UIView animateWithDuration:PPModrenSegmrntedAnimationDuration
                              delay:0.0
             usingSpringWithDamping:0.78
              initialSpringVelocity:0.15
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
                         animations:layoutChanges
                         completion:nil];
    } else {
        layoutChanges();
    }
}

- (void)pp_updateSelectionIndicatorMetrics
{
    BOOL hasSelection = self.selectedIndex >= 0 && self.selectedIndex < (NSInteger)self.segmentViews.count;
    if (!hasSelection) {
        self.selectionIndicatorLeadingConstraint.constant = CGRectGetMidX(self.bounds);
        self.selectionIndicatorWidthConstraint.constant = 0.0;
        return;
    }

    _PPModrenSegmrntedSegmentView *selectedSegment = self.segmentViews[self.selectedIndex];
    CGRect selectedFrame = [self convertRect:selectedSegment.frame fromView:self.segmentsStackView];
    self.selectionIndicatorLeadingConstraint.constant = CGRectGetMinX(selectedFrame);
    self.selectionIndicatorWidthConstraint.constant = CGRectGetWidth(selectedFrame);
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

    [self setSelectedIndex:tappedIndex animated:YES];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

@end
