//
//  CartManager.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 03/02/2026.
//
#import "CartManager.h"
#import "PetAccessoryManager.h"
#import "PPCartCalculator.h"
#import <UIKit/UIKit.h>
#import <math.h>

@interface CartManager()
@property (nonatomic, strong) CartItem *lastRemovedItem;
@property (nonatomic, assign) NSInteger lastRemovedIndex;
@property (nonatomic, assign, readwrite) BOOL isLocked;
@property (nonatomic, assign, readwrite) double deliveryFee;
@property (nonatomic, assign, readwrite) BOOL cashOnDeliveryEnabled;
@property (nonatomic, assign, readwrite) BOOL onlinePaymentEnabled;

@end
@implementation CartManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        _deliveryFee = 22.0;
        _cashOnDeliveryEnabled = YES;
        _onlinePaymentEnabled = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(pp_handleAppDidBecomeActiveNotification:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        [self refreshPricingConfiguration];
    }
    return self;
}

static NSString *PPCartPricingTrimmedString(id value)
{
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static double PPCartNormalizedDeliveryFee(id value, double fallback)
{
    if ([value respondsToSelector:@selector(doubleValue)]) {
        double candidate = [value doubleValue];
        if (isfinite(candidate) && candidate >= 0.0) {
            return round(candidate * 100.0) / 100.0;
        }
    }
    return MAX(0.0, fallback);
}

static BOOL PPCartBoolOrDefault(id value, BOOL fallback)
{
    if ([value isKindOfClass:NSNumber.class]) {
        return [(NSNumber *)value boolValue];
    }
    NSString *stringValue = [[PPCartPricingTrimmedString(value) lowercaseString] copy];
    if ([stringValue isEqualToString:@"true"] ||
        [stringValue isEqualToString:@"1"] ||
        [stringValue isEqualToString:@"yes"]) {
        return YES;
    }
    if ([stringValue isEqualToString:@"false"] ||
        [stringValue isEqualToString:@"0"] ||
        [stringValue isEqualToString:@"no"]) {
        return NO;
    }
    return fallback;
}

- (void)pp_handleAppDidBecomeActiveNotification:(NSNotification *)notification
{
    (void)notification;
    [self refreshPricingConfiguration];
}

- (void)refreshPricingConfiguration
{
    FIRDocumentReference *settingsRef = [[[FIRFirestore firestore] collectionWithPath:@"CommerceConfig"]
                                         documentWithPath:@"payments"];
    __weak typeof(self) weakSelf = self;
    [settingsRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[Cart] ⚠️ Pricing config fetch failed: %@", error.localizedDescription);
            return;
        }
        NSDictionary *data = [snapshot.data isKindOfClass:NSDictionary.class] ? snapshot.data : @{};
        [weakSelf pp_applyPricingConfiguration:data];
    }];
}

- (void)pp_applyPricingConfiguration:(NSDictionary *)data
{
    double nextDeliveryFee = PPCartNormalizedDeliveryFee(data[@"deliveryFee"], self.deliveryFee > 0.0 ? self.deliveryFee : 22.0);
    BOOL nextCashEnabled = PPCartBoolOrDefault(data[@"cashOnDeliveryEnabled"], YES);
    BOOL nextOnlineEnabled = PPCartBoolOrDefault(data[@"onlinePaymentEnabled"], YES);

    BOOL changed = (fabs(self.deliveryFee - nextDeliveryFee) > 0.009) ||
                   (self.cashOnDeliveryEnabled != nextCashEnabled) ||
                   (self.onlinePaymentEnabled != nextOnlineEnabled);

    self.deliveryFee = nextDeliveryFee;
    self.cashOnDeliveryEnabled = nextCashEnabled;
    self.onlinePaymentEnabled = nextOnlineEnabled;

    if (changed) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kCartPricingConfigurationDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:kCartUpdatedNotification object:nil];
    }
}

- (double)pp_currentCheckoutShippingFee
{
    return self.cartItems.count == 0 ? 0.0 : MAX(0.0, self.deliveryFee);
}


