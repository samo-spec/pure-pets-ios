//
//  PPSearchHelper.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 11/01/2026.
//

#import <Foundation/Foundation.h>

/*
 typedef NS_ENUM(NSInteger, PPSearchRank) {
     PPSearchRankExact        = 0,   // 🔥 highest priority
     PPSearchRankPrefix       = 1,
     PPSearchRankWordStart    = 2,
     PPSearchRankContains     = 3,
     PPSearchRankWeak         = 4    // lowest
 };
 */

NS_ASSUME_NONNULL_BEGIN

@interface PPSearchHelper : NSObject
+ (PPSearchRank)pp_rankForText:(NSString *)text query:(NSString *)query;

+ (PPSearchMatchType)matchText:(NSString *)text
                     withQuery:(NSString *)query;
@end

NS_ASSUME_NONNULL_END
