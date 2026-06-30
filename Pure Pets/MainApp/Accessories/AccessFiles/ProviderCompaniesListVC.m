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
#import "PPMarketplaceHeroCardStyle.h"
#import "UIViewController+PPBottomSurface.h"
#import <QuartzCore/QuartzCore.h>

@import FirebaseFunctions;
@import FirebaseFirestore;

@interface PPProviderCompaniesAmbientGlowView : UIView
@property (nonatomic, strong) CAGradientLayer *radialLayer;
@property (nonatomic, assign, getter=isFaded) BOOL faded;
- (void)applyColor:(UIColor *)color
         peakAlpha:(CGFloat)peakAlpha
       middleAlpha:(CGFloat)middleAlpha;
@end

@implementation PPProviderCompaniesAmbientGlowView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.userInteractionEnabled = NO;
    self.isAccessibilityElement = NO;
    self.accessibilityElementsHidden = YES;
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.faded = NO;

    _radialLayer = [CAGradientLayer layer];
    if (@available(iOS 12.0, *)) {
        _radialLayer.type = kCAGradientLayerRadial;
        _radialLayer.startPoint = CGPointMake(0.5, 0.5);
        _radialLayer.endPoint = CGPointMake(1.0, 1.0);
    } else {
        _radialLayer.startPoint = CGPointMake(0.0, 0.5);
        _radialLayer.endPoint = CGPointMake(1.0, 0.5);
    }
    _radialLayer.locations = @[@0.0, @0.46, @1.0];
    _radialLayer.drawsAsynchronously = YES;
    [self.layer addSublayer:_radialLayer];
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.layer.cornerRadius = CGRectGetWidth(self.bounds) * 0.5;
    self.layer.masksToBounds = !self.isFaded;
    self.radialLayer.frame = self.bounds;
    [CATransaction commit];
}

- (void)applyColor:(UIColor *)color
         peakAlpha:(CGFloat)peakAlpha
       middleAlpha:(CGFloat)middleAlpha
{
    UIColor *safeColor = color ?: UIColor.clearColor;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.layer.cornerRadius = CGRectGetWidth(self.bounds) * 0.5;
    self.layer.masksToBounds = !self.isFaded;
    if (self.isFaded) {
        self.backgroundColor = UIColor.clearColor;
        self.radialLayer.hidden = NO;
        self.radialLayer.locations = @[@0.0, @0.46, @1.0];
        self.radialLayer.colors = @[
            (id)[safeColor colorWithAlphaComponent:peakAlpha].CGColor,
            (id)[safeColor colorWithAlphaComponent:middleAlpha].CGColor,
            (id)[safeColor colorWithAlphaComponent:0.0].CGColor
        ];
    } else {
        self.radialLayer.hidden = YES;
        self.backgroundColor = [safeColor colorWithAlphaComponent:peakAlpha];
    }
    [CATransaction commit];
}

@end

static NSString * const PPProviderCompaniesMiddleBackgroundGlowPositionMotionKey = @"pp.providerCompanies.background.mid.position";
static NSString * const PPProviderCompaniesMiddleBackgroundGlowPeekMotionKey = @"pp.providerCompanies.background.mid.peek";











@interface ProviderCompaniesListVC () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *pp_premiumBackgroundCanvasView;
@property (nonatomic, strong) PPProviderCompaniesAmbientGlowView *pp_premiumBackgroundGlowViewTop;
@property (nonatomic, strong) PPProviderCompaniesAmbientGlowView *pp_premiumBackgroundGlowViewMid;
@property (nonatomic, strong) PPProviderCompaniesAmbientGlowView *pp_premiumBackgroundGlowViewBottom;
 @property (nonatomic, strong) UIButton *FilterBTN;
 @property (nonatomic, strong) UIButton *heroLayoutToggleButton;
@property (nonatomic, strong) UIButton *heroSearchChromeView;
@property (nonatomic, strong) UIImageView *heroSearchIconView;
@property (nonatomic, strong) UITextField *heroSearchTextField;
 
 

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
@property (nonatomic, assign) BOOL didStartPremiumBackgroundGlowMotion;
@property (nonatomic, assign) BOOL backgroundGlowsFadedByHomeConfig;
@property (nonatomic, assign) BOOL providerCompaniesScreenVisible;
@property (nonatomic, assign) CGSize premiumBackgroundGlowMotionCanvasSize;
@property (nonatomic, assign) BOOL prefersCompactListLayout;
@property (nonatomic, assign) PPProviderCompaniesDiscoveryMode selectedDiscoveryMode;
 - (void)pp_handleLayoutToggleButton;
- (void)pp_updateLayoutToggleAppearanceAnimated:(BOOL)animated;
- (void)pp_focusHeroSearchTextField;
 - (void)pp_updateBottomNavigationInsetsIfNeeded;