+ (instancetype)sharedManager {
    static CartManager *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[CartManager alloc] init];
        shared.cartItems = [NSMutableArray array];
        [shared loadCart];
    });
    return shared;
}

- (NSInteger)quantityForAccessory:(PetAccessory *)accessory {
    for (CartItem *item in self.cartItems) {
        if ([item.itemID isEqualToString:accessory.accessoryID]) {
            return item.quantity;
        }
    }
    return 0; // Not found in cart
}


- (CartItem *)pp_existingItemForID:(NSString *)itemID
{
    if (itemID.length == 0) return nil;
    for (CartItem *existing in self.cartItems) {
        if ([existing.itemID isEqualToString:itemID]) {
            return existing;
        }
    }
    return nil;
}

- (NSInteger)pp_stockLimitForItem:(CartItem *)item existingItem:(CartItem *)existingItem
{
    if (item.stockQuantity != NSNotFound) {
        return MAX(0, item.stockQuantity);
    }
    if (existingItem && existingItem.stockQuantity != NSNotFound) {
        return MAX(0, existingItem.stockQuantity);
    }

    PetAccessory *accessory = [[PetAccessoryManager sharedManager] getAccessoryID:item.itemID];
    if (accessory) {
        return MAX(0, accessory.quantity);
    }
    return NSNotFound;
}

- (NSMutableDictionary *)pp_firestorePayloadForItem:(CartItem *)item quantity:(NSInteger)quantity
{
    NSMutableDictionary *payload = [@{
        @"itemID": item.itemID ?: @"",
        @"name": item.name ?: @"",
        @"quantity": @(MAX(quantity, 0)),
        @"price": @(item.price),
        @"originalPrice": @(item.originalPrice),
        @"imageURL": item.imageURL ?: @""
    } mutableCopy];
    if (item.stockQuantity != NSNotFound) {
        payload[@"stockQuantity"] = @(MAX(item.stockQuantity, 0));
    }
    return payload;
}

- (void)pp_syncCartItemToFirestore:(CartItem *)item
{
    if (!UserManager.sharedManager.isUserLoggedIn) { return; }
    // U8: Use FIRAuth UID as primary, UserManager as fallback
    NSString *userID = PPCurrentFIRAuthUser.uid;
    if (userID.length == 0) userID = UserManager.sharedManager.currentUser.ID;
    if (userID.length == 0 || item.itemID.length == 0) { return; }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *itemRef = [[[[db collectionWithPath:@"UsersCol"]
                                       documentWithPath:userID]
                                      collectionWithPath:@"cartItems"]
                                     documentWithPath:item.itemID];

    NSMutableDictionary *payload =
        [self pp_firestorePayloadForItem:item quantity:item.quantity];
    [itemRef setData:payload
               merge:YES
          completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ Failed to sync cart item %@: %@",
                  item.itemID, error.localizedDescription);
        }
    }];
}


