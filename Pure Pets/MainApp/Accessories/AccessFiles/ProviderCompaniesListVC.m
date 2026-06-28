//
//  ProviderCompaniesListVC.m
//  Pure Pets
//

#import "ProviderCompaniesListVC.h"

#import "PetAccessory.h"
#import "PetAccessoryManager.h"
#import "PPImageLoaderManager.h"
#import "PPModernAvatarRenderer.h"
#import "ProviderStorefrontProductsVC.h"
#import "UserManager.h"
#import "UserModel.h"
#import "CitiesManager.h"

#import "PPProviderCompanyPremiumCardCell.h"
#import "PPProviderCompanyCell.h"
#import <QuartzCore/QuartzCore.h>

@import FirebaseFunctions;
@import FirebaseFirestore;











@interface ProviderCompaniesListVC () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *tableBackgroundMiddleGlowView;
@property (nonatomic, strong) UIView *tableBackgroundBottomGlowView;
@property (nonatomic, strong) CAGradientLayer *tableBackgroundMiddleGlowLayer;
@property (nonatomic, strong) CAGradientLayer *tableBackgroundBottomGlowLayer;
@property (nonatomic, strong) UIView *headerContainerView;
@property (nonatomic, strong) UIView *heroSurfaceView;
@property (nonatomic, strong) UIVisualEffectView *heroFrostedMaterialView;
@property (nonatomic, strong) CAGradientLayer *heroSurfaceGradientLayer;
@property (nonatomic, strong) CAShapeLayer *heroSurfaceEdgeHighlightLayer;
@property (nonatomic, strong) UIView *heroAmbientGlowView;
@property (nonatomic, strong) UIView *heroAmbientAccentView;
@property (nonatomic, strong) UIView *heroAmbientSupportView;
@property (nonatomic, strong) UIView *heroContentContainerView;
@property (nonatomic, strong) UILabel *heroEyebrowLabel;
@property (nonatomic, strong) UILabel *heroTitleLabel;
@property (nonatomic, strong) PPInsetLabel *heroTitleCountBadgeLabel;
@property (nonatomic, strong) UILabel *heroSubtitleLabel;
@property (nonatomic, strong) UIView *heroTrailIconPlateView;
@property (nonatomic, strong) UIImageView *heroTrailIconView;
@property (nonatomic, strong) UIButton *heroDismissButton;

@property (nonatomic, strong) UIButton *heroLayoutToggleButton;
@property (nonatomic, strong) UIView *heroSearchChromeView;
@property (nonatomic, strong) UIImageView *heroSearchIconView;
@property (nonatomic, strong) UITextField *heroSearchTextField;
@property (nonatomic, strong) UIView *heroProofRailView;
@property (nonatomic, strong) UIScrollView *heroDiscoveryScrollView;
@property (nonatomic, strong) UIStackView *heroDiscoveryStackView;
@property (nonatomic, strong) NSArray<UIButton *> *heroDiscoveryButtons;
@property (nonatomic, strong) NSLayoutConstraint *heroContainerHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroSurfaceTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroSurfaceBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroContentHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroProofRailLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroProofRailTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroProofRailBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroProofRailHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroSearchChromeBottomConstraint;

@property (nonatomic, strong) UIView *stateContainerView;
@property (nonatomic, strong) UIImageView *stateIconView;
@property (nonatomic, strong) UILabel *stateTitleLabel;
@property (nonatomic, strong) UILabel *stateSubtitleLabel;
@property (nonatomic, strong) UIButton *retryButton;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) NSArray<PPProviderCompanyEntry *> *allEntries;
@property (nonatomic, strong) NSArray<PPProviderCompanyEntry *> *visibleEntries;
@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, assign) PPProviderCompaniesLoadState loadState;
@property (nonatomic, strong, nullable) NSError *lastLoadError;
@property (nonatomic, assign) BOOL heroEntrancePrepared;
@property (nonatomic, assign) BOOL heroEntranceCompleted;
@property (nonatomic, strong) NSMutableSet<NSString *> *animatedCompanyCellKeys;
@property (nonatomic, assign) BOOL searchChromeFocused;
@property (nonatomic, assign) BOOL heroDiscoveryInitialOffsetApplied;
@property (nonatomic, assign) BOOL heroPinnedScrollPositionApplied;
@property (nonatomic, assign) CGFloat heroCollapseProgress;
@property (nonatomic, assign) BOOL heroCollapsed;
@property (nonatomic, assign) BOOL applyingHeroCollapseLayout;
@property (nonatomic, assign) BOOL heroAmbientMotionStarted;
@property (nonatomic, assign) BOOL prefersCompactListLayout;
@property (nonatomic, assign) PPProviderCompaniesDiscoveryMode selectedDiscoveryMode;
- (UIButton *)pp_makeDiscoveryButtonForMode:(PPProviderCompaniesDiscoveryMode)mode;
- (void)pp_updateDiscoveryButtonAppearances;
- (void)pp_handleDiscoveryButton:(UIButton *)button;
- (UIView *)pp_makeHeroMetricViewWithTitleLabel:(UILabel * __strong *)titleLabel
                                     valueLabel:(UILabel * __strong *)valueLabel;
- (void)pp_handleLayoutToggleButton;
- (void)pp_updateLayoutToggleAppearanceAnimated:(BOOL)animated;
- (void)pp_focusHeroSearchTextField;
- (void)pp_alignDiscoveryRailForCurrentLanguageIfNeeded;
- (void)pp_updateBottomNavigationInsetsIfNeeded;
- (void)pp_applyHeroCollapseProgress:(CGFloat)progress animated:(BOOL)animated;
- (void)pp_updatePinnedHeroForCurrentScrollPosition;
- (void)pp_updateHeroSurfaceGeometry;
- (void)pp_hideDecorativeHeroContent;
- (void)pp_handleHeroSearchTextChanged:(UITextField *)textField;
- (CGFloat)pp_expandedHeroHeight;
- (CGFloat)pp_expandedHeroContentHeight;
- (CGFloat)pp_collapsedHeroHeight;
- (CGFloat)pp_heroCollapseDistance;
- (CAGradientLayer *)pp_makeBackgroundGlowLayer;
- (void)pp_applyBackgroundGlowColor:(UIColor *)color
                               view:(UIView *)view
                      gradientLayer:(CAGradientLayer *)gradientLayer
                          peakAlpha:(CGFloat)peakAlpha;
- (void)pp_addHeroAmbientSequenceToView:(UIView *)view
                                  delay:(CFTimeInterval)delay
                                 travel:(CGFloat)travel
                             scaleDelta:(CGFloat)scaleDelta
                           opacityFloor:(CGFloat)opacityFloor
                                    key:(NSString *)key;
- (void)pp_stopHeroAmbientMotion;
- (void)pp_hydrateProviderProfileForEntry:(PPProviderCompanyEntry *)entry
                               completion:(dispatch_block_t)completion;
- (void)pp_refreshProviderRatingSummaries;
@end

@implementation ProviderCompaniesListVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        _selectedProviderCategoryIdentifier = @"marketplace";
        _allEntries = @[];
        _visibleEntries = @[];
        _searchQuery = @"";
        _animatedCompanyCellKeys = [NSMutableSet set];
        _selectedDiscoveryMode = PPProviderCompaniesDiscoveryModeRecommended;
        _prefersCompactListLayout = YES;
    }
    return self;
}

- (void)dealloc
{
    [self pp_stopHeroAmbientMotion];
 }

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self pp_buildUI];
    [self pp_applyHeaderContent];
    [self pp_prepareHeroEntranceIfNeeded];
    [self loadProviders];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self pp_prepareHeroEntranceIfNeeded];
    self.navigationItem.searchController = nil;
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.leftBarButtonItem = nil;
    [self pp_hideDecorativeHeroContent];
    [self pp_applyPremiumSearchChromeAppearanceFocused:self.searchChromeFocused animated:NO];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self pp_runHeroEntranceIfNeeded];
    [self pp_startHeroAmbientMotionIfNeeded];
    [self pp_updateBottomNavigationInsetsIfNeeded];
    [self pp_updatePinnedHeroForCurrentScrollPosition];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self pp_stopHeroAmbientMotion];
 }

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    [self pp_updateHeroSurfaceGeometry];

    [self pp_alignDiscoveryRailForCurrentLanguageIfNeeded];
    [self pp_updateBottomNavigationInsetsIfNeeded];
    [self pp_updatePinnedHeroForCurrentScrollPosition];
}

- (void)pp_updateHeroSurfaceGeometry
{
    if (CGRectIsEmpty(self.heroSurfaceView.bounds)) {
        return;
    }

    CGFloat surfaceRadius = 30.0;
    PPProviderCompaniesApplyContinuousCorners(self.heroSurfaceView, surfaceRadius);
    PPProviderCompaniesApplyContinuousCorners(self.heroFrostedMaterialView, surfaceRadius);
    self.heroFrostedMaterialView.layer.masksToBounds = YES;
    self.heroSurfaceGradientLayer.frame = self.heroSurfaceView.bounds;
    self.heroSurfaceGradientLayer.cornerRadius = surfaceRadius;
    self.heroSurfaceGradientLayer.masksToBounds = YES;

    CGRect highlightBounds = CGRectInset(self.heroSurfaceView.bounds, 0.75, 0.75);
    CGFloat highlightRadius = MAX(0.0, surfaceRadius - 0.75);
    self.heroSurfaceEdgeHighlightLayer.frame = self.heroSurfaceView.bounds;
    self.heroSurfaceEdgeHighlightLayer.path =
        [UIBezierPath bezierPathWithRoundedRect:highlightBounds
                                   cornerRadius:highlightRadius].CGPath;
    self.heroSurfaceEdgeHighlightLayer.fillColor = UIColor.clearColor.CGColor;
    self.heroSurfaceEdgeHighlightLayer.lineWidth = 0.7;
    if (self.heroSurfaceEdgeHighlightLayer.superlayer != self.heroSurfaceView.layer) {
        [self.heroSurfaceView.layer addSublayer:self.heroSurfaceEdgeHighlightLayer];
    }
    self.heroSurfaceView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.heroSurfaceView.bounds cornerRadius:surfaceRadius].CGPath;
    self.heroAmbientGlowView.layer.cornerRadius = CGRectGetWidth(self.heroAmbientGlowView.bounds) * 0.5;
    self.heroAmbientAccentView.layer.cornerRadius = CGRectGetWidth(self.heroAmbientAccentView.bounds) * 0.5;
    self.heroAmbientSupportView.layer.cornerRadius = CGRectGetWidth(self.heroAmbientSupportView.bounds) * 0.5;
    self.tableBackgroundMiddleGlowView.layer.cornerRadius = CGRectGetWidth(self.tableBackgroundMiddleGlowView.bounds) * 0.5;
    self.tableBackgroundBottomGlowView.layer.cornerRadius = CGRectGetWidth(self.tableBackgroundBottomGlowView.bounds) * 0.5;
    self.tableBackgroundMiddleGlowLayer.frame = self.tableBackgroundMiddleGlowView.bounds;
    self.tableBackgroundMiddleGlowLayer.cornerRadius = CGRectGetWidth(self.tableBackgroundMiddleGlowView.bounds) * 0.5;
    self.tableBackgroundMiddleGlowLayer.masksToBounds = YES;
    self.tableBackgroundBottomGlowLayer.frame = self.tableBackgroundBottomGlowView.bounds;
    self.tableBackgroundBottomGlowLayer.cornerRadius = CGRectGetWidth(self.tableBackgroundBottomGlowView.bounds) * 0.5;
    self.tableBackgroundBottomGlowLayer.masksToBounds = YES;
    self.tableBackgroundMiddleGlowView.layer.shadowPath =
        [UIBezierPath bezierPathWithOvalInRect:self.tableBackgroundMiddleGlowView.bounds].CGPath;
    self.tableBackgroundBottomGlowView.layer.shadowPath =
        [UIBezierPath bezierPathWithOvalInRect:self.tableBackgroundBottomGlowView.bounds].CGPath;
    PPProviderCompaniesApplyContinuousCorners(self.heroSearchChromeView, CGRectGetHeight(self.heroSearchChromeView.bounds) * 0.5);
    self.heroSearchChromeView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.heroSearchChromeView.bounds
                                   cornerRadius:CGRectGetHeight(self.heroSearchChromeView.bounds) * 0.5].CGPath;
    self.heroLayoutToggleButton.layer.cornerRadius = CGRectGetWidth(self.heroLayoutToggleButton.bounds) * 0.5;
   
    PPProviderCompaniesApplyContinuousCorners(self.heroProofRailView, CGRectGetHeight(self.heroProofRailView.bounds) * 0.5);
    PPProviderCompaniesApplyContinuousCorners(self.heroTitleCountBadgeLabel,
                                             CGRectGetHeight(self.heroTitleCountBadgeLabel.bounds) * 0.5);
    self.heroTitleCountBadgeLabel.layer.shadowPath = nil;
    PPProviderCompaniesApplyContinuousCorners(self.heroTrailIconPlateView, 20.0);
    self.heroTrailIconPlateView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.heroTrailIconPlateView.bounds
                                   cornerRadius:20.0].CGPath;
}

- (void)viewSafeAreaInsetsDidChange
{
    [super viewSafeAreaInsetsDidChange];
    [self pp_updateBottomNavigationInsetsIfNeeded];
    [self pp_updatePinnedHeroForCurrentScrollPosition];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if (![self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            return;
        }
    }
    [self pp_applyHeroMaterialPalette];
}

