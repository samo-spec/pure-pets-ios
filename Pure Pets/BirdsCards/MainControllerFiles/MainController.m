
#import "MainController.h"

#import "ProfileVC.h"
#import "PPSelectOptionViewController.h"
#import "selectUserVC.h"
#import "LBHamburgerButton.h"
#import "PPCommerceFeedbackManager.h"
#import "FullscreenImageViewController.h"


#pragma mark - UIScrollViewDelegate methods

typedef NS_ENUM(NSInteger, MainItemType) {
    MainItemTypeCard,
    MainItemTypeCage,
    MainItemTypeArchive,
    MainItemTypeTrash,
    MainItemTypeBuyer
};

typedef NS_ENUM(NSInteger, PPCardSortType) {
    PPCardSortNewest = 0,
    PPCardSortOldest,
    PPCardSortRingAsc,
    PPCardSortRingDesc
};


typedef NS_ENUM(NSInteger, PPSearchScopeMainController) {
    PPSearchScopeMainControllerAll,
    PPSearchScopeMainControllerRing,
    PPSearchScopeMainControllerame,
    PPSearchScopeMainControllerBuyer
};


typedef NS_ENUM(NSUInteger, PPMainTabBarState) {
    PPMainTabBarStateCollapsed,
    PPMainTabBarStateExpanded
};



static const void *kCachedSearchTextKey = &kCachedSearchTextKey;

static NSString * const kPPSortKey   = @"pp.cards.sort";
static NSString * const kPPFilterKey = @"pp.cards.filter.subkind";
 @interface MainItem : NSObject
@property (nonatomic, assign) MainItemType type;
@property (nonatomic, strong) NSString *identifier;
@property (nonatomic, strong) id model;
@property (nonatomic, assign) NSUInteger version; // 👈 ADD

@end

@implementation MainItem
- (NSUInteger)hash {
    return self.identifier.hash ^ self.version;
}
- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:MainItem.class]) return NO;
    MainItem *other = object;
    return [self.identifier isEqualToString:other.identifier]
        && self.version == other.version;
}
@end


@interface MainController () <
UINavigationControllerDelegate,
UserDataProtocol,
UIViewControllerTransitioningDelegate,
PPBirdSummaryCollectionCellDelegate,
UICollectionViewDataSourcePrefetching,
UITabBarDelegate,
TrashCollectionViewCellDelegate,SalesCellDelegate,UITextFieldDelegate>

{

    CGFloat topPadding;
    CGFloat bottomPadding;

    NSInteger shareForIndex;
    NSString *shareFor;

    PPBirdSummaryCollectionCell *cellToArchive;
    CardModel *archiveCard;
    NSIndexPath *currentCellIndex;
     
    NSMutableArray *segmTitles;
    BOOL isSubViewsAdded;
    NSString *remainStringOne;
    NSString *remainStringTwo;
     UIBarButtonItem *SearchBarButtonItem;
    UIBarButtonItem *FilterBTNBarButtonItem;
}
@property (nonatomic, assign) BOOL snapshotScheduled;
@property (nonatomic, assign) BOOL snapshotPendingAnimated;
@property (nonatomic, strong) dispatch_block_t pendingSnapshotBlock;

@property (nonatomic, assign) BOOL didSetupTabBar;
@property (nonatomic, assign) PPSearchScopeMainController searchScope;
@property (nonatomic, strong) UICollectionViewDiffableDataSource<NSNumber *, MainItem *> *dataSource;
@property (nonatomic, assign) BOOL didApplyInitialSnapshot;
@property (nonatomic, strong) UIImage *placeHolderImage;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *scrollOffsets;
@property (nonatomic) PPCardSortType selectedSort;
@property (nonatomic, copy) NSString *selectedSubKind;
@property (nonatomic, copy) NSString *activeSearchText;

@property (nonatomic, strong) NSArray<UITabBarItem *> *itemsWithIconsAndTitles;
@property (nonatomic, strong) NSArray<UITabBarItem *> *itemsWithIconsOnly;
@property (nonatomic, assign) BOOL isSearchVisible;
@property (nonatomic, strong) NSLayoutConstraint *searchViewHeightConstraint;

@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSString *> *anchorItemIDs;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *anchorItemOffsets;

@property (nonatomic, strong) NSLayoutConstraint *mainTabBarTopConstraint;

@end




@implementation MainController


- (NSString *)cachedSearchTextForObject:(id)obj builder:(NSString *(^)(void))builder
{
    NSString *cached = objc_getAssociatedObject(obj, kCachedSearchTextKey);
    if (cached) return cached;

    NSString *raw = builder();
    NSString *norm = [self normalizedSearchString:raw];

    objc_setAssociatedObject(obj,
                             kCachedSearchTextKey,
                             norm,
                             OBJC_ASSOCIATION_COPY_NONATOMIC);
    return norm;
}

- (void)updateLegacyMainTabBarBackgroundIfNeeded
{
    if (!self.mainTabBar) {
        return;
    }

    if (PPIOS26()) {
        self.mainTabBar.backgroundColor = UIColor.clearColor;
        self.mainTabBar.barTintColor = UIColor.clearColor;
        self.mainTabBar.layer.cornerRadius = 0.0;
        self.mainTabBar.layer.shadowPath = nil;
        return;
    }

    UIColor *legacyBackgroundColor = [AppForgroundColr colorWithAlphaComponent:0.85];
    self.mainTabBar.backgroundColor = legacyBackgroundColor;
    self.mainTabBar.barTintColor = legacyBackgroundColor;
    self.mainTabBar.layer.cornerRadius = 26.0;

    if (@available(iOS 13.0, *)) {
        self.mainTabBar.layer.cornerCurve = kCACornerCurveContinuous;
    }

    self.mainTabBar.layer.shadowPath =
    [UIBezierPath bezierPathWithRoundedRect:self.mainTabBar.bounds
                               cornerRadius:self.mainTabBar.layer.cornerRadius].CGPath;
}

-(void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    self.mainTabBar.layer.masksToBounds = NO;
    self.mainTabBar.clipsToBounds = NO;
    [self updateLegacyMainTabBarBackgroundIfNeeded];
    
}


-(UIButton *)filterButton
{
    // 1️⃣ Create symbol image
    UIImage *image =
    [UIImage pp_symbolNamed:@"plus"
                  pointSize:18
                     weight:UIImageSymbolWeightSemibold
                      scale:UIImageSymbolScaleLarge
                    palette:@[AppPrimaryClr, AppPrimaryClrShiner]
               makeTemplate:NO];

    // 2️⃣ Create button
    UIButton *filterButton = [UIButton buttonWithType:UIButtonTypeSystem];
    filterButton.translatesAutoresizingMaskIntoConstraints = NO;
    [filterButton setImage:image forState:UIControlStateNormal];

    // Ensure original colors (not tinted)
    filterButton.tintColor = UIColor.clearColor;

    // Touch target (Apple recommended minimum)
    filterButton.contentEdgeInsets = UIEdgeInsetsMake(6, 6, 6, 6);

    // Optional: prevent dimming
    filterButton.adjustsImageWhenHighlighted = NO;
    filterButton.userInteractionEnabled = YES;
    
    [self setupActionsMenuoOnButton:filterButton];

    if (@available(iOS 18.0, *)) {
        [filterButton.imageView  addSymbolEffect: [[NSSymbolWiggleEffect effect] effectWithByLayer] options: [NSSymbolEffectOptions optionsWithRepeatBehavior:[NSSymbolEffectOptionsRepeatBehavior behaviorPeriodicWithDelay:3.0]]];
    } else {
        // Fallback on earlier versions
    }
    
    
    return filterButton;
    // 3️⃣ Wrap in UIBarButtonItem
   
}


- (void)viewDidLoad {
    [super viewDidLoad];
   // UIImage *image = [UIImage pp_symbolNamed:PPIOS26() ? @"plus" : @"plus" pointSize:17 weight:UIImageSymbolWeightMedium scale:UIImageSymbolScaleLarge palette:@[AppPrimaryClr,AppPrimaryClrShiner] makeTemplate:NO];
  
    self.anchorItemIDs = [NSMutableDictionary dictionary];
    self.anchorItemOffsets = [NSMutableDictionary dictionary];
    
    FilterBTNBarButtonItem =
    [[UIBarButtonItem alloc] initWithCustomView:self.filterButton];
    
    FilterBTNBarButtonItem.primaryAction = nil;
   
    UIImage *searchImage =
    [UIImage pp_symbolNamed:@"magnifyingglass"
                  pointSize:16
                     weight:UIImageSymbolWeightMedium
                      scale:UIImageSymbolScaleLarge
                    palette:@[AppPrimaryTextClr, UIColor.grayColor]
               makeTemplate:NO];

    UIImage *closeImage =
    [UIImage pp_symbolNamed:@"eye.slash.circle" //SearchClose
                  pointSize:18
                     weight:UIImageSymbolWeightSemibold
                      scale:UIImageSymbolScaleLarge
                    palette:@[AppPrimaryTextClr,UIColor.grayColor]
               makeTemplate:NO];

    SearchBarButtonItem =
    [[UIBarButtonItem alloc] initWithImage:searchImage
                                     style:UIBarButtonItemStylePlain
                                    target:self
                                    action:@selector(onSearchTapped)];

    objc_setAssociatedObject(SearchBarButtonItem, @"pp_searchImg", searchImage, OBJC_ASSOCIATION_RETAIN);
    objc_setAssociatedObject(SearchBarButtonItem, @"pp_closeImg", closeImage, OBJC_ASSOCIATION_RETAIN);
    
    self.itemsWithIconsAndTitles = [self tabbarItemsFromArrayWithDict:UITabBarItem.tabBarItemsIconsAndTitlesDict];
    self.itemsWithIconsOnly = [self tabbarItemsFromArrayWithDict:UITabBarItem.tabBarItemsIconsOnlyDict];
    isSubViewsAdded = NO;
    _placeHolderImage = [UIImage imageNamed:@"placeholder3"];
    self.childsCountListeners = [NSMutableDictionary dictionary];
 
    self.searchScope = PPSearchScopeMainControllerAll;
    self.lastSegmentedIndex = NSIntegerMin;
    
    
    self.prefetchingURLs = [NSMutableSet set];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onCardsUpdated)
                                               name:@"cardsUpdated"
                                             object:nil];

    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onCagesUpdated)
                                               name:@"cagesUpdated"
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onArchivesUpdated)
                                               name:@"archivesUpdated"
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onTrashUpdated)
                                               name:@"trashUpdated"
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onSalesUpdated)
                                               name:@"salesUpdated"
                                             object:nil];
    //[self fetchDidComplete];

    // --- Programmatic creation of former IBOutlet views ---
    {
        // refershArrow: hidden by default, shown after search filtering
        UIButton *refreshBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        refreshBtn.translatesAutoresizingMaskIntoConstraints = NO;
        refreshBtn.alpha = 0;
        [refreshBtn setImage:[UIImage systemImageNamed:@"arrow.counterclockwise"]
                    forState:UIControlStateNormal];
        refreshBtn.tintColor = [UIColor systemBlueColor];
        [refreshBtn addTarget:self
                       action:@selector(showAllDataBTN:)
             forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:refreshBtn];
        [NSLayoutConstraint activateConstraints:@[
            [refreshBtn.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
            [refreshBtn.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
            [refreshBtn.widthAnchor constraintEqualToConstant:36],
            [refreshBtn.heightAnchor constraintEqualToConstant:36]
        ]];
        self.refershArrow = refreshBtn;

        // salesBTN: hidden off-screen (frame zeroed in reloadUInterFace)
        UIButton *salesBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        salesBtn.frame = CGRectZero;
        salesBtn.hidden = YES;
        [self.view addSubview:salesBtn];
        self.salesBTN = salesBtn;
    }

    [self initialState];                        //initial State
     [self setupCollectionView];
    self.collectionView.alwaysBounceVertical = YES;
 
    
    self.scrollOffsets = [NSMutableDictionary dictionary];
    [self setupConstraint];
   
    [self configureDiffableDataSource];
    [self reloadUInterFace]; //layout Search Bar
    
    self.didInitialLoad = YES;
    
    [NSNotificationCenter.defaultCenter addObserver:self
            selector:@selector(onKeyboardWillChangeFrame:)
            name:UIKeyboardWillChangeFrameNotification
            object:nil];
    
    
    if (!self.didSetupTabBar) {
        [self configureTabBar];
        [self.view sendSubviewToBack:self.collectionView];
        self.didSetupTabBar = YES;
    }

    
    
    [self setupSearchViewIfNeeded];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    if (self.pendingSnapshotBlock) {
        dispatch_block_cancel(self.pendingSnapshotBlock);
        self.pendingSnapshotBlock = nil;
    }
    // Remove all Firestore child-count listeners to prevent leaked connections
    for (id<FIRListenerRegistration> listener in self.childsCountListeners.allValues) {
        [listener remove];
    }
    [self.childsCountListeners removeAllObjects];
}

- (void)configureDiffableDataSource
{
    __weak typeof(self) weakSelf = self;

    self.dataSource =
    [[UICollectionViewDiffableDataSource alloc]
     initWithCollectionView:self.collectionView
     cellProvider:^UICollectionViewCell *(
        UICollectionView *cv,
        NSIndexPath *indexPath,
        MainItem *item)
    {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return nil;

        switch (item.type) {
            case MainItemTypeCard:
                return [self collectionView:cv
              cellForItemAtIndexPath:indexPath
                               model:item.model];

            case MainItemTypeArchive:
                return [self collectionViewArchive:cv
                     cellForItemAtIndexPath:indexPath];

            case MainItemTypeTrash:
                return [self collectionViewTrash:cv
                     cellForItemAtIndexPath:indexPath];

            case MainItemTypeCage:
                return [self collectionViewCages:cv
                     cellForItemAtIndexPath:indexPath];

            case MainItemTypeBuyer:
                return [self collectionViewBuyer:cv
                     cellForItemAtIndexPath:indexPath];
        }
        return nil;
    }];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
          cellForItemAtIndexPath:(NSIndexPath *)indexPath
                           model:(CardModel *)cardData
{
    PPBirdSummaryCollectionCell *cell =
    [collectionView dequeueReusableCellWithReuseIdentifier:
     [PPBirdSummaryCollectionCell reuseIdentifier]
                                              forIndexPath:indexPath];

    cell.delegate = self;
    cell.cellIndexPath = indexPath;

    PPImageLoader loader = ^(UIImageView *iv,
                             NSString *url,
                             UIImage *ph,
                             UIView *con) {
        //NSLog(@" IMAGES  url ............................. %@",url);
             [GM setImageFromUrlString:url imageView:iv phImage:@"placeholder3" completion:^(UIImage * _Nullable image, NSError * _Nullable error) {
                 if(!image)
                 {
                     NSLog(@"NO IMAGES");
                     iv.image = [UIImage imageNamed:@"placeholder3"];
                     iv.backgroundColor = AppPrimaryClr;
                     dispatch_async(dispatch_get_main_queue(), ^{
                         [cell setNeedsLayout];
                         [cell layoutIfNeeded];
                     });
                 }
             }];
         
    };

    [cell configureWithCard:cardData
                 placeholder:[UIImage imageNamed:@"placeholder3"]
                          RTL:Language.isRTL
                  imageLoader:loader];

    return cell;
}

- (NSArray *)sourceArrayForCurrentSection:(MainItemType *)outType {
    switch (self.cellSection) {
        case CellSectionCards:
            *outType = MainItemTypeCard;
            return self.userCardsArray;

        case CellSectionCage:
            *outType = MainItemTypeCage;
            return self.CagedataSource;

        case CellSectionArchive:
            *outType = MainItemTypeArchive;
            return self.UserArchivesDocs;

        case CellSectionTrash:
            *outType = MainItemTypeTrash;
            return self.trachArray;

        case CellSectionSalesBuyer:
            *outType = MainItemTypeBuyer;
            return self.SalesBuyerArr;
    }
    *outType = MainItemTypeCard;
    return @[];
}

- (void)applySnapshotAnimated:(BOOL)animated
{
    // First snapshot must never animate
    if (!self.didApplyInitialSnapshot) {
        animated = NO;
    }

    // Capture current scroll offset
    [self captureAnchorForCurrentSection];

    NSDiffableDataSourceSnapshot<NSNumber *, MainItem *> *snapshot =
    [[NSDiffableDataSourceSnapshot alloc] init];

    NSNumber *section = @(self.cellSection);
    [snapshot appendSectionsWithIdentifiers:@[section]];

    MainItemType type;
    NSArray *source = [self sourceArrayForCurrentSection:&type];

    NSMutableArray *items = [NSMutableArray arrayWithCapacity:source.count];
    for (id model in source) {
        MainItem *item = [MainItem new];
        item.type = type;
        item.model = model;
        item.identifier = [model valueForKey:@"ID"];
        item.version = [self versionForModel:model];
        [items addObject:item];
    }

    [snapshot appendItemsWithIdentifiers:items];

    __weak typeof(self) weakSelf = self;
    [self.dataSource applySnapshot:snapshot
             animatingDifferences:animated
                        completion:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        // Restore scroll position safely
        if (!self.suppressScrollAdjustment) {
            [self restoreAnchorForCurrentSection];
        }
        self.didApplyInitialSnapshot = YES;
        
        [self restoreScrollOffsetForCurrentSection];
    }];
}


- (NSUInteger)versionForModel:(id)model {
    NSUInteger v = 0;

    if ([model respondsToSelector:@selector(lastUpdated)] &&
        [model valueForKey:@"lastUpdated"]) {

        v ^= [[model valueForKey:@"lastUpdated"] hash];

        if ([model respondsToSelector:@selector(masterArchiveID)]) {
            NSString *archiveID = [model valueForKey:@"masterArchiveID"];
            v ^= archiveID.hash;
        }
    }

    if ([model respondsToSelector:@selector(childsCount)]) {
        v ^= [[model valueForKey:@"childsCount"] integerValue];
    }

    if ([model respondsToSelector:@selector(detailsCount)]) {
        v ^= [[model valueForKey:@"detailsCount"] integerValue];
    }

    if ([model respondsToSelector:@selector(isDeleted)]) {
        v ^= [[model valueForKey:@"isDeleted"] integerValue];
    }

    // Absolute fallback (deterministic, NOT random)
    if (v == 0) {
        v = [model hash];
    }

    return v;
}
  

- (void)requestSnapshotAnimated:(BOOL)animated
{
    // Coalesce animation intent
    self.snapshotPendingAnimated |= animated;

    if (self.snapshotScheduled) {
        return;
    }

    self.snapshotScheduled = YES;

    __weak typeof(self) weakSelf = self;
    self.pendingSnapshotBlock = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        BOOL shouldAnimate = self.snapshotPendingAnimated;

        self.snapshotScheduled = NO;
        self.snapshotPendingAnimated = NO;
        self.pendingSnapshotBlock = nil;

        [self applySnapshotAnimated:shouldAnimate];
    });

    // 🔑 Throttle window (Apple‑style)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.12 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   self.pendingSnapshotBlock);
}

