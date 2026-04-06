//
//  PPSearchHelper.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 11/01/2026.
//

#import "PPSearchHelper.h"

#import "ArabicNormalizer.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    NSUInteger distance;
    NSUInteger location;
    NSUInteger wordIndex;
    NSUInteger wordLength;
} PPFuzzyCandidate;

NS_INLINE PPFuzzyCandidate PPFuzzyCandidateMake(NSUInteger distance,
                                                NSUInteger location,
                                                NSUInteger wordIndex,
                                                NSUInteger wordLength)
{
    PPFuzzyCandidate candidate;
    candidate.distance = distance;
    candidate.location = location;
    candidate.wordIndex = wordIndex;
    candidate.wordLength = wordLength;
    return candidate;
}

@interface PPSearchHelper ()

+ (PPSearchScore)pp_invalidScore;
+ (NSArray<NSString *> *)pp_wordsFromNormalizedText:(NSString *)normalizedText;
+ (NSCharacterSet *)pp_searchSeparatorCharacterSet;
+ (NSUInteger)pp_lengthDeltaBetweenLength:(NSUInteger)lhs
                                andLength:(NSUInteger)rhs;
+ (NSUInteger)pp_wordIndexForLocation:(NSUInteger)location
                     inNormalizedText:(NSString *)normalizedText
                                 words:(NSArray<NSString *> *)words;
+ (PPFuzzyCandidate)pp_bestFuzzyCandidateForNormalizedText:(NSString *)normalizedText
                                                     words:(NSArray<NSString *> *)words
                                           normalizedQuery:(NSString *)normalizedQuery;

@end

@implementation PPSearchHelper

#pragma mark - Public

