//
//  PPAdsBrowser.m
//  Pure Pets
//
//  Created by Sam + ChatGPT.
//

#import "PPAdsBrowser.h"
#import "PetAd.h"
#import "PPImageLoaderManager.h"
#import "PPAdSharingHelper.h"
#import "YYWebImageManager.h"
#import "YYWebImageOperation.h"


#define SCREEN_WIDTH [UIScreen mainScreen].bounds.size.width
#define NUMBER_OF_VISIBLE_VIEWS 5
#define ICON_VIEW_PADDING 5

@interface PPAdsBrowser () <LTInfiniteScrollViewDataSource, LTInfiniteScrollViewDelegate,UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, PPUniversalCellDelegate, AdsBrowserDelegate, UICollectionViewDataSourcePrefetching,PPCenteredSelectorViewDelegate>
@property (nonatomic, strong) UIView *categoriesContainer;
@property (nonatomic, strong) NSLayoutConstraint *categoriesTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *categoriesHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *adsTopConstraint;
@property (strong, nonatomic) LTInfiniteScrollView *scrollView;
@property (nonatomic, assign) BOOL didReceiveInitialData;

@end

@implementation PPAdsBrowser



#pragma mark - Factory

+ (instancetype)browserWithCategories:(NSArray<MainKindsModel *> *)categories navHeight:(float)navHeight {
    return [[self alloc] initWithFrame:CGRectZero categories:categories navHeight:navHeight];
}

+ (instancetype)initWithCategories:(NSArray<MainKindsModel *> *)categories navHeight:(float)navHeight {
    return [self browserWithCategories:categories navHeight:navHeight];
}

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame categories:(NSArray<MainKindsModel *> *)categories navHeight:(float)navHeight {
    self = [super initWithFrame:frame];
    if (self) {
        _NavBarHeight = navHeight;
        _heightCacheKey = @"PPAdsBrowserPinterestHeights";
        _categories = categories ?: @[];
        _cellLayoutMode = PPCellLayoutModePinterest;
        _adManager = [PetAdManager sharedManager];
        self.backgroundColor = UIColor.clearColor;
        _prefetchTasks = [NSMutableDictionary dictionary];
        [self setupViews];
        [self configureAdsDataSource];
        
        _scrollView.delegate = self;
        _scrollView.dataSource = self;
        _scrollView.userInteractionEnabled = NO;
    }
    return self;
}

#pragma mark - Setup

- (void)setupViews {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    _ads = [NSMutableArray array];
    
    // Create container for categories to ensure it stays on top
    _categoriesContainer = [[UIView alloc] init];
    _categoriesContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _categoriesContainer.backgroundColor = UIColor.clearColor;
    _categoriesContainer.clipsToBounds = YES;
    [self addSubview:_categoriesContainer];
    /* [_categoriesCollectionView registerClass:[PPCategoryKindCell class]
                   forCellWithReuseIdentifier:@"PPCategoryKindCell"];
     [_categoriesContainer addSubview:_categoriesCollectionView];
     */
   
    
    // Setup ads collection view with Pinterest layout
    PPPinterestLayout *pLayout = [[PPPinterestLayout alloc] init];
    pLayout.delegate = self;
    pLayout.columnCount = 0; // auto (2+ columns depending on width)
    pLayout.minimumInteritemSpacing = 4.0;
    pLayout.minimumLineSpacing = 4.0;
    pLayout.spacing = 14.0;
    pLayout.sectionInset = UIEdgeInsetsMake(90, 14, 4, 14); // Top inset to account for categories
    
    _adsCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:pLayout];
    _adsCollectionView.translatesAutoresizingMaskIntoConstraints = NO;
    _adsCollectionView.backgroundColor = UIColor.clearColor;
    _adsCollectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [_adsCollectionView registerClass:[PPUniversalCell class] forCellWithReuseIdentifier:@"PPUniversalCell"];
    _adsCollectionView.delegate = self;
    [self addSubview:_adsCollectionView];
    
    // Create glass background for categories
    UIButton *backgroundView = [self createCategoriesBackground];
    backgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    backgroundView.userInteractionEnabled = NO; // Allow taps to pass through to collection view
    [_categoriesContainer insertSubview:backgroundView atIndex:0];
    
    /*
    self.selector = [[PPCenteredSelectorView alloc] initWithItems:MKM.MainKindsArray];
    self.selector.translatesAutoresizingMaskIntoConstraints = NO;
    self.selector.delegate = self;

    [self.categoriesContainer addSubview:self.selector];

    [NSLayoutConstraint activateConstraints:@[
        [self.selector.topAnchor constraintEqualToAnchor:self.categoriesContainer.topAnchor constant:0],
        [self.selector.leadingAnchor constraintEqualToAnchor:self.categoriesContainer.leadingAnchor],
        [self.selector.trailingAnchor constraintEqualToAnchor:self.categoriesContainer.trailingAnchor],
        [self.selector.heightAnchor constraintEqualToAnchor:self.categoriesContainer.heightAnchor]
    ]];*/
    
    self.selector =
    [[PPCenteredSelectorView alloc] initWithItems:MKM.MainKindsArray];

    self.selector.delegate = self;
    [self.categoriesContainer addSubview:self.selector];

    self.selector.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [self.selector.topAnchor constraintEqualToAnchor:self.categoriesContainer.safeAreaLayoutGuide.topAnchor constant:0],
        [self.selector.leadingAnchor constraintEqualToAnchor:self.categoriesContainer.leadingAnchor],
        [self.selector.trailingAnchor constraintEqualToAnchor:self.categoriesContainer.trailingAnchor],
        [self.selector.heightAnchor constraintEqualToAnchor:self.categoriesContainer.heightAnchor]
    ]];
    
    // Setup constraints
    [self setupConstraintsWithBackground:backgroundView];
    
    _adsCollectionView.prefetchDataSource = self;
    _adsCollectionView.prefetchingEnabled = YES;
    
    [[PPHeightCacheManager sharedManager] loadCacheForKey:self.heightCacheKey];
    [self applyCollectionViewOptimizations];
    [self initialSelectionIfNeeded];
    
    [self.scrollView reloadDataWithInitialIndex:200];

    

}
# pragma mark - LTInfiniteScrollView dataSource
- (NSInteger)numberOfViews
{
    return 999;
}

