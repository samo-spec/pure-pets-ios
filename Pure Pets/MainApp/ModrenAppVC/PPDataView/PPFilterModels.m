//
//  PPFilterModels.m
//  Pure Pets
//
//  Data-driven filter architecture implementation.
//

#import "PPFilterModels.h"

// ─── Filter group ID constants ───────────────────────────────────────
NSString * const PPFilterIDCondition   = @"condition";
NSString * const PPFilterIDGender      = @"gender";
NSString * const PPFilterIDServiceType = @"serviceType";
NSString * const PPFilterIDPrice       = @"price";
NSString * const PPFilterIDSort        = @"sort";
NSString * const PPFilterIDHasOffer    = @"hasOffer";

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
    PPFilterOption *o = [[PPFilterOption alloc] init];
    o.title    = title;
    o.value    = value;
    o.iconName = iconName;
    return o;
}

@end

// ═════════════════════════════════════════════════════════════════════
#pragma mark - PPFilterGroup
// ═════════════════════════════════════════════════════════════════════

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
    return self.options.firstObject.value;
}

- (BOOL)isActive
{
    return self.selectedValue != [self defaultValue];
}

- (nullable NSString *)selectedTitle
{
    for (PPFilterOption *o in self.options) {
        if (o.value == self.selectedValue) {
            return o.title;
        }
    }
    return self.options.firstObject.title;
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

    NSMutableArray *opts = [NSMutableArray arrayWithCapacity:self.options.count];
    for (PPFilterOption *o in self.options) {
        PPFilterOption *oc = [PPFilterOption optionWithTitle:o.title value:o.value icon:o.iconName];
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
              title:PPFilterL(@"Gender", @"الجنس")
           chipIcon:@"figure.2"
            options:@[
                [PPFilterOption optionWithTitle:PPFilterL(@"All", @"الكل") value:PPFilterGenderAll],
                [PPFilterOption optionWithTitle:PPFilterL(@"Male", @"ذكر") value:PPFilterGenderMale icon:@"figure.stand"],
                [PPFilterOption optionWithTitle:PPFilterL(@"Female", @"انثى") value:PPFilterGenderFemale icon:@"figure.stand.dress"],
            ]];

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
                [PPFilterOption optionWithTitle:PPFilterL(@"Price low to high", @"السعر من الاقل للاعلى") value:PPFilterSortPriceLowToHigh],
                [PPFilterOption optionWithTitle:PPFilterL(@"Price high to low", @"السعر من الاعلى للاقل") value:PPFilterSortPriceHighToLow],
                [PPFilterOption optionWithTitle:PPFilterL(@"Newest", @"الاحدث") value:PPFilterSortNewest],
            ]];

    return [PPFilterState stateWithGroups:@[gender, price, sort]];
}

#pragma mark — Accessories

+ (PPFilterState *)pp_accessoriesFilterState
{
    PPFilterGroup *condition = [PPFilterGroup
        groupWithID:PPFilterIDCondition
              title:PPFilterL(@"Condition", @"الحالة")
           chipIcon:@"checkmark.seal"
            options:@[
                [PPFilterOption optionWithTitle:PPFilterL(@"All", @"الكل") value:PPFilterAccessoryAll],
                [PPFilterOption optionWithTitle:PPFilterL(@"New", @"جديد") value:PPFilterAccessoryNew],
                [PPFilterOption optionWithTitle:PPFilterL(@"Used", @"مستعمل") value:PPFilterAccessoryUsed],
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
                [PPFilterOption optionWithTitle:PPFilterL(@"Price low to high", @"السعر من الاقل للاعلى") value:PPFilterSortPriceLowToHigh],
                [PPFilterOption optionWithTitle:PPFilterL(@"Price high to low", @"السعر من الاعلى للاقل") value:PPFilterSortPriceHighToLow],
                [PPFilterOption optionWithTitle:PPFilterL(@"Name A-Z", @"الاسم من الالف للياء") value:PPFilterSortNameAZ],
            ]];

    return [PPFilterState stateWithGroups:@[condition, price, sort]];
}

#pragma mark — Food

+ (PPFilterState *)pp_foodFilterState
{
    PPFilterGroup *condition = [PPFilterGroup
        groupWithID:PPFilterIDCondition
              title:PPFilterL(@"Condition", @"الحالة")
           chipIcon:@"checkmark.seal"
            options:@[
                [PPFilterOption optionWithTitle:PPFilterL(@"All", @"الكل") value:PPFilterAccessoryAll],
                [PPFilterOption optionWithTitle:PPFilterL(@"New", @"جديد") value:PPFilterAccessoryNew],
                [PPFilterOption optionWithTitle:PPFilterL(@"Used", @"مستعمل") value:PPFilterAccessoryUsed],
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
                [PPFilterOption optionWithTitle:PPFilterL(@"Price low to high", @"السعر من الاقل للاعلى") value:PPFilterSortPriceLowToHigh],
                [PPFilterOption optionWithTitle:PPFilterL(@"Price high to low", @"السعر من الاعلى للاقل") value:PPFilterSortPriceHighToLow],
                [PPFilterOption optionWithTitle:PPFilterL(@"Name A-Z", @"الاسم من الالف للياء") value:PPFilterSortNameAZ],
            ]];

    return [PPFilterState stateWithGroups:@[condition, price, sort]];
}

#pragma mark — Services

+ (PPFilterState *)pp_servicesFilterState
{
    PPFilterGroup *type = [PPFilterGroup
        groupWithID:PPFilterIDServiceType
              title:PPFilterL(@"Type", @"النوع")
           chipIcon:@"list.bullet"
            options:@[
                [PPFilterOption optionWithTitle:PPFilterL(@"All", @"الكل") value:PPFilterServiceAll],
                [PPFilterOption optionWithTitle:PPFilterL(@"Training", @"تدريب") value:PPFilterServiceTraining],
                [PPFilterOption optionWithTitle:PPFilterL(@"Grooming", @"عناية") value:PPFilterServiceGrooming],
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

    PPFilterGroup *sort = [PPFilterGroup
        groupWithID:PPFilterIDSort
              title:PPFilterL(@"Sort", @"الترتيب")
           chipIcon:@"arrow.up.arrow.down"
            options:@[
                [PPFilterOption optionWithTitle:PPFilterL(@"Recommended", @"الافتراضي") value:PPFilterSortRecommended],
                [PPFilterOption optionWithTitle:PPFilterL(@"Price low to high", @"السعر من الاقل للاعلى") value:PPFilterSortPriceLowToHigh],
                [PPFilterOption optionWithTitle:PPFilterL(@"Price high to low", @"السعر من الاعلى للاقل") value:PPFilterSortPriceHighToLow],
                [PPFilterOption optionWithTitle:PPFilterL(@"Newest", @"الاحدث") value:PPFilterSortNewest],
            ]];

    return [PPFilterState stateWithGroups:@[type, price, sort]];
}

@end
