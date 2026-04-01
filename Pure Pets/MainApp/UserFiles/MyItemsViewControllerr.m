//
//  MyItemsViewController 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/12/2025.
//


//
//  MyItemsViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 31/05/2025.
//  Refactored by ChatGPT
//

#import "MyItemsViewController.h"
#import "PetAdManager.h"
#import "PetAccessoryManager.h"
#import "AdoptPetManager.h"
#import "PetAd.h"
#import "PetAccessory.h"
#import "AdoptPetCell.h"
#import "AdoptPetModel.h"
#import "AppClasses.h"
#import "GM.h"
#import "PPImageLoaderManager.h"
 
#import "UserManager.h"
#import "AdoptPetManager.h"

@interface MyItemsViewController () <
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout,
    AdoptCollectionViewCellDelegate,
    AddNewAdDelegate
>

@property (nonatomic, assign) MyItemsMode mode;
@property (nonatomic, strong) UICollectionView *collectionView;
 @property (nonatomic, strong) NSArray *items;
@property (nonatomic, strong) CCActivityHUD *activityHUD;

// cached sets (optional)
@property (nonatomic, strong) NSArray *allAds;
@property (nonatomic, strong) NSArray *allAccessories;
@property (nonatomic, strong) NSArray *allFoods;
@property (nonatomic, strong) NSArray *allAdoptPets;

@end

@implementation MyItemsViewController

- (instancetype)initWithMode:(MyItemsMode)mode {
    if (self = [super init]) {
        _mode = mode;
    }
    return self;
}

- (instancetype)initWithMode:(MyItemsMode)mode viewType:(ViewType)viewType {
    if (self = [self initWithMode:mode]) {
        // store desired initial view type in a tag on self.segmentedControl after creation,
        // or apply it in viewDidLoad. We'll store a property-less workaround: set in viewDidLoad via a dispatch.
        dispatch_async(dispatch_get_main_queue(), ^{
            
            self.viewType = viewType;
            // We'll call segmentChanged after viewDidLoad sets up the segmentedControl.
            // If segmentedControl isn't created yet, segmentChanged will be called from viewDidLoad.
            switch (viewType) {
                case ViewTypeAds:      self.segmentedControl.selectedSegmentIndex = 0; break;
                case ViewTypeAccess:   self.segmentedControl.selectedSegmentIndex = 1; break;
                case ViewTypeFood:     self.segmentedControl.selectedSegmentIndex = 2; break;
                case ViewTypeAdopt:    self.segmentedControl.selectedSegmentIndex = 3; break;
                default:               self.segmentedControl.selectedSegmentIndex = 0; break;
            }
            [self fetchDataForCurrentSegment];
        });
    }
    return self;
}

#pragma mark - 📦 Section Handling Helpers

- (NSArray<PPUniversalCellViewModel *> *)pp_currentUniversalModelArray {
    return [self pp_generateUniversalModelsArrayFromArray:self.pp_currentDataSourse];
}

- (NSArray<id> *)pp_currentDataSourse {
    switch (self.viewType) {
        case ViewTypeAds:           return self.allAds;
        case ViewTypeAccess:  return self.allAccessories;
        case ViewTypeFood:          return self.allFoods;
        case ViewTypeAdopt:      return self.allAdoptPets;
        default:                       return 0;
    }
}

- (NSInteger)pp_currentDataCount {
    switch (self.viewType) {
        case ViewTypeAds:           return self.allAds.count;
        case ViewTypeAccess:  return self.allAccessories.count;
        case ViewTypeFood:          return self.allFoods.count;
        case ViewTypeAdopt:      return self.allAdoptPets.count;
        default:                       return 0;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = PPBackgroundColorForIOS26(GM.backOffwhileColor);
    
    NSArray *segmTitles = [GM getAdsAccessSegmentedTitleForLanguage:[Language languageVal]];
    self.segmentedControl = [[UISegmentedControl alloc] initWithItems:segmTitles];
    self.segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    
    // Style segmented control (use your helper)
    [self pp_styleSegment:self.segmentedControl];
    
    [self.view addSubview:self.segmentedControl];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.segmentedControl.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10],
        [self.segmentedControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:10],
        [self.segmentedControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-10],
        [self.segmentedControl.heightAnchor constraintEqualToConstant:40]
    ]];
    
    [self setActivityIndecator];
    [self setupCollectionView];
    
    // Ensure a default index (if not set externally)
    if (self.segmentedControl.selectedSegmentIndex < 0) {
        self.segmentedControl.selectedSegmentIndex = 0;
    }
    
    // Initially load content for current mode+segment
    [self.activityHUD show];
    [self fetchDataForCurrentSegment];
    
    self.segmentedControl.semanticContentAttribute = [GM setSemantic];
}

