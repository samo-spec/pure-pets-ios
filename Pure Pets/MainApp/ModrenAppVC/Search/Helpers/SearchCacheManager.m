//
//  SearchCacheManager 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 12/01/2026.
//


#import "SearchCacheManager.h"
#import "PetAdManager.h"
#import "PetAccessoryManager.h"
#import "ServicesManager.h"
#import "ArabicNormalizer.h"

@interface SearchCacheManager ()

@property (nonatomic, strong) NSArray<PetAd *> *ads;
@property (nonatomic, strong) NSArray<PetAccessory *> *accessories;
@property (nonatomic, strong) NSArray<ServiceModel *> *services;

@property (nonatomic, assign) BOOL didWarmUp;
@property (nonatomic, assign) BOOL isWarmingUp;

@end

@implementation SearchCacheManager

+ (instancetype)shared {
    static SearchCacheManager *m;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        m = [SearchCacheManager new];
    });
    return m;
}

#pragma mark - Warm Up

- (void)warmUpCacheIfNeeded:(nullable SearchCacheCompletion)completion {
    if (self.didWarmUp) {
        if (completion) completion();
        return;
    }

    if (self.isWarmingUp) {
        return;
    }

    self.isWarmingUp = YES;

    dispatch_group_t group = dispatch_group_create();

    // Ads
    dispatch_group_enter(group);
    [[PetAdManager sharedManager] fetchAllAdsWithCompletion:^(NSArray<PetAd *> * _Nullable ads, NSError * _Nullable error) {
        self.ads = ads ?: @[];
        dispatch_group_leave(group);
    }];

    // Accessories
    dispatch_group_enter(group);
    [[PetAccessoryManager sharedManager] fetchAccessoriesForAllMainKinds:^(NSArray<PetAccessory *> * _Nonnull accessories) {
        self.accessories = accessories ?: @[];
        dispatch_group_leave(group);
    }];

    // Services
    dispatch_group_enter(group);
    [[ServicesManager sharedInstance] fetchServicesForAllMainKinds:^(NSArray<ServiceModel *> * _Nonnull services, NSError * _Nullable error) {
        self.services = services ?: @[];
        dispatch_group_leave(group);
    }];

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        self.didWarmUp = YES;
        self.isWarmingUp = NO;

        NSLog(@"🔥 SearchCache warm-up finished | ads=%lu acc=%lu services=%lu",
              (unsigned long)self.ads.count,
              (unsigned long)self.accessories.count,
              (unsigned long)self.services.count);

        if (completion) completion();
    });
}

#pragma mark - Search

- (NSArray *)searchWithQuery:(NSString *)query {
    if (query.length == 0) return @[];

    NSString *normalized =
        [ArabicNormalizer normalize:query];

    NSMutableArray *results = [NSMutableArray array];

    // Ads
    for (PetAd *ad in self.ads) {
        if ([self matchText:ad.searchTitle query:normalized]) {
            [results addObject:ad];
        }
    }

    // Accessories
    for (PetAccessory *a in self.accessories) {
        if ([self matchText:a.searchTitle query:normalized]) {
            [results addObject:a];
        }
    }

    // Services
    for (ServiceModel *s in self.services) {
        if ([self matchText:s.searchTitle query:normalized]) {
            [results addObject:s];
        }
    }

    return results;
}

#pragma mark - Matching Logic

- (BOOL)matchText:(NSString *)text query:(NSString *)query {
    if (text.length == 0 || query.length == 0) return NO;

    // CONTAINS
    if ([text containsString:query]) return YES;

    // PREFIX
    if ([text hasPrefix:query]) return YES;

    // END
    if ([text hasSuffix:query]) return YES;

    return NO;
}

#pragma mark - Clear

- (void)clearCache {
    self.ads = nil;
    self.accessories = nil;
    self.services = nil;
    self.didWarmUp = NO;
}

@end