- (void)onCardsUpdated {
    NSLog(@"reloading .................. onCardsUpdated ..........................");
    self.userCardsArray = AppData.UserCardsDocs;
    self.allCardsArray = AppData.AllCardsDocs;

    if(self.cellSection != CellSectionCards) return;
    [self requestSnapshotAnimated:YES];
}

- (void)onCagesUpdated {
    self.CagedataSource = AppData.UserCaGeDocs;

    if(self.cellSection != CellSectionCage) return;
    [self requestSnapshotAnimated:YES];
}

- (void)onArchivesUpdated {
    self.UserArchivesDocs = AppData.UserArchivesDocs;

    if(self.cellSection != CellSectionArchive) return;
    [self requestSnapshotAnimated:YES];
}

- (void)onTrashUpdated {
    self.trachArray = AppData.trashDocs;

    if(self.cellSection != CellSectionTrash) return;
    [self requestSnapshotAnimated:YES];
}

- (void)onSalesUpdated {
    self.SalesBuyerArr = AppData.BuyerArray;

    if(self.cellSection != CellSectionSalesBuyer) return;
    [self requestSnapshotAnimated:YES];
}

#pragma mark - Button Actions
 
 
- (void)listenForChildsCountForCage:(CageModel *)cage
{
    if (!cage.ID.length) return;
    if (self.childsCountListeners[cage.ID]) return;

    FIRDocumentReference *cageRef =
    [[[FIRFirestore firestore]
      collectionWithPath:@"CagesCol"]
     documentWithPath:cage.ID];

    id<FIRListenerRegistration> listener =
    [cageRef addSnapshotListener:^(FIRDocumentSnapshot * _Nullable snapshot,
                                   NSError * _Nullable error)
    {
        if (error || !snapshot.exists) return;

        NSNumber *count = snapshot.data[@"childsCount"];
        if (![count isKindOfClass:[NSNumber class]]) return;

        cage.childsCount = count.integerValue;

        dispatch_async(dispatch_get_main_queue(), ^{
            self.suppressScrollAdjustment = YES;
            [self requestSnapshotAnimated:NO];
            self.suppressScrollAdjustment = NO;
        });
    }];

    self.childsCountListeners[cage.ID] = listener;
}
- (void)applyInitialContentInsetIfNeeded
{
    static BOOL didApply = NO;
    if (didApply) return;
    didApply = YES;
 
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (!self.didApplyInitialSnapshot) {
        self.suppressScrollAdjustment = YES;
        [self applySnapshotAnimated:NO];
        self.suppressScrollAdjustment = NO;
    }
}

-(void)setupConstraint
{
    
   
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview: self.collectionView];
    self.collectionView.backgroundColor = AppClearClr;
    
    
//////////////////////////////////////   ////////////////////////  Issue in this block bellow
    
    NSAssert(self.collectionView, @"collectionView is nil");

    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:0],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:0],
    ]];
   
    isSubViewsAdded = YES;
    
}

- (void)configureTabBar {
   
    NSLog(@"[TABBAR MAIN] configureTabBar starting ...");
    if (self.mainTabBar) {  NSLog(@"[TABBAR MAIN] tab bar already configured"); return; }
    self.items = [self tabbarItemsFromArrayWithDict:UITabBarItem.tabBarItemsIconsAndTitlesDict];
    
    self.mainTabBar = [[UITabBar alloc] init];
    self.mainTabBar.delegate = self;
    [self configureAppearance];
    self.mainTabBar.items = self.items;

    self.mainTabBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.mainTabBar.itemPositioning = UITabBarItemPositioningFill;
    self.mainTabBar.itemSpacing = 0;
    self.mainTabBar.itemWidth = 0;
    
    [self.view addSubview:self.mainTabBar];

        // 2️⃣ Create tab bar items
    [self configureAppearance];

    self.mainTabBar.translatesAutoresizingMaskIntoConstraints = NO;

    
    [NSLayoutConstraint activateConstraints:@[
        [self.mainTabBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.mainTabBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
 
    ]];
   
    [self.view bringSubviewToFront:self.mainTabBar];
    
    
        
    [self.mainTabBar  setSelectedItem:self.items.firstObject];
    [self.mainTabBar setNeedsLayout];
    [self.mainTabBar layoutIfNeeded];
     

    UIEdgeInsets inset = self.collectionView.contentInset;
    inset.top = 64.0;

    self.collectionView.contentInset = inset;
    self.collectionView.scrollIndicatorInsets = inset;
    
}

- (NSMutableArray<UITabBarItem *> *)tabbarItemsFromArrayWithDict:(NSArray<NSDictionary *> *)tabItems
{
    NSMutableArray<UITabBarItem *> *tabbaritemsArr = [NSMutableArray array];
    if (tabItems.count < 5) return tabbaritemsArr;

    _cardsBarItem = [UITabBarItem pp_tabBarItemWithInfo:tabItems[0]];
    [tabbaritemsArr addObject:_cardsBarItem];
    
    _cagesBarItem = [UITabBarItem pp_tabBarItemWithInfo:tabItems[1]];
    [tabbaritemsArr addObject:_cagesBarItem];
    
    _archiveBarItem = [UITabBarItem pp_tabBarItemWithInfo:tabItems[2]];
    [tabbaritemsArr addObject:_archiveBarItem];
    
    _trashBarItem = [UITabBarItem pp_tabBarItemWithInfo:tabItems[3]];
    [tabbaritemsArr addObject:_trashBarItem];
    
    _salesBarItem = [UITabBarItem pp_tabBarItemWithInfo:tabItems[4]];
    [tabbaritemsArr addObject:_salesBarItem];
    
    return tabbaritemsArr;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self updateLegacyMainTabBarBackgroundIfNeeded];
    if (self.segEmptyCard) {
        [self applyTabBarShadowToContainer:self.segEmptyCard];
    }
}


- (void)onKeyboardWillChangeFrame:(NSNotification *)note
{
    NSDictionary *info = note.userInfo;

    CGRect keyboardEnd =
    [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];

    NSTimeInterval duration =
    [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];

    UIViewAnimationOptions curve =
    ([info[UIKeyboardAnimationCurveUserInfoKey] integerValue] << 16);

    CGRect keyboardInView =
    [self.view convertRect:keyboardEnd fromView:nil];

    CGFloat overlap =
    MAX(0, CGRectGetMaxY(self.view.bounds) - keyboardInView.origin.y);

    BOOL keyboardVisible = overlap > 0;
 
    if(keyboardVisible)
    {
        self.mainTabBar.layer.shadowOpacity = 0.32;
        self.mainTabBar.layer.shadowOffset = CGSizeMake(0, -6);
        self.mainTabBar.layer.shadowRadius = 24;
      //  [PPMainTabBarItemsHelper showIconsOnlyOnTabBar:self.mainTabBar
                                               // items:self.itemsWithIconsOnly
                                            // animated:YES];
     }
    else{
        self.mainTabBar.layer.shadowOpacity = 0.08;
        self.mainTabBar.layer.shadowOffset = CGSizeMake(0, 4);
        self.mainTabBar.layer.shadowRadius = 10;
        
       // [PPMainTabBarItemsHelper showIconsAndTitlesOnTabBar:self.mainTabBar
                                                //     items:self.itemsWithIconsAndTitles
                                                 // animated:YES];
    }

    
    [UIView animateWithDuration:duration
                          delay:0
                        options:curve
                     animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
}
  
- (void)reloadUInterFace {
    
    topPadding = 0.0;
    bottomPadding = 0.0;
    [self getSafeAreaInsets:&topPadding bottomPadding:&bottomPadding];
    NSLog(@"Top Padding: %f", topPadding);
    NSLog(@"Bottom Padding: %f", bottomPadding);

     
    
    self.cellSection = CellSectionCards;
  
    [self cellSectionChanged];
    remainStringOne =kLang(@"remainStringOne");
    remainStringTwo =kLang(@"remainStringTwo");
  
    self.salesBTN.hx_x = 0;
    self.salesBTN.hx_y = 0;
                    
}


-(void)barCodeScannerTapped
{
    [ZXQRScanViewController startScanInViewController:self asPush:false autoDismiss:true callBack:^(NSString *result) {
        //[self searchStringWithBarCode:result];
        id foundObject = [self findObjectWithID:result];
        if (foundObject) {
            NSLog(@"Found object: %@", foundObject); // You will need to cast foundObject to its appropriate type
        } else {
            NSLog(@"Object not found");
        }
        
    }];
    
}
// MARK: - QrForCage CageCellDelegate BardCode
-(void)QrForID:(NSString *)barcodeString
{
    UIImage *barcodeImage = [BarcodeGenerator generateBarcode:barcodeString width:300 height:300]; // Desired width and height
                                                                                                   // Assuming you have a UIImage called 'myImage'
    FullscreenImageViewController *fullscreenVC = [[FullscreenImageViewController alloc] initWithImage:barcodeImage];
    fullscreenVC.modalPresentationStyle = UIModalPresentationAutomatic; // Ensure fullscreen presentation
    
    [PPFunc presentSheetFrom:self sheetVC:fullscreenVC detentStyle:PPSheetDetentStyleMediumOnly];
    
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [PPHUD dismiss];
    
    [[NSNotificationCenter defaultCenter]
           postNotificationName:PPShowSystemTabBarNotification
                         object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    if (@available(iOS 26.0, *)) { [self ios26Bar]; }
    else { [self ios15Bar]; }

   
    [[NSNotificationCenter defaultCenter]
           postNotificationName:PPHideSystemTabBarNotification
                         object:nil];
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClrDarker);
}

#pragma mark - Local Search View Control (NO PPS TOUCH)
- (void)onSearchTapped
{
    if (self.isSearchVisible) {
        [self hideSearchViewAnimated:YES];
    } else {
        [self showSearchViewAnimated:YES];
    }
}
- (void)showSearchViewAnimated:(BOOL)animated
{
    if (self.isSearchVisible) return;
    self.isSearchVisible = YES;

    self.searchView.hidden = NO;
    self.searchView.userInteractionEnabled = YES;

    CGFloat targetHeight = 56.0  ;

    UIEdgeInsets inset = self.collectionView.contentInset;
    inset.top += targetHeight;

    CGPoint offset = self.collectionView.contentOffset;
    offset.y -= targetHeight;   // 🔑 THIS IS THE FIX

    void (^changes)(void) = ^{
        self.searchView.alpha = 1.0;
        self.searchViewHeightConstraint.constant = targetHeight;
        self.collectionView.contentInset = inset;
        self.collectionView.scrollIndicatorInsets = inset;
        self.collectionView.contentOffset = offset;
        [self.view layoutIfNeeded];
    };

    [self runSearchAnimation:animated
                     changes:changes
                  completion:^(BOOL finished) {
        
        [self.searchView.textField becomeFirstResponder];
    }];
    [self updateSearchBarButtonStateAnimated:YES];
    
}

- (void)hideSearchViewAnimated:(BOOL)animated
{
    if (!self.isSearchVisible) return;
    self.isSearchVisible = NO;

    CGFloat height = self.searchViewHeightConstraint.constant;

    UIEdgeInsets inset = self.collectionView.contentInset;
    inset.top -= height;

    __weak typeof(self) weakSelf = self;
    void (^changes)(void) = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.searchView.alpha = 0.0;
        strongSelf.searchViewHeightConstraint.constant = 0;
        strongSelf.collectionView.contentInset = inset;
        strongSelf.collectionView.scrollIndicatorInsets = inset;
        [strongSelf.view layoutIfNeeded];
    };

    [self runSearchAnimation:animated changes:changes completion:^(BOOL finished) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.searchView.hidden = YES;
        [strongSelf.searchView.textField resignFirstResponder];
    }];
    
    [self updateSearchBarButtonStateAnimated:YES];
}

- (void)runSearchAnimation:(BOOL)animated
                   changes:(void (^)(void))changes
                completion:(void (^)(BOOL finished))completion
{
    if (!animated) {
        changes();
        if (completion) completion(YES);
        return;
    }

    [UIView animateWithDuration:0.28
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:changes
                     completion:completion];
}
- (void)ios26Bar {
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"showProdection") showBack:YES];
    self.navigationItem.rightBarButtonItems = @[FilterBTNBarButtonItem ,SearchBarButtonItem];
    self.navigationItem.rightBarButtonItem.tintColor = UIColor.labelColor;
    
 
}

- (void)setupActionsMenuoOnButton:(UIButton *)button {
    if (@available(iOS 14.0, *)) {
        __weak typeof(self) weakSelf = self;

        NSArray *titles = @[
            kLang(@"Add New Parrot Card"),
            kLang(@"Add New Archive"),
            kLang(@"addBox")
        ];

        NSArray *icons = @[
            [UIImage imageNamed:@"dogCus"] ?: [UIImage new],
            [UIImage imageNamed:@"archiveCus"] ?: [UIImage new],
            [UIImage imageNamed:@"love-birdsCus"] ?: [UIImage new]
        ];

 
        [PPMenuHelper presentMenuFromButton:button
                                     titles:titles
                                     images:icons
                               destructive:nil
                                   handler:^(NSInteger index, NSString *title) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;

            switch (index) {
                case 0: // Details
                    [self showAddNewCard];
                    break;
                case 1: // Call
                    [self addNewArchive];
                    break;
                case 2: // WhatsApp
                    [self showAddNewCage];
                    break;
                case 3: // Return
                  
                    break;
            }
        }];
    }
}

