//
//  PPSearchViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 05/01/2026.
//

#import "PPSearchViewController.h"

#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

#import "BBNavigationBar.h"
#import "AdoptPetModel.h"
#import "Language.h"
#import "PPImageLoaderManager.h"
#import "PPOverlayCoordinator.h"
#import "PPHUD.h"
#import "PPInsetLabel.h"
#import "PPSearchHelper.h"
#import "PPUniversalCell.h"
#import "PPUniversalCellViewModel.h"
#import "PetAccessory.h"
#import "PetAd.h"
#import "SearchCacheManager.h"
#import "ServiceModel.h"
#import "PPPermissionHelper.h"
#import "PPImageSearchService.h"
#import "PPNovaChatViewController.h"

typedef NS_ENUM(NSUInteger, PPSearchSection) {
    PPSearchSectionResults = 0
};

typedef NS_ENUM(NSInteger, PPSearchSegment) {
    PPSearchSegmentAds = 0,
    PPSearchSegmentServices = 1,
    PPSearchSegmentAccessories = 2
};

static CGFloat const kPPSearchHorizontalInset = 16.0;
static CGFloat const kPPSearchInteritemSpacing = 14.0;
static CGFloat const kPPSearchLineSpacing = 18.0;
static NSInteger const kPPSearchMinimumQueryLength = 2;
static NSInteger const kPPSearchSegmentIconTag = 9101;
static NSInteger const kPPSearchSegmentTitleTag = 9102;
static NSInteger const kPPSearchSegmentCountTag = 9103;
static NSTimeInterval const kPPSearchDebounceDelay = 0.22;

@interface PPSearchRankedResult : NSObject

@property (nonatomic, strong) id object;
@property (nonatomic, assign) PPSearchScore searchScore;
@property (nonatomic, copy) NSString *displayTitle;
@property (nonatomic, copy) NSString *stableIdentifier;

@end

@implementation PPSearchRankedResult
@end

@interface PPSearchViewController ()
<UITextFieldDelegate,
UICollectionViewDelegate,
UICollectionViewDelegateFlowLayout,
PPUniversalCellDelegate,
UIImagePickerControllerDelegate,
UINavigationControllerDelegate>

@property (nonatomic, strong) UIView *searchBarContainerView;
@property (nonatomic, strong) UIView *searchFieldChromeView;
@property (nonatomic, strong) UIImageView *searchFieldIconView;
@property (nonatomic, strong) UITextField *searchTextField;
@property (nonatomic, strong) UILabel *searchPlaceholderLabel;
@property (nonatomic, strong) UIView *bottomSearchFadeView;
@property (nonatomic, strong) CAGradientLayer *bottomSearchFadeLayer;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UICollectionViewDiffableDataSource<NSNumber *, PPUniversalCellViewModel *> *dataSource;

@property (nonatomic, copy) NSArray<PPUniversalCellViewModel *> *results;
@property (nonatomic, copy) NSArray<id> *allSearchResults;
@property (nonatomic, copy, nullable) NSString *lastQuery;

@property (nonatomic, strong) UIView *primaryGlowView;
@property (nonatomic, strong) UIView *secondaryGlowView;
@property (nonatomic, strong) UIView *heroCardShadowView;
@property (nonatomic, strong) UIView *heroCardView;
@property (nonatomic, strong) CAGradientLayer *heroGradientLayer;
@property (nonatomic, strong) CAGradientLayer *heroMeshLayer;
@property (nonatomic, strong) CAGradientLayer *heroShineLayer;
@property (nonatomic, strong) UILabel *eyebrowLabel;
@property (nonatomic, strong) UILabel *heroTitleLabel;
@property (nonatomic, strong) UILabel *heroSubtitleLabel;
@property (nonatomic, strong) UIScrollView *segmentScrollView;
@property (nonatomic, strong) UIStackView *segmentButtonsStackView;
@property (nonatomic, copy) NSArray<UIButton *> *segmentButtons;
@property (nonatomic, strong) UIStackView *metaStackView;
@property (nonatomic, strong) UILabel *statusPillLabel;
@property (nonatomic, strong) UILabel *scopePillLabel;
@property (nonatomic, strong) UILabel *countPillLabel;
@property (nonatomic, strong) UILabel *queryPillLabel;
@property (nonatomic, strong) UIButton *novaNavigationButton;

@property (nonatomic, assign) PPSearchSegment selectedSearchSegment;
@property (nonatomic, strong) UIView *segmentGlassView;
@property (nonatomic, strong) UILabel *adsBadge;
@property (nonatomic, strong) UILabel *servicesBadge;
@property (nonatomic, strong) UILabel *accessoriesBadge;

@property (nonatomic, strong) UIView *emptyStateView;
@property (nonatomic, strong) UIImageView *emptyStateIconView;
@property (nonatomic, strong) UILabel *emptyTitleLabel;
@property (nonatomic, strong) UILabel *emptySubtitleLabel;
@property (nonatomic, strong) UIView *imageSearchLoadingView;
@property (nonatomic, strong) UIView *imageSearchLoadingCardView;
@property (nonatomic, strong) UIView *imageSearchLoadingOrbView;
@property (nonatomic, strong) UIImageView *imageSearchLoadingIconView;
@property (nonatomic, strong) UILabel *imageSearchLoadingTitleLabel;
@property (nonatomic, strong) UILabel *imageSearchLoadingSubtitleLabel;
@property (nonatomic, strong) CAGradientLayer *imageSearchLoadingOrbGradientLayer;
@property (nonatomic, assign) BOOL imageSearchLoadingVisible;

@property (nonatomic, assign) BOOL isSearching;
@property (nonatomic, assign) BOOL didAnimateHero;
@property (nonatomic, assign) NSInteger currentSearchRequestID;
@property (nonatomic, assign) NSInteger imageSearchRequestGeneration;
@property (nonatomic, strong, nullable) UIImage *lastImageSearchImage;
@property (nonatomic, strong) UIButton *imageSearchButton;
@property (nonatomic, copy) NSArray<NSDictionary *> *imageSearchResultRefs;
@property (nonatomic, copy) NSArray<NSDictionary *> *imageSearchRawResults;
@property (nonatomic, copy) NSArray<PPUniversalCellViewModel *> *imageSearchAllResults;
@property (nonatomic, strong) dispatch_queue_t searchQueue;
@property (nonatomic, copy, nullable) dispatch_block_t pendingDebounceBlock;
@property (nonatomic, assign) BOOL pendingSearchFieldFocus;
@property (nonatomic, assign) BOOL previousIQKeyboardManagerEnabled;
@property (nonatomic, assign) BOOL previousIQKeyboardToolbarEnabled;
@property (nonatomic, assign) BOOL isOverridingIQKeyboardManager;

@property (nonatomic, strong) NSLayoutConstraint *segmentRowTopExpandedConstraint;
@property (nonatomic, strong) NSLayoutConstraint *segmentRowTopCollapsedConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *searchBarBottomConstraint;
@property (nonatomic, assign) BOOL isHeroCollapsed;
@property (nonatomic, strong) UIButton *heroCollapseToggleButton;

@end

@implementation PPSearchViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    self.view.backgroundColor = AppBageColor();
    self.results = @[];
    self.allSearchResults = @[];
    self.searchQueue = dispatch_queue_create("com.purepets.search.controller", DISPATCH_QUEUE_SERIAL);

    [self setupBackdrop];
    [self setupNavigation];
    [self setupSearch];
    [self setupHeroHeader];
    [self setupCollectionView];
    [self setupBottomSearchFade];
    [self setupDataSource];
    [self setupSearchSegment];
    [self setupEmptyState];
    [self setupImageSearchLoadingState];
    [self pp_updateSearchLayering];
    [self warmUpSearchCacheIfNeeded];
    [self updateHeaderStateAnimated:NO];
    [self updateEmptyState];

    UITapGestureRecognizer *dismissTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_dismissKeyboard)];
    dismissTap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:dismissTap];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

    self.pendingSearchFieldFocus = NO;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    // Force gradient relayout on first appear — heroCardView now has correct bounds
    [self.heroCardView setNeedsLayout];
    [self.heroCardView layoutIfNeeded];
    [self.view setNeedsLayout];
    [self animateHeroIfNeeded];
    [self pp_activatePendingSearchFieldFocusIfPossible];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self pp_setRootBottomNavigationHidden:YES animated:animated];
    [self pp_applySearchKeyboardManagerOverridesIfNeeded];
    [self pp_schedulePendingSearchFieldFocusIfNeeded];
    if (self.imageSearchLoadingVisible) {
        [self pp_startImageSearchLoadingAnimations];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[self pp_searchTextField] resignFirstResponder];
    [self pp_restoreSearchKeyboardManagerOverridesIfNeeded];
    [self pp_stopImageSearchLoadingAnimations];

    BOOL isLeavingSearch =
        self.isMovingFromParentViewController ||
        self.isBeingDismissed ||
        self.navigationController.isBeingDismissed;
    if (!isLeavingSearch) {
        return;
    }

    [self pp_setRootBottomNavigationHidden:NO animated:animated];
    id<UIViewControllerTransitionCoordinator> coordinator = self.transitionCoordinator;
    if (coordinator) {
        __weak typeof(self) weakSelf = self;
        [coordinator animateAlongsideTransition:nil
                                     completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            if (!context.isCancelled) {
                return;
            }
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            [self pp_setRootBottomNavigationHidden:YES animated:YES];
        }];
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    [self pp_applyPremiumHeroBackgroundStyle];

    CGRect heroBounds = self.heroCardView.bounds;
    // Use screen-based fallback if hero hasn't been laid out yet (first pass)
    CGFloat gradientW = heroBounds.size.width;
    if (gradientW < 1.0) {
        gradientW = UIScreen.mainScreen.bounds.size.width - (PPScreenMargin * 2);
    }
    CGFloat fixedGradientH = MAX(heroBounds.size.height, 300.0);
    CGRect gradientRect = CGRectMake(0, 0, gradientW, fixedGradientH);
    self.heroGradientLayer.frame = gradientRect;
    self.heroMeshLayer.frame = gradientRect;
    self.heroShineLayer.frame = gradientRect;
    self.heroCardShadowView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.heroCardShadowView.bounds cornerRadius:PPCornerHero].CGPath;
    self.searchFieldChromeView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.searchFieldChromeView.bounds
                                   cornerRadius:self.searchFieldChromeView.layer.cornerRadius].CGPath;
    self.imageSearchLoadingCardView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.imageSearchLoadingCardView.bounds
                                   cornerRadius:self.imageSearchLoadingCardView.layer.cornerRadius].CGPath;
    self.imageSearchLoadingOrbGradientLayer.frame = self.imageSearchLoadingOrbView.bounds;
    self.imageSearchLoadingOrbView.layer.cornerRadius = CGRectGetWidth(self.imageSearchLoadingOrbView.bounds) * 0.5;
    self.primaryGlowView.layer.cornerRadius = CGRectGetWidth(self.primaryGlowView.bounds) * 0.5;
    self.secondaryGlowView.layer.cornerRadius = CGRectGetWidth(self.secondaryGlowView.bounds) * 0.5;
    [self pp_updateBottomSearchFadeLayer];
    [self pp_updateSearchLayering];

    [self.view bringSubviewToFront:self.searchBarContainerView];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if (previousTraitCollection.userInterfaceStyle != self.traitCollection.userInterfaceStyle) {
            [self pp_applyPremiumHeroBackgroundStyle];
            [self pp_updateBottomSearchFadeLayer];
            [self pp_updateSegmentButtonsSelectionAnimated:NO];
            [self pp_applyNovaNavigationButtonStyle];
            [self updateHeaderStateAnimated:NO];
        }
    }
}

- (void)dealloc
{
    if (self.pendingDebounceBlock) {
        dispatch_block_cancel(self.pendingDebounceBlock);
        self.pendingDebounceBlock = nil;
    }
    [self pp_restoreSearchKeyboardManagerOverridesIfNeeded];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (void)pp_keyboardWillShow:(NSNotification *)notification
{
    if (@available(iOS 15.0, *)) {
        self.searchBarBottomConstraint.active = NO;
        self.searchBarBottomConstraint = [self.searchBarContainerView.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor constant:-12.0];
        self.searchBarBottomConstraint.active = YES;
    }
}

- (void)pp_keyboardWillHide:(NSNotification *)notification
{
    self.searchBarBottomConstraint.active = NO;
    self.searchBarBottomConstraint = [self.searchBarContainerView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:26.0];
    self.searchBarBottomConstraint.active = YES;
}

- (void)pp_setRootBottomNavigationHidden:(BOOL)hidden animated:(BOOL)animated
{
    UITabBarController *tabBarController = self.tabBarController;
    if ([tabBarController respondsToSelector:@selector(setPremiumTabDockViewHidden:animation:)]) {
        [(id)tabBarController setPremiumTabDockViewHidden:hidden animation:animated];
        return;
    }
    if ([tabBarController respondsToSelector:@selector(pp_setBottomNavigationHidden:animated:)]) {
        [(id)tabBarController pp_setBottomNavigationHidden:hidden animated:animated];
        return;
    }

    UITabBar *tabBar = tabBarController.tabBar;
    if (!tabBar) {
        return;
    }
    if (!hidden) {
        tabBar.hidden = NO;
    }

    void (^changes)(void) = ^{
        tabBar.alpha = hidden ? 0.0 : 1.0;
    };
    void (^completion)(BOOL) = ^(__unused BOOL finished) {
        tabBar.hidden = hidden;
    };
    if (!animated) {
        changes();
        completion(YES);
        return;
    }
    [UIView animateWithDuration:0.22
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
                     animations:changes
                     completion:completion];
}

#pragma mark - Public

- (void)focusSearchField
{
    return;
}

- (void)openAccessoriesAll
{
    [self loadViewIfNeeded];
    self.selectedSearchSegment = PPSearchSegmentAccessories;
    [self pp_updateSegmentButtonsSelectionAnimated:NO];
    [self applySegmentFilter];
    [self focusSearchField];
}

#pragma mark - Setup

- (void)setupBackdrop
{
    UIView *primaryGlow = [UIView new];
    primaryGlow.translatesAutoresizingMaskIntoConstraints = NO;
    primaryGlow.userInteractionEnabled = NO;
    primaryGlow.backgroundColor = [[UIColor colorWithRed:0.92 green:0.78 blue:0.66 alpha:1.0] colorWithAlphaComponent:0.26];
    [primaryGlow pp_setShadowColor:[UIColor colorWithRed:0.92 green:0.78 blue:0.66 alpha:1.0]];
    primaryGlow.layer.shadowOpacity = 0.30;
    primaryGlow.layer.shadowRadius = 120.0;
    primaryGlow.layer.shadowOffset = CGSizeZero;
    primaryGlow.layer.cornerRadius = 50.0;

    UIView *secondaryGlow = [UIView new];
    secondaryGlow.translatesAutoresizingMaskIntoConstraints = NO;
    secondaryGlow.userInteractionEnabled = NO;
    secondaryGlow.backgroundColor = [[UIColor colorWithRed:0.48 green:0.25 blue:0.33 alpha:1.0] colorWithAlphaComponent:0.16];
    [secondaryGlow pp_setShadowColor:[UIColor colorWithRed:0.48 green:0.25 blue:0.33 alpha:1.0]];
    secondaryGlow.layer.shadowOpacity = 0.22;
    secondaryGlow.layer.shadowRadius = 96.0;
    secondaryGlow.layer.shadowOffset = CGSizeZero;
    secondaryGlow.layer.cornerRadius = 45.0;
    [self.view addSubview:primaryGlow];
    [self.view addSubview:secondaryGlow];

    [NSLayoutConstraint activateConstraints:@[
        [primaryGlow.widthAnchor constraintEqualToConstant:320.0],
        [primaryGlow.heightAnchor constraintEqualToConstant:320.0],
        [primaryGlow.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:-120.0],
        [primaryGlow.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:120.0],

        [secondaryGlow.widthAnchor constraintEqualToConstant:250.0],
        [secondaryGlow.heightAnchor constraintEqualToConstant:250.0],
        [secondaryGlow.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:140.0],
        [secondaryGlow.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-110.0]
    ]];

    self.primaryGlowView = primaryGlow;
    self.secondaryGlowView = secondaryGlow;
    [self pp_sendBackdropGlowsToBack];
    // Start hidden — animateHeroIfNeeded fades them in with breathing
    primaryGlow.alpha = 0.0;
    secondaryGlow.alpha = 0.0;
}

- (void)pp_sendBackdropGlowsToBack
{
    if (self.secondaryGlowView.superview == self.view) {
        [self.view sendSubviewToBack:self.secondaryGlowView];
    }
    if (self.primaryGlowView.superview == self.view) {
        [self.view sendSubviewToBack:self.primaryGlowView];
    }
}

- (void)BackToMain
{
    [self.navigationController popViewControllerAnimated:YES];
}


- (void)setupNavigation
{
    self.navigationItem.title = kLang(@"searchOnly");
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
   // self.navigationItem.hidesBackButton = YES;
     
    
    //if(PPIsRL)
       //self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:PPChevronName] style:UIBarButtonItemStylePlain target:self action:@selector(BackToMain)];
  //  else
        //self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:PPChevronName] //style:UIBarButtonItemStylePlain target:self action:@selector(BackToMain)];
    //BBNavigationBar *bar = [BBNavigationBar new];
    //[bar attachTo:self];

    // Add dismiss button when presented modally (not pushed)
    BOOL isModal = (self.navigationController.viewControllers.firstObject == self &&
                    self.navigationController.presentingViewController != nil);
    if (!isModal && self.presentingViewController != nil && self.navigationController == nil) {
        isModal = YES;
    }
    if (isModal) {
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold];
        UIImage *xImage = [UIImage systemImageNamed:@"xmark" withConfiguration:cfg];
        UIButton *dismissBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        dismissBtn.tintColor = AppSecondaryTextClr;
        [dismissBtn setImage:xImage forState:UIControlStateNormal];
        dismissBtn.backgroundColor = PPIOS26() ? AppClearClr : AppForgroundColr;
        dismissBtn.layer.cornerRadius = 16.0;
        if (@available(iOS 13.0, *)) {
            dismissBtn.layer.cornerCurve = kCACornerCurveContinuous;
        }
        [dismissBtn addTarget:self action:@selector(pp_dismissTapped) forControlEvents:UIControlEventTouchUpInside];
        [NSLayoutConstraint activateConstraints:@[
            [dismissBtn.widthAnchor constraintEqualToConstant:32.0],
            [dismissBtn.heightAnchor constraintEqualToConstant:32.0]
        ]];
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:dismissBtn];
    }

    UIButton *novaBtn = [self pp_makeNovaNavigationButton];
    self.novaNavigationButton = novaBtn;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:novaBtn];
    [self pp_applyNovaNavigationButtonStyle];
}

- (UIButton *)pp_makeNovaNavigationButton
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.adjustsImageWhenHighlighted = NO;
    button.showsTouchWhenHighlighted = NO;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    button.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    button.titleLabel.font = [self pp_novaNavigationTitleFont];
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.82;
    button.accessibilityLabel = kLang(@"nova_title");
    button.accessibilityHint = kLang(@"nova_subtitle");
    button.accessibilityTraits = UIAccessibilityTraitButton;

    button.contentEdgeInsets = UIEdgeInsetsZero;
    button.titleEdgeInsets = UIEdgeInsetsZero;
    button.imageEdgeInsets = UIEdgeInsetsZero;

    button.layer.cornerRadius = 18.0;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    button.layer.borderWidth = 1.0;
    button.layer.masksToBounds = NO;

    [button addTarget:self action:@selector(pp_novaNavigationButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(pp_novaNavigationButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(pp_novaNavigationButtonTouchUp:) forControlEvents:UIControlEventTouchUpOutside];
    [button addTarget:self action:@selector(pp_novaNavigationButtonTouchUp:) forControlEvents:UIControlEventTouchCancel];
    [button addTarget:self action:@selector(pp_novaNavigationButtonTouchUp:) forControlEvents:UIControlEventTouchDragExit];
    [button addTarget:self action:@selector(pp_novaButtonTapped) forControlEvents:UIControlEventTouchUpInside];

    [button setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [button setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:36.0],
        [button.heightAnchor constraintEqualToConstant:36.0]
    ]];

    return button;
}

