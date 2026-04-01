#import "BuyerModel.h"

@implementation BuyerModel

// Firestore Collection Name
static NSString * const kBuyersCollection = @"BuyersCollection";

// Firestore Field Keys
static NSString * const kID = @"ID";
static NSString * const kBuyerNameKey = @"buyerName";
static NSString * const kBuyerMobileKey = @"buyerMobile";
static NSString * const kbuyerPrice = @"buyerPrice";
static NSString * const kSellDateKey = @"sellDate";
static NSString * const kBuyerNoteKey = @"buyerNote";
static NSString * const kBirdWasInKey = @"birdWasIn";
static NSString * const kBirdIDKey = @"birdID";
static NSString * const kUserID = @"UserID";
static NSString * const kisDeleted = @"isDeleted";
static NSString * const kCityIDKey = @"cityID"; // Added cityID key

 // MARK: - CRUD Operations

// Create Buyer
+ (void)createBuyer:(BuyerModel *)buyer completion:(void (^)(NSError * _Nullable))completion {
    FIRFirestore *db = [FIRFirestore firestore];

        FIRDocumentReference *buyerDocument = [[db collectionWithPath:kBuyersCollection] documentWithAutoID];
        NSString *documentID = buyerDocument.documentID; // Get the auto-generated document ID

        // Convert the BuyerModel to a dictionary for Firestore
        NSMutableDictionary *buyerData = [[buyer toDictionary] mutableCopy]; // Make it mutable

        // Add the document ID to the buyer data
        buyerData[kID] = documentID; // Add the ID field

        [buyerDocument setData:buyerData completion:completion];
        //  [[db collectionWithPath:kBuyersCollection] addDocumentWithData:buyerData completion:completion];
}

// Modify Buyer
+ (void)modifyBuyer:(BuyerModel *)buyer documentID:(NSString *)documentID completion:(void (^)(NSError * _Nullable))completion {
    FIRFirestore *db = [FIRFirestore firestore];

    // Convert the BuyerModel to a dictionary for Firestore
    NSDictionary *buyerData = [buyer toDictionary];

    [[[db collectionWithPath:kBuyersCollection] documentWithPath:documentID] setData:buyerData merge:YES completion:completion];
}


// Delete Buyer
+ (void)deleteBuyerWithDocumentID:(NSString *)documentID completion:(void (^)(NSError * _Nullable))completion {
    FIRFirestore *db = [FIRFirestore firestore];

    [[[db collectionWithPath:kBuyersCollection] documentWithPath:documentID] deleteDocumentWithCompletion:completion];
}

// Get All Buyers
+ (void)getAllBuyersWithCompletion:(void (^)(NSArray<BuyerModel *> * _Nullable, NSError * _Nullable))completion {
    FIRFirestore *db = [FIRFirestore firestore];

    [[db collectionWithPath:kBuyersCollection] getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
        if (error != nil) {
            completion(nil, error);
            return;
        }

        NSMutableArray<BuyerModel *> *buyers = [NSMutableArray array];
        for (FIRDocumentSnapshot *document in snapshot.documents) {
            BuyerModel *buyer = [BuyerModel buyerFromDictionary:document.data];
            if (buyer) {
                [buyers addObject:buyer];
            }
        }

        completion([buyers copy], nil); // Return an immutable copy
    }];
}

// MARK: - Helper Methods

// Convert BuyerModel to Dictionary
- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if (self.ID) {
        dict[kID] = self.ID;
    }
    
    if (self.UserID) {
        dict[kUserID] = self.UserID;
    }
    
    if (self.cityID > 0) {
        dict[kCityIDKey] = @(self.cityID);
    }
    
    if (self.buyerName.isValid) {
        dict[kBuyerNameKey] = self.buyerName;
    }
    if (self.buyerMobile.isValid) {
        dict[kBuyerMobileKey] = self.buyerMobile;
    }
    if (self.buyerPrice) {
        dict[kbuyerPrice] = self.buyerPrice;
    }
    if (self.sellDate) {
        dict[kSellDateKey] = self.sellDate;
    }
    if (self.buyerNote.isValid) {
        dict[kBuyerNoteKey] = self.buyerNote;
    }
    if (self.birdWasIn) {
        dict[kBirdWasInKey] = @(self.birdWasIn);
    }
    if (self.birdID) {
        dict[kBirdIDKey] = self.birdID;
    }
    
  
    dict[kisDeleted] = @(self.isDeleted);
    
    return [dict copy]; // Return an immutable copy
}