- (void)ios15Bar {
    UIButton *salesButton = [self pp_ButtonWithSystemName:@"plus" action:nil];
    [self setupActionsMenuoOnButton:salesButton];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:salesButton title:kLang(@"showProdection") showBack:YES];
    
}
//showFilter
-(void)secondRightTapped:(UIButton *)sender
{
    if(!UserManager.sharedManager.isUserLoggedIn) { [UserManager showPromptOnTopController]; return; }
    
    UserChatsViewController *vc = [[UserChatsViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
    
}



// MARK: - Afer Fetch
-(void)fetchDidComplete
{
    NSLog(@"MainController------->>>>>> fetchComplete");
  
}
 




// MARK: - Init Data
-(void)initialState
{

    segmTitles = [NSMutableArray new];
    
    [segmTitles addObject:kLang(@"Cards")];
    [segmTitles addObject:kLang(@"Boxes")];
    [segmTitles addObject:kLang(@"Archive")];
    [segmTitles addObject:kLang(@"Trash")];
    [segmTitles addObject:kLang(@"Buyer")];
    
    self.puaseAnimation = 0;
    self.userID = UserManager.sharedManager.currentUser.ID;
    self.currentLanguage = [[Language currentLanguageCode] mutableCopy];
    
    self.trachArray =       [NSMutableArray new];
    self.userCardsArray   = [NSMutableArray<CardModel *> new];
    self.UserArchivesDocs =     [NSMutableArray<ArchiveModel *>  new];
    self.SalesBuyerArr =     [NSMutableArray<BuyerModel *>  new];
    self.SubKindsArrayLocal =    [MKM getSubKindArray:1];
    
    [self setupConstraints];
    
    self.sort = [[NSUserDefaults standardUserDefaults] integerForKey:@"SortType"];
    if(!self.sort || self.sort == SortAsc)
    {
        [[NSUserDefaults standardUserDefaults] setInteger:SortAsc forKey:@"SortType"];
        [self sortAsc];
    }
    else if(self.sort == SortDesc)
        [self sortDesc];
    
}



// C48D69 #FFD2A6
- (void)topSegChanged:(NSInteger)index {
    [self saveScrollOffsetForCurrentSection];
    [PPEmptyStateHelper removeEmptyStateFromListView:self.collectionView];
    NSLog(@"Selected segment: %ld", index);
    NSInteger previousIndex = self.lastSegmentedIndex;
    if (previousIndex != NSIntegerMin && previousIndex != index) {
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventRootTabSelected];
    }
    self.lastSegmentedIndex = index;
    /*
     
     [self.anchorItemIDs removeObjectForKey:@(self.cellSection)];
     [self.anchorItemOffsets removeObjectForKey:@(self.cellSection)];
     */
    if(index == 3)
    {
        NSArray *titles = @[
            kLang(@"deletedFrom_cards"),
            kLang(@"deletedFrom_childs"),
            kLang(@"deletedFrom_archive"),
            kLang(@"allDeleted")
        ];
        
        NSArray *icons = @[
            [UIImage systemImageNamed:@"doc.text"] ?: [UIImage new],
            [UIImage systemImageNamed:@"tray"] ?: [UIImage new],
            [UIImage systemImageNamed:@"archivebox"] ?: [UIImage new],
            [UIImage systemImageNamed:@"trash"] ?: [UIImage new]
        ];
        
        [PPMenuHelper presentMenuFromButton:self.searchView.primaryButton
                                     titles:titles
                                     images:icons
                                destructive:nil
                                    handler:^(NSInteger index, NSString *title) {
            
            [PPHUD showLoading];
            
            if (index == 0) {
                self.trachArray =
                [[AppData.trashDocs filteredArrayUsingPredicate:
                  [NSPredicate predicateWithFormat:@"RefType == %ld", RefTypeCard]] mutableCopy];
            }
            else if (index == 1) {
                self.trachArray =
                [[AppData.trashDocs filteredArrayUsingPredicate:
                  [NSPredicate predicateWithFormat:@"RefType == %ld or RefType == %ld",
                   RefTypeChild,
                   RefTypeCage]] mutableCopy];
            }
            else if (index == 2) {
                self.trachArray =
                [[AppData.trashDocs filteredArrayUsingPredicate:
                  [NSPredicate predicateWithFormat:@"RefType == %ld", RefTypeArchive]] mutableCopy];
            }
            else {
                self.trachArray = AppData.trashDocs.mutableCopy;
            }
            
            [self applySnapshotAnimated:YES];
            [PPHUD dismiss];
        }];
        
    }
    else
        [self configureSearchSortMenu];
    
    if(index == 0)
        self.cellSection = CellSectionCards;
    if(index == 1)
        self.cellSection = CellSectionCage;
    if(index == 2)
        self.cellSection = CellSectionArchive;
    if(index == 3)
        self.cellSection = CellSectionTrash;
    if(index == 4)
        self.cellSection = CellSectionSalesBuyer;
    
    if (@available(iOS 16.4, *)) {
    }
    
    // Section switch ≠ data update
    [self.anchorItemIDs removeObjectForKey:@(self.cellSection)];
    [self.anchorItemOffsets removeObjectForKey:@(self.cellSection)];
    
    [self cellSectionChanged];
    [self didSwitchToSection:self.cellSection];
    
}

#pragma mark - Per-Section Scroll Memory

- (void)saveScrollOffsetForCurrentSection
{
    if (!self.collectionView) return;

    NSNumber *key = @(self.cellSection);
    CGFloat y = self.collectionView.contentOffset.y;

    CGFloat minY = -self.collectionView.adjustedContentInset.top;
    CGFloat maxY =
    MAX(minY,
        self.collectionView.contentSize.height
        - self.collectionView.bounds.size.height
        + self.collectionView.adjustedContentInset.bottom);

    y = MIN(MAX(y, minY), maxY);
    self.scrollOffsets[key] = @(y);
}
 
- (void)restoreScrollOffsetForCurrentSection
{
    NSNumber *key = @(self.cellSection);
    NSNumber *stored = self.scrollOffsets[key];
    if (!stored) return;

    CGFloat y = stored.doubleValue;

    CGFloat minY = -self.collectionView.adjustedContentInset.top;
    CGFloat maxY =
    MAX(minY,
        self.collectionView.contentSize.height
        - self.collectionView.bounds.size.height
        + self.collectionView.adjustedContentInset.bottom);

    y = MIN(MAX(y, minY), maxY);

    [self.collectionView setContentOffset:CGPointMake(0, y) animated:NO];
}


- (void)setupConstraints {
    // 1. Button Constraints
     
}

- (UICollectionViewLayout *)makeCollectionLayout
{
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.minimumLineSpacing = 14;
    layout.minimumInteritemSpacing = 14;
    layout.sectionInset = UIEdgeInsetsMake(22, 0, 90, 0);
    return layout;
}


#pragma mark - Set Collection
- (void)setupCollectionView
{
    if (self.collectionView) return;

    UICollectionViewLayout *layout = [self makeCollectionLayout];

    self.collectionView =
    [[UICollectionView alloc] initWithFrame:CGRectZero
                       collectionViewLayout:layout];

    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = AppClearClr;
    self.collectionView.alwaysBounceVertical = YES;


    self.collectionView.delegate = self;
    self.collectionView.prefetchingEnabled = YES;
    self.collectionView.prefetchDataSource = self;

    // Register cells
    [self.collectionView registerClass:PPBirdSummaryCollectionCell.class
            forCellWithReuseIdentifier:[PPBirdSummaryCollectionCell reuseIdentifier]];

    [self.collectionView registerClass:PPCageCell.class
            forCellWithReuseIdentifier:[PPCageCell reuseIdentifier]];

    [self.collectionView registerNib:[UINib nibWithNibName:@"ArchCell" bundle:nil]
          forCellWithReuseIdentifier:@"ArchCell"];

    [self.collectionView registerClass:TrashCollectionViewCell.class
          forCellWithReuseIdentifier:@"TrashCollectionViewCell"];

    [self.collectionView registerClass:SalesCell.class
            forCellWithReuseIdentifier:@"SalesCell"];

    [self.view addSubview:self.collectionView];
}

- (void)layoutCollectionView
{
    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)dropViewDidBeginRefreshing:(ODRefreshControl *)refreshControl
{
    NSLog(@"dropViewDidBeginRefreshing MyNameIsMohamedSamrau");
   
    double delayInSeconds = 1.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [refreshControl endRefreshing];
    });
}




// MARK: - Add Card Complete Notification
- (void)addCardComplete {
    NSLog(@"Start addCardComplete");;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"addCardComplete" object:nil];
}

 

// MARK: - Update Padding Values
- (void)getSafeAreaInsets:(CGFloat *)topPadding bottomPadding:(CGFloat *)bottomPadding {
    if (@available(iOS 11.0, *)) {
        UIWindow *window = [[[UIApplication sharedApplication] windows] firstObject]; // Get the first window
        if (window) { // Ensure the window is valid
            UIEdgeInsets safeAreaInsets = window.safeAreaInsets;
            *topPadding = safeAreaInsets.top;
            *bottomPadding = safeAreaInsets.bottom;
        } else {
            // Fallback if window is nil (unlikely in most cases)
            *topPadding = 20.0;
            *bottomPadding = 0.0;
            NSLog(@"Warning: Key window is nil. Using default safe area insets.");
        }
        
    } else {
        *topPadding = 20.0;
        *bottomPadding = 0.0;
    }
}


#pragma mark - actions
#pragma mark - <UICollectionViewDataSource>
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if(self.cellSection == CellSectionCards)
    {
        return self.userCardsArray.count;
    }
    else if (self.cellSection == CellSectionTrash)
    {
        return self.trachArray.count;
    }
    else if (self.cellSection == CellSectionArchive)
    {
        return self.UserArchivesDocs.count;
    }
    else if (self.cellSection == CellSectionSalesBuyer)
    {
        return self.SalesBuyerArr.count;
    }
    else
    {
        return self.CagedataSource.count;
    }
}
/*
 - (void)collectionView:(UICollectionView *)collectionView prefetchItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
 for (NSIndexPath *indexPath in indexPaths) {
 MyModel *model = self.items[indexPath.item];
 NSURL *url = [NSURL URLWithString:model.thumbnailURL];
 
 // Example: Start async download ahead of time
 [[ImageDownloader shared] prefetchImageWithURL:url];
 }
 } */
// MARK: - Cell For Item
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    switch (self.cellSection) {
        case CellSectionCards:
        {
            if (indexPath.row >= (NSInteger)self.userCardsArray.count) {
                return [collectionView dequeueReusableCellWithReuseIdentifier:[PPBirdSummaryCollectionCell reuseIdentifier] forIndexPath:indexPath];
            }
            CardModel *cardData = self.userCardsArray[indexPath.row];
            PPBirdSummaryCollectionCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[PPBirdSummaryCollectionCell reuseIdentifier]
                                                                                          forIndexPath:indexPath];
            cell.delegate = self;
            cell.cellIndexPath = indexPath;
            
            PPImageLoader loader = ^(UIImageView *iv,
                                     NSString *url,
                                     UIImage *ph,
                                     UIView *con) {
                [GM setImageFromUrlString:url imageView:iv phImage:@"placeholder3"];
                
            };
            
            [cell configureWithCard:cardData placeholder:[UIImage imageNamed:@"placeholder3"] RTL:Language.isRTL imageLoader:loader];
            cell.onTapGrid = ^{ NSLog(@"📦 grid tap"); };
            cell.onTapShare = ^{ NSLog(@"📤 share tap"); };
            return cell;
            
        }
            break;
            
        case CellSectionCage:
            return [self collectionViewCages:collectionView cellForItemAtIndexPath:indexPath];
            break;
            
        case CellSectionArchive:       //archive items:
            return [self collectionViewArchive:collectionView cellForItemAtIndexPath:indexPath];
            break;
            
        case CellSectionTrash:
            return [self collectionViewTrash:collectionView cellForItemAtIndexPath:indexPath];
            break;
            
        case CellSectionSalesBuyer:
            return [self collectionViewBuyer:collectionView cellForItemAtIndexPath:indexPath];
            break;
            
        default:
            return [self collectionViewTrash:collectionView cellForItemAtIndexPath:indexPath];
            break;
    }
}
- (UICollectionViewCell *)collectionViewBuyer:(UICollectionView *)collectionView
                 cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    SalesCell *cell =
    [collectionView dequeueReusableCellWithReuseIdentifier:@"SalesCell"
                                              forIndexPath:indexPath];

    BuyerModel *buyer = self.SalesBuyerArr[indexPath.row];
    CardModel  *card  = [self cardDataForID:buyer.birdID];

    [cell configureWithBuyer:buyer card:card];
    cell.delegate = self;

    return cell;
}

- (NSAttributedString *)attributedPrice:(NSString *)price
{
    NSString *p = price.length ? price : @"—";

    NSString *text =
    [NSString stringWithFormat:@"%@ %@", p, kLang(@"currency")];

    NSMutableAttributedString *att =
    [[NSMutableAttributedString alloc] initWithString:text];

    [att addAttributes:@{
        NSFontAttributeName: [GM boldFontWithSize:17],
        NSForegroundColorAttributeName: AppPrimaryClr
    } range:NSMakeRange(0, p.length)];

    return att;
}
    
-(CardModel *)cardDataForID:(NSString *)cardID{
    return  [[AppData.AllCardsDocs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID ==[c] %@",cardID]] firstObject];
}

- (NSString *)cardIDForTrashModel:(TrashModel *)trash
{
    if (!trash) return @"";
    if (trash.CardID.length) return trash.CardID;
    if (trash.RefType == RefTypeCard && trash.RefID.length) return trash.RefID;
    return @"";
}

- (CardModel *)localCardForTrashModel:(TrashModel *)trash
{
    NSString *cardID = [self cardIDForTrashModel:trash];
    if (!cardID.length) return nil;

    CardModel *card = [self cardDataForID:cardID];
    if (card) return card;

    NSPredicate *predicate =
    [NSPredicate predicateWithFormat:@"SELF.ID ==[c] %@", cardID];

    card = [[AppData.UserCardsDocs filteredArrayUsingPredicate:predicate] firstObject];
    if (card) return card;

    return [[self.userCardsArray filteredArrayUsingPredicate:predicate] firstObject];
}

- (void)showCardDetailsForTrashModel:(TrashModel *)trash
{
    if (!trash) return;

    CardModel *localCard = [self localCardForTrashModel:trash];
    if (localCard) {
        [self showViewer:localCard];
        return;
    }

    NSString *cardID = [self cardIDForTrashModel:trash];
    if (!cardID.length) {
        return;
    }

    [PPHUD showLoading];

    __weak typeof(self) weakSelf = self;
    FIRDocumentReference *cardRef =
    [[[FIRFirestore firestore] collectionWithPath:@"CardsCol"]
     documentWithPath:cardID];

    [cardRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot,
                                         NSError * _Nullable error)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [PPHUD dismiss];

            if (error || !snapshot.exists) {
                [weakSelf.dataManager showSnakBar:kLang(@"alertSubtitleError")
                                        withColor:[UIColor systemRedColor]
                                      andDuration:2
                                    containerView:weakSelf.view];
                return;
            }

            CardModel *remoteCard = [[CardModel alloc] initWithSnapshot:snapshot];
            if (!remoteCard) {
                [weakSelf.dataManager showSnakBar:kLang(@"alertSubtitleError")
                                        withColor:[UIColor systemRedColor]
                                      andDuration:2
                                    containerView:weakSelf.view];
                return;
            }

            [weakSelf showViewer:remoteCard];
        });
    }];
}

- (TrashModel *)trashModelForIndexPath:(NSIndexPath *)indexPath
{
    MainItem *item = [self.dataSource itemIdentifierForIndexPath:indexPath];
    if (!item) return nil;
    return (TrashModel *)item.model;
}


