//
//  PPFilterModels.m
//  Pure Pets
//
//  Data-driven filter architecture implementation.
//

#import "PPFilterModels.h"
#import "MainKindsModel.h"

// ─── Filter group ID constants ───────────────────────────────────────
NSString * const PPFilterIDCondition   = @"condition";
NSString * const PPFilterIDAccessoryCategory = @"accessoryCategory";
NSString * const PPFilterIDGender      = @"gender";
NSString * const PPFilterIDServiceType = @"serviceType";
NSString * const PPFilterIDPrice       = @"price";
NSString * const PPFilterIDSort        = @"sort";
NSString * const PPFilterIDHasOffer    = @"hasOffer";
NSString * const PPFilterIDAvailability = @"availability";

static NSString *PPFilterL(NSString *english, NSString *arabic) {
    return Language.isRTL ? arabic : english;
}

// ═════════════════════════════════════════════════════════════════════
#pragma mark - PPFilterOption
// ═════════════════════════════════════════════════════════════════════

@implementation PPFilterOption

+ (instancetype)optionWithTitle:(NSString *)title value:(NSInteger)value
{
    return [self optionWithTitle:title value:value icon:nil];
}

+ (instancetype)optionWithTitle:(NSString *)title value:(NSInteger)value icon:(nullable NSString *)iconName
{
    return [self optionWithTitle:title value:value identifierValue:nil icon:iconName];
}

+ (instancetype)optionWithTitle:(NSString *)title
                          value:(NSInteger)value
                identifierValue:(nullable NSString *)identifierValue
                           icon:(nullable NSString *)iconName
{
    PPFilterOption *o = [[PPFilterOption alloc] init];
    o.title    = title;
    o.value    = value;
    o.iconName = iconName;
    o.identifierValue = identifierValue;
    return o;
}

@end

// ═════════════════════════════════════════════════════════════════════
#pragma mark - PPFilterGroup
// ═════════════════════════════════════════════════════════════════════

@interface PPFilterGroup ()
@property (nonatomic, assign) BOOL pp_hasDefaultValueOverride;
@property (nonatomic, assign) NSInteger pp_defaultValueOverride;
- (void)pp_setDefaultSelectedValue:(NSInteger)defaultValue;
@end

@implementation PPFilterGroup

+ (instancetype)groupWithID:(NSString *)filterID
                      title:(NSString *)title
                   chipIcon:(nullable NSString *)icon
                    options:(NSArray<PPFilterOption *> *)options
{
    PPFilterGroup *g = [[PPFilterGroup alloc] init];
    g.filterID     = filterID;
    g.title        = title;
    g.chipIconName = icon;
    g.options      = options;
    g.selectedValue = options.firstObject.value;
    return g;
}

- (NSInteger)defaultValue
{
    if (self.pp_hasDefaultValueOverride) {
        return self.pp_defaultValueOverride;
    }
    return self.options.firstObject.value;
}

- (void)pp_setDefaultSelectedValue:(NSInteger)defaultValue
{
    self.pp_hasDefaultValueOverride = YES;
    self.pp_defaultValueOverride = defaultValue;
    self.selectedValue = defaultValue;
}

- (BOOL)isActive
{
    return self.selectedValue != [self defaultValue];
}

- (nullable NSString *)selectedTitle
{
    PPFilterOption *selected = [self selectedOption];
    if (selected) {
        return selected.title;
    }
    if (self.selectedValue == [self defaultValue]) {
        return self.title;
    }
    return self.options.firstObject.title;
}

- (nullable PPFilterOption *)selectedOption
{
    for (PPFilterOption *o in self.options) {
        if (o.value == self.selectedValue) {
            return o;
        }
    }
    return nil;
}

- (void)reset
{
    self.selectedValue = [self defaultValue];
}