// Create BuyerModel from Dictionary
+ (BuyerModel *)buyerFromDictionary:(NSDictionary *)dictionary {
    if (!dictionary || ![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    BuyerModel *buyer = [[BuyerModel alloc] init];
    buyer.ID = dictionary[kID] ?: @"";
    buyer.UserID = dictionary[kUserID] ?: @"";
    buyer.cityID = [dictionary[kCityIDKey] integerValue];
    buyer.city = nil; // resolved later by CitiesManager
    buyer.buyerName = [BuyerModel pp_safeString:dictionary[kBuyerNameKey]];
    buyer.buyerMobile = [BuyerModel pp_safeString:dictionary[kBuyerMobileKey]];
    buyer.buyerPrice = [BuyerModel pp_safeString:dictionary[kbuyerPrice]];
    
    id rawDate = dictionary[kSellDateKey];
    if ([rawDate isKindOfClass:[FIRTimestamp class]]) {
        buyer.sellDate = ((FIRTimestamp *)rawDate).dateValue;
    } else {
        buyer.sellDate = [BuyerModel pp_safeDate:rawDate];
    }
    
    buyer.buyerNote = [BuyerModel pp_safeString:dictionary[kBuyerNoteKey]];
    buyer.birdWasIn = dictionary[kBirdWasInKey] ? [dictionary[kBirdWasInKey] integerValue] : 0;
    buyer.birdID = [BuyerModel pp_safeString:dictionary[kBirdIDKey]];
    buyer.isDeleted = [dictionary[kisDeleted] boolValue];

    return buyer;
}


-(void)updateCageIsSoldForCard:(CardModel *)card
                     withValue:(NSInteger)isSold
             completionHandler:(void (^)(int result))completionHandler
{
    if (!card.ID.length || !card.CageID.length) {
        if (completionHandler) completionHandler(0);
        return;
    }

    // 🔥 Use ChildsCol instead of AllChildsArray
    [ChildsDataManager updateChildWithCardID:card.ID
                                      cageID:card.CageID
                                        data:@{ @"isSold": @(isSold) }
                                   completion:^(NSError * _Nullable error)
    {
        if (error) {
            NSLog(@"❌ Failed to update isSold for child (card %@): %@",
                  card.ID, error);
            if (completionHandler) completionHandler(0);
            return;
        }

        NSLog(@"✅ Child isSold updated for card %@", card.ID);
        if (completionHandler) completionHandler(1);
    }];
}

#pragma mark - Snapshot Mapping
+ (NSMutableArray<BuyerModel *> *)fromSnapshot:(id)snapshotOrArray {
    NSMutableArray<BuyerModel *> *result = [NSMutableArray array];
    if (!snapshotOrArray) return result;

    // Firestore Query Snapshot
    if ([snapshotOrArray isKindOfClass:NSClassFromString(@"FIRQuerySnapshot")]) {
        NSArray *docs = [snapshotOrArray valueForKey:@"documents"];
        for (FIRDocumentSnapshot *doc in docs) {
            BuyerModel *m = [[BuyerModel alloc] initWithSnapshot:doc];
            if (m) [result addObject:m];
        }
        return result;
    }

    // Array of snapshots
    if ([snapshotOrArray isKindOfClass:[NSArray class]]) {
        for (id doc in (NSArray *)snapshotOrArray) {
            if ([doc respondsToSelector:@selector(documentID)]) {
                BuyerModel *m = [[BuyerModel alloc] initWithSnapshot:doc];
                if (m) [result addObject:m];
            }
        }
        return result;
    }

    // Single snapshot
    if ([snapshotOrArray respondsToSelector:@selector(documentID)]) {
        BuyerModel *m = [[BuyerModel alloc] initWithSnapshot:snapshotOrArray];
        if (m) [result addObject:m];
    }

    return result;
}

- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot {
    if (!snapshot) return nil;

    self = [super init];
    if (!self) return nil;
    
    self.cityID = 0;

    NSDictionary *d = snapshot.data;
    self.ID = snapshot.documentID;

    // tolerate case differences
    self.UserID      = d[@"UserID"] ?: d[@"userID"];
    self.cityID = [d[@"cityID"] integerValue];
    self.city = nil; // resolved lazily
    self.buyerName   = [BuyerModel pp_safeString:d[@"buyerName"]];
    self.buyerMobile = [BuyerModel pp_safeString:d[@"buyerMobile"]];
    self.buyerPrice  = [BuyerModel pp_safeString:d[@"buyerPrice"]];
    self.buyerNote   = [BuyerModel pp_safeString:d[@"buyerNote"]];
    self.birdID      = [BuyerModel pp_safeString:d[@"birdID"]];

    self.birdRingId  = [BuyerModel pp_safeString:d[@"birdRingId"]];
    self.birdTitle   = [BuyerModel pp_safeString:d[@"birdTitle"]];
    self.birdBirdDate = [BuyerModel pp_safeString:d[@"birdBirdDate"]];
    self.birdAge     = [BuyerModel pp_safeString:d[@"birdAge"]];
    self.isDeleted     = [d[@"isDeleted"] boolValue];

    id rawDate = d[@"sellDate"];
    if ([rawDate isKindOfClass:[FIRTimestamp class]]) {
        self.sellDate = ((FIRTimestamp *)rawDate).dateValue;
    } else {
        self.sellDate = [BuyerModel pp_safeDate:rawDate];
    }

    // Enum
    self.birdWasIn = [d[@"birdWasIn"] integerValue];

    return self;
}


- (void)updateArchiveIsSoldForCard:(CardModel *)card
                         withValue:(NSInteger)isSold
                 completionHandler:(void (^)(int result))completionHandler
{
    if (!card.ID.length) {
        if (completionHandler) completionHandler(0);
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];

    [[[db collectionGroupWithID:@"ArchiveDetailsCol"]
      queryWhereField:@"CardID" isEqualTo:card.ID]
     getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error)
    {
        if (error) {
            NSLog(@"Archive sold update error: %@", error);
            if (completionHandler) completionHandler(-1);
            return;
        }

        if (snapshot.documents.count == 0) {
            // Card not found in any archive
            if (completionHandler) completionHandler(0);
            return;
        }

        FIRWriteBatch *batch = [db batch];

        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            [batch updateData:@{ @"isSold": @(isSold) }
                 forDocument:doc.reference];
        }

        [batch commitWithCompletion:^(NSError * _Nullable commitError) {

            if (commitError) {
                NSLog(@"Archive sold batch update failed: %@", commitError);
                if (completionHandler) completionHandler(-1);
            } else {
                NSLog(@"Archive sold status updated for card %@", card.ID);
                if (completionHandler) completionHandler(1);
            }
        }];
    }];
}

