//
//  AppManager.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 14/12/2024.
//

#import "AppManager.h"
#import "AppDelegate.h"
#import "FBLPromises.h"

@interface AppManager()

@end

@implementation AppManager

+ (FIRFirestore *)pp_configuredFirestoreInstance
{
    static FIRFirestore *sharedFirestore = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if ([FIRApp defaultApp] == nil) {
            [FIRApp configure];
        }

        sharedFirestore = [FIRFirestore firestore];

        FIRPersistentCacheIndexManager *indexManager = sharedFirestore.persistentCacheIndexManager;
        if (indexManager) {
            // Firestore persistence is already enabled by default in the current SDK.
            // Only keep the safe cache-index setup here so late AppManager init cannot
            // crash when another code path touched Firestore earlier in launch.
            [indexManager enableIndexAutoCreation];
        }
    });

    return sharedFirestore ?: [FIRFirestore firestore];
}

/*
 witch one load frist SceneDelegate or AppDelegate , and depends on best practices what should i use
 */
//DISK @synthesize DiskCache;
@synthesize formatter;
@synthesize dF;


static AppManager *sharedInstance = nil;
static NSInteger isListenStart = 0;
static NSInteger userDevIDUpdated = 0;
static NSInteger loadingCardFlag = 0;
// Get the shared instance and create it if necessary.



#pragma mark - Application Lifecycle Notifications

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    // U10: Re-enabled background listener cleanup to prevent leaked connections
    [self stopListeningForUsers];
    [self stoplistenerRegistration];
    [self stopListeningForArchives];
}

// Users Listener
- (void)stopListeningForArchives {
    [self stopAllListener];
}

// Users Listener
- (void)stoplistenerRegistration {
    if (self.listenerRegistration) {
        [self.listenerRegistration remove];
        self.listenerRegistration = nil;
        //NSLog(@"AppManager: Users listener removed.");
    }
}


- (void)applicationWillTerminate:(NSNotification *)notification {
    //NSLog(@"AppManager: Application terminating - removing listeners");
    [self stopListeningForUsers];
    
    [AppData stopAllListeners];
    
    [AppDataListenerManager.shared stopAllListeners];
}


- (void)stopAllListener {
    //NSLog(@"AppManager: Application terminating - removing listeners After Logot");
    [self stopListeningForUsers];
    [self stopListeningForTriggers];
    [AppData stopAllListeners];
    [AppDataListenerManager.shared stopAllListeners];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"stopAllListener" object:nil];
    
}



// Get the shared instance and create it if necessary.
+ (AppManager *)sharedInstance {
    static AppManager *sharedInstance = nil;
    static dispatch_once_t onceToken; // onceToken = 0
    
    dispatch_once(&onceToken, ^{
        //sharedInstance = [[AppManager alloc] init];
        sharedInstance = [[super allocWithZone:NULL] init];
        
        sharedInstance.formatter = [[ISO8601DateFormatter alloc] init];
        [sharedInstance.formatter setIncludeTime:YES];
 
        [[NSNotificationCenter defaultCenter] addObserver:sharedInstance
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:sharedInstance
                                                 selector:@selector(applicationWillTerminate:)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:sharedInstance
                                                 selector:@selector(stopAllListener)
                                                     name:@"stopAllListener"
                                                   object:nil];
        
    });
    return sharedInstance;
}

 
// return the shared instance
+ (id)allocWithZone:(NSZone *)zone
{
    return [self sharedInstance];
}

// Overriding the copyWithZone method to always
// return the same instance (since this is a singleton)
- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

// Implementing the init method to initialize any
// instance variables (if needed)
- (id)init
{
    self = [super init];
    if (self != nil) {
        dF = [AppManager pp_configuredFirestoreInstance];
        
        // --- U10: Migrate cachedUsers from NSUserDefaults to File System if needed ---
        NSArray *legacyCachedUsers = [[NSUserDefaults standardUserDefaults] objectForKey:kCachedUsersKey];
        if (legacyCachedUsers) {
            //NSLog(@"[Cache] 🚚 Migrating legacy users from NSUserDefaults to file system...");
            if (!self.usersArray) self.usersArray = [NSMutableArray array];
            for (NSDictionary *d in legacyCachedUsers) {
                UserModel *u = [[UserModel alloc] initWithDict:d];
                if (u) [self.usersArray addObject:u];
            }
            [self saveUsersToCache]; // Save to file
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:kCachedUsersKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        // -----------------------------------------------------------------------------

        // [self  deleteMyDataFromFirestore];
        //[self  compressImagesInFirebaseStorageFolder:@"/CardsImages"];
        
        __block int flag = 0;
        [self loadUsersDocuments:^(DataLoadingResult result) {
            if (result == DataLoadingResultSuccess) {
            } else {
            }
        }];
        
        
        if (flag == 0) {
            flag = 1;
            
                    [self scheduleDailyCheck];
                } else {
                    //NSLog(@"Failed to load all data!");
                    // Handle the error here
           
        }
        
        
    }
    
    return self;
}


-(void)setupAppConfiguration
{
    [self scheduleDailyCheck];
}

- (void)checkReminderDates {

    [[dF collectionWithPath:@"CagesCol"] getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
        if (error != nil) {
            //NSLog(@"Error getting documents: %@", error);
        } else {
            for (FIRDocumentSnapshot *document in snapshot.documents) {
                NSDictionary *data = document.data;
                
                //FIRTimestamp *ReminderDatetimestamp = data[@"ReminderDate"];
                NSDate *reminderDate = data[@"ReminderDate"];
                
                //NSLog(@"REMINDER ---- >>>>>> CageName : %@", data[@"CageName"]);
                
                // Compare reminderDate with current date
                if ([self isToday:reminderDate]) {
                    [self scheduleLocalNotificationForCage:data[@"CageName"]];
                }
            }
        }
    }];
}

- (void)scheduleLocalNotificationForCage:(NSString *)cageName {
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    
    //NSLog(@"REMINDER ---- >>>>>> scheduleLocalNotificationForCage : %@", cageName);
    content.title = kLang(@"Reminder");
    content.body = [NSString stringWithFormat:@"%@ %@",kLang(@"timeToCheck") , cageName];
    content.sound = [UNNotificationSound defaultSound];
    
    UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1 repeats:NO];
    
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:cageName content:content trigger:trigger];
    
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
        if (error != nil) {
            //NSLog(@"Error adding notification: %@", error);
        }
    }];
}

- (void)scheduleDailyCheck {
    
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:86400 target:self selector:@selector(checkReminderDates) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

- (BOOL)isToday:(NSDate *)date {
    //NSLog(@"REMINDER ---- >>>>>> isToday : %@", date);
    NSCalendar *calendar = [NSCalendar currentCalendar];
    return [calendar isDateInToday:date];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopListeningForUsers]; // Stop listening for UsersCol changes
    [self stopListeningForTriggers]; // Stop listening for trGCol changes

    [AppData stopAllListeners];
    
}


#pragma mark - Listener Management

// Users Listener
- (void)stopListeningForUsers {
    if (self.usersListener) {
        [self.usersListener remove];
        self.usersListener = nil;
        //NSLog(@"AppManager: Users listener removed.");
    }
}

// Trigger Listener
- (void)stopListeningForTriggers {
    if (self.triggerListener) {
        [self.triggerListener remove];
        self.triggerListener = nil;
        startListen = 0;
    }
}

