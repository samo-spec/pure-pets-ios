//
//  PPAgentClient.m
//  PurePets
//

#import "PPAgentClient.h"
#import "PPAgentResponseParser.h"
@import FirebaseAuth;
@import FirebaseAppCheck;

// ADK Cloud Run base URL — all paths are relative to this.
// Keep this aligned with Console's Nova runtime; client_type selects the iOS market assistant.
NSString * const kPPAgentBaseURL = @"https://nova-646051621158.us-central1.run.app";

static NSString * const kPPAgentAppName   = @"app";
// Maps VC-managed novaSessionId (UUID) → ADK server-assigned session UUID.
// Persisted so sessions survive cold relaunches.
static NSString * const kADKSessionMapKey = @"pp_nova_adk_session_map";

@interface PPAgentClient ()
@property (nonatomic, strong) NSURLSession *session;
/// The VC's novaSessionId from the last message — detects conversation resets.
@property (nonatomic, copy)   NSString *lastKnownVCSessionId;
/// Server-assigned ADK session UUID for the current conversation.
@property (nonatomic, copy)   NSString *adkSessionId;
@end

@implementation PPAgentClient

+ (PPAgentClient *)shared {
    static PPAgentClient *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [PPAgentClient new]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        NSURLSessionConfiguration *cfg = NSURLSessionConfiguration.defaultSessionConfiguration;
        cfg.timeoutIntervalForRequest = 45.0;
        cfg.timeoutIntervalForResource = 90.0;
        cfg.waitsForConnectivity      = YES;
        _session = [NSURLSession sessionWithConfiguration:cfg];
    }
    return self;
}

- (void)resetSession {
    self.sessionId            = nil;
    self.lastKnownVCSessionId = nil;
    self.adkSessionId         = nil;
}

- (NSURLSessionDataTask *)sendMessage:(NSString *)message
                           completion:(void (^)(PPAgentMessage *, NSError *))completion {
    return [self sendMessage:message language:nil completion:completion];
}

- (NSURLSessionDataTask *)sendMessage:(NSString *)message
                             language:(NSString *)language
                           completion:(void (^)(PPAgentMessage *, NSError *))completion {

    FIRUser *user = FIRAuth.auth.currentUser;
    if (!user) {
        [self finish:completion msg:nil err:[self err:401 code:@"not_signed_in"]];
        return nil;
    }

    __block NSString *idToken = nil;
    __block NSString *acToken = nil;
    dispatch_group_t g = dispatch_group_create();

    dispatch_group_enter(g);
    [user getIDTokenForcingRefresh:NO completion:^(NSString *t, NSError *e) {
        (void)e;
        if (t.length > 0) {
            idToken = t;
            dispatch_group_leave(g);
            return;
        }
        [user getIDTokenForcingRefresh:YES completion:^(NSString *refreshedToken, NSError *refreshError) {
            (void)refreshError;
            idToken = refreshedToken;
            dispatch_group_leave(g);
        }];
    }];

    dispatch_group_enter(g);
    [[FIRAppCheck appCheck] limitedUseTokenWithCompletion:^(FIRAppCheckToken *t, NSError *e) {
        acToken = t.token;
        dispatch_group_leave(g);
    }];

    dispatch_group_notify(g, dispatch_get_main_queue(), ^{
        if (!idToken.length) {
            [self finish:completion msg:nil err:[self err:401 code:@"auth_token_failed"]];
            return;
        }
        [self sendMessage:message
                 language:language
                  idToken:idToken
            appCheckToken:acToken
               completion:completion];
    });

    return nil;
}

