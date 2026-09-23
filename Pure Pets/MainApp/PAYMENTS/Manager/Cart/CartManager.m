//
//  CartManager.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 03/02/2026.
//
#import "CartManager.h"
#import "PetAccessoryManager.h"
#import "PPCartCalculator.h"
#import "PPFirestoreErrorNotifier.h"
#import "PPAlertHelper.h"
#import <UIKit/UIKit.h>
#import <math.h>
@import FirebaseAuth;

@interface CartManager()
@property (nonatomic, strong) CartItem *lastRemovedItem;
@property (nonatomic, assign) NSInteger lastRemovedIndex;
@property (nonatomic, assign, readwrite) BOOL isLocked;
@property (nonatomic, assign, readwrite) double deliveryFee;
@property (nonatomic, assign, readwrite) BOOL cashOnDeliveryEnabled;
@property (nonatomic, assign, readwrite) BOOL onlinePaymentEnabled;
@property (nonatomic, assign, readwrite) BOOL applePayEnabled;
@property (nonatomic, assign, readwrite) BOOL ooredooMoneyEnabled;
@property (nonatomic, assign, readwrite) BOOL napsEnabled;
@property (nonatomic, assign, readwrite) BOOL allowMultiProviderCart;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> cartListener;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> pricingListener;

- (BOOL)pp_addItem:(CartItem *)item
    syncCompletion:(void (^ _Nullable)(BOOL success))syncCompletion;
- (void)pp_syncCartItemToFirestore:(CartItem *)item
                        completion:(void (^ _Nullable)(BOOL success))completion;
- (void)clearCartAndSyncToFirestoreWithCompletion:(void (^ _Nullable)(BOOL success))completion
                                 postNotification:(BOOL)postNotification;

@end

@interface PPCartAddProjection ()

@property (nonatomic, assign, readwrite) NSInteger addedQuantity;
@property (nonatomic, assign, readwrite) NSInteger totalUnits;
@property (nonatomic, assign, readwrite) double selectionSubtotal;
@property (nonatomic, assign, readwrite) double projectedSubtotal;
@property (nonatomic, assign, readwrite) BOOL requiresProviderSwitch;

- (instancetype)initWithAddedQuantity:(NSInteger)addedQuantity
                           totalUnits:(NSInteger)totalUnits
                  selectionSubtotal:(double)selectionSubtotal
                  projectedSubtotal:(double)projectedSubtotal
              requiresProviderSwitch:(BOOL)requiresProviderSwitch;

@end

@implementation PPCartAddProjection

- (instancetype)initWithAddedQuantity:(NSInteger)addedQuantity
                           totalUnits:(NSInteger)totalUnits
                  selectionSubtotal:(double)selectionSubtotal
                  projectedSubtotal:(double)projectedSubtotal
              requiresProviderSwitch:(BOOL)requiresProviderSwitch
{
    self = [super init];
    if (self) {
        _addedQuantity = MAX(addedQuantity, 0);
        _totalUnits = MAX(totalUnits, 0);
        _selectionSubtotal = MAX(selectionSubtotal, 0.0);
        _projectedSubtotal = MAX(projectedSubtotal, 0.0);
        _requiresProviderSwitch = requiresProviderSwitch;
    }
    return self;
}

@end

@implementation CartManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        _deliveryFee = 22.0;
        _cashOnDeliveryEnabled = YES;
        _onlinePaymentEnabled = YES;
        _applePayEnabled = YES;
        _ooredooMoneyEnabled = YES;
        _napsEnabled = YES;
        _allowMultiProviderCart = NO;
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

static void PPCartCompleteAdd(PPCartAddItemCompletion completion, BOOL success, BOOL didCancel)
{
    if (!completion) { return; }
    if ([NSThread isMainThread]) {
        completion(success, didCancel);
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(success, didCancel);
        });
    }
}

