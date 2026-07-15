//
//  PetAdManager.m
//  Pure Pets
//
//  Refactored for best practices by ChatGPT (2025)
//

#import "PetAdManager.h"
#import "PetAd.h"
#import "ArabicNormalizer.h"
#import "PPSearchHelper.h"
#import <CoreLocation/CoreLocation.h>
#import <math.h>
#import <float.h>
#import "PPFunc.h"
#import "PPImageCollection.h"

static NSString * const PPAdManagerErrorDomain = @"PetAdManagerError";
static NSString * const PPGeoHashAlphabet = @"0123456789bcdefghjkmnpqrstuvwxyz";
static CLLocationDistance const PPNearbyEarthRadiusMeters = 6371000.0;
static NSString * const PPAccessoriesCollectionPath = @"petAccessories";
static NSString * const PPServicesCollectionPath = @"serviceOffers";
static NSString * const PPViewersIDsSubcollection = @"viewerIDs";
static NSString * const PPFavoritesIDsSubcollection = @"favIDs";
static NSString * const PPSharesIDsSubcollection = @"shareIDs";
static NSString * const PPCallersIDsSubcollection = @"callersIDs";
static NSString * const PPChatsIDsSubcollection = @"chatsIDs";

static NSString *PPTrimmedFavoritesValue(NSString *value) {
    return [[value ?: @"" lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *PPCanonicalFavoritesCollection(NSString *favoritesCollection) {
    NSString *normalized = PPTrimmedFavoritesValue(favoritesCollection);
    if (normalized.length == 0) return @"";

    if ([normalized isEqualToString:@"favoritesads"] ||
        [normalized isEqualToString:@"favoriteads"]) {
        return @"favoritesAds";
    }

    if ([normalized isEqualToString:@"favoritesaccessories"] ||
        [normalized isEqualToString:@"favoriteaccessories"] ||
        [normalized isEqualToString:@"favoritesaccess"] ||
        [normalized isEqualToString:@"favoriteaccess"] ||
        [normalized isEqualToString:@"favoritesfood"] ||
        [normalized isEqualToString:@"favoritefood"]) {
        return @"favoritesAccessories";
    }

    if ([normalized isEqualToString:@"favoritesservices"] ||
        [normalized isEqualToString:@"favoriteservices"] ||
        [normalized isEqualToString:@"favoriteservice"]) {
        return @"favoritesServices";
    }

    if ([normalized isEqualToString:@"favoritesvets"] ||
        [normalized isEqualToString:@"favoritevets"]) {
        return @"favoritesVets";
    }

    if ([normalized isEqualToString:@"favoritesadoptpets"] ||
        [normalized isEqualToString:@"favoriteadoptpets"]) {
        return @"favoritesAdoptPets";
    }

    return [favoritesCollection stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *PPCurrentRequesterUserDocumentID(NSString *requestedUserID) {
    NSString *authUID = [[[FIRAuth auth].currentUser.uid ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
    if (authUID.length > 0) {
        return authUID;
    }

    return [[requestedUserID ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
}

static FIRQuery *PPPublicPetAdsQuery(FIRQuery *query) {
    query = [query queryWhereField:@"status" isEqualTo:@(PetAdStatusActive)];
    query = [query queryWhereField:@"isApproved" isEqualTo:@(YES)];
    query = [query queryWhereField:@"visibility" isEqualTo:@(PetAdVisibilityPublic)];
    return query;
}

static NSString *PPCountFieldForInteraction(PPItemInteractionType interaction) {
    switch (interaction) {
        case PPItemInteractionTypeView: return @"viewsCount";
        case PPItemInteractionTypeFavoriteAdd:
        case PPItemInteractionTypeFavoriteRemove: return @"favoritesCount";
        case PPItemInteractionTypeShare: return @"sharesCount";
        case PPItemInteractionTypeCall: return @"callsCount";
        case PPItemInteractionTypeChat: return @"chatsCount";
    }
    return nil;
}

static NSString *PPSubcollectionForInteraction(PPItemInteractionType interaction) {
    switch (interaction) {
        case PPItemInteractionTypeView: return PPViewersIDsSubcollection;
        case PPItemInteractionTypeFavoriteAdd:
        case PPItemInteractionTypeFavoriteRemove: return PPFavoritesIDsSubcollection;
        case PPItemInteractionTypeShare: return PPSharesIDsSubcollection;
        case PPItemInteractionTypeCall: return PPCallersIDsSubcollection;
        case PPItemInteractionTypeChat: return PPChatsIDsSubcollection;
    }
    return nil;
}

#pragma mark - Hidden-Category Filtering

/// Returns the set of currently visible main-kind IDs.
static NSSet<NSNumber *> *PPVisibleMainKindIDs(void) {
    NSMutableSet<NSNumber *> *ids = [NSMutableSet set];
    for (MainKindsModel *kind in PPMainKindsArray) {
        if (kind.ID > 0) {
            [ids addObject:@(kind.ID)];
        }
    }
    return ids;
}

/// Filters out ads whose category belongs to a hidden main kind.
static NSArray<PetAd *> *PPFilterAdsByVisibleCategories(NSArray<PetAd *> *ads) {
    NSSet<NSNumber *> *visibleIDs = PPVisibleMainKindIDs();
    if (visibleIDs.count == 0) return ads; // Categories not loaded yet — don't filter

    return [ads filteredArrayUsingPredicate:
        [NSPredicate predicateWithBlock:^BOOL(PetAd *ad, NSDictionary *bindings) {
            if (ad.category <= 0) return YES; // General/no-category items pass through
            return [visibleIDs containsObject:@(ad.category)];
        }]];
}

static NSDate *PPAdSortDate(PetAd *ad) {
    return ad.postedDate ?: ad.createdAt ?: ad.updatedAt ?: [NSDate distantPast];
}

static NSArray<PetAd *> *PPSortedAdsNewestFirst(NSArray<PetAd *> *ads) {
    return [ads sortedArrayUsingComparator:^NSComparisonResult(PetAd *left, PetAd *right) {
        NSDate *leftDate = PPAdSortDate(left);
        NSDate *rightDate = PPAdSortDate(right);
        NSComparisonResult dateResult = [rightDate compare:leftDate];
        if (dateResult != NSOrderedSame) {
            return dateResult;
        }
        return [(left.adID ?: @"") compare:(right.adID ?: @"") options:NSCaseInsensitiveSearch];
    }];
}

static NSString *PPItemCollectionPathForFavoritesCollection(NSString *favoritesCollection) {
    NSString *canonical = PPCanonicalFavoritesCollection(favoritesCollection);
    if (canonical.length == 0) return nil;

    if ([canonical isEqualToString:@"favoritesAds"]) {
        return kPetAdsCollection;
    }

    if ([canonical isEqualToString:@"favoritesAccessories"]) {
        return PPAccessoriesCollectionPath;
    }

    if ([canonical isEqualToString:@"favoritesServices"]) {
        return PPServicesCollectionPath;
    }

    return nil;
}

static inline double PPClampLatitude(double latitude) {
    return fmax(-90.0, fmin(90.0, latitude));
}

static inline double PPWrapLongitude(double longitude) {
    double wrapped = fmod(longitude + 180.0, 360.0);
    if (wrapped < 0) wrapped += 360.0;
    return wrapped - 180.0;
}

static inline BOOL PPIsCoordinateFinite(CLLocationCoordinate2D coordinate) {
    return isfinite(coordinate.latitude) && isfinite(coordinate.longitude);
}

static inline BOOL PPIsValidCoordinate(CLLocationCoordinate2D coordinate) {
    if (!PPIsCoordinateFinite(coordinate)) return NO;
    if (coordinate.latitude < -90.0 || coordinate.latitude > 90.0) return NO;
    if (coordinate.longitude < -180.0 || coordinate.longitude > 180.0) return NO;
    if (fabs(coordinate.latitude) < DBL_EPSILON && fabs(coordinate.longitude) < DBL_EPSILON) return NO; // invalid sentinel
    return YES;
}

static inline double PPDeg2Rad(double degrees) {
    return degrees * (M_PI / 180.0);
}

static CLLocationDistance PPDistanceMeters(CLLocationCoordinate2D a, CLLocationCoordinate2D b) {
    double lat1 = PPDeg2Rad(a.latitude);
    double lat2 = PPDeg2Rad(b.latitude);
    double dLat = lat2 - lat1;
    double dLon = PPDeg2Rad(b.longitude - a.longitude);

    double h = pow(sin(dLat / 2.0), 2.0) +
               cos(lat1) * cos(lat2) * pow(sin(dLon / 2.0), 2.0);
    double c = 2.0 * atan2(sqrt(h), sqrt(fmax(0.0, 1.0 - h)));
    return PPNearbyEarthRadiusMeters * c;
}

static NSUInteger PPGeoHashPrecisionForRadiusKm(double radiusKm) {
    if (radiusKm <= 1.5) return 6;
    if (radiusKm <= 10.0) return 5;
    if (radiusKm <= 40.0) return 4;
    return 3;
}

static double PPGeoHashCellKmForPrecision(NSUInteger precision) {
    switch (precision) {
        case 1: return 5000.0;
        case 2: return 1250.0;
        case 3: return 156.0;
        case 4: return 39.1;
        case 5: return 4.89;
        case 6: return 1.22;
        case 7: return 0.153;
        case 8: return 0.0382;
        default: return 0.00477;
    }
}

static NSString *PPGeoHashEncode(CLLocationCoordinate2D coordinate, NSUInteger precision) {
    if (!PPIsValidCoordinate(coordinate) || precision == 0) {
        return @"";
    }

    double latMin = -90.0, latMax = 90.0;
    double lonMin = -180.0, lonMax = 180.0;
    BOOL evenBit = YES;
    int bitIndex = 0;
    int currentChar = 0;

    NSMutableString *hash = [NSMutableString stringWithCapacity:precision];
    while (hash.length < precision) {
        if (evenBit) {
            double mid = (lonMin + lonMax) * 0.5;
            if (coordinate.longitude >= mid) {
                currentChar = (currentChar << 1) | 1;
                lonMin = mid;
            } else {
                currentChar = (currentChar << 1);
                lonMax = mid;
            }
        } else {
            double mid = (latMin + latMax) * 0.5;
            if (coordinate.latitude >= mid) {
                currentChar = (currentChar << 1) | 1;
                latMin = mid;
            } else {
                currentChar = (currentChar << 1);
                latMax = mid;
            }
        }

        evenBit = !evenBit;
        bitIndex += 1;
        if (bitIndex == 5) {
            unichar c = [PPGeoHashAlphabet characterAtIndex:currentChar];
            [hash appendFormat:@"%C", c];
            bitIndex = 0;
            currentChar = 0;
        }
    }

    return hash;
}

static NSString *PPGeoHashPrefixUpperBound(NSString *prefix) {
    if (prefix.length == 0) return @"~";
    return [prefix stringByAppendingString:@"~"];
}

static NSSet<NSString *> *PPGeoHashPrefixesAroundCoordinate(CLLocationCoordinate2D center,
                                                            NSUInteger precision) {
    if (!PPIsValidCoordinate(center)) return [NSSet set];

    double cellKm = PPGeoHashCellKmForPrecision(precision);
    double latStepDeg = cellKm / 110.574;
    double cosLat = cos(PPDeg2Rad(center.latitude));
    if (fabs(cosLat) < 0.01) cosLat = (cosLat < 0 ? -0.01 : 0.01);
    double lonStepDeg = cellKm / (111.320 * cosLat);

    NSMutableSet<NSString *> *prefixes = [NSMutableSet setWithCapacity:9];
    for (NSInteger dy = -1; dy <= 1; dy++) {
        for (NSInteger dx = -1; dx <= 1; dx++) {
            CLLocationCoordinate2D shifted = CLLocationCoordinate2DMake(
                PPClampLatitude(center.latitude + (latStepDeg * dy)),
                PPWrapLongitude(center.longitude + (lonStepDeg * dx))
            );
            NSString *hash = PPGeoHashEncode(shifted, precision);
            if (hash.length > 0) {
                [prefixes addObject:hash];
            }
        }
    }

    return [prefixes copy];
}


@interface PetAdManager ()
@property (nonatomic, strong) FIRFirestore *db;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> listener;
@end

@implementation PetAdManager

#pragma mark - Singleton
// MainKind-only fetch, backward compatible. Now delegates to subKind-aware fetch.
- (void)fetchAdsForMainKind:(MainKindsModel *)mainKind
                 completion:(void (^)(NSArray<PetAd *> *ads))completion
{
    [self fetchAdsForMainKind:mainKind
                   subKindID:0
                  completion:completion];
}

// SubKind-aware fetch. Fetches ads filtered by mainKind and (optionally) subKindID.
- (void)fetchAdsForMainKind:(MainKindsModel *)mainKind
                 subKindID:(NSInteger)subKindID
                completion:(void (^)(NSArray<PetAd *> *ads))completion
{
    if (!mainKind) {
        if (completion) completion(@[]);
        return;
    }

    NSInteger categoryID = mainKind.ID;

    FIRQuery *query = PPPublicPetAdsQuery([self.db collectionWithPath:kPetAdsCollection]);

    if (categoryID > 0) {
        query =
        [query queryWhereField:@"category"
                   isEqualTo:@(categoryID)];
    }

    if (subKindID > 0) {
        query =
        [query queryWhereField:@"subcategory"
                   isEqualTo:@(subKindID)];
    }

    [query getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {

        if (error || !snapshot) {
            NSLog(@"❌ fetchAdsForMainKind:subKindID error: %@",
                  error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(@[]);
            });
            return;
        }

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{

            NSMutableArray<PetAd *> *ads =
                [NSMutableArray arrayWithCapacity:snapshot.documents.count];

            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                PetAd *ad =
                    [PetAd adFromFirestoreData:doc.data
                                    documentID:doc.documentID];
                if (ad) [ads addObject:ad];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(PPSortedAdsNewestFirst(PPFilterAdsByVisibleCategories(ads)));
            });
        });
    }];
}


- (void)fetchAdsForAllMainKinds:(void (^)(NSArray<PetAd *> *ads))completion
{
    FIRQuery *query = [[PPPublicPetAdsQuery([self.db collectionWithPath:kPetAdsCollection]) queryOrderedByField:@"createdAt" descending:YES] queryLimitedTo:50];

    [query getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {

        if (error || !snapshot) {
            NSLog(@"❌ fetchAdsForAllMainKinds error: %@", error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(@[]);
            });
            return;
        }

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{

            NSMutableArray<PetAd *> *ads =
            [NSMutableArray arrayWithCapacity:snapshot.documents.count];

            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                PetAd *ad =
                [PetAd adFromFirestoreData:doc.data
                                documentID:doc.documentID];
                if (ad) [ads addObject:ad];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(PPSortedAdsNewestFirst(PPFilterAdsByVisibleCategories(ads)));
            });
        });
    }];
}


- (void)fetchNearByAdsWithLimit:(NSInteger)limit
                       category:(NSInteger)category
                      completion:(void (^)(NSArray<PetAd *> *ads))completion
{
    // Backward-compatible fallback for legacy call sites.
    if (limit <= 0) {
        if (completion) completion(@[]);
        return;
    }

    FIRQuery *query =
    [[self.db collectionWithPath:kPetAdsCollection]
     queryWhereField:@"status" isEqualTo:@(PetAdStatusActive)];
    query = [query queryWhereField:@"isApproved" isEqualTo:@(YES)];
    query = [query queryWhereField:@"visibility" isEqualTo:@(PetAdVisibilityPublic)];
    if (category > 0) {
        query = [query queryWhereField:@"category" isEqualTo:@(category)];
    }
    query = [[query queryOrderedByField:@"createdAt" descending:YES]
             queryLimitedTo:limit];

    void (^executeWithSource)(FIRFirestoreSource, void (^)(FIRQuerySnapshot * _Nullable, NSError * _Nullable)) =
    ^(FIRFirestoreSource source, void (^handler)(FIRQuerySnapshot * _Nullable, NSError * _Nullable)) {
        [query getDocumentsWithSource:source completion:handler];
    };

    executeWithSource(FIRFirestoreSourceServer,
 ^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error || !snapshot) {
            NSLog(@"[PetAdManager] fetchNearByAdsWithLimit server fetch failed, trying cache: %@",
                  error.localizedDescription ?: @"Unknown error");
            executeWithSource(FIRFirestoreSourceCache,
                              ^(FIRQuerySnapshot * _Nullable cacheSnapshot,
                                NSError * _Nullable cacheError) { //FIRFirestoreSourceCache
                FIRQuerySnapshot *resolvedSnapshot = cacheSnapshot;
                NSError *resolvedError = cacheError ?: error;
                if (!resolvedSnapshot) {
                    if (completion) completion(@[]);
                    return;
                }

                NSMutableArray<PetAd *> *cachedAds = [NSMutableArray arrayWithCapacity:resolvedSnapshot.documents.count];
                for (FIRDocumentSnapshot *doc in resolvedSnapshot.documents) {
                    PetAd *ad = [PetAd adFromFirestoreData:doc.data documentID:doc.documentID];
                    if (!ad || ad.isDeleted || ad.isBlocked) continue;
                    if (ad.expiresAt && [ad.expiresAt compare:[NSDate date]] != NSOrderedDescending) continue;
                    [cachedAds addObject:ad];
                }
                if (resolvedError) {
                    NSLog(@"[PetAdManager] fetchNearByAdsWithLimit using cached data after server error.");
                }
                if (completion) completion(PPFilterAdsByVisibleCategories(cachedAds));
            });
            return;
        }

        if (error || !snapshot) {
            if (completion) completion(@[]);
            return;
        }

        NSMutableArray<PetAd *> *ads = [NSMutableArray arrayWithCapacity:snapshot.documents.count];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            PetAd *ad = [PetAd adFromFirestoreData:doc.data documentID:doc.documentID];
            if (!ad || ad.isDeleted || ad.isBlocked) continue;
            if (ad.expiresAt && [ad.expiresAt compare:[NSDate date]] != NSOrderedDescending) continue;
            [ads addObject:ad];
        }
        if (completion) completion(PPFilterAdsByVisibleCategories(ads));
    });
}