- (UIFont *)pp_novaNavigationTitleFont
{
    return [GM BlackFontWithSize:16.0] ?: [GM boldFontWithSize:16.0] ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightBlack];
}

- (NSAttributedString *)pp_novaNavigationAttributedTitleWithColor:(UIColor *)color alpha:(CGFloat)alpha
{
    UIColor *resolvedColor = color ?: (AppPrimaryClr ?: UIColor.systemPinkColor);
    UIFont *font = [self pp_novaNavigationTitleFont];
    NSDictionary *attributes = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: [resolvedColor colorWithAlphaComponent:alpha]
    };
    return [[NSAttributedString alloc] initWithString:@"N" attributes:attributes];
}

- (void)pp_applyNovaNavigationButtonStyle
{
    UIButton *button = self.novaNavigationButton;
    if (!button) {
        return;
    }

    UIColor *foreground = AppPrimaryClr ?: UIColor.systemPinkColor;
    UIColor *background = AppForgroundColr ?: UIColor.systemBackgroundColor;
    UIColor *stroke = [foreground colorWithAlphaComponent:0.18];
    UIColor *shadow = UIColor.blackColor;
    if (@available(iOS 13.0, *)) {
        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            background = [foreground colorWithAlphaComponent:0.12];
            stroke = [foreground colorWithAlphaComponent:0.28];
        }
    }

    button.titleLabel.font = [self pp_novaNavigationTitleFont];
    button.backgroundColor = background;
    button.tintColor = foreground;
    [button setAttributedTitle:[self pp_novaNavigationAttributedTitleWithColor:foreground alpha:1.0]
                      forState:UIControlStateNormal];
    [button setAttributedTitle:[self pp_novaNavigationAttributedTitleWithColor:foreground alpha:0.62]
                      forState:UIControlStateHighlighted];
    [button setTitleColor:foreground forState:UIControlStateNormal];
    [button setTitleColor:[foreground colorWithAlphaComponent:0.62] forState:UIControlStateHighlighted];
    [button pp_setBorderColor:stroke];
    [button pp_setShadowColor:shadow];
    button.layer.shadowOpacity = 0.10f;
    button.layer.shadowRadius = 10.0f;
    button.layer.shadowOffset = CGSizeMake(0.0, 3.0);
}

- (void)pp_novaButtonTapped
{
    [self.view endEditing:YES];
    [PPFunc triggerLightHaptic];
    [PPNovaChatViewController presentNovaFromViewController:self];
}

- (void)pp_novaNavigationButtonTouchDown:(UIButton *)button
{
    if (!button || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    [UIView animateWithDuration:0.14
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        button.transform = CGAffineTransformMakeScale(0.965, 0.965);
        button.layer.shadowOpacity = 0.06f;
        button.layer.shadowRadius = 6.0f;
    } completion:nil];
}

- (void)pp_novaNavigationButtonTouchUp:(UIButton *)button
{
    if (!button) {
        return;
    }

    void (^updates)(void) = ^{
        button.transform = CGAffineTransformIdentity;
        button.layer.shadowOpacity = 0.10f;
        button.layer.shadowRadius = 10.0f;
    };

    if (UIAccessibilityIsReduceMotionEnabled()) {
        updates();
        return;
    }

    [UIView animateWithDuration:0.28
                          delay:0.0
         usingSpringWithDamping:0.78
          initialSpringVelocity:0.42
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:updates
                     completion:nil];
}

