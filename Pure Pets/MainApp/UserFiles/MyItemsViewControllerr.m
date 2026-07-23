//
//  MyItemsViewControllerr.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 31/05/2025.
//

#import "MyItemsViewController.h"
#import "PetAdManager.h"
#import "PetAccessoryManager.h"
#import "AdoptPetManager.h"
#import "PetAd.h"
#import "PetAccessory.h"
#import "AdoptPetModel.h"
#import "AppClasses.h"
#import "GM.h"
#import "PPImageLoaderManager.h"
#import "UserManager.h"
#import "PPUniversalCell.h"
#import "AddAdoptPetViewController.h"
#import "CitiesManager.h"
#import "AppManager.h"
#import "PPAdSharingHelper.h"
#import "AddNewAd.h"
#import "AddNewAccessory.h"
#import "AccessViewerVC.h"
#import "AdoptPetDetailsViewController.h"

static CGFloat const PPMyItemsColumnHeight = 332.0;
static CGFloat const PPMyItemsGridInteritemSpacing = 10.0;
static CGFloat const PPMyItemsGridVerticalSpacing = 12.0;
static CGFloat const PPMyItemsMyAdsHorizontalInset = 12.0;
static NSInteger const PPMyItemsSkeletonCount = 6;

typedef NS_ENUM(NSUInteger, PPMyItemsContentState) {
    PPMyItemsContentStateLoading,
    PPMyItemsContentStateContent,
    PPMyItemsContentStateEmpty,
    PPMyItemsContentStateError,
    PPMyItemsContentStateSignedOut
};

static UIColor *PPMyItemsDynamicColor(UIColor *lightColor, UIColor *darkColor)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traits) {
            return traits.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
        }];
    }
    return lightColor;
}

static UIFont *PPMyItemsScaledFont(UIFont *font, UIFontTextStyle textStyle)
{
    UIFont *resolvedFont = font ?: [UIFont preferredFontForTextStyle:textStyle];
    if (@available(iOS 11.0, *)) {
        return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:resolvedFont];
    }
    return resolvedFont;
}

static UIColor *PPMyItemsAccentColor(void)
{
    return AppPrimaryClr ?: UIColor.systemPinkColor;
}

static UIColor *PPMyItemsHeroSurfaceColor(void)
{
    return PPMyItemsDynamicColor([UIColor colorWithWhite:1.0 alpha:0.82],
                                 [UIColor colorWithWhite:0.10 alpha:0.90]);
}

static UIColor *PPMyItemsHeroStrokeColor(void)
{
    return PPMyItemsDynamicColor([UIColor colorWithWhite:0.0 alpha:0.055],
                                 [UIColor colorWithWhite:1.0 alpha:0.10]);
}

static UIColor *PPMyItemsPillSurfaceColor(void)
{
    return PPMyItemsDynamicColor([UIColor colorWithWhite:1.0 alpha:0.62],
                                 [UIColor colorWithWhite:1.0 alpha:0.07]);
}

#pragma mark - Premium State View

@interface PPMyItemsStateView : UIView
@property (nonatomic, strong) UIView *iconPlate;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *actionButton;
- (void)configureWithSymbol:(NSString *)symbol
                      title:(NSString *)title
                   subtitle:(NSString *)subtitle
                actionTitle:(nullable NSString *)actionTitle
                     target:(nullable id)target
                     action:(nullable SEL)action;
@end

@implementation PPMyItemsStateView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.hidden = YES;

    _iconPlate = [UIView new];
    _iconPlate.translatesAutoresizingMaskIntoConstraints = NO;
    _iconPlate.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.09];
    _iconPlate.layer.cornerRadius = 29.0;
    _iconPlate.layer.borderWidth = 0.75;
    [_iconPlate pp_setBorderColor:[AppPrimaryClr colorWithAlphaComponent:0.13]];
    PPApplyContinuousCorners(_iconPlate, 29.0);

    _iconView = [UIImageView new];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    _iconView.tintColor = AppPrimaryClr;
    [_iconPlate addSubview:_iconView];

    _titleLabel = [UILabel new];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = PPMyItemsScaledFont([GM boldFontWithSize:22.0], UIFontTextStyleTitle2);
    _titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.numberOfLines = 0;
    _titleLabel.adjustsFontForContentSizeCategory = YES;

    _subtitleLabel = [UILabel new];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = PPMyItemsScaledFont([GM MidFontWithSize:15.0], UIFontTextStyleBody);
    _subtitleLabel.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    _subtitleLabel.textAlignment = NSTextAlignmentCenter;
    _subtitleLabel.numberOfLines = 0;
    _subtitleLabel.adjustsFontForContentSizeCategory = YES;

    _actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    _actionButton.titleLabel.font =
        PPMyItemsScaledFont([GM boldFontWithSize:15.0], UIFontTextStyleHeadline);
    _actionButton.tintColor = UIColor.whiteColor;
    _actionButton.backgroundColor = AppPrimaryClr;
    _actionButton.layer.cornerRadius = 22.0;
    PPApplyContinuousCorners(_actionButton, 22.0);
    [_actionButton addTarget:self
                      action:@selector(pp_touchDown)
            forControlEvents:UIControlEventTouchDown];
    [_actionButton addTarget:self
                      action:@selector(pp_touchUp)
            forControlEvents:UIControlEventTouchUpInside |
                             UIControlEventTouchUpOutside |
                             UIControlEventTouchCancel];

    UIStackView *textStack =
        [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel, _subtitleLabel]];
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.alignment = UIStackViewAlignmentFill;
    textStack.spacing = 7.0;

    UIStackView *stack =
        [[UIStackView alloc] initWithArrangedSubviews:@[_iconPlate, textStack, _actionButton]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = PPSpaceBase;
    [stack setCustomSpacing:PPSpaceXL afterView:_iconPlate];
    [stack setCustomSpacing:PPSpaceXL afterView:textStack];
    [self addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [_iconPlate.widthAnchor constraintEqualToConstant:58.0],
        [_iconPlate.heightAnchor constraintEqualToConstant:58.0],
        [_iconView.centerXAnchor constraintEqualToAnchor:_iconPlate.centerXAnchor],
        [_iconView.centerYAnchor constraintEqualToAnchor:_iconPlate.centerYAnchor],
        [_iconView.widthAnchor constraintEqualToConstant:25.0],
        [_iconView.heightAnchor constraintEqualToConstant:25.0],
        [_actionButton.heightAnchor constraintEqualToConstant:44.0],
        [_actionButton.widthAnchor constraintGreaterThanOrEqualToConstant:132.0],
        [textStack.widthAnchor constraintLessThanOrEqualToAnchor:self.widthAnchor constant:-48.0],
        [stack.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:-8.0],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.leadingAnchor constant:PPScreenMargin],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-PPScreenMargin]
    ]];

    return self;
}

- (void)configureWithSymbol:(NSString *)symbol
                      title:(NSString *)title
                   subtitle:(NSString *)subtitle
                actionTitle:(NSString *)actionTitle
                     target:(id)target
                     action:(SEL)action
{
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:24.0
                                                         weight:UIImageSymbolWeightSemibold
                                                          scale:UIImageSymbolScaleMedium];
    self.iconView.image = [UIImage systemImageNamed:symbol withConfiguration:configuration];
    self.titleLabel.text = title;
    self.subtitleLabel.text = subtitle;
    [self.actionButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    BOOL showsAction = actionTitle.length > 0 && target && action;
    self.actionButton.hidden = !showsAction;
    if (showsAction) {
        [self.actionButton setTitle:actionTitle forState:UIControlStateNormal];
        [self.actionButton addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
        self.actionButton.accessibilityLabel = actionTitle;
    }
}

- (void)pp_touchDown
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    [UIView animateWithDuration:0.09
                     animations:^{
        self.actionButton.transform = CGAffineTransformMakeScale(0.965, 0.965);
    }];
}