- (void)pp_buildUI
{
    self.view.backgroundColor = AppBackgroundClr ?: [UIColor colorWithRed:0.982 green:0.976 blue:0.956 alpha:1.0];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    //self.title = PPProviderCompaniesTitleForCategoryIdentifier(self.selectedProviderCategoryIdentifier);
    self.navigationItem.hidesBackButton = YES;
    if (@available(iOS 16.0, *)) {
        self.navigationItem.backBarButtonItem.hidden = YES;
    } else {
        // Fallback on earlier versions
    }

    self.tableBackgroundMiddleGlowView = [[UIView alloc] init];
    self.tableBackgroundMiddleGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableBackgroundMiddleGlowView.userInteractionEnabled = NO;
    self.tableBackgroundMiddleGlowView.clipsToBounds = NO;
    self.tableBackgroundMiddleGlowLayer = [self pp_makeBackgroundGlowLayer];
    [self.tableBackgroundMiddleGlowView.layer insertSublayer:self.tableBackgroundMiddleGlowLayer atIndex:0];
    [self.view addSubview:self.tableBackgroundMiddleGlowView];

    self.tableBackgroundBottomGlowView = [[UIView alloc] init];
    self.tableBackgroundBottomGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableBackgroundBottomGlowView.userInteractionEnabled = NO;
    self.tableBackgroundBottomGlowView.clipsToBounds = NO;
    self.tableBackgroundBottomGlowLayer = [self pp_makeBackgroundGlowLayer];
    [self.tableBackgroundBottomGlowView.layer insertSublayer:self.tableBackgroundBottomGlowLayer atIndex:0];
    [self.view addSubview:self.tableBackgroundBottomGlowView];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 260.0;
    self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.tableFooterView = [UIView new];
    [self.tableView registerClass:PPProviderCompanyCell.class forCellReuseIdentifier:@"PPProviderCompanyCell"];
    [self.tableView registerClass:PPProviderCompanyPremiumCardCell.class
           forCellReuseIdentifier:PPProviderCompanyPremiumCardCell.reuseIdentifier];
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableBackgroundMiddleGlowView.leadingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-60.0],
        [self.tableBackgroundMiddleGlowView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:112.0],
        [self.tableBackgroundMiddleGlowView.widthAnchor constraintEqualToConstant:228.0],
        [self.tableBackgroundMiddleGlowView.heightAnchor constraintEqualToConstant:228.0],

        [self.tableBackgroundBottomGlowView.centerXAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:96.0],
        [self.tableBackgroundBottomGlowView.centerYAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-123.0],
        [self.tableBackgroundBottomGlowView.widthAnchor constraintEqualToConstant:286.0],
        [self.tableBackgroundBottomGlowView.heightAnchor constraintEqualToConstant:286.0],

        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-22]
    ]];

    [self pp_buildHeader];
    [self pp_buildHeroSearchChrome];
    [self pp_buildStateView];
}

- (void)pp_updateBottomNavigationInsetsIfNeeded
{
    if (!self.tableView) {
        return;
    }

    CGFloat bottomInset = PPProviderCompaniesBottomNavigationClearanceForController(self);
    CGFloat topInset = ceil([self pp_expandedHeroHeight] + 8.0);
    UIEdgeInsets contentInset = self.tableView.contentInset;
    UIEdgeInsets indicatorInset = self.tableView.scrollIndicatorInsets;
    CGFloat previousTopInset = contentInset.top;
    CGFloat previousRelativeOffsetY = self.tableView.contentOffset.y + previousTopInset;
    if (fabs(contentInset.bottom - bottomInset) < 0.5 &&
        fabs(indicatorInset.bottom - bottomInset) < 0.5 &&
        fabs(contentInset.top - topInset) < 0.5) {
        return;
    }

    contentInset.top = topInset;
    contentInset.bottom = bottomInset;
    indicatorInset.top = topInset;
    indicatorInset.bottom = bottomInset;
    self.tableView.contentInset = contentInset;
    self.tableView.scrollIndicatorInsets = indicatorInset;

    if (!self.heroPinnedScrollPositionApplied) {
        self.heroPinnedScrollPositionApplied = YES;
        [self.tableView setContentOffset:CGPointMake(0.0, -topInset) animated:NO];
    } else if (fabs(previousTopInset - topInset) >= 0.5) {
        CGFloat restoredRelativeOffsetY = previousRelativeOffsetY <= 8.0 ? 0.0 : previousRelativeOffsetY;
        CGPoint restoredOffset = self.tableView.contentOffset;
        restoredOffset.y = restoredRelativeOffsetY - topInset;
        if (fabs(restoredOffset.y - self.tableView.contentOffset.y) >= 0.5) {
            [self.tableView setContentOffset:restoredOffset animated:NO];
        }
    }
}

