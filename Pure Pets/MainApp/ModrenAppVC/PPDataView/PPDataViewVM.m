#import "PPDataViewVM.h"

#import "MainKindsModel.h"
#import "ServiceModel.h"
 
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
// Filters — data-driven
@property (nonatomic, strong, nullable) PPFilterState *filterState;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, PPFilterState *> *filterStatesBySection;
// Section
//@property (nonatomic, assign) PPDataSection currentSection;

// Storage
@property (nonatomic, strong) NSMutableArray<PPUniversalCellViewModel *> *mutableItems;
@property (nonatomic, copy) NSArray *latestRawResults;
@property (nonatomic, assign) NSUInteger requestVersion;
@property (nonatomic, assign) BOOL didNotifyInitialSectionsDataLoaded;

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

- (NSArray *)pp_resultsRespectingUsedAccessoryFlag:(NSArray *)results
{
    if (PPAllwedUsedAccessoriesEnabled() || self.currentSection != PPDataSectionAccessories) {
        return results ?: @[];
    }

    return [(results ?: @[]) filteredArrayUsingPredicate:
        [NSPredicate predicateWithBlock:^BOOL(id obj, __unused NSDictionary *bindings) {
            if (![obj isKindOfClass:PetAccessory.class]) {
                return YES;
            }
            PetAccessory *accessory = (PetAccessory *)obj;
            if (accessory.accessKindType != AccessTypeAccessory) {
                return YES;
            }
            return accessory.condition == AccessConditionsNew;
        }]];
}

#pragma mark - Init

