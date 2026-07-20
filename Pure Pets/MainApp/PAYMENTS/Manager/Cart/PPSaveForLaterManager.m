#import "PPSaveForLaterManager.h"
#import "PPUniversalCellViewModel.h"
#import "PetAccessoryManager.h"
#import "UserManager.h"

static NSString * const PPSaveForLaterUpdatedNotification = @"PPSaveForLaterUpdatedNotification";
static NSString * const PPSaveForLaterErrorDomain = @"com.purepets.savedForLater";

static NSInteger PPSaveForLaterStockQuantityFromValue(id value) {
    if ([value respondsToSelector:@selector(integerValue)]) {
        NSInteger rawStock = [value integerValue];
        return rawStock == NSNotFound ? NSNotFound : MAX(0, rawStock);
    }
    return NSNotFound;
}

static NSError *PPSaveForLaterError(NSInteger code, NSString *description) {
    return [NSError errorWithDomain:PPSaveForLaterErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description ?: @"Saved item operation failed."}];
}

static void PPSaveForLaterCompleteOnMain(PPSaveForLaterRemoveCompletion _Nullable completion, NSError * _Nullable error) {
    if (!completion) { return; }
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(error);
    });
}

@interface PPSaveForLaterManager ()
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> savedForLaterListener;
@property (nonatomic, assign) FIRAuthStateDidChangeListenerHandle authStateHandle;
@property (nonatomic, assign) BOOL suppressSavedForLaterUpdateNotifications;
@end

@implementation PPSaveForLaterManager {
    NSMutableArray<CartItem *> *_items;
}

+ (instancetype)sharedManager {
    static PPSaveForLaterManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[PPSaveForLaterManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _items = [NSMutableArray array];
        self.suppressSavedForLaterUpdateNotifications = YES;
        
        // Load initial local cache if a user is already signed in
        NSString *userID = [FIRAuth auth].currentUser.uid;
        if (userID.length == 0) userID = UserManager.sharedManager.currentUser.ID;
        if (userID.length > 0) {
            [self loadLocalCacheForUser:userID];
            [self startListeningToSavedForLaterChanges];
        }
        
        // Setup state change listener to monitor dynamic Auth logins/logouts
        __weak typeof(self) weakSelf = self;
        self.authStateHandle = [[FIRAuth auth] addAuthStateDidChangeListener:^(FIRAuth * _Nonnull auth, FIRUser * _Nullable user) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            if (user) {
                [strongSelf loadLocalCacheForUser:user.uid];
                [strongSelf startListeningToSavedForLaterChanges];
            } else {
                [strongSelf stopListeningToSavedForLaterChanges];
                [strongSelf clearLocalAndMemory];
            }
        }];

        self.suppressSavedForLaterUpdateNotifications = NO;
    }
    return self;
}

- (void)dealloc {
    if (self.authStateHandle && [FIRAuth auth]) {
        [[FIRAuth auth] removeAuthStateDidChangeListener:self.authStateHandle];
    }
    [self.savedForLaterListener remove];
}

- (NSArray<CartItem *> *)savedItems {
    return [_items copy];
}

