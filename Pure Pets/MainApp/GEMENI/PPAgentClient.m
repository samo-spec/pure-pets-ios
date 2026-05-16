//
//  PPAgentClient.m
//  PurePets
//

#import "PPAgentClient.h"
#import "PPAgentResponseParser.h"
@import FirebaseAuth;
@import FirebaseAppCheck;

// ADK Cloud Run base URL — all paths are relative to this.
NSString * const kPPAgentBaseURL = @"https://nova-ufzhhjmzdq-uc.a.run.app";

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
        cfg.timeoutIntervalForRequest = 60.0;
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
        idToken = t;
        dispatch_group_leave(g);
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
        // acToken may be empty if App Check isn't enforced — the ADK server doesn't check it.

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
                 retryOnNotFound:NO
                        completion:completion];
            }];
        }
    });

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
    [req setValue:[NSString stringWithFormat:@"Bearer %@", idToken] forHTTPHeaderField:@"Authorization"];
    if (acToken.length) [req setValue:acToken forHTTPHeaderField:@"X-Firebase-AppCheck"];
    [req setValue:@"application/json"                              forHTTPHeaderField:@"Content-Type"];
    // Declare client_type so the root coordinator routes to nova_market_assistan.
    NSDictionary *sessionBody = @{ @"state": @{ @"client_type": @"ios" } };
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
    retryOnNotFound:(BOOL)retryOnNotFound
          completion:(void (^)(PPAgentMessage *, NSError *))completion {

    NSString *urlStr = [NSString stringWithFormat:@"%@/run", kPPAgentBaseURL];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.HTTPMethod = @"POST";
    [req setValue:[NSString stringWithFormat:@"Bearer %@", idToken] forHTTPHeaderField:@"Authorization"];
    if (acToken.length) [req setValue:acToken forHTTPHeaderField:@"X-Firebase-AppCheck"];
    [req setValue:@"application/json"                              forHTTPHeaderField:@"Content-Type"];
    [req setValue:NSLocale.currentLocale.localeIdentifier          forHTTPHeaderField:@"Accept-Language"];

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
                [self doRunMessage:message userId:userId idToken:idToken acToken:acToken retryOnNotFound:NO completion:completion];
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
        if (!m && !pErr) pErr = [self err:0 code:@"empty_response"];
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
    if ([responseObject isKindOfClass:NSDictionary.class]) return responseObject;
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
                NSDictionary *response = funcResp[@"response"];
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
                if ([txt isKindOfClass:NSString.class] && [(NSString *)txt length]) {
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
            // Model-authored fields override tool defaults: text, options, cards.
            for (NSString *k in @[@"text", @"assistantText", @"options",
                                  @"suggestions", @"quickReplies", @"cards"]) {
                id v = modelJSON[k];
                if (v) merged[k] = v;
            }
        } else if (finalModelText
                   && !merged[@"text"]
                   && !merged[@"assistantText"]) {
            merged[@"text"] = finalModelText;
        }
        return [merged copy];
    }

    if (modelJSON) return modelJSON;
    if (finalModelText) return @{ @"text": finalModelText };

    return nil;
}

/// Extract a JSON dict from the model's text turn — either inside a ```json ... ```
/// fenced block, or a raw `{...}` body. Returns nil if no valid JSON dict is found.
- (nullable NSDictionary *)extractJSONEnvelopeFromText:(NSString *)text {
    if (![text isKindOfClass:NSString.class] || !text.length) return nil;
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!trimmed.length) return nil;

    NSRegularExpression *fenced =
        [NSRegularExpression regularExpressionWithPattern:@"```(?:json)?\\s*(\\{(?:.|\\n|\\r)*\\})\\s*```"
                                                  options:NSRegularExpressionCaseInsensitive
                                                    error:nil];
    NSTextCheckingResult *match = [fenced firstMatchInString:trimmed
                                                     options:0
                                                       range:NSMakeRange(0, trimmed.length)];
    if (match && match.numberOfRanges > 1) {
        NSString *body = [trimmed substringWithRange:[match rangeAtIndex:1]];
        NSData *data = [body dataUsingEncoding:NSUTF8StringEncoding];
        id parsed = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if ([parsed isKindOfClass:NSDictionary.class]) return parsed;
    }

    if ([trimmed hasPrefix:@"{"] && [trimmed hasSuffix:@"}"]) {
        NSData *data = [trimmed dataUsingEncoding:NSUTF8StringEncoding];
        id parsed = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if ([parsed isKindOfClass:NSDictionary.class]) return parsed;
    }

    return nil;
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
