#import "PPPetCareViewController.h"
#import "PPPetCareDiscoveryView.h"
#import "PPDesignTokens.h"
#import "PPUniversalCell.h"
#import "PPUniversalCellViewModel.h"
#import "PPImageLoaderManager.h"
#import "PPOverlayCoordinator.h"
#import "PetAccessory.h"
#import "PetAccessoryManager.h"
#import "VetManager.h"
#import "VetModel.h"
#import "MainKindsModel.h"
#import "ArabicNormalizer.h"
#import "CartManager.h"
#import "CartViewController.h"
#import "PPNavigationController.h"
#import "PPRootTabBarController.h"
#import "PPHomeHelper.h"
#import "UIView+Badge.h"
#import "AppClasses.h"
#import "PPNetworkRetryHelper.h"
#import "PPAlertHelper.h"
#import "PPHUD.h"
#import "PPFunc.h"
#import "PPPetCareVetCell.h"
 
#import "PPPetCareViewerVC.h"
#import "PPPetCareVetViewrVC.h"

typedef NS_ENUM(NSInteger, PPPetCareMedicineFilter) {
    PPPetCareMedicineFilterAll = 0,
    PPPetCareMedicineFilterAvailable,
    PPPetCareMedicineFilterInStock,
    PPPetCareMedicineFilterNew
};

typedef NS_ENUM(NSInteger, PPPetCareVetFilter) {
    PPPetCareVetFilterAll = 0,
    PPPetCareVetFilterWithPhone,
    PPPetCareVetFilterCompany,
    PPPetCareVetFilterPersonal
};



static BOOL PPPetCareUsesAccessibilityLayout(UITraitCollection *traitCollection)
{
    return UIContentSizeCategoryIsAccessibilityCategory(traitCollection.preferredContentSizeCategory);
}



static NSString *PPPetCareNormalizedText(NSString *value)
{
    NSString *trimmed = [PPPetCareSafeString(value) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) {
        return @"";
    }
    NSString *normalized = [ArabicNormalizer normalize:trimmed] ?: trimmed;
    return normalized.lowercaseString;
}

@interface PPPetCareViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UITextFieldDelegate, PPUniversalCellDelegate>
@property (nonatomic, assign) PPPetCareInitialSection selectedSection;
@property (nonatomic, assign) PPPetCareMedicineFilter medicineFilter;
@property (nonatomic, assign) PPPetCareVetFilter vetFilter;
@property (nonatomic, strong, nullable) MainKindsModel *selectedMainKind;
@property (nonatomic, copy) NSArray<MainKindsModel *> *mainKinds;
@property (nonatomic, copy) NSArray<VetMedicineModel *> *allMedicines;
@property (nonatomic, copy) NSArray<VetMedicineModel *> *filteredMedicines;
@property (nonatomic, copy) NSArray<VetModel *> *allVets;
@property (nonatomic, copy) NSArray<VetModel *> *filteredVets;
@property (nonatomic, strong) PPPetCareDiscoveryView *discoveryView;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIButton *filterButton;
@property (nonatomic, strong) UIButton *navCartButton;
@property (nonatomic, copy) NSString *selectedMedicineID;
@property (nonatomic, copy) NSString *medicineQuery;
@property (nonatomic, copy) NSString *vetQuery;
@property (nonatomic, strong, nullable) NSError *medicineLoadError;
@property (nonatomic, strong, nullable) NSError *vetLoadError;
@property (nonatomic, assign) BOOL loadingMedicines;
@property (nonatomic, assign) BOOL loadingVets;
@property (nonatomic, assign) BOOL previousIQKeyboardManagerEnabled;
@property (nonatomic, assign) BOOL previousIQKeyboardToolbarEnabled;
@property (nonatomic, assign) BOOL isOverridingIQKeyboardManager;
@property (nonatomic, assign) BOOL didAnimateEntrance;
@property (nonatomic, assign) CGFloat lastLayoutWidth;
- (void)pp_applyFiltersAndReload;
- (void)pp_updateDiscoveryAnimated:(BOOL)animated;
- (void)pp_layoutDiscovery;
- (void)pp_loadSection:(PPPetCareInitialSection)section;
- (void)pp_presentMedicineDetails:(VetMedicineModel *)medicine;
- (void)pp_presentVetDetails:(VetModel *)vet;
- (void)pp_openPetCareViewer:(UIViewController *)viewer;
- (void)pp_selectMedicine:(VetMedicineModel *)medicine;
- (void)pp_reloadMedicineCellForViewModel:(PPUniversalCellViewModel *)vm;
- (void)pp_reloadVisibleMedicineCells;
- (BOOL)pp_ensureSignedInForAction;
- (PPUniversalCellViewModel *)pp_universalViewModelForMedicine:(VetMedicineModel *)medicine mainKindName:(NSString *)mainKindName indexPath:(NSIndexPath *)indexPath;
@end

@implementation PPPetCareViewController

- (instancetype)initWithInitialSection:(PPPetCareInitialSection)section mainKind:(MainKindsModel *)mainKind
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) return nil;
    _selectedSection = section;
    _selectedMainKind = mainKind;
    _mainKinds = @[];
    _allMedicines = @[];
    _filteredMedicines = @[];
    _allVets = @[];
    _filteredVets = @[];
    _medicineQuery = @"";
    _vetQuery = @"";
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self pp_setupNavigation];
    [self pp_setupViews];
    [self pp_applyKeyboardManagerOverridesIfNeeded];
    [self pp_loadFilters];
    [self pp_loadData];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_appWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_handleCartUpdated:) name:kCartUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_reduceMotionStatusDidChange) name:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if ([self.tabBarController respondsToSelector:@selector(setPremiumTabDockViewHidden:animation:)]) {
        [(PPRootTabBarController *)self.tabBarController setPremiumTabDockViewHidden:YES animation:animated];
    }
    [[self.view viewWithTag:8726] removeFromSuperview];
    [self pp_applyKeyboardManagerOverridesIfNeeded];
    [self pp_setupNavigation];
    [self pp_updateLocalizedText];
    [self pp_updateCartBadge];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (self.didAnimateEntrance) return;
    self.didAnimateEntrance = YES;
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    self.discoveryView.alpha = 0;
    self.discoveryView.transform = CGAffineTransformMakeTranslation(0, 6);
    [UIView animateWithDuration:0.24 delay:0 options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.discoveryView.alpha = 1;
        self.discoveryView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.searchField resignFirstResponder];
    [self pp_reduceMotionStatusDidChange];
    [self pp_restoreKeyboardManagerOverridesIfNeeded];
    if ((self.isMovingFromParentViewController || self.isBeingDismissed) &&
        [self.tabBarController respondsToSelector:@selector(setPremiumTabDockViewHidden:animation:)]) {
        [(PPRootTabBarController *)self.tabBarController setPremiumTabDockViewHidden:NO animation:animated];
    }
}

