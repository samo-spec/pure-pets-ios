#import "PPDataViewVM.h"

#import "MainKindsModel.h"
 
#import "PetAdManager.h"
#import "PetAccessoryManager.h"
#import "VetManager.h"
#import "ServicesManager.h"

@interface PPDataViewVM ()

// Input
@property (nonatomic, strong) MainKindsModel *mainKind;
// Pagination
@property (nonatomic, assign) NSInteger currentPage;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL hasMore;
// Filters
@property (nonatomic, assign) PPFilterAccessoryType accessoryFilter;
@property (nonatomic, assign) PPFilterServiceType serviceFilter;
// Section
//@property (nonatomic, assign) PPDataSection currentSection;

// Storage
@property (nonatomic, strong) NSMutableArray<PPUniversalCellViewModel *> *mutableItems;
@property (nonatomic, assign) NSUInteger requestVersion;

@end

@implementation PPDataViewVM

#pragma mark - Helpers

- (void)pp_dispatchMain:(dispatch_block_t)block
{
    if (!block) { return; }
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

- (NSUInteger)pp_beginRequest
{
    self.requestVersion += 1;
    return self.requestVersion;
}

- (BOOL)pp_isCurrentRequest:(NSUInteger)requestToken
{
    return requestToken == self.requestVersion;
}

#pragma mark - Init

- (instancetype)initWithMainKind:(MainKindsModel *)mainKind
                    sourceTarget:(PPDeepLinkTarget)sourceTarget
{
    self = [super init];
    if (!self) return nil;

    _mainKind = mainKind;
    _mutableItems = [NSMutableArray new];

    _currentPage = 1;
    _hasMore = YES;
    _isLoading = NO;

    _accessoryFilter = PPFilterAccessoryAll;
    _serviceFilter   = PPFilterServiceAll;

    _currentDeepLinkTarget = sourceTarget;

    // Special case: All Categories deep link → default to Ads
    if (sourceTarget == PPDeepLinkTargetAllCategories) {
        _currentSection = PPDataSectionAds;
    } else {
        _currentSection = [PPHomeHelper sectionFromSourceTarget:sourceTarget];
    }
    
    // ─────────────────────────────────────────────
    // 🔑 Restore saved SubKind (title + image)
    // ─────────────────────────────────────────────

    NSString *subKey = [self subKindKeyForMainKind:mainKind];
    NSInteger savedSubKindID =
    [[NSUserDefaults standardUserDefaults] integerForKey:subKey];

    // 0 means "All"
    self.currentSubKindID = savedSubKindID;

    if (savedSubKindID != 0) {
        self.currentSubKindID = savedSubKindID;
    } else {
        self.currentSubKindID = 0;
    }
    
    
    

    _pendingRestoreSection = NSNotFound;
    
    return self;
}

- (NSString *)subKindKeyForMainKind:(MainKindsModel *)mainKind
{
    // All kinds mode
    if (!mainKind) { return @"pp.lastSubKind.all"; }
    return [NSString stringWithFormat:@"pp.lastSubKind.%ld", (long)mainKind.ID];
}
#pragma mark - Public Accessors

- (NSArray<PPUniversalCellViewModel *> *)items
{
    return self.mutableItems;
}

- (NSInteger)itemCount
{
    return self.mutableItems.count;
}

- (PPUniversalCellViewModel *)viewModelAtIndex:(NSInteger)index
{
    if (index < 0 || index >= self.mutableItems.count) return nil;
    return self.mutableItems[index];
}

- (void)switchToSection:(PPDataSection)section
{
    BOOL isInitialLoad = (self.items.count == 0);

    // ✅ Allow first load even if section is same
    if (_currentSection == section && !isInitialLoad) {
        return;
    }

    _currentSection = section;
    [self pp_beginRequest];

    // Reset data
    [self.mutableItems removeAllObjects];
    self.currentPage = 0;
    self.hasMore = YES;
    self.isLoading = NO;

    // 🔥 ALWAYS notify VC
    [self pp_dispatchMain:^{
        if (self.onReloadData) {
            self.onReloadData();
        }
    }];

    // Fetch first page
    [self refreshCurrentSection];
}


- (UIMenu *)filtersArray
{
    
    NSMutableArray *searchGroup = [NSMutableArray array];
    NSMutableArray *filterGroup = [NSMutableArray array];
    NSMutableArray *layoutGroup = [NSMutableArray array];
    UIAction *searchPPAction = [PPActionButton actionWithTitle:kLang(@"searchOnly")
                                               systemImageName:@"magnifyingglass"
                                                          font:[GM MidFontWithSize:16]
                                                         color:AppSecondaryTextClr
                                                       handler:^(UIAction * _Nonnull action) {  }];
    
    
    
    UIAction *filterPPAction = [PPActionButton actionWithTitle:kLang(@"filterPPAction")
                                               systemImageName:@"line.3.horizontal.decrease"
                                                          font:[GM MidFontWithSize:16]
                                                         color:AppSecondaryTextClr
                                                       handler:^(UIAction * _Nonnull action){  }];
    
    
    /// ------------------------------------------------------------------------------------------------------------------------------------------------------------------
    
    
    UIAction *layoutSquirePPAction = [PPActionButton actionWithTitle:kLang(@"PPCellLayoutSquare")
                                                     systemImageName:@"widget.small"
                                                                font:[GM MidFontWithSize:16]
                                                               color:AppSecondaryTextClr
                                                             handler:^(UIAction * _Nonnull action)  {
        
    }];
    
    
    UIAction *layoutFullPPAction = [PPActionButton actionWithTitle:kLang(@"PPCellLayoutFullWidth")
                                                   systemImageName:@"widget.medium"
                                                              font:[GM MidFontWithSize:16]
                                                             color:AppSecondaryTextClr
                                                           handler:^(UIAction * _Nonnull action) {
        //PPManagerCellLayoutMode newMode = PPCellLayoutModeFullWidth; // or FullWidth, Square, Vertical
      
    }];
    
    
    UIAction *layoutLargePPAction = [PPActionButton actionWithTitle:kLang(@"PPCellLayoutVertical")
                                                    systemImageName:@"widget.extralarge"
                                                               font:[GM MidFontWithSize:16]
                                                              color:AppSecondaryTextClr
                                                            handler:^(UIAction * _Nonnull action) {
        
    }];

   
    UIAction *layoutPintrestPPAction = [PPActionButton actionWithTitle:kLang(@"Pintrest")
                                                    systemImageName:@"widget.extralarge"
                                                               font:[GM MidFontWithSize:16]
                                                              color:AppSecondaryTextClr
                                                            handler:^(UIAction * _Nonnull action) {
        
         
    }];
    
    [searchGroup addObject:searchPPAction];
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


- (void)switchToMainKind:(MainKindsModel *)mainKind
{
    if (!mainKind) return;

    // Ignore if same main kind
    if (self.mainKind && self.mainKind.ID == mainKind.ID) {
        return;
    }

    self.mainKind = mainKind;
    [self pp_beginRequest];

    // Reset pagination
    self.currentPage = 0;
    self.hasMore = YES;
    self.isLoading = NO;

    // Reset filters
    self.accessoryFilter = PPFilterAccessoryAll;
    self.serviceFilter   = PPFilterServiceAll;

    // Clear current items
    [self.mutableItems removeAllObjects];

    [self pp_dispatchMain:^{
        if (self.onReloadData) {
            self.onReloadData();
        }
    }];

    if (self.pendingRestoreSection != NSNotFound) {
        _currentSection = self.pendingRestoreSection;
        self.pendingRestoreSection = NSNotFound;
    }

    // Reload current section with new main kind
    [self refreshCurrentSection];
}

//#pragma mark - SubKind

#pragma mark - SubKind

- (void)reloadForSubKind:(SubKindModel *)subKind
{
    if (!subKind) return;

    // Ignore same subKind
  //     return;
   // }

    self.currentSubKindID = subKind.ID;
    [self pp_beginRequest];

    // Reset pagination
    self.currentPage = 0;
    self.hasMore = YES;
    self.isLoading = NO;

    // Clear items
    [self.mutableItems removeAllObjects];

    // Notify VC to reset UI immediately
    [self pp_dispatchMain:^{
        if (self.onReloadData) {
            self.onReloadData();
        }
    }];

    // Reload current section using new subKind
    [self refreshCurrentSection];
}

#pragma mark - Filters

- (void)applyAccessoryFilter:(PPFilterAccessoryType)accessory
               serviceFilter:(PPFilterServiceType)service
{
    self.accessoryFilter = accessory;
    self.serviceFilter   = service;
    [self pp_beginRequest];

    [self refreshCurrentSection];
}

#pragma mark - Data Flow

- (void)fetchInitialData
{
    // ✅ Apply pending restored section ONCE
    if (self.pendingRestoreSection != NSNotFound) {
        _currentSection = self.pendingRestoreSection;
        self.pendingRestoreSection = NSNotFound;
    }

    [self pp_beginRequest];
    [self refreshCurrentSection];
}

- (void)fetchNextPage
{
    // Current data sources are one-shot snapshots (up to 50 items), not true paged cursors.
    // Prevent duplicate inserts when UI asks for "next page".
    self.hasMore = NO;
}

- (void)refreshCurrentSection
{
    NSUInteger requestToken = [self pp_beginRequest];
    self.isLoading = YES;
    self.currentPage = 1;
    self.hasMore = YES;

    __weak typeof(self) weakSelf = self;

    [self fetchRawDataForSection:self.currentSection
                            page:1
                      completion:^(NSArray *results, NSError *error) {
        [weakSelf pp_dispatchMain:^{
            if (!weakSelf || ![weakSelf pp_isCurrentRequest:requestToken]) {
                return;
            }

            weakSelf.isLoading = NO;

            if (error) {
                if (weakSelf.onError) {
                    weakSelf.onError(error);
                }
                return;
            }

            NSArray *safeResults = [results isKindOfClass:[NSArray class]] ? results : @[];
            NSArray *filtered = [weakSelf applyFiltersToResults:safeResults];
            NSArray *viewModels = [weakSelf buildViewModelsFromModels:filtered];

            [weakSelf.mutableItems removeAllObjects];
            [weakSelf.mutableItems addObjectsFromArray:viewModels];

            weakSelf.currentPage = 1;
            weakSelf.hasMore = NO;

            if (weakSelf.onReloadData) {
                weakSelf.onReloadData();
            }
        }];
    }];
}

#pragma mark - Raw Fetch Router

- (void)fetchRawDataForSection:(PPDataSection)section
                          page:(NSInteger)page
                    completion:(void (^)(NSArray *results, NSError *error))completion
{
    (void)page;
   
    
    
    switch (section) {

        case PPDataSectionAds: {
            BOOL isGlobal =
               (self.currentDeepLinkTarget == PPDeepLinkTargetAllCategories || !self.mainKind);
            // All Categories → fetch ads for ALL main kinds
            if (isGlobal) {
                [[PetAdManager sharedManager]
                 fetchAdsForAllMainKinds:^(NSArray<PetAd *> * _Nonnull ads) {
                    if (completion) completion(ads, nil);
                }];

            } else {
                if (self.currentSubKindID > 0) {
                    [[PetAdManager sharedManager]
                     fetchAdsForMainKind:self.mainKind
                               subKindID:self.currentSubKindID
                              completion:^(NSArray<PetAd *> * _Nonnull ads) {
                        if (completion) completion(ads, nil);
                    }];
                } else {
                    [[PetAdManager sharedManager]
                     fetchAdsForMainKind:self.mainKind
                              completion:^(NSArray<PetAd *> * _Nonnull ads) {
                        if (completion) completion(ads, nil);
                    }];
                }
            }

            break;
        }

        case PPDataSectionAccessories: {

            BOOL isGlobal =
            (self.currentDeepLinkTarget == PPDeepLinkTargetAllCategories || !self.mainKind);

            if (isGlobal) {

                [[PetAccessoryManager sharedManager]
                 fetchAccessoriesForAllMainKinds:^(NSArray<PetAccessory *> *items) {
                    if (completion) completion(items, nil);
                }];

            } else {
                if (self.currentSubKindID > 0) {
                    [[PetAccessoryManager sharedManager]
                     fetchAccessoriesOfKind:AccessTypeAccessory
                     MainCategory:self.mainKind.ID
                     subKindID:self.currentSubKindID
                     completion:^(NSArray<PetAccessory *> * _Nonnull accessories) {
                        if (completion) completion(accessories, nil);
                     }];
                } else {
                    [[PetAccessoryManager sharedManager]
                     fetchAccessoriesOfKind:AccessTypeAccessory
                     MainCategory:self.mainKind.ID
                     completion:^(NSArray<PetAccessory *> * _Nonnull accessories) {
                        if (completion) completion(accessories, nil);
                     }];
                }
            }

            break;
        }
         
            
            
        case PPDataSectionFood: {
            
            BOOL isGlobal =
            (self.currentDeepLinkTarget == PPDeepLinkTargetAllCategories || !self.mainKind);
            
            if (isGlobal) {

                [[PetAccessoryManager sharedManager]
                 fetchFoodForAllMainKinds:^(NSArray<PetAccessory *> *items) {
                    if (completion) completion(items, nil);
                }];

            } else {
                if (self.currentSubKindID > 0) {
                    [[PetAccessoryManager sharedManager]
                     fetchAccessoriesOfKind:AccessTypeFood
                     MainCategory:self.mainKind.ID
                     subKindID:self.currentSubKindID
                     completion:^(NSArray<PetAccessory *> * _Nonnull accessories) {
                        if(completion) completion(accessories,nil);
                    }];
                } else {
                    [[PetAccessoryManager sharedManager]
                     fetchAccessoriesOfKind:AccessTypeFood
                     MainCategory:self.mainKind.ID
                     completion:^(NSArray<PetAccessory *> * _Nonnull accessories) {
                        if(completion) completion(accessories,nil);
                    }];
                }
            }
           
            break;
        }

        /*
         case PPDataSectionVets: {
             [[VetManager sharedManager]
              getVetsForPetMainKindID:self.mainKind.ID completion:^(NSArray<VetModel *> * _Nonnull vets,
                                                                    NSError * _Nullable error) {
                 
                 if(completion) completion(vets,nil);
             }];
             break;
         }
         */
        case PPDataSectionServices: {

            BOOL isGlobal =
            (self.currentDeepLinkTarget == PPDeepLinkTargetAllCategories || !self.mainKind);

            if (isGlobal) {

                [[ServicesManager sharedInstance]
                 fetchServicesForAllMainKinds:^(NSArray<ServiceModel *> * _Nonnull services, NSError * _Nullable error) {
                            if (completion) completion(services ?: @[], error);
                }];

            } else {

                [[ServicesManager sharedInstance]
                 fetchServicesForPetMainKindID:self.mainKind.ID completion:^(NSArray<ServiceModel *> * _Nonnull services, NSError * _Nullable error) {
                    if (completion) completion(services ?: @[], error);
                }];
            }

            break;
        }
        

        default:
            if (completion) completion(@[], nil);
            break;
    }
}

#pragma mark - Filtering

- (NSArray *)applyFiltersToResults:(NSArray *)results
{
    NSArray *filtered = results;

    if (self.currentSection == PPDataSectionAccessories &&
        self.accessoryFilter != PPFilterAccessoryAll) {

        BOOL wantNew = (self.accessoryFilter == PPFilterAccessoryNew);

        filtered =
        [filtered filteredArrayUsingPredicate:
         [NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *_) {
            return [obj respondsToSelector:@selector(isNew)]
            && ([obj isNew] == wantNew);
        }]];
    }

    if (self.currentSection == PPDataSectionServices &&
        self.serviceFilter != PPFilterServiceAll) {

        filtered =
        [filtered filteredArrayUsingPredicate:
         [NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *_) {

            if (![obj isKindOfClass:[ServiceModel class]]) {
                return NO;
            }

            ServiceModel *service = (ServiceModel *)obj;

            if (self.serviceFilter == PPFilterServiceGrooming) {
                return service.type == ServiceTypeGrooming;
            }

            return service.type == ServiceTypeTraining;
         }]];
    }

    return filtered;
}

