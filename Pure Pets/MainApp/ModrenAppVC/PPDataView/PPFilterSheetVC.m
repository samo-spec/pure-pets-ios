//
//  PPFilterSheetVC.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 31/12/2025.
//  Refactored: Trending modern filter sheet for PPDataView.
//

#import "PPFilterSheetVC.h"
#import <QuartzCore/QuartzCore.h>

static NSString *PPFilterSheetL(NSString *english, NSString *arabic)
{
    return Language.isRTL ? arabic : english;
}

static UIFont *PPFilterSheetBold(CGFloat size)
{
    return [GM boldFontWithSize:size] ?: [UIFont systemFontOfSize:size weight:UIFontWeightBold];
}

static UIFont *PPFilterSheetMedium(CGFloat size)
{
    return [GM MidFontWithSize:size] ?: [UIFont systemFontOfSize:size weight:UIFontWeightMedium];
}

static UIColor *PPFilterSheetAccentColor(void)
{
    return AppPrimaryClr ?: UIColor.systemOrangeColor;
}

static UIColor *PPFilterSheetCanvasColor(void)
{
    return AppBackgroundClrLigter;
}

static CGFloat PPFilterSheetHairline(void)
{
    return 1.0 / MAX(UIScreen.mainScreen.scale, 1.0);
}

static UIColor *PPFilterSheetBlendColor(UIColor *fromColor, UIColor *toColor, CGFloat factor)
{
    factor = MIN(MAX(factor, 0.0), 1.0);

    CGFloat fr = 0.0, fg = 0.0, fb = 0.0, fa = 0.0;
    CGFloat tr = 0.0, tg = 0.0, tb = 0.0, ta = 0.0;

    if (![fromColor getRed:&fr green:&fg blue:&fb alpha:&fa]) {
        return toColor ?: fromColor;
    }
    if (![toColor getRed:&tr green:&tg blue:&tb alpha:&ta]) {
        return fromColor;
    }

    return [UIColor colorWithRed:(fr + ((tr - fr) * factor))
                           green:(fg + ((tg - fg) * factor))
                            blue:(fb + ((tb - fb) * factor))
                           alpha:(fa + ((ta - fa) * factor))];
}

#pragma mark - Capsule label

@interface PPFilterCapsuleLabel : UILabel
@property (nonatomic, assign) UIEdgeInsets contentInsets;
@end

@implementation PPFilterCapsuleLabel

- (instancetype)init
{
    self = [super init];
    if (self) {
        _contentInsets = UIEdgeInsetsMake(6.0, 10.0, 6.0, 10.0);
    }
    return self;
}

- (CGSize)intrinsicContentSize
{
    CGSize size = [super intrinsicContentSize];
    size.width += self.contentInsets.left + self.contentInsets.right;
    size.height += self.contentInsets.top + self.contentInsets.bottom;
    return size;
}

- (void)drawTextInRect:(CGRect)rect
{
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, self.contentInsets)];
}

@end

#pragma mark - Option pill

@interface PPFilterOptionPill : UIButton
@property (nonatomic, assign) NSInteger optionValue;
@property (nonatomic, copy) NSString *groupID;
@property (nonatomic, copy) NSString *optionTitle;
@property (nonatomic, copy, nullable) NSString *optionIconName;
- (void)pp_configureWithOption:(PPFilterOption *)option
                       groupID:(NSString *)groupID
                        target:(id)target
                        action:(SEL)action;
- (void)pp_applySelected:(BOOL)selected accentColor:(UIColor *)accentColor;
@end

@implementation PPFilterOptionPill

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat radius = CGRectGetHeight(self.bounds) * 0.5;
    self.layer.cornerRadius = radius;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:radius].CGPath;
}

- (void)pp_configureWithOption:(PPFilterOption *)option
                       groupID:(NSString *)groupID
                        target:(id)target
                        action:(SEL)action
{
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.groupID = groupID;
    self.optionValue = option.value;
    self.optionTitle = option.title ?: @"";
    self.optionIconName = option.iconName;
    self.adjustsImageWhenHighlighted = NO;
    self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.accessibilityIdentifier = [NSString stringWithFormat:@"pp.filter.%@.%ld", groupID, (long)option.value];
    [self setTitle:self.optionTitle forState:UIControlStateNormal];
    [self addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    [self.heightAnchor constraintEqualToConstant:44.0].active = YES;
}

- (void)pp_applySelected:(BOOL)selected accentColor:(UIColor *)accentColor
{
    UIColor *accent = accentColor ?: PPFilterSheetAccentColor();
    UIImage *icon = nil;
    if (self.optionIconName.length > 0) {
        UIColor *iconColor = selected ? UIColor.whiteColor : accent;
        icon =
        [UIImage pp_symbolNamed:self.optionIconName
                      pointSize:14
                         weight:UIImageSymbolWeightSemibold
                          scale:UIImageSymbolScaleSmall
                        palette:@[iconColor]
                   makeTemplate:YES];
    }

    UIColor *surfaceColor = selected
        ? accent
        : AppBackgroundClrLigter;
    UIColor *foregroundColor = selected
        ? UIColor.whiteColor
        : UIColor.labelColor;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *configuration = [UIButtonConfiguration filledButtonConfiguration];
        configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        configuration.title = self.optionTitle ?: @"";
        configuration.image = icon;
        configuration.imagePadding = icon ? 6.0 : 0.0;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(11.0, 15.0, 11.0, 15.0);

        UIBackgroundConfiguration *background = [UIBackgroundConfiguration clearConfiguration];
        background.backgroundColor = surfaceColor;
        background.strokeColor = selected
            ? UIColor.clearColor
            : [accent colorWithAlphaComponent:0.14];
        background.strokeWidth = selected ? 0.0 : 1.0;
        background.cornerRadius = 22.0;
        configuration.background = background;
        configuration.baseBackgroundColor = surfaceColor;
        configuration.baseForegroundColor = foregroundColor;
        configuration.titleTextAttributesTransformer =
        ^NSDictionary<NSAttributedStringKey,id> * _Nonnull(NSDictionary<NSAttributedStringKey,id> * _Nonnull incoming) {
            NSMutableDictionary *attributes = [incoming mutableCopy];
            attributes[NSFontAttributeName] = selected
                ? PPFilterSheetBold(14.0)
                : PPFilterSheetMedium(14.0);
            return attributes;
        };

        self.configuration = configuration;
    } else {
        self.backgroundColor = surfaceColor;
        self.layer.borderWidth = selected ? 0.0 : 1.0;
        self.layer.borderColor = selected
            ? UIColor.clearColor.CGColor
            : [accent colorWithAlphaComponent:0.14].CGColor;
        self.contentEdgeInsets = UIEdgeInsetsMake(11.0, 15.0, 11.0, 15.0);
        self.titleLabel.font = selected ? PPFilterSheetBold(14.0) : PPFilterSheetMedium(14.0);
        [self setTitle:self.optionTitle ?: @"" forState:UIControlStateNormal];
        [self setTitleColor:foregroundColor forState:UIControlStateNormal];
        [self setImage:icon forState:UIControlStateNormal];
        self.tintColor = foregroundColor;
        self.titleEdgeInsets = icon ? UIEdgeInsetsMake(0.0, 6.0, 0.0, -6.0) : UIEdgeInsetsZero;
        self.imageEdgeInsets = UIEdgeInsetsZero;
    }

    self.layer.masksToBounds = NO;
    self.layer.shadowColor = accent.CGColor;
    self.layer.shadowOpacity = selected ? 0.20f : 0.0f;
    self.layer.shadowRadius = selected ? 16.0f : 0.0f;
    self.layer.shadowOffset = selected ? CGSizeMake(0.0, 10.0) : CGSizeZero;
    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
}