- (void)dealloc
{
    [self pp_restoreKeyboardManagerOverridesIfNeeded];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (![self.traitCollection.preferredContentSizeCategory isEqualToString:previousTraitCollection.preferredContentSizeCategory] ||
        [self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self pp_updateLocalizedText];
        [self.collectionView.collectionViewLayout invalidateLayout];
        [self.collectionView reloadData];
    }
}

- (void)pp_appWillEnterForeground
{
    [self pp_loadFilters];
    [self pp_updateLocalizedText];
}

- (void)pp_reduceMotionStatusDidChange
{
    [self.discoveryView.layer removeAllAnimations];
    self.discoveryView.alpha = 1;
    self.discoveryView.transform = CGAffineTransformIdentity;
    for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
        [cell.layer removeAllAnimations];
        cell.alpha = 1;
        cell.transform = CGAffineTransformIdentity;
    }
}

#pragma mark - Discovery surface

- (void)pp_setupViews
{
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumLineSpacing = PPSpaceBase;
    layout.minimumInteritemSpacing = PPSpaceMD;
    layout.sectionInset = UIEdgeInsetsMake(PPSpaceSM, PPScreenMargin, PPSpaceXL, PPScreenMargin);
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.alwaysBounceVertical = YES;
    self.collectionView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.collectionView.accessibilityIdentifier = @"petCare.results";
    [PPUniversalCell pp_registerInCollectionView:self.collectionView];
    [self.collectionView registerClass:PPPetCareVetCell.class forCellWithReuseIdentifier:PPPetCareVetCell.reuseIdentifier];
    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    [refresh addTarget:self action:@selector(pp_refreshSelectedSection) forControlEvents:UIControlEventValueChanged];
    self.collectionView.refreshControl = refresh;
    [self.view addSubview:self.collectionView];
    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor]
    ]];
    // A persistent scroll header keeps text-field focus intact when result cells reload.
    self.discoveryView = [[PPPetCareDiscoveryView alloc] initWithFrame:CGRectZero];
    [self.collectionView addSubview:self.discoveryView];
    self.searchField = self.discoveryView.searchField;
    self.searchField.delegate = self;
    self.filterButton = self.discoveryView.filterButton;
    [self.searchField addTarget:self action:@selector(pp_searchTextChanged:) forControlEvents:UIControlEventEditingChanged];
    [self.discoveryView.medicineButton addTarget:self action:@selector(pp_sectionTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.discoveryView.vetsButton addTarget:self action:@selector(pp_sectionTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.discoveryView.primaryButton addTarget:self action:@selector(pp_recoverDiscovery) forControlEvents:UIControlEventTouchUpInside];
    [self.discoveryView.alternateButton addTarget:self action:@selector(pp_exploreOtherSection) forControlEvents:UIControlEventTouchUpInside];
    [self.discoveryView.refreshButton addTarget:self action:@selector(pp_refreshSelectedSection) forControlEvents:UIControlEventTouchUpInside];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self pp_layoutDiscovery];
}

- (void)pp_layoutDiscovery
{
    CGFloat width = CGRectGetWidth(self.collectionView.bounds);
    if (width <= 0) return;
    CGFloat height = [self.discoveryView fittingHeightForWidth:width];
    CGFloat oldHeight = self.collectionView.contentInset.top;
    BOOL atTop = self.collectionView.contentOffset.y <= -oldHeight + 1;
    if (fabs(height - oldHeight) > 0.5 || fabs(width - self.lastLayoutWidth) > 0.5) {
        BOOL widthChanged = fabs(width - self.lastLayoutWidth) > 0.5;
        self.lastLayoutWidth = width;
        self.discoveryView.frame = CGRectMake(0, -height, width, height);
        UIEdgeInsets insets = self.collectionView.contentInset;
        insets.top = height;
        insets.bottom = PPSpaceBase;
        self.collectionView.contentInset = insets;
        if (atTop) self.collectionView.contentOffset = CGPointMake(0, -height);
        if (widthChanged) {
            UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
            CGFloat margin = MAX(PPScreenMargin, (width - 920) / 2);
            layout.sectionInset = UIEdgeInsetsMake(PPSpaceSM, margin, PPSpaceXL, margin);
            [layout invalidateLayout];
        }
    }
}

- (void)pp_updateLocalizedText
{
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.collectionView.semanticContentAttribute = self.view.semanticContentAttribute;
    self.view.backgroundColor = AppBackgroundClr;
    self.title = nil;
    self.navigationItem.title = nil;
    self.navigationItem.titleView = nil;
    [self pp_navBarSetTitle:kLang(@"pet_care_title")];
    self.navCartButton.accessibilityLabel = kLang(@"Cart");
    [self pp_updateFilterMenu];
    [self pp_updateDiscoveryAnimated:NO];
}

- (BOOL)pp_hasSearchCriteria
{
    BOOL medicine = self.selectedSection == PPPetCareInitialSectionMedicines;
    return self.selectedMainKind != nil || PPPetCareNormalizedText(self.searchField.text).length > 0 ||
        (medicine ? self.medicineFilter != PPPetCareMedicineFilterAll : self.vetFilter != PPPetCareVetFilterAll);
}

- (void)pp_updateDiscoveryAnimated:(BOOL)animated
{
    BOOL medicine = self.selectedSection == PPPetCareInitialSectionMedicines;
    BOOL loading = medicine ? self.loadingMedicines : self.loadingVets;
    NSError *error = medicine ? self.medicineLoadError : self.vetLoadError;
    NSUInteger count = medicine ? self.filteredMedicines.count : self.filteredVets.count;
    PPPetCareDiscoveryState state = PPPetCareDiscoveryStateResults;
    if (count > 0 && error) state = PPPetCareDiscoveryStateRetainedError;
    else if (count == 0 && loading) state = PPPetCareDiscoveryStateLoading;
    else if (count == 0 && error) state = PPPetCareDiscoveryStateError;
    else if (count == 0) state = [self pp_hasSearchCriteria] ? PPPetCareDiscoveryStateNoMatches : PPPetCareDiscoveryStateEmpty;
    NSArray<NSString *> *filterKeys = medicine
        ? @[@"pet_care_filter_all", @"pet_care_filter_available", @"pet_care_filter_in_stock", @"pet_care_filter_new"]
        : @[@"pet_care_filter_all", @"pet_care_filter_with_phone", @"pet_care_filter_clinics", @"pet_care_filter_doctors"];
    NSInteger filter = medicine ? (NSInteger)self.medicineFilter : (NSInteger)self.vetFilter;
    NSString *filterName = filter > 0 && filter < filterKeys.count ? kLang(filterKeys[filter]) : nil;
    NSString *kindName = self.selectedMainKind ? [self pp_mainKindNameForID:self.selectedMainKind.ID] : nil;
    [self.discoveryView configureForVeterinarians:!medicine kindName:kindName filterName:filterName count:count state:state loading:loading animated:animated];
    [self pp_layoutDiscovery];
}