- (void)pp_buildHeader
{
    self.headerContainerView = [[UIView alloc] init];//[PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleFixed];
    self.headerContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerContainerView.backgroundColor = UIColor.clearColor;
    self.headerContainerView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.headerContainerView.clipsToBounds = NO;
    [self.view addSubview:self.headerContainerView];

    self.heroSurfaceView = [[UIView alloc] init];
    self.heroSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSurfaceView.backgroundColor = UIColor.clearColor;
    self.heroSurfaceView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    PPProviderCompaniesApplyContinuousCorners(self.heroSurfaceView, 30.0);
    self.heroSurfaceView.layer.borderWidth = 1.0;
    self.heroSurfaceView.layer.masksToBounds = NO;
    [self.heroSurfaceView pp_setShadowColor:UIColor.blackColor];
    self.heroSurfaceView.layer.shadowOpacity = 0.055;
    self.heroSurfaceView.layer.shadowRadius = 28.0;
    self.heroSurfaceView.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    [self.headerContainerView addSubview:self.heroSurfaceView];

    self.heroSurfaceGradientLayer = [CAGradientLayer layer];
    self.heroSurfaceGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.heroSurfaceGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    self.heroSurfaceGradientLayer.locations = @[@0.0, @0.55, @1.0];
    [self.heroSurfaceView.layer insertSublayer:self.heroSurfaceGradientLayer atIndex:0];

    self.heroSurfaceEdgeHighlightLayer = [CAShapeLayer layer];
    self.heroSurfaceEdgeHighlightLayer.fillColor = UIColor.clearColor.CGColor;
    self.heroSurfaceEdgeHighlightLayer.lineWidth = 0.7;

    UIBlurEffectStyle blurStyle = UIBlurEffectStyleExtraLight;
    if (@available(iOS 13.0, *)) {
        blurStyle = UIBlurEffectStyleSystemUltraThinMaterial;
    }
    self.heroFrostedMaterialView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:blurStyle]];
    self.heroFrostedMaterialView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroFrostedMaterialView.userInteractionEnabled = NO;
    self.heroFrostedMaterialView.clipsToBounds = YES;
    self.heroFrostedMaterialView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.heroSurfaceView addSubview:self.heroFrostedMaterialView];

    self.heroAmbientGlowView = [[UIView alloc] init];
    self.heroAmbientGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroAmbientGlowView.userInteractionEnabled = NO;
    self.heroAmbientGlowView.alpha = 0.0;
    self.heroAmbientGlowView.hidden = YES;
    [self.heroSurfaceView insertSubview:self.heroAmbientGlowView belowSubview:self.heroFrostedMaterialView];

    self.heroAmbientAccentView = [[UIView alloc] init];
    self.heroAmbientAccentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroAmbientAccentView.userInteractionEnabled = NO;
    self.heroAmbientAccentView.alpha = 0.0;
    self.heroAmbientAccentView.hidden = YES;
    [self.heroSurfaceView insertSubview:self.heroAmbientAccentView belowSubview:self.heroFrostedMaterialView];

    self.heroAmbientSupportView = [[UIView alloc] init];
    self.heroAmbientSupportView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroAmbientSupportView.userInteractionEnabled = NO;
    self.heroAmbientSupportView.alpha = 0.0;
    self.heroAmbientSupportView.hidden = YES;
    [self.heroSurfaceView insertSubview:self.heroAmbientSupportView belowSubview:self.heroFrostedMaterialView];

    self.heroContentContainerView = [[UIView alloc] init];
    self.heroContentContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroContentContainerView.backgroundColor = UIColor.clearColor;
    self.heroContentContainerView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.heroContentContainerView.clipsToBounds = YES;
    [self.heroSurfaceView addSubview:self.heroContentContainerView];

    self.heroEyebrowLabel = [[UILabel alloc] init];
    self.heroEyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroEyebrowLabel.font = PPProviderCompaniesScaledFont([GM boldFontWithSize:11.0], UIFontTextStyleCaption1);
    self.heroEyebrowLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.heroEyebrowLabel.numberOfLines = 1;
    self.heroEyebrowLabel.hidden = NO;
    self.heroEyebrowLabel.accessibilityElementsHidden = NO;
    [self.heroContentContainerView addSubview:self.heroEyebrowLabel];

    self.heroLayoutToggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.heroLayoutToggleButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroLayoutToggleButton.clipsToBounds = NO;
    self.heroLayoutToggleButton.accessibilityHint =
        kLang(@"provider_companies_layout_toggle_hint") ?: @"Changes the provider layout";
    [self.heroLayoutToggleButton addTarget:self
                                    action:@selector(pp_handleLayoutToggleButton)
                          forControlEvents:UIControlEventTouchUpInside];
    
    self.heroTitleLabel = [[UILabel alloc] init];
    self.heroTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTitleLabel.font = PPProviderCompaniesScaledFont([GM boldFontWithSize:26.0]
                                                             ?: [UIFont systemFontOfSize:18.0
                                                                                  weight:UIFontWeightBold],
                                                             UIFontTextStyleTitle2);
    self.heroTitleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    self.heroTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.heroTitleLabel.numberOfLines = 1;
    self.heroTitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.heroTitleLabel.adjustsFontForContentSizeCategory = YES;
    [self.heroContentContainerView addSubview:self.heroTitleLabel];

    self.heroTitleCountBadgeLabel = [[PPInsetLabel alloc] init];
    self.heroTitleCountBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTitleCountBadgeLabel.font = PPProviderCompaniesScaledFont([GM boldFontWithSize:11.0]
                                                                       ?: [UIFont systemFontOfSize:11.0
                                                                                            weight:UIFontWeightSemibold],
                                                                       UIFontTextStyleCaption1);
    self.heroTitleCountBadgeLabel.textAlignment = NSTextAlignmentCenter;
    self.heroTitleCountBadgeLabel.numberOfLines = 1;
    self.heroTitleCountBadgeLabel.adjustsFontSizeToFitWidth = YES;
    self.heroTitleCountBadgeLabel.minimumScaleFactor = 0.86;
    self.heroTitleCountBadgeLabel.adjustsFontForContentSizeCategory = YES;
    self.heroTitleCountBadgeLabel.textInsets = UIEdgeInsetsMake(3.0, 9.0, 3.0, 9.0);
    self.heroTitleCountBadgeLabel.layer.borderWidth = 0.75;
    self.heroTitleCountBadgeLabel.clipsToBounds = YES;
    self.heroTitleCountBadgeLabel.layer.masksToBounds = YES;
    [self.heroTitleCountBadgeLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                                   forAxis:UILayoutConstraintAxisHorizontal];
    [self.heroTitleCountBadgeLabel setContentHuggingPriority:UILayoutPriorityRequired
                                                     forAxis:UILayoutConstraintAxisHorizontal];
    [self.heroContentContainerView addSubview:self.heroTitleCountBadgeLabel];

    self.heroSubtitleLabel = [[UILabel alloc] init];
    self.heroSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSubtitleLabel.font = PPProviderCompaniesScaledFont([GM MidFontWithSize:12.0], UIFontTextStyleCaption1);
    self.heroSubtitleLabel.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    self.heroSubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.heroSubtitleLabel.numberOfLines = 2;
    self.heroSubtitleLabel.adjustsFontForContentSizeCategory = YES;
    self.heroSubtitleLabel.hidden = NO;
    self.heroSubtitleLabel.accessibilityElementsHidden = NO;
    [self.heroContentContainerView addSubview:self.heroSubtitleLabel];

    self.heroTrailIconPlateView = [[UIView alloc] init];
    self.heroTrailIconPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTrailIconPlateView.userInteractionEnabled = NO;
    self.heroTrailIconPlateView.accessibilityElementsHidden = YES;
    self.heroTrailIconPlateView.hidden = NO;
    self.heroTrailIconPlateView.layer.borderWidth = 1.0;
    self.heroTrailIconPlateView.layer.masksToBounds = NO;
    [self.heroTrailIconPlateView pp_setShadowColor:UIColor.blackColor];
    self.heroTrailIconPlateView.layer.shadowOpacity = 0.035;
    self.heroTrailIconPlateView.layer.shadowRadius = 12.0;
    self.heroTrailIconPlateView.layer.shadowOffset = CGSizeMake(0.0, 5.0);
    [self.heroSurfaceView addSubview:self.heroTrailIconPlateView];
    
    self.heroTrailIconView = [[UIImageView alloc] init];
    self.heroTrailIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTrailIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.heroTrailIconView.accessibilityElementsHidden = YES;
    [self.heroTrailIconPlateView addSubview:self.heroTrailIconView];

    self.heroDismissButton = [self pp_ButtonWithSystemName:@"chevron.down" action:@selector(onBack)];
    self.heroDismissButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroDismissButton.contentMode = UIViewContentModeScaleAspectFit;
    self.heroDismissButton.accessibilityElementsHidden = YES;
    [self.heroTrailIconPlateView addSubview:self.heroDismissButton];
    

    self.heroSearchChromeView = [[UIView alloc] init];
    self.heroSearchChromeView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSearchChromeView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.heroSearchChromeView.layer.borderWidth = 1.0;
    self.heroSearchChromeView.layer.masksToBounds = NO;
    PPProviderCompaniesApplyContinuousCorners(self.heroSearchChromeView, 0.0);
    [self.heroSurfaceView addSubview:self.heroSearchChromeView];
    UITapGestureRecognizer *searchChromeTap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_focusHeroSearchTextField)];
    searchChromeTap.cancelsTouchesInView = NO;
    searchChromeTap.delegate = self;
    [self.heroSearchChromeView addGestureRecognizer:searchChromeTap];

    self.heroSearchIconView = [[UIImageView alloc] init];
    self.heroSearchIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSearchIconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.heroSearchChromeView addSubview:self.heroSearchIconView];

    self.heroSearchTextField = [[UITextField alloc] init];
    self.heroSearchTextField.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSearchTextField.borderStyle = UITextBorderStyleNone;
    self.heroSearchTextField.backgroundColor = UIColor.clearColor;
    self.heroSearchTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.heroSearchTextField.returnKeyType = UIReturnKeySearch;
    self.heroSearchTextField.enablesReturnKeyAutomatically = NO;
    self.heroSearchTextField.delegate = self;
    self.heroSearchTextField.textAlignment = Language.alignmentForCurrentLanguage;
    self.heroSearchTextField.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.heroSearchTextField.font = PPProviderCompaniesScaledFont([GM MidFontWithSize:14.5], UIFontTextStyleSubheadline);
    self.heroSearchTextField.adjustsFontForContentSizeCategory = YES;
    self.heroSearchTextField.placeholder = kLang(@"provider_companies_search_placeholder") ?: @"Search providers";
    [self.heroSearchTextField addTarget:self
                                 action:@selector(pp_handleHeroSearchTextChanged:)
                       forControlEvents:UIControlEventEditingChanged];
    [self.heroSearchChromeView addSubview:self.heroSearchTextField];
    [self.heroSearchChromeView addSubview:self.heroLayoutToggleButton];

    self.heroProofRailView = [[UIView alloc] init];
    self.heroProofRailView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroProofRailView.backgroundColor = PPProviderCompaniesHeroSecondarySurfaceColor();
    self.heroProofRailView.layer.borderWidth = 0.75;
    self.heroProofRailView.layer.masksToBounds = YES;
    [self.heroProofRailView pp_setBorderColor:PPProviderCompaniesHeroStrokeColor()];
    [self.heroSurfaceView addSubview:self.heroProofRailView];

    self.heroDiscoveryScrollView = [[UIScrollView alloc] init];
    self.heroDiscoveryScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroDiscoveryScrollView.backgroundColor = UIColor.clearColor;
    self.heroDiscoveryScrollView.showsHorizontalScrollIndicator = NO;
    self.heroDiscoveryScrollView.alwaysBounceHorizontal = NO;
    self.heroDiscoveryScrollView.directionalLockEnabled = YES;
    self.heroDiscoveryScrollView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.heroProofRailView addSubview:self.heroDiscoveryScrollView];

    self.heroDiscoveryStackView = [[UIStackView alloc] init];
    self.heroDiscoveryStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroDiscoveryStackView.axis = UILayoutConstraintAxisHorizontal;
    self.heroDiscoveryStackView.alignment = UIStackViewAlignmentCenter;
    self.heroDiscoveryStackView.distribution = UIStackViewDistributionFill;
    self.heroDiscoveryStackView.spacing = 8.0;
    self.heroDiscoveryStackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.heroDiscoveryScrollView addSubview:self.heroDiscoveryStackView];

    NSMutableArray<UIButton *> *discoveryButtons = [NSMutableArray arrayWithCapacity:4];
    for (NSInteger rawMode = PPProviderCompaniesDiscoveryModeRecommended;
         rawMode <= PPProviderCompaniesDiscoveryModeNewest;
         rawMode++) {
        UIButton *button = [self pp_makeDiscoveryButtonForMode:(PPProviderCompaniesDiscoveryMode)rawMode];
        [self.heroDiscoveryStackView addArrangedSubview:button];
        [discoveryButtons addObject:button];
    }
    self.heroDiscoveryButtons = discoveryButtons.copy;


    self.heroContainerHeightConstraint = [self.headerContainerView.heightAnchor constraintEqualToConstant:0];
    self.heroSurfaceTopConstraint = [self.heroSurfaceView.topAnchor constraintEqualToAnchor:self.headerContainerView.topAnchor constant:0];
    self.heroSurfaceBottomConstraint = [self.heroSurfaceView.bottomAnchor constraintEqualToAnchor:self.headerContainerView.bottomAnchor constant:0.0];
    self.heroProofRailLeadingConstraint = [self.heroProofRailView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:0.0];
    self.heroProofRailTrailingConstraint = [self.heroProofRailView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-0.0];
    self.heroProofRailBottomConstraint = [self.heroProofRailView.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:-16.0];
    self.heroProofRailHeightConstraint = [self.heroProofRailView.heightAnchor constraintEqualToConstant:40.0];
    self.heroSearchChromeBottomConstraint = [self.heroProofRailView.topAnchor constraintEqualToAnchor:self.heroSearchChromeView.bottomAnchor constant:12.0];
    self.heroContentHeightConstraint = [self.heroContentContainerView.heightAnchor constraintEqualToConstant:[self pp_expandedHeroContentHeight]];
    self.heroDismissButton.alpha = 0;
    [NSLayoutConstraint activateConstraints:@[
        [self.headerContainerView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:0.0],
        [self.headerContainerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:0.0],
        [self.headerContainerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-0.0],
        self.heroContainerHeightConstraint,

        self.heroSurfaceTopConstraint,
        [self.heroSurfaceView.leadingAnchor constraintEqualToAnchor:self.headerContainerView.leadingAnchor constant:14.0],
        [self.heroSurfaceView.trailingAnchor constraintEqualToAnchor:self.headerContainerView.trailingAnchor constant:-14.0],
        self.heroSurfaceBottomConstraint,

        [self.heroFrostedMaterialView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor],
        [self.heroFrostedMaterialView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor],
        [self.heroFrostedMaterialView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor],
        [self.heroFrostedMaterialView.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor],

        [self.heroAmbientSupportView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:18.0],
        [self.heroAmbientSupportView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-90.0],
        [self.heroAmbientSupportView.widthAnchor constraintEqualToConstant:30.0],
        [self.heroAmbientSupportView.heightAnchor constraintEqualToConstant:30.0],

        [self.heroAmbientGlowView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:24.0],
        [self.heroAmbientGlowView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-54.0],
        [self.heroAmbientGlowView.widthAnchor constraintEqualToConstant:44.0],
        [self.heroAmbientGlowView.heightAnchor constraintEqualToConstant:44.0],

        [self.heroAmbientAccentView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:31.0],
        [self.heroAmbientAccentView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-18.0],
        [self.heroAmbientAccentView.widthAnchor constraintEqualToConstant:24.0],
        [self.heroAmbientAccentView.heightAnchor constraintEqualToConstant:24.0],

        [self.heroContentContainerView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:PPIOS26() ? PPStatusBarHeight+ 8.0 : PPStatusBarHeight + 8.0],
        [self.heroContentContainerView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:20.0],
        [self.heroContentContainerView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-20.0],
        self.heroContentHeightConstraint,

        [self.heroEyebrowLabel.topAnchor constraintEqualToAnchor:self.heroContentContainerView.topAnchor],
        [self.heroEyebrowLabel.leadingAnchor constraintEqualToAnchor:self.heroContentContainerView.leadingAnchor],
        [self.heroEyebrowLabel.trailingAnchor constraintEqualToAnchor:self.heroContentContainerView.trailingAnchor],
        [self.heroEyebrowLabel.heightAnchor constraintGreaterThanOrEqualToConstant:0.0],

        [self.heroTitleLabel.topAnchor constraintEqualToAnchor:self.heroContentContainerView.topAnchor],
        [self.heroTitleLabel.leadingAnchor constraintEqualToAnchor:self.heroContentContainerView.leadingAnchor],
        [self.heroTitleLabel.trailingAnchor constraintEqualToAnchor:self.heroContentContainerView.trailingAnchor],
        [self.heroTitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.heroContentContainerView.bottomAnchor],

        [self.heroTitleCountBadgeLabel.trailingAnchor constraintEqualToAnchor:self.heroContentContainerView.trailingAnchor],
        [self.heroTitleCountBadgeLabel.centerYAnchor constraintEqualToAnchor:self.heroTitleLabel.centerYAnchor constant:2],
        [self.heroTitleCountBadgeLabel.heightAnchor constraintGreaterThanOrEqualToConstant:24.0],
        [self.heroTitleCountBadgeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:52.0],
        [self.heroTitleCountBadgeLabel.widthAnchor constraintLessThanOrEqualToConstant:122.0],

        [self.heroSubtitleLabel.topAnchor constraintEqualToAnchor:self.heroTitleLabel.bottomAnchor constant:8.0],
        [self.heroSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.heroContentContainerView.leadingAnchor],
        [self.heroSubtitleLabel.trailingAnchor constraintEqualToAnchor:self.heroContentContainerView.trailingAnchor],
        [self.heroSubtitleLabel.heightAnchor constraintGreaterThanOrEqualToConstant:18.0],

        [self.heroTrailIconPlateView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:PPStatusBarHeight + 8.0],
        [self.heroTrailIconPlateView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-18.0],
        [self.heroTrailIconPlateView.widthAnchor constraintEqualToConstant:52.0],
        [self.heroTrailIconPlateView.heightAnchor constraintEqualToConstant:52.0],

        [self.heroTrailIconView.centerXAnchor constraintEqualToAnchor:self.heroTrailIconPlateView.centerXAnchor],
        [self.heroTrailIconView.centerYAnchor constraintEqualToAnchor:self.heroTrailIconPlateView.centerYAnchor],
        [self.heroTrailIconView.widthAnchor constraintEqualToConstant:24.0],
        [self.heroTrailIconView.heightAnchor constraintEqualToConstant:24.0],
        
        
        [self.heroDismissButton.centerXAnchor constraintEqualToAnchor:self.heroTrailIconPlateView.centerXAnchor],
        [self.heroDismissButton.centerYAnchor constraintEqualToAnchor:self.heroTrailIconPlateView.centerYAnchor],
        [self.heroDismissButton.widthAnchor constraintEqualToConstant:44.0],
        [self.heroDismissButton.heightAnchor constraintEqualToConstant:44.0],
 

        self.heroProofRailLeadingConstraint,
        self.heroProofRailTrailingConstraint,
        self.heroProofRailBottomConstraint,
        self.heroProofRailHeightConstraint,
        self.heroSearchChromeBottomConstraint,

        [self.heroSearchChromeView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:18.0],
        [self.heroSearchChromeView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-18.0],
        [self.heroSearchChromeView.heightAnchor constraintEqualToConstant:50.0],

        [self.heroSearchIconView.leadingAnchor constraintEqualToAnchor:self.heroSearchChromeView.leadingAnchor constant:15.0],
        [self.heroSearchIconView.centerYAnchor constraintEqualToAnchor:self.heroSearchChromeView.centerYAnchor],
        [self.heroSearchIconView.widthAnchor constraintEqualToConstant:18.0],
        [self.heroSearchIconView.heightAnchor constraintEqualToConstant:18.0],

        [self.heroLayoutToggleButton.trailingAnchor constraintEqualToAnchor:self.heroSearchChromeView.trailingAnchor constant:-4.0],
        [self.heroLayoutToggleButton.centerYAnchor constraintEqualToAnchor:self.heroSearchChromeView.centerYAnchor],
        [self.heroLayoutToggleButton.widthAnchor constraintEqualToConstant:40.0],
        [self.heroLayoutToggleButton.heightAnchor constraintEqualToConstant:40.0],

        [self.heroSearchTextField.leadingAnchor constraintEqualToAnchor:self.heroSearchIconView.trailingAnchor constant:9.0],
        [self.heroSearchTextField.trailingAnchor constraintEqualToAnchor:self.heroLayoutToggleButton.leadingAnchor constant:-7.0],
        [self.heroSearchTextField.topAnchor constraintEqualToAnchor:self.heroSearchChromeView.topAnchor constant:6.0],
        [self.heroSearchTextField.bottomAnchor constraintEqualToAnchor:self.heroSearchChromeView.bottomAnchor constant:-6.0],

        [self.heroDiscoveryScrollView.topAnchor constraintEqualToAnchor:self.heroProofRailView.topAnchor constant:3.0],
        [self.heroDiscoveryScrollView.leadingAnchor constraintEqualToAnchor:self.heroProofRailView.leadingAnchor constant:3.0],
        [self.heroDiscoveryScrollView.trailingAnchor constraintEqualToAnchor:self.heroProofRailView.trailingAnchor constant:-3.0],
        [self.heroDiscoveryScrollView.bottomAnchor constraintEqualToAnchor:self.heroProofRailView.bottomAnchor constant:-3.0],

        [self.heroDiscoveryStackView.topAnchor constraintEqualToAnchor:self.heroDiscoveryScrollView.contentLayoutGuide.topAnchor],
        [self.heroDiscoveryStackView.leadingAnchor constraintEqualToAnchor:self.heroDiscoveryScrollView.contentLayoutGuide.leadingAnchor],
        [self.heroDiscoveryStackView.trailingAnchor constraintEqualToAnchor:self.heroDiscoveryScrollView.contentLayoutGuide.trailingAnchor],
        [self.heroDiscoveryStackView.bottomAnchor constraintEqualToAnchor:self.heroDiscoveryScrollView.contentLayoutGuide.bottomAnchor],
        [self.heroDiscoveryStackView.heightAnchor constraintEqualToAnchor:self.heroDiscoveryScrollView.frameLayoutGuide.heightAnchor],
        [self.heroDiscoveryStackView.widthAnchor constraintGreaterThanOrEqualToAnchor:self.heroDiscoveryScrollView.frameLayoutGuide.widthAnchor],
    ]];

    [self pp_updateDiscoveryButtonAppearances];
    [self pp_updateLayoutToggleAppearanceAnimated:NO];
    [self pp_applyHeroMaterialPalette];
    [self pp_hideDecorativeHeroContent];
    [self pp_applyHeroCollapseProgress:0.0 animated:NO];
}

- (void)pp_alignDiscoveryRailForCurrentLanguageIfNeeded
{
    if (self.heroDiscoveryInitialOffsetApplied || !self.heroDiscoveryScrollView) {
        return;
    }

    [self.heroDiscoveryScrollView layoutIfNeeded];
    [self.heroDiscoveryStackView layoutIfNeeded];

    CGFloat visibleWidth = CGRectGetWidth(self.heroDiscoveryScrollView.bounds);
    CGFloat contentWidth = MAX(self.heroDiscoveryScrollView.contentSize.width,
                               CGRectGetMaxX(self.heroDiscoveryStackView.frame));
    if (visibleWidth <= 1.0 || contentWidth <= 1.0) {
        return;
    }

    UIEdgeInsets adjustedInsets = self.heroDiscoveryScrollView.contentInset;
    if (@available(iOS 11.0, *)) {
        adjustedInsets = self.heroDiscoveryScrollView.adjustedContentInset;
    }

    self.heroDiscoveryInitialOffsetApplied = YES;
    CGFloat maxOffsetX = MAX(-adjustedInsets.left, contentWidth - visibleWidth + adjustedInsets.right);
    CGFloat offsetX = Language.isRTL ? maxOffsetX : -adjustedInsets.left;
    [self.heroDiscoveryScrollView setContentOffset:CGPointMake(offsetX, -adjustedInsets.top) animated:NO];
}