@end

#pragma mark - Wrap layout

@interface PPFilterWrapView : UIView
@property (nonatomic, copy) NSArray<PPFilterOptionPill *> *pillViews;
@property (nonatomic, assign) CGFloat cachedHeight;
- (instancetype)initWithPills:(NSArray<PPFilterOptionPill *> *)pillViews;
@end

@implementation PPFilterWrapView

- (instancetype)initWithPills:(NSArray<PPFilterOptionPill *> *)pillViews
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
        self.backgroundColor = UIColor.clearColor;
        self.pillViews = pillViews ?: @[];
        for (PPFilterOptionPill *pill in self.pillViews) {
            [self addSubview:pill];
        }
    }
    return self;
}

- (CGSize)intrinsicContentSize
{
    CGFloat width = CGRectGetWidth(self.bounds);
    if (width < 10.0) {
        width = UIScreen.mainScreen.bounds.size.width - 72.0;
    }
    CGFloat height = [self pp_requiredHeightForWidth:width applyFrames:NO];
    return CGSizeMake(UIViewNoIntrinsicMetric, height);
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat width = CGRectGetWidth(self.bounds);
    if (width < 10.0) {
        return;
    }

    CGFloat newHeight = [self pp_requiredHeightForWidth:width applyFrames:YES];
    if (fabs(newHeight - self.cachedHeight) > 0.5) {
        self.cachedHeight = newHeight;
        [self invalidateIntrinsicContentSize];
    }
}

- (CGSize)pp_sizeForPill:(PPFilterOptionPill *)pill constrainedToWidth:(CGFloat)availableWidth
{
    CGSize size = [pill intrinsicContentSize];
    if (size.width <= 1.0 || size.height <= 1.0) {
        size = [pill sizeThatFits:CGSizeMake(availableWidth, CGFLOAT_MAX)];
    }
    size.width = MIN(MAX(66.0, ceil(size.width)), availableWidth);
    size.height = MAX(44.0, ceil(size.height));
    return size;
}

- (CGFloat)pp_requiredHeightForWidth:(CGFloat)width applyFrames:(BOOL)applyFrames
{
    CGFloat availableWidth = MAX(120.0, width);
    CGFloat horizontalSpacing = 10.0;
    CGFloat verticalSpacing = 10.0;
    BOOL isRTL = (Language.semanticAttributeForCurrentLanguage == UISemanticContentAttributeForceRightToLeft);

    NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];
    NSMutableArray<NSDictionary *> *currentRow = [NSMutableArray array];
    CGFloat currentRowWidth = 0.0;
    CGFloat currentRowHeight = 0.0;

    for (PPFilterOptionPill *pill in self.pillViews) {
        CGSize pillSize = [self pp_sizeForPill:pill constrainedToWidth:availableWidth];
        BOOL needsNewRow = (currentRow.count > 0) && ((currentRowWidth + horizontalSpacing + pillSize.width) > availableWidth);

        if (needsNewRow) {
            [rows addObject:@{
                @"items" : [currentRow copy],
                @"width" : @(currentRowWidth),
                @"height": @(currentRowHeight)
            }];
            [currentRow removeAllObjects];
            currentRowWidth = 0.0;
            currentRowHeight = 0.0;
        }

        [currentRow addObject:@{
            @"pill"  : pill,
            @"width" : @(pillSize.width),
            @"height": @(pillSize.height)
        }];
        currentRowWidth = currentRow.count == 1 ? pillSize.width : (currentRowWidth + horizontalSpacing + pillSize.width);
        currentRowHeight = MAX(currentRowHeight, pillSize.height);
    }

    if (currentRow.count > 0) {
        [rows addObject:@{
            @"items" : [currentRow copy],
            @"width" : @(currentRowWidth),
            @"height": @(currentRowHeight)
        }];
    }

    CGFloat y = 0.0;
    for (NSDictionary *row in rows) {
        NSArray<NSDictionary *> *items = row[@"items"];
        CGFloat rowWidth = [row[@"width"] doubleValue];
        CGFloat rowHeight = [row[@"height"] doubleValue];
        CGFloat x = isRTL ? MAX(0.0, availableWidth - rowWidth) : 0.0;

        for (NSDictionary *item in items) {
            PPFilterOptionPill *pill = item[@"pill"];
            CGFloat pillWidth = [item[@"width"] doubleValue];
            CGFloat pillHeight = [item[@"height"] doubleValue];
            CGFloat yOffset = y + ((rowHeight - pillHeight) * 0.5);

            if (applyFrames) {
                pill.frame = CGRectIntegral(CGRectMake(x, yOffset, pillWidth, pillHeight));
            }
            x += pillWidth + horizontalSpacing;
        }

        y += rowHeight + verticalSpacing;
    }

    if (rows.count > 0) {
        y -= verticalSpacing;
    }
    return MAX(0.0, y);
}

@end

#pragma mark - Section view

@interface PPFilterSectionView : UIView
@property (nonatomic, strong, readonly) PPFilterGroup *group;
@property (nonatomic, copy, readonly) NSArray<PPFilterOptionPill *> *pills;
- (instancetype)initWithGroup:(PPFilterGroup *)group
                  accentColor:(UIColor *)accentColor
                       target:(id)target
                       action:(SEL)action;
- (void)pp_applyGroupStateWithAccentColor:(UIColor *)accentColor;
@end

@interface PPFilterSectionView ()
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *accentOrbView;
@property (nonatomic, strong) UIView *iconChipView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *summaryLabel;
@property (nonatomic, strong) PPFilterCapsuleLabel *stateLabel;
@property (nonatomic, strong) PPFilterWrapView *wrapView;
@property (nonatomic, strong, readwrite) PPFilterGroup *group;
@property (nonatomic, copy, readwrite) NSArray<PPFilterOptionPill *> *pills;
@end

@implementation PPFilterSectionView

- (instancetype)initWithGroup:(PPFilterGroup *)group
                  accentColor:(UIColor *)accentColor
                       target:(id)target
                       action:(SEL)action
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _group = group;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
        [self pp_buildUIWithAccentColor:accentColor target:target action:action];
        [self pp_applyGroupStateWithAccentColor:accentColor];
    }
    return self;
}