/*
 - (void)loadUsersDocuments:(void (^)(DataLoadingResult result))completionHandler {
 //NSLog(@"AppManager Now Initializing ....... 🔄 Starting loadUsersDocuments...");
 
 FIRFirestore *db = [FIRFirestore firestore];
 UserID = UserManager.sharedManager.currentUser.ID;
 
 FIRCollectionReference *UsersColRef = [db collectionWithPath:@"UsersCol"];
 
 // Initialize usersArray if nil
 if (!self.usersArray) {
 //NSLog(@"AppManager Now Initializing ....... 📦 Initializing usersArray...");
 self.usersArray = [[NSMutableArray<UserModel *> alloc] init];
 }
 
 //NSLog(@"AppManager Now Initializing ....... 📡 Attaching Firestore listener to UsersCol...");
 
 // Add snapshot listener
 __weak typeof(self) weakSelf = self;
 self.usersListener = [UsersColRef addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
 __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return;
 
 if (error) {
 //NSLog(@"AppManager Now Initializing ....... ❌ Error listening to UsersCol: %@", error.localizedDescription);
 if (completionHandler) completionHandler(DataLoadingResultFailure);
 return;
 }
 if (!snapshot) {
 //NSLog(@"AppManager Now Initializing ....... ⚠️ Snapshot is nil for UsersCol.");
 if (completionHandler) completionHandler(DataLoadingResultFailure);
 return;
 }
 
 // Log source & pending writes
 NSString *source = snapshot.metadata.isFromCache ? @"CACHE" : @"SERVER";
 BOOL pending = snapshot.metadata.hasPendingWrites;
 //NSLog(@"AppManager Now Initializing ....... 📡 UsersCol snapshot source: %@ | pendingWrites: %@", source, pending ? @"YES" : @"NO");
 
 if (snapshot.documents.count == 0) {
 //NSLog(@"AppManager Now Initializing ....... 🪹 UsersCol has 0 documents.");
 }
 
 //NSLog(@"AppManager Now Initializing ....... 📥 Processing %lu user document changes...", (unsigned long)snapshot.documentChanges.count);
 
 // Process document changes
 for (FIRDocumentChange *change in snapshot.documentChanges) {
 FIRDocumentSnapshot *userDoc = change.document;
 //NSString *docID = userDoc.documentID;
 
 switch (change.type) {
 case FIRDocumentChangeTypeAdded: {
 //NSLog(@"AppManager Now Initializing ....... ➕ User ADDED docID: %@ (source: %@)", docID, source);
 UserModel *userModel = [[UserModel alloc] initWithSnapshot:userDoc];
 [strongSelf handleUserAdded:userModel];
 } break;
 
 case FIRDocumentChangeTypeModified: {
 //NSLog(@"AppManager Now Initializing ....... ✏️ User MODIFIED docID: %@ (source: %@)", docID, source);
 UserModel *userModel = [[UserModel alloc] initWithSnapshot:userDoc];
 [strongSelf handleUserModified:userModel];
 } break;
 
 case FIRDocumentChangeTypeRemoved: {
 //NSLog(@"AppManager Now Initializing ....... 🗑 User REMOVED docID: %@ (source: %@)", docID, source);
 UserModel *userModel = [[UserModel alloc] initWithSnapshot:userDoc];
 [strongSelf handleUserRemoved:userModel];
 } break;
 }
 }
 
 //NSLog(@"AppManager Now Initializing ....... 📊 usersArray now has %lu items.", (unsigned long)self.usersArray.count);
 
 // Call completion handler
 if (completionHandler) completionHandler(DataLoadingResultSuccess);
 }];
 }
 
 To Do :  First of all
 --->>>> if users cached locally
 if users cached locally dirct call this
 
 self.usersArray = cached users
 if (!didFireInitialCompletion) {
 didFireInitialCompletion = YES;
 if (completionHandler) completionHandler(DataLoadingResultSuccess);
 }
 after called completionHandler check if there is any updates on server and apply referesh cached users arr and keep it listen to add, updates , remove to apply it to cache
 
 
 
 To Do :  Second
 --->>>> if No Users Cached Locally
 if no users cached locally trigger the listener and set the cached users arr and users arr
 and also sure  keep it listen to add, updates , remove to apply it to cache
 
 
 
 */


- (void)loadUsersDocuments:(void (^)(DataLoadingResult result))completionHandler {
    // 0) reset listeners
    if (self.usersListener) { [self.usersListener remove]; self.usersListener = nil; }
  
    
    if (!self.usersArray) self.usersArray = [NSMutableArray array];
    else [self.usersArray removeAllObjects];
    
 
    __block BOOL didFireInitialCompletion = NO;
    FIRCollectionReference *UsersColRef = [dF collectionWithPath:@"PublicUserProfiles"];
    
    // 1) hydrate users from cache
    NSArray<UserModel *> *cachedUsers = [self loadUsersFromCache];
    if (cachedUsers.count) {
        [self.usersArray addObjectsFromArray:cachedUsers];
        NSLog(@"[Users] ✅ Applied cached users: %lu", (unsigned long)cachedUsers.count);
        
        if (!didFireInitialCompletion && completionHandler) {
            didFireInitialCompletion = YES;
            completionHandler(DataLoadingResultSuccess);
        }

        // Keep cached public profiles instead of attaching a broad listener that can
        // be invalidated by one legacy malformed document.
        return;
    }
    
    // 2) attach Firestore listener
    __weak typeof(self) weakSelf = self;
    self.usersListener = [UsersColRef addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf; if (!self) return;
        
        if (error || !snapshot) {
            NSLog(@"[Users] ⚠️ Public profiles unavailable, continuing without live refresh: %@",
                  error.localizedDescription ?: @"unknown");
            if (!didFireInitialCompletion && completionHandler) {
                didFireInitialCompletion = YES;
                completionHandler(DataLoadingResultSuccess);
            }
            return;
        }
        
        for (FIRDocumentChange *change in snapshot.documentChanges) {
            UserModel *user = [[UserModel alloc] initWithSnapshot:change.document];
            //NSString *uidKey = [self _keyForUser:user];
            
            switch (change.type) {
                case FIRDocumentChangeTypeAdded: {
                    //NSLog(@"[Users] ➕ Added: %@", user.UserName);
                    [self handleUserAdded:user];
                 } break;
                    
                case FIRDocumentChangeTypeModified: {
                    //NSLog(@"[Users] 🔄 Modified: %@", user.UserName);
                    [self handleUserModified:user];
                 } break;
                    
                case FIRDocumentChangeTypeRemoved: {
                    //NSLog(@"[Users] 🗑️ Removed: %@", user.UserName);
                    [self handleUserRemoved:user];
 
                } break;
            }
        }
        
        // persist latest users snapshot
        [self saveUsersToCache];
        
        if (!didFireInitialCompletion && completionHandler) {
            didFireInitialCompletion = YES;
            completionHandler(DataLoadingResultSuccess);
        }
    }];
}

- (NSString *)_keyForUser:(UserModel *)u {
    // Prefer your canonical document id (your code uses self.ID as doc id)
    return u.ID.length ? u.ID : (u.ID ?: @"");
}
 

// Helper to find the in-memory user object
- (UserModel *)userInArrayForID:(NSString *)userID {
    NSPredicate *p = [NSPredicate predicateWithFormat:@"ID == %@", userID];
    return [self.usersArray filteredArrayUsingPredicate:p].firstObject;
}



// MARK: - Cache Keys
static NSString * const kCachedUsersKey              = @"cachedUsers";
static NSString * const kCachedAddressesByUserKey    = @"cachedAddressesByUser";

// MARK: - Users cache

- (NSURL *)_usersCacheURL {
    NSURL *cacheDir = [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject];
    return [cacheDir URLByAppendingPathComponent:@"pp_users_v1.json"];
}