// MARK: - TrashCollectionViewCell
- (UICollectionViewCell *)collectionViewTrash:(UICollectionView *)collectionView
                      cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    TrashCollectionViewCell *cell =
    [collectionView dequeueReusableCellWithReuseIdentifier:@"TrashCollectionViewCell"
                                              forIndexPath:indexPath];
    TrashModel *trash = self.trachArray[indexPath.row];
    NSString *refTypeString = @"Unknown";
    switch (trash.RefType) {
        case RefTypeCard:    refTypeString = @"Card"; break;
        case RefTypeCage:    refTypeString = @"Cage"; break;
        case RefTypeChild:   refTypeString = @"Child"; break;
        case RefTypeArchive: refTypeString = @"Archive"; break;
    }
    /*NSLog(@"🗑️ Trash RefType = %@ (%ld) | RefID=%@ | CardID=%@ | title=%@", refTypeString, (long)trash.RefType,  trash.RefID,  trash.CardID, trash.title); */
    
    //NSLog(@"trash cardID %@",trash.cardID);
    cell.indexPath = indexPath;
    cell.delegate  = self;
    [cell configureWithTrash:trash];

    return cell;
}
// MARK: - ArchCell
- (UICollectionViewCell *)collectionViewArchive:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    ArchCell *cell;
    
    if ([Language languageVal] == 0) {
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"ArchCell" forIndexPath:indexPath];
    } else {
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"ArchCell" forIndexPath:indexPath];
    }
    
    cell.layer.cornerRadius = 28;
    cell.cellIndexPath = indexPath;
    if (indexPath.row >= (NSInteger)self.UserArchivesDocs.count) return cell;
    cell.archiveData = self.UserArchivesDocs[indexPath.row];
    
    cell.clipsToBounds = NO;
    cell.contentView.layer.cornerRadius = 28;
    cell.contentView.layer.masksToBounds = YES;
    cell.childRingID.text = [NSString stringWithFormat:@" %@ :     %@", kLang(@"ArchiveName"), self.UserArchivesDocs[indexPath.row].archiveTitle];
    cell.archiveDate.text = [NSString stringWithFormat:@" %@:     %@", kLang(@"CreateDate"), [[AppManager sharedInstance] managerStringfromDate:self.UserArchivesDocs[indexPath.row].archiveDate]];
    cell.childIndexPath = indexPath;
    
    
    ArchiveModel *archive = self.UserArchivesDocs[indexPath.row];

    cell.archiveCount.text =
        [NSString stringWithFormat:@"%@ :     %ld",
         kLang(@"ArchiveCardsCount"),
         archive.detailsCount];

    cell.isEmpty = archive.detailsCount == 0;
    
    
    cell.ID = self.UserArchivesDocs[indexPath.row].ID;
 

    cell.delegate = self;
    //cell.contentView.backgroundColor = [UIColor colorWithHexString:@"#ffffff"];
    cell.contentView.backgroundColor = AppForgroundColr;
    return cell;
}


- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];

    if (self.cellSection == CellSectionCards) {
        if (indexPath.row >= (NSInteger)self.userCardsArray.count) return;
        //CardsCell *call = [collectionView cellForItemAtIndexPath:indexPath];
        // call.videoPlayView.jp_muted = YES;
        //call.videoContainerView.jp_muted = YES;
        // [call.videoPlayView jp_stopPlay];
        // [call.videoContainerView jp_stopPlay];
        self.SelectItemAtIndexPath = indexPath;
        
        [self showViewer:self.userCardsArray[self.SelectItemAtIndexPath.row]];
        return;
    }

    if (self.cellSection == CellSectionTrash) {
        TrashModel *trash = [self trashModelForIndexPath:indexPath];
        if (!trash && indexPath.row < self.trachArray.count) {
            trash = self.trachArray[indexPath.row];
        }
        [self showCardDetailsForTrashModel:trash];
        return;
    }

    if (self.cellSection == CellSectionSalesBuyer) {
        if (indexPath.row >= (NSInteger)self.SalesBuyerArr.count) return;
        BuyerModel *buyer = self.SalesBuyerArr[indexPath.row];
        CardModel *card = [self cardDataForID:buyer.birdID];
        if (!card) return;

        [self showViewer:card];
        return;
    }
    
    if (self.cellSection == CellSectionArchive) {
        if (indexPath.row >= (NSInteger)self.UserArchivesDocs.count) return;
        selectArchiveVC *add =  [selectArchiveVC new];
        add.archiveClass = self.UserArchivesDocs[indexPath.row];
        add.cardsArray = self.allCardsArray;
        add.archiveArray = self.UserArchivesDocs;
       
        [PPFunc presentSheetFrom:self sheetVC:add detentStyle:PPSheetDetentStyleProfile];
        // [self presentViewController:add animated:YES completion:nil];
        return;
    }
}


// TESTEDsize


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


// MARK: - PPCageCell
- (UICollectionViewCell *)collectionViewCages:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PPCageCell *cell = [self dequeueCellForIndexPath:indexPath];
    CageModel *cageData = self.CagedataSource[indexPath.row];
    [cell configureWithCage:cageData];
    cell.delegate = self;
    return cell;
}

- (PPCageCell *)dequeueCellForIndexPath:(NSIndexPath *)indexPath {
    NSString *cellIdentifier = @"PPCageCell";
    PPCageCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:cellIdentifier forIndexPath:indexPath];
    
    [cell configureWithCage:[self.CagedataSource objectAtIndex:indexPath.row]];
    cell.delegate = self;
    return cell;
}

 

// MARK: - Size For Item
- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat cellWidth = collectionView.bounds.size.width - 28;

    switch (self.cellSection) {
        case CellSectionCards:
            return CGSizeMake(cellWidth, 260);
        case CellSectionTrash:
            return CGSizeMake(cellWidth, 110);
        case CellSectionArchive:
            return CGSizeMake(cellWidth - 0, 90);
        case CellSectionSalesBuyer:
            return CGSizeMake(cellWidth - 0, 200);
        case CellSectionCage:
            return CGSizeMake(cellWidth+10, 310);
        default:
            return CGSizeMake(cellWidth, 340);
    }
}

// Helper function to get the SubKind name (moved out of the cellForRowAtIndexPath method)
NSString* getSubKindName(NSInteger subKindID, NSArray<SubKindModel*> *subKindsArrayLocal) {
    for (SubKindModel *subKind in subKindsArrayLocal) {
        if (subKind.ID == subKindID) {
            return subKind.SubKindNameAr;
        }
    }
    return @""; // Return an empty string if not found or use your localized "not found" string.
}


-(void)shareCard:(long)rowIndex index:(long)index cardImage:(UIImage *)cardImage subKind:(NSString *)subKind cardID:(NSString *)cardID
{
    
    self.selectedCard = self.userCardsArray[rowIndex];
    self.selectedImage = cardImage;
    shareForIndex = index;
    if(index == 0)
    {
        shareFor = kLang(@"shareForReview");
        [self presentShareUserPicker];
    }
    if(index == 1)
    {
        shareFor = kLang(@"shareForLoan");
        [self presentShareUserPicker];
    }
    if(index == 2)
    {
        shareFor = kLang(@"shareForSell");
        [self presentShareUserPicker];
    }
    if(index == 3)
    {
        // Dismiss any existing presented VC (e.g. context menu) before sharing
        if (self.presentedViewController) {
            [self dismissViewControllerAnimated:NO completion:^{
                NSString *text = [NSString stringWithFormat:@"(%@) %@",self.selectedCard.RingID,self.selectedCard.CardTitle];
                UIImage *watermarkedImage =
                [GM setWatermarkImage:[UIImage imageNamed:@"logoImag"]
                              toImage:self.selectedImage ?: [UIImage imageNamed:@"placeholder3"]];
                NSData *imageData = UIImageJPEGRepresentation(watermarkedImage, 0.8);
                UIImage *img = [UIImage imageWithData:imageData] ?: watermarkedImage;
                [GM shareToWhatsApp:text sharingImage:img inViewController:self];
            }];
        } else {
            NSString *text = [NSString stringWithFormat:@"(%@) %@",self.selectedCard.RingID,self.selectedCard.CardTitle];
            UIImage *watermarkedImage =
            [GM setWatermarkImage:[UIImage imageNamed:@"logoImag"]
                          toImage:self.selectedImage ?: [UIImage imageNamed:@"placeholder3"]];
            NSData *imageData = UIImageJPEGRepresentation(watermarkedImage, 0.8);
            UIImage *img = [UIImage imageWithData:imageData] ?: watermarkedImage;
            [GM shareToWhatsApp:text sharingImage:img inViewController:self];
        }
    }
    if(index == 4)
    {
        NSLog(@"STORY ---->>>  SHARE --->>>>>> STARRT"); // Add this line
        NSArray<FileModel *> *files = self.selectedCard.FilesArray;
        NSString *imageURL = nil;

        if (files.count > 0) {
            imageURL = files.firstObject.FileUrl;
        }

        [GM setImageFromUrlString:imageURL
                        imageView:[[UIImageView alloc] init]
                          phImage:@"placeholder"
                        completion:^(UIImage * _Nullable image, NSError * _Nullable error) {
            NSLog(@"STORY ---->>> shareCard image loaded");
            dispatch_async(dispatch_get_main_queue(), ^{
                // continue share flow here
            });
        }];
        
        
    }
}

- (void)presentShareUserPicker
{
    NSArray<UserModel *> *users = PPUsersArr ?: @[];
    if (users.count == 0) {
        [[AppManager sharedInstance] showSnakBar:kLang(@"notFound")
                                       withColor:[GM appPrimaryColor]
                                     andDuration:3
                                   containerView:self.view];
        return;
    }

    __weak typeof(self) weakSelf = self;
    PPSelectOptionViewController *picker =
    [[PPSelectOptionViewController alloc] initWithOptions:users
                                                   title:shareFor ?: @""
                                                     row:nil
                                        presentationStyle:PPSelectOptionPresentationSheet
                                          showSearchBar:YES
                                               completion:^(id _Nullable selectedObject) {
        if (![selectedObject isKindOfClass:[UserModel class]]) {
            return;
        }
        [weakSelf selectUser:(UserModel *)selectedObject vcName:@"mainController"];
    }];

    picker.allOptions = users;
    picker.filteredOptions = users;
    picker.title = shareFor ?: @"";

    [PPFunc presentSheetFrom:self
                     sheetVC:picker
                 detentStyle:PPSheetDetentStyleProfile];
}

-(void)refreshView
{
    
}

- (void)deleteEditOptions:(long)index CardData:(CardModel *)card
{
    if (!card) return;

    switch (index) {

        case PPCardOptionEdit:
            [self openEditCard:card];
            return;

        case PPCardOptionDelete:
            [self confirmDeleteCard:card];
            return;

        case PPCardOptionQR:
            [self QrForID:card.ID];
            return;

        default:
            return;
    }
}
- (void)openEditCard:(CardModel *)card
{
    self.navigationController.delegate = self;

    NewCardForm *vc = [NewCardForm new];
    vc.FromVC = @"main";
    vc.serverCardClass = card;

    [self.navigationController pushViewController:vc animated:YES];
}
- (void)confirmDeleteCard:(CardModel *)card
{
    __weak typeof(self) weakSelf = self;

    [PPAlertHelper showTextFieldAlertIn:self
                                 title:kLang(@"DeleteCardAlert")
                              subtitle:kLang(@"DeleteCardAlertDesc")
                           placeholder:kLang(@"DeleteCardReason")
                           initialText:nil
                           confirmText:kLang(@"yes")
                            cancelText:kLang(@"cancel")
                            completion:^(NSString * _Nullable text, BOOL didConfirm)
    {
        if (!didConfirm) return;
        [weakSelf deleteCard:card reason:text ?: @""];
    }];
}

- (void)deleteCard:(CardModel *)card reason:(NSString *)reason
{
    if (!card.ID.length) return;

    [PPHUD showLoading];

    FIRFirestore *db = [FIRFirestore firestore];
    NSDate *now = [NSDate date];

    // ===============================
    // 1️⃣ Mark Card Deleted
    // ===============================
    FIRDocumentReference *cardRef =
    [[db collectionWithPath:@"CardsCol"] documentWithPath:card.ID];

    [cardRef updateData:@{
        @"isDeleted"    : @1,
        @"deleteReason" : PPSafeString(reason),
        @"lastUpdated"  : [FIRTimestamp timestampWithDate:now]
    } completion:^(NSError * _Nullable error)
    {
        if (error) {
            NSLog(@"❌ Card delete failed: %@", error);
            [PPHUD dismiss];
            return;
        }

        // ===============================
        // 2️⃣ Create Trash Model (SINGLE SOURCE)
        // ===============================
        ArchiveDetailsModel *archiveDetails = nil;
        if (card.cardSection == CardSectionArchive && card.archiveID.length) {
            archiveDetails = [ArchivesManager.shared cachedArchiveDetailByID:card.archiveID];
            if (!archiveDetails) {
                archiveDetails = [ArchiveDetailsModel new];
                archiveDetails.ID = card.archiveID;
                archiveDetails.masterArchiveID = PPSafeString(card.masterArchiveID);
                archiveDetails.CardID = card.ID;
                archiveDetails.UserID = PPSafeString(PPCurrentUser.ID);
            }
        }

        TrashModel *trash =
        [TrashModel trashFromCard:card
                            child:nil
                             cage:nil
                   archiveDetails:archiveDetails
                    archiveMaster:nil
                     deleteReason:reason];

        [[[db collectionWithPath:@"TrashCol"]
          documentWithPath:trash.ID]
         setData:[trash firestoreData]
         completion:^(NSError * _Nullable error)
        {
            if (error) {
                NSLog(@"❌ Trash insert failed: %@", error);
            }
        }];

        // ===============================
        // 3️⃣ Side Effects (Child / Archive)
        // ===============================
        [self applyDeleteSideEffectsForCard:card];

        // ===============================
        // 4️⃣ UI Feedback
        // ===============================
        [self.dataManager showSnakBar:kLang(@"DeletedSuccess")
                             withColor:[GM appPrimaryColor]
                          andDuration:3
                         containerView:self.view];

        [PPHUD dismiss];
    }];
}
- (void)applyDeleteSideEffectsForCard:(CardModel *)card
{
    if (card.cardSection == CardSectionNewChild) {

        [ChildsDataManager updateChildWithCardID:card.ID
                                          cageID:card.CageID
                                            data:@{ @"isDeleted": @1 }
                                       completion:^(NSError * _Nullable error)
        {
            if (error) {
                NSLog(@"❌ Child delete sync failed: %@", error);
            }
        }];
    }

    else if (card.cardSection == CardSectionArchive) {

        [self updateIsDeletedForArchiveID:card.masterArchiveID
                     andArchiveDetailsID:card.archiveID
                             withNewValue:1
                               completion:nil];
    }
}


// MARK: - Card Options
-(void)archiveCardData:(CardModel *)CardData cellIndexPath:(NSIndexPath *)cellIndexPath
{
    
    // ARCH
    NSString *title = kLang(@"deleteCard");
    NSString *subtitle = kLang(@"deleteCardTitle");
    NSString *msgTXT = kLang(@"deleteCardSucsses");
    UIImage *img = [UIImage imageNamed:@"trashOrg"];
    
    title = kLang(@"archiveCard");
    subtitle = kLang(@"archiveCardTitle");
    img = [UIImage imageNamed:@"archive"];
    msgTXT = kLang(@"archiveCardSucsses");
    
    cellToArchive = [self.collectionView cellForItemAtIndexPath:cellIndexPath];
    currentCellIndex = cellIndexPath;
    
    archiveCard = CardData;
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    ArchiveManagerVC *VC= [ArchiveManagerVC new];
    VC.cardToArchive =  CardData;
    VC.FromVC = 1;
    float archiveHeight = self.view.frame.size.height * 0.7;
    VC.archiveHeight = archiveHeight;
     
    
    [PPFunc presentSheetFrom:self sheetVC:VC detentStyle:PPSheetDetentStyleProfile];
    
}