- (NSInteger)numberOfVisibleViews
{
    return NUMBER_OF_VISIBLE_VIEWS;
}

# pragma mark - LTInfiniteScrollView delegate
- (UIView *)viewAtIndex:(NSInteger)index reusingView:(UIView *)view
{
    if (!view) {
        view = [self newIconView];
    }
    return view;
}

- (UIView *)newIconView
{
    CGFloat width =  SCREEN_WIDTH/NUMBER_OF_VISIBLE_VIEWS - ICON_VIEW_PADDING * 2;
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 100)];
    view.backgroundColor = AppForgroundColr;
    view.layer.cornerRadius = 5;
    view.layer.masksToBounds = YES;
    
    CGFloat innerIconPadding = 5;
    CGFloat iconSize = width - innerIconPadding * 2;
    UIView *innerIcon = [[UIView alloc] initWithFrame:CGRectMake(innerIconPadding, innerIconPadding, iconSize, iconSize)];
    innerIcon.backgroundColor = UIColor.systemGray3Color;
    innerIcon.layer.cornerRadius = 5;
    innerIcon.layer.masksToBounds = YES;
    
    [view addSubview:innerIcon];
    return view;
}

- (void)updateView:(UIView *)view withProgress:(CGFloat)progress scrollDirection:(ScrollDirection)direction
{
    // you can appy animations duration scrolling here
    if (progress == 0) {
        [self animateMenuOut:view];
    } else if(fabs(progress) == 1) {
        [self animateMenuBack:view];
    }
    
}

- (void)animateMenuOut:(UIView *)view
{
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.56 initialSpringVelocity:0 options:0 animations:^{
        view.transform = CGAffineTransformMakeTranslation(0, -60);
    } completion:^(BOOL finished) {
        
    }];
}

- (void)animateMenuBack:(UIView *)view
{
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.56 initialSpringVelocity:0 options:0 animations:^{
        view.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        
    }];
}

- (UIButton *)createCategoriesBackground
{
    UIButton *bgButton;
    if (@available(iOS 26.0, *)) {
        // 🧊 iOS 26+ system glass button
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        
        
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
 

        bgButton = [UIButton  buttonWithType:UIButtonTypeSystem];
        bgButton.configuration = cfg;
      } else {
         
 
        // 🌫️ Fallback for iOS <26
        bgButton = [UIButton buttonWithType:UIButtonTypeSystem];
        bgButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        bgButton.layer.cornerRadius = 16;
        bgButton.layer.masksToBounds = YES;
        [bgButton pp_setShadowColor:AppShadowClr];
        bgButton.layer.shadowOpacity = 0.15;
        bgButton.layer.shadowRadius = 8;
        bgButton.layer.shadowOffset = CGSizeMake(0, 4);
    }

    bgButton.translatesAutoresizingMaskIntoConstraints = NO;
    return bgButton;
}