- (BOOL)addItem:(CartItem *)item {
    if (!UserManager.sharedManager.isUserLoggedIn) { return NO; }
    if (![item isKindOfClass:CartItem.class] || item.itemID.length == 0) { return NO; }
    if (item.quantity <= 0) {
        NSLog(@"[Cart] Reject add: invalid requested quantity for itemID=%@", item.itemID);
        return NO;
    }

    @synchronized (self) {
        if (self.isLocked) {
            NSLog(@"[Cart] Reject add: manager is locked for itemID=%@", item.itemID);
            return NO;
        }
        self.isLocked = YES;
    }

    self.lastRemovedItem = nil;
    self.lastRemovedIndex = NSNotFound;

    __block CartItem *itemToSync = nil;
    __block BOOL success = NO;

    @try {
        CartItem *existing = [self pp_existingItemForID:item.itemID];
        NSInteger existingQty = existing ? MAX(existing.quantity, 0) : 0;
        NSInteger stockLimit = [self pp_stockLimitForItem:item existingItem:existing];
        NSInteger increment = item.quantity;

        if (stockLimit == NSNotFound) {
            NSLog(@"[Cart] Reject add: missing/invalid stock for itemID=%@", item.itemID);
            return NO;
        }
        if (stockLimit <= 0) {
            NSLog(@"[Cart] Reject add: stock is 0 for itemID=%@", item.itemID);
            return NO;
        }
        NSInteger availableToAdd = MAX(0, stockLimit - existingQty);
        if (availableToAdd <= 0) {
            NSLog(@"[Cart] Reject add: no remaining stock for itemID=%@", item.itemID);
            return NO;
        }
        increment = MIN(increment, availableToAdd);

        increment = MAX(0, increment);
        if (increment <= 0) {
            return NO;
        }

        if (existing) {
            existing.quantity += increment;
            if (item.stockQuantity != NSNotFound) {
                existing.stockQuantity = MAX(0, item.stockQuantity);
            } else if (stockLimit != NSNotFound) {
                existing.stockQuantity = stockLimit;
            }
            itemToSync = existing;
        } else {
            item.quantity = increment;
            if (stockLimit != NSNotFound) {
                item.stockQuantity = stockLimit;
            }
            [self.cartItems addObject:item];
            itemToSync = item;
        }

        [self saveCart];
        success = YES;
    }
    @finally {
        self.isLocked = NO;
    }

    if (!success || !itemToSync) {
        return NO;
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:kCartUpdatedNotification object:nil];
    [self pp_syncCartItemToFirestore:itemToSync];
    return YES;
}


- (NSInteger)indexOfCartItemForItem:(CartItem *)myitem {
    for (NSInteger i = 0; i < self.cartItems.count; i++) {
        CartItem *item = self.cartItems[i];
        if ([item.itemID isEqualToString:myitem.itemID]) {
            return i;
        }
    }
    return NSNotFound; // means not found
}


- (void)saveCart {
    NSMutableArray *encoded = [NSMutableArray array];
    for (CartItem *item in self.cartItems) {
        NSMutableDictionary *dict = [@{
            @"itemID": item.itemID ?: @"",
            @"name": item.name ?: @"",
            @"quantity": @(MAX(item.quantity, 0)),
            @"price": @(item.price),
            @"originalPrice": @(item.originalPrice),
            @"imageURL": item.imageURL ?: @"",
        } mutableCopy];
        if (item.stockQuantity != NSNotFound) {
            dict[@"stockQuantity"] = @(MAX(item.stockQuantity, 0));
        }
        [encoded addObject:dict];
    }
    [[NSUserDefaults standardUserDefaults] setObject:encoded forKey:kSavedCartKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)loadCart {
    NSArray *saved = [[NSUserDefaults standardUserDefaults] objectForKey:kSavedCartKey];
    [self.cartItems removeAllObjects];
    for (NSDictionary *dict in saved) {
        CartItem *item = [[CartItem alloc] init];
        item.itemID = dict[@"itemID"];
        item.name = dict[@"name"];
        item.quantity = MAX(0, [dict[@"quantity"] integerValue]);
        if ([dict[@"stockQuantity"] respondsToSelector:@selector(integerValue)]) {
            NSInteger rawStock = [dict[@"stockQuantity"] integerValue];
            item.stockQuantity = (rawStock == NSNotFound) ? NSNotFound : MAX(0, rawStock);
        } else {
            item.stockQuantity = NSNotFound;
        }
        item.price = [dict[@"price"] floatValue];
        // Restore originalPrice; fallback to price for pre-migration data
        if ([dict[@"originalPrice"] respondsToSelector:@selector(floatValue)]) {
            float stored = [dict[@"originalPrice"] floatValue];
            item.originalPrice = stored > 0.0f ? stored : item.price;
        } else {
            item.originalPrice = item.price;
        }
        item.imageURL = dict[@"imageURL"] ?: @"";
        [self.cartItems addObject:item];
    }
    //[[NSNotificationCenter defaultCenter] postNotificationName:kCartUpdatedNotification object:nil];
}

- (void)clearCart {
    [self.cartItems removeAllObjects];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSavedCartKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:kCartUpdatedNotification object:nil];
}
/*
- (void)addItem:(CartItem *)item {
    [self.cartItems addObject:item];
    NSLog(@"🛒 Added to cart: %@", item.name);
    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *cartRef = [[db collectionWithPath:@"users"] documentWithPath:[UserManager sharedManager].currentUser.ID];
    [[cartRef collectionWithPath:@"cartItems"] addDocumentWithData:@{
        @"itemID": item.itemID,
        @"name": item.name,
        @"quantity": @(item.quantity),
        @"price": @(item.price),
    } completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ Failed to save cart item: %@", error.localizedDescription);
        } else {
            NSLog(@"✅ Cart item saved to Firestore");
        }
    }];
} */