- (void)pp_dismissTapped
{
    [self.view endEditing:YES];
    if (self.navigationController.presentingViewController) {
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)pp_dismissKeyboard
{
    [self.view endEditing:YES];
}

- (void)setupSearch
{
    //UISemanticContentAttribute semanticAttribute = Language.semanticAttributeForCurrentLanguage;

    UIView *container = [UIView new];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = UIColor.clearColor;
    container.preservesSuperviewLayoutMargins = YES;
    container.layer.zPosition = 1000.0;
     if (@available(iOS 11.0, *)) {
        container.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(0.0,
                                                                        kPPSearchHorizontalInset,
                                                                        8.0,
                                                                        kPPSearchHorizontalInset);
    } else {
        container.layoutMargins = UIEdgeInsetsMake(0.0, kPPSearchHorizontalInset, 8.0, kPPSearchHorizontalInset);
    }

    NSString *placeholderText = [self pp_modernSearchPlaceholderText];
    UIView *chromeView = [UIView new];
    chromeView.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        chromeView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [[UIColor colorWithRed:0.10 green:0.08 blue:0.11 alpha:1.0] colorWithAlphaComponent:0.96];
            }
            return [[UIColor whiteColor] colorWithAlphaComponent:0.96];
        }];
    } else {
        chromeView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.96];
    }
    //chromeView.semanticContentAttribute = semanticAttribute;
    chromeView.layer.cornerRadius = 20.0;
    chromeView.layer.masksToBounds = NO;
    chromeView.layer.borderWidth = 1.0;
    [chromeView pp_setBorderColor:[UIColor colorWithWhite:0.0 alpha:0.14]];
    [chromeView pp_setShadowColor:[UIColor colorWithWhite:0.09 alpha:1.0]];
    chromeView.layer.shadowOpacity = 0.12f;
    chromeView.layer.shadowRadius = 18.0f;
    chromeView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    if (@available(iOS 13.0, *)) {
        chromeView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIView *accentView = [UIView new];
    accentView.translatesAutoresizingMaskIntoConstraints = NO;
    accentView.backgroundColor = AppPrimaryClr ?: [UIColor colorWithRed:0.72 green:0.22 blue:0.36 alpha:1.0];
    accentView.layer.cornerRadius = 1.5;
    accentView.layer.masksToBounds = YES;

    UIImageSymbolConfiguration *iconConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    UIImageView *iconView =
        [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:iconConfig]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = [UIColor colorWithWhite:0.38 alpha:1.0];
    iconView.contentMode = UIViewContentModeScaleAspectFit;

    UITextField *textField = [UITextField new];
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    textField.delegate = self;
  // textField.semanticContentAttribute = semanticAttribute;
    textField.textAlignment = NSTextAlignmentNatural;
    textField.textColor = UIColor.labelColor;
    textField.tintColor = AppPrimaryClr;
    textField.font = [GM MidFontWithSize:15.5] ?: [UIFont systemFontOfSize:15.5 weight:UIFontWeightMedium];
    textField.borderStyle = UITextBorderStyleNone;
    textField.backgroundColor = UIColor.clearColor;
    textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    textField.returnKeyType = UIReturnKeySearch;
    textField.enablesReturnKeyAutomatically = NO;
    textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    textField.autocorrectionType = UITextAutocorrectionTypeDefault;
    textField.spellCheckingType = UITextSpellCheckingTypeDefault;
    textField.accessibilityLabel = placeholderText;
    textField.accessibilityHint  = NSLocalizedString(@"a11y_search_field_hint", @"Type to search for pets, services, or accessories");
    [textField addTarget:self
                  action:@selector(searchTextFieldEditingChanged:)
        forControlEvents:UIControlEventEditingChanged];

    UILabel *placeholderLabel = [UILabel new];
    placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    placeholderLabel.userInteractionEnabled = NO;
  // placeholderLabel.semanticContentAttribute = semanticAttribute;
    placeholderLabel.text = placeholderText;
    placeholderLabel.font = [GM MidFontWithSize:15.5] ?: [UIFont systemFontOfSize:15.5 weight:UIFontWeightMedium];
    placeholderLabel.textColor = [UIColor colorWithWhite:0.52 alpha:1.0];
    placeholderLabel.textAlignment = NSTextAlignmentNatural;

    [chromeView addSubview:accentView];
    [chromeView addSubview:iconView];
    [chromeView addSubview:textField];
    [chromeView addSubview:placeholderLabel];

    UIButton *cameraButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cameraButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *cameraCfg =
        [self pp_imageSearchCameraSymbolConfigurationWithPointSize:22.0
                                                            weight:UIImageSymbolWeightSemibold];
    [cameraButton setPreferredSymbolConfiguration:cameraCfg forImageInState:UIControlStateNormal];
    [cameraButton setImage:[self pp_imageSearchCameraSymbolWithConfiguration:cameraCfg]
                  forState:UIControlStateNormal];
    cameraButton.tintColor = AppPrimaryClr ?: [UIColor colorWithRed:0.72 green:0.22 blue:0.36 alpha:1.0];
    cameraButton.backgroundColor = UIColor.clearColor;
    cameraButton.layer.cornerRadius = 0.0;
    cameraButton.layer.masksToBounds = NO;
    cameraButton.layer.borderWidth = 0.0;
    [cameraButton pp_setBorderColor:UIColor.clearColor];
    [cameraButton pp_setShadowColor:UIColor.clearColor];
    cameraButton.layer.shadowOpacity = 0.0f;
    cameraButton.layer.shadowRadius = 0.0f;
    cameraButton.layer.shadowOffset = CGSizeZero;
    cameraButton.accessibilityLabel = kLang(@"ImageSearchButtonAccessibilityLabel");
    cameraButton.accessibilityHint = kLang(@"ImageSearchButtonAccessibilityHint");
    cameraButton.accessibilityTraits = UIAccessibilityTraitButton;
    [cameraButton addTarget:self action:@selector(didTapImageSearchButton) forControlEvents:UIControlEventTouchUpInside];
    [cameraButton addTarget:self action:@selector(pp_imageSearchButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [cameraButton addTarget:self action:@selector(pp_imageSearchButtonTouchUp:) forControlEvents:UIControlEventTouchUpOutside];
    [cameraButton addTarget:self action:@selector(pp_imageSearchButtonTouchUp:) forControlEvents:UIControlEventTouchCancel];
    [cameraButton addTarget:self action:@selector(pp_imageSearchButtonTouchUp:) forControlEvents:UIControlEventTouchDragExit];
    [chromeView addSubview:cameraButton];

    [container addSubview:chromeView];
    [self.view addSubview:container];

    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray arrayWithArray:@[
        [container.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [container.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [container.heightAnchor constraintEqualToConstant:64.0],

        [chromeView.leadingAnchor constraintEqualToAnchor:container.layoutMarginsGuide.leadingAnchor],
        [chromeView.trailingAnchor constraintEqualToAnchor:container.layoutMarginsGuide.trailingAnchor],
        [chromeView.bottomAnchor constraintEqualToAnchor:container.layoutMarginsGuide.bottomAnchor],
        [chromeView.heightAnchor constraintEqualToConstant:52.0],

        [accentView.leadingAnchor constraintEqualToAnchor:chromeView.leadingAnchor constant:12.0],
        [accentView.centerYAnchor constraintEqualToAnchor:chromeView.centerYAnchor],
        [accentView.widthAnchor constraintEqualToConstant:3.0],
        [accentView.heightAnchor constraintEqualToConstant:18.0],

        [iconView.leadingAnchor constraintEqualToAnchor:accentView.trailingAnchor constant:10.0],
        [iconView.centerYAnchor constraintEqualToAnchor:chromeView.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:18.0],
        [iconView.heightAnchor constraintEqualToConstant:18.0],

        [textField.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:10.0],
        [textField.trailingAnchor constraintEqualToAnchor:cameraButton.leadingAnchor constant:-8.0],
        [textField.topAnchor constraintEqualToAnchor:chromeView.topAnchor],
        [textField.bottomAnchor constraintEqualToAnchor:chromeView.bottomAnchor],

        [cameraButton.trailingAnchor constraintEqualToAnchor:chromeView.trailingAnchor constant:-10.0],
        [cameraButton.centerYAnchor constraintEqualToAnchor:chromeView.centerYAnchor],
        [cameraButton.widthAnchor constraintEqualToConstant:38.0],
        [cameraButton.heightAnchor constraintEqualToConstant:38.0],

        [placeholderLabel.leadingAnchor constraintEqualToAnchor:textField.leadingAnchor],
        [placeholderLabel.trailingAnchor constraintLessThanOrEqualToAnchor:textField.trailingAnchor],
        [placeholderLabel.centerYAnchor constraintEqualToAnchor:textField.centerYAnchor]
    ]];

    NSLayoutConstraint *bottomConstraint =
        [container.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:26.0];
    [constraints addObject:bottomConstraint];
    self.searchBarBottomConstraint = bottomConstraint;

    [NSLayoutConstraint activateConstraints:constraints];

    self.searchBarContainerView = container;
    self.searchFieldChromeView = chromeView;
    self.searchFieldIconView = iconView;
    self.searchTextField = textField;
    self.searchPlaceholderLabel = placeholderLabel;
    self.imageSearchButton = cameraButton;
    [self pp_applyImageSearchButtonSymbolEffectIfAvailable:cameraButton];
    [self pp_updateSearchPlaceholderVisibility];
}

- (UIColor *)pp_imageSearchSymbolColor
{
    return AppPrimaryClr ?: [UIColor colorWithRed:1.0 green:0.22 blue:0.42 alpha:1.0];
}

- (UIImageSymbolConfiguration *)pp_imageSearchCameraSymbolConfigurationWithPointSize:(CGFloat)pointSize
                                                                              weight:(UIImageSymbolWeight)weight
{
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:weight];
    UIColor *symbolColor = [self pp_imageSearchSymbolColor];

    if (@available(iOS 15.0, *)) {
        UIImageSymbolConfiguration *hierarchical =
            [UIImageSymbolConfiguration configurationWithHierarchicalColor:symbolColor];
        configuration = [configuration configurationByApplyingConfiguration:hierarchical];
    }

    if (@available(iOS 26.0, *)) {
        UIImageSymbolConfiguration *gradient =
            [UIImageSymbolConfiguration configurationWithColorRenderingMode:UIImageSymbolColorRenderingModeGradient];
        configuration = [configuration configurationByApplyingConfiguration:gradient];
    }

    return configuration;
}

- (UIImage *)pp_imageSearchCameraSymbolWithConfiguration:(UIImageSymbolConfiguration *)configuration
{
    UIImage *image = [UIImage systemImageNamed:@"camera.viewfinder" withConfiguration:configuration];
    return image ?: [UIImage systemImageNamed:@"camera.fill" withConfiguration:configuration];
}

- (void)pp_applyImageSearchButtonSymbolEffectIfAvailable:(UIButton *)button
{
    if (!button.imageView || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    if (@available(iOS 18.0, *)) {
        Class wiggleClass = NSClassFromString(@"NSSymbolWiggleEffect");
        if (![wiggleClass respondsToSelector:@selector(effect)]) {
            return;
        }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id effect = [wiggleClass performSelector:@selector(effect)];
#pragma clang diagnostic pop
        if (effect) {
            [button.imageView addSymbolEffect: [[NSSymbolWiggleEffect effect] effectWithByLayer] options: [NSSymbolEffectOptions optionsWithRepeatBehavior:[NSSymbolEffectOptionsRepeatBehavior behaviorPeriodicWithDelay:3.0]]];
        }
    }
}

- (BOOL)pp_heroUsesDarkSurface
{
    if (@available(iOS 13.0, *)) {
        return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

- (UIColor *)pp_heroPrimaryTextColor
{
    return [self pp_heroUsesDarkSurface]
    ? [UIColor colorWithWhite:0.96 alpha:1.0]
    : (AppPrimaryTextClr ?: UIColor.labelColor);
}

- (UIColor *)pp_heroSecondaryTextColor
{
    return [self pp_heroUsesDarkSurface]
    ? [UIColor colorWithWhite:0.78 alpha:1.0]
    : ([AppSecondaryTextClr colorWithAlphaComponent:0.78] ?: UIColor.secondaryLabelColor);
}

- (UIColor *)pp_heroPanelBackgroundColor
{
    return [self pp_heroUsesDarkSurface]
    ? [UIColor colorWithWhite:1.0 alpha:0.055]
    : [UIColor colorWithWhite:1.0 alpha:0.74];
}

- (UIColor *)pp_heroPanelBorderColor
{
    return [self pp_heroUsesDarkSurface]
    ? [UIColor colorWithWhite:1.0 alpha:0.09]
    : [UIColor colorWithWhite:0.0 alpha:0.055];
}

- (void)pp_applyPremiumHeroBackgroundStyle
{
    if (!self.heroCardView || !self.heroGradientLayer || !self.heroMeshLayer || !self.heroShineLayer) {
        return;
    }

    BOOL dark = [self pp_heroUsesDarkSurface];
    UIColor *accent = AppPrimaryClr ?: [UIColor colorWithRed:0.72 green:0.22 blue:0.36 alpha:1.0];
    UIColor *surfaceTop = dark
    ? [UIColor colorWithRed:0.085 green:0.088 blue:0.102 alpha:1.0]
    : [UIColor colorWithRed:0.992 green:0.990 blue:0.984 alpha:1.0];
    UIColor *surfaceMid = dark
    ? [UIColor colorWithRed:0.108 green:0.112 blue:0.128 alpha:1.0]
    : [UIColor colorWithRed:0.974 green:0.976 blue:0.972 alpha:1.0];
    UIColor *surfaceBottom = dark
    ? [UIColor colorWithRed:0.058 green:0.062 blue:0.074 alpha:1.0]
    : [UIColor colorWithRed:0.930 green:0.938 blue:0.940 alpha:1.0];
    UIColor *coolAccent = dark
    ? [UIColor colorWithRed:0.34 green:0.48 blue:0.56 alpha:1.0]
    : [UIColor colorWithRed:0.58 green:0.69 blue:0.72 alpha:1.0];

    self.heroCardView.backgroundColor = surfaceMid;
    [self.heroCardView pp_setBorderColor:[self pp_heroPanelBorderColor]];
    [self.heroCardShadowView pp_setShadowColor:dark ? UIColor.blackColor : [UIColor colorWithRed:0.22 green:0.19 blue:0.20 alpha:1.0]];
    self.heroCardShadowView.layer.shadowOpacity = dark ? 0.24f : 0.10f;
    self.heroCardShadowView.layer.shadowRadius = dark ? 30.0f : 22.0f;
    self.heroCardShadowView.layer.shadowOffset = CGSizeMake(0.0, dark ? 18.0 : 12.0);

    self.heroGradientLayer.colors = @[
        (id)surfaceTop.CGColor,
        (id)surfaceMid.CGColor,
        (id)surfaceBottom.CGColor
    ];
    self.heroMeshLayer.colors = @[
        (id)[accent colorWithAlphaComponent:(dark ? 0.26 : 0.13)].CGColor,
        (id)[coolAccent colorWithAlphaComponent:(dark ? 0.18 : 0.10)].CGColor,
        (id)[UIColor clearColor].CGColor,
        (id)[UIColor clearColor].CGColor
    ];
    self.heroShineLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:(dark ? 0.10 : 0.72)].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:(dark ? 0.04 : 0.18)].CGColor,
        (id)[UIColor clearColor].CGColor
    ];

    self.eyebrowLabel.textColor = accent;
    self.heroTitleLabel.textColor = [self pp_heroPrimaryTextColor];
    self.heroSubtitleLabel.textColor = [self pp_heroSecondaryTextColor];
    self.heroCollapseToggleButton.tintColor = [[self pp_heroSecondaryTextColor] colorWithAlphaComponent:0.56];
    self.segmentGlassView.backgroundColor = [self pp_heroPanelBackgroundColor];
    [self.segmentGlassView pp_setBorderColor:[self pp_heroPanelBorderColor]];
}

- (void)setupHeroHeader
{
   // UISemanticContentAttribute semanticAttribute = Language.semanticAttributeForCurrentLanguage;
    NSTextAlignment textAlignment = Language.alignmentForCurrentLanguage;

    UIView *heroShadowView = [UIView new];
    heroShadowView.translatesAutoresizingMaskIntoConstraints = NO;
    heroShadowView.backgroundColor = UIColor.clearColor;
  //  heroShadowView.semanticContentAttribute = semanticAttribute;
    heroShadowView.layer.cornerRadius = PPCornerHero;
    [heroShadowView pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    heroShadowView.layer.shadowOpacity = 0.10f;
    heroShadowView.layer.shadowRadius = 24.0f;
    heroShadowView.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    if (@available(iOS 13.0, *)) {
        heroShadowView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIView *heroCard = [UIView new];
    heroCard.translatesAutoresizingMaskIntoConstraints = NO;
//    heroCard.semanticContentAttribute = semanticAttribute;
    heroCard.layer.cornerRadius = PPCornerHero;
    heroCard.layer.masksToBounds = YES;
    heroCard.layer.borderWidth = 1.0;
    [heroCard pp_setBorderColor:[UIColor colorWithWhite:0.0 alpha:0.06]];
    if (@available(iOS 13.0, *)) {
        heroCard.layer.cornerCurve = kCACornerCurveContinuous;
    }

    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.locations = @[@0.0, @0.58, @1.0];
    gradient.startPoint = CGPointMake(0.08, 0.0);
    gradient.endPoint = CGPointMake(0.92, 1.0);
    [heroCard.layer insertSublayer:gradient atIndex:0];

    CAGradientLayer *mesh = [CAGradientLayer layer];
    mesh.locations = @[@0.0, @0.36, @0.70, @1.0];
    mesh.startPoint = CGPointMake(0.0, 0.0);
    mesh.endPoint = CGPointMake(1.0, 1.0);
    [heroCard.layer insertSublayer:mesh above:gradient];

    CAGradientLayer *shine = [CAGradientLayer layer];
    shine.locations = @[@0.0, @0.12, @0.34];
    shine.startPoint = CGPointMake(0.0, 0.0);
    shine.endPoint = CGPointMake(1.0, 0.62);
    [heroCard.layer insertSublayer:shine above:mesh];

    // Set initial gradient frames so they render on the first frame (before viewDidLayoutSubviews)
    CGFloat initialW = UIScreen.mainScreen.bounds.size.width - (PPScreenMargin * 2);
    CGRect initialGradientFrame = CGRectMake(0, 0, initialW, 300.0);
    gradient.frame = initialGradientFrame;
    mesh.frame = initialGradientFrame;
    shine.frame = initialGradientFrame;

    UILabel *eyebrow = [UILabel new];
    eyebrow.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrow.font = [GM boldFontWithSize:PPFontFootnote];
    eyebrow.textColor = AppPrimaryClr ?: [UIColor colorWithRed:0.72 green:0.22 blue:0.36 alpha:1.0];
    eyebrow.textAlignment = textAlignment;
    eyebrow.text = kLang(@"SearchHeroEyebrow");

    UILabel *statusPill = [self makeHeroPillLabel];

    UILabel *titleLabel = [UILabel new];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:31] ?: [UIFont systemFontOfSize:31.0 weight:UIFontWeightBold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.numberOfLines = 2;
    titleLabel.textAlignment = textAlignment;
    titleLabel.text = kLang(@"SearchHeroTitle");

    UILabel *subtitleLabel = [UILabel new];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [AppSecondaryTextClr colorWithAlphaComponent:0.78] ?: UIColor.secondaryLabelColor;
    subtitleLabel.numberOfLines = 3;
    subtitleLabel.textAlignment = textAlignment;

    UILabel *scopePill = [self makeHeroPillLabel];
    UILabel *countPill = [self makeHeroPillLabel];
    UILabel *queryPill = [self makeHeroPillLabel];

    UIView *segmentRowView = [UIView new];
    segmentRowView.translatesAutoresizingMaskIntoConstraints = NO;
   // segmentRowView.semanticContentAttribute = semanticAttribute;
    segmentRowView.backgroundColor = [self pp_heroPanelBackgroundColor];
    segmentRowView.layer.cornerRadius = 22.0;
    segmentRowView.layer.masksToBounds = NO;
    segmentRowView.clipsToBounds = NO;
    segmentRowView.layer.borderWidth = 1.0;
    [segmentRowView pp_setBorderColor:[self pp_heroPanelBorderColor]];
    if (@available(iOS 13.0, *)) {
        segmentRowView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIScrollView *segmentScrollView = [UIScrollView new];
    segmentScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    segmentScrollView.backgroundColor = UIColor.clearColor;
    segmentScrollView.showsHorizontalScrollIndicator = NO;
    segmentScrollView.alwaysBounceHorizontal = NO;
    segmentScrollView.delaysContentTouches = NO;
    segmentScrollView.userInteractionEnabled = YES;
  //  segmentScrollView.semanticContentAttribute = semanticAttribute;
    segmentScrollView.clipsToBounds = NO;
    if (@available(iOS 11.0, *)) {
        segmentScrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }

    UIStackView *segmentStackView = [[UIStackView alloc] init];
    segmentStackView.translatesAutoresizingMaskIntoConstraints = NO;
    segmentStackView.axis = UILayoutConstraintAxisHorizontal;
    segmentStackView.alignment = UIStackViewAlignmentFill;
    segmentStackView.distribution = UIStackViewDistributionFillEqually;
    segmentStackView.spacing = 8.0;
  //  segmentStackView.semanticContentAttribute = semanticAttribute;
    [segmentScrollView addSubview:segmentStackView];

    NSArray<NSDictionary<NSString *, id> *> *segmentDescriptors = [self pp_searchSegmentDescriptors];
    NSMutableArray<UIButton *> *segmentButtons = [NSMutableArray arrayWithCapacity:segmentDescriptors.count];
    __block UILabel *adsBadge = nil;
    __block UILabel *servicesBadge = nil;
    __block UILabel *accessoriesBadge = nil;
    [segmentDescriptors enumerateObjectsUsingBlock:^(NSDictionary<NSString *,id> * _Nonnull descriptor, __unused NSUInteger idx, __unused BOOL * _Nonnull stop) {
        PPSearchSegment segment = (PPSearchSegment)[descriptor[@"segment"] integerValue];
        UIButton *button = [self pp_makeSegmentBadgeButtonWithTitle:descriptor[@"title"]
                                                           iconName:descriptor[@"icon"]
                                                            segment:segment];
        UILabel *countLabel = [self pp_segmentCountLabelForButton:button];
        switch (segment) {
            case PPSearchSegmentAds:
                adsBadge = countLabel;
                break;
            case PPSearchSegmentServices:
                servicesBadge = countLabel;
                break;
            case PPSearchSegmentAccessories:
                accessoriesBadge = countLabel;
                break;
        }
        [segmentStackView addArrangedSubview:button];
        [segmentButtons addObject:button];
    }];

    UIStackView *metaStack = [[UIStackView alloc] initWithArrangedSubviews:@[scopePill, countPill, queryPill]];
    metaStack.translatesAutoresizingMaskIntoConstraints = NO;
    metaStack.axis = UILayoutConstraintAxisHorizontal;
    metaStack.spacing = PPSpaceSM;
    metaStack.alignment = UIStackViewAlignmentCenter;
    metaStack.distribution = UIStackViewDistributionFill;
 //   metaStack.semanticContentAttribute = semanticAttribute;

    [heroShadowView addSubview:heroCard];
    [heroCard addSubview:eyebrow];
    [heroCard addSubview:statusPill];
    [heroCard addSubview:titleLabel];
    [heroCard addSubview:subtitleLabel];
    [heroCard addSubview:segmentRowView];
    [segmentRowView addSubview:segmentScrollView];

    // Collapse/expand toggle
    UIButton *toggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    toggleButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *toggleCfg =
        [UIImageSymbolConfiguration configurationWithPointSize:10.0 weight:UIImageSymbolWeightBold];
    [toggleButton setImage:[UIImage systemImageNamed:@"chevron.up" withConfiguration:toggleCfg]
                  forState:UIControlStateNormal];
    toggleButton.tintColor = [[self pp_heroSecondaryTextColor] colorWithAlphaComponent:0.56];
    [toggleButton addTarget:self action:@selector(heroCollapseToggleTapped) forControlEvents:UIControlEventTouchUpInside];
    [heroCard addSubview:toggleButton];

    [self.view addSubview:heroShadowView];

    CGFloat cardPadding = PPSpaceXL;

    // Dual top constraints for collapse/expand animation
    NSLayoutConstraint *segTopExpanded =
        [segmentRowView.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:18.0];
    NSLayoutConstraint *segTopCollapsed =
        [segmentRowView.topAnchor constraintEqualToAnchor:heroCard.topAnchor constant:PPSpaceSM];
    segTopCollapsed.active = NO;
    // Bottom constraint anchored to toggle grip
    NSLayoutConstraint *heroBottom =
        [toggleButton.bottomAnchor constraintEqualToAnchor:heroCard.bottomAnchor constant:-PPSpaceXS];

    [NSLayoutConstraint activateConstraints:@[
        [heroShadowView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:PPSpaceSM],
        [heroShadowView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPScreenMargin],
        [heroShadowView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPScreenMargin],

        [heroCard.topAnchor constraintEqualToAnchor:heroShadowView.topAnchor],
        [heroCard.leadingAnchor constraintEqualToAnchor:heroShadowView.leadingAnchor],
        [heroCard.trailingAnchor constraintEqualToAnchor:heroShadowView.trailingAnchor],
        [heroCard.bottomAnchor constraintEqualToAnchor:heroShadowView.bottomAnchor],

        [eyebrow.topAnchor constraintEqualToAnchor:heroCard.topAnchor constant:cardPadding],
        [eyebrow.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:cardPadding],
        [eyebrow.trailingAnchor constraintLessThanOrEqualToAnchor:statusPill.leadingAnchor constant:-PPSpaceSM],

        [statusPill.centerYAnchor constraintEqualToAnchor:eyebrow.centerYAnchor],
        [statusPill.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-cardPadding],

        [titleLabel.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:12.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:cardPadding],
        [titleLabel.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-cardPadding],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:10.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

        segTopExpanded,
        [segmentRowView.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:PPSpaceMD],
        [segmentRowView.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-PPSpaceMD],
        [segmentRowView.heightAnchor constraintEqualToConstant:76.0],

        [toggleButton.topAnchor constraintEqualToAnchor:segmentRowView.bottomAnchor constant:2.0],
        [toggleButton.centerXAnchor constraintEqualToAnchor:heroCard.centerXAnchor],
        [toggleButton.widthAnchor constraintEqualToConstant:44.0],
        [toggleButton.heightAnchor constraintEqualToConstant:22.0],
        heroBottom,

        [segmentScrollView.topAnchor constraintEqualToAnchor:segmentRowView.topAnchor constant:4.0],
        [segmentScrollView.leadingAnchor constraintEqualToAnchor:segmentRowView.leadingAnchor constant:4.0],
        [segmentScrollView.trailingAnchor constraintEqualToAnchor:segmentRowView.trailingAnchor constant:-4.0],
        [segmentScrollView.bottomAnchor constraintEqualToAnchor:segmentRowView.bottomAnchor constant:-4.0],

        [segmentStackView.topAnchor constraintEqualToAnchor:segmentScrollView.contentLayoutGuide.topAnchor],
        [segmentStackView.bottomAnchor constraintEqualToAnchor:segmentScrollView.contentLayoutGuide.bottomAnchor],
        [segmentStackView.leadingAnchor constraintEqualToAnchor:segmentScrollView.contentLayoutGuide.leadingAnchor],
        [segmentStackView.trailingAnchor constraintEqualToAnchor:segmentScrollView.contentLayoutGuide.trailingAnchor],
        [segmentStackView.heightAnchor constraintEqualToAnchor:segmentScrollView.frameLayoutGuide.heightAnchor],
        [segmentStackView.widthAnchor constraintEqualToAnchor:segmentScrollView.frameLayoutGuide.widthAnchor]
    ]];

    self.segmentRowTopExpandedConstraint = segTopExpanded;
    self.segmentRowTopCollapsedConstraint = segTopCollapsed;
    self.heroBottomConstraint = heroBottom;
    self.heroCollapseToggleButton = toggleButton;
    self.heroCardShadowView = heroShadowView;
    self.heroCardView = heroCard;
    self.heroGradientLayer = gradient;
    self.heroMeshLayer = mesh;
    self.heroShineLayer = shine;
    self.eyebrowLabel = eyebrow;
    self.heroTitleLabel = titleLabel;
    self.heroSubtitleLabel = subtitleLabel;
    self.segmentGlassView = segmentRowView;
    self.segmentScrollView = segmentScrollView;
    self.segmentButtonsStackView = segmentStackView;
    self.segmentButtons = segmentButtons.copy;
    self.metaStackView = metaStack;
    self.statusPillLabel = statusPill;
    self.scopePillLabel = scopePill;
    self.countPillLabel = countPill;
    self.queryPillLabel = queryPill;
    self.adsBadge = adsBadge;
    self.servicesBadge = servicesBadge;
    self.accessoriesBadge = accessoriesBadge;
    // All hero content starts hidden — animateHeroIfNeeded reveals with staggered spring
    self.eyebrowLabel.alpha = 0.0;
    self.statusPillLabel.alpha = 0.0;
    self.heroTitleLabel.alpha = 0.0;
    self.heroSubtitleLabel.alpha = 0.0;
    self.segmentGlassView.alpha = 0.0;
    self.heroCollapseToggleButton.alpha = 0.0;
    [self pp_applyPremiumHeroBackgroundStyle];
}

- (void)setupCollectionView
{
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.minimumInteritemSpacing = kPPSearchInteritemSpacing;
    layout.minimumLineSpacing = kPPSearchLineSpacing;
    layout.sectionInset = UIEdgeInsetsMake(0.0,
                                           kPPSearchHorizontalInset,
                                           64.0,
                                           kPPSearchHorizontalInset);

    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero
                                                           collectionViewLayout:layout];
    collectionView.backgroundColor = UIColor.clearColor;
    collectionView.alwaysBounceVertical = YES;
    collectionView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    collectionView.delegate = self;
    collectionView.showsVerticalScrollIndicator = NO;
    collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    [collectionView registerClass:PPUniversalCell.class forCellWithReuseIdentifier:@"PPUniversalCell"];

    [self.view addSubview:collectionView];
    [self pp_sendBackdropGlowsToBack];
    [NSLayoutConstraint activateConstraints:@[
        [collectionView.topAnchor constraintEqualToAnchor:self.heroCardView.bottomAnchor constant:14.0],
        [collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-0.0]
    ]];

    self.collectionView = collectionView;
}

- (void)setupBottomSearchFade
{
    if (self.bottomSearchFadeView || !self.searchBarContainerView) {
        return;
    }

    UIView *fadeView = [UIView new];
    fadeView.translatesAutoresizingMaskIntoConstraints = NO;
    fadeView.userInteractionEnabled = NO;
    fadeView.backgroundColor = UIColor.clearColor;

    CAGradientLayer *fadeLayer = [CAGradientLayer layer];
    fadeLayer.startPoint = CGPointMake(0.5, 0.0);
    fadeLayer.endPoint = CGPointMake(0.5, 1.0);
    fadeLayer.locations = @[@0.0, @0.62, @1.0];
    [fadeView.layer addSublayer:fadeLayer];

    [self.view addSubview:fadeView];
    [NSLayoutConstraint activateConstraints:@[
        [fadeView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [fadeView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [fadeView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [fadeView.heightAnchor constraintEqualToConstant:98.0]
    ]];

    self.bottomSearchFadeView = fadeView;
    self.bottomSearchFadeLayer = fadeLayer;
    [self pp_updateBottomSearchFadeLayer];
}

- (void)pp_updateBottomSearchFadeLayer
{
    if (!self.bottomSearchFadeLayer || !self.bottomSearchFadeView) {
        return;
    }

    UIColor *backgroundColor = AppBageColor() ?: self.view.backgroundColor ?: UIColor.systemBackgroundColor;
    if (@available(iOS 13.0, *)) {
        backgroundColor = [backgroundColor resolvedColorWithTraitCollection:self.traitCollection];
    }

    self.bottomSearchFadeLayer.frame = self.bottomSearchFadeView.bounds;
    self.bottomSearchFadeLayer.colors = @[
        (id)[backgroundColor colorWithAlphaComponent:0.0].CGColor,
        (id)[backgroundColor colorWithAlphaComponent:0.76].CGColor,
        (id)[backgroundColor colorWithAlphaComponent:1.0].CGColor
    ];
}

- (void)pp_updateSearchLayering
{
    [self pp_sendBackdropGlowsToBack];
    UIView *topGlowView = self.secondaryGlowView.superview == self.view ? self.secondaryGlowView : self.primaryGlowView;
    if (self.collectionView.superview == self.view && topGlowView.superview == self.view) {
        [self.view insertSubview:self.collectionView aboveSubview:topGlowView];
    }
    if (self.bottomSearchFadeView.superview == self.view) {
        [self.view bringSubviewToFront:self.bottomSearchFadeView];
    }
    if (self.searchBarContainerView.superview == self.view) {
        [self.view bringSubviewToFront:self.searchBarContainerView];
    }
}

- (void)setupDataSource
{
    __weak typeof(self) weakSelf = self;
    self.dataSource = [[UICollectionViewDiffableDataSource alloc]
                       initWithCollectionView:self.collectionView
                       cellProvider:^UICollectionViewCell * _Nullable(UICollectionView *collectionView,
                                                                      NSIndexPath *indexPath,
                                                                      PPUniversalCellViewModel *viewModel) {
        PPUniversalCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"PPUniversalCell"
                                                                           forIndexPath:indexPath];
        viewModel.indexPath = indexPath;
        [cell applyViewModel:viewModel
                     context:viewModel.modelContext
                  layoutMode:PPCellLayoutModePinterest
                discountMode:PPDiscountStylePlain
                  imageLoader:^(UIImageView *iv,
                                NSString *url,
                                UIImage *placeholder,
                                UIView *card) {
            iv.image = placeholder ?: [UIImage imageNamed:@"placeholder"];
            [[PPImageLoaderManager shared]
             setImageOnImageView:iv
                             url:url
                      placeholder:placeholder
                 transitionStyle:PPImageTransitionStyleNone
                        complation:nil];
        }];
        cell.delegate = weakSelf;
        return cell;
    }];

    [self applyResultsAnimated:NO];
}

- (void)setupSearchSegment
{
    self.selectedSearchSegment = PPSearchSegmentAds;
    [self pp_hideAllBadges];
    [self pp_updateSegmentButtonsSelectionAnimated:NO];
}

- (void)setupEmptyState
{
    UIView *container = [UIView new];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.hidden = YES;
    container.alpha = 0.0;

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"sparkle.magnifyingglass"]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = [[UIColor colorWithRed:0.98 green:0.80 blue:0.54 alpha:1.0] colorWithAlphaComponent:0.92];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:30 weight:UIImageSymbolWeightSemibold];

    UILabel *titleLabel = [UILabel new];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [GM boldFontWithSize:22];
    titleLabel.textColor = AppSecondaryTextClr;
    titleLabel.numberOfLines = 2;

    UILabel *subtitleLabel = [UILabel new];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.font = [GM MidFontWithSize:14];
    subtitleLabel.textColor = [AppSecondaryTextClr colorWithAlphaComponent:0.70];
    subtitleLabel.numberOfLines = 3;

    [container addSubview:iconView];
    [container addSubview:titleLabel];
    [container addSubview:subtitleLabel];
    [self.view addSubview:container];

    [NSLayoutConstraint activateConstraints:@[
        [container.centerXAnchor constraintEqualToAnchor:self.collectionView.centerXAnchor],
        [container.centerYAnchor constraintEqualToAnchor:self.collectionView.centerYAnchor constant:-18.0],
        [container.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:36.0],
        [container.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-36.0],

        [iconView.topAnchor constraintEqualToAnchor:container.topAnchor],
        [iconView.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [iconView.widthAnchor constraintEqualToConstant:48.0],
        [iconView.heightAnchor constraintEqualToConstant:48.0],

        [titleLabel.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:18.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:10.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];

    self.emptyStateView = container;
    self.emptyStateIconView = iconView;
    self.emptyTitleLabel = titleLabel;
    self.emptySubtitleLabel = subtitleLabel;
}

- (void)setupImageSearchLoadingState
{
    UIView *hostView = [UIView new];
    hostView.translatesAutoresizingMaskIntoConstraints = NO;
    hostView.userInteractionEnabled = NO;
    hostView.hidden = YES;
    hostView.alpha = 0.0;

    UIView *cardView = [UIView new];
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    cardView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.96] ?: [[UIColor whiteColor] colorWithAlphaComponent:0.96];
    cardView.layer.cornerRadius = 24.0;
    cardView.layer.masksToBounds = NO;
    cardView.layer.borderWidth = 1.0;
    [cardView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.28]];
    [cardView pp_setShadowColor:[UIColor colorWithWhite:0.05 alpha:1.0]];
    cardView.layer.shadowOpacity = 0.16f;
    cardView.layer.shadowRadius = 28.0f;
    cardView.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    if (@available(iOS 13.0, *)) {
        cardView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIView *orbView = [UIView new];
    orbView.translatesAutoresizingMaskIntoConstraints = NO;
    orbView.clipsToBounds = YES;

    CAGradientLayer *orbGradient = [CAGradientLayer layer];
    orbGradient.colors = @[
        (id)[(AppPrimaryClr ?: [UIColor colorWithRed:0.72 green:0.22 blue:0.36 alpha:1.0]) colorWithAlphaComponent:0.98].CGColor,
        (id)[[UIColor colorWithRed:0.98 green:0.78 blue:0.46 alpha:1.0] colorWithAlphaComponent:0.92].CGColor,
        (id)[[UIColor colorWithRed:0.31 green:0.54 blue:0.64 alpha:1.0] colorWithAlphaComponent:0.92].CGColor
    ];
    orbGradient.startPoint = CGPointMake(0.0, 0.0);
    orbGradient.endPoint = CGPointMake(1.0, 1.0);
    [orbView.layer insertSublayer:orbGradient atIndex:0];

    UIView *orbInnerGlow = [UIView new];
    orbInnerGlow.translatesAutoresizingMaskIntoConstraints = NO;
    orbInnerGlow.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.18];
    orbInnerGlow.layer.cornerRadius = 18.0;
    orbInnerGlow.layer.masksToBounds = YES;

    UIImageSymbolConfiguration *iconConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:28.0 weight:UIImageSymbolWeightSemibold];
    UIImage *iconImage = [UIImage systemImageNamed:@"camera.viewfinder" withConfiguration:iconConfig];
    if (!iconImage) {
        iconImage = [UIImage systemImageNamed:@"camera.fill" withConfiguration:iconConfig];
    }
    UIImageView *iconView = [[UIImageView alloc] initWithImage:iconImage];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = UIColor.whiteColor;
    iconView.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *titleLabel = [UILabel new];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:17.0] ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightBold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.numberOfLines = 1;
    titleLabel.text = kLang(@"ImageSearchLoadingTitle");

    UILabel *subtitleLabel = [UILabel new];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [AppSecondaryTextClr colorWithAlphaComponent:0.78] ?: [UIColor.secondaryLabelColor colorWithAlphaComponent:0.78];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.numberOfLines = 2;
    subtitleLabel.text = kLang(@"ImageSearchLoadingSubtitle");

    [orbView addSubview:orbInnerGlow];
    [orbView addSubview:iconView];
    [cardView addSubview:orbView];
    [cardView addSubview:titleLabel];
    [cardView addSubview:subtitleLabel];
    [hostView addSubview:cardView];
    [self.view addSubview:hostView];

    [NSLayoutConstraint activateConstraints:@[
        [hostView.topAnchor constraintEqualToAnchor:self.collectionView.topAnchor],
        [hostView.leadingAnchor constraintEqualToAnchor:self.collectionView.leadingAnchor],
        [hostView.trailingAnchor constraintEqualToAnchor:self.collectionView.trailingAnchor],
        [hostView.bottomAnchor constraintEqualToAnchor:self.collectionView.bottomAnchor],

        [cardView.centerXAnchor constraintEqualToAnchor:hostView.centerXAnchor],
        [cardView.centerYAnchor constraintEqualToAnchor:hostView.centerYAnchor constant:-18.0],
        [cardView.leadingAnchor constraintGreaterThanOrEqualToAnchor:hostView.leadingAnchor constant:34.0],
        [cardView.trailingAnchor constraintLessThanOrEqualToAnchor:hostView.trailingAnchor constant:-34.0],
        [cardView.widthAnchor constraintGreaterThanOrEqualToConstant:248.0],
        [cardView.widthAnchor constraintLessThanOrEqualToConstant:314.0],

        [orbView.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:24.0],
        [orbView.centerXAnchor constraintEqualToAnchor:cardView.centerXAnchor],
        [orbView.widthAnchor constraintEqualToConstant:76.0],
        [orbView.heightAnchor constraintEqualToConstant:76.0],

        [orbInnerGlow.centerXAnchor constraintEqualToAnchor:orbView.centerXAnchor constant:-10.0],
        [orbInnerGlow.centerYAnchor constraintEqualToAnchor:orbView.centerYAnchor constant:-10.0],
        [orbInnerGlow.widthAnchor constraintEqualToConstant:36.0],
        [orbInnerGlow.heightAnchor constraintEqualToConstant:36.0],

        [iconView.centerXAnchor constraintEqualToAnchor:orbView.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:orbView.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:34.0],
        [iconView.heightAnchor constraintEqualToConstant:34.0],

        [titleLabel.topAnchor constraintEqualToAnchor:orbView.bottomAnchor constant:18.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:22.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-22.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-24.0],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-24.0]
    ]];

    self.imageSearchLoadingView = hostView;
    self.imageSearchLoadingCardView = cardView;
    self.imageSearchLoadingOrbView = orbView;
    self.imageSearchLoadingIconView = iconView;
    self.imageSearchLoadingTitleLabel = titleLabel;
    self.imageSearchLoadingSubtitleLabel = subtitleLabel;
    self.imageSearchLoadingOrbGradientLayer = orbGradient;
}

#pragma mark - UITextFieldDelegate

- (void)searchTextFieldEditingChanged:(UITextField *)textField
{
    [self pp_updateSearchPlaceholderVisibility];
    [self handleSearchQueryUpdateWithRawText:textField.text];
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    (void)textField;
    [self resetSearchState];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self pp_updateSearchPlaceholderVisibility];
        [self pp_updateSegmentButtonsSelectionAnimated:YES];
    });
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    (void)textField;
    [self setHeroCollapsed:YES animated:YES];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    (void)textField;
    if (self.lastQuery.length < kPPSearchMinimumQueryLength) {
        [self setHeroCollapsed:NO animated:YES];
    }
}

