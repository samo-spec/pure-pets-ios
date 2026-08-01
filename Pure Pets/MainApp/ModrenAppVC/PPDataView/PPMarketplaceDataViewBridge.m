#import "PPMarketplaceDataViewBridge.h"

#import <FirebaseAuth/FirebaseAuth.h>
#import <FirebaseFirestore/FirebaseFirestore.h>
#import <Pure_Pets-Swift.h>

#import "AddNewAccessory.h"
#import "AddNewAd.h"
#import "AppManager.h"
#import "CartItem.h"
#import "CartManager.h"
#import "CartViewController.h"
#import "ChManager.h"
#import "FullScreenImageViewerController.h"
#import "GM.h"
#import "MainKindsArrayManager.h"
#import "MainKindsModel.h"
#import "PPAdSharingHelper.h"
#import "PPAlertHelper.h"
#import "PPAnalytics.h"
#import "PPDataViewVM.h"
#import "PPHomeHelper.h"
#import "PPHUD.h"
#import "PPNavigationController.h"
#import "PPNetworkRetryHelper.h"
#import "PPOverlayCoordinator.h"
#import "PPSaveForLaterManager.h"
#import "PPSearchViewController.h"
#import "PetAccessory.h"
#import "PetAccessoryManager.h"
#import "PetAd.h"
#import "PetAdManager.h"
#import "ServiceModel.h"
#import "SubKindModel.h"
#import "UserManager.h"
#import "UserModel.h"

static NSString * const PPMarketplaceProviderIdentityTitleKey = @"title";
static NSString * const PPMarketplaceProviderIdentityPhotoURLKey = @"photoURL";

static NSString *PPMarketplaceTrimmedString(id value)
{
    if ([value isKindOfClass:NSString.class]) {
        return [(NSString *)value
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
    }
    if ([value isKindOfClass:NSURL.class]) {
        return [[(NSURL *)value absoluteString]
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
    }
    return @"";
}

static id _Nullable PPMarketplaceObjectValueForSelector(id object, NSString *selectorName)
{
    if (!object || selectorName.length == 0) {
        return nil;
    }
    if ([object isKindOfClass:NSDictionary.class]) {
        return ((NSDictionary *)object)[selectorName];
    }
    SEL selector = NSSelectorFromString(selectorName);
    if (![object respondsToSelector:selector]) {
        return nil;
    }
    id (*implementation)(id, SEL) =
        (id (*)(id, SEL))[object methodForSelector:selector];
    return implementation ? implementation(object, selector) : nil;
}

@implementation PPMarketplaceProviderOption

- (instancetype)initWithProviderID:(NSString *)providerID
                              title:(NSString *)title
                           photoURL:(NSString *)photoURL
                          itemCount:(NSInteger)itemCount
{
    self = [super init];
    if (!self) {
        return nil;
    }
    _providerID = [providerID copy] ?: @"";
    _title = [title copy] ?: @"";
    _photoURL = [photoURL copy];
    _itemCount = MAX(0, itemCount);
    return self;
}

@end

@interface PPMarketplaceDataViewBridge ()

@property (nonatomic, strong) PPDataViewVM *viewModel;
@property (nonatomic, strong, readwrite) PPDataViewInput *input;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, PPFilterState *> *filterStates;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *providerIdentityCache;
@property (nonatomic, strong) NSMutableSet<NSString *> *providerIdentityFetchesInFlight;
@property (nonatomic, strong) NSMutableSet<NSString *> *hydratedProviderIDs;
@property (nonatomic, assign) BOOL started;

@end

@implementation PPMarketplaceDataViewBridge

#pragma mark - Lifecycle

- (instancetype)initWithInput:(PPDataViewInput *)input
{
    NSParameterAssert(input);
    self = [super init];
    if (!self) {
        return nil;
    }

    _input = input;
    _filterStates = [NSMutableDictionary dictionary];
    _providerIdentityCache = [NSMutableDictionary dictionary];
    _providerIdentityFetchesInFlight = [NSMutableSet set];
    _hydratedProviderIDs = [NSMutableSet set];

    if (_input.sourceTarget == PPDeepLinkTargetAllCategories &&
        !_input.mainKind && _input.mainKindsArr.count > 0) {
        _input.mainKind = _input.mainKindsArr.firstObject;
    }

    _viewModel = [[PPDataViewVM alloc] initWithMainKind:_input.mainKind
                                           sourceTarget:_input.sourceTarget];
    [self pp_bindViewModel];
    return self;
}

- (void)dealloc
{
    _viewModel.onReloadData = nil;
    _viewModel.onAppendData = nil;
    _viewModel.onError = nil;
    _viewModel.onInitialSectionsDataLoaded = nil;
}

- (void)pp_bindViewModel
{
    __weak typeof(self) weakSelf = self;
    self.viewModel.onReloadData = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        if (self.itemsDidChange) {
            self.itemsDidChange();
        }
        if (self.presentationStateDidChange) {
            self.presentationStateDidChange();
        }
        [self hydrateProviderIdentitiesForItems:self.viewModel.items
                                        section:self.viewModel.currentSection];
    };
    self.viewModel.onAppendData = ^(NSArray<NSIndexPath *> *indexPaths) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        if (self.itemsDidAppend) {
            self.itemsDidAppend(indexPaths ?: @[]);
        }
        if (self.itemsDidChange) {
            self.itemsDidChange();
        }
    };
    self.viewModel.onError = ^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (self.loadingDidFail) {
            self.loadingDidFail(error);
        }
    };
    self.viewModel.onInitialSectionsDataLoaded = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (self.initialContentDidLoad) {
            self.initialContentDidLoad();
        }
    };
}

- (void)start
{
    if (self.started) {
        return;
    }
    self.started = YES;

    PPDataSection section = [self pp_resolvedInitialSection];
    PPFilterState *state = [self filterStateForSection:section];
    [self.viewModel setFilterState:state forSection:section];
    self.viewModel.currentSubKindID = 0;
    [self pp_persistSection:section];
    [self.viewModel switchToSection:section];
}