- (void)pp_buildUIWithAccentColor:(UIColor *)accentColor
                           target:(id)target
                           action:(SEL)action
{
    UIColor *accent = accentColor ?: PPFilterSheetAccentColor();
    NSTextAlignment alignment = Language.alignmentForCurrentLanguage;

    UIView *surfaceView = [[UIView alloc] init];
    surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    surfaceView.backgroundColor = AppBackgroundClrLigter;
    surfaceView.layer.cornerRadius = 28.0;
    surfaceView.layer.borderWidth = PPFilterSheetHairline();
    surfaceView.layer.borderColor = [accent colorWithAlphaComponent:0.10].CGColor;
    surfaceView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self addSubview:surfaceView];
    self.surfaceView = surfaceView;

    UIView *accentOrb = [[UIView alloc] init];
    accentOrb.translatesAutoresizingMaskIntoConstraints = NO;
    accentOrb.backgroundColor = [accent colorWithAlphaComponent:0.10];
    accentOrb.layer.cornerRadius = 54.0;
    accentOrb.userInteractionEnabled = NO;
    [surfaceView addSubview:accentOrb];
    self.accentOrbView = accentOrb;

    UIView *iconChipView = [[UIView alloc] init];
    iconChipView.translatesAutoresizingMaskIntoConstraints = NO;
    iconChipView.layer.cornerRadius = 20.0;
    iconChipView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        iconChipView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [surfaceView addSubview:iconChipView];
    self.iconChipView = iconChipView;

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.tintColor = accent;
    if (self.group.chipIconName.length > 0) {
        iconView.image =
        [UIImage pp_symbolNamed:self.group.chipIconName
                      pointSize:16
                         weight:UIImageSymbolWeightSemibold
                          scale:UIImageSymbolScaleMedium
                        palette:@[accent]
                   makeTemplate:YES];
    }
    [iconChipView addSubview:iconView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = PPFilterSheetBold(17.0);
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.textAlignment = alignment;
    titleLabel.text = self.group.title;
    [surfaceView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    UILabel *summaryLabel = [[UILabel alloc] init];
    summaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    summaryLabel.font = PPFilterSheetMedium(13.0);
    summaryLabel.textAlignment = alignment;
    summaryLabel.textColor = UIColor.secondaryLabelColor;
    summaryLabel.numberOfLines = 2;
    [surfaceView addSubview:summaryLabel];
    self.summaryLabel = summaryLabel;

    PPFilterCapsuleLabel *stateLabel = [[PPFilterCapsuleLabel alloc] init];
    stateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    stateLabel.font = PPFilterSheetBold(11.0);
    stateLabel.textAlignment = NSTextAlignmentCenter;
    stateLabel.contentInsets = UIEdgeInsetsMake(6.0, 10.0, 6.0, 10.0);
    stateLabel.layer.cornerRadius = 14.0;
    stateLabel.clipsToBounds = YES;
    [surfaceView addSubview:stateLabel];
    self.stateLabel = stateLabel;

    NSMutableArray<PPFilterOptionPill *> *pills = [NSMutableArray arrayWithCapacity:self.group.options.count];
    for (PPFilterOption *option in self.group.options) {
        PPFilterOptionPill *pill = [PPFilterOptionPill buttonWithType:UIButtonTypeSystem];
        [pill pp_configureWithOption:option groupID:self.group.filterID target:target action:action];
        [pills addObject:pill];
    }
    self.pills = [pills copy];

    PPFilterWrapView *wrapView = [[PPFilterWrapView alloc] initWithPills:self.pills];
    [surfaceView addSubview:wrapView];
    self.wrapView = wrapView;

    [NSLayoutConstraint activateConstraints:@[
        [surfaceView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [surfaceView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [surfaceView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [surfaceView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [accentOrb.widthAnchor constraintEqualToConstant:108.0],
        [accentOrb.heightAnchor constraintEqualToConstant:108.0],
        [accentOrb.topAnchor constraintEqualToAnchor:surfaceView.topAnchor constant:-26.0],
        [accentOrb.trailingAnchor constraintEqualToAnchor:surfaceView.trailingAnchor constant:26.0],

        [iconChipView.topAnchor constraintEqualToAnchor:surfaceView.topAnchor constant:18.0],
        [iconChipView.leadingAnchor constraintEqualToAnchor:surfaceView.leadingAnchor constant:18.0],
        [iconChipView.widthAnchor constraintEqualToConstant:40.0],
        [iconChipView.heightAnchor constraintEqualToConstant:40.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconChipView.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconChipView.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:18.0],
        [iconView.heightAnchor constraintEqualToConstant:18.0],

        [stateLabel.topAnchor constraintEqualToAnchor:surfaceView.topAnchor constant:18.0],
        [stateLabel.trailingAnchor constraintEqualToAnchor:surfaceView.trailingAnchor constant:-18.0],

        [titleLabel.leadingAnchor constraintEqualToAnchor:iconChipView.trailingAnchor constant:12.0],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:stateLabel.leadingAnchor constant:-10.0],
        [titleLabel.topAnchor constraintEqualToAnchor:surfaceView.topAnchor constant:18.0],

        [summaryLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [summaryLabel.trailingAnchor constraintEqualToAnchor:surfaceView.trailingAnchor constant:-18.0],
        [summaryLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],

        [wrapView.leadingAnchor constraintEqualToAnchor:surfaceView.leadingAnchor constant:18.0],
        [wrapView.trailingAnchor constraintEqualToAnchor:surfaceView.trailingAnchor constant:-18.0],
        [wrapView.topAnchor constraintEqualToAnchor:summaryLabel.bottomAnchor constant:16.0],
        [wrapView.bottomAnchor constraintEqualToAnchor:surfaceView.bottomAnchor constant:-18.0]
    ]];
}

- (void)pp_applyGroupStateWithAccentColor:(UIColor *)accentColor
{
    UIColor *accent = accentColor ?: PPFilterSheetAccentColor();
    NSString *selectedTitle = self.group.selectedTitle ?: PPFilterSheetL(@"All", @"الكل");
    BOOL isActive = self.group.isActive;

    self.summaryLabel.text = isActive
        ? [NSString stringWithFormat:@"%@ %@", PPFilterSheetL(@"Current:", @"الحالي:"), selectedTitle]
        : [NSString stringWithFormat:@"%@ %@", PPFilterSheetL(@"Default:", @"الافتراضي:"), selectedTitle];

    self.stateLabel.text = isActive
        ? PPFilterSheetL(@"Active", @"مفعل")
        : PPFilterSheetL(@"Default", @"افتراضي");
    self.stateLabel.textColor = isActive ? UIColor.whiteColor : [accent colorWithAlphaComponent:0.94];
    self.stateLabel.backgroundColor = isActive
        ? accent
        : [accent colorWithAlphaComponent:0.12];

    self.iconChipView.backgroundColor = [accent colorWithAlphaComponent:isActive ? 0.20 : 0.12];
    self.surfaceView.layer.borderColor = [accent colorWithAlphaComponent:isActive ? 0.22 : 0.10].CGColor;

    for (PPFilterOptionPill *pill in self.pills) {
        [pill pp_applySelected:(pill.optionValue == self.group.selectedValue) accentColor:accent];
    }
    [self.wrapView invalidateIntrinsicContentSize];
    [self.wrapView setNeedsLayout];
}

@end

#pragma mark - Main VC

@interface PPFilterSheetVC ()
@property (nonatomic, strong) UIView *canvasView;
@property (nonatomic, strong) CAGradientLayer *canvasGradientLayer;
@property (nonatomic, strong) CAGradientLayer *canvasGlowLayer;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIView *heroShadowView;
@property (nonatomic, strong) UIView *heroCardView;
@property (nonatomic, strong) CAGradientLayer *heroGradientLayer;
@property (nonatomic, strong) CAGradientLayer *heroMeshLayer;
@property (nonatomic, strong) CAGradientLayer *heroShineLayer;
@property (nonatomic, strong) PPFilterCapsuleLabel *sectionCapsuleLabel;
@property (nonatomic, strong) PPFilterCapsuleLabel *activeCountCapsuleLabel;
@property (nonatomic, strong) PPFilterCapsuleLabel *resultCountCapsuleLabel;
@property (nonatomic, strong) UILabel *heroStatusLabel;
@property (nonatomic, strong) UILabel *footerSummaryLabel;
@property (nonatomic, strong) UIButton *resetButton;
@property (nonatomic, strong) UIButton *applyButton;
@property (nonatomic, strong) UIView *footerShellView;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<PPFilterOptionPill *> *> *pillsByGroupID;
@property (nonatomic, strong) NSMutableDictionary<NSString *, PPFilterSectionView *> *sectionViewsByGroupID;
@property (nonatomic, copy) NSArray<UIView *> *entranceViews;
@property (nonatomic, assign) BOOL didAnimateEntrance;
@property (nonatomic, assign) BOOL didPrepareEntranceState;
@end

@implementation PPFilterSheetVC

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = AppBackgroundClr;
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.pillsByGroupID = [NSMutableDictionary dictionary];
    self.sectionViewsByGroupID = [NSMutableDictionary dictionary];

    if (!self.filterState) {
        self.filterState = [PPFilterState stateWithGroups:@[]];
    }

    if (@available(iOS 15.0, *)) {
        self.sheetPresentationController.prefersGrabberVisible = YES;
    }

    [self pp_buildUI];
    //[self pp_updateCanvasColors];
    [self pp_updateHeroGradientColors];
    [self pp_updateActiveStateAnimated:NO];
    [self pp_prepareEntranceStateIfNeeded];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self pp_performEntranceAnimationIfNeeded];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    self.canvasGradientLayer.frame = self.canvasView.bounds;
    self.canvasGlowLayer.frame = self.canvasView.bounds;
    self.heroGradientLayer.frame = self.heroCardView.bounds;
    self.heroMeshLayer.frame = self.heroCardView.bounds;
    self.heroShineLayer.frame = self.heroCardView.bounds;

    self.heroShadowView.layer.shadowPath =
    [UIBezierPath bezierPathWithRoundedRect:self.heroShadowView.bounds cornerRadius:30.0].CGPath;
    self.footerShellView.layer.shadowPath =
    [UIBezierPath bezierPathWithRoundedRect:self.footerShellView.bounds cornerRadius:28.0].CGPath;
}

#pragma mark - Build UI

- (void)pp_buildUI
{
    NSMutableArray<UIView *> *entranceViews = [NSMutableArray array];
    UISemanticContentAttribute semantic = Language.semanticAttributeForCurrentLanguage;

    [self pp_buildBackdropCanvas];

    UIView *handle = nil;
    if (@available(iOS 15.0, *)) {
        handle = nil;
    } else {
        handle = [[UIView alloc] init];
        handle.translatesAutoresizingMaskIntoConstraints = NO;
        handle.backgroundColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.22];
        handle.layer.cornerRadius = 2.5;
        [self.view addSubview:handle];
    }

    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.alwaysBounceVertical = YES;
    scrollView.backgroundColor = UIColor.clearColor;
    scrollView.semanticContentAttribute = semantic;
    [self.view addSubview:scrollView];
    self.scrollView = scrollView;

    UIStackView *contentStack = [[UIStackView alloc] init];
    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    contentStack.axis = UILayoutConstraintAxisVertical;
    contentStack.spacing = 18.0;
    contentStack.semanticContentAttribute = semantic;
    [scrollView addSubview:contentStack];
    self.contentStack = contentStack;

    UIView *heroView = [self pp_buildHeroView];
    [contentStack addArrangedSubview:heroView];
    [entranceViews addObject:heroView];

    if (self.filterState.groups.count == 0) {
        UIView *emptyState = [self pp_emptyStateView];
        [contentStack addArrangedSubview:emptyState];
        [entranceViews addObject:emptyState];
    } else {
        for (PPFilterGroup *group in self.filterState.groups) {
            PPFilterSectionView *sectionView =
            [[PPFilterSectionView alloc] initWithGroup:group
                                           accentColor:PPFilterSheetAccentColor()
                                                target:self
                                                action:@selector(pp_pillTapped:)];
            self.sectionViewsByGroupID[group.filterID] = sectionView;
            self.pillsByGroupID[group.filterID] = sectionView.pills;
            [contentStack addArrangedSubview:sectionView];
            [entranceViews addObject:sectionView];
        }
    }

    UIView *footerShell = [self pp_buildFooterShell];
    [self.view addSubview:footerShell];
    self.footerShellView = footerShell;
    [entranceViews addObject:footerShell];
    self.entranceViews = [entranceViews copy];

    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray arrayWithArray:@[
        [footerShell.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [footerShell.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],
        [footerShell.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12.0],

        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:footerShell.topAnchor constant:-14.0],

        [contentStack.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor constant:6.0],
        [contentStack.leadingAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.leadingAnchor constant:16.0],
        [contentStack.trailingAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.trailingAnchor constant:-16.0],
        [contentStack.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor constant:-24.0]
    ]];

    if (handle) {
        [constraints addObjectsFromArray:@[
            [handle.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10.0],
            [handle.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
            [handle.widthAnchor constraintEqualToConstant:42.0],
            [handle.heightAnchor constraintEqualToConstant:5.0],
            [scrollView.topAnchor constraintEqualToAnchor:handle.bottomAnchor constant:16.0]
        ]];
    } else {
        [constraints addObject:[scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8.0]];
    }

    [NSLayoutConstraint activateConstraints:constraints];
}

- (void)pp_buildBackdropCanvas
{
    UIView *canvasView = [[UIView alloc] init];
    canvasView.translatesAutoresizingMaskIntoConstraints = NO;
    canvasView.backgroundColor = UIColor.clearColor;
    canvasView.userInteractionEnabled = NO;
    [self.view insertSubview:canvasView atIndex:0];
    self.canvasView = canvasView;

    [NSLayoutConstraint activateConstraints:@[
        [canvasView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [canvasView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [canvasView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [canvasView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.startPoint = CGPointMake(0.08, 0.0);
    gradientLayer.endPoint = CGPointMake(0.92, 1.0);
    gradientLayer.locations = @[@0.0, @0.34, @1.0];
    [canvasView.layer addSublayer:gradientLayer];
    self.canvasGradientLayer = gradientLayer;

    CAGradientLayer *glowLayer = [CAGradientLayer layer];
    glowLayer.type = kCAGradientLayerRadial;
    glowLayer.startPoint = CGPointMake(0.20, 0.0);
    glowLayer.endPoint = CGPointMake(1.0, 1.0);
    glowLayer.locations = @[@0.0, @0.24, @1.0];
    [canvasView.layer addSublayer:glowLayer];
    self.canvasGlowLayer = glowLayer;
}

- (UIView *)pp_buildHeroView
{
    UIColor *accent = PPFilterSheetAccentColor();
    NSTextAlignment alignment = Language.alignmentForCurrentLanguage;

    UIView *shadowView = [[UIView alloc] init];
    shadowView.translatesAutoresizingMaskIntoConstraints = NO;
    shadowView.backgroundColor = UIColor.clearColor;
    shadowView.layer.shadowColor = [accent colorWithAlphaComponent:0.34].CGColor;
    shadowView.layer.shadowOpacity = 0.20f;
    shadowView.layer.shadowRadius = 28.0f;
    shadowView.layer.shadowOffset = CGSizeMake(0.0, 16.0);
    self.heroShadowView = shadowView;

    UIView *heroCard = [[UIView alloc] init];
    heroCard.translatesAutoresizingMaskIntoConstraints = NO;
    heroCard.layer.cornerRadius = 30.0;
    heroCard.layer.borderWidth = PPFilterSheetHairline();
    heroCard.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.08].CGColor;
    heroCard.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        heroCard.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [shadowView addSubview:heroCard];
    self.heroCardView = heroCard;

    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.startPoint = CGPointMake(0.0, 0.15);
    gradient.endPoint = CGPointMake(1.0, 1.0);
    gradient.locations = @[@0.0, @0.36, @1.0];
    gradient.opacity = 1;
    [heroCard.layer insertSublayer:gradient atIndex:0];
    self.heroGradientLayer = gradient;

    CAGradientLayer *mesh = [CAGradientLayer layer];
    mesh.startPoint = CGPointMake(1.0, 0.0);
    mesh.endPoint = CGPointMake(0.0, 1.0);
    mesh.locations = @[@0.0, @0.28, @0.72, @1.0];
    mesh.opacity = 1;
    [heroCard.layer insertSublayer:mesh above:gradient];
    self.heroMeshLayer = mesh;

    CAGradientLayer *shine = [CAGradientLayer layer];
    shine.startPoint = CGPointMake(0.0, 0.0);
    shine.endPoint = CGPointMake(0.0, 1.0);
    shine.locations = @[@0.0, @0.12, @0.32];
    shine.opacity = 1;
    [heroCard.layer insertSublayer:shine above:mesh];
    self.heroShineLayer = shine;

    UIView *orbView = [[UIView alloc] init];
    orbView.translatesAutoresizingMaskIntoConstraints = NO;
    orbView.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.10];
    orbView.layer.cornerRadius = 78.0;
    orbView.userInteractionEnabled = NO;
    [heroCard addSubview:orbView];

    UIImageView *heroSymbolView = [[UIImageView alloc] init];
    heroSymbolView.translatesAutoresizingMaskIntoConstraints = NO;
    heroSymbolView.contentMode = UIViewContentModeScaleAspectFit;
    heroSymbolView.alpha = 0.18;
    heroSymbolView.image =
    [UIImage pp_symbolNamed:[self pp_sectionFilledIconName]
                  pointSize:76
                     weight:UIImageSymbolWeightBold
                      scale:UIImageSymbolScaleLarge
                    palette:@[UIColor.whiteColor]
               makeTemplate:YES];
    [heroCard addSubview:heroSymbolView];

    UILabel *eyebrowLabel = [[UILabel alloc] init];
    eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowLabel.font = PPFilterSheetBold(11.0);
    eyebrowLabel.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.76];
    eyebrowLabel.textAlignment = alignment;
    eyebrowLabel.text = PPFilterSheetL(@"RESULT FILTERS", @"فلاتر النتائج");
    [heroCard addSubview:eyebrowLabel];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = PPFilterSheetBold(30.0);
    titleLabel.textColor = UIColor.whiteColor;
    titleLabel.numberOfLines = 2;
    titleLabel.textAlignment = alignment;
    titleLabel.text = [self pp_sectionHeroTitle];
    [heroCard addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = PPFilterSheetMedium(13.0);
    subtitleLabel.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.84];
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.textAlignment = alignment;
    subtitleLabel.text = [self pp_sectionHeroSubtitle];
    [heroCard addSubview:subtitleLabel];

    UIStackView *metaStack = [[UIStackView alloc] init];
    metaStack.translatesAutoresizingMaskIntoConstraints = NO;
    metaStack.axis = UILayoutConstraintAxisHorizontal;
    metaStack.spacing = 8.0;
    metaStack.alignment = UIStackViewAlignmentCenter;
    metaStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [heroCard addSubview:metaStack];

    PPFilterCapsuleLabel *sectionLabel = [[PPFilterCapsuleLabel alloc] init];
    sectionLabel.font = PPFilterSheetBold(12.0);
    sectionLabel.textColor = UIColor.whiteColor;
    sectionLabel.textAlignment = NSTextAlignmentCenter;
    sectionLabel.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.14];
    sectionLabel.contentInsets = UIEdgeInsetsMake(7.0, 12.0, 7.0, 12.0);
    sectionLabel.layer.cornerRadius = 15.0;
    sectionLabel.clipsToBounds = YES;
    sectionLabel.text = [self pp_sectionTitle];
    [metaStack addArrangedSubview:sectionLabel];
    self.sectionCapsuleLabel = sectionLabel;

    PPFilterCapsuleLabel *activeLabel = [[PPFilterCapsuleLabel alloc] init];
    activeLabel.font = PPFilterSheetBold(12.0);
    activeLabel.textAlignment = NSTextAlignmentCenter;
    activeLabel.textColor = UIColor.whiteColor;
    activeLabel.backgroundColor = [accent colorWithAlphaComponent:0.92];
    activeLabel.contentInsets = UIEdgeInsetsMake(7.0, 12.0, 7.0, 12.0);
    activeLabel.layer.cornerRadius = 15.0;
    activeLabel.clipsToBounds = YES;
    activeLabel.hidden = YES;
    [metaStack addArrangedSubview:activeLabel];
    self.activeCountCapsuleLabel = activeLabel;

    PPFilterCapsuleLabel *resultLabel = [[PPFilterCapsuleLabel alloc] init];
    resultLabel.font = PPFilterSheetBold(12.0);
    resultLabel.textAlignment = NSTextAlignmentCenter;
    resultLabel.textColor = UIColor.whiteColor;
    resultLabel.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.14];
    resultLabel.contentInsets = UIEdgeInsetsMake(7.0, 12.0, 7.0, 12.0);
    resultLabel.layer.cornerRadius = 15.0;
    resultLabel.clipsToBounds = YES;
    [metaStack addArrangedSubview:resultLabel];
    self.resultCountCapsuleLabel = resultLabel;

    UILabel *statusLabel = [[UILabel alloc] init];
    statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    statusLabel.font = PPFilterSheetMedium(12.0);
    statusLabel.textAlignment = alignment;
    statusLabel.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.90];
    statusLabel.numberOfLines = 0;
    [heroCard addSubview:statusLabel];
    self.heroStatusLabel = statusLabel;

    [NSLayoutConstraint activateConstraints:@[
        [heroCard.topAnchor constraintEqualToAnchor:shadowView.topAnchor],
        [heroCard.leadingAnchor constraintEqualToAnchor:shadowView.leadingAnchor],
        [heroCard.trailingAnchor constraintEqualToAnchor:shadowView.trailingAnchor],
        [heroCard.bottomAnchor constraintEqualToAnchor:shadowView.bottomAnchor],

        [orbView.widthAnchor constraintEqualToConstant:156.0],
        [orbView.heightAnchor constraintEqualToConstant:156.0],
        [orbView.topAnchor constraintEqualToAnchor:heroCard.topAnchor constant:-30.0],
        [orbView.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:34.0],

        [heroSymbolView.widthAnchor constraintEqualToConstant:92.0],
        [heroSymbolView.heightAnchor constraintEqualToConstant:92.0],
        [heroSymbolView.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-18.0],
        [heroSymbolView.bottomAnchor constraintEqualToAnchor:heroCard.bottomAnchor constant:-20.0],

        [eyebrowLabel.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:20.0],
        [eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:heroCard.trailingAnchor constant:-20.0],
        [eyebrowLabel.topAnchor constraintEqualToAnchor:heroCard.topAnchor constant:18.0],

        [titleLabel.leadingAnchor constraintEqualToAnchor:eyebrowLabel.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-22.0],
        [titleLabel.topAnchor constraintEqualToAnchor:eyebrowLabel.bottomAnchor constant:10.0],

        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-22.0],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],

        [metaStack.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [metaStack.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:14.0],

        [statusLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [statusLabel.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-22.0],
        [statusLabel.topAnchor constraintEqualToAnchor:metaStack.bottomAnchor constant:12.0],
        [statusLabel.bottomAnchor constraintEqualToAnchor:heroCard.bottomAnchor constant:-20.0]
    ]];

    return shadowView;
}

- (UIView *)pp_emptyStateView
{
    UIColor *accent = PPFilterSheetAccentColor();
    NSTextAlignment alignment = Language.alignmentForCurrentLanguage;

    UIView *surfaceView = [[UIView alloc] init];
    surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    surfaceView.backgroundColor = AppBackgroundClrLigter;
    surfaceView.layer.cornerRadius = 28.0;
    surfaceView.layer.borderWidth = PPFilterSheetHairline();
    surfaceView.layer.borderColor = [accent colorWithAlphaComponent:0.10].CGColor;
    if (@available(iOS 13.0, *)) {
        surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIView *iconChipView = [[UIView alloc] init];
    iconChipView.translatesAutoresizingMaskIntoConstraints = NO;
    iconChipView.backgroundColor = [accent colorWithAlphaComponent:0.12];
    iconChipView.layer.cornerRadius = 24.0;
    [surfaceView addSubview:iconChipView];

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.image =
    [UIImage pp_symbolNamed:@"line.3.horizontal.decrease.circle"
                  pointSize:22
                     weight:UIImageSymbolWeightSemibold
                      scale:UIImageSymbolScaleMedium
                    palette:@[accent]
               makeTemplate:YES];
    iconView.tintColor = accent;
    [iconChipView addSubview:iconView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = PPFilterSheetBold(18.0);
    titleLabel.textAlignment = alignment;
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.text = PPFilterSheetL(@"No extra filters yet", @"لا توجد فلاتر إضافية حالياً");
    [surfaceView addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = PPFilterSheetMedium(13.0);
    subtitleLabel.textAlignment = alignment;
    subtitleLabel.textColor = UIColor.secondaryLabelColor;
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.text = PPFilterSheetL(@"This section is already showing its default results.", @"هذا القسم يعرض نتائجه الافتراضية بالفعل.");
    [surfaceView addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [iconChipView.topAnchor constraintEqualToAnchor:surfaceView.topAnchor constant:18.0],
        [iconChipView.leadingAnchor constraintEqualToAnchor:surfaceView.leadingAnchor constant:18.0],
        [iconChipView.widthAnchor constraintEqualToConstant:48.0],
        [iconChipView.heightAnchor constraintEqualToConstant:48.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconChipView.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconChipView.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:24.0],
        [iconView.heightAnchor constraintEqualToConstant:24.0],

        [titleLabel.leadingAnchor constraintEqualToAnchor:iconChipView.trailingAnchor constant:14.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:surfaceView.trailingAnchor constant:-18.0],
        [titleLabel.topAnchor constraintEqualToAnchor:surfaceView.topAnchor constant:18.0],

        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6.0],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:surfaceView.bottomAnchor constant:-18.0]
    ]];

    return surfaceView;
}

- (UIView *)pp_buildFooterShell
{
    UIView *shellView = [[UIView alloc] init];
    shellView.translatesAutoresizingMaskIntoConstraints = NO;
    shellView.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.96];
    shellView.layer.cornerRadius = 28.0;
    shellView.layer.borderWidth = PPFilterSheetHairline();
    shellView.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.12].CGColor;
    shellView.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:1.0].CGColor;
    shellView.layer.shadowOpacity = 0.10f;
    shellView.layer.shadowRadius = 24.0f;
    shellView.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    if (@available(iOS 13.0, *)) {
        shellView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UILabel *summaryLabel = [[UILabel alloc] init];
    summaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    summaryLabel.font = PPFilterSheetMedium(13.0);
    summaryLabel.textAlignment = Language.alignmentForCurrentLanguage;
    summaryLabel.textColor = UIColor.secondaryLabelColor;
    summaryLabel.numberOfLines = 0;
    [shellView addSubview:summaryLabel];
    self.footerSummaryLabel = summaryLabel;

    UIStackView *buttonStack = [[UIStackView alloc] init];
    buttonStack.translatesAutoresizingMaskIntoConstraints = NO;
    buttonStack.axis = UILayoutConstraintAxisHorizontal;
    buttonStack.spacing = 10.0;
    buttonStack.alignment = UIStackViewAlignmentFill;
    buttonStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [shellView addSubview:buttonStack];

    UIButton *resetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    resetButton.translatesAutoresizingMaskIntoConstraints = NO;
    [resetButton addTarget:self action:@selector(pp_resetTapped) forControlEvents:UIControlEventTouchUpInside];
    [resetButton.heightAnchor constraintEqualToConstant:54.0].active = YES;
    [resetButton.widthAnchor constraintEqualToConstant:118.0].active = YES;
    [buttonStack addArrangedSubview:resetButton];
    self.resetButton = resetButton;

    UIButton *applyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    applyButton.translatesAutoresizingMaskIntoConstraints = NO;
    [applyButton addTarget:self action:@selector(pp_applyTapped) forControlEvents:UIControlEventTouchUpInside];
    [applyButton.heightAnchor constraintEqualToConstant:54.0].active = YES;
    [buttonStack addArrangedSubview:applyButton];
    self.applyButton = applyButton;

    [NSLayoutConstraint activateConstraints:@[
        [summaryLabel.topAnchor constraintEqualToAnchor:shellView.topAnchor constant:16.0],
        [summaryLabel.leadingAnchor constraintEqualToAnchor:shellView.leadingAnchor constant:16.0],
        [summaryLabel.trailingAnchor constraintEqualToAnchor:shellView.trailingAnchor constant:-16.0],

        [buttonStack.topAnchor constraintEqualToAnchor:summaryLabel.bottomAnchor constant:0.0],
        [buttonStack.leadingAnchor constraintEqualToAnchor:shellView.leadingAnchor constant:16.0],
        [buttonStack.trailingAnchor constraintEqualToAnchor:shellView.trailingAnchor constant:-16.0],
        [buttonStack.bottomAnchor constraintEqualToAnchor:shellView.bottomAnchor constant:-16.0]
    ]];

    return shellView;
}