+ (NSString *)pp_normalizedSearchString:(NSString *)text
{
    if (![text isKindOfClass:NSString.class] || text.length == 0) {
        return @"";
    }

    NSString *normalized = [ArabicNormalizer normalize:text];
    if (normalized.length == 0) {
        return @"";
    }

    normalized =
        [normalized stringByFoldingWithOptions:NSDiacriticInsensitiveSearch | NSWidthInsensitiveSearch
                                        locale:[NSLocale currentLocale]];
    normalized = [normalized lowercaseStringWithLocale:[NSLocale currentLocale]];

    NSArray<NSString *> *segments =
        [normalized componentsSeparatedByCharactersInSet:[self pp_searchSeparatorCharacterSet]];
    NSString *spaceJoined = [segments componentsJoinedByString:@" "];
    NSArray<NSString *> *parts =
        [spaceJoined componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSMutableArray<NSString *> *tokens = [NSMutableArray arrayWithCapacity:parts.count];
    for (NSString *part in parts) {
        NSString *trimmed =
            [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length > 0) {
            [tokens addObject:trimmed];
        }
    }

    return tokens.count > 0 ? [tokens componentsJoinedByString:@" "] : @"";
}

+ (PPSearchScore)pp_scoreForText:(NSString *)text
                           query:(NSString *)query
{
    NSString *normalizedQuery = [self pp_normalizedSearchString:query];
    return [self pp_scoreForText:text normalizedQuery:normalizedQuery];
}

+ (PPSearchScore)pp_scoreForText:(NSString *)text
                 normalizedQuery:(NSString *)normalizedQuery
{
    NSString *normalizedText = [self pp_normalizedSearchString:text];
    if (normalizedText.length == 0 || normalizedQuery.length == 0) {
        return [self pp_invalidScore];
    }

    NSArray<NSString *> *words = [self pp_wordsFromNormalizedText:normalizedText];
    if (words.count == 0) {
        return [self pp_invalidScore];
    }

    NSUInteger queryLength = normalizedQuery.length;

    if ([normalizedText isEqualToString:normalizedQuery]) {
        return PPSearchScoreMake(YES,
                                 PPSearchRankExact,
                                 PPSearchMatchExact,
                                 0,
                                 0,
                                 0,
                                 normalizedText.length,
                                 0);
    }

    if ([normalizedText hasPrefix:normalizedQuery]) {
        NSUInteger lengthDelta = [self pp_lengthDeltaBetweenLength:normalizedText.length
                                                         andLength:queryLength];
        return PPSearchScoreMake(YES,
                                 PPSearchRankPrefix,
                                 PPSearchMatchStartsWith,
                                 lengthDelta,
                                 0,
                                 0,
                                 normalizedText.length,
                                 0);
    }

    NSUInteger cursor = 0;
    for (NSUInteger idx = 0; idx < words.count; idx++) {
        NSString *word = words[idx];
        if ([word hasPrefix:normalizedQuery]) {
            NSUInteger lengthDelta = [self pp_lengthDeltaBetweenLength:word.length
                                                             andLength:queryLength];
            return PPSearchScoreMake(YES,
                                     PPSearchRankWordStart,
                                     PPSearchMatchStartsWith,
                                     (idx * 64) + lengthDelta,
                                     cursor,
                                     idx,
                                     word.length,
                                     0);
        }
        cursor += word.length + 1;
    }

    NSRange containsRange = [normalizedText rangeOfString:normalizedQuery];
    if (containsRange.location != NSNotFound) {
        NSUInteger wordIndex = [self pp_wordIndexForLocation:containsRange.location
                                          inNormalizedText:normalizedText
                                                      words:words];
        NSUInteger matchedWordLength =
            (wordIndex < words.count) ? words[wordIndex].length : normalizedText.length;
        NSUInteger lengthDelta = [self pp_lengthDeltaBetweenLength:matchedWordLength
                                                         andLength:queryLength];
        BOOL startsAtWordBoundary =
            (containsRange.location == 0) ||
            ([normalizedText characterAtIndex:containsRange.location - 1] == ' ');
        NSUInteger endLocation = NSMaxRange(containsRange);
        BOOL isSuffix = (endLocation == normalizedText.length);
        PPSearchMatchType matchType = isSuffix ? PPSearchMatchEndsWith : PPSearchMatchContains;
        NSUInteger boundaryPenalty = startsAtWordBoundary ? 0 : 400;
        NSUInteger sortScore =
            boundaryPenalty +
            (containsRange.location * 8) +
            (wordIndex * 32) +
            lengthDelta;

        return PPSearchScoreMake(YES,
                                 PPSearchRankContains,
                                 matchType,
                                 sortScore,
                                 containsRange.location,
                                 wordIndex,
                                 matchedWordLength,
                                 0);
    }

    PPFuzzyCandidate fuzzyCandidate =
        [self pp_bestFuzzyCandidateForNormalizedText:normalizedText
                                               words:words
                                     normalizedQuery:normalizedQuery];
    if (fuzzyCandidate.distance != NSUIntegerMax) {
        NSUInteger lengthDelta = [self pp_lengthDeltaBetweenLength:fuzzyCandidate.wordLength
                                                         andLength:queryLength];
        NSUInteger sortScore =
            (fuzzyCandidate.distance * 1000) +
            (fuzzyCandidate.wordIndex * 64) +
            (fuzzyCandidate.location * 4) +
            lengthDelta;

        return PPSearchScoreMake(YES,
                                 PPSearchRankFuzzy,
                                 PPSearchMatchFuzzy,
                                 sortScore,
                                 fuzzyCandidate.location,
                                 fuzzyCandidate.wordIndex,
                                 fuzzyCandidate.wordLength,
                                 fuzzyCandidate.distance);
    }

    return [self pp_invalidScore];
}

+ (PPSearchRank)pp_rankForText:(NSString *)text query:(NSString *)query
{
    PPSearchScore score = [self pp_scoreForText:text query:query];
    return score.matched ? score.rank : PPSearchRankWeak;
}

+ (PPSearchMatchType)matchText:(NSString *)text
                     withQuery:(NSString *)query
{
    PPSearchScore score = [self pp_scoreForText:text query:query];
    return score.matched ? score.matchType : PPSearchMatchNone;
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

    if (n > m) {
        NSString *tmp = source;
        source = target;
        target = tmp;

        NSUInteger tempLength = n;
        n = m;
        m = tempLength;
    }

    NSUInteger *row = calloc(n + 1, sizeof(NSUInteger));
    if (!row) return maxDist + 1;

    for (NSUInteger i = 0; i <= n; i++) {
        row[i] = i;
    }

    for (NSUInteger j = 1; j <= m; j++) {
        NSUInteger prev = row[0];
        row[0] = j;
        NSUInteger rowMin = row[0];
        unichar tc = [target characterAtIndex:j - 1];

        for (NSUInteger i = 1; i <= n; i++) {
            NSUInteger saved = row[i];
            unichar sc = [source characterAtIndex:i - 1];
            NSUInteger cost = (sc == tc) ? 0 : 1;

            NSUInteger value = prev + cost;
            if (row[i] + 1 < value) value = row[i] + 1;
            if (row[i - 1] + 1 < value) value = row[i - 1] + 1;

            row[i] = value;
            if (value < rowMin) {
                rowMin = value;
            }
            prev = saved;
        }

        if (rowMin > maxDist) {
            free(row);
            return maxDist + 1;
        }
    }

    NSUInteger result = row[n];
    free(row);
    return (result <= maxDist) ? result : maxDist + 1;
}

#pragma mark - Fuzzy Utilities

+ (NSUInteger)pp_fuzzyThresholdForQueryLength:(NSUInteger)length
{
    if (length < 3) return 0;
    if (length <= 4) return 1;
    if (length <= 7) return 2;
    return 3;
}

+ (NSUInteger)pp_bestFuzzyDistanceForText:(NSString *)text query:(NSString *)query
{
    NSString *normalizedQuery = [self pp_normalizedSearchString:query];
    NSString *normalizedText = [self pp_normalizedSearchString:text];
    if (normalizedQuery.length == 0 || normalizedText.length == 0) {
        return NSUIntegerMax;
    }

    NSArray<NSString *> *words = [self pp_wordsFromNormalizedText:normalizedText];
    PPFuzzyCandidate candidate =
        [self pp_bestFuzzyCandidateForNormalizedText:normalizedText
                                               words:words
                                     normalizedQuery:normalizedQuery];
    return candidate.distance;
}

+ (BOOL)pp_isFuzzyMatchForText:(NSString *)text query:(NSString *)query
{
    return [self pp_bestFuzzyDistanceForText:text query:query] != NSUIntegerMax;
}

#pragma mark - Private

+ (PPSearchScore)pp_invalidScore
{
    return PPSearchScoreMake(NO,
                             PPSearchRankWeak,
                             PPSearchMatchNone,
                             NSUIntegerMax,
                             NSUIntegerMax,
                             NSUIntegerMax,
                             NSUIntegerMax,
                             NSUIntegerMax);
}

+ (NSArray<NSString *> *)pp_wordsFromNormalizedText:(NSString *)normalizedText
{
    if (normalizedText.length == 0) {
        return @[];
    }

    return [normalizedText componentsSeparatedByString:@" "];
}

+ (NSCharacterSet *)pp_searchSeparatorCharacterSet
{
    static NSCharacterSet *separatorSet;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableCharacterSet *allowed = [[NSCharacterSet alphanumericCharacterSet] mutableCopy];
        [allowed formUnionWithCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        separatorSet = [allowed invertedSet];
    });
    return separatorSet;
}