- (void)reload
{
    __weak typeof(self) weakSelf = self;
    [self.viewModel reloadDataWithCompletion:^(NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (error && self.loadingDidFail) {
            self.loadingDidFail(error);
        }
    }];
}

- (void)fetchNextPage
{
    [self.viewModel fetchNextPage];
}

#pragma mark - Read-only state

- (NSArray<PPUniversalCellViewModel *> *)items
{
    return [self.viewModel.items copy] ?: @[];
}

- (NSArray<MainKindsModel *> *)mainKinds
{
    NSArray<MainKindsModel *> *provided = self.input.mainKindsArr;
    if (provided.count > 0) {
        return [provided copy];
    }
    return [[[MainKindsArrayManager shared] MainKindsArray] copy] ?: @[];
}

- (NSArray<SubKindModel *> *)subKinds
{
    return [self.input.mainKind.SubKindsArray copy] ?: @[];
}

- (MainKindsModel *)currentMainKind
{
    return self.input.mainKind;
}

- (PPDataSection)currentSection
{
    return self.viewModel.currentSection;
}

- (NSInteger)currentSubKindID
{
    return self.viewModel.currentSubKindID;
}

- (BOOL)isLoading
{
    return self.viewModel.isLoading;
}

- (BOOL)isNetworkAvailable
{
    return [PPNetworkRetryHelper isNetworkAvailable];
}

- (NSString *)currentMainKindTitle
{
    if (self.input.sourceTarget == PPDeepLinkTargetAllCategories) {
        return kLang(@"data_nav_all_species") ?: @"";
    }
    NSString *title = PPMarketplaceTrimmedString(self.input.mainKind.KindName);
    if (title.length == 0) {
        title = PPMarketplaceTrimmedString(self.input.mainKind.KindNameEn);
    }
    return title.length > 0 ? title : (kLang(@"data_nav_all_species") ?: @"");
}

- (NSString *)currentSubKindTitle
{
    if (self.viewModel.currentSubKindID == 0) {
        return kLang(@"data_nav_all_breed") ?: @"";
    }
    SubKindModel *subKind =
        [self.input.mainKind subKindForID:self.viewModel.currentSubKindID];
    NSString *title = PPMarketplaceTrimmedString(subKind.SubKindName);
    return title.length > 0 ? title : (kLang(@"data_nav_all_breed") ?: @"");
}

- (UIColor *)accentColor
{
    return self.input.accentColor ?: [GM appPrimaryColor] ?: UIColor.systemPinkColor;
}

- (NSInteger)cartItemCount
{
    return [[CartManager sharedManager] totalItemsCount];
}

- (CGFloat)bottomNavigationClearance
{
    SEL selector = NSSelectorFromString(@"pp_bottomNavigationContentClearance");
    NSMutableOrderedSet<UIViewController *> *candidates = [NSMutableOrderedSet orderedSet];
    UIViewController *presenter = self.presentingViewController;
    if (presenter) {
        [candidates addObject:presenter];
    }
    if (presenter.navigationController) {
        [candidates addObject:presenter.navigationController];
    }
    if (presenter.tabBarController) {
        [candidates addObject:presenter.tabBarController];
    }
    if (presenter.navigationController.tabBarController) {
        [candidates addObject:presenter.navigationController.tabBarController];
    }
    UIViewController *parent = presenter.parentViewController;
    while (parent) {
        [candidates addObject:parent];
        parent = parent.parentViewController;
    }

    for (UIViewController *candidate in candidates) {
        if (![candidate respondsToSelector:selector]) {
            continue;
        }
        CGFloat (*implementation)(id, SEL) =
            (CGFloat (*)(id, SEL))[candidate methodForSelector:selector];
        if (!implementation) {
            continue;
        }
        CGFloat clearance = implementation(candidate, selector);
        if (isfinite(clearance) && clearance > 0.0) {
            return clearance;
        }
    }
    return 0.0;
}

#pragma mark - Route and selection state

- (PPDataSection)pp_resolvedInitialSection
{
    NSString *key = [self pp_sectionKeyForMainKind:
        self.input.sourceTarget == PPDeepLinkTargetAllCategories
            ? nil
            : self.input.mainKind];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    PPDataSection section = PPDataSectionAds;
    if ([self.input.initialSectionOverride respondsToSelector:@selector(integerValue)]) {
        section = (PPDataSection)self.input.initialSectionOverride.integerValue;
    } else if ([defaults objectForKey:key] != nil) {
        section = (PPDataSection)[defaults integerForKey:key];
    }
    if (section < PPDataSectionAds || section > PPDataSectionServices) {
        section = PPDataSectionAds;
    }
    return section;
}

- (NSString *)pp_sectionKeyForMainKind:(MainKindsModel *)mainKind
{
    if (!mainKind) {
        return kPPAllKindsSectionKey;
    }
    return [NSString stringWithFormat:@"pp.lastSection.%ld", (long)mainKind.ID];
}

- (NSString *)pp_subKindKeyForMainKind:(MainKindsModel *)mainKind
{
    if (!mainKind) {
        return @"pp.lastSubKind.all";
    }
    return [NSString stringWithFormat:@"pp.lastSubKind.%ld", (long)mainKind.ID];
}

- (void)pp_persistSection:(PPDataSection)section
{
    MainKindsModel *mainKind =
        self.input.sourceTarget == PPDeepLinkTargetAllCategories
            ? nil
            : self.input.mainKind;
    [NSUserDefaults.standardUserDefaults
        setInteger:section
            forKey:[self pp_sectionKeyForMainKind:mainKind]];
}

- (void)switchToSection:(PPDataSection)section
{
    if (section < PPDataSectionAds || section > PPDataSectionServices) {
        return;
    }
    [self pp_persistSection:section];
    PPFilterState *state = [self filterStateForSection:section];
    [self.viewModel setFilterState:state forSection:section];
    [self.viewModel switchToSection:section];
}