#pragma mark - Sections & copy

- (NSString *)pp_sectionTitle
{
    switch (self.currentSection) {
        case PPDataSectionAccessories: return kLang(@"Accessories");
        case PPDataSectionServices:    return kLang(@"services");
        case PPDataSectionFood:        return kLang(@"Food");
        case PPDataSectionAds:
        default:                       return kLang(@"Ads");
    }
}

- (NSString *)pp_sectionHeroTitle
{
    switch (self.currentSection) {
        case PPDataSectionAccessories:
            return PPFilterSheetL(@"Refine accessories results", @"عدّل نتائج الإكسسوارات");
        case PPDataSectionFood:
            return PPFilterSheetL(@"Refine food results", @"عدّل نتائج الطعام");
        case PPDataSectionServices:
            return PPFilterSheetL(@"Refine service results", @"عدّل نتائج الخدمات");
        case PPDataSectionAds:
        default:
            return PPFilterSheetL(@"Refine ad results", @"عدّل نتائج الإعلانات");
    }
}

- (NSString *)pp_sectionHeroSubtitle
{
    switch (self.currentSection) {
        case PPDataSectionAccessories:
            return PPFilterSheetL(@"Adjust condition, price, and sort so the list opens on the items that fit your intent first.", @"عدّل الحالة والسعر والترتيب حتى تبدأ القائمة بالعناصر الأنسب لك أولاً.");
        case PPDataSectionFood:
            return PPFilterSheetL(@"Choose offers, price range, and order before refreshing the food feed.", @"اختر العروض ونطاق السعر والترتيب قبل تحديث قائمة الطعام.");
        case PPDataSectionServices:
            return PPFilterSheetL(@"Narrow the service feed by type, price range, and priority order.", @"ضيّق قائمة الخدمات حسب النوع ونطاق السعر وأولوية الترتيب.");
        case PPDataSectionAds:
        default:
            return PPFilterSheetL(@"Set gender, price range, and sorting to control which listings surface first.", @"حدّد الجنس ونطاق السعر والترتيب للتحكم في الإعلانات التي تظهر أولاً.");
    }
}