- (void)pp_handleHeroSearchTextChanged:(UITextField *)textField;
- (void)pp_applyPremiumProviderBackgroundAppearance;
- (PPProviderCompaniesAmbientGlowView *)pp_makePremiumBackgroundGlowView;
- (void)pp_installPremiumBackgroundGlowViewsIfNeeded;
- (void)pp_applyPremiumGlowView:(PPProviderCompaniesAmbientGlowView *)glowView
                          color:(UIColor *)color
                      peakAlpha:(CGFloat)peakAlpha
                    middleAlpha:(CGFloat)middleAlpha;
- (void)pp_updatePremiumBackgroundGlowAppearance;
- (void)pp_layoutPremiumBackgroundGlowViews;
- (BOOL)pp_shouldReduceProviderBackgroundMotion;
- (void)pp_addRandomizedMiddleBackgroundGlowPositionMotion;
- (void)pp_addPremiumMiddleBackgroundGlowPeekMotionIfNeeded;
- (void)pp_beginPremiumBackgroundGlowMotionIfNeeded;
- (void)pp_stopPremiumBackgroundGlowMotion;
- (void)pp_hydrateProviderProfileForEntry:(PPProviderCompanyEntry *)entry
                               completion:(dispatch_block_t)completion;
- (void)pp_refreshProviderRatingSummaries;
@end

@implementation ProviderCompaniesListVC

- (PPBottomSurfaceKind)pp_preferredBottomSurfaceKind
{
    return PPBottomSurfaceKindNone;
}

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
        _prefersCompactListLayout = NO;
        _backgroundGlowsFadedByHomeConfig = NO;
    }
    return self;
}

- (void)dealloc
{
    [self pp_stopPremiumBackgroundGlowMotion];
 }

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self pp_buildUI];
     [self loadProviders];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
     self.navigationItem.searchController = nil;
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.leftBarButtonItem = nil;
     [self pp_applyPremiumSearchChromeAppearanceFocused:self.searchChromeFocused animated:NO];
    self.hidesBottomBarWhenPushed=YES;
    [self pp_applyBottomSurfaceAnimated:animated];
    
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto
                     button:_heroLayoutToggleButton
                       title:kLang(@"provider_marketplace_title")
                   showBack:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.providerCompaniesScreenVisible = YES;
     [self pp_startHeroAmbientMotionIfNeeded];
    [self pp_updateBottomNavigationInsetsIfNeeded];
 }

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.providerCompaniesScreenVisible = NO;
    [self pp_stopPremiumBackgroundGlowMotion];
 }

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    [self pp_layoutPremiumBackgroundGlowViews];
    [self pp_updateHeroSurfaceGeometry];

     [self pp_updateBottomNavigationInsetsIfNeeded];
 }

- (void)pp_updateHeroSurfaceGeometry
{
    PPProviderCompaniesApplyContinuousCorners(self.heroSearchChromeView, CGRectGetHeight(self.heroSearchChromeView.bounds) * 0.5);
    self.heroSearchChromeView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.heroSearchChromeView.bounds
                                   cornerRadius:CGRectGetHeight(self.heroSearchChromeView.bounds) * 0.5].CGPath;
    if (!PPIOS26()) {
        self.heroLayoutToggleButton.layer.cornerRadius = CGRectGetWidth(self.heroLayoutToggleButton.bounds) * 0.5;
    }
   
 
 
}