- (void)pp_touchUp
{
    [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0.0 : 0.20
                          delay:0.0
         usingSpringWithDamping:0.84
          initialSpringVelocity:0.3
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.actionButton.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end

#pragma mark - Skeleton Cell

@interface PPMyItemsSkeletonCell : UICollectionViewCell
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *imagePlaceholder;
@property (nonatomic, strong) NSArray<UIView *> *pulseViews;
- (void)startAnimating;
- (void)stopAnimating;
@end

@implementation PPMyItemsSkeletonCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    _surfaceView = [UIView new];
    _surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _surfaceView.backgroundColor =
        PPMyItemsDynamicColor([UIColor colorWithWhite:1.0 alpha:0.76],
                              [UIColor colorWithWhite:0.12 alpha:0.84]);
    _surfaceView.layer.cornerRadius = 26.0;
    _surfaceView.layer.borderWidth = 0.75;
    [_surfaceView pp_setBorderColor:
        PPMyItemsDynamicColor([UIColor colorWithWhite:0.90 alpha:0.88],
                              [UIColor colorWithWhite:1.0 alpha:0.08])];
    PPApplyContinuousCorners(_surfaceView, 26.0);
    [self.contentView addSubview:_surfaceView];

    UIColor *placeholderColor =
        PPMyItemsDynamicColor([UIColor colorWithWhite:0.88 alpha:0.88],
                              [UIColor colorWithWhite:0.22 alpha:0.94]);

    _imagePlaceholder = [UIView new];
    _imagePlaceholder.translatesAutoresizingMaskIntoConstraints = NO;
    _imagePlaceholder.backgroundColor = placeholderColor;
    _imagePlaceholder.layer.cornerRadius = 20.0;
    PPApplyContinuousCorners(_imagePlaceholder, 20.0);
    [_surfaceView addSubview:_imagePlaceholder];

    UIView *titleLine = [UIView new];
    UIView *metadataLine = [UIView new];
    UIView *actionLine = [UIView new];
    for (UIView *line in @[titleLine, metadataLine, actionLine]) {
        line.translatesAutoresizingMaskIntoConstraints = NO;
        line.backgroundColor = placeholderColor;
        line.layer.cornerRadius = 7.0;
        [_surfaceView addSubview:line];
    }
    actionLine.layer.cornerRadius = 16.0;
    self.pulseViews = @[_imagePlaceholder, titleLine, metadataLine, actionLine];

    [NSLayoutConstraint activateConstraints:@[
        [_surfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:3.0],
        [_surfaceView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:2.0],
        [_surfaceView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-2.0],
        [_surfaceView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-3.0],
        [_imagePlaceholder.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:12.0],
        [_imagePlaceholder.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:12.0],
        [_imagePlaceholder.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-12.0],
        [_imagePlaceholder.heightAnchor constraintEqualToAnchor:_surfaceView.heightAnchor multiplier:0.57],
        [titleLine.topAnchor constraintEqualToAnchor:_imagePlaceholder.bottomAnchor constant:14.0],
        [titleLine.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:16.0],
        [titleLine.widthAnchor constraintEqualToAnchor:_surfaceView.widthAnchor multiplier:0.62],
        [titleLine.heightAnchor constraintEqualToConstant:14.0],
        [metadataLine.topAnchor constraintEqualToAnchor:titleLine.bottomAnchor constant:9.0],
        [metadataLine.leadingAnchor constraintEqualToAnchor:titleLine.leadingAnchor],
        [metadataLine.widthAnchor constraintEqualToAnchor:_surfaceView.widthAnchor multiplier:0.42],
        [metadataLine.heightAnchor constraintEqualToConstant:11.0],
        [actionLine.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:14.0],
        [actionLine.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-14.0],
        [actionLine.bottomAnchor constraintEqualToAnchor:_surfaceView.bottomAnchor constant:-14.0],
        [actionLine.heightAnchor constraintEqualToConstant:34.0]
    ]];

    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [self stopAnimating];
    self.contentView.alpha = 1.0;
    self.contentView.transform = CGAffineTransformIdentity;
}

- (void)startAnimating
{
    [self stopAnimating];
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    for (NSUInteger index = 0; index < self.pulseViews.count; index++) {
        UIView *view = self.pulseViews[index];
        [UIView animateWithDuration:0.92
                              delay:0.08 * (NSTimeInterval)index
                            options:UIViewAnimationOptionAutoreverse |
                                    UIViewAnimationOptionRepeat |
                                    UIViewAnimationOptionAllowUserInteraction |
                                    UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            view.alpha = 0.52;
        } completion:nil];
    }
}

- (void)stopAnimating
{
    for (UIView *view in self.pulseViews) {
        [view.layer removeAllAnimations];
        view.alpha = 1.0;
    }
}

@end

#pragma mark - My Items

@interface MyItemsViewController () <
    UICollectionViewDataSource,
    UICollectionViewDelegate,
    PPUniversalCellDelegate,
    AddNewAdDelegate
>

@property (nonatomic, assign) MyItemsMode mode;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray<PPUniversalCellViewModel *> *items;
@property (nonatomic, strong) NSArray *rawItems;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) PPMyItemsStateView *stateView;

@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIView *heroSurfaceView;
@property (nonatomic, strong) UIView *heroAuraView;
@property (nonatomic, strong) UIView *accentRail;
@property (nonatomic, strong) UIView *iconPlate;
@property (nonatomic, strong) UIImageView *modeIconView;
@property (nonatomic, strong) UILabel *heroEyebrow;
@property (nonatomic, strong) UILabel *heroTitle;
@property (nonatomic, strong) UILabel *heroSubtitle;
@property (nonatomic, strong) UIView *statusPillView;
@property (nonatomic, strong) UIView *statusDotView;
@property (nonatomic, strong) UILabel *resultLabel;

@property (nonatomic, assign) PPMyItemsContentState contentState;
@property (nonatomic, strong, nullable) NSError *contentError;
@property (nonatomic, assign) NSUInteger requestGeneration;
@property (nonatomic, assign) BOOL showsAllFavoriteCategories;
@property (nonatomic, assign) BOOL hasLoadedOnce;
@property (nonatomic, assign) BOOL entrancePrepared;
@property (nonatomic, assign) BOOL entranceCompleted;
@property (nonatomic, strong) NSMutableSet<NSIndexPath *> *pendingEntranceIndexPaths;

@end

@implementation MyItemsViewController

#pragma mark - Initialization

- (instancetype)initWithMode:(MyItemsMode)mode
{
    self = [super init];
    if (self) {
        _mode = mode;
        _viewType = ViewTypeAds;
        _showsAllFavoriteCategories = mode == MyItemsModeFavorites;
        _items = @[];
        _rawItems = @[];
        _pendingEntranceIndexPaths = [NSMutableSet set];
    }
    return self;
}

