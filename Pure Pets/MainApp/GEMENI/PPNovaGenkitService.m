//
//  PPNovaGenkitService.m
//  Pure Pets
//

#import "PPNovaGenkitService.h"
#import <FirebaseAuth/FirebaseAuth.h>

static NSString * const PPNovaGenkitErrorDomain = @"PPNovaGenkitErrorDomain";
static NSString * const PPNovaGenkitCallableURLString = @"https://us-central1-pure-pets-49199.cloudfunctions.net/novaGenkitChat";

static NSString *PPNovaGenkitTrimmedDescription(id value) {
    NSString *text = nil;
    if ([value isKindOfClass:NSString.class]) {
        text = (NSString *)value;
    } else if (value) {
        text = [value description];
    }
    if (text.length <= 600) {
        return text ?: @"";
    }
    return [[text substringToIndex:600] stringByAppendingString:@"..."];
}

static NSError *PPNovaGenkitError(NSInteger code, NSString *description, id details) {
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[NSLocalizedDescriptionKey] = description.length > 0 ? description : @"Nova request failed.";
    if (details) {
        userInfo[@"details"] = details;
    }
    return [NSError errorWithDomain:PPNovaGenkitErrorDomain code:code userInfo:userInfo];
}

static NSInteger PPNovaGenkitMappedCallableCode(NSInteger statusCode, NSDictionary *errorDict) {
    NSString *status = [errorDict[@"status"] isKindOfClass:NSString.class] ? errorDict[@"status"] : @"";
    if ([status isEqualToString:@"UNAUTHENTICATED"]) return 16;
    if ([status isEqualToString:@"PERMISSION_DENIED"]) return 7;
    if ([status isEqualToString:@"RESOURCE_EXHAUSTED"]) return 8;
    if ([status isEqualToString:@"UNAVAILABLE"]) return 14;
    return statusCode;
}

static NSString *PPNovaGenkitErrorSummary(NSError *error) {
    if (!error) {
        return @"(nil)";
    }

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    [parts addObject:[NSString stringWithFormat:@"domain=%@ code=%ld",
                      error.domain ?: @"",
                      (long)error.code]];
    if (error.localizedDescription.length > 0) {
        [parts addObject:[NSString stringWithFormat:@"description=%@",
                          PPNovaGenkitTrimmedDescription(error.localizedDescription)]];
    }

    NSDictionary *userInfo = [error.userInfo isKindOfClass:NSDictionary.class] ? error.userInfo : nil;
    id details = userInfo[@"details"];
    if (details) {
        [parts addObject:[NSString stringWithFormat:@"details=%@",
                          PPNovaGenkitTrimmedDescription(details)]];
    }

    NSError *underlying = [userInfo[NSUnderlyingErrorKey] isKindOfClass:NSError.class]
        ? userInfo[NSUnderlyingErrorKey]
        : nil;
    if (underlying) {
        [parts addObject:[NSString stringWithFormat:@"underlying={domain=%@ code=%ld description=%@}",
                          underlying.domain ?: @"",
                          (long)underlying.code,
                          PPNovaGenkitTrimmedDescription(underlying.localizedDescription)]];
    }

    return [parts componentsJoinedByString:@" "];
}

@implementation PPNovaGenkitService