#pragma mark - Keyboard and navigation

- (void)pp_applyKeyboardManagerOverridesIfNeeded
{
    IQKeyboardManager *manager = [IQKeyboardManager sharedManager];
    if (!self.isOverridingIQKeyboardManager) {
        self.previousIQKeyboardManagerEnabled = manager.enable;
        self.previousIQKeyboardToolbarEnabled = manager.enableAutoToolbar;
        self.isOverridingIQKeyboardManager = YES;
    }

    manager.enable = NO;
    manager.enableAutoToolbar = NO;
    self.searchField.inputAccessoryView = nil;
    [self.searchField reloadInputViews];
}

- (void)pp_restoreKeyboardManagerOverridesIfNeeded
{
    if (!self.isOverridingIQKeyboardManager) {
        return;
    }

    IQKeyboardManager *manager = [IQKeyboardManager sharedManager];
    manager.enable = self.previousIQKeyboardManagerEnabled;
    manager.enableAutoToolbar = self.previousIQKeyboardToolbarEnabled;
    self.isOverridingIQKeyboardManager = NO;
}

- (void)pp_setupNavigation
{
    self.title = nil;
    self.navigationItem.title = nil;
    self.navigationItem.titleView = nil;
    BOOL showBack = (self.navigationController.viewControllers.count > 1) || (self.presentingViewController != nil);
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"pet_care_title") showBack:showBack];
    [self pp_installCartNavigationButton];
}

- (void)pp_installCartNavigationButton
{
    if (self.navCartButton && self.navigationItem.rightBarButtonItem.customView == self.navCartButton) {
        return;
    }

    UIButton *cartNavBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [cartNavBtn setImage:[UIImage systemImageNamed:@"cart.fill"] forState:UIControlStateNormal];
    [cartNavBtn addTarget:self action:@selector(onCartTapped) forControlEvents:UIControlEventTouchUpInside];
    cartNavBtn.accessibilityLabel = PPPetCareLocalized(@"Cart", @"Cart");
    cartNavBtn.accessibilityIdentifier = @"petCare.cart";
    [cartNavBtn.widthAnchor constraintEqualToConstant:PPTouchTargetMin].active = YES;
    [cartNavBtn.heightAnchor constraintEqualToConstant:PPTouchTargetMin].active = YES;

    if (!PPIOS26()) {
        cartNavBtn.backgroundColor = AppForgroundColr;
        cartNavBtn.layer.cornerRadius = 22.0;
        cartNavBtn.clipsToBounds = NO;
    }

    self.navCartButton = cartNavBtn;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cartNavBtn];
    [self pp_updateCartBadge];
}

- (NSInteger)pp_currentCartItemCount
{
    return [CartManager.sharedManager totalItemsCount];
}

- (void)pp_updateCartBadge
{
    if (!self.navCartButton) {
        return;
    }

    UIButton *badgeHost = self.navCartButton;
    [badgeHost removeBadge];

    NSInteger count = [self pp_currentCartItemCount];
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:Language.isRTL ? @"ar" : @"en"];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    NSString *localizedCount = [formatter stringFromNumber:@(MAX(0, count))];
    badgeHost.accessibilityValue = [NSString stringWithFormat:kLang(@"pet_care_cart_count_format"), localizedCount];
    if (count <= 0) {
        return;
    }

    NSString *badgeText = (count > 99) ? kLang(@"pet_care_count_over_99") : localizedCount;
    UIColor *badgeColor = AppPrimaryClr ?: UIColor.systemPinkColor;

    void (^applyBadge)(void) = ^{
        UIButton *host = self.navCartButton;
        if (!host || [self pp_currentCartItemCount] != count) return;

        [host layoutIfNeeded];
        if (CGRectIsEmpty(host.bounds)) return;

        [host removeBadge];
        [host addBadgeWithContent:badgeText
                       badgeColor:badgeColor
                           offset:CGPointMake(-10.0, 10.0)
                      badgeRadius:9.5];
    };

    applyBadge();
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.navigationController.navigationBar setNeedsLayout];
        [self.navigationController.navigationBar layoutIfNeeded];
        applyBadge();
    });
}

- (void)pp_handleCartUpdated:(NSNotification *)notification
{
    (void)notification;
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_handleCartUpdated:nil];
        });
        return;
    }
    [self pp_updateCartBadge];
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        [self pp_reloadVisibleMedicineCells];
    }
}