- (void)setupConstraintsWithBackground:(UIButton *)backgroundView {
    // Categories container constraints
    self.categoriesTopConstraint = [_categoriesContainer.topAnchor constraintEqualToAnchor:self.topAnchor constant:_NavBarHeight];
    self.categoriesHeightConstraint = [_categoriesContainer.heightAnchor constraintEqualToConstant:64];
    
    [NSLayoutConstraint activateConstraints:@[
        self.categoriesTopConstraint,
        [_categoriesContainer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [_categoriesContainer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        self.categoriesHeightConstraint
    ]];
    
    // Background view constraints
    [NSLayoutConstraint activateConstraints:@[
        [backgroundView.topAnchor constraintEqualToAnchor:_categoriesContainer.topAnchor],
        [backgroundView.leadingAnchor constraintEqualToAnchor:_categoriesContainer.leadingAnchor],
        [backgroundView.trailingAnchor constraintEqualToAnchor:_categoriesContainer.trailingAnchor],
        [backgroundView.bottomAnchor constraintEqualToAnchor:_categoriesContainer.bottomAnchor]
    ]];
    
    // Ads collection view constraints - starts below categories container
    self.adsTopConstraint = [_adsCollectionView.topAnchor constraintEqualToAnchor:self.topAnchor constant:-5];
    
    [NSLayoutConstraint activateConstraints:@[
        self.adsTopConstraint,
        [_adsCollectionView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_adsCollectionView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_adsCollectionView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];
    
    
    _categoriesContainer.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
}

- (void)applyCollectionViewOptimizations {
    UICollectionView *cv = self.adsCollectionView;
    
    // Enable cell prefetching (iOS 10+)
    if (@available(iOS 10.0, *)) {
        cv.prefetchDataSource = self;
        cv.prefetchingEnabled = YES;
    }
    
    // Disable animations during scrolling
    cv.layer.speed = 1.0;
    
    // Optimize cell rendering
    cv.showsHorizontalScrollIndicator = NO;
    cv.showsVerticalScrollIndicator = NO;
    cv.delaysContentTouches = NO;
    cv.canCancelContentTouches = YES;
    
    // Set estimated item size for better performance
    if (@available(iOS 10.0, *)) {
        //[(UICollectionViewFlowLayout *)cv.collectionViewLayout setEstimatedItemSize:CGSizeMake(100, 200)];
    }
}

#pragma mark - Update Categories Position

- (void)updateCategoriesPosition {
    // This method ensures categories stay on top when scrolling
    // Bring categories container to front
    [self bringSubviewToFront:_categoriesContainer];
    
    // Add subtle shadow for better visibility
    [_categoriesContainer pp_setShadowColor:[UIColor blackColor]];
    _categoriesContainer.layer.shadowOffset = CGSizeMake(0, 2);
    _categoriesContainer.layer.shadowRadius = 4;
    _categoriesContainer.layer.shadowOpacity = 0.1;
    _categoriesContainer.layer.masksToBounds = NO;
    
    self.selector.layer.cornerRadius = self.selector.hx_h /2;
    self.selector.clipsToBounds = YES;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // Ensure categories stay on top
    [self updateCategoriesPosition];
    
    // Update pinterest layout section inset based on categories height
    if ([_adsCollectionView.collectionViewLayout isKindOfClass:[PPPinterestLayout class]]) {
        PPPinterestLayout *layout = (PPPinterestLayout *)_adsCollectionView.collectionViewLayout;
        layout.sectionInset = UIEdgeInsetsMake(100, 8, 8, 8);
    }
    
    // Update ads collection view top constraint
    self.adsTopConstraint.constant = -5; // Negative to overlap categories slightly
}

#pragma mark - Initial Selection

- (void)initialSelectionIfNeeded {
    if (self.categories.count == 0) {
        self.selectedCategoryID = NSNotFound;
        return;
    }
    MainKindsModel *first = self.categories.firstObject;
    self.selectedCategoryID = first.ID;
    
    [self reloadCurrentCategory];
}

#pragma mark - Public Methods

- (void)reloadCurrentCategory {
    if (self.selectedCategoryID == NSNotFound) {
        [PPHUD dismiss];
        [self applyEmptySnapshot];
        return;
    }
    
    NSInteger categoryID = self.selectedCategoryID;
    __weak typeof(self) weakSelf = self;
    
    [[PetAdManager sharedManager] startListeningForPetAdsWithFilters:nil
                                                            category:categoryID
                                                         subcategory:0
                                                currentAdsPointer:self.ads.mutableCopy
                                                          onChange:^(NSArray<PetAd *> *updatedAds) {
        self.ads = updatedAds.mutableCopy;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            if (self.ads.count == 0) {
                [PPHUD dismiss];
                [strongSelf applyEmptySnapshot];
                strongSelf.didReceiveInitialData = YES;
                return;
            }
            
            BOOL isInitial = !strongSelf.didReceiveInitialData;
            strongSelf.didReceiveInitialData = YES;
            
            NSArray<PPUniversalCellViewModel *> *vms = [strongSelf buildViewModelsFromAds:self.ads];
            [strongSelf applySnapshotWithViewModels:vms animate:!isInitial];
            
            // Prevent auto-scroll on initial load — keep filter visible
            if (isInitial) {
                [strongSelf.adsCollectionView setContentOffset:CGPointZero animated:NO];
            }
            
            [PPHUD dismiss];
        });
    }];
}

- (void)selectCategoryWithID:(NSInteger)categoryID {
    __block NSInteger index = NSNotFound;
    [self.categories enumerateObjectsUsingBlock:^(MainKindsModel *obj, NSUInteger idx, BOOL *stop) {
        if (obj.ID == categoryID) {
            index = (NSInteger)idx;
            *stop = YES;
        }
    }];
    
    if (index == NSNotFound) return;
    
    self.selectedCategoryID = categoryID;
  //  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:0];
    
   
    [self reloadCurrentCategory];
}

#pragma mark - Snapshot Helpers

- (void)applyEmptySnapshot {
    NSDiffableDataSourceSnapshot<NSNumber *, PPUniversalCellViewModel *> *snapshot =
    [[NSDiffableDataSourceSnapshot alloc] init];
    [snapshot appendSectionsWithIdentifiers:@[@0]];
    [self.adsDataSource applySnapshot:snapshot animatingDifferences:NO];
}

- (void)applySnapshotWithViewModels:(NSArray<PPUniversalCellViewModel *> *)viewModels
                            animate:(BOOL)animate {
    NSDiffableDataSourceSnapshot<NSNumber *, PPUniversalCellViewModel *> *snapshot =
    [[NSDiffableDataSourceSnapshot alloc] init];
    [snapshot appendSectionsWithIdentifiers:@[@0]];
    if (viewModels.count) {
        [snapshot appendItemsWithIdentifiers:viewModels intoSectionWithIdentifier:@0];
    }
    [self.adsDataSource applySnapshot:snapshot animatingDifferences:animate];
}

#pragma mark - ViewModel Builder

- (NSArray<PPUniversalCellViewModel *> *)buildViewModelsFromAds:(NSArray<PetAd *> *)ads {
    if (ads.count == 0) return @[];
    
    NSMutableArray<PPUniversalCellViewModel *> *result = [NSMutableArray arrayWithCapacity:ads.count];
    
    for (PetAd *ad in ads) {
        PPUniversalCellViewModel *vm = [PPUniversalCellViewModel new];
        
        vm.placeholder = [UIImage imageNamed:@"placeholder"];
        vm.isOwner = ([PPCurrentUser.ID isEqualToString:ad.ownerID]);
        vm.hasOffer = NO;
        vm.isNew = NO;
        vm.ModelID = ad.adID ?: NSUUID.UUID.UUIDString;
        
        NSString *imageURL = nil;
        UIImage *placeholder = [UIImage imageNamed:@"placeholder"];

        PetImageItem *firstItem = ad.imageItems.firstObject;
        if (firstItem) {
            imageURL = firstItem.url;

            if (firstItem.blurHash.length > 0) {
                placeholder =
                [PPBlurHashBridge  imageFrom:firstItem.blurHash
                             syncSize:CGSizeMake(40, 40)
                            punch:1.0];
            }
        }

        vm.imageURL = imageURL;
        vm.placeholder = placeholder;
        
        
        vm.priceText = ad.price ?
        [NSString stringWithFormat:@"%@ %@", ad.price, kLang(@"Rials")] :
        kLang(@"NoPrice");
        vm.subtitle = [NSString stringWithFormat:@"%ld",ad.adLocation] ?: @"";
        vm.ppSection = PPSectionAds;
        vm.imageSize = CGSizeZero;
        vm.ModelObject = ad;
        vm.modelContext = PPCellForAds;
        vm.cellSection = CellSectionAds;
        vm.finalPrice = ad.price;
        vm.price = ad.price;
        vm.title = ad.adTitle ?: kLang(@"UntitledAd");
        
        [result addObject:vm];
    }
    
    return result;
}


- (CGFloat)calculateCellWidthForTitle:(NSString *)title {
    UIFont *font = [GM MidFontWithSize:15];
    CGSize textSize = [title sizeWithAttributes:@{NSFontAttributeName: font}];
    
    // Constants based on cell layout
    CGFloat iconWidth = 22.0;      // Icon width
    CGFloat leftPadding = 12.0;    // Leading padding
    CGFloat iconTextSpacing = 8.0; // Space between icon and text
    CGFloat rightPadding = 12.0;   // Trailing padding
    
    return leftPadding + iconWidth + iconTextSpacing + textSize.width + rightPadding+20;
}
- (void)selectorDidSelectIndex:(NSInteger)index item:(MainKindsModel *)item {
    self.selectedCategoryID = item.ID;;

    [self.adManager listenForCategory:self.selectedCategoryID onChange:^(NSArray<PetAd *> * _Nonnull updatedAds) {
         
        dispatch_async(dispatch_get_main_queue(), ^{
            NSArray *vms = [self buildViewModelsFromAds:updatedAds];
            [self applySnapshotWithViewModels:vms animate:NO];
            [self.adsCollectionView setContentOffset:CGPointZero animated:NO];
        });
    }];
}


- (void)didSelectIndex:(NSInteger)index {
    MainKindsModel *kind = self.categories[index];
    self.selectedCategoryID = kind.ID;
    
    [[PetAdManager sharedManager] startListeningForPetAdsWithFilters:nil
                                                            category:self.selectedCategoryID
                                                         subcategory:0
                                                   currentAdsPointer:self.ads
                                                            onChange:^(NSArray<PetAd *> *updatedAds) {
        self.ads = updatedAds.mutableCopy;
        
        
        [self reloadCurrentCategory];
    }];
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    
    /*
     - (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
     cellForItemAtIndexPath:(NSIndexPath *)indexPath {
     if (collectionView == self.categoriesCollectionView) {
     PPCategoryKindCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"PPCategoryKindCell"
     forIndexPath:indexPath];
     cell.indexPath = indexPath;
     MainKindsModel *kind = self.categories[indexPath.item];
             
     NSString *title = kind.KindName ?: kind.KindNameEn ?: kind.KindNameAr ?: @"-";
             
     // Calculate cell width based on content
     CGFloat cellWidth = [self calculateCellWidthForTitle:title];
     [cell updateCellBgButtonWidth:cellWidth ];
             
     // Update cell content
     [cell updateValuesWithTitle:title imageName:kind.KindIconName];
             
     // Set selection state
     BOOL selected = (kind.ID == self.selectedCategoryID);
     [cell setSelected:selected];
             
     cell.delegate = self;
             
     return cell;
     }
         
     return nil;
     }
     [self.categoriesCollectionView reloadData];
     
     
     if (collectionView == self.categoriesCollectionView) {
     MainKindsModel *kind = self.categories[indexPath.item];
     self.selectedCategoryID = kind.ID;
        
     [[PetAdManager sharedManager] startListeningForPetAdsWithFilters:nil
     category:self.selectedCategoryID
     subcategory:0
     currentAdsPointer:self.ads.mutableCopy
     onChange:^(NSArray<PetAd *> *updatedAds) {
     self.ads = updatedAds.mutableCopy;
     [self.categoriesCollectionView reloadData];
     [self reloadCurrentCategory];
     }];
     }
     if (collectionView != self.categoriesCollectionView) {
     return CGSizeZero;
     }
     */
     
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
   
    
    MainKindsModel *kind = self.categories[indexPath.item];
    NSString *title = kind.KindName ?: kind.KindNameEn ?: kind.KindNameAr ?: @"-";
    
    CGFloat width = [self calculateCellWidthForTitle:title];
    // Add a bit of extra width for comfort
    width = MAX(70.0, ceil(width));
    
    return CGSizeMake(width+30,
                      self.categoriesHeightConstraint.constant - 10); // Container height is 44
}
#pragma mark - Configure Ads Data Source

- (void)configureAdsDataSource {
    __weak typeof(self) weakSelf = self;
    _adsDataSource = [[UICollectionViewDiffableDataSource alloc] initWithCollectionView:_adsCollectionView
                                                                           cellProvider:^UICollectionViewCell * _Nullable(UICollectionView *collectionView,
                                                                                                                          NSIndexPath *indexPath,
                                                                                                                          PPUniversalCellViewModel *universalModel) {
        
        PPUniversalCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"PPUniversalCell"
                                                                          forIndexPath:indexPath];
        cell.indexPath = indexPath;
        
        if (![universalModel isKindOfClass:[PPUniversalCellViewModel class]]) {
            return cell;
        }
        
        universalModel.indexPath = indexPath;
        [cell applyViewModel:universalModel
                     context:universalModel.modelContext
                  layoutMode:self.cellLayoutMode
                discountMode:PPDiscountStyleBadge
                 imageLoader:^(UIImageView * _Nonnull imageView,
                               NSString * _Nullable urlString,
                               UIImage * _Nullable placeholder,
                               UIView * _Nullable card) {
            
            // Load image asynchronously
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0),
 ^{
                [[PPImageLoaderManager shared] setImageOnImageView:imageView url:urlString complation:^(UIImage * _Nonnull image, NSString * _Nullable urlString) {
                    
                }]; 
            });
        }];
        
        cell.delegate = weakSelf;
        return cell;
    }];
    
    [self applyEmptySnapshot];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == self.adsCollectionView) {
        // Ensure categories stay on top while scrolling
        //[self updateCategoriesPosition];
        
        // Optional: Add parallax or fade effects
        CGFloat offsetY = scrollView.contentOffset.y;
        if (offsetY < 0) {
            // Pull down - categories move with content
            // self.categoriesTopConstraint.constant = -MIN(-offsetY, -40);
        } else {
            // Scroll up - categories stay at top
            //self.categoriesTopConstraint.constant = _NavBarHeight;
        }
    }
}



