#import "PPDataViewVC.h"
#import "PPDataViewInput.h"
#import "PPDataViewVM.h"
#import "PPFilterModels.h"

#import "PPUniversalCell.h"
#import "PPCollectionLayoutManager.h"
#import "PPImageLoaderManager.h"
#import "PPFilterSheetVC.h"
#import "PPAdSharingHelper.h"
#import "CartManager.h"
#import "CartViewController.h"
#import "PPModrenSegmrnted.h"
#import "PPNavigationController.h"
#import "PPSearchViewController.h"
#import "PPHUD.h"

#if DEBUG
#define PPDataViewLog(...) NSLog(__VA_ARGS__)
#else
#define PPDataViewLog(...)
#endif

static const CGFloat kPPSectionsTabBarHeight = 64.0;
static const CGFloat kPPAccessoryFilterHeight = 42.0;

static CGFloat PPCurrentSectionsTabBarHeight(void)
{
    return kPPSectionsTabBarHeight;
}


@interface PPDropdownFilterChipButton : UIButton
@property (nonatomic, copy) NSString *chipIconName;
- (void)pp_applyChipTitle:(NSString *)title active:(BOOL)active;
@end

@implementation PPDropdownFilterChipButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.showsMenuAsPrimaryAction = YES;
    self.layer.masksToBounds = NO;

    [self.heightAnchor constraintEqualToConstant:36.0].active = YES;
    return self;
}

- (void)pp_applyChipTitle:(NSString *)title active:(BOOL)active
{
    UIColor *brand = AppPrimaryClr ?: UIColor.systemOrangeColor;
    UIColor *fg = active ? brand : UIColor.secondaryLabelColor;
    UIFont *font = active ? [GM boldFontWithSize:13] : [GM MidFontWithSize:13];
    NSDictionary *textAttrs = @{
        NSFontAttributeName            : font,
        NSForegroundColorAttributeName : fg
    };

    // --- Attributed title: [icon] text ---
    NSMutableAttributedString *attrTitle = [[NSMutableAttributedString alloc] init];

    if (self.chipIconName.length > 0) {
        UIImageSymbolConfiguration *iconCfg =
            [UIImageSymbolConfiguration configurationWithPointSize:11
                                                            weight:UIImageSymbolWeightMedium];
        UIImage *icon = [[UIImage systemImageNamed:self.chipIconName
                                 withConfiguration:iconCfg]
                         imageWithTintColor:fg
                              renderingMode:UIImageRenderingModeAlwaysOriginal];
        if (icon) {
            NSTextAttachment *att = [[NSTextAttachment alloc] init];
            att.image = icon;
            att.bounds = CGRectMake(0, -1.5, 14, 14);
            [attrTitle appendAttributedString:
             [NSAttributedString attributedStringWithAttachment:att]];
            [attrTitle appendAttributedString:
             [[NSAttributedString alloc] initWithString:@" " attributes:textAttrs]];
        }
    }

    [attrTitle appendAttributedString:
     [[NSAttributedString alloc] initWithString:title attributes:textAttrs]];

    // --- Configuration ---
    UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
    cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 14, 6, 11);
    cfg.baseForegroundColor = fg;
    cfg.attributedTitle = attrTitle;

    // Trailing chevron
    UIImageSymbolConfiguration *chevCfg =
        [UIImageSymbolConfiguration configurationWithPointSize:9
                                                        weight:UIImageSymbolWeightSemibold];
    cfg.image = [UIImage systemImageNamed:@"chevron.down" withConfiguration:chevCfg];
    cfg.imagePlacement = NSDirectionalRectEdgeTrailing;
    cfg.imagePadding = 5.0;

    // Surface & border
    cfg.background.backgroundColor = active
        ? [brand colorWithAlphaComponent:0.12]
        : UIColor.tertiarySystemFillColor;
    cfg.background.strokeColor = active
        ? [brand colorWithAlphaComponent:0.24]
        : [UIColor.separatorColor colorWithAlphaComponent:0.30];
    cfg.background.strokeWidth = active ? 1.0 : 0.6;

    self.configuration = cfg;
    self.tintColor = fg;
    self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;

    // Active state: brand-glow shadow
    self.layer.shadowColor  = [brand colorWithAlphaComponent:0.50].CGColor;
    self.layer.shadowOpacity = active ? 0.22 : 0.0;
    self.layer.shadowRadius  = active ? 8.0  : 0.0;
    self.layer.shadowOffset  = active ? CGSizeMake(0, 3) : CGSizeZero;
}

@end

@interface PPDataViewVC () <PPUniversalCellDelegate,UITabBarDelegate,UIGestureRecognizerDelegate,UICollectionViewDataSourcePrefetching>//UITabBarDelegate
 // Input
@property (nonatomic, strong) PPDataViewInput *input;
@property (nonatomic, assign) BOOL didInitialReload;
// ViewModel
@property (nonatomic, strong) PPDataViewVM *viewModel;
@property (nonatomic, assign) PPManagerCellLayoutMode cellLayoutMode;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) PPCollectionLayoutManager *layoutManager;
@property (nonatomic, strong) UIView *filterChipContainer;
@property (nonatomic, strong) UIStackView *filterChipStackView;
@property (nonatomic, strong) NSMutableArray<PPDropdownFilterChipButton *> *filterChips;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, PPFilterState *> *filterStates;
// Scroll restore
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSValue *> *scrollOffsetsBySection;
@property (nonatomic, strong) id imageLoader;

@property (nonatomic, strong) PPModrenSegmrnted *sectionsSegmentedControl;

@property (nonatomic, assign) CGFloat lastContentOffsetY;
@property (nonatomic, assign) BOOL isRestoringScrollOffset;
// Custom navigation bar center view
@property (nonatomic, strong) UIButton *navContainerView;
@property (nonatomic, strong) UIButton *KindsButton;
@property (nonatomic, strong) UIButton *subKindsButton;
@property (nonatomic, strong) UIButton *cartButton;
@property (nonatomic, strong) UILabel *cartBadgeLabel;
@property (nonatomic, strong)  PPEmptyStateConfig *emptyStateConfig;
@property (nonatomic, strong) NSLayoutConstraint *mainKindsWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *sectionsWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *sectionsTabBarHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *filterChipHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *cartButtonWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *subKindsTrailingToCartConstraint;
@property (nonatomic, strong) NSLayoutConstraint *subKindsTrailingToContainerConstraint;
@property (nonatomic, strong) NSLayoutConstraint *cartBadgeMinWidthConstraint;
@property (nonatomic, assign) BOOL isCartButtonVisible;
// Skeleton loading stateAppForgroundColr
@property (nonatomic, assign) BOOL isShowingSkeleton;
@property (nonatomic, strong) UICollectionViewDiffableDataSource<NSNumber *, PPUniversalCellViewModel *> *dataSource;
@property (nonatomic, assign) BOOL didApplyInitialSnapshot;
@property (nonatomic, assign) BOOL didlayout;
@property (nonatomic, assign) BOOL didFixInitialScroll;
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *blurHashCache;
@property (nonatomic, strong) dispatch_queue_t blurHashQueue;
@property (nonatomic, assign) BOOL isPerformingCrossFade;
@property (nonatomic, copy) NSString *lastSubKindsTitle;
@property (nonatomic, assign) CGSize lastSectionsIndicatorSize;
@property (nonatomic, copy) NSArray<PPUniversalCellViewModel *> *presentedItems;
- (void)pp_prefetchImagesAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (void)pp_prefetchTopImagesWithLimit:(NSInteger)limit;
- (void)updateSectionsTabBarSelectionIndicatorIfNeeded;
- (void)saveCurrentSectionScrollOffset;
- (void)restoreScrollOffsetForCurrentSection;
- (CGFloat)preferredTopContentOffsetY;
- (void)pp_handleCartUpdated:(NSNotification *)note;
- (NSInteger)currentCartItemCount;
- (void)updateCartBadge;
- (void)updateCartButtonVisibilityForSection:(PPDataSection)section;
- (void)updateCartButtonVisibilityForSection:(PPDataSection)section animated:(BOOL)animated;
- (void)updateCartButtonVisibility;
- (void)persistSectionSelection:(PPDataSection)section;
- (void)updateSectionsTabBarSelectionForSection:(PPDataSection)section;
- (void)activateSection:(PPDataSection)section userInitiated:(BOOL)userInitiated;
- (BOOL)shouldShowFilterChipBarForSection:(PPDataSection)section;
- (void)syncFilterChipsForCurrentSection;
- (void)updateFilterChipVisibilityForSection:(PPDataSection)section animated:(BOOL)animated;
- (void)refreshPresentedItemsAnimated:(BOOL)animated scrollToTop:(BOOL)scrollToTop;
- (void)refreshFilterChipTitles;
- (void)sectionsSegmentedControlChanged:(PPModrenSegmrnted *)sender;
- (void)onCartTapped;
- (PPFilterState *)pp_currentFilterState;@end
@implementation PPDataViewVC
-(void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    if(!_didlayout && self.viewModel.currentSubKindID == 0)
    {
        _didlayout = YES;
        [self updateNavMainKindTitle];
    }
    
 }
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    UINavigationController *nav = self.navigationController;
    if (!nav) return;

    UIGestureRecognizer *pop = nav.interactivePopGestureRecognizer;

    // 🔥 CRITICAL FIX
    pop.delegate = nil;          // reset UIKit internal state
    pop.enabled = YES;
    pop.delegate = self;         // reattach
    [self updateCartBadge];

    // Recover from any interrupted cross-fade path to avoid "dead" taps.
    self.isPerformingCrossFade = NO;
    if (self.collectionView) {
        self.collectionView.userInteractionEnabled = YES;
        self.collectionView.alpha = 1.0;
    }
}
- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    UIGestureRecognizer *pop = self.navigationController.interactivePopGestureRecognizer;
    if (pop.delegate == self) {
        pop.delegate = nil;
    }
}
-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.view bringSubviewToFront:self.sectionsSegmentedControl];
    [self.view bringSubviewToFront:self.filterChipContainer];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.isPerformingCrossFade = NO;
    if (self.collectionView) {
        self.collectionView.userInteractionEnabled = YES;
        self.collectionView.alpha = 1.0;
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        BOOL changed = [self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection];
        if (changed && self.lastSubKindsTitle.length > 0) {
            [self updateSubKindsButtonTitle:self.lastSubKindsTitle];
            [self refreshFilterChipTitles];
        }
    }
}

- (void)prefetchSubKindIcons
{
    MainKindsModel *mainKind = self.input.mainKind;
    if (!mainKind || mainKind.SubKindsArray.count == 0) return;

    NSMutableArray<NSURL *> *urls = [NSMutableArray array];

    for (SubKindModel *subKind in mainKind.SubKindsArray) {
        if (subKind.subKindIconUrl.length) {
            NSURL *url = [NSURL URLWithString:subKind.subKindIconUrl];
            if (url) [urls addObject:url];
        }
    }

    if (urls.count == 0) return;
  

    [[SDWebImagePrefetcher sharedImagePrefetcher]
     prefetchURLs:urls
     progress:nil
     completed:^(NSUInteger finishedCount, NSUInteger skippedCount) {
        PPDataViewLog(@"[SubKind Prefetch] done=%lu skipped=%lu",
                      (unsigned long)finishedCount,
                      (unsigned long)skippedCount);
    }];
}


 
#pragma mark - Init

- (instancetype)initWithInput:(PPDataViewInput *)input
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) return nil;

    _input = input;
    return self;
}

 #pragma mark - Skeleton Loading

- (void)showSkeleton
{
    if (self.isShowingSkeleton) return;
    self.isShowingSkeleton = YES;

    NSMutableArray *items = [NSMutableArray array];
    NSInteger count = 8;

    for (NSInteger i = 0; i < count; i++) {
        PPUniversalCellViewModel *vm =
        [[PPUniversalCellViewModel alloc] initSkeleton];
        [items addObject:vm];
    }

    self.layoutManager.items = items;
    self.presentedItems = items;

    [self.layoutManager applyLayoutMode:self.layoutManager.currentLayoutMode
                       toCollectionView:self.collectionView
                               animated:NO];

    [self performCrossFadeReload];
}

- (void)hideSkeleton
{
    if (!self.isShowingSkeleton) return;
    self.isShowingSkeleton = NO;
}

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.didFixInitialScroll = NO;
    _didlayout = NO;
    self.blurHashCache = [NSCache new];
    self.blurHashCache.countLimit = 200;
    self.blurHashQueue =
    dispatch_queue_create("com.purepets.blurhash.decode", DISPATCH_QUEUE_CONCURRENT);
    self.isPerformingCrossFade = NO;
    self.presentedItems = @[];
    self.view.backgroundColor = PPBackgroundColorForIOS26(NewBgColor);
    [self emptyStateInit];
    [self setupSectionsTabBar];
    // 🔥 FIX: normalize AllKinds EARLY
    [self normalizeInitialMainKind];
    
    [self setupNavigation];
    [self setupViewModel];
   
    [self setupCollectionView];
    [self showSkeleton];
    [self updateEmptyState];
    
    [self bindViewModel];
    [self handleInitialRoute];
    
    [self prefetchSubKindIcons];
    
    self.title=nil;
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(pp_handleAdDidUpload:)
     name:PPAdDidFinishUploadNotification
     object:nil];
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(pp_handleCartUpdated:)
     name:kCartUpdatedNotification
     object:nil];
    
     
}

