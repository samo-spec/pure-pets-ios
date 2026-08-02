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
#import "PPDataViewInput.h"
#import "PPDataViewVM.h"
#import "PPFunc.h"
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
#import "UIViewController+PPBottomSurface.h"

static NSString * const PPMarketplaceProviderIdentityTitleKey = @"title";
static NSString * const PPMarketplaceProviderIdentityPhotoURLKey = @"photoURL";

@interface UIViewController (PPMarketplaceDataViewBottomClearance)
- (CGFloat)pp_bottomNavigationContentClearance;
@end

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

@implementation PPMarketplaceTaxonomyOption

- (instancetype)initWithIdentifier:(NSInteger)identifier
                              title:(NSString *)title
{
    self = [super init];
    if (!self) {
        return nil;
    }
    _identifier = identifier;
    _title = [title copy] ?: @"";
    return self;
}

@end

@implementation PPMarketplaceNavigationContext

- (instancetype)initWithTitle:(NSString *)title
                      subtitle:(NSString *)subtitle
               systemImageName:(NSString *)systemImageName
            accessibilityLabel:(NSString *)accessibilityLabel
{
    self = [super init];
    if (!self) {
        return nil;
    }
    _title = [title copy] ?: @"";
    _subtitle = [subtitle copy] ?: @"";
    _systemImageName = [systemImageName copy] ?: @"";
    _accessibilityLabel = [accessibilityLabel copy] ?: @"";
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

- (BOOL)pp_shouldUseBrandAccent;
- (void)pp_submitReportForContentID:(NSString *)contentID
                        contentType:(NSString *)contentType
                         collection:(NSString *)collection
                            ownerID:(NSString *)ownerID
                         reporterID:(NSString *)reporterID
                             reason:(NSString *)reason;

@end

@implementation PPMarketplaceDataViewBridge

#pragma mark - Lifecycle

- (instancetype)initWithInput:(PPDataViewInput *)input
{
    NSParameterAssert(input != nil);
    self = [super init];
    if (!self) {
        return nil;
    }

    _input = input;
    _filterStates = [NSMutableDictionary dictionary];
    _providerIdentityCache = [NSMutableDictionary dictionary];
    _providerIdentityFetchesInFlight = [NSMutableSet set];
    _hydratedProviderIDs = [NSMutableSet set];

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
    [self reloadWithCompletion:nil];
}

- (void)reloadWithCompletion:(void (^)(NSError * _Nullable))completion
{
    __weak typeof(self) weakSelf = self;
    [self.viewModel reloadDataWithCompletion:^(NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        BOOL wasCancelled = [error.domain isEqualToString:NSURLErrorDomain] &&
            error.code == NSURLErrorCancelled;
        if (error && !wasCancelled && self.loadingDidFail) {
            self.loadingDidFail(error);
        }
        if (completion) {
            completion(error);
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
    if (self.input.sourceTarget == PPDeepLinkTargetAllCategories) {
        return @[];
    }
    return [self.input.mainKind.SubKindsArray copy] ?: @[];
}

- (NSArray<PPMarketplaceTaxonomyOption *> *)mainKindOptions
{
    NSMutableArray<PPMarketplaceTaxonomyOption *> *options = [NSMutableArray array];
    for (MainKindsModel *mainKind in self.mainKinds) {
        [options addObject:[[PPMarketplaceTaxonomyOption alloc]
            initWithIdentifier:[self identifierForMainKind:mainKind]
                         title:[self displayTitleForMainKind:mainKind]]];
    }
    return options;
}

- (NSArray<PPMarketplaceTaxonomyOption *> *)subKindOptions
{
    NSMutableArray<PPMarketplaceTaxonomyOption *> *options = [NSMutableArray array];
    for (SubKindModel *subKind in self.subKinds) {
        [options addObject:[[PPMarketplaceTaxonomyOption alloc]
            initWithIdentifier:[self identifierForSubKind:subKind]
                         title:[self displayTitleForSubKind:subKind]]];
    }
    return options;
}

- (NSArray<PPMarketplaceTaxonomyOption *> *)subKindOptionsForMainKindIdentifier:(NSInteger)mainKindIdentifier
{
    if (mainKindIdentifier == 0) {
        return @[];
    }

    MainKindsModel *selectedMainKind = nil;
    for (MainKindsModel *mainKind in self.mainKinds) {
        if (mainKind.ID == mainKindIdentifier) {
            selectedMainKind = mainKind;
            break;
        }
    }
    if (!selectedMainKind) {
        return @[];
    }

    NSMutableArray<PPMarketplaceTaxonomyOption *> *options =
        [NSMutableArray array];
    for (SubKindModel *subKind in selectedMainKind.SubKindsArray ?: @[]) {
        if (subKind.MainKindID != 0 &&
            subKind.MainKindID != selectedMainKind.ID) {
            continue;
        }
        [options addObject:[[PPMarketplaceTaxonomyOption alloc]
            initWithIdentifier:[self identifierForSubKind:subKind]
                         title:[self displayTitleForSubKind:subKind]]];
    }
    return options.copy;
}

- (NSInteger)currentMainKindID
{
    if (self.input.sourceTarget == PPDeepLinkTargetAllCategories) {
        return 0;
    }
    return self.input.mainKind.ID;
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
    UIColor *raw = [self pp_shouldUseBrandAccent]
        ? ([GM appPrimaryColor] ?: UIColor.systemPinkColor)
        : self.input.accentColor;
    return [MainKindsModel pp_softenedKindColorIfNeeded:raw forMainKind:self.input.mainKind];
}

- (BOOL)isUsingBrandAccent
{
    return [self pp_shouldUseBrandAccent];
}

- (BOOL)pp_shouldUseBrandAccent
{
    if (self.input.sourceTarget == PPDeepLinkTargetAllCategories) {
        return YES;
    }

    BOOL usesMainKindAccentColors =
        [NSUserDefaults.standardUserDefaults
            boolForKey:PPMarketplaceUsesMainKindAccentColorsPreferenceKey];
    return !usesMainKindAccentColors || self.input.accentColor == nil;
}

- (NSInteger)cartItemCount
{
    return [[CartManager sharedManager] totalItemsCount];
}

- (CGFloat)bottomNavigationClearance
{
    SEL selector = @selector(pp_bottomNavigationContentClearance);
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
    BOOL exitsAllCategories =
        self.input.sourceTarget == PPDeepLinkTargetAllCategories;
    if (!mainKind ||
        (!exitsAllCategories && self.input.mainKind.ID == mainKind.ID)) {
        return;
    }

    self.input.mainKind = mainKind;
    self.input.accentColor = mainKind.kindColor;
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

- (void)switchToMainKindIdentifier:(NSInteger)identifier
{
    if (identifier == 0) {
        [self switchToAllMainKinds];
        return;
    }
    for (MainKindsModel *mainKind in self.mainKinds) {
        if (mainKind.ID == identifier) {
            [self switchToMainKind:mainKind];
            return;
        }
    }
}

- (void)switchToAllMainKinds
{
    if (self.input.sourceTarget == PPDeepLinkTargetAllCategories) {
        return;
    }

    self.input.sourceTarget = PPDeepLinkTargetAllCategories;
    self.input.mainKind = self.mainKinds.firstObject;
    self.input.accentColor = [GM appPrimaryColor] ?: UIColor.systemPinkColor;
    [self.filterStates removeAllObjects];
    self.viewModel.currentSubKindID = 0;
    [self.viewModel switchToAllMainKinds];
    [[NovaAmbientAssistantCoordinator sharedCoordinator]
        categoryDidOpen:self.currentMainKindTitle];
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

- (void)switchToSubKindIdentifier:(NSInteger)identifier
{
    if (identifier == 0) {
        [self switchToSubKind:nil];
        return;
    }
    for (SubKindModel *subKind in self.subKinds) {
        if (subKind.ID == identifier) {
            [self switchToSubKind:subKind];
            return;
        }
    }
}

- (void)applyCategoryMainKindIdentifier:(NSInteger)mainKindIdentifier
                      subKindIdentifier:(NSInteger)subKindIdentifier
{
    if (mainKindIdentifier == 0) {
        [self switchToAllMainKinds];
        return;
    }

    MainKindsModel *selectedMainKind = nil;
    for (MainKindsModel *mainKind in self.mainKinds) {
        if (mainKind.ID == mainKindIdentifier) {
            selectedMainKind = mainKind;
            break;
        }
    }
    if (!selectedMainKind) {
        return;
    }

    SubKindModel *selectedSubKind = nil;
    if (subKindIdentifier > 0) {
        SubKindModel *candidate =
            [selectedMainKind subKindForID:subKindIdentifier];
        if (candidate &&
            (candidate.MainKindID == 0 ||
             candidate.MainKindID == selectedMainKind.ID)) {
            selectedSubKind = candidate;
        }
    }
    NSInteger resolvedSubKindID = selectedSubKind ? selectedSubKind.ID : 0;
    BOOL exitsAllCategories =
        self.input.sourceTarget == PPDeepLinkTargetAllCategories;
    BOOL changesMainKind =
        exitsAllCategories || self.input.mainKind.ID != selectedMainKind.ID;

    if (!changesMainKind) {
        if (self.viewModel.currentSubKindID == resolvedSubKindID) {
            return;
        }
        [self switchToSubKind:selectedSubKind];
        return;
    }

    self.input.mainKind = selectedMainKind;
    self.input.accentColor = selectedMainKind.kindColor;
    [self.filterStates removeAllObjects];
    if (exitsAllCategories) {
        self.input.sourceTarget = PPDeepLinkTargetNone;
    }
    self.viewModel.currentDeepLinkTarget = self.input.sourceTarget;

    NSString *sectionKey = [self pp_sectionKeyForMainKind:selectedMainKind];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    PPDataSection restoredSection = PPDataSectionAds;
    if ([defaults objectForKey:sectionKey] != nil) {
        restoredSection = (PPDataSection)[defaults integerForKey:sectionKey];
    }
    if (restoredSection < PPDataSectionAds ||
        restoredSection > PPDataSectionServices) {
        restoredSection = PPDataSectionAds;
    }
    self.viewModel.pendingRestoreSection = restoredSection;
    [self.viewModel setFilterState:[self filterStateForSection:restoredSection]
                        forSection:restoredSection];
    [NSUserDefaults.standardUserDefaults
        setInteger:resolvedSubKindID
            forKey:[self pp_subKindKeyForMainKind:selectedMainKind]];
    [self.viewModel switchToMainKind:selectedMainKind
                             subKind:selectedSubKind];

    NSString *analyticsCategory = selectedSubKind
        ? selectedSubKind.SubKindName
        : selectedMainKind.KindName;
    [[NovaAmbientAssistantCoordinator sharedCoordinator]
        categoryDidOpen:analyticsCategory ?: selectedMainKind.KindNameEn];
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

- (NSInteger)activeFilterCountForSection:(PPDataSection)section
{
    return [self filterStateForSection:section].activeFilterCount;
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
    return @"";
}

- (NSString *)pp_displayTitleForUser:(UserModel *)user
                          providerID:(NSString *)providerID
{
    if (![user isKindOfClass:UserModel.class]) {
        return @"";
    }
    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    NSString *bestName = PPMarketplaceTrimmedString([user bestDisplayName]);
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

#pragma mark - Smart navigation context

- (NSString *)pp_navigationSectionTitleForSection:(PPDataSection)section
{
    switch (section) {
        case PPDataSectionAds:
            return kLang(@"Ads") ?: @"";
        case PPDataSectionAccessories:
            return kLang(@"Accessories") ?: @"";
        case PPDataSectionFood:
            return kLang(@"Food") ?: @"";
        case PPDataSectionServices:
            return kLang(@"services") ?: @"";
    }
    return @"";
}

- (NSString *)pp_navigationSectionContextForSection:(PPDataSection)section
{
    NSString *key = @"dataview_filter_context_products";
    if (section == PPDataSectionAds) {
        key = @"dataview_filter_context_listings";
    } else if (section == PPDataSectionServices) {
        key = @"dataview_filter_context_services";
    }
    NSString *localized = PPMarketplaceTrimmedString(kLang(key));
    return localized.length > 0
        ? localized
        : [self pp_navigationSectionTitleForSection:section];
}

- (NSString *)pp_navigationMainKindContextTitle
{
    NSString *title = PPMarketplaceTrimmedString(self.currentMainKindTitle);
    NSString *allSpecies = PPMarketplaceTrimmedString(kLang(@"data_nav_all_species"));
    NSString *all = PPMarketplaceTrimmedString(kLang(@"All"));
    if (title.length == 0 ||
        [title isEqualToString:allSpecies] ||
        (all.length > 0 && [title isEqualToString:all])) {
        return @"";
    }
    return title;
}

- (NSString *)pp_navigationSubKindContextTitle
{
    NSString *title = PPMarketplaceTrimmedString(self.currentSubKindTitle);
    NSString *allBreed = PPMarketplaceTrimmedString(kLang(@"data_nav_all_breed"));
    NSString *all = PPMarketplaceTrimmedString(kLang(@"All"));
    if (title.length == 0 ||
        [title isEqualToString:allBreed] ||
        (all.length > 0 && [title isEqualToString:all])) {
        return @"";
    }
    return title;
}

- (NSString *)pp_navigationPrimaryTitleForSection:(PPDataSection)section
{
    NSString *sectionTitle = PPMarketplaceTrimmedString(
        [self pp_navigationSectionTitleForSection:section]);
    NSString *kindTitle = [self pp_navigationMainKindContextTitle];
    NSString *baseTitle = @"";
    if (sectionTitle.length == 0) {
        baseTitle = kindTitle.length > 0
            ? kindTitle
            : [self pp_navigationSectionContextForSection:section];
    } else if (kindTitle.length == 0) {
        baseTitle = sectionTitle;
    } else if ([sectionTitle localizedCaseInsensitiveContainsString:kindTitle] ||
               [kindTitle localizedCaseInsensitiveContainsString:sectionTitle]) {
        baseTitle = sectionTitle;
    } else {
        baseTitle = Language.isRTL
            ? [NSString stringWithFormat:@"%@ %@", sectionTitle, kindTitle]
            : [NSString stringWithFormat:@"%@ %@", kindTitle, sectionTitle];
    }

    NSString *subKindTitle = [self pp_navigationSubKindContextTitle];
    if (subKindTitle.length == 0 ||
        [baseTitle localizedCaseInsensitiveContainsString:subKindTitle]) {
        return baseTitle;
    }
    if (baseTitle.length == 0) {
        return subKindTitle;
    }
    return [NSString stringWithFormat:@"%@ · %@", baseTitle, subKindTitle];
}

- (PPFilterGroup *)pp_navigationStrongestActiveFilterForSection:(PPDataSection)section
{
    PPFilterState *state = [self filterStateForSection:section];
    NSArray<NSString *> *priority = @[
        PPFilterIDAccessoryCategory,
        PPFilterIDServiceType,
        PPFilterIDPrice,
        PPFilterIDHasOffer,
        PPFilterIDAvailability,
        PPFilterIDCondition,
        PPFilterIDGender,
        PPFilterIDSort
    ];
    for (NSString *filterID in priority) {
        PPFilterGroup *group = [state groupForID:filterID];
        if (group.isActive) {
            return group;
        }
    }
    for (PPFilterGroup *group in state.groups) {
        if (group.isActive) {
            return group;
        }
    }
    return nil;
}

- (NSString *)pp_navigationDisplayTitleForFilterGroup:(PPFilterGroup *)group
{
    NSString *selectedTitle = PPMarketplaceTrimmedString(group.selectedTitle);
    NSString *groupTitle = PPMarketplaceTrimmedString(group.title);
    if (selectedTitle.length == 0 || [selectedTitle isEqualToString:groupTitle]) {
        return @"";
    }
    return selectedTitle;
}

- (NSString *)pp_navigationShortProviderIdentifier:(NSString *)providerID
{
    NSString *cleanID = PPMarketplaceTrimmedString(providerID);
    return cleanID.length <= 6 ? cleanID : [cleanID substringToIndex:6];
}

- (BOOL)pp_navigationProviderTitleIsGeneric:(NSString *)title
                                 providerID:(NSString *)providerID
{
    NSString *cleanTitle = PPMarketplaceTrimmedString(title);
    NSString *cleanProviderID = PPMarketplaceTrimmedString(providerID);
    if (cleanTitle.length == 0 ||
        (cleanProviderID.length > 0 && [cleanTitle isEqualToString:cleanProviderID]) ||
        (cleanProviderID.length > 0 &&
         [cleanTitle isEqualToString:[self pp_navigationShortProviderIdentifier:cleanProviderID]])) {
        return YES;
    }

    NSMutableArray<NSString *> *genericTitles = [@[
        @"Provider", @"Service Provider", @"مقدم الخدمة", @"مزود"
    ] mutableCopy];
    for (NSString *key in @[@"service_view_provider_title", @"dataview_filter_by_provider"]) {
        NSString *localized = PPMarketplaceTrimmedString(kLang(key));
        if (localized.length > 0) {
            [genericTitles addObject:localized];
        }
    }
    for (NSString *generic in genericTitles) {
        if ([cleanTitle localizedCaseInsensitiveCompare:generic] == NSOrderedSame) {
            return YES;
        }
    }
    return NO;
}

- (NSString *)pp_navigationProviderTitleForID:(NSString *)providerID
                                      section:(PPDataSection)section
{
    NSString *cleanProviderID = PPMarketplaceTrimmedString(providerID);
    if (cleanProviderID.length == 0 || ![self sectionSupportsProviderFilter:section]) {
        return @"";
    }

    NSDictionary<NSString *, NSString *> *cached =
        [self pp_cachedIdentityForProviderID:cleanProviderID];
    NSString *cachedTitle = PPMarketplaceTrimmedString(
        cached[PPMarketplaceProviderIdentityTitleKey]);
    if (![self pp_navigationProviderTitleIsGeneric:cachedTitle providerID:cleanProviderID]) {
        return cachedTitle;
    }

    NSArray<PPMarketplaceProviderOption *> *options =
        [self providerOptionsForItems:self.items section:section];
    for (PPMarketplaceProviderOption *option in options) {
        if (![option.providerID isEqualToString:cleanProviderID]) {
            continue;
        }
        NSString *title = PPMarketplaceTrimmedString(option.title);
        if (![self pp_navigationProviderTitleIsGeneric:title providerID:cleanProviderID]) {
            return title;
        }
    }

    for (PPUniversalCellViewModel *viewModel in self.items) {
        if (![[self pp_providerIDForViewModel:viewModel] isEqualToString:cleanProviderID]) {
            continue;
        }
        NSString *title = [self pp_providerTitleForViewModel:viewModel
                                                  providerID:cleanProviderID];
        if (![self pp_navigationProviderTitleIsGeneric:title providerID:cleanProviderID]) {
            return title;
        }
    }

    NSString *shortIdentifier = [self pp_navigationShortProviderIdentifier:cleanProviderID];
    NSString *fallbackFormat = kLang(@"dataview_provider_fallback_name_format");
    return fallbackFormat.length > 0
        ? [NSString stringWithFormat:fallbackFormat, shortIdentifier]
        : shortIdentifier;
}

- (NSString *)pp_navigationSecondaryTitleForSection:(PPDataSection)section
                                  selectedProviderID:(NSString *)selectedProviderID
{
    NSInteger activeCount = [self activeFilterCountForSection:section];
    if (PPMarketplaceTrimmedString(selectedProviderID).length > 0 &&
        [self sectionSupportsProviderFilter:section]) {
        activeCount += 1;
    }

    NSString *candidate = [self pp_navigationProviderTitleForID:selectedProviderID
                                                        section:section];
    if (candidate.length == 0) {
        candidate = [self pp_navigationDisplayTitleForFilterGroup:
            [self pp_navigationStrongestActiveFilterForSection:section]];
    }
    if (candidate.length == 0) {
        candidate = [self pp_navigationSectionContextForSection:section];
    }
    if (candidate.length == 0) {
        return @"";
    }

    if (activeCount > 1) {
        NSString *format = kLang(@"dataview_smart_filter_additional_count_format");
        NSString *additional = format.length > 0
            ? [NSString stringWithFormat:format, (long)(activeCount - 1)]
            : [NSString stringWithFormat:@"+%ld", (long)(activeCount - 1)];
        return [NSString stringWithFormat:@"%@ · %@", candidate, additional];
    }
    return candidate;
}

- (NSString *)pp_navigationIconNameForSection:(PPDataSection)section
                           selectedProviderID:(NSString *)selectedProviderID
{
    if ([self sectionSupportsProviderFilter:section] &&
        PPMarketplaceTrimmedString(selectedProviderID).length > 0) {
        return @"storefront.fill";
    }
    PPFilterGroup *group = [self pp_navigationStrongestActiveFilterForSection:section];
    if ([group.filterID isEqualToString:PPFilterIDAccessoryCategory]) {
        return @"square.grid.2x2.fill";
    }
    if ([group.filterID isEqualToString:PPFilterIDPrice]) {
        return @"tag.fill";
    }
    if ([group.filterID isEqualToString:PPFilterIDHasOffer]) {
        return @"flame.fill";
    }
    if ([group.filterID isEqualToString:PPFilterIDAvailability]) {
        return @"calendar.badge.clock";
    }
    if ([group.filterID isEqualToString:PPFilterIDGender]) {
        return @"person.2.fill";
    }
    NSString *chipIcon = PPMarketplaceTrimmedString(group.chipIconName);
    if (chipIcon.length > 0) {
        return chipIcon;
    }
    switch (section) {
        case PPDataSectionAds:
            return @"megaphone.fill";
        case PPDataSectionAccessories:
            return @"bag.fill";
        case PPDataSectionFood:
            return @"cart.fill";
        case PPDataSectionServices:
            return @"cross.case.fill";
    }
    return @"line.3.horizontal.decrease.circle.fill";
}

- (PPMarketplaceNavigationContext *)navigationContextForSection:(PPDataSection)section
                                             selectedProviderID:(NSString *)selectedProviderID
{
    NSString *title = [self pp_navigationPrimaryTitleForSection:section];
    NSString *subtitle = [self pp_navigationSecondaryTitleForSection:section
                                                   selectedProviderID:selectedProviderID];
    NSInteger activeCount = [self activeFilterCountForSection:section];
    if (PPMarketplaceTrimmedString(selectedProviderID).length > 0 &&
        [self sectionSupportsProviderFilter:section]) {
        activeCount += 1;
    }

    NSMutableArray<NSString *> *accessibilityParts = [NSMutableArray array];
    if (title.length > 0) {
        [accessibilityParts addObject:title];
    }
    if (subtitle.length > 0 && ![subtitle isEqualToString:title]) {
        [accessibilityParts addObject:subtitle];
    }
    NSString *activeCountFormat = kLang(@"dataview_filters_active_count_accessibility_format");
    if (activeCount > 0 && activeCountFormat.length > 0) {
        [accessibilityParts addObject:
            [NSString stringWithFormat:activeCountFormat, (long)activeCount]];
    }

    return [[PPMarketplaceNavigationContext alloc]
        initWithTitle:title
             subtitle:subtitle
      systemImageName:[self pp_navigationIconNameForSection:section
                                         selectedProviderID:selectedProviderID]
   accessibilityLabel:[accessibilityParts componentsJoinedByString:@", "]];
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

- (void)goBack
{
    UIViewController *presenter = self.presentingViewController;
    UINavigationController *navigationController = presenter.navigationController;
    if (navigationController &&
        navigationController.viewControllers.firstObject != presenter &&
        [navigationController.viewControllers containsObject:presenter]) {
        [navigationController popViewControllerAnimated:YES];
        return;
    }
    [presenter dismissViewControllerAnimated:YES completion:nil];
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
            [[NSNotificationCenter defaultCenter]
                postNotificationName:kCartUpdatedNotification object:nil];
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
    FIRUser *authenticatedUser = [FIRAuth auth].currentUser;
    if (authenticatedUser.uid.length == 0) {
        [UserManager showPromptOnTopController];
        return;
    }

    NSString *contentID = @"";
    NSString *ownerID = @"";
    NSString *collection = @"";
    NSString *contentType = @"";
    if ([universalModel.ModelObject isKindOfClass:PetAd.class]) {
        PetAd *ad = (PetAd *)universalModel.ModelObject;
        contentID = PPMarketplaceTrimmedString(ad.adID);
        ownerID = PPMarketplaceTrimmedString(ad.ownerID);
        collection = kPetAdsCollection;
        contentType = @"pet_ad";
    } else if ([universalModel.ModelObject isKindOfClass:PetAccessory.class]) {
        PetAccessory *accessory = (PetAccessory *)universalModel.ModelObject;
        contentID = PPMarketplaceTrimmedString(accessory.accessoryID);
        ownerID = PPMarketplaceTrimmedString(accessory.ownerID);
        collection = @"petAccessories";
        contentType = @"pet_accessory";
    } else if ([universalModel.ModelObject isKindOfClass:ServiceModel.class]) {
        ServiceModel *service = (ServiceModel *)universalModel.ModelObject;
        contentID = PPMarketplaceTrimmedString(service.serviceID);
        ownerID = PPMarketplaceTrimmedString(service.serviceOwnerID);
        collection = @"serviceOffers";
        contentType = @"service_offer";
    } else {
        [PPHUD showError:kLang(@"report_submit_failed_message")];
        return;
    }
    NSString *reporterID = PPMarketplaceTrimmedString(authenticatedUser.uid);
    if (contentID.length == 0 || reporterID.length == 0 ||
        (ownerID.length > 0 && [ownerID isEqualToString:reporterID])) {
        [PPHUD showError:kLang(@"report_submit_failed_message")];
        return;
    }

    UIViewController *presenter = [self pp_resolvedPresenter];
    if (!presenter || presenter.viewIfLoaded.window == nil ||
        presenter.isBeingDismissed ||
        [presenter isKindOfClass:UIAlertController.class]) {
        [PPHUD showError:kLang(@"report_submit_failed_message")];
        return;
    }
    UIAlertController *sheet = [UIAlertController
        alertControllerWithTitle:kLang(@"report_alert_title")
                         message:kLang(@"report_alert_message")
                  preferredStyle:UIAlertControllerStyleActionSheet];
    NSDictionary<NSString *, NSString *> *reasonTitles = @{
        @"inappropriate_content": kLang(@"report_reason_inappropriate") ?: @"",
        @"scam_fraud": kLang(@"report_reason_fraud") ?: @"",
        @"wrong_category": kLang(@"report_reason_wrong_category") ?: @"",
        @"spam": kLang(@"report_reason_spam") ?: @"",
        @"other": kLang(@"report_reason_other") ?: @""
    };
    NSArray<NSString *> *orderedReasons = @[
        @"inappropriate_content", @"scam_fraud", @"wrong_category",
        @"spam", @"other"
    ];
    __weak typeof(self) weakSelf = self;
    for (NSString *reason in orderedReasons) {
        [sheet addAction:[UIAlertAction
            actionWithTitle:reasonTitles[reason]
                      style:UIAlertActionStyleDefault
                    handler:^(__unused UIAlertAction *action) {
            __strong typeof(weakSelf) self = weakSelf;
            [self pp_submitReportForContentID:contentID
                                   contentType:contentType
                                    collection:collection
                                       ownerID:ownerID
                                    reporterID:reporterID
                                        reason:reason];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"cancel")
                                               style:UIAlertActionStyleCancel
                                             handler:nil]];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = presenter.view;
        sheet.popoverPresentationController.sourceRect = CGRectMake(
            CGRectGetMidX(presenter.view.bounds),
            CGRectGetMidY(presenter.view.bounds),
            1,
            1
        );
        sheet.popoverPresentationController.permittedArrowDirections = 0;
    }
    [presenter presentViewController:sheet animated:YES completion:nil];
}

- (void)pp_submitReportForContentID:(NSString *)contentID
                        contentType:(NSString *)contentType
                         collection:(NSString *)collection
                            ownerID:(NSString *)ownerID
                         reporterID:(NSString *)reporterID
                             reason:(NSString *)reason
{
    NSString *reportID = [NSString stringWithFormat:@"%@_%@", contentID, reporterID];
    NSDictionary *reportData = @{
        @"reportId": reportID,
        @"contentId": contentID,
        @"contentType": contentType,
        @"collection": collection,
        @"reason": reason,
        @"reporterUid": reporterID,
        @"reportedOwnerUid": ownerID ?: @"",
        @"status": @"pending",
        @"platform": @"ios",
        @"createdAt": [FIRFieldValue fieldValueForServerTimestamp],
        @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
    };
    FIRDocumentReference *reportReference =
        [[[FIRFirestore firestore] collectionWithPath:@"reports"]
            documentWithPath:reportID];
    [PPHUD showLoading:kLang(@"Loading")];
    [[FIRFirestore firestore]
        runTransactionWithBlock:^id _Nullable(
            FIRTransaction * _Nonnull transaction,
            NSError * _Nullable __autoreleasing * _Nullable errorPointer
        ) {
            FIRDocumentSnapshot *snapshot =
                [transaction getDocument:reportReference error:errorPointer];
            if (!snapshot || (errorPointer && *errorPointer)) {
                return nil;
            }
            if (snapshot.exists) {
                // A report ID is deterministic per content/reporter. Never
                // reopen a resolved case or rewrite its original timestamp.
                return @NO;
            }
            [transaction setData:reportData forDocument:reportReference];
            return @YES;
        }
        completion:^(__unused id _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [PPHUD dismiss];
            if (error) {
                [PPHUD showError:kLang(@"report_submit_failed_message")];
                return;
            }
            [PPHUD showSuccess:kLang(@"reported_successfully")];
        });
    }];
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
    [self.presentingViewController pp_applyBottomSurfaceAnimated:YES];
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
