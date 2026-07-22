//
//  PPStory.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 2/22/26.
//

#import "PPStory.h"

const NSTimeInterval PPStoryExpiryInterval = 86400.0;

@implementation PPStoryItem
@end

@implementation PPStory

- (instancetype)init {
    self = [super init];
    if (self) {
        _viewedBy = [NSSet set];
        _items = @[];
    }
    return self;
}

- (BOOL)isExpired {
    NSDate *referenceDate = self.updatedAt ?: self.createdAt;
    if (!referenceDate) {
        return NO;
    }
    return [[NSDate date] timeIntervalSinceDate:referenceDate] > PPStoryExpiryInterval;
}

- (BOOL)isSeenByUserID:(NSString *)userID {
    if (userID.length == 0) {
        return NO;
    }
    if (self.viewedBy.count > 0) {
        return [self.viewedBy containsObject:userID];
    }
    return self.isSeen;
}

@end