- (void)dealloc
{
    [[PPImageLoaderManager shared] cancelAllPrefetching];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:PPAdDidFinishUploadNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kCartUpdatedNotification
                                                  object:nil];
    UIGestureRecognizer *pop = self.navigationController.interactivePopGestureRecognizer;
    if (pop.delegate == self) {
        pop.delegate = nil;
    }
}


- (void)pp_handleAdDidUpload:(NSNotification *)note
{
    PetAd *ad = note.userInfo[@"ad"];
    BOOL isEditing = [note.userInfo[@"isEditing"] boolValue];

    PPDataViewLog(@"🔔 [PPDataViewVC] Ad %@ %@ notification received",
          ad.adID,
          isEditing ? @"UPDATED" : @"CREATED");

    // ✅ Only react if we are currently on Ads section
    if (self.viewModel.currentSection != PPDataSectionAds) {
        PPDataViewLog(@"ℹ️ [PPDataViewVC] Ignored (current section is not Ads)");
        return;
    }

    PPDataViewLog(@"🔄 [PPDataViewVC] Reloading Ads section");

    // Optional: show skeleton only if list is empty
    if (self.layoutManager.items.count == 0) {
        [self showSkeleton];
    }

    // 🔥 Reload Ads data from ViewModel
    [self.viewModel reloadDataWithCompletion:^(NSError * _Nullable error) {
        
        PPDataViewLog(@"✅ [PPDataViewVC] Ads reload finished");

        // Scroll to top ONLY if new ad was created
        if (!isEditing) {
            [self scrollCollectionViewToTopAfterReload:YES];
        }
    }];
}


- (void)normalizeInitialMainKind
{
    if (self.input.sourceTarget == PPDeepLinkTargetAllCategories) {
        if (!self.input.mainKind && self.input.mainKindsArr.count > 0) {
            self.input.mainKind = self.input.mainKindsArr.firstObject;
        }
    }
}

- (void)emptyStateInit
{
    self.emptyStateConfig = [PPEmptyStateConfig new];
    self.emptyStateConfig.animationName = @"404.json";
    self.emptyStateConfig.title      = kLang(@"empty_no_results_title");
    self.emptyStateConfig.subTitle  = kLang(@"empty_no_results_subtitle");
    self.emptyStateConfig.buttonTitle  = kLang(@"empty_retry_button");
    self.emptyStateConfig.target       = self;
    self.emptyStateConfig.action       = @selector(retryReloadData);
    self.emptyStateConfig.isNetworkFile = YES;
    self.didInitialReload = NO;
    self.scrollOffsetsBySection = [NSMutableDictionary dictionary];
}

#pragma mark - Routing
- (void)handleInitialRoute
{
    PPDataViewLog(@"\n================ handleInitialRoute =================");
    PPDataViewLog(@"[VC] sourceTarget = %ld", (long)self.input.sourceTarget);

    NSString *key =
    [self sectionKeyForMainKind:
     (self.input.sourceTarget == PPDeepLinkTargetAllCategories)
     ? nil
     : self.input.mainKind];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    PPDataSection section;

    if ([defaults objectForKey:key] != nil) {
        section = (PPDataSection)[defaults integerForKey:key];
        PPDataViewLog(@"[Route] Restored section %ld for key %@", (long)section, key);
    } else {
        section = PPDataSectionAds;
        PPDataViewLog(@"[Route] No saved section, defaulting to Ads for key %@", key);
    }

    if (section < PPDataSectionAds || section > PPDataSectionServices) {
        section = PPDataSectionAds;
    }
    
    PPDataViewLog(@"[ROUTE] Initial switchToSection = %ld",
          (long)section);
    
    
    
    PPDataViewLog(@"[VC] resolved section = %ld", (long)section);
    //bar  PPDataViewLog(@"[VC] section control ready");

    [self updateSectionsTabBarSelectionForSection:section];
    
    PPDataViewLog(@"[VC] calling switchToSection:%ld", (long)section);
    [self activateSection:section userInitiated:NO];
    
    // 🔑 Restore subkind state BEFORE menus are built
    NSString *subKey = [self subKindKeyForMainKind:self.input.mainKind];
    NSInteger savedSubKindID =
    [[NSUserDefaults standardUserDefaults] integerForKey:subKey];

    self.viewModel.currentSubKindID = savedSubKindID;
    
    if(self.viewModel.currentSubKindID > 0 && self.input.mainKind)
    {
        SubKindModel *subKind = [self.input.mainKind subKindForID:self.viewModel.currentSubKindID];
        if (subKind) {
            [self.viewModel reloadForSubKind:subKind];
            [self updateSubKindsButtonTitle:subKind.SubKindName subKind:subKind];
        }
    }

    [self.scrollOffsetsBySection removeAllObjects];
    PPDataViewLog(@"[VC] scrollOffsetsBySection cleared");
    
   
}

#pragma mark - Setup
- (void)setupViewModel
{
    self.viewModel =
    [[PPDataViewVM alloc]initWithMainKind:self.input.mainKind sourceTarget:self.input.sourceTarget];
}

-(void)retryReloadData
{
    [self showSkeleton];
    __weak typeof(self) weakSelf = self;
    [self.viewModel reloadDataWithCompletion:^(NSError * _Nullable error) {
        if (!error) { return; }
        [weakSelf hideSkeleton];
        [weakSelf updateEmptyState];
    }];
}
 
 - (void)updateEmptyState {
    if (self.isShowingSkeleton) return;
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateEmptyState];
        });
        return;
    }
    [PPEmptyStateHelper updateEmptyStateForListView:self.collectionView
                                          dataCount:self.presentedItems.count
                                             config:self.emptyStateConfig];
 }

- (void)setupCollectionView
{
    self.layoutManager = [PPCollectionLayoutManager new];

    
    PPManagerCellLayoutMode savedMode =
    (PPManagerCellLayoutMode)[[NSUserDefaults standardUserDefaults]
                              integerForKey:kPPLayoutModeKey];

    if (savedMode >= PPCellLayoutModeSquare &&
        savedMode <= PPCellLayoutModePinterest) {
        self.layoutManager.currentLayoutMode = savedMode;
    } else {
        self.layoutManager.currentLayoutMode = PPCellLayoutModePinterest;
    }
    
    UICollectionViewLayout *layout = [self.layoutManager layoutForMode:self.layoutManager.currentLayoutMode];

    self.collectionView =
    [[UICollectionView alloc] initWithFrame:CGRectZero
                       collectionViewLayout:layout];

    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.delegate = self;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.alwaysBounceVertical = YES;
    self.collectionView.prefetchingEnabled = YES;
    self.collectionView.prefetchDataSource = self;
    self.collectionView.decelerationRate = UIScrollViewDecelerationRateNormal;
    if (@available(iOS 13.0, *)) {
       // self.collectionView.automaticallyAdjustsScrollIndicatorInsets = NO;
    }
    [self.collectionView registerClass:[PPUniversalCell class] forCellWithReuseIdentifier:@"PPUniversalCell"];
    [self configureDataSource];
    [self.view insertSubview:self.collectionView atIndex:0];

    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    
}

 
- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self updateCollectionContentInset];
    [self updateSectionsTabBarSelectionIndicatorIfNeeded];
}

- (void)viewSafeAreaInsetsDidChange
{
    [super viewSafeAreaInsetsDidChange];
    [self updateCollectionContentInset];
}


/// Smoothly scrolls collection view to top (safe and async)
- (void)scrollCollectionViewToTopAfterReload:(BOOL)animated
{
    UICollectionView *cv = self.collectionView;
    if (!cv) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        // Force layout pass (CRITICAL for Pinterest)
        [cv layoutIfNeeded];

        if (cv.contentSize.height <= cv.bounds.size.height) {
            return; // nothing to scroll
        }

        CGPoint topOffset = CGPointMake(0, [self preferredTopContentOffsetY]);
        [cv setContentOffset:topOffset animated:animated];
    });
}

- (void)persistCurrentSection
{
    PPDataSection section = self.viewModel.currentSection;
    [self persistSectionSelection:section];
}

- (void)persistSectionSelection:(PPDataSection)section
{
    NSString *key = [self sectionKeyForMainKind:self.input.mainKind];
    [[NSUserDefaults standardUserDefaults] setInteger:section forKey:key];
    PPDataViewLog(@"[Persist] Saved section %ld for key %@", (long)section, key);
}

- (void)refreshsubKindsMenu
{
    if (!self.subKindsButton || !self.input.mainKind) {
        return;
    }
    self.subKindsButton.menu = [self subKindsMenu];
}


 - (void)bindViewModel
{
    __weak typeof(self) weakSelf = self;

    self.viewModel.onReloadData = ^{
        [weakSelf hideSkeleton];
        PPDataViewLog(@"\n================ onReloadData =================");
        PPDataViewLog(@"[VC] currentSection = %ld", (long)weakSelf.viewModel.currentSection);
        PPDataViewLog(@"[VC] items.count = %ld", (long)weakSelf.viewModel.items.count);

        [weakSelf refreshPresentedItemsAnimated:weakSelf.didApplyInitialSnapshot
                                     scrollToTop:NO];
        weakSelf.didApplyInitialSnapshot = YES;
        [weakSelf updateSectionsTabBarSelectionForSection:weakSelf.viewModel.currentSection];
        [weakSelf updateFilterChipVisibilityForSection:weakSelf.viewModel.currentSection animated:NO];
        [weakSelf syncFilterChipsForCurrentSection];
        // ✅ THIS IS THE FIX
          [weakSelf persistCurrentSection];
        
        [weakSelf updateEmptyState];
        
        // 3️⃣ Force nav container relayout
        //[weakSelf updateNavSectionTitle];
        
        
        [weakSelf updateCollectionContentInset];

        if (!weakSelf.didFixInitialScroll) {
            weakSelf.didFixInitialScroll = YES;

            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf updateCollectionContentInset];
                [weakSelf.collectionView layoutIfNeeded];
                CGPoint topOffset =
                CGPointMake(0, [weakSelf preferredTopContentOffsetY]);
                [weakSelf.collectionView setContentOffset:topOffset animated:NO];
            });
        } else {
            [weakSelf restoreScrollOffsetForCurrentSection];
        }
        [weakSelf updateCartButtonVisibility];
        [weakSelf pp_prefetchTopImagesWithLimit:16];
        
        if(weakSelf.viewModel.currentSubKindID > 0)
        {
            [weakSelf refreshsubKindsMenu];
            SubKindModel *subKind = [weakSelf.input.mainKind subKindForID:weakSelf.viewModel.currentSubKindID];
            [weakSelf updateSubKindsButtonTitle:subKind.SubKindName subKind:subKind];
        }
    };
    self.viewModel.onAppendData = ^(NSArray<NSIndexPath *> *indexPaths) {
        PPDataViewLog(@"\n================ onAppendData =================");
        PPDataViewLog(@"[VC] indexPaths.count = %ld", (long)indexPaths.count);
        PPDataViewLog(@"[VC] items.count BEFORE = %ld", (long)weakSelf.viewModel.items.count);
        PPDataViewLog(@"[VC] didInitialReload = %@", weakSelf.didInitialReload ? @"YES" : @"NO");

        [weakSelf refreshPresentedItemsAnimated:YES scrollToTop:NO];
        [weakSelf updateEmptyState];
        [weakSelf syncFilterChipsForCurrentSection];
        //[weakSelf updateNavSectionTitle];
        
        [weakSelf refreshsubKindsMenu];
        [weakSelf updateCollectionContentInset];
        [weakSelf updateCartButtonVisibility];
        [weakSelf pp_prefetchImagesAtIndexPaths:indexPaths];
    };

    self.viewModel.onError = ^(NSError * _Nonnull error) {
        PPDataViewLog(@"[PPDataViewVC] data error: %@", error.localizedDescription ?: @"unknown");
        [weakSelf hideSkeleton];
        [weakSelf updateEmptyState];
    };
}


#pragma mark - Collection Content Inset Fix

