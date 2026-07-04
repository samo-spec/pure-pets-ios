//
//  PPFilterModels.h
//  Pure Pets
//
//  Data-driven filter architecture for PPDataViewVC.
//  Each section (Ads, Accessories, Food, Services) gets its own PPFilterState
//  built from PPFilterGroups. The UI (chips, sheet) is generated from this config.
//

#import <Foundation/Foundation.h>
#import "EnumValues.h"

NS_ASSUME_NONNULL_BEGIN

@class PPAccessoryCategoryModel;

// ─── Filter group identifiers ────────────────────────────────────────
extern NSString * const PPFilterIDCondition;   // New / Used
extern NSString * const PPFilterIDAccessoryCategory; // AccessoryCategoryID
extern NSString * const PPFilterIDGender;      // Male / Female
extern NSString * const PPFilterIDServiceType; // Training / Grooming / Walking
extern NSString * const PPFilterIDPrice;       // Price range tiers
extern NSString * const PPFilterIDSort;        // Sort order
extern NSString * const PPFilterIDHasOffer;    // Has Offer (Accessories/Food)
extern NSString * const PPFilterIDAvailability; // Available Now / Upcoming (Services)

// ─── Generic enum values used across sections ────────────────────────

typedef NS_ENUM(NSInteger, PPFilterPriceRange) {
    PPFilterPriceAll = 0,
    PPFilterPriceTier1,
    PPFilterPriceTier2,
    PPFilterPriceTier3,
};

typedef NS_ENUM(NSInteger, PPFilterSortOrder) {
    PPFilterSortRecommended = 0,
    PPFilterSortPriceLowToHigh,
    PPFilterSortPriceHighToLow,
    PPFilterSortNameAZ,
    PPFilterSortNewest,
};

typedef NS_ENUM(NSInteger, PPFilterGender) {
    PPFilterGenderAll = 0,
    PPFilterGenderMale,
    PPFilterGenderFemale,
};

typedef NS_ENUM(NSInteger, PPFilterHasOffer) {
    PPFilterHasOfferAll = 0,
    PPFilterHasOfferYes,
};

typedef NS_ENUM(NSInteger, PPFilterAvailability) {
    PPFilterAvailabilityAll = 0,
    PPFilterAvailabilityNow,
    PPFilterAvailabilityUpcoming,
};

// ─── PPFilterOption ──────────────────────────────────────────────────

@interface PPFilterOption : NSObject
@property (nonatomic, copy)   NSString *title;
@property (nonatomic, assign) NSInteger value;
@property (nonatomic, copy, nullable) NSString *iconName;
@property (nonatomic, copy, nullable) NSString *identifierValue;

+ (instancetype)optionWithTitle:(NSString *)title value:(NSInteger)value;
+ (instancetype)optionWithTitle:(NSString *)title value:(NSInteger)value icon:(nullable NSString *)iconName;
+ (instancetype)optionWithTitle:(NSString *)title
                          value:(NSInteger)value
                identifierValue:(nullable NSString *)identifierValue
                           icon:(nullable NSString *)iconName;
@end

// ─── PPFilterGroup ───────────────────────────────────────────────────

@interface PPFilterGroup : NSObject <NSCopying>
@property (nonatomic, copy)   NSString *filterID;
@property (nonatomic, copy)   NSString *title;
@property (nonatomic, copy, nullable) NSString *chipIconName;
@property (nonatomic, copy)   NSArray<PPFilterOption *> *options;
@property (nonatomic, assign) NSInteger selectedValue;

- (NSInteger)defaultValue;
- (BOOL)isActive;
- (nullable NSString *)selectedTitle;
- (nullable PPFilterOption *)selectedOption;
- (void)reset;

+ (instancetype)groupWithID:(NSString *)filterID
                      title:(NSString *)title
                   chipIcon:(nullable NSString *)icon
                    options:(NSArray<PPFilterOption *> *)options;
@end

// ─── PPFilterState ───────────────────────────────────────────────────

@interface PPFilterState : NSObject <NSCopying>
@property (nonatomic, copy) NSArray<PPFilterGroup *> *groups;

- (nullable PPFilterGroup *)groupForID:(NSString *)filterID;
- (NSInteger)valueForFilterID:(NSString *)filterID;
- (BOOL)hasActiveFilters;
- (NSInteger)activeFilterCount;
- (void)resetAll;

+ (instancetype)stateWithGroups:(NSArray<PPFilterGroup *> *)groups;
@end

// ─── PPFilterConfigProvider ──────────────────────────────────────────
// Factory that generates the default PPFilterState for each PPDataSection.

@interface PPFilterConfigProvider : NSObject
+ (PPFilterState *)defaultFilterStateForSection:(PPDataSection)section;
+ (PPFilterState *)accessoriesFilterStateWithCategories:(NSArray<PPAccessoryCategoryModel *> *)categories;
@end

NS_ASSUME_NONNULL_END