- (void)saveUsersToCache {
    NSMutableArray *arr = [NSMutableArray array];
    for (UserModel *u in self.usersArray) {
        if ([u respondsToSelector:@selector(toDictionary)]) {
            [arr addObject:[u toDictionary]];
        }
    }
    
    // U10: Move from NSUserDefaults to atomic file write
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:arr options:0 error:&error];
    if (data && !error) {
        [data writeToURL:[self _usersCacheURL] options:NSDataWritingAtomic error:&error];
        if (error) {
            NSLog(@"[Cache] ❌ Failed to write users to file: %@", error.localizedDescription);
        }
    } else {
        NSLog(@"[Cache] ❌ Failed to serialize users: %@", error.localizedDescription);
    }
}

- (NSArray<UserModel *> *)loadUsersFromCache {
    // U10: Read from file system instead of NSUserDefaults
    NSData *data = [NSData dataWithContentsOfURL:[self _usersCacheURL]];
    if (!data) return @[];
    
    NSError *error = nil;
    NSArray *raw = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error || ![raw isKindOfClass:NSArray.class]) {
        NSLog(@"[Cache] ⚠️ Failed to parse users cache file: %@", error.localizedDescription);
        return @[];
    }
    
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:raw.count];
    for (NSDictionary *d in raw) {
        UserModel *u = [[UserModel alloc] initWithDict:d];
        if (u) [out addObject:u];
    }
    return out;
}
 

// Call this on signout
- (void)clearAllUserCaches {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kCachedUsersKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kCachedAddressesByUserKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // U10: Also clear the cache file
    [[NSFileManager defaultManager] removeItemAtURL:[self _usersCacheURL] error:nil];
    //NSLog(@"[Cache] 🧹 Cleared users + addresses cache.");
}




#pragma mark - Handle Document Changes

- (void)handleUserAdded:(UserModel *)userModel {
    // Check if the user already exists in the array
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"ID == %@", userModel.ID];
    NSArray *filteredArray = [self.usersArray filteredArrayUsingPredicate:predicate];
    
    if([userModel.ID isEqualToString:PPCurrentUser.ID]){
        // NSLog(@"User added: %@", userModel.ID);
        // NSLog(@"UserID: %@", UserID);
        
        // Update PPUserTokenID and SubID for the current user
        //NSString *PPUserTokenID = [[NSUserDefaults standardUserDefaults] valueForKey:@"PPUserTokenID"];
        //[[UserManager sharedManager] updateCurrentUserWithDevID:PPUserTokenID];
    }
    
    if (filteredArray.count == 0) {
        [self.usersArray addObject:userModel];
        //NSLog(@"User added: %@", userModel.ID);
    }
}

- (void)handleUserModified:(UserModel *)userModel {
    // Find the user in the array and update it
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"ID == %@", userModel.ID];
    NSArray *filteredArray = [self.usersArray filteredArrayUsingPredicate:predicate];
    
    if (filteredArray.count > 0) {
        NSInteger index = [self.usersArray indexOfObject:filteredArray.firstObject];
        [self.usersArray replaceObjectAtIndex:index withObject:userModel];
        NSLog(@"User modified: %@", userModel.ID);
    }
}

- (void)handleUserRemoved:(UserModel *)userModel {
    // Remove the user from the array
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"ID == %@", userModel.ID];
    NSArray *filteredArray = [self.usersArray filteredArrayUsingPredicate:predicate];
    
    if (filteredArray.count > 0) {
        [self.usersArray removeObject:filteredArray.firstObject];
        NSLog(@"User removed: %@", userModel.ID);
    }
}
/*
 
 #pragma mark - Update Current User
 - (NSMutableArray<ChildModel *> *)TradhDocs
 {
     NSMutableArray<ChildModel *> *trashDocs = [[NSMutableArray<ChildModel *> alloc] init];
     for (CageModel *cage in self.AllCaGeDocs) {
         for (ChildModel *child in cage.DeletedChildsArray) {
             if (child.isDeleted == 1) {
                 child.cameFrom = CameFromChilds;
                 // [trashDocs addObject:child];
             }
         }
     }
     return trashDocs;
 }
 */

- (void)setImageUrlToCache:(NSString *)imageName imageUrl:(NSURL *)imageUrl
{
    
}

- (NSURL *)getImageUrlFromCache:(NSString *)imageName
{
    
    return nil;
    //DISK }
}

- (void)loadCardsDocuments:(void (^)(DataLoadingResult result))completionHandler {
    
    __block BOOL allPromisesSuccess = YES; // Track overall success.
    
    
}