// Ensures collectionView has proper bottom inset for tab bar & safe area, and always bounces vertically.
- (void)updateCollectionContentInset
{
    if (!self.collectionView) { return; }

    CGFloat targetTopInset =
    [self shouldShowFilterChipBarForSection:self.viewModel.currentSection]
    ? (PPCurrentSectionsTabBarHeight() + kPPAccessoryFilterHeight + 18.0)
    : (PPCurrentSectionsTabBarHeight() + 12.0);
    CGRect sectionsFrame = self.sectionsSegmentedControl.frame;
    CGRect safeAreaFrame = self.view.safeAreaLayoutGuide.layoutFrame;

    if (!CGRectIsEmpty(sectionsFrame) && !CGRectIsEmpty(safeAreaFrame)) {
        CGFloat maxVisibleY = CGRectGetMaxY(sectionsFrame);

        // If filter segmented is visible, push content below it
        if (self.filterChipContainer &&
            !self.filterChipContainer.hidden &&
            self.filterChipContainer.alpha > 0.01) {

            CGRect filterFrame = self.filterChipContainer.frame;

            if (!CGRectIsEmpty(filterFrame)) {
                maxVisibleY = CGRectGetMaxY(filterFrame);
            }
        }

        targetTopInset =
        MAX(0.0, maxVisibleY - CGRectGetMinY(safeAreaFrame) + 8.0);
    }

    CGFloat bottomInset = 0;

    // Account for tab bar
    if (self.tabBarController) {
        bottomInset += self.tabBarController.tabBar.bounds.size.height;
    }

    // Account for safe area
    bottomInset += self.view.safeAreaInsets.bottom;

    CGFloat targetBottomInset = bottomInset + 16.0;
    UIEdgeInsets currentInset = self.collectionView.contentInset;
    CGFloat topDelta = currentInset.top - targetTopInset;
    if (topDelta < 0) { topDelta = -topDelta; }
    CGFloat bottomDelta = currentInset.bottom - targetBottomInset;
    if (bottomDelta < 0) { bottomDelta = -bottomDelta; }
    if (topDelta < 0.5 && bottomDelta < 0.5) {
        return;
    }
 
    UIEdgeInsets inset = currentInset;
    inset.top = targetTopInset;
    inset.bottom = targetBottomInset; // breathing space

    self.collectionView.contentInset = inset;
    self.collectionView.scrollIndicatorInsets = inset;
}

- (void)saveCurrentSectionScrollOffset
{
    if (!self.collectionView) { return; }
    CGPoint currentOffset = self.collectionView.contentOffset;
    CGFloat preferredTopY = [self preferredTopContentOffsetY];
    if (currentOffset.y < preferredTopY) {
        currentOffset.y = preferredTopY;
    }
    self.scrollOffsetsBySection[@(self.viewModel.currentSection)] =
    [NSValue valueWithCGPoint:currentOffset];
}

- (void)restoreScrollOffsetForCurrentSection
{
    if (!self.collectionView) { return; }

    NSValue *savedOffset =
    self.scrollOffsetsBySection[@(self.viewModel.currentSection)];
    CGPoint targetOffset = CGPointMake(0, [self preferredTopContentOffsetY]);
    if (savedOffset) {
        targetOffset = savedOffset.CGPointValue;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.collectionView layoutIfNeeded];

        CGFloat minY = -self.collectionView.adjustedContentInset.top;
        CGFloat maxY = self.collectionView.contentSize.height -
        self.collectionView.bounds.size.height +
        self.collectionView.adjustedContentInset.bottom;
        if (maxY < minY) {
            maxY = minY;
        }

        CGFloat preferredTopY = [self preferredTopContentOffsetY];
        CGFloat clampedY = targetOffset.y;
        if (clampedY < preferredTopY) { clampedY = preferredTopY; }
        if (clampedY < minY) { clampedY = minY; }
        if (clampedY > maxY) { clampedY = maxY; }
        CGPoint clampedOffset = CGPointMake(0, clampedY);
        self.isRestoringScrollOffset = YES;
        [self.collectionView setContentOffset:clampedOffset animated:NO];
        self.isRestoringScrollOffset = NO;
        self.scrollOffsetsBySection[@(self.viewModel.currentSection)] =
        [NSValue valueWithCGPoint:clampedOffset];
        self.lastContentOffsetY = clampedY;
    });
}

- (CGFloat)preferredTopContentOffsetY
{
    if (!self.collectionView) {
        return 0.0;
    }
    return -self.collectionView.adjustedContentInset.top;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView != self.collectionView) { return; }
    if (self.isRestoringScrollOffset) { return; }
    if (self.layoutManager.items.count == 0) { return; }
    if (!scrollView.isTracking && !scrollView.isDragging && !scrollView.isDecelerating) { return; }
    CGFloat y = scrollView.contentOffset.y;
    if (ABS(y - self.lastContentOffsetY) < 6.0) { return; }
    self.lastContentOffsetY = y;
    [self saveCurrentSectionScrollOffset];
}

- (void)pp_handleCartUpdated:(NSNotification *)note
{
    (void)note;
    [self updateCartBadge];
}

- (NSInteger)currentCartItemCount
{
    return [CartManager.sharedManager totalItemsCount];
}

- (void)updateCartBadge
{
    if (!self.cartBadgeLabel) {
        return;
    }

    NSInteger count = [self currentCartItemCount];
    BOOL shouldShowBadge = count > 0;

    NSString *text = (count > 99) ? @"99+" : [NSString stringWithFormat:@"%ld", (long)MAX(count, 0)];
    self.cartBadgeLabel.text = text;

    CGFloat textWidth = ceil([text sizeWithAttributes:@{NSFontAttributeName : self.cartBadgeLabel.font}].width) + 8.0;
    self.cartBadgeMinWidthConstraint.constant = MAX(16.0, textWidth);
    self.cartBadgeLabel.hidden = !shouldShowBadge;
    self.cartBadgeLabel.alpha = shouldShowBadge ? 1.0 : 0.0;
}

#pragma mark - Actions

- (void)onBack
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)onCartTapped
{
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    CartViewController *vc = [[CartViewController alloc] init];
    PPNavigationController *nav =
    [[PPNavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [PPHomeHelper presentViewControllerSafely:nav
                                         from:self
                                     animated:YES
                                   completion:nil];
}

- (void)updateCartButtonVisibility
{
    [self updateCartButtonVisibilityForSection:self.viewModel.currentSection animated:NO];
}

- (void)updateCartButtonVisibilityForSection:(PPDataSection)section
{
    [self updateCartButtonVisibilityForSection:section animated:NO];
}

- (void)updateCartButtonVisibilityForSection:(PPDataSection)section animated:(BOOL)animated
{
    if (!self.cartButton || !self.cartButtonWidthConstraint) {
        return;
    }

    BOOL shouldShow = YES;//(section == PPDataSectionAccessories);
    self.isCartButtonVisible = shouldShow;
    self.cartButton.userInteractionEnabled = shouldShow;

    if (self.subKindsTrailingToCartConstraint && self.subKindsTrailingToContainerConstraint) {
        self.subKindsTrailingToCartConstraint.active = shouldShow;
        self.subKindsTrailingToContainerConstraint.active = !shouldShow;
    }

    void (^layoutChanges)(void) = ^{
        self.cartButtonWidthConstraint.constant = shouldShow ? 36.0 : 0.0;
        self.cartButton.alpha = shouldShow ? 1.0 : 0.0;
        self.cartButton.transform = shouldShow ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.9, 0.9);
        [self reloadNavigationCenterViewLayout];
        [self.navContainerView layoutIfNeeded];
        [self.navigationController.navigationBar layoutIfNeeded];
    };

    if (shouldShow) {
        self.cartButton.hidden = NO;
    }

    BOOL shouldAnimate = animated && self.view.window != nil;
    if (shouldShow) {
        self.cartButton.transform = shouldAnimate ? CGAffineTransformMakeScale(0.9, 0.9) : CGAffineTransformIdentity;
    } else {
        self.cartButton.transform = CGAffineTransformIdentity;
    }
    if (shouldAnimate) {
        [UIView animateWithDuration:0.26
                              delay:0
             usingSpringWithDamping:0.9
              initialSpringVelocity:0.4
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:layoutChanges
                         completion:^(__unused BOOL finished) {
            if (!shouldShow) {
                self.cartButton.hidden = YES;
            }
            self.cartButton.transform = CGAffineTransformIdentity;
            [self updateCartBadge];
        }];
    } else {
        layoutChanges();
        if (!shouldShow) {
            self.cartButton.hidden = YES;
            self.cartButton.transform = CGAffineTransformIdentity;
        }
        [self updateCartBadge];
    }
}

- (void)openFilters
{
    if (self.presentedViewController) {
        return;
    }

    PPFilterSheetVC *vc = [PPFilterSheetVC new];
     vc.currentSection = self.viewModel.currentSection;
    vc.filterState = [[self pp_currentFilterState] copy];
    __weak typeof(self) weakSelf = self;
    vc.resultCountProvider = ^NSInteger(PPFilterState *state) {
        PPDataViewVC *strongSelf = weakSelf;
        if (!strongSelf) {
            return 0;
        }
        return [strongSelf.viewModel previewResultCountForFilterState:state];
    };
    vc.onApply = ^(PPFilterState *applied) {

        PPDataViewVC *strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.filterStates[@(strongSelf.viewModel.currentSection)] = applied;
        [strongSelf.viewModel applyFilterState:applied];
        [strongSelf syncFilterChipsForCurrentSection];
        [strongSelf refreshFilterChipTitles];
        [strongSelf refreshPresentedItemsAnimated:YES scrollToTop:YES];

    };
    [PPFunc presentSheetFrom:self sheetVC:vc detentStyle:PPSheetDetentStyle80 ];

}
 

#pragma mark - Diffable Data Source

- (void)configureDataSource
{
    __weak typeof(self) weakSelf = self;

    self.dataSource =
    [[UICollectionViewDiffableDataSource alloc]
     initWithCollectionView:self.collectionView
     cellProvider:^UICollectionViewCell *
     (UICollectionView *collectionView,
      NSIndexPath *indexPath,
      PPUniversalCellViewModel *vm) {

        PPUniversalCell *cell =
        [collectionView dequeueReusableCellWithReuseIdentifier:@"PPUniversalCell"
                                                  forIndexPath:indexPath];

        if (!vm) {
            cell.hidden = YES;
            return cell;
        }

        cell.hidden = NO;
        vm.indexPath = indexPath;

        [cell applyViewModel:vm
                     context:vm.modelContext
                  layoutMode:weakSelf.layoutManager.currentLayoutMode
                discountMode:PPDiscountStyleBadge
                 imageLoader:^(UIImageView *iv,
                               NSString *url,
                               UIImage *placeholder,
                               UIView *card) {
            
            
            UIImage *fallback =
            vm.placeholder ?: [UIImage imageNamed:@"placeholder"];

            iv.contentMode = UIViewContentModeScaleAspectFill;
            iv.clipsToBounds = YES;

            // 1️⃣ Set placeholder immediately
            iv.image = fallback;

            // Capture identity
            NSString *currentHash = vm.blurHash;
            __weak UIImageView *weakIV = iv;

            // 2️⃣ Async blurhash (SAFE)
            if (currentHash.length > 0) {
                PPDataViewVC *strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                [strongSelf asyncBlurHashImageForHash:currentHash
                                           size:CGSizeMake(40, 40)
                                      completion:^(UIImage * _Nullable blurImg) {

                    if (!blurImg) return;
                    if (!weakIV) return;

                    // Cell reuse protection
                    if (![currentHash isEqualToString:vm.blurHash]) {
                        return;
                    }

                    // 🔒 DO NOT override real image
                    [UIView performWithoutAnimation:^{
                        if (weakIV.image == fallback) {
                            weakIV.image = blurImg;
                        }
                    }];
                }];
            }

            // 3️⃣ Load real image (FINAL AUTHORITY)
            [[PPImageLoaderManager shared]
             setImageOnImageView:iv
                             url:url
                      placeholder:fallback
                    transitionStyle:PPImageTransitionStyleNone
                       complation:nil];
        }];

        cell.delegate = weakSelf;
        return cell;
    }];
}

#pragma mark - Collection Prefetch

- (NSArray<NSString *> *)pp_imageURLsFromIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    if (indexPaths.count == 0 || self.presentedItems.count == 0) {
        return @[];
    }

    NSArray<PPUniversalCellViewModel *> *items = self.presentedItems;
    NSMutableOrderedSet<NSString *> *urls = [NSMutableOrderedSet orderedSet];

    for (NSIndexPath *indexPath in indexPaths) {
        NSInteger itemIndex = indexPath.item;
        if (itemIndex < 0 || itemIndex >= (NSInteger)items.count) {
            continue;
        }

        PPUniversalCellViewModel *vm = items[itemIndex];
        if (vm.imageURL.length > 0) {
            [urls addObject:vm.imageURL];
        }
    }

    return urls.array;
}

- (void)pp_prefetchImagesAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    NSArray<NSString *> *urls = [self pp_imageURLsFromIndexPaths:indexPaths];
    if (urls.count == 0) {
        return;
    }
    [[PPImageLoaderManager shared] prefetchURLs:urls];
}