#pragma mark - UI Setup

- (void)setupCollectionView {
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.minimumLineSpacing = 10;
    layout.minimumInteritemSpacing = 10;
    layout.sectionInset = UIEdgeInsetsMake(10, 10, 10, 10);
    
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.backgroundColor = GM.backOffwhileColor;
    self.collectionView.layer.cornerRadius = 15;
    self.collectionView.clipsToBounds = YES;
    
    // Register cells (single AdCell used for both PetAd & PetAccessory)

    [self.collectionView registerClass:AdoptPetCell.class forCellWithReuseIdentifier:@"AdoptPetCell"];
    [self.collectionView registerClass:[PPUniversalCell class] forCellWithReuseIdentifier:@"PPUniversalCell"];

    [self.view addSubview:self.collectionView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor constraintEqualToAnchor:self.segmentedControl.bottomAnchor constant:8],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)setActivityIndecator {
    self.activityHUD = [CCActivityHUD new];
    self.activityHUD.isTheOnlyActiveView = YES;
    self.activityHUD.backColor = [UIColor clearColor];
    self.activityHUD.indicatorColor = [GM appPrimaryColor];
    self.activityHUD.overlayType = CCActivityHUDOverlayTypeShadow;
    [self.activityHUD setAppearAnimationType:CCActivityHUDAppearAnimationTypeZoomIn];
    [self.activityHUD setDisappearAnimationType:CCActivityHUDDisappearAnimationTypeZoomOut];
}

#pragma mark - Segment & Fetch

- (void)segmentChanged:(UISegmentedControl *)sender {
    [self.activityHUD show];
    // scroll to top for better UX
    if (self.collectionView.numberOfSections > 0 && [self.collectionView numberOfItemsInSection:0] > 0) {
        [self.collectionView setContentOffset:CGPointZero animated:NO];
    }
    [self fetchDataForCurrentSegment];
}

- (void)fetchDataForCurrentSegment {
    if (self.mode == MyItemsModeMyAds) {
        switch (self.segmentedControl.selectedSegmentIndex) {
            case 0: _viewType = ViewTypeAds; [self fetchAds]; break;
            case 1: _viewType = ViewTypeAccess; [self fetchAccessories]; break;
            case 2: _viewType = ViewTypeFood; [self fetchFood]; break;
            case 3: _viewType = ViewTypeAdopt; [self fetchAdopt]; break;
            default: _viewType = ViewTypeAds; [self fetchAds]; break;
        }
    } else {
        // favorites
        switch (self.segmentedControl.selectedSegmentIndex) {
            case 0: _viewType = ViewTypeAds; [self fetchFavoriteAdsOnly]; break;
            case 1: _viewType = ViewTypeAccess; [self fetchFavoriteAccessoriesOnly]; break;
            case 2: _viewType = ViewTypeFood; [self fetchFavoriteFoodOnly]; break;
            case 3: _viewType = ViewTypeAdopt; [self fetchFavoriteAdoptOnly]; break;
            default: _viewType = ViewTypeAds; [self fetchFavoriteAdsOnly]; break;
        }
    }
}
#pragma mark - My Ads Fetchers

- (void)fetchAds {
    NSString *userID = [UserManager sharedManager].currentUser.ID;
    NSLog(@"[MyItems] fetchAds START userID=%@", userID);

    __weak typeof(self) weakSelf = self;
    [PetAdManager fetchAdsForUserID:userID completion:^(NSArray *fetchedAds) {

        NSLog(@"[MyItems] fetchAds DONE count=%lu", (unsigned long)fetchedAds.count);

        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.items = fetchedAds ?: @[];
            [AppClasses reloadThisCollectionView:weakSelf.collectionView];
            [weakSelf.activityHUD dismiss];

            NSLog(@"[MyItems] fetchAds UI updated");
        });
    }];
}