- (instancetype)initWithMode:(MyItemsMode)mode viewType:(ViewType)viewType
{
    self = [self initWithMode:mode];
    if (self) {
        if (viewType == ViewTypeAccess || viewType == ViewTypeFood) {
            _viewType = ViewTypeAds;
        } else {
            _viewType = viewType;
        }
        _showsAllFavoriteCategories = NO;
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self setupBaseUI];
    [self setupHeader];
    [self setupSegmentedControl];
    [self setupCollectionView];
    [self setupStateView];
    [self prepareEntranceStateIfNeeded];
    [self fetchDataForCurrentSegment];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    NSString *title =
        self.mode == MyItemsModeMyAds ? kLang(@"myadsTitle") : kLang(@"myfavTitle");
    BOOL isNavigationRoot =
        self.navigationController.viewControllers.firstObject == self;
    BOOL shouldHideBackButton =
        isNavigationRoot || self.hidesBackButtonWhenOpenedFromHomeDeck;
    self.navigationItem.hidesBackButton = shouldHideBackButton;
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto
                     button:nil
                      title:title
                   showBack:!shouldHideBackButton];

    if (self.hasLoadedOnce && self.contentState != PPMyItemsContentStateLoading) {
        [self fetchDataForCurrentSegment];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self runEntranceIfNeeded];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
        if ([PPUniversalCell pp_isUniversalCell:cell]) {
            [(PPUniversalCell *)cell stopMediaPlayback];
        }
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];

    BOOL contentSizeChanged =
        previousTraitCollection &&
        ![previousTraitCollection.preferredContentSizeCategory
            isEqualToString:self.traitCollection.preferredContentSizeCategory];
    if (contentSizeChanged) {
        [self.collectionView.collectionViewLayout invalidateLayout];
    }
}

#pragma mark - UI Setup

- (void)setupBaseUI
{
    self.view.backgroundColor = AppBackgroundClr;
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
}

- (CGFloat)pp_horizontalContentInset
{
    return self.mode == MyItemsModeMyAds
        ? PPMyItemsMyAdsHorizontalInset
        : PPScreenMargin;
}

- (void)setupHeader
{
    NSTextAlignment alignment = [Language alignmentForCurrentLanguage];
    CGFloat horizontalInset = [self pp_horizontalContentInset];

    UIView *header = [UIView new];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.backgroundColor = UIColor.clearColor;
    header.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:header];
    self.headerView = header;

    UIView *surface = [UIView new];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.backgroundColor = PPMyItemsHeroSurfaceColor();
    surface.layer.cornerRadius = 30.0;
    surface.layer.borderWidth = 0.75;
    [surface pp_setBorderColor:PPMyItemsHeroStrokeColor()];
    PPApplyContinuousCorners(surface, 30.0);
    PPApplyCardShadow(surface);
    surface.accessibilityIdentifier = @"myitems.hero.surface";
    [header addSubview:surface];
    self.heroSurfaceView = surface;

    UIView *aura = [UIView new];
    aura.translatesAutoresizingMaskIntoConstraints = NO;
    aura.backgroundColor = [PPMyItemsAccentColor() colorWithAlphaComponent:0.065];
    aura.layer.cornerRadius = 48.0;
    PPApplyContinuousCorners(aura, 48.0);
    aura.isAccessibilityElement = NO;
    [surface addSubview:aura];
    self.heroAuraView = aura;

    UIView *rail = [UIView new];
    rail.translatesAutoresizingMaskIntoConstraints = NO;
    rail.backgroundColor = PPMyItemsAccentColor();
    rail.layer.cornerRadius = 1.5;
    PPApplyContinuousCorners(rail, 1.5);
    [surface addSubview:rail];
    self.accentRail = rail;

    UIView *iconPlate = [UIView new];
    iconPlate.translatesAutoresizingMaskIntoConstraints = NO;
    iconPlate.backgroundColor = [PPMyItemsAccentColor() colorWithAlphaComponent:0.095];
    iconPlate.layer.cornerRadius = 25.0;
    iconPlate.layer.borderWidth = 0.75;
    [iconPlate pp_setBorderColor:[PPMyItemsAccentColor() colorWithAlphaComponent:0.14]];
    PPApplyContinuousCorners(iconPlate, 25.0);
    self.iconPlate = iconPlate;

    UIImageSymbolConfiguration *iconConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:22.0
                                                         weight:UIImageSymbolWeightSemibold
                                                          scale:UIImageSymbolScaleMedium];
    NSString *symbol = self.mode == MyItemsModeMyAds ? @"square.grid.2x2.fill" : @"heart.fill";
    UIImageView *iconView =
        [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol
                                                   withConfiguration:iconConfiguration]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = PPMyItemsAccentColor();
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.isAccessibilityElement = NO;
    [iconPlate addSubview:iconView];
    self.modeIconView = iconView;

    LOTAnimationView *iconLottie = [[LOTAnimationView alloc] init];
    iconLottie.translatesAutoresizingMaskIntoConstraints = NO;
    iconLottie.contentMode = UIViewContentModeScaleAspectFit;
    iconLottie.loopAnimation = YES;
    iconLottie.alpha = 0.0;
    [aura addSubview:iconLottie];
    
    [Styling setAnimationNamed:@"Speaker.lottie" toView:iconLottie withSpeed:0.8 loopAnimation:YES autoplay:YES completion:^(BOOL success) {
        if (success) {
            [UIView animateWithDuration:0.3 animations:^{
                iconLottie.alpha = 1.0;
            }];
        }
    }];

    UILabel *eyebrow = [UILabel new];
    eyebrow.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrow.font =
        PPMyItemsScaledFont([GM boldFontWithSize:12.0], UIFontTextStyleFootnote);
    eyebrow.textColor = PPMyItemsAccentColor();
    eyebrow.textAlignment = alignment;
    eyebrow.adjustsFontForContentSizeCategory = YES;
    eyebrow.text =
        self.mode == MyItemsModeMyAds
            ? kLang(@"myitems_hero_eyebrow_ads")
            : kLang(@"myitems_hero_eyebrow_fav");
    self.heroEyebrow = eyebrow;

    UILabel *titleLabel = [UILabel new];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font =
        PPMyItemsScaledFont([GM BlackFontWithSize:27.0], UIFontTextStyleLargeTitle);
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = alignment;
    titleLabel.numberOfLines = 2;
    titleLabel.adjustsFontForContentSizeCategory = YES;
    titleLabel.text =
        self.mode == MyItemsModeMyAds
            ? kLang(@"myitems_hero_title_ads")
            : kLang(@"myitems_hero_title_fav");
    self.heroTitle = titleLabel;

    UILabel *subtitleLabel = [UILabel new];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font =
        PPMyItemsScaledFont([GM MidFontWithSize:14.0], UIFontTextStyleSubheadline);
    subtitleLabel.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    subtitleLabel.textAlignment = alignment;
    subtitleLabel.numberOfLines = 2;
    subtitleLabel.adjustsFontForContentSizeCategory = YES;
    subtitleLabel.text =
        self.mode == MyItemsModeMyAds
            ? kLang(@"myitems_hero_subtitle_ads")
            : kLang(@"myitems_hero_subtitle_fav");
    self.heroSubtitle = subtitleLabel;

    UIStackView *textStack =
        [[UIStackView alloc] initWithArrangedSubviews:@[eyebrow, titleLabel, subtitleLabel]];
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.alignment = UIStackViewAlignmentFill;
    textStack.spacing = 4.0;
    [textStack setCustomSpacing:6.0 afterView:eyebrow];
    [textStack setCustomSpacing:7.0 afterView:titleLabel];

    UIStackView *identityRow =
        [[UIStackView alloc] initWithArrangedSubviews:@[iconPlate, textStack]];
    identityRow.translatesAutoresizingMaskIntoConstraints = NO;
    identityRow.axis = UILayoutConstraintAxisHorizontal;
    identityRow.alignment = UIStackViewAlignmentTop;
    identityRow.distribution = UIStackViewDistributionFill;
    identityRow.spacing = PPSpaceBase;
    identityRow.semanticContentAttribute =
        [Language semanticAttributeForCurrentLanguage];
    [surface addSubview:identityRow];

    UIView *statusPill = [UIView new];
    statusPill.translatesAutoresizingMaskIntoConstraints = NO;
    statusPill.backgroundColor = PPMyItemsPillSurfaceColor();
    statusPill.layer.cornerRadius = 18.0;
    statusPill.layer.borderWidth = 0.75;
    [statusPill pp_setBorderColor:PPMyItemsHeroStrokeColor()];
    PPApplyContinuousCorners(statusPill, 18.0);
    statusPill.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [surface addSubview:statusPill];
    self.statusPillView = statusPill;

    UIView *statusDot = [UIView new];
    statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    statusDot.backgroundColor = PPMyItemsAccentColor();
    statusDot.layer.cornerRadius = 3.5;
    PPApplyContinuousCorners(statusDot, 3.5);
    statusDot.isAccessibilityElement = NO;
    [statusPill addSubview:statusDot];
    self.statusDotView = statusDot;

    UILabel *resultLabel = [UILabel new];
    resultLabel.translatesAutoresizingMaskIntoConstraints = NO;
    resultLabel.font =
        PPMyItemsScaledFont([GM boldFontWithSize:12.0], UIFontTextStyleFootnote);
    resultLabel.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    resultLabel.textAlignment = alignment;
    resultLabel.numberOfLines = 1;
    resultLabel.adjustsFontForContentSizeCategory = YES;
    resultLabel.accessibilityTraits = UIAccessibilityTraitUpdatesFrequently;
    [statusPill addSubview:resultLabel];
    self.resultLabel = resultLabel;

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:PPSpaceSM],
        [header.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:horizontalInset],
        [header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-horizontalInset],

        [surface.topAnchor constraintEqualToAnchor:header.topAnchor],
        [surface.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [surface.trailingAnchor constraintEqualToAnchor:header.trailingAnchor],
        [surface.bottomAnchor constraintEqualToAnchor:header.bottomAnchor],

        [aura.topAnchor constraintEqualToAnchor:surface.topAnchor constant:16.0],
        [aura.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-18.0],
        [aura.widthAnchor constraintEqualToConstant:96.0],
        [aura.heightAnchor constraintEqualToConstant:96.0],

        [rail.topAnchor constraintEqualToAnchor:surface.topAnchor constant:PPSpaceLG],
        [rail.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:PPSpaceLG],
        [rail.widthAnchor constraintEqualToConstant:44.0],
        [rail.heightAnchor constraintEqualToConstant:3.0],

        [identityRow.topAnchor constraintEqualToAnchor:rail.bottomAnchor constant:PPSpaceBase],
        [identityRow.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:PPSpaceLG],
        [identityRow.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-PPSpaceLG],

        [iconPlate.widthAnchor constraintEqualToConstant:52.0],
        [iconPlate.heightAnchor constraintEqualToConstant:52.0],
        [iconView.centerXAnchor constraintEqualToAnchor:iconPlate.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconPlate.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:24.0],
        [iconView.heightAnchor constraintEqualToConstant:24.0],

        [iconLottie.centerXAnchor constraintEqualToAnchor:aura.centerXAnchor],
        [iconLottie.centerYAnchor constraintEqualToAnchor:aura.centerYAnchor],
        [iconLottie.widthAnchor constraintEqualToConstant:64.0],
        [iconLottie.heightAnchor constraintEqualToConstant:64.0],

        [statusPill.topAnchor constraintEqualToAnchor:identityRow.bottomAnchor constant:PPSpaceMD],
        [statusPill.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:PPSpaceLG],
        [statusPill.heightAnchor constraintGreaterThanOrEqualToConstant:36.0],
        [statusPill.trailingAnchor constraintLessThanOrEqualToAnchor:surface.trailingAnchor constant:-PPSpaceLG],

        [statusDot.leadingAnchor constraintEqualToAnchor:statusPill.leadingAnchor constant:PPSpaceMD],
        [statusDot.centerYAnchor constraintEqualToAnchor:statusPill.centerYAnchor],
        [statusDot.widthAnchor constraintEqualToConstant:7.0],
        [statusDot.heightAnchor constraintEqualToConstant:7.0],

        [resultLabel.topAnchor constraintEqualToAnchor:statusPill.topAnchor constant:7.0],
        [resultLabel.leadingAnchor constraintEqualToAnchor:statusDot.trailingAnchor constant:PPSpaceSM],
        [resultLabel.trailingAnchor constraintEqualToAnchor:statusPill.trailingAnchor constant:-PPSpaceMD],
        [resultLabel.bottomAnchor constraintEqualToAnchor:statusPill.bottomAnchor constant:-7.0]
    ]];
}