- (void)pp_prefetchTopImagesWithLimit:(NSInteger)limit
{
    if (limit <= 0 || self.presentedItems.count == 0) {
        return;
    }

    NSInteger upperBound = MIN((NSInteger)self.presentedItems.count, limit);
    NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray arrayWithCapacity:(NSUInteger)upperBound];
    for (NSInteger i = 0; i < upperBound; i++) {
        [indexPaths addObject:[NSIndexPath indexPathForItem:i inSection:0]];
    }
    [self pp_prefetchImagesAtIndexPaths:indexPaths];
}

- (void)collectionView:(UICollectionView *)collectionView
prefetchItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    (void)collectionView;
    [self pp_prefetchImagesAtIndexPaths:indexPaths];
}

- (void)collectionView:(UICollectionView *)collectionView
cancelPrefetchingForItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    (void)collectionView;
    if (indexPaths.count == 0) {
        return;
    }
    [[PPImageLoaderManager shared] cancelAllPrefetching];
}

- (void)applySnapshotAnimated:(BOOL)animated
{
    if (!self.viewModel || !self.dataSource) return;
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self applySnapshotAnimated:animated];
        });
        return;
    }

    NSDiffableDataSourceSnapshot<NSNumber *, PPUniversalCellViewModel *> *snapshot =
    [NSDiffableDataSourceSnapshot new];

    NSNumber *section = @(self.viewModel.currentSection);
    [snapshot appendSectionsWithIdentifiers:@[section]];
    [snapshot appendItemsWithIdentifiers:self.presentedItems
               intoSectionWithIdentifier:section];

    BOOL shouldAnimate = animated && self.view.window != nil;
    if (self.presentedItems.count > 120) {
        shouldAnimate = NO;
    }

    if (!shouldAnimate && [self.dataSource respondsToSelector:@selector(applySnapshotUsingReloadData:)]) {
        [self.dataSource applySnapshotUsingReloadData:snapshot];
    } else {
        [self.dataSource applySnapshot:snapshot
                    animatingDifferences:shouldAnimate];
    }
}

- (double)resolvedPriceForViewModel:(PPUniversalCellViewModel *)vm
{
    NSNumber *price = vm.finalPrice ?: vm.price;
    return MAX(0.0, price.doubleValue);
}

- (NSArray<PPUniversalCellViewModel *> *)filteredPresentedItemsFromSourceItems:(NSArray<PPUniversalCellViewModel *> *)sourceItems
{
    // The VM now applies all data-model-level filters (condition, gender, service type,
    // hasOffer, price, sort).  The VC simply passes items through — this method is kept
    // as an integration point for any future presentation-only transforms.
    return sourceItems ?: @[];
}

- (void)refreshPresentedItemsAnimated:(BOOL)animated scrollToTop:(BOOL)scrollToTop
{
    // Keep the server-backed view model intact while the screen applies lightweight
    // presentation-only price filtering and sorting for the accessories experience.
    NSArray<PPUniversalCellViewModel *> *sourceItems = self.viewModel.items ?: @[];
    self.presentedItems = [self filteredPresentedItemsFromSourceItems:sourceItems];
    self.layoutManager.items = self.presentedItems;
    [self applySnapshotAnimated:animated];
    [self refreshFilterChipTitles];

    if (scrollToTop) {
        [self scrollCollectionViewToTopAfterReload:YES];
    }
}

- (void)refreshFilterChipTitles
{
    UISemanticContentAttribute semantic = Language.semanticAttributeForCurrentLanguage;
    self.filterChipContainer.semanticContentAttribute = semantic;
    self.filterChipStackView.semanticContentAttribute = semantic;

    PPFilterState *state = [self pp_currentFilterState];
    NSArray<PPFilterGroup *> *groups = state.groups;

    for (NSInteger i = 0; i < (NSInteger)self.filterChips.count && i < (NSInteger)groups.count; i++) {
        PPDropdownFilterChipButton *chip = self.filterChips[i];
        PPFilterGroup *group = groups[i];
        NSString *title = group.isActive ? group.selectedTitle : group.title;
        [chip pp_applyChipTitle:title active:group.isActive];
        chip.menu = [self pp_menuForFilterGroup:group chipIndex:i];
        chip.accessibilityValue = group.selectedTitle;
    }
}





- (NSString *)titleForSection:(PPDataSection)section
{
    switch (section) {
        case PPDataSectionAds:         return kLang(@"Ads");
        case PPDataSectionAccessories: return kLang(@"Accessories");
        case PPDataSectionFood:        return kLang(@"Food");
        case PPDataSectionServices:    return kLang(@"services");
        default:                       return @"";
    }
}







                                          


                                      


                                     













- (NSString *)iconForSection:(PPDataSection)section
{
    switch (section) {
        case PPDataSectionAds:         return @"megaphone";
        case PPDataSectionAccessories: return @"bag";
        case PPDataSectionFood:        return @"cart";
        case PPDataSectionServices:    return @"cross.case";
        default:                       return @"";
    }
}

- (NSString *)selectedIconForSection:(PPDataSection)section
{
    switch (section) {
        case PPDataSectionAds:         return @"megaphone.fill";
        case PPDataSectionAccessories: return @"bag.fill";
        case PPDataSectionFood:        return @"cart.fill";
        case PPDataSectionServices:    return @"cross.case.fill";
        default:                       return [self iconForSection:section];
    }
}

- (UITabBarItem *)tabBarItemForSection:(PPDataSection)section
{
    NSString *title = [self titleForSection:section];
    NSString *iconName = [self iconForSection:section];

    UIImage *icon =
    [UIImage pp_symbolNamed:iconName
                  pointSize:18
                     weight:UIImageSymbolWeightSemibold
                      scale:UIImageSymbolScaleMedium
                    palette:@[AppPrimaryClr]
               makeTemplate:YES];

    UIImage *selectedIcon =
    [UIImage pp_symbolNamed:[self selectedIconForSection:section]
                  pointSize:19
                     weight:UIImageSymbolWeightBold
                      scale:UIImageSymbolScaleMedium
                    palette:@[AppPrimaryClr]
               makeTemplate:YES];

    UITabBarItem *item =
    [[UITabBarItem alloc] initWithTitle:title
                                  image:icon
                          selectedImage:selectedIcon];
    item.tag = section;
    return item;
}

- (UIImage *)sectionsSelectionIndicatorImage
{
    CGSize size = self.lastSectionsIndicatorSize;
    if (CGSizeEqualToSize(size, CGSizeZero)) {
        size = CGSizeMake(72.0, PPCurrentSectionsTabBarHeight());
    }
    CGFloat radius = 18.0;
    UIGraphicsImageRenderer *renderer =
    [[UIGraphicsImageRenderer alloc] initWithSize:size];

    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        CGRect rect = CGRectInset((CGRect){CGPointZero, size}, 2.0, 2.0);
        UIBezierPath *path =
        [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:radius];
        [[AppPrimaryClr colorWithAlphaComponent:0.12] setFill];
        [path fill];
        [[UIColor colorWithWhite:1.0 alpha:0.22] setStroke];
        path.lineWidth = 1.0;
        [path stroke];
    }];

    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(radius + 2.0,
                                                               radius + 2.0,
                                                               radius + 2.0,
                                                               radius + 2.0)
                                 resizingMode:UIImageResizingModeStretch];
}

- (void)updateSectionsTabBarSelectionIndicatorIfNeeded
{
    return;
}

- (void)configureSectionTabBarAppearance:(UITabBarAppearance *)appearance
{
    if (!appearance) {
        return;
    }

    [appearance configureWithTransparentBackground];
    appearance.backgroundEffect = nil;
    appearance.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.30];
    appearance.shadowColor = UIColor.clearColor;

    NSDictionary *normalAttributes = @{
        NSFontAttributeName : [GM MidFontWithSize:14],
        NSForegroundColorAttributeName : UIColor.secondaryLabelColor
    };
    NSDictionary *selectedAttributes = @{
        NSFontAttributeName : [GM boldFontWithSize:14],
        NSForegroundColorAttributeName : AppPrimaryClr
    };

    NSArray<UITabBarItemAppearance *> *appearances = @[
        appearance.stackedLayoutAppearance,
        appearance.inlineLayoutAppearance,
        appearance.compactInlineLayoutAppearance
    ];

    for (UITabBarItemAppearance *itemAppearance in appearances) {
        itemAppearance.normal.iconColor = UIColor.secondaryLabelColor;
        itemAppearance.selected.iconColor = AppPrimaryClr;
        itemAppearance.normal.titleTextAttributes = normalAttributes;
        itemAppearance.selected.titleTextAttributes = selectedAttributes;
        itemAppearance.normal.titlePositionAdjustment = UIOffsetMake(0, 0.0);
        itemAppearance.selected.titlePositionAdjustment = UIOffsetMake(0, 0.0);
    }
}

- (void)updateSectionsTabBarSelectionForSection:(PPDataSection)section
{
    if (!self.sectionsSegmentedControl || self.sectionsSegmentedControl.numberOfSegments == 0) {
        return;
    }

    NSInteger selectedIndex = (NSInteger)section;
    if (selectedIndex < 0 || selectedIndex >= self.sectionsSegmentedControl.numberOfSegments) {
        selectedIndex = PPDataSectionAds;
    }

    [self.sectionsSegmentedControl setSelectedIndex:selectedIndex animated:NO];
}

- (void)activateSection:(PPDataSection)section userInitiated:(BOOL)userInitiated
{
    if (section < PPDataSectionAds || section > PPDataSectionServices) {
        return;
    }

    BOOL isSameSection = (section == self.viewModel.currentSection);
    BOOL shouldSwitchSection = !isSameSection || self.viewModel.items.count == 0;

    [self updateSectionsTabBarSelectionForSection:section];

    if (userInitiated) {
        [PPFunc triggerLightHaptic];
    }

    if (!shouldSwitchSection) {
        [self scrollCollectionViewToTopAfterReload:YES];
        return;
    }

    if (!isSameSection) {
        [self saveCurrentSectionScrollOffset];
    }

    [self persistSectionSelection:section];
    [self updateCartButtonVisibilityForSection:section animated:userInitiated];
    [self updateFilterChipVisibilityForSection:section animated:userInitiated];
    [self.viewModel switchToSection:section];
}

- (BOOL)shouldShowFilterChipBarForSection:(PPDataSection)section
{
    return NO; // Temporarily hidden
}

- (void)syncFilterChipsForCurrentSection
{
    PPFilterState *state = [self pp_currentFilterState];
    NSArray<PPFilterGroup *> *groups = state.groups;

    // Remove existing chips
    for (PPDropdownFilterChipButton *chip in self.filterChips) {
        [chip removeFromSuperview];
    }
    [self.filterChips removeAllObjects];

    // Create chips dynamically from filter groups
    for (NSInteger i = 0; i < (NSInteger)groups.count; i++) {
        PPFilterGroup *group = groups[i];
        PPDropdownFilterChipButton *chip = [[PPDropdownFilterChipButton alloc] init];
        chip.chipIconName = group.chipIconName;
        chip.tag = i;
        chip.showsMenuAsPrimaryAction = YES;
        [self.filterChips addObject:chip];
        [self.filterChipStackView addArrangedSubview:chip];
    }

    [self refreshFilterChipTitles];
}

- (void)updateFilterChipVisibilityForSection:(PPDataSection)section animated:(BOOL)animated
{
    if (!self.filterChipContainer || !self.filterChipHeightConstraint) {
        return;
    }

    BOOL shouldShow = [self shouldShowFilterChipBarForSection:section];
    [self syncFilterChipsForCurrentSection];

    self.filterChipContainer.hidden = NO;
    void (^layoutChanges)(void) = ^{
        self.filterChipHeightConstraint.constant = shouldShow ? kPPAccessoryFilterHeight : 0.0;
        self.filterChipContainer.alpha = shouldShow ? 1.0 : 0.0;
        [self.view layoutIfNeeded];
    };

    if (!animated || self.view.window == nil) {
        layoutChanges();
        self.filterChipContainer.hidden = !shouldShow;
        [self updateCollectionContentInset];
        return;
    }

    [UIView animateWithDuration:0.22
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:layoutChanges
                     completion:^(__unused BOOL finished) {
        self.filterChipContainer.hidden = !shouldShow;
        [self updateCollectionContentInset];
    }];
}

// ---------- Dynamic filter menu builder ----------

- (UIMenu *)pp_menuForFilterGroup:(PPFilterGroup *)group chipIndex:(NSInteger)chipIndex
{
    __weak typeof(self) weakSelf = self;
    NSMutableArray<UIMenuElement *> *actions = [NSMutableArray array];
    for (PPFilterOption *opt in group.options) {
        UIAction *action =
        [UIAction actionWithTitle:opt.title
                            image:opt.iconName ? [UIImage systemImageNamed:opt.iconName] : nil
                       identifier:nil
                          handler:^(__kindof UIAction * _Nonnull act) {
            [weakSelf pp_filterGroupChangedToValue:opt.value forGroupAtIndex:chipIndex];
        }];
        action.state = (group.selectedValue == opt.value) ? UIMenuElementStateOn : UIMenuElementStateOff;
        [actions addObject:action];
    }
    return [UIMenu menuWithTitle:@"" children:actions];
}

