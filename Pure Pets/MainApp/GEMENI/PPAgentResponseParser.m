//
//  PPAgentResponseParser.m
//  PurePets
//

#import "PPAgentResponseParser.h"

@implementation PPAgentResponseParser

+ (PPAgentMessage *)parseEnvelope:(NSDictionary *)json error:(NSError **)error {
    if (![json isKindOfClass:NSDictionary.class]) {
        if (error) *error = [self err:@"invalid_envelope"];
        return nil;
    }

    id data = json[@"data"];
    if (!data) {
        data = [self resultPayloadFromAgentEventDictionary:json];
    }
    if (!data && (json[@"text"] || json[@"assistantText"] || json[@"options"] || json[@"cards"])) {
        data = json;
    }
    NSString *text = nil;
    NSString *tool = nil;
    NSArray  *sugg = nil;
    NSDictionary *responseData = nil;
    BOOL hasRenderablePayload = NO;

    // 1) String directly, or a raw Nova JSON envelope returned as text.
    if ([data isKindOfClass:NSString.class]) {
        NSDictionary *rawEnvelope = [self novaEnvelopeFromRawText:data];
        if (rawEnvelope) {
            data = rawEnvelope;
        } else {
            text = ([self isRawNovaEnvelopeText:data] || [self isInternalNovaDebugText:data]) ? nil : data;
        }
    }
    // 2) Dict with common keys
    if ([data isKindOfClass:NSDictionary.class]) {
        NSDictionary *d = data;
        NSDictionary *eventPayload = [self resultPayloadFromAgentEventDictionary:d];
        responseData = eventPayload ?: d;
        hasRenderablePayload = [self hasRenderableResultPayload:responseData];

        if (eventPayload) {
            text = @"";
        }

        if (!eventPayload) {
            for (NSString *k in @[ @"text", @"assistantText", @"output", @"response", @"answer",
                                   @"message", @"content" ]) {
                id v = d[k];
                if ([v isKindOfClass:NSString.class] &&
                    [(NSString *)v length] &&
                    ![self isRawNovaEnvelopeText:v] &&
                    ![self isInternalNovaDebugText:v]) {
                    text = v;
                    break;
                }
            }
        }

        // ADK / LangChain: { messages: [ { content / text } ] }
        if (!text) {
            NSArray *msgs = d[@"messages"];
            if ([msgs isKindOfClass:NSArray.class]) {
                NSMutableArray *parts = [NSMutableArray array];
                for (id m in msgs) {
                    if (![m isKindOfClass:NSDictionary.class]) continue;
                    id c = m[@"content"] ?: m[@"text"];
                    if ([c isKindOfClass:NSString.class] &&
                        ![self isRawNovaEnvelopeText:c] &&
                        ![self isInternalNovaDebugText:c]) {
                        [parts addObject:c];
                    }
                }
                if (parts.count) {
                    text = [parts componentsJoinedByString:@"\n"];
                }
            }
        }

        // Tool-call indicators
        id toolCalls = d[@"tool_calls"] ?: d[@"actions"];
        if ([toolCalls isKindOfClass:NSArray.class] && [(NSArray *)toolCalls count]) {
            id first = [toolCalls firstObject];
            if ([first isKindOfClass:NSDictionary.class]) {
                tool = first[@"name"] ?: first[@"tool"];
            }
        }

        // Suggestions / quick replies
        id s = d[@"options"] ?: d[@"suggestions"] ?: d[@"quickReplies"];
        if ([s isKindOfClass:NSArray.class]) sugg = s;

        // Result payloads may carry cards even if assistantText is empty.
        // Empty Nova envelopes must fail closed; never stringify JSON into
        // a customer-visible chat bubble.
        if (!text) {
            if (hasRenderablePayload) {
                text = @"";
            }
        }
    }
    // 3) Raw passthrough
    else if (!text && json[@"raw"]) {
        id raw = json[@"raw"];
        text = ([raw isKindOfClass:NSString.class] &&
                ![self isRawNovaEnvelopeText:raw] &&
                ![self isInternalNovaDebugText:raw]) ? raw : nil;
    }

    if ([self isInternalNovaDebugText:text]) {
        text = nil;
    }

    if (!text.length && !hasRenderablePayload) {
        if (error) *error = [self err:@"empty_response"];
        return nil;
    }

    PPAgentMessage *msg = [PPAgentMessage agentText:text tool:tool];
    msg.suggestions = sugg;
    msg.responseData = responseData;
    return msg;
}