- (void)switchToMainKind:(MainKindsModel *)mainKind
{
    if (!mainKind || self.input.mainKind.ID == mainKind.ID) {
        return;
    }

    self.input.mainKind = mainKind;
    [self.filterStates removeAllObjects];
    if (self.input.sourceTarget == PPDeepLinkTargetAllCategories) {
        self.input.sourceTarget = PPDeepLinkTargetNone;
    }
    self.viewModel.currentDeepLinkTarget = self.input.sourceTarget;
    self.viewModel.currentSubKindID = 0;

    NSString *sectionKey = [self pp_sectionKeyForMainKind:mainKind];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    PPDataSection restoredSection = PPDataSectionAds;
    if ([defaults objectForKey:sectionKey] != nil) {
        restoredSection = (PPDataSection)[defaults integerForKey:sectionKey];
    }
    if (restoredSection < PPDataSectionAds || restoredSection > PPDataSectionServices) {
        restoredSection = PPDataSectionAds;
    }
    self.viewModel.pendingRestoreSection = restoredSection;
    [self.viewModel setFilterState:[self filterStateForSection:restoredSection]
                        forSection:restoredSection];
    [self.viewModel switchToMainKind:mainKind];
    [[NovaAmbientAssistantCoordinator sharedCoordinator]
        categoryDidOpen:mainKind.KindName ?: mainKind.KindNameEn];
    if (self.presentationStateDidChange) {
        self.presentationStateDidChange();
    }
}

- (void)switchToSubKind:(SubKindModel *)subKind
{
    if (self.input.sourceTarget == PPDeepLinkTargetAllCategories) {
        self.input.sourceTarget = PPDeepLinkTargetNone;
        self.viewModel.currentDeepLinkTarget = PPDeepLinkTargetNone;
    }

    NSInteger subKindID = subKind ? subKind.ID : 0;
    [NSUserDefaults.standardUserDefaults
        setInteger:subKindID
            forKey:[self pp_subKindKeyForMainKind:self.input.mainKind]];

    if (subKind) {
        [self.viewModel reloadForSubKind:subKind];
        [[NovaAmbientAssistantCoordinator sharedCoordinator]
            categoryDidOpen:subKind.SubKindName];
    } else {
        self.viewModel.currentSubKindID = 0;
        [self reload];
        [[NovaAmbientAssistantCoordinator sharedCoordinator]
            categoryDidOpen:self.input.mainKind.KindName];
    }
    if (self.presentationStateDidChange) {
        self.presentationStateDidChange();
    }
}

- (NSInteger)identifierForMainKind:(MainKindsModel *)mainKind
{
    return mainKind.ID;
}

- (NSString *)displayTitleForMainKind:(MainKindsModel *)mainKind
{
    NSString *title = PPMarketplaceTrimmedString(mainKind.KindName);
    if (title.length == 0) {
        title = PPMarketplaceTrimmedString(mainKind.KindNameEn);
    }
    return title;
}

- (NSInteger)identifierForSubKind:(SubKindModel *)subKind
{
    return subKind.ID;
}

- (NSString *)displayTitleForSubKind:(SubKindModel *)subKind
{
    NSString *title = PPMarketplaceTrimmedString(subKind.SubKindName);
    if (title.length == 0) {
        title = PPMarketplaceTrimmedString(subKind.SubKindNameEn);
    }
    return title;
}

#pragma mark - Filters

- (NSArray<PPAccessoryCategoryModel *> *)pp_accessoryCategories
{
    NSMutableArray<PPAccessoryCategoryModel *> *categories = [NSMutableArray array];
    MainKindsModel *mainKind = self.input.mainKind;
    if (mainKind && self.input.sourceTarget != PPDeepLinkTargetAllCategories) {
        NSArray<PPAccessoryCategoryModel *> *cached =
            [[MainKindsArrayManager shared] accessoryCategoriesForMainKindID:mainKind.ID] ?: @[];
        [categories addObjectsFromArray:
            cached.count > 0 ? cached : (mainKind.accessoryCategories ?: @[])];
    } else {
        NSArray<MainKindsModel *> *sourceKinds = self.mainKinds;
        for (MainKindsModel *kind in sourceKinds) {
            [categories addObjectsFromArray:kind.accessoryCategories ?: @[]];
        }
    }

    NSMutableArray<PPAccessoryCategoryModel *> *unique = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (PPAccessoryCategoryModel *category in categories) {
        NSString *categoryID = PPMarketplaceTrimmedString(
            category.categoryID.length > 0 ? category.categoryID : category.documentID);
        if (categoryID.length == 0 || [seen containsObject:categoryID]) {
            continue;
        }
        [seen addObject:categoryID];
        [unique addObject:category];
    }
    return unique.copy;
}

- (PPFilterState *)filterStateForSection:(PPDataSection)section
{
    NSNumber *key = @(section);
    PPFilterState *state = self.filterStates[key];
    if (!state) {
        state = section == PPDataSectionAccessories
            ? [PPFilterConfigProvider accessoriesFilterStateWithCategories:[self pp_accessoryCategories]]
            : [PPFilterConfigProvider defaultFilterStateForSection:section];
        self.filterStates[key] = state;
    }
    return state;
}

- (void)applyFilterState:(PPFilterState *)filterState
              forSection:(PPDataSection)section
{
    if (!filterState || section < PPDataSectionAds || section > PPDataSectionServices) {
        return;
    }
    self.filterStates[@(section)] = filterState;
    [self.viewModel setFilterState:filterState forSection:section];
    if (section == self.viewModel.currentSection) {
        [self.viewModel applyFilterState:filterState];
    }
}

- (NSInteger)previewResultCountForFilterState:(PPFilterState *)filterState
{
    return [self.viewModel previewResultCountForFilterState:filterState];
}

#pragma mark - Provider presentation filter