#pragma mark - Search Flow

- (void)warmUpSearchCacheIfNeeded
{
    __weak typeof(self) weakSelf = self;
    [[SearchCacheManager shared] warmUpCacheIfNeeded:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        NSString *query = [strongSelf normalizedQueryFromRawString:strongSelf.searchTextField.text];
        if (query.length >= kPPSearchMinimumQueryLength &&
            ![query isEqualToString:strongSelf.lastQuery]) {
            strongSelf.lastQuery = query;
            [strongSelf updateHeaderStateAnimated:NO];
            [strongSelf executeSearchForQuery:query];
        }
    }];
}

- (void)performSearchDebounced:(NSString *)query
{
    if (self.pendingDebounceBlock) {
        dispatch_block_cancel(self.pendingDebounceBlock);
        self.pendingDebounceBlock = nil;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_block_t block = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf executeSearchForQuery:query];
    });

    self.pendingDebounceBlock = block;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kPPSearchDebounceDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   block);
}

- (void)handleSearchQueryUpdateWithRawText:(nullable NSString *)rawText
{
    NSString *query = [self normalizedQueryFromRawString:rawText];

    if (query.length < kPPSearchMinimumQueryLength) {
        [self resetSearchState];
        return;
    }

    if ([self pp_isImageSearchMode]) {
        self.imageSearchRequestGeneration += 1;
        [self pp_clearImageSearchState];
        [self pp_hideAllBadges];
    }

    if ([query isEqualToString:self.lastQuery]) {
        return;
    }

    self.lastQuery = query;
    [self updateHeaderStateAnimated:YES];
    [self performSearchDebounced:query];
}

- (void)executeSearchForQuery:(NSString *)query
{
    if (query.length < kPPSearchMinimumQueryLength) {
        [self resetSearchState];
        return;
    }

    [self pp_showSkeletonIfNeeded];

    NSInteger requestID = self.currentSearchRequestID + 1;
    self.currentSearchRequestID = requestID;
    NSString *searchToken = [query copy];

    __weak typeof(self) weakSelf = self;
    dispatch_async(self.searchQueue, ^{
        NSArray *items = [[SearchCacheManager shared] searchWithQuery:searchToken];
        NSArray *rankedItems = [self rankedResultsFromItems:items query:searchToken];

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }

            BOOL isStaleRequest = (requestID != strongSelf.currentSearchRequestID);
            BOOL isDifferentQuery = ![strongSelf.lastQuery isEqualToString:searchToken];
            if (isStaleRequest || isDifferentQuery) {
                return;
            }

            strongSelf.allSearchResults = rankedItems ?: @[];
            [strongSelf updateSegmentBadgesWithItems:strongSelf.allSearchResults];
            [strongSelf applySegmentFilter];
            [strongSelf pp_hideSkeleton];
        });
    });
}

- (NSArray<id> *)rankedResultsFromItems:(NSArray<id> *)items query:(NSString *)query
{
    if (items.count == 0) {
        return items ?: @[];
    }

    NSString *normalizedQuery = [PPSearchHelper pp_normalizedSearchString:query];
    if (normalizedQuery.length == 0) {
        return @[];
    }

    NSMutableArray<PPSearchRankedResult *> *scoredItems =
        [NSMutableArray arrayWithCapacity:items.count];
    for (id obj in items) {
        NSString *searchableText = [self searchableTextForObject:obj];
        PPSearchScore score = [PPSearchHelper pp_scoreForText:searchableText
                                              normalizedQuery:normalizedQuery];
        if (!score.matched) {
            continue;
        }

        PPSearchRankedResult *rankedResult = [PPSearchRankedResult new];
        rankedResult.object = obj;
        rankedResult.searchScore = score;
        rankedResult.displayTitle = [self displayTitleForObject:obj];
        rankedResult.stableIdentifier = [self stableIdentifierForObject:obj];
        [scoredItems addObject:rankedResult];
    }

    if (scoredItems.count <= 1) {
        NSMutableArray<id> *singleResult = [NSMutableArray arrayWithCapacity:scoredItems.count];
        for (PPSearchRankedResult *rankedResult in scoredItems) {
            if (rankedResult.object) {
                [singleResult addObject:rankedResult.object];
            }
        }
        return singleResult.copy;
    }

    [scoredItems sortUsingComparator:^NSComparisonResult(PPSearchRankedResult *result1,
                                                         PPSearchRankedResult *result2) {
        PPSearchScore score1 = result1.searchScore;
        PPSearchScore score2 = result2.searchScore;

        if (score1.rank < score2.rank) return NSOrderedAscending;
        if (score1.rank > score2.rank) return NSOrderedDescending;

        if (score1.sortScore < score2.sortScore) return NSOrderedAscending;
        if (score1.sortScore > score2.sortScore) return NSOrderedDescending;

        NSString *title1 = result1.displayTitle ?: @"";
        NSString *title2 = result2.displayTitle ?: @"";
        NSComparisonResult titleCompare = [title1 localizedCaseInsensitiveCompare:title2];
        if (titleCompare != NSOrderedSame) {
            return titleCompare;
        }

        NSString *identifier1 = result1.stableIdentifier ?: @"";
        NSString *identifier2 = result2.stableIdentifier ?: @"";
        return [identifier1 compare:identifier2];
    }];

    NSMutableArray<id> *sortedObjects = [NSMutableArray arrayWithCapacity:scoredItems.count];
    for (PPSearchRankedResult *rankedResult in scoredItems) {
        if (rankedResult.object) {
            [sortedObjects addObject:rankedResult.object];
        }
    }

    return sortedObjects.copy;
}

