#import <Foundation/Foundation.h>
#import "PetAd.h"
typedef NS_ENUM(NSInteger, AccessConditions)
{
    AccessConditionsNew = 1,
    AccessConditionsUsed = 2,
    AccessConditionsNone = -1
};

typedef NS_ENUM(NSInteger, AccessKindType)
{
    AccessTypeAccessory = 1,
    AccessTypeFood = 2,
    AccessTypeLivePet = 3,
    AccessTypePetMedicine = 4
};

NS_ASSUME_NONNULL_BEGIN

@interface PetAccessory : NSObject
@property (nonatomic, copy)   NSString *blurHash;

// Search-normalized title for Arabic/English safe queries
@property (nonatomic, readonly) NSString *searchTitle;
+ (instancetype)deepCopyFrom:(PetAccessory *)source;

@property (nonatomic, strong) NSString *accessoryID;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *desc;
@property (nonatomic, strong) NSNumber *price;                     // Base/original price
@property (nonatomic, strong, nullable) NSNumber *discountPercent;  // % discount (0–100)
@property (nonatomic, strong, nullable) NSNumber *discountAmount;   // Absolute discount (e.g. 15.0)
@property (nonatomic, readonly) NSNumber *finalPrice;               // Auto-calculated final price
@property (nonatomic, copy, nullable) NSString *weightText;          // Display-ready package weight, e.g. "2 kg"
@property (nonatomic, strong, nullable) NSNumber *weight;            // Numeric package weight when stored separately
@property (nonatomic, copy, nullable) NSString *weightUnit;          // Unit for numeric package weight
@property (nonatomic, copy, nullable) NSString *size;                // Item size (e.g. "XS", "S", "M", "L", "XL", "Free Size")

@property (nonatomic, strong) NSArray<NSString *> *imageURLsArray;
@property (nonatomic, copy, nullable) NSArray<NSDictionary *> *imageMeta;
@property (nonatomic, copy, readonly)  NSArray<PetImageItem *> *imageItems;


@property (nonatomic, assign) NSInteger petMainCategoryID;
@property (nonatomic, assign) NSInteger petSubCategoryID;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *petMainCategoryIDs;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *petSubCategoryIDs;
@property (nonatomic, assign) BOOL isAllCategories;
@property (nonatomic, assign) BOOL isAllSubCategories;
@property (nonatomic, copy, nullable) NSString *AccessoryCategoryID;
@property (nonatomic, assign) NSInteger cityID;

- (BOOL)matchesMainCategoryID:(NSInteger)categoryID;
- (BOOL)matchesSubCategoryID:(NSInteger)subCategoryID;

@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, strong, nullable) NSDate *expiryDate;
@property (nonatomic, strong) NSString *ownerID;
@property (nonatomic, strong, nullable) NSString *ownerType;
@property (nonatomic, strong, nullable) NSString *source;
@property (nonatomic, assign) AccessKindType accessKindType;
@property (nonatomic, assign) AccessConditions condition;
@property (nonatomic, assign) NSInteger quantity; // how many in stock

/// F-22 — the server's authoritative unavailability flag.
///
/// This model previously parsed only `quantity`, so **every** availability decision
/// in the app was client-derived: `noStock` appeared in exactly two files out of the
/// whole iOS repo. A product the server had explicitly flagged unavailable stayed
/// purchasable wherever the two signals disagreed.
///
/// Read straight from Firestore; never computed on the client.
@property (nonatomic, assign) BOOL serverMarkedNoStock;

/// The single availability predicate. Either signal saying "unavailable" wins, and
/// lifecycle flags (`isBlocked`/`isDeleted`/`isDisabled`) are included so callers
/// cannot accidentally check stock while ignoring a withdrawn product.
///
/// Prefer this over comparing `quantity` directly.
@property (nonatomic, assign, readonly) BOOL isOutOfStock;
@property (nonatomic, assign, readonly) BOOL isPurchasable;

- (NSString *)stockStatusText;
@property (nonatomic, assign) BOOL isNew;
@property (nonatomic, assign) BOOL hasOffer;
@property (nonatomic, assign) BOOL showInAppMarket;
@property (nonatomic, assign) BOOL isBlocked;
@property (nonatomic, assign) BOOL isDeleted;
@property (nonatomic, assign) BOOL isDisabled;

