
//
//  PPBrowseHistoryManager.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 07/01/2026.
//

#import "PPBrowseHistoryManager.h"

static NSString * const kPPBrowseHistoryKey = @"pp.browse.history";
static NSInteger const kPPBrowseHistoryMaxItems = 40;

@interface PPBrowseHistoryManager ()
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *events;
@end

@implementation PPBrowseHistoryManager

+ (instancetype)shared
{
    static PPBrowseHistoryManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[PPBrowseHistoryManager alloc] initPrivate];
    });
    return manager;
}

- (instancetype)init
{
    NSAssert(NO, @"Use +shared");
    return nil;
}

- (instancetype)initPrivate
{
    self = [super init];
    if (self) {
        [self loadHistory];
    }
    return self;
}

#pragma mark - Public API

- (void)trackItemWithType:(PPBrowseItemType)type
               mainKindID:(NSInteger)mainKindID
{
    if (mainKindID <= 0) {
        return;
    }

    NSDictionary *event = @{
        @"type" : @(type),
        @"kind" : @(mainKindID),
        @"date" : @([[NSDate date] timeIntervalSince1970])
    };

    // Insert newest first
    [self.events insertObject:event atIndex:0];

    // Trim old items
    if (self.events.count > kPPBrowseHistoryMaxItems) {
        [self.events removeObjectsInRange:
         NSMakeRange(kPPBrowseHistoryMaxItems,
                     self.events.count - kPPBrowseHistoryMaxItems)];
    }

    [self persist];
    
    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"PPBrowseHistoryDidUpdate"
                      object:nil];
}

- (NSArray<NSNumber *> *)topMainKindsWithLimit:(NSInteger)limit
{
    if (limit <= 0 || self.events.count == 0) {
        return @[];
    }

    NSMutableDictionary<NSNumber *, NSNumber *> *weights = [NSMutableDictionary dictionary];

    // Newer events weigh more
    NSInteger index = 0;
    for (NSDictionary *event in self.events) {
        NSNumber *kindID = event[@"kind"];
        if (!kindID) continue;

        NSInteger weight = MAX(1, (NSInteger)(10 - index));
        NSInteger current = weights[kindID].integerValue;
        weights[kindID] = @(current + weight);

        index++;
        if (index > 10) break; // only recent events matter
    }

    // Sort by weight DESC
    NSArray *sorted =
    [weights keysSortedByValueUsingComparator:^NSComparisonResult(id  _Nonnull obj1,
                                                                   id  _Nonnull obj2) {
        return [obj2 compare:obj1];
    }];

    if (sorted.count <= limit) {
        return sorted;
    }

    return [sorted subarrayWithRange:NSMakeRange(0, limit)];
}

#pragma mark - Persistence

- (void)loadHistory
{
    NSArray *saved =
    [[NSUserDefaults standardUserDefaults] objectForKey:kPPBrowseHistoryKey];

    if ([saved isKindOfClass:NSArray.class]) {
        self.events = [saved mutableCopy];
    } else {
        self.events = [NSMutableArray array];
    }
}

- (void)persist
{
    [[NSUserDefaults standardUserDefaults]
     setObject:self.events
     forKey:kPPBrowseHistoryKey];

    [[NSUserDefaults standardUserDefaults] synchronize];
}


- (NSDictionary *)latestEvent
{
    return self.events.firstObject;
}

@end
