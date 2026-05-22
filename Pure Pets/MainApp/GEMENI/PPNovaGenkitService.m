//
//  PPNovaGenkitService.m
//  Pure Pets
//

#import "PPNovaGenkitService.h"
@import FirebaseFunctions;
@import FirebaseAuth;

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
    id details = userInfo[@"details"] ?: userInfo[@"FIRFunctionsErrorDetailsKey"];
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
    
    FIRFunctions *functions = [FIRFunctions functionsForRegion:@"us-central1"];
    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:@"novaGenkitChat"];
    
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    data[@"message"] = message ?: @"";
    if (sessionId) {
        data[@"sessionId"] = sessionId;
    }
    data[@"language"] = language ?: @"ar";
    if (context) {
        data[@"context"] = context;
    }
    
    [callable callWithObject:data completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[PPNovaGenkitService] novaGenkitChat failed %@", PPNovaGenkitErrorSummary(error));
            if (completion) {
                completion(nil, nil, error);
            }
            return;
        }
        
        NSDictionary *responseDict = result.data;
        if ([responseDict isKindOfClass:[NSDictionary class]]) {
            NSString *text = responseDict[@"text"];
            NSDictionary *metadata = responseDict[@"metadata"];
            if (completion) {
                completion(text, metadata, nil);
            }
        } else {
            if (completion) {
                NSError *parseError = [NSError errorWithDomain:@"PPNovaGenkitErrorDomain" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid response format"}];
                completion(nil, nil, parseError);
            }
        }
    }];
}

@end
