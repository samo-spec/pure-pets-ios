//
//  MyItemsViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 31/05/2025.
//  Refactored for iOS 26 Trending Modern UI
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
#import "PPUniversalCell.h"
#import "PPEmptyStateHelper.h"
//#import "PPBlurHashBridge.h"
#import "AddAdoptPetViewController.h"
#import "CitiesManager.h"
#import "AppManager.h"

@interface MyItemsViewController () <
    UICollectionViewDataSource,
    UICollectionViewDelegate,
    AdoptCollectionViewCellDelegate,
    AddNewAdDelegate
>

@property (nonatomic, assign) MyItemsMode mode;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray<PPUniversalCellViewModel *> *items;
@property (nonatomic, strong) CCActivityHUD *activityHUD;

// Cached raw data
@property (nonatomic, strong) NSArray *rawItems;

@end

@implementation MyItemsViewController

#pragma mark - Initialization

- (instancetype)initWithMode:(MyItemsMode)mode {
    if (self = [super init]) {
        _mode = mode;
    }
    return self;
}

- (instancetype)initWithMode:(MyItemsMode)mode viewType:(ViewType)viewType {
    if (self = [self initWithMode:mode]) {
        _viewType = viewType;
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupBaseUI];
    [self setupSegmentedControl];
    [self setupCollectionView];
    [self setupActivityIndicator];
    
    [self fetchDataForCurrentSegment];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    NSString *title = (self.mode == MyItemsModeMyAds) ? kLang(@"myadsTitle") : kLang(@"myfavTitle");
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:title showBack:YES];
}

#pragma mark - UI Setup

- (void)setupBaseUI {
    self.view.backgroundColor = PPBackgroundColorForIOS26(GM.backOffwhileColor);
}

- (void)setupSegmentedControl {
    NSArray *titles = [GM getAdsAccessSegmentedTitleForLanguage:[Language languageVal]];
    self.segmentedControl = [[UISegmentedControl alloc] initWithItems:titles];
    self.segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    
    [self pp_styleSegment:self.segmentedControl];
    
    [self.view addSubview:self.segmentedControl];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.segmentedControl.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [self.segmentedControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.segmentedControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.segmentedControl.heightAnchor constraintEqualToConstant:46]
    ]];
    
    // Set initial index based on viewType
    switch (self.viewType) {
        case ViewTypeAds:    self.segmentedControl.selectedSegmentIndex = 0; break;
        case ViewTypeAccess: self.segmentedControl.selectedSegmentIndex = 1; break;
        case ViewTypeFood:   self.segmentedControl.selectedSegmentIndex = 2; break;
        case ViewTypeAdopt:  self.segmentedControl.selectedSegmentIndex = 3; break;
        default:             self.segmentedControl.selectedSegmentIndex = 0; break;
    }
    
    self.segmentedControl.semanticContentAttribute = [GM setSemantic];
}