static void PPCartCompleteSync(void (^completion)(BOOL success), BOOL success)
{
    if (!completion) { return; }
    if ([NSThread isMainThread]) {
        completion(success);
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(success);
        });
    }
}

static CartItem *PPCartCopyItem(CartItem *source)
{
    if (![source isKindOfClass:CartItem.class]) { return nil; }
    CartItem *copy = [CartItem new];
    copy.itemID = source.itemID ?: @"";
    copy.name = source.name ?: @"";
    copy.quantity = source.quantity;
    copy.stockQuantity = source.stockQuantity;
    copy.price = source.price;
    copy.originalPrice = source.originalPrice;
    copy.imageURL = source.imageURL ?: @"";
    copy.providerID = source.providerID ?: @"";
    copy.type = source.type ?: @"";
    copy.size = source.size ?: @"";
    copy.sellableUnitId = source.sellableUnitId ?: @"";
    copy.variantId = source.variantId ?: @"";
    copy.variantCombinationKey = source.variantCombinationKey ?: @"";
    copy.productFamilyId = source.productFamilyId ?: @"";
    copy.sku = source.sku ?: @"";
    copy.barcode = source.barcode ?: @"";
    copy.isVariant = source.isVariant;
    copy.selectedOptions = [source.selectedOptions copy];
    copy.selectedOptionsSnapshot = [source.selectedOptionsSnapshot copy];
    copy.optionsSummary = source.optionsSummary ?: @"";
    return copy;
}

static void PPCartMergeVariantMetadata(CartItem *source, CartItem *target)
{
    if (![source.itemID isEqualToString:target.itemID]) { return; }
    if (source.productFamilyId.length > 0) { target.productFamilyId = source.productFamilyId; }
    if (source.sellableUnitId.length > 0) { target.sellableUnitId = source.sellableUnitId; }
    if (source.variantId.length > 0) { target.variantId = source.variantId; }
    if (source.variantCombinationKey.length > 0) { target.variantCombinationKey = source.variantCombinationKey; }
    if (source.sku.length > 0) { target.sku = source.sku; }
    if (source.barcode.length > 0) { target.barcode = source.barcode; }
    if (source.selectedOptions.count > 0) { target.selectedOptions = [source.selectedOptions copy]; }
    if (source.selectedOptionsSnapshot.count > 0) { target.selectedOptionsSnapshot = [source.selectedOptionsSnapshot copy]; }
    if (source.optionsSummary.length > 0) { target.optionsSummary = source.optionsSummary; }
    target.isVariant = target.isVariant || source.isVariant;
}

- (void)pp_handleAppDidBecomeActiveNotification:(NSNotification *)notification
{
    (void)notification;
    [self refreshPricingConfiguration];
}