- (void)fetchAccessories {
    NSString *userID = [UserManager sharedManager].currentUser.ID;
    NSLog(@"[MyItems] fetchAccessories START userID=%@", userID);

    __weak typeof(self) weakSelf = self;
    [PetAccessoryManager fetchAccessoriesForUserID:userID
                                   accessKindType:AccessTypeAccessory
                                       completion:^(NSArray<PetAccessory *> * _Nonnull list) {

        NSLog(@"[MyItems] fetchAccessories DONE count=%lu", (unsigned long)list.count);

        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.items = list ?: @[];
            [AppClasses reloadThisCollectionView:weakSelf.collectionView];
            [weakSelf.activityHUD dismiss];

            NSLog(@"[MyItems] fetchAccessories UI updated");
        });
    }];
}

- (void)fetchFood {
    NSString *userID = [UserManager sharedManager].currentUser.ID;
    NSLog(@"[MyItems] fetchFood START userID=%@", userID);

    __weak typeof(self) weakSelf = self;
    [PetAccessoryManager fetchAccessoriesForUserID:userID
                                   accessKindType:AccessTypeFood
                                       completion:^(NSArray<PetAccessory *> * _Nonnull list) {
        
        NSLog(@"[MyItems] fetchFood DONE count=%lu", (unsigned long)list.count);

        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.items = list ?: @[];
            [AppClasses reloadThisCollectionView:weakSelf.collectionView];
            [weakSelf.activityHUD dismiss];

            NSLog(@"[MyItems] fetchFood UI updated");
        });
    }];
}

- (void)fetchAdopt {
    NSString *userID = [UserManager sharedManager].currentUser.ID;
    NSLog(@"[MyItems] fetchAdopt START userID=%@", userID);

    __weak typeof(self) weakSelf = self;
    [AdoptPetManager.shared fetchPetsForUserID:userID completion:^(NSArray<AdoptPetModel *> * _Nullable pets, NSError * _Nullable error) {

        if (error) {
            NSLog(@"[MyItems] fetchAdopt ERROR: %@", error);
        }
        NSLog(@"[MyItems] fetchAdopt DONE count=%lu", (unsigned long)pets.count);

        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.items = pets ?: @[];
            [AppClasses reloadThisCollectionView:weakSelf.collectionView];
            [weakSelf.activityHUD dismiss];

            NSLog(@"[MyItems] fetchAdopt UI updated");
        });
    }];
}

#pragma mark - Favorites Fetchers

- (void)fetchFavoriteAdsOnly {
    NSString *userID = [UserManager sharedManager].currentUser.ID;
    NSLog(@"[MyItems] fetchFavoriteAdsOnly START userID=%@", userID);

    __weak typeof(self) weakSelf = self;
    [PetAdManager fetchFavoriteAdIDsForUserID:userID
                                   collection:@"favoritesAds"
                                   completion:^(NSArray<NSString *> *adIDs) {

        NSLog(@"[MyItems] favoriteAds IDs count=%lu -> %@", (unsigned long)adIDs.count, adIDs);

        [PetAdManager fetchAdsWithIDs:adIDs completion:^(NSArray *fetchedAds) {

            NSLog(@"[MyItems] favoriteAds fetched count=%lu", (unsigned long)fetchedAds.count);

            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.items = fetchedAds ?: @[];
                [AppClasses reloadThisCollectionView:weakSelf.collectionView];
                [weakSelf.activityHUD dismiss];

                NSLog(@"[MyItems] fetchFavoriteAdsOnly UI updated");
            });
        }];
    }];
}