- (void)onCartTapped
{
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    CartViewController *vc = [[CartViewController alloc] init];
    PPNavigationController *nav = [[PPNavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [PPHomeHelper presentViewControllerSafely:nav
                                         from:self
                                     animated:YES
                                   completion:nil];
}

- (void)pp_loadFilters
{
    NSArray *kinds = [MKM.MainKindsArray isKindOfClass:NSArray.class] ? MKM.MainKindsArray : @[];
    self.mainKinds = kinds;
    [self pp_updateFilterMenu];
}

- (void)pp_updateFilterMenu
{
    if (@available(iOS 14.0, *)) {
        NSMutableArray<UIAction *> *kindActions = [NSMutableArray array];
        __weak typeof(self) weakSelf = self;

        UIAction *allKindAction = [UIAction actionWithTitle:PPPetCareLocalized(@"pet_care_all_pets", @"All pets") image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            weakSelf.selectedMainKind = nil;
            [weakSelf pp_applyFiltersAndReload];
            [weakSelf pp_updateFilterMenu];
        }];
        allKindAction.state = self.selectedMainKind == nil ? UIMenuElementStateOn : UIMenuElementStateOff;
        [kindActions addObject:allKindAction];

        for (MainKindsModel *kind in self.mainKinds) {
            NSString *title = kind.KindName.length > 0 ? kind.KindName : kind.KindNameEn ?: kind.KindNameAr ?: @"";
            UIAction *action = [UIAction actionWithTitle:title image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                weakSelf.selectedMainKind = kind;
                [weakSelf pp_applyFiltersAndReload];
                [weakSelf pp_updateFilterMenu];
            }];
            action.state = (self.selectedMainKind && self.selectedMainKind.ID == kind.ID) ? UIMenuElementStateOn : UIMenuElementStateOff;
            [kindActions addObject:action];
        }

        UIMenu *kindMenu = [UIMenu menuWithTitle:PPPetCareLocalized(@"pet_care_kind_filter", @"Pet Kind") image:[UIImage systemImageNamed:@"pawprint.fill"] identifier:nil options:0 children:kindActions];

        NSMutableArray<UIAction *> *modeActions = [NSMutableArray array];
        NSArray<NSDictionary *> *items = self.selectedSection == PPPetCareInitialSectionMedicines
            ? @[
                @{@"title": PPPetCareLocalized(@"pet_care_filter_all", @"All"), @"tag": @(PPPetCareMedicineFilterAll)},
                @{@"title": PPPetCareLocalized(@"pet_care_filter_available", @"Available"), @"tag": @(PPPetCareMedicineFilterAvailable)},
                @{@"title": PPPetCareLocalized(@"pet_care_filter_in_stock", @"In stock"), @"tag": @(PPPetCareMedicineFilterInStock)},
                @{@"title": PPPetCareLocalized(@"pet_care_filter_new", @"New"), @"tag": @(PPPetCareMedicineFilterNew)}
            ]
            : @[
                @{@"title": PPPetCareLocalized(@"pet_care_filter_all", @"All"), @"tag": @(PPPetCareVetFilterAll)},
                @{@"title": PPPetCareLocalized(@"pet_care_filter_with_phone", @"Contact ready"), @"tag": @(PPPetCareVetFilterWithPhone)},
                @{@"title": PPPetCareLocalized(@"pet_care_filter_clinics", @"Clinics"), @"tag": @(PPPetCareVetFilterCompany)},
                @{@"title": PPPetCareLocalized(@"pet_care_filter_doctors", @"Doctors"), @"tag": @(PPPetCareVetFilterPersonal)}
            ];

        for (NSDictionary *item in items) {
            NSInteger tag = [item[@"tag"] integerValue];
            BOOL isSelected = self.selectedSection == PPPetCareInitialSectionMedicines
                ? tag == self.medicineFilter
                : tag == self.vetFilter;

            UIAction *action = [UIAction actionWithTitle:item[@"title"] image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                if (weakSelf.selectedSection == PPPetCareInitialSectionMedicines) {
                    weakSelf.medicineFilter = (PPPetCareMedicineFilter)tag;
                } else {
                    weakSelf.vetFilter = (PPPetCareVetFilter)tag;
                }
                [weakSelf pp_applyFiltersAndReload];
                [weakSelf pp_updateFilterMenu];
            }];
            action.state = isSelected ? UIMenuElementStateOn : UIMenuElementStateOff;
            [modeActions addObject:action];
        }

        UIMenu *modeMenu = [UIMenu menuWithTitle:PPPetCareLocalized(@"pet_care_filter_by", @"Filter By") image:[UIImage systemImageNamed:@"line.3.horizontal.decrease"] identifier:nil options:0 children:modeActions];

        UIMenu *mainMenu = [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[kindMenu, modeMenu]];
        self.filterButton.menu = mainMenu;
        self.discoveryView.kindButton.menu = kindMenu;
    }
}

#pragma mark - Data and recovery

- (void)pp_loadData
{
    [self pp_loadSection:PPPetCareInitialSectionMedicines];
    [self pp_loadSection:PPPetCareInitialSectionVeterinarians];
}

- (void)pp_loadSection:(PPPetCareInitialSection)section
{
    BOOL medicines = section == PPPetCareInitialSectionMedicines;
    // Refresh and retry share one request per section; switching tabs never starts duplicates.
    if (medicines ? self.loadingMedicines : self.loadingVets) return;
    if (medicines) {
        self.loadingMedicines = YES;
        self.medicineLoadError = nil;
    } else {
        self.loadingVets = YES;
        self.vetLoadError = nil;
    }
    [self pp_updateDiscoveryAnimated:NO];
    __weak typeof(self) weakSelf = self;
    if (medicines) {
        [[VetManager sharedManager] fetchAllPetMedicinesWithCompletion:^(NSArray<VetMedicineModel *> *items, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;
                self.loadingMedicines = NO;
                self.medicineLoadError = error;
                // A refresh failure preserves the last successful result and explains its state.
                if (!error) {
                    self.allMedicines = [(items ?: @[]) sortedArrayUsingComparator:^NSComparisonResult(VetMedicineModel *a, VetMedicineModel *b) {
                        return [PPPetCareSafeString(a.title) localizedCaseInsensitiveCompare:PPPetCareSafeString(b.title)];
                    }];
                }
                [self pp_finishDataLoad];
            });
        }];
    } else {
        [[VetManager sharedManager] fetchAllVetsWithCompletion:^(NSArray<VetModel *> *items, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;
                self.loadingVets = NO;
                self.vetLoadError = error;
                if (!error) {
                    self.allVets = [(items ?: @[]) sortedArrayUsingComparator:^NSComparisonResult(VetModel *a, VetModel *b) {
                        return [PPPetCareSafeString(a.title) localizedCaseInsensitiveCompare:PPPetCareSafeString(b.title)];
                    }];
                }
                [self pp_finishDataLoad];
            });
        }];
    }
}

- (void)pp_finishDataLoad
{
    BOOL loading = self.selectedSection == PPPetCareInitialSectionMedicines ? self.loadingMedicines : self.loadingVets;
    if (!loading) [self.collectionView.refreshControl endRefreshing];
    [self pp_applyFiltersAndReload];
}

- (void)pp_refreshSelectedSection
{
    [self pp_loadSection:self.selectedSection];
}

- (void)pp_recoverDiscovery
{
    NSError *error = self.selectedSection == PPPetCareInitialSectionMedicines ? self.medicineLoadError : self.vetLoadError;
    if (!error && [self pp_hasSearchCriteria]) {
        self.selectedMainKind = nil;
        self.searchField.text = @"";
        if (self.selectedSection == PPPetCareInitialSectionMedicines) {
            self.medicineQuery = @"";
            self.medicineFilter = PPPetCareMedicineFilterAll;
        } else {
            self.vetQuery = @"";
            self.vetFilter = PPPetCareVetFilterAll;
        }
        [self pp_updateFilterMenu];
        [self pp_applyFiltersAndReload];
        [PPFunc triggerLightHaptic];
        UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, self.discoveryView.kindButton);
    } else {
        [self pp_refreshSelectedSection];
    }
}

