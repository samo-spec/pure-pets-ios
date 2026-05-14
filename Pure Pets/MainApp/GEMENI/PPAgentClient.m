//
//  PPAgentClient.m
//  PurePets
//

#import "PPAgentClient.h"
#import "PPAgentResponseParser.h"
@import FirebaseAuth;
@import FirebaseAppCheck;

// >>> REPLACE with the URL Cloud Run prints after `gcloud run deploy`.
// Example: https://pp-nova-agent-proxy-646051621158.us-central1.run.app/chat
// TODO: set Cloud Run URL
// TODO: set Cloud Run URL — grep-able
NSString * const kPPAgentProxyURL = @"https://pp-nova-agent-proxy-646051621158.us-central1.run.app/chat";
 
@interface PPAgentClient ()
@property (nonatomic, strong) NSURLSession *session;
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
        _session   = [NSURLSession sessionWithConfiguration:cfg];
        _sessionId = [self freshSessionId];
    }
    return self;
}

- (void)resetSession {
    self.sessionId = [self freshSessionId];
}

- (NSString *)freshSessionId {
    return [NSString stringWithFormat:@"s_%@", [NSUUID UUID].UUIDString];
}

- (NSURLSessionDataTask *)sendMessage:(NSString *)message
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
        if (!idToken.length || !acToken.length) {
            [self finish:completion msg:nil err:[self err:401 code:@"auth_token_failed"]];
            return;
        }

        NSMutableURLRequest *req =
            [NSMutableURLRequest requestWithURL:[NSURL URLWithString:kPPAgentProxyURL]];
        req.HTTPMethod = @"POST";
        [req setValue:[NSString stringWithFormat:@"Bearer %@", idToken]
            forHTTPHeaderField:@"Authorization"];
        [req setValue:acToken forHTTPHeaderField:@"X-Firebase-AppCheck"];
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [req setValue:NSLocale.currentLocale.localeIdentifier
            forHTTPHeaderField:@"Accept-Language"];

        NSDictionary *body = @{
            @"message"   : message ?: @"",
            @"sessionId" : self.sessionId
        };
        req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

        NSURLSessionDataTask *t = [self.session dataTaskWithRequest:req
            completionHandler:^(NSData *data, NSURLResponse *resp, NSError *netErr) {

                if (netErr) {
                    [self finish:completion msg:nil err:netErr];
                    return;
                }

                NSInteger code = ((NSHTTPURLResponse *)resp).statusCode;
                NSDictionary *json = data
                    ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil]
                    : nil;

                if (code != 200) {
                    NSString *errCode = json[@"error"] ?: @"http_error";
                    [self finish:completion msg:nil err:[self err:code code:errCode]];
                    return;
                }

                NSError *pErr = nil;
                PPAgentMessage *m = [PPAgentResponseParser parseEnvelope:json error:&pErr];
                [self finish:completion msg:m err:pErr];
            }];
        [t resume];
    });

    return nil; // task created inside the auth block; not exposed for cancel here
}

#pragma mark - helpers

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