+ (BOOL)hasRenderableResultPayload:(NSDictionary *)data {
    if (![data isKindOfClass:NSDictionary.class]) {
        return NO;
    }
    for (NSString *key in @[ @"resultRefs", @"result_refs", @"cards", @"products", @"items", @"product_ids", @"productIds", @"productIDs" ]) {
        id value = data[key];
        if ([value isKindOfClass:NSArray.class] && [(NSArray *)value count] > 0) {
            return YES;
        }
    }
    id resultSet = data[@"result_set"] ?: data[@"resultSet"];
    if ([resultSet isKindOfClass:NSDictionary.class]) {
        id cards = resultSet[@"cards"];
        if ([cards isKindOfClass:NSArray.class] && [(NSArray *)cards count] > 0) {
            return YES;
        }
        id items = resultSet[@"items"];
        if ([items isKindOfClass:NSArray.class] && [(NSArray *)items count] > 0) {
            return YES;
        }
        id cardsRequired = resultSet[@"cardsRequired"] ?: resultSet[@"cards_required"];
        if ([cardsRequired respondsToSelector:@selector(boolValue)] && [cardsRequired boolValue]) {
            return YES;
        }
    }
    id cardsRequired = data[@"cardsRequired"] ?: data[@"cards_required"];
    return [cardsRequired respondsToSelector:@selector(boolValue)] && [cardsRequired boolValue];
}