- (void)fetchNearbyAdsAtCoordinate:(CLLocationCoordinate2D)coordinate
                          radiusKm:(double)radiusKm
                             limit:(NSInteger)limit
                          category:(NSInteger)category
                        completion:(void (^)(NSArray<PetAd *> *ads))completion
{
    if (limit <= 0) {
        if (completion) completion(@[]);
        return;
    }

    if (!PPIsValidCoordinate(coordinate)) {
        if (completion) completion(@[]);
        return;
    }

    double normalizedRadiusKm = radiusKm > 0 ? radiusKm : 8.0;
    NSUInteger precision = PPGeoHashPrecisionForRadiusKm(normalizedRadiusKm);
    NSSet<NSString *> *prefixSet = PPGeoHashPrefixesAroundCoordinate(coordinate, precision);
    NSArray<NSString *> *prefixes = [[prefixSet allObjects] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];

    if (prefixes.count == 0) {
        if (completion) completion(@[]);
        return;
    }

    NSInteger perQueryLimit = MAX(limit * 2, 24);
    CLLocationDistance radiusMeters = normalizedRadiusKm * 1000.0;
    NSDate *now = [NSDate date];

    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t syncQueue = dispatch_queue_create("com.purepets.nearby.sync", DISPATCH_QUEUE_SERIAL);
    __block NSMutableDictionary<NSString *, PetAd *> *byID = [NSMutableDictionary dictionary];

    for (NSString *prefix in prefixes) {
        dispatch_group_enter(group);

        FIRQuery *query = [self.db collectionWithPath:kPetAdsCollection];
        query = [query queryWhereField:@"status" isEqualTo:@(PetAdStatusActive)];
        query = [query queryWhereField:@"isApproved" isEqualTo:@(YES)];
        query = [query queryWhereField:@"visibility" isEqualTo:@(PetAdVisibilityPublic)];
        if (category > 0) {
            query = [query queryWhereField:@"category" isEqualTo:@(category)];
        }
        query = [query queryWhereField:@"geohash" isGreaterThanOrEqualTo:prefix];
        query = [query queryWhereField:@"geohash" isLessThan:PPGeoHashPrefixUpperBound(prefix)];
        query = [query queryOrderedByField:@"geohash" descending:NO];
        query = [query queryOrderedByField:@"createdAt" descending:YES];
        query = [query queryLimitedTo:perQueryLimit];

        void (^handleSnapshot)(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) =
        ^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
            if (!error && snapshot) {
                for (FIRDocumentSnapshot *doc in snapshot.documents) {
                    PetAd *ad = [PetAd adFromFirestoreData:doc.data documentID:doc.documentID];
                    if (!ad) continue;
                    if (![ad hasValidGeoLocation]) continue;
                    if (ad.isDeleted || ad.isBlocked) continue;
                    if (ad.expiresAt && [ad.expiresAt compare:now] != NSOrderedDescending) continue;

                    CLLocationCoordinate2D adCoordinate = CLLocationCoordinate2DMake(ad.latitude, ad.longitude);
                    CLLocationDistance distance = PPDistanceMeters(coordinate, adCoordinate);
                    if (distance > radiusMeters) continue;

                    dispatch_sync(syncQueue, ^{
                        PetAd *existing = byID[ad.adID];
                        if (!existing) {
                            byID[ad.adID] = ad;
                            return;
                        }

                        NSDate *existingDate = existing.createdAt ?: existing.postedDate ?: [NSDate distantPast];
                        NSDate *candidateDate = ad.createdAt ?: ad.postedDate ?: [NSDate distantPast];
                        if ([candidateDate compare:existingDate] == NSOrderedDescending) {
                            byID[ad.adID] = ad;
                        }
                    });
                }
            } else {
                NSLog(@"❌ fetchNearbyAdsAtCoordinate prefix(%@) error: %@",
                      prefix,
                      error.localizedDescription);
            }

            dispatch_group_leave(group);
        };

        [query getDocumentsWithSource:FIRFirestoreSourceServer
                           completion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
            if (!error && snapshot) {
                handleSnapshot(snapshot, nil);
                return;
            }

            NSLog(@"[PetAdManager] fetchNearbyAdsAtCoordinate prefix(%@) server fetch failed, trying cache: %@",
                  prefix,
                  error.localizedDescription ?: @"Unknown error");

            [query getDocumentsWithSource:FIRFirestoreSourceCache
                               completion:^(FIRQuerySnapshot * _Nullable cacheSnapshot, NSError * _Nullable cacheError) {
                if (cacheSnapshot) {
                    handleSnapshot(cacheSnapshot, nil);
                    return;
                }
                handleSnapshot(nil, cacheError ?: error);
            }];
        }];
    }

    dispatch_group_notify(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray<PetAd *> *allAds = byID.allValues ?: @[];
        NSArray<PetAd *> *sorted = [allAds sortedArrayUsingComparator:^NSComparisonResult(PetAd *a, PetAd *b) {
            NSDate *aDate = a.createdAt ?: a.postedDate ?: [NSDate distantPast];
            NSDate *bDate = b.createdAt ?: b.postedDate ?: [NSDate distantPast];
            NSComparisonResult timeOrder = [bDate compare:aDate]; // newest first
            if (timeOrder != NSOrderedSame) {
                return timeOrder;
            }

            // Deterministic tie-breaker for stable diff updates
            return [a.adID compare:b.adID options:NSCaseInsensitiveSearch];
        }];

        NSArray<PetAd *> *limited =
        sorted.count > (NSUInteger)limit
            ? [sorted subarrayWithRange:NSMakeRange(0, (NSUInteger)limit)]
            : sorted;

        NSArray<PetAd *> *filtered = PPFilterAdsByVisibleCategories(limited ?: @[]);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(filtered);
        });
    });
}





