//
//  SearchManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 12/08/2025.
//

// SearchManager.h
#import <Foundation/Foundation.h>
#import "SearchResultItem.h"

@interface SearchManager : NSObject
+ (instancetype)shared;

/// Loads all data from managers (ads, accessories, services, vets) and keeps a warm cache.
- (void)warmUpIfNeeded:(void(^_Nullable)(void))completion;

/// Case/diacritic-insensitive contains search across title/desc/etc.
- (void)searchText:(NSString *)text completion:(void(^)(NSArray<SearchResultItem *> *results))completion;

/// Clear cached lists if you want to force a reload.
- (void)invalidateCache;
@end