- (void)refreshPricingConfiguration
{
    if (self.pricingListener) {
        return;
    }
    FIRDocumentReference *settingsRef = [[[FIRFirestore firestore] collectionWithPath:@"CommerceConfig"]
                                         documentWithPath:@"payments"];
    __weak typeof(self) weakSelf = self;
    self.pricingListener = [settingsRef addSnapshotListener:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[Cart] ⚠️ Pricing config live listen failed: %@", error.localizedDescription);
            [PPFirestoreErrorNotifier postError:error context:PPFirestoreContextCartPricingFetch];
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
    BOOL nextAppleEnabled = PPCartBoolOrDefault(data[@"applePayEnabled"], YES);
    BOOL nextOoredooEnabled = PPCartBoolOrDefault(data[@"ooredooMoneyEnabled"], YES);
    BOOL nextNapsEnabled = PPCartBoolOrDefault(data[@"napsEnabled"], YES);
    BOOL nextAllowMultiProviderCart = PPCartBoolOrDefault(data[@"allowMultiProviderCart"], NO);

    BOOL changed = (fabs(self.deliveryFee - nextDeliveryFee) > 0.009) ||
                   (self.cashOnDeliveryEnabled != nextCashEnabled) ||
                   (self.onlinePaymentEnabled != nextOnlineEnabled) ||
                   (self.applePayEnabled != nextAppleEnabled) ||
                   (self.ooredooMoneyEnabled != nextOoredooEnabled) ||
                   (self.napsEnabled != nextNapsEnabled) ||
                   (self.allowMultiProviderCart != nextAllowMultiProviderCart);

    self.deliveryFee = nextDeliveryFee;
    self.cashOnDeliveryEnabled = nextCashEnabled;
    self.onlinePaymentEnabled = nextOnlineEnabled;
    self.applePayEnabled = nextAppleEnabled;
    self.ooredooMoneyEnabled = nextOoredooEnabled;
    self.napsEnabled = nextNapsEnabled;
    self.allowMultiProviderCart = nextAllowMultiProviderCart;

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
    if (!accessory) return 0;
    CartItem *existing = nil;
    if (accessory.accessoryID.length > 0) {
        existing = [self getCartItemForItemID:accessory.accessoryID];
    }
    if (!existing && accessory.accessoryID.length > 0) {
        existing = [self getCartItemForItemID:accessory.accessoryID];
    }
    return existing ? existing.quantity : 0;
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

- (CartItem *)pp_existingItemMatching:(CartItem *)item
{
    if (!item || item.itemID.length == 0) return nil;
    for (CartItem *existing in self.cartItems) {
        if (![existing.itemID isEqualToString:item.itemID]) {
            continue;
        }
        if (existing.variantCombinationKey.length > 0 && item.variantCombinationKey.length > 0) {
            if ([existing.variantCombinationKey isEqualToString:item.variantCombinationKey]) {
                return existing;
            }
            continue;
        }
        return existing;
    }
    return nil;
}

- (NSInteger)pp_stockLimitForItem:(CartItem *)item existingItem:(CartItem *)existingItem
{
    // F-22: the live catalogue document is authoritative, so it is consulted FIRST.
    //
    // This used to prefer the in-memory `stockQuantity` hint on the cart item, which
    // is only ever as fresh as the last time that product was loaded. A cart held
    // open across a sell-out therefore enforced a stale ceiling, and the server's own
    // `noStock` was never consulted at all.
    PetAccessory *accessory = [[PetAccessoryManager sharedManager] getAccessoryID:item.itemID];
    if (accessory) {
        if (!accessory.isPurchasable) {
            return 0;
        }
        return MAX(0, accessory.quantity);
    }

    // No catalogue document cached. Fall back to the session hint, taking the LOWER
    // of the two when both exist — a second opinion must never widen a ceiling.
    NSInteger hint = NSNotFound;
    if (item.stockQuantity != NSNotFound) {
        hint = MAX(0, item.stockQuantity);
    }
    if (existingItem && existingItem.stockQuantity != NSNotFound) {
        NSInteger existingHint = MAX(0, existingItem.stockQuantity);
        hint = (hint == NSNotFound) ? existingHint : MIN(hint, existingHint);
    }
    return hint;
}

- (NSMutableDictionary *)pp_firestorePayloadForItem:(CartItem *)item quantity:(NSInteger)quantity
{
    NSMutableDictionary *payload = [[item firestoreDictionary] mutableCopy];
    payload[@"quantity"] = @(MAX(quantity, 0));
    payload[@"qty"] = @(MAX(quantity, 0));
    return payload;
}

- (void)pp_syncCartItemToFirestore:(CartItem *)item
                        completion:(void (^)(BOOL success))completion
{
    if (!UserManager.sharedManager.isUserLoggedIn) {
        PPCartCompleteSync(completion, NO);
        return;
    }
    // U8: Use FIRAuth UID as primary, UserManager as fallback
    NSString *userID = PPCurrentFIRAuthUser.uid;
    if (userID.length == 0) userID = UserManager.sharedManager.currentUser.ID;
    if (userID.length == 0 || item.itemID.length == 0) {
        PPCartCompleteSync(completion, NO);
        return;
    }

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
            [PPFirestoreErrorNotifier postError:error context:PPFirestoreContextCartItemSync];
        }
        PPCartCompleteSync(completion, error == nil);
    }];
}