- (void)pp_exploreOtherSection
{
    [self pp_selectSection:self.selectedSection == PPPetCareInitialSectionMedicines ? PPPetCareInitialSectionVeterinarians : PPPetCareInitialSectionMedicines];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, self.selectedSection == PPPetCareInitialSectionMedicines ? self.discoveryView.medicineButton : self.discoveryView.vetsButton);
}

- (void)pp_sectionTapped:(UIButton *)sender
{
    [self pp_selectSection:sender.tag == 1 ? PPPetCareInitialSectionVeterinarians : PPPetCareInitialSectionMedicines];
}

- (void)pp_selectSection:(PPPetCareInitialSection)section
{
    if (section == self.selectedSection) return;
    [self.searchField resignFirstResponder];
    self.selectedSection = section;
    self.searchField.text = section == PPPetCareInitialSectionMedicines ? self.medicineQuery : self.vetQuery;
    [self.collectionView.refreshControl endRefreshing];
    // Update selection before reloading; the persistent header owns the only tab animation.
    [self pp_updateDiscoveryAnimated:YES];
    [self pp_updateFilterMenu];
    [self.collectionView.collectionViewLayout invalidateLayout];
    [self.collectionView reloadData];
    [self.collectionView setContentOffset:CGPointMake(0, -self.collectionView.contentInset.top) animated:NO];
    [PPFunc triggerLightHaptic];
}

- (void)pp_searchTextChanged:(UITextField *)textField
{
    if (self.selectedSection == PPPetCareInitialSectionMedicines) self.medicineQuery = textField.text ?: @"";
    else self.vetQuery = textField.text ?: @"";
    [self pp_applyFiltersAndReload];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    CGRect rect = [textField convertRect:textField.bounds toView:self.collectionView];
    [self.collectionView scrollRectToVisible:CGRectInset(rect, 0, -PPSpaceBase) animated:!UIAccessibilityIsReduceMotionEnabled()];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (void)pp_applyFiltersAndReload
{
    NSString *medicineQuery = PPPetCareNormalizedText(self.medicineQuery);
    NSString *vetQuery = PPPetCareNormalizedText(self.vetQuery);
    NSInteger kindID = self.selectedMainKind ? self.selectedMainKind.ID : 0;

    NSMutableArray<VetMedicineModel *> *medicines = [NSMutableArray array];
    for (VetMedicineModel *item in self.allMedicines) {
        if (kindID > 0 && ![self pp_animalTypes:item.animalTypes matchMainKind:self.selectedMainKind]) {
            continue;
        }
        if (![self pp_medicine:item matchesFilter:self.medicineFilter]) {
            continue;
        }
        if (medicineQuery.length > 0) {
            NSString *haystack = PPPetCareNormalizedText([@[PPPetCareSafeString(item.title),
                                                           PPPetCareSafeString(item.title_lowercase)]
                                                         componentsJoinedByString:@" "]);
            if (![haystack containsString:medicineQuery]) {
                continue;
            }
        }
        [medicines addObject:item];
    }
    self.filteredMedicines = medicines.copy;

    NSMutableArray<VetModel *> *vets = [NSMutableArray array];
    for (VetModel *vet in self.allVets) {
        if (kindID > 0 && ![self pp_vet:vet matchesMainKind:self.selectedMainKind]) {
            continue;
        }
        if (![self pp_vet:vet matchesFilter:self.vetFilter]) {
            continue;
        }
        if (vetQuery.length > 0) {
            NSString *haystack = PPPetCareNormalizedText([@[PPPetCareSafeString(vet.title),
                                                           PPPetCareSafeString(vet.name_lowercase)]
                                                         componentsJoinedByString:@" "]);
            if (![haystack containsString:vetQuery]) {
                continue;
            }
        }
        [vets addObject:vet];
    }
    self.filteredVets = vets.copy;

    [self.collectionView reloadData];
    [self pp_updateDiscoveryAnimated:NO];
}

- (BOOL)pp_medicine:(VetMedicineModel *)medicine matchesFilter:(PPPetCareMedicineFilter)filter
{
    if (medicine.isPublished == NO || medicine.isDisabled) {
        return NO;
    }
    switch (filter) {
        case PPPetCareMedicineFilterAvailable:
            return medicine.isAvailable && medicine.stockQuantity > 0;
        case PPPetCareMedicineFilterInStock:
            return medicine.stockQuantity > 0;
        case PPPetCareMedicineFilterNew:
            if (!medicine.createdAt) {
                return YES;
            }
            return [medicine.createdAt timeIntervalSinceNow] >= -(14.0 * 24.0 * 60.0 * 60.0);
        case PPPetCareMedicineFilterAll:
        default:
            return YES;
    }
}

- (BOOL)pp_vet:(VetModel *)vet matchesFilter:(PPPetCareVetFilter)filter
{
    if (vet.isDisabled) {
        return NO;
    }
    if (![self pp_vetIsApprovedForListing:vet]) {
        return NO;
    }
    switch (filter) {
        case PPPetCareVetFilterWithPhone:
            return vet.readyToContact || vet.phone.length > 0 || vet.whatsapp.length > 0;
        case PPPetCareVetFilterCompany:
            return vet.type == VetTypeCompany;
        case PPPetCareVetFilterPersonal:
            return vet.type == VetTypePersonal;
        case PPPetCareVetFilterAll:
        default:
            return YES;
    }
}

- (BOOL)pp_vetIsApprovedForListing:(VetModel *)vet
{
    NSString *verificationStatus = PPPetCareSafeString(vet.verificationStatus).lowercaseString;
    if (verificationStatus.length == 0) {
        return YES;
    }

    static NSSet<NSString *> *approvedStatuses = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        approvedStatuses = [NSSet setWithArray:@[@"approved", @"active", @"verified"]];
    });

    return [approvedStatuses containsObject:verificationStatus];
}

- (BOOL)pp_animalTypes:(NSArray<NSString *> *)animalTypes matchMainKind:(MainKindsModel *)mainKind
{
    if (!mainKind) {
        return YES;
    }
    if (animalTypes.count == 0) {
        return YES;
    }

    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    if (mainKind.ID > 0) {
        [candidates addObject:[NSString stringWithFormat:@"%ld", (long)mainKind.ID]];
    }
    for (NSString *value in @[PPPetCareSafeString(mainKind.KindName), PPPetCareSafeString(mainKind.KindNameEn), PPPetCareSafeString(mainKind.KindNameAr)]) {
        NSString *normalized = PPPetCareNormalizedText(value);
        if (normalized.length > 0) {
            [candidates addObject:normalized];
        }
    }

    for (NSString *animalType in animalTypes) {
        NSString *normalizedAnimalType = PPPetCareNormalizedText(animalType);
        for (NSString *candidate in candidates) {
            if ([normalizedAnimalType isEqualToString:candidate]) {
                return YES;
            }
        }
    }
    return NO;
}