/*
 case PPDataSectionAds: {
     [[PetAdManager sharedManager]
      fetchAdsForMainKind:self.mainKind
      completion:^(NSArray<PetAd *> * _Nonnull ads) {
         if(completion) completion(ads,nil);
     }];
     break;
 }

 case PPDataSectionAccessories:{
     [[PetAccessoryManager sharedManager]
      fetchAccessoriesOfKind:AccessTypeAccessory MainCategory:self.mainKind.ID completion:^(NSArray<PetAccessory *> * _Nonnull accessories) {
         if(completion) completion(accessories,nil);
     }];
     break;
 }
 case PPDataSectionFood: {
     [[PetAccessoryManager sharedManager]
      fetchAccessoriesOfKind:AccessTypeFood MainCategory:self.mainKind.ID completion:^(NSArray<PetAccessory *> * _Nonnull accessories) {
         if(completion) completion(accessories,nil);
     }];
     break;
 }

 case PPDataSectionVets: {
     [[VetManager sharedManager]
      getVetsForPetMainKindID:self.mainKind.ID completion:^(NSArray<VetModel *> * _Nonnull vets,
                                                            NSError * _Nullable error) {
         
         if(completion) completion(vets,nil);
     }];
     break;
 }

 case PPDataSectionServices: {
     [[ServicesManager sharedInstance] listenToServicesForPetMainKindID:self.mainKind.ID completion:^(NSArray<ServiceModel *> * _Nonnull services, NSError * _Nullable error) {
         
         if(completion) completion(services,nil);
     }];
     break;
 }

 default: {
     if (completion) {
         completion(@[], nil);
     }
     break;
 }
}
 */
