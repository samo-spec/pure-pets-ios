//
//  SearchManager 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 12/08/2025.
//


#import "SearchManager.h"
#import "PetAdManager.h"
#import "PetAccessoryManager.h"
#import "ServicesManager.h"
#import "VetManager.h"


#import "PetAd.h"
#import "PetAccessory.h"
#import "ServiceModel.h"
#import "VetModel.h"

@interface SearchManager ()
@property (nonatomic, strong) NSArray<PetAd *> *ads;
@property (nonatomic, strong) NSArray<PetAccessory *> *accessories;
@property (nonatomic, strong) NSArray<PetAccessory *> *foods;
@property (nonatomic, strong) NSArray<ServiceModel *> *services;
@property (nonatomic, strong) NSArray<VetModel *> *vets;
@property (nonatomic, assign) BOOL warmedUp;
@property (nonatomic, strong) dispatch_queue_t workQ;
@end

@implementation SearchManager

+ (instancetype)shared {
    static SearchManager *S;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        S = [SearchManager new];
        S.workQ = dispatch_queue_create("purepets.search.workq", DISPATCH_QUEUE_CONCURRENT);
    });
    return S;
}

- (void)invalidateCache {
    NSLog(@"🗑 SearchManager cache invalidated");
    self.warmedUp = NO;
    self.ads = nil;
    self.accessories = nil;
    self.services = nil;
    self.vets = nil;
    self.foods = nil;
}

- (void)warmUpIfNeeded:(void(^_Nullable)(void))completion {
    if (self.warmedUp) {
        NSLog(@"⚡ SearchManager warm-up skipped (already warmed)");
        if (completion) completion();
        return;
    }

    NSLog(@"SearchManager starting warm-up...");
    dispatch_group_t g = dispatch_group_create();

    // Ads
    dispatch_group_enter(g);
    [[PetAdManager sharedManager] fetchAllAdsWithCompletion:^(NSArray<PetAd *> * _Nonnull ads, NSError * _Nonnull error) {
        self.ads = error ? @[] : (ads ?: @[]);
        NSLog(@"📢 Warm-up: Loaded %lu ads (error: %@)", (unsigned long)self.ads.count, error.localizedDescription ?: @"none");
        dispatch_group_leave(g);
    }];

    // Accessories
    dispatch_group_enter(g);
    [[PetAccessoryManager sharedManager] loadAllAccessories:^(NSArray<PetAccessory *> * _Nonnull accessories) {
        self.accessories = accessories ?: @[];
        NSLog(@"📢 Warm-up: Loaded %lu accessories", (unsigned long)self.accessories.count);
        dispatch_group_leave(g);
    }];

    // Services (first return only)
    dispatch_group_enter(g);
    __block BOOL servicesFirst = NO;
    [[ServicesManager sharedInstance] listenToAllServicesWithCompletion:^(NSArray<ServiceModel *> * _Nonnull services, NSError * _Nullable error) {
        self.services = error ? @[] : (services ?: @[]);
        if (!servicesFirst) {
            servicesFirst = YES;
            NSLog(@"📢 Warm-up: Loaded %lu services (error: %@)", (unsigned long)self.services.count, error.localizedDescription ?: @"none");
            dispatch_group_leave(g);
        }
    }];

    // Vets
    dispatch_group_enter(g);
    [[VetManager sharedManager] fetchAllVetsWithCompletion:^(NSArray<VetModel *> * _Nonnull vetsArray, NSError * _Nullable error) {
        self.vets = error ? @[] : (vetsArray ?: @[]);
        NSLog(@"📢 Warm-up: Loaded %lu vets (error: %@)", (unsigned long)self.vets.count, error.localizedDescription ?: @"none");
        dispatch_group_leave(g);
    }];
    
    dispatch_group_notify(g, dispatch_get_main_queue(), ^{
        self.warmedUp = YES;
        NSLog(@"✅ SearchManager warm-up complete");
        if (completion) completion();
    });
}

#pragma mark - Search

static inline NSString *Norm(NSString *s) {
    if (!s) return @"";
    return [[s lowercaseString] stringByFoldingWithOptions:NSDiacriticInsensitiveSearch
                                                    locale:[NSLocale currentLocale]];
}

