//
//  PPHomeItem.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/01/2026.
//

#import "PPHomeItem.h"
@implementation PPHomeItem

- (instancetype)init
{
    self = [super init];
    if (self) {
        _identifier = [[NSUUID UUID] UUIDString];
    }
    return self;
}

- (instancetype)initWithType:(PPHomeItemType)type payload:(id)payload {
    self = [self init];
    if (self) {
        _type = type;
        _payload = payload;
    }
    return self;
}

- (instancetype)initWithType:(PPHomeItemType)type
             universalModel:(PPUniversalCellViewModel *)viewModel {
    
    self = [self init];
    
    if (self) {
        _type = type;
        _universalViewModel = viewModel;
    }
    
    return self;
}

#pragma mark - Diffable Identity

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:[PPHomeItem class]]) return NO;
    return [self.identifier isEqualToString:((PPHomeItem *)object).identifier];
}

- (NSUInteger)hash {
    return self.identifier.hash;
}

@end