-(void)fetchLatestAdsWithLimit:(NSInteger)limit
                   completion:(void (^)(NSArray<PetAd *> *ads))completion
{
    if (limit <= 0) {
        if (completion) completion(@[]);
        return;
    }

    FIRQuery *query = PPPublicPetAdsQuery([self.db collectionWithPath:kPetAdsCollection]);

    [query getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {

        if (error || !snapshot) {
            NSLog(@"❌ fetchLatestAdsWithLimit error: %@", error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(@[]);
            });
            return;
        }

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            NSMutableArray<PetAd *> *ads =
            [NSMutableArray arrayWithCapacity:snapshot.documents.count];

            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                PetAd *ad =
                [PetAd adFromFirestoreData:doc.data
                                documentID:doc.documentID];
                if (ad) [ads addObject:ad];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                NSArray<PetAd *> *sorted = PPSortedAdsNewestFirst(PPFilterAdsByVisibleCategories(ads));
                if (sorted.count > (NSUInteger)limit) {
                    sorted = [sorted subarrayWithRange:NSMakeRange(0, (NSUInteger)limit)];
                }
                if (completion) completion(sorted);
            });
        });
    }];
}


#pragma mark - Firebase Text Search

// Firestore search using normalized searchTitle (Arabic-safe)
- (void)searchAdsWithText:(NSString *)query
               completion:(void (^)(NSArray<PetAd *> *ads))completion
{
    if (query.length == 0) {
        if (completion) completion(@[]);
        return;
    }

    NSString *normalizedQuery = [ArabicNormalizer normalize:query];
    if (normalizedQuery.length == 0) {
        if (completion) completion(@[]);
        return;
    }
    
    // 🔑 Broad Firestore prefix (first character only)
    NSString *prefix = [normalizedQuery substringToIndex:1];

    FIRQuery *fsQuery =
    [[[PPPublicPetAdsQuery([self.db collectionWithPath:kPetAdsCollection])
       queryOrderedByField:@"searchTitle"]
      queryStartingAtValues:@[prefix]]
     queryEndingAtValues:@[[prefix stringByAppendingString:@"\uf8ff"]]];

    [fsQuery getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {

        if (error || !snapshot) {
            NSLog(@"❌ searchAdsWithText error: %@", error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(@[]);
            });
            return;
        }
        
        NSLog(@"Fetched Document snapshot: %@",snapshot);
        NSMutableArray<PetAd *> *results = [NSMutableArray array];

        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            PetAd *ad =
            [PetAd adFromFirestoreData:doc.data
                            documentID:doc.documentID];

            if (!ad.adTitle.length) continue;

            // ✅ Client-side matching (exact / starts / ends / contains)
            PPSearchMatchType match =
            [PPSearchHelper matchText:ad.adTitle withQuery:query];

            if (match != PPSearchMatchNone) {
                [results addObject:ad];
            }
        }

        dispatch_async(dispatch_get_main_queue(),
 ^{
            NSLog(@"✅ Ads matched = %lu results %@",
                  (unsigned long)results.count,
                  [results valueForKey:@"adTitle"]);
            if (completion) completion(PPFilterAdsByVisibleCategories(results));
        });
    }];
}

#pragma mark - Fetch by MainKind