- (NSString *)pp_sectionFilledIconName
{
    switch (self.currentSection) {
        case PPDataSectionAccessories: return @"bag.fill";
        case PPDataSectionFood:        return @"cart.fill";
        case PPDataSectionServices:    return @"cross.case.fill";
        case PPDataSectionAds:
        default:                       return @"megaphone.fill";
    }
}

- (NSString *)pp_activeBadgeTextForCount:(NSInteger)count
{
    return [NSString stringWithFormat:@"%ld %@", (long)count, PPFilterSheetL(@"active", @"مفعلة")];
}

- (NSString *)pp_resultBadgeTextForCount:(NSInteger)count
{
    NSString *noun = PPFilterSheetL(@"results", @"نتيجة");
    return [NSString stringWithFormat:@"%ld %@", (long)count, noun];
}

- (NSInteger)pp_previewResultCount
{
    if (self.resultCountProvider) {
        return MAX(0, self.resultCountProvider(self.filterState));
    }
    return 0;
}

- (NSString *)pp_activeSummaryTextForCount:(NSInteger)count
{
    if (self.filterState.groups.count == 0) {
        return PPFilterSheetL(@"This section does not have extra filters right now.", @"هذا القسم لا يحتوي على فلاتر إضافية حالياً.");
    }
    if (count <= 0) {
        return PPFilterSheetL(@"Default results are selected.", @"تم تحديد النتائج الافتراضية.");
    }
    return [NSString stringWithFormat:PPFilterSheetL(@"%ld filters are ready to apply.", @"%ld فلاتر جاهزة للتطبيق."), (long)count];
}