- (void)pp_filterGroupChangedToValue:(NSInteger)value forGroupAtIndex:(NSInteger)chipIndex
{
    PPFilterState *state = [self pp_currentFilterState];
    if (chipIndex < 0 || chipIndex >= (NSInteger)state.groups.count) return;

    PPFilterGroup *group = state.groups[chipIndex];
    group.selectedValue = value;

    [PPFunc triggerLightHaptic];
    [self.viewModel applyFilterState:state];
    [self refreshPresentedItemsAnimated:YES scrollToTop:YES];
    [self pp_prefetchTopImagesWithLimit:12];
    [self updateEmptyState];
}

- (PPFilterState *)pp_currentFilterState
{
    PPDataSection section = self.viewModel.currentSection;
    NSNumber *key = @(section);
    PPFilterState *state = self.filterStates[key];
    if (!state) {
        state = [PPFilterConfigProvider defaultFilterStateForSection:section];
        self.filterStates[key] = state;
    }
    return state;
}

#pragma mark - Custom Navigation Center View

// Updates the main kinds button title in the navigation bar
- (void)updateNavMainKindTitle
{
    if (!self.input.mainKind) return;
    if (self.input.sourceTarget == PPDeepLinkTargetAllCategories) return;

    UIImage *icon = [PPImageButtonHelper imageFor44ptButton:PPImage(self.input.mainKind.KindImageNamed)];
    [self.KindsButton  setImage:icon forState:UIControlStateNormal];
    
     
}


-(UIMenu *)mainMenu
{
    return  [PPHomeHelper MainKindsMenuWithHandler:^(MainKindsModel *model) {
        // 1️⃣ Ignore if same main kind
        if (model.ID == self.input.mainKind.ID) {
            return;
        }

        // 2️⃣ Update input
        self.input.mainKind = model;
         
         NSString *subKey = [self subKindKeyForMainKind:model];
         NSInteger savedSubKindID =
         [[NSUserDefaults standardUserDefaults] integerForKey:subKey];

         SubKindModel *savedSubKind =
         [model subKindForID:savedSubKindID];

         if (savedSubKind) {
             self.viewModel.currentSubKindID = savedSubKind.ID;
             [self updateSubKindsButtonTitle:savedSubKind.SubKindName subKind:savedSubKind];
         } else {
             self.viewModel.currentSubKindID = 0; // All
             [self updateSubKindsButtonTitle:model.KindName];
         }
         [self refreshsubKindsMenu];
         

         // 🔥 Exit AllCategories mode once user selects a real kind
         if (self.input.sourceTarget == PPDeepLinkTargetAllCategories) {
             self.input.sourceTarget = PPDeepLinkTargetNone;
         }
         self.viewModel.currentDeepLinkTarget = self.input.sourceTarget;
         
         
        [self reloadNavigationCenterViewLayout];

        // 4️⃣ Clear saved scroll positions (VERY IMPORTANT)
        [self.scrollOffsetsBySection removeAllObjects];

        // 5️⃣ Reset layout cache (Pinterest safety)
        [self resetLayoutForSectionChange];

        // 6️⃣ Restore last selected section for this MainKind
        NSString *key = [self sectionKeyForMainKind:model];
        PPDataSection lastSection =
        (PPDataSection)[[NSUserDefaults standardUserDefaults] integerForKey:key];

        if (lastSection >= PPDataSectionAds &&
            lastSection <= PPDataSectionServices) {
            self.viewModel.pendingRestoreSection = lastSection;

            [self updateSectionsTabBarSelectionForSection:lastSection];
            [self updateCartButtonVisibilityForSection:lastSection];
        }

        [self.viewModel switchToMainKind:model];
        [self prefetchSubKindIcons];
        [self updateNavMainKindTitle];

    }];
}
// Modified to add a second navigation button: sectionsButton
-(void)setupKindsView
{
    _navContainerView = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleCapsule configType:PPButtonConfigrationGlass];
    self.navContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIButtonConfiguration *navContainerViewcfg = self.navContainerView.configuration;
    navContainerViewcfg.background.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.30];
    navContainerViewcfg.baseBackgroundColor = [AppForgroundColr colorWithAlphaComponent:0.30];
    
    self.navContainerView.configuration = navContainerViewcfg;
    
    if (!PPIOS26()) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurView.translatesAutoresizingMaskIntoConstraints = NO;
        blurView.layer.cornerRadius = 22;
        blurView.clipsToBounds = YES;
        blurView.userInteractionEnabled = NO;
        [self.navContainerView insertSubview:blurView atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [blurView.topAnchor constraintEqualToAnchor:self.navContainerView.topAnchor],
            [blurView.bottomAnchor constraintEqualToAnchor:self.navContainerView.bottomAnchor],
            [blurView.leadingAnchor constraintEqualToAnchor:self.navContainerView.leadingAnchor],
            [blurView.trailingAnchor constraintEqualToAnchor:self.navContainerView.trailingAnchor]
        ]];
    }
    self.KindsButton = [self pp_ZeroButtonWithSystemName:self.input.sourceTarget ==  PPDeepLinkTargetAllCategories ? @"square.grid.2x2.fill" : (self.input.mainKind
                                                                                                                                       ? self.input.mainKind.KindImageNamed
                                                                                                                             : @"square.grid.2x2.fill") action:nil];
    // Remove any size constraints previously set by helpers
    self.KindsButton.translatesAutoresizingMaskIntoConstraints = NO;
    // Do NOT add width/height constraints here except the explicit width below
    self.KindsButton.showsMenuAsPrimaryAction = YES;
    self.KindsButton.menu =   [PPHomeHelper MainKindsMenuWithHandler:^(MainKindsModel *model) {
        // 1️⃣ Ignore if same main kind
        if (model.ID == self.input.mainKind.ID) {
            return;
        }

        // 2️⃣ Update input
        self.input.mainKind = model;
        
        self.KindsButton.menu =
        [self mainMenu];
         
         NSString *subKey = [self subKindKeyForMainKind:model];
         NSInteger savedSubKindID =
         [[NSUserDefaults standardUserDefaults] integerForKey:subKey];

         SubKindModel *savedSubKind =
         [model subKindForID:savedSubKindID];

         if (savedSubKind) {
             self.viewModel.currentSubKindID = savedSubKind.ID;
             [self updateSubKindsButtonTitle:savedSubKind.SubKindName subKind:savedSubKind];
          
             
         } else {
             self.viewModel.currentSubKindID = 0; // All
             [self updateSubKindsButtonTitle:model.KindName];
         }
         [self refreshsubKindsMenu];
         

         // 🔥 Exit AllCategories mode once user selects a real kind
         if (self.input.sourceTarget == PPDeepLinkTargetAllCategories) {
             self.input.sourceTarget = PPDeepLinkTargetNone;
         }
         self.viewModel.currentDeepLinkTarget = self.input.sourceTarget;
         
         
        [self reloadNavigationCenterViewLayout];

        // 4️⃣ Clear saved scroll positions (VERY IMPORTANT)
        [self.scrollOffsetsBySection removeAllObjects];

        // 5️⃣ Reset layout cache (Pinterest safety)
        [self resetLayoutForSectionChange];

        // 6️⃣ Restore last selected section for this MainKind
        NSString *key = [self sectionKeyForMainKind:model];
        PPDataSection lastSection =
        (PPDataSection)[[NSUserDefaults standardUserDefaults] integerForKey:key];

        if (lastSection >= PPDataSectionAds &&
            lastSection <= PPDataSectionServices) {
            self.viewModel.pendingRestoreSection = lastSection;

            [self updateSectionsTabBarSelectionForSection:lastSection];
            [self updateCartButtonVisibilityForSection:lastSection];
        }

        [self.viewModel switchToMainKind:model];
        [self prefetchSubKindIcons];
        [self updateNavMainKindTitle];

    }];
 
 
    UIButton *sectionsBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    sectionsBtn.translatesAutoresizingMaskIntoConstraints = NO;

    // Configuration (iOS 16+ best practice)
    UIButtonConfiguration *cfg;
    if (@available(iOS 26.0, *)) {
        cfg = [UIButtonConfiguration glassButtonConfiguration];
    } else {
        cfg = [UIButtonConfiguration plainButtonConfiguration];
    }
    cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 12, 6, 12);
    cfg.imagePadding = 6;
    cfg.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;
    cfg.baseForegroundColor = UIColor.labelColor;
 


    UIImage *chevron =
    [UIImage pp_symbolNamed:@"chevron.down" pointSize:16 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleDefault palette:@[AppPrimaryClr] makeTemplate:NO];
    cfg.image = chevron;

    sectionsBtn.configuration = cfg;
    sectionsBtn.showsMenuAsPrimaryAction = YES;
   // sectionsBtn.menu = [self subKindsMenu];

    // HARD LOCK against navbar / layout animations
    sectionsBtn.layer.actions = @{
        @"position" : [NSNull null],
        @"bounds"   : [NSNull null],
        @"transform": [NSNull null],
        @"opacity"  : [NSNull null]
    };

    // Content rules (no jumps, RTL safe)
    sectionsBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    sectionsBtn.titleLabel.numberOfLines = 1;
    sectionsBtn.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    sectionsBtn.semanticContentAttribute = UISemanticContentAttributeUnspecified;

    // Assign
    self.subKindsButton = sectionsBtn;
    if (@available(iOS 18.0, *)) {
        [self.subKindsButton.imageView addSymbolEffect: [[NSSymbolWiggleEffect effect] effectWithByLayer] options: [NSSymbolEffectOptions optionsWithRepeatBehavior:[NSSymbolEffectOptionsRepeatBehavior behaviorPeriodicWithDelay:2.0]]];
    } else {
        // Fallback on earlier versions
    }
    
    if (!PPIOS26()) {
        self.KindsButton.layer.cornerRadius = 18;
        self.KindsButton.clipsToBounds = YES;
        self.subKindsButton.layer.cornerRadius = 18;
        self.subKindsButton.clipsToBounds = YES;
    }

    self.subKindsButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.cartButton = [self pp_ZeroButtonWithSystemName:@"magnifyingglass"
                                                  action:nil];
    self.cartButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.cartButton.showsMenuAsPrimaryAction = YES;
    self.cartButton.menu = [self actionsArrayFrom:self collectionView:nil];
    self.cartButton.hidden = NO;
    self.cartButton.alpha = 1.0;

    self.mainKindsWidthConstraint =
    [self.KindsButton.widthAnchor constraintEqualToConstant:36];
    self.sectionsWidthConstraint =
    [self.subKindsButton.widthAnchor constraintEqualToConstant:140];
    self.cartButtonWidthConstraint =
    [self.cartButton.widthAnchor constraintEqualToConstant:0];
    self.mainKindsWidthConstraint.priority = UILayoutPriorityRequired;
    self.sectionsWidthConstraint.priority = UILayoutPriorityRequired;
    self.cartButtonWidthConstraint.priority = UILayoutPriorityRequired;
    self.mainKindsWidthConstraint.active = YES;
    self.sectionsWidthConstraint.active = YES;
    self.cartButtonWidthConstraint.active = YES;

    [self.navContainerView addSubview:self.KindsButton];
    [self.navContainerView addSubview:self.subKindsButton];
    [self.navContainerView addSubview:self.cartButton];

    // Cart badge moved to rightBarButtonItem — see setupNavigation
 
    
    float inset = 4;
    self.subKindsTrailingToCartConstraint =
    [self.subKindsButton.trailingAnchor constraintEqualToAnchor:self.cartButton.leadingAnchor constant:-inset];
    self.subKindsTrailingToContainerConstraint =
    [self.subKindsButton.trailingAnchor constraintEqualToAnchor:self.navContainerView.trailingAnchor constant:-inset];
    self.subKindsTrailingToContainerConstraint.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        // Vertical
        [self.KindsButton.topAnchor constraintEqualToAnchor:self.navContainerView.topAnchor constant:inset],
        [self.KindsButton.bottomAnchor constraintEqualToAnchor:self.navContainerView.bottomAnchor constant:-inset],
        [self.subKindsButton.topAnchor constraintEqualToAnchor:self.navContainerView.topAnchor constant:inset],
        [self.subKindsButton.bottomAnchor constraintEqualToAnchor:self.navContainerView.bottomAnchor constant:-inset],
        [self.cartButton.topAnchor constraintEqualToAnchor:self.navContainerView.topAnchor constant:inset],
        [self.cartButton.bottomAnchor constraintEqualToAnchor:self.navContainerView.bottomAnchor constant:-inset],

        // Horizontal (Kinds → SubKinds)
        [self.KindsButton.leadingAnchor constraintEqualToAnchor:self.navContainerView.leadingAnchor constant:inset],
        [self.cartButton.trailingAnchor constraintEqualToAnchor:self.navContainerView.trailingAnchor constant:-inset],
        [self.KindsButton.trailingAnchor constraintEqualToAnchor:self.subKindsButton.leadingAnchor  constant:-inset],

        // Height
        [self.navContainerView.heightAnchor constraintEqualToConstant:44]
    ]];
    

    // No max-width cap — navContainerView stretches to fill available nav bar space
   
    
    // Remove forced intrinsic layout for KindsButton (do not call setNeedsLayout/layoutIfNeeded here)
    
    sectionsBtn.menu = [self subKindsMenu];
    
    NSString *subKey = [self subKindKeyForMainKind:self.input.mainKind];
    NSInteger savedSubKindID =
    [[NSUserDefaults standardUserDefaults] integerForKey:subKey];

    SubKindModel *savedSubKind =
    [self.input.mainKind subKindForID:savedSubKindID];

    if (savedSubKind) {
        self.viewModel.currentSubKindID = savedSubKind.ID;
        [self updateSubKindsButtonTitle:savedSubKind.SubKindName subKind:savedSubKind];
    } else {
        self.viewModel.currentSubKindID = 0; // All
        [self updateSubKindsButtonTitle:self.input.mainKind.KindName];
    }
    
    sectionsBtn.menu = [self subKindsMenu];
    [self updateCartButtonVisibility];
}