- (void)populateMissingImageMetadataForExistingAds:(void (^)(NSError * _Nullable error))completion {
    NSLog(@"ℹ️ Starting one-time image metadata enrichment for existing ads...");
    [[self.db collectionWithPath:kPetAdsCollection] getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
        if (error) {
            NSLog(@"❌ Error fetching ads for enrichment: %@", error.localizedDescription);
            if (completion) completion(error);
            return;
        }
        // Process documents one by one on a background queue
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            __block NSError *overallError = nil;
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                @autoreleasepool {  // autoreleasepool to manage memory in loop
                    NSDictionary *data = doc.data;
                    // 🔧 Backfill adTitle / searchTitle if missing (migration safety)
                    NSString *adTitle = data[@"adTitle"];
                    NSString *searchTitle = data[@"searchTitle"];

                    NSMutableDictionary *updates = [NSMutableDictionary dictionary];

                    if ((adTitle == nil || adTitle.length == 0) &&
                        (searchTitle == nil || searchTitle.length == 0)) {
                        // Both missing → force safe defaults
                        NSString *fallbackTitle = @"untitled";
                        updates[@"adTitle"] = fallbackTitle;
                        updates[@"searchTitle"] = [ArabicNormalizer normalize:fallbackTitle];
                        NSLog(@"ℹ️ Backfilled adTitle + searchTitle (untitled) for ad %@", doc.documentID);
                    }
                    else if ((adTitle == nil || adTitle.length == 0) && searchTitle.length > 0) {
                        // adTitle missing only
                        updates[@"adTitle"] = searchTitle;
                        NSLog(@"ℹ️ Backfilled adTitle from searchTitle for ad %@", doc.documentID);
                    }
                    else if (adTitle.length > 0 && (searchTitle == nil || searchTitle.length == 0)) {
                        // searchTitle missing only
                        updates[@"searchTitle"] = [ArabicNormalizer normalize:adTitle];
                        NSLog(@"ℹ️ Backfilled searchTitle from adTitle for ad %@", doc.documentID);
                    }

                    if (updates.count > 0) {
                        [[doc reference] updateData:updates];
                    }
                    NSArray *urls = data[@"imageURLs"] ?: @[];
                    id metaField = data[@"imageMeta"];
                    // Only process if images exist and imageMeta is not set
                    if (urls.count > 0 && metaField == nil) {
                        NSString *adID = doc.documentID;
                        NSLog(@"ℹ️ Enriching ad %@ with image sizes...", adID);
                        NSMutableArray *metaArr = [NSMutableArray arrayWithCapacity:urls.count];
                        for (NSUInteger i = 0; i < urls.count; i++) {
                            [metaArr addObject:[NSNull null]];
                        }
                        dispatch_group_t g = dispatch_group_create();
                        
                        // Download each image to get dimensions
                        [urls enumerateObjectsUsingBlock:^(NSString *urlStr, NSUInteger idx, BOOL *stop) {
                            NSURL *url = [NSURL URLWithString:urlStr];
                            if (!url) return;
                            dispatch_group_enter(g);
                            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                                NSData *imgData = [NSData dataWithContentsOfURL:url];
                                if (imgData) {
                                    UIImage *img = [UIImage imageWithData:imgData];
                                    if (img) {
                                        metaArr[idx] = @{
                                            @"url": urlStr,
                                            @"width": @(img.size.width),
                                            @"height": @(img.size.height)
                                        };
                                    } else {
                                        NSLog(@"❌ Could not decode image for URL: %@", urlStr);
                                    }
                                } else {
                                    NSLog(@"❌ Failed to download image at URL: %@", urlStr);
                                }
                                dispatch_group_leave(g);
                            });
                        }];
                        
                        // Wait for all images of this ad to be processed
                        dispatch_group_wait(g, DISPATCH_TIME_FOREVER);
                        // Remove any placeholders where download failed
                        NSPredicate *notNull = [NSPredicate predicateWithFormat:@"SELF != %@", [NSNull null]];
                        [metaArr filterUsingPredicate:notNull];
                        
                        // If all images were processed, update Firestore
                        if (metaArr.count == urls.count) {
                            FIRDocumentReference *docRef = [[self.db collectionWithPath:kPetAdsCollection] documentWithPath:adID];
                            dispatch_semaphore_t sem = dispatch_semaphore_create(0);
                            [docRef updateData:@{ @"imageMeta": [metaArr copy] } completion:^(NSError *err) {
                                if (err) {
                                    NSLog(@"❌ Failed to update ad %@: %@", adID, err.localizedDescription);
                                    if (!overallError) overallError = err;  // capture the first error
                                } else {
                                    NSLog(@"✅ Added imageMeta for ad %@", adID);
                                }
                                dispatch_semaphore_signal(sem);
                            }];
                            // Wait for the Firestore update to complete before proceeding to the next document
                            dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
                        } else {
                            NSLog(@"⚠️ Skipped updating ad %@ (incomplete image data)", adID);
                        }
                    }
                }
            }
            NSLog(@"ℹ️ Completed image metadata enrichment for all ads.");
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(overallError);
                });
            }
        });
    }];
}

+ (instancetype)sharedManager {
    static PetAdManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[PetAdManager alloc] init];
        sharedInstance.db = [FIRFirestore firestore];
    });
    return sharedInstance;
}

#pragma mark - Live Snapshot Listening

- (void)startListeningForPetAdsWithFilters:(nullable NSString *)ownerID
                                  category:(NSInteger)category
                               subcategory:(NSInteger)subcategory
                         currentAdsPointer:(NSMutableArray<PetAd *> *)adsArray
                                  onChange:(void (^)(NSArray<PetAd *> *updatedAds))changeBlock {

    [self stopListening];
    
    FIRQuery *query = [self.db collectionWithPath:kPetAdsCollection];
    if (ownerID.length > 0)
        query = [query queryWhereField:@"ownerID" isEqualTo:ownerID];
    else
        query = PPPublicPetAdsQuery(query);
    if (category > 0)
        query = [query queryWhereField:@"category" isEqualTo:@(category)];
    if (subcategory > 0)
        query = [query queryWhereField:@"subcategory" isEqualTo:@(subcategory)];
    
    query = [query queryOrderedByField:@"postedDate" descending:NO];

    __weak typeof(self) weakSelf = self;
    self.listener = [query addSnapshotListener:^(FIRQuerySnapshot *snapshot, NSError *error) {
        if (error) {
            NSLog(@"❌ Firestore listener error: %@", error.localizedDescription);
            return;
        }

        for (FIRDocumentChange *change in snapshot.documentChanges) {
            NSString *docID = change.document.documentID;
            PetAd *newAd = [PetAd adFromFirestoreData:change.document.data documentID:docID];

            switch (change.type) {
                case FIRDocumentChangeTypeAdded:
                {
                    NSUInteger existingIdx = [adsArray indexOfObjectPassingTest:^BOOL(PetAd *obj, NSUInteger idx, BOOL *stop) {
                        return [obj.adID isEqualToString:docID];
                    }];
                    if (existingIdx == NSNotFound) {
                        [adsArray insertObject:newAd atIndex:0];
                    } else {
                        adsArray[existingIdx] = newAd;
                    }
                    if (newAd.imageItems.count > 0 &&
                        !(newAd.imageItems.firstObject.width > 0)) {

                        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                            [weakSelf updateImageMetadataForAdIfNeeded:newAd];
                        });
                    }
                    break;
                }
                case FIRDocumentChangeTypeModified: {
                    NSUInteger idx = [adsArray indexOfObjectPassingTest:^BOOL(PetAd *obj, NSUInteger idx, BOOL *stop) {
                        return [obj.adID isEqualToString:docID];
                    }];
                    if (idx != NSNotFound) adsArray[idx] = newAd;
                    break;
                }
                case FIRDocumentChangeTypeRemoved: {
                    NSUInteger idx = [adsArray indexOfObjectPassingTest:^BOOL(PetAd *obj, NSUInteger idx, BOOL *stop) {
                        return [obj.adID isEqualToString:docID];
                    }];
                    if (idx != NSNotFound) [adsArray removeObjectAtIndex:idx];
                    break;
                }
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (changeBlock) changeBlock([adsArray copy]);
        });
    }];
}

- (void)startListeningForPetAdsWithUpdate:(void (^)(NSArray<PetAd *> *ads))updateBlock {
    [self stopListening];
    
    self.listener = [[self.db collectionWithPath:kPetAdsCollection]
                     addSnapshotListener:^(FIRQuerySnapshot *snapshot, NSError *error) {
        if (error) {
            NSLog(@"❌ Error listening for pet ads: %@", error.localizedDescription);
            return;
        }

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            NSMutableArray *ads = [NSMutableArray array];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                [ads addObject:[PetAd adFromFirestoreData:doc.data documentID:doc.documentID]];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (updateBlock) updateBlock(ads);
            });
        });
    }];
}

- (void)stopListening {
    [self.listener remove];
    self.listener = nil;
}

- (void)dealloc {
    [self stopListening];
}

#pragma mark - CRUD Operations

- (void)fetchAllAdsWithCompletion:(PetAdListCompletion)completion {
    [[self.db collectionWithPath:kPetAdsCollection]
     getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, error);
            });
            return;
        }

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            NSMutableArray *ads = [NSMutableArray array];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                [ads addObject:[PetAd adFromFirestoreData:doc.data documentID:doc.documentID]];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion([ads copy], nil);
            });
        });
    }];
}

// Add Pet Ad with normalized searchTitle
- (void)addPetAd:(PetAd *)ad completion:(PetAdCompletion)completion {
    if (ad.adID.length == 0) {
        NSError *err = [NSError errorWithDomain:PPAdManagerErrorDomain
                                           code:1101
                                       userInfo:@{NSLocalizedDescriptionKey: @"Missing adID for create"}];
        if (completion) completion(err);
        return;
    }

    if (![ad hasValidGeoLocation]) {
        NSError *err = [NSError errorWithDomain:PPAdManagerErrorDomain
                                           code:1102
                                       userInfo:@{NSLocalizedDescriptionKey: @"Ad must include a valid location before publishing."}];
        if (completion) completion(err);
        return;
    }

    // Normalize and enforce production defaults.
    ad.geohash = PPGeoHashEncode(CLLocationCoordinate2DMake(ad.latitude, ad.longitude), 9);
    ad.status = PetAdStatusActive;
    ad.visibility = PetAdVisibilityPublic;
    ad.isApproved = YES;
    ad.isDeleted = NO;
    ad.isBlocked = NO;

    NSMutableDictionary *data = [[ad toFirestoreDictionary] mutableCopy];
    data[@"searchTitle"] = [ArabicNormalizer normalize:ad.adTitle ?: @""];
    data[@"geohash"] = ad.geohash ?: @"";
    data[@"latitude"] = @(ad.latitude);
    data[@"longitude"] = @(ad.longitude);
    data[@"location"] = [[FIRGeoPoint alloc] initWithLatitude:ad.latitude longitude:ad.longitude];
    data[@"createdAt"] = [FIRFieldValue fieldValueForServerTimestamp];
    data[@"updatedAt"] = [FIRFieldValue fieldValueForServerTimestamp];
    data[@"postedDate"] = [FIRFieldValue fieldValueForServerTimestamp];
    data[@"status"] = @(PetAdStatusActive);
    data[@"statusCode"] = @(PetAdStatusActive);
    data[@"visibility"] = @(PetAdVisibilityPublic);
    data[@"isApproved"] = @(YES);
    data[@"isDeleted"] = @(NO);
    data[@"isBlocked"] = @(NO);

    FIRDocumentReference *docRef =
    [[self.db collectionWithPath:kPetAdsCollection] documentWithPath:ad.adID];

    [docRef setData:data completion:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(error);
        });
    }];
}