- (NSString *)normalizedQueryFromRawString:(nullable NSString *)rawText
{
    if (![rawText isKindOfClass:NSString.class]) {
        return @"";
    }

    NSString *trimmed = [rawText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmed ?: @"";
}

- (void)resetSearchState
{
    if (self.pendingDebounceBlock) {
        dispatch_block_cancel(self.pendingDebounceBlock);
        self.pendingDebounceBlock = nil;
    }

    self.currentSearchRequestID += 1;
    self.imageSearchRequestGeneration += 1;
    self.lastQuery = nil;
    [self pp_clearImageSearchState];
    self.allSearchResults = @[];
    self.results = @[];
    [self pp_hideSkeleton];
    [self pp_hideAllBadges];
    [self applyResultsAnimated:NO];
    [self updateEmptyState];
    [self updateHeaderStateAnimated:YES];

    if (!self.searchTextField.isFirstResponder) {
        [self setHeroCollapsed:NO animated:YES];
    }
}

#pragma mark - Hero Collapse

- (void)setHeroCollapsed:(BOOL)collapsed animated:(BOOL)animated
{
    if (self.isHeroCollapsed == collapsed) return;
    self.isHeroCollapsed = collapsed;

    // Deactivate both first to avoid momentary constraint conflicts
    self.segmentRowTopExpandedConstraint.active = NO;
    self.segmentRowTopCollapsedConstraint.active = NO;

    if (collapsed) {
        self.segmentRowTopCollapsedConstraint.active = YES;
    } else {
        self.segmentRowTopExpandedConstraint.active = YES;
    }

    // Flip toggle direction
    UIImageSymbolConfiguration *toggleCfg =
        [UIImageSymbolConfiguration configurationWithPointSize:10.0 weight:UIImageSymbolWeightBold];
    NSString *chevronName = collapsed ? @"chevron.down" : @"chevron.up";
    [self.heroCollapseToggleButton setImage:[UIImage systemImageNamed:chevronName withConfiguration:toggleCfg]
                                  forState:UIControlStateNormal];

    void (^updates)(void) = ^{
        CGFloat contentAlpha = collapsed ? 0.0 : 1.0;
        self.eyebrowLabel.alpha = contentAlpha;
        self.statusPillLabel.alpha = contentAlpha;
        self.heroTitleLabel.alpha = contentAlpha;
        self.heroSubtitleLabel.alpha = contentAlpha;
        [self.view layoutIfNeeded];
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        updates();
        return;
    }

    [UIView animateWithDuration:0.38
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.6
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
                     animations:updates
                     completion:nil];
}

- (void)heroCollapseToggleTapped
{
    [self setHeroCollapsed:!self.isHeroCollapsed animated:YES];
    [PPFunc triggerLightHaptic];
}

#pragma mark - Segment Filtering

- (void)segmentBadgeTapped:(UIButton *)sender
{
    PPSearchSegment segment = (PPSearchSegment)sender.tag;
    if (segment < PPSearchSegmentAds || segment > PPSearchSegmentAccessories) {
        segment = PPSearchSegmentAds;
    }

    if (self.selectedSearchSegment != segment) {
        self.selectedSearchSegment = segment;
        [self pp_updateSegmentButtonsSelectionAnimated:YES];
        [self applySegmentFilter];
    } else {
        [self pp_scrollSegmentButtonIntoView:sender animated:YES];
    }

    [PPFunc triggerLightHaptic];
}

- (void)applySegmentFilter
{
    if ([self pp_isImageSearchMode]) {
        [self pp_applyImageSearchSegmentFilterAnimated:YES];
        return;
    }

    NSInteger selectedIndex = self.selectedSearchSegment;
    if (selectedIndex < PPSearchSegmentAds || selectedIndex > PPSearchSegmentAccessories) {
        selectedIndex = PPSearchSegmentAds;
    }

    NSMutableArray<id> *filteredItems = [NSMutableArray array];
    for (id obj in self.allSearchResults) {
        if ([self object:obj belongsToSegment:selectedIndex]) {
            [filteredItems addObject:obj];
        }
    }

    [self buildViewModelsFromResults:filteredItems];
}

- (BOOL)object:(id)obj belongsToSegment:(PPSearchSegment)segment
{
    switch (segment) {
        case PPSearchSegmentAds:
            return [obj isKindOfClass:PetAd.class];
        case PPSearchSegmentServices:
            return [obj isKindOfClass:ServiceModel.class];
        case PPSearchSegmentAccessories:
            return [obj isKindOfClass:PetAccessory.class];
    }
    return NO;
}

- (void)updateSegmentBadgesWithItems:(NSArray<id> *)items
{
    NSInteger adsCount = 0;
    NSInteger servicesCount = 0;
    NSInteger accessoriesCount = 0;

    for (id obj in items) {
        if ([obj isKindOfClass:PetAd.class]) {
            adsCount += 1;
        } else if ([obj isKindOfClass:ServiceModel.class]) {
            servicesCount += 1;
        } else if ([obj isKindOfClass:PetAccessory.class]) {
            accessoriesCount += 1;
        }
    }

    [self pp_updateBadge:self.adsBadge count:adsCount];
    [self pp_updateBadge:self.servicesBadge count:servicesCount];
    [self pp_updateBadge:self.accessoriesBadge count:accessoriesCount];
}

#pragma mark - View Models

- (void)buildViewModelsFromResults:(NSArray<id> *)results
{
    NSMutableArray<PPUniversalCellViewModel *> *viewModels = [NSMutableArray arrayWithCapacity:results.count];
    NSMutableSet<NSString *> *seenIdentifiers = [NSMutableSet setWithCapacity:results.count];

    for (id obj in results) {
        NSString *identifier = [self stableIdentifierForObject:obj];
        if (identifier.length > 0) {
            if ([seenIdentifiers containsObject:identifier]) {
                continue;
            }
            [seenIdentifiers addObject:identifier];
        }

        PPUniversalCellViewModel *viewModel = [self viewModelForObject:obj];
        if (viewModel) {
            [viewModels addObject:viewModel];
        }
    }

    self.results = viewModels.copy;
    [self applyResultsAnimated:YES];
    [self updateEmptyState];
    [self updateHeaderStateAnimated:YES];
}

- (nullable PPUniversalCellViewModel *)viewModelForObject:(id)obj
{
    if ([obj isKindOfClass:PetAd.class]) {
        return [[PPUniversalCellViewModel alloc] initWithModel:obj context:PPCellForAds];
    }

    if ([obj isKindOfClass:ServiceModel.class]) {
        return [[PPUniversalCellViewModel alloc] initWithModel:obj context:PPCellForServices];
    }

    if ([obj isKindOfClass:PetAccessory.class]) {
        return [[PPUniversalCellViewModel alloc] initWithModel:obj context:PPCellForMarket];
    }

    return nil;
}

- (void)applyResultsAnimated:(BOOL)animated
{
    NSDiffableDataSourceSnapshot<NSNumber *, PPUniversalCellViewModel *> *snapshot = [NSDiffableDataSourceSnapshot new];
    [snapshot appendSectionsWithIdentifiers:@[@(PPSearchSectionResults)]];
    if (self.results.count > 0) {
        [snapshot appendItemsWithIdentifiers:self.results];
    }
    [self.dataSource applySnapshot:snapshot animatingDifferences:animated];
}

#pragma mark - Helpers

- (void)updateHeaderStateAnimated:(BOOL)animated
{
    BOOL hasValidQuery = self.lastQuery.length >= kPPSearchMinimumQueryLength;
    BOOL hasImageSearchMode = [self pp_isImageSearchMode];
    NSString *segmentTitle = [self selectedSegmentTitle];
    NSString *statusText = nil;
    NSString *subtitleText = nil;
    NSString *countText = nil;
    BOOL showQueryPill = hasValidQuery && !hasImageSearchMode;
    BOOL showCountPill = YES;

    self.eyebrowLabel.text = kLang(@"SearchHeroEyebrow");
    self.heroTitleLabel.text = kLang(@"SearchHeroTitle");

    if (hasImageSearchMode) {
        if (self.isSearching) {
            statusText = kLang(@"SearchHeroSearchingBadge");
            subtitleText = kLang(@"ImageSearchPreparing");
            countText = kLang(@"ImageSearchHeroBadge");
        } else if (self.results.count > 0) {
            statusText = kLang(@"ImageSearchHeroBadge");
            subtitleText = [NSString stringWithFormat:kLang(@"ImageSearchHeroResultsSubtitleFormat"),
                            (long)self.results.count];
            countText = [NSString stringWithFormat:kLang(@"SearchHeroResultsCountFormat"), (long)self.results.count];
        } else {
            statusText = kLang(@"SearchHeroReady");
            subtitleText = kLang(@"ImageSearchNoResultsSubtitle");
            countText = [NSString stringWithFormat:kLang(@"SearchHeroResultsCountFormat"), (long)0];
        }
    } else if (!hasValidQuery) {
        statusText = kLang(@"Hero_TrendingNow") ?: kLang(@"SearchHeroReady");
        subtitleText = kLang(@"SearchHeroIdleSubtitle");
        countText = kLang(@"SearchHeroTypingHint");
    } else if (self.isSearching) {
        statusText = kLang(@"SearchHeroSearchingBadge");
        subtitleText = kLang(@"SearchHeroSearching");
        countText = [NSString stringWithFormat:kLang(@"SearchHeroResultsCountFormat"), (long)self.results.count];
    } else if (self.results.count > 0) {
        statusText = kLang(@"SearchHeroLive");
        subtitleText = [NSString stringWithFormat:kLang(@"SearchHeroResultsSubtitleFormat"),
                        (long)self.results.count,
                        self.lastQuery ?: @""];
        countText = [NSString stringWithFormat:kLang(@"SearchHeroResultsCountFormat"), (long)self.results.count];
    } else {
        statusText = kLang(@"SearchHeroReady");
        subtitleText = [NSString stringWithFormat:kLang(@"SearchNoResultsMessage_fmt"), self.lastQuery ?: @""];
        countText = [NSString stringWithFormat:kLang(@"SearchHeroResultsCountFormat"), (long)0];
    }

    [self setLabel:self.heroSubtitleLabel text:subtitleText animated:animated];
    [self setLabel:self.statusPillLabel text:statusText animated:animated];
    [self setLabel:self.scopePillLabel text:segmentTitle animated:animated];
    [self setLabel:self.countPillLabel text:countText animated:animated];
    [self setLabel:self.queryPillLabel text:(hasValidQuery ? self.lastQuery : @"") animated:animated];
    [self setPill:self.queryPillLabel hidden:!showQueryPill animated:animated];
    [self setPill:self.countPillLabel hidden:!showCountPill animated:animated];

    UIColor *scopeTint = [self pp_scopeTintColorForSelectedSegment];
    UIColor *primaryText = [self pp_heroPrimaryTextColor];
    UIColor *secondaryText = [self pp_heroSecondaryTextColor];
    UIColor *neutralPillBackground = [self pp_heroPanelBackgroundColor];
    UIColor *neutralPillBorder = [self pp_heroPanelBorderColor];
    BOOL darkHero = [self pp_heroUsesDarkSurface];
    UIColor *statusBackground = nil;
    UIColor *statusForeground = nil;

    if (hasImageSearchMode && self.isSearching) {
        statusBackground = [[UIColor colorWithRed:0.95 green:0.67 blue:0.22 alpha:1.0] colorWithAlphaComponent:(darkHero ? 0.22 : 0.13)];
        statusForeground = darkHero ? [UIColor colorWithRed:1.0 green:0.88 blue:0.58 alpha:1.0] : [UIColor colorWithRed:0.55 green:0.34 blue:0.06 alpha:1.0];
    } else if (hasImageSearchMode && self.results.count > 0) {
        statusBackground = [scopeTint colorWithAlphaComponent:(darkHero ? 0.22 : 0.12)];
        statusForeground = darkHero ? [UIColor colorWithWhite:0.98 alpha:1.0] : scopeTint;
    } else if (hasImageSearchMode) {
        statusBackground = neutralPillBackground;
        statusForeground = secondaryText;
    } else if (!hasValidQuery) {
        statusBackground = [scopeTint colorWithAlphaComponent:(darkHero ? 0.18 : 0.10)];
        statusForeground = darkHero ? [UIColor colorWithWhite:0.96 alpha:1.0] : scopeTint;
    } else if (self.isSearching) {
        statusBackground = [[UIColor colorWithRed:0.95 green:0.67 blue:0.22 alpha:1.0] colorWithAlphaComponent:(darkHero ? 0.22 : 0.13)];
        statusForeground = darkHero ? [UIColor colorWithRed:1.0 green:0.88 blue:0.58 alpha:1.0] : [UIColor colorWithRed:0.55 green:0.34 blue:0.06 alpha:1.0];
    } else if (self.results.count > 0) {
        statusBackground = [scopeTint colorWithAlphaComponent:(darkHero ? 0.22 : 0.12)];
        statusForeground = darkHero ? [UIColor colorWithWhite:0.98 alpha:1.0] : scopeTint;
    } else {
        statusBackground = neutralPillBackground;
        statusForeground = secondaryText;
    }

    self.statusPillLabel.backgroundColor = statusBackground;
    self.statusPillLabel.textColor = statusForeground;
    [self.statusPillLabel pp_setBorderColor:[statusForeground colorWithAlphaComponent:(darkHero ? 0.16 : 0.10)]];

    self.scopePillLabel.backgroundColor = [scopeTint colorWithAlphaComponent:(darkHero ? 0.20 : 0.11)];
    self.scopePillLabel.textColor = darkHero ? [UIColor colorWithWhite:0.98 alpha:1.0] : scopeTint;
    [self.scopePillLabel pp_setBorderColor:[scopeTint colorWithAlphaComponent:(darkHero ? 0.24 : 0.15)]];

    self.countPillLabel.backgroundColor = neutralPillBackground;
    self.countPillLabel.textColor = secondaryText;
    [self.countPillLabel pp_setBorderColor:neutralPillBorder];

    self.queryPillLabel.backgroundColor = [scopeTint colorWithAlphaComponent:(darkHero ? 0.18 : 0.10)];
    self.queryPillLabel.textColor = primaryText;
    [self.queryPillLabel pp_setBorderColor:[scopeTint colorWithAlphaComponent:(darkHero ? 0.24 : 0.14)]];

    [self pp_updateSegmentButtonsSelectionAnimated:animated];
}

- (void)updateEmptyState
{
    BOOL hasValidQuery = self.lastQuery.length >= kPPSearchMinimumQueryLength;
    BOOL hasImageSearchMode = [self pp_isImageSearchMode];
    BOOL noImageResults = hasImageSearchMode && !self.isSearching && self.results.count == 0;
    BOOL noResults = !hasImageSearchMode && hasValidQuery && !self.isSearching && self.results.count == 0;
    BOOL idleState = !hasImageSearchMode && !hasValidQuery && !self.isSearching;

    BOOL shouldShow = noImageResults || noResults || idleState;

    if (noImageResults) {
        self.emptyStateIconView.image = [UIImage systemImageNamed:@"camera.metering.none"];
        self.emptyStateIconView.tintColor = [[UIColor colorWithRed:0.98 green:0.80 blue:0.54 alpha:1.0] colorWithAlphaComponent:0.92];
        self.emptyTitleLabel.text = kLang(@"ImageSearchNoResultsTitle");
        self.emptySubtitleLabel.text = kLang(@"ImageSearchNoResultsSubtitle");
        [self pp_animateImageSearchEmptyStateIfNeeded];
    } else if (noResults) {
        // No results found
        self.emptyStateIconView.image = [UIImage systemImageNamed:@"sparkle.magnifyingglass"];
        self.emptyStateIconView.tintColor = [[UIColor colorWithRed:0.98 green:0.80 blue:0.54 alpha:1.0] colorWithAlphaComponent:0.92];
        self.emptyTitleLabel.text = kLang(@"SearchNoResultsTitle");
        self.emptySubtitleLabel.text = [NSString stringWithFormat:kLang(@"SearchNoResultsMessage_fmt"), self.lastQuery ?: @""];
    } else if (idleState) {
        // Start searching prompt
        self.emptyStateIconView.image = [UIImage systemImageNamed:@"text.magnifyingglass"];
        self.emptyStateIconView.tintColor = [[UIColor colorWithRed:0.72 green:0.76 blue:0.82 alpha:1.0] colorWithAlphaComponent:0.68];
        self.emptyTitleLabel.text = kLang(@"SearchStartTitle");
        self.emptySubtitleLabel.text = kLang(@"SearchStartSubtitle");
    }

    // Hide collection view when showing empty/idle, show when we have results
    self.collectionView.hidden = shouldShow;

    [self setEmptyStateVisible:shouldShow animated:YES];
}

- (NSString *)searchableTextForObject:(id)obj
{
    if ([obj isKindOfClass:PetAd.class]) {
        PetAd *ad = (PetAd *)obj;
        return ad.searchTitle ?: ad.adTitle ?: @"";
    }

    if ([obj isKindOfClass:PetAccessory.class]) {
        PetAccessory *accessory = (PetAccessory *)obj;
        return accessory.searchTitle ?: accessory.name ?: @"";
    }

    if ([obj isKindOfClass:ServiceModel.class]) {
        ServiceModel *service = (ServiceModel *)obj;
        return service.searchTitle ?: service.title ?: @"";
    }

    return @"";
}

- (NSString *)displayTitleForObject:(id)obj
{
    if ([obj isKindOfClass:PetAd.class]) {
        return ((PetAd *)obj).adTitle ?: @"";
    }

    if ([obj isKindOfClass:PetAccessory.class]) {
        return ((PetAccessory *)obj).name ?: @"";
    }

    if ([obj isKindOfClass:ServiceModel.class]) {
        return ((ServiceModel *)obj).title ?: @"";
    }

    return @"";
}

- (NSString *)stableIdentifierForObject:(id)obj
{
    if ([obj isKindOfClass:PetAd.class]) {
        return ((PetAd *)obj).adID ?: [NSString stringWithFormat:@"%p", obj];
    }

    if ([obj isKindOfClass:PetAccessory.class]) {
        return ((PetAccessory *)obj).accessoryID ?: [NSString stringWithFormat:@"%p", obj];
    }

    if ([obj isKindOfClass:ServiceModel.class]) {
        return ((ServiceModel *)obj).serviceID ?: [NSString stringWithFormat:@"%p", obj];
    }

    return [NSString stringWithFormat:@"%p", obj];
}

- (UILabel *)makeHeroPillLabel
{
    PPInsetLabel *label = [PPInsetLabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.textInsets = UIEdgeInsetsMake(PPSpaceXS + 2.0, PPSpaceMD, PPSpaceXS + 2.0, PPSpaceMD);
    label.font = [GM MidFontWithSize:PPFontCaption1];
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [self pp_heroSecondaryTextColor];
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    [label setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [label setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    label.backgroundColor = [self pp_heroPanelBackgroundColor];
    label.layer.cornerRadius = 14.0;
    label.layer.masksToBounds = YES;
    label.layer.borderWidth = 0.5;
    [label pp_setBorderColor:[self pp_heroPanelBorderColor]];
    [NSLayoutConstraint activateConstraints:@[
        [label.heightAnchor constraintEqualToConstant:28.0]
    ]];
    return label;
}

- (UILabel *)makeBadgeLabel
{
    PPInsetLabel *label = [PPInsetLabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.textInsets = UIEdgeInsetsMake(3.0, 7.0, 3.0, 7.0);
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [GM boldFontWithSize:10.0] ?: [UIFont systemFontOfSize:10.0 weight:UIFontWeightBold];
    label.textColor = [self pp_heroSecondaryTextColor];
    label.backgroundColor = [self pp_heroPanelBackgroundColor];
    label.layer.cornerRadius = 10.0;
    label.layer.masksToBounds = YES;
    label.alpha = 0.0;
    [NSLayoutConstraint activateConstraints:@[
        [label.heightAnchor constraintEqualToConstant:20.0]
    ]];
    return label;
}

- (void)pp_hideAllBadges
{
    [self pp_updateBadge:self.adsBadge count:0];
    [self pp_updateBadge:self.servicesBadge count:0];
    [self pp_updateBadge:self.accessoriesBadge count:0];
}

- (void)pp_updateBadge:(UILabel *)badge count:(NSInteger)count
{
    if (badge == nil) {
        return;
    }

    UIView *hostView = badge.superview;
    while (hostView && ![hostView isKindOfClass:UIButton.class]) {
        hostView = hostView.superview;
    }
    UIButton *hostButton = (UIButton *)hostView;

    if (count <= 0) {
        [UIView animateWithDuration:0.2 animations:^{
            badge.hidden = NO;
            badge.alpha = 0.0;
            badge.transform = CGAffineTransformMakeScale(0.8, 0.8);
        } completion:^(__unused BOOL finished) {
            badge.hidden = YES;
            badge.text = nil;
        }];
        hostButton.accessibilityValue = nil;
        return;
    }

    NSString *nextText = (count > 99) ? @"99+" : [NSString stringWithFormat:@"%ld", (long)count];
    BOOL wasVisible = (badge.alpha > 0.01 && !badge.hidden);
    BOOL didChangeValue = ![badge.text isEqualToString:nextText];

    badge.hidden = NO;
    hostButton.accessibilityValue = nextText;

    if (wasVisible) {
        if (didChangeValue) {
            [UIView transitionWithView:badge
                              duration:0.18
                               options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionBeginFromCurrentState
                            animations:^{
                badge.text = nextText;
            } completion:nil];

            if (!UIAccessibilityIsReduceMotionEnabled()) {
                badge.transform = CGAffineTransformMakeScale(1.12, 1.12);
                [UIView animateWithDuration:0.20
                                      delay:0.0
                     usingSpringWithDamping:0.58
                      initialSpringVelocity:0.55
                                    options:UIViewAnimationOptionBeginFromCurrentState
                                 animations:^{
                    badge.transform = CGAffineTransformIdentity;
                } completion:nil];
            } else {
                badge.transform = CGAffineTransformIdentity;
            }
        }

        badge.transform = CGAffineTransformIdentity;
        return;
    }

    badge.text = nextText;
    badge.transform = CGAffineTransformMakeScale(0.6, 0.6);
    [UIView animateWithDuration:0.25
                          delay:0.0
         usingSpringWithDamping:0.55
          initialSpringVelocity:0.8
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        badge.alpha = 1.0;
        badge.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        if (finished) {
            [PPFunc triggerLightHaptic];
        }
    }];
}

- (void)pp_showSkeletonIfNeeded
{
    if (self.isSearching) {
        return;
    }

    self.isSearching = YES;
    [self pp_showSkeletonCells];
    [self pp_startSearchLoadingAnimation];
    [self updateEmptyState];
    [self updateHeaderStateAnimated:YES];
}

- (void)pp_hideSkeleton
{
    self.isSearching = NO;
    [self pp_stopSearchLoadingAnimation];
    [self updateEmptyState];
    [self updateHeaderStateAnimated:YES];
}

- (void)pp_showSkeletonCells
{
    NSMutableArray<PPUniversalCellViewModel *> *skeletons = [NSMutableArray array];
    NSInteger count = 6;
    for (NSInteger i = 0; i < count; i++) {
        [skeletons addObject:[[PPUniversalCellViewModel alloc] initSkeleton]];
    }
    self.results = skeletons.copy;
    [self applyResultsAnimated:NO];
}

- (void)pp_startSearchLoadingAnimation
{
    [self pp_startSearchBarLoadingPulse];
    [self pp_startHeroLoadingShimmer];
}

- (void)pp_stopSearchLoadingAnimation
{
    [self pp_stopSearchBarLoadingPulse];
    [self pp_stopHeroLoadingShimmer];
}

- (void)pp_startSearchBarLoadingPulse
{
    if (!self.searchFieldIconView) return;

    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    pulse.fromValue = @0.6;
    pulse.toValue = @1.0;
    pulse.duration = 0.6;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.searchFieldIconView.layer addAnimation:pulse forKey:@"pp.search.loading.icon"];

    CABasicAnimation *tint = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    tint.fromValue = @1.0;
    tint.toValue = @1.12;
    tint.duration = 0.6;
    tint.autoreverses = YES;
    tint.repeatCount = HUGE_VALF;
    [self.searchFieldIconView.layer addAnimation:tint forKey:@"pp.search.loading.scale"];
}

- (void)pp_stopSearchBarLoadingPulse
{
    [self.searchFieldIconView.layer removeAnimationForKey:@"pp.search.loading.icon"];
    [self.searchFieldIconView.layer removeAnimationForKey:@"pp.search.loading.scale"];
}

- (void)pp_startHeroLoadingShimmer
{
    if (!self.heroCardView || UIAccessibilityIsReduceMotionEnabled()) return;

    CAGradientLayer *shimmer = [CAGradientLayer layer];
    shimmer.frame = self.heroCardView.bounds;
    shimmer.startPoint = CGPointMake(0.0, 0.5);
    shimmer.endPoint = CGPointMake(1.0, 0.5);

    UIColor *base = [AppPrimaryClr colorWithAlphaComponent:0.0];
    UIColor *highlight = [AppPrimaryClr colorWithAlphaComponent:0.12];
    shimmer.colors = @[(id)base.CGColor, (id)highlight.CGColor, (id)base.CGColor];
    shimmer.locations = @[@0.0, @0.5, @1.0];

    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"locations"];
    anim.fromValue = @[@(-1.0), @(-0.5), @0.0];
    anim.toValue = @[@1.0, @1.5, @2.0];
    anim.duration = 1.8;
    anim.repeatCount = HUGE_VALF;
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [shimmer addAnimation:anim forKey:@"pp.search.loading.shimmer"];

    shimmer.name = @"pp.search.loading.shimmer.layer";
    [self.heroCardView.layer addSublayer:shimmer];
    objc_setAssociatedObject(self, @selector(pp_startHeroLoadingShimmer), shimmer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)pp_stopHeroLoadingShimmer
{
    CAGradientLayer *shimmer = objc_getAssociatedObject(self, @selector(pp_startHeroLoadingShimmer));
    if (shimmer) {
        [shimmer removeAllAnimations];
        [shimmer removeFromSuperlayer];
        objc_setAssociatedObject(self, @selector(pp_startHeroLoadingShimmer), nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (NSString *)selectedSegmentTitle
{
    NSInteger selectedIndex = self.selectedSearchSegment;
    switch (selectedIndex) {
        case PPSearchSegmentServices:
            return kLang(@"services");
        case PPSearchSegmentAccessories:
            return kLang(@"Accessories");
        case PPSearchSegmentAds:
        default:
            return kLang(@"Ads");
    }
}

- (UITextField *)pp_searchTextField
{
    return self.searchTextField;
}

- (NSString *)pp_modernSearchPlaceholderText
{
    NSString *modernText = kLang(@"SearchPlaceholderModern");
    if (modernText.length > 0) {
        return modernText;
    }
    return kLang(@"SearchPlaceholder");
}

- (void)pp_applySearchKeyboardManagerOverridesIfNeeded
{
    IQKeyboardManager *manager = [IQKeyboardManager sharedManager];
    if (!self.isOverridingIQKeyboardManager) {
        self.previousIQKeyboardManagerEnabled = manager.enable;
        self.previousIQKeyboardToolbarEnabled = manager.enableAutoToolbar;
        self.isOverridingIQKeyboardManager = YES;
    }

    manager.enable = NO;
    manager.enableAutoToolbar = NO;
}

- (void)pp_restoreSearchKeyboardManagerOverridesIfNeeded
{
    if (!self.isOverridingIQKeyboardManager) {
        return;
    }

    IQKeyboardManager *manager = [IQKeyboardManager sharedManager];
    manager.enable = self.previousIQKeyboardManagerEnabled;
    manager.enableAutoToolbar = self.previousIQKeyboardToolbarEnabled;
    self.isOverridingIQKeyboardManager = NO;
}

- (void)pp_schedulePendingSearchFieldFocusIfNeeded
{
    if (!self.pendingSearchFieldFocus) {
        return;
    }

    id<UIViewControllerTransitionCoordinator> coordinator = self.transitionCoordinator;
    if (!coordinator) {
        [self pp_activatePendingSearchFieldFocusIfPossible];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [coordinator animateAlongsideTransition:nil
                                 completion:^(__unused id<UIViewControllerTransitionCoordinatorContext> context) {
        [weakSelf pp_activatePendingSearchFieldFocusIfPossible];
    }];
}

- (void)pp_activatePendingSearchFieldFocusIfPossible
{
    if (!self.pendingSearchFieldFocus || !self.isViewLoaded || self.view.window == nil) {
        return;
    }

    UITextField *textField = [self pp_searchTextField];
    if (!textField || textField.isFirstResponder) {
        self.pendingSearchFieldFocus = (textField == nil);
        return;
    }

    if ([textField becomeFirstResponder]) {
        self.pendingSearchFieldFocus = NO;
    }
}

- (void)pp_updateSearchPlaceholderVisibility
{
    BOOL shouldHidePlaceholder = self.searchTextField.text.length > 0;
    self.searchPlaceholderLabel.hidden = shouldHidePlaceholder;
}

- (NSArray<NSDictionary<NSString *, id> *> *)pp_searchSegmentDescriptors
{
    return @[
        @{
            @"title" : (kLang(@"Ads") ?: @"Ads"),
            @"icon" : @"tag.fill",
            @"segment" : @(PPSearchSegmentAds)
        },
        @{
            @"title" : (kLang(@"services") ?: @"Services"),
            @"icon" : @"stethoscope",
            @"segment" : @(PPSearchSegmentServices)
        },
        @{
            @"title" : (kLang(@"Accessories") ?: @"Accessories"),
            @"icon" : @"shippingbox.fill",
            @"segment" : @(PPSearchSegmentAccessories)
        }
    ];
}

- (UIButton *)pp_makeSegmentBadgeButtonWithTitle:(NSString *)title
                                        iconName:(NSString *)iconName
                                         segment:(PPSearchSegment)segment
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tag = segment;
   // button.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    button.backgroundColor = [self pp_heroPanelBackgroundColor];
    button.layer.cornerRadius = 18.0;
    button.layer.borderWidth = 1.0;
    [button pp_setBorderColor:[self pp_heroPanelBorderColor]];
    button.layer.shadowOpacity = 0.0f;
    button.layer.shadowRadius = 12.0f;
    button.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }

    // --- Row 1: Icon (centered) with badge overlay ---
    UIImageSymbolConfiguration *iconConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightSemibold];
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName
                                                                        withConfiguration:iconConfiguration]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tag = kPPSearchSegmentIconTag;
    iconView.tintColor = [self pp_heroSecondaryTextColor];
    iconView.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *countLabel = [self makeBadgeLabel];
    countLabel.tag = kPPSearchSegmentCountTag;
    countLabel.hidden = YES;
    [countLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                forAxis:UILayoutConstraintAxisHorizontal];

    UIView *iconContainer = [UIView new];
    iconContainer.translatesAutoresizingMaskIntoConstraints = NO;
    iconContainer.userInteractionEnabled = NO;
    iconContainer.clipsToBounds = NO;
    [iconContainer addSubview:iconView];
    [iconContainer addSubview:countLabel];

    // --- Row 2: Title (centered, no truncation) ---
    UILabel *titleLabel = [UILabel new];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.tag = kPPSearchSegmentTitleTag;
    titleLabel.text = title ?: @"";
    titleLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = [self pp_heroSecondaryTextColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.numberOfLines = 1;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.78;

    // --- Vertical stack: icon row → title row ---
    UIStackView *vStack = [[UIStackView alloc] initWithArrangedSubviews:@[iconContainer, titleLabel]];
    vStack.translatesAutoresizingMaskIntoConstraints = NO;
    vStack.axis = UILayoutConstraintAxisVertical;
    vStack.alignment = UIStackViewAlignmentCenter;
    vStack.spacing = 4.0;
    vStack.userInteractionEnabled = NO;

    [button addSubview:vStack];

    [NSLayoutConstraint activateConstraints:@[
        [iconView.centerXAnchor constraintEqualToAnchor:iconContainer.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconContainer.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:22.0],
        [iconView.heightAnchor constraintEqualToConstant:22.0],

        [countLabel.centerYAnchor constraintEqualToAnchor:iconView.topAnchor constant:-1.0],
        [countLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:-6.0],

        [iconContainer.widthAnchor constraintGreaterThanOrEqualToConstant:36.0],
        [iconContainer.heightAnchor constraintEqualToConstant:26.0],

        [vStack.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
        [vStack.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
        [vStack.leadingAnchor constraintGreaterThanOrEqualToAnchor:button.leadingAnchor constant:4.0],
        [vStack.trailingAnchor constraintLessThanOrEqualToAnchor:button.trailingAnchor constant:-4.0],
    ]];

    button.isAccessibilityElement = YES;
    button.accessibilityLabel = title ?: @"";
    button.accessibilityHint = NSLocalizedString(@"a11y_search_segment_hint", @"Choose between Ads, Services, or Accessories");
    button.accessibilityTraits = UIAccessibilityTraitButton;

    [button addTarget:self action:@selector(segmentBadgeTapped:) forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(pp_segmentButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(pp_segmentButtonTouchUp:) forControlEvents:UIControlEventTouchUpOutside];
    [button addTarget:self action:@selector(pp_segmentButtonTouchUp:) forControlEvents:UIControlEventTouchCancel];
    return button;
}

- (UILabel *)pp_segmentCountLabelForButton:(UIButton *)button
{
    return (UILabel *)[button viewWithTag:kPPSearchSegmentCountTag];
}

- (UIImageView *)pp_segmentIconViewForButton:(UIButton *)button
{
    return (UIImageView *)[button viewWithTag:kPPSearchSegmentIconTag];
}

- (UILabel *)pp_segmentTitleLabelForButton:(UIButton *)button
{
    return (UILabel *)[button viewWithTag:kPPSearchSegmentTitleTag];
}

- (void)pp_segmentButtonTouchDown:(UIButton *)button
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    [UIView animateWithDuration:0.12
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        button.transform = CGAffineTransformMakeScale(0.975, 0.975);
    } completion:nil];
}

- (void)pp_segmentButtonTouchUp:(UIButton *)button
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        button.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.22
                          delay:0.0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.24
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        button.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_updateSegmentButtonsSelectionAnimated:(BOOL)animated
{
    __block UIButton *selectedButton = nil;
    [self.segmentButtons enumerateObjectsUsingBlock:^(UIButton * _Nonnull button, __unused NSUInteger idx, __unused BOOL * _Nonnull stop) {
        PPSearchSegment segment = (PPSearchSegment)button.tag;
        BOOL isSelected = (segment == self.selectedSearchSegment);
        if (isSelected && selectedButton == nil) {
            selectedButton = button;
        }
        [self pp_applySegmentButton:button selected:isSelected animated:animated];
    }];

    if (selectedButton != nil) {
        [self pp_scrollSegmentButtonIntoView:selectedButton animated:animated];
    }
}

- (void)pp_applySegmentButton:(UIButton *)button selected:(BOOL)selected animated:(BOOL)animated
{
    UIColor *accentColor = [self pp_scopeTintColorForSegment:(PPSearchSegment)button.tag];
    UIImageView *iconView = [self pp_segmentIconViewForButton:button];
    UILabel *titleLabel = [self pp_segmentTitleLabelForButton:button];
    UILabel *countLabel = [self pp_segmentCountLabelForButton:button];
    button.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);

    void (^updates)(void) = ^{
        BOOL darkHero = [self pp_heroUsesDarkSurface];
        CGFloat selectedFillAlpha = darkHero ? 0.24 : 0.12;
        CGFloat selectedBorderAlpha = darkHero ? 0.34 : 0.18;
        button.backgroundColor = selected
            ? [accentColor colorWithAlphaComponent:selectedFillAlpha]
            : [self pp_heroPanelBackgroundColor];
        [button pp_setBorderColor:(selected
            ? [accentColor colorWithAlphaComponent:selectedBorderAlpha]
            : [self pp_heroPanelBorderColor])];
        [button pp_setShadowColor:accentColor];
        button.layer.shadowOpacity = (selected && darkHero) ? 0.12f : 0.0f;

        UIColor *contentColor = selected
            ? (darkHero ? [UIColor colorWithWhite:0.98 alpha:1.0] : accentColor)
            : [self pp_heroSecondaryTextColor];
        iconView.tintColor = contentColor;
        titleLabel.textColor = contentColor;

        countLabel.backgroundColor = selected
            ? [accentColor colorWithAlphaComponent:(darkHero ? 0.30 : 0.16)]
            : [self pp_heroPanelBackgroundColor];
        countLabel.textColor = selected
            ? (darkHero ? [UIColor colorWithWhite:0.98 alpha:1.0] : accentColor)
            : [self pp_heroSecondaryTextColor];
    };

    if (!animated) {
        updates();
        return;
    }

    [UIView animateWithDuration:0.22
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
                     animations:updates
                     completion:nil];
}

- (void)pp_scrollSegmentButtonIntoView:(UIButton *)button animated:(BOOL)animated
{
    if (button == nil || self.segmentScrollView == nil) {
        return;
    }

    CGRect buttonRect = [button convertRect:button.bounds toView:self.segmentScrollView];
    CGFloat horizontalInset = 18.0;
    CGRect targetRect = CGRectInset(buttonRect, -horizontalInset, 0.0);
    [self.segmentScrollView scrollRectToVisible:targetRect animated:animated];
}

- (UIColor *)pp_scopeTintColorForSelectedSegment
{
    return [self pp_scopeTintColorForSegment:self.selectedSearchSegment];
}

- (UIColor *)pp_scopeTintColorForSegment:(PPSearchSegment)segment
{
    switch (segment) {
        case PPSearchSegmentServices:
            return [UIColor colorWithRed:0.34 green:0.66 blue:0.72 alpha:1.0];
        case PPSearchSegmentAccessories:
            return [UIColor colorWithRed:0.83 green:0.56 blue:0.28 alpha:1.0];
        case PPSearchSegmentAds:
        default:
            return AppPrimaryClr ?: [UIColor colorWithRed:0.72 green:0.22 blue:0.36 alpha:1.0];
    }
}

- (void)setLabel:(UILabel *)label text:(NSString *)text animated:(BOOL)animated
{
    NSString *safeText = text ?: @"";
    if ([label.text isEqualToString:safeText]) {
        return;
    }

    void (^changes)(void) = ^{
        label.text = safeText;
    };

    if (!animated) {
        changes();
        return;
    }

    [UIView transitionWithView:label
                      duration:0.22
                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionBeginFromCurrentState
                    animations:changes
                    completion:nil];
}

- (void)setPill:(UILabel *)pill hidden:(BOOL)hidden animated:(BOOL)animated
{
    if (pill.hidden == hidden && fabs(pill.alpha - (hidden ? 0.0 : 1.0)) < 0.01) {
        return;
    }

    void (^changes)(void) = ^{
        pill.hidden = NO;
        pill.alpha = hidden ? 0.0 : 1.0;
        pill.transform = hidden ? CGAffineTransformMakeScale(0.92, 0.92) : CGAffineTransformIdentity;
    };

    void (^completion)(BOOL) = ^(BOOL finished) {
        if (finished) {
            pill.hidden = hidden;
        }
    };

    if (!animated) {
        changes();
        completion(YES);
        return;
    }

    [UIView animateWithDuration:0.22
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:changes
                     completion:completion];
}

- (void)setEmptyStateVisible:(BOOL)visible animated:(BOOL)animated
{
    if (visible == !self.emptyStateView.hidden &&
        fabs(self.emptyStateView.alpha - (visible ? 1.0 : 0.0)) < 0.01) {
        return;
    }

    void (^changes)(void) = ^{
        self.emptyStateView.hidden = NO;
        self.emptyStateView.alpha = visible ? 1.0 : 0.0;
        self.emptyStateView.transform = visible ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0.0, 10.0);
    };

    void (^completion)(BOOL) = ^(BOOL finished) {
        if (finished) {
            self.emptyStateView.hidden = !visible;
        }
    };

    if (!animated) {
        changes();
        completion(YES);
        return;
    }

    [UIView animateWithDuration:0.24
                          delay:0.0
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.42
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:changes
                     completion:completion];
}

- (void)animateHeroIfNeeded
{
    if (self.didAnimateHero) {
        return;
    }

    self.didAnimateHero = YES;
    NSArray<UIView *> *stagedViews = @[
        self.eyebrowLabel,
        self.statusPillLabel,
        self.heroTitleLabel,
        self.heroSubtitleLabel,
        self.segmentGlassView,
        self.heroCollapseToggleButton
    ];

    [stagedViews enumerateObjectsUsingBlock:^(UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 18.0 + (CGFloat)idx * 2.0);
        [UIView animateWithDuration:0.52
                              delay:0.05 * idx
             usingSpringWithDamping:0.88
              initialSpringVelocity:0.72
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];

    if (!UIAccessibilityIsReduceMotionEnabled()) {
        CABasicAnimation *shineDrift = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
        shineDrift.fromValue = @(-18.0);
        shineDrift.toValue = @(18.0);
        shineDrift.duration = 8.4;
        shineDrift.autoreverses = YES;
        shineDrift.repeatCount = HUGE_VALF;
        shineDrift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.heroShineLayer addAnimation:shineDrift forKey:@"pp.search.hero.shineDrift"];
    }

    // Gentle glow fade-in, then breathing
    [UIView animateWithDuration:0.9 delay:0.25 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.primaryGlowView.alpha = 0.38;
        self.secondaryGlowView.alpha = 0.28;
    } completion:^(BOOL finished) {
        if (!finished) return;
        // Breathing animation — slow opacity pulse for ambient life
        CABasicAnimation *breathePrimary = [CABasicAnimation animationWithKeyPath:@"opacity"];
        breathePrimary.fromValue = @(0.14);
        breathePrimary.toValue = @(0.64);
        breathePrimary.duration = 3.8;
        breathePrimary.autoreverses = YES;
        breathePrimary.repeatCount = HUGE_VALF;
        breathePrimary.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.primaryGlowView.layer addAnimation:breathePrimary forKey:@"breathe"];

        CABasicAnimation *breatheSecondary = [CABasicAnimation animationWithKeyPath:@"opacity"];
        breatheSecondary.fromValue = @(0.10);
        breatheSecondary.toValue = @(0.68);
        breatheSecondary.duration = 4.2;
        breatheSecondary.autoreverses = YES;
        breatheSecondary.repeatCount = HUGE_VALF;
        breatheSecondary.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.secondaryGlowView.layer addAnimation:breatheSecondary forKey:@"breathe"];
        
        self.primaryGlowView.alpha = 1.0;
        self.secondaryGlowView.alpha = 1.0;
    }];
}