- (NSURLSessionDataTask *)sendMessage:(NSString *)message
                             language:(NSString *)language
                              idToken:(NSString *)idToken
                        appCheckToken:(NSString *)appCheckToken
                           completion:(void (^)(PPAgentMessage *, NSError *))completion {
    FIRUser *user = FIRAuth.auth.currentUser;
    if (!user) {
        [self finish:completion msg:nil err:[self err:401 code:@"not_signed_in"]];
        return nil;
    }
    NSString *acToken = appCheckToken ?: @"";
    NSString *vcSessionId = self.sessionId ?: @"";

    // Detect VC session reset — restore or create ADK session mapping.
    if (![vcSessionId isEqualToString:self.lastKnownVCSessionId ?: @""]) {
        self.lastKnownVCSessionId = vcSessionId;
        self.adkSessionId = [self storedADKSessionIdForVCSession:vcSessionId];
    }

    NSString *userId = user.uid;

    if (self.adkSessionId) {
        [self doRunMessage:message
                    userId:userId
                   idToken:idToken
                   acToken:acToken
                  language:language
         retryOnNotFound:YES
                completion:completion];
    } else {
        [self createADKSessionForUser:userId
                         vcSessionId:vcSessionId
                             idToken:idToken
                             acToken:acToken
                          completion:^(NSString *adkSid, NSError *err) {
            if (err || !adkSid) {
                [self finish:completion msg:nil err:err ?: [self err:503 code:@"session_create_failed"]];
                return;
            }
            self.adkSessionId = adkSid;
            [self doRunMessage:message
                        userId:userId
                       idToken:idToken
                       acToken:acToken
                      language:language
             retryOnNotFound:NO
                    completion:completion];
        }];
    }
    return nil;
}

#pragma mark - ADK Session Management

- (nullable NSString *)storedADKSessionIdForVCSession:(NSString *)vcSessionId {
    if (!vcSessionId.length) return nil;
    NSDictionary *map = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kADKSessionMapKey];
    id adkSid = map[vcSessionId];
    return [adkSid isKindOfClass:NSString.class] ? adkSid : nil;
}

- (void)storeADKSessionId:(NSString *)adkId forVCSession:(NSString *)vcSessionId {
    if (!adkId.length || !vcSessionId.length) return;
    NSMutableDictionary *map = [([[NSUserDefaults standardUserDefaults] dictionaryForKey:kADKSessionMapKey] ?: @{}) mutableCopy];
    map[vcSessionId] = adkId;
    [[NSUserDefaults standardUserDefaults] setObject:map forKey:kADKSessionMapKey];
}

- (void)createADKSessionForUser:(NSString *)userId
                   vcSessionId:(NSString *)vcSessionId
                       idToken:(NSString *)idToken
                       acToken:(NSString *)acToken
                    completion:(void (^)(NSString *adkSessionId, NSError *err))completion {
    NSString *urlStr = [NSString stringWithFormat:@"%@/apps/%@/users/%@/sessions",
                        kPPAgentBaseURL, kPPAgentAppName, userId];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.HTTPMethod = @"POST";
    if (idToken.length) {
        [req setValue:[NSString stringWithFormat:@"Bearer %@", idToken] forHTTPHeaderField:@"Authorization"];
    }
    if (acToken.length) [req setValue:acToken forHTTPHeaderField:@"X-Firebase-AppCheck"];
    [req setValue:@"application/json"                              forHTTPHeaderField:@"Content-Type"];
    // Declare client_type so the root coordinator routes to the market assistant.
    NSDictionary *sessionBody = @{
        @"state": @{
            @"client_type": @"ios",
            @"client_platform": @"ios",
            @"client_session_id": vcSessionId ?: @""
        }
    };
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:sessionBody options:0 error:nil];

    [[self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *netErr) {
        if (netErr) { completion(nil, netErr); return; }
        NSInteger code = ((NSHTTPURLResponse *)resp).statusCode;
        NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        NSString *adkSid = [json[@"id"] isKindOfClass:NSString.class] ? json[@"id"] : nil;
        if ((code == 200 || code == 201) && adkSid) {
            [self storeADKSessionId:adkSid forVCSession:vcSessionId];
            completion(adkSid, nil);
        } else {
            completion(nil, [self err:code code:@"session_create_failed"]);
        }
    }] resume];
}

#pragma mark - ADK Run

