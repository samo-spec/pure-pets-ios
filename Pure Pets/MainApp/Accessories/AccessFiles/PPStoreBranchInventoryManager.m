//
//  PPStoreBranchInventoryManager.m
//  Pure Pets
//
//  Single source of truth for branch-level live inventory (branchInventory) in Pure Pets iOS.
//

#import "PPStoreBranchInventoryManager.h"
#import "PPStoreBranchManager.h"
#import <FirebaseFirestore/FirebaseFirestore.h>

NSString * const PPStoreBranchInventoryDidUpdateNotification = @"PPStoreBranchInventoryDidUpdateNotification";

@implementation PPStoreBranchInventoryRecord

- (instancetype)initWithDictionary:(NSDictionary *)dict documentId:(NSString *)docId {
    self = [super init];
    if (self) {
        _recordId = [docId copy] ?: @"";
        _branchId = [dict[@"branchId"] isKindOfClass:[NSString class]] ? [dict[@"branchId"] copy] : @"";
        _productId = [dict[@"productId"] isKindOfClass:[NSString class]] ? [dict[@"productId"] copy] : @"";
        
        id rawQty = dict[@"quantity"];
        _quantity = [rawQty respondsToSelector:@selector(integerValue)] ? [rawQty integerValue] : 0;
        
        id rawReserved = dict[@"reservedQuantity"];
        _reservedQuantity = [rawReserved respondsToSelector:@selector(integerValue)] ? [rawReserved integerValue] : 0;
        
        id rawAvailable = dict[@"availableQuantity"];
        if ([rawAvailable respondsToSelector:@selector(integerValue)]) {
            _availableQuantity = [rawAvailable integerValue];
        } else {
            _availableQuantity = MAX(0, _quantity - _reservedQuantity);
        }
        
        id rawNoStock = dict[@"noStock"];
        if ([rawNoStock respondsToSelector:@selector(boolValue)]) {
            _noStock = [rawNoStock boolValue];
        } else {
            _noStock = (_availableQuantity <= 0);
        }
        
        id rawPrice = dict[@"sellingPrice"];
        if ([rawPrice respondsToSelector:@selector(doubleValue)] && [rawPrice doubleValue] > 0.0) {
            _sellingPrice = @([rawPrice doubleValue]);
        } else {
            _sellingPrice = nil;
        }
        
        id ts = dict[@"updatedAt"];
        if ([ts isKindOfClass:[FIRTimestamp class]]) {
            _updatedAt = [(FIRTimestamp *)ts dateValue];
        } else if ([ts isKindOfClass:[NSDate class]]) {
            _updatedAt = (NSDate *)ts;
        } else {
            _updatedAt = nil;
        }
    }
    return self;
}

@end

@interface PPStoreBranchInventoryManager ()

@property (nonatomic, copy, readwrite, nullable) NSString *activeBranchId;
@property (nonatomic, assign, readwrite) BOOL isListening;
@property (nonatomic, assign, readwrite) BOOL isServerConfirmed;
@property (nonatomic, strong, readwrite, nullable) NSDate *lastSyncDate;
@property (nonatomic, strong) id<FIRListenerRegistration> listenerRegistration;
@property (nonatomic, strong) NSMutableDictionary<NSString *, PPStoreBranchInventoryRecord *> *inventoryMap;
@property (nonatomic, strong) dispatch_queue_t syncQueue;

@end

@implementation PPStoreBranchInventoryManager

+ (instancetype)sharedManager {
    static PPStoreBranchInventoryManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[PPStoreBranchInventoryManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _inventoryMap = [NSMutableDictionary dictionary];
        _syncQueue = dispatch_queue_create("com.purepets.branchInventorySyncQueue", DISPATCH_QUEUE_CONCURRENT);
        _isListening = NO;
        _isServerConfirmed = NO;
        
        // Listen to active consumer branch change from PPStoreBranchManager
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(pp_storeBranchDidChange:)
                                                     name:PPStoreBranchDidChangeNotification
                                                   object:nil];
        
        // Initial bind if branch is already known
        NSString *initialBranchId = [PPStoreBranchManager sharedManager].currentBranchId;
        if (initialBranchId.length > 0) {
            [self bindToBranchId:initialBranchId];
        }
    }
    return self;
}

- (void)startListening {
    NSString *branchId = [PPStoreBranchManager sharedManager].currentBranchId;
    if (branchId.length > 0 && (!self.isListening || ![self.activeBranchId isEqualToString:branchId])) {
        [self bindToBranchId:branchId];
    }
}

- (void)stopListening {
    if (self.listenerRegistration) {
        [self.listenerRegistration remove];
        self.listenerRegistration = nil;
    }
    self.isListening = NO;
}

- (void)pp_storeBranchDidChange:(NSNotification *)notification {
    NSString *newBranchId = notification.userInfo[@"branchId"] ?: [PPStoreBranchManager sharedManager].currentBranchId;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self bindToBranchId:newBranchId];
    });
}