- (BOOL)addItem:(CartItem *)item
{
    return [self pp_addItem:item syncCompletion:nil];
}

- (BOOL)pp_addItem:(CartItem *)item
    syncCompletion:(void (^)(BOOL success))syncCompletion
{
    if (!UserManager.sharedManager.isUserLoggedIn) { return NO; }
    if (![item isKindOfClass:CartItem.class] || item.itemID.length == 0) { return NO; }
    if (item.quantity <= 0) {
        NSLog(@"[Cart] Reject add: invalid requested quantity for itemID=%@", item.itemID);
        return NO;
    }
    if (item.price < 0.01 || isnan(item.price)) {
        NSLog(@"[Cart] Reject add: invalid price (%.4f) for itemID=%@", item.price, item.itemID);
        return NO;
    }
    if ([self shouldConfirmProviderSwitchForItem:item]) {
        NSLog(@"[Cart] Reject add: provider switch requires user confirmation for itemID=%@", item.itemID);
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
        CartItem *existing = [self pp_existingItemMatching:item];
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
            PPCartMergeVariantMetadata(item, existing);
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
    [self pp_syncCartItemToFirestore:itemToSync
                          completion:syncCompletion];
    return YES;
}

- (void)addItemAndWaitForSync:(CartItem *)item
                   completion:(void (^)(BOOL success))completion
{
    CartItem *existingBefore = [self pp_existingItemMatching:item];
    CartItem *existingSnapshot = PPCartCopyItem(existingBefore);

    __weak typeof(self) weakSelf = self;
    BOOL didAdd = [self pp_addItem:item
                    syncCompletion:^(BOOL syncSucceeded) {
        void (^finalizeOnMain)(void) = ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                PPCartCompleteSync(completion, NO);
                return;
            }

            if (!syncSucceeded) {
                CartItem *current = [self pp_existingItemMatching:item];
                if (existingSnapshot) {
                    NSUInteger index = current
                        ? [self.cartItems indexOfObjectIdenticalTo:current]
                        : NSNotFound;
                    if (index != NSNotFound) {
                        self.cartItems[index] = existingSnapshot;
                    } else {
                        [self.cartItems addObject:existingSnapshot];
                    }
                } else if (current) {
                    [self.cartItems removeObjectIdenticalTo:current];
                }
                [self saveCart];
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:kCartUpdatedNotification
                                  object:nil];
            }

            PPCartCompleteSync(completion, syncSucceeded);
        };

        if ([NSThread isMainThread]) {
            finalizeOnMain();
        } else {
            dispatch_async(dispatch_get_main_queue(), finalizeOnMain);
        }
    }];

    if (!didAdd) {
        PPCartCompleteSync(completion, NO);
    }
}

- (BOOL)shouldConfirmProviderSwitchForItem:(CartItem *)item
{
    return [self shouldConfirmProviderSwitchForProviderID:item.providerID];
}

- (BOOL)shouldConfirmProviderSwitchForProviderID:(NSString *)providerID
{
    if (self.allowMultiProviderCart) { return NO; }
    NSString *incomingProviderID = PPCartPricingTrimmedString(providerID);
    if (incomingProviderID.length == 0) { return NO; }

    for (CartItem *existing in self.cartItems) {
        NSString *existingProviderID =
            PPCartPricingTrimmedString(existing.providerID);
        if (existingProviderID.length == 0) { continue; }
        if (![existingProviderID isEqualToString:incomingProviderID]) {
            return YES;
        }
    }
    return NO;
}