- (NSLayoutYAxisAnchor *)globalSafeAreaTopAnchor {
    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    if (!window) {
        window = UIApplication.sharedApplication.windows.firstObject;
    }
    return window.safeAreaLayoutGuide.topAnchor;
}
- (CGFloat)globalSafeAreaTopY {
    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    if (!window) {
        window = UIApplication.sharedApplication.windows.firstObject;
    }
    [window layoutIfNeeded];
    return CGRectGetMinY(window.safeAreaLayoutGuide.layoutFrame);
}



#pragma mark - PPUniversalCellDelegate forwarding

- (void)PPUniversalCell_tapCard:(PPUniversalCellViewModel *)universalModel {
    if ([self.externalCellDelegate respondsToSelector:@selector(PPUniversalCell_tapCard:)]) {
        [self.externalCellDelegate PPUniversalCell_tapCard:universalModel];
    }
}

- (void)PPUniversalCell_tapShare:(PPUniversalCellViewModel *)universalModel {
    if ([self.externalCellDelegate respondsToSelector:@selector(PPUniversalCell_tapShare:)]) {
        [self.externalCellDelegate PPUniversalCell_tapShare:universalModel];
    } else if ([universalModel.ModelObject isKindOfClass:[PetAd class]] && self.adManager.ParentVC) {
        [PPAdSharingHelper sharePetAd:(PetAd *)universalModel.ModelObject fromViewController:self.adManager.ParentVC];
    }
}