/*
 
 - (void)loadBuyers:(void (^)(DataLoadingResult result))completionHandler {
     
     FIRCollectionReference *BuyersColRef = [dF collectionWithPath:@"BuyersCollection"];
     FIRQuery *BuyersColQuery = [BuyersColRef queryOrderedByField:@"sellDate" descending:NO];
     
     self.BuyerArray = [[NSMutableArray<BuyerModel *> alloc] init];
     
     __weak typeof(self) weakSelf = self; // Capture self weakly to avoid retain cycles
     
     self.BuyersListener = [BuyersColQuery addSnapshotListener:^(FIRQuerySnapshot *_Nullable snapshot, NSError *_Nullable error) {
         // //NSLog(@"AppManager: Start Listening For Buyers");
         if (error) {
             NSLog(@"Error fetching Buyers: %@", error.localizedDescription);
             completionHandler(DataLoadingResultFailure); // Indicate failure
             return;
         }
         
         if (snapshot.documents.count == 0) {
             NSLog(@"No Buyers found");
             completionHandler(DataLoadingResultSuccess); // Indicate no data
             if (loadingCardFlag == 0) {
                 loadingCardFlag = 1;
             }
             return;
         }
         
         
         for (FIRDocumentChange *dc in snapshot.documentChanges) {
             BuyerModel *B_Model = [BuyerModel buyerFromDictionary:dc.document.data];
             
             switch (dc.type) {
                 case FIRDocumentChangeTypeAdded:
                     [weakSelf handleBuyerAdded:B_Model];
                     break;
                     
                 case FIRDocumentChangeTypeModified:
                     [weakSelf handleBuyerModified:B_Model];
                     break;
                     
                 case FIRDocumentChangeTypeRemoved:
                     [weakSelf handleBuyerRemoved:B_Model];
                     break;
             }
         }
         
         completionHandler(DataLoadingResultSuccess); // Indicate success (data loaded or updated)
     }];
 }
 
 
 - (void)handleBuyerRemoved:(BuyerModel *)b_Model
 {
     for (int i = 0; i < self.BuyerArray.count; i++) {
         BuyerModel *buyerM = self.BuyerArray[i];
         if ([buyerM.ID isEqualToString:b_Model.ID]) {
             [self.BuyerArray removeObjectAtIndex:i];
             break;
         }
     }
     
     if(loadingCardFlag == 1)
     {
         if([b_Model.UserID isEqualToString:PPCurrentUser.ID])
             [self refreshSalesVC];
     }
 }
 #pragma mark - Helper Methods for Updating Arrays

 - (void)handleBuyerAdded:(BuyerModel *)b_Model {
     
     
     if ([b_Model.UserID isEqualToString:PPCurrentUser.ID])
     {
         //    NSLog(@"TRIGER ------>>>>>> Buyer: %@  PPCurrentUser.ID: %@  ADEEEEEEEEEEEEEEED", b_Model.UserID,PPCurrentUser.ID);
         [self.BuyerArray insertObject:b_Model atIndex:0];
     }
     
     if(loadingCardFlag == 1)
     {
         if([b_Model.UserID isEqualToString:PPCurrentUser.ID])
             [self refreshSalesVC];
     }
     
 }

 - (void)handleBuyerModified:(BuyerModel *)b_Model {
     
     // Modify in UserCardsDocs (if applicable) // && modifiedCardModel.cardInfo == 1
     if ([b_Model.UserID isEqualToString:PPCurrentUser.ID]) {
         BOOL foundInUserCards = NO;
         for (int i = 0; i < self.BuyerArray.count; i++) {
             BuyerModel *buyerM = self.BuyerArray[i];
             if ([buyerM.ID isEqualToString:b_Model.ID]) {
                 
                 [self.BuyerArray replaceObjectAtIndex:i withObject:b_Model];
                 foundInUserCards = YES;
                 break;
             }
         }
         if (!foundInUserCards) {
             [self.BuyerArray insertObject:b_Model atIndex:0];
         }
         
     } else {
         // Remove from UserCardsDocs if no longer matching the filter
         for (int i = 0; i < self.BuyerArray.count; i++) {
             BuyerModel *buyerM = self.BuyerArray[i];
             if ([buyerM.ID isEqualToString:b_Model.ID]) {
                 [self.BuyerArray removeObjectAtIndex:i];
                 break;
             }
         }
     }
     
     if([b_Model.UserID isEqualToString:PPCurrentUser.ID])
         [self refreshSalesVC];
 }
- (void)loadCards:(void (^)(DataLoadingResult result))completionHandler {
    
    

 
 #pragma mark - Helper Methods for Updating Arrays

 - (void)handleCardAdded:(CardModel *)cardModel {
     
     if(![self.AllCardsDocs containsObject:cardModel] && [self.AllCardsDocs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@", cardModel.ID]].count == 0)
         [self.AllCardsDocs insertObject:cardModel atIndex:0];
     
     // && cardModel.cardInfo == 1
     
     if (![self.UserCardsDocs containsObject:cardModel] &&
         [cardModel.UserID isEqualToString:PPCurrentUser.ID] &&
         cardModel.isDeleted == 0 &&
         [self.UserCardsDocs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@", cardModel.ID]].count == 0 &&
         cardModel.isSold != 1) {
         [self.UserCardsDocs insertObject:cardModel atIndex:0];
         
     }
     
     if (![self.DeletedCardsDocs containsObject:cardModel] &&  [cardModel.UserID isEqualToString:PPCurrentUser.ID] && cardModel.isDeleted == 1 &&
         [self.DeletedCardsDocs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@", cardModel.ID]].count == 0 && cardModel.isSold != 1) {
         [self.DeletedCardsDocs insertObject:cardModel atIndex:0];
     }
     
     if(loadingCardFlag == 1)
     {
         if([cardModel.UserID isEqualToString:PPCurrentUser.ID])
             [self refreshViewController];
     }
     
 }

 - (void)handleCardModified:(CardModel *)modifiedCardModel {
     self.dataChanged = 1;
     // Modify in AllCardsDocs
     for (int i = 0; i < self.AllCardsDocs.count; i++) {
         CardModel *card = self.AllCardsDocs[i];
         if ([card.ID isEqualToString:modifiedCardModel.ID]) {
             [self.AllCardsDocs replaceObjectAtIndex:i withObject:modifiedCardModel];
             break;
         }
     }
     
     // Modify in UserCardsDocs (if applicable) // && modifiedCardModel.cardInfo == 1
     if ([modifiedCardModel.UserID isEqualToString:PPCurrentUser.ID] && modifiedCardModel.isDeleted == 0 && modifiedCardModel.isSold == 0) {
         BOOL foundInUserCards = NO;
         for (int i = 0; i < self.UserCardsDocs.count; i++) {
             CardModel *card = self.UserCardsDocs[i];
             if ([card.ID isEqualToString:modifiedCardModel.ID]) {
                 [self.UserCardsDocs replaceObjectAtIndex:i withObject:modifiedCardModel];
                 foundInUserCards = YES;
                 break;
             }
         }
         if (!foundInUserCards) {
             [self.UserCardsDocs insertObject:modifiedCardModel atIndex:0];
         }
         
     } else {
         // Remove from UserCardsDocs if no longer matching the filter
         for (int i = 0; i < self.UserCardsDocs.count; i++) {
             CardModel *card = self.UserCardsDocs[i];
             if ([card.ID isEqualToString:modifiedCardModel.ID]) {
                 [self.UserCardsDocs removeObjectAtIndex:i];
                 break;
             }
         }
     }
     
     // Modify in DeletedCardsDocs (if applicable)
     if ([modifiedCardModel.UserID isEqualToString:PPCurrentUser.ID] && modifiedCardModel.isDeleted == 1) {
         BOOL foundInDeletedCards = NO;
         for (int i = 0; i < self.DeletedCardsDocs.count; i++) {
             CardModel *card = self.DeletedCardsDocs[i];
             if ([card.ID isEqualToString:modifiedCardModel.ID]) {
                 [self.DeletedCardsDocs replaceObjectAtIndex:i withObject:modifiedCardModel];
                 foundInDeletedCards = YES;
                 break;
             }
         }
         if (!foundInDeletedCards) {
             [self.DeletedCardsDocs insertObject:modifiedCardModel atIndex:0];
         }
         
     } else {
         // Remove from DeletedCardsDocs if no longer matching the filter
         for (int i = 0; i < self.DeletedCardsDocs.count; i++) {
             CardModel *card = self.DeletedCardsDocs[i];
             if ([card.ID isEqualToString:modifiedCardModel.ID]) {
                 [self.DeletedCardsDocs removeObjectAtIndex:i];
                 break;
             }
         }
     }
     if([modifiedCardModel.UserID isEqualToString:PPCurrentUser.ID])
         [self refreshViewController];
 }

 - (void)handleCardRemoved:(CardModel *)removedCardModel {
     // Remove from AllCardsDocs
     for (int i = 0; i < self.AllCardsDocs.count; i++) {
         CardModel *card = self.AllCardsDocs[i];
         if ([card.ID isEqualToString:removedCardModel.ID]) {
             [self.AllCardsDocs removeObjectAtIndex:i];
             break;
         }
     }
     
     // Remove from UserCardsDocs
     for (int i = 0; i < self.UserCardsDocs.count; i++) {
         CardModel *card = self.UserCardsDocs[i];
         if ([card.ID isEqualToString:removedCardModel.ID]) {
             [self.UserCardsDocs removeObjectAtIndex:i];
             break;
         }
     }
     
     // Remove from DeletedCardsDocs
     for (int i = 0; i < self.DeletedCardsDocs.count; i++) {
         CardModel *card = self.DeletedCardsDocs[i];
         if ([card.ID isEqualToString:removedCardModel.ID]) {
             [self.DeletedCardsDocs removeObjectAtIndex:i];
             break;
         }
     }
     
     if([removedCardModel.UserID isEqualToString:PPCurrentUser.ID])
         [self refreshViewController];
 }
 */

- (void)refreshViewController
{
    
}


- (void)refreshSalesVC
{
    
}