// MARK: - Collection Data Changed
- (void)showArchive:(NSIndexPath *)cellIndexPath archiveClass:(ArchiveModel *)archiveClass haveArchive:(long)haveArchive CardData:(CardModel *)CardData {
    
    cellToArchive = [self.collectionView cellForItemAtIndexPath:cellIndexPath];
    currentCellIndex = cellIndexPath;
    archiveCard = CardData;
    
    if(CardData.cardSection != CardSectionCage)
    {
        if(haveArchive ==0)
        {
            cellToArchive = [self.collectionView cellForItemAtIndexPath:cellIndexPath];
            currentCellIndex = cellIndexPath;
        }
        
        float archiveHeight = self.view.frame.size.height * 0.7;;
        archiveCard = CardData;
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        ArchiveManagerVC *VC= [ArchiveManagerVC new];
        VC.cardToArchive =  CardData;
        VC.FromVC = 1;
        VC.archiveHeight = archiveHeight;
        
        [PPFunc presentSheetFrom:self sheetVC:VC detentStyle:PPSheetDetentStyleProfile];

    }
    else
    {
        selectArchiveVC *add= [selectArchiveVC new];
        add.archiveClass = archiveClass;
        add.UserArchivesDocs =self.UserArchivesDocs;
        add.cardsArray = self.allCardsArray;
        
        [PPFunc presentSheetFrom:self sheetVC:add detentStyle:PPSheetDetentStyle70];
        //[self presentViewController:add animated:YES completion:nil];
    }
    
}
 


/*
 // MARK: - didEndDisplayingCell
 - (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
 
 if (!self.playingCell) {
 return;
 }
 if (cell.hash == self.playingCell.hash) {
 [self.playingCell.videoPlayView jp_stopPlay];
 self.playingCell.playButton.hidden = NO;
 self.playingCell = nil;
 }
 }
 
 #pragma mark - JPVPNetEasyTableViewCellDelegate
 
 -(BOOL)shouldResumePlaybackFromPlaybackRecordForURL:(NSURL *)videoURL elapsedSeconds:(NSTimeInterval)elapsedSeconds
 {
 return true;
 }
 
 -(void)resumePlayMyVID
 {
 NSLog(@"resumePlayMyVID");
 [self.playingCell.videoPlayView jp_resume];
 
 }
 - (void)cellPlayButtonDidClick:(CollectionViewCell *)cell {
 
 if (self.firstVideoFrame.origin.x == 0) {
 self.firstVideoFrame = cell.mainImageView.frame;
 }
 
 if (self.playingCell) {
 [self.playingCell.videoPlayView jp_stopPlay];
 self.playingCell.playButton.hidden = NO;
 
 [self.playingCell resetVideoFrame];
 [self.playingCell layoutIfNeeded];
 [self.playingCell setNeedsLayout];
 [self.playingCell layoutSubviews];
 }
 // 1. Store the current cell
 self.playingCell = cell;
 
 // 3. Hide the play button (immediately now)
 self.playingCell.playButton.hidden = YES;
 
 // 4. Configure video player
 self.playingCell.videoPlayView.jp_videoPlayerDelegate = self;
 NSIndexPath *indexPath = [self.collectionView indexPathForCell:cell];
 [self.playingCell.videoPlayView jp_resumeMutePlayWithURL:[NSURL URLWithString:self.dataSource[indexPath.item].FilesArray[0].FileUrl] bufferingIndicator:nil progressView:nil configuration:^(UIView * _Nonnull view, JPVideoPlayerModel * _Nonnull playerModel) {
 
 }];
 return;
 }*/


- (void)showMessagesControllerWithChat:(ChatThreadModel *)chat
{
   if(!UserManager.sharedManager.isUserLoggedIn) { [UserManager showPromptOnTopController]; return; }
    
    UserChatsViewController *vc = [[UserChatsViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
    
    //[GM showMessagingWithChat:chat FromController:self];
}

 

- (void)howEmptyState {
    [self showEmptyStateAnimationNamed:@"Emptyred.json" title:kLang(@"archiveEmptyTitle") subTitle:kLang(@"archiveEmptyDesc")];
}


- (void)onRetryTapped {}
- (void)showEmptyStateAnimationNamed:(NSString *)animationName
                               title:(NSString *)title
                            subTitle:(NSString *)subTitle
{
    // Remove any previous instance if needed
    [self.emptyStateView removeFromSuperview];
    
    // Create the view
    self.emptyStateView = [[EmptyStateView alloc]
                           initWithFrame:CGRectZero
                           animationNamed:animationName
                           title:title
                           subTitle:subTitle
                           buttonTitle:nil
                           target:self
                           emptyIconSize:250
                           isNetworkFile:YES
                           action:@selector(onRetryTapped)];
    
    // Add to main view
    [self.view addSubview:self.emptyStateView];
    self.emptyStateView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // --- Constraints (centered + safe area aware) ---
    [NSLayoutConstraint activateConstraints:@[
        [self.emptyStateView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyStateView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.emptyStateView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [self.emptyStateView.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [self.emptyStateView.widthAnchor constraintLessThanOrEqualToAnchor:self.view.widthAnchor constant:-32]
    ]];
    
    // --- ✅ Animate Appearance ---
    self.emptyStateView.alpha = 0.0;
    self.emptyStateView.transform = CGAffineTransformMakeTranslation(0, 70); // slide-up start position
    
    [UIView animateWithDuration:0.4
                          delay:0
         usingSpringWithDamping:0.8
          initialSpringVelocity:0.5
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self.emptyStateView.alpha = 1.0;
        self.emptyStateView.transform = CGAffineTransformIdentity;
    } completion:nil];
    
}


-(void)sellThisCard:(CardModel *)card lastLocation:(NSInteger)location cageIndex:(NSInteger)idx
{
    if (self.presentedViewController && !self.presentedViewController.isBeingDismissed) {
        return;
    }

    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    self.navigationController.delegate = self;
    buyerDataVC *vc = [buyerDataVC new];
    vc.lastLocation =  location;
    vc.serverCardClass = card;
    
    PPNavigationController *navBar = [[PPNavigationController alloc]initWithRootViewController:vc];
    [navBar setModalInPresentation:NO];
    navBar.delegate = self;
    navBar.transitioningDelegate = self;
    [PPFunc presentSheetFrom:self sheetVC:navBar detentStyle:PPSheetDetentStyle70];
    return;
     
    
    
}




// MARK: - changeLanguageWithCode Delagate
- (void)changeLanguageWithCode:(int)code {
    self.currentLanguage = LanguageCode[code];
    [Language userSelectedLanguage:LanguageCode[code]];
    [Language userSelectedLanguage:self.currentLanguage];
    
    [self reloadUInterFace];
}

// ******************************************* Buttons

// MARK: - Buttons
// MARK: - chatsBTN
- (IBAction)chatsBTN:(id)sender {
}

// MARK: - Show Story Bar
- (IBAction)showdimmingViewBTN:(id)sender {
}


// MARK: - Show New ADS
-(void)showAddNewCard {
    if (self.navigationController.topViewController != self) {
        return;
    }
  
    self.navigationController.delegate = self;
    UIStoryboard *storyboard = self.storyboard ?: [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    NewCardForm *vc = [NewCardForm new];
    vc.FromVC = @"newAd";
    [self.navigationController pushViewController:vc animated:YES];

    
}


// MARK: - Show New ADS
-(void)showAddNewCage {
    if (self.presentedViewController && !self.presentedViewController.isBeingDismissed) {
        return;
    }
         // transition.startingPoint = button.center;
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    NewCageVC *VC = [NewCageVC new];
        VC.CagedataSource = self.CagedataSource;
    
    [PPFunc presentSheetFrom:self sheetVC:VC detentStyle:PPSheetDetentStyle70];
  
}

- (void)moreCardOptions:(long)rowIndex index:(long)index CardData:(CardModel *)CardData cellView:(UIView *)cellView cellIndexPath:(NSIndexPath *)cellIndexPath {
    NSLog(@"(void)moreCardOptions:(long)rowIndex index:(long)index CardData:(CardModel *)CardData cellView:(UIView *)cellView cellIndexPath:(NSIndexPath *)cellIndexPath");
}

- (void)addNewArchive {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    
    NSLog(@"ARCHIVE ---->>> MANAGER TEXTFIELD");
    [dateFormatter setDateFormat:@"dd/MM/yyyy"];
    // or @"yyyy-MM-dd hh:mm:ss a" if you prefer the time with AM/PM
    NSLocale *locale = [[NSLocale alloc]
                        initWithLocaleIdentifier:@"en"];
    [dateFormatter setLocale:locale];
    
    __block NSDate *archiveDate = [NSDate date];
    __block NSString *archiveTitle;
    //showTextFieldAlertIn if(!didConfirm) return;
    [PPAlertHelper showTextFieldAlertIn:self title:kLang(@"addArchiveTitle") subtitle:kLang(@"enterArchiveName") placeholder:kLang(@"enterArchiveName") initialText:nil confirmText:kLang(@"save") cancelText:kLang(@"cancel") completion:^(NSString * _Nullable text, BOOL didConfirm) {
        
        if(!didConfirm) return;
        archiveTitle =text;
        NSLog(@"ARCHIVE ---->>> %@",text);
        //return;
        [PPHUD showLoading];
 
        [dateFormatter setDateFormat:@"ddmmssSSS"];
        NSString *CreateDate = [dateFormatter stringFromDate:[NSDate date]];
        NSString *ID = [NSString stringWithFormat:@"ARC_%@_%@",
                        PPCurrentUser.ID,
                        CreateDate];
        NSDate *AddedDate = [NSDate date];
        
        NSMutableDictionary *Dic = [NSMutableDictionary new];
        [Dic setValue:ID forKey:@"ID"];
        [Dic setValue:archiveTitle forKey:@"archiveTitle"];
        [Dic setValue:archiveDate forKey:@"archiveDate"];
        [Dic setValue:PPCurrentUser.ID forKey:@"archiveOwnerID"];
        [Dic setValue:AddedDate forKey:@"CreateDate"];
        [Dic setValue:@0 forKey:@"isDeleted"];
        
        FIRFirestore *db = [FIRFirestore firestore];
        FIRCollectionReference *ref = [db collectionWithPath:@"ArchiveCol"];
        
        [[ref documentWithPath:ID] setData:Dic
                                completion:^(NSError *_Nullable error) {
            if (error != nil) {
                NSLog(@"ARCHIVE ---->>> MANAGER Error While Inser Doc %@",
                      error);
                return;
            }
            
            [PPHUD dismiss];
        }];
        
        [PPHUD dismiss];
        
        
    }];
   
}

- (id)findObjectWithID:(NSString *)searchID {
    
    NSPredicate *predicates = [NSCompoundPredicate orPredicateWithSubpredicates: @[ [NSPredicate predicateWithFormat:@"SELF.ID == %@",searchID]]];
    
    // Search in userCardsArray
    for (CardModel *card in self.userCardsArray) {
        if ([card.ID isEqualToString:searchID]) {
            //[self.topSeg setSelectedSegmentIndex:3];
            [self.mainTabBar setSelectedItem:self.cardsBarItem];
            dispatch_async(dispatch_get_main_queue(),
                           ^{
                self.cellSection = CellSectionCards;
                [self cellSectionChanged];
                self.userCardsArray = [AppData.UserCardsDocs filteredArrayUsingPredicate:predicates].mutableCopy;
                [self applySnapshotAnimated:YES];
            });
            return card;
        }
    }
    
    // Search in CagedataSource
    for (CageModel *cage in self.CagedataSource) {
        if ([cage.ID isEqualToString:searchID]) {
            self.cellSection = CellSectionCage;
            [self cellSectionChanged];
            [self.mainTabBar setSelectedItem:self.cagesBarItem];
            dispatch_async(dispatch_get_main_queue(),
                           ^{
                self.CagedataSource = [AppData.UserCaGeDocs filteredArrayUsingPredicate:predicates].mutableCopy;
                [self applySnapshotAnimated:YES];
            });
            return cage;
        }
    }
    
    for (ArchiveModel *archive in self.UserArchivesDocs) {
        if ([archive containsCardID:searchID]) {
            self.cellSection = CellSectionArchive;
            [self.mainTabBar setSelectedItem:self.archiveBarItem];
            return archive;
        }
    }
    
   /* // Search in archiveArray
    for (ArchiveModel *archive in self.UserArchivesDocs) {
        if ([archive.ID isEqualToString:searchID]) {
            self.cellSection = CellSectionArchive;
            [self cellSectionChanged];
            [self.mainTabBar setSelectedItem:self.archiveBarItem];
            dispatch_async(dispatch_get_main_queue(),
                           ^{
                self.UserArchivesDocs = [AppData.UserArchivesDocs filteredArrayUsingPredicate:predicates].mutableCopy;
                [self applySnapshotAnimated:YES];
            });
            return archive;
        }
    }
    */
    
    // Search in UserArchivesDocs
    for (BuyerModel *buyer in self.SalesBuyerArr) {
        if ([buyer.ID isEqualToString:searchID]) {
            self.cellSection = CellSectionSalesBuyer;
            [self cellSectionChanged];
            [self.mainTabBar setSelectedItem:self.salesBarItem];
            dispatch_async(dispatch_get_main_queue(),
                           ^{
                self.SalesBuyerArr = [AppData.BuyerArray filteredArrayUsingPredicate:predicates].mutableCopy;
                [self applySnapshotAnimated:YES];
            });
            return buyer;
        }
    }
    
    [[AppManager sharedInstance] showSnakBar:kLang(@"no_data_barcode") withColor:[GM appPrimaryColor] andDuration:5 containerView:self.collectionView];
    // If not found, return nil
    return nil;
}

// MARK: - update Data after Login
- (void)initalDataAferLogin
{
   // NSLog(@"initalDataAferLogin");
   // [[NSNotificationCenter defaultCenter] addObserver:self
                                           //  selector:@selector(fetchDidComplete)
                                                // name:@"fetchDidComplete"
                                            //   object:nil];
   //
    
}

-(void)updateUnreadsCount
{
}
// MARK: - updateUnreadsCount MessagesCount
 

// MARK: - selectUser to Start CHat
- (void)selectUser:(UserModel *)selectedUserClass vcName:(NSString *)vcName
{
    NSLog(@"self presentViewController:navBar animated:YES completion");
    [self startChatWith:selectedUserClass];
}

// MARK: - startChatWith SelectUser
- (void)startChatWith:(UserModel *)user {
    [GM chatWith:user FromController:self];
}


#pragma mark - Navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    [super prepareForSegue:segue sender:sender];
    
    
    if ([segue.identifier isEqualToString:@"MessageController"]) {
        NSLog(@"message.shareFormessage.shareFormessage.shareFormessage.shareFormessage.shareFor: %ld",
              shareForIndex);
        
    }
    
    if ([segue.identifier isEqualToString:@"ChatController"]) {
        //  UserChatsViewController *vc = [segue destinationViewController];
    }
    
    if ([segue.identifier isEqualToString:@"NewCardForm"]) {
        self.navigationController.delegate = self;
        NewCardForm *toVC = segue.destinationViewController;
        toVC.transitioningDelegate = self;
    }
    
    if ([segue.identifier isEqualToString:@"showNewCage"]) {
        NewCageVC *VC = [segue destinationViewController];
        VC.CagedataSource = self.CagedataSource;
    }
    
    if ([segue.identifier isEqualToString:@"showViewData"]) {
        viewDataVC *VC = [segue destinationViewController];
        VC.cardModel = self.userCardsArray[self.SelectItemAtIndexPath.row];
    }
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    id<UIViewControllerAnimatedTransitioning> animationController;
    NSLog(@"animationControllerForDismissedController");

    return animationController;
}

// MARK: - Filter Card By SubKinds
/*
 
 */
- (void)collectionView:(UICollectionView *)collectionView
 prefetchItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    if (self.cellSection != CellSectionCards) {
        return;
    }
    
    for (NSIndexPath *indexPath in indexPaths) {
        if (indexPath.item >= self.userCardsArray.count) {
            continue;
        }
        
        CardModel *card = self.userCardsArray[indexPath.item];
        
        // Use whatever you use inside configureWithCard to get main image URL
        NSString *imageURLString = card.imagesUrlsStrings.firstObject ?: @""; // or [card mainImageURL], etc.
        if (imageURLString.length == 0) {
            //NSLog(@"[Prefetch] imageURLString not exist for card %@ ",card.ID);
            continue;
        }
        
        
        
        NSURL *url = [NSURL URLWithString:imageURLString];
        if (!url || [self.prefetchingURLs containsObject:url])
        {
            //NSLog(@"[Prefetch] Already Prefetched %ld",indexPath.item);
            continue;
        }
        [self.prefetchingURLs addObject:url];
        //NSLog(@"[Prefetch] imageURLString %@ ",imageURLString);
        [[SDWebImagePrefetcher sharedImagePrefetcher]
         prefetchURLs:@[url]
         progress:nil
         completed:^(NSUInteger finished, NSUInteger skipped) {
             [self.prefetchingURLs removeObject:url];
         }];
    }
}

 

// MARK: - TrashCollectionViewCellDelegate

#pragma mark - TrashCollectionViewCellDelegate

- (void)trashRestore:(TrashModel *)trash
{
 
    [PPAlertHelper showConfirmationIn:self
                                title:kLang(@"RestoreItem")
                             subtitle:kLang(@"RestoreItemDesc")
                        confirmButton:kLang(@"Restore")
                         cancelButton:kLang(@"Cancel")
                                 icon:PPSYSImage(@"arrow.up.trash")
                         confirmBlock:^(NSString * _Nullable text, BOOL didConfirm)
    {
        if (!didConfirm) return;
        [PPHUD showLoading];
        [self restoreTrashItem:trash];
    } cancelBlock:^{}];
}



- (void)trashCellDidTapDeleteForever:(NSIndexPath *)indexPath
{
    if (!indexPath || indexPath.row >= self.trachArray.count) return;

    TrashModel *trash = self.trachArray[indexPath.row];

    [PPAlertHelper showConfirmationIn:self
                                title:kLang(@"DeleteForever")
                             subtitle:kLang(@"DeleteForeverDesc")
                        confirmButton:kLang(@"Delete")
                         cancelButton:kLang(@"Cancel")
                                 icon:PPSYSImage(@"trash")
                         confirmBlock:^(NSString * _Nullable text, BOOL didConfirm)
    {
        if (!didConfirm) return;

        FIRFirestore *db = [FIRFirestore firestore];
        FIRWriteBatch *batch = [db batch];

        // ===============================
        // 1️⃣ DELETE TARGET PERMANENTLY
        // ===============================

        switch (trash.RefType) {

            case RefTypeCard: {
                FIRDocumentReference *cardRef =
                [[db collectionWithPath:@"CardsCol"]
                 documentWithPath:trash.CardID];

                [batch deleteDocument:cardRef];
            } break;

            case RefTypeChild: {
                if (trash.CageID.length && trash.RefID.length) {
                    FIRDocumentReference *childRef =
                    [[[[db collectionWithPath:@"CagesCol"]
                       documentWithPath:trash.CageID]
                      collectionWithPath:@"ChildsCol"]
                     documentWithPath:trash.RefID];

                    [batch deleteDocument:childRef];
                }
            } break;

            case RefTypeArchive: {

                if (trash.masterArchiveID.length && trash.RefID.length) {

                    FIRDocumentReference *detailsRef =
                    [[[[db collectionWithPath:@"ArchiveCol"]
                       documentWithPath:trash.masterArchiveID]
                      collectionWithPath:@"ArchiveDetailsCol"]
                     documentWithPath:trash.RefID];

                    [batch deleteDocument:detailsRef];

                } else {
                    NSLog(@"⚠️ Skip permanent delete ArchiveDetails (invalid IDs) master=%@ ref=%@",
                          trash.masterArchiveID, trash.RefID);
                }

            }  break;

            default:
                break;
        }

        // ===============================
        // 2️⃣ DELETE TRASH RECORD
        // ===============================
        FIRDocumentReference *trashRef =
        [[db collectionWithPath:@"TrashCol"]
         documentWithPath:trash.ID];

        [batch deleteDocument:trashRef];

        // ===============================
        // 3️⃣ COMMIT
        // ===============================
        __weak typeof(self) weakSelf = self;

        [batch commitWithCompletion:^(NSError * _Nullable error) {

            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    NSLog(@"❌ Permanent delete failed: %@", error);
                    return;
                }

                NSLog(@"🗑️ Permanently deleted %@", trash.ID);

                [weakSelf.dataManager showSnakBar:kLang(@"DeletedPermanently")
                                         withColor:[UIColor systemRedColor]
                                      andDuration:3
                                     containerView:weakSelf.view];

                [[NSNotificationCenter defaultCenter]
                 postNotificationName:@"trashUpdated"
                 object:nil];
            });
        }];
    } cancelBlock:^{}];
}