- (void)saveItemForLater:(CartItem *)item {
    if (!item || item.itemID.length == 0) return;
    
    NSString *userID = [FIRAuth auth].currentUser.uid;
    if (userID.length == 0) userID = UserManager.sharedManager.currentUser.ID;
    if (userID.length == 0) return; // Must be logged in to save to Firestore
    
    // 1. Update local memory
    NSInteger resolvedStockQuantity = item.stockQuantity;
    if (resolvedStockQuantity == NSNotFound) {
        PetAccessory *cachedAccessory = [[PetAccessoryManager sharedManager] getAccessoryID:item.itemID];
        if (cachedAccessory) {
            resolvedStockQuantity = MAX(0, cachedAccessory.quantity);
        }
    }

    if (![self isItemSaved:item.itemID]) {
        CartItem *itemCopy = [[CartItem alloc] init];
        itemCopy.itemID = item.itemID;
        itemCopy.name = item.name;
        itemCopy.price = item.price;
        itemCopy.originalPrice = item.originalPrice;
        itemCopy.imageURL = item.imageURL;
        itemCopy.providerID = item.providerID;
        itemCopy.type = item.type ?: @"";
        itemCopy.stockQuantity = resolvedStockQuantity;
        itemCopy.quantity = 1;
        [_items addObject:itemCopy];
        [self persistForUser:userID];
    }
    
    // 2. Sync to Firestore subcollection: /UsersCol/{userID}/savedForLater/{itemID}
    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *docRef = [[[[db collectionWithPath:@"UsersCol"]
                                     documentWithPath:userID]
                                    collectionWithPath:@"savedForLater"]
                                   documentWithPath:item.itemID];
    
    NSMutableDictionary *payload = [@{
        @"itemID": item.itemID ?: @"",
        @"name": item.name ?: @"",
        @"price": @(item.price),
        @"originalPrice": @(item.originalPrice),
        @"imageURL": item.imageURL ?: @"",
        @"providerID": item.providerID ?: @"",
        @"quantity": @(1),
        @"timestamp": [FIRFieldValue fieldValueForServerTimestamp]
    } mutableCopy];
    if (item.type.length > 0) {
        payload[@"type"] = item.type;
    }
    if (resolvedStockQuantity != NSNotFound) {
        payload[@"stockQuantity"] = @(MAX(0, resolvedStockQuantity));
    }
    
    [docRef setData:payload merge:YES completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ SavedForLater: Failed to write to Firestore: %@", error.localizedDescription);
        }
    }];
}

- (void)saveViewModelForLater:(PPUniversalCellViewModel *)viewModel {
    if (!viewModel || viewModel.ModelID.length == 0) return;
    
    CartItem *item = [[CartItem alloc] init];
    item.itemID = viewModel.ModelID;
    item.name = viewModel.title ?: @"";
    double basePrice = viewModel.price ? [viewModel.price doubleValue] : 0.0;
    double finalPrice = viewModel.finalPrice ? [viewModel.finalPrice doubleValue] : basePrice;
    if (finalPrice <= 0.0 && basePrice > 0.0) {
        finalPrice = basePrice;
    }
    item.price = finalPrice;
    item.originalPrice = basePrice > 0.0 ? basePrice : finalPrice;
    item.imageURL = viewModel.imageURL ?: @"";
    item.stockQuantity = MAX(0, viewModel.itemQuantitiy);
    item.type = viewModel.modelType ?: @"";
    
    id model = viewModel.ModelObject;
    if ([model isKindOfClass:PetAccessory.class]) {
        PetAccessory *accessory = (PetAccessory *)model;
        item.stockQuantity = MAX(0, accessory.quantity);
    }
    if ([model respondsToSelector:@selector(providerID)]) {
        item.providerID = [model performSelector:@selector(providerID)];
    } else if ([model respondsToSelector:@selector(userID)]) {
        item.providerID = [model performSelector:@selector(userID)];
    } else if ([model respondsToSelector:@selector(ownerID)]) {
        item.providerID = [model performSelector:@selector(ownerID)];
    }
    
    [self saveItemForLater:item];
}

- (NSString *)pp_currentUserID
{
    NSString *userID = [FIRAuth auth].currentUser.uid;
    if (userID.length == 0) userID = UserManager.sharedManager.currentUser.ID;
    return userID ?: @"";
}

- (FIRDocumentReference *)pp_savedItemDocumentReferenceForUserID:(NSString *)userID
                                                          itemID:(NSString *)itemID
{
    FIRFirestore *db = [FIRFirestore firestore];
    return [[[[db collectionWithPath:@"UsersCol"]
              documentWithPath:userID]
             collectionWithPath:@"savedForLater"]
            documentWithPath:itemID];
}