- (void)viewSafeAreaInsetsDidChange
{
    [super viewSafeAreaInsetsDidChange];
    [self pp_layoutPremiumBackgroundGlowViews];
    [self pp_updateBottomNavigationInsetsIfNeeded];
 }

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if (![self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            return;
        }
    }
    [self pp_updatePremiumBackgroundGlowAppearance];
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

    [self pp_applyPremiumProviderBackgroundAppearance];

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
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-0]
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

    CGFloat bottomInset = 72;
    CGFloat topInset = PPNavBarHeightFull;
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
- (void)pp_handleHeroFilterButtonTap:(UIButton *)sender
{
    [self pp_presentLegacyHeroFilterSheetFromButton:sender];
}
- (void)pp_buildHeader
{
    
    if (PPIOS26()) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.buttonSize = UIButtonConfigurationSizeLarge;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
        self.heroLayoutToggleButton = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    } else {
        self.heroLayoutToggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.heroLayoutToggleButton.clipsToBounds = NO;
    }
    self.heroLayoutToggleButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroLayoutToggleButton.accessibilityHint =
        kLang(@"provider_companies_layout_toggle_hint") ?: @"Changes the provider layout";
    [self.heroLayoutToggleButton addTarget:self
                                    action:@selector(pp_handleLayoutToggleButton)
                          forControlEvents:UIControlEventTouchUpInside];
     
 

    UIButton *heroFilterButton = [self pp_ButtonWithSystemName:@"line.3.horizontal.decrease" action:@selector(pp_handleHeroFilterButtonTap:)];
    heroFilterButton.translatesAutoresizingMaskIntoConstraints = NO;
     heroFilterButton.contentMode = UIViewContentModeScaleAspectFit;
    heroFilterButton.accessibilityElementsHidden = YES;
    [self.view addSubview:heroFilterButton];

    self.FilterBTN =  heroFilterButton;
    

    self.heroSearchChromeView = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleCapsule];
    self.heroSearchChromeView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSearchChromeView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
 
    if(!PPIOS26())
    {
        self.heroSearchChromeView.layer.borderWidth = 1.0;
        self.heroSearchChromeView.layer.masksToBounds = NO;
        PPProviderCompaniesApplyContinuousCorners(self.heroSearchChromeView, 0.0);
    }
        
    
    
    [self.view addSubview:self.heroSearchChromeView];
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
     [self.heroSearchChromeView addSubview:self.FilterBTN];
     [self.heroSearchChromeView addSubview:self.heroLayoutToggleButton];
    
    [NSLayoutConstraint activateConstraints:@[
          
        [self.heroSearchChromeView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-16.0],

        [self.heroSearchChromeView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [self.heroSearchChromeView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],
        [self.heroSearchChromeView.heightAnchor constraintEqualToConstant:54.0],

        [self.heroSearchIconView.leadingAnchor constraintEqualToAnchor:self.heroSearchChromeView.leadingAnchor constant:15.0],
        [self.heroSearchIconView.centerYAnchor constraintEqualToAnchor:self.heroSearchChromeView.centerYAnchor],
        [self.heroSearchIconView.widthAnchor constraintEqualToConstant:18.0],
        [self.heroSearchIconView.heightAnchor constraintEqualToConstant:18.0],

        [ self.FilterBTN.trailingAnchor constraintEqualToAnchor:self.heroSearchChromeView.trailingAnchor constant:-4.0],
        [ self.FilterBTN.centerYAnchor constraintEqualToAnchor:self.heroSearchChromeView.centerYAnchor],
        [ self.FilterBTN.widthAnchor constraintEqualToConstant:40.0],
        [ self.FilterBTN.heightAnchor constraintEqualToConstant:40.0],

    
        [self.heroLayoutToggleButton.widthAnchor constraintEqualToConstant:44.0],
        [self.heroLayoutToggleButton.heightAnchor constraintEqualToConstant:44.0],

        [self.heroSearchTextField.leadingAnchor constraintEqualToAnchor:self.heroSearchIconView.trailingAnchor constant:9.0],
        [self.heroSearchTextField.trailingAnchor constraintEqualToAnchor:self.heroLayoutToggleButton.leadingAnchor constant:-7.0],
        [self.heroSearchTextField.topAnchor constraintEqualToAnchor:self.heroSearchChromeView.topAnchor constant:6.0],
        [self.heroSearchTextField.bottomAnchor constraintEqualToAnchor:self.heroSearchChromeView.bottomAnchor constant:-6.0],

       
    ]];

     [self pp_updateLayoutToggleAppearanceAnimated:NO];
    [self pp_configureHeroFilterMenu];
 }
