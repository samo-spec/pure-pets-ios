//
//  PPSearchHelper.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 11/01/2026.
//

#import "PPSearchHelper.h"

#import "ArabicNormalizer.h"

NS_ASSUME_NONNULL_BEGIN

@implementation PPSearchHelper


+ (PPSearchRank)pp_rankForText:(NSString *)text query:(NSString *)query
{
    if (text.length == 0 || query.length == 0) {
        return PPSearchRankContains;
    }

    NSString *normalizedQuery =
    [ArabicNormalizer normalize:query];

    // Split ORIGINAL text into words first
    NSArray<NSString *> *rawWords =
    [text componentsSeparatedByCharactersInSet:
     [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSMutableArray<NSString *> *words = [NSMutableArray array];
    for (NSString *w in rawWords) {
        NSString *nw = [ArabicNormalizer normalize:w];
        if (nw.length) [words addObject:nw];
    }

    NSString *normalizedText =
    [ArabicNormalizer normalize:text];

    // 1️⃣ Exact
    if ([normalizedText isEqualToString:normalizedQuery]) {
        return PPSearchRankExact;
    }

    // 2️⃣ Starts with (full title)
    if ([normalizedText hasPrefix:normalizedQuery]) {
        return PPSearchRankPrefix;
    }

    // 3️⃣ Word starts with (🔥 important)
    for (NSString *w in words) {
        if ([w hasPrefix:normalizedQuery]) {
            return PPSearchRankPrefix;
        }
    }

    // 4️⃣ Ends with
    for (NSString *w in words) {
        if ([w hasSuffix:normalizedQuery]) {
            return PPSearchRankContains;
        }
    }

    // 5️⃣ Contains (🔥 THIS WAS FAILING)
    for (NSString *w in words) {
        if ([w containsString:normalizedQuery]) {
            return PPSearchRankContains;
        }
    }

    
    return PPSearchRankWeak;
}


+ (PPSearchMatchType)matchText:(NSString *)text
                     withQuery:(NSString *)query
{
    if (text.length == 0 || query.length == 0) {
        return PPSearchMatchNone;
    }

    NSString *q = [ArabicNormalizer normalize:query];
    if (q.length == 0) {
        return PPSearchMatchNone;
    }

    // Split ORIGINAL text into words FIRST
    NSArray<NSString *> *rawWords =
    [text componentsSeparatedByCharactersInSet:
     [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSMutableArray<NSString *> *words = [NSMutableArray array];
    for (NSString *w in rawWords) {
        NSString *nw = [ArabicNormalizer normalize:w];
        if (nw.length) {
            [words addObject:nw];
        }
    }

    NSString *full = [ArabicNormalizer normalize:text];

    // 1️⃣ Exact title
    if ([full isEqualToString:q]) {
        return PPSearchMatchExact;
    }

    // 2️⃣ Full title starts with query
    if ([full hasPrefix:q]) {
        return PPSearchMatchStartsWith;
    }

    // 3️⃣ Word-based matching (🔥 THIS FIXES "شا")
    for (NSString *w in words) {

        // starts with (شاهين ← شا)
        if ([w hasPrefix:q]) {
            return PPSearchMatchStartsWith;
        }

        // contains inside word (طائرشاهين ← شا)
        if ([w rangeOfString:q].location != NSNotFound) {
            return PPSearchMatchContains;
        }
    }

    return PPSearchMatchNone;
}

@end

NS_ASSUME_NONNULL_END