- (BOOL)sectionSupportsProviderFilter:(PPDataSection)section
{
    return section == PPDataSectionAccessories || section == PPDataSectionFood;
}

- (NSString *)pp_providerIDForViewModel:(PPUniversalCellViewModel *)viewModel
{
    id model = viewModel.ModelObject;
    if ([model isKindOfClass:PetAd.class]) {
        return PPMarketplaceTrimmedString(((PetAd *)model).ownerID);
    }
    if ([model isKindOfClass:PetAccessory.class]) {
        return PPMarketplaceTrimmedString(((PetAccessory *)model).ownerID);
    }
    if ([model isKindOfClass:ServiceModel.class]) {
        return PPMarketplaceTrimmedString(((ServiceModel *)model).serviceOwnerID);
    }
    for (NSString *selectorName in @[@"ownerID", @"providerID", @"providerId", @"userID", @"sellerID"]) {
        NSString *providerID = PPMarketplaceTrimmedString(
            PPMarketplaceObjectValueForSelector(model, selectorName));
        if (providerID.length > 0) {
            return providerID;
        }
    }
    return @"";
}

- (NSString *)pp_displayTitleForUser:(UserModel *)user
                          providerID:(NSString *)providerID
{
    if (![user isKindOfClass:UserModel.class]) {
        return @"";
    }
    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    NSString *bestName = PPMarketplaceTrimmedString(
        PPMarketplaceObjectValueForSelector(user, @"bestDisplayName"));
    if (bestName.length > 0) {
        [candidates addObject:bestName];
    }
    if (user.UserName.length > 0) {
        [candidates addObject:user.UserName];
    }
    NSString *fullName = PPMarketplaceTrimmedString(
        [NSString stringWithFormat:@"%@ %@", user.FirstName ?: @"", user.LastName ?: @""]);
    if (fullName.length > 0) {
        [candidates addObject:fullName];
    }
    for (NSString *candidate in candidates) {
        NSString *title = PPMarketplaceTrimmedString(candidate);
        if (title.length > 0 && ![title isEqualToString:providerID]) {
            return title;
        }
    }
    return @"";
}

- (NSDictionary<NSString *, NSString *> *)pp_cachedIdentityForProviderID:(NSString *)providerID
{
    NSDictionary<NSString *, NSString *> *cached = self.providerIdentityCache[providerID];
    if (cached.count > 0) {
        return cached;
    }
    UserModel *user = [UserManager userModelForID:providerID] ?:
        [UserManager userModelFromUsersArrayForID:providerID];
    NSString *title = [self pp_displayTitleForUser:user providerID:providerID];
    NSString *photoURL = PPMarketplaceTrimmedString(user.UserImageUrl);
    if (title.length > 0 || photoURL.length > 0) {
        NSMutableDictionary *identity = [NSMutableDictionary dictionary];
        if (title.length > 0) {
            identity[PPMarketplaceProviderIdentityTitleKey] = title;
        }
        if (photoURL.length > 0) {
            identity[PPMarketplaceProviderIdentityPhotoURLKey] = photoURL;
        }
        self.providerIdentityCache[providerID] = identity.copy;
    }
    return self.providerIdentityCache[providerID] ?: @{};
}

- (NSString *)pp_providerTitleForViewModel:(PPUniversalCellViewModel *)viewModel
                                providerID:(NSString *)providerID
{
    NSDictionary *cached = [self pp_cachedIdentityForProviderID:providerID];
    NSString *cachedTitle = PPMarketplaceTrimmedString(cached[PPMarketplaceProviderIdentityTitleKey]);
    if (cachedTitle.length > 0) {
        return cachedTitle;
    }

    id model = viewModel.ModelObject;
    if ([model isKindOfClass:PetAd.class]) {
        NSString *ownerName = PPMarketplaceTrimmedString(((PetAd *)model).ownerName);
        if (ownerName.length > 0 && ![ownerName isEqualToString:providerID]) {
            return ownerName;
        }
    }
    NSArray<NSString *> *selectors = @[
        @"providerDisplayName", @"providerName", @"providerBusinessName",
        @"ownerDisplayName", @"ownerName", @"sellerDisplayName", @"sellerName",
        @"storeName", @"shopName", @"companyName", @"CompanyName",
        @"businessName", @"legalName"
    ];
    for (NSString *selectorName in selectors) {
        NSString *title = PPMarketplaceTrimmedString(
            PPMarketplaceObjectValueForSelector(model, selectorName));
        if (title.length > 0 && ![title isEqualToString:providerID]) {
            return title;
        }
    }
    NSString *fallback = kLang(@"service_view_provider_title");
    return fallback.length > 0 ? fallback : providerID;
}

- (NSString *)pp_providerPhotoURLForViewModel:(PPUniversalCellViewModel *)viewModel
                                   providerID:(NSString *)providerID
{
    NSDictionary *cached = [self pp_cachedIdentityForProviderID:providerID];
    NSString *cachedURL = PPMarketplaceTrimmedString(cached[PPMarketplaceProviderIdentityPhotoURLKey]);
    if (cachedURL.length > 0) {
        return cachedURL;
    }
    NSArray<NSString *> *selectors = @[
        @"providerImageURL", @"providerImageUrl", @"providerPhotoURL", @"providerPhotoUrl",
        @"providerLogoURL", @"providerLogoUrl", @"ownerImageURL", @"ownerImageUrl",
        @"ownerPhotoURL", @"ownerPhotoUrl", @"ownerLogoURL", @"ownerLogoUrl",
        @"sellerImageURL", @"sellerImageUrl", @"sellerPhotoURL", @"sellerPhotoUrl",
        @"storeImageURL", @"storeImageUrl", @"storeLogoURL", @"storeLogoUrl",
        @"companyLogoURL", @"companyLogoUrl"
    ];
    for (NSString *selectorName in selectors) {
        NSString *photoURL = PPMarketplaceTrimmedString(
            PPMarketplaceObjectValueForSelector(viewModel.ModelObject, selectorName));
        if (photoURL.length > 0) {
            return photoURL;
        }
    }
    return @"";
}