- (UIButton *)pp_makeHeroBackButton
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.accessibilityLabel = kLang(@"Back") ?: @"Back";
    button.accessibilityHint = kLang(@"seller_profile_back_hint") ?: @"Double-tap to go back";
    button.accessibilityTraits = UIAccessibilityTraitButton;
    button.adjustsImageWhenHighlighted = NO;

    UIImage *image = [UIImage pp_symbolNamed:PPChevronName
                                    pointSize:17.0
                                       weight:UIImageSymbolWeightSemibold
                                        scale:UIImageSymbolScaleMedium
                                      palette:@[UIColor.labelColor, UIColor.labelColor]
                                 makeTemplate:YES];
    UIColor *fill = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.08]
            : ([AppForgroundColr colorWithAlphaComponent:0.92] ?: [UIColor colorWithWhite:1.0 alpha:0.92]);
    }];
    UIColor *stroke = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.12]
            : [UIColor colorWithWhite:1.0 alpha:0.82];
    }];

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
        configuration.image = image;
        configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(11.0, 11.0, 11.0, 11.0);
        configuration.baseForegroundColor = UIColor.labelColor;
        configuration.background.backgroundColor = fill;
        configuration.background.strokeColor = stroke;
        configuration.background.strokeWidth = 0.8;
        button.configuration = configuration;
    } else {
        [button setImage:image forState:UIControlStateNormal];
        button.tintColor = UIColor.labelColor;
        button.backgroundColor = fill;
        button.layer.cornerRadius = 22.0;
        button.layer.borderWidth = 0.8;
        [button pp_setBorderColor:[stroke resolvedColorWithTraitCollection:self.traitCollection]];
    }

    button.layer.shadowColor = UIColor.blackColor.CGColor;
    button.layer.shadowOpacity = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.0 : 0.02;
    button.layer.shadowRadius = 4.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 2.0);
    [button addTarget:self action:@selector(pp_handleHeroBack) forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(handleButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(handleButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    return button;
}

#pragma mark - Hero Filter Menu

- (void)pp_configureHeroFilterMenu
{
    if (!self.FilterBTN) {
        return;
    }

    self.FilterBTN.accessibilityLabel = kLang(@"provider_companies_filter_menu") ?: @"Provider options";
    self.FilterBTN.accessibilityHint = kLang(@"provider_companies_filter_menu_hint") ?: @"Shows view and sorting options";

    if (@available(iOS 14.0, *)) {
        self.FilterBTN.showsMenuAsPrimaryAction = YES;
        self.FilterBTN.menu = [self pp_makeHeroFilterMenu];
    } else {
        [self.FilterBTN addTarget:self
                                  action:@selector(pp_handleFilterBTNTap:)
                        forControlEvents:UIControlEventTouchUpInside];
    }
}

- (void)pp_refreshHeroFilterMenuIfNeeded
{
    if (@available(iOS 14.0, *)) {
        if (self.FilterBTN) {
            self.FilterBTN.menu = [self pp_makeHeroFilterMenu];
        }
    }
}

- (void)pp_handleFilterBTNTap:(UIButton *)sender
{
    [self pp_presentLegacyHeroFilterSheetFromButton:sender];
}

- (void)pp_applyDiscoveryModeFromFilterMenu:(PPProviderCompaniesDiscoveryMode)mode
{
    if (mode == self.selectedDiscoveryMode) {
        return;
    }

    self.selectedDiscoveryMode = mode;
     [self pp_refreshHeroFilterMenuIfNeeded];

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

- (void)pp_presentLegacyHeroFilterSheetFromButton:(UIButton *)button
{
    UIAlertController *sheet =
    [UIAlertController alertControllerWithTitle:(kLang(@"provider_companies_filter_menu") ?: @"Provider options")
                                        message:nil
                                 preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray<NSNumber *> *modes = @[
        @(PPProviderCompaniesDiscoveryModeFeatured),
        @(PPProviderCompaniesDiscoveryModeTopSellers),
        @(PPProviderCompaniesDiscoveryModeNewest)
    ];

    for (NSNumber *modeNumber in modes) {
        PPProviderCompaniesDiscoveryMode mode = (PPProviderCompaniesDiscoveryMode)modeNumber.integerValue;
        NSString *title = PPProviderCompaniesDiscoveryTitle(mode);

        if (mode == self.selectedDiscoveryMode) {
            title = [NSString stringWithFormat:@"✓ %@", title];
        }

        __weak typeof(self) weakSelf = self;
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) { return; }
            [self pp_applyDiscoveryModeFromFilterMenu:mode];
        }]];
    }

    NSString *layoutTitle = self.prefersCompactListLayout
        ? (kLang(@"provider_companies_layout_toggle_grid") ?: @"Show premium cards")
        : (kLang(@"provider_companies_layout_toggle_list") ?: @"Show compact list");

    __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:layoutTitle
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { return; }
        [self pp_handleLayoutToggleButton];
        [self pp_refreshHeroFilterMenuIfNeeded];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:(kLang(@"cancel") ?: @"Cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    UIView *sourceView = button ?: self.FilterBTN ?: self.view;
    sheet.popoverPresentationController.sourceView = sourceView;
    sheet.popoverPresentationController.sourceRect = sourceView.bounds;
    sheet.popoverPresentationController.permittedArrowDirections =
        UIPopoverArrowDirectionUp | UIPopoverArrowDirectionDown;

    [self presentViewController:sheet animated:YES completion:nil];
}

- (UIMenu *)pp_makeHeroFilterMenu API_AVAILABLE(ios(14.0))
{
    NSMutableArray<UIMenuElement *> *discoveryActions = [NSMutableArray array];

    NSArray<NSNumber *> *modes = @[
        @(PPProviderCompaniesDiscoveryModeFeatured),
        @(PPProviderCompaniesDiscoveryModeTopSellers),
        @(PPProviderCompaniesDiscoveryModeNewest)
    ];

    for (NSNumber *modeNumber in modes) {
        PPProviderCompaniesDiscoveryMode mode = (PPProviderCompaniesDiscoveryMode)modeNumber.integerValue;

        UIImage *image = nil;
        if (@available(iOS 13.0, *)) {
            image = [UIImage systemImageNamed:PPProviderCompaniesDiscoverySymbol(mode)];
        }

        UIAction *action =
        [UIAction actionWithTitle:PPProviderCompaniesDiscoveryTitle(mode)
                            image:image
                       identifier:nil
                          handler:^(__kindof UIAction * _Nonnull action) {
            [self pp_applyDiscoveryModeFromFilterMenu:mode];
        }];

        action.state = (mode == self.selectedDiscoveryMode)
            ? UIMenuElementStateOn
            : UIMenuElementStateOff;

        [discoveryActions addObject:action];
    }

    NSString *layoutTitle = self.prefersCompactListLayout
        ? (kLang(@"provider_companies_layout_toggle_grid") ?: @"Show premium cards")
        : (kLang(@"provider_companies_layout_toggle_list") ?: @"Show compact list");

    UIImage *layoutImage = nil;
    if (@available(iOS 13.0, *)) {
        layoutImage = [UIImage systemImageNamed:(self.prefersCompactListLayout
            ? @"square.grid.2x2.fill"
            : @"rectangle.grid.1x2.fill")];
    }

    UIAction *layoutAction =
    [UIAction actionWithTitle:layoutTitle
                        image:layoutImage
                   identifier:nil
                      handler:^(__kindof UIAction * _Nonnull action) {
        [self pp_handleLayoutToggleButton];
        [self pp_refreshHeroFilterMenuIfNeeded];
    }];

    UIMenu *discoveryMenu =
    [UIMenu menuWithTitle:(kLang(@"provider_companies_discovery_title") ?: @"View")
                    image:nil
               identifier:nil
                  options:UIMenuOptionsDisplayInline
                 children:discoveryActions];

    UIMenu *layoutMenu =
    [UIMenu menuWithTitle:@""
                    image:nil
               identifier:nil
                  options:UIMenuOptionsDisplayInline
                 children:@[layoutAction]];

    return [UIMenu menuWithTitle:@""
                           image:nil
                      identifier:nil
                         options:0
                        children:@[discoveryMenu, layoutMenu]];
}

#pragma mark - Actions

- (void)handleButtonTouchDown:(UIButton *)sender {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        sender.transform = CGAffineTransformMakeScale(0.965, 0.965);
    } completion:nil];
}