/// Identifier of the `ProductFamilies` document that groups this product with its
/// sibling colours, or `nil` when the product is standalone.
///
/// Server-owned: written only by the `upsertProductVariantFamily` callable, which is
/// staff-only. The client reads it to decide whether a colour rail applies at all,
/// which is why absence must mean "standalone" rather than a default value.
///
/// Deliberately **not** serialized by `toFirestoreDictionary` — the consumer app
/// never writes it, and emitting it would let a merge write clobber server state.
@property (nonatomic, copy, nullable) NSString *productFamilyId;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *selectedOptions;
@property (nonatomic, copy, nullable) NSString *variantCombinationKey;
@property (nonatomic, copy, nullable) NSString *sellableUnitId;
@property (nonatomic, assign) BOOL isVariant;
@property (nonatomic, assign) BOOL isDefaultVariant;
@property (nonatomic, assign) BOOL variantIsArchived;
@property (nonatomic, assign) NSInteger variantSortOrder;

/// Line-identity fields the server already writes on catalogue and order-line
/// documents, but which this model never declared — so `CartItem.m:76-98` read
/// five properties that did not exist and the target did not compile.
///
/// Read-only projections of server state, like the variant fields above:
/// deliberately not serialized by `toFirestoreDictionary`, because the consumer
/// app must never author them.
///
/// `variantId` is the server's alias for `sellableUnitId` on an order line;
/// `colorID`/`colorName` arrive as `variantColorId`/`variantColorName` from the
/// variant snapshot and as `colorID`/`colorName` on legacy catalogue documents,
/// so both spellings are accepted.
@property (nonatomic, copy, nullable) NSString *variantId;
@property (nonatomic, copy, nullable) NSString *colorID;
@property (nonatomic, copy, nullable) NSString *colorName;
@property (nonatomic, copy, nullable) NSString *sku;
@property (nonatomic, copy, nullable) NSString *barcode;

#pragma mark - Phase 11 Marketplace Aggregations & Facets

@property (nonatomic, strong, nullable) NSNumber *minPrice;
@property (nonatomic, strong, nullable) NSNumber *maxPrice;
@property (nonatomic, assign) BOOL hasVariablePrice;
@property (nonatomic, assign) NSInteger totalAvailableStock;
@property (nonatomic, assign) BOOL hasInStockVariants;
@property (nonatomic, strong, nullable) NSArray<NSString *> *availableColors;
@property (nonatomic, strong, nullable) NSArray<NSString *> *availableSizes;
@property (nonatomic, strong, nullable) NSArray<NSString *> *searchTokens;
@property (nonatomic, assign) NSInteger colorCount;
@property (nonatomic, assign) NSInteger variantCount;

- (NSInteger)distinctColorCount;

// Computed type helpers
@property (nonatomic, readonly) BOOL isLivePet;
@property (nonatomic, readonly) BOOL isFood;
@property (nonatomic, readonly) BOOL isPetMedicine;

// Firestore helpers
- (instancetype)initWithDictionary:(NSDictionary *)dict documentID:(NSString *)docID;
- (NSDictionary *)toFirestoreDictionary;

// Business logic helpers
- (NSNumber *)calculateFinalPrice;





+ (nullable NSURL *)firstImageURLForAccessory:(PetAccessory *)accessory;
+ (NSString *)typeTextForAccessory:(PetAccessory *)accessory;
+ (NSString *)conditionTextForAccessory:(PetAccessory *)accessory;
+ (NSString *)formatCurrency:(NSNumber *)amount;
+ (NSString *)formattedPrice:(NSNumber *)finalPrice
               originalPrice:(NSNumber *)originalPrice
             discountPercent:(NSNumber *)discountPercent;
+ (NSString *)formattedPriceRangeForAccessory:(PetAccessory *)accessory;
+ (NSString *)shareMessageForAccessory:(PetAccessory *)accessory;
+ (nullable NSURL *)shareableLinkForAccessory:(PetAccessory *)accessory;
+ (void)sharePetAccessory:(PetAccessory *)accessory
       fromViewController:(UIViewController *)vc
               sourceView:(nullable UIView *)sourceView;
+ (void)sharePetAccessory:(PetAccessory *)accessory fromViewController:(UIViewController *)vc;



@end

NS_ASSUME_NONNULL_END