- (void)syncCartToFirestore:(NSArray<CartItem *> *)items {
    
    // U8: Use FIRAuth UID as primary, UserManager as fallback
    NSString *userID = PPCurrentFIRAuthUser.uid;
    if (userID.length == 0) userID = UserManager.sharedManager.currentUser.ID;
    if (!userID) return;

    FIRFirestore *db = [FIRFirestore firestore];
    FIRCollectionReference *userCartRef = [[[db collectionWithPath:@"UsersCol"] documentWithPath:userID] collectionWithPath:@"cartItems"];

    FIRWriteBatch *batch = [db batch];
    for (CartItem *item in items) {
        FIRDocumentReference *ref = [userCartRef documentWithPath:item.itemID];
        NSMutableDictionary *data = [@{
            @"itemID": item.itemID ?: @"",
            @"name": item.name ?: @"",
            @"quantity": @(item.quantity),
            @"price": @(item.price),
            @"originalPrice": @(item.originalPrice),
            @"imageURL": item.imageURL ?: @""
        } mutableCopy];
        if (item.stockQuantity != NSNotFound) {
            data[@"stockQuantity"] = @(MAX(0, item.stockQuantity));
        }
        [batch setData:data forDocument:ref merge:YES];
    }
    [batch commitWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ Failed to sync cart batch: %@", error.localizedDescription);
        } else {
            NSLog(@"✅ Cart batch synced");
        }
    }];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kCartUpdatedNotification object:nil];
}