- (void)PPUniversalCell_tapFavorite:(PPUniversalCellViewModel *)universalModel {
    if ([self.externalCellDelegate respondsToSelector:@selector(PPUniversalCell_tapFavorite:)]) {
        [self.externalCellDelegate PPUniversalCell_tapFavorite:universalModel];
    }
}

- (void)PPUniversalCell_tapEdit:(PPUniversalCellViewModel *)universalModel {
    if ([self.externalCellDelegate respondsToSelector:@selector(PPUniversalCell_tapEdit:)]) {
        [self.externalCellDelegate PPUniversalCell_tapEdit:universalModel];
    }
}

- (void)PPUniversalCell_tapDelete:(PPUniversalCellViewModel *)universalModel {
    if ([self.externalCellDelegate respondsToSelector:@selector(PPUniversalCell_tapDelete:)]) {
        [self.externalCellDelegate PPUniversalCell_tapDelete:universalModel];
    }
}

- (void)PPUniversalCell_changeQuantity:(PPUniversalCellViewModel *)universalModel quantity:(NSInteger)quantity {
    if ([self.externalCellDelegate respondsToSelector:@selector(PPUniversalCell_changeQuantity:quantity:)]) {
        [self.externalCellDelegate PPUniversalCell_changeQuantity:universalModel quantity:quantity];
    }
}

#pragma mark - PPPinterestLayoutDelegate

- (CGFloat)collectionView:(UICollectionView *)collectionView
                   layout:(PPPinterestLayout *)collectionViewLayout
 heightForItemAtIndexPath:(NSIndexPath *)indexPath
                withWidth:(CGFloat)width {

    // 1) Use cache if we already calculated this height
    NSString *cacheKey = self.heightCacheKey ?: @"PPAdsBrowserPinterestHeights";
    NSNumber *cachedHeight = [[PPHeightCacheManager sharedManager]
                              heightForIndexPath:indexPath
                              key:cacheKey];
    if (cachedHeight) {
        return cachedHeight.floatValue;
    }

    // 2) Get the view model from diffable data source

    CGFloat height = kPPPinterestMinCellHeight;

    // Your logic for calculating height...
    if (indexPath.item < [self buildViewModelsFromAds:self.ads].count) {
        PPUniversalCellViewModel *model = [self buildViewModelsFromAds:self.ads][indexPath.item];
        if ([model.ModelObject isKindOfClass:[PetAd class]]) {
            PetAd *ad = (PetAd *)model.ModelObject;
            PetImageItem *img = ad.imageItems.firstObject;
            if (img && img.width > 0) {
                height = width * (img.height / img.width);
            }
        }
        
        else if ([model.ModelObject isKindOfClass:[PetAccessory class]]) {
            PetAccessory *ad = (PetAccessory *)model.ModelObject;
            PetImageItem *img = ad.imageItems.firstObject;
            if (img && img.width > 0) {
                height = width * (img.height / img.width);
            }
        }
    }
    
    height = MAX(height, kPPPinterestMinCellHeight);
    
    [[PPHeightCacheManager sharedManager] setHeight:height forIndexPath:indexPath key:self.currentCellSectionKey];
    if(indexPath.item > ([self buildViewModelsFromAds:self.ads].count - 1 ))
    {
        [[PPHeightCacheManager sharedManager] saveCacheForKey:self.currentCellSectionKey];
        //NSLog(@"⚠️ [PPHeightCacheManager] saveCacheForKey %@", self.currentCellSectionKey);
    }
    return height;
}


-(NSString *)currentCellSectionKey
{
    switch (self.cellSection) {
        case CellSectionAds:
            return @"CellSectionAds";
            break;
            
        case CellSectionAccessories:
            return @"CellSectionAccessories";
            break;
            
        case CellSectionVet:
            return @"CellSectionVet";
            break;
            
        case CellSectionServices:
            return @"CellSectionServices";
            break;
            
        case CellSectionFood:
            return @"CellSectionFood";
            break;
            
        default:
            return @"CellSectionAds";
            break;
    }
}


-(void)dealloc
{
    [[PPHeightCacheManager sharedManager] saveCacheForKey:self.heightCacheKey];

}

#pragma mark - UICollectionViewDataSourcePrefetching

- (void)collectionView:(UICollectionView *)collectionView
prefetchItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {

    if (collectionView != self.adsCollectionView) return;

    YYWebImageManager *manager = [YYWebImageManager sharedManager];

    for (NSIndexPath *indexPath in indexPaths) {

        // Already prefetching?
        if (self.prefetchTasks[indexPath]) continue;

        PPUniversalCellViewModel *vm = [self.adsDataSource itemIdentifierForIndexPath:indexPath];
        if (!vm.imageURL.length) continue;

        NSURL *url = [NSURL URLWithString:vm.imageURL];
        if (!url) continue;

        // Cache key
        NSString *cacheKey = [manager cacheKeyForURL:url];
        if (!cacheKey.length) continue;

        // Already cached? no work needed
        if ([manager.cache getImageForKey:cacheKey]) {
            continue;
        }

        // Prefetch using YYWebImage manager
        YYWebImageOperation *op =
        [manager requestImageWithURL:url
                             options:YYWebImageOptionIgnorePlaceHolder
                            progress:nil
                           transform:nil
                          completion:^(UIImage * _Nullable image,
                                       NSURL * _Nonnull url,
                                       YYWebImageFromType from,
                                       YYWebImageStage stage,
                                       NSError * _Nullable error) {

            // Remove operation when done
            @synchronized (self.prefetchTasks) {
                [self.prefetchTasks removeObjectForKey:indexPath];
            }
        }];

        if (op) {
            @synchronized (self.prefetchTasks) {
                self.prefetchTasks[indexPath] = op;
            }
        }
    }
}