- (void)setupSegmentedControl
{
    NSMutableArray *titles = [NSMutableArray array];
    [titles addObject:kLang(@"Ads")];
    [titles addObject:kLang(@"For Adoption")];
    
    self.segmentedControl = [[UISegmentedControl alloc] initWithItems:titles];
    self.segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.segmentedControl.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.segmentedControl addTarget:self
                              action:@selector(segmentChanged:)
                    forControlEvents:UIControlEventValueChanged];
    [self pp_styleSegment:self.segmentedControl];
    UIView *segmentHost = self.heroSurfaceView ?: self.headerView;
    [segmentHost addSubview:self.segmentedControl];

    [NSLayoutConstraint activateConstraints:@[
        [self.segmentedControl.topAnchor constraintEqualToAnchor:self.statusPillView.bottomAnchor
                                                        constant:PPSpaceMD],
        [self.segmentedControl.leadingAnchor constraintEqualToAnchor:segmentHost.leadingAnchor
                                                            constant:PPSpaceMD],
        [self.segmentedControl.trailingAnchor constraintEqualToAnchor:segmentHost.trailingAnchor
                                                             constant:-PPSpaceMD],
        [self.segmentedControl.heightAnchor constraintEqualToConstant:44.0],
        [self.segmentedControl.bottomAnchor constraintEqualToAnchor:segmentHost.bottomAnchor
                                                           constant:-PPSpaceMD]
    ]];

    if (self.showsAllFavoriteCategories) {
        self.segmentedControl.selectedSegmentIndex = UISegmentedControlNoSegment;
    } else {
        switch (self.viewType) {
            case ViewTypeAds:
                self.segmentedControl.selectedSegmentIndex = 0;
                break;
            case ViewTypeAdopt:
                self.segmentedControl.selectedSegmentIndex = 1;
                break;
            default:
                self.segmentedControl.selectedSegmentIndex = 0;
                break;
        }
    }
    self.segmentedControl.accessibilityLabel = kLang(@"myitems_segment_accessibility");
}