- (void)restoreAllTrash
{
    for (TrashModel *trash in self.trachArray) {
        [self restoreTrashItem:trash];
    }
}

#pragma mark - Trash Restore (FINAL – Subcollection Safe)

- (void)restoreTrashItem:(TrashModel *)trash
{
    FIRFirestore *db = [FIRFirestore firestore];
    FIRWriteBatch *batch = [db batch];
    NSDate *now = [NSDate date];
    FIRTimestamp *nowTS = [FIRTimestamp timestampWithDate:now];

    // ===============================
    // 0️⃣ VALIDATION (HARD SAFETY)
    // ===============================
    if (!trash.ID.length || !trash.RefID.length) {
        NSLog(@"❌ Restore aborted: invalid trash identifiers %@", trash);
        [PPHUD dismiss];
        return;
    }

    // ===============================
    // 1️⃣ RESTORE CARD (SAFE)
    // ===============================
    if (trash.CardID.length) {

        FIRDocumentReference *cardRef =
        [[db collectionWithPath:@"CardsCol"]
         documentWithPath:trash.CardID];

        NSMutableDictionary *cardUpdate = [@{
            @"isDeleted"     : @0,
            @"deleteReason"  : @"",
            @"lastUpdated"   : nowTS
        } mutableCopy];

        [batch updateData:cardUpdate forDocument:cardRef];
    }

    // ===============================
    // 2️⃣ RESTORE CHILD (SAFE)
    // ===============================
    if (trash.RefType == RefTypeChild &&
        trash.CageID.length &&
        trash.RefID.length)
    {
        FIRDocumentReference *childRef =
        [[[[db collectionWithPath:@"CagesCol"]
           documentWithPath:trash.CageID]
          collectionWithPath:@"ChildsCol"]
         documentWithPath:trash.RefID];

        [batch updateData:@{
            @"isDeleted"   : @0,
            @"lastUpdated" : nowTS
        } forDocument:childRef];
    }

    // ===============================
    // 3️⃣ RESTORE ARCHIVE DETAIL (FULLY BATCHED)
    // ===============================
    if (trash.RefType == RefTypeArchive &&
        trash.masterArchiveID.length &&
        trash.RefID.length)
    {
        // Card
        if (trash.CardID.length) {
            FIRDocumentReference *cardRef =
            [[db collectionWithPath:@"CardsCol"]
             documentWithPath:trash.CardID];

            [batch updateData:@{
                @"isDeleted"   : @0,
                @"lastUpdated" : nowTS
            } forDocument:cardRef];
        }

        // Archive Details
        FIRDocumentReference *detailsRef =
        [[[[db collectionWithPath:@"ArchiveCol"]
           documentWithPath:trash.masterArchiveID]
          collectionWithPath:@"ArchiveDetailsCol"]
         documentWithPath:trash.RefID];

        [batch updateData:@{
            @"isDeleted"   : @0,
            @"lastUpdated" : nowTS
        } forDocument:detailsRef];
    }

    // ===============================
    // 4️⃣ REMOVE TRASH RECORD (ALWAYS)
    // ===============================
    FIRDocumentReference *trashRef =
    [[db collectionWithPath:@"TrashCol"]
     documentWithPath:trash.ID];

    [batch deleteDocument:trashRef];

    // ===============================
    // 5️⃣ COMMIT (ATOMIC)
    // ===============================
    __weak typeof(self) weakSelf = self;

    [batch commitWithCompletion:^(NSError * _Nullable error) {

        dispatch_async(dispatch_get_main_queue(), ^{

            [PPHUD dismiss];

            if (error) {
                NSLog(@"❌ Restore failed for trash %@ : %@", trash.ID, error);
                return;
            }

            // ===============================
            // POST-SYNC COUNTS (SAFE)
            // ===============================
            if ((trash.RefType == RefTypeChild ||
                 trash.RefType == RefTypeCard) &&
                trash.CageID.length &&
                trash.CardID.length) {

                // If a new-child card was deleted as RefTypeCard, restore its child soft-delete as well.
                [ChildsDataManager updateChildWithCardID:trash.CardID
                                                  cageID:trash.CageID
                                                    data:@{
                    @"isDeleted" : @0,
                    @"lastUpdated" : nowTS
                } completion:^(NSError * _Nullable error) {
                    
                }];
            }

            if (trash.CageID.length) {

                [ChildsDataManager syncDetailsCountForCageID:trash.CageID
                                                  completion:^(NSError * _Nullable error) {
                    
                }];
            }

            if (trash.RefType == RefTypeArchive &&
                trash.masterArchiveID.length) {

                [ArchivesManager.shared
                 syncDetailsCountForArchiveID:trash.masterArchiveID];
            }

            NSLog(@"✅ Restored from trash safely: %@", trash.RefID);

            [weakSelf.dataManager showSnakBar:kLang(@"RestoreSuccess")
                                     withColor:[GM appPrimaryColor]
                                  andDuration:3
                                 containerView:weakSelf.view];
        });
    }];
}