- (void)collectionView:(UICollectionView *)collectionView
cancelPrefetchingForItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {

    if (collectionView != self.adsCollectionView) return;

    @synchronized (self.prefetchTasks) {
        for (NSIndexPath *indexPath in indexPaths) {
            YYWebImageOperation *op = self.prefetchTasks[indexPath];
            if (op) {
                [op cancel];
                [self.prefetchTasks removeObjectForKey:indexPath];
            }
        }
    }
}



- (UIButton *)setContainerBackround
{
    UIButton *bgButton;
    if (@available(iOS 26.0, *)) {
        // 🧊 iOS 26+ system glass button
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        
        
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(0, 0, 0, 0);
        cfg.background.cornerRadius = 16;
 

        bgButton = [UIButton  buttonWithType:UIButtonTypeSystem];
        bgButton.configuration = cfg;
        //bgButton.clipsToBounds = NO;
    } else {
         
 
        // 🌫️ Fallback for iOS <26
        bgButton = [UIButton buttonWithType:UIButtonTypeSystem];
        bgButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        bgButton.layer.cornerRadius = 16;
        bgButton.layer.masksToBounds = YES;
        [bgButton pp_setShadowColor:AppShadowClr];
        bgButton.layer.shadowOpacity = 0.15;
        bgButton.layer.shadowRadius = 8;
        bgButton.layer.shadowOffset = CGSizeMake(0, 4);
    }

    bgButton.translatesAutoresizingMaskIntoConstraints = NO;
    return bgButton;
}
  
@end






@implementation PPCategoryKindCell
#pragma mark - Category Centering & Scaling



- (void) updateValuesWithTitle:(NSString *)title imageName:(NSString *)imageName
{
    UIImage *img = [UIImage systemImageNamed:imageName] ?: [UIImage imageNamed:imageName];
    
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *cfg = self.cellBgButton.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
        
        // Set the title with specific attributes (including font)
        cfg.attributedTitle = [[NSAttributedString alloc] initWithString:title
                                                              attributes:@{
            NSFontAttributeName: [GM boldFontWithSize:15],
            NSForegroundColorAttributeName: AppPrimaryTextClr
        }];
        cfg.baseForegroundColor = AppPrimaryClr;
        
        // Set the image for the button
        cfg.titleAlignment = UIButtonConfigurationTitleAlignmentTrailing;
        cfg.image = img;
        cfg.imagePlacement = NSDirectionalRectEdgeLeading;
        cfg.imagePadding = 10;
        cfg.background.backgroundColor = UIColor.clearColor;
        cfg.baseBackgroundColor = UIColor.clearColor;
        self.cellBgButton.configuration = cfg;
    } else {
        _iconView.image = img;
        _titleLabel.text = title;
    }
    
    
    _iconView.layer.cornerRadius = _iconView.hx_h / 2;
    _iconView.clipsToBounds = YES;

}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.contentView.layer.masksToBounds = NO;
        self.contentView.clipsToBounds = NO;
        
        self.layer.masksToBounds = NO;
        self.clipsToBounds = NO;
        
        self.contentView.backgroundColor = [UIColor clearColor];
        self.backgroundColor = [UIColor clearColor];
        
        // Create cellBgButton button
       
        if (@available(iOS 26.0, *)) {
            UIButtonConfiguration *config = [UIButtonConfiguration clearGlassButtonConfiguration];
            config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;

            self.cellBgButton = [UIButton buttonWithConfiguration:config primaryAction:nil];
        } else {
            self.cellBgButton = [UIButton buttonWithType:UIButtonTypeSystem];

            self.cellBgButton.backgroundColor = [AppBackgroundClrLigter colorWithAlphaComponent:1];
            self.cellBgButton.layer.cornerRadius = 22.0;
            self.cellBgButton.layer.masksToBounds = YES;
        }
        
        self.cellBgButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:self.cellBgButton];
        
        // cellBgButton width constraint - will be updated based on content
        self.cellBgButtonWidth = [self.cellBgButton.widthAnchor constraintEqualToConstant:0];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.cellBgButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [self.cellBgButton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [self.cellBgButton.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
            self.cellBgButtonWidth
        ]];
        
        // For iOS 14 and below
        if (@available(iOS 115.0, *)) {
            // iOS 15+ uses button configuration
        } else {
            _iconView = [[UIImageView alloc] init];
            _iconView.translatesAutoresizingMaskIntoConstraints = NO;
            _iconView.contentMode = UIViewContentModeScaleAspectFit;
            _iconView.tintColor = AppPrimaryClr;
            _iconView.backgroundColor = UIColor.clearColor;

            [self.cellBgButton addSubview:_iconView];
            
            _titleLabel = [[UILabel alloc] init];
            _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
            _titleLabel.font = [GM MidFontWithSize:15];
            _titleLabel.textColor = UIColor.labelColor;
            _titleLabel.backgroundColor = UIColor.clearColor;

            _titleLabel.textAlignment = NSTextAlignmentCenter;
            [self.cellBgButton addSubview:_titleLabel];
            
            [NSLayoutConstraint activateConstraints:@[
                [_iconView.leadingAnchor constraintEqualToAnchor:self.cellBgButton.leadingAnchor constant:5],
                [_iconView.centerYAnchor constraintEqualToAnchor:self.cellBgButton.centerYAnchor],
                [_iconView.widthAnchor constraintEqualToAnchor:self.cellBgButton.heightAnchor constant:-10],
                [_iconView.heightAnchor constraintEqualToAnchor:self.cellBgButton.heightAnchor constant:-10],
                
                [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:4],
                [_titleLabel.trailingAnchor constraintEqualToAnchor:self.cellBgButton.trailingAnchor constant:-4],
                [_titleLabel.centerYAnchor constraintEqualToAnchor:self.cellBgButton.centerYAnchor]
            ]];
        }
        self.cellBgButton.alpha =1;
        [self.cellBgButton addTarget:self action:@selector(cellBgButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)cellBgButtonTapped {
    NSLog(@"cellBgButtonTapped");
    [self.delegate didSelectIndex:self.indexPath.item];
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = self.cellBgButton.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
        
        if (selected) {
            config.background.backgroundColor = [AppClearClr colorWithAlphaComponent:0.00];
            config.baseForegroundColor = AppClearClr;
            
            // Update attributed title for selected state
            NSString *title = [config.attributedTitle string];
            if (title) {
                config.attributedTitle = [[NSAttributedString alloc] initWithString:title
                                                                          attributes:@{
                    NSFontAttributeName: [GM boldFontWithSize:15],
                    NSForegroundColorAttributeName: AppPrimaryClr
                }];
            }
        } else {
            config.background.backgroundColor = [AppBackgroundClrLigter colorWithAlphaComponent:1];
            config.baseForegroundColor = UIColor.labelColor;
            
            // Update attributed title for normal state
            NSString *title = [config.attributedTitle string];
            if (title) {
                config.attributedTitle = [[NSAttributedString alloc] initWithString:title
                                                                          attributes:@{
                    NSFontAttributeName: [GM MidFontWithSize:15],
                    NSForegroundColorAttributeName: UIColor.labelColor
                }];
            }
        }
        
        self.cellBgButton.configuration = config;
    } else {
        if (selected) {
            self.cellBgButton.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.0];
            _titleLabel.textColor = AppPrimaryClr;
            _iconView.tintColor = AppPrimaryClr;
            _titleLabel.font = [GM boldFontWithSize:15];
        } else {
            self.cellBgButton.backgroundColor = [AppBackgroundClrLigter colorWithAlphaComponent:0];
            _titleLabel.textColor = UIColor.labelColor;
            _iconView.tintColor = UIColor.labelColor;
            _titleLabel.font = [GM MidFontWithSize:15];
        }
    }
}