#pragma mark - Actions

- (void)pp_pillTapped:(PPFilterOptionPill *)pill
{
    PPFilterGroup *group = [self.filterState groupForID:pill.groupID];
    if (!group) {
        return;
    }

    group.selectedValue = pill.optionValue;
    [PPFunc triggerLightHaptic];
    [self pp_refreshGroupInterfaceForGroupID:pill.groupID animated:YES emphasizePill:pill];
    [self pp_updateActiveStateAnimated:YES];
}

- (void)pp_resetTapped
{
    if (self.filterState.activeFilterCount == 0) {
        return;
    }

    [self.filterState resetAll];
    [PPFunc triggerMediumHaptic];

    for (PPFilterGroup *group in self.filterState.groups) {
        [self pp_refreshGroupInterfaceForGroupID:group.filterID animated:YES emphasizePill:nil];
    }
    [self pp_updateActiveStateAnimated:YES];
}

- (void)pp_applyTapped
{
    if (self.onApply) {
        self.onApply(self.filterState);
    }
    [PPFunc triggerLightHaptic];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Refresh

- (void)pp_refreshGroupInterfaceForGroupID:(NSString *)groupID
                                  animated:(BOOL)animated
                             emphasizePill:(nullable PPFilterOptionPill *)emphasizePill
{
    PPFilterGroup *group = [self.filterState groupForID:groupID];
    PPFilterSectionView *sectionView = self.sectionViewsByGroupID[groupID];
    NSArray<PPFilterOptionPill *> *pills = self.pillsByGroupID[groupID];
    UIColor *accent = PPFilterSheetAccentColor();

    if (!group || !sectionView || pills.count == 0) {
        return;
    }

    void (^updates)(void) = ^{
        [sectionView pp_applyGroupStateWithAccentColor:accent];
    };

    if (animated) {
        [UIView animateWithDuration:0.22
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:updates
                         completion:nil];
    } else {
        updates();
    }

    if (emphasizePill && !UIAccessibilityIsReduceMotionEnabled()) {
        emphasizePill.transform = CGAffineTransformMakeScale(0.94, 0.94);
        [UIView animateWithDuration:0.32
                              delay:0.0
             usingSpringWithDamping:0.70
              initialSpringVelocity:0.35
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            emphasizePill.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

- (void)pp_updateActiveStateAnimated:(BOOL)animated
{
    NSInteger count = self.filterState.activeFilterCount;
    NSInteger resultCount = [self pp_previewResultCount];
    NSString *summaryText = [self pp_activeSummaryTextForCount:count];
    BOOL showCount = count > 0;

    void (^updates)(void) = ^{
        self.heroStatusLabel.text = summaryText;
        self.footerSummaryLabel.text = summaryText;
        self.activeCountCapsuleLabel.hidden = !showCount;
        self.activeCountCapsuleLabel.text = showCount ? [self pp_activeBadgeTextForCount:count] : @"";
        self.resultCountCapsuleLabel.text = [self pp_resultBadgeTextForCount:resultCount];
        self.resultCountCapsuleLabel.hidden = NO;
        [self pp_applyFooterButtonStylesForActiveCount:count];
    };

    if (animated) {
        [UIView transitionWithView:self.heroCardView
                          duration:0.22
                           options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent
                        animations:updates
                        completion:nil];
    } else {
        updates();
    }
}

- (void)pp_applyFooterButtonStylesForActiveCount:(NSInteger)count
{
    UIColor *accent = PPFilterSheetAccentColor();
    BOOL resetEnabled = count > 0;
    UIImage *resetImage =
    [UIImage pp_symbolNamed:@"arrow.counterclockwise"
                  pointSize:15
                     weight:UIImageSymbolWeightSemibold
                      scale:UIImageSymbolScaleSmall
                    palette:@[resetEnabled ? accent : UIColor.tertiaryLabelColor]
               makeTemplate:YES];
    UIImage *applyImage =
    [UIImage pp_symbolNamed:@"checkmark.circle.fill"
                  pointSize:16
                     weight:UIImageSymbolWeightBold
                      scale:UIImageSymbolScaleSmall
                    palette:@[UIColor.whiteColor]
               makeTemplate:YES];

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *resetConfiguration = [UIButtonConfiguration filledButtonConfiguration];
        resetConfiguration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        resetConfiguration.title = kLang(@"Reset");
        resetConfiguration.image = resetImage;
        resetConfiguration.imagePadding = 6.0;
        resetConfiguration.contentInsets = NSDirectionalEdgeInsetsMake(15.0, 16.0, 15.0, 16.0);

        UIBackgroundConfiguration *resetBackground = [UIBackgroundConfiguration clearConfiguration];
        resetBackground.cornerRadius = 27.0;
        resetBackground.backgroundColor = resetEnabled
            ? [accent colorWithAlphaComponent:0.12]
            : UIColor.tertiarySystemFillColor;
        resetBackground.strokeColor = resetEnabled
            ? [accent colorWithAlphaComponent:0.18]
            : [UIColor.separatorColor colorWithAlphaComponent:0.12];
        resetBackground.strokeWidth = 1.0;
        resetConfiguration.background = resetBackground;
        resetConfiguration.baseBackgroundColor = resetBackground.backgroundColor;
        resetConfiguration.baseForegroundColor = resetEnabled ? accent : UIColor.tertiaryLabelColor;
        resetConfiguration.titleTextAttributesTransformer =
        ^NSDictionary<NSAttributedStringKey,id> * _Nonnull(NSDictionary<NSAttributedStringKey,id> * _Nonnull incoming) {
            NSMutableDictionary *attributes = [incoming mutableCopy];
            attributes[NSFontAttributeName] = PPFilterSheetBold(15.0);
            return attributes;
        };
        self.resetButton.configuration = resetConfiguration;

        UIButtonConfiguration *applyConfiguration = [UIButtonConfiguration filledButtonConfiguration];
        applyConfiguration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        applyConfiguration.title = kLang(@"Done");
        applyConfiguration.image = applyImage;
        applyConfiguration.imagePadding = 6.0;
        applyConfiguration.contentInsets = NSDirectionalEdgeInsetsMake(15.0, 18.0, 15.0, 18.0);

        UIBackgroundConfiguration *applyBackground = [UIBackgroundConfiguration clearConfiguration];
        applyBackground.cornerRadius = 27.0;
        applyBackground.backgroundColor = accent;
        applyConfiguration.background = applyBackground;
        applyConfiguration.baseBackgroundColor = accent;
        applyConfiguration.baseForegroundColor = UIColor.whiteColor;
        applyConfiguration.titleTextAttributesTransformer =
        ^NSDictionary<NSAttributedStringKey,id> * _Nonnull(NSDictionary<NSAttributedStringKey,id> * _Nonnull incoming) {
            NSMutableDictionary *attributes = [incoming mutableCopy];
            attributes[NSFontAttributeName] = PPFilterSheetBold(15.0);
            return attributes;
        };
        self.applyButton.configuration = applyConfiguration;
    } else {
        [self pp_applyLegacyFooterStyleToButton:self.resetButton
                                          title:kLang(@"Reset")
                                          image:resetImage
                                      tintColor:(resetEnabled ? accent : UIColor.tertiaryLabelColor)
                                backgroundColor:(resetEnabled ? [accent colorWithAlphaComponent:0.12] : UIColor.tertiarySystemFillColor)
                                    borderColor:(resetEnabled ? [accent colorWithAlphaComponent:0.18] : [UIColor.separatorColor colorWithAlphaComponent:0.12])
                                      textColor:(resetEnabled ? accent : UIColor.tertiaryLabelColor)];

        [self pp_applyLegacyFooterStyleToButton:self.applyButton
                                          title:kLang(@"Done")
                                          image:applyImage
                                      tintColor:UIColor.whiteColor
                                backgroundColor:accent
                                    borderColor:UIColor.clearColor
                                      textColor:UIColor.whiteColor];
    }

    self.resetButton.enabled = resetEnabled;
    self.resetButton.alpha = resetEnabled ? 1.0 : 0.78;
}

- (void)pp_applyLegacyFooterStyleToButton:(UIButton *)button
                                    title:(NSString *)title
                                    image:(nullable UIImage *)image
                                tintColor:(UIColor *)tintColor
                          backgroundColor:(UIColor *)backgroundColor
                              borderColor:(UIColor *)borderColor
                                textColor:(UIColor *)textColor
{
    if (@available(iOS 15.0, *)) {
        button.configuration = nil;
    }
    button.backgroundColor = backgroundColor;
    button.layer.cornerRadius = 27.0;
    button.layer.borderWidth = CGColorGetAlpha(borderColor.CGColor) <= 0.001 ? 0.0 : 1.0;
    button.layer.borderColor = borderColor.CGColor;
    button.contentEdgeInsets = UIEdgeInsetsMake(15.0, 18.0, 15.0, 18.0);
    button.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    button.titleLabel.font = PPFilterSheetBold(15.0);
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:textColor forState:UIControlStateNormal];
    [button setImage:image forState:UIControlStateNormal];
    button.tintColor = tintColor;
    button.titleEdgeInsets = image ? UIEdgeInsetsMake(0.0, 6.0, 0.0, -6.0) : UIEdgeInsetsZero;
    button.imageEdgeInsets = UIEdgeInsetsZero;
    button.clipsToBounds = YES;
}

#pragma mark - Motion

- (void)pp_performEntranceAnimationIfNeeded
{
    if (self.didAnimateEntrance || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    self.didAnimateEntrance = YES;
    [self pp_prepareEntranceStateIfNeeded];

    NSTimeInterval delay = 0.0;
    for (UIView *view in self.entranceViews) {
        [UIView animateWithDuration:0.72
                              delay:delay
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.18
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];

        delay += 0.055;
    }
}

- (void)pp_prepareEntranceStateIfNeeded
{
    if (self.didPrepareEntranceState || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    self.didPrepareEntranceState = YES;
    for (UIView *view in self.entranceViews) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 18.0);
    }
}

#pragma mark - Gradient colors

- (void)pp_updateCanvasColors
{
    UIColor *accent = PPFilterSheetAccentColor();
    BOOL isDark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);

    UIColor *topColor = isDark
        ? [UIColor colorWithRed:0.07 green:0.07 blue:0.09 alpha:1.0]
        : [UIColor colorWithRed:0.98 green:0.98 blue:0.99 alpha:1.0];
    UIColor *bottomColor = isDark
        ? [UIColor colorWithRed:0.05 green:0.05 blue:0.07 alpha:1.0]
        : [UIColor colorWithRed:0.94 green:0.95 blue:0.98 alpha:1.0];

    self.canvasGradientLayer.colors = @[
        (__bridge id)topColor.CGColor,
        (__bridge id)[PPFilterSheetBlendColor(topColor, accent, isDark ? 0.08 : 0.05) CGColor],
        (__bridge id)bottomColor.CGColor
    ];

    self.canvasGlowLayer.colors = @[
        (__bridge id)[accent colorWithAlphaComponent:(isDark ? 0.24 : 0.16)].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:(isDark ? 0.10 : 0.06)].CGColor,
        (__bridge id)UIColor.clearColor.CGColor
    ];
}

