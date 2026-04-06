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
     PPSearchRankFuzzy        = 4,   // typo-tolerant (Levenshtein)
     PPSearchRankWeak         = 5    // lowest
 };
 */

NS_ASSUME_NONNULL_BEGIN

@interface PPSearchHelper : NSObject
+ (PPSearchRank)pp_rankForText:(NSString *)text query:(NSString *)query;

+ (PPSearchMatchType)matchText:(NSString *)text
                     withQuery:(NSString *)query;

#pragma mark - Levenshtein / Fuzzy

/// Optimized single-row Levenshtein distance with early length-diff exit.
+ (NSUInteger)pp_levenshteinFrom:(NSString *)source
                              to:(NSString *)target
                     maxDistance:(NSUInteger)maxDist;

/// Adaptive threshold: query 1-2→0, 3-4→1, 5-7→2, 8+→3.
+ (NSUInteger)pp_fuzzyThresholdForQueryLength:(NSUInteger)length;

/// Best edit distance between the normalized query and any word in the normalized text.
/// Returns NSUIntegerMax when no word is within threshold.
+ (NSUInteger)pp_bestFuzzyDistanceForText:(NSString *)text query:(NSString *)query;

/// YES when at least one word in text is within Levenshtein threshold of query.
+ (BOOL)pp_isFuzzyMatchForText:(NSString *)text query:(NSString *)query;

@end

NS_ASSUME_NONNULL_END