- (instancetype)initWithMainKind:(MainKindsModel *)mainKind
                    sourceTarget:(PPDeepLinkTarget)sourceTarget
{
    self = [super init];
    if (!self) return nil;

    _mainKind = mainKind;
    _mutableItems = [NSMutableArray new];
    _filterStatesBySection = [NSMutableDictionary dictionary];

    _currentPage = 1;
    _hasMore = YES;
    _isLoading = NO;

    _currentDeepLinkTarget = sourceTarget;

    // Special case: All Categories deep link → default to Ads
    if (sourceTarget == PPDeepLinkTargetAllCategories) {
        _currentSection = PPDataSectionAds;
    } else {
        _currentSection = [PPHomeHelper sectionFromSourceTarget:sourceTarget];
    }
    
    // Main-kind entry must start at "All". A previously selected breed/subkind
    // should not silently narrow a fresh category browse to one item.
    self.currentSubKindID = 0;
    
    
    

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

- (void)pp_useStoredFilterStateForCurrentSection
{
    self.filterState = self.filterStatesBySection[@(self.currentSection)];
}

- (void)switchToSection:(PPDataSection)section
{
    BOOL isInitialLoad = (self.items.count == 0);

    // ✅ Allow first load even if section is same
    if (_currentSection == section && !isInitialLoad) {
        return;
    }

    _currentSection = section;
    [self pp_useStoredFilterStateForCurrentSection];
    [self pp_beginRequest];

    // Reset data
    [self.mutableItems removeAllObjects];
    self.latestRawResults = @[];
    self.currentPage = 0;
    self.hasMore = YES;
    self.isLoading = YES;

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
    self.isLoading = YES;

    // Reset filters
    self.filterState = nil;
    [self.filterStatesBySection removeAllObjects];
    self.currentSubKindID = 0;

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
    self.isLoading = YES;

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

- (void)setFilterState:(PPFilterState *)state forSection:(PPDataSection)section
{
    if (!self.filterStatesBySection) {
        self.filterStatesBySection = [NSMutableDictionary dictionary];
    }

    NSNumber *key = @(section);
    if (state) {
        self.filterStatesBySection[key] = state;
    } else {
        [self.filterStatesBySection removeObjectForKey:key];
    }

    if (self.currentSection == section) {
        self.filterState = state;
    }
}

- (void)applyFilterState:(PPFilterState *)state
{
    [self setFilterState:state forSection:self.currentSection];
    [self pp_beginRequest];
    [self refreshCurrentSection];
}

- (NSInteger)previewResultCountForFilterState:(PPFilterState *)state
{
    NSArray *sourceResults = self.latestRawResults;
    if (sourceResults.count == 0) {
        return self.mutableItems.count;
    }

    NSArray *filtered = [self pp_applyFiltersToResults:sourceResults filterState:state];
    return filtered.count;
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
            weakSelf.latestRawResults = safeResults;
            NSArray *filtered = [weakSelf applyFiltersToResults:safeResults];
            NSArray *viewModels = [weakSelf buildViewModelsFromModels:filtered];

            [weakSelf.mutableItems removeAllObjects];
            [weakSelf.mutableItems addObjectsFromArray:viewModels];

            weakSelf.currentPage = 1;
            weakSelf.hasMore = NO;

            BOOL shouldNotifyInitialSectionsDataLoaded = !weakSelf.didNotifyInitialSectionsDataLoaded;
            if (shouldNotifyInitialSectionsDataLoaded) {
                weakSelf.didNotifyInitialSectionsDataLoaded = YES;
            }

            if (weakSelf.onReloadData) {
                weakSelf.onReloadData();
            }

            if (shouldNotifyInitialSectionsDataLoaded && weakSelf.onInitialSectionsDataLoaded) {
                weakSelf.onInitialSectionsDataLoaded();
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
    return [self pp_applyFiltersToResults:results filterState:self.filterState];
}

- (NSArray *)pp_applyFiltersToResults:(NSArray *)results filterState:(PPFilterState *)state
{
    NSArray *filtered = [self pp_resultsRespectingUsedAccessoryFlag:results];

    if (!state || !state.hasActiveFilters) {
        return filtered;
    }

    BOOL isAdsSection = (self.currentSection == PPDataSectionAds);
    BOOL isAccessoriesSection = (self.currentSection == PPDataSectionAccessories);
    BOOL isFoodSection = (self.currentSection == PPDataSectionFood);
    BOOL isServicesSection = (self.currentSection == PPDataSectionServices);

    // ── Condition filter (Accessories / Food) ──
    NSInteger condVal = [state valueForFilterID:PPFilterIDCondition];
    if ((isAccessoriesSection || isFoodSection) &&
        PPAllwedUsedAccessoriesEnabled() &&
        condVal != 0) { // 0 = All
        BOOL wantNew = (condVal == PPFilterAccessoryNew);
        filtered = [filtered filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *_) {
                return [obj respondsToSelector:@selector(isNew)] && ([obj isNew] == wantNew);
            }]];
    }

    // ── Accessory category filter ──
    PPFilterGroup *accessoryCategoryGroup = [state groupForID:PPFilterIDAccessoryCategory];
    NSString *selectedAccessoryCategoryID = accessoryCategoryGroup.selectedOption.identifierValue ?: @"";
    if (isAccessoriesSection && selectedAccessoryCategoryID.length > 0) {
        filtered = [filtered filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(id obj, __unused NSDictionary *bindings) {
                if (![obj isKindOfClass:PetAccessory.class]) {
                    return YES;
                }
                PetAccessory *accessory = (PetAccessory *)obj;
                NSString *categoryID = accessory.AccessoryCategoryID ?: @"";
                return [categoryID isEqualToString:selectedAccessoryCategoryID];
            }]];
    }

    // ── Gender filter (Ads) ──
    NSInteger genderVal = [state valueForFilterID:PPFilterIDGender];
    if (isAdsSection && genderVal != PPFilterGenderAll) {
        filtered = [filtered filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *_) {
                NSString *gender = @"";
                if ([obj respondsToSelector:@selector(gender)]) {
                    id rawGender = [obj valueForKey:@"gender"];
                    if ([rawGender isKindOfClass:NSString.class]) {
                        gender = [[(NSString *)rawGender lowercaseString]
                                  stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                    }
                }

                if (genderVal == PPFilterGenderUndefined) {
                    return [gender isEqualToString:@"undefined"];
                }
                if ([gender isEqualToString:@"female"]) {
                    return genderVal == PPFilterGenderFemale;
                }
                if ([gender isEqualToString:@"male"]) {
                    return genderVal == PPFilterGenderMale;
                }
                if ([gender isEqualToString:@"undefined"]) {
                    return NO;
                }
                if (![obj respondsToSelector:@selector(isFemale)]) {
                    return NO;
                }

                BOOL isFemale = [obj isFemale];
                return (genderVal == PPFilterGenderFemale) ? isFemale : !isFemale;
            }]];
    }

    // ── Service type filter (uses category string — covers Training/Grooming/Walking) ──
    NSInteger svcVal = [state valueForFilterID:PPFilterIDServiceType];
    if (isServicesSection && svcVal != PPFilterServiceAll) {
        filtered = [filtered filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *_) {
                if (![obj isKindOfClass:[ServiceModel class]]) return NO;
                ServiceModel *svc = (ServiceModel *)obj;
                NSString *cat = svc.category ?: @"";
                NSString *catID = svc.categoryID ?: @"";
                switch (svcVal) {
                    case PPFilterServiceTraining:
                        return [catID isEqualToString:@"2"]
                            || [cat localizedCaseInsensitiveContainsString:@"train"]
                            || [cat localizedCaseInsensitiveContainsString:@"تدريب"]
                            || svc.type == ServiceTypeTraining;
                    case PPFilterServiceGrooming:
                        return [catID isEqualToString:@"1"]
                            || [cat localizedCaseInsensitiveContainsString:@"groom"]
                            || [cat localizedCaseInsensitiveContainsString:@"عناية"]
                            || svc.type == ServiceTypeGrooming;
                    case PPFilterServiceWalking:
                        return [catID isEqualToString:@"3"]
                            || [cat localizedCaseInsensitiveContainsString:@"walk"]
                            || [cat localizedCaseInsensitiveContainsString:@"تمشية"];
                    default: return YES;
                }
            }]];
    }

    // ── Availability filter (Services — based on availableDate) ──
    NSInteger availVal = [state valueForFilterID:PPFilterIDAvailability];
    if (isServicesSection && availVal != PPFilterAvailabilityAll) {
        NSDate *today = [NSDate date];
        filtered = [filtered filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *_) {
                if (![obj isKindOfClass:[ServiceModel class]]) return YES;
                ServiceModel *svc = (ServiceModel *)obj;
                NSDate *avail = svc.availableDate;
                if (!avail) {
                    return (availVal == PPFilterAvailabilityNow);
                }
                if (availVal == PPFilterAvailabilityNow) {
                    return [avail compare:today] != NSOrderedDescending;
                }
                return [avail compare:today] == NSOrderedDescending;
            }]];
    }

    // ── HasOffer filter (Accessories / Food) ──
    NSInteger offerVal = [state valueForFilterID:PPFilterIDHasOffer];
    if ((isAccessoriesSection || isFoodSection) && offerVal == PPFilterHasOfferYes) {
        filtered = [filtered filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *_) {
                return [obj respondsToSelector:@selector(hasOffer)] && [obj hasOffer];
            }]];
    }

    // ── Price filter ──
    NSInteger priceVal = [state valueForFilterID:PPFilterIDPrice];
    if ((isAdsSection || isFoodSection || isServicesSection) && priceVal != PPFilterPriceAll) {
        // Determine thresholds based on current section
        double lowCeiling = 0, midFloor = 0, midCeiling = 0;
        switch (self.currentSection) {
            case PPDataSectionAds:
                lowCeiling = 500; midFloor = 500; midCeiling = 2000; break;
            case PPDataSectionServices:
                lowCeiling = 100; midFloor = 100; midCeiling = 500; break;
            default: // Accessories, Food
                lowCeiling = 250; midFloor = 250; midCeiling = 750; break;
        }

        filtered = [filtered filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *_) {
                double p = 0;
                if ([obj respondsToSelector:@selector(price)]) p = [[obj valueForKey:@"price"] doubleValue];
                switch (priceVal) {
                    case PPFilterPriceTier1: return p < lowCeiling;
                    case PPFilterPriceTier2: return p >= midFloor && p <= midCeiling;
                    case PPFilterPriceTier3: return p > midCeiling;
                    default: return YES;
                }
            }]];
    }

    // ── Sort ──
    BOOL sectionUsesSort = (isAdsSection || isAccessoriesSection || isFoodSection);
    PPFilterGroup *sortGroup = [state groupForID:PPFilterIDSort];
    NSInteger sortVal = (sectionUsesSort && sortGroup)
        ? [state valueForFilterID:PPFilterIDSort]
        : PPFilterSortRecommended;
    if (sortVal != PPFilterSortRecommended) {
        filtered = [filtered sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
            switch (sortVal) {
                case PPFilterSortPriceLowToHigh: {
                    double pa = [a respondsToSelector:@selector(price)] ? [[a valueForKey:@"price"] doubleValue] : 0;
                    double pb = [b respondsToSelector:@selector(price)] ? [[b valueForKey:@"price"] doubleValue] : 0;
                    return pa < pb ? NSOrderedAscending : (pa > pb ? NSOrderedDescending : NSOrderedSame);
                }
                case PPFilterSortPriceHighToLow: {
                    double pa = [a respondsToSelector:@selector(price)] ? [[a valueForKey:@"price"] doubleValue] : 0;
                    double pb = [b respondsToSelector:@selector(price)] ? [[b valueForKey:@"price"] doubleValue] : 0;
                    return pb < pa ? NSOrderedAscending : (pb > pa ? NSOrderedDescending : NSOrderedSame);
                }
                case PPFilterSortNameAZ: {
                    NSString *na = [a respondsToSelector:@selector(title)] ? [a title] : @"";
                    NSString *nb = [b respondsToSelector:@selector(title)] ? [b title] : @"";
                    if (!na) na = @""; if (!nb) nb = @"";
                    return [na localizedCaseInsensitiveCompare:nb];
                }
                case PPFilterSortNewest: {
                    // Use createdAt if available — descending
                    NSDate *da = [a respondsToSelector:@selector(createdAt)] ? [a createdAt] : nil;
                    NSDate *db = [b respondsToSelector:@selector(createdAt)] ? [b createdAt] : nil;
                    if (!da && !db) return NSOrderedSame;
                    if (!da) return NSOrderedDescending;
                    if (!db) return NSOrderedAscending;
                    return [db compare:da]; // newest first
                }
                default: return NSOrderedSame;
            }
        }];
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
            weakSelf.latestRawResults = safeResults;
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