- (void)doRunMessage:(NSString *)message
              userId:(NSString *)userId
             idToken:(NSString *)idToken
             acToken:(NSString *)acToken
            language:(NSString *)language
    retryOnNotFound:(BOOL)retryOnNotFound
          completion:(void (^)(PPAgentMessage *, NSError *))completion {

    NSString *urlStr = [NSString stringWithFormat:@"%@/run", kPPAgentBaseURL];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.HTTPMethod = @"POST";
    if (idToken.length) {
        [req setValue:[NSString stringWithFormat:@"Bearer %@", idToken] forHTTPHeaderField:@"Authorization"];
    }
    if (acToken.length) [req setValue:acToken forHTTPHeaderField:@"X-Firebase-AppCheck"];
    [req setValue:@"application/json"                              forHTTPHeaderField:@"Content-Type"];
    NSString *acceptLanguage = language.length > 0 ? language : NSLocale.currentLocale.localeIdentifier;
    [req setValue:acceptLanguage                                  forHTTPHeaderField:@"Accept-Language"];

    NSDictionary *body = @{
        @"appName"   : kPPAgentAppName,
        @"userId"    : userId,
        @"sessionId" : self.adkSessionId,
        @"newMessage": @{
            @"role" : @"user",
            @"parts": @[ @{ @"text": message ?: @"" } ]
        }
    };
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    [[self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *netErr) {
        if (netErr) { [self finish:completion msg:nil err:netErr]; return; }

        NSInteger code = ((NSHTTPURLResponse *)resp).statusCode;
        id responseObject = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;

        // ADK session expired or deleted — recreate and retry once.
        if (code == 404 && retryOnNotFound) {
            self.adkSessionId = nil;
            NSString *vcSid = self.lastKnownVCSessionId ?: @"";
            [self createADKSessionForUser:userId
                             vcSessionId:vcSid
                                 idToken:idToken
                                 acToken:acToken
                              completion:^(NSString *adkSid, NSError *err) {
                if (err || !adkSid) {
                    [self finish:completion msg:nil err:err ?: [self err:503 code:@"session_create_failed"]];
                    return;
                }
                self.adkSessionId = adkSid;
                [self doRunMessage:message userId:userId idToken:idToken acToken:acToken language:language retryOnNotFound:NO completion:completion];
            }];
            return;
        }

        if (code != 200) {
            NSString *errCode = @"http_error";
            if ([responseObject isKindOfClass:NSDictionary.class]) {
                errCode = responseObject[@"error"] ?: errCode;
            }
            [self finish:completion msg:nil err:[self err:code code:errCode]];
            return;
        }

        NSDictionary *envelope = [self normalizedEnvelopeFromADKResponse:responseObject];
        NSError *pErr = nil;
        PPAgentMessage *m = envelope ? [PPAgentResponseParser parseEnvelope:envelope error:&pErr] : nil;
        if (!m && !pErr) { NSLog(@"[PPAgentClient] empty_response raw JSON: %@", responseObject); pErr = [self err:0 code:@"empty_response"]; }
        [self finish:completion msg:m err:pErr];
    }] resume];
}

#pragma mark - Response Normalization