- (PPCartAddProjection *)projectionForAddingItem:(CartItem *)item
{
    if (![item isKindOfClass:CartItem.class] ||
        item.itemID.length == 0 ||
        item.quantity <= 0 ||
        item.price < 0.01 ||
        isnan(item.price)) {
        return nil;
    }

    BOOL requiresProviderSwitch =
        [self shouldConfirmProviderSwitchForItem:item];
    NSMutableArray<CartItem *> *candidateItems = [NSMutableArray array];
    if (!requiresProviderSwitch) {
        for (CartItem *existingItem in self.cartItems) {
            CartItem *copy = PPCartCopyItem(existingItem);
            if (copy) { [candidateItems addObject:copy]; }
        }
    }

    CartItem *candidateExisting = nil;
    for (CartItem *candidate in candidateItems) {
        if ([candidate.itemID isEqualToString:item.itemID]) {
            candidateExisting = candidate;
            break;
        }
    }

    NSInteger existingQuantity =
        candidateExisting ? MAX(candidateExisting.quantity, 0) : 0;
    NSInteger stockLimit =
        [self pp_stockLimitForItem:item existingItem:candidateExisting];
    if (stockLimit == NSNotFound || stockLimit <= 0) {
        return nil;
    }

    NSInteger availableToAdd = MAX(0, stockLimit - existingQuantity);
    NSInteger increment = MIN(MAX(item.quantity, 0), availableToAdd);
    if (increment <= 0) { return nil; }

    double selectionUnitPrice = item.price;
    if (candidateExisting) {
        selectionUnitPrice = candidateExisting.price;
        candidateExisting.quantity += increment;
        if (item.stockQuantity != NSNotFound) {
            candidateExisting.stockQuantity = MAX(0, item.stockQuantity);
        } else {
            candidateExisting.stockQuantity = stockLimit;
        }
    } else {
        CartItem *candidate = PPCartCopyItem(item);
        if (!candidate) { return nil; }
        candidate.quantity = increment;
        candidate.stockQuantity = stockLimit;
        [candidateItems addObject:candidate];
    }

    PPCartSummary *summary =
        [PPCartCalculator summaryForItems:candidateItems shippingFee:0.0];
    return [[PPCartAddProjection alloc]
        initWithAddedQuantity:increment
                   totalUnits:summary.totalQuantity
          selectionSubtotal:
            MAX(0.0, selectionUnitPrice * (double)increment)
          projectedSubtotal:summary.subtotal
      requiresProviderSwitch:requiresProviderSwitch];
}