- (BOOL)pp_vet:(VetModel *)vet matchesMainKind:(MainKindsModel *)mainKind
{
    if (!mainKind) {
        return YES;
    }
    if (vet.animalTypes.count > 0) {
        return [self pp_animalTypes:vet.animalTypes matchMainKind:mainKind];
    }
    return vet.petMainKindID == mainKind.ID;
}

#pragma mark - Collection

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        return self.filteredMedicines.count;
    }
    return self.filteredVets.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                          cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        PPUniversalCell *cell = (PPUniversalCell *)[PPUniversalCell pp_dequeueFromCollectionView:collectionView indexPath:indexPath];
        cell.delegate = self;
        cell.indexPath = indexPath;
        cell.hideTopBadge = YES;
        cell.showsSubtitle = YES;
        cell.onTap = nil;
        if (indexPath.item < self.filteredMedicines.count) {
            VetMedicineModel *medicine = self.filteredMedicines[indexPath.item];
            NSString *mainKindName = self.selectedMainKind ? [self pp_mainKindNameForID:self.selectedMainKind.ID] : PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
            PPUniversalCellViewModel *vm = [self pp_universalViewModelForMedicine:medicine
                                                                      mainKindName:mainKindName
                                                                        indexPath:indexPath];
            [cell applyViewModel:vm
                         context:PPCellForMarket
                       layoutMode:PPCellLayoutModeMarket
                     discountMode:PPDiscountStylePlain
                      imageLoader:^(UIImageView *imageView,
                                    NSString *url,
                                    UIImage *placeholder,
                                    UIView *card) {
                (void)card;
                imageView.contentMode = UIViewContentModeScaleAspectFill;
                imageView.clipsToBounds = YES;
                [[PPImageLoaderManager shared] setImageOnImageView:imageView
                                                               url:url
                                                       placeholder:placeholder
                                                  transitionStyle:PPImageTransitionStyleFade
                                                        complation:nil];
            }];
            cell.selected = [PPPetCareMedicineItemIdentifier(medicine) isEqualToString:self.selectedMedicineID];
        }
        return cell;
    }

    PPPetCareVetCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:PPPetCareVetCell.reuseIdentifier
                                                                       forIndexPath:indexPath];
    if (indexPath.item < self.filteredVets.count) {
        VetModel *vet = self.filteredVets[indexPath.item];
        [cell configureWithVet:vet mainKindName:[self pp_mainKindNameForID:vet.petMainKindID]];
        __weak typeof(self) weakSelf = self;
        cell.onDetailsTap = ^{
            __strong typeof(weakSelf) self = weakSelf;
            [self pp_openObject:vet];
        };
        cell.onCallTap = ^{
            __strong typeof(weakSelf) self = weakSelf;
            [self pp_callVet:vet];
        };
        cell.onWhatsAppTap = ^{
            __strong typeof(weakSelf) self = weakSelf;
            [self pp_openWhatsAppForVet:vet];
        };
    }
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat width = CGRectGetWidth(collectionView.bounds);
    UIEdgeInsets inset = ((UICollectionViewFlowLayout *)collectionViewLayout).sectionInset;
    CGFloat available = MAX(1, width - inset.left - inset.right);
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        BOOL accessibility = PPPetCareUsesAccessibilityLayout(self.traitCollection);
        NSInteger columns = accessibility ? 1 : (available >= 680 ? 3 : (available >= 344 ? 2 : 1));
        CGFloat itemWidth = floor((available - (columns - 1) * PPSpaceMD) / columns);
        // Geometry depends only on width and text category, never on image arrival or scrolling.
        CGFloat informationHeight = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
            scaledValueForValue:192 compatibleWithTraitCollection:self.traitCollection];
        CGFloat imageHeight = MIN(220, MAX(128, itemWidth * 0.72));
        return CGSizeMake(itemWidth, ceil(imageHeight + informationHeight));
    }
    if (PPPetCareUsesAccessibilityLayout(self.traitCollection)) {
        if (indexPath.item < self.filteredVets.count) {
            VetModel *vet = self.filteredVets[indexPath.item];
            CGFloat measuredHeight = [PPPetCareVetCell preferredHeightForVet:vet
                                                                 mainKindName:[self pp_mainKindNameForID:vet.petMainKindID]
                                                                        width:available
                                                              traitCollection:self.traitCollection];
            return CGSizeMake(available, measuredHeight);
        }
        return CGSizeMake(available, 420.0);
    }
    return CGSizeMake(available, 208.0);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        if (indexPath.item < self.filteredMedicines.count) {
            [self pp_selectMedicine:self.filteredMedicines[indexPath.item]];
        }
        return;
    } else {
        if (indexPath.item < self.filteredVets.count) {
            [self pp_openObject:self.filteredVets[indexPath.item]];
        }
    }
}

- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0 : 0.12 animations:^{
        cell.transform = UIAccessibilityIsReduceMotionEnabled() ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.985, 0.985);
        cell.alpha = 0.92;
    }];
}

- (void)collectionView:(UICollectionView *)collectionView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0 : 0.20
                          delay:0.0
         usingSpringWithDamping:0.78
          initialSpringVelocity:0.4
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        cell.transform = CGAffineTransformIdentity;
        cell.alpha = 1.0;
    } completion:nil];
}

#pragma mark - Universal Cell

- (void)PPUniversalCell_tapCard:(PPUniversalCellViewModel *)universalModel
{
    if ([universalModel.ModelObject isKindOfClass:VetMedicineModel.class]) {
        [self pp_selectMedicine:(VetMedicineModel *)universalModel.ModelObject];
    }
    [self pp_openObject:universalModel.ModelObject];
}

