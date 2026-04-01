#import "PPModrenSegmrnted.h"
#import "PPNavigationController.h"

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

@property (nonatomic, strong) UIView *selectionBackgroundView;
@property (nonatomic, strong) UIStackView *contentStackView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) NSLayoutConstraint *iconWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *iconHeightConstraint;
@property (nonatomic, strong) PPModrenSegmrntedItem *item;
@property (nonatomic, assign, getter=isSegmentSelected) BOOL segmentSelected;

- (void)configureWithItem:(PPModrenSegmrntedItem *)item;
- (void)applySelectionState:(BOOL)selected
                   animated:(BOOL)animated
            normalTextColor:(UIColor *)normalTextColor
          selectedTextColor:(UIColor *)selectedTextColor
                 normalFont:(UIFont *)normalFont
               selectedFont:(UIFont *)selectedFont
           selectedFillColor:(UIColor *)selectedFillColor;

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

    UIButton *selectionBackgroundView = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleFixed configType:PPButtonConfigrationGlass];
    selectionBackgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    selectionBackgroundView.alpha = 0.0;
    
    UIButtonConfiguration *config = selectionBackgroundView.configuration;
    config.background.cornerRadius = 18.0;
    
    selectionBackgroundView.configuration = config;
    selectionBackgroundView.userInteractionEnabled = NO;
    if(!PPIOS26()) selectionBackgroundView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    if(!PPIOS26()) selectionBackgroundView.layer.borderWidth = 1.0;
    if(!PPIOS26()) selectionBackgroundView.layer.borderColor = [AppBackgroundClr colorWithAlphaComponent:0.0].CGColor;
    if(!PPIOS26()) selectionBackgroundView.layer.shadowColor = AppShadowClr.CGColor;
    if(!PPIOS26()) selectionBackgroundView.layer.shadowOpacity = 0.12;
    if(!PPIOS26()) selectionBackgroundView.layer.shadowRadius = 10.0;
    if(!PPIOS26()) selectionBackgroundView.layer.shadowOffset = CGSizeMake(0.0, 4.0);
    if (@available(iOS 13.0, *)) {
        selectionBackgroundView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.selectionBackgroundView = selectionBackgroundView;
    [self addSubview:selectionBackgroundView];

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFill;
    self.iconView = iconView;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.numberOfLines = 1;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.78;
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.titleLabel = titleLabel;

    UIStackView *contentStackView = [[UIStackView alloc] initWithArrangedSubviews:@[iconView, titleLabel]];
    contentStackView.translatesAutoresizingMaskIntoConstraints = NO;
    contentStackView.axis = UILayoutConstraintAxisVertical;
    contentStackView.alignment = UIStackViewAlignmentCenter;
    contentStackView.distribution = UIStackViewDistributionFill;
    contentStackView.spacing = 2.0;
    contentStackView.userInteractionEnabled = NO;
    contentStackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.contentStackView = contentStackView;
    [self addSubview:contentStackView];

    self.iconWidthConstraint = [iconView.widthAnchor constraintEqualToConstant:22.0];
    self.iconHeightConstraint = [iconView.heightAnchor constraintEqualToConstant:22.0];

    [NSLayoutConstraint activateConstraints:@[
        [selectionBackgroundView.topAnchor constraintEqualToAnchor:self.topAnchor constant:2.0],
        [selectionBackgroundView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:2.0],
        [selectionBackgroundView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-2.0],
        [selectionBackgroundView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-2.0],

        [contentStackView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.leadingAnchor constant:6.0],
        [contentStackView.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-6.0],
        [contentStackView.topAnchor constraintGreaterThanOrEqualToAnchor:self.topAnchor constant:3.0],
        [contentStackView.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-3.0],
        [contentStackView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [contentStackView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],

        self.iconWidthConstraint,
        self.iconHeightConstraint
    ]];

    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat radius = 22;
    if(!PPIOS26()) self.selectionBackgroundView.layer.cornerRadius = radius;
}

- (void)configureWithItem:(PPModrenSegmrntedItem *)item
{
    self.item = item;
    self.titleLabel.text = item.title;

    BOOL hasIcon = item.iconName.length > 0;
    self.iconView.hidden = !hasIcon;
    self.iconWidthConstraint.constant = hasIcon ? 18.0 : 0.0;
    self.iconHeightConstraint.constant = hasIcon ? 18.0 : 0.0;
}

- (UIImage *)segmentImageForSelectionState:(BOOL)selected tintColor:(UIColor *)tintColor
{
    NSString *iconName = selected && self.item.selectedIconName.length > 0 ? self.item.selectedIconName : self.item.iconName;
    if (iconName.length == 0) {
        return nil;
    }

    return [UIImage pp_symbolNamed:iconName
                         pointSize:selected ? 18.0 : 18.0
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
           selectedFillColor:(UIColor *)selectedFillColor
{
    self.segmentSelected = selected;

    UIColor *targetTextColor = selected ? selectedTextColor : normalTextColor;
    UIFont *targetFont = selected ? selectedFont : normalFont;
    UIImage *targetImage = [self segmentImageForSelectionState:selected tintColor:targetTextColor];

    void (^updates)(void) = ^{
        self.selectionBackgroundView.alpha = selected ? 1.0 : 0.0;
        if(!PPIOS26()) self.selectionBackgroundView.backgroundColor = selectedFillColor;
        if(!PPIOS26()) self.selectionBackgroundView.layer.shadowOpacity = selected ? 0.14 : 0.0;
        self.titleLabel.textColor = targetTextColor;
        self.titleLabel.font = targetFont;
        self.iconView.image = targetImage;
        self.iconView.tintColor = targetTextColor;
    };

    if (animated) {
        [UIView animateWithDuration:0.22
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
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
@property (nonatomic, strong, nullable) UIButton *glassContainerButton;
@property (nonatomic, strong) UIStackView *segmentsStackView;
@property (nonatomic, copy) NSArray<_PPModrenSegmrntedSegmentView *> *segmentViews;

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
    
    if(!PPIOS26()) _containerBackgroundColor = AppForgroundColr;
    _selectedSegmentColor = AppPrimaryClr;
    _normalTextColor = UIColor.secondaryLabelColor;
    _selectedTextColor = UIColor.whiteColor;
    _normalFont = [GM MidFontWithSize:13];
    _selectedFont = [GM boldFontWithSize:13];
    _selectedIndex = NSNotFound;

    UIView *containerFillView = [[UIView alloc] init];
    containerFillView.translatesAutoresizingMaskIntoConstraints = NO;
    containerFillView.backgroundColor = _containerBackgroundColor;
    if(!PPIOS26()) containerFillView.layer.borderWidth = 1.0;
    if(!PPIOS26()) containerFillView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;
    if (@available(iOS 13.0, *)) {
        containerFillView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.containerFillView = containerFillView;
    [self addSubview:containerFillView];

    if (@available(iOS 26.0, *)) {
        UIButton *glassContainerButton = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleFixed configType:PPButtonConfigrationGlass];
        glassContainerButton.userInteractionEnabled = NO;
        glassContainerButton.backgroundColor = UIColor.clearColor;
        glassContainerButton.translatesAutoresizingMaskIntoConstraints = NO;
        UIButtonConfiguration *config = glassContainerButton.configuration;
        config.background.cornerRadius = 22.0;
        glassContainerButton.configuration = config;
        self.glassContainerButton = glassContainerButton;
        [self addSubview:glassContainerButton];
    }

    UIStackView *segmentsStackView = [[UIStackView alloc] init];
    segmentsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    segmentsStackView.axis = UILayoutConstraintAxisHorizontal;
    segmentsStackView.alignment = UIStackViewAlignmentFill;
    segmentsStackView.distribution = UIStackViewDistributionFillEqually;
    segmentsStackView.spacing = 4.0;
    segmentsStackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.segmentsStackView = segmentsStackView;
    [self addSubview:segmentsStackView];

    [NSLayoutConstraint activateConstraints:@[
        [containerFillView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [containerFillView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [containerFillView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [containerFillView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [segmentsStackView.topAnchor constraintEqualToAnchor:self.topAnchor constant:3.0],
        [segmentsStackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:3.0],
        [segmentsStackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-3.0],
        [segmentsStackView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-3.0]
    ]];

    if (self.glassContainerButton) {
        [NSLayoutConstraint activateConstraints:@[
            [self.glassContainerButton.topAnchor constraintEqualToAnchor:self.topAnchor],
            [self.glassContainerButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [self.glassContainerButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [self.glassContainerButton.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
        ]];
    }
}

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(UIViewNoIntrinsicMetric, 44.0);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat radius = 22.0;;
    self.containerFillView.layer.cornerRadius = radius;
    self.glassContainerButton.layer.cornerRadius = radius;
}

- (NSInteger)numberOfSegments
{
    return self.items.count;
}

- (void)setItems:(NSArray<PPModrenSegmrntedItem *> *)items
{
    _items = [items copy] ?: @[];
    [self pp_rebuildSegments];
}

- (void)setSelectedIndex:(NSInteger)selectedIndex
{
    [self setSelectedIndex:selectedIndex animated:NO];
}

- (void)setSelectedIndex:(NSInteger)selectedIndex animated:(BOOL)animated
{
    if (self.items.count == 0) {
        _selectedIndex = NSNotFound;
        return;
    }

    NSInteger clampedIndex = MAX(0, MIN(selectedIndex, self.items.count - 1));
    _selectedIndex = clampedIndex;

    [self.segmentViews enumerateObjectsUsingBlock:^(_PPModrenSegmrntedSegmentView * _Nonnull segmentView, NSUInteger idx, BOOL * _Nonnull stop) {
        [segmentView applySelectionState:(idx == (NSUInteger)clampedIndex)
                                animated:animated
                         normalTextColor:self.normalTextColor
                       selectedTextColor:self.selectedTextColor
                              normalFont:self.normalFont
                            selectedFont:self.selectedFont
                        selectedFillColor:self.selectedSegmentColor];
    }];
}

- (void)setContainerBackgroundColor:(UIColor *)containerBackgroundColor
{
    _containerBackgroundColor = containerBackgroundColor ?: AppForgroundColr;
    self.containerFillView.backgroundColor = _containerBackgroundColor;
}

- (void)setSelectedSegmentColor:(UIColor *)selectedSegmentColor
{
    _selectedSegmentColor = selectedSegmentColor ?: AppPrimaryClr;
    [self setSelectedIndex:self.selectedIndex animated:NO];
}

- (void)setNormalTextColor:(UIColor *)normalTextColor
{
    _normalTextColor = normalTextColor ?: UIColor.secondaryLabelColor;
    [self setSelectedIndex:self.selectedIndex animated:NO];
}

- (void)setSelectedTextColor:(UIColor *)selectedTextColor
{
    _selectedTextColor = selectedTextColor ?: UIColor.whiteColor;
    [self setSelectedIndex:self.selectedIndex animated:NO];
}

- (void)setNormalFont:(UIFont *)normalFont
{
    _normalFont = normalFont ?: [GM MidFontWithSize:15];
    [self setSelectedIndex:self.selectedIndex animated:NO];
}

- (void)setSelectedFont:(UIFont *)selectedFont
{
    _selectedFont = selectedFont ?: [GM boldFontWithSize:15];
    [self setSelectedIndex:self.selectedIndex animated:NO];
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

    self.segmentViews = segmentViews;

    NSInteger targetIndex = self.selectedIndex == NSNotFound ? 0 : self.selectedIndex;
    [self setSelectedIndex:targetIndex animated:NO];
}

- (void)pp_segmentTapped:(_PPModrenSegmrntedSegmentView *)sender
{
    NSInteger tappedIndex = sender.tag;
    if (tappedIndex == self.selectedIndex) {
        return;
    }

    [self setSelectedIndex:tappedIndex animated:YES];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

@end