- (void)updateCellBgButtonWidth:(CGFloat)width {
    self.cellBgButtonWidth.constant = width;
}

@end





















//
//  LTInfiniteScrollView.m
//  LTInfiniteScrollView
//
//  Created by ltebean on 14/11/21.
//  Copyright (c) 2014年 ltebean. All rights reserved.
//



@interface LTInfiniteScrollView()<UIScrollViewDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic) CGFloat viewSize;
@property (nonatomic) NSInteger visibleViewCount;
@property (nonatomic) NSInteger totalViewCount;
@property (nonatomic) CGFloat previousPosition;
@property (nonatomic) CGFloat totalSize;
@property (nonatomic) ScrollDirection scrollDirection;
@property (nonatomic, strong) NSMutableDictionary *views;
@end

@implementation LTInfiniteScrollView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setup];
    }
    return self;
}

- (CGFloat)scrollViewSize
{
    return self.verticalScroll ? self.bounds.size.height : self.bounds.size.width;
}

- (CGFloat)scrollViewContentSize
{
    CGSize size = self.scrollView.contentSize;
    return self.verticalScroll ? size.height : size.width;
}

- (CGFloat)scrollPosition
{
    CGPoint position = self.scrollView.contentOffset;
    return self.verticalScroll ? position.y : position.x;
}

- (void)setup
{
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds))];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleHeight;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.delegate = self;
    self.scrollView.clipsToBounds = NO;
    self.scrollView.pagingEnabled = self.pagingEnabled;
    [self addSubview:self.scrollView];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.scrollView.frame = self.bounds;
    NSInteger index = self.currentIndex;
    [self updateSize];
    if (self.views.count == 0) {
        return;
    }
    for (UIView *view in self.views.allValues) {
        view.center = [self centerForViewAtIndex:view.tag];
    }
    [self scrollToIndex:index animated:NO];
}

#pragma mark - public methods

- (void)setPagingEnabled:(BOOL)pagingEnabled
{
    _pagingEnabled = pagingEnabled;
    self.scrollView.pagingEnabled = pagingEnabled;
}

- (void)setScrollEnabled:(BOOL)scrollEnabled
{
    _scrollEnabled = scrollEnabled;
    self.scrollView.scrollEnabled = scrollEnabled;
}

- (void)setBounces:(BOOL)bounces
{
    _bounces = bounces;
    self.scrollView.bounces = bounces;
}

- (void)setContentInset:(UIEdgeInsets)contentInset
{
    _contentInset = contentInset;
    self.scrollView.contentInset = contentInset;
}

- (void)reloadDataWithInitialIndex:(NSInteger)initialIndex
{
    for (UIView *view in self.scrollView.subviews) {
        [view removeFromSuperview];
    }
    self.views = [NSMutableDictionary dictionary];

    self.visibleViewCount = [self.dataSource numberOfVisibleViews];
    self.totalViewCount = [self.dataSource numberOfViews];
    
    [self updateSize];
    _currentIndex = initialIndex;
    self.scrollView.contentOffset = [self contentOffsetForIndex:_currentIndex];
    [self reArrangeViews];
    [self updateProgress];
}

- (void)scrollToIndex:(NSInteger)index animated:(BOOL)animated
{
    if (index < _currentIndex) {
        self.scrollDirection = ScrollDirectionPrev;
    } else {
        self.scrollDirection = ScrollDirectionNext;
    }
    [self.scrollView setContentOffset:[self contentOffsetForIndex:index] animated:animated];
}

- (UIView *)viewAtIndex:(NSInteger)index
{
    return self.views[@(index)];
}

- (NSArray *)allViews
{
    return [self.views allValues];
}

#pragma mark - private methods