- (void)updateBackdropForOffset:(CGFloat)offset
{
    CGFloat positiveOffset = MAX(0.0, offset);
    CGFloat drift = MIN(positiveOffset, 180.0);

    self.primaryGlowView.transform = CGAffineTransformConcat(
        CGAffineTransformMakeTranslation(-drift * 0.12, drift * 0.10),
        CGAffineTransformMakeScale(1.0 + drift / 1200.0, 1.0 + drift / 1200.0)
    );
    self.secondaryGlowView.transform = CGAffineTransformConcat(
        CGAffineTransformMakeTranslation(drift * 0.10, -drift * 0.08),
        CGAffineTransformMakeScale(1.0 + drift / 1500.0, 1.0 + drift / 1500.0)
    );
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UIEdgeInsets sectionInset = UIEdgeInsetsMake(0.0,
                                                 kPPSearchHorizontalInset,
                                                 64.0,
                                                 kPPSearchHorizontalInset);
    CGFloat interitemSpacing = kPPSearchInteritemSpacing;
    UICollectionViewFlowLayout *flowLayout =
    [collectionViewLayout isKindOfClass:[UICollectionViewFlowLayout class]]
    ? (UICollectionViewFlowLayout *)collectionViewLayout
    : nil;
    if (flowLayout) {
        sectionInset = flowLayout.sectionInset;
        interitemSpacing = flowLayout.minimumInteritemSpacing;
    }

    CGFloat availableWidth = collectionView.bounds.size.width - sectionInset.left - sectionInset.right;
    CGFloat gridWidth = floor((availableWidth - interitemSpacing) / 2.0);
    CGFloat itemHeight = 320.0;
    return CGSizeMake(MAX(0.0, gridWidth), itemHeight);
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self updateBackdropForOffset:scrollView.contentOffset.y];
}

#pragma mark - PPUniversalCellDelegate

- (void)PPUniversalCell_tapCard:(PPUniversalCellViewModel *)universalModel
{
    if (!universalModel || !universalModel.ModelObject) {
        NSLog(@"[Search][TapCard] payload is nil");
        return;
    }

    id object = universalModel.ModelObject;

    if ([object isKindOfClass:[NSDictionary class]]) {
        NSDictionary *ref = (NSDictionary *)object;
        NSString *kind = ref[@"kind"];
        NSString *docID = ref[@"docID"] ?: ref[@"id"];

        if (!kind || !docID) {
            NSLog(@"[Search][TapCard] invalid image search ref");
            return;
        }

        [PPHUD showIndeterminateIn:self.view
                              title:kLang(@"Loading")
                           subtitle:nil];
        __weak typeof(self) weakSelf = self;
        [self fetchFullDocumentForKind:kind documentID:docID completion:^(id fullObject) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [PPHUD dismiss];

            if (fullObject) {
                [PPOverlayCoordinator pp_openDetailForObject:fullObject
                                                      fromVC:strongSelf
                                                  routingNav:nil];
            } else {
                [AppMgr showSnakBar:kLang(@"UnableToLoadDetails") withColor:nil andDuration:2.0 containerView:strongSelf.view];
            }
        }];
        return;
    }

    [PPOverlayCoordinator pp_openDetailForObject:universalModel.ModelObject
                                          fromVC:self
                                      routingNav:nil];
}

#pragma mark - Image Search

- (void)didTapImageSearchButton
{
    [self.view endEditing:YES];
    [self pp_imageSearchButtonTouchUp:self.imageSearchButton];
    [PPFunc triggerLightHaptic];
    [self pp_presentImageSearchSourceSheet];
}

- (void)pp_presentImageSearchSourceSheet
{
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:kLang(@"ImageSearchSourceTitle")
                                                                   message:kLang(@"ImageSearchSourceSubtitle")
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    __weak typeof(self) weakSelf = self;
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        UIAlertAction *cameraAction = [UIAlertAction actionWithTitle:kLang(@"ImageSearchTakePhoto")
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(__unused UIAlertAction *action) {
            [weakSelf pp_openImageSearchCamera];
        }];
        [sheet addAction:cameraAction];
    }

    UIAlertAction *libraryAction = [UIAlertAction actionWithTitle:kLang(@"ImageSearchChoosePhoto")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(__unused UIAlertAction *action) {
        [weakSelf pp_openImageSearchPhotoLibrary];
    }];
    [sheet addAction:libraryAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:(kLang(@"cancel") ?: kLang(@"Cancel"))
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [sheet addAction:cancelAction];

    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover) {
        popover.sourceView = self.imageSearchButton ?: self.view;
        popover.sourceRect = self.imageSearchButton ? self.imageSearchButton.bounds : self.view.bounds;
        popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)pp_openImageSearchCamera
{
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        [AppMgr showSnakBar:kLang(@"ImageSearchCameraUnavailable")
                  withColor:nil
                andDuration:2.0
              containerView:self.view];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [PPPermissionHelper requestCameraPermissionFromViewController:self completion:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || !granted) {
                return;
            }
            [strongSelf pp_presentImageSearchPickerWithSourceType:UIImagePickerControllerSourceTypeCamera];
        });
    }];
}

- (void)pp_openImageSearchPhotoLibrary
{
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        [AppMgr showSnakBar:kLang(@"ImageSearchPhotoLibraryUnavailable")
                  withColor:nil
                andDuration:2.0
              containerView:self.view];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [PPPermissionHelper requestPhotoLibraryPermissionFromViewController:self completion:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || !granted) {
                return;
            }
            [strongSelf pp_presentImageSearchPickerWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
        });
    }];
}