- (void)bindToBranchId:(NSString *)branchId {
    NSString *trimmed = [branchId isKindOfClass:[NSString class]]
        ? [branchId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        : @"";

    if (trimmed.length > 0 && self.isListening && [self.activeBranchId isEqualToString:trimmed]) {
        return;
    }

    if (self.listenerRegistration) {
        [self.listenerRegistration remove];
        self.listenerRegistration = nil;
    }
    
    dispatch_barrier_async(self.syncQueue, ^{
        [self.inventoryMap removeAllObjects];
        self.isServerConfirmed = NO;
        self.lastSyncDate = nil;
    });
    
    if (trimmed.length == 0) {
        self.activeBranchId = nil;
        self.isListening = NO;
        NSLog(@"[PPStoreBranchInventoryManager] No active branch ID -> cleared inventory listener");
        return;
    }
    
    self.activeBranchId = trimmed;
    self.isListening = YES;
    NSLog(@"[PPStoreBranchInventoryManager] Attaching live listener to branchInventory for branch: %@", trimmed);
    
    FIRQuery *query = [[[FIRFirestore firestore] collectionWithPath:@"branchInventory"] queryWhereField:@"branchId" isEqualTo:trimmed];
    
    __weak typeof(self) weakSelf = self;
    self.listenerRegistration = [query addSnapshotListenerWithIncludeMetadataChanges:YES listener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (error != nil) {
            NSLog(@"[PPStoreBranchInventoryManager] branchInventory listen note: %@", error.localizedDescription);
            if (error.code == FIRFirestoreErrorCodePermissionDenied || error.code == FIRFirestoreErrorCodeUnauthenticated) {
                [strongSelf stopListening];
            }
            return;
        }
        
        if (!snapshot) return;
        
        NSMutableDictionary<NSString *, PPStoreBranchInventoryRecord *> *newMap = [NSMutableDictionary dictionaryWithCapacity:snapshot.documents.count];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            PPStoreBranchInventoryRecord *record = [[PPStoreBranchInventoryRecord alloc] initWithDictionary:doc.data documentId:doc.documentID];
            if (record.productId.length > 0) {
                newMap[record.productId] = record;
            }
        }
        
        BOOL serverConfirmed = !snapshot.metadata.isFromCache && !snapshot.metadata.hasPendingWrites;
        
        dispatch_barrier_async(strongSelf.syncQueue, ^{
            strongSelf.inventoryMap = newMap;
            strongSelf.isServerConfirmed = serverConfirmed;
            if (serverConfirmed) {
                strongSelf.lastSyncDate = [NSDate date];
            }
        });
        
        NSLog(@"[PPStoreBranchInventoryManager] Live inventory snapshot received: %lu records for branch %@", (unsigned long)newMap.count, trimmed);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:PPStoreBranchInventoryDidUpdateNotification
                                                                object:strongSelf
                                                              userInfo:@{
                                                                  @"branchId": trimmed,
                                                                  @"recordsCount": @(newMap.count),
                                                                  @"isFromCache": @(snapshot.metadata.isFromCache)
                                                              }];
        });
    }];
}

#pragma mark - Query Methods

- (NSInteger)availableStockForProductId:(NSString *)productId fallback:(NSInteger)fallback {
    if (!productId || productId.length == 0) return fallback;
    
    __block NSInteger result = fallback;
    dispatch_sync(self.syncQueue, ^{
        PPStoreBranchInventoryRecord *rec = self.inventoryMap[productId];
        if (rec) {
            result = MAX(0, rec.availableQuantity);
        }
    });
    return result;
}

- (BOOL)isOutOfStockForProductId:(NSString *)productId fallback:(BOOL)fallback {
    if (!productId || productId.length == 0) return fallback;
    
    __block BOOL result = fallback;
    dispatch_sync(self.syncQueue, ^{
        PPStoreBranchInventoryRecord *rec = self.inventoryMap[productId];
        if (rec) {
            result = rec.noStock || (rec.availableQuantity <= 0);
        }
    });
    return result;
}

- (nullable NSNumber *)sellingPriceForProductId:(NSString *)productId {
    if (!productId || productId.length == 0) return nil;
    
    __block NSNumber *price = nil;
    dispatch_sync(self.syncQueue, ^{
        PPStoreBranchInventoryRecord *rec = self.inventoryMap[productId];
        if (rec) {
            price = rec.sellingPrice;
        }
    });
    return price;
}

- (BOOL)hasInventoryRecordForProductId:(NSString *)productId {
    if (!productId || productId.length == 0) return NO;
    
    __block BOOL exists = NO;
    dispatch_sync(self.syncQueue, ^{
        exists = (self.inventoryMap[productId] != nil);
    });
    return exists;
}

- (nullable PPStoreBranchInventoryRecord *)inventoryRecordForProductId:(NSString *)productId {
    if (!productId || productId.length == 0) return nil;
    
    __block PPStoreBranchInventoryRecord *rec = nil;
    dispatch_sync(self.syncQueue, ^{
        rec = self.inventoryMap[productId];
    });
    return rec;
}

- (NSDictionary<NSString *, NSNumber *> *)availableStockSnapshot {
    __block NSMutableDictionary<NSString *, NSNumber *> *copy = [NSMutableDictionary dictionary];
    dispatch_sync(self.syncQueue, ^{
        [self.inventoryMap enumerateKeysAndObjectsUsingBlock:^(NSString *key, PPStoreBranchInventoryRecord *obj, BOOL *stop) {
            copy[key] = @(MAX(0, obj.availableQuantity));
        }];
    });
    return [copy copy];
}

- (void)dealloc {
    [self stopListening];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