- (id)copyWithZone:(NSZone *)zone
{
    PPFilterGroup *copy = [[PPFilterGroup allocWithZone:zone] init];
    copy.filterID      = self.filterID;
    copy.title         = self.title;
    copy.chipIconName  = self.chipIconName;
    copy.selectedValue = self.selectedValue;
    copy.pp_hasDefaultValueOverride = self.pp_hasDefaultValueOverride;
    copy.pp_defaultValueOverride = self.pp_defaultValueOverride;

    NSMutableArray *opts = [NSMutableArray arrayWithCapacity:self.options.count];
    for (PPFilterOption *o in self.options) {
        PPFilterOption *oc = [PPFilterOption optionWithTitle:o.title
                                                       value:o.value
                                             identifierValue:o.identifierValue
                                                        icon:o.iconName];
        [opts addObject:oc];
    }
    copy.options = opts;
    return copy;
}

@end

// ═════════════════════════════════════════════════════════════════════
#pragma mark - PPFilterState
// ═════════════════════════════════════════════════════════════════════

@implementation PPFilterState

+ (instancetype)stateWithGroups:(NSArray<PPFilterGroup *> *)groups
{
    PPFilterState *s = [[PPFilterState alloc] init];
    s.groups = groups;
    return s;
}

- (nullable PPFilterGroup *)groupForID:(NSString *)filterID
{
    for (PPFilterGroup *g in self.groups) {
        if ([g.filterID isEqualToString:filterID]) {
            return g;
        }
    }
    return nil;
}

- (NSInteger)valueForFilterID:(NSString *)filterID
{
    PPFilterGroup *g = [self groupForID:filterID];
    return g ? g.selectedValue : 0;
}

- (BOOL)hasActiveFilters
{
    for (PPFilterGroup *g in self.groups) {
        if (g.isActive) return YES;
    }
    return NO;
}

- (NSInteger)activeFilterCount
{
    NSInteger c = 0;
    for (PPFilterGroup *g in self.groups) {
        if (g.isActive) c++;
    }
    return c;
}

- (void)resetAll
{
    for (PPFilterGroup *g in self.groups) {
        [g reset];
    }
}

- (id)copyWithZone:(NSZone *)zone
{
    NSMutableArray *groupsCopy = [NSMutableArray arrayWithCapacity:self.groups.count];
    for (PPFilterGroup *g in self.groups) {
        [groupsCopy addObject:[g copy]];
    }
    return [PPFilterState stateWithGroups:groupsCopy];
}

@end

// ═════════════════════════════════════════════════════════════════════
#pragma mark - PPFilterConfigProvider
// ═════════════════════════════════════════════════════════════════════

@implementation PPFilterConfigProvider

+ (PPFilterState *)defaultFilterStateForSection:(PPDataSection)section
{
    switch (section) {
        case PPDataSectionAds:
            return [self pp_adsFilterState];
        case PPDataSectionAccessories:
            return [self pp_accessoriesFilterState];
        case PPDataSectionFood:
            return [self pp_foodFilterState];
        case PPDataSectionServices:
            return [self pp_servicesFilterState];
        default:
            return [PPFilterState stateWithGroups:@[]];
    }
}

#pragma mark — Ads

+ (PPFilterState *)pp_adsFilterState
{
    PPFilterGroup *gender = [PPFilterGroup
        groupWithID:PPFilterIDGender
              title:kLang(@"Gender")
           chipIcon:@"gender"
            options:@[
                [PPFilterOption optionWithTitle:kLang(@"all") value:PPFilterGenderAll icon:nil],
                [PPFilterOption optionWithTitle:kLang(@"Male") value:PPFilterGenderMale icon:@"male"],
                [PPFilterOption optionWithTitle:kLang(@"Female") value:PPFilterGenderFemale icon:@"female"],
                [PPFilterOption optionWithTitle:kLang(@"no_value") value:PPFilterGenderUndefined icon:@"gender"],
            ]];
    [gender pp_setDefaultSelectedValue:PPFilterGenderAll];

    PPFilterGroup *price = [PPFilterGroup
        groupWithID:PPFilterIDPrice
              title:PPFilterL(@"Price", @"السعر")
           chipIcon:@"tag"
            options:@[
                [PPFilterOption optionWithTitle:PPFilterL(@"All prices", @"كل الاسعار") value:PPFilterPriceAll],
                [PPFilterOption optionWithTitle:PPFilterL(@"Under 500", @"اقل من 500") value:PPFilterPriceTier1],
                [PPFilterOption optionWithTitle:@"500 - 2000" value:PPFilterPriceTier2],
                [PPFilterOption optionWithTitle:PPFilterL(@"2000+", @"2000+") value:PPFilterPriceTier3],
            ]];

    PPFilterGroup *sort = [PPFilterGroup
        groupWithID:PPFilterIDSort
              title:PPFilterL(@"Sort", @"الترتيب")
           chipIcon:@"arrow.up.arrow.down"
            options:@[
                [PPFilterOption optionWithTitle:PPFilterL(@"Recommended", @"الافتراضي") value:PPFilterSortRecommended],
                [PPFilterOption optionWithTitle:PPFilterL(@"Low to high", @"الاقل للاعلى") value:PPFilterSortPriceLowToHigh],
                [PPFilterOption optionWithTitle:PPFilterL(@"High to low", @"الاعلى للاقل") value:PPFilterSortPriceHighToLow],
                [PPFilterOption optionWithTitle:PPFilterL(@"Newest", @"الاحدث") value:PPFilterSortNewest],
            ]];

    return [PPFilterState stateWithGroups:@[gender, price, sort]];
}