- (void)pp_removeLocalItemID:(NSString *)itemID forUser:(NSString *)userID
{
    if (itemID.length == 0 || userID.length == 0) { return; }
    for (CartItem *existing in [_items copy]) {
        if ([existing.itemID isEqualToString:itemID]) {
            [_items removeObject:existing];
            break;
        }
    }
    [self persistForUser:userID];
}

- (void)removeItem:(CartItem *)item {
    if (!item || item.itemID.length == 0) return;

    NSString *userID = [self pp_currentUserID];
    if (userID.length == 0) return;

    // 1. Update local memory
    [self pp_removeLocalItemID:item.itemID forUser:userID];
    
    // 2. Delete from Firestore subcollection
    FIRDocumentReference *docRef = [self pp_savedItemDocumentReferenceForUserID:userID itemID:item.itemID];
    
    [docRef deleteDocumentWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ SavedForLater: Failed to delete from Firestore: %@", error.localizedDescription);
        }
    }];
}

- (void)removeItem:(CartItem *)item completion:(PPSaveForLaterRemoveCompletion _Nullable)completion
{
    if (!item || item.itemID.length == 0) {
        PPSaveForLaterCompleteOnMain(completion, PPSaveForLaterError(1001, @"Invalid saved item."));
        return;
    }

    NSString *userID = [self pp_currentUserID];
    if (userID.length == 0) {
        PPSaveForLaterCompleteOnMain(completion, PPSaveForLaterError(1002, @"A signed-in user is required."));
        return;
    }

    FIRDocumentReference *docRef = [self pp_savedItemDocumentReferenceForUserID:userID itemID:item.itemID];
    __weak typeof(self) weakSelf = self;
    [docRef deleteDocumentWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ SavedForLater: Failed to delete from Firestore: %@", error.localizedDescription);
            PPSaveForLaterCompleteOnMain(completion, error);
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) {
                [strongSelf pp_removeLocalItemID:item.itemID forUser:userID];
            }
            if (completion) {
                completion(nil);
            }
        });
    }];
}

- (BOOL)isItemSaved:(NSString *)itemID {
    if (itemID.length == 0) return NO;
    for (CartItem *existing in _items) {
        if ([existing.itemID isEqualToString:itemID]) {
            return YES;
        }
    }
    return NO;
}

- (void)clearAll {
    NSString *userID = [FIRAuth auth].currentUser.uid;
    if (userID.length == 0) userID = UserManager.sharedManager.currentUser.ID;
    if (userID.length == 0) return;
    
    NSArray<CartItem *> *itemsToDelete = [_items copy];
    [_items removeAllObjects];
    [self persistForUser:userID];
    
    FIRFirestore *db = [FIRFirestore firestore];
    for (CartItem *item in itemsToDelete) {
        FIRDocumentReference *docRef = [[[[db collectionWithPath:@"UsersCol"]
                                         documentWithPath:userID]
                                        collectionWithPath:@"savedForLater"]
                                       documentWithPath:item.itemID];
        [docRef deleteDocumentWithCompletion:nil];
    }
}

#pragma mark - Local Caching

- (void)postSavedForLaterUpdatedNotification {
    if (self.suppressSavedForLaterUpdateNotifications) {
        return;
    }

    dispatch_block_t notifyBlock = ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:PPSaveForLaterUpdatedNotification object:nil];
    };

    if ([NSThread isMainThread]) {
        notifyBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), notifyBlock);
    }
}

