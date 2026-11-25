//
//  PPStoreBranchInventoryManager.h
//  Pure Pets
//
//  Single source of truth for branch-level live inventory (branchInventory) in Pure Pets iOS.
//  Subscribes to Firestore `branchInventory` collection for the active consumer store branch
//  governed by PPStoreBranchManager (AppConfigCol/ConsumerStockConfig).
//
//  Provides real-time stock updates across all catalog kinds:
//  - Accessories (AccessTypeAccessory)
//  - Food (AccessTypeFood)
//  - Live Pets (AccessTypeLivePet)
//  - Medicines (AccessTypePetMedicine)
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const PPStoreBranchInventoryDidUpdateNotification;

@interface PPStoreBranchInventoryRecord : NSObject

@property (nonatomic, copy, readonly) NSString *recordId;
@property (nonatomic, copy, readonly) NSString *branchId;
@property (nonatomic, copy, readonly) NSString *productId;
@property (nonatomic, assign, readonly) NSInteger quantity;
@property (nonatomic, assign, readonly) NSInteger reservedQuantity;
@property (nonatomic, assign, readonly) NSInteger availableQuantity;
@property (nonatomic, assign, readonly) BOOL noStock;
@property (nonatomic, strong, nullable, readonly) NSNumber *sellingPrice;
@property (nonatomic, strong, nullable, readonly) NSDate *updatedAt;

- (instancetype)initWithDictionary:(NSDictionary *)dict documentId:(NSString *)docId;

@end

@interface PPStoreBranchInventoryManager : NSObject

@property (nonatomic, copy, readonly, nullable) NSString *activeBranchId;
@property (nonatomic, assign, readonly) BOOL isListening;
@property (nonatomic, assign, readonly) BOOL isServerConfirmed;
@property (nonatomic, strong, readonly, nullable) NSDate *lastSyncDate;

+ (instancetype)sharedManager;

- (void)startListening;
- (void)stopListening;

/// Returns available stock for a product in the current active branch.
/// If no record exists for this branch yet, falls back to `fallback`.
- (NSInteger)availableStockForProductId:(NSString *)productId fallback:(NSInteger)fallback;

/// Returns whether a product is out of stock in the current active branch.
- (BOOL)isOutOfStockForProductId:(NSString *)productId fallback:(BOOL)fallback;

/// Returns the branch-specific selling price if configured, or nil.
- (nullable NSNumber *)sellingPriceForProductId:(NSString *)productId;

/// Returns YES if a branch inventory record exists for the given product in the current branch.
- (BOOL)hasInventoryRecordForProductId:(NSString *)productId;

/// Returns the full branch inventory record for a product if available.
- (nullable PPStoreBranchInventoryRecord *)inventoryRecordForProductId:(NSString *)productId;

/// Snapshot dictionary of productId -> NSNumber(availableQuantity) for current branch.
- (NSDictionary<NSString *, NSNumber *> *)availableStockSnapshot;

@end

NS_ASSUME_NONNULL_END