- (void)setupCollectionView
{
    self.collectionView =
        [[UICollectionView alloc] initWithFrame:CGRectZero
                           collectionViewLayout:[self createCompositionalLayout]];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.alwaysBounceVertical = YES;
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.collectionView.contentInset =
        UIEdgeInsetsMake(0.0, 0.0, PPSpaceXL + self.view.safeAreaInsets.bottom, 0.0);

    [PPUniversalCell pp_registerInCollectionView:self.collectionView];
    [self.collectionView registerClass:PPMyItemsSkeletonCell.class
            forCellWithReuseIdentifier:@"PPMyItemsSkeletonCell"];

    UIRefreshControl *refreshControl = [UIRefreshControl new];
    refreshControl.tintColor = AppPrimaryClr;
    refreshControl.accessibilityLabel = kLang(@"myitems_refresh_accessibility");
    [refreshControl addTarget:self
                       action:@selector(refreshTriggered)
             forControlEvents:UIControlEventValueChanged];
    self.collectionView.refreshControl = refreshControl;
    self.refreshControl = refreshControl;

    [self.view addSubview:self.collectionView];
    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor constraintEqualToAnchor:self.headerView.bottomAnchor],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (UICollectionViewCompositionalLayout *)createCompositionalLayout
{
    __weak typeof(self) weakSelf = self;
    return [[UICollectionViewCompositionalLayout alloc]
        initWithSectionProvider:^NSCollectionLayoutSection * _Nullable(
            __unused NSInteger sectionIndex,
            id<NSCollectionLayoutEnvironment> layoutEnvironment) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        CGFloat interItemSpacing = PPMyItemsGridInteritemSpacing;
        CGFloat itemHeight = PPMyItemsColumnHeight;
        CGFloat horizontalInset = strongSelf
            ? [strongSelf pp_horizontalContentInset]
            : PPScreenMargin;
        CGFloat containerWidth = layoutEnvironment.container.contentSize.width;
        if (containerWidth <= 0.0) {
            containerWidth = CGRectGetWidth(UIScreen.mainScreen.bounds);
        }
        CGFloat availableWidth =
            MAX(1.0, containerWidth - (horizontalInset * 2.0) - interItemSpacing);
        CGFloat itemWidth = floor(availableWidth / 2.0);

        NSCollectionLayoutSize *itemSize =
            [NSCollectionLayoutSize
                sizeWithWidthDimension:[NSCollectionLayoutDimension absoluteDimension:itemWidth]
                       heightDimension:[NSCollectionLayoutDimension fractionalHeightDimension:1.0]];
        NSCollectionLayoutItem *item =
            [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

        NSCollectionLayoutSize *groupSize =
            [NSCollectionLayoutSize
                sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                       heightDimension:[NSCollectionLayoutDimension absoluteDimension:itemHeight]];
        NSCollectionLayoutGroup *group = nil;
        if (@available(iOS 16.0, *)) {
            group =
                [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize
                                                           repeatingSubitem:item
                                                                    count:2];
        } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            group =
                [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize
                                                                subitem:item
                                                                  count:2];
#pragma clang diagnostic pop
        }
        group.interItemSpacing =
            [NSCollectionLayoutSpacing fixedSpacing:interItemSpacing];

        NSCollectionLayoutSection *section =
            [NSCollectionLayoutSection sectionWithGroup:group];
        section.contentInsets =
            NSDirectionalEdgeInsetsMake(8.0, horizontalInset, PPSpaceXL, horizontalInset);
        section.interGroupSpacing = PPMyItemsGridVerticalSpacing;
        return section;
    }];
}

- (void)setupStateView
{
    PPMyItemsStateView *stateView = [PPMyItemsStateView new];
    [self.view addSubview:stateView];
    self.stateView = stateView;

    [NSLayoutConstraint activateConstraints:@[
        [stateView.topAnchor constraintEqualToAnchor:self.headerView.bottomAnchor],
        [stateView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [stateView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [stateView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
}

#pragma mark - Motion

- (void)prepareEntranceStateIfNeeded
{
    if (self.entranceCompleted || self.entrancePrepared) {
        return;
    }
    self.entrancePrepared = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    self.heroSurfaceView.alpha = 0.0;
    self.heroSurfaceView.transform =
        CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 10.0),
                                CGAffineTransformMakeScale(0.985, 0.985));
    self.heroAuraView.alpha = 0.0;
    self.heroAuraView.transform = CGAffineTransformMakeScale(0.92, 0.92);
    self.accentRail.alpha = 0.0;
    self.iconPlate.alpha = 0.0;
    self.iconPlate.transform =
        CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 8.0),
                                CGAffineTransformMakeScale(0.94, 0.94));
    self.heroEyebrow.alpha = 0.0;
    self.heroTitle.alpha = 0.0;
    self.heroTitle.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
    self.heroSubtitle.alpha = 0.0;
    self.heroSubtitle.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    self.statusPillView.alpha = 0.0;
    self.statusPillView.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    self.resultLabel.alpha = 0.0;
    self.segmentedControl.alpha = 0.0;
    self.segmentedControl.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
}

- (void)runEntranceIfNeeded
{
    if (self.entranceCompleted) {
        return;
    }
    self.entranceCompleted = YES;
    [self.view layoutIfNeeded];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.heroSurfaceView.alpha = 1.0;
        self.heroSurfaceView.transform = CGAffineTransformIdentity;
        self.heroAuraView.alpha = 1.0;
        self.heroAuraView.transform = CGAffineTransformIdentity;
        self.accentRail.alpha = 1.0;
        self.iconPlate.alpha = 1.0;
        self.iconPlate.transform = CGAffineTransformIdentity;
        self.heroEyebrow.alpha = 1.0;
        self.heroTitle.alpha = 1.0;
        self.heroTitle.transform = CGAffineTransformIdentity;
        self.heroSubtitle.alpha = 1.0;
        self.heroSubtitle.transform = CGAffineTransformIdentity;
        self.statusPillView.alpha = 1.0;
        self.statusPillView.transform = CGAffineTransformIdentity;
        self.resultLabel.alpha = 1.0;
        self.segmentedControl.alpha = 1.0;
        self.segmentedControl.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.40
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroSurfaceView.alpha = 1.0;
        self.heroSurfaceView.transform = CGAffineTransformIdentity;
        self.heroAuraView.alpha = 1.0;
        self.heroAuraView.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:0.34
                          delay:0.03
                        options:UIViewAnimationOptionCurveEaseOut |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.accentRail.alpha = 1.0;
        self.heroEyebrow.alpha = 1.0;
    } completion:nil];
    [UIView animateWithDuration:0.42
                          delay:0.04
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.25
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.iconPlate.alpha = 1.0;
        self.iconPlate.transform = CGAffineTransformIdentity;
        self.heroTitle.alpha = 1.0;
        self.heroTitle.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:0.36
                          delay:0.11
                        options:UIViewAnimationOptionCurveEaseOut |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroSubtitle.alpha = 1.0;
        self.heroSubtitle.transform = CGAffineTransformIdentity;
        self.statusPillView.alpha = 1.0;
        self.statusPillView.transform = CGAffineTransformIdentity;
        self.resultLabel.alpha = 1.0;
    } completion:nil];
    [UIView animateWithDuration:0.44
                          delay:0.17
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.20
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.segmentedControl.alpha = 1.0;
        self.segmentedControl.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)prepareItemEntrances
{
    [self.pendingEntranceIndexPaths removeAllObjects];
    NSUInteger count = MIN(self.items.count, 8);
    for (NSUInteger index = 0; index < count; index++) {
        [self.pendingEntranceIndexPaths addObject:[NSIndexPath indexPathForItem:index inSection:0]];
    }
}

#pragma mark - Actions

- (void)segmentChanged:(UISegmentedControl *)sender
{
    self.showsAllFavoriteCategories = NO;
    switch (sender.selectedSegmentIndex) {
        case 0:
            self.viewType = ViewTypeAds;
            break;
        case 1:
            self.viewType = ViewTypeAdopt;
            break;
        default:
            self.viewType = ViewTypeAds;
            break;
    }

    UISelectionFeedbackGenerator *feedback = [UISelectionFeedbackGenerator new];
    [feedback selectionChanged];
    [self fetchDataForCurrentSegment];
}

- (void)refreshTriggered
{
    [self fetchDataForCurrentSegment];
}

- (void)retryTapped
{
    [self fetchDataForCurrentSegment];
}

- (void)signInTapped
{
    [UserManager showPromptOnTopController];
}

#pragma mark - Data Fetching