- (TrashModel *)trashByID:(NSString *)trashID
{
    for (TrashModel *t in self.trachArray) {
        if ([t.ID isEqualToString:trashID]) {
            return t;
        }
    }
    return nil;
}
- (void)onFilterTapped {
    // Deprecated — filter now handled by primary menu
}
- (void)setupSearchViewIfNeeded {
    if (self.searchView) return;

    PPS *search = [[PPS alloc] initWithFrame:CGRectZero];
    search.translatesAutoresizingMaskIntoConstraints = NO;
    search.delegate = (id<PPSDelegate>)self;

    search.blurEnabled = YES;
    search.shadowEnabled = NO;
    search.debounceInterval = 0.16;
    search.fuzzyEnabled = YES;
    search.caseInsensitive = NO;
    search.diacriticsInsensitive = NO;
    search.minRelevanceScore = 0.35;
    search.maxResults = 100;
   
    search.backgroundColor = AppClearClr;

    // Buttons
    //UIImage *fil = [UIImage systemImageNamed:@"line.3.horizontal.decrease.circle"];
    //[_vc.searchView configurePrimaryButtonWithImage:fil target:self action:@selector(onFilterTapped:)];
    search.showsPrimaryButton = YES;
    search.showsSecondaryButton = NO;

    // Localization
    search.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

     search.glassAlpha = 1.0;
    search.returnKeyType = UIReturnKeySearch;
 
     search.textField.placeholder = kLang(@"SearchBirdsPlaceholder");
    
    UIImage *sortImage = [UIImage pp_symbolNamed:@"circle.grid.2x2.topleft.checkmark.filled" pointSize:18 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleLarge palette:@[UIColor.grayColor,AppPrimaryClr] makeTemplate:YES];
    
    // you can access Primary at  search.btn1
    [search configurePrimaryButtonWithImage:sortImage
                                     target:nil
                                     action:nil];

    search.showsPrimaryButton = YES;
  
    //search.textField.delegate = self;
    
     [[IQKeyboardManager sharedManager].disabledToolbarClasses addObject:self.class];
  
    
    [self.view addSubview:search];
    self.searchView = search;
    
    // [self restoreSortAndFilter];
     [self configureSearchSortMenu];
     
     self.searchViewHeightConstraint =
         [self.searchView.heightAnchor constraintEqualToConstant:0];

    self.mainTabBarTopConstraint =
    [self.mainTabBar.topAnchor constraintEqualToAnchor:self.searchView.bottomAnchor constant:8];
    float inset = PPIOS26() ? 20 : 16;
         [NSLayoutConstraint activateConstraints:@[
            [self.searchView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:inset],
            [self.searchView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-inset],
             [self.searchView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
             self.searchViewHeightConstraint,
            
            self.mainTabBarTopConstraint
         ]];
    self.searchView.clipsToBounds = YES;
    self.searchView.cornerRadius = 28.0;
    //[self configureSearchSortMenu];
   
}

#pragma mark - Multi Token Match

- (BOOL)allTokens:(NSArray<NSString *> *)tokens
      matchValues:(NSArray<NSString *> *)values
{
    for (NSString *token in tokens) {

        BOOL matched = NO;
        NSArray *variants = [self tokenVariants:token];

        for (NSString *v in values) {
            if (!v.length) continue;

            NSString *normValue = [self normalizedSearchString:v];

            for (NSString *variant in variants) {
                NSString *normToken = [self normalizedSearchString:variant];

                if ([normValue containsString:normToken]) {
                    matched = YES;
                    break;
                }
            }

            if (matched) break;
        }

        if (!matched) return NO; // AND logic
    }

    return YES;
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Search Tokenization

- (NSArray<NSString *> *)searchTokensFromText:(NSString *)text
{
    if (!text.length) return @[];

    // Split by spaces, remove empties
    NSArray *raw =
    [text componentsSeparatedByCharactersInSet:
     [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSMutableArray *tokens = [NSMutableArray array];
    for (NSString *t in raw) {
        NSString *trim = [t stringByTrimmingCharactersInSet:
                          [NSCharacterSet whitespaceCharacterSet]];
        if (trim.length > 0) {
            [tokens addObject:trim];
        }
    }
    return tokens;
}
#pragma mark - Weighted Search Scoring

#pragma mark - Weighted Relevance (Multi Token)

- (NSInteger)relevanceScoreForTokens:(NSArray<NSString *> *)tokens
                                ring:(NSString *)ring
                                name:(NSString *)name
                               phone:(NSString *)phone
                               extra:(NSArray<NSString *> *)extra
{
    NSInteger score = 0;

    for (NSString *t in tokens) {

        if (ring.length &&
            [ring localizedCaseInsensitiveContainsString:t]) {
            score += 100;
            continue;
        }

        if (name.length &&
            [name localizedCaseInsensitiveContainsString:t]) {
            score += 60;
            continue;
        }

        if (phone.length &&
            [phone localizedCaseInsensitiveContainsString:t]) {
            score += 40;
            continue;
        }

        for (NSString *e in extra) {
            if (e.length &&
                [e localizedCaseInsensitiveContainsString:t]) {
                score += 15;
                break;
            }
        }
    }

    return score;
}

// ⚠️ DEPRECATED — replaced by applySortAndFilter + unified menu
- (void)filterCardsBySubKind:(NSString *)subKind {
    if (!subKind.length) return;

    NSPredicate *predicate =
    [NSPredicate predicateWithFormat:@"subKindString ==[c] %@", subKind];

    self.userCardsArray =
    [[AppData.UserCardsDocs filteredArrayUsingPredicate:predicate] mutableCopy];

    [self applySnapshotAnimated:YES];
}
// ⚠️ DEPRECATED — replaced by applySortAndFilter + unified menu
- (UIMenu *)buildSubKindFilterMenu {
    __weak typeof(self) weakSelf = self;

    // ===== Collect unique subKinds =====
    NSMutableOrderedSet<NSString *> *uniqueSubKinds = [NSMutableOrderedSet orderedSet];

    for (CardModel *card in self.userCardsArray) {
        if (card.subKindString.length) {
            [uniqueSubKinds addObject:card.subKindString];
        }
    }

    NSMutableArray<UIMenuElement *> *actions = [NSMutableArray array];

    // ===== Reset (All) =====
    UIAction *allAction =
    [UIAction actionWithTitle:kLang(@"FilterAllBirds")
                        image:[UIImage systemImageNamed:@"tray.full"]
                   identifier:nil
                      handler:^(__kindof UIAction * _Nonnull action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        [self restoreCurrentDataSource];
        [self applySnapshotAnimated:YES];
    }];

    [actions addObject:allAction];

    // ===== SubKind actions =====
    for (NSString *subKind in uniqueSubKinds) {
        UIAction *action =
        [UIAction actionWithTitle:subKind
                            image:[UIImage systemImageNamed:@"leaf"]
                       identifier:nil
                          handler:^(__kindof UIAction * _Nonnull action) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;

            [self filterCardsBySubKind:subKind];
        }];

        [actions addObject:action];
    }

    // ===== Menu =====
    UIMenu *menu =
    [UIMenu menuWithTitle:kLang(@"FilterByBreedTitle")
                    image:nil
               identifier:nil
                  options:0
                 children:actions];

    return menu;
}

- (BOOL)didInitialLoad {
  NSNumber *boxed = objc_getAssociatedObject(self, @selector(didInitialLoad));
  return boxed.boolValue;
}

- (void)setDidInitialLoad:(BOOL)didInitialLoad
{
  NSNumber *boxed = @(didInitialLoad);
  objc_setAssociatedObject(self, @selector(didInitialLoad), boxed, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - PPSDelegate


- (void)searchViewDidBeginEditing:(PPS *)view {
    // optional
    
 }

- (void)searchViewDidEndEditing:(PPS *)view {
    if (view.textField.text.length == 0) {
         [self restoreCurrentDataSource];
         [self applySnapshotAnimated:YES];
    }
}

- (void)searchView:(PPS *)view didChangeText:(NSString *)text
{
    
    self.activeSearchText = text;
    
    if (!text.length) {
        [self updateSearchBadgesForText:nil];
        [self restoreCurrentDataSource];
        [self applySnapshotAnimated:YES];
        return;
    }

    // 🔔 Global badge counts (ALL sections)
    [self updateSearchBadgesForText:text];

    // 🎯 Filter ONLY current section
    [self searchString:text];
}

- (void)searchViewDidSubmit:(PPS *)view
{
    [view unfocus];

    if (view.textField.text.length > 0) {
        [self updateSearchBadgesForText:view.textField.text];
        [self searchString:view.textField.text];
    }
    else if (view.textField.text.length == 0)
    {
     }
}

#pragma mark - Tab Auto Search Apply

- (void)didSwitchToSection:(CellSection)newSection
{
    self.cellSection = newSection;
   
    
    if (self.activeSearchText.length > 0) {
        // Re-apply same search text to the new section
        [self searchString:self.activeSearchText];
    } else {
        [self restoreCurrentDataSource];
        [self applySnapshotAnimated:YES];
    }
}

-(void)searchBarCancelButtonClicked:(PPS *)searchBar
{
    [self updateSearchBadgesForText:nil];

    searchBar.textFieldSearchBar.text = @"";
    [searchBar.textFieldSearchBar setShowsCancelButton:NO animated:YES];
    [searchBar resignFirstResponder];
    [self restoreCurrentDataSource];
    [self applySnapshotAnimated:YES];
}
#pragma mark - Search Normalization

- (NSString *)normalizedSearchString:(NSString *)s
{
    if (!s.length) return @"";

    NSString *r = s.lowercaseString;

    // unify separators
    r = [r stringByReplacingOccurrencesOfString:@"-" withString:@""];
    r = [r stringByReplacingOccurrencesOfString:@"_" withString:@""];
    r = [r stringByReplacingOccurrencesOfString:@" " withString:@""];

    return r;
}
- (NSArray<NSString *> *)tokenVariants:(NSString *)token
{
    if (!token.length) return @[];

    NSString *t = token.lowercaseString;

    return @[
        t,
        [t stringByReplacingOccurrencesOfString:@"-" withString:@""],
        [t stringByReplacingOccurrencesOfString:@"_" withString:@""],
        [t stringByReplacingOccurrencesOfString:@" " withString:@""]
    ];
}
#pragma mark - Global Search Badges (All Sections)
- (void)searchString:(NSString *)text
{
    if (!text.length) {
        [self restoreCurrentDataSource];
        [self updateSearchBadgesForText:nil];
        [self applySnapshotAnimated:YES];
        return;
    }

    // 🔔 Update tab badges for ALL sections
    [self updateSearchBadgesForText:text];

    switch (self.cellSection) {

        case CellSectionCards: {

            NSArray *tokens = [self searchTokensFromText:text];

            NSMutableArray<CardModel *> *results = [NSMutableArray array];

            for (CardModel *c in AppData.UserCardsDocs) {

                if (![self allTokens:tokens
                         matchValues:@[
                             c.RingID ?: @"",
                             c.CardTitle ?: @"",
                             c.subKindString ?: @""
                         ]]) {
                    continue;
                }

                [results addObject:c];
            }

            [results sortUsingComparator:^NSComparisonResult(CardModel *a, CardModel *b) {

                NSInteger sa =
                [self relevanceScoreForTokens:tokens
                                         ring:a.RingID
                                         name:a.CardTitle
                                        phone:nil
                                        extra:@[a.subKindString ?: @""]];

                NSInteger sb =
                [self relevanceScoreForTokens:tokens
                                         ring:b.RingID
                                         name:b.CardTitle
                                        phone:nil
                                        extra:@[b.subKindString ?: @""]];

                if (sa != sb) return sb > sa ? NSOrderedAscending : NSOrderedDescending;
                return [b.AddedDate compare:a.AddedDate];
            }];

            self.userCardsArray = results;
        } break;

        case CellSectionCage: {
            NSPredicate *p =
            [NSPredicate predicateWithFormat:
             @"CageName CONTAINS[cd] %@",
             text];

            self.CagedataSource =
            [[AppData.UserCaGeDocs filteredArrayUsingPredicate:p] mutableCopy];
        } break;

        case CellSectionArchive: {
            NSPredicate *p =
            [NSPredicate predicateWithFormat:
             @"archiveTitle CONTAINS[cd] %@",
             text];

            self.UserArchivesDocs =
            [[AppData.UserArchivesDocs filteredArrayUsingPredicate:p] mutableCopy];
        } break;

        case CellSectionTrash: {
            NSPredicate *p =
            [NSPredicate predicateWithFormat:
             @"title CONTAINS[cd] %@ OR CardID CONTAINS[cd] %@",
             text, text];

            self.trachArray =
            [[AppData.trashDocs filteredArrayUsingPredicate:p] mutableCopy];
        } break;

        case CellSectionSalesBuyer: {

            NSArray *tokens = [self searchTokensFromText:text];
            NSMutableArray<BuyerModel *> *results = [NSMutableArray array];

            for (BuyerModel *b in AppData.BuyerArray) {

                CardModel *card = [self cardDataForID:b.birdID];

                NSString *price = [NSString stringWithFormat:@"%@", b.buyerPrice ?: @""];
                NSString *date  = b.sellDate ? [GM formatDateFromDate:b.sellDate] : @"";

                NSArray *values = @[
                    b.buyerName ?: @"",
                    b.buyerMobile ?: @"",
                    price,
                    card.RingID ?: @"",
                    card.CardTitle ?: @"",
                    date
                ];

                if (![self allTokens:tokens matchValues:values]) {
                    continue;
                }

                [results addObject:b];
            }

            [results sortUsingComparator:^NSComparisonResult(BuyerModel *a, BuyerModel *b) {

                CardModel *ca = [self cardDataForID:a.birdID];
                CardModel *cb = [self cardDataForID:b.birdID];

                NSInteger sa =
                [self relevanceScoreForTokens:tokens
                                         ring:ca.RingID
                                         name:a.buyerName
                                        phone:a.buyerMobile
                                        extra:@[
                                            ca.CardTitle ?: @"",
                                            a.buyerPrice ?: @""
                                        ]];

                NSInteger sb =
                [self relevanceScoreForTokens:tokens
                                         ring:cb.RingID
                                         name:b.buyerName
                                        phone:b.buyerMobile
                                        extra:@[
                                            cb.CardTitle ?: @"",
                                            b.buyerPrice ?: @""
                                        ]];

                if (sa != sb) return sb > sa ? NSOrderedAscending : NSOrderedDescending;
                return [b.sellDate compare:a.sellDate];
            }];

            self.SalesBuyerArr = results;
        } break;
    }

    [self applySnapshotAnimated:YES];
}
- (void)updateSearchBadgesForText:(NSString *)text
{
    if (!text.length) {
        self.cardsBarItem.badgeValue   = nil;
        self.cagesBarItem.badgeValue   = nil;
        self.archiveBarItem.badgeValue = nil;
        self.trashBarItem.badgeValue   = nil;
        self.salesBarItem.badgeValue   = nil;
        return;
    }

    NSPredicate *cardsP =
    [NSPredicate predicateWithFormat:
     @"CardTitle CONTAINS[cd] %@ OR RingID CONTAINS[cd] %@",
     text, text];

    NSPredicate *cagesP =
    [NSPredicate predicateWithFormat:
     @"CageName CONTAINS[cd] %@",
     text];

    NSPredicate *archivesP =
    [NSPredicate predicateWithFormat:
     @"archiveTitle CONTAINS[cd] %@",
     text];

    NSPredicate *trashP =
    [NSPredicate predicateWithFormat:
     @"title CONTAINS[cd] %@ OR CardID CONTAINS[cd] %@",
     text, text];

    NSPredicate *buyersP =
    [NSPredicate predicateWithFormat:
     @"buyerName CONTAINS[cd] %@ OR buyerMobile CONTAINS[cd] %@",
     text, text];

    NSInteger cards    = [AppData.UserCardsDocs filteredArrayUsingPredicate:cardsP].count;
    NSInteger cages    = [AppData.UserCaGeDocs filteredArrayUsingPredicate:cagesP].count;
    NSInteger archives = [AppData.UserArchivesDocs filteredArrayUsingPredicate:archivesP].count;
    NSInteger trash    = [AppData.trashDocs filteredArrayUsingPredicate:trashP].count;
    NSInteger buyers   = [AppData.BuyerArray filteredArrayUsingPredicate:buyersP].count;

    self.cardsBarItem.badgeValue   = cards    ? @(cards).stringValue    : nil;
    self.cagesBarItem.badgeValue   = cages    ? @(cages).stringValue    : nil;
    self.archiveBarItem.badgeValue = archives ? @(archives).stringValue : nil;
    self.trashBarItem.badgeValue   = trash    ? @(trash).stringValue    : nil;
    self.salesBarItem.badgeValue   = buyers   ? @(buyers).stringValue   : nil;
}


























- (void)configureSearchSortMenu {

    // ========= FILTER =========
    NSMutableDictionary<NSString *, NSNumber *> *subKindCounts = [NSMutableDictionary dictionary];

    for (CardModel *c in AppData.UserCardsDocs) {
        if (!c.subKindString.length) continue;

        NSNumber *count = subKindCounts[c.subKindString];
        subKindCounts[c.subKindString] = @(count.integerValue + 1);
    }

    NSMutableArray *filterActions = [NSMutableArray array];

    // All
    [filterActions addObject:
     [self filterActionWithTitle:kLang(@"FilterAllBirds") subKind:nil]];

    // SubKinds
    for (NSString *sub in subKindCounts.allKeys) {
        NSInteger count = subKindCounts[sub].integerValue;
        NSString *title =
        [NSString stringWithFormat:@"%@ · %ld", sub, (long)count];

        [filterActions addObject:
         [self filterActionWithTitle:title subKind:sub]];
    }
    
    if (self.selectedSubKind.length) {
        [filterActions addObject:[self clearFilterAction]];
    }

    UIMenu *filterMenu =
    [UIMenu menuWithTitle:kLang(@"FilterByBreedTitle")
                    image:nil
               identifier:nil
                  options:UIMenuOptionsSingleSelection
                 children:filterActions];

    // ========= SORT =========
    UIAction *newest =
    [self simpleSortActionWithTitle:kLang(@"SortNewest")  image:PPSYSImage(@"plus")
                               type:PPCardSortNewest];

    UIAction *oldest =
    [self simpleSortActionWithTitle:kLang(@"SortOldest") image:PPSYSImage(@"plus")
                               type:PPCardSortOldest];

    UIMenu *sortMenu =
    [UIMenu menuWithTitle:kLang(@"SortTitle")
                    image:nil
               identifier:nil
                  options:UIMenuOptionsSingleSelection
                 children:@[newest, oldest]];

    // ========= ROOT =========
    UIMenu *root =
    [UIMenu menuWithTitle:kLang(@"BirdActionsTitle")
                    image:nil
               identifier:nil
                  options:0
                 children:@[filterMenu, sortMenu]];

    self.searchView.primaryButton.menu = root;
    self.searchView.primaryButton.showsMenuAsPrimaryAction = YES;
}


- (void)sortByRingIDAscending:(BOOL)asc
{
    NSSortDescriptor *sd =
    [NSSortDescriptor sortDescriptorWithKey:@"RingID"
                                   ascending:asc
                                    selector:@selector(localizedCaseInsensitiveCompare:)];
    [self.userCardsArray sortUsingDescriptors:@[sd]];
    [self applySnapshotAnimated:YES];
}

- (void)sortByDateNewest:(BOOL)newest
{
    NSSortDescriptor *sd =
    [NSSortDescriptor sortDescriptorWithKey:@"AddedDate"
                                   ascending:!newest];
    [self.userCardsArray sortUsingDescriptors:@[sd]];
    [self applySnapshotAnimated:YES];
}

- (void)sortByBreedAscending:(BOOL)asc
{
    NSSortDescriptor *sd =
    [NSSortDescriptor sortDescriptorWithKey:@"subKindString"
                                   ascending:asc
                                    selector:@selector(localizedCaseInsensitiveCompare:)];
    [self.userCardsArray sortUsingDescriptors:@[sd]];
    [self applySnapshotAnimated:YES];
}

- (void)restoreSortAndFilter {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    self.selectedSort = [d integerForKey:kPPSortKey];
    self.selectedSubKind = [d stringForKey:kPPFilterKey];
}

- (void)persistSortAndFilter {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d setInteger:self.selectedSort forKey:kPPSortKey];

    if (self.selectedSubKind.length) {
        [d setObject:self.selectedSubKind forKey:kPPFilterKey];
    } else {
        [d removeObjectForKey:kPPFilterKey];
    }
}

- (UIAction *)simpleSortActionWithTitle:(NSString *)title image:(UIImage *)image
                                   type:(PPCardSortType)type
{
    __weak typeof(self) weakSelf = self;

    UIAction *action =
    [UIAction actionWithTitle:title
                        image:image
                   identifier:nil
                      handler:^(__kindof UIAction * _Nonnull action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        self.selectedSort = type;
        [self applySortAndFilter];
    }];

    action.state = (self.selectedSort == type)
                 ? UIMenuElementStateOn
                 : UIMenuElementStateOff;

    return action;
}
- (void)reloadItemWithID:(NSString *)identifier
{
    if (!identifier.length) return;

    NSDiffableDataSourceSnapshot *snapshot = self.dataSource.snapshot;
    if (!snapshot) return;

    for (MainItem *item in snapshot.itemIdentifiers) {
        if ([item.identifier isEqualToString:identifier]) {
            [snapshot reloadItemsWithIdentifiers:@[item]];
            [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
            break;
        }
    }
}
- (void)applySortAndFilter {
    
    if (!self.suppressScrollAdjustment) {
        NSString *scrollKey =
        [NSString stringWithFormat:@"section_%ld_%@",
         (long)self.cellSection,
         self.selectedSubKind ?: @"ALL"];
        self.scrollOffsets[scrollKey] = @(self.collectionView.contentOffset.y);
    }
    
    [self updateSearchFilterBadge];
    
    NSArray *source = AppData.UserCardsDocs;

    // 1️⃣ Filter by SubKind (if any)
    if (self.selectedSubKind.length) {
        source = [source filteredArrayUsingPredicate:
                  [NSPredicate predicateWithFormat:@"subKindString ==[c] %@",
                   self.selectedSubKind]];
    }

    NSMutableArray *result = source.mutableCopy;

    // 2️⃣ Sort
    NSSortDescriptor *sd = nil;
    switch (self.selectedSort) {

        case PPCardSortOldest:
            sd = [NSSortDescriptor sortDescriptorWithKey:@"AddedDate"
                                               ascending:YES];
            break;

        case PPCardSortRingAsc:
            sd = [NSSortDescriptor sortDescriptorWithKey:@"RingID"
                                               ascending:YES
                                                selector:@selector(localizedCaseInsensitiveCompare:)];
            break;

        case PPCardSortRingDesc:
            sd = [NSSortDescriptor sortDescriptorWithKey:@"RingID"
                                               ascending:NO
                                                selector:@selector(localizedCaseInsensitiveCompare:)];
            break;

        case PPCardSortNewest:
        default:
            sd = [NSSortDescriptor sortDescriptorWithKey:@"AddedDate"
                                               ascending:NO];
            break;
    }

    if (sd) {
        [result sortUsingDescriptors:@[sd]];
    }

    // 3️⃣ Apply
    self.userCardsArray = result;

    // 4️⃣ Persist + refresh UI
    [self persistSortAndFilter];
    [self configureSearchSortMenu];
    [self applySnapshotAnimated:YES];
    
   
}

- (UIAction *)filterActionWithTitle:(NSString *)title
                            subKind:(NSString *)subKind
{
    __weak typeof(self) weakSelf = self;

    UIAction *action =
    [UIAction actionWithTitle:title
                        image:[UIImage systemImageNamed:@"leaf"]
                   identifier:nil
                      handler:^(__kindof UIAction * _Nonnull action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        self.selectedSubKind = subKind;
        [self applySortAndFilter];
    }];

    action.state =
    ((subKind == nil && self.selectedSubKind == nil) ||
     [self.selectedSubKind isEqualToString:subKind])
    ? UIMenuElementStateOn
    : UIMenuElementStateOff;

    return action;
}

- (void)updateSearchFilterBadge {
    BOOL filterActive = (self.selectedSubKind.length > 0);

    UIButton *btn = self.searchView.btn1;

    if (filterActive) {
        [btn addBadgeWithContent:@""
                     contentFont:nil
                    contentColor:nil
                      badgeColor:AppPrimaryClr
                          offset:CGPointMake(-10, 10)
                    badgeRadius:6];
    } else {
        [btn removeBadge];
    }
}

- (UIAction *)clearFilterAction {
    __weak typeof(self) weakSelf = self;

    UIAction *action =
    [UIAction actionWithTitle:kLang(@"ClearFilters")
                        image:[UIImage systemImageNamed:@"xmark.circle"]
                   identifier:nil
                      handler:^(__kindof UIAction * _Nonnull action) {
        __strong typeof(weakSelf) self = weakSelf;
        self.selectedSubKind = nil;
        [self applySortAndFilter];
    }];

    action.attributes = UIMenuElementAttributesDestructive;
    return action;
}

- (void)scrollCollectionViewToTopAnimated:(BOOL)animated {
    if (!self.collectionView) return;

    CGPoint top =
    CGPointMake(0, -self.collectionView.adjustedContentInset.top);

    [self.collectionView setContentOffset:top animated:animated];
}



- (NSString *)sanitizedPhoneDigits:(NSString *)value
{
    if (!value.length) return @"";
    NSCharacterSet *nonDigits =
    [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    return [[value componentsSeparatedByCharactersInSet:nonDigits]
            componentsJoinedByString:@""];
}

- (void)updateArchiveSoldStateForCardID:(NSString *)cardID
                                 isSold:(BOOL)isSold
                             completion:(void(^)(NSError * _Nullable error))completion
{
    if (!cardID.length) {
        if (completion) completion(nil);
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRTimestamp *nowTS = [FIRTimestamp timestampWithDate:[NSDate date]];

    [[[db collectionGroupWithID:@"ArchiveDetailsCol"]
      queryWhereField:@"CardID" isEqualTo:cardID]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot,
                                  NSError * _Nullable error)
    {
        if (error) {
            if (completion) completion(error);
            return;
        }

        if (snapshot.documents.count == 0) {
            if (completion) completion(nil);
            return;
        }

        FIRWriteBatch *batch = [db batch];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            [batch updateData:@{
                @"isSold" : @(isSold),
                @"lastUpdated" : nowTS
            } forDocument:doc.reference];
        }

        [batch commitWithCompletion:^(NSError * _Nullable batchError) {
            if (completion) completion(batchError);
        }];
    }];
}

- (void)BuyerWhatsAppMessage:(BuyerModel *)b_model {
    NSString *digits = [self sanitizedPhoneDigits:b_model.buyerMobile];
    if (!digits.length) {
        [self.dataManager showSnakBar:kLang(@"alertSubtitleError")
                            withColor:[UIColor systemRedColor]
                          andDuration:3
                        containerView:self.view];
        return;
    }

    NSString *encodedMessage =
    [@"" stringByAddingPercentEncodingWithAllowedCharacters:
     [NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString =
    [NSString stringWithFormat:@"whatsapp://send?phone=%@&text=%@",
     digits,
     encodedMessage ?: @""];
    NSURL *url = [NSURL URLWithString:urlString];

    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url
                                           options:@{}
                                 completionHandler:nil];
        return;
    }

    [self.dataManager showSnakBar:kLang(@"alertSubtitleError")
                        withColor:[UIColor systemRedColor]
                      andDuration:3
                    containerView:self.view];
}

- (void)Buyercall:(BuyerModel *)b_model {
    NSString *digits = [self sanitizedPhoneDigits:b_model.buyerMobile];
    if (!digits.length) {
        [self.dataManager showSnakBar:kLang(@"alertSubtitleError")
                            withColor:[UIColor systemRedColor]
                          andDuration:3
                        containerView:self.view];
        return;
    }

    NSURL *phoneURL =
    [NSURL URLWithString:[NSString stringWithFormat:@"tel:%@", digits]];

    if ([[UIApplication sharedApplication] canOpenURL:phoneURL]) {
        [[UIApplication sharedApplication] openURL:phoneURL
                                           options:@{}
                                 completionHandler:nil];
        return;
    }

    [self.dataManager showSnakBar:kLang(@"alertSubtitleError")
                        withColor:[UIColor systemRedColor]
                      andDuration:3
                    containerView:self.view];
}

- (void)exportSalesBillForBuyer:(BuyerModel *)buyer card:(CardModel *)card sender:(UIButton *)sender
{
    NSLog(@"buyer %@",buyer);
    NSLog(@"card %@",card);

    [PPSalesPDFGenerator generateSalesBillPDFWithBuyer:buyer card:card autoShow:YES];
    
}

- (void)returnCard:(BuyerModel *)b_model buyerCell:(SalesCell *)buyerCell {
    (void)buyerCell;
    if (!b_model.ID.length) return;

    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showConfirmationIn:self
                                title:kLang(@"returnCard")
                             subtitle:kLang(@"returnSelledCard")
                        confirmButton:kLang(@"yes")
                         cancelButton:kLang(@"no")
                                 icon:[UIImage imageNamed:@"Return"]
                         confirmBlock:^(NSString * _Nullable text, BOOL didConfirm)
    {
        if (!didConfirm) return;

        [PPHUD showLoading];

        FIRFirestore *db = [FIRFirestore firestore];
        FIRTimestamp *nowTS = [FIRTimestamp timestampWithDate:[NSDate date]];
        CardModel *cardToReturn = [weakSelf cardDataForID:b_model.birdID];

        FIRWriteBatch *batch = [db batch];
        FIRDocumentReference *buyerRef =
        [[db collectionWithPath:@"BuyersCollection"] documentWithPath:b_model.ID];

        [batch setData:@{
            @"isDeleted" : @1,
            @"lastUpdated" : nowTS
        } forDocument:buyerRef merge:YES];

        if (cardToReturn.ID.length) {
            FIRDocumentReference *cardRef =
            [[db collectionWithPath:@"CardsCol"] documentWithPath:cardToReturn.ID];
            [batch updateData:@{
                @"isSold" : @0,
                @"soldPrice" : @"",
                @"lastUpdated" : nowTS
            } forDocument:cardRef];
        }

        [batch commitWithCompletion:^(NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    [PPHUD dismiss];
                    NSLog(@"❌ Return sold card failed: %@", error);
                    [weakSelf.dataManager showSnakBar:kLang(@"alertSubtitleError")
                                            withColor:[UIColor systemRedColor]
                                          andDuration:3
                                        containerView:weakSelf.view];
                    return;
                }

                dispatch_group_t group = dispatch_group_create();

                if (cardToReturn.ID.length && cardToReturn.CageID.length) {
                    dispatch_group_enter(group);
                    [ChildsDataManager updateChildWithCardID:cardToReturn.ID
                                                      cageID:cardToReturn.CageID
                                                        data:@{
                        @"isSold" : @0,
                        @"lastUpdated" : nowTS
                    } completion:^(NSError * _Nullable error) {
                        if (error) {
                            NSLog(@"⚠️ Return sold child sync failed: %@", error);
                        }
                        dispatch_group_leave(group);
                    }];
                }

                if (cardToReturn.ID.length) {
                    dispatch_group_enter(group);
                    [weakSelf updateArchiveSoldStateForCardID:cardToReturn.ID
                                                       isSold:NO
                                                   completion:^(NSError * _Nullable error) {
                        if (error) {
                            NSLog(@"⚠️ Return sold archive sync failed: %@", error);
                        }
                        dispatch_group_leave(group);
                    }];
                }

                dispatch_group_notify(group, dispatch_get_main_queue(), ^{
                    [PPHUD dismiss];
                    [weakSelf.dataManager showSnakBar:kLang(@"Retutn_Compelete")
                                            withColor:[GM appPrimaryColor]
                                          andDuration:5
                                        containerView:weakSelf.view];
                });
            });
        }];
    } cancelBlock:^{
        
    }];
}

- (void)shareCard:(CardModel *)card andImage:(UIImage *)image {
    
}

- (void)showDetails:(BuyerModel *)b_model cardModel:(CardModel *)cardModel {
    CardModel *selectedCard = cardModel;
    if (!selectedCard && b_model.birdID.length) {
        selectedCard = [self cardDataForID:b_model.birdID];
    }
    if (!selectedCard) return;

    [self showViewer:selectedCard];
}

#pragma mark - PPCageCellDelegate

- (void)cageCellDidTapParentCard:(CardModel *)card
                        fromCage:(CageModel *)cage
                        isFather:(BOOL)isFather
{
    if (!card) return;

    NSLog(@"🐦 Cage parent tapped | cage=%@ | card=%@ | parent=%@",
          cage.ID,
          card.ID,
          isFather ? @"father" : @"mother");

    [self showViewer:card];
}

- (void)cageCellDidArchiveParent:(CageModel *)cage isFather:(BOOL)isFather
{
    CardModel *card = isFather ? cage.FatherCard : cage.MotherCard;
    if (!card) return;

    NSLog(@"📦 Cage archive parent | cage=%@ | card=%@ | isFather=%d",
          cage.ID, card.ID, isFather);

    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    ArchiveManagerVC *vc =[ArchiveManagerVC new];
    vc.cardToArchive = card;
    vc.FromVC = 1;
    vc.archiveHeight = self.view.frame.size.height * 0.7;

    [PPFunc presentSheetFrom:self
                     sheetVC:vc
                 detentStyle:PPSheetDetentStyleProfile];
}

- (void)cageCellDidSellParent:(CageModel *)cage isFather:(BOOL)isFather
{
    CardModel *card = isFather ? cage.FatherCard : cage.MotherCard;
    if (!card) return;

    NSLog(@"💰 Cage sell parent | cage=%@ | card=%@ | isFather=%d",
          cage.ID, card.ID, isFather);

    [self sellThisCard:card
          lastLocation:CardSectionCage
            cageIndex:0];
}

- (void)cageCellDidTapAddChick:(CageModel *)cage
{
    if (!cage) return;

    NSLog(@"🐣 Add chick | cage=%@ | count=%ld",
          cage.ID, (long)cage.childsCount);

    self.selectedCage = cage;

    selectChildViewController *VC = [selectChildViewController new];
    VC.CageData = cage;
    //VC.FromAction = @"cage";
    //VC.CageData = cage;

    [PPFunc presentSheetFrom:self sheetVC:VC detentStyle:PPSheetDetentStyle80];
}
  

- (void)cageCellDidTapBarcode:(CageModel *)cage
{
    if (!cage.ID.length) return;

    NSLog(@"🔳 Cage barcode | cage=%@", cage.ID);

    UIImage *barcodeImage =
    [BarcodeGenerator generateBarcode:cage.ID
                                width:320
                               height:320];

    FullscreenImageViewController *vc =
    [[FullscreenImageViewController alloc] initWithImage:barcodeImage];

    [PPFunc presentSheetFrom:self
                     sheetVC:vc
                 detentStyle:PPSheetDetentStyleMediumOnly];
}

- (void)cageCellDidTapEdit:(CageModel *)cage
{
    if (!cage) return;

    NSLog(@"✏️ Edit cage | cage=%@", cage.ID);

    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    NewCageVC *vc =[NewCageVC new];

    vc.FromAction = @"Edit";
    vc.CageData = cage;
    vc.CagedataSource = self.CagedataSource;

    [PPFunc presentSheetFrom:self
                     sheetVC:vc
                 detentStyle:PPSheetDetentStyle70];
}


 

- (void)cageCellDidTapSetFirstEggDate:(CageModel *)cage
{
    if (!cage) return;

    NSLog(@"🥚 Set first egg date | cage=%@", cage.ID);

    [self showEggDateController:cage];
}


- (void)updateSearchBarButtonStateAnimated:(BOOL)animated
{
    UIImage *img =
    self.isSearchVisible
    ? objc_getAssociatedObject(SearchBarButtonItem, @"pp_closeImg")
    : objc_getAssociatedObject(SearchBarButtonItem, @"pp_searchImg");

    if (!animated) {
        SearchBarButtonItem.image = img;
        return;
    }

    UIView *view = [SearchBarButtonItem valueForKey:@"view"];
    if (!view) {
        SearchBarButtonItem.image = img;
        return;
    }

    [UIView transitionWithView:view
                      duration:0.25
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        self->SearchBarButtonItem.image = img;
    } completion:nil];
}