- (NSArray<PPMarketplaceProviderOption *> *)providerOptionsForItems:(NSArray<PPUniversalCellViewModel *> *)items
                                                            section:(PPDataSection)section
{
    if (![self sectionSupportsProviderFilter:section]) {
        return @[];
    }
    NSMutableDictionary<NSString *, NSMutableDictionary *> *entries = [NSMutableDictionary dictionary];
    for (PPUniversalCellViewModel *viewModel in items ?: @[]) {
        if (viewModel.isSkeleton) {
            continue;
        }
        NSString *providerID = [self pp_providerIDForViewModel:viewModel];
        if (providerID.length == 0) {
            continue;
        }
        NSMutableDictionary *entry = entries[providerID];
        if (!entry) {
            entry = [@{
                @"title": [self pp_providerTitleForViewModel:viewModel providerID:providerID],
                @"photoURL": [self pp_providerPhotoURLForViewModel:viewModel providerID:providerID],
                @"count": @0
            } mutableCopy];
            entries[providerID] = entry;
        }
        entry[@"count"] = @([entry[@"count"] integerValue] + 1);
    }

    NSArray<NSString *> *orderedIDs = [entries.allKeys
        sortedArrayUsingComparator:^NSComparisonResult(NSString *left, NSString *right) {
            NSInteger leftCount = [entries[left][@"count"] integerValue];
            NSInteger rightCount = [entries[right][@"count"] integerValue];
            if (leftCount != rightCount) {
                return leftCount > rightCount ? NSOrderedAscending : NSOrderedDescending;
            }
            return [entries[left][@"title"] localizedCaseInsensitiveCompare:entries[right][@"title"]];
        }];

    NSMutableArray<PPMarketplaceProviderOption *> *options = [NSMutableArray array];
    for (NSString *providerID in orderedIDs) {
        NSDictionary *entry = entries[providerID];
        [options addObject:[[PPMarketplaceProviderOption alloc]
            initWithProviderID:providerID
                         title:entry[@"title"] ?: providerID
                      photoURL:PPMarketplaceTrimmedString(entry[@"photoURL"])
                     itemCount:[entry[@"count"] integerValue]]];
    }
    return options.copy;
}

- (NSArray<PPUniversalCellViewModel *> *)items:(NSArray<PPUniversalCellViewModel *> *)items
                           matchingProviderID:(NSString *)providerID
{
    NSString *cleanProviderID = PPMarketplaceTrimmedString(providerID);
    if (cleanProviderID.length == 0) {
        return [items copy] ?: @[];
    }
    return [items filteredArrayUsingPredicate:
        [NSPredicate predicateWithBlock:^BOOL(PPUniversalCellViewModel *viewModel, NSDictionary *bindings) {
            (void)bindings;
            return [[self pp_providerIDForViewModel:viewModel] isEqualToString:cleanProviderID];
        }]];
}

- (void)pp_storeProviderIdentityForID:(NSString *)providerID
                                title:(NSString *)title
                             photoURL:(NSString *)photoURL
{
    if (providerID.length == 0) {
        return;
    }
    NSMutableDictionary *identity =
        [self.providerIdentityCache[providerID] mutableCopy] ?: [NSMutableDictionary dictionary];
    NSString *cleanTitle = PPMarketplaceTrimmedString(title);
    NSString *cleanPhotoURL = PPMarketplaceTrimmedString(photoURL);
    if (cleanTitle.length > 0 && ![cleanTitle isEqualToString:providerID]) {
        identity[PPMarketplaceProviderIdentityTitleKey] = cleanTitle;
    }
    if (cleanPhotoURL.length > 0) {
        identity[PPMarketplaceProviderIdentityPhotoURLKey] = cleanPhotoURL;
    }
    if (identity.count > 0) {
        self.providerIdentityCache[providerID] = identity.copy;
    }
}

- (void)pp_hydrateProviderID:(NSString *)providerID
{
    if (providerID.length == 0 ||
        [self.hydratedProviderIDs containsObject:providerID] ||
        [self.providerIdentityFetchesInFlight containsObject:providerID]) {
        return;
    }
    [self.providerIdentityFetchesInFlight addObject:providerID];

    NSDictionary *cached = [self pp_cachedIdentityForProviderID:providerID];
    __block NSString *resolvedTitle = PPMarketplaceTrimmedString(cached[PPMarketplaceProviderIdentityTitleKey]);
    __block NSString *resolvedPhotoURL = PPMarketplaceTrimmedString(cached[PPMarketplaceProviderIdentityPhotoURLKey]);
    dispatch_group_t group = dispatch_group_create();

    dispatch_group_enter(group);
    [[UserManager sharedManager] getUserWithUID:providerID
                                      completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
        if (!error && user) {
            NSString *title = [self pp_displayTitleForUser:user providerID:providerID];
            NSString *photoURL = PPMarketplaceTrimmedString(user.UserImageUrl);
            if (title.length > 0) {
                resolvedTitle = title;
            }
            if (photoURL.length > 0) {
                resolvedPhotoURL = photoURL;
            }
        }
        dispatch_group_leave(group);
    }];

    NSString *profileID = [NSString stringWithFormat:@"%@_marketplace", providerID];
    FIRDocumentReference *profileRef =
        [[[FIRFirestore firestore] collectionWithPath:@"providerProfiles"]
            documentWithPath:profileID];
    dispatch_group_enter(group);
    [profileRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot,
                                            NSError * _Nullable error) {
        if (!error && snapshot.exists) {
            NSDictionary *data = [snapshot.data isKindOfClass:NSDictionary.class] ? snapshot.data : @{};
            NSDictionary *form = [data[@"form"] isKindOfClass:NSDictionary.class] ? data[@"form"] : @{};
            NSDictionary *summary = [data[@"userSummary"] isKindOfClass:NSDictionary.class]
                ? data[@"userSummary"] : @{};
            NSArray *titleCandidates = @[
                form[@"fullName"] ?: @"", summary[@"displayName"] ?: @"",
                data[@"displayName"] ?: @"", form[@"businessName"] ?: @"",
                data[@"businessName"] ?: @""
            ];
            for (id candidate in titleCandidates) {
                NSString *title = PPMarketplaceTrimmedString(candidate);
                if (title.length > 0 && ![title isEqualToString:providerID]) {
                    resolvedTitle = title;
                    break;
                }
            }
            NSArray *photoCandidates = @[
                summary[@"photoURL"] ?: @"", data[@"avatarURL"] ?: @"",
                data[@"photoURL"] ?: @""
            ];
            for (id candidate in photoCandidates) {
                NSString *photoURL = PPMarketplaceTrimmedString(candidate);
                if (photoURL.length > 0) {
                    resolvedPhotoURL = photoURL;
                    break;
                }
            }
        }
        dispatch_group_leave(group);
    }];

    __weak typeof(self) weakSelf = self;
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        [self.providerIdentityFetchesInFlight removeObject:providerID];
        [self.hydratedProviderIDs addObject:providerID];
        [self pp_storeProviderIdentityForID:providerID
                                     title:resolvedTitle
                                  photoURL:resolvedPhotoURL];
        if (self.providerIdentitiesDidChange) {
            self.providerIdentitiesDidChange();
        }
    });
}