#pragma mark - ViewModel Builder

- (NSArray<PPUniversalCellViewModel *> *) buildViewModelsFromModels:(NSArray *)models
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:models.count];

    for (id model in models) {
        PPCellContext cellContext = PPCellForAds;

        switch (self.currentSection) {
            case PPDataSectionAds:
                cellContext = PPCellForAds;
                break;

            case PPDataSectionAccessories:
            case PPDataSectionFood:
                cellContext = PPCellForMarket;
                break;

            case PPDataSectionServices:
                cellContext = PPCellForServices;
                break;

            default:
                cellContext = PPCellForAds;
                break;
        }

        PPUniversalCellViewModel *vm =
        [[PPUniversalCellViewModel alloc] initWithModel:model context:cellContext];
        if (vm) [result addObject:vm];
    }

    return result;
}
- (void)reloadDataWithCompletion:(void (^)(NSError * _Nullable error))completion
{
    NSUInteger requestToken = [self pp_beginRequest];

    // Reset state
    self.currentPage = 0;
    self.hasMore = YES;
    self.isLoading = YES;

    // Clear current items
    [self.mutableItems removeAllObjects];

    __weak typeof(self) weakSelf = self;

    // Fetch first page of current section
    [self fetchRawDataForSection:self.currentSection
                            page:1
                      completion:^(NSArray *results, NSError *error) {
        [weakSelf pp_dispatchMain:^{
            if (!weakSelf || ![weakSelf pp_isCurrentRequest:requestToken]) {
                return;
            }

            weakSelf.isLoading = NO;

            if (error) {
                if (completion) completion(error);
                return;
            }

            NSArray *safeResults = [results isKindOfClass:[NSArray class]] ? results : @[];
            NSArray *filtered = [weakSelf applyFiltersToResults:safeResults];
            NSArray *viewModels = [weakSelf buildViewModelsFromModels:filtered];

            [weakSelf.mutableItems removeAllObjects];
            [weakSelf.mutableItems addObjectsFromArray:viewModels];

            weakSelf.currentPage = 1;
            weakSelf.hasMore = NO;

            // Notify VC
            if (weakSelf.onReloadData) {
                weakSelf.onReloadData();
            }

            if (completion) completion(nil);
        }];
    }];
}


@end