- (void)pp_applyDiscoveryAppearanceToButton:(UIButton *)button
{
    PPProviderCompaniesDiscoveryMode mode = (PPProviderCompaniesDiscoveryMode)button.tag;
    BOOL selected = (mode == self.selectedDiscoveryMode);
    BOOL highlighted = button.highlighted;
    UIColor *accent = AppPrimaryClr ?: UIColor.systemRedColor;
    UIColor *foreground = selected
        ? accent
        : [AppPrimaryTextClr ?: UIColor.labelColor colorWithAlphaComponent:0.64];
    UIColor *background = selected
        ? [accent colorWithAlphaComponent:(highlighted ? 0.15 : 0.10)]
        : ([AppForgroundColr colorWithAlphaComponent:(highlighted ? 0.86 : 0.64)]
           ?: PPProviderCompaniesHeroSecondarySurfaceColor());
    UIColor *stroke = selected
        ? [accent colorWithAlphaComponent:0.24]
        : [[UIColor whiteColor] colorWithAlphaComponent:(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.18 : 0.66)];

    UIFont *discoveryFont = PPProviderCompaniesScaledFont(
        selected ? [GM boldFontWithSize:11.5] : [GM MidFontWithSize:11.5],
        UIFontTextStyleCaption1
    );
    UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
    configuration.title = PPProviderCompaniesDiscoveryTitle(mode);
    configuration.image =
        [[UIImage systemImageNamed:PPProviderCompaniesDiscoverySymbol(mode)
                 withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11.5
                                                                                   weight:selected ? UIImageSymbolWeightBold : UIImageSymbolWeightSemibold]]
         imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    configuration.imagePlacement = NSDirectionalRectEdgeLeading;
    configuration.imagePadding = 3.5;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(5.0, 9.0, 5.0, 9.0);
    configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    configuration.baseForegroundColor = foreground;
    configuration.baseBackgroundColor = background;
    configuration.background.backgroundColor = background;
    configuration.background.strokeColor = stroke;
    configuration.background.strokeWidth = selected ? 1.0 : 0.65;
    UIFont *finalDiscoveryFont = discoveryFont;
    configuration.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey,id> * _Nonnull(NSDictionary<NSAttributedStringKey,id> * _Nonnull incoming) {
        NSMutableDictionary *attrs = [incoming mutableCopy];
        attrs[NSFontAttributeName] = finalDiscoveryFont;
        return attrs;
    };
    button.configuration = configuration;
    button.layer.shadowColor = accent.CGColor;
    button.layer.shadowOpacity = selected ? 0.08 : 0.0;
    button.layer.shadowRadius = selected ? 6.0 : 0.0;
    button.layer.shadowOffset = selected ? CGSizeMake(0.0, 2.0) : CGSizeZero;
    button.transform = highlighted && !UIAccessibilityIsReduceMotionEnabled()
        ? CGAffineTransformMakeScale(0.975, 0.975)
        : CGAffineTransformIdentity;
    button.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);
}

- (UIButton *)pp_makeDiscoveryButtonForMode:(PPProviderCompaniesDiscoveryMode)mode
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tag = mode;
    button.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    button.adjustsImageWhenHighlighted = NO;
    button.accessibilityLabel = PPProviderCompaniesDiscoveryTitle(mode);
    button.accessibilityHint = kLang(@"provider_companies_discovery_hint") ?: @"Changes how providers are shown";
    [button setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [button setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [button.heightAnchor constraintEqualToConstant:32.0].active = YES;
    [button addTarget:self action:@selector(pp_handleDiscoveryButton:) forControlEvents:UIControlEventTouchUpInside];

    __weak typeof(self) weakSelf = self;
    button.configurationUpdateHandler = ^(UIButton *updatedButton) {
        [weakSelf pp_applyDiscoveryAppearanceToButton:updatedButton];
    };
    [self pp_applyDiscoveryAppearanceToButton:button];
    return button;
}

- (void)pp_updateDiscoveryButtonAppearances
{
    for (UIButton *button in self.heroDiscoveryButtons) {
        button.selected = ((PPProviderCompaniesDiscoveryMode)button.tag == self.selectedDiscoveryMode);
        [button setNeedsUpdateConfiguration];
        [self pp_applyDiscoveryAppearanceToButton:button];
    }
}

- (void)pp_handleDiscoveryButton:(UIButton *)button
{
    PPProviderCompaniesDiscoveryMode mode = (PPProviderCompaniesDiscoveryMode)button.tag;
    if (mode == self.selectedDiscoveryMode) {
        return;
    }

    self.selectedDiscoveryMode = mode;
    [self pp_updateDiscoveryButtonAppearances];

    UISelectionFeedbackGenerator *feedback = [[UISelectionFeedbackGenerator alloc] init];
    [feedback prepare];
    [feedback selectionChanged];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self pp_applySearchFilter];
        return;
    }

    [UIView transitionWithView:self.tableView
                      duration:0.24
                       options:UIViewAnimationOptionTransitionCrossDissolve |
                               UIViewAnimationOptionAllowUserInteraction |
                               UIViewAnimationOptionBeginFromCurrentState
                    animations:^{
        [self pp_applySearchFilter];
    } completion:nil];
}

- (void)pp_handleLayoutToggleButton
{
    self.prefersCompactListLayout = !self.prefersCompactListLayout;
    [self pp_updateLayoutToggleAppearanceAnimated:YES];
    [self pp_applyHeaderContent];

    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
    [feedback prepare];
    [feedback impactOccurred];

    self.animatedCompanyCellKeys = [NSMutableSet set];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        [UIView performWithoutAnimation:^{
            [self.tableView reloadData];
            [self.tableView layoutIfNeeded];
        }];
        return;
    }

    [self.tableView.layer removeAllAnimations];
    UIView *outgoingSnapshot = [self.tableView snapshotViewAfterScreenUpdates:NO];
    outgoingSnapshot.frame = self.tableView.frame;
    outgoingSnapshot.userInteractionEnabled = NO;
    if (outgoingSnapshot) {
        [self.view insertSubview:outgoingSnapshot aboveSubview:self.tableView];
    }

    self.tableView.alpha = 0.0;
    self.tableView.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
    [UIView performWithoutAnimation:^{
        [self.tableView reloadData];
        [self.tableView layoutIfNeeded];
    }];

    [UIView animateWithDuration:0.18
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut |
                                UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        outgoingSnapshot.alpha = 0.0;
        outgoingSnapshot.transform =
            CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -6.0),
                                    CGAffineTransformMakeScale(0.996, 0.996));
    } completion:^(__unused BOOL finished) {
        [outgoingSnapshot removeFromSuperview];
    }];

    [UIView animateWithDuration:0.36
                          delay:0.04
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.tableView.alpha = 1.0;
        self.tableView.transform = CGAffineTransformIdentity;
    } completion:^(__unused BOOL finished) {
        self.tableView.alpha = 1.0;
        self.tableView.transform = CGAffineTransformIdentity;
    }];
}