- (void)hydrateProviderIdentitiesForItems:(NSArray<PPUniversalCellViewModel *> *)items
                                   section:(PPDataSection)section
{
    if (![self sectionSupportsProviderFilter:section]) {
        return;
    }
    NSMutableOrderedSet<NSString *> *providerIDs = [NSMutableOrderedSet orderedSet];
    for (PPUniversalCellViewModel *viewModel in items ?: @[]) {
        NSString *providerID = [self pp_providerIDForViewModel:viewModel];
        if (providerID.length > 0) {
            [providerIDs addObject:providerID];
        }
    }
    for (NSString *providerID in providerIDs) {
        [self pp_hydrateProviderID:providerID];
    }
}

#pragma mark - Navigation

- (UIViewController *)pp_resolvedPresenter
{
    UIViewController *presenter = self.presentingViewController ?: [AppManager sharedInstance].topViewController;
    while (presenter.presentedViewController &&
           !presenter.presentedViewController.isBeingDismissed) {
        presenter = presenter.presentedViewController;
    }
    return presenter;
}

- (void)openSearch
{
    UIViewController *presenter = [self pp_resolvedPresenter];
    if (!presenter || presenter.presentedViewController) {
        return;
    }
    PPSearchViewController *search = [PPSearchViewController new];
    PPNavigationController *navigation =
        [[PPNavigationController alloc] initWithRootViewController:search];
    navigation.modalPresentationStyle = UIModalPresentationFullScreen;
    [PPHomeHelper presentViewControllerSafely:navigation
                                         from:presenter
                                     animated:YES
                                   completion:nil];
}

- (void)openCart
{
    if (![UserManager sharedManager].isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }
    UIViewController *presenter = [self pp_resolvedPresenter];
    if (!presenter) {
        return;
    }
    CartViewController *cart = [CartViewController new];
    PPNavigationController *navigation =
        [[PPNavigationController alloc] initWithRootViewController:cart];
    navigation.modalPresentationStyle = UIModalPresentationFullScreen;
    [PPHomeHelper presentViewControllerSafely:navigation
                                         from:presenter
                                     animated:YES
                                   completion:nil];
}

- (void)openItem:(PPUniversalCellViewModel *)viewModel
{
    if (!viewModel.ModelObject) {
        return;
    }
    [PPOverlayCoordinator pp_openDetailForObject:viewModel.ModelObject
                                          fromVC:self.presentingViewController ?: [self pp_resolvedPresenter]
                                      routingNav:nil];
}

- (void)playVideoForItem:(PPUniversalCellViewModel *)viewModel
{
    if (!PPReusableVideoMediaEnabled() || !viewModel.isVideoMedia || viewModel.videoURL.length == 0) {
        [self openItem:viewModel];
        return;
    }
    NSURL *url = [NSURL URLWithString:PPMarketplaceTrimmedString(viewModel.videoURL)];
    if (!url) {
        [PPHUD showError:kLang(@"video_processing_failed_message")];
        return;
    }
    PPPremiumVideoPlayerViewController *player =
        [[PPPremiumVideoPlayerViewController alloc] initWithURL:url];
    [[self pp_resolvedPresenter] presentViewController:player
                                              animated:!UIAccessibilityIsReduceMotionEnabled()
                                            completion:nil];
}

#pragma mark - Universal card actions

- (void)changeQuantityForItem:(PPUniversalCellViewModel *)viewModel
                     quantity:(NSInteger)quantity
{
    [self PPUniversalCell_changeQuantity:viewModel quantity:quantity];
}

- (void)shareItem:(PPUniversalCellViewModel *)viewModel
{
    [self PPUniversalCell_tapShare:viewModel];
}

- (void)editItem:(PPUniversalCellViewModel *)viewModel
{
    [self PPUniversalCell_tapEdit:viewModel];
}

- (void)deleteItem:(PPUniversalCellViewModel *)viewModel
{
    [self PPUniversalCell_tapDelete:viewModel];
}

- (void)toggleVisibilityForItem:(PPUniversalCellViewModel *)viewModel
{
    [self PPUniversalCell_tapVisibilityToggle:viewModel];
}

- (void)chatAboutItem:(PPUniversalCellViewModel *)viewModel
{
    [self PPUniversalCell_tapChat:viewModel];
}

- (void)reportItem:(PPUniversalCellViewModel *)viewModel
{
    [self PPUniversalCell_tapReport:viewModel];
}