// Centralized nav resize logic (single source of truth)

- (void)reloadNavigationCenterViewLayout
{
    // ✅ FORCE layout pass FIRST (fixes AllKinds → first switch)
    [self.navContainerView layoutIfNeeded];

    [self.KindsButton invalidateIntrinsicContentSize];
    [self.subKindsButton invalidateIntrinsicContentSize];
    [self.cartButton invalidateIntrinsicContentSize];

    // 🔒 Icon-only main kind button → square
    CGFloat h = self.navContainerView.bounds.size.height;
    CGFloat mainWidth = h;

    CGFloat sectionWidth =
    MIN(220, MAX(140, self.subKindsButton.intrinsicContentSize.width + 24));

    self.mainKindsWidthConstraint.constant = mainWidth;
    self.sectionsWidthConstraint.constant = sectionWidth;

    [self.navContainerView setNeedsLayout];
    [self.navContainerView layoutIfNeeded];

}
- (UIButton *)glassButtonWithTitle:(NSString *)title menu:(UIMenu *)menu iconNamed:(NSString *)icon dataViewNavBarButtonKind:(PPDataViewNavBarButtonKind)buttonKind
{
    UIButton *btn = [PPButtonHelper pp_buttonForDataVCNavBar:title imageName:icon target:self dataViewNavBarButtonKind:buttonKind];
    btn.semanticContentAttribute =Language.semanticAttributeForCurrentLanguage;
    btn.translatesAutoresizingMaskIntoConstraints = NO;

    
    UIColor *color = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.85];

    btn.layer.masksToBounds = YES;
    btn.clipsToBounds = YES;
    
    UIImage *img = [UIImage pp_symbolNamed:icon pointSize:16 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleDefault palette:buttonKind == PPDataViewNavBarButtonKindSections ? @[AppForgroundColr] : @[color]  makeTemplate:YES];
    [btn setImage:img forState:UIControlStateNormal];
    UIButtonConfiguration *cfg;
    if (@available(iOS 26.0, *)) {
        cfg = UIButtonConfiguration.prominentClearGlassButtonConfiguration;
    } else {
        // Fallback on earlier versions
    }
    cfg.attributedTitle = [[NSAttributedString alloc] initWithString:title
                                                          attributes:@{
        NSFontAttributeName: [GM boldFontWithSize:18],
        NSForegroundColorAttributeName: AppForgroundColr
    }];
     
    cfg.baseForegroundColor =  AppForgroundColr;
    cfg.baseBackgroundColor = [AppPrimaryClr colorWithAlphaComponent:1.0];
    cfg.background.backgroundColor =  [AppPrimaryClr colorWithAlphaComponent:1.0];

    cfg.imagePadding = 6;
    // Remove any fixed-size assumptions (do not set titlePadding)
    
    btn.configuration = cfg;
    
    // 🔒 Prevent title wrapping (Arabic & RTL safe)
    btn.titleLabel.numberOfLines = 1;
    btn.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    btn.titleLabel.adjustsFontSizeToFitWidth = YES;
    btn.titleLabel.minimumScaleFactor = 0.85;
    btn.titleLabel.textAlignment = NSTextAlignmentCenter;
    btn.tintColor =  buttonKind == PPDataViewNavBarButtonKindSections ? AppForgroundColr : color;
    btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    btn.semanticContentAttribute = UISemanticContentAttributeUnspecified;
    
    // Do NOT add width/height constraints inside this helper
    return btn;
}


#pragma mark - SubKinds Button
- (void)updateSubKindsButtonTitle:(NSString *)title
{
    [self updateSubKindsButtonTitle:title subKind:nil];
}
// Update subKindsButton styling: Use light appearance only when current interface style is Light
- (void)updateSubKindsButtonTitle:(NSString *)title subKind:(nullable SubKindModel *)subKind
{
    if (!self.subKindsButton) return;
    if (!title || title.length == 0) return;
    self.lastSubKindsTitle = title;

    BOOL isLight =
    (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleLight);

    UIColor *titleColor = isLight
        ? AppPrimaryClr
        : UIColor.labelColor;

    UIFont *titleFont = isLight
        ? [GM boldFontWithSize:17]
        : [GM MidFontWithSize:17];

    UIButtonConfiguration *config = self.subKindsButton.configuration;

    config.attributedTitle =
    [[NSAttributedString alloc] initWithString:title
                                    attributes:@{
        NSFontAttributeName : titleFont,
        NSForegroundColorAttributeName : titleColor
    }];

    config.baseForegroundColor = titleColor;
    self.subKindsButton.configuration = config;

    // Force size + nav refresh (no animation)
    [self.subKindsButton invalidateIntrinsicContentSize];
    [UIView performWithoutAnimation:^{
        [self reloadNavigationCenterViewLayout];
    }];
    
    if(subKind)
    {
        PPDataViewLog(@"subKind %ld %@ %@ ",subKind.ID,subKind.SubKindName,subKind.SubKindImageName);
        UIImage *btnImg =
        [PPImageButtonHelper imageFor44ptButton:PPImage(subKind.SubKindImageName)];
        [self.KindsButton setImage:btnImg forState:UIControlStateNormal];
    }
    
    
}


- (void)resetLayoutForSectionChange
{
    [self.layoutManager applyLayoutMode:self.layoutManager.currentLayoutMode
                       toCollectionView:self.collectionView
                               animated:NO];
}

- (void)performCrossFadeReload
{
    if (!self.collectionView) { return; }

    if (!self.view.window) {
        self.layoutManager.items = self.presentedItems;
        [self applySnapshotAnimated:NO];
        return;
    }

    if (self.isPerformingCrossFade) {
        self.layoutManager.items = self.presentedItems;
        [self applySnapshotAnimated:NO];
        return;
    }

    self.isPerformingCrossFade = YES;
    self.collectionView.userInteractionEnabled = NO;
    [self.collectionView.layer removeAllAnimations];

    [UIView animateWithDuration:0.18
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.collectionView.alpha = 0.0;
    } completion:^(BOOL finished) {

        // Reload data while invisible
        self.layoutManager.items = self.presentedItems;
        [self applySnapshotAnimated:NO];
        [self.collectionView layoutIfNeeded];

        [UIView animateWithDuration:0.22
                              delay:0
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
            self.collectionView.alpha = 1.0;
        } completion:^(BOOL finished) {
            self.collectionView.userInteractionEnabled = YES;
            self.isPerformingCrossFade = NO;
            
           // [self updateNavSectionTitle];
        }];
    }];
}

#pragma mark - PPUniversalCellDelegate

- (void)PPUniversalCell_tapCard:(PPUniversalCellViewModel *)universalModel
{
    if (!universalModel || !universalModel.ModelObject) {
        PPDataViewLog(@"[DataVC][TapCard] payload is nil");
        return;
    }

    PPDataViewLog(@"[DataVC][TapCard] context=%ld payload=%@",
          universalModel.modelContext,
          universalModel.ModelObject);

    // Centralized routing (best practice)
    [PPOverlayCoordinator pp_openDetailForObject:universalModel.ModelObject
                                          fromVC:self
                                      routingNav:nil];
}

 

- (void)PPUniversalCell_changeQuantity:(PPUniversalCellViewModel *)vm
                              quantity:(NSInteger)quantity
{
    PPDataViewLog(@"[DataVC][Quantity] id=%@ qty=%ld",
          vm.ModelID,
          (long)quantity);
    
    PetAccessory *accessory = (PetAccessory *)vm.ModelObject;
    if (!accessory) return;
    NSInteger maxStock = MAX(accessory.quantity, 0);
    NSInteger safeQuantity = MAX(0, quantity);

    if (maxStock <= 0 && safeQuantity > 0) {
        [PPHUD showError:kLang(@"Out of stock")];
        safeQuantity = 0;
    } else if (safeQuantity > maxStock) {
        safeQuantity = maxStock;
        [PPHUD showInfo:[NSString stringWithFormat:@"%@ %ld %@",
                         kLang(@"Only"),
                         (long)maxStock,
                         kLang(@"left in stock")]];
    }

    if (safeQuantity == 0) {
        // Removed last item
        [PPFunc triggerWarningHaptic];
        [[CartManager sharedManager] removeItemForAccessory:accessory];

    } else {
        CartManager *cart = [CartManager sharedManager];
        CartItem *existing = [cart getCartItemForItemID:accessory.accessoryID];
        CartItem *item = [[CartItem alloc] initWithAccessory:accessory quantity:safeQuantity];
        BOOL didAddNewItem = NO;

        if (existing) {
            [cart updateQuantity:safeQuantity forItem:item completion:nil];
        } else {
            BOOL didAdd = [cart addItem:item];
            if (!didAdd) {
                [PPHUD showError:kLang(@"Out of stock")];
            } else {
                didAddNewItem = YES;
            }
        }
        
        if (safeQuantity == 1) {
            // First add
            [PPFunc triggerLightHaptic];
            if (didAddNewItem) {
                [PPHUD showSuccess:(kLang(@"ItemAddedToCart") ?: @"Item added to cart")];
            }
        }
        else {
            // Increment / decrement
            [PPFunc triggerMediumHaptic];
        }
    }
   

    // 🔔 Notify cart change (already your system)
    [[NSNotificationCenter defaultCenter]
        postNotificationName:kCartUpdatedNotification //@"PPCartDidChangeNotification"
                      object:nil];
}


- (NSString *)sectionKeyForMainKind:(MainKindsModel *)mainKind
{
    // All kinds mode
    if (!mainKind) {
        return kPPAllKindsSectionKey;
    }

    // Persist per MainKind ID (pp.lastSection.<kindID>)
    return [NSString stringWithFormat:@"pp.lastSection.%ld",
            (long)mainKind.ID];
}
 