- (void)setupCollectionView {
    UICollectionViewCompositionalLayout *layout = [self createCompositionalLayout];
    
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.showsVerticalScrollIndicator = NO;
    
    [self.collectionView registerClass:[PPUniversalCell class] forCellWithReuseIdentifier:@"PPUniversalCell"];
    [self.collectionView registerClass:[AdoptPetCell class] forCellWithReuseIdentifier:@"AdoptPetCell"];
    
    [self.view addSubview:self.collectionView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor constraintEqualToAnchor:self.segmentedControl.bottomAnchor constant:12],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (UICollectionViewCompositionalLayout *)createCompositionalLayout {
    return [[UICollectionViewCompositionalLayout alloc] initWithSectionProvider:^NSCollectionLayoutSection * _Nullable(NSInteger sectionIndex, id<NSCollectionLayoutEnvironment>  _Nonnull layoutEnvironment) {
        
        CGFloat spacing = 12.0;
        NSCollectionLayoutSize *itemSize = [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:0.5]
                                                                          heightDimension:[NSCollectionLayoutDimension estimatedDimension:250]];
        
        NSCollectionLayoutItem *item = [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
        item.contentInsets = NSDirectionalEdgeInsetsMake(0, spacing/2, 0, spacing/2);
        
        NSCollectionLayoutSize *groupSize = [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                                                           heightDimension:[NSCollectionLayoutDimension estimatedDimension:250]];
        
        NSCollectionLayoutGroup *group = [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize subitems:@[item]];
        
        NSCollectionLayoutSection *section = [NSCollectionLayoutSection sectionWithGroup:group];
        section.contentInsets = NSDirectionalEdgeInsetsMake(spacing, spacing/2, spacing, spacing/2);
        section.interGroupSpacing = spacing;
        
        return section;
    }];
}

- (void)setupActivityIndicator {
    self.activityHUD = [CCActivityHUD new];
    self.activityHUD.isTheOnlyActiveView = YES;
    self.activityHUD.backColor = [UIColor clearColor];
    self.activityHUD.indicatorColor = [GM appPrimaryColor];
    self.activityHUD.overlayType = CCActivityHUDOverlayTypeShadow;
}

#pragma mark - Actions

- (void)segmentChanged:(UISegmentedControl *)sender {
    [self.activityHUD show];
    
    switch (sender.selectedSegmentIndex) {
        case 0: _viewType = ViewTypeAds; break;
        case 1: _viewType = ViewTypeAccess; break;
        case 2: _viewType = ViewTypeFood; break;
        case 3: _viewType = ViewTypeAdopt; break;
        default: _viewType = ViewTypeAds; break;
    }
    
    [self fetchDataForCurrentSegment];
}

#pragma mark - Data Fetching

- (void)fetchDataForCurrentSegment {
    NSString *userID = [UserManager sharedManager].currentUser.ID;
    if (!userID) {
        [self.activityHUD dismiss];
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    void (^completion)(NSArray *) = ^(NSArray *fetchedItems) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.rawItems = fetchedItems ?: @[];
            weakSelf.items = [weakSelf pp_generateUniversalModelsArrayFromArray:weakSelf.rawItems];
            [weakSelf.collectionView reloadData];
            [weakSelf.activityHUD dismiss];
            [weakSelf updateEmptyState];
        });
    };
    
    if (self.mode == MyItemsModeMyAds) {
        switch (self.viewType) {
            case ViewTypeAds:    [PetAdManager fetchAdsForUserID:userID completion:completion]; break;
            case ViewTypeAccess: [PetAccessoryManager fetchAccessoriesForUserID:userID accessKindType:AccessTypeAccessory completion:completion]; break;
            case ViewTypeFood:   [PetAccessoryManager fetchAccessoriesForUserID:userID accessKindType:AccessTypeFood completion:completion]; break;
            case ViewTypeAdopt:  [AdoptPetManager.shared fetchPetsForUserID:userID completion:^(NSArray *pets, NSError *error) { completion(pets); }]; break;
        }
    } else {
        // Favorites
        NSString *collection = @"";
        switch (self.viewType) {
            case ViewTypeAds:    collection = @"favoritesAds"; break;
            case ViewTypeAccess: collection = @"favoritesAccessories"; break;
            case ViewTypeFood:   collection = @"favoritesAccessories"; break; // Intentional shared collection
            case ViewTypeAdopt:  collection = @"favoritesAdoptPets"; break;
        }
        
        [PetAdManager fetchFavoriteAdIDsForUserID:userID collection:collection completion:^(NSArray<NSString *> *adIDs) {
            if (adIDs.count == 0) {
                completion(@[]);
                return;
            }
            
            switch (weakSelf.viewType) {
                case ViewTypeAds:    [PetAdManager fetchAdsWithIDs:adIDs completion:completion]; break;
                case ViewTypeAccess:
                case ViewTypeFood:   [PetAccessoryManager fetchAccessoriesWithIDs:adIDs completion:completion]; break;
                case ViewTypeAdopt:  [AdoptPetManager.shared fetchPetsWithIDs:adIDs completion:^(NSArray *pets, NSError *error) { completion(pets); }]; break;
            }
        }];
    }
}

- (void)updateEmptyState {
    PPEmptyStateConfig *cfg = [PPEmptyStateConfig new];
    cfg.animationName = @"Emptyred.json";
    cfg.title = kLang(@"nodata");
    cfg.target = self;
    cfg.isNetworkFile = YES;
    [PPEmptyStateHelper updateEmptyStateForListView:self.collectionView dataCount:self.items.count config:cfg];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.items.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PPUniversalCellViewModel *viewModel = self.items[indexPath.item];
    
    if (self.viewType == ViewTypeAdopt) {
        AdoptPetCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"AdoptPetCell" forIndexPath:indexPath];
        AdoptPetModel *model = (AdoptPetModel *)viewModel.ModelObject;
        cell.adoptModel = model;
        cell.delegate = self;
        NSString *cityName = [CitiesManager.shared cityNameForID:model.cityID];
        [cell configureWithName:model.name imageURL:model.imageURLs.firstObject subtitle:cityName adoptPetModel:model];
        [cell pp_applyOwnerMode:(self.mode == MyItemsModeMyAds) animated:NO];
        return cell;
    }
    
    PPUniversalCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"PPUniversalCell" forIndexPath:indexPath];
    viewModel.indexPath = indexPath;
    [cell applyViewModel:viewModel
                 context:viewModel.modelContext
              layoutMode:PPCellLayoutModePinterest
            discountMode:PPDiscountStyleBadge
             imageLoader:^(UIImageView *imageView, NSString *urlString, UIImage *placeholder, UIView *card) {
        [[PPImageLoaderManager shared] setImageOnImageView:imageView url:urlString complation:nil];
    }];
    
    return cell;
}