+ (NSDictionary *)resultPayloadFromAgentEventDictionary:(NSDictionary *)event {
    if (![event isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    NSDictionary *content = [event[@"content"] isKindOfClass:NSDictionary.class] ? event[@"content"] : nil;
    NSArray *parts = [content[@"parts"] isKindOfClass:NSArray.class] ? content[@"parts"] : nil;
    for (id part in parts) {
        if (![part isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSDictionary *partDict = (NSDictionary *)part;
        NSDictionary *functionResponse = [partDict[@"functionResponse"] isKindOfClass:NSDictionary.class]
            ? partDict[@"functionResponse"]
            : ([partDict[@"function_response"] isKindOfClass:NSDictionary.class] ? partDict[@"function_response"] : nil);
        id responseObject = functionResponse[@"response"];
        NSDictionary *response = [responseObject isKindOfClass:NSDictionary.class]
            ? responseObject
            : ([responseObject isKindOfClass:NSString.class] ? [self novaEnvelopeFromRawText:responseObject] : nil);
        BOOL hasOptions = [response[@"options"] isKindOfClass:NSArray.class] ||
                          [response[@"suggestions"] isKindOfClass:NSArray.class] ||
                          [response[@"quickReplies"] isKindOfClass:NSArray.class];
        BOOL hasText = [response[@"text"] isKindOfClass:NSString.class] ||
                       [response[@"assistantText"] isKindOfClass:NSString.class];
        if ([self hasRenderableResultPayload:response] || hasOptions || hasText) {
            return response;
        }
    }
    return nil;
}

+ (NSDictionary *)novaEnvelopeFromRawText:(NSString *)text {
    if (![text isKindOfClass:NSString.class]) {
        return nil;
    }
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    for (NSDictionary<NSString *, id> *candidate in [self novaJSONDictionaryCandidatesFromText:trimmed]) {
        NSDictionary *dict = [candidate[@"object"] isKindOfClass:NSDictionary.class] ? candidate[@"object"] : nil;
        if (![self dictionaryLooksLikeNovaEnvelope:dict]) {
            continue;
        }
        NSMutableDictionary *mutable = [dict mutableCopy];
        if (!mutable[@"text"] && !mutable[@"assistantText"]) {
            NSString *jsonText = [candidate[@"json"] isKindOfClass:NSString.class] ? candidate[@"json"] : @"";
            NSString *visibleText = jsonText.length > 0
                ? [trimmed stringByReplacingOccurrencesOfString:jsonText withString:@""]
                : trimmed;
            NSRegularExpression *fence = [NSRegularExpression regularExpressionWithPattern:@"```(?:json)?"
                                                                                   options:NSRegularExpressionCaseInsensitive
                                                                                     error:nil];
            visibleText = [fence stringByReplacingMatchesInString:visibleText
                                                          options:0
                                                            range:NSMakeRange(0, visibleText.length)
                                                     withTemplate:@""];
            visibleText = [visibleText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (visibleText.length > 0) {
                if (![self isInternalNovaDebugText:visibleText]) {
                    mutable[@"text"] = visibleText;
                }
            }
        }
        return [mutable copy];
    }

    NSRegularExpression *fencedJSON = [NSRegularExpression regularExpressionWithPattern:@"```(?:json)?\\s*(\\{(?:.|\\n|\\r)*\\})\\s*```"
                                                                                options:NSRegularExpressionCaseInsensitive
                                                                                  error:nil];
    NSTextCheckingResult *fencedMatch = [fencedJSON firstMatchInString:trimmed
                                                               options:0
                                                                 range:NSMakeRange(0, trimmed.length)];
    if (fencedMatch && fencedMatch.numberOfRanges > 1) {
        NSRange jsonRange = [fencedMatch rangeAtIndex:1];
        NSString *jsonText = [trimmed substringWithRange:jsonRange];
        NSData *jsonData = [jsonText dataUsingEncoding:NSUTF8StringEncoding];
        id parsed = jsonData ? [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil] : nil;
        if ([parsed isKindOfClass:NSDictionary.class]) {
            NSMutableDictionary *dict = [(NSDictionary *)parsed mutableCopy];
            if (dict[@"text"] || dict[@"assistantText"] || dict[@"options"] || dict[@"cards"] || dict[@"resultRefs"] || dict[@"product_ids"] || dict[@"productIds"] || dict[@"productIDs"]) {
                NSString *visibleText = [fencedJSON stringByReplacingMatchesInString:trimmed
                                                                              options:0
                                                                                range:NSMakeRange(0, trimmed.length)
                                                                         withTemplate:@""];
                visibleText = [visibleText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                if (!dict[@"text"] && !dict[@"assistantText"] && visibleText.length > 0) {
                    if (![self isInternalNovaDebugText:visibleText]) {
                        dict[@"text"] = visibleText;
                    }
                }
                return [dict copy];
            }
        }
    }
    if ([trimmed hasPrefix:@"```"]) {
        NSRegularExpression *openFence = [NSRegularExpression regularExpressionWithPattern:@"^```(?:json)?\\s*"
                                                                                   options:NSRegularExpressionCaseInsensitive
                                                                                     error:nil];
        trimmed = [openFence stringByReplacingMatchesInString:trimmed
                                                      options:0
                                                        range:NSMakeRange(0, trimmed.length)
                                                 withTemplate:@""];
        if ([trimmed hasSuffix:@"```"]) {
            trimmed = [trimmed substringToIndex:trimmed.length - 3];
        }
        trimmed = [trimmed stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    if (![trimmed hasPrefix:@"{"] || ![trimmed hasSuffix:@"}"]) {
        return nil;
    }
    NSData *data = [trimmed dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        return nil;
    }
    id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![parsed isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    NSDictionary *dict = (NSDictionary *)parsed;
    if (dict[@"text"] || dict[@"assistantText"] || dict[@"options"] || dict[@"cards"] || dict[@"resultRefs"] || dict[@"product_ids"] || dict[@"productIds"] || dict[@"productIDs"]) {
        return dict;
    }
    return nil;
}

+ (BOOL)isRawNovaEnvelopeText:(NSString *)text {
    if (![text isKindOfClass:NSString.class]) {
        return NO;
    }
    if ([self novaEnvelopeFromRawText:text]) {
        return YES;
    }
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (![trimmed hasPrefix:@"{"] || ![trimmed hasSuffix:@"}"]) {
        return NO;
    }
    return [trimmed containsString:@"\"assistantText\""] ||
           [trimmed containsString:@"\"text\""] ||
           [trimmed containsString:@"\"options\""] ||
           [trimmed containsString:@"\"cards\""] ||
           [trimmed containsString:@"\"resultRefs\""] ||
           [trimmed containsString:@"\"cardsRequired\""] ||
           [trimmed containsString:@"\"product_ids\""] ||
           [trimmed containsString:@"\"productIds\""] ||
           [trimmed containsString:@"\"productIDs\""];
}

+ (NSArray<NSDictionary<NSString *, id> *> *)novaJSONDictionaryCandidatesFromText:(NSString *)text {
    if (![text isKindOfClass:NSString.class] || text.length == 0) {
        return @[];
    }
    NSMutableArray<NSDictionary<NSString *, id> *> *candidates = [NSMutableArray array];
    NSInteger depth = 0;
    NSUInteger start = NSNotFound;
    BOOL inString = NO;
    BOOL escapeNext = NO;

    for (NSUInteger idx = 0; idx < text.length; idx++) {
        unichar ch = [text characterAtIndex:idx];
        if (escapeNext) {
            escapeNext = NO;
            continue;
        }
        if (inString && ch == '\\') {
            escapeNext = YES;
            continue;
        }
        if (ch == '"') {
            inString = !inString;
            continue;
        }
        if (inString) {
            continue;
        }
        if (ch == '{') {
            if (depth == 0) {
                start = idx;
            }
            depth++;
        } else if (ch == '}' && depth > 0) {
            depth--;
            if (depth == 0 && start != NSNotFound) {
                NSRange range = NSMakeRange(start, idx - start + 1);
                NSString *body = [text substringWithRange:range];
                NSData *data = [body dataUsingEncoding:NSUTF8StringEncoding];
                id parsed = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
                if ([parsed isKindOfClass:NSDictionary.class]) {
                    [candidates addObject:@{@"object": parsed, @"json": body}];
                }
                start = NSNotFound;
            }
        }
    }
    return [candidates copy];
}

+ (BOOL)dictionaryLooksLikeNovaEnvelope:(NSDictionary *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) {
        return NO;
    }
    for (NSString *key in @[ @"text", @"assistantText", @"options", @"cards",
                             @"resultRefs", @"result_refs", @"product_ids",
                             @"productIds", @"productIDs", @"products", @"items", @"result_set",
                             @"resultSet", @"cardsRequired", @"cards_required" ]) {
        if (dict[key]) {
            return YES;
        }
    }
    return NO;
}

+ (BOOL)isInternalNovaDebugText:(NSString *)text {
    if (![text isKindOfClass:NSString.class]) {
        return NO;
    }
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!trimmed.length) {
        return NO;
    }
    NSString *lower = trimmed.lowercaseString;
    NSRegularExpression *printCall = [NSRegularExpression regularExpressionWithPattern:@"(^|\\s)print\\s*\\("
                                                                                options:NSRegularExpressionCaseInsensitive
                                                                                  error:nil];
    return [printCall firstMatchInString:trimmed options:0 range:NSMakeRange(0, trimmed.length)] != nil ||
           [lower containsString:@"transfer_to_agent("] ||
           [lower containsString:@".transfer_to_agent"] ||
           [lower containsString:@"function_call"] ||
           [lower containsString:@"functioncall"] ||
           [lower containsString:@"function_response"] ||
           [lower containsString:@"functionresponse"] ||
           [lower containsString:@"tool_code"];
}

+ (NSError *)err:(NSString *)code {
    return [NSError errorWithDomain:@"PPAgentParse" code:0
                           userInfo:@{ NSLocalizedDescriptionKey: code }];
}

@end