- (void)pp_presentImageSearchPickerWithSourceType:(UIImagePickerControllerSourceType)sourceType
{
    if (![UIImagePickerController isSourceTypeAvailable:sourceType]) {
        NSString *message = (sourceType == UIImagePickerControllerSourceTypeCamera)
            ? kLang(@"ImageSearchCameraUnavailable")
            : kLang(@"ImageSearchPhotoLibraryUnavailable");
        [AppMgr showSnakBar:message withColor:nil andDuration:2.0 containerView:self.view];
        return;
    }

    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = sourceType;
    picker.allowsEditing = NO;
    picker.modalPresentationStyle = UIModalPresentationFullScreen;

    if (sourceType == UIImagePickerControllerSourceTypePhotoLibrary &&
        UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad &&
        picker.popoverPresentationController) {
        picker.popoverPresentationController.sourceView = self.imageSearchButton ?: self.view;
        picker.popoverPresentationController.sourceRect = self.imageSearchButton ? self.imageSearchButton.bounds : self.view.bounds;
        picker.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }

    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker
 didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info
{
    UIImage *image = info[UIImagePickerControllerEditedImage];
    if (![image isKindOfClass:UIImage.class]) {
        image = info[UIImagePickerControllerOriginalImage];
    }

    __weak typeof(self) weakSelf = self;
    [picker dismissViewControllerAnimated:YES completion:^{
        [weakSelf runDirectImageSearch:image];
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (nullable NSDictionary *)pp_dictionaryFromObject:(id)object
{
    return [object isKindOfClass:NSDictionary.class] ? (NSDictionary *)object : nil;
}

- (NSArray *)pp_arrayFromObject:(id)object
{
    return [object isKindOfClass:NSArray.class] ? (NSArray *)object : @[];
}

- (NSString *)pp_stringFromObject:(id)object
{
    NSString *string = @"";
    if ([object isKindOfClass:NSString.class]) {
        string = (NSString *)object;
    } else if ([object isKindOfClass:NSNumber.class]) {
        string = [(NSNumber *)object stringValue];
    }
    return [string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
}

- (NSNumber *)pp_numberFromObject:(id)object
{
    if ([object isKindOfClass:NSNumber.class]) {
        return (NSNumber *)object;
    }
    NSString *string = [self pp_stringFromObject:object];
    if (string.length == 0) {
        return nil;
    }

    static NSNumberFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSNumberFormatter new];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
    });

    NSNumber *number = [formatter numberFromString:string];
    if (number) {
        return number;
    }

    double raw = string.doubleValue;
    return raw > 0.0 ? @(raw) : nil;
}

- (NSString *)pp_firstStringInDictionary:(NSDictionary *)dictionary
                                    keys:(NSArray<NSString *> *)keys
{
    if (![dictionary isKindOfClass:NSDictionary.class]) {
        return @"";
    }
    for (NSString *key in keys) {
        NSString *value = [self pp_stringFromObject:dictionary[key]];
        if (value.length > 0) {
            return value;
        }
    }
    return @"";
}

- (NSNumber *)pp_firstNumberInDictionary:(NSDictionary *)dictionary
                                    keys:(NSArray<NSString *> *)keys
{
    if (![dictionary isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    for (NSString *key in keys) {
        NSNumber *number = [self pp_numberFromObject:dictionary[key]];
        if (number) {
            return number;
        }
    }
    return nil;
}

- (NSString *)pp_normalizedImageSearchKindFromDictionary:(NSDictionary *)dictionary
{
    NSString *rawKind = [self pp_firstStringInDictionary:dictionary
                                                    keys:@[@"kind", @"type", @"resultKind", @"collection"]];
    NSString *kind = [[rawKind.lowercaseString stringByReplacingOccurrencesOfString:@"-" withString:@"_"]
                      stringByReplacingOccurrencesOfString:@" " withString:@"_"];

    if (kind.length == 0) {
        NSNumber *accessKindType = [self pp_numberFromObject:dictionary[@"accessKindType"]];
        if (accessKindType) {
            return accessKindType.integerValue == 4 ? @"medicine" : @"product";
        }
    }

    if ([kind isEqualToString:@"product"] ||
        [kind isEqualToString:@"products"] ||
        [kind isEqualToString:@"accessory"] ||
        [kind isEqualToString:@"accessories"] ||
        [kind isEqualToString:@"petaccessories"] ||
        [kind isEqualToString:@"petaccessory"]) {
        NSNumber *accessKindType = [self pp_numberFromObject:dictionary[@"accessKindType"]];
        return accessKindType.integerValue == 4 ? @"medicine" : @"product";
    }

    if ([kind isEqualToString:@"medicine"] || [kind isEqualToString:@"medicines"]) {
        return @"medicine";
    }

    if ([kind isEqualToString:@"pet_ad"] ||
        [kind isEqualToString:@"pet_ads"] ||
        [kind isEqualToString:@"petad"] ||
        [kind isEqualToString:@"pets"] ||
        [kind isEqualToString:@"pets_for_sale"]) {
        return @"pet_ad";
    }

    if ([kind isEqualToString:@"adoption"] ||
        [kind isEqualToString:@"adopt"] ||
        [kind isEqualToString:@"adopt_pets"] ||
        [kind isEqualToString:@"adoptpet"]) {
        return @"adoption";
    }

    return kind;
}

- (NSString *)pp_imageSearchIdentityForKind:(NSString *)kind
                                      docID:(NSString *)docID
{
    if (kind.length == 0 || docID.length == 0) {
        return @"";
    }
    return [NSString stringWithFormat:@"%@|%@", kind, docID];
}

- (NSArray<NSDictionary *> *)pp_normalizedImageSearchRefsFromArray:(NSArray *)refs
{
    NSMutableArray<NSDictionary *> *normalizedRefs = [NSMutableArray array];
    for (id object in refs) {
        NSDictionary *rawRef = [self pp_dictionaryFromObject:object];
        if (!rawRef) {
            continue;
        }

        NSString *kind = [self pp_normalizedImageSearchKindFromDictionary:rawRef];
        NSString *docID = [self pp_firstStringInDictionary:rawRef
                                                      keys:@[@"id", @"docID", @"documentID", @"objectID", @"itemID", @"itemId"]];
        if (kind.length == 0 || docID.length == 0) {
            continue;
        }

        NSMutableDictionary *ref = rawRef.mutableCopy ?: [NSMutableDictionary dictionary];
        ref[@"kind"] = kind;
        ref[@"id"] = docID;
        ref[@"docID"] = docID;
        [normalizedRefs addObject:ref.copy];
    }
    return normalizedRefs.copy;
}

- (NSArray<NSDictionary *> *)pp_imageSearchResultRefsFromResponse:(NSDictionary *)response
                                                         metadata:(NSDictionary *)metadata
                                                          results:(NSArray *)results
{
    NSArray *candidateRefs = [self pp_arrayFromObject:metadata[@"resultRefs"]];
    if (candidateRefs.count == 0) {
        candidateRefs = [self pp_arrayFromObject:response[@"resultRefs"]];
    }

    NSArray<NSDictionary *> *normalizedRefs = [self pp_normalizedImageSearchRefsFromArray:candidateRefs];
    if (normalizedRefs.count > 0) {
        return normalizedRefs;
    }

    return [self pp_normalizedImageSearchRefsFromArray:results];
}

- (NSDictionary<NSString *, NSDictionary *> *)pp_imageSearchLightResultsByIdentity:(NSArray *)results
{
    NSMutableDictionary<NSString *, NSDictionary *> *lookup = [NSMutableDictionary dictionary];
    for (id object in results) {
        NSDictionary *result = [self pp_dictionaryFromObject:object];
        if (!result) {
            continue;
        }
        NSString *kind = [self pp_normalizedImageSearchKindFromDictionary:result];
        NSString *docID = [self pp_firstStringInDictionary:result
                                                      keys:@[@"id", @"docID", @"documentID", @"objectID", @"itemID", @"itemId"]];
        NSString *identity = [self pp_imageSearchIdentityForKind:kind docID:docID];
        if (identity.length > 0 && !lookup[identity]) {
            lookup[identity] = result;
        }
    }
    return lookup.copy;
}

- (NSString *)pp_imageSearchMediaURLFromObject:(id)object
{
    NSString *string = [self pp_stringFromObject:object];
    if (string.length > 0) {
        return string;
    }

    NSDictionary *dictionary = [self pp_dictionaryFromObject:object];
    if (dictionary) {
        NSString *mediaType = [[self pp_firstStringInDictionary:dictionary
                                                           keys:@[@"media_type", @"mediaType", @"type", @"mimeType", @"contentType"]] lowercaseString];
        NSString *thumbnail = [self pp_firstStringInDictionary:dictionary
                                                          keys:@[@"thumbnail_url", @"thumbnailURL", @"thumbnailUrl", @"thumbURL", @"coverURL", @"coverUrl"]];
        NSString *direct = [self pp_firstStringInDictionary:dictionary
                                                       keys:@[@"url", @"imageUrl", @"imageURL", @"downloadURL", @"downloadUrl", @"path"]];
        BOOL isVideo = [mediaType isEqualToString:@"video"] || [mediaType hasPrefix:@"video/"];
        return isVideo ? (thumbnail.length > 0 ? thumbnail : direct) : (direct.length > 0 ? direct : thumbnail);
    }

    NSArray *array = [self pp_arrayFromObject:object];
    for (id item in array) {
        NSString *url = [self pp_imageSearchMediaURLFromObject:item];
        if (url.length > 0) {
            return url;
        }
    }
    return @"";
}

- (NSDictionary *)pp_firstImageSearchMediaMetadataFromObject:(id)object
{
    NSDictionary *dictionary = [self pp_dictionaryFromObject:object];
    if (dictionary) {
        return dictionary;
    }

    NSArray *array = [self pp_arrayFromObject:object];
    for (id item in array) {
        NSDictionary *itemDictionary = [self pp_dictionaryFromObject:item];
        if (itemDictionary) {
            return itemDictionary;
        }
    }
    return nil;
}

- (NSDictionary *)pp_firstImageSearchMediaMetadataFromDictionary:(NSDictionary *)dictionary
{
    for (NSString *key in @[@"imageMeta", @"imageItems", @"imageItemsRaw", @"media", @"images", @"photos"]) {
        NSDictionary *metadata = [self pp_firstImageSearchMediaMetadataFromObject:dictionary[key]];
        if (metadata) {
            return metadata;
        }
    }
    return nil;
}

- (NSString *)pp_firstImageSearchImageURLFromDictionary:(NSDictionary *)dictionary
{
    NSString *direct = [self pp_firstStringInDictionary:dictionary
                                                   keys:@[@"imageUrl", @"imageURL", @"thumbnailURL", @"thumbnailUrl", @"thumbnail_url", @"mainImage", @"mainImageUrl", @"photoURL", @"thumbnail", @"coverImage", @"coverUrl", @"image"]];
    if (direct.length > 0) {
        return direct;
    }

    for (NSString *key in @[@"imageMeta", @"imageItems", @"imageItemsRaw", @"imageURLsArray", @"imageURLs", @"imageUrls", @"imagesURLs", @"images", @"photos", @"media", @"files"]) {
        NSString *url = [self pp_imageSearchMediaURLFromObject:dictionary[key]];
        if (url.length > 0) {
            return url;
        }
    }
    return @"";
}

- (CGFloat)pp_imageSearchAspectRatioFromMetadata:(NSDictionary *)metadata
                                        fallback:(CGFloat)fallback
{
    NSNumber *width = [self pp_firstNumberInDictionary:metadata
                                                  keys:@[@"thumbnail_width", @"thumbnailWidth", @"width", @"imageWidth"]];
    NSNumber *height = [self pp_firstNumberInDictionary:metadata
                                                   keys:@[@"thumbnail_height", @"thumbnailHeight", @"height", @"imageHeight"]];
    if (width.doubleValue <= 0.0 || height.doubleValue <= 0.0) {
        return fallback;
    }
    CGFloat ratio = height.doubleValue / width.doubleValue;
    return MAX(0.68, MIN(1.24, ratio));
}

- (void)runDirectImageSearch:(UIImage *)image
{
    if (!image) {
        [AppMgr showSnakBar:kLang(@"ImageSearchImageRequired")
                  withColor:nil
                andDuration:2.0
              containerView:self.view];
        return;
    }

    NSInteger generation = self.imageSearchRequestGeneration + 1;
    self.imageSearchRequestGeneration = generation;
    self.currentSearchRequestID += 1;
    self.lastImageSearchImage = image;
    self.lastQuery = nil;
    self.searchTextField.text = @"";
    [self pp_updateSearchPlaceholderVisibility];

    self.imageSearchResultRefs = @[];
    self.imageSearchRawResults = @[];
    self.imageSearchAllResults = @[];
    self.allSearchResults = @[];
    self.results = @[];
    self.isSearching = YES;
    [self pp_hideAllBadges];
    [self applyResultsAnimated:NO];
    [self pp_setImageSearchLoading:YES];
    [self pp_setImageSearchLoadingOverlayVisible:YES animated:YES];
    [self pp_hideSkeleton];
    [self updateEmptyState];
    [self updateHeaderStateAnimated:YES];

    if (!self.isHeroCollapsed) {
        [self setHeroCollapsed:YES animated:YES];
    }

    __weak typeof(self) weakSelf = self;
    [[PPImageSearchService shared] searchWithImage:image
                                              mode:PPImageSearchModeAuto
                                             limit:@20
                                        completion:^(NSDictionary * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || generation != strongSelf.imageSearchRequestGeneration) {
                return;
            }

            strongSelf.isSearching = NO;
            [strongSelf pp_setImageSearchLoading:NO];
            [strongSelf pp_setImageSearchLoadingOverlayVisible:NO animated:YES];

            if (error) {
                NSLog(@"Image search error: %@", error.localizedDescription);
                [strongSelf pp_clearImageSearchState];
                [strongSelf pp_hideAllBadges];
                strongSelf.results = @[];
                [strongSelf applyResultsAnimated:NO];
                [strongSelf updateEmptyState];
                [strongSelf updateHeaderStateAnimated:YES];
                [strongSelf pp_animateImageSearchErrorFeedback];
                NSString *message = error.localizedDescription.length > 0 ? error.localizedDescription : kLang(@"ImageSearchError");
                [AppMgr showSnakBar:message withColor:nil andDuration:2.0 containerView:strongSelf.view];
                return;
            }

            NSDictionary *metadata = [strongSelf pp_dictionaryFromObject:response[@"metadata"]] ?: @{};
            NSDictionary *detected = [strongSelf pp_dictionaryFromObject:response[@"detected"]] ?: @{};
            NSArray *results = [strongSelf pp_arrayFromObject:response[@"results"]];
            NSArray *resultRefs = [strongSelf pp_imageSearchResultRefsFromResponse:response
                                                                          metadata:metadata
                                                                           results:results];

            [strongSelf renderDirectImageSearchResults:results resultRefs:resultRefs metadata:detected];
        });
    }];
}

- (void)renderDirectImageSearchResults:(NSArray *)results
                            resultRefs:(NSArray *)resultRefs
                              metadata:(NSDictionary *)metadata
{
    NSDictionary *safeMetadata = [self pp_dictionaryFromObject:metadata] ?: @{};
    NSArray *safeResults = [self pp_arrayFromObject:results];
    NSArray *safeResultRefs = [self pp_normalizedImageSearchRefsFromArray:[self pp_arrayFromObject:resultRefs]];
    if (safeResultRefs.count == 0) {
        safeResultRefs = [self pp_normalizedImageSearchRefsFromArray:safeResults];
    }

    if (safeMetadata[@"speciesText"] || safeMetadata[@"productType"]) {
        NSString *species = [self pp_stringFromObject:safeMetadata[@"speciesText"]];
        NSString *breed = [self pp_stringFromObject:safeMetadata[@"breedText"]];
        NSString *product = [self pp_stringFromObject:safeMetadata[@"productType"]];

        if (species.length > 0) {
            NSString *full = [NSString stringWithFormat:@"%@ %@", species.capitalizedString, breed];
            self.heroTitleLabel.text = [full stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            self.heroSubtitleLabel.text = kLang(@"ImageSearchDetectedSubtitle");
        } else if (product.length > 0) {
            self.heroTitleLabel.text = product.capitalizedString;
            self.heroSubtitleLabel.text = kLang(@"ImageSearchDetectedSubtitle");
        }
    }

    if (safeResultRefs.count == 0) {
        self.imageSearchResultRefs = @[];
        self.imageSearchRawResults = @[];
        self.imageSearchAllResults = @[];
        self.allSearchResults = @[];
        self.results = @[];
        [self pp_hideAllBadges];
        [self applyResultsAnimated:NO];
        [self updateEmptyState];
        [self updateHeaderStateAnimated:YES];
        return;
    }

    self.imageSearchResultRefs = safeResultRefs;
    self.imageSearchRawResults = safeResults;

    NSDictionary<NSString *, NSDictionary *> *lightResultsByIdentity =
        [self pp_imageSearchLightResultsByIdentity:safeResults];
    NSMutableArray<PPUniversalCellViewModel *> *viewModels = [NSMutableArray arrayWithCapacity:safeResultRefs.count];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];

    for (NSUInteger i = 0; i < safeResultRefs.count; i++) {
        NSDictionary *ref = safeResultRefs[i];
        NSString *kind = [self pp_stringFromObject:ref[@"kind"]];
        NSString *docID = [self pp_stringFromObject:ref[@"docID"]];
        NSString *refID = [self pp_imageSearchIdentityForKind:kind docID:docID];
        if (refID.length == 0 || [seen containsObject:refID]) {
            continue;
        }
        [seen addObject:refID];

        NSDictionary *lightResult = lightResultsByIdentity[refID];
        if (!lightResult && i < safeResults.count) {
            lightResult = [self pp_dictionaryFromObject:safeResults[i]];
        }

        PPUniversalCellViewModel *vm = [self viewModelForImageSearchRef:ref lightResult:lightResult];
        if (vm) {
            [viewModels addObject:vm];
        }
    }

    self.imageSearchAllResults = viewModels.copy;
    self.allSearchResults = @[];
    [self pp_selectBestSegmentForImageSearchRefs:safeResultRefs];
    [self pp_updateImageSearchSegmentBadgesWithRefs:safeResultRefs];
    [self pp_updateSegmentButtonsSelectionAnimated:YES];
    [self pp_applyImageSearchSegmentFilterAnimated:YES];

    if (!self.isHeroCollapsed) {
        [self setHeroCollapsed:YES animated:YES];
    }
}

- (BOOL)pp_isImageSearchMode
{
    return self.lastImageSearchImage != nil;
}

- (void)pp_clearImageSearchState
{
    self.lastImageSearchImage = nil;
    self.imageSearchResultRefs = @[];
    self.imageSearchRawResults = @[];
    self.imageSearchAllResults = @[];
    [self pp_setImageSearchLoading:NO];
    [self pp_setImageSearchLoadingOverlayVisible:NO animated:YES];
}

- (void)pp_applyImageSearchSegmentFilterAnimated:(BOOL)animated
{
    NSInteger selectedIndex = self.selectedSearchSegment;
    if (selectedIndex < PPSearchSegmentAds || selectedIndex > PPSearchSegmentAccessories) {
        selectedIndex = PPSearchSegmentAds;
    }

    NSMutableArray<PPUniversalCellViewModel *> *filtered = [NSMutableArray array];
    for (PPUniversalCellViewModel *viewModel in self.imageSearchAllResults) {
        if ([self pp_imageSearchViewModel:viewModel belongsToSegment:selectedIndex]) {
            [filtered addObject:viewModel];
        }
    }

    self.results = filtered.copy;
    [self applyResultsAnimated:animated];
    [self updateEmptyState];
    [self updateHeaderStateAnimated:YES];

    if (animated && self.results.count > 0) {
        [self pp_animateVisibleImageSearchResultsIfNeeded];
    }
}

- (BOOL)pp_imageSearchViewModel:(PPUniversalCellViewModel *)viewModel
               belongsToSegment:(PPSearchSegment)segment
{
    NSDictionary *ref = [viewModel.ModelObject isKindOfClass:NSDictionary.class]
        ? (NSDictionary *)viewModel.ModelObject
        : nil;
    NSString *kind = [ref[@"kind"] isKindOfClass:NSString.class] ? ref[@"kind"] : nil;

    switch (segment) {
        case PPSearchSegmentAds:
            return [kind isEqualToString:@"pet_ad"] || [kind isEqualToString:@"adoption"];
        case PPSearchSegmentAccessories:
            return [kind isEqualToString:@"product"] || [kind isEqualToString:@"medicine"];
        case PPSearchSegmentServices:
            return NO;
    }
    return NO;
}

- (void)pp_updateImageSearchSegmentBadgesWithRefs:(NSArray<NSDictionary *> *)refs
{
    NSInteger adsCount = 0;
    NSInteger accessoriesCount = 0;

    for (NSDictionary *ref in refs) {
        if (![ref isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSString *kind = [ref[@"kind"] isKindOfClass:NSString.class] ? ref[@"kind"] : nil;
        if ([kind isEqualToString:@"pet_ad"] || [kind isEqualToString:@"adoption"]) {
            adsCount += 1;
        } else if ([kind isEqualToString:@"product"] || [kind isEqualToString:@"medicine"]) {
            accessoriesCount += 1;
        }
    }

    [self pp_updateBadge:self.adsBadge count:adsCount];
    [self pp_updateBadge:self.servicesBadge count:0];
    [self pp_updateBadge:self.accessoriesBadge count:accessoriesCount];
}

- (void)pp_selectBestSegmentForImageSearchRefs:(NSArray<NSDictionary *> *)refs
{
    NSInteger currentCount = [self pp_countImageSearchRefs:refs forSegment:self.selectedSearchSegment];
    if (currentCount > 0) {
        return;
    }

    NSInteger adsCount = [self pp_countImageSearchRefs:refs forSegment:PPSearchSegmentAds];
    NSInteger accessoriesCount = [self pp_countImageSearchRefs:refs forSegment:PPSearchSegmentAccessories];

    self.selectedSearchSegment = (adsCount > 0 || accessoriesCount == 0)
        ? PPSearchSegmentAds
        : PPSearchSegmentAccessories;
}

- (NSInteger)pp_countImageSearchRefs:(NSArray<NSDictionary *> *)refs
                          forSegment:(PPSearchSegment)segment
{
    NSInteger count = 0;
    for (NSDictionary *ref in refs) {
        if (![ref isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSString *kind = [ref[@"kind"] isKindOfClass:NSString.class] ? ref[@"kind"] : nil;
        if (segment == PPSearchSegmentAds &&
            ([kind isEqualToString:@"pet_ad"] || [kind isEqualToString:@"adoption"])) {
            count += 1;
        } else if (segment == PPSearchSegmentAccessories &&
                   ([kind isEqualToString:@"product"] || [kind isEqualToString:@"medicine"])) {
            count += 1;
        }
    }
    return count;
}

- (void)pp_setImageSearchLoading:(BOOL)loading
{
    UIButton *button = self.imageSearchButton;
    if (!button) {
        return;
    }

    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:18.0 weight:UIImageSymbolWeightSemibold];
    if (loading) {
        [button setImage:[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:config]
                forState:UIControlStateNormal];
    } else {
        config = [self pp_imageSearchCameraSymbolConfigurationWithPointSize:26.0
                                                                     weight:UIImageSymbolWeightSemibold];
        [button setPreferredSymbolConfiguration:config forImageInState:UIControlStateNormal];
        [button setImage:[self pp_imageSearchCameraSymbolWithConfiguration:config]
                forState:UIControlStateNormal];
        [self pp_applyImageSearchButtonSymbolEffectIfAvailable:button];
    }
    button.enabled = !loading;
    button.alpha = loading ? 0.82 : 1.0;
    button.accessibilityValue = loading ? kLang(@"ImageSearchPreparing") : nil;

    [button.layer removeAnimationForKey:@"pp.imageSearch.loadingPulse"];
    button.transform = CGAffineTransformIdentity;

    if (loading && !UIAccessibilityIsReduceMotionEnabled()) {
        CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        pulse.fromValue = @(0.96);
        pulse.toValue = @(1.045);
        pulse.duration = 0.72;
        pulse.autoreverses = YES;
        pulse.repeatCount = HUGE_VALF;
        pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [button.layer addAnimation:pulse forKey:@"pp.imageSearch.loadingPulse"];
    }
}

- (void)pp_setImageSearchLoadingOverlayVisible:(BOOL)visible animated:(BOOL)animated
{
    UIView *hostView = self.imageSearchLoadingView;
    UIView *cardView = self.imageSearchLoadingCardView;
    if (!hostView || !cardView) {
        return;
    }

    self.imageSearchLoadingTitleLabel.text = kLang(@"ImageSearchLoadingTitle");
    self.imageSearchLoadingSubtitleLabel.text = kLang(@"ImageSearchLoadingSubtitle");

    if (visible == self.imageSearchLoadingVisible && hostView.hidden == !visible) {
        if (visible) {
            [self pp_startImageSearchLoadingAnimations];
        }
        return;
    }

    self.imageSearchLoadingVisible = visible;
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();

    if (visible) {
        hostView.hidden = NO;
        [self pp_startImageSearchLoadingAnimations];

        if (!animated || reduceMotion) {
            hostView.alpha = 1.0;
            cardView.alpha = 1.0;
            cardView.transform = CGAffineTransformIdentity;
            return;
        }

        hostView.alpha = 0.0;
        cardView.alpha = 0.0;
        cardView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 12.0),
                                                     CGAffineTransformMakeScale(0.975, 0.975));
        [UIView animateWithDuration:0.34
                              delay:0.0
             usingSpringWithDamping:0.88
              initialSpringVelocity:0.42
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                         animations:^{
            hostView.alpha = 1.0;
            cardView.alpha = 1.0;
            cardView.transform = CGAffineTransformIdentity;
        } completion:nil];
        return;
    }

    void (^finishHidden)(void) = ^{
        hostView.hidden = YES;
        hostView.alpha = 0.0;
        cardView.alpha = 1.0;
        cardView.transform = CGAffineTransformIdentity;
        [self pp_stopImageSearchLoadingAnimations];
    };

    if (!animated || reduceMotion) {
        finishHidden();
        return;
    }

    [UIView animateWithDuration:0.20
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseIn
                     animations:^{
        hostView.alpha = 0.0;
        cardView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -6.0),
                                                     CGAffineTransformMakeScale(0.985, 0.985));
    } completion:^(__unused BOOL finished) {
        finishHidden();
    }];
}