- (void)fetchFavoriteAccessoriesOnly {
    NSString *userID = [UserManager sharedManager].currentUser.ID;
    NSLog(@"[MyItems] fetchFavoriteAccessoriesOnly START userID=%@", userID);

    __weak typeof(self) weakSelf = self;
    [PetAdManager fetchFavoriteAdIDsForUserID:userID
                                   collection:@"favoritesAccessories"
                                   completion:^(NSArray<NSString *> *accIDs) {

        NSLog(@"[MyItems] favoriteAccessories IDs count=%lu -> %@", (unsigned long)accIDs.count, accIDs);

        [PetAccessoryManager fetchAccessoriesWithIDs:accIDs completion:^(NSArray *fetchedAccessories) {

            NSLog(@"[MyItems] favoriteAccessories fetched count=%lu", (unsigned long)fetchedAccessories.count);

            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.items = fetchedAccessories ?: @[];
                [AppClasses reloadThisCollectionView:weakSelf.collectionView];
                [weakSelf.activityHUD dismiss];

                NSLog(@"[MyItems] fetchFavoriteAccessoriesOnly UI updated");
            });
        }];
    }];
}

- (void)fetchFavoriteFoodOnly {
    NSString *userID = [UserManager sharedManager].currentUser.ID;
    NSLog(@"[MyItems] fetchFavoriteFoodOnly START userID=%@", userID);

    __weak typeof(self) weakSelf = self;
    [PetAdManager fetchFavoriteAdIDsForUserID:userID
                                   collection:@"favoritesAccessories"
                                   completion:^(NSArray<NSString *> *accIDs) {

        NSLog(@"[MyItems] favoriteFood IDs count=%lu -> %@", (unsigned long)accIDs.count, accIDs);

        [PetAccessoryManager fetchAccessoriesWithIDs:accIDs completion:^(NSArray *fetchedAccessories) {

            NSLog(@"[MyItems] favoriteFood fetched count=%lu", (unsigned long)fetchedAccessories.count);

            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.items = fetchedAccessories ?: @[];
                [AppClasses reloadThisCollectionView:weakSelf.collectionView];
                [weakSelf.activityHUD dismiss];

                NSLog(@"[MyItems] fetchFavoriteFoodOnly UI updated");
            });
        }];
    }];
}

- (void)fetchFavoriteAdoptOnly {
    NSString *userID = [UserManager sharedManager].currentUser.ID;
    NSLog(@"[MyItems] fetchFavoriteAdoptOnly START userID=%@", userID);

    __weak typeof(self) weakSelf = self;
    [PetAdManager fetchFavoriteAdIDsForUserID:userID
                                   collection:@"favoritesAdoptPets"
                                   completion:^(NSArray<NSString *> *accIDs) {

        NSLog(@"[MyItems] favoriteAdopt IDs count=%lu -> %@", (unsigned long)accIDs.count, accIDs);

        [AdoptPetManager.shared fetchPetsWithIDs:accIDs completion:^(NSArray<AdoptPetModel *> * _Nullable pets, NSError * _Nullable error) {

            if (error) {
                NSLog(@"[MyItems] fetchFavoriteAdoptOnly ERROR: %@", error);
            }

            NSLog(@"[MyItems] favoriteAdopt fetched count=%lu", (unsigned long)pets.count);

            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.items = pets ?: @[];
                [AppClasses reloadThisCollectionView:weakSelf.collectionView];
                [weakSelf.activityHUD dismiss];

                NSLog(@"[MyItems] fetchFavoriteAdoptOnly UI updated");
            });
        }];
    }];
}