#pragma mark — Accessories

+ (PPFilterState *)pp_accessoriesFilterState
{
    return [self accessoriesFilterStateWithCategories:@[]];
}

+ (PPFilterState *)accessoriesFilterStateWithCategories:(NSArray<PPAccessoryCategoryModel *> *)categories
{
    NSMutableArray<PPFilterOption *> *categoryOptions = [NSMutableArray array];
    [categoryOptions addObject:[PPFilterOption optionWithTitle:PPFilterL(@"All categories", @"كل التصنيفات")
                                                         value:0
                                                           icon:@"square.grid.2x2"]];

    NSMutableSet<NSString *> *usedCategoryIDs = [NSMutableSet set];
    NSInteger nextValue = 1;
    for (PPAccessoryCategoryModel *category in categories ?: @[]) {
        if (![category isKindOfClass:PPAccessoryCategoryModel.class] || !category.enabled) {
            continue;
        }
        NSString *categoryID = category.categoryID.length > 0 ? category.categoryID : category.documentID;
        if (categoryID.length == 0 || [usedCategoryIDs containsObject:categoryID]) {
            continue;
        }
        [usedCategoryIDs addObject:categoryID];
        [categoryOptions addObject:[PPFilterOption optionWithTitle:[category displayName]
                                                             value:nextValue
                                                   identifierValue:categoryID
                                                              icon:@"tag"]];
        nextValue += 1;
    }

    PPFilterGroup *category = [PPFilterGroup
        groupWithID:PPFilterIDAccessoryCategory
              title:PPFilterL(@"Accessory Category", @"تصنيف المستلزمات")
           chipIcon:@"square.grid.2x2"
            options:categoryOptions.copy];

    PPFilterGroup *sort = [PPFilterGroup
        groupWithID:PPFilterIDSort
              title:PPFilterL(@"Sort", @"الترتيب")
           chipIcon:@"arrow.up.arrow.down"
            options:@[
                [PPFilterOption optionWithTitle:PPFilterL(@"Recommended", @"الافتراضي") value:PPFilterSortRecommended],
                [PPFilterOption optionWithTitle:PPFilterL(@"Low to high", @"الاقل للاعلى") value:PPFilterSortPriceLowToHigh],
                [PPFilterOption optionWithTitle:PPFilterL(@"High to low", @"الاعلى للاقل") value:PPFilterSortPriceHighToLow],
                [PPFilterOption optionWithTitle:PPFilterL(@"Name A-Z", @"الاسم من الالف للياء") value:PPFilterSortNameAZ],
            ]];

    return [PPFilterState stateWithGroups:@[category, sort]];
}

#pragma mark — Food

