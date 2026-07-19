#import "PPSaveForLaterManager.h"
#import "PPUniversalCellViewModel.h"
#import "UserManager.h"

static NSString * const PPSaveForLaterUpdatedNotification = @"PPSaveForLaterUpdatedNotification";

@interface PPSaveForLaterManager ()
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> savedForLaterListener;
@property (nonatomic, assign) FIRAuthStateDidChangeListenerHandle authStateHandle;
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
    if (![self isItemSaved:item.itemID]) {
        CartItem *itemCopy = [[CartItem alloc] init];
        itemCopy.itemID = item.itemID;
        itemCopy.name = item.name;
        itemCopy.price = item.price;
        itemCopy.originalPrice = item.originalPrice;
        itemCopy.imageURL = item.imageURL;
        itemCopy.providerID = item.providerID;
        itemCopy.quantity = 1;
        [_items addObject:itemCopy];
        [self persistForUser:userID];
    }
    
    // 2. Sync to Firestore subcollection: /UsersCol/{userID}/SavedForLaterCol/{itemID}
    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *docRef = [[[[db collectionWithPath:@"UsersCol"]
                                     documentWithPath:userID]
                                    collectionWithPath:@"SavedForLaterCol"]
                                   documentWithPath:item.itemID];
    
    NSDictionary *payload = @{
        @"itemID": item.itemID ?: @"",
        @"name": item.name ?: @"",
        @"price": @(item.price),
        @"originalPrice": @(item.originalPrice),
        @"imageURL": item.imageURL ?: @"",
        @"providerID": item.providerID ?: @"",
        @"quantity": @(1),
        @"timestamp": [FIRFieldValue fieldValueForServerTimestamp]
    };
    
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
    item.price = viewModel.finalPrice ? [viewModel.finalPrice doubleValue] : 0.0;
    item.originalPrice = viewModel.price ? [viewModel.price doubleValue] : 0.0;
    item.imageURL = viewModel.imageURL ?: @"";
    
    id model = viewModel.ModelObject;
    if ([model respondsToSelector:@selector(providerID)]) {
        item.providerID = [model performSelector:@selector(providerID)];
    } else if ([model respondsToSelector:@selector(userID)]) {
        item.providerID = [model performSelector:@selector(userID)];
    } else if ([model respondsToSelector:@selector(ownerID)]) {
        item.providerID = [model performSelector:@selector(ownerID)];
    }
    
    [self saveItemForLater:item];
}

- (void)removeItem:(CartItem *)item {
    if (!item || item.itemID.length == 0) return;
    
    NSString *userID = [FIRAuth auth].currentUser.uid;
    if (userID.length == 0) userID = UserManager.sharedManager.currentUser.ID;
    if (userID.length == 0) return;
    
    // 1. Update local memory
    for (CartItem *existing in [_items copy]) {
        if ([existing.itemID isEqualToString:item.itemID]) {
            [_items removeObject:existing];
            break;
        }
    }
    [self persistForUser:userID];
    
    // 2. Delete from Firestore subcollection
    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *docRef = [[[[db collectionWithPath:@"UsersCol"]
                                     documentWithPath:userID]
                                    collectionWithPath:@"SavedForLaterCol"]
                                   documentWithPath:item.itemID];
    
    [docRef deleteDocumentWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ SavedForLater: Failed to delete from Firestore: %@", error.localizedDescription);
        }
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
                                        collectionWithPath:@"SavedForLaterCol"]
                                       documentWithPath:item.itemID];
        [docRef deleteDocumentWithCompletion:nil];
    }
}

#pragma mark - Local Caching

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
        item.quantity = [dict[@"quantity"] integerValue];
        [_items addObject:item];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:PPSaveForLaterUpdatedNotification object:nil];
}

- (void)persistForUser:(NSString *)userID {
    if (userID.length == 0) return;
    NSString *userKey = [NSString stringWithFormat:@"PPSaveForLaterItemsKey_%@", userID];
    NSMutableArray *serialized = [NSMutableArray array];
    for (CartItem *item in _items) {
        NSDictionary *dict = @{
            @"itemID": item.itemID ?: @"",
            @"name": item.name ?: @"",
            @"price": @(item.price),
            @"originalPrice": @(item.originalPrice),
            @"imageURL": item.imageURL ?: @"",
            @"providerID": item.providerID ?: @"",
            @"quantity": @(item.quantity)
        };
        [serialized addObject:dict];
    }
    [[NSUserDefaults standardUserDefaults] setObject:serialized forKey:userKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:PPSaveForLaterUpdatedNotification object:nil];
}

- (void)clearLocalAndMemory {
    [_items removeAllObjects];
    [[NSNotificationCenter defaultCenter] postNotificationName:PPSaveForLaterUpdatedNotification object:nil];
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
      collectionWithPath:@"SavedForLaterCol"]
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
            item.quantity = [doc[@"quantity"] integerValue] ?: 1;
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