#pragma mark - Collection View

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.pp_currentUniversalModelArray.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    id universalViewModel = self.pp_currentUniversalModelArray[indexPath.item];
    
    
    PPUniversalCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"PPUniversalCell" forIndexPath:indexPath];
    if (![universalViewModel isKindOfClass:[PPUniversalCellViewModel class]])
    {  NSLog(@"⚠️ Expected PPUniversalCellViewModel but got %@", [universalViewModel class]); return cell; }
    
    PPUniversalCellViewModel *universalModel = (PPUniversalCellViewModel *)universalViewModel;
    universalModel.indexPath = indexPath;
    [cell applyViewModel:universalModel context:universalModel.modelContext layoutMode:PPCellLayoutModePinterest discountMode:PPDiscountStyleBadge imageLoader:^(UIImageView * _Nonnull imageView,
                                                                                                                                                                 NSString * _Nullable urlString,
                                                                                                                                                                 UIImage * _Nullable placeholder,
                                                                                                                                                                 UIView * _Nullable card) {
         
        [[PPImageLoaderManager shared] setImageOnImageView:imageView url:urlString  complation:^(UIImage * _Nonnull image, NSString * _Nullable urlString) {
            
        }] ;
         
    }];
   // cell.delegate = self; return cell;
    return cell;
    /*
     
     
     
     if ([item isKindOfClass:PetAd.class]) {
         PetAdCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"AdCell" forIndexPath:indexPath];
         [cell configureWithPetAd:(PetAd *)item];
         cell.qtyButton.alpha = 0;
         if (self.mode == MyItemsModeMyAds) {
             [cell layoutForMyAds];
         } else {
             [cell layoutForAds];
         }
         cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
         cell.delegate = self;
         [cell setCellLayout:CellLayoutattachbuttomView];
         return cell;
         
     } else if ([item isKindOfClass:PetAccessory.class]) {
         PetAdCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"AdCell" forIndexPath:indexPath];
         [cell configureWithPetAccessory:(PetAccessory *)item];
         cell.qtyButton.alpha = 0;
         if (self.mode == MyItemsModeMyAds) {
             [cell layoutForMyAccess];
         } else {
             [cell layoutForAccess];
         }
         cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
         cell.delegate = self;
         [cell setCellLayout:CellLayoutattachbuttomView];
         return cell;
         
     } else if ([item isKindOfClass:AdoptPetModel.class]) {
         AdoptPetModel *model = (AdoptPetModel *)item;
         AdoptPetCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"AdoptPetCell" forIndexPath:indexPath];
         cell.adoptModel = model;
         cell.delegate = self;
         NSString *cityName = [CitiesManager.shared cityNameForID:model.cityID];
         [cell configureWithName:model.name imageURL:model.imageURLs.firstObject subtitle:cityName adoptPetModel:model];
         [cell pp_applyOwnerMode:(self.mode == MyItemsModeMyAds) animated:YES];
         cell.delegate = self;
         return cell;
     }
     
     // fallback
     PetAdCollectionViewCell *fallback = [collectionView dequeueReusableCellWithReuseIdentifier:@"AdCell" forIndexPath:indexPath];
     return fallback;
     */
}

#pragma mark - Collection view layout sizing

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat itemSize = (collectionView.hx_w - 30) / 2.0;
    return CGSizeMake(itemSize, itemSize + 45);
}

#pragma mark - Cell actions (edit/delete) handlers
 
#pragma mark - Adopt cell delegate

- (void)adoptCellDidTapEdit:(AdoptPetCell *)cell onModel:(AdoptPetModel *)adoptModel {
    AddAdoptPetViewController *vc = [[AddAdoptPetViewController alloc] init];
    vc.editingPet = adoptModel;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)adoptCellDidTapDelete:(AdoptPetCell *)cell onModel:(AdoptPetModel *)adoptModel {
    [GM showDeleteConfirmationFrom:self
                             title:kLang(@"Confirm Deletion")
                           message:kLang(@"Are you sure you want to delete this item?")
                        completion:^(BOOL confirmed) {
        if (!confirmed) return;
        [AdoptPetManager.shared deletePetWithID:adoptModel.documentID completion:^(BOOL success, NSError * _Nullable error) {
            [AppClasses reloadThisCollectionView:self.collectionView completion:^(BOOL finished) {
                [AppManager.sharedInstance showSnakBar:kLang(@"Trash") withColor:GM.appPrimaryColor andDuration:0.3 containerView:self.view];
            }];
        }];
    }];
}

#pragma mark - AddNewAdDelegate

- (void)addNewAd:(AddNewAd *)vc didUpdateAd:(PetAd *)ad {
    [AppClasses reloadThisCollectionView:self.collectionView completion:^(BOOL finished) {}];
}

#pragma mark - View lifecycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (self.mode == MyItemsModeMyAds) {
        [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"myadsTitle") showBack:NO];
        [self fetchAllMyItems]; // keep your "all" endpoint if needed elsewhere
    } else {
        [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"myfavTitle") showBack:NO];
        [self fetchAllMyFavItems];
    }
}

#pragma mark - Combined fetch helpers (optional aggregated views)