- (void)fetchDataForCurrentSegment
{
    NSString *userID =
        [[UserManager sharedManager].currentUser.ID
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (userID.length == 0) {
        self.requestGeneration += 1;
        self.contentError = nil;
        [self finishRefreshControl];
        [self applyContentState:PPMyItemsContentStateSignedOut animated:YES];
        return;
    }

    NSUInteger request = ++self.requestGeneration;
    [self applyContentState:PPMyItemsContentStateLoading animated:self.hasLoadedOnce];

    __weak typeof(self) weakSelf = self;
    void (^completion)(NSArray *, NSError *) = ^(NSArray *fetchedItems, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || request != strongSelf.requestGeneration) {
                return;
            }

            strongSelf.hasLoadedOnce = YES;
            strongSelf.contentError = error;
            [strongSelf finishRefreshControl];

            if (error) {
                [strongSelf applyContentState:PPMyItemsContentStateError animated:YES];
                return;
            }

            strongSelf.rawItems = fetchedItems ?: @[];
            strongSelf.items =
                [strongSelf pp_generateUniversalModelsArrayFromArray:strongSelf.rawItems];
            [strongSelf prepareItemEntrances];
            [strongSelf applyContentState:
                strongSelf.items.count > 0
                    ? PPMyItemsContentStateContent
                    : PPMyItemsContentStateEmpty
                                  animated:YES];
        });
    };

    if (self.mode == MyItemsModeMyAds) {
        switch (self.viewType) {
            case ViewTypeAds: {
                [PetAdManager fetchAdsForUserID:userID
                                      completion:^(NSArray *items) {
                    completion(items, nil);
                }];
                break;
            }
            case ViewTypeAccess: {
                [PetAccessoryManager fetchAccessoriesForUserID:userID
                                                 accessKindType:AccessTypeAccessory
                                                     completion:^(NSArray *items) {
                    completion(items, nil);
                }];
                break;
            }
            case ViewTypeFood: {
                [PetAccessoryManager fetchAccessoriesForUserID:userID
                                                 accessKindType:AccessTypeFood
                                                     completion:^(NSArray *items) {
                    completion(items, nil);
                }];
                break;
            }
            case ViewTypeAdopt: {
                [AdoptPetManager.shared fetchPetsForUserID:userID
                                                completion:^(NSArray *pets, NSError *error) {
                    completion(pets, error);
                }];
                break;
            }
        }
        return;
    }

    if (self.showsAllFavoriteCategories) {
        [self fetchAllFavoritesForUserID:userID
                                 request:request
                              completion:completion];
        return;
    }

    NSString *collection = @"";
    switch (self.viewType) {
        case ViewTypeAds:
            collection = @"favoritesAds";
            break;
        case ViewTypeAccess:
        case ViewTypeFood:
            collection = @"favoritesAccessories";
            break;
        case ViewTypeAdopt:
            collection = @"favoritesAdoptPets";
            break;
    }

    [PetAdManager fetchFavoriteAdIDsForUserID:userID
                                   collection:collection
                                   completion:^(NSArray<NSString *> *adIDs) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || request != strongSelf.requestGeneration) {
            return;
        }
        if (adIDs.count == 0) {
            completion(@[], nil);
            return;
        }

        switch (strongSelf.viewType) {
            case ViewTypeAds: {
                [PetAdManager fetchAdsWithIDs:adIDs
                                   completion:^(NSArray *items) {
                    completion(items, nil);
                }];
                break;
            }
            case ViewTypeAccess:
            case ViewTypeFood: {
                [PetAccessoryManager fetchAccessoriesWithIDs:adIDs
                                                   completion:^(NSArray *items) {
                    completion(items, nil);
                }];
                break;
            }
            case ViewTypeAdopt: {
                [AdoptPetManager.shared fetchPetsWithIDs:adIDs
                                               completion:^(NSArray *pets, NSError *error) {
                    completion(pets, error);
                }];
                break;
            }
        }
    }];
}

- (void)fetchAllFavoritesForUserID:(NSString *)userID
                           request:(NSUInteger)request
                        completion:(void (^)(NSArray *, NSError *))completion
{
    dispatch_group_t group = dispatch_group_create();
    __block NSArray *ads = @[];
    __block NSArray *accessories = @[];
    __block NSArray *adoptionPets = @[];
    __block NSError *adoptionError = nil;
    __weak typeof(self) weakSelf = self;

    dispatch_group_enter(group);
    [PetAdManager fetchFavoriteAdIDsForUserID:userID
                                   collection:@"favoritesAds"
                                   completion:^(NSArray<NSString *> *identifiers) {
        if (identifiers.count == 0) {
            dispatch_group_leave(group);
            return;
        }
        [PetAdManager fetchAdsWithIDs:identifiers
                           completion:^(NSArray *items) {
            ads = items ?: @[];
            dispatch_group_leave(group);
        }];
    }];

    dispatch_group_enter(group);
    [PetAdManager fetchFavoriteAdIDsForUserID:userID
                                   collection:@"favoritesAccessories"
                                   completion:^(NSArray<NSString *> *identifiers) {
        if (identifiers.count == 0) {
            dispatch_group_leave(group);
            return;
        }
        [PetAccessoryManager fetchAccessoriesWithIDs:identifiers
                                           completion:^(NSArray *items) {
            accessories = items ?: @[];
            dispatch_group_leave(group);
        }];
    }];

    dispatch_group_enter(group);
    [PetAdManager fetchFavoriteAdIDsForUserID:userID
                                   collection:@"favoritesAdoptPets"
                                   completion:^(NSArray<NSString *> *identifiers) {
        if (identifiers.count == 0) {
            dispatch_group_leave(group);
            return;
        }
        [AdoptPetManager.shared fetchPetsWithIDs:identifiers
                                      completion:^(NSArray *pets, NSError *error) {
            adoptionPets = pets ?: @[];
            adoptionError = error;
            dispatch_group_leave(group);
        }];
    }];

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || request != strongSelf.requestGeneration) {
            return;
        }
        NSMutableArray *combined = [NSMutableArray array];
        [combined addObjectsFromArray:ads];
        [combined addObjectsFromArray:accessories];
        [combined addObjectsFromArray:adoptionPets];
        NSError *resolvedError = combined.count == 0 ? adoptionError : nil;
        completion(combined.copy, resolvedError);
    });
}

- (void)finishRefreshControl
{
    if (self.refreshControl.isRefreshing) {
        [self.refreshControl endRefreshing];
    }
}

- (void)applyContentState:(PPMyItemsContentState)state animated:(BOOL)animated
{
    self.contentState = state;
    BOOL showsCollection =
        state == PPMyItemsContentStateLoading || state == PPMyItemsContentStateContent;
    self.collectionView.hidden = !showsCollection;
    self.collectionView.userInteractionEnabled = state == PPMyItemsContentStateContent;
    self.stateView.hidden = showsCollection;

    [self updateResultLabel];
    if (!showsCollection) {
        [self configureStateViewForState:state];
    }

    void (^updates)(void) = ^{
        self.collectionView.alpha = showsCollection ? 1.0 : 0.0;
        self.stateView.alpha = showsCollection ? 0.0 : 1.0;
        self.stateView.transform = CGAffineTransformIdentity;
    };

    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        if (!showsCollection) {
            self.stateView.alpha = 0.0;
            self.stateView.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
        }
        [UIView transitionWithView:self.view
                          duration:0.24
                           options:UIViewAnimationOptionTransitionCrossDissolve |
                                   UIViewAnimationOptionBeginFromCurrentState |
                                   UIViewAnimationOptionAllowUserInteraction
                        animations:^{
            [self.collectionView reloadData];
            updates();
        } completion:nil];
    } else {
        [self.collectionView reloadData];
        updates();
    }
}