- (void)searchText:(NSString *)text completion:(void(^)(NSArray<SearchResultItem *> *results))completion {
    NSString *q = Norm(text);
    NSLog(@"🔍 Search started for query: '%@'", q);

    if (q.length == 0) {
        NSLog(@"⚠️ Search query empty — returning no results");
        if (completion) completion(@[]);
        return;
    }

    void (^doSearch)(void) = ^{
        NSMutableArray<SearchResultItem *> *acc = [NSMutableArray arrayWithCapacity:32];
        NSUInteger adMatches = 0, accMatches = 0, svcMatches = 0, vetMatches = 0;

        // Ads
        for (PetAd *ad in self.ads) {
            NSString *title = ad.adTitle ?: @"";
            NSString *sub = ad.adDescription ?: @"";
            BOOL hit = [Norm(title) containsString:q] ||
                       [Norm(sub) containsString:q] ||
            [Norm([CitiesManager.shared cityNameForID:ad.adLocation] ?: @"") containsString:q];

            if (hit) {
                adMatches++;

                NSString *img = @"";
                PetImageItem *firstItem = ad.imageItems.firstObject;
                if (firstItem.url.length > 0) {
                    img = firstItem.url;
                }

                [acc addObject:[SearchResultItem itemWithType:SearchResultTypePetAd
                                                       title:title
                                                    subtitle:[GM formatPrice:ad.price currencyCode:kLang(@"Rials")].length
                                                             ? [GM formatPrice:ad.price currencyCode:kLang(@"Rials")]
                                                             : (sub ?: @"")
                                                     imageURL:img
                                                    rawObject:ad]];
            }
        }

        // Accessories
        for (PetAccessory *a in self.accessories) {
            NSString *title = a.name ?: @"";
            NSString *sub = a.desc ?: @"";
            BOOL hit = [Norm(title) containsString:q] || [Norm(sub) containsString:q];
            if (hit) {
                accMatches++;
                NSString *img = a.imageURLsArray.firstObject ?: @"";
                SearchResultType searchResultType = a.accessKindType == AccessTypeFood ? SearchResultTypeFood : SearchResultTypeAccessory;
                [acc addObject:[SearchResultItem itemWithType:searchResultType
                                                       title:title
                                                    subtitle:sub
                                                     imageURL:img
                                                    rawObject:a]];
            }
        }

        // Services
        for (ServiceModel *s in self.services) {
            NSString *title = s.title ?: @"";
            NSString *sub = s.desc ?: @"";
            BOOL hit = [Norm(title) containsString:q] ||
                       [Norm(sub) containsString:q] ||
                       [Norm(s.category ?: @"") containsString:q];
            if (hit) {
                svcMatches++;
                [acc addObject:[SearchResultItem itemWithType:SearchResultTypeService
                                                       title:title
                                                    subtitle:sub.length ? sub : (s.category ?: @"")
                                                     imageURL:(s.imageURL ?: @"")
                                                    rawObject:s]];
            }
        }

        // Vets
        for (VetModel *v in self.vets) {
            NSString *title = v.title ?: @"";
            NSString *sub   = v.descriptionText ?: @"";
            BOOL hit = [Norm(title) containsString:q] || [Norm(sub) containsString:q];
            if (hit) {
                vetMatches++;
                [acc addObject:[SearchResultItem itemWithType:SearchResultTypeVet
                                                       title:title
                                                    subtitle:sub
                                                     imageURL:(v.logoURL ?: @"")
                                                    rawObject:v]];
            }
        }

        NSLog(@"📊 Search results count: Ads=%lu, Accessories=%lu, Services=%lu, Vets=%lu, Total=%lu",
              (unsigned long)adMatches,
              (unsigned long)accMatches,
              (unsigned long)svcMatches,
              (unsigned long)vetMatches,
              (unsigned long)acc.count);

        // Sort results
        [acc sortUsingComparator:^NSComparisonResult(SearchResultItem * _Nonnull a, SearchResultItem * _Nonnull b) {
            BOOL aHit = [Norm(a.titleText) containsString:q];
            BOOL bHit = [Norm(b.titleText) containsString:q];
            if (aHit != bHit) return aHit ? NSOrderedAscending : NSOrderedDescending;
            return a.titleText.length <= b.titleText.length ? NSOrderedAscending : NSOrderedDescending;
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(acc);
        });
    };

    if (!self.warmedUp) {
        NSLog(@"⏳ Search triggered before warm-up — warming up now...");
        [self warmUpIfNeeded:^{
            dispatch_async(self.workQ, doSearch);
        }];
    } else {
        dispatch_async(self.workQ, doSearch);
    }
}

@end