/*
 
 - (void)loadCagesDocuments:(void (^)(DataLoadingResult result))completionHandler {
     FIRSnapshotListenOptions *options = [[FIRSnapshotListenOptions alloc] init];
     FIRSnapshotListenOptions *optionsWithSourceAndMetadata = [options optionsWithIncludeMetadataChanges:YES];
     
     FIRCollectionReference *CagesColRef = [dF collectionWithPath:@"CagesCol"];
     FIRQuery *CagesQuery = [[CagesColRef queryWhereField:@"UserID" isEqualTo:PPCurrentUser.ID] queryOrderedByField:@"CreateDate" descending:NO];
     
     self.AllCaGeDocs = [[NSMutableArray<CageModel *> alloc] init];
     self.TradhDocs = [[NSMutableArray<ChildModel *> alloc] init]; // Not used in the function, consider removing if not needed.
     
     __weak typeof(self) weakSelf = self; // Avoid retain cycles with block capture
     
     self.cagesListener = [CagesQuery addSnapshotListenerWithOptions:optionsWithSourceAndMetadata
                                                            listener:^(FIRQuerySnapshot *_Nullable snapshot, NSError *_Nullable error) {
         //NSLog(@"AppManager: Start Listening For Cages");
         if (error != nil) {
             NSLog(@"Error listening to cages documents: %@", error.localizedDescription);
             completionHandler(DataLoadingResultFailure);
             return;
         }
         
         if (!snapshot || snapshot.documentChanges.count == 0) {
             NSLog(@"No changes in snapshot or empty snapshot");
             completionHandler(DataLoadingResultSuccess); // Handle case where no changes means success
             return;
         }
         
         __strong typeof(weakSelf) strongSelf = weakSelf; // Use strong self inside the block
         
         for (FIRDocumentChange *dc in snapshot.documentChanges) {
             switch (dc.type) {
                 case FIRDocumentChangeTypeAdded:
                     [strongSelf handleCageAdded:dc.document];
                     break;
                 case FIRDocumentChangeTypeModified:
                     [strongSelf handleCageModified:dc.document];
                     break;
                 case FIRDocumentChangeTypeRemoved:
                     [strongSelf handleCageRemoved:dc.document];
                     break;
             }
         }
         
         //NSLog(@"AppManager >> Finished load AllCaGeDocs Documents %ld", strongSelf.AllCaGeDocs.count);
         completionHandler(DataLoadingResultSuccess);
     }];
 }
 - (void)handleCageAdded:(FIRDocumentSnapshot *)document {
     
     CageModel *cageModel = [[CageModel alloc] initWithSnapshot:document];
     //NSLog(@"TRIGER Added ------>>>>>> CageModel %@ Name %@ ",cageModel.ID,cageModel.CageName);
     
     if (cageModel.isDeleted == 0) {
         [self.AllCaGeDocs insertObject:cageModel atIndex:0];
     }
     
     if(loadingCardFlag == 1)
     {
         [self refreshViewController];
         return;
     }
     
     
     
     
 }
 - (void)handleCageModified:(FIRDocumentSnapshot *)document {
     
     CageModel *modifiedCage = [[CageModel alloc] initWithSnapshot:document];
     NSLog(@"TRIGER Modified ------>>>>>> CageModel %@ Name %@ ",modifiedCage.ID,modifiedCage.CageName);
     
     NSUInteger index = [self.AllCaGeDocs indexOfObjectPassingTest:^BOOL(CageModel *obj, NSUInteger idx, BOOL *stop) {
         return [obj.ID isEqualToString:modifiedCage.ID];
     }];
     if (index != NSNotFound) {
         if (modifiedCage.isDeleted == 1) {
             [self.AllCaGeDocs removeObjectAtIndex:index];
         }else{
             [self.AllCaGeDocs replaceObjectAtIndex:index withObject:modifiedCage];
         }
         [self refreshViewController];
     }
 }
 - (void)handleCageRemoved:(FIRDocumentSnapshot *)document {
     CageModel *removedCage = [[CageModel alloc] initWithSnapshot:document];
     NSLog(@"TRIGER Removed ------>>>>>> CageModel %@ Name %@ ",removedCage.ID,removedCage.CageName);
     
     NSUInteger index = [self.AllCaGeDocs indexOfObjectPassingTest:^BOOL(CageModel *obj, NSUInteger idx, BOOL *stop) {
         return [obj.ID isEqualToString:removedCage.ID];
     }];
     if (index != NSNotFound) {
         [self.AllCaGeDocs removeObjectAtIndex:index];
         [self refreshViewController];
     }
 }


 - (void)loadArchivesDocuments:(void (^)(DataLoadingResult result))completionHandler {
     
     FIRSnapshotListenOptions *options = [[FIRSnapshotListenOptions alloc] init];
     FIRSnapshotListenOptions *optionsWithSourceAndMetadata = [options optionsWithIncludeMetadataChanges:YES];
     
     FIRCollectionReference *ArchiveColRef = [dF collectionWithPath:@"ArchiveCol"];
     FIRQuery *ArchiveColQuery = [ArchiveColRef queryWhereField:@"archiveOwnerID" isEqualTo:PPCurrentUser.ID];
     
     self.ArchivesDocs = [[NSMutableArray<ArchiveModel *> alloc] init];
     
     __weak typeof(self) weakSelf = self;
     
     self.archivesListener = [ArchiveColQuery addSnapshotListenerWithOptions:optionsWithSourceAndMetadata
                                                                    listener:^(FIRQuerySnapshot *_Nullable snapshot, NSError *_Nullable error) {
         //NSLog(@"AppManager: Start Listening For Archives");
         if (error) {
             NSLog(@"Error listening to archive documents: %@", error.localizedDescription);
             completionHandler(DataLoadingResultFailure);
             return;
         }
         
         if (!snapshot) {
             NSLog(@"Error snapshot is nil");
             completionHandler(DataLoadingResultFailure);
             return;
         }
         
         
         for (FIRDocumentChange *dc in snapshot.documentChanges) {
             ArchiveModel *archiveModel = [[ArchiveModel alloc] initWithSnapshot:dc.document];
             
             switch (dc.type) {
                 case FIRDocumentChangeTypeAdded: {
                     //NSLog(@"TRIGER ------>>>>>> ArchiveModel FIRDocumentChangeTypeAdded for Archive %@",archiveModel.archiveTitle);
                     if(archiveModel.isDeleted == 0)
                         [weakSelf.ArchivesDocs addObject:archiveModel];
                     break;
                 }
                 case FIRDocumentChangeTypeModified: {
                     NSLog(@"TRIGER ------>>>>>> ArchiveModel FIRDocumentChangeTypeModified for Archive %@",archiveModel.archiveTitle);
                     
                     NSUInteger index = [self indexOfArchiveWithID:archiveModel.ID];
                     
                     if (index != NSNotFound) {
                         [weakSelf.ArchivesDocs replaceObjectAtIndex:index withObject:archiveModel];
                         if(archiveModel.isDeleted == 1)
                             [weakSelf.ArchivesDocs removeObject:archiveModel];
                     } else {
                         NSLog(@"Modified document not found in local array"); // Log if not found
                     }
                     break;
                     
                 }
                 case FIRDocumentChangeTypeRemoved: {
                     //NSLog(@"TRIGER ------>>>>>> ArchiveModel FIRDocumentChangeTypeRemoved for Archive %@",archiveModel.archiveTitle);
                     NSUInteger index = [self indexOfArchiveWithID:archiveModel.ID];
                     
                     if (index != NSNotFound) {
                         [weakSelf.ArchivesDocs removeObjectAtIndex:index];
                         NSLog(@"Archive Removes Succsess"); // Log if not found
                     } else {
                         NSLog(@"Removed document not found in local array"); // Log if not found
                     }
                     break;
                 }
             }
         }
         
         //NSLog(@"AppManager-->> Updated Archive Documents Count: %ld", weakSelf.ArchivesDocs.count);
         
         completionHandler(DataLoadingResultSuccess);
     }];
 }



 - (NSUInteger)indexOfArchiveWithID:(NSString *)archiveID {
     for (NSUInteger i = 0; i < self.ArchivesDocs.count; i++) {
         if ([self.ArchivesDocs[i].ID isEqualToString:archiveID]) {
             return i;
         }
     }
     return NSNotFound;
 }

 */