// Update Pet Ad with normalized searchTitle
- (void)updatePetAd:(PetAd *)ad completion:(PetAdCompletion)completion {
    if (ad.adID.length == 0) {
        NSError *err = [NSError errorWithDomain:@"PetAdManagerError"
                                           code:1001
                                       userInfo:@{NSLocalizedDescriptionKey: @"Missing adID for update"}];
        completion(err);
        return;
    }

    if (![ad hasValidGeoLocation]) {
        NSError *err = [NSError errorWithDomain:PPAdManagerErrorDomain
                                           code:1103
                                       userInfo:@{NSLocalizedDescriptionKey: @"Ad must include a valid location before update."}];
        if (completion) completion(err);
        return;
    }

    ad.geohash = PPGeoHashEncode(CLLocationCoordinate2DMake(ad.latitude, ad.longitude), 9);

    NSMutableDictionary *data = [[ad toFirestoreDictionary] mutableCopy];
    data[@"searchTitle"] = [ArabicNormalizer normalize:ad.adTitle ?: @""];
    data[@"geohash"] = ad.geohash ?: @"";
    data[@"latitude"] = @(ad.latitude);
    data[@"longitude"] = @(ad.longitude);
    data[@"location"] = [[FIRGeoPoint alloc] initWithLatitude:ad.latitude longitude:ad.longitude];
    data[@"updatedAt"] = [FIRFieldValue fieldValueForServerTimestamp];

    // Never overwrite create timestamp from client/device time.
    [data removeObjectForKey:@"createdAt"];
    [data removeObjectForKey:@"postedDate"];

    [[[self.db collectionWithPath:kPetAdsCollection] documentWithPath:ad.adID]
     setData:data merge:YES completion:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(error);
        });
    }];
}

- (void)updatePetAdID:(NSString *)adID
           visibility:(PetAdVisibility)visibility
           completion:(PetAdCompletion)completion {
    NSString *cleanID = [adID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (cleanID.length == 0) {
        NSError *err = [NSError errorWithDomain:PPAdManagerErrorDomain
                                           code:1001
                                       userInfo:@{NSLocalizedDescriptionKey: @"Missing adID for visibility update"}];
        if (completion) completion(err);
        return;
    }

    NSDictionary *data = @{
        @"visibility": @(visibility),
        @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
    };
    [[[self.db collectionWithPath:kPetAdsCollection] documentWithPath:cleanID]
     updateData:data
     completion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(error);
        });
    }];
}

- (void)deletePetAd:(PetAd *)ad completion:(PetAdCompletion)completion {
    if (ad.adID.length == 0) {
        NSError *err = [NSError errorWithDomain:@"PetAdManagerError"
                                           code:1002
                                       userInfo:@{NSLocalizedDescriptionKey: @"Missing adID for deletion"}];
        completion(err);
        return;
    }
    
    // 🗑️ Capture image URLs before deleting so we can clean up Storage
    NSMutableArray<NSString *> *imageURLs = [NSMutableArray array];
    for (PetImageItem *item in ad.imageItems) {
        if (item.url.length > 0) [imageURLs addObject:item.url];
    }
    
    [PPImageCollection deleteEntityMediaWithEntityType:@"ads" entityID:ad.adID completion:nil];

    [[[self.db collectionWithPath:kPetAdsCollection] documentWithPath:ad.adID]
     deleteDocumentWithCompletion:^(NSError *error) {
        if (!error && imageURLs.count > 0) {
            [PPFunc pp_deleteStorageImagesForURLs:imageURLs];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(error);
        });
    }];
}

#pragma mark - Upload Images (Async & Safe)
/*- (void)uploadImages:(NSArray<NSURL *> *)images
 forAd:(PetAd *)ad
completion:(void (^)(PetAd *_Nullable updatedAd, NSError *_Nullable error))completion {

if (images.count == 0) {
dispatch_async(dispatch_get_main_queue(), ^{
if (completion) completion(ad, nil);
});
return;
}

NSMutableArray *downloadURLs = [NSMutableArray arrayWithCapacity:images.count];
NSMutableArray *metaArray    = [NSMutableArray arrayWithCapacity:images.count];
// Prepare placeholders for thread-safe assignment by index
for (NSUInteger i = 0; i < images.count; i++) {
[downloadURLs addObject:[NSNull null]];
[metaArray addObject:[NSNull null]];
}

dispatch_group_t group = dispatch_group_create();
FIRStorage *storage = [FIRStorage storage];
FIRStorageReference *storageRef = [storage reference];

[images enumerateObjectsUsingBlock:^(NSURL *imageUrl, NSUInteger idx, BOOL *stop) {
dispatch_group_enter(group);
dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
NSData *data = [NSData dataWithContentsOfURL:imageUrl];
if (!data) {
  NSLog(@"❌ Could not read image file at URL: %@", imageUrl);
  dispatch_group_leave(group);
  return;
}
UIImage *image = [UIImage imageWithData:data];
NSData *compressed = UIImageJPEGRepresentation(image, 0.75);
CGSize imgSize = image ? image.size : CGSizeZero;

NSString *fileName = [NSString stringWithFormat:@"%@_%lu.jpg", ad.adID ?: NSUUID.UUID.UUIDString, (unsigned long)idx];
FIRStorageReference *imgRef = [storageRef child:[NSString stringWithFormat:@"%@/%@", kPetAdsCollection, fileName]];

// Upload image data to Firebase Storage
[imgRef putData:compressed metadata:nil completion:^(FIRStorageMetadata *meta, NSError *error) {
  if (error) {
      NSLog(@"❌ Upload error for %@: %@", fileName, error.localizedDescription);
      dispatch_group_leave(group);
      return;
  }
  // Get the download URL once upload completes
  [imgRef downloadURLWithCompletion:^(NSURL *url, NSError *error) {
      if (url) {
          // Store the download URL and image size metadata at the correct index
          downloadURLs[idx] = url.absoluteString;
          metaArray[idx] = @{
              @"url": url.absoluteString,
              @"width": @(imgSize.width),
              @"height": @(imgSize.height)
          };
      }
      dispatch_group_leave(group);
  }];
}];
});
}];

// After all uploads complete, update the PetAd object and callback
dispatch_group_notify(group, dispatch_get_main_queue(), ^{
// Remove any placeholders (just in case)
[downloadURLs removeObjectIdenticalTo:[NSNull null]];
[metaArray removeObjectIdenticalTo:[NSNull null]];

ad.imageURLs = [downloadURLs copy];
ad.imageMeta = [metaArray copy];

NSLog(@"✅ Uploaded %lu images for ad %@ and recorded their sizes.", (unsigned long)ad.imageURLs.count, ad.adID);
if (completion) completion(ad, nil);
});
}
*/


- (void)uploadImagesFromUIImageArray:(NSArray<UIImage *> *)images
                               forAd:(PetAd *)ad
                          completion:(void (^)(PetAd *_Nullable updatedAd, NSError *_Nullable error))completion
{
    if (!ad || images.count == 0) {
        if (completion) completion(ad, nil);
        return;
    }

    FIRStorageReference *storageRef =
    [[FIRStorage storage] referenceWithPath:kPetAdsCollection];

    NSMutableArray<PetImageItem *> *items =
    [NSMutableArray arrayWithCapacity:images.count];

    dispatch_group_t group = dispatch_group_create();

    for (NSUInteger idx = 0; idx < images.count; idx++) {

        UIImage *image = images[idx];
        if (![image isKindOfClass:UIImage.class]) continue;

        dispatch_group_enter(group);

        NSData *data = UIImageJPEGRepresentation(image, 0.75);
        if (!data) {
            dispatch_group_leave(group);
            continue;
        }

        NSString *fileName =
        [NSString stringWithFormat:@"%@_%lu.jpg", ad.adID, (unsigned long)idx];

        FIRStorageReference *imgRef =
        [storageRef child:fileName];

        [imgRef putData:data metadata:nil completion:^(FIRStorageMetadata *meta, NSError *error) {

            if (error) {
                NSLog(@"❌ Image upload failed: %@", error.localizedDescription);
                dispatch_group_leave(group);
                return;
            }

            [imgRef downloadURLWithCompletion:^(NSURL *url, NSError *error) {

                if (!url) {
                    dispatch_group_leave(group);
                    return;
                }

                // 🔑 Generate blurHash ONCE (small image)
                NSString *blurHash =
                [PPBlurHashGenerator generateFrom:image];

                PetImageItem *item =
                [PetImageItem itemWithURL:url.absoluteString
                                    width:image.size.width
                                   height:image.size.height
                                 blurHash:blurHash];

                @synchronized (items) {
                    [items addObject:item];
                }

                dispatch_group_leave(group);
            }];
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{

        if (items.count == 0) {
            if (completion) completion(ad, nil);
            return;
        }

        // 🔑 SINGLE SOURCE OF TRUTH
        ad.imageItems = items.copy;

        // Persist PetImageItem dictionaries
        NSMutableArray *dicts = [NSMutableArray arrayWithCapacity:items.count];
        for (PetImageItem *item in items) {
            [dicts addObject:[item toDictionary]];
        }

        FIRDocumentReference *docRef =
        [[self.db collectionWithPath:kPetAdsCollection]
         documentWithPath:ad.adID];

        [docRef updateData:@{ @"imageMeta": dicts }
                completion:^(NSError *error) {

            if (error) {
                NSLog(@"❌ Failed saving imageItems for ad %@: %@",
                      ad.adID, error.localizedDescription);
            } else {
                NSLog(@"✅ Saved %lu PetImageItem(s) for ad %@",
                      (unsigned long)items.count, ad.adID);
            }

            if (completion) completion(ad, error);
        }];
    });
}



#pragma mark - Filtering

+ (NSArray<PetAd *> *)filterAdsByCategory:(NSInteger)categoryID targetArray:(NSArray<PetAd *> *)ads {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"category == %ld", categoryID];
    return [ads filteredArrayUsingPredicate:predicate];
}

+ (NSArray<PetAd *> *)filterAdsWithCategory:(NSInteger)category
                                subcategory:(NSInteger)subcategory
                               targetArray:(NSArray<PetAd *> *)ads {
    //NSPredicate *predicate = [NSPredicate predicateWithFormat:@"category == %ld AND subcategory == %ld", category, subcategory];
    
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(PetAd *ad, NSDictionary *bindings) {
        return ad.category == category && ad.subcategory == subcategory;
    }];
    NSLog(@"✅ filterAdsWithCategory : category %ld .....  subcategory %ld", category,subcategory);
    return [ads filteredArrayUsingPredicate:predicate];
}