- (void)captureAnchorForCurrentSection
{
    NSArray<NSIndexPath *> *visible = [self.collectionView indexPathsForVisibleItems];
    if (visible.count == 0) return;

    NSIndexPath *top =
    [[visible sortedArrayUsingSelector:@selector(compare:)] firstObject];

    MainItem *item =
    [self.dataSource itemIdentifierForIndexPath:top];
    if (!item.identifier.length) return;

    UICollectionViewLayoutAttributes *attr =
    [self.collectionView layoutAttributesForItemAtIndexPath:top];
    if (!attr) return;

    CGFloat offset =
    self.collectionView.contentOffset.y - attr.frame.origin.y;

    NSNumber *key = @(self.cellSection);
    self.anchorItemIDs[key] = item.identifier;
    self.anchorItemOffsets[key] = @(offset);
}

- (void)restoreAnchorForCurrentSection
{
    NSNumber *key = @(self.cellSection);
    NSString *anchorID = self.anchorItemIDs[key];
    NSNumber *offsetNum = self.anchorItemOffsets[key];

    if (!anchorID || !offsetNum) return;

    NSDiffableDataSourceSnapshot *snapshot = self.dataSource.snapshot;
    NSArray<MainItem *> *items = snapshot.itemIdentifiers;
    if (items.count == 0) return;

    NSInteger foundIndex = NSNotFound;

    for (NSInteger i = 0; i < items.count; i++) {
        MainItem *item = items[i];
        if ([item.identifier isEqualToString:anchorID]) {
            foundIndex = i;
            break;
        }
    }

    if (foundIndex == NSNotFound) return;

    NSIndexPath *indexPath =
    [NSIndexPath indexPathForItem:foundIndex inSection:0];

    UICollectionViewLayoutAttributes *attr =
    [self.collectionView layoutAttributesForItemAtIndexPath:indexPath];
    if (!attr) return;

    CGFloat y =
    attr.frame.origin.y + offsetNum.doubleValue;

    y = MAX(-self.collectionView.adjustedContentInset.top, y);

    [self.collectionView setContentOffset:CGPointMake(0, y) animated:NO];
}
@end
