//
//  PPNovaLocalChatMemory.m
//  Pure Pets
//

#import "PPNovaLocalChatMemory.h"

// Keep up to 100 messages total to avoid runaway file size.
static const NSUInteger kMaxMessagesToKeep = 100;
static const NSTimeInterval kMaxAgeSeconds = 30 * 24 * 60 * 60; // 30 days

@interface PPNovaLocalChatMemory ()
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *messages;
@property (nonatomic, strong) dispatch_queue_t ioQueue;
@property (nonatomic, copy) NSString *filePath;
@end

@implementation PPNovaLocalChatMemory

+ (instancetype)sharedMemory {
    static PPNovaLocalChatMemory *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[PPNovaLocalChatMemory alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _messages = [NSMutableArray array];
        _ioQueue = dispatch_queue_create("com.purepets.nova.memory", DISPATCH_QUEUE_SERIAL);
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *docDir = paths.firstObject;
        _filePath = [docDir stringByAppendingPathComponent:@".nova_local_chat_memory.json"];
        
        [self cleanupAndLoad];
    }
    return self;
}

- (void)cleanupAndLoad {
    dispatch_sync(self.ioQueue, ^{
        if (![[NSFileManager defaultManager] fileExistsAtPath:self.filePath]) {
            return;
        }
        
        NSData *data = [NSData dataWithContentsOfFile:self.filePath];
        if (!data) return;
        
        NSError *error = nil;
        NSArray *loaded = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (![loaded isKindOfClass:[NSArray class]]) {
            return;
        }
        
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        NSMutableArray *validMessages = [NSMutableArray array];
        
        for (NSDictionary *msg in loaded) {
            if (![msg isKindOfClass:[NSDictionary class]]) continue;
            
            NSNumber *ts = msg[@"timestamp"];
            if (![ts isKindOfClass:[NSNumber class]]) continue;
            
            if (now - ts.doubleValue <= kMaxAgeSeconds) {
                [validMessages addObject:msg];
            }
        }
        
        // Enforce max count
        if (validMessages.count > kMaxMessagesToKeep) {
            NSRange range = NSMakeRange(validMessages.count - kMaxMessagesToKeep, kMaxMessagesToKeep);
            validMessages = [[validMessages subarrayWithRange:range] mutableCopy];
        }
        
        self.messages = validMessages;
        [self _saveToDiskUnsafe];
    });
}

- (BOOL)hasPreviousHistory {
    __block BOOL hasHistory = NO;
    dispatch_sync(self.ioQueue, ^{
        hasHistory = (self.messages.count > 0);
    });
    return hasHistory;
}

- (void)addMessageWithRole:(NSString *)role text:(NSString *)text {
    if (text.length == 0 || role.length == 0) return;
    
    // Privacy safeguard: do not store credit card formats or apparent tokens
    // (Simple heuristic: replace strings of digits > 12 if found, though true 
    // payment info shouldn't hit Nova chat anyway)
    NSString *safeText = [self _maskPotentialSensitiveData:text];
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSDictionary *msg = @{
        @"role": role,
        @"text": safeText,
        @"timestamp": @(now)
    };
    
    dispatch_async(self.ioQueue, ^{
        [self.messages addObject:msg];
        if (self.messages.count > kMaxMessagesToKeep) {
            [self.messages removeObjectAtIndex:0];
        }
        [self _saveToDiskUnsafe];
    });
}

- (NSArray<NSDictionary *> *)recentHistoryLimit:(NSUInteger)limit {
    __block NSArray *result = nil;
    dispatch_sync(self.ioQueue, ^{
        if (self.messages.count <= limit) {
            result = [self.messages copy];
        } else {
            NSRange range = NSMakeRange(self.messages.count - limit, limit);
            result = [self.messages subarrayWithRange:range];
        }
    });
    
    // Format for backend contract: {role: "user"|"model", text: "..."}
    NSMutableArray *formatted = [NSMutableArray array];
    for (NSDictionary *dict in result) {
        NSString *role = dict[@"role"];
        if ([role isEqualToString:@"nova"]) role = @"model";
        [formatted addObject:@{
            @"role": role ?: @"user",
            @"text": dict[@"text"] ?: @""
        }];
    }
    return formatted;
}

- (NSString *)recentContextSummary {
    NSArray *recent = [self recentHistoryLimit:10];
    NSMutableArray *lines = [NSMutableArray array];
    for (NSDictionary *msg in recent) {
        [lines addObject:[NSString stringWithFormat:@"%@: %@", msg[@"role"], msg[@"text"]]];
    }
    return [lines componentsJoinedByString:@" | "];
}

- (nullable NSString *)lastKnownPetType {
    // This is extracted globally per session in NovaChatViewController normally.
    // If we wanted cross-session extraction, we'd regex the history here.
    // For now, we rely on PPNovaChatViewController's own extraction logic,
    // which we will seed from recent history on boot.
    return nil;
}

- (nullable NSString *)lastKnownNeed {
    return nil;
}

#pragma mark - Internal

- (void)_saveToDiskUnsafe {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:self.messages options:0 error:&error];
    if (data) {
        [data writeToFile:self.filePath atomically:YES];
    }
}

- (NSString *)_maskPotentialSensitiveData:(NSString *)text {
    // Very basic safety mask for 14-16 digit numbers that might be CCs
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\b\\d{14,16}\\b" options:0 error:nil];
    return [regex stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"[REDACTED]"];
}

@end