//Get Sub Kinds Array From MainKinds By subKindsID



/*
 - (void)loadMainDataCompletionHandler:(void (^)(int result))completionHandler
 {
 
 __block MainKindsModel *main;
 FIRSnapshotListenOptions *options = [[FIRSnapshotListenOptions alloc] init];
 FIRSnapshotListenOptions *optionsWithSourceAndMetadata = [options optionsWithIncludeMetadataChanges:YES];
 [[[dF collectionWithPath:@"MainKindsCollection"] queryOrderedByField:@"ID" descending:NO] addSnapshotListenerWithOptions:optionsWithSourceAndMetadata
 listener:^(FIRQuerySnapshot *_Nullable snapshot, NSError *_Nullable error) {
 if (error != nil) {
 NSLog(@"Error Getting Data: %@", error);
 return;
 }
 //NSLog(@"snapshot.documentChanges %lu",(unsigned long)snapshot.documentChanges.count);
 for (FIRDocumentChange *dc in snapshot.documentChanges) {
 
 
 if (dc.type == FIRDocumentChangeTypeAdded) {
 //if(self.MainKindsArray.count > 0)
 //    return;
 main = [[MainKindsModel alloc] initWithSnapshot:dc.document];
 
 
 [self.MainKindsArray addObject:main];
 }
 
 if (dc.type == FIRDocumentChangeTypeModified) {
 //NSString *source = snapshot.metadata.isFromCache ? @"local cache" : @"server";
 // //NSLog(@"AppManager MainKindsModel >> -------  FIRDocumentChangeTypeModified SOURCE:  %@", source);
 }
 
 if (dc.type == FIRDocumentChangeTypeRemoved) {
 //NSString *source = snapshot.metadata.isFromCache ? @"local cache" : @"server";
 ////NSLog(@"AppManager MainKindsModel >> -------  FIRDocumentChangeTypeModified SOURCE:  %@", source);
 }
 
 if(dc == snapshot.documentChanges.lastObject)
 completionHandler(1);
 
 }
 
 //if (dc.type == FIRDocumentChangeTypeAdded) { }
 }];
 
 }
 */





- (NSString *)managerStringfromDate:(NSDate *)date
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    
    [dateFormatter setDateFormat:@"dd-MM-yyyy"];
    NSLocale *locale = [[NSLocale alloc]
                        initWithLocaleIdentifier:@"en"];
    [dateFormatter setLocale:locale];
    return [dateFormatter stringFromDate:date];
}

- (UIViewController *)topViewController {
    return [self topViewController:[UIApplication sharedApplication].keyWindow.rootViewController];
}