- (void)PPUniversalCell_changeQuantity:(PPUniversalCellViewModel *)vm
                              quantity:(NSInteger)quantity
{
    if (![vm.ModelObject isKindOfClass:VetMedicineModel.class]) {
        return;
    }

    VetMedicineModel *medicine = (VetMedicineModel *)vm.ModelObject;
    [self pp_selectMedicine:medicine];

    if (![PPNetworkRetryHelper isNetworkAvailable]) {
        [PPAlertHelper showWarningIn:self
                               title:kLang(@"offline_action_title")
                            subtitle:kLang(@"offline_action_message")
                          completion:nil];
        [self pp_reloadMedicineCellForViewModel:vm];
        return;
    }

    if (![self pp_ensureSignedInForAction]) {
        [self pp_reloadMedicineCellForViewModel:vm];
        return;
    }

    NSInteger maxStock = MAX(medicine.stockQuantity, 0);
    NSInteger safeQuantity = MAX(0, quantity);

    if (!medicine.isAvailable || maxStock <= 0) {
        if (safeQuantity > 0) {
            [PPHUD showError:kLang(@"Out of stock")];
            [PPFunc triggerWarningHaptic];
        }
        [self pp_reloadMedicineCellForViewModel:vm];
        return;
    }

    if (safeQuantity > maxStock) {
        safeQuantity = maxStock;
        [PPHUD showInfo:[NSString stringWithFormat:@"%@ %ld %@",
                         kLang(@"Only"),
                         (long)maxStock,
                         kLang(@"left in stock")]];
    }

    CartManager *cart = [CartManager sharedManager];
    NSString *itemID = PPPetCareMedicineItemIdentifier(medicine);
    CartItem *existing = itemID.length > 0 ? [cart getCartItemForItemID:itemID] : nil;

    if (safeQuantity == 0) {
        if (existing) {
            [cart removeItem:existing];
            [PPFunc triggerWarningHaptic];
        }
        [self pp_reloadMedicineCellForViewModel:vm];
        return;
    }

    CartItem *item = PPPetCareCartItemForMedicine(medicine, safeQuantity);
    if (!item) {
        [self pp_reloadMedicineCellForViewModel:vm];
        return;
    }

    if (existing) {
        __weak typeof(self) weakSelf = self;
        [cart updateQuantity:safeQuantity
                     forItem:item
                  completion:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!success) {
                    [PPHUD showError:kLang(@"Out of stock")];
                    [PPFunc triggerWarningHaptic];
                } else if (safeQuantity == 1) {
                    [PPFunc triggerLightHaptic];
                } else {
                    [PPFunc triggerMediumHaptic];
                }
                [self pp_reloadMedicineCellForViewModel:vm];
                [self pp_updateCartBadge];
            });
        }];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [cart addItem:item
presentingViewController:self
       completion:^(BOOL didAdd, BOOL didCancel) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { return; }
        if (didCancel) {
            [self pp_reloadMedicineCellForViewModel:vm];
            return;
        }
        if (!didAdd) {
            [PPHUD showError:kLang(@"Out of stock")];
            [PPFunc triggerWarningHaptic];
            [self pp_reloadMedicineCellForViewModel:vm];
            return;
        }

        if (safeQuantity == 1) {
            [PPFunc triggerLightHaptic];
        } else {
            [PPFunc triggerMediumHaptic];
        }
        [self pp_updateCartBadge];
        [self pp_reloadMedicineCellForViewModel:vm];
    }];
}

- (PPUniversalCellViewModel *)pp_universalViewModelForMedicine:(VetMedicineModel *)medicine
                                                   mainKindName:(NSString *)mainKindName
                                                     indexPath:(NSIndexPath *)indexPath
{
    PPUniversalCellViewModel *vm = [[PPUniversalCellViewModel alloc] initWithModel:nil
                                                                           context:PPCellForMarket];
    NSString *currency = medicine.currency.length > 0 ? medicine.currency : @"QAR";
    NSNumber *price = @(MAX(medicine.price, 0.0));
    NSString *fallbackTitle = PPPetCareLocalized(@"pet_care_medicine_untitled", @"Medicine");
    NSString *fallbackSubtitle = PPPetCareLocalized(@"pet_care_medicine_default_subtitle", @"Care essentials prepared by approved veterinary partners.");
    NSString *stockText = medicine.stockQuantity > 0
        ? [NSString stringWithFormat:PPPetCareLocalized(@"pet_care_viewer_stock_units_format", @"%ld in stock"), (long)medicine.stockQuantity]
        : PPPetCareLocalized(@"pet_care_medicine_out_of_stock", @"Out of stock");

    vm.ModelObject = medicine;
    vm.ModelID = PPPetCareMedicineItemIdentifier(medicine);
    vm.modelType = NSStringFromClass([VetMedicineModel class]);
    vm.modelContext = PPCellForMarket;
    vm.indexPath = indexPath;
    vm.title = medicine.title.length > 0 ? medicine.title : fallbackTitle;
    vm.subtitle = medicine.medicineDescription.length > 0 ? medicine.medicineDescription : fallbackSubtitle;
    vm.price = price;
    vm.finalPrice = price;
    vm.priceText = [GM formatPrice:price currencyCode:currency] ?: [NSString stringWithFormat:@"%.2f %@", medicine.price, currency];
    vm.currencyCode = currency;
    vm.imageURL = medicine.imageUrl ?: @"";
    vm.blurHash = medicine.blurHash ?: @"";
    vm.placeholder = [UIImage imageNamed:@"petcare_placeholder"];
    vm.preferredAspectRatio = 0.78;
    vm.imageSize = CGSizeMake(1.0, 0.78);
    vm.itemQuantitiy = MAX(medicine.stockQuantity, 0);
    vm.availabilityText = medicine.isAvailable && medicine.stockQuantity > 0
        ? PPPetCareLocalized(@"pet_care_medicine_available", @"Available")
        : PPPetCareLocalized(@"pet_care_medicine_not_available", @"Not available");
    vm.stockStatusText = stockText;
    vm.badgeText = mainKindName.length > 0 ? mainKindName : PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
    vm.location = @"";
    vm.isOwner = NO;
    vm.isNew = medicine.createdAt == nil || [medicine.createdAt timeIntervalSinceNow] >= -(14.0 * 24.0 * 60.0 * 60.0);
    vm.hasOffer = NO;

    return vm;
}

- (NSIndexPath *)pp_indexPathForMedicineID:(NSString *)medicineID
{
    if (medicineID.length == 0) {
        return nil;
    }

    NSUInteger index = [self.filteredMedicines indexOfObjectPassingTest:^BOOL(VetMedicineModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)idx;
        return [PPPetCareMedicineItemIdentifier(obj) isEqualToString:medicineID];
    }];
    if (index == NSNotFound) {
        return nil;
    }
    return [NSIndexPath indexPathForItem:index inSection:0];
}