- (void)toggleSaveForLaterForItem:(PPUniversalCellViewModel *)viewModel
{
    [self PPUniversalCell_tapSaveForLater:viewModel];
}

- (void)PPUniversalCell_tapVideo:(PPUniversalCellViewModel *)universalModel
{
    [self playVideoForItem:universalModel];
}

- (void)PPUniversalCell_tapCard:(PPUniversalCellViewModel *)universalModel
{
    [self openItem:universalModel];
}

- (void)PPUniversalCell_changeQuantity:(PPUniversalCellViewModel *)viewModel
                              quantity:(NSInteger)quantity
{
    if (![viewModel.ModelObject isKindOfClass:PetAccessory.class]) {
        return;
    }
    PetAccessory *accessory = (PetAccessory *)viewModel.ModelObject;
    NSInteger maximumStock = MAX(accessory.quantity, 0);
    NSInteger safeQuantity = MAX(quantity, 0);
    if (maximumStock <= 0 && safeQuantity > 0) {
        [PPHUD showError:kLang(@"Out of stock")];
        safeQuantity = 0;
    } else if (safeQuantity > maximumStock) {
        safeQuantity = maximumStock;
        [PPHUD showInfo:[NSString stringWithFormat:@"%@ %ld %@",
            kLang(@"Only"), (long)maximumStock, kLang(@"left in stock")]];
    }

    CartManager *cart = [CartManager sharedManager];
    if (safeQuantity == 0) {
        [PPFunc triggerWarningHaptic];
        [cart removeItemForAccessory:accessory];
        [[NSNotificationCenter defaultCenter]
            postNotificationName:kCartUpdatedNotification object:nil];
        return;
    }

    CartItem *existing = [cart getCartItemForItemID:accessory.accessoryID];
    CartItem *item = [[CartItem alloc] initWithAccessory:accessory quantity:safeQuantity];
    if (existing) {
        [cart updateQuantity:safeQuantity forItem:item completion:nil];
        safeQuantity == 1 ? [PPFunc triggerLightHaptic] : [PPFunc triggerMediumHaptic];
        [[NSNotificationCenter defaultCenter]
            postNotificationName:kCartUpdatedNotification object:nil];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [cart addItem:item
        presentingViewController:self.presentingViewController
                     completion:^(BOOL didAdd, BOOL didCancel) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        if (didCancel) {
            [[NSNotificationCenter defaultCenter]
                postNotificationName:kCartUpdatedNotification object:nil];
            return;
        }
        if (!didAdd) {
            [PPHUD showError:kLang(@"Out of stock")];
            return;
        }
        if (safeQuantity == 1) {
            [PPFunc triggerLightHaptic];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [PPAddToCartSuccessToast showWithTitle:kLang(@"ItemAddedToCart") ?: @""];
            });
        } else {
            [PPFunc triggerMediumHaptic];
        }
        [[NSNotificationCenter defaultCenter]
            postNotificationName:kCartUpdatedNotification object:nil];
    }];
}

- (void)PPUniversalCell_tapShare:(PPUniversalCellViewModel *)universalModel
{
    UIViewController *presenter = self.presentingViewController ?: [self pp_resolvedPresenter];
    if ([universalModel.ModelObject isKindOfClass:PetAccessory.class]) {
        [PetAccessory sharePetAccessory:(PetAccessory *)universalModel.ModelObject
                     fromViewController:presenter];
    } else if ([universalModel.ModelObject isKindOfClass:PetAd.class]) {
        [PPAdSharingHelper sharePetAd:(PetAd *)universalModel.ModelObject
                  fromViewController:presenter];
    } else {
        [self openItem:universalModel];
    }
}

- (void)PPUniversalCell_tapEdit:(PPUniversalCellViewModel *)universalModel
{
    UIViewController *presenter = self.presentingViewController ?: [self pp_resolvedPresenter];
    if ([universalModel.ModelObject isKindOfClass:PetAd.class]) {
        AddNewAd *editor = [AddNewAd new];
        editor.mode = AdEditorModeEdit;
        editor.editingAd = (PetAd *)universalModel.ModelObject;
        UINavigationController *navigation =
            [[UINavigationController alloc] initWithRootViewController:editor];
        navigation.modalPresentationStyle = UIModalPresentationFullScreen;
        [presenter presentViewController:navigation animated:YES completion:nil];
        return;
    }
    if ([universalModel.ModelObject isKindOfClass:PetAccessory.class]) {
        AddNewAccessory *editor = [AddNewAccessory new];
        editor.editingAccessory = (PetAccessory *)universalModel.ModelObject;
        __weak typeof(self) weakSelf = self;
        editor.onFinish = ^(PetAccessory *result, BOOL isEdit) {
            (void)result;
            (void)isEdit;
            [weakSelf reload];
        };
        UINavigationController *navigation =
            [[UINavigationController alloc] initWithRootViewController:editor];
        navigation.modalPresentationStyle = UIModalPresentationFullScreen;
        [presenter presentViewController:navigation animated:YES completion:nil];
    }
}

- (void)PPUniversalCell_tapDelete:(PPUniversalCellViewModel *)universalModel
{
    if (![universalModel.ModelObject isKindOfClass:PetAd.class]) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    [GM showDeleteConfirmationFrom:self.presentingViewController ?: [self pp_resolvedPresenter]
                             title:kLang(@"Confirm Deletion")
                           message:kLang(@"Are you sure you want to delete this item?")
                        completion:^(BOOL confirmed) {
        if (!confirmed) {
            return;
        }
        [[PetAdManager sharedManager]
            deletePetAd:(PetAd *)universalModel.ModelObject
              completion:^(NSError * _Nullable error) {
            if (error) {
                [PPHUD showError:error.localizedDescription ?: kLang(@"SomethingWentWrong")];
                return;
            }
            [weakSelf reload];
        }];
    }];
}