- (UIViewController *)topViewController:(UIViewController *)rootViewController
{
    if ([rootViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = (UINavigationController *)rootViewController;
        return [self topViewController:[navigationController.viewControllers lastObject]];
    }
    
    if ([rootViewController isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tabController = (UITabBarController *)rootViewController;
        return [self topViewController:tabController.selectedViewController];
    }
    
    if (rootViewController.presentedViewController) {
        return [self topViewController:rootViewController.presentedViewController];
    }
    
    return rootViewController;
}

- (UIFont *)fontSize:(float)size
{
    return [UIFont fontWithName:@"Beiruti-Medium" size:size + 1];
    
}

- (UIFont *)boldFontSize:(float)size
{
    return [UIFont fontWithName:@"Beiruti-Bold" size:size + 1];
    
}

//  ******************************************************** GLOBAL DATA


int startListen = 0;
- (void)setListener
{
    // return;
    
    __block NSString *userID = UserManager.sharedManager.currentUser.ID;
    
    //return;
    if (startListen == 1) {
        return;
    }
    
    startListen = 1;
    // // NSLog(@"TRIGER ------>>>>>>  START LISTENING");
     FIRCollectionReference *MslListener = [dF collectionWithPath:@"trGCol"];
    
    self.triggerListener =
    [MslListener addSnapshotListenerWithIncludeMetadataChanges:YES
                                                      listener:^(FIRQuerySnapshot *_Nullable snapshot, NSError *_Nullable error) {
        if (error != nil) {
            NSLog(@"Error getting documents: %@", error);
            return;
        }
        
        for (FIRDocumentChange *dc in snapshot.documentChanges) {
            if (dc.type == FIRDocumentChangeTypeModified) {
                // // NSLog(@"TRIGER ------>>>>>>  NEW GARD ADDED , CONTROLLER REFERSHING NOW");
                NSString *cardID = dc.document.data[@"cardID"];
                NSString *firstUserID = dc.document.data[@"firstUserID"];
                NSString *secUserID = dc.document.data[@"secUserID"];
                NSInteger showing = [dc.document.data[@"showing"] integerValue];
                
                //NSString *trigerFor = dc.document.data[@"trigerFor"];
                NSLog(@"TRIGER ------->>>> dc.document.data %@", dc.document.data);
                
                if ([firstUserID isEqualToString:PPCurrentUser.ID] || [secUserID isEqualToString:PPCurrentUser.ID]) {
                    if ([NSStringFromClass([[self topViewController] class]) isEqualToString:@"ViewController"]) {
                     ///   [self loadCardsDocuments:^(DataLoadingResult result) {
                           
                            
                            if ([firstUserID isEqualToString:userID] && showing == 0) {
                                //UserModel *byerUser = [[self.usersArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@", secUserID]] firstObject];
                                
                                //CardModel *sharedChard = [[[AppManager sharedInstance].AllCardsDocs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@", cardID]] firstObject];
                                
                                //[self postLocalNotification:@"تم قبول البطاقة"  alertBody:[NSString stringWithFormat:@"لقد قام %@ بقول البطاقة (%@) التي قمت بارسالها الية", byerUser.UserName, sharedChard.CardTitle]];
                                
                                [self updateCardTriger:cardID values:@{ @"showing": @1 }];
                            }
                       // }];
                    }
                }
            }
        }
    }];
}

- (void)postLocalNotification:(NSString *)title alertBody:(NSString *)alertBody
{
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.fireDate = [NSDate date];
    notification.alertTitle = title;
    notification.soundName = @"donesound.mp3";
    notification.alertBody = alertBody;
    //[[UIApplication sharedApplication] scheduleLocalNotification:notification];
    [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
}

- (void)updateCardTriger:(NSString *)collectionPath values:(NSDictionary *)dictValues
{
    FIRCollectionReference *collectionRef = [dF collectionWithPath:@"trGCol"];
    
    // Perform a transaction
    [dF runTransactionWithBlock:^id _Nullable (FIRTransaction *_Nonnull transaction, NSError *__autoreleasing _Nullable *_Nullable error) {
        [transaction updateData:dictValues forDocument:[collectionRef documentWithPath:collectionPath]];
        return transaction;
    }
                                           completion:^(id _Nullable result, NSError *_Nullable error) { }];
}
 
- (void)setFirImageToPath:(NSString *)folderName andImageName:(NSString *)imageName toImageView:(UIImageView *)imgView
{
    // UsersImages
    FIRStorage *storage = [FIRStorage storage];
    FIRStorageReference *storageRef = [storage reference];
    // Create a reference to the file you want to download
    NSString *str = [NSString stringWithFormat:@"%@/%@", folderName, imageName];
    FIRStorageReference *starsRef = [storageRef child:str];
    
    // Fetch the download URL
    [starsRef downloadURLWithCompletion:^(NSURL *URL, NSError *error) {
        if (error != nil) {
            // Handle any errors
            NSLog(@"Error Getting Image From Fire Storage -->> Image Name Is: %@", imageName);
        } else {
            // Get the download URL for 'images/stars.jpg'
            [[SDWebImageManager sharedManager] loadImageWithURL:URL
                                                        options:SDWebImageProgressiveLoad | SDWebImageScaleDownLargeImages
                                                       progress:nil
                                                      completed:^(UIImage *_Nullable image, NSData *_Nullable data, NSError *_Nullable error, SDImageCacheType cacheType, BOOL finished, NSURL *_Nullable imageURL) {
                imgView.image = image;
            }];
        }
    }];
}

- (NSDate *)MsgDateFromStr:(NSString *)msgDateStr
{
    return [self.formatter dateFromString:msgDateStr];
}

- (NSString *)MsgStrFtromDate:(NSDate *)msgDate
{
    return [self.formatter stringFromDate:msgDate];
}

- (void)setCornerRadius:(CGFloat)radius withOpacity:(CGFloat)opacity shadowOffset:(CGFloat)offset shadowRadius:(CGFloat)sharowRadis onView:(UIView *)view color:(UIColor *)color {
    view.layer.cornerRadius = radius;
    
    view.layer.shadowColor = color.CGColor;
    view.layer.shadowOpacity = opacity;
    view.layer.shadowOffset = CGSizeMake(-(offset), offset);
    view.layer.shadowRadius = sharowRadis;
    view.layer.shouldRasterize = NO;
    view.layer.shadowPath = [[UIBezierPath bezierPathWithRoundedRect:[view bounds] cornerRadius:radius] CGPath];
    
    view.layer.masksToBounds = !shadow;
}

- (void)setBasicData
{
    /*  return;
     NSMutableArray *MainDict = [[NSMutableArray alloc]  init];
     
     for (MainKindsModel *mainKind in self.MainKindsArray) {
     
     NSMutableDictionary *Dict = [mainKind toFirestoreDictionary].mutableCopy;
     
     
     NSMutableDictionary *SubKindsArray = [[NSMutableDictionary alloc]  init];
     for (SubKindModel *subKindModel in mainKind.SubKindsArray) {
     
     NSMutableDictionary *subKindDict = [subKindModel yy_modelToJSONObject];
     
     
     NSMutableDictionary *subSubKindArray = [[NSMutableDictionary alloc]  init];
     for (subSubKindModel *sub_SubKindModel in subKindModel.subSubKindArray) {
     
     NSMutableDictionary *subSubKindDict = [sub_SubKindModel yy_modelToJSONObject];
     [subSubKindDict setValue:@(sub_SubKindModel.ID) forKey:@"ID"];
     [subSubKindDict setValue:@(sub_SubKindModel.subKindID) forKey:@"subKindID"];
     [subSubKindDict setValue:sub_SubKindModel.nameAr forKey:@"nameAr"];
     [subSubKindDict setValue:sub_SubKindModel.nameEn forKey:@"nameEn"];
     
     
     NSMutableDictionary *subKindItemsArray = [[NSMutableDictionary alloc]  init];
     for (subKindItemsModel *subItemModel in sub_SubKindModel.subKindItemsArray) {
     
     NSMutableDictionary *subItemDict = [[NSMutableDictionary alloc]  init];
     [subItemDict setValue:@(subItemModel.ID) forKey:@"ID"];
     [subItemDict setValue:@(subItemModel.subSubKindID) forKey:@"subSubKindID"];
     [subItemDict setValue:subItemModel.itemNameAr forKey:@"itemNameAr"];
     [subItemDict setValue:subItemModel.itemNameEn forKey:@"itemNameEn"];
     [subItemDict setValue:subItemModel.Male forKey:@"Male"];
     [subItemDict setValue:subItemModel.Female forKey:@"Female"];
     
     [subKindItemsArray setValue:subItemDict forKey:[NSString stringWithFormat:@"%ld",subItemModel.ID]];
     
     }
     
     
     [subSubKindDict setValue:subKindItemsArray forKey:@"subKindItemsArray"];
     [subSubKindArray setValue:subSubKindDict forKey:[NSString stringWithFormat:@"%ld",sub_SubKindModel.ID]];
     }
     
     
     [subKindDict setValue:subSubKindArray forKey:@"subSubKindArray"];
     [SubKindsArray setValue:subKindDict forKey:[NSString stringWithFormat:@"%ld",subKindModel.ID]];
     }
     
     [Dict setValue:SubKindsArray forKey:@"SubKindsArray"];
     [MainDict addObject:Dict];
     //[MainDict setValue:Dict forKey:[NSString stringWithFormat:@"%ld",mainKind.ID]];
     }
     FIRCollectionReference *MainKindsCollection = [dF collectionWithPath:@"MainKindsCollectionTemp"];
     for (MainKindsModel *dict in self.MainKindsArray) {
     NSLog(@"Dict %@",dict);
     NSDictionary *mydic = [dict yy_modelToJSONObject];
     [[MainKindsCollection documentWithPath:[NSString stringWithFormat:@"%ld",dict.ID]] setData:mydic];
     }
     */
    
    
}

- (void)showSnakBar:(NSString *)message withColor:(UIColor *)color andDuration:(float)duration containerView:(UIView *)containerView
{
    self.snakBar = [[TTGSnackbar alloc]initWithMessage:[NSString stringWithFormat:@"%@", message] duration:duration];
    [self.snakBar setAnimationType:TTGSnackbarAnimationTypeSlideFromTopBackToTop];
    self.snakBar.containerView = containerView;
    [self.snakBar setMessageTextAlign:NSTextAlignmentCenter];
    [self.snakBar setMessageTextFont:[self fontSize:16]];
    [self.snakBar setCornerRadius:20];
    self.snakBar.shouldDismissOnSwipe = YES;
    self.snakBar.snackbarMaxWidth = containerView.frame.size.width - 60;
    [self.snakBar setIconTintColor:[UIColor whiteColor]];
    [self.snakBar setBackgroundColor:color];
    
    [self.snakBar show];
}


+ (void)showSnakBar:(NSString *)message withColor:(UIColor *)color andDuration:(float)duration containerView:(UIView *)containerView
{
    
    [self showSnakBar:message withColor:color andDuration:duration containerView:containerView];
}


-(void)FetchStories
{
     FIRCollectionReference *storiesRef = [dF collectionWithPath:@"stories"];
    FIRQuery *query = [storiesRef queryWhereField:@"expiresAt" isGreaterThan:[NSDate date]];
    
    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error fetching stories: %@", error.localizedDescription);
            return;
        }
        for (FIRDocumentSnapshot *document in snapshot.documents) {
            NSDictionary *storyData = document.data;
            NSLog(@"Story: %@", storyData);
            // Update UI with story data
        }
    }];
    
}

-(NSString *)formatDateFromDate:(NSDate *)date
{
    NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"dd-MM-yyyy"];
    [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en"]];
    return [dateFormatter stringFromDate:date];
}