- (void)pp_updateLayoutToggleAppearanceAnimated:(BOOL)animated
{
    UIColor *accent = AppPrimaryClr ?: UIColor.systemRedColor;
    UIColor *backgroundColor = self.prefersCompactListLayout
        ? [accent colorWithAlphaComponent:0.12]
        : PPProviderCompaniesHeroSurfaceColor();
    UIColor *strokeColor = self.prefersCompactListLayout
        ? [accent colorWithAlphaComponent:0.28]
        : PPProviderCompaniesHeroStrokeColor();
    UIColor *foregroundColor = self.prefersCompactListLayout
        ? accent
        : [AppPrimaryTextClr ?: UIColor.labelColor colorWithAlphaComponent:0.74];
    NSString *symbolName = self.prefersCompactListLayout ? @"square.grid.2x2.fill" : @"rectangle.grid.1x2.fill";
    NSString *accessibilityLabel = self.prefersCompactListLayout
        ? (kLang(@"provider_companies_layout_toggle_grid") ?: @"Show premium cards")
        : (kLang(@"provider_companies_layout_toggle_list") ?: @"Show compact list");

    void (^changes)(void) = ^{
        self.heroLayoutToggleButton.backgroundColor = backgroundColor;
        self.heroLayoutToggleButton.layer.borderWidth = 0.2;
        [self.heroLayoutToggleButton pp_setBorderColor:strokeColor];
        self.heroLayoutToggleButton.layer.shadowColor = UIColor.blackColor.CGColor;
        self.heroLayoutToggleButton.layer.shadowOpacity = 0.06;
        self.heroLayoutToggleButton.layer.shadowRadius = 10.0;
        self.heroLayoutToggleButton.layer.shadowOffset = CGSizeMake(0.0, 5.0);
        self.heroLayoutToggleButton.tintColor = foregroundColor;
        [self.heroLayoutToggleButton setImage:[[UIImage systemImageNamed:symbolName
                                                        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14.0
                                                                                                                          weight:UIImageSymbolWeightMedium scale:UIImageSymbolScaleDefault]]
                                            imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                                  forState:UIControlStateNormal];
        self.heroLayoutToggleButton.accessibilityLabel = accessibilityLabel;
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        changes();
    } else {
        self.heroLayoutToggleButton.transform = CGAffineTransformMakeScale(0.92, 0.92);
        [UIView animateWithDuration:0.34
                              delay:0.0
             usingSpringWithDamping:0.82
              initialSpringVelocity:0.16
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            changes();
            self.heroLayoutToggleButton.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

- (void)pp_focusHeroSearchTextField
{
    [self.heroSearchTextField becomeFirstResponder];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if ([touch.view isDescendantOfView:self.heroLayoutToggleButton]) {
        return NO;
    }
    return YES;
}

- (void)pp_buildStateView
{
    self.stateContainerView = [[UIView alloc] init];
    self.stateContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.stateContainerView.hidden = YES;
    [self.view addSubview:self.stateContainerView];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10.0;
    stack.alignment = UIStackViewAlignmentCenter;
    [self.stateContainerView addSubview:stack];

    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.color = AppPrimaryClr ?: UIColor.systemRedColor;
    [stack addArrangedSubview:self.loadingIndicator];

    self.stateIconView = [[UIImageView alloc] init];
    self.stateIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.stateIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.stateIconView.tintColor = [AppPrimaryTextClr ?: [UIColor colorWithWhite:0.10 alpha:1.0] colorWithAlphaComponent:0.72];
    [self.stateIconView.widthAnchor constraintEqualToConstant:42.0].active = YES;
    [self.stateIconView.heightAnchor constraintEqualToConstant:42.0].active = YES;
    [stack addArrangedSubview:self.stateIconView];

    self.stateTitleLabel = [[UILabel alloc] init];
    self.stateTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.stateTitleLabel.font = [GM boldFontWithSize:22.0] ?: [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold];
    self.stateTitleLabel.textColor = AppPrimaryTextClr ?: [UIColor colorWithWhite:0.10 alpha:1.0];
    self.stateTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.stateTitleLabel.numberOfLines = 2;
    [stack addArrangedSubview:self.stateTitleLabel];

    self.stateSubtitleLabel = [[UILabel alloc] init];
    self.stateSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.stateSubtitleLabel.font = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    self.stateSubtitleLabel.textColor = AppSecondaryTextClr ?: [UIColor colorWithWhite:0.42 alpha:1.0];
    self.stateSubtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.stateSubtitleLabel.numberOfLines = 3;
    [stack addArrangedSubview:self.stateSubtitleLabel];

    self.retryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.retryButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.retryButton.backgroundColor = AppPrimaryClr ?: UIColor.systemRedColor;
    self.retryButton.layer.cornerRadius = 16.0;
    self.retryButton.layer.masksToBounds = YES;
    self.retryButton.titleLabel.font = [GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    [self.retryButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.retryButton.contentEdgeInsets = UIEdgeInsetsMake(12.0, 18.0, 12.0, 18.0);
    [self.retryButton addTarget:self action:@selector(pp_handleRetryTap) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:self.retryButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.stateContainerView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.stateContainerView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:32.0],
        [self.stateContainerView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:28.0],
        [self.stateContainerView.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-28.0],

        [stack.topAnchor constraintEqualToAnchor:self.stateContainerView.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:self.stateContainerView.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:self.stateContainerView.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:self.stateContainerView.bottomAnchor]
    ]];
}

- (void)pp_buildHeroSearchChrome
{
    self.navigationItem.searchController = nil;
    self.navigationItem.rightBarButtonItem = nil;
    self.definesPresentationContext = YES;
    [self pp_applyPremiumSearchChromeAppearanceFocused:NO animated:NO];
}

- (void)pp_dismissHeroSearchChromeAndClear:(BOOL)clearQuery
{
    if (clearQuery) {
        self.heroSearchTextField.text = @"";
        self.searchQuery = @"";
        [self pp_applySearchFilter];
    }

    self.searchChromeFocused = NO;
    if ([self.heroSearchTextField isFirstResponder]) {
        [self.heroSearchTextField resignFirstResponder];
    }
    self.navigationItem.searchController = nil;
    self.navigationItem.rightBarButtonItem = nil;
    [self pp_applyPremiumSearchChromeAppearanceFocused:NO animated:YES];
    [self pp_updatePinnedHeroForCurrentScrollPosition];
}

- (void)pp_applyPremiumSearchChromeAppearanceFocused:(BOOL)focused animated:(BOOL)animated
{
    if (!self.heroSearchChromeView || !self.heroSearchTextField) {
        return;
    }

    self.heroSearchChromeView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.heroSearchTextField.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.heroSearchTextField.textAlignment = Language.alignmentForCurrentLanguage;

    void (^applyBlock)(void) = ^{
        UIColor *accent = AppPrimaryClr ?: UIColor.systemRedColor;
        UIColor *surfaceColor = focused
            ? PPProviderCompaniesHeroSurfaceColor()
            : [PPProviderCompaniesHeroSecondarySurfaceColor() colorWithAlphaComponent:0.98];
        UIColor *strokeColor = focused
            ? [accent colorWithAlphaComponent:0.28]
            : PPProviderCompaniesHeroStrokeColor();

        self.heroSearchChromeView.transform = focused && !UIAccessibilityIsReduceMotionEnabled()
            ? CGAffineTransformMakeScale(1.008, 1.008)
            : CGAffineTransformIdentity;
        self.heroSearchChromeView.backgroundColor = surfaceColor;
        [self.heroSearchChromeView pp_setBorderColor:strokeColor];
        self.heroSearchChromeView.layer.shadowColor = UIColor.blackColor.CGColor;
        self.heroSearchChromeView.layer.shadowOpacity = focused ? 0.062 : 0.032;
        self.heroSearchChromeView.layer.shadowRadius = focused ? 13.0 : 9.0;
        self.heroSearchChromeView.layer.shadowOffset = CGSizeMake(0.0, focused ? 6.0 : 3.0);

        self.heroSearchTextField.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
        self.heroSearchTextField.tintColor = accent;
        self.heroSearchTextField.font = PPProviderCompaniesScaledFont([GM MidFontWithSize:14.5], UIFontTextStyleSubheadline);
        self.heroSearchTextField.attributedPlaceholder =
            [[NSAttributedString alloc] initWithString:(self.heroSearchTextField.placeholder ?: @"")
                                            attributes:@{
                NSForegroundColorAttributeName: [AppSecondaryTextClr ?: UIColor.secondaryLabelColor colorWithAlphaComponent:(focused ? 0.76 : 0.62)],
                NSFontAttributeName: PPProviderCompaniesScaledFont([GM MidFontWithSize:14.5], UIFontTextStyleSubheadline)
            }];

        self.heroSearchIconView.tintColor = focused
            ? accent
            : [AppSecondaryTextClr ?: UIColor.secondaryLabelColor colorWithAlphaComponent:0.72];
        if (@available(iOS 13.0, *)) {
            self.heroSearchIconView.image =
                [[UIImage systemImageNamed:@"magnifyingglass"
                         withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15.5
                                                                                           weight:focused ? UIImageSymbolWeightBold : UIImageSymbolWeightSemibold]]
                 imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        applyBlock();
        return;
    }

    [UIView animateWithDuration:focused ? 0.20 : 0.24
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:applyBlock
                     completion:nil];
}

- (void)pp_prepareHeroEntranceIfNeeded
{
    if (self.heroEntranceCompleted || self.heroEntrancePrepared || !self.heroSurfaceView) {
        return;
    }

    self.heroEntrancePrepared = YES;
    self.heroSurfaceView.alpha = 0.0;
    self.heroSurfaceView.transform = CGAffineTransformMakeScale(1.016, 1.016);
    self.heroAmbientGlowView.alpha = 0.0;
    self.heroAmbientAccentView.alpha = 0.0;
    self.heroAmbientSupportView.alpha = 0.0;
    self.heroAmbientGlowView.transform = CGAffineTransformMakeScale(0.96, 0.96);
    self.heroAmbientAccentView.transform = CGAffineTransformMakeScale(0.96, 0.96);
    self.heroAmbientSupportView.transform = CGAffineTransformMakeScale(0.96, 0.96);
    self.heroContentContainerView.alpha = 0.0;
    self.heroContentContainerView.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
    self.heroTrailIconPlateView.alpha = 0.0;
    self.heroTrailIconPlateView.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    self.heroSearchChromeView.alpha = 0.0;
    self.heroSearchChromeView.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    self.heroProofRailView.alpha = 0.0;
    self.heroProofRailView.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    [self pp_hideDecorativeHeroContent];
}

- (void)pp_runHeroEntranceIfNeeded
{
    if (self.heroEntranceCompleted || !self.heroEntrancePrepared) {
        return;
    }

    self.heroEntranceCompleted = YES;
    [self.view layoutIfNeeded];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        for (UIView *view in @[self.heroSurfaceView,
                               self.heroAmbientGlowView,
                               self.heroAmbientAccentView,
                               self.heroAmbientSupportView,
                               self.heroContentContainerView,
                               self.heroTrailIconPlateView,
                               self.heroSearchChromeView,
                               self.heroProofRailView]) {
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        }
        [self pp_hideDecorativeHeroContent];
        return;
    }

    [UIView animateWithDuration:0.42
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroSurfaceView.alpha = 1.0;
        self.heroSurfaceView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.28
                          delay:0.04
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroAmbientSupportView.alpha = 1.0;
        self.heroAmbientSupportView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.30
                          delay:0.10
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroAmbientGlowView.alpha = 1.0;
        self.heroAmbientGlowView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.26
                          delay:0.16
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroAmbientAccentView.alpha = 1.0;
        self.heroAmbientAccentView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.38
                          delay:0.08
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.heroContentContainerView.alpha = 1.0;
        self.heroContentContainerView.transform = CGAffineTransformIdentity;
        self.heroTrailIconPlateView.alpha = 1.0;
        self.heroTrailIconPlateView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.34
                          delay:0.12
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.heroSearchChromeView.alpha = 1.0;
        self.heroSearchChromeView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.42
                          delay:0.18
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.heroProofRailView.alpha = 1.0;
        self.heroProofRailView.transform = CGAffineTransformIdentity;
    } completion:^(__unused BOOL finished) {
        [self pp_hideDecorativeHeroContent];
    }];
}

- (void)pp_startHeroAmbientMotionIfNeeded
{
    [self pp_hideDecorativeHeroContent];
    [self pp_stopHeroAmbientMotion];
    if (UIAccessibilityIsReduceMotionEnabled() || !self.heroEntranceCompleted || !self.view.window) {
        return;
    }

    self.heroAmbientMotionStarted = YES;
    UIUserInterfaceLayoutDirection layoutDirection =
        [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:self.heroSurfaceView.semanticContentAttribute];
    CGFloat trailingTravel = layoutDirection == UIUserInterfaceLayoutDirectionRightToLeft ? -6.0 : 6.0;

    [self pp_addHeroAmbientSequenceToView:self.heroAmbientSupportView
                                    delay:0.00
                                   travel:trailingTravel * 0.90
                               scaleDelta:0.030
                             opacityFloor:0.70
                                      key:@"PPProviderCompaniesHeroAmbientSupportLine"];
    [self pp_addHeroAmbientSequenceToView:self.heroAmbientGlowView
                                    delay:0.20
                                   travel:trailingTravel
                               scaleDelta:0.040
                             opacityFloor:0.76
                                      key:@"PPProviderCompaniesHeroAmbientGlowLine"];
    [self pp_addHeroAmbientSequenceToView:self.heroAmbientAccentView
                                    delay:0.40
                                   travel:trailingTravel * 1.10
                               scaleDelta:0.048
                             opacityFloor:0.82
                                      key:@"PPProviderCompaniesHeroAmbientAccentLine"];
}

- (CAGradientLayer *)pp_makeBackgroundGlowLayer
{
    CAGradientLayer *layer = [CAGradientLayer layer];
    layer.startPoint = CGPointMake(0.5, 0.5);
    layer.endPoint = CGPointMake(1.0, 1.0);
    layer.locations = @[@0.0, @0.44, @1.0];
    layer.drawsAsynchronously = YES;
    if (@available(iOS 12.0, *)) {
        layer.type = kCAGradientLayerRadial;
    }
    return layer;
}

- (void)pp_applyBackgroundGlowColor:(UIColor *)color
                               view:(UIView *)view
                      gradientLayer:(CAGradientLayer *)gradientLayer
                          peakAlpha:(CGFloat)peakAlpha
{
    if (!view || !gradientLayer) {
        return;
    }

    UIColor *safeColor = color ?: UIColor.clearColor;
    UIColor *resolvedColor = safeColor;
    if (@available(iOS 13.0, *)) {
        resolvedColor = [safeColor resolvedColorWithTraitCollection:self.traitCollection];
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    view.backgroundColor = UIColor.clearColor;
    view.layer.shadowOpacity = 0.0;
    gradientLayer.hidden = NO;
    gradientLayer.colors = @[
        (__bridge id)[resolvedColor colorWithAlphaComponent:peakAlpha].CGColor,
        (__bridge id)[resolvedColor colorWithAlphaComponent:peakAlpha].CGColor,
        (__bridge id)[resolvedColor colorWithAlphaComponent:peakAlpha].CGColor
    ];
    [CATransaction commit];
}

- (void)pp_addHeroAmbientSequenceToView:(UIView *)view
                                  delay:(CFTimeInterval)delay
                                 travel:(CGFloat)travel
                             scaleDelta:(CGFloat)scaleDelta
                           opacityFloor:(CGFloat)opacityFloor
                                    key:(NSString *)key
{
    if (!view || key.length == 0) {
        return;
    }

    CFTimeInterval duration = 4.6;
    CFTimeInterval beginTime = CACurrentMediaTime() + delay;

    CAKeyframeAnimation *translation = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    translation.values = @[@0.0, @(travel * 0.52), @(travel), @(travel * 0.34), @0.0];
    translation.keyTimes = @[@0.0, @0.30, @0.54, @0.78, @1.0];

    CAKeyframeAnimation *scale = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    scale.values = @[@1.0, @(1.0 + scaleDelta), @1.0];
    scale.keyTimes = @[@0.0, @0.52, @1.0];

    CAKeyframeAnimation *opacity = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    opacity.values = @[@1.0, @(opacityFloor), @1.0];
    opacity.keyTimes = @[@0.0, @0.52, @1.0];

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[translation, scale, opacity];
    group.duration = duration;
    group.beginTime = beginTime;
    group.repeatCount = HUGE_VALF;
    group.removedOnCompletion = NO;
    group.fillMode = kCAFillModeBoth;
    [view.layer addAnimation:group forKey:key];
}

- (void)pp_stopHeroAmbientMotion
{
    self.heroAmbientMotionStarted = NO;
    [self.heroAmbientSupportView.layer removeAnimationForKey:@"PPProviderCompaniesHeroAmbientSupportLine"];
    [self.heroAmbientGlowView.layer removeAnimationForKey:@"PPProviderCompaniesHeroAmbientGlowLine"];
    [self.heroAmbientAccentView.layer removeAnimationForKey:@"PPProviderCompaniesHeroAmbientAccentLine"];
}


- (CGFloat)pp_expandedHeroHeight
{
    CGFloat contentHeight = [self pp_expandedHeroContentHeight];
    CGFloat requiredHeight =
        PPStatusBarHeight +
    (PPIOS26() ? 0 : 18.0) +  // content top inset below status bar
        contentHeight +

    50.0 +  // search chrome
        12.0 +  // search to discovery rail
        40.0 +  // discovery rail
        16.0;   // discovery rail bottom inset
    return ceil(MAX(250.0, requiredHeight));
}

- (CGFloat)pp_expandedHeroContentHeight
{
    BOOL accessibilityCategory =
        UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
    return accessibilityCategory ? 92.0 : 72.0;
}

- (CGFloat)pp_collapsedHeroHeight
{
    return [self pp_expandedHeroHeight];
}

- (CGFloat)pp_heroCollapseDistance
{
    return MAX(1.0, [self pp_expandedHeroHeight] - [self pp_collapsedHeroHeight]);
}

- (void)pp_applyHeroCollapseProgress:(CGFloat)progress animated:(BOOL)animated
{
    progress = MAX(0.0, MIN(1.0, progress));
    if (progress < 0.012) {
        progress = 0.0;
    } else if (progress > 0.988) {
        progress = 1.0;
    }
    _heroCollapseProgress = progress;

    CGFloat currentHeight = [self pp_expandedHeroHeight];
    CGFloat topInset = 0.0;
    CGFloat bottomInset = 0.0;
    CGFloat railSideInset = 18.0;
    CGFloat railBottomInset = 16.0;
    CGFloat railHeight = 40.0;
    CGFloat searchRailGap = 12.0;
    CGFloat contentHeight = [self pp_expandedHeroContentHeight];
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    CGFloat surfaceShadowOpacity = dark ? 0.16 : 0.060;
    CGFloat surfaceShadowRadius = dark ? 28.0 : 24.0;
    CGFloat surfaceShadowY = 14.0;
    CGFloat contentAlpha = 1.0;
    CGFloat eyebrowAlpha = 0.0;
    CGFloat titleAlpha = 1.0;
    CGFloat titleBadgeAlpha = 0.0;
    CGFloat subtitleAlpha = 1.0;
    CGFloat metricsAlpha = 0.0;
    CGFloat layoutToggleScale = 1.0;
    CGFloat searchScale = self.searchChromeFocused ? 1.008 : 1.0;
    CGFloat proofRailScale = 1.0;
    CGFloat ambientAlpha = self.heroEntranceCompleted ? 1.0 : 0.0;

    void (^updates)(void) = ^{
        self.heroContainerHeightConstraint.constant = currentHeight;
        self.heroSurfaceTopConstraint.constant = topInset;
        self.heroSurfaceBottomConstraint.constant = bottomInset;
        self.heroContentHeightConstraint.constant = contentHeight;
        self.heroProofRailLeadingConstraint.constant = railSideInset;
        self.heroProofRailTrailingConstraint.constant = -railSideInset;
        self.heroProofRailBottomConstraint.constant = -railBottomInset;
        self.heroProofRailHeightConstraint.constant = railHeight;
        self.heroSearchChromeBottomConstraint.constant = searchRailGap;

        self.heroSurfaceView.layer.shadowOpacity = surfaceShadowOpacity;
        self.heroSurfaceView.layer.shadowRadius = surfaceShadowRadius;
        self.heroSurfaceView.layer.shadowOffset = CGSizeMake(0.0, surfaceShadowY);

        self.heroContentContainerView.alpha = contentAlpha;
        self.heroEyebrowLabel.alpha = eyebrowAlpha;
        self.heroTitleLabel.alpha = titleAlpha;
        self.heroTitleCountBadgeLabel.alpha = titleBadgeAlpha;
        self.heroSubtitleLabel.alpha = subtitleAlpha;
        self.heroTrailIconPlateView.alpha = contentAlpha;
         self.heroAmbientGlowView.alpha = ambientAlpha;
        self.heroAmbientAccentView.alpha = ambientAlpha;
        self.heroAmbientSupportView.alpha = ambientAlpha;
        self.heroContentContainerView.transform = CGAffineTransformIdentity;
        self.heroTrailIconPlateView.transform = CGAffineTransformIdentity;
        self.heroAmbientGlowView.transform = CGAffineTransformIdentity;
        self.heroAmbientAccentView.transform = CGAffineTransformIdentity;
        self.heroAmbientSupportView.transform = CGAffineTransformIdentity;
        self.heroLayoutToggleButton.transform = UIAccessibilityIsReduceMotionEnabled()
            ? CGAffineTransformIdentity
            : CGAffineTransformMakeScale(layoutToggleScale, layoutToggleScale);
        self.heroProofRailView.alpha = 1.0;
        self.heroProofRailView.transform = UIAccessibilityIsReduceMotionEnabled()
            ? CGAffineTransformIdentity
            : CGAffineTransformMakeScale(proofRailScale, proofRailScale);
        self.heroSearchChromeView.alpha = 1.0;
        self.heroSearchChromeView.transform = UIAccessibilityIsReduceMotionEnabled()
            ? CGAffineTransformIdentity
            : CGAffineTransformMakeScale(searchScale, searchScale);
        [self.view layoutIfNeeded];
        [self pp_updateHeroSurfaceGeometry];
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        self.applyingHeroCollapseLayout = YES;
        updates();
        self.applyingHeroCollapseLayout = NO;
    } else {
        self.applyingHeroCollapseLayout = YES;
        [UIView animateWithDuration:0.32
                              delay:0.0
             usingSpringWithDamping:0.92
              initialSpringVelocity:0.12
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                         animations:updates
                         completion:^(BOOL finished) {
            self.applyingHeroCollapseLayout = NO;
        }];
    }

    self.heroCollapsed = (progress >= 1.0);
}

- (void)pp_updatePinnedHeroForCurrentScrollPosition
{
    if (self.applyingHeroCollapseLayout || !self.tableView || !self.heroContainerHeightConstraint) {
        return;
    }

    CGFloat topInset = self.tableView.adjustedContentInset.top;
    CGFloat offset = self.tableView.contentOffset.y + topInset;
    CGFloat collapseDistance = [self pp_heroCollapseDistance];
    CGFloat snapThreshold = collapseDistance * 0.12;
    if (offset <= snapThreshold) {
        offset = 0.0;
    }
    CGFloat progress = offset <= 0.0 ? 0.0 : MIN(1.0, offset / collapseDistance);
    if (self.searchChromeFocused) {
        progress = 1.0;
    }
    [self pp_applyHeroCollapseProgress:progress animated:NO];
}

- (void)pp_hideDecorativeHeroContent
{
    self.heroEyebrowLabel.hidden = YES;
    self.heroEyebrowLabel.accessibilityElementsHidden = YES;
    self.heroSubtitleLabel.hidden = NO;
    self.heroSubtitleLabel.accessibilityElementsHidden = NO;
    self.heroTrailIconPlateView.hidden = NO;
    self.heroTrailIconPlateView.accessibilityElementsHidden = NO;
 
    self.heroContentContainerView.hidden = NO;
    self.heroContentContainerView.accessibilityElementsHidden = NO;
    self.heroTitleLabel.hidden = NO;
    self.heroTitleLabel.accessibilityElementsHidden = NO;
    self.heroTitleCountBadgeLabel.hidden = YES;
    self.heroTitleCountBadgeLabel.accessibilityElementsHidden = YES;
    self.heroProofRailView.hidden = NO;
    self.heroProofRailView.userInteractionEnabled = YES;
    self.heroDiscoveryScrollView.hidden = NO;
    self.heroDiscoveryScrollView.userInteractionEnabled = YES;
}

- (void)pp_applyHeroMaterialPalette
{
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *accent = AppPrimaryClr ?: UIColor.systemRedColor;
    UIColor *surface = PPProviderCompaniesHeroSurfaceColor();
    UIColor *warmSurface = dark
        ? [UIColor colorWithWhite:0.135 alpha:1.0]
        : [UIColor colorWithRed:0.995 green:0.987 blue:0.978 alpha:1.0];
    UIColor *warmHighlight = dark
        ? [UIColor colorWithWhite:0.170 alpha:1.0]
        : [UIColor colorWithRed:1.0 green:0.998 blue:0.994 alpha:0.3];
    UIColor *warmTint = dark
        ? [accent colorWithAlphaComponent:0.10]
        : [accent colorWithAlphaComponent:0.045];
    UIColor *surfaceBorder =
        dark ? [UIColor.whiteColor colorWithAlphaComponent:0.12] : [UIColor.whiteColor colorWithAlphaComponent:0.86];
    UIColor *edgeColor =
        dark ? [UIColor.whiteColor colorWithAlphaComponent:0.06] : [UIColor.whiteColor colorWithAlphaComponent:0.92];

    UIBlurEffectStyle blurStyle = dark ? UIBlurEffectStyleDark : UIBlurEffectStyleExtraLight;
    if (@available(iOS 13.0, *)) {
        blurStyle = UIBlurEffectStyleSystemUltraThinMaterial;
    }
    self.heroFrostedMaterialView.effect = [UIBlurEffect effectWithStyle:blurStyle];
    self.heroFrostedMaterialView.contentView.backgroundColor =
        [surface colorWithAlphaComponent:(dark ? 0.14 : 0.04)];

    self.heroSurfaceView.backgroundColor = UIColor.clearColor;
    self.heroSurfaceGradientLayer.colors = @[
        (__bridge id)warmHighlight.CGColor,
        (__bridge id)warmSurface.CGColor,
        (__bridge id)warmTint.CGColor
    ];
    self.heroSurfaceGradientLayer.startPoint = CGPointMake(0.08, 0.0);
    self.heroSurfaceGradientLayer.endPoint = CGPointMake(0.96, 1.0);
    [self.heroSurfaceView pp_setBorderColor:surfaceBorder];
    self.heroSurfaceEdgeHighlightLayer.strokeColor = edgeColor.CGColor;
    [self.heroSurfaceView pp_setShadowColor:UIColor.blackColor];
    self.heroSurfaceView.layer.shadowOpacity = dark ? 0.16 : 0.060;
    self.heroSurfaceView.layer.shadowRadius = dark ? 28.0 : 24.0;
    self.heroSurfaceView.layer.shadowOffset = CGSizeMake(0.0, 14.0);

    self.heroAmbientGlowView.hidden = NO;
    self.heroAmbientAccentView.hidden = NO;
    self.heroAmbientSupportView.hidden = NO;
    self.heroAmbientGlowView.backgroundColor = [accent colorWithAlphaComponent:(dark ? 0.18 : 0.10)];
    self.heroAmbientGlowView.layer.shadowOpacity = 0.0;
    self.heroAmbientGlowView.layer.shadowRadius = 0.0;
    self.heroAmbientGlowView.layer.shadowOffset = CGSizeZero;
    self.heroAmbientGlowView.layer.borderWidth = 0.0;

    self.heroAmbientAccentView.backgroundColor = [accent colorWithAlphaComponent:(dark ? 0.10 : 0.065)];
    self.heroAmbientAccentView.layer.shadowOpacity = 0.0;
    self.heroAmbientAccentView.layer.shadowRadius = 0.0;
    self.heroAmbientAccentView.layer.shadowOffset = CGSizeZero;
    self.heroAmbientAccentView.layer.borderWidth = 0.0;

    self.heroAmbientSupportView.backgroundColor =
        dark ? [[UIColor whiteColor] colorWithAlphaComponent:0.08]
             : [UIColor colorWithRed:0.969 green:0.909 blue:0.814 alpha:0.64];
    self.heroAmbientSupportView.layer.shadowOpacity = 0.0;
    self.heroAmbientSupportView.layer.shadowRadius = 0.0;
    self.heroAmbientSupportView.layer.shadowOffset = CGSizeZero;
    self.heroAmbientSupportView.layer.borderWidth = 0.0;

    [self pp_applyBackgroundGlowColor:accent
                                 view:self.tableBackgroundMiddleGlowView
                        gradientLayer:self.tableBackgroundMiddleGlowLayer
                            peakAlpha:(dark ? 0.11 : 0.082)];
    self.tableBackgroundMiddleGlowView.layer.shadowRadius = 0.0;
    self.tableBackgroundMiddleGlowView.layer.shadowOffset = CGSizeZero;
    self.tableBackgroundMiddleGlowView.layer.borderWidth = 0.0;

    UIColor *bottomGlowColor = [UIColor colorNamed:@"NewBg"] ?: accent;
    [self pp_applyBackgroundGlowColor:bottomGlowColor
                                 view:self.tableBackgroundBottomGlowView
                        gradientLayer:self.tableBackgroundBottomGlowLayer
                            peakAlpha:(dark ? 0.10 : 0.095)];
    self.tableBackgroundBottomGlowView.layer.shadowRadius = 0.0;
    self.tableBackgroundBottomGlowView.layer.shadowOffset = CGSizeZero;
    self.tableBackgroundBottomGlowView.layer.borderWidth = 0.0;

    self.heroTrailIconPlateView.backgroundColor = [surface colorWithAlphaComponent:(dark ? 0.70 : 0.86)];
    [self.heroTrailIconPlateView pp_setBorderColor:[[UIColor secondarySystemBackgroundColor] colorWithAlphaComponent:(dark ? 0.18 : 0.70)]];
    self.heroTrailIconPlateView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.heroTrailIconPlateView.layer.shadowOpacity = dark ? 0.10 : 0.035;
    self.heroTrailIconPlateView.layer.shadowRadius = 14.0;
    self.heroTrailIconPlateView.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    self.heroTrailIconView.tintColor = [accent colorWithAlphaComponent:0.92];

    self.heroTitleCountBadgeLabel.backgroundColor = [accent colorWithAlphaComponent:(dark ? 0.18 : 0.095)];
    self.heroTitleCountBadgeLabel.textColor = [accent colorWithAlphaComponent:(dark ? 0.96 : 0.92)];
    [self.heroTitleCountBadgeLabel pp_setBorderColor:[accent colorWithAlphaComponent:(dark ? 0.30 : 0.16)]];
    self.heroTitleCountBadgeLabel.layer.shadowColor = accent.CGColor;
    self.heroTitleCountBadgeLabel.layer.shadowOpacity = 0.0;
    self.heroTitleCountBadgeLabel.layer.shadowRadius = 0.0;
    self.heroTitleCountBadgeLabel.layer.shadowOffset = CGSizeZero;
    self.heroProofRailView.backgroundColor = [surface colorWithAlphaComponent:(dark ? 0.50 : 0.72)];
    [self.heroProofRailView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:(dark ? 0.10 : 0.52)]];
        
 
    [self pp_applyPremiumSearchChromeAppearanceFocused:self.searchChromeFocused animated:NO];
    [self pp_updateLayoutToggleAppearanceAnimated:NO];
    [self pp_updateDiscoveryButtonAppearances];
}

- (void)pp_applyHeaderContent
{
    [self pp_applyHeroMaterialPalette];

    NSString *identifier = self.selectedProviderCategoryIdentifier;
    NSInteger sourceCount = self.loadState == PPProviderCompaniesLoadStateLoaded ? self.visibleEntries.count : self.allEntries.count;
    sourceCount = MAX(sourceCount, self.visibleEntries.count);
    NSString *heroTitle = PPProviderCompaniesHeroTitleForCategoryIdentifier(identifier);
    NSString *heroSubtitle = PPProviderCompaniesHeroSupportText(identifier);
    NSString *countBadgeValue = [NSString stringWithFormat:@"%ld", (long)MAX(sourceCount, 0)];
    NSString *countValue = PPProviderCompaniesCountText(sourceCount, identifier);
    NSString *modeTitle = kLang(@"provider_companies_metric_mode_title") ?: @"View";
    NSString *trustTitle = kLang(@"provider_companies_metric_trust_title") ?: @"Why choose";
    NSString *layoutTitle = kLang(@"provider_companies_metric_layout_title") ?: @"Layout";

    self.heroEyebrowLabel.text = @"";
    self.heroTitleLabel.text = heroTitle;
    self.heroTitleCountBadgeLabel.text = countBadgeValue;
    self.heroTitleCountBadgeLabel.accessibilityLabel = countValue;
    self.heroSubtitleLabel.text = heroSubtitle;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *configuration =
            [UIImageSymbolConfiguration configurationWithPointSize:20.0
                                                           weight:UIImageSymbolWeightSemibold];
        self.heroTrailIconView.image =
            [[UIImage systemImageNamed:PPProviderCompaniesSymbolNameForCategoryIdentifier(identifier)
                     withConfiguration:configuration] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else {
        self.heroTrailIconView.image = nil;
    }
   

    NSString *layoutValue = self.prefersCompactListLayout
        ? (kLang(@"provider_companies_layout_mode_list") ?: @"Compact")
        : (kLang(@"provider_companies_layout_mode_grid") ?: @"Showcase");
    self.heroLayoutToggleButton.accessibilityValue = layoutValue;
    self.heroLayoutToggleButton.accessibilityHint =
        [NSString stringWithFormat:@"%@. %@",
         layoutTitle,
         self.prefersCompactListLayout
            ? (kLang(@"provider_companies_layout_toggle_grid") ?: @"Show premium cards")
            : (kLang(@"provider_companies_layout_toggle_list") ?: @"Show compact list")];
    self.heroSurfaceView.isAccessibilityElement = NO;
}

- (void)loadProviders
{
    self.lastLoadError = nil;
    [self pp_setLoadState:PPProviderCompaniesLoadStateLoading error:nil];

    __weak typeof(self) weakSelf = self;
    void (^completion)(NSArray<PetAccessory *> *, NSError * _Nullable) = ^(NSArray<PetAccessory *> *accessories, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            [self pp_hydrateEntriesFromAccessories:accessories ?: @[] seedError:error];
        });
    };

    if (PPProviderCompaniesIsPharmacyCategory(self.selectedProviderCategoryIdentifier)) {
        [PetAccessoryManager fetchPublicPharmacyAccessoriesWithCompletion:completion];
    } else {
        [PetAccessoryManager fetchPublicMarketplaceAccessoriesWithCompletion:completion];
    }
}

- (void)pp_hydrateEntriesFromAccessories:(NSArray<PetAccessory *> *)accessories
                               seedError:(NSError * _Nullable)seedError
{
    if (accessories.count == 0) {
        if (seedError) {
            [self pp_setLoadState:PPProviderCompaniesLoadStateError error:seedError];
        } else {
            self.allEntries = @[];
            self.visibleEntries = @[];
            [self pp_setLoadState:PPProviderCompaniesLoadStateEmpty error:nil];
        }
        return;
    }

    NSMutableDictionary<NSString *, NSMutableArray<PetAccessory *> *> *grouped = [NSMutableDictionary dictionary];
    for (PetAccessory *item in accessories) {
        NSString *ownerID = PPProviderCompaniesSafeString(item.ownerID);
        if (ownerID.length == 0) {
            continue;
        }
        NSMutableArray<PetAccessory *> *bucket = grouped[ownerID];
        if (!bucket) {
            bucket = [NSMutableArray array];
            grouped[ownerID] = bucket;
        }
        [bucket addObject:item];
    }

    if (grouped.count == 0) {
        self.allEntries = @[];
        self.visibleEntries = @[];
        [self pp_setLoadState:PPProviderCompaniesLoadStateEmpty error:nil];
        return;
    }

    NSMutableArray<PPProviderCompanyEntry *> *entries = [NSMutableArray arrayWithCapacity:grouped.count];
    [grouped enumerateKeysAndObjectsUsingBlock:^(NSString *ownerID, NSMutableArray<PetAccessory *> *items, BOOL *stop) {
        [items sortUsingComparator:^NSComparisonResult(PetAccessory *lhs, PetAccessory *rhs) {
            NSDate *leftDate = lhs.createdAt ?: NSDate.distantPast;
            NSDate *rightDate = rhs.createdAt ?: NSDate.distantPast;
            return [rightDate compare:leftDate];
        }];

        PPProviderCompanyEntry *entry = [PPProviderCompanyEntry new];
        entry.ownerID = ownerID;
        entry.items = items.copy;
        entry.productCount = items.count;
        entry.latestCreatedAt = items.firstObject.createdAt;
        [entries addObject:entry];
    }];

    dispatch_group_t group = dispatch_group_create();
    __block NSError *profileError = seedError;
    NSString *currentUID = [UserManager sharedManager].currentUser.ID ?: @"";
    __weak typeof(self) weakSelf = self;

    for (PPProviderCompanyEntry *entry in entries) {
        dispatch_group_enter(group);

        if (currentUID.length > 0 &&
            [entry.ownerID isEqualToString:currentUID] &&
            [UserManager sharedManager].currentUser) {
            entry.user = [UserManager sharedManager].currentUser;
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                dispatch_group_leave(group);
                continue;
            }
            [strongSelf pp_hydrateProviderProfileForEntry:entry completion:^{
                dispatch_group_leave(group);
            }];
            continue;
        }

        [[UserManager sharedManager] getOtherUserModelFromFirestoreWithUID:entry.ownerID completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
            if (user) {
                entry.user = user;
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) {
                    dispatch_group_leave(group);
                    return;
                }
                [strongSelf pp_hydrateProviderProfileForEntry:entry completion:^{
                    dispatch_group_leave(group);
                }];
                return;
            } else if (error && !profileError) {
                profileError = error;
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        NSPredicate *resolvedPredicate = [NSPredicate predicateWithBlock:^BOOL(PPProviderCompanyEntry *entry, NSDictionary *bindings) {
            return [self pp_displayNameForEntry:entry].length > 0;
        }];
        NSArray<PPProviderCompanyEntry *> *resolvedEntries = [entries filteredArrayUsingPredicate:resolvedPredicate];
        resolvedEntries = [resolvedEntries sortedArrayUsingComparator:^NSComparisonResult(PPProviderCompanyEntry *lhs, PPProviderCompanyEntry *rhs) {
            if (lhs.productCount != rhs.productCount) {
                return lhs.productCount > rhs.productCount ? NSOrderedAscending : NSOrderedDescending;
            }

            NSDate *leftDate = lhs.latestCreatedAt ?: NSDate.distantPast;
            NSDate *rightDate = rhs.latestCreatedAt ?: NSDate.distantPast;
            NSComparisonResult dateResult = [rightDate compare:leftDate];
            if (dateResult != NSOrderedSame) {
                return dateResult;
            }

            return [[self pp_displayNameForEntry:lhs] localizedCaseInsensitiveCompare:[self pp_displayNameForEntry:rhs]];
        }];

        self.allEntries = resolvedEntries ?: @[];
        [self pp_applySearchFilter];

        if (self.allEntries.count == 0) {
            [self pp_setLoadState:(profileError ? PPProviderCompaniesLoadStateError : PPProviderCompaniesLoadStateEmpty)
                            error:profileError];
        } else {
            [self pp_setLoadState:PPProviderCompaniesLoadStateLoaded error:nil];
            [self pp_refreshProviderRatingSummaries];
        }
    });
}