- (void)pp_startImageSearchLoadingAnimations
{
    [self pp_stopImageSearchLoadingAnimations];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.imageSearchLoadingOrbView.transform = CGAffineTransformIdentity;
        self.imageSearchLoadingIconView.alpha = 1.0;
        return;
    }

    CABasicAnimation *orbSpin = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    orbSpin.fromValue = @(0.0);
    orbSpin.toValue = @(M_PI * 2.0);
    orbSpin.duration = 2.4;
    orbSpin.repeatCount = HUGE_VALF;
    orbSpin.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    [self.imageSearchLoadingOrbView.layer addAnimation:orbSpin forKey:@"pp.imageSearch.loading.orbSpin"];

    CABasicAnimation *orbPulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    orbPulse.fromValue = @(0.965);
    orbPulse.toValue = @(1.035);
    orbPulse.duration = 0.9;
    orbPulse.autoreverses = YES;
    orbPulse.repeatCount = HUGE_VALF;
    orbPulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.imageSearchLoadingOrbView.layer addAnimation:orbPulse forKey:@"pp.imageSearch.loading.orbPulse"];

    CABasicAnimation *iconPulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    iconPulse.fromValue = @(0.70);
    iconPulse.toValue = @(1.0);
    iconPulse.duration = 0.72;
    iconPulse.autoreverses = YES;
    iconPulse.repeatCount = HUGE_VALF;
    iconPulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.imageSearchLoadingIconView.layer addAnimation:iconPulse forKey:@"pp.imageSearch.loading.iconPulse"];
}

- (void)pp_stopImageSearchLoadingAnimations
{
    [self.imageSearchLoadingOrbView.layer removeAnimationForKey:@"pp.imageSearch.loading.orbSpin"];
    [self.imageSearchLoadingOrbView.layer removeAnimationForKey:@"pp.imageSearch.loading.orbPulse"];
    [self.imageSearchLoadingIconView.layer removeAnimationForKey:@"pp.imageSearch.loading.iconPulse"];
    self.imageSearchLoadingOrbView.transform = CGAffineTransformIdentity;
    self.imageSearchLoadingIconView.alpha = 1.0;
}

- (void)pp_imageSearchButtonTouchDown:(UIButton *)button
{
    if (!button.enabled || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    [self pp_applyImageSearchButtonSymbolEffectIfAvailable:button];

    [UIView animateWithDuration:0.12
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        button.transform = CGAffineTransformMakeScale(0.94, 0.94);
    } completion:nil];
}

- (void)pp_imageSearchButtonTouchUp:(UIButton *)button
{
    if (!button || UIAccessibilityIsReduceMotionEnabled()) {
        button.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.24
                          delay:0.0
         usingSpringWithDamping:0.74
          initialSpringVelocity:0.45
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        button.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_animateVisibleImageSearchResultsIfNeeded
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        NSArray<UICollectionViewCell *> *visibleCells = self.collectionView.visibleCells;
        NSArray<UICollectionViewCell *> *sortedCells =
            [visibleCells sortedArrayUsingComparator:^NSComparisonResult(UICollectionViewCell *cellA,
                                                                         UICollectionViewCell *cellB) {
            NSIndexPath *indexPathA = [self.collectionView indexPathForCell:cellA];
            NSIndexPath *indexPathB = [self.collectionView indexPathForCell:cellB];
            if (!indexPathA || !indexPathB) {
                return NSOrderedSame;
            }
            return [indexPathA compare:indexPathB];
        }];

        [sortedCells enumerateObjectsUsingBlock:^(UICollectionViewCell *cell,
                                                  NSUInteger idx,
                                                  __unused BOOL *stop) {
            cell.alpha = 0.0;
            cell.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 14.0),
                                                     CGAffineTransformMakeScale(0.985, 0.985));
            [UIView animateWithDuration:0.34
                                  delay:MIN(0.045 * idx, 0.18)
                 usingSpringWithDamping:0.86
                  initialSpringVelocity:0.48
                                options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                             animations:^{
                cell.alpha = 1.0;
                cell.transform = CGAffineTransformIdentity;
            } completion:nil];
        }];
    });
}

- (void)pp_animateImageSearchEmptyStateIfNeeded
{
    if (UIAccessibilityIsReduceMotionEnabled() || self.emptyStateIconView.hidden) {
        return;
    }

    [self.emptyStateIconView.layer removeAnimationForKey:@"pp.imageSearch.emptyPulse"];
    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulse.fromValue = @(0.96);
    pulse.toValue = @(1.04);
    pulse.duration = 0.42;
    pulse.autoreverses = YES;
    pulse.repeatCount = 1;
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.emptyStateIconView.layer addAnimation:pulse forKey:@"pp.imageSearch.emptyPulse"];
}

- (void)pp_animateImageSearchErrorFeedback
{
    if (UIAccessibilityIsReduceMotionEnabled() || !self.imageSearchButton) {
        return;
    }

    CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    shake.values = @[@0.0, @(-5.0), @4.0, @(-2.0), @0.0];
    shake.duration = 0.28;
    shake.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    [self.imageSearchButton.layer addAnimation:shake forKey:@"pp.imageSearch.errorShake"];
}

- (nullable PPUniversalCellViewModel *)viewModelForImageSearchRef:(NSDictionary *)ref
                                                       lightResult:(nullable NSDictionary *)lightResult
{
    NSDictionary *safeRef = [self pp_dictionaryFromObject:ref] ?: @{};
    NSDictionary *safeLightResult = [self pp_dictionaryFromObject:lightResult] ?: @{};
    NSString *kind = [self pp_normalizedImageSearchKindFromDictionary:safeRef];
    NSString *docID = [self pp_firstStringInDictionary:safeRef
                                                  keys:@[@"docID", @"id", @"documentID", @"objectID", @"itemID", @"itemId"]];

    if (kind.length == 0 || docID.length == 0) return nil;

    NSMutableDictionary *refWithDoc = safeRef.mutableCopy ?: [NSMutableDictionary dictionary];
    refWithDoc[@"kind"] = kind;
    refWithDoc[@"id"] = docID;
    refWithDoc[@"docID"] = docID;

    NSString *title = [self pp_firstStringInDictionary:safeLightResult
                                                  keys:@[@"title", @"name", @"nameEn", @"adTitle", @"details", @"desc", @"description"]];
    if (title.length == 0) {
        title = [self pp_firstStringInDictionary:safeRef
                                            keys:@[@"title", @"name", @"nameEn", @"adTitle", @"details", @"desc", @"description"]];
    }

    NSString *imageURL = [self pp_firstImageSearchImageURLFromDictionary:safeLightResult];
    if (imageURL.length == 0) {
        imageURL = [self pp_firstImageSearchImageURLFromDictionary:safeRef];
    }

    NSNumber *price = [self pp_firstNumberInDictionary:safeLightResult
                                                  keys:@[@"finalPrice", @"price", @"sellPrice"]];
    if (!price) {
        price = [self pp_firstNumberInDictionary:safeRef
                                            keys:@[@"finalPrice", @"price", @"sellPrice"]];
    }

    NSString *currencyCode = [self pp_firstStringInDictionary:safeLightResult
                                                         keys:@[@"currencyCode", @"currency"]];
    if (currencyCode.length == 0) {
        currencyCode = [self pp_firstStringInDictionary:safeRef
                                                   keys:@[@"currencyCode", @"currency"]];
    }

    NSDictionary *mediaMetadata = [self pp_firstImageSearchMediaMetadataFromDictionary:safeLightResult];
    if (!mediaMetadata) {
        mediaMetadata = [self pp_firstImageSearchMediaMetadataFromDictionary:safeRef];
    }
    NSString *mediaType = [[self pp_firstStringInDictionary:mediaMetadata
                                                       keys:@[@"media_type", @"mediaType", @"type", @"mimeType", @"contentType"]] lowercaseString];
    BOOL isVideo = [mediaType isEqualToString:@"video"] || [mediaType hasPrefix:@"video/"];
    NSString *videoThumbnailURL = [self pp_firstStringInDictionary:mediaMetadata
                                                              keys:@[@"thumbnail_url", @"thumbnailURL", @"thumbnailUrl"]];
    NSString *videoURL = [self pp_firstStringInDictionary:mediaMetadata
                                                     keys:@[@"url", @"downloadURL", @"downloadUrl"]];

    if ([kind isEqualToString:@"pet_ad"]) {
        PPUniversalCellViewModel *vm = [[PPUniversalCellViewModel alloc] initWithModel:refWithDoc context:PPCellForAds];
        vm.ModelID = docID;
        vm.title = title;
        vm.modelType = kind;
        vm.price = price;
        vm.finalPrice = price;
        if (currencyCode.length > 0) vm.currencyCode = currencyCode;
        vm.priceText = price ? ([GM formatPrice:price currencyCode:vm.currencyCode] ?: @"") : @"";
        vm.imageURL = imageURL;
        vm.mediaMetadata = mediaMetadata;
        vm.isVideoMedia = isVideo;
        vm.videoURL = isVideo ? videoURL : @"";
        vm.videoThumbnailURL = isVideo ? videoThumbnailURL : @"";
        vm.badgeText = kLang(@"Ads");
        vm.availabilityText = kLang(@"Available");
        vm.preferredAspectRatio = [self pp_imageSearchAspectRatioFromMetadata:mediaMetadata fallback:0.98];
        vm.ModelObject = refWithDoc;
        return vm;
    }

    if ([kind isEqualToString:@"product"] || [kind isEqualToString:@"medicine"]) {
        PPUniversalCellViewModel *vm = [[PPUniversalCellViewModel alloc] initWithModel:refWithDoc context:PPCellForMarket];
        vm.ModelID = docID;
        vm.title = title;
        vm.modelType = kind;
        vm.price = price;
        vm.finalPrice = price;
        if (currencyCode.length > 0) vm.currencyCode = currencyCode;
        vm.priceText = price ? ([GM formatPrice:price currencyCode:vm.currencyCode] ?: @"") : @"";
        vm.imageURL = imageURL;
        vm.mediaMetadata = mediaMetadata;
        vm.isVideoMedia = isVideo;
        vm.videoURL = isVideo ? videoURL : @"";
        vm.videoThumbnailURL = isVideo ? videoThumbnailURL : @"";
        vm.badgeText = kLang(@"Accessories");
        vm.availabilityText = @"";
        vm.preferredAspectRatio = [self pp_imageSearchAspectRatioFromMetadata:mediaMetadata fallback:0.78];
        vm.ModelObject = refWithDoc;
        return vm;
    }

    if ([kind isEqualToString:@"adoption"]) {
        PPUniversalCellViewModel *vm = [[PPUniversalCellViewModel alloc] initWithModel:refWithDoc context:PPCellForAdopt];
        vm.ModelID = docID;
        vm.title = title.length > 0 ? title : kLang(@"AdoptPet");
        vm.modelType = kind;
        vm.priceText = @"";
        vm.imageURL = imageURL;
        vm.mediaMetadata = mediaMetadata;
        vm.isVideoMedia = isVideo;
        vm.videoURL = isVideo ? videoURL : @"";
        vm.videoThumbnailURL = isVideo ? videoThumbnailURL : @"";
        vm.badgeText = kLang(@"For Adoption");
        vm.availabilityText = kLang(@"Available");
        vm.preferredAspectRatio = [self pp_imageSearchAspectRatioFromMetadata:mediaMetadata fallback:0.98];
        vm.ModelObject = refWithDoc;
        return vm;
    }

    return nil;
}

- (void)fetchFullDocumentForKind:(NSString *)kind
                      documentID:(NSString *)docID
                      completion:(void (^)(id fullObject))completion
{
    NSString *collection;
    if ([kind isEqualToString:@"pet_ad"]) {
        collection = @"pet_ads";
    } else if ([kind isEqualToString:@"product"] || [kind isEqualToString:@"medicine"]) {
        collection = @"petAccessories";
    } else if ([kind isEqualToString:@"adoption"]) {
        collection = @"adopt_pets";
    } else {
        if (completion) completion(nil);
        return;
    }

    FIRFirestore *db = [AppManager sharedInstance].dF ?: [FIRFirestore firestore];
    FIRDocumentReference *documentRef =
    [db documentWithPath:[NSString stringWithFormat:@"%@/%@", collection, docID]];
    [documentRef getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
        if (error || !snapshot.exists) {
            if (completion) completion(nil);
            return;
        }
        NSDictionary *data = snapshot.data;
        if (!data) {
            if (completion) completion(nil);
            return;
        }

        id object = nil;
        if ([kind isEqualToString:@"pet_ad"]) {
            object = [PetAd adFromFirestoreData:data documentID:docID];
        } else if ([kind isEqualToString:@"product"] || [kind isEqualToString:@"medicine"]) {
            object = [[PetAccessory alloc] initWithDictionary:data documentID:docID];
        } else if ([kind isEqualToString:@"adoption"]) {
            object = [[AdoptPetModel alloc] initWithSnapshot:snapshot];
        }

        if (completion) completion(object);
    }];
}

- (void)updateEmptyStateForImageSearch:(BOOL)show
{
    self.emptyStateIconView.image = [UIImage systemImageNamed:show ? @"camera.metering.none" : @"sparkle.magnifyingglass"];
}

- (void)showLoading:(BOOL)show
{
    if (show) {
        [self pp_showSkeletonIfNeeded];
    } else {
        [self pp_hideSkeleton];
    }
}

@end