- (void)startListeningToCartChanges {
    // U8: Use FIRAuth UID as primary, UserManager as fallback
    NSString *userID = PPCurrentFIRAuthUser.uid;
    if (userID.length == 0) userID = UserManager.sharedManager.currentUser.ID;
    if (userID.length == 0) { return; }
    FIRFirestore *db = [FIRFirestore firestore];
    [[[[db collectionWithPath:@"UsersCol"] documentWithPath:userID] collectionWithPath:@"cartItems"]
     addSnapshotListener:^(FIRQuerySnapshot *snapshot, NSError *error) {
        if (error) {
            NSLog(@"❌ Cart listener error: %@", error.localizedDescription);
            return;
        }
        if (!snapshot) return;

        NSMutableDictionary<NSString *, CartItem *> *mergedByItemID = [NSMutableDictionary dictionary];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            CartItem *item = [[CartItem alloc] init];
            NSString *itemID = [doc[@"itemID"] isKindOfClass:NSString.class] ? doc[@"itemID"] : @"";
            if (itemID.length == 0) {
                itemID = doc.documentID ?: @"";
            }
            if (itemID.length == 0) {
                continue;
            }
            item.itemID = itemID;
            item.name = doc[@"name"];
            item.quantity = MAX(0, [doc[@"quantity"] integerValue]);
            if ([doc[@"stockQuantity"] respondsToSelector:@selector(integerValue)]) {
                item.stockQuantity = MAX(0, [doc[@"stockQuantity"] integerValue]);
            } else {
                item.stockQuantity = NSNotFound;
            }
            item.price = [doc[@"price"] floatValue];
            // Restore originalPrice from remote; fallback to price
            if ([doc[@"originalPrice"] respondsToSelector:@selector(floatValue)]) {
                float remote = [doc[@"originalPrice"] floatValue];
                item.originalPrice = remote > 0.0f ? remote : item.price;
            } else {
                item.originalPrice = item.price;
            }
            item.imageURL = doc[@"imageURL"] ?: @"";

            CartItem *existing = mergedByItemID[item.itemID];
            if (existing) {
                existing.quantity += item.quantity;
                if (item.stockQuantity != NSNotFound) {
                    if (existing.stockQuantity == NSNotFound) {
                        existing.stockQuantity = item.stockQuantity;
                    } else {
                        existing.stockQuantity = MAX(existing.stockQuantity, item.stockQuantity);
                    }
                }
                if (item.name.length > 0) { existing.name = item.name; }
                if (item.imageURL.length > 0) { existing.imageURL = item.imageURL; }
                if (item.price > 0) { existing.price = item.price; }
            } else {
                mergedByItemID[item.itemID] = item;
            }
        }

        NSArray<NSString *> *sortedIDs =
            [[mergedByItemID allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        NSMutableArray<CartItem *> *remoteCart = [NSMutableArray arrayWithCapacity:sortedIDs.count];
        for (NSString *itemID in sortedIDs) {
            CartItem *item = mergedByItemID[itemID];
            if (!item || item.quantity <= 0) { continue; }

            NSInteger stockLimit = [self pp_stockLimitForItem:item existingItem:item];
            if (stockLimit != NSNotFound) {
                if (stockLimit <= 0) {
                    continue;
                }
                item.quantity = MIN(item.quantity, stockLimit);
            }
            [remoteCart addObject:item];
        }

        self.cartItems = remoteCart;
        [self saveCart]; // persist to local
        [[NSNotificationCenter defaultCenter] postNotificationName:kCartUpdatedNotification object:nil];
    }];
}




- (void)updateQuantity:(NSInteger)newQuantity
              forItem:(CartItem *)item
           completion:(void (^ _Nullable)(BOOL success))completion {

    if (![item isKindOfClass:CartItem.class] || item.itemID.length == 0) {
        if (completion) completion(NO);
        return;
    }

    BOOL updated = NO;
    NSInteger clampedQuantity = MAX(newQuantity, 1);
    CartItem *existing = [self pp_existingItemForID:item.itemID];
    if (!existing) {
        if (completion) completion(NO);
        return;
    }

    NSInteger stockLimit = [self pp_stockLimitForItem:item existingItem:existing];
    if (stockLimit == NSNotFound) {
        if (completion) completion(NO);
        return;
    }
    if (stockLimit <= 0) {
        if (completion) completion(NO);
        return;
    }
    clampedQuantity = MIN(clampedQuantity, stockLimit);

    existing.quantity = clampedQuantity;
    if (item.stockQuantity != NSNotFound) {
        existing.stockQuantity = MAX(0, item.stockQuantity);
    } else if (stockLimit != NSNotFound) {
        existing.stockQuantity = stockLimit;
    }
    updated = YES;

    [self saveCart];
    [[NSNotificationCenter defaultCenter] postNotificationName:kCartUpdatedNotification object:nil];

    // U8: Use FIRAuth UID as primary, UserManager as fallback
    NSString *userID = PPCurrentFIRAuthUser.uid;
    if (userID.length == 0) userID = UserManager.sharedManager.currentUser.ID;
    if (updated && userID.length > 0) {
        FIRFirestore *db = [FIRFirestore firestore];
        FIRDocumentReference *itemRef = [[[[db collectionWithPath:@"UsersCol"]
                                           documentWithPath:userID]
                                          collectionWithPath:@"cartItems"]
                                         documentWithPath:item.itemID];

        NSMutableDictionary *payload =
            [self pp_firestorePayloadForItem:existing quantity:clampedQuantity];
        [itemRef setData:payload
                   merge:YES
              completion:^(NSError * _Nullable updateError) {
            if (updateError) {
                NSLog(@"❌ Failed to update remote quantity: %@",
                      updateError.localizedDescription);
            }
        }];
    }

    if (completion) {
        completion(updated); // ✅ Call completion with success/failure
    }
}


- (PetAccessory *)accessoryForCartItem:(CartItem *)item inArray:(NSArray<PetAccessory *> *)accessories {
    for (PetAccessory *accessory in accessories) {
        if ([accessory.accessoryID isEqualToString:item.itemID]) {
            return accessory;
        }
    }
    return nil; // not found
}

- (void)removeItem:(CartItem *)item {
    if (!item || item.itemID.length == 0) return;

    // 🔁 Remove from local cartItems
    NSUInteger indexToRemove = NSNotFound;
    for (NSUInteger i = 0; i < self.cartItems.count; i++) {
        CartItem *existing = self.cartItems[i];
        if ([existing.itemID isEqualToString:item.itemID]) {
            indexToRemove = i;
            break;
        }
    }

    if (indexToRemove == NSNotFound) return;

    self.lastRemovedItem = item;
    self.lastRemovedIndex = indexToRemove;

    [self.cartItems removeObjectAtIndex:indexToRemove];
    [self saveCart];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:kCartUpdatedNotification
                      object:nil];

    // 🔁 Remove from Firestore
    // U8: Use FIRAuth UID as primary, UserManager as fallback
    NSString *userID = PPCurrentFIRAuthUser.uid;
    if (userID.length == 0) userID = UserManager.sharedManager.currentUser.ID;
    if (!userID) return;

    FIRFirestore *db = [FIRFirestore firestore];
    FIRCollectionReference *cartItemsRef =
    [[[db collectionWithPath:@"UsersCol"]
      documentWithPath:userID]
     collectionWithPath:@"cartItems"];

    [[cartItemsRef queryWhereField:@"itemID" isEqualTo:item.itemID]
     getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {

        if (error) {
            NSLog(@"❌ Error querying Firestore for delete: %@",
                  error.localizedDescription);
            return;
        }

        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            [[cartItemsRef documentWithPath:doc.documentID]
             deleteDocumentWithCompletion:^(NSError * _Nullable err) {
                if (err) {
                    NSLog(@"❌ Failed to delete cart item: %@",
                          err.localizedDescription);
                } else {
                    NSLog(@"🗑️ Deleted cart item: %@",
                          item.itemID);
                }
            }];
        }
    }];
}

