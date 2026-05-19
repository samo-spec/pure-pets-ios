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
        _isMemoryEnabled = YES; // Enable by default — needed so history reaches the proxy and the greeting doesn't re-fire on every cold open.
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
    if (!self.isMemoryEnabled || text.length == 0 || role.length == 0) return;
    
    // Privacy safeguard: do not store credit card formats or apparent tokens
    // (Simple heuristic: replace strings of digits > 12 if found, though true 
    // payment info shouldn't hit Nova chat anyway)
    NSString *safeText = [self _maskPotentialSensitiveData:text];
    
    // Offset model timestamps by 1ms past the last user timestamp so
    // chronological sort (array order) is unambiguous even within the same
    // millisecond window.
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    BOOL isModel = [role isEqualToString:@"nova"] || [role isEqualToString:@"model"] || [role isEqualToString:@"assistant"];
    if (isModel) {
        NSTimeInterval lastUserTs = 0;
        for (NSDictionary *m in self.messages.reverseObjectEnumerator) {
            NSString *r = m[@"role"];
            if ([r isEqualToString:@"user"]) {
                lastUserTs = [m[@"timestamp"] doubleValue];
                break;
            }
        }
        if (lastUserTs > 0 && now <= lastUserTs) {
            now = lastUserTs + 0.001;
        }
    }
    
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

- (NSArray<NSDictionary *> *)allMessages {
    __block NSArray *result = nil;
    dispatch_sync(self.ioQueue, ^{
        result = [self.messages copy];
    });
    return result ?: @[];
}

- (void)clearAllMessages {
    dispatch_async(self.ioQueue, ^{
        [self.messages removeAllObjects];
        [self _saveToDiskUnsafe];
    });
}

- (nullable NSString *)lastKnownPetType {
    __block NSString *result = nil;
    dispatch_sync(self.ioQueue, ^{
        for (NSDictionary *msg in self.messages.reverseObjectEnumerator) {
            NSString *text = msg[@"text"];
            if (text.length == 0) continue;
            NSString *lower = [text lowercaseString];
            result = [self _matchPetTypeInText:lower original:text];
            if (result) break;
        }
    });
    return result;
}

- (nullable NSString *)lastKnownNeed {
    __block NSString *result = nil;
    dispatch_sync(self.ioQueue, ^{
        for (NSDictionary *msg in self.messages.reverseObjectEnumerator) {
            NSString *text = msg[@"text"];
            if (text.length == 0) continue;
            NSString *lower = [text lowercaseString];
            result = [self _matchNeedInText:lower original:text];
            if (result) break;
        }
    });
    return result;
}

- (nullable NSString *)_matchPetTypeInText:(NSString *)lower original:(NSString *)original {
    NSArray<NSDictionary *> *petKeywords = @[
        @{@"label": @"cat",     @"keys": @[@"cat", @"cats", @"kitten", @"kitty",@"جاو",
                                            @"قط", @"قطة", @"قطه", @"قطتي", @"قطط", @"بسة", @"بسه", @"هر", @"هرة"]},
        @{@"label": @"dog",     @"keys": @[@"dog", @"dogs", @"puppy", @"pup",
                                            @"كلب", @"كلبة", @"كلبه", @"كلبي", @"جرو", @"كلاب"]},
        @{@"label": @"bird",    @"keys": @[@"bird", @"birds",
                                            @"طير", @"طائر", @"طيور", @"عصفور", @"عصافير"]},
        @{@"label": @"parrot",  @"keys": @[@"parrot", @"parrots", @"cockatiel", @"cockatoo", @"budgie",
                                            @"ببغاء", @"ببغاوات", @"كاسكو", @"درة", @"كروان"]},
        @{@"label": @"fish",    @"keys": @[@"fish", @"fishes", @"aquarium",
                                            @"سمك", @"سمكة", @"سمكه", @"أسماك", @"اسماك"]},
        @{@"label": @"rabbit",  @"keys": @[@"rabbit", @"rabbits", @"bunny",
                                            @"أرنب", @"ارنب", @"أرانب", @"ارانب"]},
        @{@"label": @"hamster", @"keys": @[@"hamster", @"hamsters",
                                            @"هامستر", @"هامستار"]},
        @{@"label": @"turtle",  @"keys": @[@"turtle", @"turtles", @"tortoise",
                                            @"سلحفاة", @"سلحفاه", @"سلاحف"]}
    ];
    for (NSDictionary *p in petKeywords) {
        for (NSString *kw in p[@"keys"]) {
            if ([lower containsString:kw] || [original containsString:kw]) {
                return p[@"label"];
            }
        }
    }
    return nil;
}

- (nullable NSString *)_matchNeedInText:(NSString *)lower original:(NSString *)original {
    NSArray<NSDictionary *> *needKeywords = @[
        @{@"label": @"food",     @"keys": @[@"food", @"feed", @"meal", @"kibble", @"treat", @"snack",
                                              @"dry food", @"wet food", @"dry", @"wet",
                                            @"طقة", @"عضة", @"جومة",
                                              @"أكل", @"اكل", @"طعام", @"غذاء", @"دراي", @"وجبة", @"وجبه", @"تغذية"]},
        @{@"label": @"cage",     @"keys": @[@"cage", @"carrier", @"crate", @"kennel", @"bed",
                                              @"aquarium", @"tank",
                                              @"قفص", @"أقفاص", @"اقفاص", @"حاملة", @"حقيبة", @"حقيبه",
                                              @"بيت", @"حوض", @"ناقلة", @"كاريير"]},
        @{@"label": @"toy",      @"keys": @[@"toy", @"toys", @"play", @"ball", @"chew",
                                              @"لعبة", @"لعبه", @"لعب", @"ألعاب", @"العاب", @"كرة"]},
        @{@"label": @"medicine", @"keys": @[@"medicine", @"medication", @"vitamin", @"vitamins",
                                              @"supplement", @"supplements", @"treatment",
                                              @"دواء", @"أدوية", @"ادوية", @"فيتامين", @"فيتامينات", @"علاج"]},
        @{@"label": @"care",     @"keys": @[@"care", @"grooming", @"groom", @"shampoo", @"brush",
                                              @"bath", @"nail", @"clean",
                                              @"عناية", @"عنايه", @"شامبو", @"تنظيف", @"نظافة",
                                              @"تمشيط", @"استحمام", @"تقليم"]},
        @{@"label": @"litter",   @"keys": @[@"litter", @"litter box", @"potty", @"toilet", @"sand",
                                              @"رمل", @"فضلات", @"ليتر"]}
    ];
    for (NSDictionary *n in needKeywords) {
        for (NSString *kw in n[@"keys"]) {
            if ([lower containsString:kw] || [original containsString:kw]) {
                return n[@"label"];
            }
        }
    }
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

#pragma mark - Session ID

static NSString * const kPPNovaSessionIdKey = @"pp_nova_last_session_id";

- (nullable NSString *)lastKnownSessionId {
    NSString *sessionId = [[NSUserDefaults standardUserDefaults] stringForKey:kPPNovaSessionIdKey];
    return sessionId.length > 0 ? sessionId : nil;
}

- (void)setLastKnownSessionId:(NSString *)sessionId {
    if (sessionId.length > 0) {
        [[NSUserDefaults standardUserDefaults] setObject:sessionId forKey:kPPNovaSessionIdKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

@end