+ (instancetype)sharedService {
    static PPNovaGenkitService *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (void)sendMessage:(NSString *)message
          sessionId:(nullable NSString *)sessionId
           language:(NSString *)language
            context:(nullable NSDictionary *)context
         completion:(void(^)(NSString * _Nullable text, NSDictionary * _Nullable metadata, NSError * _Nullable error))completion {
    NSURL *url = [NSURL URLWithString:PPNovaGenkitCallableURLString];
    if (!url) {
        if (completion) {
            completion(nil, nil, PPNovaGenkitError(-1, @"Invalid Nova callable URL.", nil));
        }
        return;
    }

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"message"] = message ?: @"";
    if (sessionId.length > 0) {
        payload[@"sessionId"] = sessionId;
    }
    payload[@"language"] = language ?: @"ar";
    if ([context isKindOfClass:NSDictionary.class]) {
        payload[@"context"] = context;
    }

    NSDictionary *body = @{@"data": payload};
    NSError *jsonError = nil;
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
    if (!bodyData || jsonError) {
        if (completion) {
            completion(nil, nil, PPNovaGenkitError(-2, @"Invalid Nova request payload.", jsonError));
        }
        return;
    }

    // Builds and fires the request with whatever auth token we resolved. A nil
    // token means we send as a guest — the server accepts both (optional auth).
    void (^performSend)(NSString * _Nullable) = ^(NSString * _Nullable authToken) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.HTTPMethod = @"POST";
        request.timeoutInterval = 60.0;
        request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        request.HTTPBody = bodyData;
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        [request setValue:@"ios" forHTTPHeaderField:@"X-PurePets-Client"];
        if (authToken.length > 0) {
            // Firebase callable auth: the server reads request.auth from this Bearer token.
            [request setValue:[@"Bearer " stringByAppendingString:authToken]
           forHTTPHeaderField:@"Authorization"];
        }
        NSLog(@"[PPNovaGenkitService] novaGenkitChat sending auth=%@", authToken.length > 0 ? @"bearer" : @"guest");

        NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
        configuration.timeoutIntervalForRequest = 60.0;
        configuration.timeoutIntervalForResource = 75.0;
        if ([configuration respondsToSelector:@selector(setWaitsForConnectivity:)]) {
            configuration.waitsForConnectivity = YES;
        }

        NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
        [[session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data,
                                                                 NSURLResponse * _Nullable response,
                                                                 NSError * _Nullable error) {
            [session finishTasksAndInvalidate];

            if (error) {
                NSLog(@"[PPNovaGenkitService] novaGenkitChat HTTP failed %@", PPNovaGenkitErrorSummary(error));
                if (completion) {
                    completion(nil, nil, error);
                }
                return;
            }

            NSInteger statusCode = [response isKindOfClass:NSHTTPURLResponse.class]
                ? ((NSHTTPURLResponse *)response).statusCode
                : 0;

            id responseObject = data.length > 0 ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
            NSDictionary *responseDict = [responseObject isKindOfClass:NSDictionary.class] ? responseObject : nil;

            if (statusCode < 200 || statusCode >= 300) {
                NSDictionary *errorDict = [responseDict[@"error"] isKindOfClass:NSDictionary.class] ? responseDict[@"error"] : nil;
                NSString *message = [errorDict[@"message"] isKindOfClass:NSString.class]
                    ? errorDict[@"message"]
                    : [NSString stringWithFormat:@"Nova request failed with HTTP %ld.", (long)statusCode];
                NSInteger mappedCode = PPNovaGenkitMappedCallableCode(statusCode, errorDict);
                NSError *httpError = PPNovaGenkitError(mappedCode, message, errorDict ?: responseDict ?: @{});
                NSLog(@"[PPNovaGenkitService] novaGenkitChat HTTP rejected %@", PPNovaGenkitErrorSummary(httpError));
                if (completion) {
                    completion(nil, nil, httpError);
                }
                return;
            }

            id result = responseDict[@"data"] ?: responseDict[@"result"];
            NSDictionary *resultDict = [result isKindOfClass:NSDictionary.class] ? result : nil;
            if (!resultDict) {
                NSError *parseError = PPNovaGenkitError(-3, @"Invalid Nova response format.", responseDict ?: @{});
                NSLog(@"[PPNovaGenkitService] novaGenkitChat parse failed %@", PPNovaGenkitErrorSummary(parseError));
                if (completion) {
                    completion(nil, nil, parseError);
                }
                return;
            }

            NSString *text = [resultDict[@"text"] isKindOfClass:NSString.class] ? resultDict[@"text"] : @"";
            NSDictionary *metadata = [resultDict[@"metadata"] isKindOfClass:NSDictionary.class] ? resultDict[@"metadata"] : nil;
            if (completion) {
                completion(text, metadata, nil);
            }
        }] resume];
    };

    // Attach the signed-in user's Firebase ID token so the server sees request.auth.
    // getIDTokenWithCompletion: returns a cached token and auto-refreshes when expired.
    // On failure (or no user) we proceed as a guest rather than blocking the chat.
    FIRUser *currentUser = [FIRAuth auth].currentUser;
    if (currentUser) {
        [currentUser getIDTokenWithCompletion:^(NSString * _Nullable token, NSError * _Nullable tokenError) {
            if (tokenError) {
                NSLog(@"[PPNovaGenkitService] ID token fetch failed, sending as guest: %@", PPNovaGenkitErrorSummary(tokenError));
            }
            performSend(tokenError ? nil : token);
        }];
    } else {
        performSend(nil);
    }
}

@end