// Navigation bar setup with custom center view (main kinds + sections menu)
- (void)setupNavigation
{
    // 1️⃣ Back button (LEFT)
    if (!PPIOS26()) {
        UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [backBtn setImage:[UIImage systemImageNamed:PPChevronName] forState:UIControlStateNormal];
        backBtn.backgroundColor = AppForgroundColr;
        backBtn.layer.cornerRadius = 20;
        backBtn.clipsToBounds = YES;
        [backBtn addTarget:self action:@selector(onBack) forControlEvents:UIControlEventTouchUpInside];
        [backBtn.widthAnchor constraintEqualToConstant:40].active = YES;
        [backBtn.heightAnchor constraintEqualToConstant:40].active = YES;
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backBtn];
    } else {
        UIBarButtonItem *backItem =
        [[UIBarButtonItem alloc]
         initWithImage:[UIImage systemImageNamed:PPChevronName]
                 style:UIBarButtonItemStylePlain
                target:self
                action:@selector(onBack)];

        self.navigationItem.leftBarButtonItem = backItem;
    }

    // 2️⃣ Center title view
    [self setupKindsView];
    self.navigationItem.titleView = self.navContainerView;

    // 3️⃣ Right cart button (swapped — cart moved here, filter moved to center nav)
    if (!PPIOS26()) {
        UIButton *cartNavBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [cartNavBtn setImage:[UIImage systemImageNamed:@"cart.fill"] forState:UIControlStateNormal];
        cartNavBtn.backgroundColor = AppForgroundColr;
        cartNavBtn.layer.cornerRadius = 20;
        cartNavBtn.clipsToBounds = NO;
        [cartNavBtn addTarget:self action:@selector(onCartTapped) forControlEvents:UIControlEventTouchUpInside];
        [cartNavBtn.widthAnchor constraintEqualToConstant:40].active = YES;
        [cartNavBtn.heightAnchor constraintEqualToConstant:40].active = YES;

        // Cart badge on rightBarButtonItem
        UILabel *badge = [[UILabel alloc] init];
        badge.translatesAutoresizingMaskIntoConstraints = NO;
        badge.textAlignment = NSTextAlignmentCenter;
        badge.font = [GM boldFontWithSize:11];
        badge.textColor = UIColor.whiteColor;
        badge.backgroundColor = [UIColor systemRedColor];
        badge.layer.cornerRadius = 8.0;
        badge.layer.masksToBounds = YES;
        badge.hidden = YES;
        badge.alpha = 0.0;
        [cartNavBtn addSubview:badge];
        self.cartBadgeLabel = badge;
        self.cartBadgeMinWidthConstraint =
        [badge.widthAnchor constraintGreaterThanOrEqualToConstant:16.0];
        self.cartBadgeMinWidthConstraint.active = YES;
        [NSLayoutConstraint activateConstraints:@[
            [badge.heightAnchor constraintEqualToConstant:16.0],
            [badge.topAnchor constraintEqualToAnchor:cartNavBtn.topAnchor constant:-4.0],
            [badge.trailingAnchor constraintEqualToAnchor:cartNavBtn.trailingAnchor constant:4.0]
        ]];

        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cartNavBtn];
    } else {
        UIButton *cartNavBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [cartNavBtn setImage:[UIImage systemImageNamed:@"cart.fill"] forState:UIControlStateNormal];
        [cartNavBtn addTarget:self action:@selector(onCartTapped) forControlEvents:UIControlEventTouchUpInside];

        UILabel *badge = [[UILabel alloc] init];
        badge.translatesAutoresizingMaskIntoConstraints = NO;
        badge.textAlignment = NSTextAlignmentCenter;
        badge.font = [GM boldFontWithSize:11];
        badge.textColor = UIColor.whiteColor;
        badge.backgroundColor = [UIColor systemRedColor];
        badge.layer.cornerRadius = 8.0;
        badge.layer.masksToBounds = YES;
        badge.hidden = YES;
        badge.alpha = 0.0;
        [cartNavBtn addSubview:badge];
        self.cartBadgeLabel = badge;
        self.cartBadgeMinWidthConstraint =
        [badge.widthAnchor constraintGreaterThanOrEqualToConstant:16.0];
        self.cartBadgeMinWidthConstraint.active = YES;
        [NSLayoutConstraint activateConstraints:@[
            [badge.heightAnchor constraintEqualToConstant:16.0],
            [badge.topAnchor constraintEqualToAnchor:cartNavBtn.topAnchor constant:-4.0],
            [badge.trailingAnchor constraintEqualToAnchor:cartNavBtn.trailingAnchor constant:4.0]
        ]];

        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cartNavBtn];
    }
}

- (UIMenu *)actionsArrayFrom:(UIViewController *)controller collectionView:(UICollectionView *)collectionView
{
    (void)controller;
    (void)collectionView;
    
    NSMutableArray *searchGroup = [NSMutableArray array];
    NSMutableArray *filterGroup = [NSMutableArray array];
    NSMutableArray *layoutGroup = [NSMutableArray array];
    // Search action — opens PPSearchViewController
   UIAction *searchPPAction = [PPActionButton actionWithTitle:kLang(@"searchOnly")
                                              systemImageName:@"magnifyingglass"
                                                         font:[GM MidFontWithSize:16]
                                                        color:AppSecondaryTextClr
                                                        handler:^(UIAction * _Nonnull action){
        PPSearchViewController *searchVC = [[PPSearchViewController alloc] init];
        PPNavigationController *nav = [[PPNavigationController alloc] initWithRootViewController:searchVC];
        nav.modalPresentationStyle = UIModalPresentationFullScreen;
        [PPHomeHelper presentViewControllerSafely:nav from:self animated:YES completion:nil];
    }];
    [searchGroup addObject:searchPPAction];
    
    
    
    UIAction *filterPPAction = [PPActionButton actionWithTitle:kLang(@"filterPPAction")
                                               systemImageName:@"line.3.horizontal.decrease"
                                                          font:[GM MidFontWithSize:16]
                                                         color:AppSecondaryTextClr
                                                       handler:^(UIAction * _Nonnull action){
        [self openFilters];
    }];
    
    
    /// ------------------------------------------------------------------------------------------------------------------------------------------------------------------
    
    
    UIAction *layoutSquirePPAction = [PPActionButton actionWithTitle:kLang(@"PPCellLayoutSquare")
                                                     systemImageName:@"widget.small"
                                                                font:[GM MidFontWithSize:16]
                                                               color:AppPrimaryTextClr
                                                             handler:^(UIAction * _Nonnull action)  {
        PPDataViewLog(@"PPManagerCellLayoutMode PPCellLayoutModeSquare");
        PPManagerCellLayoutMode newMode = PPCellLayoutModeSquare; // or FullWidth, Square, Vertical
        [self.layoutManager applyLayoutMode:newMode
                           toCollectionView:self.collectionView
                                   animated:YES];

        [self performCrossFadeReload];
        [[NSUserDefaults standardUserDefaults] setInteger:newMode forKey:kPPLayoutModeKey];
    }];
    
    
    UIAction *layoutFullPPAction = [PPActionButton actionWithTitle:kLang(@"PPCellLayoutFullWidth")
                                                   systemImageName:@"widget.medium"
                                                              font:[GM MidFontWithSize:16]
                                                             color:AppPrimaryTextClr
                                                           handler:^(UIAction * _Nonnull action) {
        PPDataViewLog(@"PPManagerCellLayoutMode PPCellLayoutModeFullWidth");
        
        PPManagerCellLayoutMode newMode = PPCellLayoutModeFullWidth; // or FullWidth, Square, Vertical
        [self.layoutManager applyLayoutMode:newMode
                           toCollectionView:self.collectionView
                                   animated:YES];

       
        [[NSUserDefaults standardUserDefaults] setInteger:newMode forKey:kPPLayoutModeKey];
        [self performCrossFadeReload];
    }];
    
    
    UIAction *layoutLargePPAction = [PPActionButton actionWithTitle:kLang(@"PPCellLayoutVertical")
                                                    systemImageName:@"widget.extralarge"
                                                               font:[GM MidFontWithSize:16]
                                                              color:AppPrimaryTextClr
                                                            handler:^(UIAction * _Nonnull action) {
        PPDataViewLog(@"PPManagerCellLayoutMode PPCellLayoutModeVertical");
        
        PPManagerCellLayoutMode newMode = PPCellLayoutModeVertical; // or FullWidth, Square, Vertical
        [self.layoutManager applyLayoutMode:newMode
                           toCollectionView:self.collectionView
                                   animated:YES];
        [[NSUserDefaults standardUserDefaults] setInteger:newMode forKey:kPPLayoutModeKey];
        
        [self performCrossFadeReload];
    }];

   
    UIAction *layoutPintrestPPAction = [PPActionButton actionWithTitle:kLang(@"Pintrest")
                                                    systemImageName:@"widget.extralarge"
                                                               font:[GM MidFontWithSize:16]
                                                              color:AppPrimaryTextClr
                                                            handler:^(UIAction * _Nonnull action) {
        PPDataViewLog(@"PPManagerCellLayoutMode PPCellLayoutModePinterest");
        PPManagerCellLayoutMode newMode = PPCellLayoutModePinterest; // or FullWidth, Square, Vertical
        [self.layoutManager applyLayoutMode:newMode
                           toCollectionView:self.collectionView
                                   animated:YES];

       
        [[NSUserDefaults standardUserDefaults] setInteger:newMode forKey:kPPLayoutModeKey];
        
        [self performCrossFadeReload];
    }];
    
     [filterGroup addObject:filterPPAction];
    
    [layoutGroup addObject:layoutSquirePPAction];
    [layoutGroup addObject:layoutFullPPAction];
    [layoutGroup addObject:layoutLargePPAction];
    [layoutGroup addObject:layoutPintrestPPAction];
    
    UIMenu *menu;
    
    if (@available(iOS 17.0, *)) {
        menu  = [UIMenu menuWithTitle:kLang(@"searchOnly")
                                image:nil
                           identifier:nil
                              options:UIMenuOptionsDisplayAsPalette
                             children:@[
            [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:searchGroup],
            [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:filterGroup],
            [UIMenu menuWithTitle:kLang(@"PPCellLayout") image:nil identifier:nil options:UIMenuOptionsDisplayInline children:layoutGroup]        ]];
        
        return  menu;
    } else {
     
        menu  = [UIMenu menuWithTitle:@""
                                image:nil
                           identifier:nil
                              options:UIMenuOptionsDisplayInline
                             children:@[
            [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:searchGroup],
            [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:filterGroup],
            [UIMenu menuWithTitle:kLang(@"PPCellLayout") image:nil identifier:nil options:UIMenuOptionsDisplayInline children:layoutGroup]
        ]];
        
    }
    
    return  menu;
}

- (PPDataSection)sectionFromDeepLinkTarget:(PPDeepLinkTarget)target
{
    switch (target) {

        case PPDeepLinkTargetAllCategories:
            return PPDataSectionAds; // default section for “All kinds”

        case PPDeepLinkTargetAds:
            return PPDataSectionAds;

        case PPDeepLinkTargetAccessories:
            return PPDataSectionAccessories;

        case PPDeepLinkTargetFood:
            return PPDataSectionFood;

        case PPDeepLinkTargetServices:
            return PPDataSectionServices;

        default:
            return PPDataSectionAds;
    }
}
 
- (void)selectSectionButton:(UIButton *)selectedButton
{
    
}

#pragma mark - Sections TabBar

- (void)setupSectionsTabBar
{
    NSArray<PPModrenSegmrntedItem *> *sectionItems = @[
        [PPModrenSegmrntedItem itemWithTitle:[self titleForSection:PPDataSectionAds]
                                    iconName:[self iconForSection:PPDataSectionAds]
                            selectedIconName:[self selectedIconForSection:PPDataSectionAds]],
        [PPModrenSegmrntedItem itemWithTitle:[self titleForSection:PPDataSectionAccessories]
                                    iconName:[self iconForSection:PPDataSectionAccessories]
                            selectedIconName:[self selectedIconForSection:PPDataSectionAccessories]],
        [PPModrenSegmrntedItem itemWithTitle:[self titleForSection:PPDataSectionFood]
                                    iconName:[self iconForSection:PPDataSectionFood]
                            selectedIconName:[self selectedIconForSection:PPDataSectionFood]],
        [PPModrenSegmrntedItem itemWithTitle:[self titleForSection:PPDataSectionServices]
                                    iconName:[self iconForSection:PPDataSectionServices]
                            selectedIconName:[self selectedIconForSection:PPDataSectionServices]]
    ];
    PPModrenSegmrnted *sectionsControl = [[PPModrenSegmrnted alloc] initWithItems:sectionItems];
    sectionsControl.translatesAutoresizingMaskIntoConstraints = NO;
    sectionsControl.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    sectionsControl.accessibilityIdentifier = @"pp.data.sectionsTabBar";
    sectionsControl.containerBackgroundColor = [AppBackgroundClrDarker colorWithAlphaComponent:0.16];
    sectionsControl.normalTextColor = UIColor.secondaryLabelColor;
    sectionsControl.selectedTextColor = [UIColor colorWithWhite:1.0 alpha:0.94];
    sectionsControl.selectedSegmentColor = AppPrimaryClr;
    sectionsControl.normalFont = [GM MidFontWithSize:13];
    sectionsControl.selectedFont = [GM boldFontWithSize:13];
    sectionsControl.layer.cornerRadius = 17.0;
    sectionsControl.layer.borderWidth = 1.0;
    sectionsControl.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.20].CGColor;
    if (@available(iOS 13.0, *)) {
        sectionsControl.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [sectionsControl setSelectedIndex:PPDataSectionAds animated:NO];
    [sectionsControl addTarget:self
                        action:@selector(sectionsSegmentedControlChanged:)
              forControlEvents:UIControlEventValueChanged];

    self.sectionsSegmentedControl = sectionsControl;
    
    if (!PPIOS26()) {
        sectionsControl.layer.shadowColor = UIColor.blackColor.CGColor;
        sectionsControl.layer.shadowOpacity = 0.1;
        sectionsControl.layer.shadowRadius = 4;
        sectionsControl.layer.shadowOffset = CGSizeMake(0, 2);
    }

    [self.view addSubview:sectionsControl];
    self.sectionsTabBarHeightConstraint =
    [sectionsControl.heightAnchor constraintEqualToConstant:PPCurrentSectionsTabBarHeight()];
    self.sectionsTabBarHeightConstraint.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [sectionsControl.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8.0],
        [sectionsControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [sectionsControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0]
    ]];
    
    UIView *filterContainer = [[UIView alloc] init];
    filterContainer.translatesAutoresizingMaskIntoConstraints = NO;
    filterContainer.hidden = YES;
    filterContainer.alpha = 0.0;

    self.filterChipContainer = filterContainer;

    [self.view addSubview:filterContainer];

    self.filterChipHeightConstraint =
    [filterContainer.heightAnchor constraintEqualToConstant:0.0];
    self.filterChipHeightConstraint.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [filterContainer.topAnchor constraintEqualToAnchor:self.sectionsSegmentedControl.bottomAnchor constant:8.0],
        [filterContainer.leadingAnchor constraintEqualToAnchor:self.sectionsSegmentedControl.leadingAnchor],
        [filterContainer.trailingAnchor constraintEqualToAnchor:self.sectionsSegmentedControl.trailingAnchor]
    ]];

    // Dynamic filter chips — created from PPFilterState for the initial section
    self.filterChips = [NSMutableArray array];
    UIStackView *chipsStack = [[UIStackView alloc] init];
    chipsStack.translatesAutoresizingMaskIntoConstraints = NO;
    chipsStack.axis = UILayoutConstraintAxisHorizontal;
    chipsStack.alignment = UIStackViewAlignmentCenter;
    chipsStack.distribution = UIStackViewDistributionFillEqually;
    chipsStack.spacing = 8.0;
    chipsStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.filterChipStackView = chipsStack;
    [filterContainer addSubview:chipsStack];

    [NSLayoutConstraint activateConstraints:@[
        [chipsStack.topAnchor constraintEqualToAnchor:filterContainer.topAnchor],
        [chipsStack.leadingAnchor constraintEqualToAnchor:filterContainer.leadingAnchor],
        [chipsStack.trailingAnchor constraintEqualToAnchor:filterContainer.trailingAnchor],
        [chipsStack.bottomAnchor constraintEqualToAnchor:filterContainer.bottomAnchor],
    ]];

    // Initialize per-section filter state dictionary
    self.filterStates = [NSMutableDictionary dictionary];

    [self syncFilterChipsForCurrentSection];
}