/// Converts the ADK event array into a flat envelope dict that
/// PPAgentResponseParser.parseEnvelope: already understands.
///
/// Forward-scans the event array collecting:
///   • The last functionResponse whose `response` has renderable payload (cards/refs)
///   • The last model text turn
/// Then merges them so the parser receives both text and card data in one dict.
- (nullable NSDictionary *)normalizedEnvelopeFromADKResponse:(id)responseObject {
    // Passthrough for old proxy / single-dict shapes.
    if ([responseObject isKindOfClass:NSDictionary.class]) {
        NSDictionary *dict = (NSDictionary *)responseObject;
        id events = [dict[@"events"] isKindOfClass:NSArray.class] ? dict[@"events"] : nil;
        if (!events) {
            events = [dict[@"result"] isKindOfClass:NSArray.class] ? dict[@"result"] : nil;
        }
        if ([events isKindOfClass:NSArray.class]) {
            responseObject = events;
        } else {
            return responseObject;
        }
    }
    if (![responseObject isKindOfClass:NSArray.class]) return nil;

    NSArray *events = responseObject;
    NSDictionary *bestFunctionResponse = nil;
    NSString     *finalModelText       = nil;

    for (id rawEvent in events) {
        if (![rawEvent isKindOfClass:NSDictionary.class]) continue;
        NSDictionary *content = rawEvent[@"content"];
        if (![content isKindOfClass:NSDictionary.class]) continue;
        NSArray *parts = content[@"parts"];
        if (![parts isKindOfClass:NSArray.class]) continue;

        for (id part in parts) {
            if (![part isKindOfClass:NSDictionary.class]) continue;

            // Collect renderable functionResponse payloads (tool results with cards/refs).
            id funcResp = ((NSDictionary *)part)[@"functionResponse"]
                       ?: ((NSDictionary *)part)[@"function_response"];
            if ([funcResp isKindOfClass:NSDictionary.class]) {
                id responseObject = funcResp[@"response"];
                NSDictionary *response = [responseObject isKindOfClass:NSDictionary.class] ? responseObject : nil;
                if (!response && [responseObject isKindOfClass:NSString.class]) {
                    response = [self extractJSONEnvelopeFromText:responseObject];
                    if (!response && ![self isInternalNovaDebugText:responseObject] && !finalModelText.length) {
                        finalModelText = responseObject;
                    }
                }
                if ([response isKindOfClass:NSDictionary.class]) {
                    // Renderable: cards/refs data OR quick-reply option chips.
                    for (NSString *key in @[@"resultRefs", @"result_refs", @"cards",
                                            @"products", @"items", @"result_set", @"resultSet",
                                            @"options", @"suggestions", @"quickReplies"]) {
                        id val = response[key];
                        if ([val isKindOfClass:NSArray.class] && [(NSArray *)val count] > 0) {
                            bestFunctionResponse = response;
                            break;
                        }
                        if ([val isKindOfClass:NSDictionary.class]) {
                            bestFunctionResponse = response;
                            break;
                        }
                    }
                    if (!bestFunctionResponse) {
                        id cr = response[@"cardsRequired"] ?: response[@"cards_required"];
                        if ([cr respondsToSelector:@selector(boolValue)] && [cr boolValue]) {
                            bestFunctionResponse = response;
                        }
                    }
                }
            }

            // Collect plain text from model turns (last one wins).
            if ([@"model" isEqualToString:content[@"role"]]) {
                id txt = part[@"text"];
                if ([txt isKindOfClass:NSString.class] && [(NSString *)txt length] && ![self isInternalNovaDebugText:txt]) {
                    finalModelText = txt;
                }
            }
        }
    }

    // If the model wrapped its turn in a JSON envelope (fenced or raw), extract
    // it. Nova's prompt mandates JSON output for clarification turns so it can
    // attach quick-reply options; never hardcode option labels on the client.
    NSDictionary *modelJSON = [self extractJSONEnvelopeFromText:finalModelText];

    if (bestFunctionResponse) {
        NSMutableDictionary *merged = [bestFunctionResponse mutableCopy];
        if (modelJSON) {
            // Model-authored structured envelope is the final client contract.
            for (NSString *k in @[@"text", @"assistantText", @"options",
                                  @"suggestions", @"quickReplies", @"cards",
                                  @"resultRefs", @"result_refs", @"product_ids",
                                  @"productIds", @"productIDs", @"cardsRequired", @"cards_required"]) {
                id v = modelJSON[k];
                if (v) merged[k] = v;
            }
            if (![self novaEnvelopeHasRenderableCardPayload:merged] &&
                [self novaEnvelopeHasVisibleTextOrOptions:modelJSON]) {
                [self clearCardRequirementInEnvelope:merged];
            }
        } else if (finalModelText
                   && ![self isInternalNovaDebugText:finalModelText]
                   && !merged[@"text"]
                   && !merged[@"assistantText"]) {
            merged[@"text"] = finalModelText;
        }
        return [merged copy];
    }

    if (modelJSON) return modelJSON;
    if (finalModelText && ![self isInternalNovaDebugText:finalModelText]) return @{ @"text": finalModelText };

    // No client-authored Nova prose. Let the caller handle this as an
    // empty_response error instead of injecting visible assistant text.
    return nil;
}

- (BOOL)isInternalNovaDebugText:(NSString *)text {
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

/// Extract a JSON dict from the model's text turn — either inside a ```json ... ```
/// fenced block, or a raw `{...}` body. Returns nil if no valid JSON dict is found.
- (nullable NSDictionary *)extractJSONEnvelopeFromText:(NSString *)text {
    if (![text isKindOfClass:NSString.class] || !text.length) return nil;
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!trimmed.length) return nil;

    for (NSDictionary<NSString *, id> *candidate in [self jsonDictionaryCandidatesFromText:trimmed]) {
        NSDictionary *object = [candidate[@"object"] isKindOfClass:NSDictionary.class] ? candidate[@"object"] : nil;
        if ([self dictionaryLooksLikeNovaEnvelope:object]) {
            return object;
        }
    }

    if ([trimmed hasPrefix:@"{"] && [trimmed hasSuffix:@"}"]) {
        NSData *data = [trimmed dataUsingEncoding:NSUTF8StringEncoding];
        id parsed = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if ([parsed isKindOfClass:NSDictionary.class]) return parsed;
    }

    return nil;
}