- (void)fetchAllMyItems {
    NSString *userID = [UserManager sharedManager].currentUser.ID;
    dispatch_group_t group = dispatch_group_create();
    
    __block NSArray *ads = @[];
    __block NSArray *accessories = @[];
    __block NSArray *foods = @[];
    __block NSArray *adopts = @[];
    
    dispatch_group_enter(group);
    [PetAdManager fetchAdsForUserID:userID completion:^(NSArray *fetchedAds) {
        ads = fetchedAds ?: @[];
        dispatch_group_leave(group);
    }];
    
    dispatch_group_enter(group);
    [PetAccessoryManager fetchAccessoriesForUserID:userID accessKindType:AccessTypeAccessory completion:^(NSArray *list) {
        accessories = list ?: @[];
        dispatch_group_leave(group);
    }];
    
    dispatch_group_enter(group);
    [PetAccessoryManager fetchAccessoriesForUserID:userID accessKindType:AccessTypeFood completion:^(NSArray *list) {
        foods = list ?: @[];
        dispatch_group_leave(group);
    }];
    
    dispatch_group_enter(group);
    [AdoptPetManager.shared fetchPetsForUserID:userID completion:^(NSArray<AdoptPetModel *> * _Nullable pets, NSError * _Nullable error) {
        adopts = pets ?: @[];
        dispatch_group_leave(group);
    }];
    
    __weak typeof(self) weakSelf = self;
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        weakSelf.allAds = ads;
        weakSelf.allAccessories = accessories;
        weakSelf.allFoods = foods;
        weakSelf.allAdoptPets = adopts;
        
        NSArray *combined = [adopts arrayByAddingObjectsFromArray:[ads arrayByAddingObjectsFromArray:[accessories arrayByAddingObjectsFromArray:foods]]];
        weakSelf.items = combined;
        [AppClasses reloadThisCollectionView:weakSelf.collectionView completion:^(BOOL finished) {
            PPEmptyStateConfig *cfg = [PPEmptyStateConfig new];
            cfg.animationName = @"Emptyred.json";
            cfg.title = kLang(@"nodata");
            cfg.target = weakSelf;
            cfg.isNetworkFile = YES;
            NSInteger totalItems = [weakSelf.collectionView numberOfItemsInSection:0];
            [PPEmptyStateHelper updateEmptyStateForListView:weakSelf.collectionView dataCount:totalItems config:cfg];
        }];
        [weakSelf.activityHUD dismiss];
    });
}

- (void)fetchAllMyFavItems {
    NSString *userID = [UserManager sharedManager].currentUser.ID;
    dispatch_group_t group = dispatch_group_create();
    
    __block NSArray *ads = @[];
    __block NSArray *accessories = @[];
    __block NSArray *foods = @[];
    __block NSArray *adopts = @[];
    
    dispatch_group_enter(group);
    [PetAdManager fetchFavoriteAdIDsForUserID:userID collection:@"favoritesAds" completion:^(NSArray<NSString *> *adIDs) {
        [PetAdManager fetchAdsWithIDs:adIDs completion:^(NSArray *fetchedAds) {
            ads = fetchedAds ?: @[];
            dispatch_group_leave(group);
        }];
    }];
    
    dispatch_group_enter(group);
    [PetAdManager fetchFavoriteAdIDsForUserID:userID collection:@"favoritesAccessories" completion:^(NSArray<NSString *> *accIDs) {
        [PetAccessoryManager fetchAccessoriesWithIDs:accIDs completion:^(NSArray *fetchedAccessories) {
            accessories = fetchedAccessories ?: @[];
            dispatch_group_leave(group);
        }];
    }];
    
    dispatch_group_enter(group);
    [PetAdManager fetchFavoriteAdIDsForUserID:userID collection:@"favoritesAccessories" completion:^(NSArray<NSString *> *accIDs) {
        [PetAccessoryManager fetchAccessoriesWithIDs:accIDs completion:^(NSArray *fetchedFoods) {
            foods = fetchedFoods ?: @[];
            dispatch_group_leave(group);
        }];
    }];
    
    dispatch_group_enter(group);
    [PetAdManager fetchFavoriteAdIDsForUserID:userID collection:@"favoritesAdoptPets" completion:^(NSArray<NSString *> *accIDs) {
        [AdoptPetManager.shared fetchPetsWithIDs:accIDs completion:^(NSArray<AdoptPetModel *> * _Nullable pets, NSError * _Nullable error) {
            adopts = pets ?: @[];
            dispatch_group_leave(group);
        }];
    }];
    
    __weak typeof(self) weakSelf = self;
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        weakSelf.allAds = ads;
        weakSelf.allAccessories = accessories;
        weakSelf.allFoods = foods;
        weakSelf.allAdoptPets = adopts;
        
        NSArray *combined = [adopts arrayByAddingObjectsFromArray:[ads arrayByAddingObjectsFromArray:[accessories arrayByAddingObjectsFromArray:foods]]];
        weakSelf.items = combined;
        [AppClasses reloadThisCollectionView:weakSelf.collectionView completion:^(BOOL finished) {
            [GM ConfigEmptyViewForCollection:weakSelf.collectionView Title:kLang(@"") Subtitle:kLang(@"") imageName:kLang(@"") completion:^(NSInteger complete) {}];
        }];
        [weakSelf.activityHUD dismiss];
    });
}