- (NSString *)pp_providerProfileCityTextForValue:(id)value
{
    NSString *rawCity = @"";
    if ([value isKindOfClass:NSNumber.class]) {
        rawCity = [(NSNumber *)value stringValue];
    } else {
        rawCity = PPProviderCompaniesSafeString(value);
    }

    rawCity = [rawCity stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (rawCity.length == 0) {
        return @"";
    }

    NSCharacterSet *nonDigits = [NSCharacterSet.decimalDigitCharacterSet invertedSet];
    BOOL looksNumeric = [rawCity rangeOfCharacterFromSet:nonDigits].location == NSNotFound;
    NSInteger cityID = looksNumeric ? rawCity.integerValue : 0;
    if (cityID > 0) {
        NSString *localizedCity = [CitiesManager.shared cityNameForID:cityID];
        if (localizedCity.length > 0) {
            return localizedCity;
        }
    }

    return rawCity;
}

- (NSArray<NSString *> *)pp_sanitizedProviderProfileURLArrayFromValue:(id)value
{
    if (![value isKindOfClass:NSArray.class]) {
        return @[];
    }

    NSMutableArray<NSString *> *urls = [NSMutableArray array];
    for (id candidate in (NSArray *)value) {
        NSString *url =
            [PPProviderCompaniesSafeString(candidate)
             stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (url.length > 0) {
            [urls addObject:url];
        }
    }
    return urls.copy;
}

- (NSString *)pp_trimmedProviderProfileStringFromValue:(id)value
{
    return [PPProviderCompaniesSafeString(value)
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (void)pp_applyProviderProfileData:(NSDictionary *)data
                            toEntry:(PPProviderCompanyEntry *)entry
{
    if (![data isKindOfClass:NSDictionary.class] || ![entry isKindOfClass:PPProviderCompanyEntry.class]) {
        return;
    }

    NSDictionary *form = [data[@"form"] isKindOfClass:NSDictionary.class] ? data[@"form"] : @{};
    NSDictionary *userSummary = [data[@"userSummary"] isKindOfClass:NSDictionary.class] ? data[@"userSummary"] : @{};

    NSString *displayName = [self pp_trimmedProviderProfileStringFromValue:form[@"fullName"]];
    if (displayName.length == 0) {
        displayName = [self pp_trimmedProviderProfileStringFromValue:userSummary[@"displayName"]];
    }
    if (displayName.length == 0) {
        displayName = [self pp_trimmedProviderProfileStringFromValue:data[@"displayName"]];
    }
    entry.profileDisplayName = displayName ?: @"";

    id cityValue = form[@"city"] ?: data[@"city"];
    entry.profileCityText = [self pp_providerProfileCityTextForValue:cityValue] ?: @"";

    NSArray<NSString *> *coverURLs = [self pp_sanitizedProviderProfileURLArrayFromValue:form[@"imageRefs"]];
    if (coverURLs.count == 0) {
        coverURLs = [self pp_sanitizedProviderProfileURLArrayFromValue:data[@"coverImageUrls"]];
    }
    entry.profileCoverImageURLs = coverURLs ?: @[];

    NSString *avatarURL = [self pp_trimmedProviderProfileStringFromValue:userSummary[@"photoURL"]];
    if (avatarURL.length == 0) {
        avatarURL = [self pp_trimmedProviderProfileStringFromValue:data[@"avatarURL"]];
    }
    if (avatarURL.length == 0) {
        avatarURL = [self pp_trimmedProviderProfileStringFromValue:data[@"photoURL"]];
    }
    entry.profileAvatarURLString = avatarURL ?: @"";
}

- (void)pp_hydrateProviderProfileForEntry:(PPProviderCompanyEntry *)entry
                               completion:(dispatch_block_t)completion
{
    void (^finish)(void) = ^{
        if (completion) {
            completion();
        }
    };

    if (entry.ownerID.length == 0) {
        finish();
        return;
    }

    NSString *providerType = PPProviderCompaniesIsPharmacyCategory(self.selectedProviderCategoryIdentifier)
        ? @"pharmacy"
        : @"marketplace";
    NSString *profileID = [NSString stringWithFormat:@"%@_%@", entry.ownerID, providerType];
    FIRDocumentReference *profileRef =
        [[[FIRFirestore firestore] collectionWithPath:@"providerProfiles"] documentWithPath:profileID];

    [profileRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (!error && snapshot.exists) {
            [self pp_applyProviderProfileData:(snapshot.data ?: @{}) toEntry:entry];
        }
        finish();
    }];
}

- (void)pp_refreshProviderRatingSummaries
{
    NSMutableOrderedSet<NSString *> *providerIDs = [NSMutableOrderedSet orderedSet];
    for (PPProviderCompanyEntry *entry in self.allEntries) {
        if (entry.ownerID.length > 0) {
            [providerIDs addObject:entry.ownerID];
        }
    }
    if (providerIDs.count == 0 || ![UserManager sharedManager].isUserLoggedIn) {
        return;
    }

    NSArray<NSString *> *requestedProviderIDs =
        providerIDs.count > 50
            ? [[providerIDs array] subarrayWithRange:NSMakeRange(0, 50)]
            : providerIDs.array;
    FIRHTTPSCallable *callable =
        [[FIRFunctions functionsForRegion:@"us-central1"] HTTPSCallableWithName:@"getProviderReviewSummaries"];
    __weak typeof(self) weakSelf = self;
    [callable callWithObject:@{@"providerIDs": requestedProviderIDs}
                  completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        if (error || ![result.data isKindOfClass:NSDictionary.class]) {
            return;
        }
        NSDictionary *summaries = [(NSDictionary *)result.data objectForKey:@"summaries"];
        if (![summaries isKindOfClass:NSDictionary.class]) {
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            for (PPProviderCompanyEntry *entry in strongSelf.allEntries) {
                NSDictionary *summary = summaries[entry.ownerID];
                if (![summary isKindOfClass:NSDictionary.class]) {
                    continue;
                }
                entry.user.providerRatingValue =
                    MAX(0.0, MIN(5.0, [summary[@"providerRatingValue"] doubleValue]));
                entry.user.providerReviewCount =
                    MAX(0, [summary[@"providerReviewCount"] integerValue]);
            }
            [strongSelf pp_applySearchFilter];
        });
    }];
}

- (NSString *)pp_displayNameForEntry:(PPProviderCompanyEntry *)entry
{
    NSString *profileName =
        [PPProviderCompaniesSafeString(entry.profileDisplayName)
         stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (profileName.length > 0) {
        return profileName;
    }

    if (![entry.user isKindOfClass:UserModel.class]) {
        return @"";
    }

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (entry.user.FirstName.length > 0) [parts addObject:entry.user.FirstName];
    if (entry.user.LastName.length > 0) [parts addObject:entry.user.LastName];
    if (parts.count > 0) {
        return [parts componentsJoinedByString:@" "];
    }

    NSString *bestName = PPProviderCompaniesSafeString([entry.user bestDisplayName]);
    if (bestName.length > 0) {
        return bestName;
    }
    bestName = PPProviderCompaniesSafeString([entry.user PPBestDisplayName]);
    if (bestName.length > 0) {
        return bestName;
    }
    return PPProviderCompaniesSafeString(entry.user.UserName);
}

- (NSArray<PPProviderCompanyEntry *> *)pp_sortedEntries:(NSArray<PPProviderCompanyEntry *> *)entries
                                                  mode:(PPProviderCompaniesDiscoveryMode)mode
{
    return [entries sortedArrayUsingComparator:^NSComparisonResult(PPProviderCompanyEntry *lhs,
                                                                    PPProviderCompanyEntry *rhs) {
        BOOL leftVerified = lhs.user.isVerified;
        BOOL rightVerified = rhs.user.isVerified;
        NSDate *leftDate = lhs.latestCreatedAt ?: NSDate.distantPast;
        NSDate *rightDate = rhs.latestCreatedAt ?: NSDate.distantPast;

        if (mode == PPProviderCompaniesDiscoveryModeNewest) {
            NSComparisonResult dateResult = [rightDate compare:leftDate];
            if (dateResult != NSOrderedSame) {
                return dateResult;
            }
            if (leftVerified != rightVerified) {
                return leftVerified ? NSOrderedAscending : NSOrderedDescending;
            }
            if (lhs.productCount != rhs.productCount) {
                return lhs.productCount > rhs.productCount ? NSOrderedAscending : NSOrderedDescending;
            }
        } else if (mode == PPProviderCompaniesDiscoveryModeTopSellers) {
            if (lhs.productCount != rhs.productCount) {
                return lhs.productCount > rhs.productCount ? NSOrderedAscending : NSOrderedDescending;
            }
            if (leftVerified != rightVerified) {
                return leftVerified ? NSOrderedAscending : NSOrderedDescending;
            }
            NSComparisonResult dateResult = [rightDate compare:leftDate];
            if (dateResult != NSOrderedSame) {
                return dateResult;
            }
        } else {
            if (leftVerified != rightVerified) {
                return leftVerified ? NSOrderedAscending : NSOrderedDescending;
            }
            if (lhs.productCount != rhs.productCount) {
                return lhs.productCount > rhs.productCount ? NSOrderedAscending : NSOrderedDescending;
            }
            NSComparisonResult dateResult = [rightDate compare:leftDate];
            if (dateResult != NSOrderedSame) {
                return dateResult;
            }
        }

        return [[self pp_displayNameForEntry:lhs]
            localizedCaseInsensitiveCompare:[self pp_displayNameForEntry:rhs]];
    }];
}

- (void)pp_applySearchFilter
{
    NSArray<PPProviderCompanyEntry *> *candidates = self.allEntries ?: @[];
    NSString *query = PPProviderCompaniesNormalizedIdentifier(self.searchQuery);
    if (query.length > 0) {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(PPProviderCompanyEntry *entry, NSDictionary *bindings) {
            NSString *displayName = [[self pp_displayNameForEntry:entry] lowercaseString];
            NSString *about = [PPProviderCompaniesSafeString(entry.user.UserAbout) lowercaseString];
            NSString *city = [PPProviderCompaniesSafeString(entry.profileCityText) lowercaseString];
            return [displayName containsString:query] ||
                   [about containsString:query] ||
                   [city containsString:query];
        }];
        candidates = [candidates filteredArrayUsingPredicate:predicate] ?: @[];
    }

    if (self.selectedDiscoveryMode == PPProviderCompaniesDiscoveryModeFeatured) {
        NSPredicate *featuredPredicate =
            [NSPredicate predicateWithBlock:^BOOL(PPProviderCompanyEntry *entry, NSDictionary *bindings) {
                return entry.user.isVerified;
            }];
        candidates = [candidates filteredArrayUsingPredicate:featuredPredicate] ?: @[];
    }

    self.visibleEntries =
        [self pp_sortedEntries:candidates mode:self.selectedDiscoveryMode] ?: @[];
    [self pp_applyHeaderContent];
    [self.tableView reloadData];

    if (self.loadState == PPProviderCompaniesLoadStateLoaded && self.visibleEntries.count == 0) {
        [self pp_setLoadState:PPProviderCompaniesLoadStateEmpty error:nil];
    } else if (self.loadState == PPProviderCompaniesLoadStateEmpty && self.allEntries.count > 0 && self.visibleEntries.count > 0) {
        [self pp_setLoadState:PPProviderCompaniesLoadStateLoaded error:nil];
    }
}

- (void)pp_setLoadState:(PPProviderCompaniesLoadState)state
                  error:(NSError * _Nullable)error
{
    self.loadState = state;
    self.lastLoadError = error;
    BOOL hasSourceEntries = (self.allEntries.count > 0);
    self.stateContainerView.hidden = (state == PPProviderCompaniesLoadStateLoaded);
    self.tableView.hidden = (state == PPProviderCompaniesLoadStateLoading ||
                             state == PPProviderCompaniesLoadStateError);

    self.stateIconView.hidden = YES;
    self.retryButton.hidden = YES;
    [self.loadingIndicator stopAnimating];

    switch (state) {
        case PPProviderCompaniesLoadStateLoading: {
            self.stateContainerView.hidden = NO;
            self.tableView.hidden = YES;
            [self.loadingIndicator startAnimating];
            self.stateTitleLabel.text = kLang(@"provider_companies_loading_title") ?: @"Loading providers";
            self.stateSubtitleLabel.text = kLang(@"provider_companies_loading_subtitle") ?: @"We’re gathering the latest providers for this category.";
            break;
        }

        case PPProviderCompaniesLoadStateEmpty: {
            self.stateContainerView.hidden = NO;
            self.tableView.hidden = !hasSourceEntries;
            self.stateIconView.hidden = NO;
            BOOL isSearching =
                (PPProviderCompaniesNormalizedIdentifier(self.searchQuery).length > 0 && hasSourceEntries);
            BOOL isFeaturedFiltering =
                (!isSearching &&
                 hasSourceEntries &&
                 self.selectedDiscoveryMode == PPProviderCompaniesDiscoveryModeFeatured);
            if (@available(iOS 13.0, *)) {
                NSString *iconName = isSearching
                    ? @"magnifyingglass"
                    : (isFeaturedFiltering
                       ? @"checkmark.seal"
                       : (PPProviderCompaniesIsPharmacyCategory(self.selectedProviderCategoryIdentifier)
                          ? @"cross.case"
                          : @"shippingbox"));
                self.stateIconView.image = [[UIImage systemImageNamed:iconName
                                                    withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:40.0
                                                                                                              weight:UIImageSymbolWeightRegular]]
                                           imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            }
            if (isSearching) {
                self.stateTitleLabel.text = kLang(@"provider_companies_no_results_title") ?: @"No matching providers";
                self.stateSubtitleLabel.text = kLang(@"provider_companies_no_results_subtitle") ?: @"Try a different name or clear the search.";
            } else if (isFeaturedFiltering) {
                self.stateTitleLabel.text =
                    kLang(@"provider_companies_no_featured_title") ?: @"No featured providers yet";
                self.stateSubtitleLabel.text =
                    kLang(@"provider_companies_no_featured_subtitle") ?: @"Choose another view to see all available providers.";
            } else {
                self.stateTitleLabel.text = PPProviderCompaniesIsPharmacyCategory(self.selectedProviderCategoryIdentifier)
                    ? (kLang(@"provider_companies_empty_title_pharmacy") ?: @"No pharmacies yet")
                    : (kLang(@"provider_companies_empty_title_marketplace") ?: @"No providers yet");
                self.stateSubtitleLabel.text = PPProviderCompaniesIsPharmacyCategory(self.selectedProviderCategoryIdentifier)
                    ? (kLang(@"provider_companies_empty_subtitle_pharmacy") ?: @"Approved pet medicine providers will appear here once products are available.")
                    : (kLang(@"provider_companies_empty_subtitle_marketplace") ?: @"Trusted marketplace providers will appear here once products are published.");
            }
            break;
        }

        case PPProviderCompaniesLoadStateError: {
            self.stateContainerView.hidden = NO;
            self.tableView.hidden = YES;
            self.stateIconView.hidden = NO;
            self.retryButton.hidden = NO;
            if (@available(iOS 13.0, *)) {
                self.stateIconView.image = [[UIImage systemImageNamed:@"wifi.exclamationmark"
                                                    withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:38.0
                                                                                                              weight:UIImageSymbolWeightRegular]]
                                           imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            }
            self.stateTitleLabel.text = kLang(@"provider_companies_error_title") ?: @"Couldn’t load providers";
            self.stateSubtitleLabel.text = kLang(@"provider_companies_error_subtitle") ?: @"Check your connection and try again.";
            [self.retryButton setTitle:kLang(@"provider_retry") ?: @"Retry" forState:UIControlStateNormal];
            break;
        }

        case PPProviderCompaniesLoadStateLoaded:
        case PPProviderCompaniesLoadStateIdle:
        default:
            self.stateContainerView.hidden = YES;
            self.tableView.hidden = NO;
            break;
    }

    [self pp_applyHeaderContent];
}

- (void)pp_handleRetryTap
{
    [self loadProviders];
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    self.searchChromeFocused = YES;
    [self pp_applyPremiumSearchChromeAppearanceFocused:YES animated:YES];
    [self pp_updatePinnedHeroForCurrentScrollPosition];
    [self pp_setPremiumTabDockHidden:YES animated:YES];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    self.searchChromeFocused = NO;
    [self pp_applyPremiumSearchChromeAppearanceFocused:NO animated:YES];
    [self pp_updatePinnedHeroForCurrentScrollPosition];
    [self pp_setPremiumTabDockHidden:NO animated:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    self.searchQuery = @"";
    [self pp_applySearchFilter];
    return YES;
}

- (void)pp_handleHeroSearchTextChanged:(UITextField *)textField
{
    self.searchQuery = PPProviderCompaniesSafeString(textField.text);
    [self pp_applySearchFilter];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.visibleEntries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PPProviderCompanyEntry *entry = self.visibleEntries[indexPath.row];
    if (self.prefersCompactListLayout) {
        PPProviderCompanyCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProviderCompanyCell"
                                                                      forIndexPath:indexPath];
        [cell configureWithEntry:entry categoryIdentifier:self.selectedProviderCategoryIdentifier];
        return cell;
    }

    PPProviderCompanyPremiumCardCell *cell =
        [tableView dequeueReusableCellWithIdentifier:PPProviderCompanyPremiumCardCell.reuseIdentifier
                                        forIndexPath:indexPath];
    [cell configureWithViewModel:[self pp_premiumCardViewModelForEntry:entry]];
    return cell;
}


- (PPProviderCompanyPremiumCardViewModel *)pp_premiumCardViewModelForEntry:(PPProviderCompanyEntry *)entry
{
    PPProviderCompanyPremiumCardViewModel *model = [[PPProviderCompanyPremiumCardViewModel alloc] init];

    NSString *title =
        [PPProviderCompaniesSafeString(entry.profileDisplayName)
         stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (title.length == 0) {
        title = PPProviderCompaniesSafeString([entry.user bestDisplayName]);
    }
    if (title.length == 0) {
        NSMutableArray<NSString *> *parts = [NSMutableArray array];
        if (entry.user.FirstName.length > 0) [parts addObject:entry.user.FirstName];
        if (entry.user.LastName.length > 0) [parts addObject:entry.user.LastName];
        title = parts.count > 0 ? [parts componentsJoinedByString:@" "] : PPProviderCompaniesSafeString(entry.user.UserName);
    }
    if (title.length == 0) {
        title = PPProviderCompaniesTitleForCategoryIdentifier(self.selectedProviderCategoryIdentifier);
    }

    model.providerIdentifier = PPProviderCompaniesSafeString(entry.ownerID);
    model.title = title;
    model.subtitle = PPProviderCompaniesCellDisplaySubtitle(entry, self.selectedProviderCategoryIdentifier);
    model.categoryText = PPProviderCompaniesTitleForCategoryIdentifier(self.selectedProviderCategoryIdentifier);
    model.countTitleText = PPProviderCompaniesIsPharmacyCategory(self.selectedProviderCategoryIdentifier)
        ? (kLang(@"provider_companies_count_title_pharmacy") ?: @"Medicines")
        : (kLang(@"provider_companies_count_title_marketplace") ?: @"Products");
    model.countValueText = [NSString stringWithFormat:@"%ld", (long)MAX(entry.productCount, 0)];
    model.cityText = PPProviderCompaniesCityForEntry(entry);
    model.accentColor = AppPrimaryClr ?: [UIColor colorWithRed:0.93 green:0.43 blue:0.18 alpha:1.0];
    model.verified = entry.user.isVerified;
    model.active = [PPProviderCompaniesSafeString(entry.user.accountStatus) isEqualToString:@"active"];
    model.accessoryStyle = PPProviderCompanyPremiumCardAccessoryStyleHeart;

    if (entry.user.providerReviewCount > 0 && entry.user.providerRatingValue > 0.0) {
        model.ratingText = [NSString stringWithFormat:@"%.1f", entry.user.providerRatingValue];
        model.ratingCountText = [NSString stringWithFormat:@"(%ld)", (long)entry.user.providerReviewCount];
    } else {
        model.ratingText = @"New";
        model.ratingCountText = @"";
    }

    NSString *coverImageURLString = @"";
    if (entry.profileCoverImageURLs.count > 0) {
        coverImageURLString = PPProviderCompaniesSafeString(entry.profileCoverImageURLs[0]);
    }
    if (coverImageURLString.length == 0 && entry.user.coverImageUrls && entry.user.coverImageUrls.count > 0) {
        coverImageURLString = PPProviderCompaniesSafeString(entry.user.coverImageUrls[0]);
    }
    if (coverImageURLString.length == 0 && entry.items.count > 0) {
        PetAccessory *latestProduct = entry.items.firstObject;
        if (latestProduct.imageURLsArray && latestProduct.imageURLsArray.count > 0) {
            coverImageURLString = PPProviderCompaniesSafeString(latestProduct.imageURLsArray[0]);
        }
    }
    if (coverImageURLString.length > 0) {
        model.imageURL = [NSURL URLWithString:coverImageURLString];
    }

    model.placeholderImage = [UIImage imageNamed:@"providers_placeholder"];

    return model;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.prefersCompactListLayout) {
        return [PPProviderCompanyCell preferredHeightForTableWidth:CGRectGetWidth(tableView.bounds)];
    }
    return [PPProviderCompanyPremiumCardCell preferredHeightForTableWidth:CGRectGetWidth(tableView.bounds)];
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.prefersCompactListLayout) {
        return [PPProviderCompanyCell preferredHeightForTableWidth:CGRectGetWidth(tableView.bounds)];
    }
    return [PPProviderCompanyPremiumCardCell preferredHeightForTableWidth:CGRectGetWidth(tableView.bounds)];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row >= self.visibleEntries.count) {
        return;
    }

    PPProviderCompanyEntry *entry = self.visibleEntries[indexPath.row];
    ProviderStorefrontProductsVC *storefrontVC =
        [[ProviderStorefrontProductsVC alloc] initWithSeller:entry.user
                                                       items:entry.items
                                          categoryIdentifier:self.selectedProviderCategoryIdentifier];
    storefrontVC.parentVC = self;
    [self.navigationController pushViewController:storefrontVC animated:YES];
}

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row >= self.visibleEntries.count) {
        return;
    }

    PPProviderCompanyEntry *entry = self.visibleEntries[indexPath.row];
    NSString *ownerKey = PPProviderCompaniesSafeString(entry.ownerID);
    if (ownerKey.length == 0) {
        ownerKey = [NSString stringWithFormat:@"%@-%ld",
                    PPProviderCompaniesNormalizedIdentifier(self.selectedProviderCategoryIdentifier),
                    (long)indexPath.row];
    }

    if ([self.animatedCompanyCellKeys containsObject:ownerKey]) {
        return;
    }

    [self.animatedCompanyCellKeys addObject:ownerKey];
    NSTimeInterval delay = MIN(indexPath.row, 6) * 0.035;
    if ([cell isKindOfClass:PPProviderCompanyCell.class]) {
        [(PPProviderCompanyCell *)cell pp_runEntranceAnimationWithDelay:delay];
    } else if ([cell isKindOfClass:PPProviderCompanyPremiumCardCell.class]) {
        [(PPProviderCompanyPremiumCardCell *)cell pp_runEntranceAnimationWithDelay:delay];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView != self.tableView) {
        return;
    }

    [self pp_updatePinnedHeroForCurrentScrollPosition];
}

- (void)pp_setPremiumTabDockHidden:(BOOL)hidden animated:(BOOL)animated
{
    if ([self.tabBarController respondsToSelector:@selector(setPremiumTabDockViewHidden:animation:)]) {
        [(id)self.tabBarController setPremiumTabDockViewHidden:hidden animation:animated];
        return;
    }
    if ([self.tabBarController respondsToSelector:@selector(pp_setBottomNavigationHidden:animated:)]) {
        [(id)self.tabBarController pp_setBottomNavigationHidden:hidden animated:animated];
        return;
    }
}

@end