- (void)loadLocalCacheForUser:(NSString *)userID {
    if (userID.length == 0) return;
    NSString *userKey = [NSString stringWithFormat:@"PPSaveForLaterItemsKey_%@", userID];
    NSArray *array = [[NSUserDefaults standardUserDefaults] arrayForKey:userKey];
    [_items removeAllObjects];
    for (NSDictionary *dict in array) {
        if (![dict isKindOfClass:[NSDictionary class]]) continue;
        CartItem *item = [[CartItem alloc] init];
        item.itemID = dict[@"itemID"];
        item.name = dict[@"name"];
        item.price = [dict[@"price"] doubleValue];
        item.originalPrice = [dict[@"originalPrice"] doubleValue];
        item.imageURL = dict[@"imageURL"];
        item.providerID = dict[@"providerID"];
        item.type = [dict[@"type"] isKindOfClass:NSString.class] ? dict[@"type"] : @"";
        item.stockQuantity = PPSaveForLaterStockQuantityFromValue(dict[@"stockQuantity"]);
        item.quantity = MAX(1, [dict[@"quantity"] integerValue]);
        [_items addObject:item];
    }
    [self postSavedForLaterUpdatedNotification];
}

- (void)persistForUser:(NSString *)userID {
    if (userID.length == 0) return;
    NSString *userKey = [NSString stringWithFormat:@"PPSaveForLaterItemsKey_%@", userID];
    NSMutableArray *serialized = [NSMutableArray array];
    for (CartItem *item in _items) {
        NSMutableDictionary *dict = [@{
            @"itemID": item.itemID ?: @"",
            @"name": item.name ?: @"",
            @"price": @(item.price),
            @"originalPrice": @(item.originalPrice),
            @"imageURL": item.imageURL ?: @"",
            @"providerID": item.providerID ?: @"",
            @"quantity": @(item.quantity)
        } mutableCopy];
        if (item.type.length > 0) {
            dict[@"type"] = item.type;
        }
        if (item.stockQuantity != NSNotFound) {
            dict[@"stockQuantity"] = @(MAX(0, item.stockQuantity));
        }
        [serialized addObject:dict];
    }
    [[NSUserDefaults standardUserDefaults] setObject:serialized forKey:userKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self postSavedForLaterUpdatedNotification];
}

- (void)clearLocalAndMemory {
    [_items removeAllObjects];
    [self postSavedForLaterUpdatedNotification];
}

#pragma mark - Firestore Synchronization

- (void)startListeningToSavedForLaterChanges {
    NSString *userID = [FIRAuth auth].currentUser.uid;
    if (userID.length == 0) userID = UserManager.sharedManager.currentUser.ID;
    if (userID.length == 0) return;
    
    [self.savedForLaterListener remove];
    self.savedForLaterListener = nil;
    
    FIRFirestore *db = [FIRFirestore firestore];
    __weak typeof(self) weakSelf = self;
    
    self.savedForLaterListener =
    [[[[db collectionWithPath:@"UsersCol"]
       documentWithPath:userID]
      collectionWithPath:@"savedForLater"]
     addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ SavedForLater listener error: %@", error.localizedDescription);
            return;
        }
        if (!snapshot) return;
        
        NSMutableArray<CartItem *> *remoteItems = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            CartItem *item = [[CartItem alloc] init];
            item.itemID = doc.documentID;
            item.name = doc[@"name"] ?: @"";
            item.price = [doc[@"price"] doubleValue];
            item.originalPrice = [doc[@"originalPrice"] doubleValue];
            item.imageURL = doc[@"imageURL"] ?: @"";
            item.providerID = doc[@"providerID"] ?: @"";
            item.type = [doc[@"type"] isKindOfClass:NSString.class] ? doc[@"type"] : @"";
            item.stockQuantity = PPSaveForLaterStockQuantityFromValue(doc[@"stockQuantity"]);
            item.quantity = MAX(1, [doc[@"quantity"] integerValue]);
            [remoteItems addObject:item];
        }
        
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf updateLocalItems:remoteItems forUser:userID];
        }
    }];
}

- (void)stopListeningToSavedForLaterChanges {
    [self.savedForLaterListener remove];
    self.savedForLaterListener = nil;
}

- (void)updateLocalItems:(NSArray<CartItem *> *)remoteItems forUser:(NSString *)userID {
    [_items removeAllObjects];
    [_items addObjectsFromArray:remoteItems];
    [self persistForUser:userID];
}

@end