- (void)pp_selectMedicine:(VetMedicineModel *)medicine
{
    NSString *medicineID = PPPetCareMedicineItemIdentifier(medicine);
    NSString *previousID = self.selectedMedicineID ?: @"";
    if ((medicineID.length == 0 && previousID.length == 0) || [previousID isEqualToString:medicineID]) {
        return;
    }

    self.selectedMedicineID = medicineID ?: @"";
    if (!self.collectionView) {
        return;
    }

    NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray array];
    NSIndexPath *previousIndexPath = [self pp_indexPathForMedicineID:previousID];
    NSIndexPath *currentIndexPath = [self pp_indexPathForMedicineID:self.selectedMedicineID];
    if (previousIndexPath) {
        [indexPaths addObject:previousIndexPath];
    }
    if (currentIndexPath && ![currentIndexPath isEqual:previousIndexPath]) {
        [indexPaths addObject:currentIndexPath];
    }

    if (indexPaths.count > 0) {
        [self.collectionView reloadItemsAtIndexPaths:indexPaths];
    } else {
        [self.collectionView reloadData];
    }
}

- (void)pp_reloadMedicineCellForViewModel:(PPUniversalCellViewModel *)vm
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_reloadMedicineCellForViewModel:vm];
        });
        return;
    }

    if (!self.collectionView || self.selectedSection != PPPetCareInitialSectionMedicines) {
        return;
    }

    NSIndexPath *indexPath = vm.indexPath;
    if ((!indexPath || indexPath.item >= self.filteredMedicines.count) && vm.ModelID.length > 0) {
        indexPath = [self pp_indexPathForMedicineID:vm.ModelID];
    }

    if (indexPath && indexPath.item < self.filteredMedicines.count) {
        [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
        return;
    }

    [self pp_reloadVisibleMedicineCells];
}

- (void)pp_reloadVisibleMedicineCells
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_reloadVisibleMedicineCells];
        });
        return;
    }

    if (!self.collectionView || self.selectedSection != PPPetCareInitialSectionMedicines) {
        return;
    }

    NSArray<NSIndexPath *> *visible = self.collectionView.indexPathsForVisibleItems;
    if (visible.count == 0) {
        return;
    }
    [self.collectionView reloadItemsAtIndexPaths:visible];
}

- (BOOL)pp_ensureSignedInForAction
{
    if (UserManager.sharedManager.isUserLoggedIn) {
        return YES;
    }
    [PPFunc triggerWarningHaptic];
    [UserManager showPromptOnTopController];
    return NO;
}

#pragma mark - Routing

- (void)pp_openObject:(id)object
{
    if (!object) {
        return;
    }
    if ([object isKindOfClass:VetMedicineModel.class]) {
        [self pp_presentMedicineDetails:(VetMedicineModel *)object];
        return;
    }
    if ([object isKindOfClass:VetModel.class]) {
        [self pp_presentVetDetails:(VetModel *)object];
        return;
    }
    [PPOverlayCoordinator pp_openDetailForObject:object
                                         fromVC:self
                                     routingNav:(PPNavigationController *)self.navigationController];
}

- (void)pp_presentMedicineDetails:(VetMedicineModel *)medicine
{
    NSString *mainKindName = self.selectedMainKind
        ? [self pp_mainKindNameForID:self.selectedMainKind.ID]
        : PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
    PPPetCareViewerVC *viewer = [[PPPetCareViewerVC alloc] initWithMedicine:medicine
                                                               mainKindName:mainKindName];
    [self pp_openPetCareViewer:viewer];
}

- (void)pp_presentVetDetails:(VetModel *)vet
{
    PPPetCareVetViewrVC *viewer = [[PPPetCareVetViewrVC alloc] initWithVet:vet
                                                              mainKindName:[self pp_mainKindNameForID:vet.petMainKindID]];
    [self pp_openPetCareViewer:viewer];
}

- (void)pp_openPetCareViewer:(UIViewController *)viewer
{
    if (!viewer) {
        return;
    }
    viewer.hidesBottomBarWhenPushed = YES;
    UINavigationController *nav = self.navigationController;
    if (nav) {
        if (!PPIOS26()) {
            UIView *dimView = [[UIView alloc] initWithFrame:self.view.bounds];
            dimView.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.0];
            dimView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            dimView.tag = 8726;
            dimView.accessibilityLabel = @"pp.serviceViewerDim";
            [self.view addSubview:dimView];
            [UIView animateWithDuration:0.22
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                dimView.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.22];
            } completion:nil];
        }
        [nav pushViewController:viewer animated:YES];
        return;
    }

    PPNavigationController *wrapped = [[PPNavigationController alloc] initWithRootViewController:viewer];
    wrapped.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:wrapped animated:YES completion:nil];
}

- (void)pp_callVet:(VetModel *)vet
{
    NSString *rawPhone = vet.phone.length > 0 ? vet.phone : vet.whatsapp;
    if (rawPhone.length == 0) {
        return;
    }

    NSMutableString *clean = [NSMutableString string];
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"+0123456789"];
    for (NSUInteger idx = 0; idx < rawPhone.length; idx++) {
        unichar ch = [rawPhone characterAtIndex:idx];
        if ([allowed characterIsMember:ch]) {
            [clean appendFormat:@"%C", ch];
        }
    }
    if (clean.length == 0) {
        return;
    }

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"telprompt:%@", clean]];
    if (!url) {
        return;
    }
    UIApplication *application = UIApplication.sharedApplication;
    if ([application canOpenURL:url]) {
        [application openURL:url options:@{} completionHandler:nil];
    }
}

- (void)pp_openWhatsAppForVet:(VetModel *)vet
{
    NSString *rawPhone = vet.whatsapp.length > 0 ? vet.whatsapp : vet.phone;
    if (rawPhone.length == 0) {
        return;
    }

    NSMutableString *clean = [NSMutableString string];
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
    for (NSUInteger idx = 0; idx < rawPhone.length; idx++) {
        unichar ch = [rawPhone characterAtIndex:idx];
        if ([allowed characterIsMember:ch]) {
            [clean appendFormat:@"%C", ch];
        }
    }
    if (clean.length == 0) {
        return;
    }

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://wa.me/%@", clean]];
    if (!url) {
        return;
    }
    UIApplication *application = UIApplication.sharedApplication;
    if ([application canOpenURL:url]) {
        [application openURL:url options:@{} completionHandler:nil];
    }
}

- (NSString *)pp_mainKindNameForID:(NSInteger)kindID
{
    if (kindID <= 0) {
        return PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
    }
    for (MainKindsModel *kind in self.mainKinds) {
        if (kind.ID == kindID) {
            return kind.KindName.length > 0 ? kind.KindName : kind.KindNameEn ?: kind.KindNameAr ?: @"";
        }
    }
    return PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
}

@end