#pragma mark - Favorites

+ (void)addFavoriteAdWithID:(NSString *)adID
                 collection:(NSString *)collection
                 forUserID:(NSString *)userID {
    NSString *normalizedCollection = PPCanonicalFavoritesCollection(collection);
    NSString *normalizedUserID = PPCurrentRequesterUserDocumentID(userID);
    if (normalizedCollection.length == 0 || normalizedUserID.length == 0 || adID.length == 0) {
        NSLog(@"❌ Favorite add skipped due to invalid identifiers");
        return;
    }

    FIRDocumentReference *favDoc = [[[FIRFirestore firestore]
        collectionWithPath:kUsersCollection] documentWithPath:normalizedUserID];
    
    [[[favDoc collectionWithPath:normalizedCollection] documentWithPath:adID]
     setData:@{@"favoritedAt": [FIRTimestamp timestamp]}
     completion:^(NSError * _Nullable error) {
        if (error) NSLog(@"❌ Favorite add error: %@", error.localizedDescription);
        else NSLog(@"✅ Favorite added: %@", adID);

        if (!error) {
            NSString *itemCollectionPath = PPItemCollectionPathForFavoritesCollection(normalizedCollection);
            if (itemCollectionPath.length > 0) {
                [self trackInteraction:PPItemInteractionTypeFavoriteAdd
                             forItemID:adID
                            collection:itemCollectionPath
                                userID:normalizedUserID
                            completion:nil];
            }
        }
    }];
}

+ (void)removeFavoriteAdWithID:(NSString *)adID
                    collection:(NSString *)collection
                    forUserID:(NSString *)userID {
    NSString *normalizedCollection = PPCanonicalFavoritesCollection(collection);
    NSString *normalizedUserID = PPCurrentRequesterUserDocumentID(userID);
    if (normalizedCollection.length == 0 || normalizedUserID.length == 0 || adID.length == 0) {
        NSLog(@"❌ Favorite remove skipped due to invalid identifiers");
        return;
    }

    FIRDocumentReference *favDoc = [[[FIRFirestore firestore]
        collectionWithPath:kUsersCollection] documentWithPath:normalizedUserID];
    
    [[[favDoc collectionWithPath:normalizedCollection] documentWithPath:adID]
     deleteDocumentWithCompletion:^(NSError * _Nullable error) {
        if (error) NSLog(@"❌ Favorite remove error: %@", error.localizedDescription);
        else NSLog(@"✅ Favorite removed: %@", adID);

        if (!error) {
            NSString *itemCollectionPath = PPItemCollectionPathForFavoritesCollection(normalizedCollection);
            if (itemCollectionPath.length > 0) {
                [self trackInteraction:PPItemInteractionTypeFavoriteRemove
                             forItemID:adID
                            collection:itemCollectionPath
                                userID:normalizedUserID
                            completion:nil];
            }
        }
    }];
}
 
- (void)fetchSimilarAdsForAd:(PetAd *)ad
                       limit:(NSInteger)limit
                  completion:(void (^)(NSArray<PetAd *> *ads))completion
{
    if (!ad || ad.category <= 0) {
        if (completion) completion(@[]);
        return;
    }

    if (limit <= 0) {
        limit = 10;
    }

    FIRQuery *query = PPPublicPetAdsQuery([self.db collectionWithPath:kPetAdsCollection]);

    // Same main category
    query =
        [query queryWhereField:@"category"
                   isEqualTo:@(ad.category)];

    // Same subcategory if available
    if (ad.subcategory > 0) {
        query =
            [query queryWhereField:@"subcategory"
                       isEqualTo:@(ad.subcategory)];
    }

    // Order by newest
    query =
        [[query queryOrderedByField:@"postedDate" descending:YES]
         queryLimitedTo:limit + 1]; // +1 so we can safely exclude current ad

    [query getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {

        if (error || !snapshot) {
            NSLog(@"❌ fetchSimilarAdsForAd error: %@",
                  error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(@[]);
            });
            return;
        }

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{

            NSMutableArray<PetAd *> *results = [NSMutableArray array];

            for (FIRDocumentSnapshot *doc in snapshot.documents) {

                // Exclude current ad
                if ([doc.documentID isEqualToString:ad.adID]) {
                    continue;
                }

                PetAd *item =
                    [PetAd adFromFirestoreData:doc.data
                                    documentID:doc.documentID];
                if (!item) continue;

                [results addObject:item];

                if (results.count >= limit) {
                    break;
                }
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(PPFilterAdsByVisibleCategories(results));
            });
        });
    }];
}


+ (void)addFavoriteAdWithID:(NSString *)adID
                 collection:(NSString *)collection
                  forUserID:(NSString *)userID
                 completion:(void (^)(NSError * _Nullable error))completion
{
    NSString *normalizedCollection = PPCanonicalFavoritesCollection(collection);
    NSString *normalizedUserID = PPCurrentRequesterUserDocumentID(userID);
    if (normalizedCollection.length == 0 || normalizedUserID.length == 0 || adID.length == 0) {
        NSError *invalidError = [NSError errorWithDomain:PPAdManagerErrorDomain
                                                    code:400
                                                userInfo:@{NSLocalizedDescriptionKey: @"Invalid favorite identifiers"}];
        if (completion) completion(invalidError);
        return;
    }

    FIRDocumentReference *favDoc =
    [[[FIRFirestore firestore] collectionWithPath:kUsersCollection]
     documentWithPath:normalizedUserID];

    [[[favDoc collectionWithPath:normalizedCollection] documentWithPath:adID]
     setData:@{ @"favoritedAt": [FIRTimestamp timestamp] }
     completion:^(NSError * _Nullable error) {

        if (error) {
            NSLog(@"❌ Favorite add error: %@", error.localizedDescription);
        } else {
            NSLog(@"✅ Favorite added: %@", adID);
        }

        if (!error) {
            NSString *itemCollectionPath = PPItemCollectionPathForFavoritesCollection(normalizedCollection);
            if (itemCollectionPath.length > 0) {
                [self trackInteraction:PPItemInteractionTypeFavoriteAdd
                             forItemID:adID
                            collection:itemCollectionPath
                                userID:normalizedUserID
                            completion:nil];
            }
        }

        if (completion) {
            completion(error);
        }
    }];
}


+ (void)removeFavoriteAdWithID:(NSString *)adID
                    collection:(NSString *)collection
                     forUserID:(NSString *)userID
                    completion:(void (^)(NSError * _Nullable error))completion
{
    NSString *normalizedCollection = PPCanonicalFavoritesCollection(collection);
    NSString *normalizedUserID = PPCurrentRequesterUserDocumentID(userID);
    if (normalizedCollection.length == 0 || normalizedUserID.length == 0 || adID.length == 0) {
        NSError *invalidError = [NSError errorWithDomain:PPAdManagerErrorDomain
                                                    code:400
                                                userInfo:@{NSLocalizedDescriptionKey: @"Invalid favorite identifiers"}];
        if (completion) completion(invalidError);
        return;
    }

    FIRDocumentReference *favDoc =
    [[[FIRFirestore firestore] collectionWithPath:kUsersCollection]
     documentWithPath:normalizedUserID];

    [[[favDoc collectionWithPath:normalizedCollection] documentWithPath:adID]
     deleteDocumentWithCompletion:^(NSError * _Nullable error) {

        if (error) {
            NSLog(@"❌ Favorite remove error: %@", error.localizedDescription);
        } else {
            NSLog(@"✅ Favorite removed: %@", adID);
        }

        if (!error) {
            NSString *itemCollectionPath = PPItemCollectionPathForFavoritesCollection(normalizedCollection);
            if (itemCollectionPath.length > 0) {
                [self trackInteraction:PPItemInteractionTypeFavoriteRemove
                             forItemID:adID
                            collection:itemCollectionPath
                                userID:normalizedUserID
                            completion:nil];
            }
        }

        if (completion) {
            completion(error);
        }
    }];
}