-(void)loadVideoThumForUrl:(NSURL *)url
{
    NSString *imageKey = [[YYWebImageManager sharedManager] cacheKeyForURL:url];
    
    if ([[YYWebImageManager sharedManager].cache getImageForKey:imageKey withType:YYImageCacheTypeAll]) {
        dispatch_async_on_main_queue(^{
            NSLog(@"thumbnailImage -->>  IMAGE FROM ---------->>> CACHE ");
        });
    }
    else
    {
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:url options:nil];
        
        // 3. Create AVAssetImageGenerator
        AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        imageGenerator.appliesPreferredTrackTransform = YES; // Ensures correct image orientation.
        
        // 4. Set a time ///////////////////////////////////////////////////////////////for the thumbnail (e.g., 1 second into the video)
        CMTime thumbnailTime = CMTimeMakeWithSeconds(1.0, 600); // 1 second at 600 frames per second
        
        // 5. Generate the thumbnail asynchronously
        [imageGenerator generateCGImagesAsynchronouslyForTimes:@[[NSValue valueWithCMTime:thumbnailTime]]
                                             completionHandler:^(CMTime requestedTime, CGImageRef _Nullable image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError * _Nullable error) {
            
            if (result == AVAssetImageGeneratorSucceeded) {
                // 6. Success: Convert CGImage to UIImage and display
                if(image){
                    UIImage *thumbnailImage = [[UIImage alloc] initWithCGImage:image];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[YYWebImageManager sharedManager].cache setImage:thumbnailImage forKey:imageKey];
                        NSLog(@"thumbnailImage -->> IMAGE FROM ---------->>> Server ");
                    });
                }
            } else {
                // Error handling
                NSLog(@"Error generating thumbnail: %@", error);
            }
        }];
        
    }
}

// 🎙 Upload audio message from NSData to Firebase Storage
- (void)uploadAudioData:(NSData *)audioData completion:(void (^)(NSString *downloadURL, NSError *error))completion {
    NSString *Uuid = [NSString stringWithFormat:@"%@_%@", [[NSUUID UUID] UUIDString], PPCurrentUser.ID];
    NSString *filename = [NSString stringWithFormat:@"chats/audio/%@.mp3", Uuid];
    FIRStorageReference *storageRef = [[FIRStorage storage] referenceWithPath:filename];
    
    FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] init];
    metadata.contentType = @"audio/mp3";
    
    FIRStorageUploadTask *uploadTask = [storageRef putData:audioData metadata:metadata completion:^(FIRStorageMetadata *metadata, NSError *error) {
        if (error) {
            NSLog(@"Error uploading audio: %@", error);
            if (completion) completion(nil, error);
            return;
        }
        
        // Get the public URL of the uploaded file
        [storageRef downloadURLWithCompletion:^(NSURL *URL, NSError *error) {
            if (error) {
                NSLog(@"Error getting download URL: %@", error);
                if (completion) completion(nil, error);
                return;
            }
            if (completion) completion(URL.absoluteString, nil);
        }];
    }];
    
    // Log upload progress
    [uploadTask observeStatus:FIRStorageTaskStatusProgress handler:^(FIRStorageTaskSnapshot *snapshot) {
        double percentComplete = 100.0 * snapshot.progress.completedUnitCount / snapshot.progress.totalUnitCount;
        NSLog(@"Upload progress: %.2f%%", percentComplete);
    }];
    
    // Handle upload failure
    [uploadTask observeStatus:FIRStorageTaskStatusFailure handler:^(FIRStorageTaskSnapshot *snapshot) {
        if (completion) completion(nil, snapshot.error);
    }];
}

// 🎧 Upload audio message from file path to Firebase Storage
- (void)uploadMP3FromPath:(NSString *)filePath completion:(void (^)(NSString *downloadURL, NSString *fileName, NSError *error))completion {
    NSString *Uuid = [NSString stringWithFormat:@"%@_%@.mp3",UUIDJoin(@"Record"), PPCurrentUser.ID];
    NSString *filename = [NSString stringWithFormat:@"chats/audio/%@", Uuid];
    FIRStorageReference *storageRef = [[FIRStorage storage] referenceWithPath:filename];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    
    FIRStorageUploadTask *uploadTask = [storageRef putFile:fileURL metadata:nil completion:^(FIRStorageMetadata *metadata, NSError *error) {
        if (error) {
            NSLog(@"Error uploading file: %@", error);
            if (completion) completion(nil, Uuid, error);
            return;
        }
        
        // Get the public URL of the uploaded file
        [storageRef downloadURLWithCompletion:^(NSURL *URL, NSError *error) {
            if (error) {
                NSLog(@"Error getting download URL: %@", error);
                if (completion) completion(nil, Uuid, error);
                return;
            }
            
            if (completion) completion(URL.absoluteString, Uuid, nil);
        }];
    }];
    
    // Log upload progress
    [uploadTask observeStatus:FIRStorageTaskStatusProgress handler:^(FIRStorageTaskSnapshot *snapshot) {
        double percentComplete = 100.0 * snapshot.progress.completedUnitCount / snapshot.progress.totalUnitCount;
        NSLog(@"Upload progress: %.2f%%", percentComplete);
    }];
    
    // Handle upload failure
    [uploadTask observeStatus:FIRStorageTaskStatusFailure handler:^(FIRStorageTaskSnapshot *snapshot) {
        if (completion) completion(nil, Uuid, snapshot.error);
    }];
}

// 🖼 Compress all images in a Firebase Storage folder and reupload them
- (void)compressImagesInFirebaseStorageFolder:(NSString *)folderPath {
    return;
    
    /*
     FIRStorageReference *folderRef = [[[FIRStorage storage] reference] child:folderPath];
     
     // List all files in the folder
     [folderRef listAllWithCompletion:^(FIRStorageListResult *result, NSError *error) {
     if (error) {
     NSLog(@"Error listing images: %@", error.localizedDescription);
     return;
     }
     
     // Loop through all image files
     for (FIRStorageReference *item in result.items) {
     [item dataWithMaxSize:10 * 1024 * 1024 completion:^(NSData *data, NSError *error) {
     if (error) {
     NSLog(@"Error downloading image: %@", error.localizedDescription);
     return;
     }
     
     UIImage *originalImage = [UIImage imageWithData:data];
     if (!originalImage) return;
     
     // Compress image to 50% quality
     NSData *compressedData = UIImageJPEGRepresentation(originalImage, 0.5);
     if (!compressedData) return;
     
     FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] init];
     metadata.contentType = @"image/jpeg";
     
     // Reupload the compressed image
     [item putData:compressedData metadata:metadata completion:^(FIRStorageMetadata *metadata, NSError *error) {
     if (error) {
     NSLog(@"Error uploading compressed image: %@", error.localizedDescription);
     } else {
     NSLog(@"Successfully reuploaded image: %@", item.fullPath);
     }
     }];
     }];
     }
     }];*/
}

// 🧹 Delete all Firestore documents owned by a specific user from a collection
- (void)deleteMyDataFromFirestore {
    
    /* [[[dF collectionWithPath:@"ArchiveCol"]
     queryWhereField:@"archiveOwnerID" isEqualTo:@"106365357607902908922"]
     getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
     if (error) {
     NSLog(@"Error fetching documents: %@", error.localizedDescription);
     return;
     }
     
     // Delete each document found in the query
     for (FIRDocumentSnapshot *document in snapshot.documents) {
     [[document reference] deleteDocumentWithCompletion:^(NSError *error) {
     if (error) {
     NSLog(@"Error deleting document: %@", error.localizedDescription);
     } else {
     NSLog(@"Document %@ successfully deleted!", document.documentID);
     }
     }];
     }
     }];     */
}

@end



/*
 can you modify only log on those func and make it same last logs we create
 
 -loadData
 - (void)loadUsersDocuments:(void (^)(DataLoadingResult result))completionHandler
 - (void)loadBuyers:(void (^)(DataLoadingResult result))completionHandler
 - (void)loadCards:(void (^)(DataLoadingResult result))completionHandler
 - (void)loadCagesDocuments:(void (^)(DataLoadingResult result))completionHandler
 - (void)loadArchivesDocuments:(void (^)(DataLoadingResult result))completionHandler
 */
