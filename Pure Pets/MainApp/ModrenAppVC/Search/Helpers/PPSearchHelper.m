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

    // 6️⃣ Fuzzy — Levenshtein within adaptive threshold
    NSUInteger threshold = [self pp_fuzzyThresholdForQueryLength:normalizedQuery.length];
    if (threshold > 0) {
        for (NSString *w in words) {
            NSUInteger dist = [self pp_levenshteinFrom:normalizedQuery to:w maxDistance:threshold];
            if (dist <= threshold) {
                return PPSearchRankFuzzy;
            }
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

    // 4️⃣ Fuzzy — Levenshtein within adaptive threshold
    NSUInteger threshold = [self pp_fuzzyThresholdForQueryLength:q.length];
    if (threshold > 0) {
        for (NSString *w in words) {
            NSUInteger dist = [self pp_levenshteinFrom:q to:w maxDistance:threshold];
            if (dist <= threshold) {
                return PPSearchMatchFuzzy;
            }
        }
    }

    return PPSearchMatchNone;
}

#pragma mark - Levenshtein Distance

+ (NSUInteger)pp_levenshteinFrom:(NSString *)source
                              to:(NSString *)target
                     maxDistance:(NSUInteger)maxDist
{
    NSUInteger n = source.length;
    NSUInteger m = target.length;

    if (n == 0) return (m <= maxDist) ? m : maxDist + 1;
    if (m == 0) return (n <= maxDist) ? n : maxDist + 1;

    NSUInteger lenDiff = (n > m) ? (n - m) : (m - n);
    if (lenDiff > maxDist) return maxDist + 1;

    // Keep shorter string as source → O(min(n,m)) space
    if (n > m) {
        NSString *tmp = source; source = target; target = tmp;
        NSUInteger x = n; n = m; m = x;
    }

    NSUInteger *row = calloc(n + 1, sizeof(NSUInteger));
    if (!row) return maxDist + 1;

    for (NSUInteger i = 0; i <= n; i++) row[i] = i;

    for (NSUInteger j = 1; j <= m; j++) {
        NSUInteger prev = row[0];
        row[0] = j;
        unichar tc = [target characterAtIndex:j - 1];

        for (NSUInteger i = 1; i <= n; i++) {
            NSUInteger saved = row[i];
            unichar sc = [source characterAtIndex:i - 1];
            NSUInteger cost = (sc == tc) ? 0 : 1;

            NSUInteger v = prev + cost;                    // replace
            if (row[i] + 1 < v) v = row[i] + 1;           // delete
            if (row[i - 1] + 1 < v) v = row[i - 1] + 1;   // insert

            row[i] = v;
            prev = saved;
        }
    }

    NSUInteger result = row[n];
    free(row);
    return (result <= maxDist) ? result : maxDist + 1;
}

#pragma mark - Fuzzy Utilities

+ (NSUInteger)pp_fuzzyThresholdForQueryLength:(NSUInteger)length
{
    if (length < 3)  return 0;   // too short — no fuzzy
    if (length <= 4) return 1;   // 1 typo
    if (length <= 7) return 2;   // 2 typos
    return 3;                     // 3 typos for 8+ chars
}

+ (NSUInteger)pp_bestFuzzyDistanceForText:(NSString *)text query:(NSString *)query
{
    if (text.length == 0 || query.length == 0) return NSUIntegerMax;

    NSString *nq = [ArabicNormalizer normalize:query];
    if (nq.length == 0) return NSUIntegerMax;

    NSUInteger threshold = [self pp_fuzzyThresholdForQueryLength:nq.length];
    if (threshold == 0) return NSUIntegerMax;

    NSArray<NSString *> *rawWords =
        [text componentsSeparatedByCharactersInSet:
         [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSUInteger bestDist = NSUIntegerMax;

    for (NSString *w in rawWords) {
        NSString *nw = [ArabicNormalizer normalize:w];
        if (nw.length == 0) continue;

        NSUInteger dist = [self pp_levenshteinFrom:nq to:nw maxDistance:threshold];
        if (dist < bestDist) {
            bestDist = dist;
            if (bestDist <= 1) break;
        }
    }

    return (bestDist <= threshold) ? bestDist : NSUIntegerMax;
}

+ (BOOL)pp_isFuzzyMatchForText:(NSString *)text query:(NSString *)query
{
    return [self pp_bestFuzzyDistanceForText:text query:query] != NSUIntegerMax;
}

@end

NS_ASSUME_NONNULL_END