- (NSArray<NSDictionary<NSString *, id> *> *)jsonDictionaryCandidatesFromText:(NSString *)text {
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

- (BOOL)dictionaryLooksLikeNovaEnvelope:(NSDictionary *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) {
        return NO;
    }
    for (NSString *key in @[@"text", @"assistantText", @"options", @"cards",
                            @"resultRefs", @"result_refs", @"product_ids",
                            @"productIds", @"productIDs", @"products", @"items", @"result_set",
                            @"resultSet", @"cardsRequired", @"cards_required"]) {
        if (dict[key]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)novaEnvelopeHasVisibleTextOrOptions:(NSDictionary *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) {
        return NO;
    }
    for (NSString *key in @[@"text", @"assistantText", @"output", @"response",
                            @"answer", @"message", @"content"]) {
        id value = dict[key];
        if ([value isKindOfClass:NSString.class] && [(NSString *)value length] > 0 && ![self isInternalNovaDebugText:value]) {
            return YES;
        }
    }
    id options = dict[@"options"] ?: dict[@"suggestions"] ?: dict[@"quickReplies"];
    return [options isKindOfClass:NSArray.class] && [(NSArray *)options count] > 0;
}

- (BOOL)novaEnvelopeHasRenderableCardPayload:(NSDictionary *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) {
        return NO;
    }
    for (NSString *key in @[@"resultRefs", @"result_refs", @"cards", @"products", @"items", @"product_ids", @"productIds", @"productIDs"]) {
        id value = dict[key];
        if ([value isKindOfClass:NSArray.class] && [(NSArray *)value count] > 0) {
            return YES;
        }
    }
    NSDictionary *resultSet = [dict[@"result_set"] isKindOfClass:NSDictionary.class] ? dict[@"result_set"] : nil;
    if (!resultSet) {
        resultSet = [dict[@"resultSet"] isKindOfClass:NSDictionary.class] ? dict[@"resultSet"] : nil;
    }
    for (NSString *key in @[@"cards", @"products", @"items", @"resultRefs", @"result_refs", @"product_ids", @"productIds", @"productIDs"]) {
        id value = resultSet[key];
        if ([value isKindOfClass:NSArray.class] && [(NSArray *)value count] > 0) {
            return YES;
        }
    }
    return NO;
}

- (void)clearCardRequirementInEnvelope:(NSMutableDictionary *)envelope {
    if (![envelope isKindOfClass:NSMutableDictionary.class]) {
        return;
    }
    envelope[@"cardsRequired"] = @NO;
    envelope[@"cards_required"] = @NO;
    envelope[@"textFallbackAllowed"] = @YES;
    envelope[@"text_fallback_allowed"] = @YES;

    for (NSString *key in @[@"result_set", @"resultSet", @"_compose_context", @"compose_context", @"composeContext"]) {
        NSDictionary *nested = [envelope[key] isKindOfClass:NSDictionary.class] ? envelope[key] : nil;
        if (!nested) {
            continue;
        }
        NSMutableDictionary *mutableNested = [nested mutableCopy];
        mutableNested[@"cardsRequired"] = @NO;
        mutableNested[@"cards_required"] = @NO;
        mutableNested[@"textFallbackAllowed"] = @YES;
        mutableNested[@"text_fallback_allowed"] = @YES;
        envelope[key] = [mutableNested copy];
    }
}

#pragma mark - Helpers

- (void)finish:(void (^)(PPAgentMessage *, NSError *))cb
           msg:(PPAgentMessage *)m
           err:(NSError *)e {
    if (!cb) return;
    dispatch_async(dispatch_get_main_queue(), ^{ cb(m, e); });
}

- (NSError *)err:(NSInteger)code code:(NSString *)c {
    return [NSError errorWithDomain:@"PPAgent"
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: c ?: @"unknown" }];
}

@end