+ (PPFilterState *)pp_foodFilterState
{
    PPFilterGroup *offer = [PPFilterGroup
        groupWithID:PPFilterIDHasOffer
              title:PPFilterL(@"Offers", @"العروض")
           chipIcon:@"percent"
            options:@[
                [PPFilterOption optionWithTitle:PPFilterL(@"All", @"الكل") value:PPFilterHasOfferAll],
                [PPFilterOption optionWithTitle:PPFilterL(@"On Sale", @"عروض فقط") value:PPFilterHasOfferYes icon:@"flame.fill"],
            ]];

    PPFilterGroup *price = [PPFilterGroup
        groupWithID:PPFilterIDPrice
              title:PPFilterL(@"Price", @"السعر")
           chipIcon:@"tag"
            options:@[
                [PPFilterOption optionWithTitle:PPFilterL(@"All prices", @"كل الاسعار") value:PPFilterPriceAll],
                [PPFilterOption optionWithTitle:PPFilterL(@"Under 250", @"اقل من 250") value:PPFilterPriceTier1],
                [PPFilterOption optionWithTitle:@"250 - 750" value:PPFilterPriceTier2],
                [PPFilterOption optionWithTitle:PPFilterL(@"750+", @"750+") value:PPFilterPriceTier3],
            ]];

    PPFilterGroup *sort = [PPFilterGroup
        groupWithID:PPFilterIDSort
              title:PPFilterL(@"Sort", @"الترتيب")
           chipIcon:@"arrow.up.arrow.down"
            options:@[
                [PPFilterOption optionWithTitle:PPFilterL(@"Recommended", @"الافتراضي") value:PPFilterSortRecommended],
                [PPFilterOption optionWithTitle:PPFilterL(@"Low to high", @"الاقل للاعلى") value:PPFilterSortPriceLowToHigh],
                [PPFilterOption optionWithTitle:PPFilterL(@"High to low", @"الاعلى للاقل") value:PPFilterSortPriceHighToLow],
                [PPFilterOption optionWithTitle:PPFilterL(@"Name A-Z", @"من الالف للياء") value:PPFilterSortNameAZ],
            ]];

    return [PPFilterState stateWithGroups:@[offer, price, sort]];
}

#pragma mark — Services

+ (PPFilterState *)pp_servicesFilterState
{
    PPFilterGroup *type = [PPFilterGroup
        groupWithID:PPFilterIDServiceType
              title:kLang(@"dataview_filter_service_badge")
           chipIcon:@"list.bullet"
            options:@[
                [PPFilterOption optionWithTitle:PPFilterL(@"All", @"الكل") value:PPFilterServiceAll],
                [PPFilterOption optionWithTitle:PPFilterL(@"Training", @"تدريب") value:PPFilterServiceTraining icon:@"figure.run"],
                [PPFilterOption optionWithTitle:PPFilterL(@"Grooming", @"عناية") value:PPFilterServiceGrooming icon:@"scissors"],
                [PPFilterOption optionWithTitle:PPFilterL(@"Walking", @"تمشية") value:PPFilterServiceWalking icon:@"figure.walk"],
            ]];

    PPFilterGroup *availability = [PPFilterGroup
        groupWithID:PPFilterIDAvailability
              title:kLang(@"dataview_filter_service_when_badge")
           chipIcon:@"calendar.badge.clock"
            options:@[
                [PPFilterOption optionWithTitle:PPFilterL(@"All", @"الكل") value:PPFilterAvailabilityAll],
                [PPFilterOption optionWithTitle:PPFilterL(@"Available Now", @"متوفر الآن") value:PPFilterAvailabilityNow icon:@"checkmark.circle.fill"],
                [PPFilterOption optionWithTitle:PPFilterL(@"Upcoming", @"قادم") value:PPFilterAvailabilityUpcoming icon:@"clock.arrow.circlepath"],
            ]];

    PPFilterGroup *price = [PPFilterGroup
        groupWithID:PPFilterIDPrice
              title:PPFilterL(@"Price", @"السعر")
           chipIcon:@"tag"
            options:@[
                [PPFilterOption optionWithTitle:PPFilterL(@"All prices", @"كل الاسعار") value:PPFilterPriceAll],
                [PPFilterOption optionWithTitle:PPFilterL(@"Under 100", @"اقل من 100") value:PPFilterPriceTier1],
                [PPFilterOption optionWithTitle:@"100 - 500" value:PPFilterPriceTier2],
                [PPFilterOption optionWithTitle:PPFilterL(@"500+", @"500+") value:PPFilterPriceTier3],
            ]];

    return [PPFilterState stateWithGroups:@[type, availability, price]];
}

@end
