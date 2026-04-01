//
//  SearchCacheManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 12/01/2026.
//


#import <Foundation/Foundation.h>

@class PetAd;
@class PetAccessory;
@class ServiceModel;

NS_ASSUME_NONNULL_BEGIN

typedef void(^SearchCacheCompletion)(void);

@interface SearchCacheManager : NSObject

+ (instancetype)shared;

/// Load ALL searchable data once (Ads + Accessories + Services)
- (void)warmUpCacheIfNeeded:(nullable SearchCacheCompletion)completion;

/// Search locally (contains / prefix / end)
- (NSArray *)searchWithQuery:(NSString *)query;

/// Clear cache manually (logout / memory warning)
- (void)clearCache;

@end

NS_ASSUME_NONNULL_END