+ (NSString *)pp_safeString:(id)value {
    if (!value || value == [NSNull null]) return @"";
    if ([value isKindOfClass:[NSString class]]) return value;
    return [[value description] isEqualToString:@"(null)"] ? @"" : [value description];
}

+ (NSDate *)pp_safeDate:(id)value {
    if (!value || value == [NSNull null]) return nil;
    if ([value isKindOfClass:[NSDate class]]) return value;
    if ([value isKindOfClass:[NSNumber class]]) return [NSDate dateWithTimeIntervalSince1970:[value doubleValue]];
    return nil;
}




- (CountryModel *)inferredCountryFromPhone
{
    NSString *raw = self.buyerMobile;
    if (![raw isKindOfClass:NSString.class] || raw.length == 0) {
        return nil;
    }

    // Normalize digits (reuse your formatter logic if needed)
    NSString *digits =
    [[raw componentsSeparatedByCharactersInSet:
      [[NSCharacterSet decimalDigitCharacterSet] invertedSet]]
     componentsJoinedByString:@""];

    // Qatar
    if ([digits hasPrefix:@"974"] || raw.length == 8) {
        return [[CitiesManager shared] countryWithCode:@"QA"];
    }

    // Saudi
    if ([digits hasPrefix:@"966"] || [digits hasPrefix:@"05"]) {
        return [[CitiesManager shared] countryWithCode:@"SA"];
    }

    // Egypt
    if ([digits hasPrefix:@"20"] || [digits hasPrefix:@"01"]) {
        return [[CitiesManager shared] countryWithCode:@"EG"];
    }

    return nil;
}


/*
 // Added lazy resolver helper for city
 - (CityModel *)resolvedCity
 {
     if (self.city) return self.city;
     if (self.cityID <= 0) return nil;

     CityModel *c =
     [[CitiesManager shared] cityByID:self.cityID];

     self.city = c;
     return c;
 }
 */

 
- (CityModel *)resolvedCity
{
    // 1️⃣ Normal path (already refactored)
    if (self.city) return self.city;

    if (self.cityID > 0) {
        self.city = [[CitiesManager shared] cityByID:self.cityID];
        return self.city;
    }

    // 2️⃣ Fallback for OLD SALES
    CountryModel *country = [self inferredCountryFromPhone];
    if (!country) return nil;

    // Qatar-specific city inference (safe default)
    if (country.defualtCityID) {

        // Optional: later you can infer by prefix (e.g. Vodafone/Ooredoo)
        CityModel *doha =
        [[CitiesManager shared] defaultCityForCountry:country];

        self.city = doha;
        return self.city;
    }

    // Other countries → default city
    CityModel *defaultCity =
    [[CitiesManager shared] defaultCityForCountry:country];

    self.city = defaultCity;
    return self.city;
}


@end