#pragma mark - Utilities

- (void)customBackPressed {
    [GM playSoundWithName:@"myClick" type:@"mp3"];
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - layout stubs

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
}


- (void)pp_styleSegment:(UISegmentedControl *)seg {
    if (!seg) return;

    // Height
    seg.translatesAutoresizingMaskIntoConstraints = NO;
    [seg.heightAnchor constraintEqualToConstant:50.0].active = YES;

    // Pill style
    seg.layer.cornerRadius = 25.0;
    seg.layer.masksToBounds = YES;
    seg.clipsToBounds = YES;

    // Title attributes
    NSDictionary *normalAttrs = @{
        NSForegroundColorAttributeName : GM.SecondaryTextColor ?: UIColor.darkTextColor,
        NSFontAttributeName            : [GM fontWithSize:14]
    };
    NSDictionary *selectedAttrs = @{
        NSForegroundColorAttributeName : GM.AppForegroundColor,
        NSFontAttributeName            : [GM boldFontWithSize:14]
    };

    [seg setTitleTextAttributes:normalAttrs   forState:UIControlStateNormal];
    [seg setTitleTextAttributes:selectedAttrs forState:UIControlStateSelected];

    // Background images (resizable solid colors)
    //UIImage *bgNormal = [self pp_imageWithColor:[GM AppForegroundColor]];
   // UIImage *bgSelect = [self pp_imageWithColor:[GM appPrimaryColor]];

    if (@available(iOS 13.0, *)) {
        // Selected segment tint
        seg.selectedSegmentTintColor = [GM appPrimaryColor];

        // Background per state
          // Remove borders/dividers
        [seg setDividerImage:[UIImage new]
          forLeftSegmentState:UIControlStateNormal
            rightSegmentState:UIControlStateNormal
                   barMetrics:UIBarMetricsDefault];

    } else {
        // Pre-iOS 13 fallback
        
        seg.tintColor = [GM appPrimaryColor];
    }
}