- (void)updateResultLabel
{
    NSString *text = @"";
    switch (self.contentState) {
        case PPMyItemsContentStateLoading:
            text = kLang(@"myitems_loading");
            break;
        case PPMyItemsContentStateContent:
            text = self.items.count == 1
                ? kLang(@"myitems_count_single")
                : [NSString stringWithFormat:kLang(@"myitems_count_format"),
                   (long)self.items.count];
            break;
        case PPMyItemsContentStateEmpty:
            text = [NSString stringWithFormat:kLang(@"myitems_count_format"), 0L];
            break;
        case PPMyItemsContentStateError:
            text = kLang(@"myitems_status_unavailable");
            break;
        case PPMyItemsContentStateSignedOut:
            text = kLang(@"myitems_status_signin");
            break;
    }
    self.resultLabel.text = text;
    self.resultLabel.accessibilityLabel = text;
}

- (void)configureStateViewForState:(PPMyItemsContentState)state
{
    switch (state) {
        case PPMyItemsContentStateEmpty: {
            BOOL isAds = self.mode == MyItemsModeMyAds;
            [self.stateView
                configureWithSymbol:isAds ? @"square.stack.3d.up" : @"heart"
                              title:kLang(isAds
                                              ? @"myitems_empty_ads_title"
                                              : @"myitems_empty_favorites_title")
                           subtitle:kLang(isAds
                                              ? @"myitems_empty_ads_subtitle"
                                              : @"myitems_empty_favorites_subtitle")
                        actionTitle:nil
                             target:nil
                             action:nil];
            break;
        }
        case PPMyItemsContentStateError:
            [self.stateView
                configureWithSymbol:@"arrow.clockwise"
                              title:kLang(@"myitems_error_title")
                           subtitle:self.contentError.localizedDescription.length > 0
                                        ? self.contentError.localizedDescription
                                        : kLang(@"myitems_error_subtitle")
                        actionTitle:kLang(@"Retry")
                             target:self
                             action:@selector(retryTapped)];
            break;
        case PPMyItemsContentStateSignedOut:
            [self.stateView
                configureWithSymbol:@"person.crop.circle"
                              title:kLang(@"myitems_signin_title")
                           subtitle:kLang(@"myitems_signin_subtitle")
                        actionTitle:kLang(@"auth_signin_required_action")
                             target:self
                             action:@selector(signInTapped)];
            break;
        case PPMyItemsContentStateLoading:
        case PPMyItemsContentStateContent:
            break;
    }
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
    return self.contentState == PPMyItemsContentStateLoading
        ? PPMyItemsSkeletonCount
        : self.items.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                           cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.contentState == PPMyItemsContentStateLoading) {
        return [collectionView
            dequeueReusableCellWithReuseIdentifier:@"PPMyItemsSkeletonCell"
                                      forIndexPath:indexPath];
    }

    PPUniversalCellViewModel *viewModel = self.items[indexPath.item];
    PPUniversalCell *cell = (PPUniversalCell *)[PPUniversalCell pp_dequeueFromCollectionView:collectionView indexPath:indexPath];
    cell.delegate = self;
    cell.forceShowsOwnerMenuButton = self.mode == MyItemsModeMyAds;
    cell.showsSubtitle = YES;
    viewModel.indexPath = indexPath;
    [cell applyViewModel:viewModel
                 context:viewModel.modelContext
              layoutMode:PPCellLayoutModePinterest
            discountMode:PPDiscountStyleBadge
             imageLoader:^(UIImageView *imageView,
                           NSString *urlString,
                           __unused UIImage *placeholder,
                           __unused UIView *card) {
        [[PPImageLoaderManager shared] setImageOnImageView:imageView
                                                       url:urlString
                                                complation:nil];
    }];
    UICollectionViewCell *resolvedCell = cell;

    if ([self.pendingEntranceIndexPaths containsObject:indexPath]) {
        resolvedCell.alpha = 0.0;
        resolvedCell.transform =
            CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 10.0),
                                    CGAffineTransformMakeScale(0.985, 0.985));
    } else {
        resolvedCell.alpha = 1.0;
        resolvedCell.transform = CGAffineTransformIdentity;
    }
    return resolvedCell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView
       willDisplayCell:(UICollectionViewCell *)cell
    forItemAtIndexPath:(NSIndexPath *)indexPath
{
    if ([cell isKindOfClass:PPMyItemsSkeletonCell.class]) {
        [(PPMyItemsSkeletonCell *)cell startAnimating];
        return;
    }
    if (![self.pendingEntranceIndexPaths containsObject:indexPath]) {
        return;
    }
    [self.pendingEntranceIndexPaths removeObject:indexPath];

    NSTimeInterval delay = MIN(indexPath.item, 5) * 0.035;
    [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0.0 : 0.34
                          delay:delay
                        options:UIViewAnimationOptionCurveEaseOut |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        cell.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)collectionView:(UICollectionView *)collectionView
  didEndDisplayingCell:(UICollectionViewCell *)cell
    forItemAtIndexPath:(NSIndexPath *)indexPath
{
    if ([cell isKindOfClass:PPMyItemsSkeletonCell.class]) {
        [(PPMyItemsSkeletonCell *)cell stopAnimating];
    } else if ([PPUniversalCell pp_isUniversalCell:cell]) {
        [(PPUniversalCell *)cell stopMediaPlayback];
    }
}

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.contentState != PPMyItemsContentStateContent ||
        indexPath.item >= (NSInteger)self.rawItems.count) {
        return;
    }

    [self pp_openDetailsForObject:self.rawItems[indexPath.item]];
}

- (void)pp_openDetailsForObject:(id)object
{
    if (!object) {
        return;
    }

    if ([object isKindOfClass:PetAd.class] ||
        [object isKindOfClass:PetAccessory.class]) {
        [PPOverlayCoordinator pp_openDetailForObject:object
                                             fromVC:self
                                         routingNav:nil];
        return;
    }

    if ([object isKindOfClass:AdoptPetModel.class]) {
        AdoptPetModel *model = (AdoptPetModel *)object;
        NSString *currentUserID = [UserManager sharedManager].currentUser.ID ?: @"";
        BOOL isOwner =
            self.mode == MyItemsModeMyAds ||
            (model.ownerID.length > 0 && [model.ownerID isEqualToString:currentUserID]);
        AdoptPetDetailsViewController *viewController =
            [[AdoptPetDetailsViewController alloc] initWithModel:model
                                                         isOwner:isOwner];
        viewController.modalPresentationStyle = UIModalPresentationPageSheet;
        if (@available(iOS 15.0, *)) {
            UISheetPresentationController *sheet =
                viewController.sheetPresentationController;
            sheet.detents = @[[UISheetPresentationControllerDetent largeDetent]];
            sheet.prefersGrabberVisible = NO;
            sheet.preferredCornerRadius = 30.0;
            sheet.prefersScrollingExpandsWhenScrolledToEdge = YES;
            sheet.prefersEdgeAttachedInCompactHeight = YES;
            sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = NO;
        }
        [self presentViewController:viewController animated:YES completion:nil];
    }
}

#pragma mark - PPUniversalCellDelegate

- (void)PPUniversalCell_tapCard:(PPUniversalCellViewModel *)universalModel
{
    [self pp_openDetailsForObject:universalModel.ModelObject];
}

