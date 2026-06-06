//
//  PPNovaGenkitService.m
//  Pure Pets
//

#import "PPNovaGenkitService.h"
@import FirebaseFunctions;

static NSString * const PPNovaGenkitErrorDomain = @"PPNovaGenkitErrorDomain";
static NSString * const PPNovaGenkitCallableName = @"novaGenkitChat";
static NSString * const PPNovaGenkitCallableRegion = @"us-central1";

static NSString *PPNovaGenkitTrimmedString(NSString *value) {
    if (![value isKindOfClass:NSString.class]) {
        return @"";
    }
    return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
}

static NSString *PPNovaGenkitNormalizedLanguage(NSString *language) {
    return [language isEqualToString:@"en"] ? @"en" : @"ar";
}

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

@interface PPNovaGenkitService ()
@property (nonatomic, strong) FIRFunctions *functions;
@end

@implementation PPNovaGenkitService

+ (instancetype)sharedService {
    static PPNovaGenkitService *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _functions = [FIRFunctions functionsForRegion:PPNovaGenkitCallableRegion];
    }
    return self;
}

- (void)sendMessage:(NSString *)message
          sessionId:(nullable NSString *)sessionId
           language:(NSString *)language
            context:(nullable NSDictionary *)context
         completion:(void(^)(NSString * _Nullable text, NSDictionary * _Nullable metadata, NSError * _Nullable error))completion {
    NSString *trimmedMessage = PPNovaGenkitTrimmedString(message);
    if (trimmedMessage.length == 0) {
        if (completion) {
            completion(nil, nil, PPNovaGenkitError(-4, @"Nova message is required.", nil));
        }
        return;
    }

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"message"] = trimmedMessage;

    NSString *trimmedSessionId = PPNovaGenkitTrimmedString(sessionId);
    if (trimmedSessionId.length > 0) {
        payload[@"sessionId"] = trimmedSessionId;
    }

    payload[@"language"] = PPNovaGenkitNormalizedLanguage(language);
    if ([context isKindOfClass:NSDictionary.class]) {
        payload[@"context"] = context;
    }

    FIRHTTPSCallable *callable = [self.functions HTTPSCallableWithName:PPNovaGenkitCallableName];
    NSLog(@"[PPNovaGenkitService] novaGenkitChat sending via FIRFunctions region=%@", PPNovaGenkitCallableRegion);
    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[PPNovaGenkitService] novaGenkitChat callable failed %@", PPNovaGenkitErrorSummary(error));
            if (completion) {
                completion(nil, nil, error);
            }
            return;
        }

        NSDictionary *resultDict = [result.data isKindOfClass:NSDictionary.class] ? (NSDictionary *)result.data : nil;
        if (!resultDict) {
            NSError *parseError = PPNovaGenkitError(-3, @"Invalid Nova response format.", result.data ?: @{});
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
    }];
}

@end
