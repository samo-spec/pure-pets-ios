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
    if (!data && (json[@"assistantText"] || json[@"options"])) {
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
            text = [self isRawNovaEnvelopeText:data] ? nil : data;
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
            for (NSString *k in @[ @"assistantText", @"output", @"response", @"answer",
                                   @"text", @"message", @"content" ]) {
                id v = d[k];
                if ([v isKindOfClass:NSString.class] && [(NSString *)v length]) {
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
                    if ([c isKindOfClass:NSString.class]) {
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
        text = ([raw isKindOfClass:NSString.class] && ![self isRawNovaEnvelopeText:raw]) ? raw : nil;
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
    for (NSString *key in @[ @"resultRefs", @"result_refs", @"products", @"items" ]) {
        id value = data[key];
        if ([value isKindOfClass:NSArray.class] && [(NSArray *)value count] > 0) {
            return YES;
        }
    }
    id resultSet = data[@"result_set"] ?: data[@"resultSet"];
    if ([resultSet isKindOfClass:NSDictionary.class]) {
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
        NSDictionary *response = [functionResponse[@"response"] isKindOfClass:NSDictionary.class]
            ? functionResponse[@"response"]
            : nil;
        if ([self hasRenderableResultPayload:response]) {
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
    if (dict[@"assistantText"] || dict[@"options"] || dict[@"resultRefs"] || dict[@"product_ids"]) {
        return dict;
    }
    return nil;
}

+ (BOOL)isRawNovaEnvelopeText:(NSString *)text {
    if (![text isKindOfClass:NSString.class]) {
        return NO;
    }
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (![trimmed hasPrefix:@"{"] || ![trimmed hasSuffix:@"}"]) {
        return NO;
    }
    return [trimmed containsString:@"\"assistantText\""] ||
           [trimmed containsString:@"\"options\""] ||
           [trimmed containsString:@"\"resultRefs\""] ||
           [trimmed containsString:@"\"cardsRequired\""] ||
           [trimmed containsString:@"\"product_ids\""];
}

+ (NSError *)err:(NSString *)code {
    return [NSError errorWithDomain:@"PPAgentParse" code:0
                           userInfo:@{ NSLocalizedDescriptionKey: code }];
}

@end