+ (NSUInteger)pp_lengthDeltaBetweenLength:(NSUInteger)lhs
                                andLength:(NSUInteger)rhs
{
    return (lhs > rhs) ? (lhs - rhs) : (rhs - lhs);
}

+ (NSUInteger)pp_wordIndexForLocation:(NSUInteger)location
                    inNormalizedText:(NSString *)normalizedText
                                words:(NSArray<NSString *> *)words
{
    if (location == NSUIntegerMax || words.count == 0) {
        return NSUIntegerMax;
    }

    NSUInteger cursor = 0;
    for (NSUInteger idx = 0; idx < words.count; idx++) {
        NSString *word = words[idx];
        NSUInteger end = cursor + word.length;
        if (location < end) {
            return idx;
        }
        cursor = end + 1;
        if (cursor > normalizedText.length) {
            break;
        }
    }

    return NSUIntegerMax;
}

+ (PPFuzzyCandidate)pp_bestFuzzyCandidateForNormalizedText:(NSString *)normalizedText
                                                     words:(NSArray<NSString *> *)words
                                           normalizedQuery:(NSString *)normalizedQuery
{
    if (normalizedText.length == 0 || normalizedQuery.length == 0 || words.count == 0) {
        return PPFuzzyCandidateMake(NSUIntegerMax, NSUIntegerMax, NSUIntegerMax, NSUIntegerMax);
    }

    NSUInteger threshold = [self pp_fuzzyThresholdForQueryLength:normalizedQuery.length];
    if (threshold == 0) {
        return PPFuzzyCandidateMake(NSUIntegerMax, NSUIntegerMax, NSUIntegerMax, NSUIntegerMax);
    }

    NSUInteger bestDistance = NSUIntegerMax;
    NSUInteger bestLocation = NSUIntegerMax;
    NSUInteger bestWordIndex = NSUIntegerMax;
    NSUInteger bestWordLength = NSUIntegerMax;
    NSUInteger bestLengthDelta = NSUIntegerMax;

    NSUInteger cursor = 0;
    NSUInteger queryLength = normalizedQuery.length;
    NSUInteger minCandidateLength = (queryLength > threshold) ? (queryLength - threshold) : 1;
    NSUInteger maxCandidateLength = queryLength + threshold;

    for (NSUInteger wordIndex = 0; wordIndex < words.count; wordIndex++) {
        NSString *word = words[wordIndex];
        NSUInteger wordLength = word.length;
        if (wordLength == 0 || wordLength < minCandidateLength) {
            cursor += wordLength + 1;
            continue;
        }

        NSUInteger upperLength = MIN(wordLength, maxCandidateLength);
        for (NSUInteger start = 0; start < wordLength; start++) {
            NSUInteger remainingLength = wordLength - start;
            if (remainingLength < minCandidateLength) {
                break;
            }

            NSUInteger maxWindowLength = MIN(upperLength, remainingLength);
            for (NSUInteger candidateLength = minCandidateLength;
                 candidateLength <= maxWindowLength;
                 candidateLength++) {
                NSString *candidate =
                    [word substringWithRange:NSMakeRange(start, candidateLength)];
                NSUInteger distance =
                    [self pp_levenshteinFrom:normalizedQuery
                                          to:candidate
                                 maxDistance:threshold];
                if (distance > threshold) {
                    continue;
                }

                NSUInteger location = cursor + start;
                NSUInteger lengthDelta = [self pp_lengthDeltaBetweenLength:candidateLength
                                                                 andLength:queryLength];
                BOOL shouldReplace = NO;
                if (distance < bestDistance) {
                    shouldReplace = YES;
                } else if (distance == bestDistance) {
                    if (wordIndex < bestWordIndex) {
                        shouldReplace = YES;
                    } else if (wordIndex == bestWordIndex && location < bestLocation) {
                        shouldReplace = YES;
                    } else if (wordIndex == bestWordIndex &&
                               location == bestLocation &&
                               lengthDelta < bestLengthDelta) {
                        shouldReplace = YES;
                    }
                }

                if (shouldReplace) {
                    bestDistance = distance;
                    bestLocation = location;
                    bestWordIndex = wordIndex;
                    bestWordLength = candidateLength;
                    bestLengthDelta = lengthDelta;

                    if (bestDistance == 0) {
                        return PPFuzzyCandidateMake(bestDistance,
                                                    bestLocation,
                                                    bestWordIndex,
                                                    bestWordLength);
                    }
                }
            }
        }

        cursor += wordLength + 1;
    }

    if (bestDistance == NSUIntegerMax) {
        return PPFuzzyCandidateMake(NSUIntegerMax, NSUIntegerMax, NSUIntegerMax, NSUIntegerMax);
    }

    return PPFuzzyCandidateMake(bestDistance,
                                bestLocation,
                                bestWordIndex,
                                bestWordLength);
}

@end

NS_ASSUME_NONNULL_END