#pragma mark - AdoptCollectionViewCellDelegate

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
        [AdoptPetManager.shared deletePetWithID:adoptModel.documentID completion:^(BOOL success, NSError *error) {
            if (success) {
                [self fetchDataForCurrentSegment];
                [AppManager.sharedInstance showSnakBar:kLang(@"Trash") withColor:GM.appPrimaryColor andDuration:0.3 containerView:self.view];
            }
        }];
    }];
}

#pragma mark - Styling

- (void)pp_styleSegment:(UISegmentedControl *)seg {
    if (!seg) return;
    
    seg.layer.cornerRadius = 23.0;
    seg.layer.masksToBounds = YES;
    
    NSDictionary *normalAttrs = @{
        NSForegroundColorAttributeName : AppSecondaryTextClr ?: [UIColor darkGrayColor],
        NSFontAttributeName : [GM fontWithSize:14]
    };
    NSDictionary *selectedAttrs = @{
        NSForegroundColorAttributeName : [UIColor whiteColor],
        NSFontAttributeName : [GM boldFontWithSize:14]
    };
    
    [seg setTitleTextAttributes:normalAttrs forState:UIControlStateNormal];
    [seg setTitleTextAttributes:selectedAttrs forState:UIControlStateSelected];
    
    if (@available(iOS 13.0, *)) {
        seg.selectedSegmentTintColor = [GM appPrimaryColor];
        seg.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.8];
        [seg setDividerImage:[UIImage new] forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    } else {
        seg.tintColor = [GM appPrimaryColor];
    }
}

#pragma mark - ViewModel Generation

- (NSArray<PPUniversalCellViewModel *> *)pp_generateUniversalModelsArrayFromArray:(NSArray *)objectsArray {
    NSMutableArray<PPUniversalCellViewModel *> *result = [NSMutableArray array];
    
    for (id obj in objectsArray) {
        PPUniversalCellViewModel *vm = [PPUniversalCellViewModel new];
        vm.placeholder = [UIImage imageNamed:@"placeholder"];
        
        if ([obj isKindOfClass:[PetAd class]]) {
            PetAd *ad = (PetAd *)obj;
            vm.title = ad.adTitle ?: kLang(@"UntitledAd");
            vm.ModelID = ad.adID;
            vm.ModelObject = ad;
            vm.modelContext = PPCellForAds;
            
            PetImageItem *firstItem = ad.imageItems.firstObject;
            if (firstItem) {
                vm.imageURL = firstItem.url;
                if (firstItem.blurHash.length > 0) {
                    vm.placeholder = [PPBlurHashBridge imageFrom:firstItem.blurHash syncSize:CGSizeMake(40, 40) punch:1.0];
                }
            }
            vm.priceText = ad.price ? [NSString stringWithFormat:@"%@ %@", ad.price, kLang(@"Rials")] : kLang(@"NoPrice");
            vm.isOwner = [[UserManager sharedManager].currentUser.ID isEqualToString:ad.ownerID];
        }
        else if ([obj isKindOfClass:[PetAccessory class]]) {
            PetAccessory *acc = (PetAccessory *)obj;
            vm.title = acc.name ?: kLang(@"UntitledAccessory");
            vm.ModelID = acc.accessoryID;
            vm.imageURL = acc.imageURLsArray.firstObject;
            vm.priceText = acc.price ? [NSString stringWithFormat:@"%@", acc.price] : kLang(@"NoPrice");
            vm.ModelObject = acc;
            vm.modelContext = PPCellForMarket;
            vm.isOwner = [[UserManager sharedManager].currentUser.ID isEqualToString:acc.ownerID];
            vm.hasOffer = acc.hasOffer;
            vm.isNew = acc.isNew;
            vm.discountPercent = acc.discountPercent;
            vm.finalPrice = acc.finalPrice;
        }
        else if ([obj isKindOfClass:[AdoptPetModel class]]) {
            AdoptPetModel *model = (AdoptPetModel *)obj;
            vm.title = model.name;
            vm.ModelID = model.documentID;
            vm.ModelObject = model;
            vm.imageURL = model.imageURLs.firstObject;
        }
        
        [result addObject:vm];
    }
    return [result copy];
}

@end