- (void)addItem:(CartItem *)item
presentingViewController:(UIViewController *)presentingViewController
     completion:(PPCartAddItemCompletion)completion
{
    if (![item isKindOfClass:CartItem.class] || item.itemID.length == 0) {
        PPCartCompleteAdd(completion, NO, NO);
        return;
    }

    if (!UserManager.sharedManager.isUserLoggedIn) {
        PPCartCompleteAdd(completion, NO, NO);
        return;
    }

    if (![self shouldConfirmProviderSwitchForItem:item]) {
        BOOL didAdd = [self addItem:item];
        PPCartCompleteAdd(completion, didAdd, NO);
        return;
    }

    UIViewController *presenter = presentingViewController ?: AppMgr.topViewController;
    if (!presenter) {
        PPCartCompleteAdd(completion, NO, NO);
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [PPAlertHelper showConfirmationIn:presenter
                                    title:kLang(@"cart_provider_switch_title")
                                 subtitle:kLang(@"cart_provider_switch_message")
                            confirmButton:kLang(@"cart_provider_switch_confirm")
                             cancelButton:kLang(@"cart_provider_switch_cancel")
                                     icon:nil
                             confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
            (void)text;
            if (!didConfirm) {
                PPCartCompleteAdd(completion, NO, YES);
                return;
            }

            [self clearCartAndSyncToFirestoreWithCompletion:^(BOOL success) {
                if (!success) {
                    PPCartCompleteAdd(completion, NO, NO);
                    return;
                }

                BOOL didAdd = [self addItem:item];
                PPCartCompleteAdd(completion, didAdd, NO);
            } postNotification:NO];
        } cancelBlock:^{
            PPCartCompleteAdd(completion, NO, YES);
        }];
    });
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
        // One serializer preserves sellable identity/options in both mirrors.
        // Its stock hint is deliberately session-only, never persisted.
        [encoded addObject:[item firestoreDictionary]];
    }
    [[NSUserDefaults standardUserDefaults] setObject:encoded forKey:kSavedCartKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)loadCart {
    NSArray *saved = [[NSUserDefaults standardUserDefaults] objectForKey:kSavedCartKey];
    [self.cartItems removeAllObjects];
    if (![saved isKindOfClass:NSArray.class]) { return; }
    for (NSDictionary *dict in saved) {
        if (![dict isKindOfClass:NSDictionary.class]) { continue; }
        CartItem *item = [[CartItem alloc] initWithDictionary:dict];
        if (item.itemID.length == 0 || item.quantity <= 0) { continue; }
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

- (void)clearCartAndSyncToFirestoreWithCompletion:(void (^ _Nullable)(BOOL success))completion
{
    [self clearCartAndSyncToFirestoreWithCompletion:completion postNotification:YES];
}

- (void)clearCartAndSyncToFirestoreWithCompletion:(void (^ _Nullable)(BOOL success))completion
                                 postNotification:(BOOL)postNotification
{
    NSArray<CartItem *> *items = [self.cartItems copy];
    NSString *userID = PPCurrentFIRAuthUser.uid;
    if (userID.length == 0) userID = UserManager.sharedManager.currentUser.ID;

    if (items.count == 0 || userID.length == 0) {
        if (postNotification) {
            [self clearCart];
        } else {
            [self.cartItems removeAllObjects];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSavedCartKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        if (completion) { completion(YES); }
        return;
    }

    NSMutableArray<CartItem *> *itemsToClear = [NSMutableArray array];
    for (CartItem *item in items) {
        if (item.itemID.length > 0) { [itemsToClear addObject:item]; }
    }
    if (itemsToClear.count == 0) {
        if (postNotification) {
            [self clearCart];
        } else {
            [self.cartItems removeAllObjects];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSavedCartKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        if (completion) { completion(YES); }
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRCollectionReference *cartItemsRef =
    [[[db collectionWithPath:@"UsersCol"]
      documentWithPath:userID]
     collectionWithPath:@"cartItems"];

    FIRWriteBatch *batch = [db batch];
    for (CartItem *item in itemsToClear) {
        [batch deleteDocument:[cartItemsRef documentWithPath:item.itemID]];
    }

    __weak typeof(self) weakSelf = self;
    [batch commitWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ Failed to clear cart during provider switch: %@", error.localizedDescription);
            [PPFirestoreErrorNotifier postError:error context:PPFirestoreContextCartBatchSync];
            if (completion) { completion(NO); }
            return;
        }
        [weakSelf.cartItems removeAllObjects];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSavedCartKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        if (postNotification) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kCartUpdatedNotification object:nil];
        }
        if (completion) { completion(YES); }
    }];
}

- (void)clearCartAndSyncToFirestore
{
    [self clearCartAndSyncToFirestoreWithCompletion:nil];
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
            @"imageURL": item.imageURL ?: @"",
            @"providerID": item.providerID ?: @""
        } mutableCopy];
        if (item.stockQuantity != NSNotFound) {
            data[@"stockQuantity"] = @(MAX(0, item.stockQuantity));
        }
        [batch setData:data forDocument:ref merge:YES];
    }
    [batch commitWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ Failed to sync cart batch: %@", error.localizedDescription);
            [PPFirestoreErrorNotifier postError:error context:PPFirestoreContextCartBatchSync];
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

    // Remove previous listener to prevent stacking
    [self.cartListener remove];
    self.cartListener = nil;

    FIRFirestore *db = [FIRFirestore firestore];
    self.cartListener =
    [[[[db collectionWithPath:@"UsersCol"] documentWithPath:userID] collectionWithPath:@"cartItems"]
     addSnapshotListener:^(FIRQuerySnapshot *snapshot, NSError *error) {
        if (error) {
            NSLog(@"❌ Cart listener error: %@", error.localizedDescription);
            [PPFirestoreErrorNotifier postError:error context:PPFirestoreContextCartListener];
            return;
        }
        if (!snapshot) return;

        NSMutableDictionary<NSString *, CartItem *> *mergedByItemID = [NSMutableDictionary dictionary];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            CartItem *item = [[CartItem alloc] initWithDictionary:doc.data ?: @{}];
            NSString *itemID = [doc[@"itemID"] isKindOfClass:NSString.class] ? doc[@"itemID"] : @"";
            if (itemID.length == 0) {
                itemID = doc.documentID ?: @"";
            }
            if (itemID.length == 0) {
                continue;
            }
            item.itemID = itemID;

            CartItem *existing = mergedByItemID[item.itemID];
            if (existing) {
                PPCartMergeVariantMetadata(item, existing);
                existing.quantity += item.quantity;
                if (item.stockQuantity != NSNotFound) {
                    if (existing.stockQuantity == NSNotFound) {
                        existing.stockQuantity = item.stockQuantity;
                    } else {
                        // F-22: merging two cart documents must take the LOWER
                        // ceiling. `MAX` let a stale, larger snapshot win over a
                        // fresher, smaller one and widen the purchasable ceiling.
                        existing.stockQuantity = MIN(existing.stockQuantity, item.stockQuantity);
                    }
                }
                if (item.name.length > 0) { existing.name = item.name; }
                if (item.imageURL.length > 0) { existing.imageURL = item.imageURL; }
                if (item.providerID.length > 0) { existing.providerID = item.providerID; }
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
    CartItem *existing = [self pp_existingItemMatching:item];
    if (!existing) {
        if (completion) completion(NO);
        return;
    }

    NSInteger stockLimit = [self pp_stockLimitForItem:item existingItem:existing];
    // A missing/zero ceiling cannot authorize an increase. Reductions remain
    // available so customers can correct a line after availability changes.
    if (clampedQuantity > existing.quantity &&
        (stockLimit == NSNotFound || stockLimit <= 0)) {
        if (completion) completion(NO);
        return;
    }
    if (stockLimit != NSNotFound && stockLimit > 0) {
        clampedQuantity = MIN(clampedQuantity, stockLimit);
    }

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
                [PPFirestoreErrorNotifier postError:updateError context:PPFirestoreContextCartQuantityUpdate];
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
            if (existing.variantCombinationKey.length > 0 && item.variantCombinationKey.length > 0) {
                if (![existing.variantCombinationKey isEqualToString:item.variantCombinationKey]) {
                    continue;
                }
            }
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
            [PPFirestoreErrorNotifier postError:error context:PPFirestoreContextCartDeleteQuery];
            return;
        }

        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            [[cartItemsRef documentWithPath:doc.documentID]
             deleteDocumentWithCompletion:^(NSError * _Nullable err) {
                if (err) {
                    NSLog(@"❌ Failed to delete cart item: %@",
                          err.localizedDescription);
                    [PPFirestoreErrorNotifier postError:err context:PPFirestoreContextCartDeleteItem];
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

- (void)stopListeningToCartChanges {
    [self.cartListener remove];
    self.cartListener = nil;
    [self.pricingListener remove];
    self.pricingListener = nil;
}

- (void)dealloc
{
    [self.cartListener remove];
    self.cartListener = nil;
    [self.pricingListener remove];
    self.pricingListener = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
}

@end