+ (void)trackInteraction:(PPItemInteractionType)interaction
               forItemID:(NSString *)itemID
              collection:(NSString *)collectionPath
                  userID:(NSString * _Nullable)userID
              completion:(void (^ _Nullable)(NSError * _Nullable error))completion
{
    if (itemID.length == 0 || collectionPath.length == 0) {
        if (completion) completion(nil);
        return;
    }

    NSString *subcollection = PPSubcollectionForInteraction(interaction);
    NSString *countField = PPCountFieldForInteraction(interaction);
    if (subcollection.length == 0 || countField.length == 0) {
        if (completion) completion(nil);
        return;
    }

    NSString *authUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (authUID.length == 0) {
        if (completion) completion(nil);
        return;
    }

    NSString *safeUserID = [[userID ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    if (safeUserID.length == 0) {
        safeUserID = authUID;
    }
    if (![safeUserID isEqualToString:authUID]) {
        if (completion) completion(nil);
        return;
    }

    if (safeUserID.length == 0) {
        if (completion) completion(nil);
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *itemDoc = [[db collectionWithPath:collectionPath] documentWithPath:itemID];
    FIRDocumentReference *interactionDoc = [[itemDoc collectionWithPath:subcollection] documentWithPath:safeUserID];
    BOOL isRemoval = (interaction == PPItemInteractionTypeFavoriteRemove);

    [db runTransactionWithBlock:^id _Nullable(FIRTransaction * _Nonnull transaction, NSError ** _Nonnull errorPointer) {
        FIRDocumentSnapshot *snapshot = [transaction getDocument:interactionDoc error:errorPointer];
        if (*errorPointer) {
            return nil;
        }

        BOOL exists = snapshot.exists;
        if (isRemoval) {
            if (!exists) {
                return @NO;
            }

            [transaction deleteDocument:interactionDoc];
            [transaction setData:@{
                countField: [FIRFieldValue fieldValueForIntegerIncrement:-1],
                @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
            } forDocument:itemDoc merge:YES];
            return @YES;
        }

        if (exists) {
            [transaction setData:@{
                @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
            } forDocument:interactionDoc merge:YES];
            return @NO;
        }

        [transaction setData:@{
            @"userID": safeUserID,
            @"createdAt": [FIRFieldValue fieldValueForServerTimestamp],
            @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
        } forDocument:interactionDoc merge:YES];

        [transaction setData:@{
            countField: [FIRFieldValue fieldValueForIntegerIncrement:1],
            @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
        } forDocument:itemDoc merge:YES];

        return @YES;
    } completion:^(id  _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"❌ Interaction track failed [%@/%@/%@]: %@",
                      collectionPath,
                      itemID,
                      subcollection,
                      error.localizedDescription);
            }
            if (completion) completion(error);
        });
    }];
}

+ (void)isAdFavorited:(NSString *)adID
              forUser:(NSString *)userID
           collection:(NSString *)collection
           completion:(void (^)(BOOL favorited))completion {
    NSString *normalizedCollection = PPCanonicalFavoritesCollection(collection);
    NSString *normalizedUserID = PPCurrentRequesterUserDocumentID(userID);
    if (normalizedUserID.length < 1 || normalizedCollection.length < 1 || adID.length < 1) {
        if (completion) completion(NO);
        return;
    }
    FIRDocumentReference *docRef = [[[[[FIRFirestore firestore]
                                       collectionWithPath:kUsersCollection] documentWithPath:normalizedUserID]
                                       collectionWithPath:normalizedCollection] documentWithPath:adID];
    
    [docRef getDocumentWithSource:FIRFirestoreSourceCache completion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (error.code != FIRFirestoreErrorCodeUnavailable) {
                    NSLog(@"❌ Favorite check error: %@", error.localizedDescription);
                }
                completion(NO);
            } else {
                completion(snapshot.exists);
            }
        });
    }];
}

+ (void)fetchFavoriteAdIDsForUserID:(NSString *)userID
                         collection:(NSString *)collection
                         completion:(void (^)(NSArray<NSString *> *adIDs))completion {
    NSString *normalizedCollection = PPCanonicalFavoritesCollection(collection);
    NSString *normalizedUserID = PPCurrentRequesterUserDocumentID(userID);
    if (normalizedUserID.length == 0 || normalizedCollection.length == 0) {
        if (completion) completion(@[]);
        return;
    }

    FIRCollectionReference *favCol = [[[[FIRFirestore firestore] collectionWithPath:kUsersCollection] documentWithPath:normalizedUserID] collectionWithPath:normalizedCollection];
    
    [favCol getDocumentsWithSource:FIRFirestoreSourceCache completion:^(FIRQuerySnapshot *snapshot, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (error.code != FIRFirestoreErrorCodeUnavailable) {
                    NSLog(@"❌ Fetch favorites error: %@", error.localizedDescription);
                }
                completion(@[]);
                return;
            }

            NSMutableArray *ids = [NSMutableArray array];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                [ids addObject:doc.documentID];
            }
            completion([ids copy]);
        });
    }];
}

#pragma mark - Counts & Fetches

- (void)getAdsCountForCategory:(NSInteger)categoryID completion:(void(^)(NSInteger count))completion {
    [[PPPublicPetAdsQuery([self.db collectionWithPath:kPetAdsCollection])
      queryWhereField:@"category" isEqualTo:@(categoryID)]
     getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"❌ Count fetch error: %@", error.localizedDescription);
                completion(0);
            } else {
                completion(snapshot.documents.count);
            }
        });
    }];
}


- (void)getAdsForCategory:(NSInteger)categoryID subCategory:(NSInteger)subcategory completion:(void (^)(NSArray<PetAd *> *_Nullable ads))completion {
    [[[PPPublicPetAdsQuery([self.db collectionWithPath:kPetAdsCollection])
       queryWhereField:@"category" isEqualTo:@(categoryID)]
      queryWhereField:@"subcategory" isEqualTo:@(subcategory)]
     
     getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"❌ Count fetch error: %@", error.localizedDescription);
                completion(nil);
            } else {
                
                
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                    NSMutableArray<PetAd *> *ads = [NSMutableArray array];
                    for (FIRDocumentSnapshot *doc in snapshot.documents) {
                        [ads addObject:[PetAd adFromFirestoreData:doc.data documentID:doc.documentID]];
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion([ads copy]);
                    });
                });
                
                
            }
        });
    }];
}

+ (void)fetchAdsForUserID:(NSString *)userID completion:(void (^)(NSArray<PetAd *> *ads))completion {
    FIRFirestore *db = [FIRFirestore firestore];
    [[[db collectionWithPath:kPetAdsCollection]
       queryWhereField:@"ownerID" isEqualTo:userID]
       getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            NSMutableArray<PetAd *> *ads = [NSMutableArray array];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                [ads addObject:[PetAd adFromFirestoreData:doc.data documentID:doc.documentID]];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                completion([ads copy]);
            });
        });
    }];
}

+ (void)fetchAdsWithIDs:(NSArray<NSString *> *)adIDs completion:(void (^)(NSArray<PetAd *> *ads))completion {
    NSMutableOrderedSet<NSString *> *cleanIDs = [NSMutableOrderedSet orderedSet];
    for (NSString *adID in adIDs) {
        NSString *cleanID = [adID isKindOfClass:NSString.class]
            ? [adID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
            : @"";
        if (cleanID.length > 0) {
            [cleanIDs addObject:cleanID];
        }
    }

    if (cleanIDs.count == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(@[]); });
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    NSMutableDictionary<NSString *, PetAd *> *resultsByID = [NSMutableDictionary dictionary];
    dispatch_queue_t syncQueue = dispatch_queue_create("com.purepets.petads.fetchByIDs", DISPATCH_QUEUE_SERIAL);
    dispatch_group_t group = dispatch_group_create();

    for (NSString *adID in cleanIDs.array) {
        dispatch_group_enter(group);
        [[[db collectionWithPath:kPetAdsCollection] documentWithPath:adID]
         getDocumentWithCompletion:^(FIRDocumentSnapshot *doc, NSError *error) {
            if (error) {
                NSLog(@"[PetAdManager] fetchAdsWithIDs failed id=%@ error=%@", adID, error.localizedDescription);
            }
            if (doc.exists && doc.data) {
                PetAd *ad = [PetAd adFromFirestoreData:doc.data documentID:doc.documentID];
                if (ad && !ad.isDeleted && !ad.isBlocked) {
                    dispatch_sync(syncQueue, ^{
                        resultsByID[doc.documentID] = ad;
                    });
                }
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSMutableArray<PetAd *> *ordered = [NSMutableArray arrayWithCapacity:cleanIDs.count];
        for (NSString *adID in cleanIDs.array) {
            PetAd *ad = resultsByID[adID];
            if (ad) {
                [ordered addObject:ad];
            } else {
                NSLog(@"[PetAdManager] fetchAdsWithIDs unresolved id=%@", adID);
            }
        }
        completion(ordered.copy);
    });
}

+ (UIImage *)imageWithLogoWatermark:(UIImage *)originalImage logo:(UIImage *)logoImage {
    CGSize imageSize = originalImage.size;
    UIGraphicsBeginImageContextWithOptions(imageSize, NO, originalImage.scale);
    
    // Draw the original image
    [originalImage drawInRect:CGRectMake(0, 0, imageSize.width, imageSize.height)];
    
    // Define logo size and position (bottom-right corner)
    CGFloat logoSize = imageSize.width * 0.25; // 15% of image width
    CGFloat margin = 10.0;
    CGRect logoRect = CGRectMake(imageSize.width - logoSize - margin,
                                 imageSize.height - logoSize,
                                 logoSize,
                                 logoSize);
    
    [logoImage drawInRect:logoRect blendMode:kCGBlendModeNormal alpha:0.85];
    
    UIImage *watermarkedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return watermarkedImage;
}


- (void)updateImageMetadataForAdIfNeeded:(PetAd *)ad
{
    if (!ad || ad.adID.length == 0) return;

    NSArray<PetImageItem *> *items = ad.imageItems;
    if (items.count == 0) return;

    // If first item already has dimensions, assume metadata is complete
    if (items.firstObject.width > 0 && items.firstObject.height > 0) return;

    NSLog(@"[ImageMeta] Enriching PetImageItem metadata for ad %@", ad.adID);

    NSMutableArray<NSDictionary *> *finalMeta =
    [NSMutableArray arrayWithCapacity:items.count];

    dispatch_group_t group = dispatch_group_create();

    for (PetImageItem *item in items) {

        dispatch_group_enter(group);

        NSURL *url = [NSURL URLWithString:item.url];
        if (!url) {
            dispatch_group_leave(group);
            continue;
        }

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            NSData *data = [NSData dataWithContentsOfURL:url];
            if (data) {
                UIImage *img = [UIImage imageWithData:data];
                if (img) {
                    PetImageItem *enriched =
                    [PetImageItem itemWithURL:item.url
                                        width:img.size.width
                                       height:img.size.height
                                     blurHash:item.blurHash];

                    @synchronized (finalMeta) {
                        [finalMeta addObject:[enriched toDictionary]];
                    }
                }
            }
            dispatch_group_leave(group);
        });
    }

    dispatch_group_notify(group, dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{

        if (finalMeta.count == 0) return;

        FIRDocumentReference *docRef =
        [[self.db collectionWithPath:kPetAdsCollection]
         documentWithPath:ad.adID];

        // 🔑 Persist PetImageItem dictionaries (still under imageMeta for now)
        [docRef updateData:@{ @"imageMeta": finalMeta }
                completion:^(NSError * _Nullable error) {

            if (error) {
                NSLog(@"[ImageMeta] ❌ Failed updating PetImageItem meta for ad %@: %@",
                      ad.adID, error.localizedDescription);
            } else {
                NSLog(@"[ImageMeta] ✅ PetImageItem metadata saved for ad %@ (%lu items)",
                      ad.adID, (unsigned long)finalMeta.count);
            }
        }];
    });
}