- (void)pp_updateHeroGradientColors
{
    UIColor *accent = PPFilterSheetAccentColor();
    BOOL isDark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);

    UIColor *topColor = isDark
        ? [UIColor colorWithRed:0.12 green:0.09 blue:0.10 alpha:1.0]
        : [UIColor colorWithRed:0.35 green:0.21 blue:0.16 alpha:1.0];
    UIColor *midColor = isDark
        ? [UIColor colorWithRed:0.19 green:0.13 blue:0.12 alpha:1.0]
        : [UIColor colorWithRed:0.64 green:0.45 blue:0.30 alpha:1.0];
    UIColor *bottomColor = isDark
        ? [UIColor colorWithRed:0.25 green:0.16 blue:0.13 alpha:1.0]
        : [UIColor colorWithRed:0.87 green:0.70 blue:0.52 alpha:1.0];

    self.heroGradientLayer.colors = @[
        (__bridge id)[PPFilterSheetBlendColor(topColor, accent, 0.12) CGColor],
        (__bridge id)[PPFilterSheetBlendColor(midColor, accent, 0.22) CGColor],
        (__bridge id)[PPFilterSheetBlendColor(bottomColor, accent, 0.12) CGColor]
    ];

    self.heroMeshLayer.colors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:(isDark ? 0.16 : 0.24)].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:(isDark ? 0.24 : 0.18)].CGColor,
        (__bridge id)UIColor.clearColor.CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:(isDark ? 0.04 : 0.08)].CGColor
    ];

    self.heroShineLayer.colors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.26].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.06].CGColor,
        (__bridge id)UIColor.clearColor.CGColor
    ];
}

@end