- (void)sectionsSegmentedControlChanged:(PPModrenSegmrnted *)sender
{
    NSInteger selectedIndex = sender.selectedIndex;
    if (selectedIndex < PPDataSectionAds || selectedIndex > PPDataSectionServices) {
        return;
    }

    [self activateSection:(PPDataSection)selectedIndex userInitiated:YES];
}

- (UIMenu *)sectionsMenu
{
    NSMutableArray *actions = [NSMutableArray array];


    for (NSInteger i = PPDataSectionAds; i <= PPDataSectionServices; i++) {
        PPDataSection section = (PPDataSection)i;

        UIAction *action =
        [UIAction actionWithTitle:[self titleForSection:section]
                            image:[UIImage pp_symbolNamed:[self iconForSection:section] pointSize:16 weight:UIImageSymbolWeightMedium scale:UIImageSymbolScaleDefault palette:@[AppPrimaryClr] makeTemplate:YES]
                       identifier:nil
                          handler:^(__kindof UIAction * _Nonnull act) {
            [self activateSection:section userInitiated:YES];
        }];

        action.state =
        (section == self.viewModel.currentSection)
        ? UIMenuElementStateOn
        : UIMenuElementStateOff;
        
        // Apply attributed title
        UIFont *useFont =  [GM boldFontWithSize:16];
        UIColor *useColor =  UIColor.labelColor;
        
        NSDictionary *attributes = @{
            NSFontAttributeName: useFont,
            NSForegroundColorAttributeName: useColor
        };
        
        NSAttributedString *attrTitle = [[NSAttributedString alloc] initWithString:[self titleForSection:section] attributes:attributes];
        [action setValue:attrTitle forKey:@"attributedTitle"]; // KVC hack (Apple doesn’t expose a property yet)
    
        [actions addObject:action];
    }

    return [UIMenu menuWithTitle:@"" children:actions];
}

// Synchronous version of subKindsMenu: builds all actions immediately, uses placeholder icons synchronously.
- (UIMenu *)subKindsMenu
{
    
    PPDataViewLog(@"[SubKindsMenu] currentSubKindID = %ld",
          (long)self.viewModel.currentSubKindID);
    
    
    NSMutableArray *actions = [NSMutableArray array];

    MainKindsModel *mainKind = self.input.mainKind;
    if (!mainKind || mainKind.SubKindsArray.count == 0) {
        return [UIMenu menuWithTitle:@"" children:@[]];
    }

    for (SubKindModel *subKind in mainKind.SubKindsArray) {
        // Synchronously get a placeholder image if possible, else nil
        
        if (subKind.subKindIconBlurHash.length > 0) {
            // If you have a synchronous blurhash decode helper, use it here.
         //   if ([PPBlurHashBridge respondsToSelector:@selector(imageFrom:syncSize:punch:)]) {
         //       placeholder = [PPBlurHashBridge imageFrom:subKind.subKindIconBlurHash syncSize:CGSizeMake(100, 100) punch:0.5 ];
         //  }
        }
        
        UIImage *btnImg =
        [PPImageButtonHelper imageFor44ptButton:PPImage(subKind.SubKindImageName)];
        UIAction *action =
        [UIAction actionWithTitle:subKind.SubKindName
                            image:btnImg
                       identifier:nil
                          handler:^(__kindof UIAction * _Nonnull act) {
            AudioServicesPlaySystemSound(1104);

            if (self.viewModel.currentSubKindID == subKind.ID) return;

            if (self.input.sourceTarget == PPDeepLinkTargetAllCategories) {
                self.input.sourceTarget = PPDeepLinkTargetNone;
                self.viewModel.currentDeepLinkTarget = self.input.sourceTarget;
            }

            NSString *key = [self subKindKeyForMainKind:self.input.mainKind];
            [[NSUserDefaults standardUserDefaults] setInteger:subKind.ID forKey:key];

            [self.scrollOffsetsBySection removeAllObjects];
            [self.viewModel reloadForSubKind:subKind];
            [self updateSubKindsButtonTitle:subKind.SubKindName subKind:subKind];
             self.subKindsButton.menu = [self subKindsMenu];
        }];

        // Selected state
        action.state =
        (subKind.ID == self.viewModel.currentSubKindID)
        ? UIMenuElementStateOn
        : UIMenuElementStateOff;

        // Attributed title (same style as subKindsMenu)
        UIFont *useFont = [GM boldFontWithSize:16];
        UIColor *useColor = UIColor.labelColor;

        NSDictionary *attributes = @{
            NSFontAttributeName : useFont,
            NSForegroundColorAttributeName : useColor
        };

        NSAttributedString *attrTitle =
        [[NSAttributedString alloc] initWithString:subKind.SubKindName
                                        attributes:attributes];

        // ⚠️ KVC hack (same as your subKindsMenu)
        [action setValue:attrTitle forKey:@"attributedTitle"];

        [actions addObject:action];
    }
    
    
    // ─────────────────────────────────────────────
    // 🔹 ALL (clear subkind filter)
    // ─────────────────────────────────────────────

    UIAction *allAction =
    [UIAction actionWithTitle:kLang(@"All")
                        image:[UIImage systemImageNamed:@"circle.grid.3x3.fill"]
                   identifier:nil
                      handler:^(__kindof UIAction * _Nonnull act) {

        AudioServicesPlaySystemSound(1104);

        PPDataViewLog(@"🔄 SubKind = ALL (clear filter)");

        if (self.input.sourceTarget == PPDeepLinkTargetAllCategories) {
            self.input.sourceTarget = PPDeepLinkTargetNone;
            self.viewModel.currentDeepLinkTarget = self.input.sourceTarget;
        }

        // Persist "All" (0 means no subkind)
        NSString *key = [self subKindKeyForMainKind:self.input.mainKind];
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:key];

        // Clear filter in ViewModel
        self.viewModel.currentSubKindID = 0;

        // Reset scroll cache
        [self.scrollOffsetsBySection removeAllObjects];

        // Reload current section WITHOUT subkind constraint
        [self.viewModel reloadDataWithCompletion:^(NSError * _Nullable error) {
            
        }];

        // Update button title back to MainKind name
        [self updateSubKindsButtonTitle:self.input.mainKind.KindName];

        // Refresh menu states
        self.subKindsButton.menu = [self subKindsMenu];
    }];

    // Selected state: ON when no subkind is selected
    allAction.state =
    (self.viewModel.currentSubKindID == 0)
    ? UIMenuElementStateOn
    : UIMenuElementStateOff;

    // Attributed title (same style)
    UIFont *allFont = [GM boldFontWithSize:16];
    UIColor *allColor = AppSecondaryTextClr;

    NSAttributedString *allAttrTitle =
    [[NSAttributedString alloc] initWithString:kLang(@"all")
                                    attributes:@{
        NSFontAttributeName : allFont,
        NSForegroundColorAttributeName : allColor
    }];
    // KVC (same pattern you already use)
    [allAction setValue:allAttrTitle forKey:@"attributedTitle"];
    // Add as LAST item
    [actions addObject:allAction];
    return [UIMenu menuWithTitle:@"" children:actions];
}

- (NSString *)subKindKeyForMainKind:(MainKindsModel *)mainKind
{
    if (!mainKind) { return @"pp.lastSubKind.all"; }
    return [NSString stringWithFormat:@"pp.lastSubKind.%ld", (long)mainKind.ID];
}

-(void)PPUniversalCell_tapShare:(PPUniversalCellViewModel *)universalModel
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [PPAdSharingHelper sharePetAd:(PetAd *)universalModel.ModelObject fromViewController:self];
    });
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer ==
        self.navigationController.interactivePopGestureRecognizer) {
        // Disable on root VC
        return self.navigationController.viewControllers.count > 1;
    }
    return YES;
}


-(void)PPUniversalCell_tapEdit:(PPUniversalCellViewModel *)universalModel
{
    
    PPDataViewLog(@"[AdsVC] PPUniversalCell_tapEdit");
    
    if(universalModel.cellSection == CellSectionAds && [universalModel.ModelObject isKindOfClass:[PetAd class]])
    {
        AddNewAd *vc = (AddNewAd *)[AddNewAd  new];
        vc.mode = AdEditorModeEdit;
        vc.editingAd = (PetAd *)universalModel.ModelObject;                 // the existing PetAd you want to edit
        //vc.delegate = self;                // optional to get callbacks
         [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
    }
    else  if(universalModel.cellSection == CellSectionAccessories && [universalModel.ModelObject isKindOfClass:[PetAccessory class]])
    {
        // Edit
        AddNewAccessory *editVC = [AddNewAccessory new];
        editVC.editingAccessory = (PetAccessory *)universalModel.ModelObject;   ;   // prefill from this model
        editVC.onFinish = ^(PetAccessory *result, BOOL isEdit) {
            // refresh list, etc.
            [AppClasses reloadThisCollectionView:self.collectionView completion:^(BOOL finished) { }];
            
        };
        [PPHomeHelper pushViewControllerSafely:editVC from:self animated:YES];
    }
}



-(void)PPUniversalCell_tapDelete:(PPUniversalCellViewModel *)universalModel
{
    PPDataViewLog(@"[AdsVC] PPUniversalCell_tapDelete");
    if(universalModel.cellSection == CellSectionAds && [universalModel.ModelObject isKindOfClass:[PetAd class]])
    {
        [GM showDeleteConfirmationFrom:self
                                 title:kLang(@"Confirm Deletion")
                               message:kLang(@"Are you sure you want to delete this item?")
                            completion:^(BOOL confirmed) {
            if (confirmed) {
                // Perform delete action
                [PetAdManager.sharedManager deletePetAd:(PetAd *)universalModel.ModelObject completion:^(NSError * _Nonnull error) {
                    [AppClasses reloadThisCollectionView:self.collectionView completion:^(BOOL finished) { }];
                }];
            }
        }];
    }
}

- (void)asyncBlurHashImageForHash:(NSString *)hash
                             size:(CGSize)size
                        completion:(void (^)(UIImage * _Nullable image))completion
{
    if (!hash.length) {
        if (completion) completion(nil);
        return;
    }

    // 1️⃣ Check cache FIRST (cheap, thread-safe)
    UIImage *cached = [self.blurHashCache objectForKey:hash];
    if (cached) {
        if (completion) completion(cached);
        return;
    }

    // 2️⃣ Decode off-main
    dispatch_async(self.blurHashQueue, ^{
        UIImage *img =
        [PPBlurHashBridge imageFrom:hash
                            syncSize:size
                               punch:1.0];

        if (!img) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil);
            });
            return;
        }

        // 3️⃣ Cache + return on main
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.blurHashCache setObject:img forKey:hash];
            if (completion) completion(img);
        });
    });
}

@end
    