- (void)PPUniversalCell_tapVisibilityToggle:(PPUniversalCellViewModel *)universalModel
{
    if (![UserManager sharedManager].isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }
    BOOL nextVisible = !universalModel.isPubliclyVisible;
    __weak typeof(self) weakSelf = self;
    void (^completion)(NSError * _Nullable) = ^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            if (error) {
                [PPAlertHelper showErrorIn:self.presentingViewController ?: [self pp_resolvedPresenter]
                                     title:kLang(@"Error")
                                  subtitle:error.localizedDescription ?: kLang(@"listing_visibility_failed")];
                return;
            }
            NSString *message = nextVisible
                ? kLang(@"listing_visible_success")
                : kLang(@"listing_hidden_success");
            [[AppManager sharedInstance]
                showSnakBar:message
                  withColor:[GM appPrimaryColor]
                andDuration:0.6
               containerView:self.presentingViewController.view];
            [self reload];
        });
    };

    if ([universalModel.ModelObject isKindOfClass:PetAd.class]) {
        PetAd *ad = (PetAd *)universalModel.ModelObject;
        [[PetAdManager sharedManager]
            updatePetAdID:ad.adID
               visibility:nextVisible ? PetAdVisibilityPublic : PetAdVisibilityHidden
               completion:completion];
    } else if ([universalModel.ModelObject isKindOfClass:PetAccessory.class]) {
        PetAccessory *accessory = (PetAccessory *)universalModel.ModelObject;
        [[PetAccessoryManager sharedManager]
            updateAccessoryID:accessory.accessoryID
              showInAppMarket:nextVisible
                   completion:completion];
    }
}

- (NSString *)pp_ownerIDForViewModel:(PPUniversalCellViewModel *)viewModel
{
    return [self pp_providerIDForViewModel:viewModel];
}

- (void)PPUniversalCell_tapChat:(PPUniversalCellViewModel *)universalModel
{
    if (![UserManager sharedManager].isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }
    NSString *ownerID = [self pp_ownerIDForViewModel:universalModel];
    if (ownerID.length == 0) {
        [PPHUD showInfo:kLang(@"bb_dataview_full_details_contact_unavailable")];
        return;
    }
    NSString *currentUID = [UserManager sharedManager].currentUser.ID ?:
        [FIRAuth auth].currentUser.uid ?: @"";
    if ([ownerID isEqualToString:currentUID]) {
        [PPHUD showInfo:kLang(@"bb_dataview_full_details_chat_self_unavailable")];
        return;
    }

    [PPHUD showLoading:kLang(@"bb_dataview_full_details_opening_chat")];
    __weak typeof(self) weakSelf = self;
    [[UserManager sharedManager]
        getOtherUserModelFromFirestoreWithUID:ownerID
        completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            [PPHUD dismiss];
            if (error || !user || user.ID.length == 0) {
                [PPHUD showError:kLang(@"bb_dataview_full_details_contact_unavailable")];
                return;
            }
            [[ChManager sharedManager]
                createOrGetChatThreadWithUser:user
                completion:^(ChatThreadModel * _Nullable thread, NSError * _Nullable chatError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (chatError || !thread) {
                        [PPHUD showError:kLang(@"SomethingWentWrong")
                               subtitle:chatError.localizedDescription ?: @""];
                        return;
                    }
                    [PPOverlayCoordinator pp_openChatThread:thread
                                                     fromVC:self.presentingViewController];
                });
            }];
        });
    }];
}

- (void)PPUniversalCell_tapReport:(PPUniversalCellViewModel *)universalModel
{
    (void)universalModel;
    [PPHUD showSuccess:kLang(@"reported_successfully")];
}

- (void)PPUniversalCell_tapSaveForLater:(PPUniversalCellViewModel *)universalModel
{
    NSString *itemID = universalModel.ModelID ?: @"";
    if (itemID.length == 0) {
        [PPHUD showError:kLang(@"SomethingWentWrong")];
        return;
    }
    PPSaveForLaterManager *manager = [PPSaveForLaterManager sharedManager];
    if ([manager isItemSaved:itemID]) {
        CartItem *item = [CartItem new];
        item.itemID = itemID;
        item.name = universalModel.title ?: @"";
        [manager removeItem:item];
        [PPHUD showInfo:kLang(@"saved_for_later_removed_toast") subtitle:nil delay:2.5];
    } else {
        [manager saveViewModelForLater:universalModel];
        [PPHUD showSuccess:kLang(@"saved_for_later_added_toast") subtitle:nil delay:2.5];
    }
}

#pragma mark - Analytics, Nova, and presentation refresh

- (void)screenWillAppear
{
    [[NovaAmbientAssistantCoordinator sharedCoordinator] setSuppressedForCriticalFlow:YES];
    NSString *category = PPMarketplaceTrimmedString(self.input.mainKind.KindNameEn);
    if (category.length == 0) {
        category = PPMarketplaceTrimmedString(self.currentMainKindTitle);
    }
    if (category.length > 0) {
        [PPAnalytics logViewCategoryWithCategory:category listName:nil];
        [PPAnalytics logViewItemListWithCategory:category
                                        listName:@"home_feed"
                                       itemCount:self.items.count];
    }
    [self refreshPresentationState];
}

- (void)screenWillDisappear
{
    [[NovaAmbientAssistantCoordinator sharedCoordinator] hideNova];
    [[NovaAmbientAssistantCoordinator sharedCoordinator] setSuppressedForCriticalFlow:NO];
}

- (void)screenDidShowEmptyState
{
    [[NovaAmbientAssistantCoordinator sharedCoordinator] emptyStateDidAppear];
}

- (void)userDidBeginScrolling
{
    [[NovaAmbientAssistantCoordinator sharedCoordinator] userDidScroll];
}

- (void)userDidEndScrolling
{
    [[NovaAmbientAssistantCoordinator sharedCoordinator] userDidStopScrolling];
}

- (void)refreshPresentationState
{
    if (self.presentationStateDidChange) {
        self.presentationStateDidChange();
    }
}

@end