- (void)handleButtonTouchUp:(UIButton *)sender {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    [UIView animateWithDuration:0.20
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        sender.transform = CGAffineTransformIdentity;
    } completion:nil];
}
- (void)pp_handleHeroBack
{
    if (self.navigationController.viewControllers.firstObject != self) {
        [self.navigationController popViewControllerAnimated:YES];
    } else if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    [self playLightFeedback];
}

- (void)playLightFeedback {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [generator prepare];
        [generator impactOccurred];
    }
}


- (void)pp_handleLayoutToggleButton
{
    self.prefersCompactListLayout = !self.prefersCompactListLayout;
    [self pp_updateLayoutToggleAppearanceAnimated:YES];

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
  
    UIColor *foregroundColor = self.prefersCompactListLayout
        ? accent
        : [AppPrimaryTextClr ?: UIColor.labelColor colorWithAlphaComponent:0.74];
    NSString *symbolName = self.prefersCompactListLayout ? @"square.grid.2x2.fill" : @"rectangle.grid.1x2.fill";
    NSString *accessibilityLabel = self.prefersCompactListLayout
        ? (kLang(@"provider_companies_layout_toggle_grid") ?: @"Show premium cards")
        : (kLang(@"provider_companies_layout_toggle_list") ?: @"Show compact list");

    UIImage *image = [[UIImage systemImageNamed:symbolName
                                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14.0
                                                                                                  weight:UIImageSymbolWeightMedium scale:UIImageSymbolScaleDefault]]
                    imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    void (^changes)(void) = ^{
        if (PPIOS26()) {
            if (@available(iOS 26.0, *)) {
                UIButtonConfiguration *cfg =  [UIButtonConfiguration glassButtonConfiguration];
                cfg.image = image;
                cfg.baseForegroundColor = [foregroundColor colorWithAlphaComponent:0.7];
                cfg.background.backgroundColor = backgroundColor;
                cfg.background.strokeColor = UIColor.clearColor;
                cfg.background.strokeWidth = 0.0;
                self.heroLayoutToggleButton.configuration = cfg;
            } else {
                // Fallback on earlier versions
            }
        } else {
            self.heroLayoutToggleButton.backgroundColor = backgroundColor;
            self.heroLayoutToggleButton.layer.borderWidth = 0.0;
            [self.heroLayoutToggleButton pp_setBorderColor:UIColor.clearColor];
            self.heroLayoutToggleButton.layer.shadowColor = UIColor.blackColor.CGColor;
            self.heroLayoutToggleButton.layer.shadowOpacity = 0.02;
            self.heroLayoutToggleButton.layer.shadowRadius = 4.0;
            self.heroLayoutToggleButton.layer.shadowOffset = CGSizeMake(0.0, 2.0);
            self.heroLayoutToggleButton.tintColor = [foregroundColor colorWithAlphaComponent:0.7];
            [self.heroLayoutToggleButton setImage:image forState:UIControlStateNormal];
        }
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
        self.heroSearchChromeView.backgroundColor = PPIOS26() ? AppClearClr  : surfaceColor;
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

- (void)pp_startHeroAmbientMotionIfNeeded
{
    [self pp_beginPremiumBackgroundGlowMotionIfNeeded];
}

- (void)pp_applyPremiumProviderBackgroundAppearance
{
    UIColor *backgroundColor = AppBackgroundClr ?: UIColor.whiteColor;
    self.view.backgroundColor = backgroundColor;
    [self pp_installPremiumBackgroundGlowViewsIfNeeded];
    self.pp_premiumBackgroundCanvasView.backgroundColor = backgroundColor;
    self.tableView.backgroundColor = UIColor.clearColor;
    [self pp_updatePremiumBackgroundGlowAppearance];
}

- (PPProviderCompaniesAmbientGlowView *)pp_makePremiumBackgroundGlowView
{
    return [[PPProviderCompaniesAmbientGlowView alloc] initWithFrame:CGRectZero];
}

- (void)pp_installPremiumBackgroundGlowViewsIfNeeded
{
    if (!self.pp_premiumBackgroundCanvasView) {
        UIView *canvasView = [[UIView alloc] initWithFrame:CGRectZero];
        canvasView.translatesAutoresizingMaskIntoConstraints = NO;
        canvasView.userInteractionEnabled = NO;
        canvasView.isAccessibilityElement = NO;
        canvasView.accessibilityElementsHidden = YES;
        canvasView.clipsToBounds = YES;
        canvasView.opaque = YES;
        self.pp_premiumBackgroundCanvasView = canvasView;
        [self.view insertSubview:canvasView atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [canvasView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
            [canvasView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [canvasView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [canvasView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
        ]];
    } else if (self.pp_premiumBackgroundCanvasView.superview != self.view) {
        [self.view insertSubview:self.pp_premiumBackgroundCanvasView atIndex:0];
    }

    if (!self.pp_premiumBackgroundGlowViewTop) {
        self.pp_premiumBackgroundGlowViewTop = [self pp_makePremiumBackgroundGlowView];
    }
    if (!self.pp_premiumBackgroundGlowViewMid) {
        self.pp_premiumBackgroundGlowViewMid = [self pp_makePremiumBackgroundGlowView];
    }
    if (!self.pp_premiumBackgroundGlowViewBottom) {
        self.pp_premiumBackgroundGlowViewBottom = [self pp_makePremiumBackgroundGlowView];
    }

    for (PPProviderCompaniesAmbientGlowView *glowView in @[
        self.pp_premiumBackgroundGlowViewBottom,
        self.pp_premiumBackgroundGlowViewMid,
        self.pp_premiumBackgroundGlowViewTop
    ]) {
        if (glowView.superview != self.pp_premiumBackgroundCanvasView) {
            [self.pp_premiumBackgroundCanvasView addSubview:glowView];
        }
    }

    [self.view sendSubviewToBack:self.pp_premiumBackgroundCanvasView];
}

- (void)pp_applyPremiumGlowView:(PPProviderCompaniesAmbientGlowView *)glowView
                          color:(UIColor *)color
                      peakAlpha:(CGFloat)peakAlpha
                    middleAlpha:(CGFloat)middleAlpha
{
    if (!glowView || !color) {
        return;
    }

    glowView.alpha = 1.0;
    UIColor *resolvedColor = color;
    if (@available(iOS 13.0, *)) {
        resolvedColor = [color resolvedColorWithTraitCollection:self.traitCollection];
    }
    glowView.faded = self.backgroundGlowsFadedByHomeConfig;
    [glowView setNeedsLayout];
    [glowView applyColor:resolvedColor peakAlpha:peakAlpha middleAlpha:middleAlpha];
}

- (void)pp_updatePremiumBackgroundGlowAppearance
{
    BOOL isDark = NO;
    if (@available(iOS 12.0, *)) {
        isDark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    }

    BOOL reduceTransparency = UIAccessibilityIsReduceTransparencyEnabled();
    BOOL increaseContrast = UIAccessibilityDarkerSystemColorsEnabled();
    CGFloat accessibilityScale = (reduceTransparency || increaseContrast) ? 0.70 : 1.0;

    UIColor *signatureColor = AppPrimaryClrShiner ?: UIColor.systemPurpleColor;
    UIColor *supportingColor = AppPrimaryClrShiner ?: AppForgroundColr ?: signatureColor;
    UIColor *topAtmosphereColor = AppPrimaryClrShiner;
    [self pp_applyPremiumGlowView:self.pp_premiumBackgroundGlowViewTop
                            color:topAtmosphereColor
                        peakAlpha:(isDark ? 0.118 : 0.038) * accessibilityScale
                      middleAlpha:(isDark ? 0.054 : 0.058) * accessibilityScale];

    [self pp_applyPremiumGlowView:self.pp_premiumBackgroundGlowViewMid
                            color:supportingColor
                        peakAlpha:(isDark ? 0.075 : 0.045) * accessibilityScale
                      middleAlpha:(isDark ? 0.026 : (self.backgroundGlowsFadedByHomeConfig ? 0.018 : 0.035)) * accessibilityScale];

    [self pp_applyPremiumGlowView:self.pp_premiumBackgroundGlowViewBottom
                            color:signatureColor
                        peakAlpha:(isDark ? 0.27 : 0.051) * accessibilityScale
                      middleAlpha:(isDark ? 0.095 : 0.082) * accessibilityScale];
}

- (void)pp_layoutPremiumBackgroundGlowViews
{
    CGRect bounds = self.view.bounds;
    if (CGRectIsEmpty(bounds)) {
        return;
    }

    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);
    CGFloat safeTop = self.view.safeAreaInsets.top;
    CGSize canvasSize = bounds.size;
    BOOL motionLayoutChanged = (fabs(canvasSize.width - self.premiumBackgroundGlowMotionCanvasSize.width) > 0.5 ||
                                fabs(canvasSize.height - self.premiumBackgroundGlowMotionCanvasSize.height) > 0.5);
    if (motionLayoutChanged && self.didStartPremiumBackgroundGlowMotion) {
        [self pp_stopPremiumBackgroundGlowMotion];
    }
    self.premiumBackgroundGlowMotionCanvasSize = canvasSize;

    CGFloat topSize = MIN(228.0, MAX(176.0, width * 0.72));
    CGFloat midSize = MIN(340.0, MAX(150.0, width * 0.86));
    CGFloat bottomSize = MIN(260.0, MAX(280.0, width * 1.12));
    BOOL isRTL = self.view.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    self.pp_premiumBackgroundGlowViewTop.bounds = CGRectMake(0.0, 0.0, topSize, topSize);
    self.pp_premiumBackgroundGlowViewTop.center = CGPointMake(
        isRTL ? topSize * 0.22 : width - (topSize * 0.22),
        safeTop + (topSize * 0.10)
    );

    self.pp_premiumBackgroundGlowViewMid.bounds = CGRectMake(0.0, 0.0, midSize, midSize);
    CGFloat middleY = MAX(180.0, height * 0.52);
    if (self.backgroundGlowsFadedByHomeConfig) {
        self.pp_premiumBackgroundGlowViewMid.center = CGPointMake(CGRectGetMidX(bounds), middleY);
    } else {
        self.pp_premiumBackgroundGlowViewMid.center = CGPointMake(
            isRTL ? width - (midSize * 0.20) : midSize * 0.20,
            middleY
        );
    }

    self.pp_premiumBackgroundGlowViewBottom.bounds = CGRectMake(0.0, 0.0, bottomSize, bottomSize);
    self.pp_premiumBackgroundGlowViewBottom.center = CGPointMake(
        isRTL ? bottomSize * 0.34 : width - (bottomSize * 0.34),
        height - (bottomSize * 0.07)
    );

    [CATransaction commit];

    [self.pp_premiumBackgroundGlowViewTop setNeedsLayout];
    [self.pp_premiumBackgroundGlowViewMid setNeedsLayout];
    [self.pp_premiumBackgroundGlowViewBottom setNeedsLayout];

    if (motionLayoutChanged && self.providerCompaniesScreenVisible) {
        [self pp_beginPremiumBackgroundGlowMotionIfNeeded];
    }
}

- (BOOL)pp_shouldReduceProviderBackgroundMotion
{
    return UIAccessibilityIsReduceMotionEnabled();
}

- (void)pp_addRandomizedMiddleBackgroundGlowPositionMotion
{
    PPProviderCompaniesAmbientGlowView *glowView = self.pp_premiumBackgroundGlowViewMid;
    if (!glowView || CGRectIsEmpty(glowView.bounds) ||
        [glowView.layer animationForKey:PPProviderCompaniesMiddleBackgroundGlowPositionMotionKey]) {
        return;
    }

    CGFloat canvasWidth = CGRectGetWidth(self.pp_premiumBackgroundCanvasView.bounds);
    CGFloat canvasHeight = CGRectGetHeight(self.pp_premiumBackgroundCanvasView.bounds);
    CGFloat maximumXOffset = MIN(92.0, MAX(64.0, canvasWidth * 0.22));
    CGFloat maximumYOffset = MIN(116.0, MAX(78.0, canvasHeight * 0.115));
    CGPoint restingPosition = glowView.layer.position;

    NSMutableArray<NSValue *> *positions = [NSMutableArray arrayWithObject:[NSValue valueWithCGPoint:restingPosition]];
    NSMutableArray<NSNumber *> *keyTimes = [NSMutableArray arrayWithObject:@0.0];
    static NSInteger const waypointCount = 7;
    for (NSInteger index = 1; index <= waypointCount; index++) {
        CGFloat randomXUnit = ((CGFloat)arc4random_uniform(2001) / 1000.0) - 1.0;
        CGFloat randomYUnit = ((CGFloat)arc4random_uniform(2001) / 1000.0) - 1.0;
        CGPoint waypoint = CGPointMake(restingPosition.x + (randomXUnit * maximumXOffset),
                                       restingPosition.y + (randomYUnit * maximumYOffset));
        [positions addObject:[NSValue valueWithCGPoint:waypoint]];
        [keyTimes addObject:@((CGFloat)index / (CGFloat)(waypointCount + 1))];
    }
    [positions addObject:[NSValue valueWithCGPoint:restingPosition]];
    [keyTimes addObject:@1.0];

    CFTimeInterval duration = 13.0 + ((CGFloat)arc4random_uniform(3501) / 1000.0);
    CAKeyframeAnimation *positionAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    positionAnimation.values = positions;
    positionAnimation.keyTimes = keyTimes;
    positionAnimation.calculationMode = kCAAnimationCubic;
    positionAnimation.duration = duration;
    positionAnimation.repeatCount = HUGE_VALF;
    positionAnimation.removedOnCompletion = YES;
    positionAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    CFTimeInterval localNow = [glowView.layer convertTime:CACurrentMediaTime() fromLayer:nil];
    CGFloat randomPhase = ((CGFloat)arc4random_uniform(10001) / 10000.0) * duration;
    positionAnimation.beginTime = localNow - randomPhase;

    [glowView.layer addAnimation:positionAnimation forKey:PPProviderCompaniesMiddleBackgroundGlowPositionMotionKey];
}

- (void)pp_addPremiumMiddleBackgroundGlowPeekMotionIfNeeded
{
    PPProviderCompaniesAmbientGlowView *glowView = self.pp_premiumBackgroundGlowViewMid;
    if (!glowView || CGRectIsEmpty(glowView.bounds) ||
        [glowView.layer animationForKey:PPProviderCompaniesMiddleBackgroundGlowPeekMotionKey]) {
        return;
    }

    CGFloat travelDistance = MIN(26.0, MAX(16.0, CGRectGetWidth(glowView.bounds) * 0.08));
    CGFloat direction = self.view.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft ? -1.0 : 1.0;

    CABasicAnimation *positionAnimation =
        [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    positionAnimation.fromValue = @(0.0);
    positionAnimation.toValue = @(travelDistance * direction);

    CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityAnimation.fromValue = @0.88;
    opacityAnimation.toValue = @1.0;

    CABasicAnimation *scaleAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnimation.fromValue = @0.985;
    scaleAnimation.toValue = @1.018;

    CAAnimationGroup *peekAnimation = [CAAnimationGroup animation];
    peekAnimation.animations = @[positionAnimation, opacityAnimation, scaleAnimation];
    peekAnimation.duration = 4.8;
    peekAnimation.autoreverses = YES;
    peekAnimation.repeatCount = HUGE_VALF;
    peekAnimation.removedOnCompletion = YES;
    peekAnimation.timingFunction =
        [CAMediaTimingFunction functionWithControlPoints:0.35 :0.0 :0.18 :1.0];

    [glowView.layer addAnimation:peekAnimation forKey:PPProviderCompaniesMiddleBackgroundGlowPeekMotionKey];
}

- (void)pp_beginPremiumBackgroundGlowMotionIfNeeded
{
    if (self.didStartPremiumBackgroundGlowMotion ||
        [self pp_shouldReduceProviderBackgroundMotion] ||
        !self.providerCompaniesScreenVisible ||
        self.view.window == nil ||
        CGRectIsEmpty(self.pp_premiumBackgroundGlowViewMid.bounds)) {
        return;
    }
    self.didStartPremiumBackgroundGlowMotion = YES;
    if (self.backgroundGlowsFadedByHomeConfig) {
        [self pp_addRandomizedMiddleBackgroundGlowPositionMotion];
    } else {
        [self pp_addPremiumMiddleBackgroundGlowPeekMotionIfNeeded];
    }
}

- (void)pp_stopPremiumBackgroundGlowMotion
{
    self.didStartPremiumBackgroundGlowMotion = NO;
    [self.pp_premiumBackgroundGlowViewMid.layer removeAnimationForKey:PPProviderCompaniesMiddleBackgroundGlowPositionMotionKey];
    [self.pp_premiumBackgroundGlowViewMid.layer removeAnimationForKey:PPProviderCompaniesMiddleBackgroundGlowPeekMotionKey];
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
    [[PPBottomSurfaceCoordinator sharedCoordinator] applySurfaceForController:self animated:YES];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    self.searchChromeFocused = NO;
    [self pp_applyPremiumSearchChromeAppearanceFocused:NO animated:YES];
    [[PPBottomSurfaceCoordinator sharedCoordinator] applySurfaceForController:self animated:YES];
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
    model.countDisplayText = PPProviderCompaniesItemsCountText(entry.productCount, self.selectedProviderCategoryIdentifier);
    model.cityText = PPProviderCompaniesCityForEntry(entry);
    model.avatarPlaceholderImage = [PPModernAvatarRenderer avatarImageForName:title size:60.0];
    NSString *avatarURLString =
        [PPProviderCompaniesSafeString(entry.profileAvatarURLString)
         stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (avatarURLString.length == 0) {
        avatarURLString =
            [PPProviderCompaniesSafeString(entry.user.UserImageUrl.absoluteString)
             stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    if (avatarURLString.length > 0) {
        model.avatarURL = [NSURL URLWithString:avatarURLString];
    }
    model.accentColor = AppPrimaryClr ?: [UIColor colorWithRed:0.93 green:0.43 blue:0.18 alpha:1.0];
    model.verified = entry.user.isVerified;
    model.active = [PPProviderCompaniesSafeString(entry.user.accountStatus) isEqualToString:@"active"];
    model.accessoryStyle = PPProviderCompanyPremiumCardAccessoryStyleHeart;

    if (entry.user.providerReviewCount > 0 && entry.user.providerRatingValue > 0.0) {
        model.ratingText = [NSString stringWithFormat:@"%.1f", entry.user.providerRatingValue];
        model.ratingCountText = [NSString stringWithFormat:@"(%ld)", (long)entry.user.providerReviewCount];
    } else {
        model.ratingText = kLang(@"provider_rating_new") ?: @"New";
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