#pragma mark - Category Live Listener

- (void)listenForCategory:(NSInteger)categoryID
                 onChange:(void (^)(NSArray<PetAd *> *updatedAds))changeBlock
{
    // stop any existing listener
    [self stopListening];

    NSMutableArray<PetAd *> *adsBuffer = [NSMutableArray array];

    FIRQuery *query = [PPPublicPetAdsQuery([self.db collectionWithPath:kPetAdsCollection])
                       queryWhereField:@"category" isEqualTo:@(categoryID)];

    query = [query queryOrderedByField:@"postedDate" descending:NO];

    __weak typeof(self) weakSelf = self;
    self.listener =
    [query addSnapshotListener:^(FIRQuerySnapshot *snapshot, NSError *error) {

        if (error) {
            NSLog(@"❌ listenForCategory(%ld) error: %@", (long)categoryID, error.localizedDescription);
            return;
        }

        for (FIRDocumentChange *change in snapshot.documentChanges) {
            NSString *docID = change.document.documentID;
            PetAd *ad = [PetAd adFromFirestoreData:change.document.data documentID:docID];

            switch (change.type) {

                case FIRDocumentChangeTypeAdded:
                {
                    NSUInteger existingIdx = [adsBuffer indexOfObjectPassingTest:^BOOL(PetAd *obj, NSUInteger idx, BOOL *stop) {
                        return [obj.adID isEqualToString:docID];
                    }];
                    if (existingIdx == NSNotFound) {
                        [adsBuffer insertObject:ad atIndex:0];
                    } else {
                        adsBuffer[existingIdx] = ad;
                    }
                    
                    // auto-enrich metadata
                    if (ad.imageItems.count > 0 && !([ad.imageItems.firstObject width] > 0)) {
                        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                            [weakSelf updateImageMetadataForAdIfNeeded:ad];
                        });
                    }
                    break;
                }

                case FIRDocumentChangeTypeModified: {
                    NSUInteger idx = [adsBuffer indexOfObjectPassingTest:^BOOL(PetAd *obj, NSUInteger idx, BOOL *stop) {
                        return [obj.adID isEqualToString:docID];
                    }];
                    if (idx != NSNotFound) adsBuffer[idx] = ad;
                    break;
                }

                case FIRDocumentChangeTypeRemoved: {
                    NSUInteger idx = [adsBuffer indexOfObjectPassingTest:^BOOL(PetAd *obj, NSUInteger idx, BOOL *stop) {
                        return [obj.adID isEqualToString:docID];
                    }];
                    if (idx != NSNotFound) [adsBuffer removeObjectAtIndex:idx];
                    break;
                }
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (changeBlock) changeBlock(adsBuffer.copy);
        });
    }];
}

- (void)populateMissingSearchTitleForExistingAds
{
    [[self.db collectionWithPath:kPetAdsCollection]
     getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {

        if (error) {
            NSLog(@"❌ Migration error: %@", error.localizedDescription);
            return;
        }

        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            NSString *title = doc.data[@"adTitle"];
            NSString *searchTitle = doc.data[@"searchTitle"];

            if (title.length > 0 && searchTitle.length == 0) {
                NSString *normalized = [ArabicNormalizer normalize:title];
                [[doc reference] updateData:@{
                    @"searchTitle": normalized
                }];
            }
        }

        NSLog(@"✅ searchTitle migration completed");
    }];
}



- (void)migrateImageMetaToImageItemsOnce
{
    NSLog(@"🚀 Starting imageMeta → imageItems migration");

    FIRFirestore *db = [FIRFirestore firestore];

    [[db collectionWithPath:kPetAdsCollection]
     getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {

        if (error) {
            NSLog(@"❌ Failed fetching ads: %@", error.localizedDescription);
            return;
        }

        for (FIRDocumentSnapshot *doc in snapshot.documents) {

            NSDictionary *data = doc.data;

            // ✅ Skip if already migrated
            if ([data[@"imageItems"] isKindOfClass:NSArray.class]) {
                continue;
            }

            NSArray *legacyMeta = data[@"imageMeta"];
            if (![legacyMeta isKindOfClass:NSArray.class] || legacyMeta.count == 0) {
                continue;
            }

            NSLog(@"🔄 Migrating ad %@", doc.documentID);

            NSMutableArray *imageItems = [NSMutableArray array];
            dispatch_group_t group = dispatch_group_create();

            for (NSDictionary *m in legacyMeta) {

                NSString *urlString = m[@"url"];
                if (urlString.length == 0) continue;

                CGFloat width  = [m[@"width"] doubleValue];
                CGFloat height = [m[@"height"] doubleValue];

                dispatch_group_enter(group);

                NSURL *url = [NSURL URLWithString:urlString];

                [[SDWebImageManager sharedManager]
                 loadImageWithURL:url
                 options:SDWebImageLowPriority
                 progress:nil
                 completed:^(UIImage *image,
                             NSData *data,
                             NSError *error,
                             SDImageCacheType cacheType,
                             BOOL finished,
                             NSURL *imageURL)
                {
                    NSString *blurHash = nil;

                    if (image) {
                        blurHash = [PPBlurHashGenerator generateFrom:image];
                    }

                    NSMutableDictionary *item = [@{
                        @"url": urlString,
                        @"width": @(width),
                        @"height": @(height)
                    } mutableCopy];

                    if (blurHash.length > 0) {
                        item[@"blurHash"] = blurHash;
                    }

                    @synchronized (imageItems) {
                        [imageItems addObject:item];
                    }

                    dispatch_group_leave(group);
                }];
            }

            dispatch_group_notify(group, dispatch_get_main_queue(), ^{

                if (imageItems.count == 0) {
                    NSLog(@"⚠️ No valid images for %@", doc.documentID);
                    return;
                }

                [[doc reference]
                 updateData:@{
                    @"imageItems": imageItems
                 } completion:^(NSError *error) {

                    if (error) {
                        NSLog(@"❌ Failed updating %@: %@",
                              doc.documentID,
                              error.localizedDescription);
                    } else {
                        NSLog(@"✅ Migrated %@ (%lu images)",
                              doc.documentID,
                              (unsigned long)imageItems.count);
                    }
                }];
            });
        }

        NSLog(@"🎉 Migration scan finished");
    }];
}


#pragma mark - One Time Admin Utilities

// ⚠️ ONE TIME USE: Approves all ads in the collection
- (void)approveAllAdsOnceWithCompletion:(void (^)(NSError * _Nullable error))completion
{
    NSLog(@"🚀 Starting one-time approval of all ads...");

    FIRFirestore *db = [FIRFirestore firestore];

    [[db collectionWithPath:kPetAdsCollection]
     getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {

        if (error) {
            NSLog(@"❌ Failed fetching ads: %@", error.localizedDescription);
            if (completion) completion(error);
            return;
        }

        dispatch_group_t group = dispatch_group_create();

        for (FIRDocumentSnapshot *doc in snapshot.documents) {

            NSNumber *isApproved = doc.data[@"isApproved"];

            // Skip already approved ads
            if ([isApproved boolValue]) {
                continue;
            }

            dispatch_group_enter(group);

            [[doc reference]
             updateData:@{
                @"isApproved": @(YES),
                @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
             }
             completion:^(NSError * _Nullable err) {

                if (err) {
                    NSLog(@"❌ Failed approving %@: %@",
                          doc.documentID,
                          err.localizedDescription);
                } else {
                    NSLog(@"✅ Approved ad %@", doc.documentID);
                }

                dispatch_group_leave(group);
            }];
        }

        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            NSLog(@"🎉 All ads approval process finished");
            if (completion) completion(nil);
        });
    }];
}


@end