- (void)removeItemForAccessory:(PetAccessory *)accessory {
    // Forward to unified remover
    CartItem *item =
    [self getCartItemForItemID:accessory.accessoryID];
    [self removeItem:item];
    return;
}

-(CartItem *)getCartItemForItemID:(NSString *)ItemID
{
    for (NSUInteger i = 0; i < self.cartItems.count; i++) {
        CartItem *item = self.cartItems[i];
        if ([item.itemID isEqualToString:ItemID]) {
            return item;
            break;
        }
    }
    return nil;
}

- (NSInteger)totalItemsCount {
    PPCartSummary *summary = [PPCartCalculator summaryForItems:self.cartItems shippingFee:0.0];
    return summary.totalQuantity;
}

- (double)subtotalAmount {
    PPCartSummary *summary = [PPCartCalculator summaryForItems:self.cartItems shippingFee:0.0];
    return summary.subtotal;
}

- (double)totalAmount {
    PPCartSummary *summary = [PPCartCalculator currentSummary];
    return summary.finalTotal;
}

- (BOOL)isCartEmpty {
    return self.cartItems.count == 0;
}

- (BOOL)undoLastRemoval
{
    if (!self.lastRemovedItem) return NO;

    NSInteger insertIndex =
        MIN(self.lastRemovedIndex, self.cartItems.count);

    [self.cartItems insertObject:self.lastRemovedItem
                          atIndex:insertIndex];

    // reset snapshot
    self.lastRemovedItem = nil;
    self.lastRemovedIndex = NSNotFound;

    [self saveCart];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:kCartUpdatedNotification
                      object:nil];

    return YES;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
}

@end