- (void)updateSize
{
    self.viewSize = self.scrollViewSize / self.visibleViewCount;;
    self.totalSize = self.viewSize * self.totalViewCount;
    if (self.verticalScroll) {
        self.scrollView.contentSize = CGSizeMake(CGRectGetWidth(self.bounds), self.totalSize);
    } else {
        self.scrollView.contentSize = CGSizeMake(self.totalSize, CGRectGetHeight(self.bounds));
    }
}

- (void)reArrangeViews
{
    NSMutableSet *indexesNeeded = [NSMutableSet set];
    NSInteger begin = _currentIndex -ceil(self.visibleViewCount / 2.0f);
    NSInteger end = _currentIndex + ceil(self.visibleViewCount / 2.0f);
    
    for (NSInteger i = begin; i <= end; i++) {
        if (i < 0 ) {
            NSInteger index = end - i;
            if (index < self.totalViewCount) {
                [indexesNeeded addObject:@(index)];
            }
        }
        else if (i >= self.totalViewCount) {
            NSInteger index = begin - i;
            if (index >= 0) {
                [indexesNeeded addObject:@(index)];
            }
        }
        else {
            [indexesNeeded addObject:@(i)];
        }
    }
    for (NSNumber *indexNeeded in indexesNeeded) {
        UIView *view = self.views[indexNeeded];
        if (view) {
            continue;
        }
        // find view to reuse
        for (NSNumber *index in [self.views allKeys]) {
            if (![indexesNeeded containsObject:index]) {
                view = self.views[index];
                [self.views removeObjectForKey:index];
                break;
            }
        }
        view = [self.dataSource viewAtIndex:indexNeeded.integerValue reusingView:view];
        [view removeFromSuperview];
        view.tag = indexNeeded.integerValue;
        view.center = [self centerForViewAtIndex:indexNeeded.integerValue];
        self.views[indexNeeded] = view;
        [self.scrollView addSubview:view];
    }
}

- (void)updateProgress
{
    if (![self.delegate respondsToSelector:@selector(updateView:withProgress:scrollDirection:)]) {
        return;
    }
    CGFloat center = [self currentCenter];
    NSArray *allViews = [self allViews];
    for (UIView *view in allViews) {
        CGFloat progress;
        if (self.verticalScroll) {
            progress = (view.center.y - center) / CGRectGetHeight(self.bounds) * self.visibleViewCount;
        } else {
            progress = (view.center.x - center) / CGRectGetWidth(self.bounds) * self.visibleViewCount;
        }
        [self.delegate updateView:view withProgress:progress scrollDirection:self.scrollDirection];
    }
}

- (void)didScrollToIndex:(NSInteger)index
{
    if ([self.delegate respondsToSelector:@selector(scrollView:didScrollToIndex:)]) {
        [self.delegate scrollView:self didScrollToIndex:self.currentIndex];
    }
}

# pragma mark - UIScrollView delegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat currentCenter = [self currentCenter];
    CGFloat offset = [self scrollPosition];
    
    _currentIndex = round((currentCenter - self.viewSize / 2) / self.viewSize);
    if (offset > self.previousPosition) {
        self.scrollDirection = ScrollDirectionNext;
    } else {
        self.scrollDirection = ScrollDirectionPrev;
    }
    self.previousPosition = offset;
    
    [self reArrangeViews];
    [self updateProgress];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!self.pagingEnabled && !decelerate && self.needsCenterPage) {
        CGFloat offset = [self scrollPosition];
        if (offset < 0 || offset > self.scrollViewContentSize) {
            return;
        }
        [self.scrollView setContentOffset:[self contentOffsetForIndex:self.currentIndex] animated:YES];
        [self didScrollToIndex:self.currentIndex];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (!self.pagingEnabled && self.needsCenterPage) {
        [self.scrollView setContentOffset:[self contentOffsetForIndex:self.currentIndex] animated:YES];
    }
    [self didScrollToIndex:self.currentIndex];
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    if (self.maxScrollDistance <= 0) {
        return;
    }
    if (![self needsCenterPage]) {
        return;
    }
    CGFloat target = self.verticalScroll ? targetContentOffset -> y : targetContentOffset -> x;
    CGPoint contentOffset = [self contentOffsetForIndex:self.currentIndex];
    CGFloat current = self.verticalScroll ? contentOffset.y : contentOffset.x;
    if (fabs(target - current) <= self.viewSize / 2) {
        return;
    } else {
        NSInteger distance = self.maxScrollDistance - 1;
        NSInteger currentIndex = [self currentIndex];
        NSInteger targetIndex = self.scrollDirection == ScrollDirectionNext ? currentIndex + distance : currentIndex - distance;
        CGPoint targetOffset = [self contentOffsetForIndex:targetIndex];
        if (self.verticalScroll) {
            targetContentOffset -> y = targetOffset.y;
        } else {
            targetContentOffset -> x = targetOffset.x;
        }
    }
}

#pragma mark - helper methods

- (BOOL)needsCenterPage
{
    CGFloat position = [self scrollPosition];
    if (position < 0 || position > self.scrollViewContentSize - self.viewSize) {
        return NO;
    } else {
        return YES;
    }
}

- (CGFloat)currentCenter
{
    return self.scrollPosition + self.scrollViewSize / 2.0f;
}

- (CGPoint)contentOffsetForIndex:(NSInteger)index
{
    CGPoint point = [self centerForViewAtIndex:index];
    
    CGFloat center = self.verticalScroll ? point.y : point.x;
    CGFloat position = center - self.scrollViewSize / 2.0f;
    position = MAX(0, position);
    position = MIN(position, self.scrollViewContentSize);
    if (self.verticalScroll) {
        return CGPointMake(0, position);
    } else {
        return CGPointMake(position, 0);
    }
}

- (CGPoint)centerForViewAtIndex:(NSInteger)index
{
    CGFloat position = index * self.viewSize + self.viewSize / 2;
    if (self.verticalScroll) {
        return CGPointMake(CGRectGetMidX(self.bounds), position);
    } else {
        return CGPointMake(position, CGRectGetMidY(self.bounds));
    }
}

@end