- (NSArray<PPUniversalCellViewModel *> *)pp_generateUniversalModelsArrayFromArray:(NSArray<id> *)objectsArray {
    if (objectsArray.count == 0) return @[];

    NSMutableArray<PPUniversalCellViewModel *> *result = [NSMutableArray arrayWithCapacity:objectsArray.count];

    for (id obj in objectsArray) {
        PPUniversalCellViewModel *vm = [PPUniversalCellViewModel new];
        vm.placeholder = [UIImage imageNamed:@"placeholder"];
        vm.isOwner = NO;
        vm.hasOffer = NO;
        vm.isNew = NO;
        vm.ModelID = NSUUID.UUID.UUIDString;
        vm.imageURL = nil;
        vm.priceText = @"";
        vm.subtitle = @"";
        vm.ppSection = PPSectionAds;
        vm.imageSize = CGSizeZero; // ✅ default

        // 🐾 PetAd
        if ([obj isKindOfClass:[PetAd class]]) {
            PetAd *ad = (PetAd *)obj;
            vm.title = ad.adTitle ?: kLang(@"UntitledAd");
            vm.ModelID = ad.adID;
            
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
            
            
            vm.priceText = ad.price ? [NSString stringWithFormat:@"%@ %@", ad.price, kLang(@"Rials")] : kLang(@"NoPrice");
            vm.isOwner = [PPCurrentUser.ID isEqualToString:ad.ownerID];
            vm.ModelObject = ad;
            vm.modelContext = PPCellForAds;
            vm.cellSection = CellSectionAds;
            vm.ppSection = PPSectionAds;
            vm.finalPrice = ad.price;
        }

        // 🧩 PetAccessory
        else if ([obj isKindOfClass:[PetAccessory class]]) {
            PetAccessory *acc = (PetAccessory *)obj;
            vm.title = acc.name ?: kLang(@"UntitledAccessory");
            vm.ModelID = acc.accessoryID;
            vm.imageURL = acc.imageURLsArray.firstObject;
            vm.priceText = acc.price ? [NSString stringWithFormat:@"%@", acc.price] : kLang(@"NoPrice");
            //vm.discountText = acc;
            vm.price = acc.price;
            vm.isOwner = [PPCurrentUser.ID isEqualToString:acc.ownerID];
            vm.hasOffer = acc.hasOffer;
            vm.isNew = acc.isNew;
            vm.ModelObject = acc;
            vm.modelContext = PPCellForMarket;
            //vm.cellSection = self.viewType;
            //vm.ppSection = self.cellSection == CellSectionAccessories ?  PPSectionAccess : PPSectionFood;
            
            vm.discountPercent = acc.discountPercent;
            vm.discountAmount = acc.discountAmount;
            vm.finalPrice = acc.finalPrice;
            vm.stockStatusText = acc.stockStatusText;
            vm.itemQuantitiy = acc.quantity;

           // NSLog(@"🧩 %@ | Base: %@ | Percent: %@ | Amount: %@ | Final: %@",
                  // acc.name, acc.price, acc.discountPercent, acc.discountAmount, acc.finalPrice);
        }

        // 🧰 ServiceModel
        else if ([obj isKindOfClass:[ServiceModel class]]) {
            ServiceModel *svc = (ServiceModel *)obj;
            vm.title = svc.title ?: kLang(@"UntitledService");
            vm.ModelID = svc.serviceID;
            vm.ModelObject = svc;
            vm.modelContext = PPCellForServices;
            vm.imageURL = svc.imageURL;
            vm.priceText = svc.price > 0 ? [NSString stringWithFormat:@"%.0f %@", svc.price, kLang(@"Rials")] : kLang(@"Free");

            vm.isOwner = [PPCurrentUser.ID isEqualToString:svc.serviceOwnerID];
            vm.cellSection = CellSectionServices;
            vm.ppSection = PPSectionServices;
            vm.finalPrice =  @(svc.price);
            vm.price =  @(svc.price);
        }

        // 🏥 VetModel
        else if ([obj isKindOfClass:[VetModel class]]) {
            VetModel *vet = (VetModel *)obj;
            vm.title = vet.title ?: kLang(@"VetClinic");
            vm.ModelID = vet.vetID;
            vm.ModelObject = vet;
            vm.modelContext = PPCellForVets;
            vm.imageURL = vet.logoURL;
            vm.subtitle = vet.descriptionText ?: @"";
            vm.isOwner = [PPCurrentUser.ID isEqualToString:vet.userID];
            vm.cellSection = CellSectionVet;
            vm.ppSection = PPSectionVets;
            
            vm.finalPrice =  @(vet.vetCost);
            vm.price =  @(vet.vetCost);
        }

        else {
            vm.title = kLang(@"UnknownItem");
            vm.ModelID = @"";
        }
    /*
        // ✅ Automatically fetch and cache image size (async)
        if (vm.imageURL.length > 0) {
            [[PPImageSizeFetcher shared] sizeForURL:vm.imageURL completion:^(CGSize size) {
                if (!CGSizeEqualToSize(size, CGSizeZero)) {
                    vm.imageSize = size;
                    // When size arrives, refresh layout for dynamic height
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.collectionView.collectionViewLayout invalidateLayout];
                        [self.collectionView reloadData];
                    });
                    [[NSUserDefaults standardUserDefaults] setObject:NSStringFromCGSize(size)
                                                              forKey:vm.imageURL];
                }
            }];
        }
*/
        [result addObject:vm];
    }

    return [result copy];
}
 
@end