- (void)PPUniversalCell_tapEdit:(PPUniversalCellViewModel *)universalModel
{
    if (!universalModel.ModelObject) {
        return;
    }

    if ([universalModel.ModelObject isKindOfClass:PetAd.class]) {
        PetAd *ad = (PetAd *)universalModel.ModelObject;
        AddNewAd *viewController =
        [[AddNewAd alloc] init];
        viewController.mode = AdEditorModeEdit;
        viewController.editingAd = ad;
        viewController.delegate = self;
        UINavigationController *navigationController =
            [[UINavigationController alloc] initWithRootViewController:viewController];
        navigationController.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:navigationController animated:YES completion:nil];
    } else if ([universalModel.ModelObject isKindOfClass:PetAccessory.class]) {
        AddNewAccessory *viewController = [AddNewAccessory new];
        viewController.editingAccessory =
            (PetAccessory *)universalModel.ModelObject;
        UINavigationController *navigationController =
            [[UINavigationController alloc] initWithRootViewController:viewController];
        navigationController.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:navigationController animated:YES completion:nil];
    }
}

- (void)PPUniversalCell_tapDelete:(PPUniversalCellViewModel *)universalModel
{
    if (!universalModel.ModelObject) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    [GM showDeleteConfirmationFrom:self
                             title:kLang(@"Confirm Deletion")
                           message:kLang(@"Are you sure you want to delete this item?")
                        completion:^(BOOL confirmed) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !confirmed) {
            return;
        }

        if ([universalModel.ModelObject isKindOfClass:PetAd.class]) {
            [[PetAdManager sharedManager]
                deletePetAd:(PetAd *)universalModel.ModelObject
                  completion:^(NSError *error) {
                if (!error) {
                    [strongSelf fetchDataForCurrentSegment];
                }
            }];
        } else if ([universalModel.ModelObject isKindOfClass:PetAccessory.class]) {
            PetAccessory *accessory =
                (PetAccessory *)universalModel.ModelObject;
            [[PetAccessoryManager sharedManager]
                deleteAccessory:accessory.accessoryID
                     completion:^(NSError *error) {
                if (!error) {
                    [strongSelf fetchDataForCurrentSegment];
                }
            }];
        }
    }];
}

- (void)PPUniversalCell_tapVisibilityToggle:(PPUniversalCellViewModel *)universalModel
{
    if (!universalModel.ModelObject) {
        return;
    }

    BOOL nextVisible = !universalModel.isPubliclyVisible;
    NSString *successMessage =
        nextVisible ? kLang(@"listing_visible_success") : kLang(@"listing_hidden_success");
    __weak typeof(self) weakSelf = self;
    void (^showResult)(NSError *) = ^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            if (error) {
                [PPAlertHelper showErrorIn:strongSelf
                                     title:kLang(@"Error")
                                  subtitle:error.localizedDescription
                                           ?: kLang(@"listing_visibility_failed")];
                return;
            }
            [strongSelf fetchDataForCurrentSegment];
            [AppManager.sharedInstance showSnakBar:successMessage
                                        withColor:GM.appPrimaryColor
                                      andDuration:0.6
                                    containerView:strongSelf.view];
        });
    };

    if ([universalModel.ModelObject isKindOfClass:PetAd.class]) {
        PetAd *ad = (PetAd *)universalModel.ModelObject;
        if (ad.adID.length == 0) {
            return;
        }
        [[PetAdManager sharedManager]
            updatePetAdID:ad.adID
               visibility:nextVisible ? PetAdVisibilityPublic : PetAdVisibilityHidden
               completion:showResult];
    } else if ([universalModel.ModelObject isKindOfClass:PetAccessory.class]) {
        PetAccessory *accessory = (PetAccessory *)universalModel.ModelObject;
        if (accessory.accessoryID.length == 0) {
            return;
        }
        [[PetAccessoryManager sharedManager]
            updateAccessoryID:accessory.accessoryID
              showInAppMarket:nextVisible
                   completion:showResult];
    } else if ([universalModel.ModelObject isKindOfClass:AdoptPetModel.class]) {
        AdoptPetModel *model = (AdoptPetModel *)universalModel.ModelObject;
        if (model.documentID.length == 0) {
            return;
        }
        [[AdoptPetManager shared]
            updatePetVisibilityWithID:model.documentID
                           visibility:nextVisible ? 0 : 1
                           completion:^(BOOL success, NSError *error) {
            showResult(success ? nil : error);
        }];
    }
}

- (void)PPUniversalCell_tapShare:(PPUniversalCellViewModel *)universalModel
{
    if (universalModel.ModelObject) {
        [PPAdSharingHelper shareItem:universalModel.ModelObject
                 fromViewController:self];
    }
}

#pragma mark - AddNewAdDelegate

- (void)addNewAd:(AddNewAd *)viewController didCreateAd:(PetAd *)ad
{
    [self fetchDataForCurrentSegment];
}

- (void)addNewAd:(AddNewAd *)viewController didUpdateAd:(PetAd *)ad
{
    [self fetchDataForCurrentSegment];
}

#pragma mark - Styling

- (void)pp_styleSegment:(UISegmentedControl *)segment
{
    if (!segment) {
        return;
    }

    segment.backgroundColor = UIColor.clearColor;
    segment.selectedSegmentTintColor = [AppForgroundColr colorWithAlphaComponent:0.82];
    segment.tintColor = UIColor.clearColor;
    segment.layer.cornerRadius = 14.0;
    PPApplyContinuousCorners(segment, 14.0);
    segment.clipsToBounds = YES;

    NSDictionary *normalAttributes = @{
        NSForegroundColorAttributeName: AppSecondaryTextClr,
        NSFontAttributeName: PPMyItemsScaledFont([GM MidFontWithSize:13.0], UIFontTextStyleFootnote)
    };
    NSDictionary *selectedAttributes = @{
        NSForegroundColorAttributeName: AppPrimaryTextClr,
        NSFontAttributeName: PPMyItemsScaledFont([GM boldFontWithSize:13.0], UIFontTextStyleFootnote)
    };
    [segment setTitleTextAttributes:normalAttributes forState:UIControlStateNormal];
    [segment setTitleTextAttributes:selectedAttributes forState:UIControlStateSelected];
    [segment setDividerImage:[UIImage new]
         forLeftSegmentState:UIControlStateNormal
           rightSegmentState:UIControlStateNormal
                  barMetrics:UIBarMetricsDefault];
}

#pragma mark - ViewModel Generation

- (NSArray<PPUniversalCellViewModel *> *)pp_generateUniversalModelsArrayFromArray:(NSArray *)objects
{
    NSMutableArray<PPUniversalCellViewModel *> *result = [NSMutableArray array];
    NSString *currentUserID = [UserManager sharedManager].currentUser.ID ?: @"";

    for (id object in objects) {
        PPCellContext context = PPCellForAds;
        if ([object isKindOfClass:PetAccessory.class]) {
            PetAccessory *accessory = (PetAccessory *)object;
            context = accessory.accessKindType == AccessTypeFood
                ? PPCellForFood
                : PPCellForMarket;
        } else if ([object isKindOfClass:AdoptPetModel.class]) {
            context = PPCellForAdopt;
        }

        PPUniversalCellViewModel *viewModel =
            [[PPUniversalCellViewModel alloc] initWithModel:object context:context];

        if (self.mode == MyItemsModeMyAds) {
            viewModel.isOwner = YES;
        } else if ([object isKindOfClass:PetAd.class]) {
            viewModel.isOwner =
                [currentUserID isEqualToString:((PetAd *)object).ownerID];
        } else if ([object isKindOfClass:PetAccessory.class]) {
            viewModel.isOwner =
                [currentUserID isEqualToString:((PetAccessory *)object).ownerID];
        } else if ([object isKindOfClass:AdoptPetModel.class]) {
            viewModel.isOwner =
                [currentUserID isEqualToString:((AdoptPetModel *)object).ownerID];
        }

        [result addObject:viewModel];
    }
    return result.copy;
}

@end
